# Chap03. 서비스 운영에 필요한 핵심 리소스

> 15주 연재의 셋째 글입니다. Kubernetes에서 애플리케이션을 실행하고, Pod 복제본을 유지하고, 요청을 전달하고, 리소스를 구분할 때 사용하는 Pod, Deployment, Service, Ingress, Namespace를 정리합니다.

## 들어가며

이전 글에서는 Kubernetes가 원하는 상태를 API에 저장하고, 여러 제어 프로세스가 그 상태를 실제 실행으로 옮기는 흐름을 살펴보았습니다. 이번 글에서는 개발자가 Kubernetes API에 제출하는 리소스를 구체적으로 살펴봅니다.

애플리케이션 하나를 운영하려면 컨테이너를 실행하는 단위만으로는 부족합니다. 같은 애플리케이션을 몇 개 유지할지 정해야 하고, 교체되는 실행 단위에 요청을 계속 전달해야 합니다. 외부 요청을 도메인과 경로에 따라 나누고, 여러 팀이나 환경의 리소스도 구분해야 합니다. Kubernetes는 각 문제를 하나의 거대한 설정에 모으지 않고, 서로 다른 리소스에 나누어 맡깁니다.

## 1. 리소스와 매니페스트

<div align="center">

![Kubernetes 리소스와 매니페스트의 관계](../images/articles/03/01-resource-manifest.svg)

</div>

**리소스**(resource)는 Kubernetes API가 저장하고 관리하는 객체입니다. Pod와 Deployment, Service처럼 각 리소스는 맡은 책임이 다릅니다. 사용자는 필요한 리소스를 조합해서 애플리케이션의 실행 방식과 운영 정책을 표현합니다.

**매니페스트**(manifest)는 어떤 리소스를 어떤 상태로 두고 싶은지를 적은 선언입니다. 실무에서는 매니페스트를 YAML 형식으로 작성하는 경우가 많습니다. YAML은 내용을 표현하는 문법이고, 매니페스트는 Kubernetes API에 제출하는 선언의 역할을 가리킵니다.

대부분의 매니페스트에는 다음 네 가지 필드가 반복해서 등장합니다. `apiVersion`에는 사용할 API 버전을 적고, `kind`에는 만들 리소스의 종류를 적습니다. `metadata`에는 리소스 이름과 분류 정보를 적습니다. `spec`에는 사용자가 원하는 상태를 적습니다. Kubernetes는 리소스를 만든 뒤 실제 상태를 `status`에 기록하지만, 사용자가 매니페스트에 `status`를 직접 작성하는 경우는 드뭅니다.

```yaml
# Kubernetes 매니페스트의 공통 구조를 보여 주는 예시
apiVersion: <API 그룹과 버전>
kind: <리소스 종류>
metadata:
  name: <리소스 이름>
spec:
  <원하는 상태>
```

이 매니페스트를 `kubectl apply -f` 명령으로 제출하면 API Server가 리소스를 검사하고 저장합니다. 저장된 `spec`은 한 번 실행하고 버리는 명령이 아닙니다. Kubernetes의 제어 프로세스는 `spec`에 적힌 원하는 상태와 클러스터의 실제 상태를 계속 비교합니다.

## 2. 컨테이너를 함께 실행하는 Pod

<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/pod.svg" alt="Kubernetes 공식 Pod 리소스 마크" width="260">

*Fig 2. Kubernetes 공식 Pod 리소스 마크: Kubernetes Community 공개 아이콘 에셋*

</div>

<div align="center">

![성수선임과 함께 배우는 쿠버네티스 : Pod 캐릭터](../images/characters/character-pod.png)

</div>

*성수선임과 함께 배우는 쿠버네티스 : Pod 캐릭터*

Pod 캐릭터는 캥거루처럼 앞주머니에 **Container**들을 품고 있습니다. 주머니의 육각, 큐브 표시는 Kubernetes의 최소 실행 단위를, 주머니 안 컨테이너가 둘인 모습은 한 Pod에 컨테이너를 여러 개 둘 수 있다는 점을 떠올리게 합니다.

<div align="center">

![Kubernetes Pod](../images/articles/02/11-pod.svg)

</div>

**Pod**(파드)는 Kubernetes가 스케줄링하고 실행하는 최소 단위입니다. Pod에는 컨테이너를 하나 이상 넣을 수 있습니다. 애플리케이션 컨테이너 하나만 넣는 구성이 가장 흔하지만, 반드시 함께 실행해야 하는 보조 컨테이너가 있으면 같은 Pod에 둘 수 있습니다.

같은 Pod 안의 컨테이너는 항상 같은 노드에 배치됩니다. 컨테이너들은 하나의 Pod IP를 함께 사용하고, 서로 다른 포트를 사용해서 `localhost`로 통신할 수 있습니다. Pod에 볼륨을 선언하면 컨테이너들이 같은 파일도 공유할 수 있습니다. **볼륨**(volume)은 컨테이너가 읽고 쓸 저장 공간을 Pod에 연결하는 방식입니다.

보조 컨테이너를 **사이드카**(sidecar)라고 부릅니다. 예를 들어 애플리케이션 컨테이너가 파일에 로그를 쓰고, 로그 수집 컨테이너가 같은 파일을 읽어 외부 저장소로 보낼 수 있습니다. 두 컨테이너는 같은 노드에서 함께 실행되어야 하고 같은 로그 디렉터리를 봐야 하므로, 두 컨테이너를 하나의 Pod로 묶는 구성이 자연스럽습니다.

```yaml
# 한 Pod 안의 두 컨테이너가 임시 볼륨을 공유하는 예시
apiVersion: v1
kind: Pod
metadata:
  name: api-server
spec:
  containers:
  - name: api
    image: my-api:1.0
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
  - name: log-agent
    image: fluentd:v1.18
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
  volumes:
  - name: app-logs
    emptyDir: {}
```

위 매니페스트의 `emptyDir`은 Pod가 노드에서 실행되는 동안 사용할 수 있는 임시 볼륨입니다. 두 컨테이너는 `app-logs`라는 같은 볼륨을 각자의 `/var/log/app` 경로에 연결합니다. Pod가 삭제되면 `emptyDir`에 저장한 데이터도 함께 사라집니다. 영구 보관이 필요한 데이터에는 별도의 영구 볼륨을 사용해야 합니다.

한 Pod에 컨테이너를 여러 개 넣을 수 있다고 해서 관련이 적은 애플리케이션까지 모두 묶어서는 안 됩니다. 함께 배포하고 함께 교체해야 하며 네트워크나 파일을 긴밀하게 공유하는 컨테이너만 같은 Pod에 두는 편이 좋습니다. 웹 서버와 데이터베이스처럼 배포 주기와 확장 기준이 다른 애플리케이션은 보통 서로 다른 Pod로 나눕니다.

Pod는 교체될 수 있는 실행 단위입니다. Pod를 새로 만들면 Pod 이름과 IP가 달라질 수 있고, 단독으로 만든 Pod를 삭제하면 Kubernetes가 같은 Pod를 자동으로 다시 만들지 않습니다. 장기간 운영할 애플리케이션에는 Pod 복제본 개수와 Pod 교체 과정을 관리하는 상위 리소스가 필요합니다.

## 3. Pod 복제본과 배포를 관리하는 Deployment

<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/deploy.svg" alt="Kubernetes 공식 Deployment 리소스 마크" width="260">

*Fig 4. Kubernetes 공식 Deployment 리소스 마크: Kubernetes Community 공개 아이콘 에셋*

</div>

<div align="center">

![성수선임과 함께 배우는 쿠버네티스 : Deployment 캐릭터](../images/characters/character-deployment.png)

</div>

*성수선임과 함께 배우는 쿠버네티스 : Deployment 캐릭터*

Deployment 캐릭터는 안전모와 점검표를 든 관리자처럼 여러 **Pod**를 살피고 있습니다. 건강한 Pod들을 일정하게 유지하고 문제가 생긴 Pod를 돌보는 모습은 Deployment가 원하는 복제본 수를 맞추고 배포 상태를 관리한다는 점을 보여 줍니다.

<div align="center">

![Kubernetes Deployment](../images/articles/02/12-deployment.svg)

</div>

**Deployment**(디플로이먼트)는 원하는 Pod 복제본 개수와 Pod의 구성을 선언하는 상위 리소스입니다. Deployment는 내부에 적힌 Pod 템플릿을 기준으로 Pod를 만들고, 지정한 Pod 복제본 개수를 유지합니다. 컨테이너 이미지가 바뀌면 Pod를 새 구성으로 교체하는 배포 과정도 관리합니다.

### 3.1 Pod 템플릿과 셀렉터

**Pod 템플릿**(Pod template)은 Deployment가 만들 Pod의 모습을 적은 부분입니다. 템플릿에는 Pod에 붙일 레이블과 컨테이너 이미지, 포트 같은 설정이 들어갑니다. **레이블**(label)은 리소스를 분류하기 위해 붙이는 키와 값 형태의 정보입니다.

Deployment의 `spec.selector`는 Deployment가 어떤 Pod를 관리할지 고르는 조건입니다. 이 조건을 **셀렉터**(selector)라고 합니다. `spec.selector.matchLabels`와 `spec.template.metadata.labels`는 같은 레이블을 가리켜야 합니다. 두 값이 다르면 API가 리소스 생성을 거절합니다.

```yaml
# Pod 복제본 세 개와 Pod 템플릿을 선언하는 Deployment 예시
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: my-web:1.0
        ports:
        - containerPort: 8080
```

최상단의 `metadata.labels`는 Deployment 자체를 검색하고 분류할 때 사용합니다. `spec.selector.matchLabels`는 Deployment가 관리할 Pod를 고릅니다. `spec.template.metadata.labels`는 새로 생성할 Pod에 실제로 붙일 레이블입니다. 세 위치에 같은 값이 자주 등장하지만, 각 필드가 고르는 대상은 서로 다릅니다.

### 3.2 ReplicaSet과 자동 복구

Deployment는 Pod를 직접 하나씩 유지하지 않습니다. Deployment가 **ReplicaSet**(레플리카셋)을 만들고, ReplicaSet이 지정한 Pod 복제본 개수를 유지합니다. Deployment 매니페스트에 `replicas: 3`을 적으면 ReplicaSet은 같은 템플릿을 사용하는 Pod 세 개가 실행되도록 상태를 맞춥니다.

Deployment가 만든 Pod 하나를 삭제하면 ReplicaSet은 실제 Pod 복제본 개수가 두 개로 줄었다는 사실을 확인합니다. ReplicaSet은 원하는 Pod 복제본 개수인 세 개를 맞추기 위해 새 Pod 하나를 만듭니다. 이 동작은 삭제된 Pod 자체를 되살리는 것이 아니라, 같은 템플릿을 사용하는 새 Pod를 만드는 방식입니다. 따라서 새 Pod의 이름과 IP는 이전 Pod와 달라질 수 있습니다.

Deployment의 컨테이너 이미지를 `my-web:1.0`에서 `my-web:1.1`로 바꾸면 Deployment는 새 ReplicaSet을 만들고 Pod를 점진적으로 교체합니다. 이 과정을 **롤링 업데이트**(rolling update)라고 합니다. 배포 기록이 남아 있으면 이전 Pod 템플릿으로 되돌리는 롤백도 수행할 수 있습니다.

### 3.3 컨테이너 상태를 검사하는 Probe

<div align="center">

![Liveness Probe와 Readiness Probe 실패 결과](../images/articles/03/04-probe.svg)

</div>

Pod가 `Running`이라고 해서 애플리케이션이 요청을 정상적으로 처리할 준비까지 끝났다는 뜻은 아닙니다. 컨테이너 프로세스는 살아 있어도 데이터베이스 연결이나 초기 데이터 로딩을 마치지 못했을 수 있습니다. Kubernetes는 컨테이너 상태를 주기적으로 검사하는 **Probe**(프로브)를 제공합니다.

**Liveness Probe**는 컨테이너가 계속 동작할 수 있는지를 검사합니다. Liveness Probe가 정해진 횟수만큼 실패하면 Kubelet이 해당 컨테이너를 재시작할 수 있습니다. **Readiness Probe**는 컨테이너가 요청을 받을 준비가 되었는지를 검사합니다. Readiness Probe가 실패하면 Kubernetes는 해당 Pod를 일반적인 요청 전달 대상에서 제외합니다. Readiness Probe 실패는 컨테이너 재시작을 뜻하지 않습니다.

```yaml
# Deployment의 Pod 템플릿에 HTTP Probe를 추가하는 예시
spec:
  template:
    spec:
      containers:
      - name: web
        image: my-web:1.0
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
```

애플리케이션 기동이 느린데 Liveness Probe를 너무 일찍 시작하면, 애플리케이션이 준비를 마치기 전에 컨테이너 재시작이 반복될 수 있습니다. 이때는 애플리케이션의 실제 기동 시간을 먼저 확인하고 검사 시작 시점과 실패 기준을 조정해야 합니다.

## 4. 변하는 Pod 앞에 고정 주소를 제공하는 Service

<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/svc.svg" alt="Kubernetes 공식 Service 리소스 마크" width="260">

*Fig 7. Kubernetes 공식 Service 리소스 마크: Kubernetes Community 공개 아이콘 에셋*

</div>

<div align="center">

![성수선임과 함께 배우는 쿠버네티스 : Service 캐릭터](../images/characters/character-service.png)

</div>

*성수선임과 함께 배우는 쿠버네티스 : Service 캐릭터*

Service 캐릭터는 안내 데스크에서 요청 목록을 확인한 뒤 뒤편의 **Pod**들을 가리키고 있습니다. 요청을 보내는 쪽은 매번 달라지는 Pod를 직접 찾지 않아도 되고, Service라는 고정된 입구를 이용하면 알맞은 Pod로 연결된다는 점을 표현합니다.

<div align="center">

![Kubernetes Service](../images/articles/02/07-k8s-service.svg)

</div>

Pod는 장애 복구와 배포 과정에서 계속 교체될 수 있습니다. 새 Pod에는 새 IP가 할당될 수 있으므로, 클라이언트가 Pod IP를 직접 저장해서 사용하면 연결이 쉽게 끊어집니다. **Service**(서비스)는 변하는 Pod 집합 앞에 고정된 가상 IP와 DNS 이름을 제공하는 네트워크 리소스입니다.

Service는 셀렉터와 일치하는 레이블을 가진 Pod를 요청 전달 대상으로 찾습니다. 클라이언트는 개별 Pod IP 대신 Service 이름과 포트로 요청을 보냅니다. Service 뒤의 Pod가 교체되어도 새 Pod의 레이블이 Service 셀렉터와 일치하면 요청 전달 대상이 새 Pod로 갱신됩니다.

```yaml
# app=web 레이블을 가진 Pod에 요청을 전달하는 Service 예시
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 8080
```

`port`는 클라이언트가 Service에 요청을 보낼 때 사용하는 포트입니다. `targetPort`는 선택된 Pod 안에서 애플리케이션이 요청을 받는 포트입니다. 위 설정에서는 클라이언트가 Service의 80번 포트로 보낸 요청을 Pod의 8080번 포트로 전달합니다.

Service의 `metadata.labels`가 아니라 `spec.selector`가 Pod 레이블과 맞아야 합니다. Deployment와 Service도 서로를 직접 참조하지 않습니다. Deployment는 Pod에 `app: web` 레이블을 붙이고, Service는 `app: web` 레이블을 가진 Pod를 독립적으로 찾습니다. 두 리소스가 같은 Pod 레이블을 기준으로 동작하기 때문에 간접적으로 연결됩니다.

Service의 기본 타입인 **ClusterIP**는 클러스터 내부에서만 사용할 가상 IP를 만듭니다. **NodePort**는 각 노드의 정해진 포트를 통해 Service를 외부에 노출합니다. **LoadBalancer**는 지원하는 클라우드 환경에서 외부 로드 밸런서를 만들고 Service와 연결합니다.

Readiness Probe도 Service와 연결됩니다. Pod의 Readiness Probe가 실패하면 해당 Pod는 요청을 받을 준비가 되지 않은 상태가 됩니다. Kubernetes는 준비되지 않은 Pod를 Service의 일반적인 요청 전달 대상에서 제외합니다. 컨테이너를 재시작하지 않고 트래픽만 차단한다는 점이 Liveness Probe와의 차이입니다.

## 5. HTTP 요청을 Service로 나누는 Ingress

<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/ing.svg" alt="Kubernetes 공식 Ingress 리소스 마크" width="260">

*Fig 9. Kubernetes 공식 Ingress 리소스 마크: Kubernetes Community 공개 아이콘 에셋*

</div>

<div align="center">

![성수선임과 함께 배우는 쿠버네티스 : Ingress 캐릭터](../images/characters/character-ingress.png)

</div>

*성수선임과 함께 배우는 쿠버네티스 : Ingress 캐릭터*

Ingress 캐릭터는 열쇠를 든 문지기처럼 외부 요청을 확인하고 여러 **Service** 입구 중 알맞은 곳을 가리키고 있습니다. 쇼핑과 웹을 나타내는 요청이 서로 다른 길로 나뉘는 모습은 Ingress가 도메인과 URL 경로에 따라 요청을 해당 Service로 전달한다는 점을 보여 줍니다.

**Ingress**(인그레스)는 클러스터 외부에서 들어오는 HTTP와 HTTPS 요청을 도메인이나 URL 경로에 따라 Service로 전달하도록 규칙을 선언하는 리소스입니다. 예를 들어 `example.com/api` 요청은 API Service로 보내고, `example.com/web` 요청은 웹 Service로 보내도록 한 주소에서 경로를 나눌 수 있습니다.

Ingress와 Service는 맡은 범위가 다릅니다. Service는 선택한 Pod 집합에 안정적인 주소를 제공하고 요청을 전달합니다. Ingress는 Service 앞에서 HTTP 호스트와 경로를 검사한 뒤 요청을 알맞은 Service로 보냅니다. Ingress의 백엔드는 Pod가 아니라 Service입니다.

```yaml
# example.com의 /web 요청을 web Service로 보내는 Ingress 예시
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
spec:
  ingressClassName: nginx
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

`host`는 요청의 도메인을, `path`는 URL 경로를 고르는 조건입니다. `pathType: Prefix`는 `/web`으로 시작하는 경로를 같은 규칙으로 처리한다는 뜻입니다. `backend.service.name`과 `backend.service.port`는 요청을 넘길 Service 이름과 포트를 가리킵니다.

Ingress 매니페스트만 만든다고 실제 네트워크 프록시가 생기지는 않습니다. **Ingress Controller**(인그레스 컨트롤러)는 Ingress 리소스를 관찰하고, 선언한 규칙을 실제 프록시나 로드 밸런서 설정으로 적용하는 실행 구성 요소입니다. 클러스터에 Ingress Controller가 설치되어 있어야 외부 요청이 Ingress 규칙을 따라 Service에 도달합니다. `ingressClassName`은 여러 Ingress Controller 중에서 이 Ingress를 처리할 대상을 지정합니다.

Ingress는 HTTPS 연결을 종료하고 인증서를 처리하도록 구성할 수도 있습니다. 이 경우 인증서와 개인 키를 Kubernetes 리소스에 저장하고 Ingress의 TLS 설정에서 해당 리소스를 참조합니다. 핵심은 Ingress가 규칙을 저장하고, Ingress Controller가 실제 요청을 처리한다는 책임 분리입니다.

## 6. 리소스 이름과 정책 범위를 나누는 Namespace

<div align="center">

![Kubernetes Namespace](../images/articles/02/08-namespace.svg)

</div>

**Namespace**(네임스페이스)는 하나의 클러스터 안에서 리소스 이름과 정책 적용 범위를 논리적으로 나누는 리소스입니다. 같은 클러스터를 여러 팀이나 서비스, 개발 환경이 함께 사용할 때 리소스를 구분하는 기준으로 사용합니다.

```yaml
# dev Namespace를 선언하는 매니페스트 예시
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```

Namespace에 속하는 리소스의 `metadata.namespace`에 `dev`를 적으면 해당 리소스가 `dev` Namespace에 만들어집니다. 매니페스트와 명령에 Namespace를 지정하지 않으면 현재 kubectl 문맥에 설정된 Namespace를 사용하며, 별도 설정이 없을 때는 보통 `default` Namespace를 사용합니다.

리소스 이름은 Namespace 안에서 고유하면 됩니다. `dev` Namespace와 `prod` Namespace에는 이름이 같은 `web` Deployment와 `web` Service가 각각 존재할 수 있습니다. 따라서 리소스를 정확히 식별하려면 Namespace와 리소스 이름을 함께 확인해야 합니다.

Service의 짧은 DNS 이름도 Namespace를 기준으로 해석됩니다. 같은 Namespace에 있는 Pod는 `web`이라는 이름으로 같은 Namespace의 Service에 접근할 수 있습니다. 다른 Namespace의 Service에 접근하려면 `web.prod`처럼 Service 이름과 Namespace 이름을 함께 적을 수 있습니다. 전체 DNS 이름은 `web.prod.svc.cluster.local`과 같은 형태입니다.

Namespace는 클러스터를 물리적으로 분리하지 않습니다. Namespace를 나눈 것만으로 서로 다른 Namespace 사이의 네트워크 통신이 자동으로 차단되거나 노드가 분리되는 것도 아닙니다. 권한을 제한하려면 역할 기반 접근 제어 정책을, 자원 사용량을 제한하려면 리소스 할당량을, 네트워크 통신을 제한하려면 네트워크 정책을 별도로 적용해야 합니다.

Pod와 Deployment, Service, Ingress는 특정 Namespace에 속합니다. 반면 Node처럼 클러스터 전체를 대상으로 하는 리소스도 있습니다. 따라서 모든 Kubernetes 리소스가 Namespace에 속한다고 이해하면 안 됩니다.

## 7. Pod이 하나의 외부 요청을 처리하는 흐름

<div align="center">

![Pod가 외부 요청을 처리하는 리소스 연결 관계](../images/articles/02/13-resource-link.svg)

</div>

지금까지 살펴본 리소스는 서로 다른 책임을 맡지만, 실제 요청을 처리할 때는 하나의 흐름으로 이어집니다. Namespace는 Pod와 Deployment, Service, Ingress의 이름과 정책 범위를 나눕니다. Deployment는 Pod 템플릿을 기준으로 ReplicaSet을 만들고, ReplicaSet은 원하는 Pod 복제본 개수를 유지합니다. Service는 Pod 레이블을 기준으로 요청 전달 대상을 찾습니다. Ingress는 외부 HTTP와 HTTPS 요청을 도메인과 경로에 따라 Service로 전달합니다.

외부 요청은 Ingress Controller에서 Ingress 규칙에 맞는 Service로 전달됩니다. Service는 자신의 셀렉터와 일치하고 요청을 받을 준비가 된 Pod 중 하나로 요청을 보냅니다. 선택된 Pod 안의 애플리케이션 컨테이너가 요청을 처리합니다. Pod가 교체되어도 Deployment가 원하는 Pod 복제본 개수를 유지하고, Service가 새 Pod를 요청 전달 대상으로 반영하므로 클라이언트는 개별 Pod IP를 알 필요가 없습니다.

이 연결에서 가장 자주 헷갈리는 부분은 레이블과 셀렉터입니다. Deployment의 `spec.selector.matchLabels`는 Deployment가 관리할 Pod를 고르고, `spec.template.metadata.labels`는 새 Pod에 실제 레이블을 붙입니다. Service의 `spec.selector`는 요청을 전달할 Pod를 고릅니다. Deployment와 Service의 셀렉터는 대개 같은 Pod 레이블을 사용하지만, 두 셀렉터는 서로 다른 목적을 가집니다.

리소스가 속한 Namespace도 맞아야 합니다. Service는 같은 Namespace에 있는 Pod를 셀렉터로 찾고, Ingress의 백엔드 Service도 Ingress와 같은 Namespace에 있어야 합니다. 이름과 레이블이 같더라도 Namespace가 다르면 이 연결은 성립하지 않습니다.

### 7.1 Service에 연결할 Pod가 보이지 않을 때

Service의 가상 IP가 만들어졌는데 요청이 실패한다면, 먼저 Service 셀렉터와 Pod 레이블을 확인해야 합니다. Service 셀렉터가 Pod 레이블과 다르거나, 일치하는 Pod가 준비되지 않았으면 Service가 요청을 전달할 대상을 찾지 못합니다.

**Endpoints**(엔드포인트)는 Service가 현재 요청을 전달할 Pod IP와 포트 목록입니다. Service와 Pod가 정상적으로 연결되었는지는 Endpoints에 대상 주소가 들어 있는지 확인해서 판단할 수 있습니다.

```bash
# Service 셀렉터와 일치하는 Pod와 요청 전달 대상을 확인하는 명령
kubectl -n dev get service web
kubectl -n dev get pods -l app=web --show-labels
kubectl -n dev get endpoints web
```

정상 상태에서는 Service 정보와 `app=web` 레이블을 가진 Pod가 보이고, Endpoints에 Pod IP와 애플리케이션 포트가 표시됩니다.

```text
NAME   TYPE        CLUSTER-IP      PORT(S)   AGE
web    ClusterIP   10.96.120.15    80/TCP    2m

NAME                   READY   STATUS    LABELS
web-7d9c7f8b6f-k2m4p    1/1     Running   app=web

NAME   ENDPOINTS          AGE
web    10.244.1.12:8080   2m
```

Endpoints가 `<none>`으로 표시된다면 Service의 `spec.selector`와 Pod의 `metadata.labels`가 같은지 확인합니다. 레이블이 맞는데도 Endpoints가 비어 있다면 Pod의 `READY` 상태와 Readiness Probe 결과를 확인합니다. Pod 이벤트에는 이미지 다운로드 실패와 Probe 실패처럼 Pod가 준비되지 못한 원인이 기록될 수 있습니다.

```bash
# 준비되지 않은 Pod의 상태와 이벤트를 확인하는 명령
kubectl -n dev describe pod -l app=web
kubectl -n dev get events --sort-by=.metadata.creationTimestamp
```

```text
Conditions:
  Type    Status
  Ready   False

Events:
  Type     Reason      Message
  Warning  Unhealthy   Readiness probe failed: HTTP probe failed with statuscode: 503
```

`describe` 출력의 `Conditions`와 `Events`에서 `Ready=False` 또는 `Readiness probe failed`를 확인할 수 있습니다. 이미지 이름이 잘못되었다면 `ErrImagePull`이나 `ImagePullBackOff` 상태가 나타날 수 있습니다. 증상을 확인한 뒤 Service 셀렉터, Pod 레이블, Readiness Probe, 컨테이너 이미지 순서로 원인을 좁히면 연결 문제를 찾기 쉽습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Pod는 함께 실행할 컨테이너를 묶고, Deployment는 Pod 복제본 개수와 배포 상태를 유지합니다. Service는 변하는 Pod 집합에 고정 주소를 제공하고, Ingress는 외부 HTTP와 HTTPS 요청을 Service로 나눕니다. Namespace는 리소스 이름과 정책 범위를 구분하며, Deployment와 Service는 Pod 레이블을 기준으로 각각 Pod를 관리하고 요청을 전달합니다.

다음 글에서는 로컬에 Kubernetes 실습 환경을 구성하고, 이번 글에서 살펴본 매니페스트와 명령을 실제 클러스터에 적용합니다.
