# 용어 정의

## Docker 기본 개념

### Image (이미지)
- 실행 환경의 설계도(Template)로, 읽기 전용이며 레이어 구조를 가집니다.
- 실행되지 않는 정적 파일이며, 하나의 이미지로 여러 컨테이너를 생성할 수 있습니다.
- 예: `nginx:latest`, `node:18`

### Container (컨테이너)
- Image를 기반으로 실행된 프로세스 인스턴스입니다.
- Image가 메모리에 로드되어 Namespace와 Cgroups가 설정된 후 실행되는 격리된 프로세스입니다.
- 하나의 Image로 여러 개의 Container를 동시에 생성할 수 있습니다.

**비유**: Image는 설계도, Container는 그 설계도를 기반으로 실제로 실행된 프로세스

### VM (Virtual Machine) vs Container
- **VM**: OS 단위 가상화로, 각 VM이 독립적인 Kernel을 가집니다. 강력한 격리를 제공하지만 무겁습니다.
- **Container**: 프로세스 단위 격리로, Host OS의 Kernel을 공유합니다. 가볍고 빠르지만 격리는 프로세스 레벨에서 이루어집니다.

### Namespace (Docker)
- Linux Kernel 기능으로, 프로세스가 독립된 환경에 있는 것처럼 보이게 합니다.
- PID, 네트워크, 파일 시스템, 사용자 공간을 분리합니다.
- Docker에서 컨테이너 간 격리를 구현하는 핵심 기술입니다.

### Cgroups (Control Groups)
- Linux Kernel 기능으로, 자원 사용량(CPU, Memory, I/O)을 제한합니다.
- Namespace가 공간을 나누고, Cgroups가 자원을 통제합니다.

### Docker Compose
- 여러 컨테이너로 이루어진 애플리케이션을 하나의 YAML 파일로 정의하고 실행하는 도구입니다.
- **단일 서버 환경**에서만 동작합니다.
- 예: `docker-compose.yml` 파일로 웹 서버, 데이터베이스, 캐시를 함께 실행

## Docker Swarm 개념

### Node (노드)
- 클러스터를 구성하는 개별 도커 서버를 의미합니다.
- Docker Engine이 실행되는 하나의 서버이며, 한 서버에 하나의 Docker Daemon을 실행하기 때문에 노드는 곧 서버라고 이해할 수 있습니다.
- **Kubernetes의 Node와 유사하지만**, Docker Swarm에서는 Manager Node가 Worker 역할도 수행할 수 있습니다.

### Cluster (클러스터)
- 여러 Node가 모여 하나의 시스템처럼 동작하는 구조입니다.
- 여러 서버가 네트워크로 연결되어 하나의 논리적인 시스템을 구성합니다.
- **Kubernetes의 Cluster와 개념적으로 동일**합니다.

### Manager Node (매니저 노드)
- 클러스터 관리와 컨테이너 오케스트레이션을 담당합니다.
- 클러스터의 Control Plane 역할을 수행하며, 클러스터 상태 관리 및 저장(Raft 알고리즘 사용), 노드 관리, 서비스 스케줄링을 담당합니다.
- **Kubernetes의 마스터 노드(Master Node, 현재는 Control Plane)와 같은 역할**이라고 할 수 있습니다.
- **Docker Swarm의 특징**: Manager Node도 기본적으로 Worker Node의 역할을 같이 수행할 수 있습니다. 물론 스케줄링을 임의로 막는 것도 가능합니다.

### Worker Node (워커 노드)
- 컨테이너 기반 서비스(Service)들이 실제 구동되는 노드를 의미합니다.
- Manager의 명령을 받아 컨테이너를 생성하고 상태를 체크합니다.
- **Kubernetes와 다른 점**: Docker Swarm에서는 Manager Node도 기본적으로 Worker Node의 역할을 같이 수행할 수 있습니다. 물론 스케줄링을 임의로 막는 것도 가능합니다.

### Service (서비스) - Docker Swarm
- 노드에서 수행하고자 하는 작업들을 정의해놓은 것으로, 클러스터 안에서 구동시킬 컨테이너 묶음을 정의한 객체입니다.
- Swarm에서 애플리케이션을 배포하는 기본 제어 단위이며, 도커 스웜에서의 기본적인 배포 단위로 취급됩니다.
- 하나의 서비스는 하나의 이미지를 기반으로 구동되며, 이들 각각이 전체 애플리케이션의 구동에 필요한 개별적인 마이크로서비스(microservice)로 기능합니다.
- 사용할 Docker Image, 실행할 컨테이너 수, 네트워크/포트 설정을 정의합니다.
- **Kubernetes의 Service와는 다른 개념**입니다. Kubernetes의 Service는 Pod에 대한 네트워크 접근을 제공하는 리소스입니다.

### Task (태스크) - Docker Swarm
- 클러스터를 통해 서비스를 구동시킬 때, 도커 스웜은 해당 서비스의 요구 사항에 맞춰 실제 마이크로서비스가 동작할 도커 컨테이너를 구성하여 노드에 분배합니다. 이것을 태스크(Task)라고 합니다.
- Service가 생성한 실행 작업 단위입니다.
- 하나의 서비스는 지정된 복제본(replica) 수에 따라 여러 개의 태스크를 가질 수 있으며, 각각의 태스크에는 하나씩의 컨테이너가 포함됩니다.
- **Kubernetes의 Pod와 유사한 역할**이지만, Task는 항상 하나의 컨테이너만 포함합니다.

### Replica (레플리카) - Docker Swarm
- 동일한 컨테이너를 여러 개 실행하는 개념입니다.
- 서비스 처리량을 확장하기 위해 사용됩니다.
- **Kubernetes의 ReplicaSet과 유사한 개념**이지만, Docker Swarm에서는 Service에 직접 정의됩니다.

### Stack (스택)
- 하나 이상의 Service로 구성된 다중 컨테이너 애플리케이션을 묶는 개념입니다.
- Docker Compose와 유사한 YAML 파일 형식으로 정의되며, 여러 Service를 한 번에 배포하고 관리할 수 있습니다.
- **Docker Compose와의 차이**: Stack은 여러 호스트에 걸쳐 서비스를 배포할 수 있지만, Docker Compose는 단일 서버에서만 동작합니다.

### Scheduler (스케줄러) - Docker Swarm
- 도커 스웜에서 스케줄링은 서비스 명세에 따라 태스크(컨테이너)를 노드에 분배하는 작업을 의미합니다.
- Manager Node에 내장되어 있으며, 어떤 Node에서 Task를 실행할지 결정하는 시스템입니다.
- 노드의 CPU/Memory 사용량, 현재 실행 중인 컨테이너 수, 클러스터 상태 등을 기반으로 컨테이너를 배치합니다.
- 노드별 설정 변경 또는 라벨링(labeling)을 통해 스케줄링 가능한 노드의 범위를 제한할 수도 있습니다.
- **Kubernetes의 Scheduler와 유사한 역할**이지만, Kubernetes의 Scheduler는 Control Plane의 독립적인 컴포넌트입니다.

### Overlay Network (오버레이 네트워크)
- 여러 서버에 분산된 컨테이너들이 하나의 네트워크처럼 통신할 수 있도록 하는 네트워크입니다.
- Docker Swarm과 Kubernetes 모두 사용하지만, 구현 방식이 다릅니다.

### Service Discovery (서비스 디스커버리) - Docker Swarm
- 내장된 DNS 서버를 통해 서비스 이름을 기반으로 컨테이너 간 통신을 가능하게 합니다.
- 컨테이너의 IP 주소가 변경되어도 서비스 이름으로 접근할 수 있습니다.
- **Kubernetes의 Service Discovery와 유사하지만**, Kubernetes는 더 복잡한 DNS 및 라벨 셀렉터 메커니즘을 사용합니다.

### Ingress Network (인그레스 네트워크)
- Swarm이 자동으로 생성하는 Overlay 네트워크입니다.
- 외부에서 클러스터로 들어오는 트래픽을 처리하며, Round-robin 방식으로 로드 밸런싱을 수행합니다.
- **Kubernetes의 Ingress와는 다른 개념**입니다. Kubernetes의 Ingress는 HTTP/HTTPS 라우팅 규칙을 정의하는 리소스입니다.

### Docker-gwbridge
- 각 노드의 컨테이너가 외부 네트워크와 통신하기 위한 브리지입니다.
- VTEP (VXLAN Tunnel Endpoint) 역할을 수행하며, Overlay 네트워크와 호스트 네트워크 간의 연결을 담당합니다.

### Raft 합의 알고리즘
- 분산 시스템에서 여러 노드 간 일관된 상태를 유지하기 위한 합의 알고리즘입니다.
- Docker Swarm에서는 Manager 노드들이 Raft를 사용하여 클러스터 상태를 동기화합니다.
- **Kubernetes는 etcd를 사용**하며, etcd도 내부적으로 Raft 알고리즘을 사용합니다.

## Kubernetes 개념

### Control Plane (컨트롤 플레인)
- 클러스터의 두뇌 역할을 하는 관리 계층입니다.
- API Server, Scheduler, Controller Manager, etcd 등으로 구성됩니다.
- **Docker Swarm의 Manager Node와 유사한 역할**이지만, Kubernetes에서는 Control Plane과 Worker Node가 명확히 분리됩니다.

### API Server (kube-apiserver)
- Kubernetes의 **중앙 관문(Entry Point)** 으로, `kubectl`/컨트롤러/노드(Kubelet 등)의 모든 요청이 거치는 API 서버입니다.
- 인증/인가, 요청 유효성 검증을 수행하고, 클러스터 상태를 etcd에 읽고/쓰는 창구 역할을 합니다.

### Scheduler (kube-scheduler)
- 아직 노드가 정해지지 않은 Pod를 감지해, 노드 자원/제약 조건을 고려하여 **어느 노드에 배치할지**를 결정합니다.
- 컨테이너를 실행하지는 않으며, 스케줄링 결과(노드 할당)를 API Server를 통해 반영합니다.

### Controller Manager (kube-controller-manager)
- 여러 컨트롤러(Deployment/ReplicaSet/Node 등)를 묶어 실행하며, Desired State와 Current State의 차이를 감지해 **보정(Reconcile)** 을 수행합니다.
- 예: Pod 개수가 줄면 다시 생성되도록 요청해 상태를 유지합니다.

### etcd
- Kubernetes 클러스터 상태를 저장하는 **분산 Key-Value 데이터베이스**입니다.
- Control Plane의 단일 진실 소스(Single Source of Truth)로, 안정적인 운영을 위해 백업/쿼럼 구성이 중요합니다.

### Worker Node (워커 노드) - Kubernetes
- 실제 Pod가 실행되는 서버입니다.
- Kubelet, Kube Proxy, Container Runtime으로 구성됩니다.
- **Docker Swarm의 Worker Node와 개념적으로 유사**하지만, Kubernetes에서는 Control Plane이 Worker 역할을 수행하지 않습니다.

### Kubelet
- 각 Worker Node에서 동작하는 에이전트로, API Server의 Pod 스펙을 받아 **Container Runtime**을 통해 컨테이너를 생성/시작/중지합니다.
- Pod/노드 상태를 주기적으로 API Server에 보고합니다.

### kube-proxy
- Service/Endpoints 정보를 바탕으로 iptables/IPVS 규칙을 구성해 **Service IP → Pod IP** 로 트래픽이 전달되도록 합니다.
- Service의 로드밸런싱/네트워크 추상화를 노드 수준에서 구현합니다.

### Container Runtime (컨테이너 런타임)
- 이미지를 내려받고 컨테이너의 파일시스템/네트워크를 준비한 뒤, 프로세스를 실제로 실행·종료하는 실행 엔진입니다.
- 대표적으로 containerd, CRI-O 등이 있으며, Kubelet은 CRI를 통해 런타임과 통신합니다.

### CRI (Container Runtime Interface)
- Kubernetes(Kubelet)가 컨테이너 런타임과 통신하기 위한 표준 인터페이스입니다.

### Pod (파드)
- Kubernetes에서 스케줄링되는 최소 단위입니다.
- 하나 이상의 컨테이너와 공유 볼륨, 네트워크 네임스페이스를 포함합니다.
- 같은 Pod 안의 컨테이너는 항상 같은 노드에서 함께 배치되고, localhost 네트워크를 공유합니다.
- **Docker Swarm의 Task와 유사하지만**, Pod는 여러 컨테이너를 포함할 수 있습니다.

### Deployment (디플로이먼트)
- 배포를 위한 상위 리소스이며, 롤링 업데이트/롤백 같은 배포 기능을 제공합니다.
- 일반적으로 내부적으로 ReplicaSet을 생성·관리하여 원하는 replicas 수를 유지합니다.

### Service (서비스) - Kubernetes
- Pod에 대한 네트워크 접근을 제공하는 리소스입니다.
- Pod의 IP 주소가 변경되어도 Service를 통해 안정적으로 접근할 수 있습니다.
- **Docker Swarm의 Service와는 완전히 다른 개념**입니다. Docker Swarm의 Service는 배포 단위이고, Kubernetes의 Service는 네트워크 추상화입니다.

### Ingress (인그레스)
- “도메인/경로 → Service” 같은 HTTP/HTTPS 라우팅 규칙과 TLS 종료 등을 정의하는 **리소스(설정)** 입니다.
- Ingress는 규칙을 담는 객체이며, 실제 트래픽 처리는 Ingress Controller가 수행합니다.

### Ingress Controller (인그레스 컨트롤러)
- Ingress 리소스를 Watch 하여 실제 L7 프록시/로드밸런서 설정으로 적용하는 **실행 컴포넌트**입니다.
- 보통 Worker Node에 Pod(Deployment/DaemonSet)로 배포되어 외부 트래픽을 직접 수신합니다.

### Namespace (네임스페이스) - Kubernetes
- 클러스터 내에서 리소스를 논리적으로 분리하는 메커니즘입니다.
- 리소스 이름 충돌을 방지하고, 권한 관리와 리소스 격리에 사용됩니다.
- **Docker의 Namespace와는 완전히 다른 개념**입니다. Docker의 Namespace는 Linux Kernel 기능이고, Kubernetes의 Namespace는 클러스터 리소스 관리 기능입니다.

### ReplicaSet (레플리카셋)
- 지정된 수의 Pod 복제본을 유지하는 리소스입니다.
- Pod가 실패하면 자동으로 새로운 Pod를 생성합니다.
- **Docker Swarm의 Replica와 유사한 개념**이지만, Kubernetes에서는 독립적인 리소스입니다.

### Control Loop / Reconcile (컨트롤 루프 / 보정)
- 컨트롤러가 “원하는 상태(Desired)와 현재 상태(Current)의 차이”를 지속적으로 감시하고, 차이가 있으면 보정하는 동작 방식입니다.
- Kubernetes의 자동 복구(Self-Healing)와 상태 유지의 핵심 메커니즘입니다.

### Liveness Probe / Readiness Probe
- **Liveness Probe**: 컨테이너가 살아 있는지 확인하며, 실패 시 재시작 같은 조치가 일어납니다.
- **Readiness Probe**: 트래픽을 받을 준비가 되었는지 확인하며, 실패 시 Service 엔드포인트에서 제외됩니다.

### Desired State (원하는 상태) vs Current State (현재 상태)
- **Desired State**: 사용자가 정의한 원하는 상태입니다.
- **Current State**: 클러스터의 현재 실제 상태입니다.
- Kubernetes는 이 두 상태를 지속적으로 비교하여 차이를 자동으로 보정합니다.
- **Docker Swarm도 유사한 개념을 사용**하지만, Kubernetes가 더 세밀한 리소스 관리와 보장을 제공합니다.

## 비교표

| 개념 | Docker Swarm | Kubernetes | 비고 |
|------|-------------|------------|------|
| 배포 단위 | Service | Deployment/Pod | Docker Swarm의 Service는 배포 단위, Kubernetes의 Service는 네트워크 리소스 |
| 실행 단위 | Task (1개 컨테이너) | Pod (1개 이상 컨테이너) | Pod는 여러 컨테이너 포함 가능 |
| 관리 계층 | Manager Node | Control Plane | Docker Swarm은 Manager가 Worker 역할도 수행 가능 |
| 상태 저장소 | Raft (Manager 간) | etcd | 둘 다 Raft 알고리즘 사용 |
| 네트워크 | Overlay Network | CNI (다양한 플러그인) | Kubernetes는 더 유연한 네트워크 플러그인 시스템 |
| 서비스 디스커버리 | 내장 DNS | DNS + 라벨 셀렉터 | Kubernetes가 더 복잡한 메커니즘 제공 |