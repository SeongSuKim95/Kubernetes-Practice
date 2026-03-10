# Container Orchestration 이해하기 : Docker Swarm

## 목차

1. Docker Compose 등장 이후의 문제  
2. Container Orchestration의 등장  
3. Docker Swarm이란 무엇인가  
4. Docker Swarm 아키텍처  
5. Docker Swarm 핵심 개념  
6. Docker Swarm 네트워크와 서비스 관리  
7. Docker Swarm의 기능  
8. 정리  


# 1. Docker Compose 등장 이후의 문제

Docker Compose는 여러 컨테이너를 하나의 YAML 파일로 정의하고 동시에 실행할 수 있는 도구입니다.

예를 들어 다음과 같은 서비스 구성이 있을 수 있습니다.

- Web Server
- Application Server
- Database
- Cache
- Message Queue

이러한 구성은 `docker-compose.yml` 파일로 정의하고 다음 명령어로 실행할 수 있습니다.

```bash
docker compose up
```

하지만 Docker Compose에는 중요한 한계가 있습니다.

> Docker Compose는 **단일 서버 환경**에서만 동작합니다.

즉 다음과 같은 상황에서는 Compose만으로는 운영이 어렵습니다.

- 서버가 여러 대인 환경
- 서비스 확장이 필요한 경우
- 장애 발생 시 자동 복구 필요
- 여러 서버 간 로드 밸런싱 필요

이 문제는 **컨테이너 수가 증가할수록 더욱 복잡해집니다.**

이때 필요한 것이 바로 **Container Orchestration** 입니다.



# 2. Container Orchestration의 등장

Container Orchestration은 여러 컨테이너를 자동으로 배포, 관리, 확장하기 위한 시스템입니다.

<p align="center">
  <img src="../images/Introduction/1.1_Container_Ochestration_1.png" alt="컨테이너 오케스트레이션 개요 1" width="70%" />
</p>

Container Orchestration 시스템은 다음과 같은 기능을 제공합니다.

- **컨테이너 자동 배치 (Container Scheduling)**  
  > Orchestrator는 컨테이너를 실행할 노드를 자동으로 선택합니다. CPU, Memory 등의 자원 사용량을 고려하여 가장 적절한 Node에 컨테이너를 배치합니다.

- **서비스 확장 (Service Scaling)**  
  > 트래픽이 증가하면 컨테이너 수를 자동으로 늘리고, 트래픽이 감소하면 컨테이너 수를 줄입니다.

- **장애 복구 (Self-Healing)**  
  > 컨테이너가 종료되거나 노드에 장애가 발생하면 Orchestrator가 새로운 컨테이너를 자동으로 다시 실행합니다.

- **로드 밸런싱 (Load Balancing)**  
  > 사용자의 요청을 여러 컨테이너에 분산하여 처리합니다. 이를 통해 특정 컨테이너에 부하가 집중되지 않도록 합니다.

- **서비스 디스커버리 (Service Discovery)**  
  > 컨테이너의 IP 주소는 계속 변경될 수 있습니다. Service Discovery를 통해 서비스 이름을 기반으로 컨테이너 간 통신을 할 수 있습니다.

- **롤링 업데이트 (Rolling Update)**  
  > 서비스를 중단하지 않고 기존 컨테이너를 새로운 버전으로 점진적으로 교체합니다.

즉 컨테이너를 **하나씩 실행하는 것이 아니라 전체 시스템을 자동으로 관리하는 플랫폼**입니다.

대표적인 Container Orchestration 도구는 다음과 같습니다.

- Docker Swarm
- Kubernetes
- Apache Mesos

이 중 Docker에서 제공하는 오케스트레이션 시스템이 **Docker Swarm**입니다.


# 3. Docker Swarm이란 무엇인가

<p align="center">
  <img src="../images/Introduction/0.Swarm_Overview.png" width="80%">
</p>

> Docker Swarm은 여러 Docker Node를 하나의 Cluster로 묶고, Manager Node가 Worker Node에 컨테이너를 스케줄링하는 구조입니다.

Docker Swarm을 이해하기 위해서는 먼저 구성요소(**Node**와 **Cluster**)와 핵심 개념(**Service**와 **Task** 등)에 대해 이해해야 합니다.
## 3.1 Node 와 Cluster
### 3.1.1 Node

Node는 Docker Engine이 실행되는 하나의 서버를 의미합니다.

> 즉 Docker가 설치되어 컨테이너를 실행할 수 있는 하나의 컴퓨팅 자원을 Node라고 합니다.

### 3.1.2 Cluster

Cluster는 여러 Node가 모여 하나의 시스템처럼 동작하는 구조입니다.

> 즉 여러 서버가 네트워크로 연결되어 하나의 논리적인 시스템을 구성하는 것을 **Cluster**라고 합니다.

Docker Swarm에서는 여러 Node가 모여 하나의 **Cluster**를 구성합니다.

> Server = Node , Multiple Nodes = Cluster

Docker Swarm 클러스터는 크게 두 가지 노드로 구성됩니다.

<p align="center">
  <img src="../images/Introduction/3.1.2_Cluster_Overview.png" width="80%">
</p>

- Manager Node : 클러스터의 **Control Plane** 역할을 수행
  - 클러스터 상태 관리 및 저장
  - 노드 관리
  - 서비스 스케줄링

- Worker Node : 실제 컨테이너가 실행되는 서버
  - 컨테이너 실행
  - 서비스 처리
  - Manager로부터 작업 수신

> Manager 노드는 기본적으로 Worker 노드의 역할을 포함하며, 운영환경에서 다중화하는 것이 좋습니다.

## 3.2 Service와 Task

Docker Swarm 환경에서는 컨테이너가 단순히 실행되는 것이 아니라  
**Service → Task → Container** 구조로 관리됩니다.

<p align="center">
  <img src="../images/Introduction/5_Service_and_Task.png" width="80%">
</p>

### 3.2.1 Service

> Service는 Swarm에서 **애플리케이션을 배포하는 기본 제어 단위**이며, 같은 이미지로 생성되는 컨테이너의 집합 입니다.

Service는 다음과 같은 정보를 정의합니다.

- 사용할 Docker Image
- 실행할 컨테이너 수
- 네트워크 / 포트 설정

예시

```bash
docker service create --name web nginx
```

## 3.2.2 Task

> Task는 Service가 생성한 **실행 작업 단위**입니다.

Service가 실행되면 Swarm은 여러 Task를 생성하며, 각 Task는 하나의 컨테이너를 실행합니다.

## 3.2.3 Replica

> Replica는 동일한 컨테이너를 여러 개 실행하는 개념입니다.

```bash
docker service create --replicas 3 nginx
```

Replica를 늘리면 서비스 처리량을 확장할 수 있습니다.

## 3.4 Docker Swarm Scheduler

> Scheduler는 어떤 Node에서 Task를 실행할지 결정하는 시스템입니다.

Scheduler는 다음과 같은 정보를 기반으로 컨테이너를 배치합니다.

- 노드의 CPU / Memory 사용량
- 현재 실행 중인 컨테이너 수
- 클러스터 상태

## 3.5 Docker Swarm 네트워크와 서비스 관리

Docker Swarm은 컨테이너 간 통신을 위해 **Overlay Network**를 사용합니다.

Overlay Network는 여러 서버에 분산된 컨테이너들이 하나의 네트워크처럼 통신할 수 있도록 합니다.
<p align="center">
  <img src="../images/Introduction/swarm_overlay_network.png" width="80%">
</p>

이 네트워크를 통해 다음 기능이 제공됩니다.

- 서비스 간 통신
- 자동 로드 밸런싱
- 서비스 디스커버리

# 4. Docker Swarm의 기능

Swarm은 위에서 언급된 자원과 개념을 통해 다음과 같은 Container Ochestration 기능을 제공합니다.

- 컨테이너 스케줄링
- 서비스 복제
- 장애 발생 시 컨테이너 재시작
- 로드 밸런싱
- 클러스터 관리

# 5. 정리

Docker Compose는 여러 컨테이너를 하나의 서버에서 실행하기 위한 도구입니다.

하지만 서비스 규모가 커지면 여러 서버에서 컨테이너를 운영해야 하며  
이를 자동으로 관리할 수 있는 시스템이 필요합니다.

이 문제를 해결하기 위해 등장한 개념이 **Container Orchestration**입니다.

Docker Swarm은 Docker에서 제공하는 Container Orchestration 시스템으로 다음 기능을 제공합니다.

- 클러스터 관리
- 컨테이너 스케줄링
- 서비스 확장
- 자동 복구