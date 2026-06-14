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
