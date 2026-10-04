# 후속 초안. Taint, Toleration과 Node 선택

> 이 글은 7장에서 분리한 후속 주제 초안이며 장 번호는 아직 정하지 않았습니다. Node Label과 선택 조건, Taint와 Toleration을 조합해 전용 Node 배치를 구성합니다.

## 들어가며

Namespace와 RBAC은 리소스 범위와 API 권한을 정하지만 Pod가 어느 Node에서 실행될지는 정하지 않습니다. 이 글은 일반용 Node와 결제 전용 Node를 준비하고, 같은 Node를 선택하는 두 워크로드가 Toleration 유무에 따라 `Running`과 `Pending`으로 갈리는 과정을 확인합니다.

본문의 출력은 핵심 필드만 남긴 예시입니다. 실습 전용 Worker Node를 변경할 권한이 필요하며, 공유 Node의 기존 Label과 Taint를 기록한 뒤 이 글에서 추가한 값만 정리해야 합니다.

## 1. Node 선택과 배제의 두 방향

Taint는 Node가 받아들이지 않을 Pod를 표시하는 **배제 조건**이고, Toleration은 Pod가 해당 Taint를 허용한다는 선언입니다.[[1]](#ref-1) `nodeSelector`와 Node Affinity는 Pod가 원하는 Node Label을 지정하는 **선택 조건**입니다.[[2]](#ref-2)

Toleration만으로 특정 Node에 반드시 배치되지는 않습니다. 반대로 `nodeSelector`만 맞아도 Node의 Taint를 허용하지 못하면 배치되지 않습니다. 전용 Node에는 보통 두 조건을 함께 사용합니다.

Taint는 `key=value:effect` 형식으로 읽습니다.

- `NoSchedule`: 일치하는 Toleration이 없는 새 Pod를 배치하지 않지만 이미 실행 중인 Pod는 내보내지 않습니다.
- `PreferNoSchedule`: 가능하면 다른 Node를 선택하는 선호 조건입니다.
- `NoExecute`: 새 배치를 막고, Toleration이 없는 실행 중 Pod도 퇴출할 수 있습니다. Pod는 `tolerationSeconds`로 허용 시간을 제한할 수 있습니다.

Taint와 Toleration은 보안 인증 수단이 아닙니다. Pod 작성자가 Toleration을 추가할 권한이 있다면 전용 Node 진입을 시도할 수 있으므로 RBAC과 Pod Admission 정책도 함께 설계해야 합니다.

## 2. Node와 EKS Node 그룹 준비

### 2.1 기존 Worker Node 준비

실제 학습용 Worker Node 이름으로 변수를 설정합니다. Control Plane Taint가 있는 Node나 공유 운영 Node는 사용하지 않습니다.

```bash
# 실습 Node를 고르고 기존 Label과 Taint를 기록
kubectl get nodes -o wide
CH_TAINT_NODE=<학습용-Worker-Node-이름>
kubectl get node "$CH_TAINT_NODE" --show-labels
kubectl describe node "$CH_TAINT_NODE"
kubectl label node "$CH_TAINT_NODE" chapter-taint-target=true --overwrite
```

`chapter-taint-target=true` Label은 두 테스트 Pod의 후보를 같은 Node로 제한합니다. 이 조건이 없으면 Toleration이 없는 Pod가 Taint 없는 다른 Node에 배치되어 비교가 흐려질 수 있습니다.

### 2.2 EKS 관리형 Node 그룹 준비

EKS에서는 Node를 만든 뒤 수동으로 수정하기보다 `eksctl` Node 그룹에 Label과 Taint를 선언할 수 있습니다.[[3]](#ref-3) 다음은 전체 ClusterConfig가 아니라 기존 파일의 `managedNodeGroups`에 들어갈 부분입니다.

```yaml
# 일반용과 결제 전용 EKS 관리형 Node 그룹 설정 조각
managedNodeGroups:
- name: ng-general
  instanceType: t3.medium
  desiredCapacity: 1
  minSize: 1
  maxSize: 1
  labels:
    payflow.io/pool: general
- name: ng-payments
  instanceType: t3.medium
  desiredCapacity: 1
  minSize: 1
  maxSize: 1
  labels:
    payflow.io/pool: payments
  taints:
  - key: workload
    value: payments
    effect: NoSchedule
```

- `managedNodeGroups`: eksctl이 관리할 Node 그룹 목록입니다.
- 각 `name`: Node 이름과 별개인 Node 그룹 이름입니다.
- 각 `instanceType: t3.medium`: 그룹에서 생성할 EC2 인스턴스 유형입니다.
- 각 `desiredCapacity: 1`: 원하는 Node 수입니다.
- 각 `minSize: 1`: 자동 조정 시 최소 Node 수입니다.
- 각 `maxSize: 1`: 자동 조정 시 최대 Node 수입니다.
- 첫 그룹의 `labels.payflow.io/pool: general`: 일반 워크로드가 선택할 Node Label입니다.
- 두 번째 그룹의 `labels.payflow.io/pool: payments`: 결제 워크로드가 선택할 Node Label입니다.
- `taints`: 결제 그룹의 모든 Node에 붙일 Taint 목록입니다.
- `taints[].key: workload`: Taint 키입니다.
- `taints[].value: payments`: 결제 전용 값을 지정합니다.
- `taints[].effect: NoSchedule`: 일치하는 Toleration이 없는 새 Pod의 배치를 막습니다.

클라우드 Node 그룹 생성에는 비용이 발생합니다. 기존 클러스터에서는 Node 그룹을 새로 만들지 않고 2.1의 수동 Label·Taint 실습만 진행할 수 있습니다.

## 3. Toleration 유무 비교

선택한 Node에 Taint를 추가합니다.

```bash
# 실습 Node에 NoSchedule Taint를 추가하고 결과를 확인
kubectl taint node "$CH_TAINT_NODE" PERMISSION=granted:NoSchedule --overwrite
kubectl describe node "$CH_TAINT_NODE"
```

다음을 `taint-basic.yaml`로 저장합니다.

```yaml
# 같은 Node를 선택하되 Toleration 유무가 다른 두 Pod
apiVersion: v1
kind: Pod
metadata:
  name: nginx-tolerated
  namespace: dev
spec:
  nodeSelector:
    chapter-taint-target: "true"
  tolerations:
  - key: PERMISSION
    operator: Equal
    value: granted
    effect: NoSchedule
  containers:
  - name: nginx
    image: nginx:1.28
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-blocked
  namespace: dev
spec:
  nodeSelector:
    chapter-taint-target: "true"
  containers:
  - name: nginx
    image: nginx:1.28
```

- 각 `apiVersion: v1`: Pod가 속한 핵심 API 버전입니다.
- 각 `kind: Pod`: 두 YAML 문서가 Pod를 선언합니다.
- 각 `metadata.name`: 허용 Pod와 비교용 차단 Pod의 이름입니다.
- 각 `metadata.namespace: dev`: 두 Pod가 속할 Namespace입니다.
- 각 `spec.nodeSelector.chapter-taint-target: "true"`: 두 Pod의 후보를 같은 학습 Node로 제한합니다.
- 첫 Pod의 `spec.tolerations`: 허용할 Taint 목록입니다.
- `key: PERMISSION`: Node Taint의 키와 맞춥니다.
- `operator: Equal`: 키와 값을 모두 비교합니다. `Exists`라면 같은 키의 존재를 비교하고 `value`를 생략합니다.
- `value: granted`: Node Taint의 값과 맞춥니다.
- `effect: NoSchedule`: 허용할 Taint 효과와 맞춥니다.
- 각 `spec.containers`: Pod의 컨테이너 목록입니다.
- 각 `containers[].name: nginx`: 컨테이너 이름입니다.
- 각 `containers[].image: nginx:1.28`: 두 비교 대상이 사용할 같은 Image입니다.
- `---`: 허용 Pod와 차단 Pod 문서를 구분합니다.

```bash
# Toleration 유무에 따른 배치 결과와 Scheduler 이벤트를 확인
kubectl apply -f taint-basic.yaml
kubectl get pods -n dev -o wide
kubectl describe pod nginx-blocked -n dev
```

```text
NAME               READY   STATUS    NODE
nginx-tolerated    1/1     Running   worker-name
nginx-blocked      0/1     Pending   <none>

Warning  FailedScheduling  ... node(s) had untolerated taint {PERMISSION: granted}
```

출력은 예시입니다. 허용 Pod도 Image 다운로드, 자원 부족, 다른 필수 조건 때문에 `Pending`일 수 있습니다. `nodeName`으로 Node를 직접 지정하면 Scheduler의 일반 선택 과정을 건너뛰므로 이 실습에 사용하지 않습니다.

Toleration의 `effect`를 `NoExecute`로 잘못 쓰면 `NoSchedule` Taint와 일치하지 않습니다. Deployment에서 Toleration을 선언할 때는 Deployment 최상위 `spec`이 아니라 `spec.template.spec.tolerations`에 둬야 합니다.

## 4. 결제 전용 Node의 두 Deployment

다음 실습은 `payflow.io/pool=payments` Label이 있는 Node에 결제와 분석 Pod를 모두 유도하지만 결제 Pod에만 Toleration을 줍니다.

```bash
# 실습 Namespace와 결제용 Node Label 및 Taint를 준비
kubectl create namespace payments --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace analytics --dry-run=client -o yaml | kubectl apply -f -
kubectl label node "$CH_TAINT_NODE" payflow.io/pool=payments --overwrite
kubectl taint node "$CH_TAINT_NODE" workload=payments:NoSchedule --overwrite
kubectl get nodes -L payflow.io/pool
```

다음을 `dedicated-node-workloads.yaml`로 저장합니다.

```yaml
# 결제 전용 Node를 함께 선택하지만 Toleration이 다른 두 Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-gateway
  namespace: payments
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-gateway
  template:
    metadata:
      labels:
        app: payment-gateway
    spec:
      nodeSelector:
        payflow.io/pool: payments
      tolerations:
      - key: workload
        operator: Equal
        value: payments
        effect: NoSchedule
      containers:
      - name: gateway
        image: nginxinc/nginx-unprivileged:stable
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-batch
  namespace: analytics
spec:
  replicas: 1
  selector:
    matchLabels:
      app: analytics-batch
  template:
    metadata:
      labels:
        app: analytics-batch
    spec:
      nodeSelector:
        payflow.io/pool: payments
      containers:
      - name: batch
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo settling; sleep 10; done"]
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
```

- 각 `apiVersion: apps/v1`과 `kind: Deployment`: Deployment API 객체를 선언합니다.
- 각 `metadata.name`과 `metadata.namespace`: 워크로드 이름과 소속 Namespace를 지정합니다.
- 각 `spec.replicas: 1`: Pod 한 개를 유지합니다.
- 각 `spec.selector.matchLabels.app`: Deployment가 관리할 Pod Label입니다.
- 각 `spec.template.metadata.labels.app`: Selector와 일치하는 Pod Label입니다.
- 각 `spec.template.spec.nodeSelector`: 결제용 Label이 있는 Node만 후보로 선택합니다.
- `payment-gateway`의 `tolerations`: `workload=payments:NoSchedule` Taint를 허용합니다.
- Toleration의 `key`, `operator`, `value`, `effect`: Node Taint와 정확히 일치시킵니다.
- 각 `containers`: Pod에서 실행할 컨테이너 목록입니다.
- `gateway`의 `name`과 `image`: 비루트 nginx 컨테이너를 지정합니다.
- `batch`의 `name`, `image`, `command`: 주기적으로 메시지를 남기는 비교 컨테이너를 지정합니다.
- 각 `resources.requests`: Scheduler가 배치 가능성을 계산할 CPU와 메모리 요청량입니다.
- 각 `resources.limits`: 컨테이너가 사용할 수 있는 CPU와 메모리 한도입니다.
- `---`: 두 Deployment 문서를 구분합니다.

```bash
# 결제 Pod의 실행과 분석 Pod의 Pending 및 이벤트를 비교
kubectl apply -f dedicated-node-workloads.yaml
kubectl rollout status deployment/payment-gateway -n payments --timeout=120s
kubectl get pods -n payments -l app=payment-gateway -o wide
kubectl get pods -n analytics -l app=analytics-batch -o wide
kubectl describe pod -n analytics -l app=analytics-batch
```

결제 Pod는 Node 선택 조건과 Toleration을 모두 충족합니다. 분석 Pod는 같은 Node를 선택하지만 Toleration이 없어 `Pending`이어야 합니다. `NoSchedule` Taint를 기존 Pod 실행 후 추가했다면 기존 Pod는 유지되므로 Pod를 다시 만들어 새 배치 판단을 관찰합니다.

## 5. 진단과 정리

`Pending` Pod는 `kubectl describe pod`의 `Events`부터 확인합니다.

- `untolerated taint`: Taint와 Toleration의 키·값·효과, `operator`를 비교합니다.
- `didn't match Pod's node affinity/selector`: Node Label과 Pod 선택 조건을 비교합니다.
- `Insufficient cpu` 또는 `Insufficient memory`: 배치 조건이 아니라 requests 기준 자원 부족입니다.
- 후보 Node가 0개: Node 준비 상태와 다른 기본 Taint도 함께 확인합니다.

```bash
# 배치 조건, Node 변경과 이벤트를 한 번에 조사
kubectl get nodes -L chapter-taint-target,payflow.io/pool
kubectl get node "$CH_TAINT_NODE" -o jsonpath='{.spec.taints}{"\n"}'
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

정리할 때 Namespace를 삭제해도 Node Label과 Taint는 남습니다. 이 글에서 추가한 값만 제거합니다.

```bash
# 워크로드를 지운 뒤 실습에서 추가한 Node Taint와 Label을 정리
kubectl delete -f dedicated-node-workloads.yaml --ignore-not-found
kubectl delete -f taint-basic.yaml --ignore-not-found
kubectl taint node "$CH_TAINT_NODE" PERMISSION=granted:NoSchedule-
kubectl taint node "$CH_TAINT_NODE" workload=payments:NoSchedule-
kubectl label node "$CH_TAINT_NODE" chapter-taint-target-
kubectl label node "$CH_TAINT_NODE" payflow.io/pool-
unset CH_TAINT_NODE
```

실습 전에 같은 키가 있었다면 제거하지 말고 기록한 원래 값으로 복구합니다. 실습 전용 EKS Node 그룹을 만들었다면 eksctl 설정과 클라우드 콘솔에서 Node 그룹과 잔여 인스턴스가 정리됐는지도 확인합니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Node Label과 선택 조건은 Pod가 갈 Node를 좁히고, Taint와 Toleration은 Node가 받을 Pod를 제한합니다. 전용 Node에는 두 방향의 조건을 함께 사용하며, `Pending` 이벤트로 Label 불일치와 Taint 불일치를 구분해야 합니다.

이 주제는 Pod requests·limits를 이해한 뒤 PriorityClass와 선점으로 이어질 수 있습니다. 후속 글의 장 번호는 정하지 않았으며, 다음 주제에서는 자원이 부족할 때 우선순위가 Scheduler 판단에 미치는 영향을 다룰 수 있습니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Taint와 Toleration 공식 문서](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- <a id="ref-2"></a>[2] [Node에 Pod 할당 공식 문서](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- <a id="ref-3"></a>[3] [eksctl Node 그룹 설정 공식 문서](https://eksctl.io/usage/managing-nodegroups/)
