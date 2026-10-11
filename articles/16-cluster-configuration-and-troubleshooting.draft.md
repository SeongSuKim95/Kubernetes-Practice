# Chap16. 클러스터 구성과 장애 진단: 런타임과 Control Plane

> 16장 연재의 16번째 글입니다. Node의 컨테이너 실행 기반과 API Server의 상태 저장 경로를 실제 구성 및 장애 문제에 적용합니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

지금까지는 클러스터가 동작하는 상태에서 애플리케이션의 실행과 배포를 관리했습니다. 하지만 런타임 서비스가 시작되지 않거나 API Server가 저장소에 연결하지 못하면, 올바른 선언도 실제 실행으로 이어지기 어렵습니다.

2~3장에서 살펴본 실행 관계를 바탕으로 이번에는 클러스터의 기반을 확인합니다. Node의 런타임 구성과 Control Plane의 연결 장애를 서로 독립적인 문제로 살펴보겠습니다.

## 1. 실행 경로와 상태 저장 경로

Node에서는 Kubelet이 CRI로 실행을 요청하고 런타임이 컨테이너를 시작합니다. Docker Engine을 사용하는 구성에서는 cri-dockerd가 이 요청을 연결합니다. 실행 문제를 확인할 때는 서비스의 기동 상태와 Kubelet이 사용하는 런타임 접속 지점을 함께 확인해야 합니다. [[1]](#ref-1)

Control Plane에서는 API Server가 etcd에 클러스터 상태를 저장합니다. API Server의 접속 대상이나 인증 설정이 잘못되면 저장된 상태를 읽고 변경하는 경로가 막힙니다. 이때는 애플리케이션 로그보다 API Server와 etcd 사이의 연결부터 확인합니다. [[2]](#ref-2)

## 2. 문제와 해설: Docker Engine의 CRI 연결

[cri-dockerd 실습](../Practice/Kubernetes/16.Cri-Dockerd/Questions.bash)은 제공된 Debian 패키지를 설치하고 cri-docker 서비스를 시작하는 문제입니다. Docker Engine이 준비된 Node에서 진행하며, 실습이 요구하는 패킷 전달과 연결 추적 관련 시스템 설정도 적용합니다.

패키지 설치 뒤에는 서비스가 활성화되었는지와 생성된 소켓을 확인합니다. Kubelet의 런타임 접속 설정이 해당 소켓을 가리키는지 살펴보고, CRI 조회와 학습용 Pod 실행으로 연결 결과를 확인합니다. 서비스 기동부터 실제 컨테이너 실행까지 따라가야 어느 구간에서 실패했는지 구분할 수 있습니다.

## 3. 문제와 해설: API Server의 etcd 연결 복구

[etcd 장애 실습](../Practice/Kubernetes/17.Etcd-Fix/Questions.bash)에서는 클러스터 이전 후 API Server가 시작되지 않습니다. 이전 과정에서 API Server의 etcd 접속 설정이 멤버 간 통신 포트인 2380을 가리키게 된 상황입니다.

먼저 API Server 로그와 실행 설정의 `--etcd-servers`를 비교합니다. etcd의 일반적인 클라이언트 접속 포트는 2379이고, 멤버 간 통신 포트는 2380입니다. 실제 etcd의 클라이언트 주소와 TLS 설정을 확인해 API Server가 올바른 접속 지점을 사용하도록 수정합니다. [[3]](#ref-3)

API Server가 static Pod로 실행되는 환경에서는 해당 Node의 런타임 도구로 컨테이너 로그를 확인하고, 실제 사용 중인 static Pod 매니페스트를 수정합니다. API가 복구된 뒤에는 상태 조회가 가능한지와 Controller들이 변경을 다시 처리하는지 확인합니다. 주소 변경만으로 끝내지 않고 상태 저장과 조회가 회복되었는지 확인하는 과정입니다.

## 4. 장애 원인과 복구 결과의 연결

두 문제는 같은 선언이라도 기반 구성에 따라 실행 결과가 달라진다는 점을 보여 줍니다. Node 문제에서는 Kubelet과 런타임의 연결을, Control Plane 문제에서는 API Server와 etcd의 연결을 따라갑니다.

증상에서 시작해 관련 로그, 실제 적용 설정, 수정 후 동작을 순서대로 비교하면 불필요한 재설치 없이 원인을 좁힐 수 있습니다. 최종 확인은 서비스 프로세스가 떠 있는지뿐 아니라 원래 실패하던 작업이 성공하는지까지 포함합니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. 컨테이너 실행 기반과 클러스터 상태 저장 경로는 각각의 연결 설정과 로그를 통해 확인합니다. 복구 후에는 실제 실행과 API 요청이 정상적으로 이어지는지 검증합니다.

이번 글로 16장 연재를 마칩니다. 이후에는 지금까지 구성한 애플리케이션을 대상으로 장애와 변경 상황을 반복해 보며, 선언부터 실행 결과까지 스스로 추적하는 연습을 이어갈 수 있습니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: 컨테이너 런타임](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: etcd 운영](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- <a id="ref-3"></a>[3] [etcd 공식 문서: 구성 옵션](https://etcd.io/docs/v3.6/op-guide/configuration/)
