## FAQ: NodePort vs LoadBalancer (외부 LB가 있을 때)

### Q1. 외부 LB가 있을 때 LoadBalancer Type과 NodePort Type의 유의미한 차이가 무엇인가?
- **핵심 차이**는 “Kubernetes가 외부 Load Balancer를 **자동으로 프로비저닝/연동**해주느냐”이다.
- **Service `LoadBalancer`**
  - (클라우드 통합 환경에서) 서비스 생성 시 외부 Load Balancer를 자동 생성하고, 해당 LB가 서비스로 트래픽을 전달하도록 구성된다(구현체에 따라 NodePort 또는 Pod IP 모드로 연동).
  - 외부 접근 엔드포인트(공인 IP/DNS)가 **서비스 단위**로 생긴다.
- **Service `NodePort`**
  - 외부 LB를 자동으로 만들지 않는다.
  - 모든 노드에 특정 포트를 열어(`NodeIP:NodePort`) 외부 LB가 있다면 그 LB가 각 노드의 NodePort로 분산한다.
- **정리**
  - 외부 LB를 Kubernetes가 “서비스 단위로 자동 관리”하게 하려면 `LoadBalancer`
  - 외부 LB를 “공유/직접 운영”하고 뒤로 K8s 서비스를 붙이려면 `NodePort`(+ 외부 LB 설정 필요)

### Q2. Node에 Pod이 안 떠있는데 NodePort VM이 만들어지는가?
- NodePort는 VM(노드)을 “생성”하지 않는다.
- NodePort 서비스가 생성되면, 클러스터의 모든 노드에서 해당 포트가 열리도록(프록시/룰 설정) 동작한다.
- **케이스 A (해당 노드에 Pod 있음)**: `NodeIP:NodePort`로 들어온 트래픽이 **그 노드에 있는 Pod**로 전달될 수도 있다.
- **케이스 B (해당 노드에 Pod 없음)**: `NodeIP:NodePort`로 들어온 트래픽이 **다른 노드에 있는 Pod**로 포워딩될 수도 있다.
- 클러스터 전체에 엔드포인트(Pod)가 없으면 요청은 실패한다(타임아웃/리셋 등).

### Q2-1. (케이스 B) Pod이 없는 노드의 NodePort로 들어온 요청은 “어떻게” 다른 Pod으로 가나? API server랑 통신하나?
- **요청이 들어올 때마다 API server에 물어보지 않는다.**
- kube-proxy는 평소에 API server를 “watch”해서 **Service / EndpointSlice(또는 Endpoints)** 변경을 구독하고, 그 결과로 **노드 로컬에 포워딩 규칙(iptables 또는 IPVS)** 을 미리 구성해둔다.
- 그래서 실제 데이터 플로우는 “컨트롤 플레인 조회”가 아니라 **노드 커널 레벨의 NAT/로드밸런싱 규칙**으로 진행된다.

#### 용어/개념 정리(이 섹션에서 쓰는 말들)
- **Node(노드)**: Kubernetes에서 Pod가 실제로 실행되는 서버/VM(워커 노드).
- **Pod IP**: Pod에 할당되는 클러스터 내부 IP(대개 CNI가 부여).
- **Service(서비스)**: “Pod 집합”을 안정적으로 가리키는 가상 엔드포인트(로드밸런싱/서비스 디스커버리).
- **NodePort**: 모든 노드에 동일 포트(보통 30000–32767)를 노출해 `NodeIP:NodePort`로 서비스에 접근하게 하는 방식.
- **EndpointSlice/Endpoints**: “이 Service 뒤에 실제로 붙은 Pod IP:Port 목록(엔드포인트 집합)”.
- **kube-proxy**: Service/EndpointSlice 변경을 watch해 노드에 **iptables/IPVS 규칙**을 구성하는 컴포넌트(데이터 패킷을 직접 프록시하지 않고 커널 규칙을 주로 사용).
- **iptables(netfilter)**: 리눅스 커널 패킷 필터/변환 프레임워크. kube-proxy가 `KUBE-*` 체인을 만든다.
- **DNAT**: 목적지 주소/포트를 바꾸는 NAT. (예: `dst=NodeIP:30080` → `dst=PodIP:8080`)
- **SNAT(MASQUERADE)**: 출발지 주소를 바꾸는 NAT. 응답 경로/라우팅을 단순화하려고 쓰이며, 상황에 따라 적용 여부가 달라질 수 있다.
- **conntrack**: 커널이 연결/NAT 매핑 상태를 저장하는 기능. 응답 패킷이 “원래 연결”로 되돌아가게 해준다.
- **CNI**: Pod 네트워크를 구성하는 플러그인/표준. 노드 간 Pod IP 라우팅/오버레이(VXLAN/Geneve 등)를 제공한다.
- **externalTrafficPolicy**
  - `Cluster`: 노드에 Pod가 없어도 다른 노드 Pod로 포워딩 가능(기본적으로 이 동작을 설명하는 모드).
  - `Local`: 해당 노드의 “로컬 엔드포인트”로만 보내려는 성격(소스 IP 보존 목적 등). 로컬 Pod가 없으면 드롭/실패할 수 있다.

#### 데이터 플로우(대표 구현: kube-proxy iptables 모드, externalTrafficPolicy=Cluster)
1) 외부 클라이언트가 `NodeIP:NodePort`로 TCP 연결을 시도한다.
2) 해당 노드에서 kube-proxy가 미리 설치한 iptables 규칙이 패킷을 가로채서, 그 NodePort가 가리키는 **Service 체인**(예: `KUBE-NODEPORTS` → `KUBE-SVC-xxxx`)으로 보낸다.
3) `KUBE-SVC-xxxx` 체인에서 **엔드포인트들(Pod IP:Port) 중 하나**를 확률적으로 선택하도록 분기 규칙이 걸려 있고,
4) 선택된 엔드포인트 체인(예: `KUBE-SEP-yyyy`)에서 패킷의 목적지를 **Pod IP:PodPort로 DNAT** 한다.
5) 목적지가 “다른 노드의 Pod IP”라면, 패킷은 CNI가 만든 오버레이/라우팅(예: VXLAN, Geneve, 라우팅 테이블 등)을 통해 **해당 Pod이 있는 노드로 전달**된다.
6) 응답 트래픽은 conntrack/NAT 상태에 의해 원래 연결로 되돌아간다. (필요 시 노드에서 SNAT/masquerade가 적용될 수 있음)

#### 다이어그램(케이스 B: Pod 없는 노드로 들어온 NodePort 요청)

```mermaid
flowchart LR
  C[Client] -->|TCP to NodeIP:NodePort| N1[Node A\n(NodePort 열린 노드)\nPod 없음]
  N1 -->|iptables KUBE-NODEPORTS| SVC[KUBE-SVC-xxxx\n(Service chain)]
  SVC -->|statistic match| SEP1[KUBE-SEP-aaaa\nPod1 IP:Port]
  SVC -->|statistic match| SEP2[KUBE-SEP-bbbb\nPod2 IP:Port]
  SEP1 -->|DNAT dst=PodIP:Port| NET[CNI overlay/routing]
  SEP2 -->|DNAT dst=PodIP:Port| NET
  NET --> N2[Node B\nPod 존재]
  N2 --> P[(Pod)]
  P -->|reply| N2 --> NET --> N1 --> C
```

#### iptables/NAT 형태로 보는 “실제 요청 예시”(개념)
- 가정
  - NodePort: `30080`
  - Service port/targetPort: `80 -> 8080`
  - 선택된 Pod(다른 노드): `10.244.2.7:8080`
  - 요청: `curl http://<NodeA_IP>:30080/`
- 핵심
  - **요청 시점에 API server를 조회하지 않고**, 이미 설치된 규칙이 동작한다.
  - NodePort로 들어온 트래픽은 **Service 체인으로 점프 → 엔드포인트 선택 → DNAT** 과정을 거친다.

```bash
# (개념) NodePort 30080 → 해당 Service 체인으로 점프
-A KUBE-NODEPORTS -p tcp --dport 30080 -j KUBE-SVC-XXXX

# (개념) Service 체인에서 엔드포인트들로 분기 (여러 개면 statistic으로 분산)
-A KUBE-SVC-XXXX -m statistic --mode random --probability 0.50 -j KUBE-SEP-AAAA
-A KUBE-SVC-XXXX -j KUBE-SEP-BBBB

# (개념) 선택된 엔드포인트에서 목적지를 Pod IP:8080로 DNAT
-A KUBE-SEP-AAAA -p tcp -j DNAT --to-destination 10.244.2.7:8080
```

#### “좀 더 현실적인” iptables 패턴(개념)
- 환경에 따라 세부 규칙은 달라질 수 있지만, kube-proxy iptables 모드에서는 아래 요소가 자주 함께 등장한다.
- **(1) NodePort 매칭 → Service 체인 점프**
- **(2) Service 체인에서 엔드포인트 선택**
- **(3) 특정 상황에서 SNAT 필요 표시(`KUBE-MARK-MASQ`)**
- **(4) POSTROUTING에서 마킹된 패킷을 MASQUERADE**

```bash
# (개념) NodePort → Service
-A KUBE-NODEPORTS -p tcp --dport 30080 -j KUBE-SVC-XXXX

# (개념) Service → (필요 시) masquerade 마킹 → 엔드포인트
-A KUBE-SVC-XXXX -j KUBE-MARK-MASQ
-A KUBE-SVC-XXXX -m statistic --mode random --probability 0.50 -j KUBE-SEP-AAAA
-A KUBE-SVC-XXXX -j KUBE-SEP-BBBB

# (개념) 엔드포인트에서 DNAT
-A KUBE-SEP-AAAA -p tcp -j DNAT --to-destination 10.244.2.7:8080

# (개념) POSTROUTING에서 마킹된 패킷 SNAT(MASQUERADE)
-A KUBE-POSTROUTING -m mark --mark 0x4000/0x4000 -j MASQUERADE
```

#### 패킷 관점(개념)
- **DNAT 전**: `src=ClientIP:ClientPort` → `dst=NodeA_IP:30080`
- **DNAT 후**: `src=ClientIP:ClientPort` → `dst=10.244.2.7:8080`
- `dst`가 “다른 노드의 Pod IP”이면, 그 이후 전달은 **CNI 라우팅/오버레이**가 담당한다.

#### 요청/응답 흐름을 “연결 단위”로 더 구체적으로 보면(개념)
- **요청(클라이언트 → 노드 A)**
  - Client가 `NodeA_IP:30080`으로 SYN을 보낸다.
  - 노드 A에서 NodePort 규칙이 매칭되어 Service/Endpoint 체인으로 들어간다.
  - 선택된 엔드포인트에 대해 **DNAT** 되어 `dst=PodIP:8080`로 바뀐다.
  - 이제 패킷의 목적지는 Pod IP이므로, 노드 A는 CNI 라우팅/오버레이를 통해 **노드 B(그 Pod가 있는 노드)** 로 패킷을 전달한다.
- **응답(Pod → 클라이언트)**
  - Pod가 응답을 보내면, conntrack이 DNAT/SNAT 매핑을 참조해 응답이 올바르게 되돌아가도록 처리한다.
  - 만약 중간에 SNAT(MASQUERADE)가 적용되었다면, 응답은 그 SNAT된 주소를 기준으로 되돌아오고, conntrack이 원래 클라이언트 연결로 역변환한다.

#### 중요 포인트(오해 방지)
- kube-proxy의 API server 통신은 **“규칙을 갱신하기 위한 컨트롤 플로우”** 이고, 실제 요청 처리 시점의 **“데이터 플로우”** 는 iptables/IPVS + CNI 네트워킹이 담당한다.
- `externalTrafficPolicy: Local`로 바꾸면 동작이 달라질 수 있다.
  - Local은 “트래픽을 해당 노드의 로컬 엔드포인트로만” 보내려는 성격이라, **그 노드에 Pod가 없으면** LB/노드에서 드롭될 수 있다(설정 의도: 클라이언트 소스 IP 보존 등).

### Q2-2. Service는 Deployment와 자동으로 연동되어 생성되나? NodePort는 “어느 노드”의 포트를 여나? Service Controller는 무슨 일을 하나?
- Service는 Deployment와 “자동 생성/연동”되는 객체가 아니라, **별도로 생성하는 리소스**다.
  - Service가 어떤 Pod로 트래픽을 보낼지는 **`spec.selector`(라벨 셀렉터)** 로 결정된다.
- `type: NodePort`에서 “어느 노드의 포트를 여는지”는 선택 개념이 아니라, 기본적으로 **모든 노드에 같은 NodePort가 노출**된다.
  - 즉, `NodeIP:NodePort`는 **클러스터의 모든 Node에서 유효**한 진입점이 된다.
  - NodePort 번호는 `spec.ports[].nodePort`를 명시하면 그 번호를 쓰고, 비워두면(0이면) 컨트롤 플레인이 범위 내에서 할당한다.
- 역할 분리(헷갈리기 쉬운 포인트)
  - **EndpointSlice(또는 Endpoints) 컨트롤러**: Service의 selector에 매칭되는 Pod들을 추적해 **백엔드 목록(Pod IP:Port)** 을 `EndpointSlice`로 생성/갱신한다.
  - **Service Controller(주로 LoadBalancer 연동)**: `type: LoadBalancer`일 때 클라우드/인프라와 연동해 **외부 LB 생성/수정/삭제**, 외부 IP를 `status.loadBalancer`에 반영 등을 담당한다(환경에 따라 동작).
  - **kube-proxy**: 노드에서 실제로 `NodePort/ClusterIP` 트래픽이 Service/Endpoint로 흘러가도록 **iptables/IPVS 규칙**을 구성한다(데이터 플레인을 커널 규칙으로 구현).

### Q3. LoadBalancer가 (서비스마다) 만들어지면 비싼데, 외부 LB만 두고 개선할 수 없나?
- 보통 LoadBalancer는 “노드마다”가 아니라 “서비스마다” 만들어지는 구조다(클라우드 구현체 기준).
- 비용/운영 측면에서 서비스마다 LB 생성을 피하려면 다음 패턴이 흔하다:
  - 외부 LB 1개(또는 최소) → Ingress Controller → 여러 Service 라우팅(Host/Path 기반)
- 결론: 가능하고, 실무에서도 Ingress로 진입점을 통합하는 방식이 흔하다.
