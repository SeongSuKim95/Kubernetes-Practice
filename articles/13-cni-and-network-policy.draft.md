# Chap13. Pod 통신의 연결과 제한: CNI와 NetworkPolicy

> 16장 연재의 13번째 글입니다. Pod 통신을 구성하는 네트워크 플러그인과 수신·송신 정책을 연결합니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

여러 애플리케이션의 Pod를 배치하고 실행 우선순위까지 정했습니다. 하지만 실행 중인 모든 Pod가 다른 모든 애플리케이션에 접근할 필요는 없습니다. 상품 화면을 만드는 frontend는 backend를 호출해야 하지만, 관계없는 테스트 Pod의 접근은 제한하고 싶을 수 있습니다.

6장에서 배운 통신 경로를 바탕으로, 연결을 구성하는 주체와 통신을 허용하거나 차단하는 정책을 살펴보겠습니다.

## 1. Pod의 연결과 정책 적용

Pod가 네트워크에 참여하려면 인터페이스와 IP 등 실행 환경의 네트워크 설정이 필요합니다. Kubernetes의 Pod 네트워크 구성에는 **CNI**(Container Network Interface) 규약을 따르는 플러그인이 사용됩니다. 사용하는 네트워크 구현에 따라 NetworkPolicy 지원 여부와 활성화 조건도 확인해야 합니다. [[1]](#ref-1)

**NetworkPolicy**는 선택한 Pod의 통신 상대와 포트를 정하는 리소스입니다. 선언은 API Server에 저장되고, 이를 지원하는 네트워크 구성요소가 실제 통신 제한을 반영합니다. 정책을 적용하기 전에는 앱과 Service의 통신이 정상인지 확인해야 제한에 따른 결과를 구분할 수 있습니다. [[2]](#ref-2)

## 2. 수신과 송신의 허용 조건

backend를 기준으로 들어오는 요청은 **Ingress**, frontend를 기준으로 밖으로 보내는 요청은 **Egress**입니다. 한 요청이 양쪽에서 제한된다면 송신과 수신 규칙을 모두 만족해야 합니다. 여러 정책이 같은 방향을 선택하면 허용한 범위는 합쳐집니다.

Namespace와 Pod 조건을 같은 출처 항목에 넣으면 두 조건을 함께 만족하는 Pod만 선택합니다. 송신을 제한할 때는 backend의 포트뿐 아니라 Service 주소를 알아내는 DNS 조회도 허용해야 이름으로 요청할 수 있습니다.

## 3. 문제: Frontend만 허용하는 Backend

[NetworkPolicy 실습](../Practice/Kubernetes/11.Network-Policy/Questions.bash)의 후보 정책을 비교해 `frontend` Namespace의 `app=frontend` Pod만 backend의 TCP 80번 포트에 접근하도록 수정합니다. 원본의 세 번째 후보는 Namespace와 Pod 조건이 서로 다른 항목이고, 설치 스크립트에는 `name=frontend` Namespace Label도 없으므로 그대로 적용하기 전에 두 조건을 고쳐야 합니다.

[CNI 실습](../Practice/Kubernetes/12.CNI&NetworkPolicy/Questions.bash)은 Pod 통신과 NetworkPolicy 적용을 모두 지원하는 구성을 선택하는 문제로 연결합니다. 정책 리소스가 생성되는지뿐 아니라 실제 허용·차단 결과까지 확인하는 것이 목표입니다.

## 4. 해설: 출처 조건과 요청 결과

다음 정책은 두 출처 조건을 한 항목으로 묶습니다.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend
      podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
```

- `spec.podSelector`: 정책을 적용할 backend Pod를 선택합니다.
- `from`: frontend Namespace이면서 `app=frontend`인 출처를 허용합니다.
- `ports`: 허용한 출처의 TCP 80번 요청만 받습니다.

다른 수신 허용 정책이 없는 학습 환경에서 정상 frontend와 다른 Label 또는 Namespace의 Pod가 보내는 요청을 비교합니다. 이후 frontend에 Egress 정책을 추가해 backend와 DNS만 허용하고, 다른 목적지의 요청이 차단되는지 확인합니다. DNS 허용 대상은 클러스터가 사용하는 실제 DNS 경로에 맞춰야 합니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. CNI 기반의 네트워크 구성 위에서 NetworkPolicy를 지원하는 구현이 통신 제한을 적용합니다. 송신과 수신을 나누고 필요한 출처, 목적지와 포트를 함께 확인해야 합니다.

지금까지는 Kubernetes에 준비된 리소스를 사용했습니다. 다음 글에서는 새로운 종류의 리소스를 추가하고 그 선언을 실제 동작으로 연결하는 방법을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: 네트워크 플러그인](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
