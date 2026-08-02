<!--
  게시용 복사본입니다. GitHub Flavored Markdown용이며, 이미지 경로는 GitHub raw URL입니다.
  원본(로컬 미리보기용): 01-background-and-docker-limits.draft.md
  이미지 저장소: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap01. Container의 등장 배경과 Docker

> 15주 연재의 첫 글입니다. Container가 왜 등장했는지 Bare Metal과 VM을 거친 배경을 정리하고, Docker로 컨테이너를 운용할 때 사람이 직접 반복하는 작업을 겪어 봅니다. Docker를 처음 듣는 분도 따라올 수 있도록, 컨테이너가 무엇인지부터 풀어 씁니다.

## 들어가며

금요일 저녁, 쇼핑몰 앱에 작은 할인 배너를 올렸습니다. 로컬에서는 앱이 잘 됐는데 운영 서버만 흰 화면이 뜹니다. “내 컴퓨터에서는 되는데?”라는 말이 채팅창에 올라옵니다. 다른 날에는 광고가 잘 먹혀 주문이 몰립니다. 서버 CPU 사용률이 높아지고, 누군가는 새 서버를 급히 빌리며 서버 설정을 베껴 붙입니다. 새벽 세 시에는 알림이 울립니다. 웹은 살아 있는데 결제만 죽었고, 로그를 뒤지며 누가 결제 서비스를 재시작할지 정하지 못한 채 시간을 씁니다.

현대 애플리케이션을 운영해 본 사람이라면, 이런 상황을 한 번쯤은 떠올릴 수 있습니다. 기능 하나 고치는 일보다 **앱을 어디서 돌릴지, 실행 환경을 어떻게 같게 맞출지, 앱이 죽으면 누가 앱을 살릴지**가 더 큰 문제가 되는 순간입니다. 팀은 서버를 늘리고, 실행 환경을 복사하고, 점검 스크립트를 쌓아 가며 그 운영을 버텨 왔습니다. 그런데 앱이 웹과 결제, 알림과 데이터베이스처럼 나뉘고 트래픽이 크게 변할수록 손으로는 그 운영을 따라가기 어려워졌습니다.

그 문제를 풀기 위해 기술도 차례로 바뀌었습니다. 남는 서버 자원을 나누려다 가상 머신(Virtual Machine)이 퍼졌습니다. “내 컴퓨터와 서버의 실행 환경을 같게” 만들려다 컨테이너(Container)와 Docker가 익숙해졌습니다. 실행 단위가 여러 대, 여러 서버로 늘어나자 컨테이너의 배치와 복구를 플랫폼에 맡기는 쪽으로 이어졌습니다. 그 끝에서 많은 팀이 Kubernetes라는 이름을 만납니다. 이번 글은 그 이름부터 외우기보다, **앞에서 본 운영 문제가 왜 VM과 컨테이너를 거쳐, 배치와 복구를 플랫폼에 맡기는 단계로 이어졌는지**를 먼저 따라가 보는 준비입니다.

![가상화에서 Kubernetes까지의 발전 흐름](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/01-journey.svg)

위 그림은 오늘 다룰 전체 흐름입니다. 기술 이름들은 본문에서 하나씩 만납니다.

## 1. 출발점: 물리 서버 한 대에 앱 하나만 올리던 때

![Bare Metal 구조](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/02-physical-server.svg)

이 흐름의 출발점은 **Bare Metal**(베어메탈, 가상화 계층 없이 운영체제가 물리 하드웨어 위에 바로 올라가는 서버)입니다. 가상 컴퓨터를 중간에 두지 않고, **Hardware** 위에 **Host OS**를 올리고, 그 위에 애플리케이션을 설치하는 구성입니다.

한동안은 이런 물리 서버 한 대에 애플리케이션 하나를 두는 일이 보통이었습니다. 구조가 단순해서 이해하기 쉽고, 성능도 직관적입니다. 서버에 설치한 OS와 앱이 하드웨어를 직접 쓰니까요.

실제 운영에서는 한계가 분명합니다. CPU와 메모리가 남아도 다른 앱을 같은 서버에 마음 놓고 올리기 어렵습니다. 라이브러리 버전이나 포트, 장애 범위가 서로 얽히기 쉽기 때문입니다. 한 앱이 자원을 많이 쓰면 같은 서버의 다른 앱도 영향을 받습니다. 앱이 늘면 서버를 새로 사고, OS와 앱을 설치하고, OS와 앱에 패치를 적용하며, 장애에 대응하는 일이 **서버 대수만큼** 불어납니다. 물리 장비를 늘리는 비용과 시간도 함께 커집니다.

단순함은 강점이었지만, “이 서버에 남은 자원을 더 효율적으로 나눌 수는 없을까?”라는 질문이 남았습니다. 그 질문이 다음 단계인 **Virtual Machine**(가상 머신)으로 이어집니다.

## 2. 남는 서버 자원을 나누다 — Virtual Machine

![Virtual Machine 구조](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/03-vm.svg)

Virtual Machine(가상 머신, VM)은 Bare Metal로 쓰이던 물리 하드웨어 위에 **Hypervisor**(하이퍼바이저)를 두고, 그 위에 **Guest OS**(게스트 운영체제)를 가진 가상 컴퓨터를 여러 대 올리는 방식입니다. Hypervisor는 한 대의 하드웨어를 여러 가상 컴퓨터에 나누어 주는 관리 계층이고, Guest OS는 각 가상 컴퓨터 안에 따로 설치되는 운영체제입니다.

![Virtual Machine 구조 보충](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/13-vm-houses.svg)

각 VM은 자신만의 운영체제와 **Kernel**(커널, 운영체제의 핵심)을 가집니다. 물리 서버 하나를 여러 대의 가상 컴퓨터로 나누는 방식입니다.

격리는 강합니다. 한 VM의 문제가 다른 VM으로 쉽게 번지지 않습니다. 물리 서버 한 대에 쇼핑몰 웹용 VM, 결제 API용 VM, 상품 DB용 VM을 나눠 두면, Bare Metal 시절처럼 “이 서버 하나에 앱을 하나만” 올리는 낭비를 줄일 수 있습니다. 자원 활용은 Bare Metal 때보다 나아졌습니다.

다만 VM은 **컴퓨터를 통째로** 복제하는 쪽에 가깝습니다. 그래서 VM을 쓰다 보면 불편이 쌓입니다.

예를 들어, 작은 API 서버 하나를 올리는 상황을 생각해 봅시다. 애플리케이션 자체는 메모리 수백 메가바이트면 충분한데, Guest OS를 띄우려면 수 기가바이트의 디스크와 적지 않은 RAM을 먼저 씁니다. 같은 물리 서버에 비슷한 앱을 열 개 올려야 한다면, 앱 열 개가 아니라 **OS 열 개**를 함께 감당해야 합니다. 배포 밀도는 물리 서버 시절보다 나아졌어도, “앱만 올리는” 요구와는 거리가 있습니다.

가상 머신의 기동 속도도 운영 방식을 바꿉니다. 트래픽이 잠깐 늘어서 가상 머신을 하나 더 만들고 싶을 때, VM은 부팅, 네트워크 설정, 패키지 확인까지 기다린 뒤에야 서비스에 합류하는 경우가 많습니다. 배포 과정이 “가상 머신을 준비해 서버에 올리고 동작을 확인한다”는 주기로 길어지면, 수정한 내용을 서비스에 반영해 확인하기까지도 함께 느려집니다.

환경을 맞추려는 시도가 오히려 일을 더 크게 만들기도 합니다. 개발자가 로컬에서 돌린 구성과 테스트, 운영이 달라지면 Node.js 버전이나 라이브러리, OS 패키지가 어긋납니다. 그때 가장 정직한 대응 중 하나는 “잘 되는 VM을 통째로 복제해 옮기자”입니다. 환경은 비슷해질 수 있습니다. 다만 옮기는 단위가 운영체제까지 포함한 가상 머신 전체라 용량이 큽니다. 가상 머신 복제본의 전송과 기동이 느리고, 보안 패치나 설정 변경도 Guest OS마다 따로 적용해야 합니다. 앱 하나를 고치려고 컴퓨터 한 대를 복제하고 배포하며 관리하는 셈이 됩니다.

정리하면 VM은 “한 서버의 자원을 나눈다”는 문제에는 답했지만, **앱을 가볍게 올리고, 빨리 늘고, 앱 단위로 같은 실행 환경을 옮긴다**는 요구에는 여전히 무거웠습니다. OS 전체가 아니라 애플리케이션이 필요한 실행 환경만 싸서 옮기고 싶다는 필요가, 다음 단계인 컨테이너(Container)로 이어집니다.

## 3. 내 컴퓨터와 서버의 실행 환경을 같게 만들다 — Container와 Docker

![성수선임과 함께 배우는 쿠버네티스 : Container 캐릭터](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-container.png)

*성수선임과 함께 배우는 쿠버네티스 : Container 캐릭터*

이 연재에서는 Kubernetes의 핵심 개념을 기억하기 쉽게, 개념마다 캐릭터를 하나씩 둡니다. 아래에서 처음 만날 **Container** 캐릭터는 앞으로 글이 이어질 때도 계속 등장합니다. 추상적인 이름을 장면으로 떠올리는 길잡이가 될 것입니다.

Container 캐릭터는 화물 컨테이너처럼 생긴 큐브입니다. 몸 앞의 `</>` 표시는 애플리케이션 코드를 담아 실행한다는 뜻을, 코너의 보강재는 필요한 실행 환경을 하나로 묶는다는 느낌을 담았습니다.

![VM과 Container 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/04-vm-vs-container.svg)

Container(컨테이너)는 Guest OS를 복제하지 않습니다. 애플리케이션과 그에 필요한 파일을 **Image**(이미지, 실행에 필요한 파일을 묶어 둔 설계도)에 담습니다. 그 이미지가 실제로 떠 있는 프로세스를 **Container**라고 부릅니다. 컨테이너가 돌아가는 실제 컴퓨터의 운영체제는 **Host**(호스트) OS입니다. 컨테이너들은 Host의 Kernel을 공유한 채 프로세스만 격리합니다. Container는 VM보다 가볍고, 같은 Host 위에서 프로세스 단위로 앱을 격리합니다.

로컬에 nginx(웹 서버 프로그램)를 직접 설치하면 OS 버전이나 패키지, 설정 경로가 사람마다 달라집니다. 대신 nginx 실행에 필요한 파일을 Image로 묶어 두면, 그 Image로 띄운 Container 안에서는 같은 경로와 구성으로 웹 서버가 뜹니다. 로컬과 테스트 서버, 운영 서버가 달라도 **같은 Image**를 쓰려는 것이 컨테이너의 매력입니다.

![Docker 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/29-docker-official-logo.svg)

이 격리를 Linux Kernel이 이미 제공하던 기능으로 구현하고, 그 위를 다루기 쉽게 만든 대표 도구가 **Docker**입니다. Docker는 2013년 Solomon Hykes가 이끌던 dotCloud에서 오픈소스로 공개했고, 같은 해 회사 이름도 Docker Inc.로 바뀌었습니다. Linux Kernel의 컨테이너 기능을 **Image**, **CLI**(Command Line Interface, 명령줄 도구), **레지스트리**(이미지를 받아 두는 저장소)로 다루기 쉽게 만든 것이 핵심입니다.

![docker run 흐름](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/05-docker-flow.svg)

컨테이너가 “전용 환경”처럼 보이는 이유는 Docker가 새로 OS를 만든 것이 아니라, Linux Kernel이 이미 제공하던 기능을 묶었기 때문입니다. 기억해 둘 이름은 셋입니다.

**Namespace**(네임스페이스)는 프로세스가 보는 **공간**을 나눕니다. 프로세스 목록, 네트워크, 마운트된 파일 시스템처럼 “무엇이 보이는지”를 컨테이너마다 따로 둡니다. Kernel은 하나인데, 컨테이너 안에서는 자신만의 작은 세상처럼 보입니다.

**cgroups**(컨트롤 그룹)는 CPU, 메모리 같은 **양**을 제한합니다. 한 컨테이너가 Host의 자원을 혼자 다 쓰지 못하게 막는 장치입니다. 컨테이너마다 쓸 수 있는 자원의 상한을 둘 때도 같은 통제를 씁니다.

**OverlayFS**(오버레이 파일 시스템)는 Image의 여러 층(레이어)을 겹쳐, 컨테이너가 하나의 root 파일 시스템처럼 보게 합니다. Image는 커널을 담지 않고, 앱과 라이브러리, 설정이 들어 있는 **사용자 공간** 스냅샷에 가깝습니다.

사용자가 터미널에서 치는 것은 보통 Docker Client(명령줄 도구)입니다. 실제로 컨테이너를 만드는 일은 백그라운드의 Docker Daemon(데몬, 상주 관리 프로세스)이 맡습니다. `docker run`을 보내면 Daemon이 Namespace, cgroups, 파일 시스템 구성을 호출해 컨테이너를 기동합니다. Docker는 그 커널 기능 위의 **관리 계층**이라고 보면 됩니다.

![Image와 Container](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/06-image-vs-container.svg)

Docker의 철학을 짧게 말하면 이렇습니다. 실행 단위가 가볍고, 한 번 만든 이미지를 어디서든 같게 돌리며, 실행 환경을 **Dockerfile**(이미지를 만드는 절차를 적은 파일)처럼 코드로 남긴다는 쪽에 가깝습니다. 여기서 Image와 Container를 헷갈리지 않는 것이 중요합니다. Image는 실행되지 않는 설계도이고, Container는 그 설계도로 실제로 떠 있는 프로세스입니다. 같은 nginx 이미지로 웹 서버 컨테이너를 여러 개 띄울 수 있는 이유도 여기에 있습니다.

여기까지가 “Image로 무엇을 만들고, Container로 무엇이 실제로 떠 있는가”입니다. 실습으로 넘어가기 전에 한 가지만 더 설명합니다. 웹 서버 컨테이너를 띄웠다면, 브라우저나 `curl`로 접속할 방법이 필요합니다. 그 방법의 이름이 **포트**(port)입니다.

![포트 연결](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/11-port-mapping.svg)

포트는 한 컴퓨터 안에서 네트워크 요청을 받을 프로세스(또는 서비스)를 가리키는 **번호**입니다. 같은 서버에 웹, DB, 캐시가 함께 있어도, 포트가 다르면 요청이 서로 다른 대상으로 들어갑니다. 예를 들어 많은 웹 서버는 컨테이너 **안**에서 80번을 듣고, 데이터베이스는 3306번을 듣는 식으로 역할이 갈립니다.

컨테이너는 호스트와 네트워크 공간이 나뉘어 있습니다. 그래서 컨테이너 안에서 nginx가 80번을 듣고 있어도, 호스트(내 컴퓨터)의 브라우저가 곧바로 그 80번에 접속한다고 연결되지는 않습니다. Docker에서는 `-p 호스트포트:컨테이너포트`로 호스트 포트와 컨테이너 포트를 연결합니다. `-p 8080:80`이면 “내 컴퓨터의 8080번으로 들어온 요청을, 컨테이너 안의 80번으로 넘겨라”는 뜻입니다. 호스트에서는 8080을 열고, 컨테이너 안에서는 그대로 80을 유지하는 셈입니다.

실습에서는 이 내용을 명령으로 확인합니다. 이미지를 받아 컨테이너를 만들고, 포트를 연결한 뒤, 컨테이너 목록을 보고, 컨테이너를 멈춘 뒤 그 컨테이너를 다시 살리는 흐름입니다. 각 옵션의 세부는 시나리오를 따라가며 그때그때 읽으면 됩니다.

## 4. 컨테이너가 여러 대, 여러 서버로 늘면 — Compose와 Swarm

컨테이너 하나만 띄우는 일은 `docker run`으로도 됩니다. 실제 서비스는 웹과 DB처럼 역할이 다른 컨테이너가 함께 움직이는 경우가 많습니다. 여기서 두 가지 도구가 등장합니다. **Docker Compose**는 한 서버 안의 여러 컨테이너 구성을 파일로 정리해 한꺼번에 올리는 도구입니다. **Docker Swarm**은 여러 서버에 컨테이너를 나누어 올리고, 컨테이너가 죽으면 컨테이너를 다시 살리는 일을 플랫폼에 맡기는 도구입니다. 먼저 Docker Compose가 푸는 문제부터 보겠습니다.

### 4.1 한 서버 안 구성을 파일로 묶다 — Docker Compose

![Docker Compose 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/30-compose-official-logo.svg)

**Docker Compose**는 여러 컨테이너로 구성된 애플리케이션을 YAML로 정의해 한꺼번에 올리고 내리는 도구입니다. 2014년에 1.0이 공개되었고, 지금은 `docker compose` 플러그인으로 Docker CLI와 함께 쓰는 경우가 많습니다.

![Docker Compose](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/14-compose-menu.svg)

매번 긴 `docker run`을 여러 줄 치면 실수하기 쉽고, “어떤 컨테이너를 어떤 순서로 올렸는지”도 남기기 어렵습니다. Docker Compose는 그 구성을 **YAML**(들여쓰기로 구조를 적는 설정 파일 형식) 한 장으로 적고 `docker compose up`으로 한꺼번에 올리는 도구입니다. 설정 파일만 있으면 같은 조합을 다시 재현하기 쉽습니다.

다만 Docker Compose는 기본적으로 **단일 호스트**(서버 한 대)를 전제로 합니다. 한 서버 안의 컨테이너 구성을 정리하는 도구이지, 여러 서버를 하나의 클러스터로 운영하는 도구는 아닙니다. 서버 한 대가 장애를 내면 Docker Compose로 묶은 서비스도 함께 위험해집니다.

### 4.2 여러 서버에서는 배치와 복구를 사람이 맞춰야 한다

![오케스트레이션이 필요한 이유](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/32-why-orchestration.svg)

서버를 여러 대로 늘리거나, 같은 역할의 컨테이너를 여러 개 두면, 한 서버용 설정 파일만으로는 부족한 상황이 옵니다. 여러 창고에 물건을 나눠 두고도, 주문마다 사람이 전화로 “어느 창고에서 꺼내 보낼지”를 맞추는 일과 비슷합니다.

그림처럼 서버 A와 C에는 웹, 앱, DB 컨테이너가 떠 있고, 서버 B만 장애로 멈춘 상황을 생각해 봅시다. 사람은 매번 이런 판단을 손으로 맞춰야 합니다. 어느 서버에 웹 컨테이너를 둘지, 웹 컨테이너 복제본을 몇 개 띄울지, 죽은 컨테이너를 누가 다시 살릴지입니다. 요청을 여러 웹 컨테이너에 나누거나, 컨테이너 IP가 바뀌어도 서비스 이름으로 컨테이너를 찾는 일도 같은 부담입니다.

이 운영을 플랫폼에 맡기는 계층이 **Container Orchestration**(컨테이너 오케스트레이션)입니다. 여러 서버에 걸친 컨테이너의 배치와 복구, 연결을 자동으로 조율합니다.

### 4.3 배치와 복구를 플랫폼에 맡기다 — Docker Swarm

![Docker Swarm 아이콘](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/31-swarm-official-logo.svg)

**Docker Swarm**은 Docker가 제공하는 컨테이너 오케스트레이션입니다. 2016년 Docker Engine 1.12부터 Swarm mode가 엔진에 포함되어, 여러 서버를 하나의 클러스터처럼 묶고 서비스를 배치하거나 복구할 수 있습니다.

![Docker Compose와 Docker Swarm](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/07-compose-to-swarm.svg)

여러 **Node**(노드, 클러스터에 참여하는 서버)를 **Cluster**(클러스터, 여러 서버를 하나의 논리 단위로 묶은 것)로 묶고, 어느 노드에 컨테이너를 둘지, 컨테이너가 죽으면 컨테이너를 다시 살릴지를 플랫폼이 조율합니다.

정리하면 역할이 갈립니다. Docker Compose는 **한 서버에서 여러 컨테이너 구성을 선언하고 기동하는 데** 강하고, Docker Swarm은 **여러 서버에 걸쳐 컨테이너를 배치하고 복구하며 서비스 규모를 조절하는 일**을 돕는 데 강합니다. Docker Compose로 로컬이나 소규모 컨테이너 구성을 다루다가, 서버가 여러 대가 되는 지점에서 Docker Swarm 같은 오케스트레이션이 필요해지는 흐름입니다.

![Docker Swarm과 Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/16-complex-vs-city.svg)

**Kubernetes**도 Docker Swarm과 같은 종류의 **컨테이너 오케스트레이션**입니다. 여러 서버에 컨테이너를 배치하고, 컨테이너가 죽으면 컨테이너를 다시 살리고, 서비스 규모를 조절하는 일을 플랫폼에 맡긴다는 점은 같습니다. 그런데도 실무에서는 Kubernetes를 더 자주 만납니다. Docker Swarm보다 **운영 정책을 더 세밀하게 선언하고 강제할 수 있는 기능**이 많기 때문입니다.

Docker Swarm으로도 서비스 배포와 규모 조절, 기본적인 무중단 교체(롤링 업데이트)는 됩니다. Kubernetes가 다음에 보완하는 부분은 다음과 같습니다. 자원 요청과 한도, 자동 확장, 네트워크 규칙, 스토리지, 권한처럼 **운영 정책을 선언으로 남기고 강제**하는 기능이 더 풍부합니다. 그 결과 모니터링과 배포를 돕는 주변 도구들도 Kubernetes를 전제로 기능이 맞춰진 경우가 많습니다.

이 글에서는 Kubernetes의 세부 기능까지는 들어가지 않습니다. **오늘은** Docker로 컨테이너를 운용할 때 사람이 직접 반복하는 작업을 시나리오로 겪어 보는 것으로 이 절을 마무리합니다. 아래 실습이 그 작업을 직접 확인하게 해 줍니다.

## 5. 배치와 복구를 손으로 해 보면 보이는 Docker의 한계

앞에서 Docker Swarm과 Kubernetes의 차이를 글로만 읽으면, Kubernetes가 왜 필요한지 구체적으로 와닿지 않기 쉽습니다. 그 차이를 제대로 이해하려면, **자동화가 없을 때 Docker 운용에서 사람이 무엇을 반복하는지**를 먼저 확인하는 편이 좋습니다. 아래 실습은 그 확인을 위한 것입니다. 목표는 명령을 외우는 것이 아니라, 컨테이너가 죽거나 늘거나 바뀌었을 때 사람이 직접 해야 하는 작업을 확인하는 일입니다. 각 시나리오 끝에서는 같은 문제가 Kubernetes에서 **어떻게 달라지는지**만 한두 문장으로 연결합니다.

Docker가 설치되어 있어야 합니다. (아직 없다면 Docker 공식 설치 안내를 따라 CLI가 동작하게 준비하면 됩니다.)

```bash
# 실습 환경에 Docker CLI가 준비됐는지 확인하는 명령
docker --version
```

```text
Docker version 27.x.x, build ...
```

버전이 보이면 CLI가 준비된 상태입니다.

### 5.1 기본 실행과 상태 확인

![시나리오 1 기본 실행](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/17-lab-run.svg)

웹 서버 컨테이너를 백그라운드로 띄웁니다. `-p 8080:80`으로 호스트의 8080번을 컨테이너 안의 80번(nginx가 수신하는 포트)에 연결합니다. 이미지가 로컬에 없으면 Docker가 레지스트리에서 내려받습니다.

```bash
# 시나리오 시작: nginx 웹 서버를 올려 기본 운용을 보기 위한 명령
docker run -d --name web-server-1 -p 8080:80 nginx:latest
```

```text
Unable to find image 'nginx:latest' locally
...
Status: Downloaded newer image for nginx:latest
a1b2c3d4e5f678901234567890abcdef1234567890abcdef1234567890abcd
```

컨테이너가 실행 중인지, 로그와 상태가 어떤지 확인합니다.

```bash
# 방금 올린 웹 서버가 떠 있는지 목록, 로그, 상태로 확인하는 명령
docker ps
docker logs web-server-1 | head -5
docker inspect web-server-1 --format='{{.State.Status}}'
```

```text
CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES
a1b2c3d4e5f6   nginx:latest   Up 5 seconds   0.0.0.0:8080->80/tcp   web-server-1

/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
...
running
```

`docker ps`는 실행 중만, `docker ps -a`는 중지된 것까지 보여 줍니다. 목록의 `STATUS`에 나오는 `Up`은 컨테이너가 **실행 중**으로 표시된다는 뜻입니다. `Exited`는 컨테이너가 종료된 상태입니다. `logs`와 `inspect`로 동작을 더 들여다볼 수 있습니다. Kubernetes에서도 목록, 로그, 상태를 보는 일은 비슷하지만, **원하는 컨테이너 개수를 계속 맞추는 일**을 플랫폼이 더 많이 맡습니다.

```bash
# 포트 연결이 됐는지 HTTP 상태 코드로 확인하는 명령
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080
```

```text
200
```

### 5.2 종료 감지와 수동 복구

![시나리오 2 수동 복구](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/18-lab-restart.svg)

컨테이너를 멈춥니다. 기본 설정에서는 멈춘 컨테이너가 자동으로 다시 살아나지 않습니다.

```bash
# 자동 복구가 없음을 보이려고 컨테이너를 직접 멈추는 명령
docker stop web-server-1
docker ps -a --filter name=web-server-1
```

```text
web-server-1

CONTAINER ID   IMAGE          STATUS                     NAMES
a1b2c3d4e5f6   nginx:latest   Exited (0) 5 seconds ago  web-server-1
```

```bash
# 컨테이너를 멈춘 뒤 서비스가 끊겼는지 확인하는 명령
curl -s -o /dev/null -w "%{http_code}\n" --max-time 3 http://localhost:8080 || echo "failed"
```

```text
failed
```

사람이 중지된 컨테이너를 다시 살립니다.

```bash
# 중지된 컨테이너를 사람이 다시 살리는 명령
docker start web-server-1
docker ps --filter name=web-server-1
```

```text
web-server-1

CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES
a1b2c3d4e5f6   nginx:latest   Up 2 seconds   0.0.0.0:8080->80/tcp   web-server-1
```

`--restart=always`를 줄 수는 있지만, **서버**(노드) 자체가 죽으면 그 옵션만으로는 다른 서버로 옮기지 못합니다. Kubernetes에서는 컨테이너가 죽거나 서버가 빠지면, **다른 서버에서 다시 원하는 컨테이너 개수를 맞춥니다**.

### 5.3 여러 컨테이너와 수동 업데이트

![시나리오 3 수동 업데이트](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/19-lab-multi-update.svg)

같은 역할의 웹 서버를 더 띄웁니다. 포트는 각각 달라야 합니다.

```bash
# 수동 스케일: 웹 서버를 포트마다 따로 늘리는 명령
docker run -d --name web-server-2 -p 8081:80 nginx:latest
docker run -d --name web-server-3 -p 8082:80 nginx:latest
docker run -d --name web-server-4 -p 8083:80 nginx:latest
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

```text
NAMES           STATUS          PORTS
web-server-4    Up 3 seconds    0.0.0.0:8083->80/tcp
web-server-3    Up 4 seconds    0.0.0.0:8082->80/tcp
web-server-2    Up 5 seconds    0.0.0.0:8081->80/tcp
web-server-1    Up 2 minutes    0.0.0.0:8080->80/tcp
```

이제 `web-server-1`만 새 이미지로 바꾼다고 가정합니다. stop한 뒤 rm하고, 새 run을 직접 수행합니다.

```bash
# 수동 업데이트: 컨테이너마다 stop/rm/run으로 이미지를 바꾸는 명령
docker stop web-server-1
docker rm web-server-1
docker run -d --name web-server-1 -p 8080:80 nginx:1.21
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

```text
web-server-1
web-server-1
...
NAMES           IMAGE         STATUS
web-server-1    nginx:1.21    Up 3 seconds
web-server-4    nginx:latest  Up 1 minute
web-server-3    nginx:latest  Up 1 minute
web-server-2    nginx:latest  Up 1 minute
```

나머지 세 개 컨테이너까지 같은 작업을 반복하면, 업데이트 중 일부 포트는 끊기고 컨테이너를 이전 이미지 버전으로 되돌리기도 컨테이너마다 따로입니다. Kubernetes에서는 **매니페스트**(manifest, 원하는 상태를 적어 두는 설정 파일)에 새 버전을 적으면 컨테이너를 차례로 교체하고, 문제가 있으면 이전 설정으로 되돌리기 쉬운 편입니다.

### 5.4 메모리 부족

![시나리오 4 OOM Kill](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/20-lab-oom.svg)

이번에는 메모리를 일부러 아주 작게 주고, 한도를 넘기면 커널이 프로세스를 죽이는지 확인합니다. (이 실험용 명령은 “메모리를 급히 쓰는 부하”를 만들기 위한 것이고, 각 옵션을 외울 필요는 없습니다.)

```bash
# 리소스 한도: 메모리 제한이 낮을 때 OOM이 나는지 보는 명령
docker run -d --name memory-test --memory=10m --memory-swap=10m \
  alpine sh -c "tail -f /dev/null & sleep 1 && dd if=/dev/zero of=/dev/null bs=1M"
sleep 3
docker ps -a --filter name=memory-test
docker inspect memory-test --format='OOMKilled={{.State.OOMKilled}} Status={{.State.Status}}'
```

```text
...
NAMES          STATUS
memory-test    Exited (137) 2 seconds ago

OOMKilled=true Status=exited
```

`OOMKilled=true`이면 메모리 한도에 걸려 커널이 프로세스를 죽인 상황에 가깝습니다. Docker는 메모리 제한을 걸 수는 있어도, 메모리가 부족해졌을 때 한도를 알아서 키우거나 컨테이너를 다른 서버로 옮기지는 않습니다. 메모리 한도를 넉넉히 주고 컨테이너를 다시 올리는 일도 사람이 합니다.

```bash
# 메모리 한도를 넉넉히 주고 다시 올려 정상 유지되는지 보는 명령
docker rm memory-test
docker run -d --name memory-test --memory=100m --memory-swap=100m \
  alpine sh -c "tail -f /dev/null"
docker ps --filter name=memory-test
```

```text
memory-test
...
NAMES          STATUS
memory-test    Up 2 seconds
```

Kubernetes에서는 컨테이너마다 쓸 수 있는 자원의 범위를 매니페스트에 적고, 한 서버에서 감당하지 못하면 **컨테이너 배치를 다른 서버로 다시 맞출 수 있습니다**.

### 5.5 로드 밸런싱을 손으로 그려 보기

![시나리오 5 로드 밸런싱](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/21-lab-lb.svg)

지금 웹 서버는 포트가 제각각입니다.

```bash
# 로드 밸런서에 넣을 호스트 포트 목록을 확인하는 명령
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Ports}}"
```

```text
NAMES           PORTS
web-server-1    0.0.0.0:8080->80/tcp
web-server-2    0.0.0.0:8081->80/tcp
web-server-3    0.0.0.0:8082->80/tcp
web-server-4    0.0.0.0:8083->80/tcp
```

사용자는 8080부터 8083을 모두 기억해야 하고, 트래픽을 나누려면 앞단에 별도 로드 밸런서(요청을 여러 서버로 나누는 장치)가 필요합니다. 앞단 설정에 “어느 포트로 보낼지”를 나열하는 예시는 대략 이런 형태입니다. (`host.docker.internal`은 컨테이너에서 내 컴퓨터 쪽을 가리킬 때 쓰는 이름입니다.)

```nginx
# 앞단이 웹 서버 포트를 수동으로 나열해야 함을 보이는 설정 예시
upstream backend {
    server host.docker.internal:8080;
    server host.docker.internal:8081;
    server host.docker.internal:8082;
    server host.docker.internal:8083;
}
server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

컨테이너가 추가되거나 제거될 때마다 이 파일을 고치고 로드 밸런서를 재시작해야 합니다. Kubernetes에서는 **살아 있는 컨테이너 목록을 플랫폼이 따라가며** 요청을 나누어, 목록을 사람이 매번 고쳐 쓰지 않도록 설계되어 있습니다.

이 시나리오는 개념 확인이 목적이므로, 로드 밸런서 컨테이너까지 꼭 띄우지 않아도 됩니다. 핵심은 **분산 대상이 바뀔 때마다 로드 밸런서 설정을 사람이 직접 고쳐야 한다**는 점입니다.

### 5.6 수동 스케일 아웃

![시나리오 6 수동 스케일](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/22-lab-scale.svg)

스케일 아웃은 같은 역할의 컨테이너 개수를 늘려 트래픽을 감당하는 일입니다. 트래픽이 늘었다고 가정하고 웹 서버를 세 개 더 올립니다. 포트도 직접 고릅니다.

```bash
# 사람이 upstream에 적을 대상이 늘어남을 보이려고 웹 서버를 더 띄우는 명령
docker run -d --name web-server-5 -p 8084:80 nginx:latest
docker run -d --name web-server-6 -p 8085:80 nginx:latest
docker run -d --name web-server-7 -p 8086:80 nginx:latest
docker ps --filter "name=web-server" --format "{{.Names}}" | wc -l
```

```text
...
7
```

컨테이너 개수를 줄이려면 다시 stop/rm을 반복하고, 앞에서 말한 로드 밸런서 설정도 함께 고쳐야 합니다. CPU 사용률에 맞춰 컨테이너 개수가 자동으로 늘고 줄지는 않습니다. Kubernetes에서는 **원하는 컨테이너 개수를 매니페스트에 남기거나**, 부하에 따라 컨테이너 개수를 자동으로 맞출 수 있습니다.

### 5.7 컨테이너는 실행 중인데 웹 서버는 죽은 경우

![시나리오 7 프로세스 사망](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/23-lab-zombie.svg)

앞에서 `docker ps`의 `Up`이 컨테이너 실행 중 표시라고 했습니다. 그런데 그 표시만으로는 “컨테이너 안에서 웹 서버가 요청을 받을 수 있는가”까지는 보장되지 않습니다. `web-server-2` 안에서 nginx를 강제로 죽여, 그 차이를 확인해 봅니다.

```bash
# 컨테이너는 실행 중인데 웹 서버만 죽은 상태를 재현하는 명령
docker exec web-server-2 pkill nginx || true
sleep 2
docker ps --filter name=web-server-2
docker exec web-server-2 ps aux || echo "no process list"
```

환경에 따라 `docker ps`에는 여전히 `Up`(실행 중)으로 보이는데, 컨테이너 안 웹 서버는 사라져 요청에 응답하지 못하는 상태가 될 수 있습니다.

```text
NAMES           STATUS
web-server-2    Up 3 minutes

...
(nginx master/worker가 보이지 않거나 exec가 실패할 수 있음)
```

Docker에도 `--health-cmd`로 **헬스체크**(컨테이너 안 서비스가 요청을 받을 수 있는지 주기적으로 확인하는 검사)를 넣을 수 있지만, 실패했다고 해서 기본으로 새 컨테이너를 띄워 주지는 않습니다. 지금은 사람이 컨테이너를 재시작합니다.

```bash
# 헬스체크 자동 조치가 없을 때 사람이 재시작하는 명령
docker restart web-server-2
docker ps --filter name=web-server-2
```

```text
web-server-2
NAMES           STATUS
web-server-2    Up 3 seconds
```

Kubernetes에서는 “컨테이너가 떠 있는가”와 “요청을 받아도 되는가”를 나누어 보고, 실패하면 컨테이너를 재시작하거나 요청을 다른 컨테이너로 돌립니다.

### 5.8 컨테이너 간 통신과 서비스 디스커버리

![시나리오 8 서비스 디스커버리](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/24-lab-discovery.svg)

서비스 디스커버리는 상대 컨테이너를 바뀌는 IP가 아니라 안정적인 이름으로 찾는 일입니다. 데이터베이스 컨테이너를 띄우고 IP를 확인한 뒤, 다른 컨테이너에서 그 IP로 접속을 시도합니다.

```bash
# 서비스 디스커버리: DB IP를 직접 조회해야 하는 상황을 만드는 명령
docker run -d --name mysql-db \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=testdb \
  mysql:8.0
sleep 8
DB_IP=$(docker inspect mysql-db --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "MySQL IP: $DB_IP"
```

```text
...
MySQL IP: 172.17.0.x
```

IP를 직접 적는 방식은, 컨테이너가 재생성되어 주소가 바뀌면 설정도 함께 고쳐야 합니다. 사용자 정의 네트워크를 만들면 이름 기반 연결이 더 낫습니다.

```bash
# 이름 기반 연결을 위해 사용자 정의 네트워크로 묶는 명령
docker network create app-network
docker network connect app-network mysql-db
docker run -d --name app-server --network app-network \
  -e MYSQL_HOST=mysql-db \
  alpine sh -c "apk add --no-cache mysql-client >/dev/null && tail -f /dev/null"
docker exec app-server sh -c 'echo MYSQL_HOST=$MYSQL_HOST'
```

```text
app-network
...
MYSQL_HOST=mysql-db
```

그래도 네트워크와 컨테이너 연결을 사람이 관리해야 합니다. Kubernetes에서는 **안정적인 서비스 이름**으로 상대 컨테이너를 찾게 해, 컨테이너 IP가 바뀌어도 앱 설정을 덜 고치게 합니다.

### 5.9 볼륨 없이 지우면 데이터도 사라진다

![시나리오 9 볼륨](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/25-lab-volume.svg)

볼륨(Volume)은 컨테이너를 지워도 남길 데이터를 컨테이너 밖에 두는 저장 공간입니다. 먼저 볼륨 없이 만든 데이터베이스를 삭제해, 데이터가 함께 사라지는지 확인합니다.

```bash
# 볼륨 없이 컨테이너를 지우면 데이터가 사라짐을 보이는 명령
docker stop mysql-db
docker rm mysql-db
echo "mysql-db removed (data in container filesystem is gone)"
```

```text
mysql-db
mysql-db
mysql-db removed (data in container filesystem is gone)
```

컨테이너의 쓰기가 가능한 계층에만 있던 데이터는 컨테이너와 함께 사라집니다. 데이터 영속성이 필요하면 볼륨을 만들고 컨테이너에 마운트합니다.

```bash
# 데이터를 남기기 위해 볼륨을 붙여 MySQL을 다시 올리는 명령
docker volume create db-data
docker run -d --name mysql-db \
  -v db-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=testdb \
  mysql:8.0
docker volume inspect db-data --format='Name={{.Name}} Mountpoint={{.Mountpoint}}'
```

```text
db-data
...
Name=db-data Mountpoint=/var/lib/docker/volumes/db-data/_data
```

Docker에서도 볼륨은 쓸 수 있지만, 볼륨의 생성과 백업, 여러 서버 공유를 사람이 설계해야 합니다. Kubernetes에서는 저장 공간을 **매니페스트에 요청해 받아 쓰는** 쪽으로 이 문제를 다룹니다.

### 5.10 한계를 한곳에 모아 보기

![시나리오 10 한계 정리](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/26-lab-summary.svg)

지금까지 겪은 일을 앞에서 본 배경과 맞춰 보면 관계가 분명해집니다.

자동 복구가 없으면 사람이 `docker start`로 컨테이너 기동을 반복합니다. 스케일링이 수동이면 포트와 로드 밸런서 설정을 함께 고쳐야 합니다. 로드 밸런싱과 서비스 디스커버리가 없으면 앞단이 가리킬 서버 목록과 컨테이너 IP를 직접 관리합니다. 헬스체크가 약하면 “컨테이너는 실행 중인데 웹 서버는 죽음” 상태를 놓치기 쉽습니다. 이미지 교체(롤링 업데이트)는 컨테이너마다 stop/rm/run입니다. 리소스 한도는 걸려도 플랫폼이 컨테이너 배치를 자동으로 맞춰 주지 않습니다. 데이터는 볼륨을 잊지 않아야 남습니다.

Kubernetes는 원하는 상태를 선언하면 플랫폼이 실제 상태와의 차이를 줄입니다. 복구, 부하 분산, 서비스 발견처럼 앞에서 손으로 맞춘 일을 플랫폼이 대신하는 쪽에 가깝습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. 서버 자원을 나누려 VM이 등장했고, 실행 환경을 가볍게 옮기려 Container와 Docker가 등장했으며, 컨테이너가 늘자 Docker Compose와 Docker Swarm이 필요해졌습니다.
다음 글에서는 Kubernetes가 무엇인지, 왜 배우는지, 핵심 개념이 어떻게 이어지는지를 개략적으로 정리합니다.
