# 3.Resource-Allocation — 풀이 보충 설명

---

## 0. 노드 자원 확인과 3 Pod·여유분 설계

문제에서 요구하는 것은 **노드 자원을 고려해** `resources`를 정하고, **여유분**을 두며, 그 결과를 **3개의 Pod**에 **공평히** 반영하는 것입니다. 숫자를 `kubectl edit`에 넣기 **전에** 다음을 하는 것이 좋습니다.

### 어떤 정보를 보나

- **`kubectl get nodes`** — 노드 목록과 Ready 여부를 빠르게 확인합니다.
- **`kubectl describe nodes`** 또는 **`kubectl describe node <이름>`** — 각 노드의 **Capacity**, **Allocatable**, 그리고 **Allocated resources**(이미 스케줄된 Pod들의 **requests** 합)를 봅니다. 스케줄러는 새 Pod를 올릴 때 **requests 합**이 노드의 남은 여유(Allocatable 대비)에 들어가는지를 봅니다.
- (선택) 클러스터에 **metrics-server**가 있으면 **`kubectl top nodes`** 로 **실제 사용량**을 참고할 수 있습니다. 다만 **요청량 설계의 1차 기준**은 여전히 매니페스트의 **requests**입니다.

### 어떻게 나누나

1. 대상 노드의 **Allocatable**(CPU·메모리)을 확인합니다.
2. 같은 노드에 이미 올라간 **다른 Pod의 requests**, 시스템 예약 등을 고려해 **쓸 수 있는 상한**을 보수적으로 잡습니다.
3. 그중 **일부는 여유분(오버헤드)** 으로 남겨 두어, 피크·시스템 부담 시 노드가 불안정해지지 않게 합니다.
4. **남은 양을 3으로 나누어** “Pod당(또는 워크로드당) 허용 범위”의 감을 잡습니다.
5. 이 실습의 Pod에는 **init 컨테이너와 메인 컨테이너**가 있고 **둘 다 같은 requests/limits** 이므로, **Pod 하나가 스케줄에 요구하는 requests**는 대략 **컨테이너 1개의 request × 2**(CPU·메모리 각각)입니다. 3개 Pod이면 그 합이 3배가 되므로, **6개 컨테이너 분의 request 합**이 노드에 맞는지 다시 확인합니다.

`SolutionNotes.bash`에 적힌 `300m` / `600Mi` 등은 **예시**이며, 실제 풀이에서는 **Step 0에서 확인한 값**에 맞게 조정해야 합니다.

---

## 1. 왜 `kubectl scale deployment wordpress --replicas 0` 을 하는가?

이 실습은 Deployment의 **Pod 템플릿(`spec.template`)** 아래에 **`resources`(requests/limits)** 를 넣어 수정하는 것이 목표입니다.

**레플리카를 0으로 줄이면** 당시 돌아가던 WordPress Pod가 종료·제거되는 쪽으로 가서, 다음을 기대할 수 있습니다.

- **편집 직후의 혼선 완화**: 이미 떠 있는 Pod와 “새 템플릿으로 만든 Pod”가 한동안 섞여 보이는 구간을 줄이기 쉽습니다.
- **노드 부담**: 리소스가 빡빡한 클러스터에서, 스펙을 고치는 동안 **실행 중인 워크로드를 잠깐 끊고** 조정하기 쉽습니다.
- **흐름 분리**: “먼저 멈추고(0) → 스펙을 고치고 → 다시 3으로 올린다”는 단계가 **강의·실습**에서 이해하기 좋습니다.

**필수는 아닙니다.** 0 없이 `kubectl edit`만 해도 Deployment는 보통 **롤링 업데이트**로 Pod를 새 템플릿으로 바꿉니다. 다만 이 문제의 풀이는 **0 → 편집 → 3** 순서를 권장하는 형태로 잡혀 있습니다.

---

## 2. `kubectl edit deployment wordpress` 로 **spec**을 바꾸면 무슨 일이 생기나?

### `spec.template`을 바꾼 경우 (이 실습의 핵심)

`spec.template`은 “앞으로 만들 Pod의 설계도”입니다. 여기에 **`resources`** 를 추가하거나 숫자를 바꾸면 **Pod의 내용**이 바뀝니다.

- Deployment 컨트롤러는 보통 **새 ReplicaSet**을 만들고, **RollingUpdate** 정책에 따라 기존 Pod를 **새 템플릿**으로 하나씩 교체합니다.
- 그 결과, **스케줄러가 보는 requests**와 **실행 시 limits**가 반영된 **새 Pod**가 올라옵니다.

### `spec.replicas`만 바꾼 경우

Pod **개수**만 맞춥니다. 템플릿이 같으면 “같은 모양의 Pod”를 늘리거나 줄이는 것에 가깝고, **새 ReplicaSet이 꼭 생기지 않을 수도** 있습니다.

---

## 3. edit으로 **spec을 실제로 바꾼 경우** vs **안 바꾼 경우**

| 상황 | 대략적인 동작 |
|------|----------------|
| **저장 시 spec 내용이 바뀌지 않음** (열람만 하거나 동일 내용) | Deployment **배포 리비전이 의미 있게 안 쌓이거나**, 롤링이 **일어나지 않을 수** 있음. Pod도 그대로인 경우가 많음. |
| **`spec.template`이 바뀜** (`resources`, 이미지, env 등) | **새 배포 리비전** + **롤링 업데이트**로 Pod **교체**가 진행됨. |
| **`spec.replicas`만 바뀜** | Pod **개수**만 조정. 템플릿이 같으면 “스케일”에 가깝고, 템플릿 교체와는 성격이 다름. |
| **`spec.selector`만 바꾸려 함** | 대부분 **API가 변경을 거절**한다. Deployment의 **`spec.selector`는 생성 후 바꿀 수 없는(immutable) 필드**로 취급되는 경우가 많아, `kubectl edit` 저장 단계에서 막히는 일이 흔하다. |

이 실습에서는 **`spec.template.spec.containers[]` / `initContainers[]`에 동일한 `resources` 블록**을 넣는 것이 목표이므로, 저장 후에는 **템플릿 변경 → 롤링**으로 이해하면 됩니다.

### `spec.selector`와 롤링 업데이트

- **롤링 업데이트**라고 흔히 부르는 동작은 주로 **`spec.template`이 바뀌어** 새 ReplicaSet이 생기고 Pod가 **교체**될 때 일어난다.
- **`spec.selector`** 는 “이 Deployment가 어떤 라벨을 가진 Pod를 관리 대상으로 삼을지”를 정하는 값이라, **`template` 교체와 같은 종류의 “새 Pod로 롤아웃”** 과는 성격이 다르다.
- **기존 Deployment에서 `spec.selector`를 바꾸는 것**은 위 표처럼 **수정 자체가 거절**되는 경우가 많아, **롤링이 일어나기 전에** 편집이 실패할 수 있다. 설령 논의만 한다면, “selector 변경 = template 변경 때와 같은 rollout”으로 이해하면 안 된다.

---

## 4. `kubectl rollout status deployment wordpress` 의 실체

- **무엇을 하는가**: `kubectl`이 Deployment(와 연관 ReplicaSet)의 상태를 **주기적으로 조회**하면서, **롤링 업데이트가 완료되었는지**(진행 중 / 성공 / 실패 등)를 **끝날 때까지 기다리는** 명령입니다.
- **왜 쓰는가**: `scale --replicas 3` 직후에는 Pod가 **아직 생성·준비 중**일 수 있고, 템플릿을 바꿨다면 **구버전 → 신버전 교체**가 진행 중일 수 있습니다. 그때 바로 검증하면 **아직 옛 설정인 Pod**가 남아 있을 수 있어, **`rollout status`로 “이번 배포가 끝났다”를 확인**한 뒤 `kubectl get pods` 등으로 검증하는 것이 안전합니다.

---

## 5. `SolutionNotes.bash`와의 대응

0. **노드 확인** (`get nodes`, `describe node(s)`, 선택적으로 `top nodes`): Allocatable·Allocated resources를 보고, 여유분을 뺀 뒤 3 Pod·init+메인 합산에 맞게 숫자를 설계.
1. **scale 0**: 워크로드를 잠깐 비우고 스펙을 고치기 쉽게 함(필수는 아님).
2. **edit**: `spec.template`에 init·메인 컨테이너 모두 동일한 `resources` 설정(설계한 값 반영).
3. **scale 3**: 다시 원하는 replica 수로 복구.
4. **rollout status**: 롤링 완료 대기.
5. **get pods**: Running/Pending 등으로 최종 확인.
