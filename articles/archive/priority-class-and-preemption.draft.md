# 후속 초안. PriorityClass와 선점

> 이 글은 7장에서 분리한 후속 주제 초안이며 장 번호는 아직 정하지 않았습니다. requests를 기준으로 한 자원 경쟁에서 PriorityClass와 선점이 작동하는 조건을 실습합니다.

## 들어가며

Pod가 `Pending`인 이유는 하나가 아닙니다. Taint를 허용하지 못했거나 Node 선택 조건이 맞지 않을 수 있고, 모든 후보 Node에 requests를 수용할 자원이 없을 수도 있습니다. PriorityClass는 마지막 경우에 어떤 Pod를 먼저 배치하고 낮은 우선순위 Pod를 선점 후보로 검토할지 정합니다.[[1]](#ref-1)

이 글은 CPU·메모리 requests와 limits의 기본 의미, `Pending` 이벤트 읽기를 선행 조건으로 둡니다. 실습은 다른 워크로드에 영향을 주지 않는 전용 Node에서 진행해야 합니다. 출력은 조건을 설명하기 위한 예시이며 실제 선점 수와 이벤트 문구는 클러스터 상태에 따라 달라집니다.

## 1. PriorityClass의 범위와 선행 조건

PriorityClass는 이름과 정수 우선순위 값을 연결하는 클러스터 범위 리소스입니다. Pod는 `spec.priorityClassName`으로 클래스를 참조하고, API Server가 대응하는 숫자를 Pod의 `spec.priority`에 기록합니다. 값이 클수록 우선순위가 높습니다.

선점은 높은 우선순위 Pod가 `Pending`이고, 낮은 우선순위 Pod를 제거하면 그 Node에 배치할 수 있을 때 Scheduler가 검토합니다. 다음 조건에서는 높은 우선순위만으로 문제가 해결되지 않습니다.

- requests 기준 자원이 이미 충분하면 낮은 우선순위 Pod를 제거할 이유가 없습니다.
- Taint, Node Selector, Affinity 같은 필수 조건이 맞지 않으면 선점으로 해결할 수 없습니다.
- 낮은 우선순위 Pod를 제거해도 필요한 자원을 확보할 수 없으면 선점이 성립하지 않습니다.
- `preemptionPolicy: Never`인 PriorityClass를 사용하면 우선순위는 높아도 다른 Pod를 선점하지 않습니다.
- PodDisruptionBudget은 선점 후보 선택에 고려되지만 항상 위반을 막는 절대 보장은 아닙니다.

Scheduler는 실시간 사용량이 아니라 각 Pod의 `resources.requests`를 기준으로 배치 가능성을 계산합니다.[[2]](#ref-2) `kubectl top`은 관측 보조 자료이며 선점 판단값 자체가 아닙니다.

## 2. 두 PriorityClass 정의

다음을 `priorityclasses.yaml`로 저장합니다.

```yaml
# 결제 처리와 배치 작업의 우선순위를 정의하는 두 PriorityClass
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: payments-critical
value: 100000
globalDefault: false
description: "결제 처리용 높은 우선순위"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-low
value: 100
globalDefault: false
description: "재실행 가능한 배치용 낮은 우선순위"
```

- 각 `apiVersion: scheduling.k8s.io/v1`: PriorityClass의 안정화된 API 버전입니다.
- 각 `kind: PriorityClass`: 클러스터 범위 우선순위 클래스를 선언합니다.
- `metadata.name: payments-critical`: 높은 우선순위 Pod가 참조할 이름입니다.
- `value: 100000`: 결제 Pod에 부여할 우선순위 값입니다.
- 첫 `globalDefault: false`: 명시적으로 참조한 Pod에만 이 값을 적용합니다.
- 첫 `description`: 클래스의 운영 목적을 설명합니다.
- `---`: 두 PriorityClass 문서를 구분합니다.
- `metadata.name: batch-low`: 낮은 우선순위 Pod가 참조할 이름입니다.
- `value: 100`: 결제 클래스보다 낮은 우선순위 값입니다.
- 두 번째 `globalDefault: false`: 기본 클래스로 지정하지 않습니다.
- 두 번째 `description`: 선점 후 다시 실행할 수 있는 배치 용도를 설명합니다.

클러스터에는 `globalDefault: true`인 사용자 PriorityClass를 최대 하나만 두는 것이 안전합니다. `system-cluster-critical`, `system-node-critical` 같은 시스템 클래스는 애플리케이션이 임의로 사용하지 않습니다.

```bash
# PriorityClass를 적용하고 값 순서와 기본 클래스 여부를 확인
kubectl apply -f priorityclasses.yaml
kubectl get priorityclass --sort-by=.value
kubectl get priorityclass payments-critical batch-low \
  -o custom-columns=NAME:.metadata.name,VALUE:.value,DEFAULT:.globalDefault
```

## 3. Pod 템플릿의 올바른 필드 위치

Deployment가 만드는 Pod에 우선순위를 적용하려면 `priorityClassName`을 `spec.template.spec`에 둡니다. Deployment 최상위 `spec.priorityClassName`은 유효한 필드가 아니며 서버 검증에서 거부됩니다.

```yaml
# 잘못된 필드 위치를 보여 주는 의도적인 부정 예시
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wrong-priority-location
  namespace: analytics
spec:
  priorityClassName: batch-low
  replicas: 1
  selector:
    matchLabels:
      app: wrong-priority-location
  template:
    metadata:
      labels:
        app: wrong-priority-location
    spec:
      containers:
      - name: pause
        image: registry.k8s.io/pause:3.9
```

- `apiVersion: apps/v1`과 `kind: Deployment`: 검증할 Deployment 객체 종류입니다.
- `metadata.name`과 `metadata.namespace`: 의도적인 오류 객체의 이름과 범위입니다.
- 잘못된 `spec.priorityClassName`: Deployment 스키마에 없는 위치이므로 서버 검증이 거부해야 합니다.
- `spec.replicas: 1`: Pod 한 개를 요청합니다.
- `spec.selector.matchLabels.app`: Deployment의 Pod Selector입니다.
- `spec.template.metadata.labels.app`: Selector와 일치하는 Pod Label입니다.
- `spec.template.spec.containers`: Pod 컨테이너 목록입니다.
- `containers[].name`과 `image`: 최소 검증용 pause 컨테이너입니다.

위 내용을 `wrong-priority-location.yaml`로 저장했다면 서버의 스키마 검증을 부정 검사로 사용할 수 있습니다.

```bash
# 잘못된 priorityClassName 위치가 서버 검증에서 거부되는지 확인
kubectl apply --dry-run=server -f wrong-priority-location.yaml
```

`unknown field "spec.priorityClassName"`과 같은 오류가 예상됩니다. 클라이언트 버전과 서버의 필드 검증 설정에 따라 문구는 달라질 수 있습니다.

## 4. 낮은 우선순위와 높은 우선순위 워크로드

실습 Node에 `payflow.io/pool=general` Label을 붙입니다. Node의 Allocatable과 이미 예약된 requests를 먼저 확인하고 아래 복제본 수와 메모리 요청량을 환경에 맞게 조정합니다.

```bash
# 선점 실습 Node와 requests 기준 여유를 확인
kubectl get nodes -L payflow.io/pool
kubectl describe node -l payflow.io/pool=general
kubectl create namespace analytics --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace payments --dry-run=client -o yaml | kubectl apply -f -
```

다음 코드에서 `---` 위쪽은 `nightly-settlement.yaml`, 아래쪽은 `payment-processor.yaml`로 각각 저장합니다.

```yaml
# 같은 Node 풀에서 자원을 경쟁하는 낮고 높은 우선순위 Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nightly-settlement
  namespace: analytics
spec:
  replicas: 4
  selector:
    matchLabels:
      app: nightly-settlement
  template:
    metadata:
      labels:
        app: nightly-settlement
    spec:
      priorityClassName: batch-low
      nodeSelector:
        payflow.io/pool: general
      terminationGracePeriodSeconds: 0
      containers:
      - name: settlement
        image: registry.k8s.io/pause:3.9
        resources:
          requests:
            cpu: "150m"
            memory: "600Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-processor
  namespace: payments
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-processor
  template:
    metadata:
      labels:
        app: payment-processor
    spec:
      priorityClassName: payments-critical
      nodeSelector:
        payflow.io/pool: general
      containers:
      - name: processor
        image: registry.k8s.io/pause:3.9
        resources:
          requests:
            cpu: "150m"
            memory: "600Mi"
```

- 각 `apiVersion: apps/v1`과 `kind: Deployment`: 두 Deployment를 선언합니다.
- 각 `metadata.name`과 `metadata.namespace`: 배치와 결제 워크로드의 이름과 범위입니다.
- 첫 `spec.replicas: 4`: 낮은 우선순위 Pod 네 개를 유지합니다.
- 두 번째 `spec.replicas: 2`: 높은 우선순위 Pod 두 개를 유지합니다.
- 각 `spec.selector.matchLabels.app`: Deployment가 관리할 Pod Label입니다.
- 각 `spec.template.metadata.labels.app`: Selector와 일치하는 Pod Label입니다.
- `priorityClassName: batch-low`: 배치 Pod에 낮은 우선순위를 부여합니다.
- `priorityClassName: payments-critical`: 결제 Pod에 높은 우선순위를 부여합니다.
- 각 `nodeSelector.payflow.io/pool: general`: 두 워크로드가 같은 Node 풀에서 경쟁하게 합니다.
- `terminationGracePeriodSeconds: 0`: 실습에서 선점된 배치 Pod가 빠르게 종료되게 합니다. 운영 종료 정책으로 그대로 사용하지 않습니다.
- 각 `containers`: Pod 컨테이너 목록입니다.
- 각 컨테이너의 `name`: 배치와 결제 프로세스를 구분합니다.
- 각 `image: registry.k8s.io/pause:3.9`: requests 경쟁만 관찰할 최소 컨테이너입니다.
- 각 `resources.requests.cpu: "150m"`: Scheduler가 예약량으로 계산할 CPU입니다.
- 각 `resources.requests.memory: "600Mi"`: Scheduler가 예약량으로 계산할 메모리입니다.
- `---`: 두 Deployment 문서를 구분합니다.

낮은 우선순위 워크로드를 먼저 적용하고 Pod가 배치된 뒤 높은 우선순위 워크로드를 추가합니다.

```bash
# 낮은 우선순위 Pod를 먼저 배치한 뒤 높은 우선순위 Pod와 이벤트를 관찰
kubectl apply -f priorityclasses.yaml
kubectl apply -f nightly-settlement.yaml
kubectl get pods -n analytics -l app=nightly-settlement -o wide
kubectl apply -f payment-processor.yaml
kubectl get pods -A -l 'app in (nightly-settlement,payment-processor)' -o wide
kubectl get events -n analytics --sort-by=.lastTimestamp
kubectl get events -n payments --sort-by=.lastTimestamp
```

조건이 맞으면 높은 우선순위 Pod가 실행되고 일부 낮은 우선순위 Pod는 삭제된 뒤 Deployment가 다시 만든 Pod가 `Pending`에 머뭅니다. 선점된 Pod가 항상 `Evicted` 문자열로 오래 남는 것은 아닙니다.

## 5. 긍정·부정 검증과 Pending 진단

Pod에 클래스 이름과 숫자가 반영됐는지 확인합니다.

```bash
# Pod의 PriorityClass 이름과 계산된 숫자 우선순위를 확인
kubectl get pods -A -l 'app in (nightly-settlement,payment-processor)' \
  -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,PC:.spec.priorityClassName,PRIORITY:.spec.priority,STATUS:.status.phase,NODE:.spec.nodeName
```

긍정 검사에서는 결제 Pod에 `payments-critical`과 `100000`, 배치 Pod에 `batch-low`와 `100`이 나타나야 합니다. 다음 부정 검사로 잘못된 위치와 존재하지 않는 이름을 구분합니다.

```bash
# 잘못된 필드 위치와 존재하지 않는 PriorityClass 참조를 부정 검사
kubectl apply --dry-run=server -f wrong-priority-location.yaml
kubectl run missing-priority --image=registry.k8s.io/pause:3.9 \
  --overrides='{"spec":{"priorityClassName":"does-not-exist"}}' \
  --dry-run=server -o yaml
```

첫 요청은 스키마 오류로, 두 번째 요청은 존재하지 않는 PriorityClass 때문에 거부되어야 합니다. 실제 오류 문구는 버전에 따라 다릅니다.

`Pending`을 진단할 때 이벤트를 원인별로 읽습니다.[[3]](#ref-3)

- `untolerated taint`: 우선순위가 아니라 Toleration 문제입니다.
- `didn't match Pod's node affinity/selector`: Label 또는 필수 Affinity 문제입니다.
- `Insufficient memory`나 `Insufficient cpu`: requests를 수용할 공간이 없습니다.
- `preemption: ... No preemption victims found`: 낮은 우선순위 Pod를 제거해도 배치할 수 없거나 적절한 희생 후보가 없습니다.
- 자원이 충분해 모두 `Running`: 실습의 requests나 복제본 수가 선점을 만들 만큼 크지 않습니다.

## 6. 정리

클러스터 범위 PriorityClass는 Namespace를 삭제해도 남습니다. 워크로드를 먼저 지운 뒤 이 글에서 만든 클래스만 삭제합니다.

```bash
# 선점 실습 워크로드와 두 PriorityClass를 정리
kubectl delete -f payment-processor.yaml -f nightly-settlement.yaml --ignore-not-found
kubectl delete -f priorityclasses.yaml --ignore-not-found
kubectl get priorityclass
```

공유 Node에 추가한 `payflow.io/pool=general` Label은 다른 실습이 사용하지 않는지 확인한 뒤 원래 값으로 복구합니다. 실습 전용 Namespace를 삭제할 때는 다른 리소스가 없는지도 확인합니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. PriorityClass는 Pod 우선순위를 이름으로 정의하고, Pod 템플릿의 `spec.priorityClassName`이 이를 참조합니다. 선점은 requests 기준 자원 부족과 적절한 낮은 우선순위 희생 후보가 모두 있을 때만 일어납니다.

이 주제는 requests·limits 설명에 의존합니다. 후속 글의 장 번호는 정하지 않았으며, 다음 주제로는 Pod 통신을 기본 허용에서 최소 허용으로 바꾸는 NetworkPolicy를 연결할 수 있습니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Pod 우선순위와 선점 공식 문서](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
- <a id="ref-2"></a>[2] [컨테이너 자원 관리 공식 문서](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- <a id="ref-3"></a>[3] [Pod 스케줄링 문제 해결 공식 문서](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
