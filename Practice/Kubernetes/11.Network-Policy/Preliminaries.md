# Network Policy: Preliminaries

`Questions.bash` / `SolutionNotes.bash` 를 풀 때 필요한 개념을 정리합니다.
이 문서는 **(1) Kubernetes 네트워크 기본 → (2) CNI 참조(12번) → (3) NetworkPolicy 개념·문법 → (4) 이 Lab 풀이** 순서로 읽으면 됩니다.


| 파일                   | 역할                                                                    |
| -------------------- | --------------------------------------------------------------------- |
| `LabSetUp.bash`      | `frontend` / `backend` NS, Deployment·Service, 후보 NetworkPolicy 3개 생성 |
| `Questions.bash`     | `/root/network-policies` 중 **최소 권한** 정책 선택·배포                         |
| `SolutionNotes.bash` | policy-1/2/3 비교, 정답은 `network-policy-3.yaml`                          |


> **CNI** 개념(역할, 동작, NetworkPolicy 집행)은 **[12.CNI&NetworkPolicy/Preliminaries.md](../12.CNI&NetworkPolicy/Preliminaries.md)** 를 참고하세요. 12번은 **집행(How)**, 이 Lab은 **선언·선택(What)** 에 집중합니다.

---

## 1. Kubernetes 네트워크 기본 구조

### 1.1 Kubernetes가 해결해야 하는 네트워킹 4문제

컨테이너 오케스트레이션에서 네트워크는 4가지 문제로 나뉩니다. **CNI는 이 중 2번(Pod ↔ Pod)** 을 책임집니다.


| #   | 문제                       | 누가 해결                             |
| --- | ------------------------ | --------------------------------- |
| 1   | **컨테이너 ↔ 컨테이너** (같은 Pod) | `localhost` (Pod 내 netns 공유)      |
| 2   | **Pod ↔ Pod** (같은/다른 노드) | **CNI**                           |
| 3   | **Pod ↔ Service**        | kube-proxy (+ CoreDNS)            |
| 4   | **외부 ↔ Service**         | LoadBalancer / Ingress / NodePort |


### 1.2 Kubernetes 네트워크 모델 (4대 규칙)

Kubernetes는 구현을 강제하지 않고 **규칙만** 정합니다. CNI가 이 규칙을 만족시키면 됩니다.


| #   | 규칙                                    |
| --- | ------------------------------------- |
| 1   | 모든 Pod는 **NAT 없이** 서로의 IP로 통신 가능      |
| 2   | 모든 노드는 그 노드의 모든 Pod와 통신 가능            |
| 3   | Pod가 보는 자기 IP = 외부가 보는 그 Pod IP (동일)  |
| 4   | 격리(차단)는 기본이 아니라 **NetworkPolicy로 선언** |


> 기본은 **flat network(전부 연결)**. CNI만 설치하면 Pod끼리 바로 통신됩니다. 막으려면 NetworkPolicy + **정책 집행 가능한 CNI**가 필요합니다 (12번 참고).

### 1.3 IP 부여 단위


| 단위          | IP               | 비고                          |
| ----------- | ---------------- | --------------------------- |
| **Pod**     | 1개 (내부 컨테이너 공유)  | 같은 Pod 컨테이너는 `localhost` 통신 |
| **컨테이너**    | 없음               | Pod IP + 포트로 구분             |
| **Service** | 가상 IP(ClusterIP) | kube-proxy가 Pod로 전달         |
| **Node**    | 노드 IP            | Pod 대역과 별개                  |


> NetworkPolicy는 **Pod IP / selector** 기준으로 트래픽을 필터링합니다. `from`/`to`에 **Service 이름을 쓸 수 없습니다.**

---

## 2. 사전 개념 — CNI (12번 문서 참조)

NetworkPolicy Lab은 **규칙 YAML 작성·최소 권한 선택**이 목표입니다. **CNI** 관련 배경만 12번 문서를 참고합니다.


| 필요한 개념                                  | 12번 문서                                                                             |
| --------------------------------------- | ---------------------------------------------------------------------------------- |
| CNI가 위치하는 곳, kubelet·CNI·NP 역할 분리       | [§1](../12.CNI&NetworkPolicy/Preliminaries.md#1-cni가-위치하는-곳)                       |
| CNI란, ADD/DEL 생명주기, 노드 간 통신 방식          | [§2](../12.CNI&NetworkPolicy/Preliminaries.md#2-cnicontainer-network-interface란)   |
| NetworkPolicy **선언 ≠ 집행**, Calico 필요 이유 | [§6](../12.CNI&NetworkPolicy/Preliminaries.md#6-cni--networkpolicy-연계-11번--12번-핵심) |


**이 Lab에서 CNI와 연결되는 점 (요약):**

- `kubectl apply`는 **규칙 선언**만 한다. 실제 차단은 **CNI 집행** — 12번 Lab에서 Calico 설치 ([§6](../12.CNI&NetworkPolicy/Preliminaries.md#6-cni--networkpolicy-연계-11번--12번-핵심)).

---

## 3. Pod 간 통신 — 정책이 없을 때 (기본값)

§1.2의 **flat network** 기본값과 같습니다. CNI가 설치되어 있고 NetworkPolicy가 **없거나**, 대상 Pod를 **선택(select)하지 않으면**:

```text
기본: 클러스터 내 모든 Pod ↔ 모든 Pod 통신 허용 (All-to-All)
```

같은 노드·다른 노드 모두 Pod IP로 직접 통신합니다.

```bash
# frontend Pod 안에서 backend Service 호출 (LabSetUp 이후)
kubectl exec -n frontend deploy/frontend-deployment -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://backend-service.backend
# 200 (정책 적용 전 — 기본 전체 허용)
```

---

## 4. NetworkPolicy란

**NetworkPolicy** 는 Pod(또는 Pod 그룹)에 대한 **L3/L4 방화벽 규칙**을 선언하는 Kubernetes 리소스입니다.

- **Ingress** — Pod로 **들어오는** 트래픽 허용 규칙
- **Egress** — Pod에서 **나가는** 트래픽 허용 규칙
- OSI 7계층 중 **L3(IP)·L4(포트/프로토콜)** 수준 (HTTP path·Host 헤더 같은 L7은 다루지 않음 → 그건 Ingress/Gateway/서비스메시 영역)

```text
NetworkPolicy (선언)  →  CNI/데이터플레인 (집행)  →  iptables / eBPF 등
```

자세한 내용은 [12 §6](../12.CNI&NetworkPolicy/Preliminaries.md#6-cni--networkpolicy-연계-11번--12번-핵심) 참고.

### 4.1 가장 중요한 동작 원리 — "선택되면 default-deny"

이 한 가지가 NetworkPolicy 전체를 좌우합니다.

```text
어떤 Pod가 정책의 podSelector에 의해 "선택(select)" 되는 순간,
  → 그 Pod의 해당 방향(Ingress/Egress)은 "화이트리스트 모드"로 전환된다.
  → 즉, 규칙에 명시적으로 허용한 트래픽만 통과, 나머지는 모두 차단.

어떤 정책에도 선택되지 않은 Pod
  → 기존처럼 전체 허용 (영향 없음)
```


| 상태                     | Ingress 결과 |
| ---------------------- | ---------- |
| 어떤 정책에도 안 잡힘           | 전체 허용      |
| 정책에 잡힘 + 허용 규칙에 매칭     | 허용         |
| 정책에 잡힘 + 허용 규칙에 매칭 안 됨 | **차단**     |


> 정책은 **누적(additive)** 입니다. 여러 정책이 같은 Pod를 선택하면 **허용 규칙들의 합집합(OR)** 이 됩니다. "거부 규칙"은 없습니다 — 허용을 안 하면 자동으로 거부입니다.

### 4.2 "최소 권한(Least Permissive)" 이란

요구사항(frontend→backend 통신)을 만족하면서 **허용 범위가 가장 좁은** 정책을 고르는 것. 이 Lab 과제의 채점 기준입니다.


| 후보           | 허용 범위                                            | 평가           |
| ------------ | ------------------------------------------------ | ------------ |
| policy-1     | backend NS 전체 Pod에 모든 인그레스                       | 너무 넓음 ✗      |
| policy-2     | frontend NS + `172.16.0.0/16` 전체 IP              | 불필요한 IP 허용 ✗ |
| **policy-3** | frontend NS 또는 app=frontend Pod → backend Pod:80 | **최소 권한** ✓  |


---

## 5. NetworkPolicy 문법

### 5.1 전체 구조

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example
  namespace: backend          # ← 이 NS 안의 Pod에만 적용
spec:
  podSelector:                # ← 정책 대상 Pod (이 NS 안에서 라벨로 선택)
    matchLabels:
      app: backend
  policyTypes:                # ← 어느 방향을 "화이트리스트 모드"로 둘지
  - Ingress
  ingress:                    # ← 허용할 인그레스 규칙 목록
  - from:                     #    누구로부터 (source)
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend
    - podSelector:
        matchLabels:
          app: frontend
    ports:                    #    어떤 포트로
    - protocol: TCP
      port: 80
```

### 5.2 주요 필드


| 필드                        | 설명                                           |
| ------------------------- | -------------------------------------------- |
| `metadata.namespace`      | 정책이 적용되는 **네임스페이스** (정책은 NS 범위 리소스)          |
| `spec.podSelector`        | 이 NS 안에서 규칙을 받을 Pod. `{}` 이면 **NS 내 모든 Pod** |
| `spec.policyTypes`        | `Ingress` / `Egress` 중 화이트리스트로 전환할 방향        |
| `ingress[].from`          | 허용 **출처(source)** 목록                         |
| `ingress[].ports`         | 허용 **프로토콜·포트** (생략 시 모든 포트)                  |
| `egress[].to`             | 허용 **목적지(destination)** 목록                   |
| `namespaceSelector`       | NS **라벨**로 출처/목적지 NS 제한                      |
| `podSelector` (from/to 안) | 출처/목적지 Pod 라벨 제한                             |
| `ipBlock`                 | CIDR 블록으로 출처/목적지 IP 제한 (외부 IP 등)             |


> **NS 라벨 팁:** 최신 Kubernetes는 모든 NS에 자동으로 `kubernetes.io/metadata.name: <NS이름>` 라벨을 붙입니다. 이 Lab 후보 YAML은 `name: frontend` 라벨을 씁니다. 없으면 `kubectl label ns frontend name=frontend --overwrite` 로 부여하세요.

### 5.3 selector 조합 규칙 — OR vs AND (가장 헷갈리는 부분)

`from`(또는 `to`) 아래 **리스트 항목(`-`)이 여러 개**면 → **OR** (하나만 맞아도 허용):

```yaml
ingress:
- from:
  - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: frontend } }   # 이거나
  - podSelector:       { matchLabels: { app: frontend } }                            # 저거나 (OR)
```

→ "frontend NS의 **모든** Pod" **또는** "(이 backend NS 안의) app=frontend Pod" 둘 다 허용 → 의도보다 넓어질 수 있음.

**AND** ("frontend NS **이면서** app=frontend Pod")는 **한 `-` 항목 안에** 두 selector를 함께 둡니다:

```yaml
ingress:
- from:
  - namespaceSelector:               # 한 항목 안에 둘 다 → AND
      matchLabels:
        kubernetes.io/metadata.name: frontend
    podSelector:
      matchLabels:
        app: frontend
```

→ "frontend NS에 있고 동시에 app=frontend 인 Pod" 만 허용. **이론상 가장 좁은 형태**입니다.

```text
[-] 가 새로 시작 = OR (출처 후보 추가)
한 [-] 안에 나란히 = AND (조건 교집합)
```

> 이 Lab의 `network-policy-3.yaml` 은 `from` 아래 `-` 가 **두 개(OR)** 입니다. policy-2 대비 `ipBlock` 이 없어 **세 후보 중 최소 권한**이지만, AND 형태보다는 넓습니다.

### 5.4 자주 쓰는 패턴 모음

**(a) Default Deny — NS의 모든 Ingress 차단 (기준선)**

```yaml
spec:
  podSelector: {}          # NS 내 모든 Pod
  policyTypes:
  - Ingress                # ingress 규칙 없음 → 전부 차단
```

**(b) Default Deny — Ingress + Egress 모두 차단**

```yaml
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**(c) Egress 허용 + DNS 예외 (실무 필수 함정)**

Egress를 막으면 **CoreDNS(53번 포트) 질의도 막혀** Service 이름 해석이 실패합니다. DNS는 거의 항상 열어줘야 합니다.

```yaml
spec:
  podSelector: { matchLabels: { app: frontend } }
  policyTypes:
  - Egress
  egress:
  - to:                                  # backend 로의 통신 허용
    - podSelector: { matchLabels: { app: backend } }
    ports:
    - { protocol: TCP, port: 80 }
  - to:                                  # kube-system CoreDNS 로의 DNS 허용
    - namespaceSelector: {}
    ports:
    - { protocol: UDP, port: 53 }
    - { protocol: TCP, port: 53 }
```

---

## 6. 이 Lab의 세 후보 비교

`LabSetUp.bash` 가 `/root/network-policies/` 에 만드는 파일입니다.

### 한눈에 비교


| 항목         | policy-1          | policy-2                                | policy-3                                   |
| ---------- | ----------------- | --------------------------------------- | ------------------------------------------ |
| **대상 Pod** | backend NS **전체** | `app=backend`만                          | `app=backend`만                             |
| **허용 출처**  | **모든 소스**         | frontend NS **또는** `172.16.0.0/16` (OR) | frontend NS **또는** `app=frontend` Pod (OR) |
| **포트**     | 전 포트              | TCP 80만                                 | TCP 80만                                    |
| **과제 충족**  | ✓ (너무 넓음)         | ✓ (불필요 IP 추가)                           | ✓                                          |
| **최소 권한**  | ✗                 | ✗                                       | **✓ (정답)**                                 |


### policy-1 (`network-policy-1.yaml`) — 너무 개방적

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-x
  namespace: backend
spec:
  podSelector: {}
  ingress:
  - {}
  policyTypes:
  - Ingress
```

- `podSelector: {}` → backend NS **모든 Pod**가 정책에 선택 → Ingress 화이트리스트 모드.
- `ingress: - {}` → `from`/`ports` 비어 있음 = **모든 출처·모든 포트 허용**.
- frontend→backend는 되지만, **클러스터 어디서든** backend로 들어올 수 있음 → **최소 권한 아님.**

### policy-2 (`network-policy-2.yaml`) — 불필요한 IP 대역

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-y
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    - ipBlock:
        cidr: 172.16.0.0/16
    ports:
    - protocol: TCP
      port: 80
  policyTypes:
  - Ingress
```

- `from` 아래 `-` 두 개 = **OR**: (1) frontend NS 전체 Pod, (2) `**172.16.0.0/16` 전체 IP**.
- TCP 80만 제한하지만, 과제에 없는 IP 대역이 추가됨 → **최소 권한 아님.**

### policy-3 (`network-policy-3.yaml`) — 정답 ✓

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-z
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
  policyTypes:
  - Ingress
```

- backend Pod만 선택 + TCP 80만. `ipBlock` 없음 → policy-2보다 좁음.
- `from` OR: frontend NS 전체 **또는** (어느 NS든) `app=frontend` Pod → Lab의 frontend Deployment 통신 허용.
- **세 후보 중 최소 권한** → 정답.

> ⚠️ policy-2 vs policy-3 차이: `ipBlock`(172.16.0.0/16) 유무. `**-` 위치(OR/AND)** 와 **추가 허용 유무**를 꼭 확인하세요.

---

## 7. 자주 헷갈리는 점

### NetworkPolicy vs AWS Security Group (한 줄 비교)


| 항목                   | NetworkPolicy                  | AWS Security Group                   |
| -------------------- | ------------------------------ | ------------------------------------ |
| **경계**               | **Pod** (컨테이너 워크로드)            | **ENI/인스턴스/로드밸런서** (노드·NIC)          |
| **계층**               | L3/L4 (IP, 포트, 프로토콜)           | L3/L4 (IP, 포트, 프로토콜)                 |
| **기본값**              | 정책 **없으면** Pod 간 대체로 **전부 허용** | 인바운드 **명시 허용 전까지 거부** (아웃바운드는 보통 허용) |
| **선택 방식**            | Pod/NS **라벨**, CIDR            | SG ID, CIDR, prefix list             |
| **집행 주체**            | **CNI** (Calico, Cilium 등)     | **AWS VPC** (하이퍼바이저/ENI)             |
| **L7 (HTTP path 등)** | ✗                              | ✗ (SG 자체는 L4; ALB/WAF는 별개)           |



| 질문                            | 답                                                                                                              |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------- |
| 정책 apply 했는데 안 막혀요            | **CNI가 정책 집행을 지원**해야 함 — [12 §6](../12.CNI&NetworkPolicy/Preliminaries.md#6-cni--networkpolicy-연계-11번--12번-핵심) |
| Service 이름으로 `from` 지정 가능?    | **아니오.** §1.3 참고 — `podSelector` / `namespaceSelector` / `ipBlock` 만 가능                                        |
| `ingress: - {}` 의 의미?         | 해당 규칙에서 **모든 소스 허용** (매우 개방적)                                                                                  |
| 정책이 없는 Pod는?                  | 어떤 정책에도 안 잡히면 **전체 허용** (기본값)                                                                                  |
| Ingress만 막으면 응답(return)도 막히나? | **아니오.** 상태 추적(stateful)이라 허용된 연결의 응답은 자동 통과. 방향은 **연결 시작 기준**                                                 |
| Egress 막았더니 DNS가 안 돼요         | CoreDNS(53/UDP·TCP)를 egress에 **명시적 허용** 필요 (5.4-c)                                                             |
| AWS Security Group과 차이?       | **Pod 경계 vs 노드(ENI) 경계** — 위 표 참고. 개념은 "Pod용 SG"에 가깝지만 기본값·집행 주체가 다름                                           |
| L7(HTTP path)도 막나?            | **아니오.** L3/L4까지만. L7은 Ingress/Gateway/서비스메시                                                                   |


> CNI·집행: [12.CNI&NetworkPolicy/Preliminaries.md](../12.CNI&NetworkPolicy/Preliminaries.md) — 선언한 정책을 **실제로 집행**하려면 Calico 등 정책 지원 CNI 설치.

