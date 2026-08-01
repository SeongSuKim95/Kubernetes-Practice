# 1주차. 컨테이너는 왜 등장했고, Docker만으로는 왜 모자란가

> 15주 연재의 첫 글입니다. 이번 주는 Kubernetes 명령을 외우기보다, 기술이 왜 이런 순서로 쌓여 왔는지를 잡아 두고, Docker로 상자를 운용할 때 손이 가는 한계를 직접 겪어 봅니다. Docker를 처음 듣는 분도 따라올 수 있도록, 컨테이너가 무엇인지부터 풀어 씁니다.
>
> **다음 글**에서는 이번 주 실습에서 느낀 빈칸을 바탕으로, Kubernetes가 무엇인지·왜 배우는지·핵심 개념이 어떻게 이어지는지를 개략적으로 정리합니다.

## 들어가며

금요일 저녁, 쇼핑몰 앱에 작은 할인 배너를 올렸습니다. 로컬에서는 잘 됐는데 운영 서버만 흰 화면이 뜹니다. “내 노트북에서는 되는데?”라는 말이 채팅창에 올라옵니다. 다른 날에는 광고가 잘 먹혀 주문이 몰립니다. 서버 CPU는 붉게 타오르고, 누군가는 새 서버를 급히 빌리며 설정을 베껴 붙입니다. 새벽 세 시에는 알림이 울립니다. 웹은 살아 있는데 결제만 죽었고, 로그를 뒤지며 “누가 재시작할 건지”를 가위바위보합니다.

현대 애플리케이션을 운영해 본 사람이라면, 이런 장면을 한 번쯤은 떠올릴 수 있습니다. 기능 하나 고치는 일보다 **어디서 돌릴지, 어떻게 같게 맞출지, 죽으면 누가 살릴지**가 더 크게 다가오는 순간들입니다. 팀은 서버를 늘리고, 환경을 복사하고, 점검 스크립트를 쌓아 가며 버텨 왔지만, 앱이 웹·결제·알림·데이터베이스처럼 조각나고 트래픽이 출렁일수록 손으로는 따라가기 어려워졌습니다.

그 고민의 자리에서 기술도 차례로 바뀌었습니다. 남는 자원을 나누려다 가상 머신(Virtual Machine)이 퍼졌고, “내 컴퓨터와 서버를 같게” 만들려다 컨테이너(Container)와 Docker가 익숙해졌으며, 실행 단위가 여러 대·여러 서버로 늘어나자 배치와 복구를 맡기는 쪽으로 이어졌습니다. 그 끝에서 많은 팀이 Kubernetes라는 이름을 만납니다. 이번 글은 그 이름부터 외우기보다, **앞에서 본 발 구르는 장면들이 왜 이런 기술 순서로 이어졌는지**를 먼저 따라가 보는 준비입니다.

<div align="center">

![기술이 쌓여 온 큰 그림](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/01-journey.svg)

</div>

아래는 오늘 따라갈 큰 그림입니다. 이름들은 본문에서 하나씩 만납니다.

---


## 물리 서버가 남긴 고민

<div align="center">

![물리 서버 한 대에 앱 하나](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/02-physical-server.svg)

</div>

한동안은 서버 한 대에 애플리케이션 하나를 설치하는 일이 보통이었습니다. 단순하지만, CPU와 메모리가 남아도 다른 앱을 마음 놓고 올리기 어렵고, 서버 대수가 늘수록 관리 비용이 커지며, 물리 장비를 늘리는 부담도 커집니다. “이 서버 자원을 더 효율적으로 나눌 수는 없을까?”라는 질문이 가상 머신(Virtual Machine)으로 이어집니다.

---


## Virtual Machine — 컴퓨터를 통째로 나누다

<div align="center">

![Virtual Machine 구조](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/03-vm.svg)

</div>

Virtual Machine(가상 머신, VM)은 물리 하드웨어 위에 **Hypervisor(하이퍼바이저)** 를 두고, 그 위에 **Guest OS(게스트 운영체제)** 를 가진 가상 컴퓨터를 여러 대 올리는 방식입니다. Hypervisor는 한 대의 하드웨어를 여러 가상 컴퓨터에 나누어 주는 관리 계층이고, Guest OS는 각 가상 컴퓨터 안에 따로 설치되는 운영체제입니다.

<div align="center">

![Virtual Machine 비유](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/13-vm-houses.svg)

</div>

건물 하나에 독립된 세대를 여러 채 두는 일과 비슷합니다. 각 세대는 자신만의 수도·전기·현관을 가지듯, 각 VM은 자신만의 운영체제와 **Kernel(커널, 운영체제의 핵심)** 을 가집니다.

격리는 강합니다. 한 VM의 문제가 다른 VM으로 쉽게 번지지 않습니다. 물리 서버 한 대에 웹용 VM, 배치 작업용 VM, 내부 도구용 VM을 나눠 두면, 예전처럼 “이 서버 하나에 앱을 하나만” 올리는 낭비를 줄일 수 있습니다. 자원 문제는 한 걸음 나아갔습니다.

다만 VM은 **컴퓨터를 통째로** 복제하는 쪽에 가깝습니다. 그래서 쓰다 보면 불편이 쌓입니다.

예를 들어, 작은 API 서버 하나를 올리는 상황을 생각해 봅시다. 애플리케이션 자체는 메모리 수백 메가바이트면 충분한데, Guest OS를 띄우려면 수 기가바이트의 디스크와 적지 않은 RAM을 먼저 씁니다. 같은 물리 서버에 비슷한 앱을 열 개 올려야 한다면, 앱 열 개가 아니라 **OS 열 개**를 함께 감당해야 합니다. 밀도는 물리 서버 시절보다 나아졌어도, “앱만 올리는” 감각과는 거리가 있습니다.

기동 속도도 운영 감각을 바꿉니다. 트래픽이 잠깐 늘어서 가상 머신을 하나 더 만들고 싶을 때, VM은 부팅·네트워크 설정·패키지 확인까지 기다린 뒤에야 서비스에 합류하는 경우가 많습니다. 배포 과정이 “가상 머신을 준비해 서버에 올리고 확인한다”는 주기로 길어지면, 팀의 피드백 루프도 함께 느려집니다.

환경을 맞추려는 시도가 오히려 무게를 키우기도 합니다. 개발자가 노트북에서 돌린 구성과 테스트·운영이 달라 Node.js 버전, 라이브러리, OS 패키지가 어긋나면, 가장 직직한 대응 중 하나는 “잘 되는 VM을 통째로 복제해 옮기자”입니다. 환경은 비슷해질 수 있지만, 옮기는 단위가 운영체제까지 포함한 가상 머신 전체라 용량이 크고, 전송과 기동이 느리며, 보안 패치나 설정 변경도 Guest OS마다 따로 따라가야 합니다. 앱 하나를 고치려고 컴퓨터 한 대를 복제·배포·관리하는 셈이 됩니다.

정리하면 VM은 “한 서버의 자원을 나눈다”는 문제에는 답했지만, **가볍게 올리고, 빨리 늘고, 앱 단위로 같은 실행 환경을 옮긴다**는 요구에는 여전히 무거웠습니다. OS 전체가 아니라 애플리케이션이 필요한 실행 환경만 싸서 옮기고 싶다는 감각이, 다음 단계인 컨테이너(Container)로 이어집니다.

---


## Container와 Docker — 실행 환경을 가벼운 상자에

<div align="center">

![VM과 Container 비교](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/04-vm-vs-container.svg)

</div>

Container(컨테이너)는 Guest OS를 복제하지 않습니다. 애플리케이션과 그에 필요한 파일을 **Image(이미지, 실행에 필요한 파일을 묶어 둔 설계도)** 에 담고, 그 이미지가 실제로 떠 있는 프로세스를 **Container** 라고 부릅니다. 컨테이너가 돌아가는 실제 컴퓨터의 운영체제를 **Host(호스트) OS** 라고 부르며, 컨테이너들은 Host의 Kernel을 공유한 채 프로세스만 격리합니다. VM이 독립 주택에 가깝다면, Container는 기숙사 방에 가깝습니다. 건물의 수도·전기(커널)는 공유하되, 방마다 보이는 세계와 쓸 수 있는 자원의 한도는 나눕니다.

일상적인 감각으로 말하면 이런 일입니다. 노트북에 nginx를 직접 설치하면 OS 버전, 패키지, 설정 경로가 사람마다 달라집니다. 대신 “nginx가 들어 있는 상자”를 받아 열면, 그 상자 안에서는 같은 경로·같은 구성으로 웹 서버가 뜹니다. 개발 노트북과 테스트 서버, 운영 서버가 달라도 **같은 상자**를 쓰려는 것이 컨테이너의 매력입니다.

<div align="center">

![docker run 흐름](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/05-docker-flow.svg)

</div>

이 격리를 Linux Kernel이 이미 제공하던 기능으로 구현하고, 그 위를 다루기 쉽게 만든 대표 도구가 **Docker**입니다. 커널은 프로세스가 보는 **공간**(프로세스 목록·네트워크·파일 등)을 나누고, CPU·메모리 같은 **양**도 제한할 수 있습니다. 사용자가 터미널에서 치는 것은 보통 Docker Client(명령줄 도구)이고, 실제로 컨테이너를 만드는 일은 백그라운드의 Docker Daemon(데몬, 상주 관리 프로세스)이 맡습니다. `docker run`을 보내면 Daemon이 그 커널 기능을 호출해 컨테이너를 기동합니다. (공간·양을 나누는 커널 장치의 이름은 이후에 필요할 때 다시 꺼냅니다.)

<div align="center">

![Image와 Container](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/06-image-vs-container.svg)

</div>

Docker의 철학을 짧게 말하면, 가볍고, 한 번 만든 이미지를 어디서든 같게 돌리며, 환경을 **Dockerfile(이미지를 만드는 절차를 적은 파일)** 처럼 코드로 남긴다는 쪽에 가깝습니다. 여기서 Image와 Container를 헷갈리지 않는 것이 중요합니다. Image는 실행되지 않는 설계도이고, Container는 그 설계도로 실제로 떠 있는 프로세스입니다. 같은 nginx 이미지로 웹 서버 컨테이너를 여러 개 띄울 수 있는 이유도 여기에 있습니다.

여기까지가 “상자를 무엇으로 만들고, 무엇이 실제로 떠 있는가”입니다. 실습으로 넘어가기 전에 한 가지만 더 짚어둡니다. 웹 서버 컨테이너를 띄웠다면, 브라우저나 `curl`로 그 안에 닿을 길이 필요합니다. 그 길의 이름이 **포트(port)** 입니다.

<div align="center">

![포트 연결](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/11-port-mapping.svg)

</div>

포트는 한 컴퓨터 안에서 네트워크 요청을 받을 **프로세스(또는 서비스)를 가르키는 번호**입니다. 같은 서버에 웹·DB·캐시가 함께 있어도, 포트가 다르면 요청이 서로 다른 문으로 들어갑니다. 예를 들어 많은 웹 서버는 상자 **안**에서 80번을 듣고, 데이터베이스는 3306번을 듣는 식으로 역할이 갈립니다.

컨테이너는 호스트와 네트워크 공간이 나뉘어 있습니다. 그래서 상자 안에서 nginx가 80번을 듣고 있어도, 호스트(내 컴퓨터)의 브라우저가 곧바로 그 80번을 두드린다고 연결되지는 않습니다. Docker에서는 `-p 호스트포트:컨테이너포트`로 두 문을 이어 줍니다. `-p 8080:80`이면 “내 컴퓨터의 8080번으로 들어온 요청을, 컨테이너 안의 80번으로 넘겨라”는 뜻입니다. 호스트에서는 8080을 열고, 상자 안 규칙은 그대로 80을 유지하는 셈입니다.

실습에서는 이 감각을 명령으로 확인합니다. 이미지를 받아 컨테이너를 만들고, 포트를 연결한 뒤, 목록을 보고, 멈추고, 다시 살리는 흐름입니다. 각 옵션의 세부는 시나리오를 따라가며 그때그때 읽으면 됩니다.

---


## Docker Compose와 Docker Swarm — 컨테이너가 많아지면

컨테이너 하나만 띄우는 일은 `docker run`으로도 됩니다. 실제 서비스는 웹, 앱, DB, 캐시처럼 역할이 다른 상자가 함께 움직이는 경우가 많습니다. 여기서 두 가지 도구가 등장하게 됩니다. **Docker Compose**는 “한 서버 안의 여러 상자를 한 도면으로 정리하는 도구”이고, **Docker Swarm**은 “여러 서버에 상자를 나누어 올리고 운영을 맡기는 오케스트레이션”입니다. 먼저 Docker Compose가 푸는 문제부터 보겠습니다.

### Docker Compose — 한 서버 안의 상자들을 도면으로

<div align="center">

![Docker Compose 비유](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/14-compose-menu.svg)

</div>

매번 긴 `docker run`을 여러 줄 치면 실수하기 쉽고, “어떤 컨테이너를 어떤 순서로 올렸는지”도 남기기 어렵습니다. **Docker Compose**는 그 구성을 **YAML(들여쓰기로 구조를 적는 설정 파일 형식)** 한 장으로 적고 `docker compose up`으로 한꺼번에 올리는 도구입니다. 한 식당의 주문을 메뉴판으로 정리하는 일에 가깝습니다. 메뉴판(설정 파일)만 있으면 같은 조합을 다시 재현하기 쉽습니다.

다만 Docker Compose는 기본적으로 **단일 호스트(서버 한 대)** 를 전제로 합니다. 한 건물(서버) 안의 방(컨테이너) 배치를 도면으로 정리하는 도구이지, 여러 건물을 하나의 단지로 운영하는 도구는 아닙니다. 서버 한 대가 흔들리면 Docker Compose로 묶은 서비스도 함께 위험해집니다.

### 왜 오케스트레이션이 필요한가 — 상자가 늘었을 때의 운영

서버를 여러 대로 늘리거나, 같은 역할의 상자를 여러 개 두면 곧바로 “도면 한 장”만으로는 부족한 상황이 옵니다. 일상으로 옮겨 보면 이런 식입니다.

<div align="center">

![오케스트레이션 비유](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/15-cafe-stores.svg)

</div>

작은 카페가 잘되어 매장을 세 곳으로 늘렸다고 합시다. 손님(요청)이 늘면 바리스타(컨테이너)를 어디에 몇 명 둘지 정해야 하고, 한 매장이 문을 닫으면(서버 장애) 손님을 다른 매장으로 넘겨야 하며, “결제 창구”처럼 이름이 같은 서비스는 손님이 IP 주소를 외우지 않아도 찾아갈 수 있어야 합니다. 사람이 매장마다 전화로 “지금 몇 명 일하고 있어? 죽은 자리 채워 줘”를 반복하면, 밤샘 운영이 됩니다.

컨테이너 세계에서도 같은 일이 생깁니다. 어느 서버에 웹 상자를 둘지, 트래픽이 늘면 복제본을 몇 개 더 띄울지, 죽은 상자를 누가 다시 살릴지, 요청을 어떻게 나눌지, 상자 IP가 바뀌어도 이름으로 찾을 수 있는지를 사람이 매번 손으로 맞추기 어렵습니다. 이 운영을 플랫폼에 맡기는 계층이 **Container Orchestration(컨테이너 오케스트레이션)** 입니다. 오케스트라는 지휘자가 악기(상자)의 배치·박자·교체를 조율하듯, 여러 서버에 걸친 컨테이너의 배치·확장·복구·연결을 조율합니다.

### Docker Swarm — 여러 서버를 하나의 단지로

<div align="center">

![Docker Compose와 Docker Swarm](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/07-compose-to-swarm.svg)

</div>

**Docker Swarm**은 Docker가 제공하는 오케스트레이션입니다. Docker Compose가 “한 집의 도면”이라면, Docker Swarm은 “여러 건물을 하나의 단지로 운영하는 관리사무소”에 가깝습니다. 여러 **Node(노드, 클러스터에 참여하는 서버)** 를 **Cluster(클러스터, 여러 서버를 하나의 논리 단위로 묶은 것)** 로 묶고, 단지 안의 어느 건물에 상자를 둘지·죽으면 다시 살릴지를 플랫폼이 조율합니다. 세부 역할 이름은 나중에 필요할 때 보면 충분합니다.

정리하면 역할이 갈립니다. Docker Compose는 **한 서버에서 여러 컨테이너 구성을 선언·기동**하는 데 강하고, Docker Swarm은 **여러 서버에 걸쳐 배치·복구·규모 조절**을 돕는 데 강합니다. Docker Compose로 로컬·소규모 구성을 다루다가, 서버가 여러 대가 되는 지점에서 Docker Swarm 같은 오케스트레이션이 필요해지는 흐름입니다.

<div align="center">

![Docker Swarm과 Kubernetes 비유](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/16-complex-vs-city.svg)

</div>

**Kubernetes**도 Docker Swarm과 같은 층위의 **컨테이너 오케스트레이션**입니다. 여러 서버에 상자를 배치하고, 죽으면 다시 살리고, 규모를 조절하는 일을 플랫폼에 맡긴다는 큰 그림은 같습니다. 그런데도 실무에서는 Kubernetes를 더 자주 만납니다. Docker Swarm이 “단지 관리사무소”라면, Kubernetes는 같은 일을 하되 **운영 규칙을 훨씬 세밀하게 적을 수 있는 도시 운영 체계**에 가깝습니다.

Docker Swarm으로도 배포·규모 조절·기본적인 무중단 교체(롤링 업데이트)는 됩니다. Kubernetes가 보완하는 쪽은 그다음입니다. 상자마다 CPU·메모리를 얼마나 쓸지(자원 요청·한도), 부하가 늘면 언제 자동으로 늘릴지, 어떤 상자가 서로 통신해도 되는지(네트워크 규칙), 데이터가 컨테이너가 사라져도 어디에 남는지(스토리지), 누가 무엇을 조작할 수 있는지(권한)처럼 **운영 정책을 선언으로 남기고 강제**하는 장치가 더 풍부합니다. 단지 안에서 “문을 열고 사람을 배치한다”를 넘어, 층별 규칙·출입·창고·권한까지 도면에 적어 두는 셈입니다. 그 결과 모니터링·배포·패키징을 돕는 주변 도구들의 이야기도 Kubernetes를 전제로 흘러가는 경우가 많습니다.

이 글에서는 Kubernetes의 세부 장치까지는 들어가지 않습니다. **다음 주차**에서 Kubernetes가 왜 이토록 크고 왜 배워야 하는지, 핵심 개념이 어떻게 이어지는지를 본격적으로 다루고, **오늘은** 그 전에 Docker로 상자를 운용할 때 손이 가는 한계를 시나리오로 직접 겪어 보는 것으로 이 절을 마무리합니다. 글로만 읽은 “도시 운영”이 왜 필요한지, 아래 실습이 감각으로 남겨 줍니다.

---

## 실습: Docker로 운용 한계를 손으로 겪어 보기

앞에서 “단지 관리사무소”와 “도시 운영 체계”의 차이를 글로만 읽으면, Kubernetes가 왜 필요한지가 추상적으로 남기 쉽습니다. 그 차이를 제대로 이해하려면, **자동화가 없을 때 Docker 운용에서 사람이 무엇을 반복하는지**를 먼저 느껴 보는 편이 좋습니다. 아래 실습은 그 감각을 만들기 위한 것입니다. 목표는 명령을 외우는 것이 아니라, 상자가 죽거나 늘거나 바뀌었을 때 손이 가는 자리를 확인하는 일입니다. 각 시나리오 끝에서는 같은 문제가 Kubernetes에서 **어떤 방향으로 바뀌는지**만 한두 문장으로 연결합니다. 장치 이름과 자세한 구조는 **다음 글**에서 붙입니다.

Docker가 설치되어 있어야 합니다. (아직 없다면 Docker 공식 설치 안내를 따라 CLI가 동작하게 준비하면 됩니다.)

```bash
docker --version
```

```text
Docker version 27.x.x, build ...
```

버전이 보이면 CLI가 준비된 상태입니다.

---


### 시나리오 1. 기본 실행과 상태 확인

<div align="center">

![시나리오 1 기본 실행](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/17-lab-run.svg)

</div>

웹 서버 컨테이너를 백그라운드로 띄웁니다. `-p 8080:80`으로 호스트의 8080번을 컨테이너 안의 80번(nginx가 듣는 문)에 연결합니다. 이미지가 로컬에 없으면 Docker가 **레지스트리(이미지를 받아 두는 저장소)** 에서 내려받습니다.

```bash
docker run -d --name web-server-1 -p 8080:80 nginx:latest
```

```text
Unable to find image 'nginx:latest' locally
...
Status: Downloaded newer image for nginx:latest
a1b2c3d4e5f678901234567890abcdef1234567890abcdef1234567890abcd
```

실행 중인지, 로그와 상태가 어떤지 확인합니다.

```bash
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

`docker ps`는 실행 중만, `docker ps -a`는 중지된 것까지 보여 줍니다. `logs`와 `inspect`로 동작을 들여다볼 수 있습니다. Kubernetes에서도 목록·로그·상태를 보는 일은 비슷하지만, **원하는 개수를 계속 맞춰 가는 쪽**이 플랫폼에 더 가깝습니다. 그 장치는 이후 주차에서 만납니다.

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080
```

```text
200
```

---


### 시나리오 2. 종료 감지와 수동 복구

<div align="center">

![시나리오 2 수동 복구](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/18-lab-restart.svg)

</div>

컨테이너를 멈춥니다. 기본 설정에서는 자동으로 다시 살아나지 않습니다.

```bash
docker stop web-server-1
docker ps -a --filter name=web-server-1
```

```text
web-server-1

CONTAINER ID   IMAGE          STATUS                     NAMES
a1b2c3d4e5f6   nginx:latest   Exited (0) 5 seconds ago  web-server-1
```

```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 3 http://localhost:8080 || echo "failed"
```

```text
failed
```

사람이 다시 살립니다.

```bash
docker start web-server-1
docker ps --filter name=web-server-1
```

```text
web-server-1

CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES
a1b2c3d4e5f6   nginx:latest   Up 2 seconds   0.0.0.0:8080->80/tcp   web-server-1
```

`--restart=always`를 줄 수는 있지만, **서버(노드) 자체가 죽으면** 그 옵션만으로는 다른 서버로 옮기지 못합니다. Kubernetes에서는 상자가 죽거나 서버가 빠지면, **다른 자리에서 다시 원하는 개수를 맞추는 쪽**으로 문제를 바꿉니다. 구체적인 장치는 이후 주차에서 봅니다.

---


### 시나리오 3. 여러 컨테이너와 수동 업데이트

<div align="center">

![시나리오 3 수동 업데이트](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/19-lab-multi-update.svg)

</div>

같은 역할의 웹 서버를 더 띄웁니다. 포트는 각각 달라야 합니다.

```bash
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

이제 `web-server-1`만 새 이미지로 바꾼다고 가정합니다. stop → rm → 새 run을 직접 수행합니다.

```bash
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

나머지 세 개까지 같은 작업을 반복하면, 업데이트 중 일부 포트는 끊기고 되돌리기도 컨테이너마다 따로입니다. Kubernetes에서는 **새 버전을 도면에 적으면** 상자를 차례로 갈아 끼우고, 문제가 있으면 이전 도면으로 되돌리기 쉬운 편입니다. 그 흐름의 이름은 이후 주차에서 붙입니다.

---


### 시나리오 4. 메모리 부족(OOM Kill)

<div align="center">

![시나리오 4 OOM Kill](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/20-lab-oom.svg)

</div>

이번에는 메모리를 일부러 아주 작게 주고, 한도를 넘기면 커널이 프로세스를 죽이는지 확인합니다. (이 실험용 명령은 “메모리를 급히 쓰는 부하”를 만들기 위한 것이고, 각 옵션을 외울 필요는 없습니다.)

```bash
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

`OOMKilled=true`이면 메모리 한도에 걸려 커널이 프로세스를 죽인 상황에 가깝습니다. Docker는 제한을 걸 수는 있어도, 부족해졌을 때 한도를 알아서 키우거나 다른 서버로 옮기지는 않습니다. 메모리를 넉넉히 주고 다시 올리는 일도 사람이 합니다.

```bash
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

Kubernetes에서는 상자마다 쓸 수 있는 자원의 범위를 도면에 적고, 한 서버에서 감당하지 못하면 **다른 자리로 다시 맞추는** 쪽으로 확장할 여지가 있습니다. 자세한 내용은 이후 주차에서 이어갑니다.

---


### 시나리오 5. 로드 밸런싱을 손으로 그려 보기

<div align="center">

![시나리오 5 로드 밸런싱](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/21-lab-lb.svg)

</div>

지금 웹 서버는 포트가 제각각입니다.

```bash
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

컨테이너가 추가되거나 제거될 때마다 이 파일을 고치고 로드 밸런서를 재시작해야 합니다. Kubernetes에서는 **살아 있는 상자 목록을 플랫폼이 따라가며** 요청을 나누어, 목록을 사람이 매번 고쳐 쓰지 않는 방향으로 설계되어 있습니다. 그 장치의 이름은 이후 주차에서 만납니다.

이 시나리오는 개념 확인이 목적이므로, 로드 밸런서 컨테이너까지 꼭 띄우지 않아도 됩니다. 핵심은 **분산 대상이 바뀔 때마다 설정이 사람의 손이 간다**는 점입니다.

---


### 시나리오 6. 수동 스케일 아웃

<div align="center">

![시나리오 6 수동 스케일](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/22-lab-scale.svg)

</div>

트래픽이 늘었다고 가정하고 웹 서버를 세 개 더 올립니다. 포트도 직접 고릅니다.

```bash
docker run -d --name web-server-5 -p 8084:80 nginx:latest
docker run -d --name web-server-6 -p 8085:80 nginx:latest
docker run -d --name web-server-7 -p 8086:80 nginx:latest
docker ps --filter "name=web-server" --format "{{.Names}}" | wc -l
```

```text
...
7
```

줄이려면 다시 stop/rm을 반복하고, 앞에서 말한 로드 밸런서 설정도 함께 고쳐야 합니다. CPU 사용률에 맞춰 자동으로 늘고 줄지는 않습니다. Kubernetes에서는 **원하는 개수를 도면에 남기거나**, 부하에 따라 개수를 자동으로 맞추는 장치를 이후 주차에서 붙일 수 있습니다.

---


### 시나리오 7. 컨테이너는 Up인데 프로세스는 죽은 경우

<div align="center">

![시나리오 7 프로세스 사망](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/23-lab-zombie.svg)

</div>

`web-server-2` 안에서 nginx 프로세스를 강제로 죽입니다.

```bash
docker exec web-server-2 pkill nginx || true
sleep 2
docker ps --filter name=web-server-2
docker exec web-server-2 ps aux || echo "no process list"
```

환경에 따라 컨테이너 자체는 `Up`으로 남아 있는데 웹 프로세스는 사라진 상태가 될 수 있습니다.

```text
NAMES           STATUS
web-server-2    Up 3 minutes

...
(nginx master/worker가 보이지 않거나 exec가 실패할 수 있음)
```

Docker에도 `--health-cmd`로 헬스체크를 넣을 수 있지만, 실패했다고 해서 기본으로 새 컨테이너를 띄워 주지는 않습니다. 지금은 사람이 재시작합니다.

```bash
docker restart web-server-2
docker ps --filter name=web-server-2
```

```text
web-server-2
NAMES           STATUS
web-server-2    Up 3 seconds
```

Kubernetes에서는 “상자 껍데기가 떠 있는가”와 “요청을 받아도 되는가”를 나누어 보고, 실패하면 재시작하거나 손님을 다른 상자로 돌리는 쪽으로 이어집니다. 그 확인 장치는 이후 주차에서 다시 만납니다.

---


### 시나리오 8. 컨테이너 간 통신과 서비스 디스커버리

<div align="center">

![시나리오 8 서비스 디스커버리](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/24-lab-discovery.svg)

</div>

데이터베이스 컨테이너를 띄우고 IP를 확인한 뒤, 다른 컨테이너에서 그 IP로 접속을 시도합니다.

```bash
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

IP를 직접 적는 방식은, 컨테이너가 재생성되어 주소가 바뀌면 설정도 함께 고쳐야 합니다. 사용자 정의 네트워크를 만들면 이름 기반 연결이 한결 낫습니다.

```bash
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

그래도 네트워크와 연결을 사람이 관리해야 합니다. Kubernetes에서는 **안정적인 이름**으로 상대를 찾게 해, 상자 IP가 바뀌어도 설정을 덜 고치게 합니다. 그 이름·주소 체계는 이후 주차에서 다룹니다.

---


### 시나리오 9. 볼륨 없이 지우면 데이터도 사라진다

<div align="center">

![시나리오 9 볼륨](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/25-lab-volume.svg)

</div>

볼륨 없이 만든 데이터베이스를 삭제합니다.

```bash
docker stop mysql-db
docker rm mysql-db
echo "mysql-db removed (data in container filesystem is gone)"
```

```text
mysql-db
mysql-db
mysql-db removed (data in container filesystem is gone)
```

컨테이너의 쓰기가 가능한 계층에만 있던 데이터는 함께 사라집니다. 영속성이 필요하면 볼륨을 만들고 마운트합니다.

```bash
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

Docker에서도 볼륨은 쓸 수 있지만, 생성·백업·여러 서버 공유를 사람이 설계해야 합니다. Kubernetes에서는 저장 공간을 **도면에 요청해 받아 쓰는** 쪽으로 이 문제를 다룹니다. 이후 스토리지 주차에서 이어집니다.

---


### 시나리오 10. 한계를 한곳에 모아 보기

<div align="center">

![시나리오 10 한계 정리](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/26-lab-summary.svg)

</div>

지금까지 겪은 일을 앞에서 본 “상자 → 도면 → 단지 → 도시” 이야기와 맞춰 보면 흐름이 선명해집니다.

자동 복구가 없으면 `docker start`를 사람이 반복합니다. 스케일링이 수동이면 포트와 로드 밸런서 설정을 함께 고쳐야 합니다. 로드 밸런싱과 서비스 디스커버리가 없으면 upstream과 IP를 직접 관리합니다. 헬스체크가 약하면 “컨테이너는 Up인데 프로세스는 죽음”을 놓치기 쉽습니다. 롤링 업데이트는 컨테이너마다 stop/rm/run이고, 리소스 한도는 걸려도 자동으로 맞춰 주지 않으며, 데이터는 볼륨을 잊지 않아야 남습니다.

Kubernetes가 약속하는 쪽은, 원하는 상태를 선언하면 플랫폼이 차이를 줄인다는 방향입니다. 복구·부하 분산·이름 찾기·상태 확인·버전 교체·자동 확장·데이터 보관 같은 빈칸의 **이름**은 이후 주차에서 하나씩 붙습니다.

현재 상태를 한 번 봅니다.

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

```text
NAMES           STATUS          PORTS
mysql-db        Up ...          3306/tcp
app-server      Up ...
memory-test     Up ...
web-server-7    Up ...          0.0.0.0:8086->80/tcp
...
web-server-1    Up ...          0.0.0.0:8080->80/tcp
```

---

---


## 다음 글로 넘어가기 전에

이번 주에 따라온 줄기는 이렇습니다. 자원을 나누려 VM이 등장했고, 환경을 가볍게 옮기려 Container와 Docker가 등장했으며, 컨테이너가 늘자 Docker Compose와 Docker Swarm이 필요해졌습니다.
다음 글에서는 Kubernetes가 왜 이토록 크고 왜 배워야 하는지부터, API·클러스터·핵심 리소스·구성 요소·설계 철학까지를 한 번에 잡아 둡니다.

---

<!-- draft: split from 01-from-vm-to-kubernetes.publish.md (part 1/2) -->
