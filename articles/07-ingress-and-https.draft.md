# Chap07. Ingress와 HTTPS: 외부 요청을 Service로 연결하기

> 16장 연재의 일곱째 글입니다. 6장에서 비교한 Service 타입을 바탕으로, Ingress가 외부 HTTP와 HTTPS 요청을 Service에 연결하는 방법을 살펴봅니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

6장에서는 Pod가 교체되어도 같은 Service 주소로 요청을 보내고, 외부 사용자에게 접속할 진입점을 제공하는 방법을 살펴보았습니다. 이제 쇼핑몰의 웹 화면과 상품 API를 함께 공개한다고 가정해 보겠습니다. 사용자가 하나의 사이트에 접속하더라도 `/web` 요청은 웹 애플리케이션으로, `/api` 요청은 상품 API로 보내야 합니다.

이때 필요한 것은 요청한 이름과 경로를 보고 알맞은 Service를 선택하는 규칙입니다. 로그인이나 결제 정보를 주고받는다면, 사용자와 사이트 사이의 통신을 HTTPS로 보호할 방법도 필요합니다. Ingress는 이런 요청 전달 규칙과 HTTPS 설정을 선언해 여러 애플리케이션을 하나의 진입점으로 연결할 수 있게 합니다.

## 1. 외부 HTTP 요청을 나누는 Ingress

외부 요청이 클러스터에 도달한 뒤에는 어느 애플리케이션에 보낼지 결정해야 합니다. Service로 연결할 대상을 HTTP 요청의 내용에서 고르는 과정부터 살펴보겠습니다.

### 1.1 Service 다음에 필요한 HTTP 규칙

<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/ing.svg" alt="Kubernetes 공식 Ingress 리소스 마크" width="260">

</div>

Service는 변하는 Pod 집합에 안정적인 이름과 가상 IP를 제공합니다. 클러스터 안의 애플리케이션은 Service 이름으로 요청하고, Service의 네트워크 경로는 준비된 Pod로 연결합니다. 여기까지 해결한 문제는 **현재 Pod의 이름과 IP를 몰라도 같은 애플리케이션에 접근하는 것**입니다.

여러 웹 Service를 외부에 공개하면 한 단계 위의 문제가 생깁니다. 외부 클라이언트가 Service마다 다른 주소를 알아야 한다면 공개 주소가 애플리케이션 수만큼 늘어납니다. `/web` 요청은 웹 Service로, `/api` 요청은 API Service로 보내는 HTTP 규칙도 외부 장비나 클라이언트 설정에 흩어질 수 있습니다.

<div align="center">

<img src="../images/characters/character-ingress.png" alt="외부 HTTP 요청을 조건에 따라 Service로 연결하는 Ingress" width="70%" />

</div>

**Ingress**(인그레스)는 클러스터 외부에서 들어오는 HTTP와 HTTPS 요청을 호스트나 URL 경로에 따라 어떤 Service로 전달할지 선언하는 API 리소스입니다. 예를 들어 하나의 진입점에서 `example.com/web`은 `web` Service로, `example.com/api`는 `api` Service로 보낼 수 있습니다. Ingress가 요청 조건에 맞는 Service를 선택하면, 그 Service에 연결된 Pod 집합이 실제 요청 대상이 됩니다. [[1]](#ref-1)

위 그림에서 입구의 안내자가 요청을 서로 다른 Service의 문으로 안내하는 모습은, 호스트와 경로에 따라 요청 대상을 나누는 역할을 나타냅니다. 이 규칙이 실제 요청 경로로 이어지는 구조는 Fig 1과 같습니다.

<div align="center">

![Service와 Ingress의 API 리소스, Control Plane의 EndpointSlice Controller, Worker Node의 Ingress Controller와 kube-proxy](../images/articles/07/01-service-ingress-overview.svg)

</div>

Fig 1에서 Service와 Ingress는 Kubernetes API에 저장되는 선언형 리소스입니다. Service는 Pod 집합의 안정적인 접근점을 선언하고, Ingress는 호스트와 URL 경로에 따른 HTTP 요청 전달 규칙을 선언합니다. 실제 요청을 처리할 프록시나 로드 밸런서는 **Ingress Controller**가 이 선언을 읽어 구성합니다. 여기서 프록시는 클라이언트의 요청을 받아 다른 서버로 전달하는 프로그램입니다. 회색 화살표는 API 정보의 관찰과 설정 반영을, 주황색 화살표는 실제 애플리케이션 요청을 나타냅니다.

### 1.2 선언을 구현하는 Ingress Controller

이처럼 선언한 규칙을 실제 요청 경로로 구현하는 프로그램을 **Ingress Controller**(인그레스 컨트롤러)라고 합니다. Fig 2에서 API 정보를 읽어 설정을 바꾸는 과정과, 그 설정에 따라 요청을 전달하는 과정을 구분해 보겠습니다.

<div align="center">

![Ingress Controller가 Ingress 선언을 요청 경로로 구현하는 구조](../images/articles/07/02-ingress-controller-flow.svg)

</div>

Fig 2에서 Controller는 API Server를 통해 Ingress의 호스트, 경로와 백엔드 Service 정보를 확인하고, 자신이 관리하는 프록시나 로드 밸런서의 설정에 반영합니다. 외부 요청이 들어오면 이 프록시나 로드 밸런서가 규칙을 비교해 선택한 백엔드로 전달합니다.

Controller와 프록시를 함께 Pod로 배포하는 구현도 있고, Controller가 클라우드 로드 밸런서를 설정하는 구현도 있습니다. 사용할 구현을 설치하고 외부에서 접근할 진입점을 연결해야 Ingress 선언에 따라 요청을 처리할 수 있습니다. [[2]](#ref-2)

Ingress Controller의 Pod는 별도의 Namespace에서 실행하면서, 설정과 권한에 따라 여러 Namespace의 Ingress를 처리할 수 있습니다. 이때도 각 Ingress는 자신과 같은 Namespace에 있는 백엔드 Service를 참조합니다.

Controller가 백엔드에 연결할 때 Service의 가상 IP를 사용할 수도 있고, Service의 EndpointSlice를 조회해 Pod IP로 직접 연결할 수도 있습니다. Ingress에는 Service 이름으로 대상을 선언하되, 실제 전달 경로는 Controller 구현에 따라 정해집니다.

외부 클라이언트가 Controller에 도달할 진입점도 필요합니다. 환경에 따라 Controller의 Service를 `LoadBalancer` 또는 `NodePort`로 노출하거나 외부 로드 밸런서와 연결합니다. 사용자가 요청할 도메인의 DNS 주소도 이 진입점을 가리키도록 설정해야 합니다.

## 2. Ingress와 Service의 백엔드 참조

요청을 전달할 경로가 마련되었으므로, 이제 요청의 조건과 목적지 Service를 어떻게 짝지어 선언하는지 살펴보겠습니다.

<div align="center">

<img src="../images/characters/interaction-ingress-services-v2.png" alt="같은 색과 모양의 꼬리표를 가진 요청과 목적지 Service를 연결하는 Ingress" width="70%" />

</div>

위 그림에서 안내자는 파란 꼬리표의 요청을 같은 꼬리표가 달린 Service로, 주황 꼬리표의 요청을 다른 Service로 안내합니다. 같은 색과 모양은 요청 조건과 목적지의 대응을 표현합니다. 실제 Ingress에는 호스트나 경로를 조건으로 적고, 그 조건에 맞는 요청을 보낼 **백엔드**(Backend), 즉 목적지 Service의 이름과 포트를 지정합니다.

이 연결 중 하나를 매니페스트로 확인해 보겠습니다. 6장에 이어 `default` Namespace의 `app: web` Label을 가진 Pod에서 애플리케이션이 8080번 포트로 요청을 받는 상황을 가정합니다. Service는 이 Namespace의 Pod를 선택하고, Ingress도 같은 Namespace에 두어 Service를 참조합니다.

<div align="center">

![Ingress의 Service 이름과 포트 참조가 Service Selector와 Pod 포트로 이어지는 필드 관계](../images/articles/07/03-ingress-service-link.svg)

</div>

Fig 3은 Ingress의 `backend.service.name`과 `port`가 Service의 이름과 포트를 참조하고, Service의 Selector와 `targetPort`가 다시 Pod의 Label과 애플리케이션 포트로 이어지는 관계를 보여 줍니다. 이 관계를 매니페스트에 옮기면 다음과 같습니다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 8080
```

- `metadata.name: web`과 `spec.ports[].port: 80`: Ingress가 백엔드로 참조할 Service 이름과 포트입니다.
- `spec.selector.app: web`: 요청을 전달할 Pod의 Label 조건입니다.
- `spec.ports[].targetPort: 8080`: 선택된 Pod의 실제 애플리케이션 포트입니다.

이제 Ingress는 이 Service의 이름 `web`과 포트 `80`을 사용해 대상을 지정할 수 있습니다.

다음은 `example.com/web` 요청을 `web:80`으로 보내는 Ingress입니다. **IngressClass**는 Ingress를 처리할 Controller 구현을 구분하는 리소스이며, 여기서는 `example-ingress`라는 클래스가 구성되어 있다고 가정합니다. Ingress의 `backend.service.name`은 Ingress와 같은 Namespace의 Service를 가리킵니다. 따라서 여기서 `web`은 `default`의 Service이며, 다른 Namespace에 같은 이름의 Service가 있어도 참조 대상이 바뀌지 않습니다. [[1]](#ref-1)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: default
spec:
  ingressClassName: example-ingress
  rules:
  - host: example.com
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

- `spec.ingressClassName`: 이 Ingress를 처리할 IngressClass를 지정합니다.
- `rules[].host`와 `http.paths[].path`, `pathType: Prefix`: 요청의 호스트와 경로를 비교해 적용할 규칙을 고릅니다.
- `backend.service.name`과 `port.number`: 요청을 보낼 Service 이름과 Service 포트입니다.

Ingress의 `backend.service.name: web`은 Service의 `metadata.name: web`과 이어지고, `backend.service.port.number: 80`은 Service의 `port: 80`과 이어집니다. Service는 `targetPort: 8080`을 통해 해당 요청을 애플리케이션의 수신 포트로 연결합니다.

`pathType: Prefix`에서 `/web`과 `/web/item`은 일치하지만 `/website`는 일치하지 않습니다. 이 규칙은 `/web/item`을 그대로 백엔드에 전달하므로, 애플리케이션도 해당 경로를 처리해야 합니다. 전달 전에 `/item`으로 바꾸려면 Controller의 경로 재작성 기능을 설정합니다. [[1]](#ref-1)

## 3. TLS Secret과 HTTPS 종료

<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/secret.svg" alt="Kubernetes 공식 Secret 리소스 마크" width="260">

</div>

요청을 알맞은 애플리케이션으로 보낼 수 있게 되었다면, 사용자와 진입점 사이의 통신을 보호할 차례입니다. HTTPS는 TLS로 통신을 암호화하며, 진입점에서 이를 복호화해 HTTP 요청을 처리하는 것을 **TLS 종료**(TLS termination)라고 합니다.

<div align="center">

![Ingress가 TLS Secret의 인증서를 참조하는 과정](../images/articles/07/04-ingress-tls.svg)

</div>

Fig 4는 Ingress Controller가 Ingress의 TLS 설정과 Secret을 읽어 HTTPS 연결을 종료한 뒤, 선택된 Service 백엔드로 요청을 전달하는 흐름을 보여 줍니다. 이때 Secret에 저장한 인증서와 개인 키는 HTTPS 연결을 수립하는 데 사용됩니다.

HTTPS 진입점에는 도메인에 유효한 TLS 인증서와 그 인증서에 대응하는 개인 키가 필요합니다. 클라이언트는 인증서의 호스트 이름, 신뢰 관계, 유효기간을 확인합니다. 서버는 인증서를 제시하지만 개인 키를 외부로 전달하지 않습니다.

Kubernetes에서는 인증서와 개인 키를 `kubernetes.io/tls` 타입의 Secret에 저장할 수 있습니다. 다음은 인증서와 개인 키를 담는 Secret의 구조입니다.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example-com-tls
  namespace: default
type: kubernetes.io/tls
data:
  tls.crt: "<Base64로 인코딩한 example.com 인증서>"
  tls.key: "<Base64로 인코딩한 인증서의 개인 키>"
```

- `type: kubernetes.io/tls`: TLS 인증서용 Secret 유형입니다.
- `data.tls.crt`와 `data.tls.key`: 인증서와 개인 키를 Base64로 인코딩한 값입니다.

Base64는 원래 값으로 되돌릴 수 있는 표현 방식이므로, 개인 키를 보호하려면 Secret 조회 권한을 제한해야 합니다. 인증서 파일에서 이 Secret을 생성하는 명령은 선택 실습에 있습니다. [[3]](#ref-3)

Ingress는 `spec.tls[].secretName`으로 같은 Namespace의 TLS Secret을 참조합니다. 앞의 Ingress가 `default`에 있으므로 인증서 Secret도 `default`에 생성합니다. 다음은 2절의 Ingress에 `example-com-tls` 인증서 참조를 추가한 선언입니다.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: default
spec:
  ingressClassName: example-ingress
  tls:
  - hosts:
    - example.com
    secretName: example-com-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

- `spec.tls[].hosts`: HTTPS로 접속할 호스트 이름입니다.
- `spec.tls[].secretName`: 같은 Namespace에 있는 인증서 Secret을 참조합니다.

호스트와 경로로 `web:80`을 선택하는 규칙은 앞의 HTTP 예시와 같습니다. 달라진 부분은 외부에서 HTTPS로 접속할 때 제시할 인증서를 지정했다는 점입니다.

인증서의 SAN, `spec.tls[].hosts`, `spec.rules[].host`, 클라이언트가 요청하는 이름이 모두 `example.com`과 맞아야 합니다. **SAN**(Subject Alternative Name)은 인증서가 유효한 호스트 이름을 기록하는 확장 필드입니다.

Ingress Controller가 구성한 HTTPS 진입점은 인증서와 개인 키를 사용해 TLS 연결을 수립하고 요청을 복호화합니다. 그 뒤 이 예시에서는 백엔드에 평문 HTTP로 요청을 전달합니다. 진입점부터 백엔드까지도 암호화하려면 Controller가 제공하는 백엔드 TLS 기능을 별도로 구성해야 합니다. [[3]](#ref-3)

## 4. 요청 실패 구간의 구분

이렇게 요청 경로를 선언한 뒤에는 실제로 백엔드까지 도달하는지 확인해야 합니다.

외부 HTTPS 호출이 실패했을 때는 요청이 어디까지 도달했는지 나누어 생각합니다. Service 내부 호출이 성공하는지, Ingress 규칙이 요청과 일치하는지, HTTPS 연결이 정상인지 순서대로 확인하면 원인을 좁힐 수 있습니다.

| 실패 구간 | 확인할 관계 |
|---|---|
| Pod와 Service | 같은 Namespace의 Pod인지, Selector, Pod 준비 상태, EndpointSlice, 실제 수신 포트 |
| Ingress와 백엔드 | 같은 Namespace의 Service인지, Controller 동작, 요청 호스트와 경로, Service 이름과 포트 |
| HTTPS 연결 | Ingress와 TLS Secret의 Namespace, 요청한 이름과 인증서 이름의 일치, 인증서 신뢰와 유효기간 |
| 외부 진입점 | 클라이언트에서 진입점까지의 경로와 방화벽 허용 |

HTTP 404는 호스트나 경로 규칙이 맞지 않을 때, 503은 백엔드가 준비되지 않았을 때 나타날 수 있습니다. 다만 상태 코드 하나로 원인을 확정하지 말고 Controller의 상태와 이벤트를 함께 확인해야 합니다. 구체적인 확인 명령과 출력은 선택 실습에 모았습니다.

## 5. 선택 실습: 내부 호출과 외부 HTTPS 비교

[Ingress와 HTTPS 선택 실습](labs/07-ingress-and-https.lab.md)에서는 같은 echo 앱을 Service로 직접 호출한 뒤 Ingress를 거쳐 호출하여 요청 경로의 차이를 확인합니다. 학습용 인증서 생성, TLS Secret 적용, 내부와 외부 HTTPS 검증, 리소스 정리는 이 문서에서 순서대로 진행할 수 있습니다.

TLS 버전 제한은 선택 심화 실습으로 구분했습니다. TLS 버전 제한은 인증서 참조와는 별개로, HTTPS 연결을 처리하는 서버가 허용할 프로토콜 버전을 정하는 설정입니다. 기본 요청 흐름을 이해한 뒤 필요한 경우에만 실행하면 됩니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Ingress에 호스트와 경로별 Service를 선언하면 Controller가 이를 프록시나 로드 밸런서에 반영합니다. HTTPS 진입점은 TLS Secret의 인증서와 개인 키로 암호화된 연결을 처리하고, 선택한 백엔드로 요청을 전달합니다.

요청이 실패하면 내부 Service 호출, 호스트와 경로의 일치, 인증서와 외부 진입점을 나누어 확인합니다. 선언한 규칙과 실제 요청 경로를 연결해서 읽는 것이 문제를 좁히는 기준입니다.

외부 요청이 애플리케이션에 도달하면 그 결과로 데이터가 쌓입니다. Pod가 교체되어도 주문이나 사용자 정보가 유지되어야 서비스를 이어갈 수 있습니다. 다음 글에서는 Pod와 데이터의 수명을 구분하고, 새 Pod에 기존 저장소를 연결하는 방법을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)
- <a id="ref-3"></a>[3] [Kubernetes 공식 문서: TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
