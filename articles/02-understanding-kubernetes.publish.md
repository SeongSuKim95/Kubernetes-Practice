<!--
  게시용 복사본입니다. GitHub Flavored Markdown용이며, 이미지 경로는 GitHub raw URL입니다.
  원본(로컬 미리보기용): 02-understanding-kubernetes.draft.md
  이미지 저장소: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap02. Kubernetes의 설계 철학

> 15주 연재의 둘째 글입니다. Kubernetes의 설계 철학인 선언형, 제어 루프, Watch 기반 통신을 중심으로, 그 철학이 API와 클러스터에서 어떻게 이어지는지를 개략적으로 정리합니다.

## 들어가며

이전 글에서 물리 서버에서 VM, Container와 Docker, Compose와 Swarm으로 이어진 배경을 따라왔고, Docker만으로 운용할 때 사람이 직접 반복하는 작업을 시나리오로 확인했습니다. 이번 글은 그 한계를 바탕으로, Kubernetes의 설계 철학을 먼저 보고, 그 철학이 API와 클러스터, 실제 실행 경로에서 어떻게 이어지는지를 개략적으로 정리합니다.

## 1. Kubernetes의 위치와 인기

![Kubernetes 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/01-k8s-logo.svg)

Kubernetes는 **컨테이너 오케스트레이션**(Container Orchestration) 플랫폼입니다. 컨테이너 오케스트레이션이란, 컨테이너를 실행하는 일에 그치지 않고 배치와 컨테이너 개수 유지, 장애 복구, 트래픽 분배까지 **자동화하는 시스템**을 말합니다. 여러 서버에 걸친 컨테이너의 배치와 복구, 연결을 자동으로 조율합니다. Kubernetes는 이 문제를 풀기 위해 등장한 오픈소스 플랫폼입니다.

2014년 공개된 뒤 전 세계 기여자가 코드를 쌓아 왔고, 주요 클라우드는 Kubernetes를 관리형으로 제공하며 같은 모델을 로컬에서도 돌릴 수 있습니다. 어디에서 실행하든 비슷한 운영 방식을 공유한다는 점이, 사실상의 표준처럼 받아들여진 이유 중 하나라고 할 수 있겠어요.

![Kubernetes 주변 생태계](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/02-k8s-ecosystem.svg)

인기의 배경에는 이식성도 있습니다. Kubernetes를 전제로 만든 애플리케이션은 환경이 바뀌어도 같은 선언 방식으로 배포를 시도할 수 있습니다. 동시에 배포, 모니터링, 네트워크를 돕는 도구들이 Kubernetes 주변에 모여, 운영에 필요한 기능을 직접 다 만들지 않아도 되도록 받쳐 줍니다. 패키징 도구, 배포 파이프라인, 모니터링 도구 등이 그 생태계를 이룹니다.

그렇다고 배우기 쉽다는 뜻은 아닙니다. 처음에는 이름과 설정 파일이 많아 “왜 이렇게 복잡하지?”가 먼저 나오기 쉽습니다. 조금 익숙해지면 “이런 것까지 되는구나” 쪽으로 질문이 바뀌는 경우가 많습니다. 이 글은 그 순서에 맞춰, 곧바로 모든 이름을 외우기보다 **필요성, 설계 철학, 핵심 개념, 선언이 실제로 실행되기까지, 명령어로 살펴보기**를 따라갑니다.

## 2. Docker만으로 부족한 것

이전 글에서 이미 느꼈듯, 컨테이너를 여러 개 실행하는 것 자체는 어렵지 않습니다. 어려운 쪽은 **운영 판단과 정책**이에요. Docker의 등장 이후 컨테이너는 실행 환경을 표준화하는 핵심이 되었고, Dockerfile로 환경을 코드처럼 남길 수 있게 되었습니다.

```bash
# Docker로 이미지를 만들고 실행하는 기본 흐름을 상기하는 예시
docker build -t my-app:1.0 .
docker run -p 8080:80 my-app:1.0
```

같은 이미지로 로컬, 테스트, 운영 환경을 맞출 수 있게 되면서 환경 불일치 문제는 크게 줄었죠. Docker Compose로 여러 컨테이너를 한 애플리케이션처럼 묶을 수 있고, Docker Swarm으로 여러 서버에 분산하는 것도 가능해졌습니다. 그래서 자연스럽게 이런 질문이 나와요.

“Docker Compose나 Docker Swarm으로도 충분하지 않은가? Kubernetes는 왜 필요한가?”

> Docker는 “컨테이너를 실행하는 도구”이고, Kubernetes는 “컨테이너가 실행되는 전체 시스템을 관리하는 **오케스트레이션 플랫폼**”입니다.

![Docker 계열과 Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/21-docker-tools-vs-k8s.svg)

단일 서버에서는 Docker Compose만으로도 충분한 경우가 많고, 여러 서버에서는 Docker Swarm으로도 일정 수준의 운영이 가능합니다. Swarm도 서비스를 배포하고 스케일하며 롤링 업데이트하는 일을 할 수 있습니다. 다만 규모와 요구가 커질수록, 실행과 복제를 넘어 **운영을 자동화하고 정책을 시스템에 남기는 일**이 부족해져요.

Docker Swarm은 Docker에 익숙한 팀이 여러 서버 배포를 빠르게 시작하기에 좋은 선택지였어요. 그런데 서비스가 커질수록 **운영 정책을 시스템으로 남기는 도구**가 상대적으로 부족한 편입니다. 자원 한도, 자동 확장, 통신 범위, 저장소, 권한 같은 정책을 말합니다. Kubernetes는 그 정책을 더 풍부하게 갖추고 있고, 업계에서는 오케스트레이션의 사실상 표준으로 쓰입니다.

트래픽이 급증할 때 Swarm에서는 관리자가 직접 서비스 복제본 수를 늘는 식의 개입이 흔합니다.

```bash
# Swarm에서는 확장을 사람이 직접 지시함을 보이는 예시
docker service scale web=10
```

확장은 가능하지만, **컨테이너를 언제 몇 개까지 늘리고 줄일지**의 판단은 사람에게 남아요. Kubernetes에서는 CPU 사용률 같은 조건을 정책으로 남겨 두고, 그 이후의 확장 판단과 실행을 플랫폼에 맡기는 쪽으로 문제를 바꿉니다. 예를 들어 “CPU 사용률 70%를 넘으면 컨테이너 복제본을 자동으로 늘려라”는 식의 목표만 정의해 두면 됩니다.

장애도 마찬가지입니다. 새벽 세 시에 컨테이너 하나가 죽었을 때 Docker만 있다면 `docker ps`로 목록을 보고, 로그를 확인한 뒤 `docker restart`를 사람이 수행합니다. Kubernetes에서는 **원하는 컨테이너 개수와 실제로 떠 있는 컨테이너 개수의 차이**를 플랫폼이 계속 맞춰 가려는 흐름이 있습니다. 어느 서버에 컨테이너를 올릴지를 고른 뒤, 그 서버에서 컨테이너를 다시 기동하는 쪽으로 이어질 수 있습니다. 사람이 개입하지 않아도 복구가 시작된다는 점이 Docker와 Kubernetes의 큰 차이입니다.

배포에서도 차이가 납니다. Swarm은 기본적인 롤링 업데이트를 제공합니다. Kubernetes는 여기에 더해, 트래픽 전부 대신 **트래픽 일부만 새 버전으로 보내는** 식의 배포도 운영에서 자주 다룹니다. 옛 버전과 새 버전을 나란히 두고 전환하거나(블루 그린), 소수 사용자에게만 새 버전을 먼저 노출하는(카나리) 방식입니다. 단순한 기능 목록의 차이가 아니라, **운영 리스크를 제어할 수 있는 수준**의 차이에 가깝습니다.

역할을 짧게 정리하면 이렇습니다. Docker는 컨테이너 이미지를 만들고 실행하는 일에 강합니다. Docker Compose는 한 서버 안의 여러 컨테이너 구성을 파일로 정리합니다. Docker Swarm은 여러 서버에 걸친 컨테이너 분산을 돕습니다. Kubernetes는 규모가 커질 때 필요한 **운영 자동화와 정책**을 표준에 가깝게 묶어 둔 오케스트레이션 플랫폼입니다.

## 3. Kubernetes의 대표 설계 철학

오케스트레이션을 “누가 무엇을 자동으로 하느냐”로만 보면 이름이 많아 보입니다. 먼저 Kubernetes가 지키려는 약속을 세 가지로 묶어 두면, 뒤의 핵심 개념이 같은 흐름으로 읽힙니다. 아래에서는 각 철학을 한 문장으로 먼저 짚고, 이어서 설명합니다.

### 3.1 선언형과 원하는 상태

Docker에서는 흔히 이렇게 실행합니다.

```bash
# 명령형 실행: 지금 당장 기동하라고 지시하는 Docker 예시
docker run -d nginx
```

이 방식은 “어떻게 실행할 것인가”를 **명령**하는 쪽에 가깝고, 실행 이후 상태를 시스템이 계속 책임지지는 않아요. 이런 방식을 **명령형**(Imperative)이라고 부릅니다.

Kubernetes는 다른 접근을 씁니다. 일상적으로는 **YAML**(들여쓰기로 구조를 표현하는 설정 파일 형식)로 목표를 적어 둡니다. 이렇게 적어 둔 내용을 **매니페스트**(manifest, 애플리케이션과 운영 설정을 담은 명세서) 또는 **리소스**(resource, 운영 시스템에 제출하는 객체)라고 부릅니다. 예를 들어 “컨테이너 복제본 세 개를 유지해 달라”는 목표는, 매니페스트에 `replicas: 3`처럼 한 줄로 남길 수 있습니다.

```yaml
# 원하는 상태를 YAML 매니페스트로 남기는 예시
replicas: 3
```

![Desired State와 실제 상태](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/04-desired-state.svg)

이 선언의 핵심은 **원하는 상태**(Desired State)입니다. “지금은 무엇이 몇 개 떠 있는가”가 아니라 **“이렇게 되어 있기를 바란다”**를 적어 둔 목표입니다. Docker Compose의 YAML처럼 목표를 적고 플랫폼에 넘깁니다. 차이는 설정을 넘긴 뒤의 책임에 있습니다.

Docker만 있을 때 컨테이너가 죽으면 사람이 `docker start`를 눌러 원하는 상태에 맞춥니다. Kubernetes에서는 플랫폼이 **원하는 상태**와 **실제로 있는 상태**(Current State)를 비교합니다. 어긋나면 컨테이너를 더 띄우거나 줄이거나, 다른 서버로 옮기며 차이를 줄입니다. “지금 당장 3개를 띄워라”로 끝나는 명령이 아니라 **“앞으로도 계속 3개가 유지되어야 한다”**는 목표를 남기는 방식을 **선언형**(Declarative)이라고 합니다. 이런 자동 맞춤을 **셀프 힐링**(self-healing, 자기 치유)이라고 부르기도 합니다.

선언형의 강점은 자동 복구만이 아닙니다. 운영 설정이 YAML 매니페스트로 남기 때문에 인프라와 배포를 코드처럼 다룰 수 있습니다. 변경을 Git 커밋으로 남기고, 파일만 있으면 같은 상태를 다시 만들 수 있습니다. 운영 변경을 리뷰하고, 이전 커밋으로 되돌려 매니페스트를 다시 적용할 수도 있습니다. 이런 방식을 **IaC**(Infrastructure as Code, 인프라를 코드로 관리), 더 나아가 **GitOps**(Git 저장소의 매니페스트를 기준으로 클러스터 상태를 맞추는 운영 방식)로 이어 가기도 합니다.

### 3.2 제어 루프

![Control Loop](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/05-control-loop.svg)

**제어 루프**(Control Loop)를 한 문장으로 정의하면, **플랫폼이 지금 어떤 상태인지 계속 관찰하고, 사용자가 선언한 원하는 상태와 다르면 원하는 상태에 자동으로 맞춰 가는 반복 메커니즘**입니다. 차이를 줄이는 한 번의 맞춤 동작을 **보정**(Reconcile)이라고 부릅니다.

중요한 포인트는 두 가지입니다. 첫째, Kubernetes는 “명령을 실행하고 끝나는 시스템”이 아니라 **상태를 유지하는 시스템**이에요. 둘째, 제어 루프는 특정 버튼 하나가 아니라 Kubernetes 전체의 작동 방식에 가깝습니다. 원하는 상태와 현재 상태를 읽고 차이를 계산합니다. 차이를 줄이도록 보정을 **요청**한 뒤, 다시 상태를 관찰합니다. 한 번으로 끝나지 않는 것이 핵심이에요.

예를 들어 “컨테이너 복제본 3개”가 목표인 상태에서 새벽 세 시에 복제본이 하나 줄면, Desired는 3, Current는 2, 그 차이는 1이 됩니다. 복제본을 새로 만들고, 어느 서버에 둘지 정한 뒤, 이를 실행하는 흐름으로 다시 3에 맞추려 합니다. 그래서 셀프 힐링은 특수 기능이라기보다, **원하는 상태를 유지하려는 제어 루프의 자연스러운 결과**라고 할 수 있겠어요. 한 줄로 정리하면, 중앙은 상태를 맞추라고 요청하고 실제 실행은 각 서버가 맡는 책임 분리예요.

### 3.3 이벤트 기반 통신

여기서 움직이는 주체는 컨테이너를 올리는 **워커 서버**가 아니라, 플랫폼 안에서 돌아가는 **프로세스**예요. 이 프로세스들은 서로를 **직접 호출해 명령하지 않습니다.** 대신 중앙의 **공유 상태**가 바뀌는 것을 **구독**(Watch)하고, 각자 맡은 일만 수행합니다. 예를 들어 **컨테이너 개수 맞춤 프로세스**, **올릴 서버 선택 프로세스**, **컨테이너 실행 프로세스**가 각각 자기 일만 해요.

왜 이렇게 만드는지는, **직접 호출**과 **공유 상태 + Watch**를 비교하면 분명해집니다.

![직접 호출과 Watch 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/15-direct-vs-watch.svg)

**직접 호출**에서는 컨테이너 개수 맞춤 프로세스가 올릴 서버 선택 프로세스를 직접 부릅니다. 올릴 서버 선택 프로세스가 다시 컨테이너 실행 프로세스를 부릅니다. 호출이 한 줄로 이어지는 구조예요. 이때 올릴 서버 선택 프로세스가 멈추면, 컨테이너 실행 프로세스는 다음 명령을 받지 못합니다. 장애가 **호출 경로**를 따라 다음 프로세스로 전파됩니다.

**공유 상태 + Watch**에서는 프로세스끼리 서로를 부르지 않습니다. “컨테이너 3개 유지” 같은 원하는 상태는 공유 상태 저장소에만 남깁니다. 각 프로세스는 그 상태 변화를 각자 Watch하고, 자기 일만 수행한 뒤 컨테이너 상태를 다시 공유 상태에 기록합니다. 올릴 서버 선택 프로세스가 잠깐 멈춰도 공유 상태는 남아 있고, 컨테이너 개수 맞춤 프로세스와 컨테이너 실행 프로세스는 자기 구독 범위 안의 일을 이어갈 수 있어요.

같은 원리를 새벽 장애에 적용하면 이렇습니다. 컨테이너 복제본이 하나 줄었다는 변화가 공유 상태에 기록됩니다. 컨테이너 개수 맞춤 프로세스가 그 차이를 보고 보정합니다. 올릴 서버 선택 프로세스와 컨테이너 실행 프로세스는, 자기에게 필요한 상태 변화가 보일 때 움직입니다. 한 프로세스가 다른 프로세스를 깨울 필요가 없습니다.

이렇게 결합을 **느슨하게**(loose coupling) 두면, 한 프로세스의 장애가 전체 흐름을 한꺼번에 멈추기 어렵습니다. Kubernetes에서는 “누가 누구를 호출했는가”보다 **“공유 상태에 무엇이 기록되었는가”**가 더 중요합니다.

설계 철학을 정리했으니, 이제 그 철학이 실제로 적용되는 부분(**Kubernetes의 핵심 개념**)으로 들어갑니다.

## 4. Kubernetes의 핵심 개념

앞에서 Docker, Docker Compose, Docker Swarm의 역할을 정리했습니다. Kubernetes는 그 연장선에서, **여러 서버에 흩어진 컨테이너의 운영을 자동화하는 플랫폼**으로 이해하면 됩니다.

![Kubernetes API와 클러스터](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/03-k8s-cluster.svg)

실무에서 가장 자주 만나는 핵심은 두 가지입니다.

첫째는 **API**입니다. API는 사용자가 클러스터에 “원하는 상태”를 전달하는 **진입점**입니다. “웹 컨테이너를 세 개 유지해 달라”, “이 이미지로 애플리케이션을 돌려 달라” 같은 요청을 API로 보냅니다. 진입점이 하나라는 점이 중요합니다. 서버마다 따로 접속하지 않아도, 같은 API로 클러스터 운영을 요청할 수 있습니다.

이 API와 대화할 때 실무에서 가장 자주 쓰는 도구가 **kubectl**입니다. kubectl은 Kubernetes API를 호출하는 **명령줄 클라이언트**입니다. 터미널에서 조회와 적용 명령을 치면, 그 명령이 내부적으로는 API 요청이 됩니다.

둘째는 **클러스터**(Cluster)입니다. 클러스터는 여러 컴퓨터를 **하나의 논리 단위**로 묶어, 그 요청이 실제로 실행되는 범위입니다. 클러스터를 이루는 개별 서버가 **노드**(Node, 클러스터에 참여하는 서버)입니다. Docker Swarm이 여러 서버를 하나의 클러스터로 묶었다면, Kubernetes의 클러스터도 비슷하게 여러 노드를 한 덩어리로 다룹니다. 다만 그 위에 운영 정책과 자동화 규칙을 더 많이 둡니다. 노드가 늘거나 줄어도, 사용자는 보통 특정 서버를 지정하기보다 클러스터 전체에 “이런 상태로 유지해 달라”고 맡기는 경우가 많습니다. 클라우드에서는 이런 클러스터를 직접 만들지 않고, 관리형 서비스로 받아 쓰는 경우도 흔합니다.

여기서 한 가지만 이름을 정해 둡니다. Docker에서는 보통 **컨테이너 하나**가 실행 단위였습니다. Kubernetes에서는 그 단위를 한 단계 넓혀, 하나 이상의 컨테이너를 **함께 배치하고 함께 관리하도록** 묶은 **Pod**(파드)를 최소 실행 단위로 씁니다. 같은 Pod 안의 컨테이너는 네트워크와 생명주기를 공유합니다. 클러스터가 실제로 올리고 내리는 일의 단위가 Pod라는 점만 먼저 알아 두면 됩니다.

이전 글에서 만난 Container 캐릭터에 이어, **Pod** 캐릭터도 이 연재에서 계속 등장합니다.

![성수선임과 함께 배우는 쿠버네티스 : Pod 캐릭터](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-pod.png)

*성수선임과 함께 배우는 쿠버네티스 : Pod 캐릭터*

Pod 캐릭터는 캥거루처럼 앞주머니에 **Container**들을 품고 있습니다. 주머니의 육각, 큐브 표시는 Kubernetes의 최소 실행 단위를, 주머니 안 컨테이너가 둘인 모습은 한 Pod에 컨테이너를 여러 개 둘 수 있다는 점을 떠올리게 합니다.

그 Pod들이 실제로 올라가는 서버가 **Node**입니다. **Node** 캐릭터도 이 연재에서 계속 등장합니다.

![성수선임과 함께 배우는 쿠버네티스 : Node 캐릭터](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-node.png)

*성수선임과 함께 배우는 쿠버네티스 : Node 캐릭터*

Node 캐릭터는 서버 랙을 닮은 몸체에, 팔로 **Pod**들을 안고 있습니다. 목걸이의 큐브, 톱니 표시는 실제로 Pod가 올라가는 기계라는 역할을, 품에 안긴 Pod들은 한 노드 위에 여러 Pod가 산다는 관계를 보여 줍니다.

매니페스트를 API에 제출하면, 플랫폼이 그 내용을 읽고 어느 노드에 앱을 올릴지 정합니다. 앞에서 본 제어 루프가 실제 상태와의 차이를 줄이려 합니다. 애플리케이션이 Node.js든 Go든, Kubernetes 입장에서는 컨테이너 이미지와 매니페스트가 중요합니다. 언어가 달라도 같은 API와 매니페스트 방식으로 운영을 요청할 수 있다는 점이, 팀 규모가 커질 때 특히 도움이 됩니다.

이제 API와 클러스터 뒤에서, **어느 서버에서 어떤 프로세스가 일을 하는지**를 살펴보겠습니다. 실제 Pod가 서는 **Worker Node**를 먼저 보고, 판단을 맡는 **Control Plane**을 이어서 보겠습니다.

클러스터는 크게 **Worker Node**(워커 노드, 실제 Pod가 실행되는 서버)와 **Control Plane**(컨트롤 플레인, 클러스터를 제어하는 구성 요소)으로 나뉩니다.

![Kubernetes 구성 요소](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/06-k8s-components.svg)

### 4.1 Worker Node

Worker Node는 실제 Pod가 돌아가는 머신입니다. 노드마다 아래 프로세스가 함께 동작합니다.

**Kubelet**은 각 노드에서 돌아가는 **에이전트**(노드를 대신해 API와 대화하며 Pod 실행을 챙기는 프로세스)입니다. “이 노드에서 실행해야 할 Pod”를 API에서 받아오고, 아래에서 볼 Container Runtime을 호출해 컨테이너를 만들고 시작하거나 중지합니다. Pod와 노드 상태는 다시 API 쪽으로 보고합니다.

**Container Runtime**은 이미지를 내려받고 컨테이너 프로세스를 **실제로 실행하고 종료하는** 소프트웨어입니다. containerd, CRI-O 등이 여기에 해당하며, Kubelet은 **CRI**(Container Runtime Interface, 런타임과 대화하는 표준 규격)로 런타임과 통신합니다.

**kube-proxy**는 **안정적인 진입점**(변하는 Pod 집합 앞에 두는 고정 이름과 주소)을 실제 네트워크 규칙으로 구현합니다. 그 진입점에 연결된 Pod 주소 정보를 받아, 고정 주소로 들어온 요청이 실제 Pod IP로 전달되도록 설정합니다.

### 4.2 Control Plane

Control Plane은 클러스터를 **제어하는 구성 요소**입니다. Desired State를 해석하고 유지하며, Pod를 어느 노드에 둘지 결정하는 등의 판단을 담당합니다. 대표적으로 API Server, Scheduler, Controller Manager, etcd가 여기서 동작합니다.

**API Server**는 Kubernetes의 **중앙 API**입니다. 앞에서 본 `kubectl`의 호출과, Worker의 Kubelet, kube-proxy를 포함한 다른 구성 요소의 요청이 모두 이곳을 거쳐야 합니다. 그래야 클러스터 상태를 조회하거나 바꿀 수 있습니다. 누가 요청했는지, 무엇을 할 수 있는지(인증과 인가)와 형식 검사를 수행한 뒤, 변경 내용을 아래의 상태 저장소에 반영합니다.

**etcd**는 그 상태 저장소, 즉 클러스터 상태를 담는 **분산 Key-Value 데이터베이스**입니다. 리소스 정의와 현재 상태가 최종적으로 여기에 기록되고, 클러스터 관점에서는 **단일 진실 소스**(Single Source of Truth)로 취급됩니다. etcd는 상태 저장소이고, API Server는 그 저장소에 읽고 쓰는 진입점입니다.

**Scheduler**(스케줄러)는 아직 노드가 정해지지 않은 Pod를 알아채고, 각 Worker 노드의 자원 여유와 배치 제약을 고려해 **어느 노드에 둘지**만 결정합니다. 컨테이너를 직접 실행하지는 않아요. “이 Pod는 이 노드에 할당한다”는 결정을 API Server에 기록하면, 이후 해당 노드의 Kubelet이 실제 컨테이너를 띄웁니다.

**Controller Manager**는 여러 **컨트롤러**(controller, 원하는 상태를 유지하려고 제어 루프를 도는 장치)를 한 프로세스에서 묶어 실행합니다. Pod 복제본 개수, 노드 상태처럼 대상마다 컨트롤러가 있고, API Server의 리소스를 Watch 하면서 Desired와 Current가 다르면 차이를 줄이는 보정(Reconcile)을 **요청**합니다. 노드에 직접 접속하지 않고 API에 상태 변경을 남기는 방식이에요.

이 구조는 앞의 설계 철학(**이벤트 기반 통신**)과 같습니다. 구성 요소끼리 직접 명령을 주고받지 않고, **API Server에 남긴 상태를 통해** 일을 나눕니다. Scheduler도 Controller Manager도 Kubelet도, 상대를 직접 부르기보다 API의 상태 변화를 보고 각자 맡은 일만 수행합니다. 그래서 Kubernetes에서는 “누가 누구에게 명령했는가”보다 **“상태가 어디에 어떻게 기록되었는가”**가 더 중요합니다.

## 5. 선언이 Pod로 실행되기까지

앞에서 API, 클러스터, Control Plane, Worker Node의 이름을 알아보았습니다. 이제는 그 구성 요소들이 **하나의 요청 경로**에서 어떻게 맞물리는지를 봅니다. 사용자가 원하는 상태를 남기면, 그 선언이 실제로 Pod와 컨테이너 실행까지 이어지는 순서를 따라갑니다.

### 5.1 kubectl로 API에 연결하기

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

실무에서 Kubernetes API에 가장 자주 요청을 보내는 도구가 **kubectl**입니다. kubectl은 Kubernetes API를 호출하는 **명령줄 클라이언트**예요. 터미널 명령은 내부적으로 API Server로 가는 HTTPS 요청이 됩니다. 어느 클러스터 주소에, 어떤 사용자로 붙을지는 위 **kubeconfig** 설정 파일이 정합니다.

선언이 Pod로 이어지는 순서를 보기 전에, 그 순서를 받치는 공통 구조부터 정리합니다. Kubernetes는 구성 요소에게 직접 명령을 흩르기보다, 상태를 저장해 두고 각 구성 요소가 그 변화를 구독합니다.

### 5.2 상태 저장과 Watch

![상태 저장과 Watch](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/10-state-and-watch.svg)

> “사용자가 `kubectl`로 명령을 내리면 Kubernetes가 즉시 어딘가에 ‘직접 명령’을 내려 Pod를 실행시킨다.”

실제로는 **직접 제어**가 아니라 **상태 저장과 상태 구독**(Watch) 기반입니다. 사용자가 매니페스트를 내면 API Server가 etcd에 상태를 저장합니다. Controller Manager, Scheduler, Kubelet은 API Server의 상태 변화를 Watch하다가, 각자 맡은 일(Pod 개수 맞추기, 노드 할당, 컨테이너 실행)만 수행하고 결과를 다시 API Server에 남깁니다.

같은 구조가 **셀프 힐링**에도 그대로 쓰입니다. 노드에서 컨테이너 프로세스가 사라져 Desired와 Current가 어긋나면, 제어 루프가 다시 상태를 맞추려 합니다. 이전 글에서 `docker start`를 사람이 반복했던 일이, 여기서는 플랫폼이 기본으로 수행하는 동작이 됩니다.

이 저장과 Watch 구조가 실제로 어떻게 이어지는지, 선언이 Pod로 실행되는 순서로 보면 아래와 같아요.

![구성 요소 동작 시퀀스](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/09-pod-creation-sequence.svg)

아래는 “원하는 상태를 남긴 뒤, Pod가 한 노드에서 실행될 때까지”를 네 단계로 나눈 순서입니다. 그림의 번호와 본문 번호는 같습니다.

1. **사용자가 선언을 남깁니다.** kubectl이 API Server에 원하는 상태를 보냅니다. API Server는 검사한 뒤, 그 내용을 **etcd**에 기록합니다. 이 순간이 **선언형**의 출발점이에요. “지금 당장 어디에 띄워라”가 아니라, “이런 상태가 되어야 한다”가 공유 상태에 남습니다.
2. **Controller Manager가 Pod 개수를 맞춥니다.** Controller Manager는 API Server의 상태 변화를 Watch하다가, 원하는 Pod 개수와 실제로 있는 Pod 개수가 다르면 차이를 줄이려 합니다. 부족한 Pod를 만들도록 API Server에 다시 요청을 남기고, 그 결과는 etcd에 반영됩니다. 여기가 **제어 루프**가 동작하는 지점이에요.
3. **Scheduler가 배치할 노드를 고릅니다.** 아직 노드가 정해지지 않은 Pod를 API Server에서 Watch한 Scheduler가, 자원 여유 등을 보고 “이 Pod는 이 노드”라고 API Server에 기록합니다. 이 할당 정보도 etcd에 남습니다. Scheduler는 컨테이너를 직접 실행하지 않습니다.
4. **Kubelet이 컨테이너를 띄웁니다.** 해당 노드의 Kubelet이 “이 노드에 할당된 Pod”를 API Server에서 Watch하고, Container Runtime에 컨테이너 실행을 맡깁니다. 실행 결과는 다시 API Server를 거쳐 etcd에 반영됩니다. Pod 상태가 Running에 가까워지는 구간이에요.

핵심은 단계마다 프로세스가 서로를 직접 부르지 않는다는 점입니다. 읽고 쓰는 대상은 늘 **API Server를 통한 공유 상태**(최종 저장은 etcd)예요. 앞에서 본 **이벤트 기반 통신**이 이 시퀀스의 기본 구조입니다.

이 순서가 다루는 범위는 배포와 기동입니다. 앞에서 본 **kube-proxy**는 트래픽을 전달하는 구성 요소라, Pod를 처음 띄우는 이 시퀀스에는 포함되지 않습니다.

## 6. Kubernetes의 고가용성

![Kubernetes 고가용성](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/14-ha.svg)

운영에서는 API와 상태 저장소가 **한곳에만** 있으면, 그 한곳이 멈출 때 클러스터 운영 자체가 흔들릴 수 있습니다. 그래서 **고가용성**(HA, High Availability, 일부가 죽어도 전체가 멈추지 않게 하는 구성)을 두는 경우가 많습니다. 직관만 잡으면 충분합니다.

API Server를 여러 대 두고, 사용자는 **하나의 주소**로 요청을 보냅니다. 그중 일부가 죽어도 나머지 API Server가 요청을 이어받습니다. 상태를 담는 etcd도 보통 여러 대(흔히 3대처럼 홀수)로 둡니다. **과반**(쿼럼, quorum)이 남아 있으면 읽기와 쓰기를 이어갑니다. Worker Node는 그 아래 여러 대가 Pod를 나눠 받습니다. Control Plane을 한 대가 아니라 여러 대가 이어받도록 구성한다고 보면 됩니다.

## 7. Docker 운용 한계와 Kubernetes 명령

이전 글에서는 Docker로 컨테이너가 죽거나, 늘거나, 바뀌거나, 서로 찾을 때 **사람이 직접 반복하는 작업**을 시나리오로 확인했습니다. 이번 절은 클러스터를 설치하거나 명령을 실행하는 실습이 아닙니다. 같은 운용 한계가 Kubernetes에서는 **어떤 명령과 선언으로 바뀌는지**만, 시나리오마다 표로 짧게 살펴봅니다.

아래 표에는 **Deployment**와 **Service** 이름이 나옵니다. 지금은 각각 “원하는 Pod 개수를 유지하는 선언”, “변하는 Pod 앞의 고정 진입점” 정도로만 읽고 넘어가시면 충분합니다.

### 7.1 멈춘 컨테이너 복구

![멈춘 컨테이너 복구 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/16-scenario-recovery.svg)

이전 글에서 컨테이너를 멈추면 `docker start`를 사람이 다시 눌러야 했습니다.

| Docker만 사용                                             | Kubernetes                                                    |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| `docker stop web-server-1` `docker start web-server-1` | `kubectl delete pod <pod-name>` `kubectl get pods -l app=web` |
| **한계점:** 기본값으로는 자동 복구가 없고, 사람이 살릴 때까지 서비스가 비어 있음       | **개선점:** 원하는 Pod 복제본 수가 남아 있으면 플랫폼이 Pod 개수를 다시 맞춤             |

### 7.2 컨테이너 개수 스케일 아웃

![컨테이너 개수 스케일 아웃 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/17-scenario-scale.svg)

이전 글에서는 컨테이너를 늘릴 때마다 이름과 포트를 직접 고르고, 앞단 목록도 함께 고쳐야 했습니다.

| Docker만 사용                                                                                                                                   | Kubernetes                                                                |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `docker run -d --name web-server-5 -p 8084:80 nginx:latest` `docker run -d --name web-server-6 -p 8085:80 nginx:latest` … (컨테이너 개수, 포트마다 반복) | `kubectl scale deployment web --replicas=5` `kubectl get pods -l app=web` |
| **한계점:** 포트 충돌을 사람이 피해야 하고, 앞단이 가리킬 서버 목록도 같이 수정                                                                                           | **개선점:** Pod 복제본 개수만 선언하면 되고, 포트 목록을 외울 필요가 없음                            |

### 7.3 컨테이너 이미지 버전 업데이트

![컨테이너 이미지 버전 업데이트 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/18-scenario-update.svg)

이전 글에서는 컨테이너마다 stop / rm / run을 반복했습니다.

| Docker만 사용                                                                                                                  | Kubernetes                                                                                                                        |
| --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `docker stop web-server-1` `docker rm web-server-1` `docker run -d --name web-server-1 -p 8080:80 nginx:1.25` … (컨테이너마다 반복) | `kubectl set image deployment/web nginx=nginx:1.25` `kubectl rollout status deployment/web` `kubectl rollout undo deployment/web` |
| **한계점:** 업데이트와 롤백이 컨테이너 단위로 흩어지고, 중간에 일부만 끊기기 쉬움                                                                            | **개선점:** 이미지를 매니페스트에 반영하면 Pod를 차례로 맞추고, undo로 이전 설정에 가깝게 되돌림                                                                         |

### 7.4 요청 부하 분산과 서비스 이름 찾기

![요청 부하 분산과 서비스 이름 찾기 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/19-scenario-service.svg)

이전 글에서는 앞단이 가리킬 서버 목록을 적거나, 컨테이너 IP를 직접 관리해야 했습니다.

| Docker만 사용                                                                      | Kubernetes                                                                       |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| 앞단 서버 목록에 `host:8080` … `host:8083` 나열 후 재시작 `docker inspect`로 IP를 확인해 앱 설정에 기입 | `kubectl expose deployment web --port=80 --type=ClusterIP` `kubectl get svc web` |
| **한계점:** 컨테이너가 늘거나 줄 때마다 설정 파일을 고치고, IP가 바뀌면 연결이 깨짐                             | **개선점:** Service 이름은 고정되고, 살아 있는 Pod 목록은 플랫폼이 맞춰 줌                               |

### 7.5 배포한 컨테이너와 진입점을 정리하며 지우기

![배포한 컨테이너와 진입점을 정리하며 지우기 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/20-scenario-cleanup.svg)

| Docker만 사용                                                | Kubernetes                                               |
| --------------------------------------------------------- | -------------------------------------------------------- |
| `docker stop …` / `docker rm …`를 이름마다 반복 볼륨, 네트워크까지 따로 확인 | `kubectl delete deployment web` `kubectl delete svc web` |
| **한계점:** 남긴 컨테이너와 포트를 사람이 하나씩 추적                          | **개선점:** Deployment, Service 단위로 목표를 통째로 거둘 수 있음         |

이전 글에서 반복했던 수동 복구와 스케일, 업데이트, IP 관리가, 여기에서는 **선언해 둔 목표를 플랫폼이 따라가는 명령**으로 바뀌는 것만 확인하면 됩니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Docker만으로 운용할 때의 한계를 바탕으로 Kubernetes가 컨테이너 오케스트레이션으로 등장했고, 선언형과 제어 루프, Watch 기반 통신이 설계의 핵심이 되었습니다. API와 클러스터, Control Plane과 Worker Node가 맞물려 선언이 Pod로 실행되며, 같은 운용 한계가 어떤 명령으로 바뀌는지도 표로 살펴보았습니다.
다음 글에서는 Pod, Deployment, Service, Ingress, Namespace를 중심으로 서비스를 운영할 때 다루는 핵심 리소스를 정리합니다.
