# Taints & Tolerations: Preliminaries

`Questions.bash` / `SolutionNotes.bash` 를 풀 때 필요한 개념만 정리합니다.

| 파일 | 역할 |
| --- | --- |
| `Questions.bash` | node01 taint + toleration Pod 배포 |
| `SolutionNotes.bash` | `kubectl taint`, Pod YAML 예시 |
| `nodegroup-examples.yaml` | EKS eksctl 노드그룹 — label·taint 선언 예시 |

---

## 이 Lab이 다루는 범위 — 스케줄링 3종

Kubernetes에서 **Pod가 어느 노드에 배치되는가**를 제어하는 개념은 세 가지이며, 모두
**kube-scheduler** 영역입니다. 

```text
         Node 쪽                         Pod 쪽
         ───────                         ──────
Taint        "아무나 오지 마"     ←──→   Toleration   "나는 들어갈 자격 있어"
Node Label   (예: disk=ssd)       ←───   Node Affinity "나는 저 Label 노드로 가고 싶어"
```

| | Taint / Toleration | Node Affinity / nodeSelector |
|--|--------------------|------------------------------|
| **누가 조건을 거는가** | Node(taint) + Pod(toleration) | **Pod** (affinity) |
| **방향** | "이 노드엔 못 온다" — **밀어냄** | "이 Label 노드로 가고 싶다" — **끌어당김** |
| **toleration만 있으면** | taint 노드에 **갈 수는** 있음 (강제 아님) | — |
| **affinity만 있으면** | — | 조건 노드로 **가려고** 함 (taint는 별개로 막을 수 있음) |

> 핵심: **Taint/Toleration은 "받아줄지"**, **Node Affinity는 "선택"** 입니다.
> 전용 노드를 **강제**하려면 보통 둘을 **함께** 씁니다(아래 "조합" 섹션).

---

## Taint와 Toleration

**Taint** 는 **Node** 에 붙는 표시이고, **Toleration** 은 **Pod** `spec` 에 선언합니다. 스케줄러가 노드를 고를 때, Pod에 맞는 toleration이 없으면 taint가 붙은 노드에는 배치하지 않습니다.

```text
taint (Node)     →  “대부분의 Pod는 이 노드에 올 수 없다”
toleration (Pod) →  “이 taint는 받아들일 수 있다”
```

### 예시 — taint 전후

클러스터에 `node01`, `node02` 가 있고, **아직 taint가 없을 때**:

```bash
kubectl run app --image=nginx
kubectl get pods -o wide
# app → node01 또는 node02 아무 데나 Running (스케줄러가 골라 배치)
```

`node01` 에 taint를 걸면:

```bash
kubectl taint nodes node01 PERMISSION=granted:NoSchedule
```

이후 toleration **없는** Pod는 `node01` 후보에서 빠집니다.

```bash
kubectl run blocked --image=nginx
kubectl get pods blocked -o wide
# STATUS=Pending, NODE=<none>

kubectl describe pod blocked
# Events:
#   Warning  FailedScheduling  ... node01 had untolerated taint {PERMISSION: granted}
```

toleration **있는** Pod만 `node01` 에 올 수 있습니다 (`SolutionNotes.bash` 의 `nginx`).

---

## Taint 형식

```text
key=value:Effect
```

과제 예: `PERMISSION=granted:NoSchedule`

| taint (Node) | toleration (Pod) — 짝이 맞아야 함 |
|--------------|-----------------------------------|
| key: `PERMISSION` | key: `PERMISSION` |
| value: `granted` | value: `granted` (`operator: Equal` 일 때) |
| effect: `NoSchedule` | effect: `NoSchedule` |

| Effect | 의미 (과제 관련) |
|--------|------------------|
| **NoSchedule** | toleration 없는 Pod는 **스케줄 불가** (이미 Running 중인 Pod는 그대로) |
| PreferNoSchedule | 가능하면 배치하지 않음 |
| NoExecute | 스케줄 불가 + toleration 없으면 **실행 중 Pod도 퇴출** 가능 |

과제 문구 “no normal pods can be scheduled” → **`NoSchedule`**.

### 예시 — Effect가 다르면 매칭 실패

Node taint:

```text
PERMISSION=granted:NoSchedule
```

Pod toleration에서 effect만 `NoExecute` 로 적으면 **짝이 안 맞아** Pending입니다.

```yaml
tolerations:
  - key: PERMISSION
    operator: Equal
    value: granted
    effect: NoExecute    # ← NoSchedule 이어야 함
```

### 노드에 taint 걸기

```bash
kubectl taint nodes node01 PERMISSION=granted:NoSchedule
```

제거할 때는 끝에 `-` (추가할 때와 key·value·effect 동일):

```bash
kubectl taint nodes node01 PERMISSION=granted:NoSchedule-
```

확인:

```bash
kubectl describe node node01 | grep -i Taint
# Taints: PERMISSION=granted:NoSchedule
```

---

## 노드그룹 매니페스트 (EKS / eksctl)

이 과제(KillerCoda 등)는 **이미 떠 있는 노드 `node01`** 에 `kubectl taint` 로 taint 를 겁니다.
실무·EKS 에서는 **노드그룹(node group)** 단위로 label·taint 를 **생성 시점에 선언**하는 경우가 많습니다.
노드그룹에 속한 모든 노드가 동일한 label·taint 를 자동으로 받습니다.

```text
kubectl taint (Lab)     →  기존 노드 1대에 수동으로 taint 부착
노드그룹 manifest (EKS) →  새 노드가 뜰 때마다 label·taint 가 자동 부착
```

### eksctl ClusterConfig — 노드그룹 2개 예시

`nodegroup-examples.yaml` 전체 내용입니다. 일반 풀과 결제 전용 풀을 나눕니다.

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: payflow-lab
  region: ap-northeast-2
  version: "1.33"

managedNodeGroups:
  # 일반 워크로드 — label 만, taint 없음
  - name: ng-general
    instanceType: t3.medium
    desiredCapacity: 1
    minSize: 1
    maxSize: 1
    labels:
      payflow.io/pool: general

  # 결제 전용 — label + taint (노드 생성 시 자동 적용)
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

| 필드 | 역할 |
|------|------|
| `labels` | 노드에 붙는 Label → Pod의 `nodeSelector` / `nodeAffinity` 가 참조 |
| `taints` | 노드에 붙는 Taint → Pod에 맞는 `tolerations` 가 없으면 스케줄 불가 |
| `name` | 노드그룹 이름 (노드 이름과는 별개) |

노드그룹으로 taint 를 선언하면, RoleBindingLab 시나리오 2에서 수동으로 실행하던 아래와 **동일한 효과**가 납니다.

```bash
# 수동 (Lab 학습용) — 라벨 셀렉터로 payments 풀 전체에 taint
kubectl taint nodes -l payflow.io/pool=payments \
  workload=payments:NoSchedule --overwrite
```

### 노드그룹 taint 와 짝이 맞는 Pod

`ng-payments` 노드그룹의 taint `workload=payments:NoSchedule` 에 맞춘 Pod 예시입니다.

**toleration 있음 → Running**

```yaml
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
          image: nginx
```

**nodeSelector 는 같지만 toleration 없음 → Pending**

```yaml
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
      # tolerations 없음 → ng-payments taint 에 막힘
      containers:
        - name: batch
          image: busybox
```

```text
ng-payments 노드그룹 (label + taint 자동 부착)
  ├─ payment-gateway   nodeSelector ✓ + toleration ✓ → Running
  └─ analytics-batch   nodeSelector ✓ + toleration ✗ → Pending
```

### Lab 과제(node01) vs 노드그룹 — 대응표

| | 이 Lab (`Questions.bash`) | EKS 노드그룹 (`nodegroup-examples.yaml`) |
|--|---------------------------|------------------------------------------|
| taint 대상 | `node01` (노드 이름) | `ng-payments` 그룹의 모든 노드 |
| taint 선언 | `kubectl taint nodes node01 ...` | `managedNodeGroups[].taints` |
| taint 값 | `PERMISSION=granted:NoSchedule` | `workload=payments:NoSchedule` |
| Pod toleration | `key: PERMISSION, value: granted` | `key: workload, value: payments` |

> 키·값 문자열은 환경마다 다를 수 있습니다. **노드 taint 와 Pod toleration 의 key·value·effect 가 짝이 맞는지**가 핵심입니다.

---

## Toleration (Pod spec)

`operator: Equal` (기본값) — key, value, effect **세 가지 모두** taint와 같아야 합니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
    - name: nginx
      image: nginx
  tolerations:
    - key: PERMISSION
      operator: Equal
      value: granted
      effect: NoSchedule
```

적용 후:

```bash
kubectl apply -f pod.yaml
kubectl get pod nginx -o wide
# NAME    READY   STATUS    RESTARTS   AGE   IP          NODE
# nginx   1/1     Running   0          10s   10.244.1.5  node01
```

### 예시 — SolutionNotes.bash 부정 테스트

toleration **없는** Pod (`nginx-fail`)는 같은 클러스터에서 Pending:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-fail
spec:
  containers:
    - name: nginx
      image: nginx
  # tolerations 없음
```

```bash
kubectl describe pod nginx-fail
# Events:
#   Warning  FailedScheduling  0/2 nodes are available: 1 node(s) had untolerated taint {PERMISSION: granted}, ...
```

→ **`nginx`** 와 **`nginx-fail`** 은 이미지·컨테이너는 같지만, toleration 유무로 Running vs Pending 이 갈립니다.

### Deployment를 쓰는 경우

과제가 Deployment라면 toleration 위치가 **`spec.template.spec`** 입니다.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      tolerations:          # ← Pod template 안
        - key: PERMISSION
          operator: Equal
          value: granted
          effect: NoSchedule
      containers:
        - name: app
          image: nginx
```

`metadata` 나 Deployment 최상위 `spec` 에 넣으면 **적용되지 않습니다**.

---

## nodeSelector vs taint/toleration (RoleBindingLab 연계)

두 메커니즘은 **방향이 반대**입니다.

| | nodeSelector / nodeAffinity | taint / toleration |
|--|------------------------------|--------------------|
| 누가 거는가 | **Pod** 가 지정 | **Node** 에 taint, **Pod** 에 toleration |
| 방향 | “이 라벨 노드로 **가고 싶다**” (끌어당김) | “이 노드에는 **못 온다**” (밀어냄) |
| toleration 없는 Pod | (무관) | taint 걸린 노드에 **스케줄 불가** |

```yaml
spec:
  nodeSelector:                 # 이 라벨 노드로 가고 싶다 (끌어당김)
    payflow.io/pool: payments
  tolerations:                  # 그 노드의 taint 도 견딜 수 있다 (밀어냄 면역)
    - key: workload
      operator: Equal
      value: payments
      effect: NoSchedule
```

RoleBindingLab 시나리오 2는 **두 Pod 모두 같은 노드(`nodeSelector: payments`)를 노리되, toleration 만 다릅니다.**

```text
payments 노드 + taint(workload=payments:NoSchedule)
  ├─ payment-gateway   nodeSelector ✓ + toleration ✓ → Running
  └─ analytics-batch   nodeSelector ✓ + toleration ✗ → Pending (FailedScheduling)
```

> nodeSelector 로 **같은 노드를 노리는데도** toleration 유무 하나로 Running vs Pending 이 갈리는 것이 핵심입니다.

---

## 과제와의 대응

| 과제 | 할 일 |
|------|--------|
| node01에 taint | `kubectl taint nodes node01 PERMISSION=granted:NoSchedule` |
| Pod 스케줄 | `spec.tolerations` 에 key/value/effect를 taint와 동일하게 |
| 확인 | `kubectl get pods -o wide` → `nginx` Running, NODE=node01 |

한 줄 요약:

```text
node01: PERMISSION=granted:NoSchedule  (taint)
nginx:  toleration { PERMISSION, granted, NoSchedule }  →  node01 Running
nginx-fail: toleration 없음  →  Pending
```
