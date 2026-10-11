# Chap15. 매니페스트 관리와 배포 자동화: Helm과 Argo CD

> 16장 연재의 15번째 글입니다. Helm으로 설정을 생성하고 Argo CD로 Git의 선언을 클러스터에 반영하는 흐름을 살펴봅니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

애플리케이션을 운영하면서 Deployment뿐 아니라 저장소, 통신 정책, 자동 확장 설정도 함께 관리하게 되었습니다. 환경마다 일부 값이 다르고 변경도 반복된다면, 파일을 직접 복사하고 적용하는 과정에서 차이가 생기기 쉽습니다.

반복되는 설정을 생성하는 방법과 변경 내용을 클러스터에 반영하는 방법을 나누어 보면, 배포 자동화의 역할을 이해하기 쉽습니다.

## 1. 설정 생성과 상태 동기화

**Helm**은 Kubernetes 리소스의 템플릿과 기본 설정을 **Chart**라는 패키지로 묶어 관리합니다. 값을 지정해 템플릿을 렌더링하면 환경에 맞는 매니페스트가 만들어집니다. `helm template`은 생성 결과를 파일로 확인하는 데 사용할 수 있습니다. [[1]](#ref-1)

**Argo CD**는 Git에 저장한 원하는 상태와 클러스터의 실제 상태를 비교하고 동기화하는 도구입니다. 관리할 저장소와 배포 위치를 `Application`이라는 Custom Resource로 선언하면, Argo CD의 Controller가 이를 바탕으로 변경을 반영합니다. [[2]](#ref-2)

Helm으로 파일을 생성하는 일과 Argo CD로 지속적으로 동기화하는 일을 구분하면, 배포 과정에서 어느 설정이 어디에 반영되는지 추적할 수 있습니다.

## 2. 문제: 기존 CRD를 유지하는 Argo CD 설치 구성

[Argo CD 실습](../Practice/Kubernetes/14.ArgoCD/Questions.bash)에서는 CRD가 이미 설치된 환경을 사용합니다. 공식 Helm 저장소의 Chart 버전 `7.7.3`으로 `argocd` Namespace에 사용할 매니페스트를 생성하되, CRD가 생성 결과에 포함되지 않도록 설정하는 것이 목표입니다.

생성 결과는 `/root/argo-helm.yaml`에 저장합니다. 이 문제의 버전과 옵션을 기준으로 결과를 확인한 뒤, 실제 설치와 애플리케이션 동기화로 범위를 넓힙니다.

## 3. 해설: 생성 결과와 동기화 상태 확인

먼저 대상 Chart의 설정에서 CRD 설치 옵션을 확인하고 끈 상태로 렌더링합니다. 파일 안에 `CustomResourceDefinition`이 없는지와 리소스가 의도한 Namespace에 배치되는지를 확인합니다. 기존 CRD와 설치할 Controller가 호환되어야 설치 후 리소스를 정상 처리할 수 있습니다.

Argo CD를 실행한 뒤에는 Git 저장소의 경로와 배포할 클러스터 및 Namespace를 Application에 연결합니다. Git에서 이미지나 설정을 바꾸고, 동기화 전후의 리소스 차이와 애플리케이션 상태를 비교합니다.

`Synced`는 선언의 동기화 상태를, `Healthy`는 리소스의 정상 동작 여부를 판단하는 상태입니다. 변경이 반영된 뒤에도 Pod 준비 상태와 실제 요청 결과를 확인해야 배포 결과를 평가할 수 있습니다. [[2]](#ref-2)

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Helm은 설정값으로 매니페스트를 생성하고, Argo CD는 Git의 선언과 클러스터 상태를 비교해 동기화합니다. CRD와 Controller의 설치 관계도 이 과정에서 함께 관리합니다.

배포 선언이 올바르더라도 실행 기반이나 상태 저장 경로가 끊기면 작업이 진행되지 않습니다. 다음 글에서는 Node와 Control Plane의 구성을 확인하고 장애 원인을 찾는 방법을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Helm 공식 문서: helm template](https://helm.sh/docs/helm/helm_template/)
- <a id="ref-2"></a>[2] [Argo CD 공식 문서: 핵심 개념](https://argo-cd.readthedocs.io/en/stable/core_concepts/)
