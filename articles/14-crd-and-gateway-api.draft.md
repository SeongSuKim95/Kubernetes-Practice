# Chap14. Kubernetes API의 확장: CRD와 Gateway API

> 16장 연재의 14번째 글입니다. 새로운 리소스 종류를 추가하는 CRD를 소개하고, Gateway API를 통해 선언과 Controller의 관계를 살펴봅니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

앞에서는 필요한 통신 범위를 NetworkPolicy로 선언했습니다. Kubernetes에는 이렇게 목적에 맞는 리소스가 있지만, 새로운 기능을 표현하려면 기존 종류만으로는 충분하지 않을 수 있습니다.

사용자가 새로운 리소스 종류를 등록하고, 그 선언을 읽는 Controller를 연결하면 같은 API 관리 방식으로 기능을 확장할 수 있습니다. 7장의 Ingress 구성을 다른 방식으로 표현하는 Gateway API를 사례로 살펴보겠습니다.

## 1. 새로운 리소스 종류와 Controller

**CRD**(CustomResourceDefinition)는 Kubernetes API에 새로운 리소스 종류와 필드 구조를 등록하는 선언입니다. 등록된 종류로 만든 개별 리소스는 **Custom Resource**입니다. API Server가 이 선언을 저장하면, 해당 기능의 Controller가 변경을 확인하고 필요한 작업을 수행합니다. [[1]](#ref-1)

<div align="center">

<img src="../images/characters/character-crd-v3.png" alt="맞는 퍼즐 블록과 빈칸으로 새로운 리소스의 구조를 표현한 모습" width="65%" />

</div>

위 그림의 퍼즐 판은 사용할 수 있는 구조를 정하는 CRD를, 그 구조에 맞는 블록은 개별 리소스를 나타냅니다. 사용할 수 있는 선언의 모양을 정한 뒤, Controller가 그 선언을 동작으로 연결하는 관계입니다.

## 2. Gateway API의 진입점과 요청 경로

Gateway API는 CRD로 추가하는 리소스들을 통해 네트워크 요청 전달을 표현합니다. **GatewayClass**는 사용할 Controller 구현과 연결되고, **Gateway**는 접속 포트와 TLS 같은 진입점 설정을, **HTTPRoute**는 요청을 어느 Service로 보낼지 선언합니다. [[2]](#ref-2)

Controller가 이 리소스를 확인해 프록시나 외부 로드밸런서에 반영하면 실제 요청 경로가 준비됩니다. API Server에 선언을 저장하는 과정과, 클라이언트의 요청이 프록시를 거쳐 Service의 대상 Pod에 도달하는 과정은 각각 구분해 읽어야 합니다.

## 3. 문제: CRD 조회와 Ingress 구성 이전

[CRD 실습](../Practice/Kubernetes/15.CRDs/Questions.bash)에서는 설치된 cert-manager CRD 목록을 확인하고 `Certificate`의 `spec.subject` 필드 설명을 조회합니다. 새 리소스도 API를 통해 구조를 확인할 수 있다는 점을 먼저 익힙니다.

이어서 [Gateway API 실습](../Practice/Kubernetes/13.Gateway-API/Questions.bash)의 Ingress가 사용하는 호스트, 인증서, Service 경로를 Gateway와 HTTPRoute로 옮깁니다. 기존 HTTPS 접속을 유지하는 것이 목표이며, 호환되는 Gateway Controller와 GatewayClass가 준비되어 있어야 합니다.

## 4. 해설: 리소스의 참조와 실제 요청 확인

Gateway에는 HTTPS 리스너와 인증서 Secret을 연결하고, HTTPRoute에는 Gateway를 가리키는 `parentRefs`와 Service를 가리키는 `backendRefs`를 선언합니다. Controller는 이 참조와 조건을 확인한 뒤 실제 요청 전달 구성을 만듭니다.

적용 후에는 Controller가 선언을 수락했는지와 참조가 해결되었는지를 상태에서 확인하고, 기존 호스트로 HTTPS 요청을 보내 같은 애플리케이션에 도달하는지 비교합니다. 원본 Ingress에 경로 재작성 설정이 있다면 이전 후에도 같은 요청 경로를 전달하도록 검토해야 합니다.

기존 echo 앱으로 비교하는 코드는 [Gateway API 실습 문서](labs/14-crd-and-gateway-api.lab.md)에 연결합니다. 선언 확인과 실제 요청 검증을 함께 해야 API 확장이 동작까지 이어졌는지 알 수 있습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. CRD는 새로운 리소스 종류를 등록하고, Controller는 그 리소스의 선언을 실제 동작으로 연결합니다. Gateway API는 진입점과 HTTP 요청 경로를 나누어 이 관계를 보여 줍니다.

리소스가 늘어날수록 선언 파일을 일관되게 관리하는 일도 중요해집니다. 다음 글에서는 여러 설정을 생성하고 Git의 변경을 클러스터에 반영하는 배포 자동화를 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- <a id="ref-2"></a>[2] [Gateway API 공식 문서: API 개요](https://gateway-api.sigs.k8s.io/concepts/api-overview/)
