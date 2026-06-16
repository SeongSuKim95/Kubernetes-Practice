# RBAC: Preliminaries — RoleBindingLab 시나리오 1

RoleBindingLab **시나리오 1(RBAC RoleBinding)** 을 풀 때 필요한 개념만 정리합니다.
Taint(시나리오 2)는 `Practice/Kubernetes/9.Taints-Tolerations/`, PriorityClass(시나리오 3)는
`Practice/Kubernetes/10.PriorityClass/` 의 `Preliminaries.md` 를 함께 참고하세요.

| 파일 | 역할 |
| --- | --- |
| `app-manifests/scenario1-rbac/serviceaccounts.yaml` | `payments-oncall`(권한 O), `analytics-intern`(권한 X) SA 생성 |
| `app-manifests/scenario1-rbac/role.yaml` | `payments-pod-reader` Role (pods get/list/watch) |
| `app-manifests/scenario1-rbac/rolebinding.yaml` | `payments-oncall-reader` — oncall 에게만 바인딩 |

---

## RBAC란

**RBAC(Role-Based Access Control)** 는 API Server가 **“누가 어떤 API를 호출할 수 있는가”** 를 판단하는
**인가(Authorization)** 메커니즘입니다. **인증(Authentication, “당신이 누구인가?”)** 과는 별개이며,
RBAC는 그 다음 단계에서 **허용/거부**를 결정합니다.

```text
요청 → [인증] 너는 누구인가? → [인가(RBAC)] 이 동작이 허용되나? → 실행/거부
```

> Taint·Priority 는 **kube-scheduler** 영역(Pod를 어느 노드에 둘지)이지만,
> RBAC 은 **API Server** 영역(`kubectl get pods` 같은 호출의 허용 여부)입니다. 스케줄러와 무관합니다.

---

## 핵심 리소스 네 가지

| 리소스 | 범위 | 역할 |
|--------|------|------|
| **Role** | 네임스페이스 | 특정 네임스페이스 안에서 허용할 API 동작(verbs) 정의 |
| **ClusterRole** | 클러스터 전체 | 클러스터 범위 API 동작 정의 |
| **RoleBinding** | 네임스페이스 | Role ↔ subject(사용자·그룹·SA) 연결 |
| **ClusterRoleBinding** | 클러스터 전체 | ClusterRole ↔ subject 연결 |

한 줄 요약: **Role(권한 묶음) + RoleBinding(누구에게 줄지)**.
Role만 만들고 Binding이 없으면 **아무도 그 권한을 쓸 수 없습니다.**

이 시나리오는 `payments` 네임스페이스 한정 **Role + RoleBinding** 만 사용합니다(클러스터 범위 아님).

---

## Role — 권한 묶음

`apiGroups` + `resources` + `verbs` 조합으로 **무엇을 할 수 있는지**를 정의합니다.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: payments-pod-reader
  namespace: payments          # ← 이 네임스페이스 안에서만 유효
rules:
  - apiGroups: [""]            # "" = core API group (pods, services 등)
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]   # 읽기 전용 (create/delete 없음)
```

| 필드 | 의미 |
|------|------|
| `apiGroups: [""]` | core 그룹. pods 는 core 라 빈 문자열 |
| `resources` | 대상 리소스 종류 (pods, pods/log = 로그 서브리소스) |
| `verbs` | 허용 동작. get/list/watch 만 → **조회만 가능, 삭제 불가** |

> `verbs` 에 `delete` 가 없으므로 `kubectl delete pod` 는 권한이 있어도 거부됩니다.

---

## ServiceAccount — 주체(identity)

**ServiceAccount(SA)** 는 Pod나 외부 클라이언트가 API를 호출할 때 쓰는 **클러스터 내부 주체**입니다.
사람 사용자(`system:admin`)와 달리, 워크로드·자동화·팀별 접근을 나눌 때 SA를 subject로 둡니다.

이 시나리오는 두 “사용자”를 SA로 표현합니다.

- `payments-oncall` — 온콜 SRE (권한 **있음**)
- `analytics-intern` — 분석팀 인턴 (권한 **없음**)

SA의 Kubernetes 사용자 이름 형식:

```text
system:serviceaccount:<namespace>:<serviceaccount-name>
# 예: system:serviceaccount:payments:payments-oncall
```

---

## RoleBinding — Role을 subject에게 연결

**RoleBinding** 은 **“이 Role을 이 subject에게 부여한다”** 는 선언입니다.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: payments-oncall-reader
  namespace: payments
subjects:                       # 누구에게
  - kind: ServiceAccount
    name: payments-oncall
    namespace: payments
roleRef:                        # 어떤 Role 을
  kind: Role
  name: payments-pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```text
Role (payments-pod-reader)  verbs: get,list,watch on pods
       ↑
RoleBinding (payments-oncall-reader) ──→ payments-oncall   ✓ 권한 있음
                                       ✗ analytics-intern  (바인딩 없음 → Forbidden)
```

> 이 LAB에서 `analytics-intern` 은 **일부러 바인딩을 만들지 않았습니다.**
> 같은 Role이 있어도 Binding이 없으면 동일한 API 호출이 `Forbidden` 이 됩니다.

---

## 관측 방법 두 가지

### 방법 A — 임퍼소네이션 `--as` (빠른 점검)

**임퍼소네이션** 은 kubectl이 API Server에 **“나 대신 이 SA인 것처럼 인가 판단해 달라”** 고 요청하는 기능입니다.
admin 권한으로 접속한 뒤 **인가 판단만** 지정 SA 기준으로 수행합니다(실제 토큰 교환 없음).

```bash
# 허용: oncall → yes
kubectl auth can-i list pods -n payments \
  --as=system:serviceaccount:payments:payments-oncall

# 거부: intern → no
kubectl auth can-i list pods -n payments \
  --as=system:serviceaccount:payments:analytics-intern

# 실제 호출 비교
kubectl get pods -n payments --as=system:serviceaccount:payments:payments-oncall    # 목록 출력
kubectl get pods -n payments --as=system:serviceaccount:payments:analytics-intern   # Forbidden
```

### 방법 B — 실제 토큰 `--token` (현실 경로 재현)

`kubectl create token` 으로 SA 토큰을 발급해 **실제로 인증된** API 요청을 만듭니다.
Pod·CI·외부 도구가 API를 호출하는 방식과 동일합니다(인증 + 인가 모두 검증).

```bash
TOKEN_OK=$(kubectl create token payments-oncall -n payments)
kubectl --token="$TOKEN_OK" get pods -n payments            # OK

TOKEN_NG=$(kubectl create token analytics-intern -n payments)
kubectl --token="$TOKEN_NG" get pods -n payments            # Forbidden
```

| 방식 | 인증 | 인가 판단 기준 | 용도 |
|------|------|----------------|------|
| `--as` (임퍼소네이션) | 본인(admin) | 지정한 SA | 빠른 권한 점검 |
| `--token` (SA 토큰) | SA 자체 | SA | **실제 호출 경로** 재현 |

### 추가 관측 — 범위 제한

```bash
# oncall 도 다른 네임스페이스(kube-system)는 못 봄 (Role 은 payments 한정)
kubectl get pods -n kube-system --as=system:serviceaccount:payments:payments-oncall   # Forbidden

# oncall 도 삭제는 불가 (verbs 에 delete 없음)
kubectl auth can-i delete pods -n payments \
  --as=system:serviceaccount:payments:payments-oncall    # no
```

---

## 흔한 실수

| 증상 | 원인 |
|------|------|
| Role 만들었는데 여전히 Forbidden | **RoleBinding 이 없음** (Role만으로는 권한 없음) |
| 다른 네임스페이스에서 Forbidden | Role 은 **네임스페이스 범위** — 해당 NS 안에서만 유효 |
| `delete` 가 거부됨 | `verbs` 에 delete 미포함 (get/list/watch 만) |
| `--as` 는 yes 인데 운영 Pod 는 실패 | Pod 는 자기 SA 토큰을 씀 — Pod 의 `serviceAccountName` 확인 |
| `roleRef` 오타로 sync 실패 | `roleRef` 는 **불변** — 잘못 만들면 RoleBinding 삭제 후 재생성 |

---

## 과제(시나리오 1)와의 대응

| 단계 | 할 일 |
|------|--------|
| SA 2개 | `payments-oncall`, `analytics-intern` (serviceaccounts.yaml) |
| Role | `payments-pod-reader` — pods get/list/watch (role.yaml) |
| RoleBinding | `payments-oncall-reader` — **oncall 에게만** (rolebinding.yaml) |
| 확인 A | `kubectl auth can-i ... --as=...` → oncall yes / intern no |
| 확인 B | `kubectl create token` + `--token` → 목록 vs Forbidden |

전체 흐름:

```text
Role (get/list/watch pods)
  └─ RoleBinding ─→ payments-oncall   →  kubectl get pods -n payments  : 목록 출력
                  ✗ analytics-intern  →  kubectl get pods -n payments  : Forbidden
```

> **포인트:** 동일한 API 호출이 subject(바인딩 유무)에 따라 **목록 vs Forbidden** 으로 갈린다.
