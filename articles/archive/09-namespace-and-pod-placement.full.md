<!-- 16장 재편 이전의 상세 초안입니다. 본문의 장 번호와 예고는 당시 구성을 보존합니다. -->

# Chap09. Pod 배치 정책: Taint와 Toleration

> 15주 연재의 아홉째 글입니다. Taint와 Toleration, Node 선택 조건으로 Pod의 실행 위치를 정합니다. 같은 Node를 선택하는 두 Pod의 배치 결과를 비교하고, 대기하는 Pod의 원인을 확인합니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../../images/articles/02/01-k8s-logo.svg)

</div>

8장에서는 Gateway API로 외부 요청이 애플리케이션에 도달할 경로를 구성했습니다. 요청을 받을 준비가 되었다면, 그 애플리케이션을 어느 서버에서 실행할지도 생각해야 합니다. 결제 애플리케이션과 대량 분석 작업이 같은 Node의 자원을 사용하면, 분석 작업이 몰릴 때 결제 처리에 필요한 자원이 부족해질 수 있습니다.

결제용 Node를 따로 마련해도 Scheduler가 그 목적을 저절로 알 수는 없습니다. 일반 작업의 새 배치를 제한하는 조건을 Node에 표시하고, 결제 Pod에는 그 제한을 받아들이면서 결제용 Node를 선택하는 조건을 선언해야 합니다.

이번 글에서는 이 두 조건이 함께 작동하는 원리를 살펴본 뒤, 같은 Node를 선택하는 Pod 하나는 실행되고 다른 하나는 대기하도록 구성해 보겠습니다. 배치 결과와 이벤트를 비교하면 원하는 실행 위치를 어떻게 선언해야 하는지 확인할 수 있습니다.

## 1. 전용 Node와 Taint의 배치 제한

결제 Pod와 분석 Pod를 함께 운영하더라도, 결제용 Node에는 결제 Pod만 배치하고 싶습니다. 이때 Node에 배치 제한을 표시하는 것이 **Taint**입니다.

### 1.1 Node의 제한 조건과 Pod의 Toleration

Taint는 Node에 선언하고, 그 제한을 받아들일 조건인 **Toleration**은 Pod에 선언합니다. Scheduler는 Node를 선택할 때 두 조건을 비교합니다. [[1]](#ref-1)

예를 들어 결제용 `node01`에 다음 Taint를 추가할 수 있습니다.

```bash
kubectl taint nodes node01 dedicated=payments:NoSchedule
```

명령의 응답 예시는 다음과 같습니다.

```text
node/node01 tainted
```

`dedicated=payments`는 제한 조건을 식별하는 키와 값이고, `NoSchedule`은 일치하는 Toleration이 없는 새 Pod를 이 Node에 배치하지 않도록 하는 효과입니다. 일반용 `node02`에 다른 제약이 없다면, Toleration 없는 Pod는 그쪽에 배치될 수 있습니다.

결제 Pod가 `node01`을 후보로 사용할 수 있게 하려면 다음과 같이 선언합니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: payment
  namespace: default
spec:
  containers:
  - name: web
    image: nginx:1.28
  tolerations:
  - key: dedicated
    operator: Equal
    value: payments
    effect: NoSchedule
```

- `tolerations`: Node의 `dedicated=payments:NoSchedule` 조건을 받아들이도록 합니다. `Equal`은 키와 효과뿐 아니라 값도 비교합니다.

이 Pod는 Taint로 인한 제한을 통과하므로 `node01`을 배치 후보로 사용할 수 있습니다. 다른 조건이 맞으면 일반용 `node02`도 후보가 됩니다. **특정 Node에 배치하려면, 허용 조건에 더해 선택 조건이 필요합니다.**

### 1.2 Taint 효과에 따른 배치와 퇴거

앞의 `NoSchedule`은 새 배치를 제한합니다. 이미 실행 중인 Pod에도 영향을 줄지에 따라 다른 효과를 선택할 수 있습니다. [[1]](#ref-1)

| 효과 | 일치하는 Toleration이 없는 Pod에 대한 동작 |
|---|---|
| `NoSchedule` | 새로 배치하지 않으며, 이미 실행 중인 Pod는 유지 |
| `PreferNoSchedule` | 가능한 다른 Node를 우선하되 필요하면 배치 가능 |
| `NoExecute` | 새 배치를 막고, 이미 실행 중인 Pod도 퇴거 대상에 포함 |

`NoExecute`에 맞는 Toleration에는 `tolerationSeconds`로 실행을 유지할 시간을 정할 수도 있습니다. 반면 지금의 결제용 Node 예시는 실행 중인 Pod를 내보내는 것이 아니라 앞으로 들어올 Pod를 구분하려는 목적이므로 `NoSchedule`을 사용합니다.

제한을 통과할 수 있게 되었다면, 다음은 결제 Pod의 목적지를 결제용 Node로 좁힐 차례입니다.

## 2. Node 선택 조건과 Toleration의 조합

Node에 Label을 붙이고 Pod의 `nodeSelector`로 그 Label을 선택하면 실행할 Node의 조건을 정할 수 있습니다. Toleration이 Node의 제한을 통과하는 조건이라면, `nodeSelector`는 Pod가 사용할 Node를 고르는 조건입니다. [[2]](#ref-2)

### 2.1 Node Label과 Deployment의 배치 선언

앞의 `node01`에 결제용임을 구분할 Label을 추가합니다. 이 예시에서는 `node01`만 해당 Label을 갖습니다.

```bash
kubectl label node node01 workload=payments
```

응답 예시는 다음과 같습니다.

```text
node/node01 labeled
```

Deployment가 만드는 모든 결제 Pod에 같은 배치 조건을 적용하려면 Pod 템플릿에 선언합니다.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment
  template:
    metadata:
      labels:
        app: payment
    spec:
      nodeSelector:
        workload: payments
      tolerations:
      - key: dedicated
        operator: Equal
        value: payments
        effect: NoSchedule
      containers:
      - name: web
        image: nginx:1.28
```

- `template.spec.nodeSelector`: `workload=payments` Label을 가진 Node로 후보를 제한합니다.
- `template.spec.tolerations`: 해당 Node의 Taint를 받아들이도록 합니다. 교체되어 생성되는 Pod에도 이 조건이 적용됩니다.

Deployment의 `selector.matchLabels`는 **관리할 Pod**를 선택하고, Pod 템플릿의 `nodeSelector`는 **실행할 Node**를 선택합니다. 이름이 비슷하지만 선택하는 대상이 다릅니다.

### 2.2 Scheduler의 후보 선택과 Pod 실행

Deployment와 ReplicaSet이 새 Pod를 API에 등록하면 Scheduler는 Node Label, Taint와 Toleration, 필요한 자원 등의 조건을 확인합니다. 모든 필수 조건을 만족하는 후보에서 Node를 선택해 API Server에 배정 결과를 기록하고, 해당 Node의 Kubelet이 컨테이너 런타임을 통해 Pod를 실행합니다. [[2]](#ref-2)

현재 예시는 다음과 같이 비교할 수 있습니다. 두 Node 모두 자원이 충분하고, 표에 적힌 조건 외에는 배치 제한이 없다고 가정합니다.

| Pod의 조건 | node01: 결제 Label과 Taint | node02: 일반용 | 결과 |
|---|---|---|---|
| 선택 조건 없음, Toleration 없음 | Taint로 제외 | 후보 | node02에 배치 가능 |
| 선택 조건 없음, Toleration 있음 | 후보 | 후보 | 두 Node 중 선택 가능 |
| 결제 nodeSelector만 있음 | Taint로 제외 | Label 불일치 | Pending |
| 결제 nodeSelector와 Toleration 있음 | 후보 | Label 불일치 | node01에 배치 가능 |

따라서 Toleration 없는 Pod가 항상 `Pending`이 되는 것은 아닙니다. **모든 Node가 조건에서 제외될 때** Scheduler가 실행 위치를 정하지 못합니다. 제공된 Taint 실습에서도 특정 Node에서 허용과 거부를 비교하려면 이러한 후보 조건을 함께 맞춰야 합니다.

5장에서 살펴본 자원 부족과 마찬가지로, 배치 정책도 `Pending`의 원인이 될 수 있습니다. 여러 조건을 만족해야 하므로 Toleration을 추가한 뒤에도 다른 필수 조건이 맞는지 확인해야 합니다.

## 3. 문제 설명: 전용 Node의 Pod 배치 제한

앞에서 배운 두 조건을 직접 조합해 보겠습니다. [Taint 실습 문제](../../Practice/Kubernetes/9.Taints-Tolerations/Questions.bash)는 `node01`에 제한을 걸고, 이를 받아들이는 Pod를 배치하는 과제입니다. 여기에 같은 Node를 선택하지만 Toleration이 없는 Pod를 함께 만들어, 배치 결과가 달라지는 이유까지 확인합니다.

### 3.1 실습 환경과 요구사항

실습용 Worker Node `node01`이 `Ready` 상태이고, nginx Pod 두 개를 실행할 자원이 충분하다고 가정합니다. 다른 필수 배치 제한은 없으며, Pod는 `default`에 생성합니다. Node 이름이 다르면 아래 명령의 `node01`을 해당 실습 Node 이름으로 바꿉니다.

- `node01`에 `PERMISSION=granted:NoSchedule` Taint를 추가합니다.
- Pod `nginx-allowed`에는 일치하는 Toleration과 Node 선택 조건을 선언해 `node01`에서 실행합니다.
- Pod `nginx-blocked`에는 같은 Node 선택 조건만 선언해 `Pending` 상태와 배정 실패 이유를 확인합니다.
- 이 실습에서 추가한 Taint를 제거했을 때 대기하던 Pod가 배정되는지 확인합니다.

여기서 `PERMISSION`은 원본 문제의 Taint 키 이름입니다. 이 값으로 비교하는 것은 Node 배치 조건이며, Kubernetes API를 사용할 권한은 별도의 접근 제어로 관리합니다.

### 3.2 비교할 결과와 후보 조건

두 Pod가 동일한 Node를 선택하게 해야 Toleration의 차이를 관찰할 수 있습니다. [원본 해설](../../Practice/Kubernetes/9.Taints-Tolerations/SolutionNotes.bash)의 Pod에는 Node 선택 조건이 없어, 다른 Node가 사용 가능하면 Toleration 없는 Pod도 그곳에서 실행될 수 있습니다. 이번 해설에서는 실습용 Label을 `node01`에만 붙이고 두 Pod가 이를 선택하도록 합니다.

완료 조건은 허용 Pod의 `Running` 상태와 `NODE=node01`, 제한 Pod의 `Pending` 상태와 Taint 관련 이벤트입니다. Taint를 제거한 뒤에는 제한 Pod도 `node01`에 배정되어야 합니다. 이제 Node의 조건부터 준비하겠습니다.

## 4. 해설과 코드: 배치 허용과 거부의 비교

먼저 Node에 선택용 Label과 Taint를 설정하고, 그 뒤에 두 Pod를 생성합니다. 이 순서를 따르면 이미 실행 중인 Pod에 대한 영향과 새 Pod의 배치 제한을 혼동하지 않고 비교할 수 있습니다. 아래 출력은 설명용 예시입니다.

### 4.1 Node 조건의 확인과 설정

학습용 Node의 상태와 기존 Taint를 확인합니다. 다음 작업은 실습에서 사용할 Node 한 대에만 적용합니다.

```bash
kubectl get node node01
kubectl describe node node01
```

```text
NAME     STATUS   ROLES    AGE   VERSION
node01   Ready    <none>   10d   v1.34.0
```

- `STATUS: Ready`: 정상 상태가 보고된 Node입니다. `describe`의 `Taints`와 자원 요청량도 함께 확인해 추가 제한이나 자원 부족이 없는지 살펴봅니다.

다음 Label은 실습 대상 Node를 고르는 표식이고, Taint는 Toleration 없는 Pod의 새 배치를 막는 조건입니다. 같은 Label이 다른 Node에 없는 실습 환경에서 실행합니다.

```bash
kubectl label node node01 scheduling-lab=taint-demo
kubectl taint node node01 PERMISSION=granted:NoSchedule
```

```text
node/node01 labeled
node/node01 tainted
```

이제 Scheduler가 `node01`을 후보로 검토할 때 `PERMISSION=granted:NoSchedule`을 받아들이는지 확인합니다. Pod 쪽에 대응하는 조건을 작성하겠습니다.

### 4.2 같은 Node를 선택하는 두 Pod

다음 내용을 `taint-pods.yaml`로 저장합니다. 두 Pod는 같은 이미지를 사용하고 같은 Node Label을 선택하지만, `nginx-allowed`에만 Toleration이 있습니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-allowed
  namespace: default
spec:
  nodeSelector:
    scheduling-lab: taint-demo
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
  namespace: default
spec:
  nodeSelector:
    scheduling-lab: taint-demo
  containers:
  - name: nginx
    image: nginx:1.28
```

- `nodeSelector`: 두 Pod의 실행 후보를 실습 Label이 있는 `node01`로 제한합니다.
- `tolerations`: `nginx-allowed`만 Node의 키·값·효과와 일치하는 조건을 갖습니다. `Equal`을 사용하므로 `value: granted`까지 일치해야 합니다.

파일을 적용하고 두 Pod의 실행 위치를 비교합니다.

```bash
kubectl apply -f taint-pods.yaml
kubectl get pods nginx-allowed nginx-blocked -n default -o wide
```

```text
NAME            READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE   READINESS GATES
nginx-allowed   1/1     Running   0          30s   10.244.1.5   node01   <none>           <none>
nginx-blocked   0/1     Pending   0          30s   <none>       <none>   <none>           <none>
```

- `STATUS`와 `NODE`: `nginx-allowed`는 `node01`에서 실행되고, `nginx-blocked`는 아직 실행할 Node를 배정받지 못했습니다.

Scheduler는 허용 Pod의 Toleration을 확인해 배정 결과를 기록합니다. 이후 `node01`의 Kubelet이 컨테이너 실행을 진행합니다. 제한 Pod는 같은 Node를 선택했지만 Taint 조건을 통과하지 못했으므로 대기합니다.

### 4.3 Pending의 원인과 Taint 제거 후의 변화

대기 중인 Pod의 이벤트를 조회해 배정이 막힌 이유를 확인합니다.

```bash
kubectl describe pod nginx-blocked -n default
```

실습용 Node 두 대 중 `node01`만 Label이 일치하는 환경에서 볼 수 있는 이벤트의 핵심 문구는 다음과 같습니다. Node 수와 추가 조건에 따라 실제 메시지는 달라집니다.

```text
Warning  FailedScheduling  10s  default-scheduler  0/2 nodes are available: 1 node(s) had untolerated taint {PERMISSION: granted}, 1 node(s) didn't match Pod's node affinity/selector.
```

- `untolerated taint`: `node01`의 Taint를 받아들이는 Toleration이 없습니다.
- `didn't match Pod's node affinity/selector`: 다른 Node는 Pod가 요구한 Label과 일치하지 않습니다.

따라서 두 Node 모두 후보에서 제외됩니다. 이 실습에서 추가한 Taint를 제거하면 `node01`이 후보가 되는지 확인할 수 있습니다.

```bash
kubectl taint node node01 PERMISSION=granted:NoSchedule-
kubectl wait --for=condition=Ready pod/nginx-blocked -n default --timeout=120s
kubectl get pods nginx-allowed nginx-blocked -n default -o wide
```

```text
NAME            READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE   READINESS GATES
nginx-allowed   1/1     Running   0          3m    10.244.1.5   node01   <none>           <none>
nginx-blocked   1/1     Running   0          3m    10.244.1.6   node01   <none>           <none>
```

제한 조건이 사라지면 Scheduler가 대기하던 Pod를 다시 검토해 배정하고, Kubelet이 컨테이너를 실행합니다. 이때 `NoSchedule` Taint를 다시 추가해도 이미 실행 중인 두 Pod는 유지됩니다. 다시 배치 차이를 관찰하려면 Taint를 먼저 추가하고 테스트 Pod를 새로 생성해야 합니다. [[1]](#ref-1)

### 4.4 결제용 Node 그룹에 적용하는 같은 원리

[AWS 실습의 결제 애플리케이션](../../AWS/RoleBindingLab/app-manifests/scenario2-taint/payment-gateway.yaml)과 [분석 작업](../../AWS/RoleBindingLab/app-manifests/scenario2-taint/analytics-batch.yaml)도 같은 원리로 비교합니다. 이 환경에서는 Node 그룹에 `payflow.io/pool=payments` Label을 붙여 두고, `workload=payments:NoSchedule` Taint를 사용합니다.

| 애플리케이션 | 선택하는 Node Label | Toleration | 새 Pod의 예상 결과 |
|---|---|---|---|
| payment-gateway | payflow.io/pool=payments | workload=payments:NoSchedule | 조건과 자원이 맞으면 실행 |
| analytics-batch | payflow.io/pool=payments | 없음 | 해당 Node에 Taint가 있으면 Pending |

결제 Deployment의 Pod 템플릿에서 핵심이 되는 부분은 다음과 같습니다.

```yaml
spec:
  template:
    spec:
      nodeSelector:
        payflow.io/pool: payments
      tolerations:
      - key: workload
        operator: Equal
        value: payments
        effect: NoSchedule
```

`nodeSelector`는 결제용 Node 그룹을 선택하고, `tolerations`는 그 그룹의 배치 제한을 통과하게 합니다. 분석 작업은 동일한 그룹을 선택하지만 Toleration이 없어 새 배치가 제한됩니다. 원본 환경에서 이미 실행 중인 분석 Pod가 있다면 Taint 추가만으로 `Pending`으로 바뀌지 않으므로, 새로 생성되는 Pod의 결과를 비교해야 합니다.

기본 문제의 단일 Node가 여러 Node로 늘어나도 조건을 비교하는 방식은 같습니다. Deployment 템플릿에 조건을 두면 이후 교체되는 Pod에도 같은 배치 정책이 적용됩니다.

### 4.5 실습 리소스 정리

기본 문제에서 만든 두 Pod를 삭제한 뒤, 이번에 추가한 Node Label을 제거합니다. Taint는 앞 절에서 제거한 상태입니다.

```bash
kubectl delete -f taint-pods.yaml
kubectl label node node01 scheduling-lab-
```

실습에서는 같은 Node를 선택한 Pod라도 Toleration에 따라 결과가 달라지는 것을 확인했습니다. 이 원리를 운영 환경에 적용하면 일반 작업의 진입을 제한하면서 특정 애플리케이션의 실행 후보를 전용 Node로 좁힐 수 있습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Taint는 Node에 배치 제한을 표시하고, Toleration은 Pod가 그 제한을 받아들이는 조건을 선언합니다. 여기에 Node 선택 조건을 함께 사용하면 애플리케이션의 실행 후보를 전용 Node로 좁힐 수 있습니다.

실습에서는 같은 Node를 선택하는 두 Pod의 실행 결과를 비교하고, Taint 때문에 배정되지 못한 Pod가 제한 해제 후 실행되는 과정까지 확인했습니다. 실행 위치를 나눈 뒤에는 애플리케이션 사이에서 어떤 통신을 허용할지도 정해야 합니다. 다음 글에서는 필요한 요청만 주고받도록 통신 범위를 제한하는 방법을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: Taint와 Toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: Pod의 Node 배치](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
