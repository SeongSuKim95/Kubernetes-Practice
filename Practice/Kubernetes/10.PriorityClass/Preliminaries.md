# PriorityClass: Preliminaries

`Questions.bash` / `SolutionNotes.bash` 를 풀 때 필요한 개념만 정리합니다.

| 파일 | 역할 |
| --- | --- |
| `LabSetUp.bash` | `priority` NS, `user-critical`(value 1000), `busybox-logger` Deployment |
| `Questions.bash` | `high-priority` PC 생성 + Deployment patch |
| `SolutionNotes.bash` | `kubectl create priorityclass`, deployment patch 예시 |

---

## PriorityClass란

**PriorityClass** 는 Pod에 줄 **우선순위 값(정수)** 을 이름으로 정의하는 **클러스터 범위** 리소스입니다. Pod는 `spec.priorityClassName` 으로 연결하고, value가 **클수록** 더 높은 우선순위입니다.

```text
PriorityClass (name + value)
       ↓ priorityClassName
Pod spec  →  spec.priority 필드에 value가 복사됨
```

### 예시 — 이름과 숫자

| PriorityClass name | value | 의미 |
|--------------------|-------|------|
| `batch-low` | 100 | 낮은 우선순위 |
| `user-critical` | 1000 | LabSetUp 에서 만든 user-defined PC |
| `high-priority` | 999 | 과제에서 **새로** 만들 PC (1000보다 1 작음) |
| `system-node-critical` | 2000000000 | 시스템 내장 (과제 계산 대상 아님) |

`kubectl get pc --sort-by=.value` 출력 예 (`LabSetUp.bash` 이후):

```text
NAME                   VALUE        GLOBAL-DEFAULT   AGE
batch-low              100          false            ...
high-priority          999          false            ...   ← 과제에서 생성
user-critical          1000         false            ...   ← LabSetUp
system-cluster-critical 2000000000  false            ...
system-node-critical   2000000000   false            ...
```

과제의 “highest **user-defined**” 는 `system-*` 를 빼고 보면 **`user-critical`(1000)** 입니다.

---

## PriorityClass 만들 때

| 필드 | 설명 |
|------|------|
| **metadata.name** | Pod의 `priorityClassName` 과 **동일한 문자열** |
| **value** | 필수. 정수 |
| **description** | 선택 (과제에서 요구 시 추가) |

```bash
kubectl create priorityclass high-priority --value=999 --description="high priority"
```

YAML로 만들 때:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 999
globalDefault: false
description: "high priority"
```

### 예시 — “최고 user-defined value − 1”

과제 문장: *value should be exactly one less than the highest existing user-defined priority class*

```text
1. kubectl get pc --sort-by=.value
2. system-* 제외 → user-critical value = 1000 이 최고
3. 새 high-priority value = 1000 - 1 = 999
```

value를 **1000** 으로 만들면 “1 작게” 조건에 맞지 않고, **1001** 로 만들면 “기존 user-defined 최고값보다 작게” 조건에 맞지 않습니다.

---

## Deployment에 연결

Pod **template** 의 `spec.priorityClassName` 으로 연결합니다.

### 예시 — patch 전 / 후

**patch 전** (`LabSetUp.bash` 상태) — `busybox-logger` Pod에 priority 없음:

```bash
kubectl get pod -n priority -l app=busybox-logger \
  -o custom-columns=NAME:.metadata.name,PC:.spec.priorityClassName,PRI:.spec.priority
# NAME              PC     PRI
# busybox-logger-xxx  <none>  0
```

**patch 후** (`SolutionNotes.bash`):

```bash
kubectl patch deployment busybox-logger -n priority \
  -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

롤아웃되면 **새 Pod** 에만 반영됩니다.

```bash
kubectl rollout status deployment/busybox-logger -n priority
kubectl get pod -n priority -l app=busybox-logger \
  -o custom-columns=NAME:.metadata.name,PC:.spec.priorityClassName,PRI:.spec.priority
# NAME              PC              PRI
# busybox-logger-yyy  high-priority   999
```

`describe deployment` 에도 표시됩니다.

```bash
kubectl describe deployment busybox-logger -n priority | grep -i "Priority Class"
# Priority Class Name:  high-priority
```

### 예시 — 잘못된 위치 (적용 안 됨)

Deployment **최상위** `spec` 에 넣으면 Pod template에 전달되지 않습니다.

```yaml
# ❌ 동작하지 않음
spec:
  priorityClassName: high-priority
  template:
    spec:
      containers: ...
```

```yaml
# ✅ 올바른 위치
spec:
  template:
    spec:
      priorityClassName: high-priority
      containers: ...
```

patch JSON도 **`spec.template.spec.priorityClassName`** 경로입니다.

---

## 우선순위가 쓰이는 경우 (개념)

이 과제는 PC **생성 + patch** 까지이지만, value가 왜 필요한지 이해하려면:

노드 메모리가 부족할 때 스케줄러는 **priority value가 큰 Pod** 를 먼저 배치하고, 필요하면 **value가 작은 Pod** 를 쫓아낼 수 있습니다(preemption).

```text
general 노드 (메모리 거의 가득)
  ├─ Pod A  priority=100   (batch-low)
  ├─ Pod B  priority=100
  └─ Pod C  priority=999 요청 (high-priority)  →  A 또는 B 중 하나 Evicted, C Running
```

과제 풀이 자체에는 선점까지 재현할 필요는 없고, **`priorityClassName` 과 `value` 를 올바르게 연결**하면 됩니다.

---

## 과제와의 대응

| 과제 | 할 일 |
|------|--------|
| `high-priority` 생성 | `kubectl create priorityclass high-priority --value=999 --description="high priority"` |
| value 조건 | user-defined 최고(1000) **− 1 = 999** |
| Deployment patch | `spec.template.spec.priorityClassName: high-priority` |
| 확인 | 새 Pod의 `PC=high-priority`, `PRI=999` |

전체 흐름:

```text
LabSetUp  →  user-critical (1000), busybox-logger (priority 없음)
Task 1    →  high-priority (999) 생성
Task 2    →  deployment patch → 롤아웃 → Pod priority 999
```
