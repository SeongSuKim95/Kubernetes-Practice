# Taints & Tolerations: Preliminaries

`Questions.bash` / `SolutionNotes.bash` 를 풀 때 필요한 개념만 정리합니다.

| 파일 | 역할 |
| --- | --- |
| `Questions.bash` | node01 taint + toleration Pod 배포 |
| `SolutionNotes.bash` | `kubectl taint`, Pod YAML 예시 |

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

### 예시 — 라벨로 여러 노드에 한 번에 taint (RoleBindingLab 연계)

노드 이름(`node01`) 대신 **라벨 셀렉터(`-l`)** 로 같은 그룹의 노드 여러 대에 한 번에 걸 수 있습니다.
RoleBindingLab 시나리오 2는 `payflow.io/pool=payments` 라벨이 붙은 노드그룹에 taint를 겁니다.

```bash
# 라벨이 payflow.io/pool=payments 인 노드 전부에 taint
kubectl taint nodes -l payflow.io/pool=payments \
  workload=payments:NoSchedule --overwrite

# 풀기 (끝에 -)
kubectl taint nodes -l payflow.io/pool=payments \
  workload=payments:NoSchedule-
```

| 옵션 | 의미 |
|------|------|
| `-l <label>=<value>` | 노드 이름 대신 **라벨로 대상 노드 선택** (여러 대 동시) |
| `--overwrite` | 이미 같은 key 의 taint 가 있으면 **값/effect 덮어쓰기** (재실행해도 에러 안 남) |

> **NoSchedule 은 새 Pod 만 막습니다.** taint 를 거는 시점에 **이미 Running 중인 Pod 는 그대로 유지**됩니다.
> (실행 중 Pod 까지 퇴출하려면 `NoExecute` 가 필요합니다.)

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

두 메커니즘은 **방향이 반대**입니다. RoleBindingLab 시나리오 2를 이해하려면 둘의 차이를 알아야 합니다.

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
