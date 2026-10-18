<!--
  Korean publication based on 07-ingress-and-https.draft.md.
  GitHub Flavored Markdown; figures use GitHub raw URLs.
-->

# Chap07. Ingress와 HTTPS: 외부 요청을 Service로 연결하기

> 16장 연재의 일곱째 글입니다. 6장에서 비교한 Service 타입을 바탕으로, Ingress가 외부 HTTP와 HTTPS 요청을 Service에 연결하는 방법을 살펴봅니다.

## 들어가며

![Kubernetes 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/01-k8s-logo.svg)

온라인 쇼핑몰에서 상품을 둘러보고 주문하는 동안, 사용자는 하나의 사이트를 이용한다고 느낍니다. 하지만 화면을 보여 주는 애플리케이션과 상품 정보를 조회하거나 주문을 처리하는 애플리케이션은 따로 실행될 수 있습니다. 기능이 나뉘어 있어도 사용자가 접속할 주소를 매번 바꿀 필요는 없어야 합니다.

앞 장에서는 애플리케이션에 안정적으로 접속할 통로를 마련했습니다. 이제 그 통로들을 하나의 사이트로 연결하려면, 사용자가 보낸 요청을 읽고 알맞은 애플리케이션으로 안내할 입구가 필요합니다. 상품 목록을 요청하면 상품 정보를 담당하는 곳으로, 주문을 요청하면 주문을 처리하는 곳으로 보내는 것입니다.

이 입구에서는 로그인 정보나 배송지처럼 중요한 내용도 오갑니다. 요청을 올바른 곳으로 보내는 일과 함께, 사용자와 사이트 사이의 통신을 보호하는 일도 필요합니다. Ingress와 HTTPS가 이러한 요구를 어떻게 충족하는지 살펴보겠습니다.

## 1. 외부 HTTP 요청과 Ingress의 역할

외부 요청이 클러스터에 도달한 뒤에는 어느 애플리케이션에 보낼지 결정해야 합니다. Service로 연결할 대상을 HTTP 요청의 내용에서 고르는 과정부터 살펴보겠습니다.

### 1.1 Service 다음에 필요한 HTTP 규칙

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/ing.svg" alt="Kubernetes 공식 Ingress 리소스 마크" width="260">

6장에서 Service에 요청을 보내면 준비된 Pod 중 하나가 요청을 처리했습니다. 웹 화면을 제공하는 Pod들과 상품 정보를 반환하는 Pod들이 따로 있다면, 각 집합을 `web`과 `api` Service로 묶을 수 있습니다. 이제 외부 사용자가 어느 쪽에 요청할지 구분할 기준이 필요합니다.

각 Service를 `LoadBalancer` 타입으로 공개할 수도 있지만, 사용자는 같은 사이트 안에서 화면을 열고 상품을 조회하기를 기대합니다. 이때는 하나의 공개 주소로 들어온 요청을 읽고, 요청한 이름과 경로에 맞춰 목적지를 나누는 편이 자연스럽습니다.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-ingress.png" alt="외부 HTTP 요청을 조건에 따라 Service로 연결하는 Ingress" width="70%" />

쇼핑몰에서 상품 목록을 보는 상황을 생각해 보겠습니다. 사용자는 하나의 사이트에 접속하지만, 브라우저에 화면을 보여 주는 애플리케이션과 상품의 이름과 가격을 조회하는 애플리케이션은 따로 실행될 수 있습니다. 화면을 여는 요청은 화면 제공용 Service로, 상품 정보를 조회하는 요청은 상품 조회용 Service로 전달해야 합니다.

**Ingress**(인그레스)는 이처럼 클러스터 외부에서 들어오는 HTTP와 HTTPS 요청을 어떤 Service로 보낼지 선언하는 API 리소스입니다. 요청한 사이트의 이름인 **호스트**와, 그 사이트 안에서 요청한 위치인 **URL 경로**를 기준으로 전달 대상을 구분합니다. 따라서 사용자는 하나의 쇼핑몰을 이용하면서도, 요청한 기능에 맞는 애플리케이션의 응답을 받을 수 있습니다. [[1]](#ref-1)

위 그림에서 입구의 안내자가 요청을 서로 다른 Service의 문으로 안내하는 모습은, 호스트와 경로에 따라 요청 대상을 나누는 역할을 나타냅니다. 이 규칙이 실제 요청 경로로 이어지는 구조는 Fig 1과 같습니다.

![쇼핑몰의 화면 요청과 상품 조회 요청이 Ingress 프록시에서 각 Service의 대상 Pod로 전달되는 구성](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/01-service-ingress-overview.png)

Fig 1에서 쇼핑몰을 이용하는 브라우저의 요청은 Worker Node A의 Ingress 프록시에 도착합니다. **프록시**는 클라이언트의 요청을 받아 목적지 서버로 전달하는 프로그램입니다. 화면을 여는 요청은 파란색 경로를 따라 화면 제공용 Service의 대상 Pod로, 상품의 이름과 가격을 조회하는 요청은 주황색 경로를 따라 상품 조회용 Service의 대상 Pod로 전달됩니다.

위쪽 Ingress 선언에는 요청 조건과 목적지 Service의 관계가 담깁니다. 각 Service 아래의 회색 점선은 그 Service가 가리키는 Pod를 나타내며, 실제 요청은 프록시가 선택한 Pod로 전달됩니다. 사용자는 하나의 쇼핑몰에 접속하지만, 뒤에서는 화면 제공과 상품 조회를 담당하는 애플리케이션이 나누어 응답하는 구성입니다.

이 관계를 선언한 뒤에는 실제 요청을 받는 프록시가 그 규칙에 따라 동작하도록 설정해야 합니다.

### 1.2 Ingress 매니페스트와 요청 규칙의 반영

앞의 쇼핑몰에서 화면을 여는 요청 하나를 설정으로 옮겨 보겠습니다. 사이트 이름을 `example.com`, 화면을 요청하는 경로를 `/web`, 화면 제공용 Service를 `web`이라고 정하면 다음과 같이 작성할 수 있습니다. 이 **Ingress 매니페스트**가 앞에서 말한 요청 규칙의 선언입니다.

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

- `rules[].host: example.com`: 요청한 쇼핑몰의 사이트 이름입니다.
- `path: /web`과 `pathType: Prefix`: `/web`과 그 아래 경로로 들어오는 화면 요청을 선택합니다.
- `backend.service`: 선택한 요청을 보낼 목적지인 **백엔드**를 지정합니다. 여기서는 `web` Service의 80번 포트를 가리킵니다.

`ingressClassName`은 이 규칙을 담당할 Controller를 선택하는 이름이며, 구체적인 연결은 2.1절에서 살펴봅니다. 위 예시는 `example-ingress` 클래스와 같은 Namespace의 `web` Service가 준비된 구성을 전제로 합니다.

3장에서 매니페스트를 API Server에 제출했던 것처럼, 이 파일을 제출하면 Ingress 리소스가 저장됩니다. **Ingress Controller**는 저장된 요청 규칙과 Service의 대상 정보를 읽어 프록시 설정에 반영합니다. 사용자가 적은 “이 사이트의 화면 요청을 이 Service로 연결한다”는 관계가 실제 요청 처리로 이어지는 것입니다.

![Ingress Controller가 Ingress 선언을 요청 경로로 구현하는 구조](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/02-ingress-controller-flow.png)

Fig 2의 위쪽에는 Control Plane의 API Server와 저장된 선언이 있습니다. 아래쪽 Worker Node A에서는 Ingress Controller Pod가 실행되며, 그 안의 Controller가 설정 변경을 담당하고 Ingress 프록시가 외부 요청을 받습니다. Worker Node B의 Pod는 전달된 요청을 처리하는 애플리케이션입니다.

사용자가 Ingress를 제출하면 선언이 API Server에 저장되고, Worker Node A의 Controller가 변경된 규칙과 Service의 대상 정보를 확인합니다. 이어 같은 Pod 안의 프록시에 `/web` 요청을 어느 Pod의 어느 포트로 전달할지 반영합니다. 그림의 회색 점선을 따라 선언이 실제 요청 처리 설정으로 이어지는 과정입니다.

이후 외부 요청이 주황색 경로를 따라 프록시에 도착하면, 프록시는 요청의 호스트와 경로를 준비된 규칙과 비교합니다. 이 예시에서는 Worker Node B의 Pod 주소인 `10.244.2.8:8080`으로 요청을 전달하고, Pod의 응답을 클라이언트에 돌려줍니다. Controller는 이러한 요청 처리와 별개로 API의 변경을 계속 관찰하며 설정을 갱신합니다.

Ingress Controller는 클러스터 환경에 맞게 별도로 준비합니다. 그림처럼 프록시를 Pod로 실행하는 구현도 있고, Controller가 클라우드 로드 밸런서를 설정해 그곳에서 요청을 처리하는 구현도 있습니다. 어느 구현이든 Ingress에 선언한 요청 조건과 목적지의 관계를 실제 요청 경로에 반영합니다. [[2]](#ref-2)

## 2. Ingress 선언과 Service 연결

앞의 Ingress 매니페스트는 담당 클래스와 목적지 Service를 이름으로 참조했습니다. 이제 이 이름들이 어떤 구성요소를 연결하는지 살펴보겠습니다. 클래스는 요청 규칙을 반영할 Controller로, Service 이름과 포트는 요청을 처리할 Pod로 이어집니다.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/interaction-ingress-services-v2.png" alt="같은 색과 모양의 꼬리표를 가진 요청과 목적지 Service를 연결하는 Ingress" width="70%" />

위 그림에서 안내자는 파란 꼬리표의 요청을 같은 꼬리표가 달린 Service로, 주황 꼬리표의 요청을 다른 Service로 안내합니다. 같은 색과 모양은 요청 조건과 목적지의 대응을 표현합니다. 앞의 매니페스트에서도 사이트 이름과 화면 경로를 조건으로 적고, 그 요청을 맡을 Service를 백엔드로 지정했습니다.

### 2.1 요청 규칙을 반영할 Ingress Controller의 선택

앞의 매니페스트에는 어떤 요청을 어느 Service로 보낼지가 담겨 있습니다. 이 규칙이 실제로 동작하려면, 클러스터에서 실행 중인 Ingress Controller가 읽어 자신이 관리하는 진입점에 반영해야 합니다. 따라서 요청의 목적지뿐 아니라 **이 규칙을 어느 Controller에 맡길지**도 연결해 주어야 합니다.

쇼핑몰의 고객용 사이트는 인터넷에서 접속하고, 직원용 관리 사이트는 사내에서만 접속하도록 운영한다고 생각해 보겠습니다. 두 사이트의 요청을 받는 진입점과 담당 Controller를 따로 마련했다면, 고객용 Ingress는 외부 진입점을 관리하는 쪽에, 관리 사이트의 Ingress는 사내 진입점을 관리하는 쪽에 맡겨야 합니다.

이 연결에 사용하는 리소스가 **IngressClass**입니다. 클러스터에 준비된 IngressClass에는 해당 클래스를 처리할 Controller의 식별 정보가 담깁니다. Ingress에서는 `spec.ingressClassName`에 그 클래스의 이름을 적어 담당 대상을 선택합니다. 즉, **Ingress → IngressClass → 담당 Controller**의 관계로 요청 규칙을 반영할 쪽을 정합니다. [[1]](#ref-1)

1.2절의 `ingressClassName: example-ingress`도 “이 요청 규칙을 `example-ingress` 클래스의 담당 Controller가 반영하도록 한다”는 의미입니다. 아래 그림은 이 선택을 고객용과 직원용으로 나누어 보여 줍니다.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/05-ingress-class.png" alt="Namespace 안의 Ingress가 IngressClass를 통해 외부 공개용 또는 사내 접속용 Controller와 연결되는 관계" width="100%" />

Fig 3에서 같은 Namespace의 `shop`과 `admin` Ingress는 서로 다른 클래스를 참조합니다. `public`은 외부 공개용 Controller에, `internal`은 사내 접속용 Controller에 연결됩니다. 각 Controller는 자신이 담당하는 Ingress의 규칙을 읽어 해당 진입점에 반영합니다. `public`과 `internal`이라는 이름은 이 역할을 구분하기 위해 정한 것이며, 외부 공개 여부는 실제 진입점의 네트워크 설정에 따라 결정됩니다.

클래스를 정한 뒤에는 해당 Controller가 연결할 애플리케이션을 지정합니다. IngressClass는 클러스터 범위에서 참조하지만, Ingress의 목적지 Service는 그 Ingress와 같은 Namespace에서 찾습니다.

### 2.2 Service 이름과 포트의 참조 관계

6장에서 Service는 Selector로 대상 Pod를 선택하고, Service의 포트를 Pod의 애플리케이션 포트에 연결한다는 것을 살펴보았습니다. 이 절에서는 그 연결 관계를 그대로 활용해, 1.2절의 Ingress가 `web` Service를 어떻게 참조하는지 확인합니다.

`default` Namespace의 `app: web` Label을 가진 Pod에서 웹 애플리케이션이 8080번 포트로 요청을 받는 상황을 가정합니다. Service는 이 Namespace의 Pod를 선택하고, Ingress도 같은 Namespace에 두어 Service의 이름과 포트를 참조합니다.

![Ingress의 Service 이름과 포트 참조가 Service Selector와 Pod 포트로 이어지는 필드 관계](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/03-ingress-service-link.png)

Fig 4는 Ingress의 `backend.service.name`과 `port`가 Service의 이름과 포트를 참조하고, Service의 Selector와 `targetPort`가 다시 Pod의 Label과 애플리케이션 포트로 이어지는 관계를 보여 줍니다. 앞에서 작성한 Ingress와 연결할 Service 매니페스트는 다음과 같습니다.

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

이 Service는 클러스터 내부의 접근점을 제공합니다. 외부 요청은 Ingress 진입점이 받아 전달하므로, 애플리케이션의 Service는 `ClusterIP`로 두고 Ingress에서 `web:80`을 참조합니다.

### 2.3 Service 선택 이후의 Pod 연결

Ingress 선언으로 목적지 Service를 정했다면, 이제 프록시에서 실제 Pod까지 요청이 전달되는 경로를 살펴보겠습니다. 이 경로는 Controller 구현에 따라 달라집니다. Ingress 프록시가 Service IP로 요청하면, 6장에서 본 `kube-proxy`가 구성한 Node의 전달 규칙을 통해 Pod에 도달합니다. 프록시가 EndpointSlice의 주소와 포트를 이용해 Pod로 직접 연결하는 구현도 있으며, Fig 1과 Fig 2는 이 경로를 보여 줍니다.

여기서 Ingress 프록시는 HTTP 요청의 호스트와 경로를 보고 백엔드를 선택하고, `kube-proxy`는 Service로 향하는 통신을 Pod에 연결할 Node의 규칙을 구성합니다. 실제 전달 경로가 달라도 Ingress 선언에서는 Service 이름과 포트로 백엔드를 지정합니다.

4장에서 본 준비 상태와 6장에서 본 대상 주소 갱신도 이 경로에 이어집니다. 웹 Pod가 교체되면 EndpointSlice Controller가 Service에 연결된 주소와 준비 상태를 갱신하고, 이를 사용하는 요청 경로에 변경 사항이 반영됩니다. Ingress의 호스트와 경로 규칙은 유지하면서 요청을 받을 Pod 집합을 바꿀 수 있습니다. [[3]](#ref-3)

## 3. 하나의 진입점과 여러 애플리케이션의 연결

Ingress 선언에는 웹 Service까지의 연결 관계가 담겼습니다. 이제 브라우저가 이 규칙을 사용하는 진입점에 도달하는 과정을 살펴보고, 같은 진입점에 상품 API를 연결하겠습니다.

### 3.1 외부 진입점과 도메인의 연결

브라우저가 Ingress의 규칙을 이용하려면 외부에서 접속할 수 있는 진입점 주소가 필요합니다. 앞의 그림처럼 프록시를 Pod로 실행한다면, 6장에서 본 `LoadBalancer` 또는 `NodePort` Service로 외부 요청이 프록시에 도달할 통로를 마련합니다.

여기에는 역할이 다른 두 Service가 등장할 수 있습니다. **Controller의 프록시를 공개하는 Service**는 외부 요청을 진입점까지 전달하고, **애플리케이션의 Service**는 진입점이 선택할 웹 Pod 집합을 가리킵니다. 이 구성에서 `web`과 `api` Service는 내부용 `ClusterIP`로 두고, 외부 공개를 진입점에 모을 수 있습니다.

도메인의 DNS에는 `example.com`이 이 외부 진입점으로 연결되도록 주소를 등록합니다. 6장의 CoreDNS 조회가 클러스터 안의 Service 이름을 찾았다면, 여기서는 사용자의 브라우저가 사이트 이름으로 공개 주소를 찾습니다. Ingress의 `host`에는 그 주소에 도착한 HTTP 요청을 구분할 이름을 적습니다. 도메인의 주소 등록과 Ingress의 요청 규칙을 함께 맞추면, 브라우저가 찾아온 진입점에서 알맞은 애플리케이션을 선택할 수 있습니다.

학습 환경에서 진입점이 `192.0.2.10:80`에 공개되어 있다면, DNS에 등록하는 대신 요청을 보내는 컴퓨터의 `/etc/hosts`에 다음 대응을 둘 수 있습니다.

```text
192.0.2.10 example.com
```

이 설정으로 `http://example.com/web`에 접속하면 해당 IP의 80번 포트로 요청합니다. Controller가 NodePort로 공개되어 있다면 URL에는 **Controller의 HTTP NodePort**를 적습니다. `/etc/hosts`는 이름과 IP를 연결하며 포트는 지정하지 않습니다.

### 3.2 NodePort 직접 요청과 Ingress 경유 요청

6장에서 사용한 NodePort 직접 접근과 비교하면 Ingress 진입점의 역할이 드러납니다. 앞에서는 Ingress가 내부용 Service의 Pod에 요청을 전달했습니다. 이번 비교에서는 애플리케이션의 Service를 NodePort 타입으로 두어, 같은 Pod 집합에 직접 접근하는 통로를 추가합니다. Fig 5는 Node A의 80번 포트에 Ingress 진입점이, 30080번 포트에 애플리케이션의 NodePort가 공개된 구성입니다.

이 비교 구성을 처음 만들 때는 앞의 ClusterIP 매니페스트 대신 다음 명령으로 `web` Deployment에 연결된 NodePort Service를 생성할 수 있습니다. [[4]](#ref-4)

```bash
kubectl expose deployment web -n default --name web --type NodePort --port 80 --target-port 8080
```

```text
service/web exposed
```

이 명령은 Deployment의 Pod 선택 조건을 이용해 Service를 만들며, NodePort는 자동 할당됩니다. Fig 5는 그 포트가 `30080`인 경우입니다. Ingress의 백엔드는 어느 타입에서도 Service 포트인 `80`을 참조합니다.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/06-service-ingress-traffic.gif" alt="설정 반영 이후 NodePort 직접 요청과 Ingress 프록시 경유 요청이 웹 Pod에 도달하고 응답하는 과정" width="100%" />

먼저 Controller가 Ingress 규칙을 프록시에 반영하고, kube-proxy는 Service와 EndpointSlice 정보를 이용해 Node의 전달 규칙을 설정합니다. 두 구성요소는 각자 변경 사항을 관찰하며 독립적으로 설정을 갱신합니다. 준비된 설정을 통해 실제 요청이 들어오는 두 경로를 비교해 보겠습니다.

Node IP가 `192.0.2.10`이라면 `http://192.0.2.10:30080/web` 요청은 Node의 Service 전달 규칙을 거쳐 웹 Pod로 갑니다. 이 경로에서는 Ingress의 호스트와 경로 규칙을 비교하지 않고, 웹 애플리케이션이 `/web` 요청을 처리합니다. Fig 5에서는 웹 Pod 1이 요청을 받고, 응답은 기존 요청에 대응하는 경로로 클라이언트에 돌아갑니다.

반면 `http://example.com/web` 요청은 3.1절에서 연결한 Ingress 진입점의 80번 포트에 도착합니다. 요청에는 `example.com`이라는 호스트와 `/web`이라는 경로가 담기고, 프록시는 이를 비교해 `web:80`에 연결된 Pod를 선택합니다. Fig 5에서는 EndpointSlice에서 확인한 웹 Pod 2의 주소로 직접 전달하며, 응답도 프록시를 거쳐 돌아옵니다. 두 경로 모두 같은 웹 Pod 집합에서 대상을 선택하며, 이 예시에서는 각 요청이 서로 다른 Pod에 도착합니다.

이 비교에서는 두 경로 모두 같은 애플리케이션에 도달합니다. 차이는 직접 접근에서는 접속한 NodePort가 대상을 정하고, Ingress 경유 접근에서는 프록시가 요청의 호스트와 경로를 읽어 목적지 Service를 선택한다는 점입니다.

### 3.3 같은 사이트 안의 경로별 Service

지금까지는 Ingress에서 화면 제공용 Service 하나를 선택했습니다. 이제 1절의 쇼핑몰 사례처럼 상품 조회용 Service를 추가해 보겠습니다. 같은 `example.com` 안에서 기존 화면 요청과 새 상품 조회 요청을 다음 경로로 구분합니다.

- **`/web` — 쇼핑몰 화면**: 브라우저에 보여 줄 화면을 요청하는 경로입니다. `web` Service에 연결된 웹 Pod가 처리합니다.
- **`/api/items` — 상품 목록 조회**: 화면에 표시할 상품 이름과 가격 등의 데이터를 요청하는 경로입니다. `/api`로 시작하는 요청을 받는 `api` Service에 연결된 API Pod가 처리합니다.

여기서는 두 Service를 내부용 ClusterIP로 두고, 외부 요청은 Ingress 진입점에서 받습니다.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/07-ingress-routing.png" alt="하나의 Ingress 프록시가 web과 api 경로를 비교해 각 Service가 선택하는 Pod로 전달하는 구성" width="100%" />

Fig 6에서는 각 Node 위에 Service와 Deployment를 별도의 리소스로 구분했습니다. Service는 Label 조건으로 요청을 받을 Pod를 선택하고, Deployment는 해당 애플리케이션의 Pod 복제본을 관리합니다. 두 리소스가 같은 Pod 집합을 대상으로 하더라도 맡은 역할은 다릅니다. 프록시에서 두 갈래로 나뉘는 화살표는 요청 경로에 따라 선택된 애플리케이션으로의 전달을 보여 줍니다. 프록시에서 각 Pod로 이어지는 화살표는 Service를 통해 확인한 대상 주소로 요청을 전달하는 경로입니다. 기존 `/web` 규칙에 `/api` 규칙을 더한 선언은 다음과 같습니다.

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
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
```

- `paths`: 같은 호스트 안에서 구분할 경로와 목적지의 목록입니다.
- 각 `backend.service`: `/web` 요청은 `web:80`으로, `/api` 요청은 `api:80`으로 연결합니다.

브라우저가 `/web`으로 화면을 열면 웹 Pod가 응답합니다. 그 화면에서 상품 목록을 얻기 위해 `/api/items`를 요청하면 이번에는 API Pod가 응답합니다. 사용자는 같은 사이트 주소를 사용하고, 내부에서는 서로 다른 Deployment가 관리하는 애플리케이션이 각 요청을 처리합니다.

### 3.4 경로의 일치 기준과 우선순위

위 선언에서 `/api/items`가 `/api` 규칙에 포함되는 이유는 `pathType`이 `Prefix`이기 때문입니다. 경로를 어느 범위까지 같은 요청으로 볼지에 따라 다음 기준을 사용합니다. [[1]](#ref-1)

- **`Prefix`**: `/`로 나눈 경로 구간을 기준으로 앞부분을 비교합니다. `/web`은 `/web`과 `/web/item`에 맞지만 `/website`에는 맞지 않습니다.
- **`Exact`**: 경로 전체가 같아야 합니다. `/web` 규칙은 `/web` 요청에만 맞고 `/web/`이나 `/web/item`과는 구분됩니다.
- **`ImplementationSpecific`**: 경로를 비교하는 방식이 Controller 구현에 따라 정해집니다. 해당 구현의 기능을 사용할 때 그 문서에 맞춰 설정합니다.

하나의 Ingress 안에서 여러 경로가 맞으면 더 긴 경로가 우선합니다. `/`와 `/api`가 모두 `Prefix`라면 `/api/items`에는 `/api` 규칙이 적용됩니다. 길이가 같은 경로끼리는 `Exact`가 `Prefix`보다 우선하며, 두 방식 모두 대소문자를 구분합니다.

경로를 선택하는 일과 전달할 경로를 바꾸는 일도 구분해야 합니다. 위 예시에서 `/api/items`는 그대로 API 애플리케이션에 전달되므로 애플리케이션도 이 경로를 처리해야 합니다. 애플리케이션이 `/items`만 처리한다면, 전달 전에 경로를 바꾸는 **경로 재작성** 기능을 Controller에 맞춰 설정합니다.

### 3.5 서로 다른 호스트와 일치하지 않는 요청

경로 대신 사이트 이름으로 목적지를 나눌 수도 있습니다. 웹 화면은 `shop.example.com`, 상품 API는 `api.example.com`으로 제공하고 싶다면, 각 이름에 대한 `rules[].host`와 백엔드를 따로 선언합니다. 두 도메인의 DNS가 같은 진입점을 가리키더라도 HTTP 요청에 담긴 호스트 이름으로 목적지를 구분할 수 있습니다.

이름과 경로를 함께 선언한 규칙에서는 둘 다 맞아야 합니다. `example.com/web` 규칙만 있는 상태에서 진입점의 IP 주소로 직접 접속하면, 요청에 담긴 호스트가 `example.com`과 달라 해당 규칙을 선택하지 못할 수 있습니다. DNS로 주소를 찾는 단계와 진입점이 요청의 호스트를 비교하는 단계가 이어져야 하는 이유입니다.

어느 규칙에도 맞지 않는 요청을 보낼 곳은 `spec.defaultBackend`로 지정할 수 있습니다. 별도로 지정하지 않았다면 Controller의 기본 처리 방식에 따라 응답하며, 흔히 404 응답을 돌려줍니다. 예를 들어 `/web`과 `/api`만 선언했을 때 `/help` 요청은 이 기본 처리로 넘어갑니다. [[1]](#ref-1)

이렇게 호스트와 경로에 맞는 목적지, 어느 규칙에도 맞지 않는 요청의 처리 방식을 정하면 여러 애플리케이션을 하나의 진입점에서 제공할 수 있습니다.

## 4. TLS Secret을 통한 HTTPS 연결

앞의 구성으로 웹 화면과 상품 API를 같은 사이트에 연결했습니다. 여기에 로그인이나 주문 기능을 제공한다면, 브라우저가 보내는 정보를 통신 중에 보호해야 합니다. 요청을 나누는 규칙은 유지하면서 외부 접속에 HTTPS를 적용하겠습니다.

### 4.1 HTTPS 진입점과 인증서

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/interaction-ingress-key-lock.png" alt="금색 열쇠를 든 Ingress와 그 옆의 잠긴 자물쇠" width="520" />

그림의 열쇠는 HTTPS 진입점이 보관하는 개인 키를, 잠긴 자물쇠는 암호화된 연결로 통신을 보호하는 역할을 떠올리게 합니다. 외부 요청을 안전하게 받으려면, 요청을 안내할 규칙과 함께 암호화된 연결을 위한 준비도 필요합니다.

**HTTPS**는 HTTP 요청과 응답을 **TLS**라는 보안 프로토콜로 보호하는 통신 방식입니다. 브라우저는 요청을 보내기 전에 접속한 사이트의 인증서를 확인하고 암호화된 연결을 맺습니다. 이를 위해 HTTPS 진입점에는 접속할 도메인에 유효한 인증서와 그 인증서에 대응하는 개인 키가 필요합니다.

인증서는 브라우저가 사이트의 신원을 확인하는 데 사용하고, 개인 키는 진입점이 안전하게 보관하면서 TLS 연결을 수립하는 데 사용합니다. `https://example.com/web`에 접속한다면 `example.com`에 유효한 인증서를 준비하고, Kubernetes에서는 이를 Secret에 담아 Controller가 읽을 수 있게 합니다.

### 4.2 인증서와 개인 키의 Secret 저장

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/secret.svg" alt="Kubernetes 공식 Secret 리소스 마크" width="260">

3장에서 애플리케이션의 민감한 설정을 Secret으로 분리했듯, 인증서와 개인 키도 별도의 리소스로 보관합니다. **TLS Secret**은 두 값을 정해진 키에 저장하는 `kubernetes.io/tls` 타입의 Secret입니다. 앞의 Ingress와 같은 `default` Namespace에 `example-com-tls`라는 이름으로 저장하는 구조는 다음과 같습니다. [[5]](#ref-5)

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

- `type: kubernetes.io/tls`: 인증서와 개인 키를 담는 Secret 유형입니다.
- `data.tls.crt`: 사이트의 인증서입니다.
- `data.tls.key`: 인증서에 대응하는 개인 키입니다.

`data`에는 각 파일의 내용을 Base64로 인코딩해 넣습니다. 준비한 인증서와 개인 키가 이 Secret에 저장되면, Ingress에서는 파일 내용을 반복해서 적는 대신 Secret의 이름을 참조할 수 있습니다.

### 4.3 Ingress의 인증서 참조와 요청 전달

3절에서 선언한 `/web`과 `/api` 규칙에 `tls` 설정을 더하면, 같은 사이트를 HTTPS로 제공할 수 있습니다. 다음 선언은 `example.com`의 인증서를 같은 Namespace에 있는 `example-com-tls`에서 읽도록 지정합니다.

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
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
```

- `spec.tls[].hosts`: 인증서를 적용할 호스트 이름입니다.
- `spec.tls[].secretName`: 인증서와 개인 키가 저장된 Secret의 이름입니다.

브라우저가 요청하는 `example.com`이 인증서의 유효한 도메인에 포함되고, Ingress의 `tls.hosts`와 `rules.host`에도 같은 이름이 연결되어야 합니다. 이 설정이 실제 HTTPS 요청 처리로 이어지는 과정은 Fig 7과 같습니다.

![TLS Secret 설정 이후 인증서 확인과 암호화된 연결 수립을 거쳐 웹 Pod에 요청과 응답을 전달하는 과정](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/04-ingress-tls.gif)

Fig 7의 위쪽에서 Controller는 Ingress의 TLS 설정을 확인하고, 참조된 Secret에서 인증서와 개인 키를 읽어 HTTPS 진입점에 반영합니다. 호스트와 경로별 백엔드 설정도 함께 준비되어 외부 요청을 받을 수 있게 됩니다. 이는 요청을 받기 위한 사전 준비이며, 이후에도 Controller는 선언이나 Secret이 변경되면 설정을 갱신합니다.

아래쪽에서 브라우저는 진입점의 443번 포트에 연결하며 접속하려는 사이트 이름을 알립니다. 진입점이 그 이름에 맞는 인증서를 제시하면 브라우저는 도메인, 발급자에 대한 신뢰, 유효기간을 확인하고 암호화된 연결을 맺습니다.

암호화된 연결이 준비되면 브라우저는 파란색 경로를 따라 `/web` 요청을 보냅니다. 진입점에서 암호화를 풀어 HTTP 요청을 처리하는 방식을 **TLS 종료**(TLS termination)라고 합니다. 진입점은 복호화한 요청의 호스트와 경로를 확인해 `web:80` 백엔드를 선택하고, 주황색 경로를 따라 준비된 웹 Pod의 8080번 포트로 HTTP 요청을 전달합니다. Pod의 응답도 HTTP로 진입점에 돌아오며, 진입점은 이를 암호화해 브라우저와 맺은 TLS 연결로 돌려줍니다. [[1]](#ref-1)

Fig 7에서 자물쇠가 표시된 브라우저와 진입점 사이는 HTTPS로 보호되고, 진입점과 Pod 사이는 HTTP로 통신합니다. 이 구성에서는 외부 연결의 암호화를 진입점에서 처리하면서, 그 뒤의 애플리케이션에는 기존 HTTP 요청 처리 방식을 유지할 수 있습니다.

## 5. kubectl을 활용한 사이트 접속 문제 확인

사이트에 접속되지 않을 때는 요청이 멈춘 구간부터 살펴보면 확인할 설정을 좁힐 수 있습니다. 5장에서 Pod의 상태를 따라 원인을 찾았다면, 여기서는 외부 진입점부터 애플리케이션까지의 연결 관계를 따라갑니다. `kubectl`로 Ingress와 관련 리소스의 설정 및 상태를 조회하고, 그 결과를 실제 접속 주소나 오류 증상과 비교하는 방법을 살펴보겠습니다. 마지막에는 `curl`로 HTTP 응답 코드를 확인해 요청이 정상적으로 처리되는지도 판단합니다.

![진입점 연결과 인증서 확인 및 애플리케이션 응답의 실패 지점에 따라 확인 대상을 나누는 흐름도](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/08-ingress-diagnosis.png)

Fig 8은 연결부터 응답까지 요청이 어디에서 멈췄는지를 기준으로 확인 대상을 나눕니다. 진입점에 연결하지 못했다면 주소와 공개 포트를, 인증서 확인에서 멈췄다면 사이트 이름과 인증서 설정을 살펴봅니다. 그 과정을 통과한 뒤 오류 응답을 받거나 응답이 늦어진다면 요청 규칙과 Service, Pod의 상태를 확인합니다.

### 5.1 연결 실패 시 접속 주소와 Ingress Controller 확인

브라우저가 사이트에 연결하지 못한다면 도메인이 가리키는 주소와 Ingress의 공개 주소부터 비교합니다. 다음은 앞의 HTTPS 설정을 적용한 Ingress의 조회 결과 예시입니다.

```bash
kubectl get ingress web -n default
```

```text
NAME   CLASS             HOSTS         ADDRESS         PORTS     AGE
web    example-ingress   example.com   203.0.113.20    80, 443   5m
```

- `CLASS`: 선언을 처리할 IngressClass입니다. 설치된 Controller가 담당하는 클래스인지 확인합니다.
- `HOSTS`: 요청을 구분하는 사이트 이름입니다. 브라우저가 `example.com`으로 요청하는지 확인합니다.
- `ADDRESS`: Controller가 보고한 외부 진입점의 IP 또는 호스트 이름입니다. 도메인의 DNS가 이 진입점으로 연결되어야 합니다.

주소가 비어 있거나 선언한 설정이 반영되지 않았다면 Controller의 실행 상태와 Ingress 이벤트를 확인합니다. 주소가 준비된 뒤에도 접속이 오래 기다리다 끝난다면, 브라우저에서 해당 진입점의 443번 포트까지 통신할 수 있는지 살펴봅니다. 진입점까지 연결된 뒤 인증서 오류가 나타난다면 확인할 대상은 TLS 설정으로 좁혀집니다.

### 5.2 인증서 오류 시 사이트 이름과 TLS Secret 확인

브라우저가 인증서 오류를 표시하면 진입점에서 제시한 인증서가 요청한 사이트에 유효한지 확인합니다. `example.com`이 인증서에 포함되어 있는지, 유효기간이 남아 있는지, 브라우저가 발급자를 신뢰하는지가 판단 기준입니다.

이어 Ingress의 `secretName`이 같은 Namespace의 `example-com-tls`를 참조하는지 확인합니다. 다른 인증서가 저장되어 있다면 올바른 인증서와 대응하는 개인 키로 Secret을 갱신하고, Controller가 변경을 반영했는지 살펴봅니다. 인증서 확인을 통과해 HTTP 응답을 받았다면 호스트와 경로 규칙과 백엔드 연결을 확인할 차례입니다.

### 5.3 오류 응답 시 Ingress 규칙과 대상 Pod 확인

요청이 진입점에 도달해도 호스트나 경로가 규칙과 다르면 원하는 Service를 선택하지 못합니다. `https://example.com/web` 요청이라면 Ingress의 `host`가 `example.com`인지, `/web`을 선택하는 경로 규칙이 있는지부터 확인합니다.

규칙이 맞다면 그 규칙이 참조하는 `web` Service가 같은 Namespace에 있고 포트 `80`을 제공하는지 확인합니다. 이어 Service의 Selector가 웹 Pod의 Label과 맞는지, EndpointSlice에 준비된 Pod의 주소와 애플리케이션 포트 `8080`이 반영되어 있는지 살펴봅니다. [[6]](#ref-6)

예를 들어 웹 Pod가 실행 중이어도 4장에서 본 준비 프로브가 실패하면 일반적인 요청 대상에서 빠집니다. 모든 웹 Pod가 준비되지 않았다면 Ingress 규칙이 맞아도 요청을 처리할 대상을 찾기 어렵습니다. 이때는 5장에서 사용한 Pod 상태와 로그 확인으로 이어가 애플리케이션이 준비되지 못한 원인을 찾습니다.

응답을 받는 경우에는 HTTP 상태 코드로 확인 범위를 좁힐 수 있습니다. 다음 명령은 응답 본문 대신 상태 코드만 표시합니다. [[7]](#ref-7)

```bash
curl -o /dev/null -s -w "%{http_code}\n" https://example.com/web
```

- `200`: 요청이 정상 처리되었음을 나타내는 응답 코드입니다.
- `404`: Ingress 규칙과 맞지 않거나, 애플리케이션에 요청한 경로가 없을 때 나타날 수 있습니다.
- `503`: 요청을 전달할 준비된 백엔드가 없을 때 나타날 수 있습니다.

오류 응답은 Controller와 애플리케이션의 로그를 함께 확인해 어느 쪽에서 반환했는지 구분합니다. 클러스터 안에서 `web` Service를 호출하면 정상 응답하지만 외부 요청만 실패한다면 진입점의 요청 규칙과 전달 설정을 집중해서 살펴볼 수 있습니다.

애플리케이션이 실제로 받은 호스트와 경로를 확인하려면 요청 정보를 응답으로 돌려주는 echo 서버가 도움이 됩니다. [Ingress 예제 자료](../Practice/Kubernetes/6.Ingress/)에서도 이 방법을 사용합니다. 응답 코드와 전달된 요청 내용을 함께 보면, 요청이 올바른 애플리케이션에 도착했는지까지 확인할 수 있습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. 여러 애플리케이션이 따로 실행되더라도, 사용자는 하나의 사이트에서 필요한 기능을 이용할 수 있습니다. 공통 진입점이 요청한 이름과 경로를 보고 알맞은 애플리케이션으로 안내하기 때문입니다. Ingress에 이 관계를 선언하면 Controller가 실제 요청 처리 설정에 반영하므로, 각 애플리케이션의 실행과 외부 요청의 전달 방식을 나누어 관리할 수 있습니다.

같은 진입점에서 HTTPS 연결을 처리하면 사용자와 사이트 사이의 통신도 보호할 수 있습니다. 요청을 어디로 보낼지 정하는 일과 통신을 보호하는 일이 어떻게 이어지는지 이해하면, 접속 문제가 생겼을 때도 연결, 인증서 확인, 애플리케이션 응답 중 어느 구간을 살펴봐야 할지 판단할 수 있습니다.

여기까지 쿠버네티스의 기본적인 리소스와 동작 방식을 살펴보았습니다. 애플리케이션의 실행 상태를 선언하면 클러스터가 그 상태를 유지하고, 문제가 생기면 복구하며, 준비된 애플리케이션으로 요청을 전달하는 흐름을 이해했습니다. 이제는 주어진 상황에서 어떤 리소스를 선택하고 어떻게 설정해야 하는지 직접 판단해 볼 차례입니다.

<a href="https://www.cncf.io/training/certification/cka/">
<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/cka-official.svg" alt="CNCF 공식 Certified Kubernetes Administrator 인증 마크" width="220">
</a>

**CKA**(Certified Kubernetes Administrator)는 CNCF와 Linux Foundation이 제공하는 쿠버네티스 관리자 인증 시험입니다. 명령줄 환경에서 클러스터를 직접 다루며 주어진 작업을 해결하는 실기형 시험으로, 애플리케이션의 배치와 네트워크와 저장소 구성, 문제 해결 등 운영에 필요한 능력을 평가합니다. 개념을 이해하는 데서 나아가 요구사항에 맞는 설정을 적용하고 결과를 확인하는 능력이 중요합니다. [[8]](#ref-8)

8장부터 16장까지는 CKA에서 다루는 작업 유형에 맞춘 연습 문제를 통해 지금까지 배운 개념을 실제 상황에 적용하겠습니다. 각 장에서는 문제를 해결하는 데 필요한 개념을 더 구체적으로 살펴본 뒤, 요구사항을 읽고 리소스와 설정을 선택하는 이유를 해설합니다. 명령과 매니페스트를 적용한 결과까지 확인하며, 조건이 달라져도 스스로 해결 방법을 찾을 수 있도록 연결하겠습니다.

다음 글에서는 앞서 살펴본 Pod의 생명주기로 돌아가, 컨테이너가 재시작되거나 Pod가 교체되는 상황을 CKA 유형의 연습 문제와 연결해 보겠습니다. 애플리케이션을 다시 실행한 뒤에도 이전에 저장한 데이터를 사용해야 한다면 무엇을 준비해야 할까요? 이 상황을 바탕으로 실행 과정에서 어떤 데이터가 사라지고 어떤 데이터가 남는지 살펴보고, 저장소를 연결하는 설정과 복구 결과를 확인하며 개념을 구체화하겠습니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)
- <a id="ref-3"></a>[3] [Kubernetes 공식 문서: EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
- <a id="ref-4"></a>[4] [Kubernetes 공식 문서: kubectl expose](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_expose/)
- <a id="ref-5"></a>[5] [Kubernetes 공식 문서: TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
- <a id="ref-6"></a>[6] [Kubernetes 공식 문서: Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- <a id="ref-7"></a>[7] [curl 공식 문서: 명령 옵션](https://curl.se/docs/manpage.html)
- <a id="ref-8"></a>[8] [CNCF 공식 안내: Certified Kubernetes Administrator (CKA)](https://www.cncf.io/training/certification/cka/)
