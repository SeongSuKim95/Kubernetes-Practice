<!--
  게시용 복사본입니다. GitHub Flavored Markdown용이며, 이미지 경로는 GitHub raw URL입니다.
  원본(로컬 미리보기용): 01-background-and-docker-limits.draft.md
  이미지 저장소: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap01. Container의 등장 배경과 Docker

> 15주 연재의 첫 글입니다. Container가 왜 등장했는지 Bare Metal과 VM을 거친 배경을 정리하고, Docker로 컨테이너를 운용할 때 사람이 직접 반복하는 작업을 겪어 봅니다. Docker를 처음 듣는 분도 따라올 수 있도록, 컨테이너가 무엇인지부터 풀어 씁니다.

## 들어가며

![Kubernetes 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/01-k8s-logo.svg)

컨테이너와 Docker는 오늘날 애플리케이션의 개발과 배포에서 널리 사용하는 기술입니다. 컨테이너는 애플리케이션과 필요한 실행 환경을 묶어 격리된 공간에서 실행하는 방식이고, Docker는 컨테이너를 만들고 실행하도록 돕는 대표적인 도구입니다. Stack Overflow의 2025년 개발자 설문에서는 클라우드 개발 및 인프라 기술 문항에 응답한 사람 중 약 71%가 지난 1년 동안 Docker를 사용했다고 답했습니다. 컨테이너를 다루는 일이 많은 개발자의 일상적인 작업이 되었음을 보여 주는 수치입니다. [[1]](#ref-1)

이 기술들이 널리 쓰이는 이유를 이해하려면, 애플리케이션을 개발한 뒤 다른 환경에 배포하고 운영할 때 어떤 문제가 생기는지부터 살펴볼 필요가 있습니다.

예를 들어 쇼핑몰 앱에 작은 할인 배너를 추가해 배포했다고 가정해 보겠습니다. 개발자의 컴퓨터에서는 정상 동작하던 앱이 운영 서버에서는 흰 화면만 보여 줍니다. 팀은 “내 컴퓨터에서는 되는데?”라는 말을 주고받으며 두 환경의 차이를 찾습니다.

실행 환경을 맞춘 뒤에도 운영 문제는 이어집니다. 광고 효과로 주문이 몰리면 서버를 추가하고 같은 설정을 적용해야 합니다. 새벽에 결제 기능이 중단되면 로그를 확인하고 애플리케이션을 다시 실행해야 합니다. 기능을 개발하는 일뿐 아니라 **같은 환경에서 실행하고, 부하에 맞춰 늘리고, 장애가 나면 복구하는 일**도 필요합니다.

애플리케이션이 웹, 결제, 알림 등으로 나뉘고 실행할 서버가 늘어날수록 이러한 작업을 사람이 모두 처리하기는 어려워집니다. 서버 자원을 효율적으로 나누는 방법, 실행 환경을 일관되게 준비하는 방법, 여러 서버의 애플리케이션을 관리하는 방법이 필요한 이유입니다.

이번 글에서는 실행 환경과 관리 범위가 확장되는 흐름을 따라 각 기술이 어떤 운영 문제를 해결하는지 살펴봅니다. 물리 서버와 가상 머신(VM)의 차이부터 시작해 컨테이너(Container)와 Docker의 역할을 알아보고, Compose와 Swarm으로 관리 범위를 넓혀 봅니다. 이어서 Docker 실습으로 수동 배치와 복구를 직접 확인하며, Kubernetes 같은 운영 플랫폼이 필요한 배경을 정리합니다.

## 1. 물리 서버 한 대에 애플리케이션 하나를 배치하는 구성

![가상화에서 Kubernetes까지의 발전 흐름](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/01-journey.svg)

위 그림은 애플리케이션을 실행하고 관리하는 범위가 확장되는 흐름을 보여 줍니다. Bare Metal은 물리 서버 한 대에 애플리케이션을 직접 배치하고, Virtual Machine은 한 서버의 자원을 여러 Guest OS로 나눕니다. Container는 Host OS를 공유하면서 애플리케이션 프로세스를 격리하고, Docker Compose는 한 서버의 여러 컨테이너를 함께 구성합니다. Docker Swarm과 Kubernetes에서는 관리 범위가 여러 서버로 넓어지고, 컨테이너 배치와 복구를 플랫폼에 맡깁니다.

![Bare Metal 구조](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/02-physical-server.svg)

이 흐름의 출발점은 **Bare Metal**(베어메탈, 가상화 계층 없이 운영체제가 물리 하드웨어 위에 바로 올라가는 서버)입니다. 가상 컴퓨터를 중간에 두지 않고, **Hardware** 위에 **Host OS**를 올리고, 그 위에 애플리케이션을 설치하는 구성입니다.

한동안은 이런 물리 서버 한 대에 애플리케이션 하나를 두는 일이 보통이었습니다. 구조가 단순해서 이해하기 쉽고, 성능도 직관적입니다. 서버에 설치한 OS와 앱이 하드웨어를 직접 사용하기 때문입니다.

실제 운영에서는 한계가 분명합니다. CPU와 메모리가 남아도 다른 앱을 같은 서버에 마음 놓고 올리기 어렵습니다. 라이브러리 버전이나 포트, 장애 범위가 서로 얽히기 쉽기 때문입니다. 한 앱이 자원을 많이 쓰면 같은 서버의 다른 앱도 영향을 받습니다. 앱이 늘면 서버를 새로 사고, OS와 앱을 설치하고, OS와 앱에 패치를 적용하며, 장애에 대응하는 일이 **서버 대수만큼** 불어납니다. 물리 장비를 늘리는 비용과 시간도 함께 커집니다.

단순함은 강점이었지만, “이 서버에 남은 자원을 더 효율적으로 나눌 수는 없을까?”라는 질문이 남았습니다. 그 질문이 다음 단계인 **Virtual Machine**(가상 머신)으로 이어집니다.

## 2. 서버 자원의 분리와 Virtual Machine

![Virtual Machine 구조](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/03-vm.svg)

Virtual Machine(가상 머신, VM)은 Bare Metal로 쓰이던 물리 하드웨어 위에 **Hypervisor**(하이퍼바이저)를 두고, 그 위에 **Guest OS**(게스트 운영체제)를 가진 가상 컴퓨터를 여러 대 올리는 방식입니다. Hypervisor는 한 대의 하드웨어를 여러 가상 컴퓨터에 나누어 주는 관리 계층이고, Guest OS는 각 가상 컴퓨터 안에 따로 설치되는 운영체제입니다.

![Virtual Machine 구조 보충](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/13-vm-houses.svg)

각 VM은 자신만의 운영체제와 **Kernel**(커널, 운영체제의 핵심)을 가집니다. 물리 서버 하나를 여러 대의 가상 컴퓨터로 나누는 방식입니다.

VM은 실행 환경을 강하게 격리합니다. 한 VM의 문제가 다른 VM으로 쉽게 번지지 않습니다. 물리 서버 한 대에 쇼핑몰 웹용 VM, 결제 API용 VM, 상품 DB용 VM을 나눠 두면, Bare Metal 시절처럼 “이 서버 하나에 앱을 하나만” 올리는 낭비를 줄일 수 있습니다. 자원 활용은 Bare Metal 때보다 나아졌습니다.

다만 VM은 **컴퓨터를 통째로** 복제하는 것처럼 운영체제를 포함한 환경을 별도로 준비해야 합니다. 이 구조는 자원 사용량과 관리 부담을 늘립니다.

예를 들어, 작은 API 서버 하나를 올리는 상황을 가정해 보겠습니다. 애플리케이션 자체는 메모리 수백 메가바이트면 충분한데, Guest OS를 띄우려면 수 기가바이트의 디스크와 적지 않은 RAM을 먼저 씁니다. 같은 물리 서버에 비슷한 앱을 열 개 올려야 한다면, 앱 열 개가 아니라 **OS 열 개**를 함께 감당해야 합니다. 배포 밀도는 물리 서버 시절보다 나아졌어도, “앱만 올리는” 요구와는 거리가 있습니다.

가상 머신의 기동 속도도 운영 방식을 바꿉니다. 트래픽이 잠깐 늘어서 가상 머신을 하나 더 만들고 싶을 때, VM은 부팅, 네트워크 설정, 패키지 확인까지 기다린 뒤에야 서비스에 합류하는 경우가 많습니다. 배포 과정이 “가상 머신을 준비해 서버에 올리고 동작을 확인한다”는 주기로 길어지면, 수정한 내용을 서비스에 반영해 확인하기까지도 함께 느려집니다.

환경을 맞추려는 시도가 오히려 일을 더 크게 만들기도 합니다. 개발자가 로컬에서 돌린 구성과 테스트, 운영이 달라지면 Node.js 버전이나 라이브러리, OS 패키지가 어긋납니다. 이때 사용할 수 있는 방법 중 하나는 “잘 되는 VM을 통째로 복제해 옮기자”입니다. 환경은 비슷해질 수 있습니다. 다만 옮기는 단위가 운영체제까지 포함한 가상 머신 전체라 용량이 큽니다. 가상 머신 복제본의 전송과 기동이 느리고, 보안 패치나 설정 변경도 Guest OS마다 따로 적용해야 합니다. 앱 하나를 고치려고 컴퓨터 한 대를 복제하고 배포하며 관리하는 셈이 됩니다.

정리하면 VM은 “한 서버의 자원을 나눈다”는 문제에는 답했지만, **앱을 가볍게 실행하고, 복제본을 빠르게 늘리며, 앱 단위로 같은 실행 환경을 옮긴다**는 요구에는 여전히 무거웠습니다. OS 전체가 아니라 애플리케이션이 필요한 실행 환경만 싸서 옮기고 싶다는 필요가, 다음 단계인 컨테이너(Container)로 이어집니다.

## 3. 실행 환경의 일관성과 Container 및 Docker

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-container.png" alt="애플리케이션의 실행 환경을 묶는 Container" width="40%" />

Container는 위 그림처럼 애플리케이션과 필요한 실행 환경을 하나의 실행 단위로 묶습니다.

![VM과 Container 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/04-vm-vs-container.svg)

Container(컨테이너)는 Guest OS를 복제하지 않습니다. 애플리케이션과 그에 필요한 파일을 **Image**(이미지, 실행에 필요한 파일을 묶어 둔 설계도)에 담습니다. 그 이미지로 실행한 프로세스를 **Container**라고 부릅니다. 컨테이너가 실행되는 실제 컴퓨터의 운영체제는 **Host**(호스트) OS입니다. 컨테이너들은 Host의 Kernel을 공유한 채 프로세스만 격리합니다. Container는 VM보다 가볍고, 같은 Host 위에서 프로세스 단위로 앱을 격리합니다. [[2]](#ref-2)

로컬에 nginx(웹 서버 프로그램)를 직접 설치하면 OS 버전이나 패키지, 설정 경로가 사람마다 달라집니다. 대신 nginx 실행에 필요한 파일을 Image로 묶어 두면, 그 Image로 실행한 Container 안에서는 같은 경로와 구성으로 웹 서버가 실행됩니다. 로컬과 테스트 서버, 운영 서버가 달라도 **같은 Image**를 쓰려는 것이 컨테이너의 매력입니다.

![Docker 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/29-docker-official-logo.svg)

이 격리를 Linux Kernel이 이미 제공하던 기능으로 구현하고, 그 위를 다루기 쉽게 만든 대표 도구가 **Docker**입니다. Docker는 2013년 Solomon Hykes가 이끌던 dotCloud에서 오픈소스로 공개했고, 같은 해 회사 이름도 Docker Inc.로 바뀌었습니다. Linux Kernel의 컨테이너 기능을 **Image**, **CLI**(Command Line Interface, 명령줄 도구), **레지스트리**(이미지를 받아 두는 저장소)로 다루기 쉽게 만든 것이 핵심입니다.

![docker run 흐름](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/05-docker-flow.svg)

컨테이너를 서로 분리하려면 각 프로세스가 볼 수 있는 대상과 사용할 자원을 제한해야 합니다. 컨테이너마다 사용할 파일도 준비해야 합니다. Docker는 다음 Linux 기능을 이용해 이 실행 환경을 구성합니다.

프로세스 목록과 네트워크 등 각 컨테이너에서 볼 수 있는 범위를 분리하는 기능이 Linux의 **Namespace**(네임스페이스)입니다. 같은 커널을 사용하더라도 컨테이너마다 분리된 실행 환경을 제공할 수 있습니다. 여기서 말하는 Linux Namespace는 Kubernetes에서 리소스를 묶는 Namespace와 다른 개념입니다.

CPU와 메모리 사용량을 제어하는 기능은 **cgroups**(컨트롤 그룹)입니다. 컨테이너별로 메모리 등의 사용 한도를 설정할 때 사용합니다. [[3]](#ref-3)

이미지의 파일과 실행 중에 변경한 파일을 하나의 파일 시스템처럼 제공하는 방법도 필요합니다. **OverlayFS**(오버레이 파일 시스템)는 여러 파일 계층을 겹쳐 이 기능을 제공하는 방식 중 하나입니다. 여기서는 내부 구현보다, 이미지에 담긴 파일을 바탕으로 컨테이너마다 사용할 파일 시스템을 구성한다는 점이 중요합니다.

사용자는 Docker Client(명령줄 도구)로 `docker run` 같은 명령을 보냅니다. 백그라운드에서 실행되는 Docker Daemon(데몬, 상주 관리 프로세스)은 이 요청을 받아 컨테이너 런타임을 통해 격리와 자원, 파일 시스템을 준비하고 컨테이너를 실행합니다. 사용자가 커널 기능을 하나씩 직접 설정할 필요가 없도록 Docker가 실행 과정을 관리합니다. [[4]](#ref-4)

![Image와 Container](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/06-image-vs-container.svg)

Docker에서는 **Dockerfile**(이미지를 만드는 절차를 적은 파일)로 실행 환경을 정의하고, 그 결과인 이미지로 컨테이너를 실행합니다. 그림처럼 같은 nginx 이미지로도 서로 다른 이름과 호스트 포트를 가진 웹 서버 컨테이너를 여러 개 실행할 수 있습니다.

지금까지 Image에 담긴 실행 환경과 실제로 실행되는 Container를 구분했습니다. 실습으로 넘어가기 전에 한 가지만 더 설명합니다. 웹 서버 컨테이너를 실행했다면, 브라우저나 `curl`로 접속할 방법이 필요합니다. 이때 요청을 전달할 **포트**(port)를 지정해야 합니다.

![포트 연결](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/11-port-mapping.svg)

포트는 한 컴퓨터 안에서 네트워크 요청을 받을 프로세스(또는 서비스)를 가리키는 **번호**입니다. 같은 서버에 웹, DB, 캐시가 함께 있어도, 포트가 다르면 요청이 서로 다른 대상으로 들어갑니다. 예를 들어 많은 웹 서버는 컨테이너 **안**에서 80번 포트에서 요청을 받고, 데이터베이스는 3306번 포트에서 요청을 받는 식으로 역할이 갈립니다.

컨테이너는 호스트와 네트워크 공간이 나뉘어 있습니다. 그래서 컨테이너 안에서 nginx가 80번 포트에서 요청을 받고 있어도, 호스트(내 컴퓨터)의 브라우저가 곧바로 그 80번에 접속한다고 연결되지는 않습니다. Docker에서는 `-p 호스트포트:컨테이너포트`로 호스트 포트와 컨테이너 포트를 연결합니다. `-p 8080:80`이면 “내 컴퓨터의 8080번으로 들어온 요청을, 컨테이너 안의 80번으로 넘겨라”는 뜻입니다. 호스트에서는 8080을 열고, 컨테이너 안에서는 그대로 80을 유지하는 셈입니다. [[5]](#ref-5)

실습에서는 이 내용을 명령으로 확인합니다. 이미지를 받아 컨테이너를 만들고, 포트를 연결한 뒤, 컨테이너 목록을 보고, 컨테이너를 중지한 뒤 다시 실행하는 과정을 확인합니다. 각 명령의 옵션은 해당 시나리오에서 설명합니다.

## 4. 여러 컨테이너의 관리와 Compose 및 Swarm

컨테이너 하나만 실행하는 일은 `docker run`으로도 됩니다. 실제 서비스는 웹과 DB처럼 역할이 다른 컨테이너가 함께 움직이는 경우가 많습니다. 이 컨테이너들의 설정을 함께 관리하고, 서버가 여러 대라면 배치와 복구도 조율해야 합니다. 먼저 한 서버의 구성을 정리하는 Docker Compose부터 살펴보겠습니다.

### 4.1 Docker Compose를 통한 단일 서버의 컨테이너 구성

![Docker Compose 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/30-compose-official-logo.svg)

**Docker Compose**는 여러 컨테이너로 구성된 애플리케이션을 YAML로 정의해 한꺼번에 실행하고 중지하는 도구입니다. 2014년에 1.0이 공개되었고, 지금은 `docker compose` 플러그인으로 Docker CLI와 함께 쓰는 경우가 많습니다.

![Docker Compose](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/14-compose-menu.svg)

매번 긴 `docker run`을 여러 줄 치면 실수하기 쉽고, “어떤 컨테이너를 어떤 순서로 올렸는지”도 남기기 어렵습니다. 그림의 `compose.yaml`에는 웹, 애플리케이션, 데이터베이스의 구성이 함께 기록됩니다. **YAML**은 들여쓰기로 구조를 적는 설정 파일 형식입니다. `docker compose up`을 실행하면 이 파일에 적힌 구성으로 컨테이너들을 생성하고 시작하므로, 같은 조합을 다시 재현하기 쉽습니다. [[6]](#ref-6)

다만 Docker Compose는 기본적으로 **단일 호스트**(서버 한 대)를 전제로 합니다. 한 서버 안의 컨테이너 구성을 정리하는 도구이지, 여러 서버를 하나의 클러스터로 운영하는 도구는 아닙니다. 서버 한 대가 장애를 내면 Docker Compose로 묶은 서비스도 함께 위험해집니다.

### 4.2 여러 서버의 컨테이너 배치와 수동 복구

![오케스트레이션이 필요한 이유](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/32-why-orchestration.svg)

서버가 여러 대가 되면 한 서버 안의 실행 설정뿐 아니라, 각 컨테이너를 어느 서버에 배치하고 장애가 난 서버의 작업을 어디서 다시 실행할지도 결정해야 합니다.

그림처럼 서버 A와 C에는 웹, 앱, DB 컨테이너가 실행 중이고, 서버 B만 장애로 멈춘 상황을 가정해 보겠습니다. 운영자는 다음 항목을 직접 결정해야 합니다. 어느 서버에 웹 컨테이너를 둘지, 웹 컨테이너 복제본을 몇 개 실행할지, 종료된 컨테이너를 누가 다시 실행할지입니다. 요청을 여러 웹 컨테이너에 나누거나, 컨테이너 IP가 바뀌어도 서비스 이름으로 컨테이너를 찾는 일도 같은 부담입니다.

이 운영을 플랫폼에 맡기는 계층이 **Container Orchestration**(컨테이너 오케스트레이션)입니다. 여러 서버에 걸친 컨테이너의 배치와 복구, 연결을 자동으로 조율합니다.

### 4.3 Docker Swarm을 통한 배치와 복구

![Docker Swarm 아이콘](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/31-swarm-official-logo.svg)

**Docker Swarm**은 Docker가 제공하는 컨테이너 오케스트레이션입니다. 2016년 Docker Engine 1.12부터 Swarm mode가 엔진에 포함되어, 여러 서버를 하나의 클러스터처럼 묶고 서비스를 배치하거나 복구할 수 있습니다.

![Docker Compose와 Docker Swarm](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/07-compose-to-swarm.svg)

여러 **Node**(노드, 클러스터에 참여하는 서버)를 **Cluster**(클러스터, 여러 서버를 하나의 논리 단위로 묶은 것)로 묶고, 어느 노드에 컨테이너를 둘지, 컨테이너가 종료되면 컨테이너를 어떻게 다시 실행할지를 플랫폼이 조율합니다. [[7]](#ref-7)

Compose로 관리하던 서버가 여러 대로 늘어나면, Swarm 같은 오케스트레이션을 통해 서버 사이의 배치와 복구까지 관리 범위를 넓힐 수 있습니다.

![Docker Swarm과 Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/16-complex-vs-city.svg)

**Kubernetes**도 Docker Swarm과 같은 종류의 **컨테이너 오케스트레이션**입니다. Swarm도 서비스 배포와 규모 조절, 점진적인 버전 교체를 지원합니다. Kubernetes는 자동 확장, 통신 범위, 저장소와 권한처럼 운영 정책을 더 세밀하게 선언할 수 있으며, 이러한 기능을 지원하는 주변 도구도 풍부합니다.

이제 오케스트레이션 기능을 사용하지 않고 Docker 명령으로 직접 운영할 때 어떤 작업이 필요한지 확인하겠습니다.

## 5. 실행 이후의 관리 작업을 확인하는 Docker 실습

이번 실습은 컨테이너를 실행한 뒤에도 복구와 이미지 교체 작업이 필요하다는 점을 확인합니다. 웹 서버 실행, 중지와 재실행, 여러 컨테이너의 이미지 교체만 다룹니다. 앞 단계에서 만든 컨테이너를 다음 단계에서 그대로 사용합니다.

Docker를 설치하고 실행해 두어야 합니다. 아직 준비되지 않았다면 공식 설치 안내[[8]](#ref-8)를 참고합니다. 호스트의 8080~8083번 포트가 비어 있는 환경을 가정하며, 아래 출력의 ID와 시간은 예시입니다.

### 5.1 웹 서버 실행과 응답 확인

![이미지로 웹 서버를 실행하고 포트를 연결하는 흐름](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/17-lab-run.svg)

nginx 웹 서버를 실행합니다. 이미지가 로컬에 없으면 Docker가 먼저 내려받습니다.

```bash
# nginx 컨테이너를 실행하고 목록에서 확인
docker run -d --name web-server-1 -p 8080:80 nginx:latest
docker ps
```

```text
<컨테이너 ID>
CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES
a1b2c3d4e5f6   nginx:latest   Up 5 seconds   0.0.0.0:8080->80/tcp   web-server-1
```

`-d`는 백그라운드 실행, `--name`은 컨테이너 이름을 지정합니다. `-p 8080:80`은 호스트 8080번 포트를 컨테이너의 80번 포트에 연결합니다. 목록의 `Up`은 컨테이너가 실행 중이라는 뜻입니다.

브라우저에서 `http://localhost:8080`을 열면 nginx의 환영 페이지를 볼 수 있습니다. 터미널에서는 다음 명령으로 응답 헤더를 확인합니다.

```bash
# 웹 서버의 HTTP 응답 확인
curl -I http://localhost:8080
```

```text
HTTP/1.1 200 OK
Server: nginx/...
...
```

`200 OK`는 웹 서버가 요청에 정상 응답했다는 뜻입니다.

### 5.2 중지된 컨테이너의 수동 복구

![컨테이너 종료와 수동 재실행](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/18-lab-restart.svg)

컨테이너를 중지하고 상태를 확인합니다. `docker ps -a`는 중지된 컨테이너도 보여 줍니다.

```bash
# 실행 중인 컨테이너를 중지하고 종료 상태 확인
docker stop web-server-1
docker ps -a
```

```text
web-server-1
CONTAINER ID   IMAGE          STATUS                      NAMES
a1b2c3d4e5f6   nginx:latest   Exited (0) 5 seconds ago    web-server-1
```

`Exited`로 표시된 컨테이너는 요청을 처리하지 못합니다. 브라우저에서 페이지를 새로 요청하면 연결에 실패합니다. 재시작 정책을 설정하지 않은 이 실습에서는 사람이 다시 실행해야 합니다.

```bash
# 중지한 웹 서버를 다시 실행
docker start web-server-1
```

```text
web-server-1
```

브라우저를 새로 고침하면 웹 서버의 응답을 다시 확인할 수 있습니다.

Docker에도 종료된 컨테이너를 같은 서버에서 다시 실행하는 재시작 정책이 있습니다. 다만 사용자가 `docker stop`으로 중지한 경우에는 정책이 바로 다시 실행시키지 않습니다. 또한 서버 자체가 중단되면 이 정책만으로 다른 서버에 대체 컨테이너를 만들 수는 없습니다. [[9]](#ref-9)

### 5.3 여러 컨테이너의 수동 이미지 교체

![여러 웹 서버의 이미지를 하나씩 교체하는 흐름](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/33-lab-image-replacement.svg)

같은 웹 서버를 세 개 더 실행합니다. 컨테이너 안의 포트는 모두 80번이지만, 같은 호스트에서 연결할 포트와 컨테이너 이름은 각각 다르게 지정합니다.

```bash
# 같은 이미지로 웹 서버 세 개를 추가 실행
docker run -d --name web-server-2 -p 8081:80 nginx:latest
docker run -d --name web-server-3 -p 8082:80 nginx:latest
docker run -d --name web-server-4 -p 8083:80 nginx:latest
```

각 명령은 새 컨테이너 ID를 반환합니다. `docker ps`에서 웹 서버 네 개를 확인할 수 있습니다. 컨테이너를 늘릴 때마다 이름과 포트를 지정하는 작업이 반복됩니다.

이번에는 첫 번째 웹 서버의 이미지를 `nginx:alpine`으로 교체합니다. Alpine Linux 기반의 다른 이미지 구성을 선택하는 예시이며, 버전을 올리는 실습은 아닙니다. 기존 컨테이너를 중지하고 삭제한 뒤 같은 이름과 포트로 새 컨테이너를 실행합니다.

```bash
# 첫 번째 웹 서버를 다른 이미지로 교체
docker stop web-server-1
docker rm web-server-1
docker run -d --name web-server-1 -p 8080:80 nginx:alpine
```

```text
web-server-1
web-server-1
<새 컨테이너 ID>
```

`docker ps`에서 첫 번째 컨테이너의 `IMAGE`가 `nginx:alpine`으로 바뀌었는지 확인합니다. 교체 중에는 8080번 포트의 요청을 처리할 웹 서버가 잠시 없어집니다. 나머지 세 개도 바꾸려면 같은 작업을 각각 반복해야 합니다.

### 5.4 실습 정리와 운영 자동화의 필요성

실습을 마쳤다면 이번에 만든 컨테이너 네 개만 중지하고 삭제합니다.

```bash
# 실습에서 생성한 웹 서버 정리
docker stop web-server-1 web-server-2 web-server-3 web-server-4
docker rm web-server-1 web-server-2 web-server-3 web-server-4
```

각 명령은 처리한 컨테이너 이름을 출력합니다.

이 실습에서 이미지는 실행 환경을 준비해 주었지만, 컨테이너를 몇 개 유지할지와 언제 다시 실행하거나 교체할지는 사람이 판단했습니다. 서버와 컨테이너가 늘어나면 이런 작업을 개별 명령으로 반복하기 어렵습니다.

여러 웹 서버로 요청을 나누는 일, 응답하지 않는 애플리케이션을 감지하는 일, 교체 후에도 데이터를 보존하는 일도 필요합니다. 여기서는 이러한 운영 문제가 있다는 점까지만 짚습니다. Docker의 네트워크나 저장소 설정까지 익혀야 다음 내용을 읽을 수 있는 것은 아닙니다.

Kubernetes는 사용자가 원하는 운영 상태를 선언하면 각 구성요소가 그 상태를 유지하도록 동작합니다. 컨테이너 실행 명령을 익히는 것에서, 실행 이후의 관리를 자동화하는 방식으로 관심을 넓힐 차례입니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. 서버 자원을 나누려 VM이 등장했고, 실행 환경을 가볍게 옮기려 Container와 Docker가 등장했으며, 컨테이너가 늘자 Docker Compose와 Docker Swarm이 필요해졌습니다.
다음 글에서는 Kubernetes가 무엇인지, 왜 배우는지, 핵심 개념이 어떻게 이어지는지를 개략적으로 정리합니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Stack Overflow 2025 개발자 설문 결과 발표: Docker 사용 비율](https://stackoverflow.co/company/press/archive/stack-overflow-2025-developer-survey/)
- <a id="ref-2"></a>[2] [컨테이너와 VM 비교 공식 문서](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)
- <a id="ref-3"></a>[3] [Docker 자원 제한 공식 문서](https://docs.docker.com/engine/containers/resource_constraints/)
- <a id="ref-4"></a>[4] [Docker 구조 공식 문서](https://docs.docker.com/get-started/docker-overview/#docker-architecture)
- <a id="ref-5"></a>[5] [Docker 포트 공개 공식 문서](https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/)
- <a id="ref-6"></a>[6] [Docker Compose 공식 문서](https://docs.docker.com/compose/)
- <a id="ref-7"></a>[7] [Docker Swarm 공식 문서](https://docs.docker.com/engine/swarm/)
- <a id="ref-8"></a>[8] [Docker 공식 설치 안내](https://docs.docker.com/get-started/get-docker/)
- <a id="ref-9"></a>[9] [Docker 재시작 정책 공식 문서](https://docs.docker.com/engine/containers/start-containers-automatically/)
