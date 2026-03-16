# Kubernetes 이해하기  
## 등장배경부터 설계 철학까지

## 1. 쿠버네티스는 왜 등장했는가?

### 1) 컨테이너 기술의 확산

컨테이너 기술은 Docker의 등장 이후 빠르게 보급되며 애플리케이션을 패키징하고 실행하는 표준 수단이 되었습니다. 하지만 단일 컨테이너를 실행하는 것은 가능했지만, 그 수많은 컨테이너를 자동으로 운영/관리해야 하는 문제는 남아 있었습니다.

### 컨테이너 오케스트레이션 개념

<p align="center">
  <img src="../images/Introduction/1.1_Container_Ochestration_1.png" alt="컨테이너 오케스트레이션 개요 1" width="48%" />
</p>

이 구조는 물리 인프라 위에서 여러 컨테이너가 동작하고, 상위 계층에서 이를 전체적으로 관리하는 형태를 보여줍니다.

이처럼 다수의 컨테이너를 자동으로 관리하기 위해 등장한 개념이 컨테이너 오케스트레이션이며, 이를 구현한 대표적인 플랫폼이 Kubernetes입니다.

---

### 2) 오케스트레이션의 필요성

컨테이너 오케스트레이션은 다음을 자동화합니다:

- 컨테이너 배포 및 스케줄링
- 자동 확장 및 축소
- 장애 감지 및 재시작
- 로드 밸런싱
- 서비스 디스커버리

---

### 3) 구글의 경험과 오픈소스화

쿠버네티스(Kubernetes, K8s)는 구글의 내부 시스템인 Borg에서 시작되었습니다. 2014년 오픈소스로 공개되면서 컨테이너 오케스트레이션의 표준 플랫폼으로 자리 잡게 되었습니다.

---

## 2. 쿠버네티스의 4가지 설계 원칙

**Kubernetes는 단순한 배포 도구가 아니라, 상태 기반 자동화 플랫폼입니다.**

### 1) 선언적 API (Declarative API)

쿠버네티스는 명령 중심(Imperative)이 아니라 상태 중심(Declarative) 접근 방식을 사용합니다.

사용자는 원하는 상태(Desired State)를 정의하고, Kubernetes는 현재 상태(Current State)를 지속적으로 비교하여 이를 일치시키는 작업을 자동으로 수행합니다.

### Control Loop 구조

![Kubernetes Control Loop 구조](../images/Introduction/2.1_ControlLoop.png)

이 그림은 Desired State와 Current State를 비교하고, 차이가 발생하면 자동으로 보정하는 Control Loop 구조를 보여줍니다.

---

### 2) 컨트롤 플레인의 투명성

쿠버네티스의 각 컴포넌트는 중앙 명령을 기다리는 것이 아니라, 공유된 API 상태를 감시(watch)하며 독립적으로 동작합니다.

### Kubernetes 아키텍처 개요

![Kubernetes Cluster 아키텍처](../images/Introduction/2.2_Kubernetes_Architecture.png)

이 구조는 Control Plane과 Worker Node의 역할이 분리되어 있음을 보여줍니다.

- Control Plane: API Server, Scheduler, Controller Manager, etcd
- Worker Node: kubelet, container runtime, kube-proxy

---

### 3) 사용자 친화성 (Meet the user where they are)

쿠버네티스는 다양한 애플리케이션 요구사항을 수용할 수 있도록 설계되었습니다.

- ConfigMap
- Secret
- 다양한 워크로드 타입

이를 통해 레거시 시스템과도 점진적으로 통합이 가능합니다.

---

### 4) 워크로드 이식성 (Workload Portability)

쿠버네티스 리소스는 추상화된 API 객체로 정의됩니다.

Deployment, Service, Config 등의 리소스 정의는 온프레미스와 클라우드 환경 모두에서 동일하게 작동합니다.

---

## 3. 쿠버네티스의 구성요소

쿠버네티스 클러스터는 **Control Plane**과 **Worker Node**로 구성되며, 각각이 맡는 역할이 다릅니다.

<p align="center">
  <img src="../images/Introduction/1.1_Container_Ochestration_2.png" alt="Kubernetes 구성요소 개요" width="80%" />
</p>

### 3.1 Control Plane 구성요소

Control Plane은 클러스터의 두뇌 역할을 하는 관리 계층입니다. 클러스터의 상태를 관리하고, 워크로드의 스케줄링과 배포를 결정하며, 모든 API 요청을 처리합니다.

#### API Server

**역할:**
- Kubernetes 클러스터의 **모든 요청의 입구(프론트 도어)** 역할을 하는 HTTP REST API 엔드포인트입니다
- `kubectl`이 보내는 명령과 Control Plane/Worker Node 컴포넌트의 요청을 수신합니다
- etcd와 연동하여 클러스터 상태를 저장하고 조회합니다

**주요 기능:**
- **인증 및 권한 관리**: 사용자와 컴포넌트의 인증을 확인하고, RBAC(Role-Based Access Control)을 통해 권한을 검증합니다
- **요청 검증**: 리소스 정의의 유효성을 검사합니다
- **상태 관리**: etcd에 상태를 저장하고, 다른 컴포넌트가 구독(Watch)할 수 있도록 제공합니다

**동작 원리:**
```
사용자/컴포넌트 요청
    ↓
API Server (인증/권한 확인)
    ↓
etcd (상태 저장/조회)
    ↓
다른 컴포넌트가 상태 변경 감지 (Watch)
```

#### Scheduler

**역할:**
- 새로 생성된 Pod가 어느 Worker Node에 배치될지 결정하는 컴포넌트입니다
- API Server의 상태를 구독(Watch)하여 Pending 상태의 Pod를 감지하고, 최적의 노드를 선택합니다

**스케줄링 고려 사항:**
- **리소스 사용량**: 노드의 CPU, Memory 사용률을 확인합니다
- **리소스 요청/제한**: Pod가 요청한 리소스와 노드의 가용 리소스를 비교합니다
- **어피니티/안티-어피니티**: 특정 Pod들이 같은 노드에 배치되거나 분리되어야 하는 규칙을 고려합니다
- **톨러레이션**: 노드의 테인트(Taint)와 Pod의 톨러레이션을 확인합니다

**동작 원리:**
```
1. API Server에서 Pending 상태의 Pod 감지
2. 모든 Worker Node의 리소스 상태 확인
3. 스케줄링 정책에 따라 최적의 노드 선택
4. API Server에 Pod의 노드 정보 업데이트
   (노드에 직접 명령하지 않음!)
```

**중요한 점:**
- Scheduler는 노드에 직접 명령하지 않습니다
- API Server의 상태를 구독하다가, Pending Pod를 발견하면 노드 정보만 업데이트합니다
- 실제 Pod 실행은 해당 노드의 Kubelet이 담당합니다

#### Controller Manager

**역할:**
- ReplicaSet, Deployment, Node 등 다양한 리소스의 실제 상태(Current State)가 원하는 상태(Desired State)와 일치하도록 반복적으로 조정하는 컨트롤러들의 집합입니다
- Control Loop를 통해 지속적으로 상태를 모니터링하고 자동으로 보정합니다

**주요 컨트롤러:**
- **Deployment Controller**: Deployment의 replicas 수를 유지하고, Pod 생성을 ReplicaSet에 위임합니다
- **ReplicaSet Controller**: 지정된 개수의 Pod가 실행되도록 관리합니다 (Pod가 죽으면 새로 생성)
- **Node Controller**: 노드의 상태를 모니터링하고, 장애 노드를 감지합니다
- **Service Controller**: Service와 LoadBalancer 리소스를 관리합니다

**동작 원리:**
```
무한 반복 (Control Loop):
1. Desired State 확인 (예: Pod 3개 필요)
2. Current State 확인 (예: Pod 2개 실행 중)
3. 차이 발견 (1개 부족)
4. API Server에 Pod 생성 요청
5. 잠시 대기
6. 다시 1번으로 돌아가기
```

**중요한 점:**
- Controller Manager는 Pod를 직접 생성하지 않습니다
- API Server에 "Pod를 생성해달라"는 요청만 보냅니다
- 실제 Pod 생성은 Scheduler가 배치하고, Kubelet이 실행합니다

#### etcd (분산 Key-Value 저장소)

**역할:**
- 클러스터의 모든 상태(리소스 정의, 메타데이터 등)를 저장하는 분산 Key-Value 저장소입니다
- Control Plane의 **"단일 진실 소스(Single Source of Truth)"** 역할을 합니다

**주요 특징:**
- **분산 저장**: 여러 etcd 인스턴스로 클러스터를 구성하여 고가용성을 보장합니다
- **Raft 합의 알고리즘**: 여러 etcd 인스턴스 간 일관된 상태를 유지하기 위해 Raft 알고리즘을 사용합니다
- **Watch 기능**: 다른 컴포넌트가 상태 변경을 실시간으로 감지할 수 있도록 Watch API를 제공합니다

**저장되는 정보:**
- 모든 리소스 정의 (Pod, Deployment, Service 등)
- 클러스터 설정 및 메타데이터
- 노드 상태 정보

**고가용성 구성:**
- 운영 환경에서는 보통 3개 이상의 etcd 인스턴스로 구성합니다
- 홀수 개로 구성하는 것이 권장됩니다 (3개, 5개, 7개)
- 절반 이상이 정상이면 클러스터가 동작합니다

#### Cloud Controller Manager (선택적)

**역할:**
- 클라우드 프로바이더(예: AWS, GCP, Azure)의 API와 연동하여 인프라 의존 기능을 처리합니다
- 온프레미스 환경에서는 필요하지 않을 수 있습니다

**주요 기능:**
- **Load Balancer 생성**: Service 타입이 LoadBalancer일 때 클라우드의 로드 밸런서를 자동으로 생성합니다
- **노드 관리**: 클라우드 환경에서 노드가 추가/삭제될 때 자동으로 처리합니다
- **스토리지 볼륨**: 클라우드의 스토리지 서비스를 Kubernetes 볼륨으로 제공합니다

---

### 3.2 Worker Node 구성요소

Worker Node는 실제 워크로드(Pod)가 실행되는 서버입니다. 각 Worker Node는 Control Plane의 지시를 받아 컨테이너를 실행하고, 상태를 보고합니다.

#### Kubelet

**역할:**
- 각 Worker Node에서 실행되는 에이전트입니다
- API Server와 통신하여 "이 노드에 어떤 Pod가 있어야 하는지"를 확인합니다
- 실제 컨테이너 런타임을 호출하여 컨테이너를 생성/삭제하고, 상태를 주기적으로 API Server에 보고합니다

**주요 기능:**
- **Pod 관리**: API Server에서 할당된 Pod의 스펙을 확인하고 실행합니다
- **상태 보고**: Pod와 노드의 상태를 주기적으로 API Server에 보고합니다
- **헬스체크**: Liveness Probe와 Readiness Probe를 실행하여 컨테이너의 건강 상태를 확인합니다
- **볼륨 마운트**: Pod에 필요한 볼륨을 마운트합니다

**동작 원리:**
```
1. API Server에서 Pod 할당 감지 (Watch)
2. Pod 스펙 확인
   - 어떤 이미지를 사용하는가?
   - 어떤 포트를 열어야 하는가?
   - 어떤 볼륨을 마운트해야 하는가?
3. Container Runtime 호출
   - containerd에게 컨테이너 생성 요청
4. 컨테이너 실행
5. 상태를 API Server에 보고
   - Pod 상태: Running
   - 컨테이너 상태: Healthy
```

**중요한 점:**
- Kubelet은 API Server의 상태를 구독(Watch)합니다
- API Server에 Pod 할당이 있으면 자동으로 실행합니다
- 실행 후 상태를 API Server에 보고합니다

#### Kube Proxy

**역할:**
- Kubernetes Service를 위해 네트워크 규칙을 설정하여, 클러스터 내부 트래픽이 올바른 Pod로 라우팅되도록 합니다
- 간단한 로드밸런싱 역할도 수행합니다

**주요 기능:**
- **Service 구현**: Service 리소스에 정의된 네트워크 규칙을 실제 네트워크 설정으로 변환합니다
- **로드 밸런싱**: 여러 Pod에 요청을 분산합니다
- **네트워크 규칙 관리**: iptables 또는 IPVS를 사용하여 네트워크 규칙을 설정합니다

**동작 원리:**
```
Service 정의: app: web 라벨을 가진 Pod들에 대한 접근 제공
    ↓
Kube Proxy가 감지
    ↓
iptables/IPVS 규칙 설정
    ↓
요청이 Service IP로 들어오면
    ↓
해당 라벨을 가진 Pod 중 하나로 라우팅
```

**모드:**
- **iptables 모드**: iptables 규칙을 사용하여 트래픽을 라우팅합니다 (기본값)
- **IPVS 모드**: IPVS를 사용하여 더 효율적인 로드 밸런싱을 제공합니다

#### Container Runtime

**역할:**
- 실제 컨테이너를 생성하고 실행하는 엔진입니다
- Kubelet의 요청을 받아 컨테이너를 시작/중지하고, 이미지를 풀(Pull)합니다

**주요 기능:**
- **이미지 관리**: 컨테이너 이미지를 레지스트리에서 가져오고 저장합니다
- **컨테이너 실행**: 컨테이너를 생성하고 실행합니다
- **리소스 격리**: Namespace와 Cgroups를 사용하여 컨테이너를 격리합니다

**지원되는 런타임:**
- **containerd**: Docker의 핵심 실행 엔진 (가장 널리 사용)
- **CRI-O**: Kubernetes 전용 경량 런타임
- **Podman**: rootless 컨테이너 실행 지원

**중요한 점:**
- Kubernetes v1.24부터는 Docker를 직접 지원하지 않습니다
- 대신 CRI(Container Runtime Interface)를 통해 containerd, CRI-O 등의 런타임을 사용합니다
- Docker로 만든 이미지는 OCI 표준이므로 containerd에서도 그대로 사용할 수 있습니다

#### Pod와 Container

**Pod:**
- Kubernetes에서 스케줄링되는 최소 단위입니다
- 하나 이상의 컨테이너와 공유 볼륨, 네트워크 네임스페이스를 포함합니다
- 같은 Pod 안의 컨테이너는 항상 같은 노드에서 함께 배치되고, localhost 네트워크를 공유합니다

**Container:**
- 실제 애플리케이션이 실행되는 단위입니다
- 동일한 Pod 안에서도 역할에 따라 여러 개의 컨테이너(예: 메인 앱 + 사이드카)를 포함할 수 있습니다

**Pod 내 컨테이너 관계:**
- **네트워크 공유**: 같은 Pod의 컨테이너들은 localhost로 통신할 수 있습니다
- **볼륨 공유**: 같은 Pod의 컨테이너들은 볼륨을 공유할 수 있습니다
- **생명주기 공유**: Pod가 시작되면 모든 컨테이너가 함께 시작되고, Pod가 종료되면 함께 종료됩니다

---

### 3.3 컴포넌트 간 통신 방식

Kubernetes의 각 컴포넌트는 서로 직접 통신하지 않습니다. 대신 **API Server를 중심으로 한 이벤트 기반 통신**을 사용합니다.

**핵심 원리:**
1. **직접 제어가 아님**: 컴포넌트들이 서로 직접 명령하지 않습니다
2. **API Server 중심**: 모든 통신은 API Server를 통해 이루어집니다
3. **상태 구독**: 각 컴포넌트는 API Server의 상태를 구독(Watch)합니다
4. **이벤트 기반**: 상태 변경이 발생하면 자동으로 동작합니다

**예시: Pod 생성 과정**

```
[사용자]
kubectl apply -f deployment.yaml
    ↓
[API Server]
Deployment 저장 (etcd)
    ↓
[Controller Manager] (구독 중)
Deployment 감지 → Pod 3개 생성 요청
    ↓
[API Server]
Pod 3개 저장 (Pending 상태)
    ↓
[Scheduler] (구독 중)
Pending Pod 감지 → 노드 선택 → Pod 업데이트
    ↓
[API Server]
Pod 상태: Assigned (worker-node-1)
    ↓
[Kubelet] (구독 중)
할당된 Pod 감지 → 컨테이너 실행
    ↓
[API Server]
Pod 상태: Running
    ↓
[Controller Manager] (구독 중)
상태 확인 → Desired State와 일치 ✓
```

이러한 구조를 통해 각 컴포넌트가 독립적으로 동작하면서도, API Server를 중심으로 일관된 상태를 유지할 수 있습니다.

### 3.4 외부와의 인터페이스

- **User / kubectl**
  - 사용자는 `kubectl` 또는 CI/CD 시스템을 통해 API Server에 요청을 보냅니다.
  - 이 요청은 YAML로 정의된 Desired State(원하는 상태)를 클러스터에 적용하는 과정입니다.
- **Cloud Provider**
  - 퍼블릭 클라우드(예: AWS, GCP, Azure)나 프라이빗 클라우드 인프라와 연동되어, 노드 프로비저닝, Load Balancer, 스토리지 볼륨 등 인프라 리소스를 제공합니다.


