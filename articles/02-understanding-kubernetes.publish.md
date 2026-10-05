<!--
  게시용 복사본입니다. GitHub Flavored Markdown용이며, 이미지 경로는 GitHub raw URL입니다.
  원본(로컬 미리보기용): 02-understanding-kubernetes.draft.md
  이미지 저장소: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap02. Kubernetes의 설계 철학

> 15주 연재의 둘째 글입니다. Kubernetes의 설계 철학인 선언형, 제어 루프, Watch 기반 통신을 중심으로, 그 철학이 API와 클러스터에서 어떻게 이어지는지를 개략적으로 정리합니다.

## 들어가며

![Kubernetes 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/01-k8s-logo.svg)

1장에서는 컨테이너와 Docker가 실행 환경을 일관되게 만드는 방법을 살펴보았습니다. 실습에서는 컨테이너를 실행한 뒤에도 중지된 컨테이너를 다시 실행하고, 복제본을 늘리고, 이미지를 교체하는 작업이 필요하다는 점을 확인했습니다. 컨테이너를 실행하는 일과 애플리케이션의 운영 상태를 유지하는 일은 서로 다릅니다.

Kubernetes는 사용자가 원하는 상태를 선언하면 실제 상태를 그 선언에 맞추는 방식으로 이러한 운영 작업을 관리합니다. 이를 이해하려면 각 구성 요소의 이름을 외우기 전에, 사용자의 선언을 어떻게 공유하고 실제 상태와의 차이를 어떻게 줄이는지 살펴볼 필요가 있습니다.

이번 글에서는 선언형, 제어 루프, 상태 변화 구독(Watch)이라는 세 가지 설계 원리를 중심으로 Kubernetes를 알아봅니다. 이어서 API와 클러스터의 구성 요소가 이 원리를 어떻게 구현하는지, 사용자의 선언이 Pod 실행으로 어떻게 이어지는지 살펴봅니다. 마지막으로 1장의 수동 운영 작업을 Kubernetes의 명령과 비교합니다.

## 1. Kubernetes의 위치와 인기

Kubernetes는 **컨테이너 오케스트레이션**(Container Orchestration) 플랫폼입니다. 컨테이너 오케스트레이션이란, 컨테이너를 실행하는 일에 그치지 않고 배치와 컨테이너 개수 유지, 장애 복구, 트래픽 분배까지 **자동화하는 시스템**을 말합니다. Kubernetes는 이러한 운영 작업을 여러 서버에 걸쳐 조율하는 오픈소스 플랫폼입니다. [[1]](#ref-1)

2014년 공개된 뒤 전 세계 기여자가 코드를 쌓아 왔고, 주요 클라우드는 Kubernetes를 관리형으로 제공하며 같은 모델을 로컬에서도 돌릴 수 있습니다. 어디에서 실행하든 비슷한 운영 방식을 공유한다는 점이, 사실상의 표준으로 받아들여진 이유 중 하나입니다.

![Kubernetes 주변 생태계](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/02-k8s-ecosystem.svg)

인기의 배경에는 이식성도 있습니다. Kubernetes를 전제로 만든 애플리케이션은 환경이 바뀌어도 같은 선언 방식으로 배포를 시도할 수 있습니다. 동시에 배포, 모니터링, 네트워크를 돕는 도구들이 Kubernetes 주변에 모여, 운영에 필요한 기능을 제공합니다. 패키징 도구, 배포 파이프라인, 모니터링 도구 등이 그 생태계를 이룹니다.

그렇다고 배우기 쉽다는 뜻은 아닙니다. 처음에는 이름과 설정 파일이 많아 “왜 이렇게 복잡하지?”가 먼저 나오기 쉽습니다. 조금 익숙해지면 “이런 것까지 되는구나” 쪽으로 질문이 바뀌는 경우가 많습니다. 이 글은 그 순서에 맞춰, 곧바로 모든 이름을 외우기보다 **필요성, 설계 철학, 핵심 개념, 선언이 실제로 실행되기까지, 명령어로 살펴보기**를 따라갑니다.

## 2. Docker만으로 부족한 것

이전 글에서 이미 느꼈듯, 컨테이너를 여러 개 실행하는 것 자체는 어렵지 않습니다. 어려운 부분은 **운영 판단과 정책**입니다. Docker의 등장 이후 컨테이너는 실행 환경을 표준화하는 핵심이 되었고, Dockerfile로 환경을 코드처럼 남길 수 있게 되었습니다.

```bash
# Docker로 이미지를 만들고 실행하는 기본 흐름을 상기하는 예시
docker build -t my-app:1.0 .
docker run -p 8080:80 my-app:1.0
```

같은 이미지로 로컬, 테스트, 운영 환경을 맞출 수 있게 되면서 환경 불일치 문제는 크게 줄었습니다. Docker Compose로 여러 컨테이너를 한 애플리케이션처럼 묶을 수 있고, Docker Swarm으로 여러 서버에 분산하는 것도 가능해졌습니다. 여기서 다음과 같은 질문을 할 수 있습니다.

“Docker Compose나 Docker Swarm으로도 충분하지 않은가? Kubernetes는 왜 필요한가?”

> Docker는 “컨테이너를 실행하는 도구”이고, Kubernetes는 “컨테이너가 실행되는 전체 시스템을 관리하는 **오케스트레이션 플랫폼**”입니다.

![Docker 계열과 Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/21-docker-tools-vs-k8s.svg)

Compose나 Swarm으로 운영 요구를 충족한다면 Kubernetes가 반드시 필요한 것은 아닙니다. 차이를 이해하려면 컨테이너를 늘리는 기능뿐 아니라, 언제 얼마나 늘릴지를 누가 판단하는지 살펴봐야 합니다.

트래픽이 급증할 때 Swarm에서는 관리자가 직접 서비스 복제본 수를 늘리는 경우가 많습니다.

```bash
# Swarm에서는 확장을 사람이 직접 지시함을 보이는 예시
docker service scale web=10
```

확장은 가능하지만, **컨테이너를 언제 몇 개까지 늘리고 줄일지**의 판단은 사람이 담당합니다. Kubernetes에서는 CPU 사용률 같은 조건을 정책으로 남겨 두고, 그 이후의 확장 판단과 실행을 플랫폼에 맡길 수 있습니다. 예를 들어 “CPU 사용률 70%를 넘으면 컨테이너 복제본을 자동으로 늘려라”는 식의 목표만 정의해 두면 됩니다.

장애 복구도 운영 설정에 따라 달라집니다. Docker에서도 재시작 정책을 사용하면 종료된 컨테이너를 같은 서버에서 다시 실행할 수 있고, Swarm은 여러 서버에 걸친 복제본 유지도 담당합니다. Kubernetes는 컨테이너의 재시작과 복제본 유지, 서버 장애 대응을 각 구성요소가 나누어 처리합니다. 컨테이너 하나의 종료와 서버 전체의 장애는 복구 경로가 다릅니다.

배포 과정에서도 Pod를 점진적으로 교체하거나 이전 구성으로 되돌리는 정책을 선언할 수 있습니다. 트래픽 일부만 새 버전에 보내는 배포처럼 더 복잡한 방식은 요청을 전달하는 구성요소나 별도 배포 도구와 함께 구현합니다. Kubernetes의 운영 범위를 이해할 때는 기본 기능과 추가 구성이 필요한 기능을 구분해야 합니다.

이처럼 운영 판단을 정책으로 남기려면, 사용자가 선언한 목표를 플랫폼이 지속적으로 확인하는 구조가 필요합니다.

## 3. Kubernetes의 대표 설계 철학

오케스트레이션을 “누가 무엇을 자동으로 하느냐”로만 보면 이름이 많아 보입니다. 먼저 Kubernetes가 지키려는 약속을 세 가지로 묶어 두면, 뒤의 핵심 개념이 같은 흐름으로 읽힙니다. 아래에서는 각 철학을 한 문장으로 먼저 짚고, 이어서 설명합니다.

### 3.1 선언형과 원하는 상태

Docker에서는 흔히 이렇게 실행합니다.

```bash
# 명령형 실행: 지금 당장 기동하라고 지시하는 Docker 예시
docker run -d nginx
```

이 명령은 “어떻게 실행할 것인가”를 지시합니다. 명령 자체가 실행 이후의 상태까지 계속 관리하지는 않습니다. 이런 방식을 **명령형**(Imperative)이라고 부릅니다.

Kubernetes에서는 원하는 상태를 보통 **YAML**(들여쓰기로 구조를 표현하는 설정 파일 형식)로 작성합니다. API에 제출할 이 선언을 **매니페스트**(manifest)라고 부릅니다. **리소스**(resource)는 Kubernetes API로 관리하는 대상이며, 매니페스트는 그 대상을 생성하거나 변경하기 위한 입력입니다. 복제본 세 개를 유지한다는 목표는 매니페스트의 `replicas: 3`으로 표현할 수 있습니다.

```yaml
# 원하는 상태를 YAML 매니페스트로 남기는 예시
replicas: 3
```

![Desired State와 실제 상태](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/04-desired-state.svg)

이 선언의 핵심은 **원하는 상태**(Desired State)입니다. “지금은 무엇이 몇 개 떠 있는가”가 아니라 **“이렇게 되어 있기를 바란다”**를 적어 둔 목표입니다. Docker Compose의 YAML처럼 목표를 적고 플랫폼에 넘깁니다. 차이는 설정을 넘긴 뒤의 책임에 있습니다. [[2]](#ref-2)

한 번의 실행 방법을 지시하는 대신 “앞으로도 복제본 세 개를 유지한다”는 목표를 남기는 방식이 **선언형**(Declarative)입니다.

설정을 파일로 남기면 변경 내용을 검토하고 이전 설정과 비교하기도 쉽습니다. 예를 들어 복제본 개수를 3에서 5로 바꾸는 작업을 Git에 기록하면, 누가 어떤 운영 설정을 바꾸었는지 확인할 수 있습니다. 파일을 수정한 뒤에는 변경된 선언을 클러스터에 제출해야 실제 설정에 반영됩니다.

### 3.2 제어 루프

![Control Loop](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/05-control-loop.svg)

**제어 루프**(Control Loop)는 실행 중인 **현재 상태**(Current State)를 관찰하고, 사용자가 선언한 원하는 상태와의 차이를 줄이는 과정을 반복하는 동작 방식입니다. 차이를 줄이는 한 번의 맞춤 동작을 **보정**(Reconcile)이라고 부릅니다.

제어 루프는 상태를 한 번 확인하고 끝내지 않습니다. 필요한 변경을 요청한 뒤 그 결과를 다시 관찰하므로, 이후에 장애나 설정 변경이 발생해도 새로운 차이를 발견할 수 있습니다. [[3]](#ref-3)

예를 들어 복제본 세 개를 유지하는 설정에서 하나가 사라지면, 복제본을 관리하는 프로세스가 부족한 실행 단위 하나의 생성을 요청합니다. 실행할 서버가 선택되고 해당 서버에서 새 복제본이 실행되면 개수가 다시 세 개가 됩니다. 장애로 달라진 상태를 자동으로 복구하는 이런 동작을 **셀프 힐링**(self-healing)이라고 합니다.

### 3.3 이벤트 기반 통신

복제본 개수를 관리하는 프로세스, 실행할 서버를 선택하는 프로세스, 컨테이너 실행을 관리하는 프로세스는 서로 다른 일을 맡습니다. 이들이 작업을 이어 가는 기준은 공유된 상태의 변화입니다. 상태 변화를 구독해 전달받는 방식을 **Watch**라고 합니다.

왜 이렇게 만드는지는, **직접 호출**과 **공유 상태 + Watch**를 비교하면 분명해집니다.

![직접 호출과 Watch 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/15-direct-vs-watch.svg)

그림의 **직접 호출** 방식은 한 프로세스가 다음 프로세스를 호출해 작업을 넘기는 구조입니다. 호출받을 프로세스가 중단되면 그 단계에서 작업 전달을 기다려야 합니다.

**공유 상태와 Watch**를 사용하는 방식에서는 필요한 작업을 상태로 기록하고, 각 프로세스가 자신이 담당하는 변화를 확인합니다. 실행할 서버를 선택하는 프로세스가 중단되면 새로운 배치는 기다려야 하지만, 기록된 요청은 남아 있으므로 복구 후 다시 처리할 수 있습니다. 이미 실행 중인 작업을 관리하는 다른 프로세스는 담당 업무를 계속 수행할 수 있습니다.

여기서 중요한 점은 모든 통신이 없어지는 것이 아니라, 앞 단계의 결과를 공유 상태에 남겨 각 프로세스가 확인한다는 것입니다. Kubernetes에서는 상태를 조회하고 변경하는 창구인 **API Server**를 통해 이 정보를 공유합니다.

이제 상태를 공유하는 창구와, 각 작업을 담당하는 실제 구성요소를 살펴보겠습니다.

## 4. Kubernetes의 핵심 개념

앞에서 Docker, Docker Compose, Docker Swarm의 역할을 정리했습니다. Kubernetes는 그 연장선에서, **여러 서버에 흩어진 컨테이너의 운영을 자동화하는 플랫폼**으로 이해하면 됩니다.

![Kubernetes API와 클러스터](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/03-k8s-cluster.svg)

실무에서 가장 자주 만나는 핵심은 두 가지입니다.

첫째는 **API**입니다. API는 사용자가 클러스터에 “원하는 상태”를 전달하는 **진입점**입니다. “웹 컨테이너를 세 개 유지해 달라”, “이 이미지로 애플리케이션을 돌려 달라” 같은 요청을 API로 보냅니다. 진입점이 하나라는 점이 중요합니다. 서버마다 따로 접속하지 않아도, 같은 API로 클러스터 운영을 요청할 수 있습니다.

이 API에 요청을 보낼 때 사용하는 대표적인 도구가 **kubectl**입니다. kubectl은 Kubernetes API를 호출하는 **명령줄 클라이언트**입니다. 터미널에서 조회와 적용 명령을 실행하면, 그 명령이 내부적으로는 API 요청이 됩니다.

둘째는 **클러스터**(Cluster)입니다. 클러스터는 여러 컴퓨터를 **하나의 논리 단위**로 묶어, 그 요청이 실제로 실행되는 범위입니다. 클러스터를 이루는 개별 서버가 **노드**(Node, 클러스터에 참여하는 서버)입니다. Docker Swarm이 여러 서버를 하나의 클러스터로 묶었다면, Kubernetes의 클러스터도 비슷하게 여러 노드를 한 덩어리로 다룹니다. 다만 그 위에 운영 정책과 자동화 규칙을 더 많이 둡니다. 노드가 늘거나 줄어도, 사용자는 보통 특정 서버를 지정하기보다 클러스터 전체에 “이런 상태로 유지해 달라”고 요청합니다. 클라우드에서는 이런 클러스터를 직접 만들지 않고, 관리형 서비스로 받아 쓰는 경우도 흔합니다.

실행 단위도 구분할 필요가 있습니다. Docker에서는 보통 **컨테이너 하나**가 실행 단위였습니다. Kubernetes에서는 그 단위를 한 단계 넓혀, 하나 이상의 컨테이너를 **함께 배치하고 함께 관리하도록** 묶은 **Pod**(파드)를 최소 실행 단위로 씁니다. 같은 Pod 안의 컨테이너는 네트워크와 생명주기를 공유합니다. 클러스터가 배치하고 삭제하는 단위가 Pod라는 점만 먼저 알아 두면 됩니다. [[4]](#ref-4)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-pod.png" alt="여러 컨테이너를 함께 묶는 Pod" width="40%" />

그림의 두 컨테이너는 하나의 Pod에 속하므로 서로 다른 Node에 나뉘어 배치되지 않습니다.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-node.png" alt="여러 Pod를 실행하는 Node" width="40%" />

그림처럼 한 Node에 여러 Pod가 배치되면, 각 Pod 안의 컨테이너 프로세스가 해당 서버의 CPU와 메모리를 사용합니다.

매니페스트를 API에 제출하면, 플랫폼이 그 내용을 읽고 어느 노드에 앱을 올릴지 정합니다. 각 구성 요소는 앞에서 살펴본 제어 루프를 통해 원하는 상태와 실제 상태의 차이를 줄입니다. 애플리케이션이 Node.js든 Go든, Kubernetes 입장에서는 컨테이너 이미지와 매니페스트가 중요합니다. 언어가 달라도 같은 API와 매니페스트 방식으로 운영을 요청할 수 있다는 점이, 팀 규모가 커질 때 특히 도움이 됩니다.

이제 API와 클러스터 뒤에서, **어느 서버에서 어떤 프로세스가 일을 하는지**를 살펴보겠습니다. 실제 Pod가 실행되는 **Worker Node**를 먼저 보고, 판단을 맡는 **Control Plane**을 이어서 보겠습니다.

클러스터는 크게 **Worker Node**(워커 노드, 실제 Pod가 실행되는 서버)와 **Control Plane**(컨트롤 플레인, 클러스터를 제어하는 구성 요소)으로 나뉩니다.

![Kubernetes 구성 요소](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/06-k8s-components.svg)

### 4.1 Worker Node

Worker Node에서는 아래 프로세스들이 컨테이너 실행과 네트워크 설정을 담당합니다.

**Kubelet**은 각 노드에서 실행되는 **에이전트**(API와 통신하며 해당 노드의 Pod 실행을 관리하는 프로세스)입니다. “이 노드에서 실행해야 할 Pod”를 API에서 받아오고, 아래에서 볼 Container Runtime을 호출해 컨테이너를 만들고 시작하거나 중지합니다. Pod와 노드 상태는 다시 API Server에 보고합니다.

**Container Runtime**은 이미지를 내려받고 컨테이너 프로세스를 **실제로 실행하고 종료하는** 소프트웨어입니다. containerd, CRI-O 등이 여기에 해당하며, Kubelet은 **CRI**(Container Runtime Interface, 런타임과 대화하는 표준 규격)로 런타임과 통신합니다.

**kube-proxy**는 **안정적인 진입점**(변하는 Pod 집합 앞에 두는 고정 이름과 주소)을 실제 네트워크 규칙으로 구현합니다. 그 진입점에 연결된 Pod 주소 정보를 받아, 고정 주소로 들어온 요청이 실제 Pod IP로 전달되도록 설정합니다.

### 4.2 Control Plane

Control Plane은 클러스터를 **제어하는 구성 요소**입니다. Desired State를 해석하고 유지하며, Pod를 어느 노드에 둘지 결정하는 등의 판단을 담당합니다. 대표적으로 API Server, Scheduler, Controller Manager, etcd가 여기서 동작합니다. [[5]](#ref-5)

**API Server**는 Kubernetes의 **중앙 API**입니다. 앞에서 본 `kubectl`의 호출과, Worker의 Kubelet, kube-proxy를 포함한 다른 구성 요소의 요청이 모두 이곳을 거쳐야 합니다. 그래야 클러스터 상태를 조회하거나 바꿀 수 있습니다. 누가 요청했는지, 무엇을 할 수 있는지(인증과 인가)와 형식 검사를 수행한 뒤, 변경 내용을 아래의 상태 저장소에 반영합니다.

**etcd**는 리소스의 선언과 상태를 보관하는 데이터베이스입니다. API Server는 이 저장소에 내용을 읽고 씁니다. 여러 구성요소는 etcd에 직접 접근하는 대신 API Server를 통해 필요한 정보를 확인합니다.

**Scheduler**(스케줄러)는 아직 노드가 정해지지 않은 Pod를 확인하고, 각 Worker 노드의 자원 여유와 배치 제약을 고려해 **어느 노드에 둘지**만 결정합니다. 컨테이너 실행은 Worker Node의 Kubelet과 런타임이 담당합니다.

**Controller Manager**는 여러 **컨트롤러**(controller, 원하는 상태를 유지하려고 제어 루프를 실행하는 프로세스)를 한 프로세스에서 묶어 실행합니다. Pod 복제본 개수, 노드 상태처럼 대상마다 컨트롤러가 있고, API Server의 리소스를 Watch 하면서 Desired와 Current가 다르면 차이를 줄이는 보정(Reconcile)을 **요청**합니다. 노드에 직접 접속하지 않고 API에 상태 변경을 남기는 방식입니다.

이 구성에서 Scheduler는 배치 위치를 결정하고, Controller Manager는 필요한 리소스 변경을 요청하며, Kubelet은 자신이 담당하는 Node의 실행 상태를 관리합니다.

## 5. 선언부터 Pod 실행까지의 경로

앞에서 API, 클러스터, Control Plane, Worker Node의 이름을 알아보았습니다. 이제는 그 구성 요소들이 **하나의 요청 경로**에서 어떻게 맞물리는지를 봅니다. 사용자가 원하는 상태를 남기면, 그 선언이 실제로 Pod와 컨테이너 실행까지 이어지는 순서를 따라갑니다.

### 5.1 kubectl의 API 연결

![kubectl과 kubeconfig](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/09-kubectl-kubeconfig.svg)

```yaml
# kubectl이 어느 클러스터에 어떤 사용자로 붙을지 정하는 kubeconfig 예시
apiVersion: v1
kind: Config
clusters:
- name: my-cluster
  cluster:
    server: https://api.my-cluster.com:6443
users:
- name: my-user
  user:
    token: <token>
contexts:
- name: my-context
  context:
    cluster: my-cluster
    user: my-user
current-context: my-context
```

위 **kubeconfig**는 kubectl이 접속할 클러스터와 사용자 인증 정보를 지정하는 설정 파일입니다.

- `clusters`: 접속할 클러스터의 API Server 주소를 지정합니다.
- `users`: 접속할 때 사용할 사용자 인증 정보를 지정합니다.
- `contexts`: 사용할 클러스터와 사용자를 하나의 연결 설정으로 묶습니다.
- `current-context`: 현재 사용할 연결 설정의 이름입니다.

kubectl은 이 설정을 읽어 선택된 API Server에 HTTPS 요청을 보냅니다. [[6]](#ref-6)

선언이 Pod 실행으로 이어지는 과정을 이해하려면 상태를 저장하고 공유하는 구조를 먼저 알아야 합니다. Kubernetes는 상태를 저장하고, 각 구성 요소는 그 상태의 변화를 구독합니다.

### 5.2 상태 저장과 Watch

![상태 저장과 Watch](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/10-state-and-watch.svg)

위 그림은 API Server가 요청 내용을 저장하고, 각 구성요소가 Watch로 변경 정보를 받는 관계를 보여 줍니다. 이제 복제본 수를 유지하는 선언이 제출된 상황을 기준으로, 누가 어떤 정보를 확인하는지 순서대로 살펴보겠습니다. [[7]](#ref-7)

![구성 요소 동작 시퀀스](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/09-pod-creation-sequence.svg)

아래는 “원하는 상태를 남긴 뒤, Pod가 한 노드에서 실행될 때까지”를 네 단계로 나눈 순서입니다. 그림의 번호와 본문 번호는 같습니다.

1. **사용자가 선언을 남깁니다.** kubectl이 API Server에 원하는 상태를 보냅니다. API Server는 검사한 뒤, 그 내용을 **etcd**에 기록합니다. 이후 구성요소들은 이 저장된 선언을 기준으로 작업합니다.
2. **Controller Manager가 Pod 개수를 맞춥니다.** Controller Manager는 API Server의 상태 변화를 Watch하다가, 원하는 Pod 개수와 실제 Pod 개수가 다르면 필요한 변경을 요청합니다. 부족한 Pod를 만들도록 API Server에 다시 요청을 남기고, 그 결과는 etcd에 반영됩니다.
3. **Scheduler가 배치할 노드를 고릅니다.** 아직 노드가 정해지지 않은 Pod를 API Server에서 Watch한 Scheduler가, 자원 여유 등을 보고 “이 Pod는 이 노드”라고 API Server에 기록합니다. 이 할당 정보도 etcd에 남습니다.
4. **Kubelet이 컨테이너를 실행합니다.** 해당 노드의 Kubelet이 “이 노드에 할당된 Pod”를 API Server에서 Watch하고, Container Runtime에 컨테이너 실행을 맡깁니다. 실행 결과는 다시 API Server를 거쳐 etcd에 반영됩니다. 이 단계에서 Pod 안의 컨테이너가 실행되기 시작합니다.

이 과정에서 API에 선언이 저장된 시점과 컨테이너가 실행되는 시점은 다릅니다. 사용자는 실행 결과와 준비 상태를 별도로 확인해야 합니다.

이 순서는 Pod의 생성과 기동을 다룹니다. kube-proxy는 요청 전달을 위한 네트워크 규칙을 설정하므로, 이 생성 순서에는 포함하지 않았습니다.

## 6. Kubernetes의 고가용성

![Kubernetes 고가용성](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/14-ha.svg)

운영에서는 API와 상태 저장소가 **한곳에만** 있으면, 그 한곳이 멈출 때 클러스터 운영 자체가 흔들릴 수 있습니다. 그래서 **고가용성**(HA, High Availability, 일부 구성요소가 중단되어도 전체가 멈추지 않게 하는 구성)을 두는 경우가 많습니다. 이 절에서는 요청 처리와 상태 저장을 여러 구성 요소가 나누어 맡는 구조를 살펴봅니다.

API Server를 여러 대 두고, 사용자는 **하나의 주소**로 요청을 보냅니다. 그중 일부가 중단되어도 나머지 API Server가 요청을 이어받습니다. 상태를 담는 etcd도 보통 여러 대(흔히 3대처럼 홀수)로 둡니다. **과반**(쿼럼, quorum)이 남아 있으면 읽기와 쓰기를 이어갑니다. Worker Node는 그 아래 여러 대가 Pod를 나눠 받습니다. Control Plane을 한 대가 아니라 여러 대가 역할을 이어받도록 구성합니다. [[8]](#ref-8)

## 7. Docker 운용 한계와 Kubernetes 명령

이전 글에서는 Docker로 컨테이너가 종료되거나, 개수와 구성이 바뀌거나, 다른 컨테이너에 연결할 때 **사람이 직접 반복하는 작업**을 시나리오로 확인했습니다. 이번 절은 클러스터를 설치하거나 명령을 실행하는 실습이 아닙니다. 같은 운영 문제와 요청 전달 문제가 Kubernetes에서는 **어떤 명령과 선언으로 바뀌는지**만, 시나리오마다 표로 짧게 살펴봅니다.

아래 표에는 **Deployment**와 **Service** 이름이 나옵니다. 지금은 각각 “원하는 Pod 개수를 유지하는 선언”, “변하는 Pod 앞의 고정 진입점” 정도로만 이해하면 됩니다. [[9]](#ref-9) [[10]](#ref-10)

### 7.1 멈춘 컨테이너 복구

![멈춘 컨테이너 복구 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/16-scenario-recovery.svg)

이전 글에서 컨테이너를 멈추면 사람이 `docker start`를 다시 실행해야 했습니다.

| Docker만 사용                                             | Kubernetes                                                    |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| `docker stop web-server-1` `docker start web-server-1` | `kubectl delete pod <pod-name>` `kubectl get pods -l app=web` |
| **한계점:** 기본값으로는 자동 복구가 없고, 사람이 다시 실행할 때까지 서비스가 비어 있음       | **개선점:** 원하는 Pod 복제본 수가 남아 있으면 플랫폼이 Pod 개수를 다시 맞춤             |

### 7.2 컨테이너 개수 스케일 아웃

![컨테이너 개수 스케일 아웃 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/17-scenario-scale.svg)

이전 글에서는 컨테이너를 늘릴 때마다 이름과 포트를 직접 골랐습니다. 여러 컨테이너로 요청을 나누려면 앞단의 전달 대상도 관리해야 합니다.

| Docker만 사용                                                                                                                                   | Kubernetes                                                                |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `docker run -d --name web-server-5 -p 8084:80 nginx:latest` `docker run -d --name web-server-6 -p 8085:80 nginx:latest` … (컨테이너 개수, 포트마다 반복) | `kubectl scale deployment web --replicas=5` `kubectl get pods -l app=web` |
| **한계점:** 포트 충돌을 사람이 피해야 하고, 앞단이 가리킬 서버 목록도 같이 수정                                                                                           | **개선점:** Pod 복제본 개수만 선언하면 되고, 포트 목록을 외울 필요가 없음                            |

### 7.3 컨테이너 이미지 버전 업데이트

![컨테이너 이미지 버전 업데이트 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/18-scenario-update.svg)

이전 글에서는 컨테이너마다 중지, 삭제, 실행 명령을 반복했습니다.

| Docker만 사용                                                                                                                  | Kubernetes                                                                                                                        |
| --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `docker stop web-server-1` `docker rm web-server-1` `docker run -d --name web-server-1 -p 8080:80 nginx:1.25` … (컨테이너마다 반복) | `kubectl set image deployment/web nginx=nginx:1.25` `kubectl rollout status deployment/web` `kubectl rollout undo deployment/web` |
| **한계점:** 업데이트와 롤백이 컨테이너 단위로 흩어지고, 중간에 일부만 끊기기 쉬움                                                                            | **개선점:** Deployment의 컨테이너 이미지를 변경하면 Pod를 점진적으로 교체하고, undo로 이전 Pod 템플릿으로 되돌림                                                                         |

`kubectl set image`는 API에 저장된 Deployment를 변경하며, 로컬 매니페스트 파일까지 수정하지는 않습니다. 파일로 배포 구성을 관리한다면 해당 파일에도 변경을 반영해야 합니다. 롤백은 이전 Pod 템플릿을 복원하는 작업이며 데이터베이스의 데이터까지 되돌리는 작업은 아닙니다.

### 7.4 요청 부하 분산과 서비스 이름 찾기

![요청 부하 분산과 서비스 이름 찾기 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/19-scenario-service.svg)

여러 웹 서버에 요청을 나누려면 전달할 서버 목록이 필요합니다. 컨테이너의 IP를 직접 사용하면 교체 시 주소 변경도 관리해야 합니다.

| Docker만 사용                                                                      | Kubernetes                                                                       |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| 앞단 서버 목록에 `host:8080` … `host:8083` 나열 후 재시작 `docker inspect`로 IP를 확인해 앱 설정에 기입 | `kubectl expose deployment web --port=80 --type=ClusterIP` `kubectl get svc web` |
| **한계점:** 컨테이너가 늘거나 줄 때마다 설정 파일을 고치고, IP가 바뀌면 연결이 깨짐                             | **개선점:** Service 이름은 고정되고, 살아 있는 Pod 목록은 플랫폼이 맞춰 줌                               |

### 7.5 배포한 컨테이너와 진입점의 삭제

![배포한 컨테이너와 진입점을 정리하며 지우기 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/20-scenario-cleanup.svg)

| Docker만 사용                                                | Kubernetes                                               |
| --------------------------------------------------------- | -------------------------------------------------------- |
| `docker stop …` / `docker rm …`를 이름마다 반복 볼륨, 네트워크까지 따로 확인 | `kubectl delete deployment web` `kubectl delete svc web` |
| **한계점:** 남긴 컨테이너와 포트를 사람이 하나씩 추적                          | **개선점:** Deployment, Service 단위로 목표를 통째로 거둘 수 있음         |

이전 글에서 반복했던 수동 복구와 스케일, 업데이트, IP 관리가, 여기에서는 **원하는 상태를 선언하고 플랫폼이 그 상태를 유지하는 방식**으로 바뀝니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Docker만으로 운용할 때의 한계를 바탕으로 Kubernetes가 컨테이너 오케스트레이션으로 등장했고, 선언형과 제어 루프, Watch 기반 통신이 설계의 핵심이 되었습니다. API와 클러스터, Control Plane과 Worker Node가 맞물려 선언이 Pod로 실행되며, 같은 운용 한계가 어떤 명령으로 바뀌는지도 표로 살펴보았습니다.
다음 글에서는 컨테이너 실행 단위인 Pod와 Pod 복제본 개수, 배포 상태를 관리하는 Deployment를 정리합니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 개요 공식 문서](https://kubernetes.io/docs/concepts/overview/)
- <a id="ref-2"></a>[2] [Kubernetes 객체와 원하는 상태 공식 문서](https://kubernetes.io/docs/concepts/overview/working-with-objects/)
- <a id="ref-3"></a>[3] [컨트롤러와 제어 루프 공식 문서](https://kubernetes.io/docs/concepts/architecture/controller/)
- <a id="ref-4"></a>[4] [Pod 공식 문서](https://kubernetes.io/docs/concepts/workloads/pods/)
- <a id="ref-5"></a>[5] [Kubernetes 구성 요소 공식 문서](https://kubernetes.io/docs/concepts/overview/components/)
- <a id="ref-6"></a>[6] [kubeconfig 공식 문서](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- <a id="ref-7"></a>[7] [Kubernetes API의 Watch 공식 문서](https://kubernetes.io/docs/reference/using-api/api-concepts/#efficient-detection-of-changes)
- <a id="ref-8"></a>[8] [고가용성 구성 공식 문서](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/)
- <a id="ref-9"></a>[9] [Deployment 공식 문서](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- <a id="ref-10"></a>[10] [Service 공식 문서](https://kubernetes.io/docs/concepts/services-networking/service/)
