# 2주차. Kubernetes 이해하기 — 왜 이토록 크고, 왜 배워야 하는가

> **이전 글**에서 물리 서버 → VM → Container/Docker → Compose/Swarm으로 이어진 배경을 따라왔고, Docker만으로 운용할 때 손이 가는 한계를 시나리오로 겪었습니다. 이번 글은 그 빈칸 위에서, Kubernetes가 무엇인지·무엇을 약속하는지·핵심 개념이 어떻게 이어지는지를 개략적으로 정리합니다.

---

## Kubernetes 이해하기 — 왜 이토록 크고, 왜 배워야 하는가

<div align="center">

![Kubernetes 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/27-k8s-official-logo.svg)

</div>

Kubernetes는 컨테이너를 여러 서버에 걸쳐 운영하기 위한 오픈소스 플랫폼입니다. 2014년 공개된 뒤 전 세계 기여자가 코드를 쌓아 왔고, 주요 클라우드는 관리형으로 제공하며 같은 모델을 노트북에서도 돌릴 수 있습니다. 어디에서 실행하든 비슷한 운영 방식을 공유한다는 점이, 사실상의 표준처럼 받아들여진 이유 중 하나입니다.

<div align="center">

![Kubernetes 주변 생태계](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/28-k8s-ecosystem.svg)

</div>

인기의 배경에는 이식성도 있습니다. Kubernetes를 전제로 만든 애플리케이션은 환경이 바뀌어도 같은 선언 방식으로 배포를 시도할 수 있다는 약속에 가깝습니다. 동시에 Kubernetes 주변에는 배포·모니터링·네트워크·스토리지·보안을 돕는 도구들이 모여, “도시 운영”을 혼자 다 만들지 않아도 되게 받쳐 줍니다.

그렇다고 배우기 쉽다는 뜻은 아닙니다. 처음에는 구성 요소와 설정 파일이 많아 “왜 이렇게 복잡하지?”가 먼저 나옵니다. 조금 익숙해지면 “이런 것까지 되는구나” 쪽으로 질문이 바뀌는 경우가 많습니다. 이 글도 같은 순서를 따릅니다. 곧바로 모든 이름을 외우기보다, Kubernetes가 **어떤 문제를 정책으로 바꾸는지**부터 보고, 이어서 API·클러스터·원하는 상태라는 뼈대를 잡은 뒤, **설계 철학 → 구성 요소 → 동작 방식 → 핵심 리소스** 순으로 도시를 조금 더 구체화합니다.

---


## Kubernetes가 푸는 문제 — 사람의 판단을 정책으로

컨테이너를 여러 개 실행하는 것은 어렵지 않습니다. 어려운 것은 운영 판단입니다. Docker의 등장 이후 컨테이너는 실행 환경을 표준화하는 핵심이 되었고, Dockerfile로 환경을 코드처럼 남길 수 있게 되었습니다.

```bash
docker build -t my-app:1.0 .
docker run -p 8080:80 my-app:1.0
```

같은 이미지로 로컬·테스트·운영을 맞출 수 있게 되면서 환경 불일치 문제는 크게 줄었습니다. Docker Compose로 여러 컨테이너를 한 애플리케이션처럼 묶을 수 있고, Docker Swarm으로 여러 서버에 분산하는 것도 가능해졌습니다. 그래서 자연스럽게 이런 질문이 나옵니다.

“Docker Compose나 Docker Swarm으로도 충분하지 않은가? Kubernetes는 왜 필요한가?”

> Docker는 “컨테이너를 실행하는 도구”이고, Kubernetes는 “컨테이너가 실행되는 전체 시스템을 관리하는 플랫폼”입니다. 비유하자면 Docker는 집을 짓는 공구에, Kubernetes는 도시를 설계·운영하는 체계에 가깝습니다.

단일 서버에서는 Docker Compose만으로도 충분한 경우가 많고, 여러 서버에서는 Docker Swarm으로도 일정 수준의 운영이 가능합니다. 다만 규모와 요구가 커질수록, 실행·복제를 넘어 **더 정교한 관리**가 필요해집니다.

### Docker Swarm이 실무에서 덜 쓰이게 된 이유

Docker Swarm은 Docker에 익숙한 팀이 멀티 호스트 배포를 빠르게 시작하기에 좋은 선택지였습니다. 그런데 서비스가 커질수록 한계가 자주 드러납니다.

1. **운영 기능의 깊이** — Kubernetes는 리소스 요청/제한, 오토스케일링, 네트워크 정책, 스토리지 추상화, RBAC처럼 운영 정책 도구가 풍부합니다. Swarm도 배포·스케일·롤링 업데이트는 되지만, 세밀한 정책과 확장 생태계는 상대적으로 제한적입니다.
2. **생태계와 표준의 중심 이동** — Helm, Argo CD, Prometheus, Service Mesh, Operator 등 CNCF 생태계가 Kubernetes를 기준으로 커지며, 도구·레퍼런스·인력 풀이 그쪽으로 쏠렸습니다.
3. **제품·커뮤니티 모멘텀** — Swarm은 한동안 안정적이되 큰 변화가 적은 흐름 갔고, 업계에서는 Kubernetes가 오케스트레이션의 사실상 표준으로 자리 잡았습니다.

### 실제 운영에서 드러나는 차이

트래픽이 급증할 때 Docker Swarm에서는 관리자가 직접 복제본 수를 늘는 식의 개입이 흔합니다.

```bash
docker service scale web=10
```

확장은 가능하지만, **언제·몇 개까지·언제 줄일지**의 판단은 사람에게 남습니다. Kubernetes에서는 CPU 사용률 같은 조건을 정책으로 남겨 두고, 그 이후의 판단과 실행을 플랫폼에 맡기는 쪽으로 문제를 바꿉니다. 예를 들어 “CPU 사용률 70%를 넘으면 자동으로 늘려라”는 식의 목표만 정의해 두면 됩니다.

```yaml
targetCPUUtilizationPercentage: 70
```

장애도 마찬가지입니다. 새벽 세 시에 컨테이너 하나가 죽었을 때 Docker만 있다면 `docker ps` → 로그 → `docker restart`를 사람이 수행합니다. Kubernetes에서는 제어 루프가 원하는 개수와 실제 개수의 차이를 감지하고, 스케줄러가 노드를 고르며, 노드 에이전트가 컨테이너를 기동하는 흐름으로 이어질 수 있습니다. 사람이 개입하지 않아도 복구가 시작된다는 점이, “집을 짓는 공구”와 “도시를 운영하는 시스템”의 차이를 실감하게 합니다.

배포 전략에서도 결이 갈립니다. Docker Swarm은 기본적인 롤링 업데이트를 제공하지만, Kubernetes는 Blue-Green·Canary처럼 **트래픽 일부만 새 버전으로 보내는** 방식까지 운영 리스크를 나누어 제어하기 쉬운 편입니다. 단순한 기능 목록의 차이가 아니라, **운영 리스크를 제어할 수 있는 수준**의 차이에 가깝습니다.

결국 Kubernetes는 컨테이너를 많이 띄우는 도구를 넘어, 엔터프라이즈 수준의 운영 환경을 제공하는 플랫폼으로 받아들여집니다. “엔터프라이즈”가 추상적으로 들린다면, 이유는 이렇습니다. 컨테이너를 늘리는 일을 넘어 **운영 규칙과 정책을 시스템 차원에서 다룰 수 있기** 때문입니다.

- **리소스 관리(요청/제한)** — 인스턴스마다 CPU·메모리를 “얼마나 필요한지(요청)”와 “최대 얼마까지(제한)” 선언해, 과부하에 서비스가 함께 무너지는 일을 줄입니다.
- **네트워크 정책** — 통신을 “기본 허용”이 아니라 “필요한 것만 허용”으로 좁힐 수 있습니다.
- **스토리지 관리** — 로컬·네트워크·클라우드 스토리지를 리소스로 추상화해, 앱은 같은 방식으로 저장소를 요청합니다.
- **보안(RBAC)** — 누가 무엇을 조회·수정할 수 있는지 권한을 나눕니다.

### 컨테이너 오케스트레이션의 본질

오케스트레이션은 컨테이너를 실행하는 일에 그치지 않습니다. 다음을 자동화하는 시스템에 가깝습니다.

- 어떤 노드에 배치할 것인가
- 몇 개를 유지할 것인가
- 장애 시 어떻게 복구할 것인가
- 트래픽을 어떻게 분산할 것인가

즉 “컨테이너 하나”가 아니라 **전체 시스템**을 관리하는 개념입니다. Kubernetes는 이 문제를 풀기 위해 등장했습니다.

비유를 한 번 더 쓰면 이렇습니다. Docker는 잘 포장된 상자를 만들고 여는 일에 강하고, Docker Compose는 한 집 안의 상자들을 한 도면으로 정리하며, Docker Swarm은 작은 단지 규모의 분산을 돕고, Kubernetes는 규모가 커질 때 필요한 정책과 자동화를 표준에 가깝게 묶어 둔 플랫폼입니다. 다만 “플랫폼”이라는 말을 제대로 이해하려면, 실제로 무엇을 묶어서 제공하는지—창구와 원하는 상태, 그리고 이어질 설계 철학·구성 요소·동작·리소스—를 조금 더 구체적으로 볼 필요가 있습니다.

---
## Kubernetes를 조금 더 구체적으로 — 도시 운영의 큰 그림

앞에서 Docker는 상자를 다루는 공구에, Docker Compose는 한 집의 도면에, Docker Swarm은 단지 관리사무소에 비유했습니다. Kubernetes는 그 연장선에서, **여러 건물에 흩어진 상자를 도시 규모로 운영하는 체계**로 이해하면 됩니다. 이번 절에서는 세부 부품 이름을 외우기보다, 그 도시가 무엇을 약속하는지만 크게 잡습니다. 구체적인 장치들은 이어지는 연재에서 하나씩 만납니다.

### 창구와 도시 — API와 클러스터

<div align="center">

![Kubernetes API와 클러스터](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/08-k8s-cluster.svg)

</div>

Kubernetes를 한 문장으로 압축하면, 컨테이너로 만든 애플리케이션을 **선언하고, 그 선언이 실제로 유지되도록 돕는 오케스트레이션 플랫폼**입니다. 여기서 두 축만 기억하면 충분합니다.

첫째는 **API**입니다. API는 사용자가 도시 운영에 “원하는 모습”을 전달하는 **창구**입니다. 시청 민원 창구에 서류를 내듯, 우리는 “웹 상자를 세 개 유지해 달라”, “이 이미지로 돌려 달라” 같은 요청을 API로 보냅니다. 창구가 하나라는 점이 중요합니다. 건물(서버)마다 따로 전화하지 않아도, 같은 창구로 도시의 운영을 말할 수 있습니다.

둘째는 **클러스터(Cluster)** 입니다. 클러스터는 그 요청이 **실제로 실행되는 도시 전체**입니다. 도시를 이루는 개별 건물이 **노드(Node, 클러스터에 참여하는 서버)** 입니다. Docker Swarm에서 본 “여러 서버를 하나의 단지로”와 같은 층위이고, Kubernetes에서는 그 단지를 더 큰 운영 규칙과 함께 다룬다고 보면 됩니다. 일상적인 사용에서는 “어느 건물 몇 호실”을 사용자가 고르기보다, 도시 전체에 “이런 상태로 유지해 달라”고 맡기는 경우가 많습니다.

### 도면과 현장 — 원하는 상태

<div align="center">

![Desired State와 실제 상태](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/09-desired-state.svg)

</div>

창구에 내는 서류의 핵심은 **원하는 상태(Desired State)** 입니다. 원하는 상태란, “지금은 무엇이 몇 개 떠 있는가”가 아니라 **“이렇게 되어 있기를 바란다”** 를 적어 둔 목표입니다. Docker Compose의 YAML이 한 집의 도면이었다면, Kubernetes에서도 비슷한 형태로 목표를 적고 API 창구에 넘깁니다. 차이는 도면을 넘긴 뒤의 책임에 있습니다.

Docker만 있을 때 상자가 죽으면 사람이 `docker start`를 눌러 현장을 도면에 맞췄습니다. Kubernetes에서는 플랫폼이 **원하는 상태**와 **현장에 실제로 있는 상태**를 비교하고, 어긋나면 상자를 더 띄우거나 줄이거나 다른 건물로 옮기며 차이를 줄입니다. 단지 관리사무소가 “매장에 바리스타가 두 명이어야 한다”는 규칙을 받아 두고, 한 명이 빠지면 다시 채우는 일과 같습니다. 이 “차이를 계속 맞추는 흐름”이 바로 **제어 루프(Control Loop)** 입니다. 자세한 항목은 아래 설계 철학에서 나열하고, 여기서는 **사람이 버튼을 누르던 일이 도시의 기본 업무가 된다**는 감각만 잡아 두면 충분합니다.

### 앞선 이야기와 어떻게 이어지는가

큰 줄기를 한 번 더 이어 보면 이렇습니다. VM은 컴퓨터를 통째로 나눴고, Container와 Docker는 앱을 가벼운 상자로 옮겼습니다. Docker Compose는 한 서버 안의 상자들을 도면으로 묶었고, Docker Swarm은 여러 서버로 단지를 넓혔습니다. Kubernetes는 그 단지·도시 운영을 **같은 창구(API)** 와 **원하는 상태라는 도면**으로 표준에 가깝게 묶어 두려는 쪽에 가깝습니다.

도시 운영에는 교통(요청을 어디로 보낼지), 창고(데이터가 어디에 남을지), 출입(누가 무엇을 할 수 있는지)처럼 세부가 많습니다. 그 세부에는 각각 이름이 붙어 있고, 연재가 진행될수록 실습에서 하나씩 만지게 됩니다. 이번 주에는 이름을 외우기보다, **상자 → 도면 → 단지 → 도시 창구**로 이어진 이유만 선명히 남겨 두면 충분합니다.

배우는 첫 환경은 꼭 거대한 도시일 필요도 없습니다. 건물 한 채(단일 노드)로도 창구와 원하는 상태의 감각을 익힐 수 있습니다. **이전 글**에서 Docker로 상자를 띄우고·멈추고·다시 살리고·늘리는 운용을 이미 손으로 겪었다면, 지금 읽는 “원하는 상태”와 “제어 루프”가 공허하지 않을 것입니다. 공구로 못을 박아 본 뒤에야 도시 운영 체계의 말이 선명해지는 것과 같습니다.

흐름은 단순합니다. 실행에 필요한 설계도(Image)로 상자를 만들고, 원하는 상태를 적고, 클러스터가 그 차이를 줄이게 맡긴다. 아래부터는 그 도시를 **조금 더 구체적으로**—설계 철학, 구성 요소, 동작 방식, 핵심 리소스—까지 내려가 봅니다.

---


## 설계 철학

Kubernetes의 설계 철학은 다음으로 요약할 수 있습니다.

1. **선언형(Declarative)**  
   “지금 무엇을 실행하라”는 일회성 지시보다, **“항상 이렇게 되어 있기를 바란다”** 는 목표를 남긴다.

2. **Desired State와 Current State**  
   도면에 적힌 목표(Desired)와 현장의 실제 상태(Current)를 구분하고, 둘의 차이를 운영의 중심으로 둔다.

3. **Control Loop(제어 루프) / Reconcile(보정)**  
   원하는 상태를 읽고 → 현재 상태를 확인하며 → 차이를 계산하고 → 차이를 줄이도록 조치를 **요청**한 뒤 → 다시 관찰하는 반복이 기본 작동 방식이다. Kubernetes는 명령을 실행하고 끝나는 시스템이 아니라 **상태를 유지하는 시스템**이다.

4. **Self-Healing은 루프의 결과**  
   인스턴스가 줄어들면 부족한 만큼 다시 맞추려는 흐름이 시작된다. 장애 복구는 특수 기능이라기보다, 원하는 상태를 유지하려는 제어 루프의 자연스러운 결과다.

5. **컨트롤러가 조정하고, Kubelet이 실행한다**  
   Control Loop는 주로 `kube-controller-manager` 안의 컨트롤러들이 돌린다. 컨트롤러는 노드에 직접 명령을 내리지 않고 **API Server에 상태 변경을 요청**하며, 실제 컨테이너 실행은 해당 노드의 Kubelet이 맡는다. Control Plane을 여러 대로 두면 Leader Election으로 중복 조정을 막는다.

6. **책임 분리의 이점**  
   - 수평 확장성: 중앙은 상태 조정에, 실행·관찰은 노드에 나눈다.  
   - 신뢰 가능한 관찰: 프로세스 상태는 해당 노드가 가장 정확히 본다.  
   - 장애 격리: 노드 문제와 Control Plane 흔들림이 서로를 덜 전파한다.  
   - 표준화된 정책 확장: Probe처럼 “정상”의 기준을 표준 인터페이스로 노드에서 수행하게 한다.

7. **이벤트 기반(Watch)과 API Server 중심 통신**  
   컴포넌트는 서로를 직접 호출하기보다, API Server에 저장된 상태 변화를 구독(Watch)한다. Scheduler는 **배치만**, Controller는 **개수·상태 유지만**, Kubelet은 **실행만** 한다.

8. **선언형은 IaC / GitOps로 이어진다**  
   목표가 파일로 남으면 버전 관리·재현·리뷰·롤백이 쉬워진다. 자동 복구만이 아니라, 운영 변경 자체를 코드처럼 다루는 토대가 된다.

---


## 구성 요소 — 도시의 두뇌와 건물

철학이 “무엇을 약속하는가”라면, 구성 요소는 “누가 그 약속을 수행하는가”입니다. Pod·Deployment·Service 같은 객체가 **어느 프로세스·노드에 의해** 실현되는지를 등장인물처럼 짚습니다. API Server, Controller, Scheduler, Kubelet은 설계 철학과도 맞물리므로, 여기서 역할을 정리해 두면 이후 흐름이 분명해집니다.

도시는 크게 **Control Plane(컨트롤 플레인, 두뇌)** 과 **Worker Node(워커 노드, 실제 건물이 서는 자리)** 로 나뉩니다.

<div align="center">

![Kubernetes API와 클러스터](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/08-k8s-cluster.svg)

</div>

### Control Plane

Control Plane은 클러스터의 **두뇌**에 해당하며, Desired State를 해석·유지하고 Pod가 어느 노드에 갈지 결정하는 등의 판단을 담당합니다. 대표 구성 요소는 API Server, Scheduler, Controller Manager, etcd입니다.

**API Server**는 Kubernetes의 **중앙 관문(Entry Point)** 입니다.

- 사용자의 `kubectl` 호출, 컨트롤러·스케줄러·Kubelet이 보내는 요청이 모두 API Server를 거쳐야만 클러스터 상태를 조회하거나 바꿀 수 있습니다.
- RESTful API를 제공하고, 인증·인가와 스키마 유효성 검사를 수행한 뒤 변경 내용을 etcd에 반영합니다.
- 예를 들어 `kubectl apply`로 리소스를 제출하면 API Server가 이를 검증·저장하고, 그 결과를 다른 컴포넌트들이 Watch 하며 감지할 수 있게 됩니다.

**Scheduler**는 각 노드의 자원·제약 조건을 고려하여 Pod를 어떤 노드에 배치할지 결정합니다.

- API Server를 통해 **아직 노드가 정해지지 않은(unscheduled) Pod**를 알아챕니다.
- Worker 노드의 CPU·메모리 여유, taint/toleration, node affinity/anti-affinity, 노드 셀렉터 등을 고려해 **어느 노드에 둘지**만 결정합니다.
- Scheduler는 컨테이너를 직접 실행하지 않으며, “이 Pod는 이 노드에 할당한다”는 결정을 API Server(및 etcd)에 기록합니다. 이후 해당 노드의 Kubelet이 그 Pod를 받아 실제 컨테이너를 띄웁니다.

**Controller Manager**는 클러스터 상태가 사용자가 선언한 원하는 상태와 계속 일치하도록 자동으로 감시·조정합니다.

- Deployment Controller, ReplicaSet Controller, Node Controller 등 여러 컨트롤러를 한 프로세스에서 묶어 실행합니다.
- 각 컨트롤러는 API Server의 리소스를 Watch 하면서 Desired State와 Current State를 비교하고, 다르면 Pod 생성·삭제·노드 상태 반영 등 **보정(Reconcile)** 을 수행합니다.
- 장애로 Pod가 사라지면 ReplicaSet 쪽 컨트롤러가 개수를 맞추기 위해 새 Pod를 만들도록 API Server에 요청하는 식입니다.
- 컨트롤러는 노드에 직접 접속하지 않고, **API Server에 리소스 변경을 남기는 방식**으로만 조치를 요청합니다.

**etcd**는 클러스터 상태를 저장하는 **분산 Key-Value 데이터베이스**입니다.

- Pod, Deployment, Service 같은 리소스 정의(Desired State)와 현재 상태(Current State)가 최종적으로 etcd에 기록됩니다.
- 여러 Control Plane 인스턴스가 동시에 접근해도 **강한 일관성(Strong Consistency)** 을 제공하며, 클러스터 관점에서는 **단일 진실 소스(Single Source of Truth)** 로 취급됩니다.
- 장애 복구·업그레이드 시 **etcd 백업 전략**이 매우 중요합니다.
- etcd는 “클러스터의 기억 장치”이고, API Server는 그 기억 장치에 읽고/쓰는 창구입니다.
- Controller/Scheduler/Kubelet은 API Server를 통해 상태를 읽고(또는 Watch 하고), 필요하면 다시 상태 변경을 요청합니다. etcd가 불안정해지면 **상태를 저장·갱신하는 관리 기능이 크게 제한**될 수 있습니다.

**모든 컴포넌트는 직접 통신하지 않고 API Server를 통해 상태를 공유합니다.**

### Worker Node

Worker Node는 실제 워크로드가 돌아가는 머신이며, **Kubelet**, **kube-proxy**, **Container Runtime**이 함께 동작합니다.

**Kubelet**은 각 노드에서 돌아가는 **에이전트**입니다.

- API Server로부터 “이 노드에서 실행해야 할 Pod” 스펙을 받아오고, **Container Runtime**을 호출해 컨테이너를 만들고 시작·중지합니다.
- Pod와 노드의 상태(리소스 사용, 프로브 결과 등)를 주기적으로 API Server에 보고해, Control Plane이 전체 클러스터 상태를 파악할 수 있게 합니다.

**kube-proxy**는 **Service**라는 추상 개념을 실제 네트워크 규칙으로 구현합니다.

- API Server로부터 Service와 Endpoints 정보를 받아, iptables나 IPVS 등으로 **Service IP → 실제 Pod IP** 로 트래픽이 전달되도록 설정합니다.
- Pod가 늘거나 줄거나 다른 노드로 옮겨져도, 클라이언트는 동일한 Service 이름·ClusterIP로 안정적으로 통신할 수 있습니다.

**Container Runtime**은 이미지를 내려받고, 컨테이너의 파일 시스템·네트워크를 준비한 뒤 **프로세스를 실제로 실행·종료**하는 소프트웨어입니다.

- Docker, containerd, CRI-O 등이 여기에 해당하며, Kubelet은 **CRI(Container Runtime Interface)** 라는 표준으로 런타임과 통신합니다.

Kubernetes는 Docker를 직접 사용하지 않고 containerd를 사용하는 경우가 많습니다. 불필요한 계층을 줄이고 성능을 높이기 위한 설계입니다.

### Kubernetes는 왜 containerd를 사용하는가?

“Kubernetes가 컨테이너를 돌린다며, 그럼 Docker로 실행해야 하는 거 아닌가?”

결론부터 말하면, **Kubernetes가 버린 것은 ‘Docker 이미지’가 아니라 ‘Docker Daemon을 거치는 실행 경로(dockershim)’**입니다.

과거(v1.23 이전)에는 보통 이런 구조였습니다.

```text
Kubelet → Docker Daemon → containerd → 컨테이너 실행
```

문제는 Docker가 “실행(Runtime)”만 하는 프로그램이 아니라는 점입니다. 이미지 빌드, 네트워크/볼륨 관리, 오케스트레이션(Swarm)까지 포함한 큰 프로그램이고, Kubernetes 입장에서는 **실행에 불필요한 중간 계층**이었습니다.

그래서 Kubernetes는 컨테이너 런타임과 통신하기 위한 표준 인터페이스를 만들었습니다.

- **CRI(Container Runtime Interface)**: Kubernetes가 런타임과 대화하는 표준 규격

현재(v1.24 이후)에는 구조가 이렇게 단순해지는 경우가 많습니다.

```text
Kubelet → CRI → containerd / CRI-O → 컨테이너 실행
```

즉 Kubernetes는 **Docker에서 필요한 ‘순수 실행 엔진’만 남긴 것**에 가깝습니다. Docker로 만든 컨테이너 이미지는 OCI(Open Container Initiative) 표준을 따릅니다.

```bash
# 개발 단계: Docker로 이미지 만들고 테스트
docker build -t my-app:1.0 .
docker run -p 8080:80 my-app:1.0

# 운영 단계: 레지스트리에 올린 뒤 Kubernetes에서 사용
# kubectl run my-app --image=my-app:1.0
```

역할을 나누면 이해가 쉽습니다.

- **Docker**: 개발 단계에서 이미지를 만들고 로컬에서 검증하기 좋다  
- **Kubernetes**: 운영 단계에서 그 이미지를 정책·자동화·복구·확장과 함께 관리한다  

### Control Plane의 고가용성(HA)

Control Plane을 여러 대로 구성하면(API Server 다중화), 하나의 서버가 죽더라도 전체 시스템은 계속 동작할 수 있습니다. 운영 환경의 Kubernetes는 보통 Control Plane을 여러 대로 두어 **고가용성(HA)** 을 확보합니다.

핵심은 다음입니다.

1. **API Server 다중화 + 로드 밸런서** — 사용자는 “마스터 여러 대”를 직접 알 필요가 없습니다. 로드 밸런서 주소 하나로 API Server 요청이 분산됩니다.
2. **etcd 클러스터(쿼럼) 구성** — 클러스터 상태는 etcd에 저장되므로, etcd도 보통 3개 이상(홀수)로 구성합니다. 과반(쿼럼)이 유지되어야 읽기/쓰기가 가능합니다.

Docker Swarm에도 클러스터 단위 이중화(HA)가 있습니다. Swarm의 HA는 주로 **Manager 노드 다중화 + Raft 합의(쿼럼)** 로 구현됩니다. Manager는 보통 홀수 개(3/5/7)로 구성하고, 과반이 살아 있어야 스케줄링·상태 변경이 정상 동작합니다.

둘 다 “관리 계층(Control Plane)을 다중화하고, 상태 저장소는 쿼럼 기반으로 운영한다”는 큰 방향은 같습니다. 차이는 Kubernetes가 Control Plane 구성 요소·API·생태계를 중심으로 더 폭넓은 운영 기능(정책/확장/도구)을 표준화해 제공한다는 점에서 나타납니다.

현실의 운영 환경은 보통 다음 그림에 가깝습니다.

```text
[Load Balancer]
    ↓
API Server (CP1) / API Server (CP2) / API Server (CP3)
    ↓
etcd (3개 이상, 쿼럼 기반)
    ↓
Worker Nodes (여러 대)
```

- etcd 3개 중 1개 장애 → 과반(2개) 유지 → 정상 동작  
- etcd 3개 중 2개 장애 → 과반 붕괴 → 읽기/쓰기 불가(클러스터 관리 기능 중단)  

그래서 운영에서는 보통 홀수 개(3/5/7)로 구성하고, 장애 허용치를 계산해 설계합니다.

---


## 동작 방식 — 서류를 내면 현장이 움직인다

구성 요소(등장인물)를 알았으니, 실제로 그 둘이 어떻게 맞물려 동작하는지 한 번에 연결합니다.

### Pod 생성 흐름

```text
1. Master(Control Plane)의 kube-apiserver에 Pod 생성을 요청한다
2. kube-apiserver는 etcd에 새로운 상태를 저장한다
3. kube-apiserver가 상태 변경을 확인하여, kube-controller-manager 쪽에 새로운 Pod가 필요함을 감지할 수 있게 한다
4. kube-controller-manager는 새 Pod(아직 노드 미할당)를 kube-apiserver에 요청하고, apiserver는 etcd에 저장한다
5. kube-scheduler는 노드 미할당 Pod를 확인하면, 조건에 맞는 Worker Node를 찾아 할당 정보를 kube-apiserver/etcd에 반영한다
6. 각 Worker Node의 kubelet은 자신에 할당되었지만 아직 생성되지 않은 Pod가 있는지 확인하고, 있으면 Pod를 생성한다
7. 해당 kubelet은 Pod 상태를 주기적으로 API Server에 전달한다
```

역할을 다시 분해하면 선명합니다.

- **Scheduler**: 배치만 한다  
- **Controller**: 개수·상태 유지만 한다  
- **Kubelet**: 실행만 한다  

### kubectl은 어디로 요청을 보내는가?

`kubectl`은 단순한 명령 모음이 아니라 **REST API 클라이언트**입니다. `kubectl get pods` 같은 명령은 내부적으로 API Server로 향하는 HTTPS 요청으로 바뀝니다.

연결의 열쇠가 **kubeconfig**입니다. kubectl은 kubeconfig를 읽어

- 어느 클러스터로 갈지 (API Server 주소: 운영에서는 보통 로드 밸런서 주소)
- 어떤 사용자/인증 정보로 접근할지
- 어떤 컨텍스트를 사용할지

를 결정합니다.

#### kubeconfig 형태

`kubeconfig`에는 크게 “클러스터 주소”, “사용자 인증 정보”, “컨텍스트(조합)”이 들어 있습니다.

```yaml
apiVersion: v1
kind: Config
clusters:
- name: my-cluster
  cluster:
    server: https://api.my-cluster.com:6443
users:
- name: my-user
  user:
    token: <token or cert>
contexts:
- name: my-context
  context:
    cluster: my-cluster
    user: my-user
current-context: my-context
```

#### kubectl과 REST API

| kubectl 명령 | 내부 REST API 예시 |
|---|---|
| `kubectl get pods` | `GET /api/v1/namespaces/default/pods` |
| `kubectl create -f pod.yaml` | `POST /api/v1/namespaces/default/pods` |
| `kubectl delete pod web-pod` | `DELETE /api/v1/namespaces/default/pods/web-pod` |

요청이 실제로 어디로 가는지 보려면 verbose를 켤 수 있습니다.

```bash
kubectl get pods -v=8
```

### 오해를 한 줄로 고쳐 두면

> “사용자가 `kubectl`로 명령을 내리면 Kubernetes가 즉시 어딘가에 ‘직접 명령’을 내려 Pod를 실행시킨다.”

실제로는 **직접 제어**가 아니라 **상태 저장과 상태 구독(Watch)** 기반입니다.

- 사용자는 `kubectl apply`로 원하는 상태를 제출합니다.
- API Server는 그 상태를 etcd에 저장합니다.
- Controller Manager는 상태를 구독하다가 Desired와 Current가 다르면 보정 요청을 남깁니다.
- Scheduler는 “어느 노드에 둘지”만 결정해 Pod 객체에 노드 정보를 기록합니다.
- Kubelet은 자신에게 할당된 Pod를 감지하면 컨테이너 런타임을 호출해 실행합니다.

흐름으로 보면 다음과 같습니다.

```text
[사용자]
kubectl apply -f deployment.yaml
    ↓
[API Server]
상태 저장 (etcd)
    ↓
[Controller Manager] (Watch)
Desired vs Current 비교 → Pod 생성 요청
    ↓
[API Server]
Pod 생성 (Pending)
    ↓
[Scheduler] (Watch)
Pending Pod 감지 → 노드 선택 → Pod 업데이트
    ↓
[Kubelet] (Watch)
할당된 Pod 감지 → 컨테이너 실행
    ↓
[API Server]
Pod 상태 갱신 (Running)
```

---


## 핵심 리소스 — 매일 만지는 도면들

Kubernetes를 처음 접할 때는 Control Plane/Worker Node 그림부터 보게 됩니다. 하지만 실무에서 개발자가 **매일 손으로 만지는 대상**은 인프라 구성 요소 그 자체보다, 서비스를 배포하기 위한 **리소스 객체**들입니다.

실무에서 “쿠버네티스에 배포한다”는 말은 보통 다음 **다섯 가지**를 조합한다는 뜻에 가깝습니다.

- **Deployment**: 애플리케이션 배포를 위한 상위 리소스. 롤링 업데이트·롤백 같은 배포 전략을 관리하며, 내부적으로 ReplicaSet을 생성·관리합니다.
- **Pod**: 애플리케이션 컨테이너가 실제로 실행되는 최소 단위입니다.
- **Service**: 여러 Pod를 하나의 논리적 서비스로 묶고, **고정된 서비스 IP(ClusterIP 등)** 와 로드밸런싱을 제공해 Pod IP가 바뀌어도 안정적으로 접근할 수 있게 합니다.
- **Ingress**: 애플리케이션 단의 네트워크 진입점. 도메인 기반 라우팅과 TLS 종료(HTTPS) 등을 담당해 외부 요청을 적절한 Service로 연결합니다.
- **Namespace**: 리소스를 팀/서비스/환경 단위로 구분하는 운영 경계입니다.

### Pod: 왜 컨테이너가 아닌 Pod인가

Docker에서는 컨테이너가 실행 단위입니다. Kubernetes에서는 Pod가 최소 단위입니다. “왜 컨테이너를 직접 실행하지 않는가?”라는 질문에 대한 답은, 실제 서비스에서 컨테이너가 단독으로만 동작하지 않는 경우가 많기 때문입니다.

예를 들어 하나의 API 서버는 메인 애플리케이션, 로그 수집기(sidecar), 보안 모듈처럼 **함께 실행되고 네트워크·스토리지를 공유해야 하는** 컨테이너로 구성될 수 있습니다. Kubernetes는 “컨테이너 하나”가 아니라 “함께 살아야 하는 컨테이너 묶음”을 최소 단위로 다루기 위해 Pod를 사용합니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-server
spec:
  containers:
  - name: api
    image: my-api:latest
  - name: log-agent
    image: fluentd:latest
```

Pod가 중요한 이유는 “함께 배치/함께 생명주기”뿐 아니라, **네트워크/볼륨 공유**가 자연스럽다는 점입니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: web
    image: nginx:latest
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  - name: app
    image: node:18
    volumeMounts:
    - name: shared
      mountPath: /app/public
  volumes:
  - name: shared
    emptyDir: {}
```

| 항목 | Docker Container | Kubernetes Pod |
|------|------------------|----------------|
| 최소 단위 | 컨테이너 1개 | 컨테이너 1개 이상 |
| 네트워크 | 컨테이너마다 독립 | Pod 내 컨테이너 공유 |
| 볼륨 | 개별 구성 | Pod 단위로 공유 가능 |
| 생명주기 | 독립 | 함께 시작/종료 |

Pod의 특징을 다시 나열하면 다음과 같습니다.

- 동일 노드 배치  
- localhost 통신  
- 볼륨 공유  
- 동일 생명주기  

즉 Kubernetes는 컨테이너를 직접 다루기보다, 컨테이너를 그룹화한 단위(Pod)를 관리합니다.

### Deployment: 상태 유지와 자동 복구

Deployment는 Pod를 직접 한 번 실행하는 객체가 아니라, **원하는 상태를 정의해 “항상 그 상태가 유지되게 만드는”** 역할을 합니다. `replicas: 3`은 단순한 숫자가 아니라 운영 정책에 가깝습니다. Kubernetes는 “언제나 3개의 Pod가 떠 있어야 한다”는 Desired State를 가지고, Current State가 그보다 적어지면 자동으로 보정합니다.

Pod가 하나 죽으면:

- Controller가 감지  
- 새로운 Pod 생성  
- 상태 복구  

사람이 개입하지 않아도 자동으로 이루어질 수 있습니다. 이미지 버전을 변경하면 롤링 업데이트로 이어지는 경우가 많습니다.

#### Self-Healing의 디테일: Liveness / Readiness Probe

자동 복구를 현실적으로 보면, Kubernetes는 Pod 개수만 맞추는 것이 아니라 “정상 상태”를 기준으로 조치합니다. 자주 쓰이는 장치가 **Probe(헬스체크)** 입니다.

- **Liveness Probe**: 컨테이너가 “살아 있는가?” (실패하면 재시작)
- **Readiness Probe**: 컨테이너가 “요청을 받을 준비가 되었는가?” (실패하면 트래픽에서 제외)

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

장애가 반복될 때는 이벤트로 원인을 추적할 수 있습니다.

```bash
kubectl get events
```

### Service: 서비스 연결 단위

> Service는 계속 변하는 Pod 집합 앞단에 안정적인 진입점(고정 가상 IP/이름)을 제공하는 리소스입니다.

- 레이블 셀렉터로 대상 Pod들을 동적으로 묶고, kube-proxy(iptables/IPVS)가 생성한 규칙을 통해 트래픽을 해당 Pod들로 로드밸런싱합니다.
- 클러스터 내부에서는 DNS(`my-svc.my-namespace.svc.cluster.local`)로 서비스 디스커버리가 이루어지며, Pod의 생성·삭제로 IP가 바뀌어도 클라이언트는 동일한 Service 이름/ClusterIP로 접근할 수 있습니다.
- 용도에 따라 ClusterIP(기본, 내부 전용), NodePort(각 노드의 고정 포트로 노출), LoadBalancer(클라우드 LB와 연동해 외부에 공개), Headless(`clusterIP: None`, 개별 Pod 직접 해석) 형태로 동작합니다. 필요 시 세션 어피니티(ClientIP), 여러 포트 정의, Headless + StatefulSet 조합 같은 고급 패턴도 구성할 수 있습니다.

예시(Service: ClusterIP):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - name: http
      port: 80        # 클라이언트가 접근하는 서비스 포트
      targetPort: 8080 # Pod 컨테이너가 실제로 리스닝하는 포트
      protocol: TCP
```

요약하면 `selector`가 Pod 집합을 정하고, `port`→`targetPort`로 트래픽이 전달되며, `type`으로 노출 범위를 결정합니다.

### Ingress: 외부 진입 단위

Service는 클러스터 내부에서 Pod로 안정적으로 연결되는 “고정된 접근점”을 만들어 주지만, 외부(인터넷)에서 들어오는 요청까지의 경로는 별도 구성이 필요합니다. Ingress는 “어떤 도메인/경로로 들어온 요청을 어떤 Service로 보낼지”를 정의하는 라우팅 계층이며, **도메인 기반 라우팅**과 **TLS 종료(HTTPS 인증서 처리)** 같은 기능을 담당합니다.

> Ingress 리소스만 만든다고 바로 동작하는 것은 아니고, 실제 트래픽을 받아 처리하는 Ingress Controller(NGINX Ingress, Traefik 등)가 클러스터에 함께 배포되어 있어야 합니다.

Ingress와 Ingress Controller는 역할과 위치가 다릅니다.

- **Ingress**: Kubernetes API에 저장되는 **라우팅 규칙(설정) 리소스**입니다. “어떤 도메인/경로를 어떤 Service로 보낼지” 같은 선언(Desired State) 자체이며, Control Plane(etcd)에 객체로 기록됩니다.
- **Ingress Controller**: Ingress 규칙을 Watch 하다가 실제 L7 프록시/로드밸런서 설정으로 변환해 적용하는 **실행 컴포넌트**입니다. 보통 Worker Node에 Pod(Deployment/DaemonSet)로 떠서 외부 트래픽을 직접 받고, 규칙에 따라 Service로 전달합니다.

정리하면, **Ingress는 설정(리소스)** 이고 **Ingress Controller는 그 설정을 실제 트래픽 처리로 구현하는 실행체**입니다.

### Namespace: 운영 경계 단위

지금까지의 Pod, Deployment, Service, Ingress는 모두 Kubernetes API 객체입니다. Namespace는 이 객체들을 클러스터 안에서 팀/서비스/환경 단위로 구분하기 위한 **논리적 경계**입니다.

핵심은 “클러스터를 물리적으로 나누지 않고도 운영 경계를 만들 수 있다”는 점입니다.

- 같은 이름의 리소스도 Namespace가 다르면 공존할 수 있습니다.
- 권한(RBAC), 쿼터(ResourceQuota), 기본 제한(LimitRange) 같은 운영 정책을 Namespace 단위로 나눌 수 있습니다.
- Service 디스커버리도 Namespace를 포함해 동작합니다.  
  예: `web.default.svc.cluster.local`, `web.prod.svc.cluster.local`

리소스 식별은 사실상 `namespace/name` 조합으로 이해하는 것이 안전합니다.

- `default/web`  
- `prod/web`  

실무에서는 같은 클러스터 안에서도 `dev`, `staging`, `prod` 같은 Namespace를 분리해 쓰는 경우가 많습니다. 이름 충돌을 피하고, 권한과 정책을 환경별로 나눌 수 있습니다.

```bash
# 특정 네임스페이스 조회
kubectl get pods -n prod

# 리소스 적용 시 네임스페이스 지정
kubectl apply -f deploy.yaml -n staging

# 현재 컨텍스트의 기본 네임스페이스 변경
kubectl config set-context --current --namespace=dev
```

Namespace는 “클러스터를 나누는 최소 운영 단위”이며, 객체를 실제 운영에서 안전하게 구분·관리하기 위한 기본 장치입니다.

### 리소스 간 연결 관계(요청 흐름과 관리 흐름)

처음에는 Pod, Deployment, Service, Ingress가 각각 별개처럼 보이지만, 실제 운영에서는 서로 다른 책임을 맡아 하나의 요청 경로를 완성합니다.

- **Pod**: 애플리케이션 컨테이너가 실제로 실행되는 최소 단위  
- **Deployment**: 원하는 개수/업데이트 전략을 기준으로 Pod 집합을 관리  
- **Service**: Pod 집합 앞단의 안정적인 접근점(고정 이름/IP)과 내부 로드밸런싱  
- **Ingress**: 외부 요청(도메인/경로/TLS)을 어떤 Service로 보낼지 라우팅 규칙  

요청 흐름을 트래픽 관점에서 보면 다음과 같습니다.

1. 사용자 요청이 들어오면 **Ingress Controller**가 Ingress 규칙을 확인합니다.  
2. 규칙에 매칭된 대상 **Service**로 요청을 전달합니다.  
3. Service는 selector로 연결된 Pod 집합 중 하나를 선택해 로드밸런싱합니다.  
4. 선택된 **Pod**가 요청을 처리하고 응답을 반환합니다.  
5. Pod 집합의 개수와 업데이트 상태는 **Deployment(내부적으로 ReplicaSet)** 가 계속 유지합니다.  

즉 트래픽 경로는 보통 **Ingress → Service → Pod**이고, Deployment는 그 경로 뒤에서 “처리 주체(Pod 집합)”를 안정적으로 유지합니다.

> **Namespace** 관점을 함께 보면, 위 관계는 네임스페이스 경계 안에서 먼저 성립합니다. Service는 기본적으로 같은 Namespace의 Pod를 selector로 찾으므로, 동일한 `web` 이름이라도 `default/web`와 `prod/web`는 서로 다른 대상입니다.

이 관계를 이해할 때는 Deployment와 Service의 최소 형태를 보는 것이 가장 빠릅니다.

**1) Deployment 최소 예시**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:latest
```

**2) Service 최소 예시**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

핵심은 **Deployment와 Service가 직접 연결되는 것이 아니라 Pod의 label로 간접 연결**된다는 점입니다. Deployment는 Pod 템플릿(`spec.template.metadata.labels`)에 `app: web`을 붙여 Pod를 만들고, Service는 `spec.selector`로 같은 라벨을 가진 Pod 집합을 찾아 트래픽을 전달합니다.

- Deployment가 만드는 Pod 라벨: `app: web`  
- Service selector: `app: web`  
- 결과: Service가 Deployment가 생성한 Pod들을 자동으로 엔드포인트로 묶음  

Pod가 교체되어 IP가 바뀌어도, 라벨만 일치하면 Service가 새 Pod를 찾아 연결합니다.

자주 헷갈리는 세 칸을 구분해 두면 초반 실수가 줄어듭니다.

- `spec.selector.matchLabels` (Deployment): **내가 관리할 Pod 집합을 고르는 기준**  
- `spec.template.metadata.labels` (Deployment): **앞으로 생성될 Pod에 실제로 붙일 라벨** (보통 matchLabels와 같게)  
- `metadata.labels` (리소스 최상단): 해당 객체 자체를 검색·분류하기 위한 메타 라벨 (Pod 매칭의 주인공은 아님)  

이 조합이 익숙해지면, Kubernetes에서 “배포한다”는 말은 결국 **Deployment와 Service를 정의하고 적용하는 것**으로 체감되기 시작합니다.

---


## 정리

- Kubernetes는 여러 서버(Node)에서 Pod를 자동으로 배포·복구·확장하는 컨테이너 오케스트레이션 플랫폼이다.
- 실무의 핵심은 인프라 구성 요소 자체보다 `Pod` / `Deployment` / `Service` / `Ingress` / `Namespace` 같은 리소스를 조합해 서비스를 운영하는 것이다.
- 트래픽 경로는 보통 **Ingress → Service → Pod**이며, Deployment는 그 뒤에서 Pod 개수·업데이트 상태를 원하는 상태로 유지한다.
- Deployment와 Service는 직접 연결되지 않고 Pod 라벨로 간접 연결된다. `spec.template.metadata.labels`와 `Service.spec.selector`가 일치할 때 트래픽이 정상 전달된다.
- `spec.selector.matchLabels`(관리 대상 선택), `spec.template.metadata.labels`(생성될 Pod 라벨), `metadata.labels`(리소스 메타 라벨)의 역할을 구분해 이해해야 운영 실수를 줄일 수 있다.
- Namespace는 클러스터 안의 운영 경계 단위이며, 동일 이름 리소스 공존, 권한(RBAC)/쿼터/정책 분리, DNS 스코프(`service.namespace.svc.cluster.local`) 구분의 기준이 된다.
- Control Plane은 API Server를 중심으로 상태를 공유하며, etcd에 클러스터 상태를 저장하고 Scheduler / Controller Manager가 Watch 기반으로 Desired State를 유지한다.
- Worker Node는 Kubelet(실행), kube-proxy(Service 네트워크 규칙), Container Runtime(컨테이너 실행)이 협력해 실제 Pod/컨테이너를 동작시킨다.
- Controller / Control Loop는 Current State와 Desired State의 차이를 Reconcile하며, 이것이 Self-Healing과 자동 복구의 핵심 메커니즘이다.
- Liveness / Readiness Probe는 “정상” 기준을 정의해 재시작·트래픽 제외를 자동화하고, 장애 시 `kubectl get events` 같은 관찰 명령으로 원인을 추적할 수 있다.
- 선언형 운영의 핵심은 `kubectl apply`로 원하는 상태를 선언하고 `get` / `describe` / `logs` / `rollout` / `events`로 현재 상태를 검증·조정하는 반복 루프를 만드는 것이다.
- 결론적으로 Kubernetes의 본질은 “리소스를 선언하고, 시스템이 상태를 수렴시키도록(Reconcile) 설계된 운영 플랫폼”이라는 점이다.

---


## 다음 주로 넘어가기 전에

이전 글에서 손으로 느낀 Docker 운용의 빈칸과, 이번 글에서 잡은 선언형·제어 루프·구성 요소·동작 흐름·핵심 리소스를 이어 두면, 이후 주차의 실습이 “명령 암기”가 아니라 **선언을 맞추고 관찰하는 연습**으로 읽히기 시작합니다. 다음 글부터는 이 도시 운영을 실제로 돌리며, 창구 뒤에 남은 이름들을 하나씩 만집니다.

---

<!-- draft: AboutKubernetes full coverage; philosophy as list without manifests; order philosophy → components → behavior → resources -->
