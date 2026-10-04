# 6장 선택 실습: Ingress와 HTTPS 요청 확인

> [6장 본문](../06-ingress-and-https.draft.md)의 개념을 확인하기 위한 선택 실습입니다. 본문을 먼저 읽은 뒤 필요한 실습만 진행하면 됩니다.

1절은 echo 앱으로 Service 직통 호출과 Ingress 경유 HTTPS 호출을 비교하는 기본 실습입니다. 2절의 TLS 버전 제한과 3절의 Gateway API 실습은 기본 실습 이후 선택해서 진행합니다. 각 절의 설치 전제를 먼저 확인하고, 마친 뒤 4절에서 리소스를 정리합니다. 출력은 실행 결과의 예시입니다.

## 1. echo 앱의 내부 호출과 외부 HTTPS 실습

이 실습은 Service 직통 호출, 클러스터 내부의 Ingress 경유 호출, 외부 PC의 HTTPS 호출을 차례로 비교합니다. 출력은 정상 동작을 설명하기 위한 예시이며 실제 이름, 주소, 포트, TLS 및 HTTP 버전은 환경에 따라 달라집니다.

### 1.1 환경과 세 가지 접근 경로

기존 학습용 Kubernetes 클러스터에 Ingress Controller가 설치되어 있고, IngressClass 이름이 `nginx`, Controller Service가 `ingress-nginx` Namespace의 `ingress-nginx-controller`라고 가정합니다. 다른 구현에서는 이름과 노출 방식을 실제 환경에 맞게 바꿉니다.

이 실습에서는 Controller의 HTTPS 진입점이 NodePort로 노출되어 있다고 가정합니다. NodePort의 원리와 다른 Service 타입과의 차이는 5장을 참고합니다. 앱 Service 자체를 NodePort로 바꾸면 Controller를 우회하므로 Ingress 규칙과 TLS를 검증할 수 없습니다.

먼저 클러스터와 Controller 상태를 확인하고 실습용 Namespace를 준비합니다.

```bash
# 현재 클러스터와 Ingress Controller의 준비 상태 확인
kubectl config current-context
kubectl get nodes
kubectl get ingressclass
kubectl get pods,svc -n ingress-nginx
kubectl create namespace echo-sound --dry-run=client -o yaml | kubectl apply -f -
```

IngressClass가 있어도 Controller Pod가 준비되지 않았다면 요청을 처리하지 못합니다. 외부 호출에는 Node 공인 IP로 가는 경로와 HTTPS NodePort를 허용하는 방화벽 또는 클라우드 보안 규칙도 필요합니다.

### 1.2 Deployment와 ClusterIP Service

다음 완성된 매니페스트를 `echo-app.yaml`로 저장합니다. echo 앱은 요청의 호스트, 경로, 헤더 같은 정보를 응답 본문에 보여 줍니다.

```yaml
# 요청 정보를 반환하는 echo 앱과 내부 ClusterIP 접근점 생성
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: echo-sound
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo  # Deployment 선택 조건, Pod Label과 Service 선택 조건 연결
  template:
    metadata:
      labels:
        app: echo  # Deployment 선택 조건, Pod Label과 Service 선택 조건 연결
    spec:
      containers:
      - name: echo
        image: gcr.io/google_containers/echoserver:1.10  # 요청 정보를 응답하는 애플리케이션
        ports:
        - name: http
          containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: echo-service
  namespace: echo-sound
spec:
  type: ClusterIP
  selector:
    app: echo  # Deployment 선택 조건, Pod Label과 Service 선택 조건 연결
  ports:
  - name: http
    port: 8080  # 라우팅 리소스가 참조할 Service 포트
    targetPort: http  # 이름이 http인 Pod 포트로 전달
```

- `containers[].image`: 요청 정보를 반환하는 echo 앱을 실행해 라우팅 결과를 확인합니다.
- `selector`와 Pod 템플릿의 `labels`: `echo` Label로 Deployment와 Service의 대상을 연결합니다.
- Service의 `port: 8080`와 `targetPort: http`: 라우팅 리소스가 참조할 포트와 실제 Pod 포트를 연결합니다.

두 YAML 문서는 `echo-sound` Namespace의 Deployment와 Service입니다. Pod는 한 개이며, 컨테이너의 `http` 포트는 8080번입니다.

리소스를 적용하고 호출용 Pod에서 Service를 직접 확인합니다.

```bash
# echo 앱과 호출용 Pod를 준비하고 Service 직접 호출 확인
kubectl apply -f echo-app.yaml
kubectl rollout status deployment/echo -n echo-sound --timeout=180s
kubectl run curl-client -n echo-sound --image=curlimages/curl:8.10.1 \
  --restart=Never --command -- sleep 86400
kubectl wait --for=condition=Ready pod/curl-client -n echo-sound --timeout=120s
kubectl get pods,svc,endpointslices -n echo-sound
kubectl exec -n echo-sound curl-client -- curl -sS -m 10 \
  -o /dev/null -w 'HTTP %{http_code}\n' http://echo-service:8080/echo
```

```text
HTTP 200
```

이 출력은 Service와 Pod의 연결이 정상이라는 뜻입니다. 아직 Ingress 규칙이나 TLS가 정상이라는 증거는 아닙니다.

### 1.3 학습용 TLS Secret과 Ingress

테스트 이름은 `echo.example.test`, 경로는 `/echo`로 사용합니다. `.test`는 문서와 테스트를 위해 예약된 이름이므로 공인 DNS 등록 없이 뒤의 `--connect-to`와 `--resolve`로 확인할 수 있습니다.

다음 명령은 SAN에 테스트 이름이 들어간 하루짜리 자체 서명 인증서를 만듭니다. `-addext`를 지원하는 OpenSSL이 필요합니다. 개인 키는 Git에 저장하지 않습니다.

```bash
# 학습용 인증서와 echo-sound Namespace의 TLS Secret 생성
CH06_TLS_DIR=$(mktemp -d)
openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
  -keyout "$CH06_TLS_DIR/echo.key" -out "$CH06_TLS_DIR/echo.crt" \
  -subj '/CN=echo.example.test' -addext 'subjectAltName=DNS:echo.example.test'
kubectl create secret tls echo-tls -n echo-sound \
  --cert="$CH06_TLS_DIR/echo.crt" --key="$CH06_TLS_DIR/echo.key" \
  --dry-run=client -o yaml | kubectl apply -f -
```

다음 완성된 매니페스트를 `echo-ingress.yaml`로 저장합니다.

```yaml
# echo.example.test의 HTTPS /echo 요청을 echo-service로 연결
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
  namespace: echo-sound
spec:
  ingressClassName: nginx  # 설치된 Controller의 IngressClass
  tls:
  - hosts:  # TLS를 적용할 호스트 목록
    - echo.example.test
    secretName: echo-tls  # 같은 Namespace의 TLS Secret
  rules:
  - host: echo.example.test  # 요청의 호스트 조건
    http:
      paths:
      - path: /echo  # 요청 경로 조건
        pathType: Prefix  # 경로 요소 단위 접두 일치
        backend:
          service:
            name: echo-service  # 백엔드 Service 이름
            port:
              number: 8080  # Service 포트 참조
```

- `spec.ingressClassName`: 이 Ingress를 처리할 IngressClass를 지정합니다.
- `spec.tls[].hosts`와 `secretName`: HTTPS 호스트와 그 인증서를 담은 TLS Secret을 연결합니다.
- `rules[].host`와 `http.paths[].path`, `pathType: Prefix`: 요청의 호스트와 경로를 비교해 적용할 규칙을 고릅니다.
- `backend.service.name`과 `port.number`: 요청을 보낼 Service 이름과 Service 포트입니다. Pod의 포트를 직접 적는 자리가 아닙니다.

API 버전과 `kind`는 Ingress 선언을 식별합니다. 리소스 이름은 관리용이며, 백엔드 Service와 TLS Secret은 Ingress와 같은 Namespace에 둡니다.

Ingress를 적용하고 Controller가 해석한 설정과 참조 대상을 확인합니다.

```bash
# Ingress를 적용하고 TLS Secret과 백엔드 EndpointSlice 확인
kubectl apply -f echo-ingress.yaml
kubectl describe ingress echo -n echo-sound
kubectl get secret echo-tls -n echo-sound
kubectl get endpointslices -n echo-sound \
  -l kubernetes.io/service-name=echo-service
```

### 1.4 클러스터 내부의 Ingress 경유 호출

URL의 호스트와 TLS SNI는 `echo.example.test`로 유지하고 실제 TCP 연결 대상만 Controller Service로 바꿉니다. **SNI**(Server Name Indication)는 TLS 연결을 시작할 때 클라이언트가 서버에 알리는 호스트 이름입니다.

```bash
# 공개 인증서를 복사하고 내부에서 Ingress HTTPS 진입점 호출
kubectl exec -i -n echo-sound curl-client -- \
  sh -c 'cat > /tmp/echo.crt' < "$CH06_TLS_DIR/echo.crt"
kubectl exec -n echo-sound curl-client -- curl -sS -m 10 \
  --cacert /tmp/echo.crt \
  --connect-to echo.example.test:443:ingress-nginx-controller.ingress-nginx.svc.cluster.local:443 \
  -o /dev/null -w 'HTTP %{http_code}\n' https://echo.example.test/echo
```

```text
HTTP 200
```

- `--connect-to`는 TCP 연결 대상만 Controller Service로 바꿉니다.
- URL의 `echo.example.test`는 인증서 검증, SNI, HTTP Host에 그대로 사용됩니다.
- `--cacert`는 학습용 공개 인증서를 이 요청의 신뢰 기준으로 사용합니다.
- Controller Service의 443번은 클러스터 내부 포트이며 외부 NodePort와 다릅니다.

인증서 검증을 생략하는 `-k`는 통신 경로를 임시로 구분할 때만 사용할 수 있습니다. `-k`로 성공한 결과를 인증서 검증 성공으로 해석하면 안 됩니다. [[1]](#ref-1)

### 1.5 외부 PC의 HTTPS 호출

먼저 Kubernetes에 접근할 수 있는 터미널에서 Controller Service의 실제 HTTPS NodePort를 확인합니다.

```bash
# Ingress Controller Service의 실제 HTTPS NodePort 확인
kubectl get svc ingress-nginx-controller -n ingress-nginx
kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}{"\n"}'
```

```text
31234
```

`31234`는 예시입니다. 값이 비어 있으면 Controller Service 타입과 포트 이름을 확인합니다. Controller 내부 443번과 외부 NodePort를 혼동하지 않습니다.

다음 명령은 외부 PC에서 실행합니다. 예시 IP `203.0.113.10`과 포트를 실제 값으로 바꾸고 공개 인증서 `echo.crt`만 외부 PC에 복사합니다. 개인 키는 복사하지 않습니다.

```bash
# 외부 PC에서 Node 공인 IP와 HTTPS NodePort를 통해 Ingress 호출
CH06_PUBLIC_IP=203.0.113.10
CH06_HTTPS_PORT=31234
curl -v --cacert ./echo.crt \
  --resolve "echo.example.test:${CH06_HTTPS_PORT}:${CH06_PUBLIC_IP}" \
  "https://echo.example.test:${CH06_HTTPS_PORT}/echo"
```

```text
* Connected to echo.example.test (...) port 31234
* SSL connection using TLSv1.3 ...
* SSL certificate verify ok.
< HTTP/2 200
...
Hostname: echo-...
...
x-forwarded-proto=https
```

출력은 설명을 위해 일부를 줄인 예시입니다. TLS 버전, HTTP 버전, 헤더와 본문 형식은 Controller와 클라이언트 환경에 따라 달라집니다.

- `certificate verify ok`: 지정한 신뢰 기준과 호스트 이름으로 인증서 검증에 성공했습니다.
- `HTTP/2 200`: echo 백엔드까지 라우팅된 요청이 정상 응답을 받았습니다.

앞의 연결 로그는 사용한 포트와 TLS 버전을 보여 줍니다. `Hostname`은 응답 Pod를 식별하고, `x-forwarded-proto=https`는 원래 요청이 HTTPS였음을 백엔드에 전달하는 정보입니다. 이 예시의 성공 판단은 인증서 검증과 HTTP 응답을 기준으로 합니다.

외부 요청은 HTTPS지만 echo Pod는 HTTP 8080번으로 요청을 받습니다. TLS를 끝낸 위치가 Ingress 진입점이기 때문입니다. 이 호출에서 사용하는 NodePort는 Controller의 진입점일 뿐 앱 Service의 타입은 계속 `ClusterIP`입니다.

## 2. 선택 심화: ConfigMap으로 TLS 버전 제한

> 이 절은 선택 심화 실습입니다. Ingress Controller 설정을 바꾸는 실습이 아니라, 별도의 nginx 애플리케이션 Pod가 직접 TLS를 종료하는 경우를 비교합니다.

Secret은 인증서와 개인 키를 제공하고, ConfigMap은 nginx가 허용할 TLS 버전을 제공합니다. 먼저 별도 Namespace와 인증서를 준비합니다. 4절과 같은 터미널에서 `CH06_TLS_DIR`가 유지되어 있어야 합니다.

```bash
# TLS 버전 비교용 Namespace와 인증서 Secret 준비
kubectl create namespace nginx-static --dry-run=client -o yaml | kubectl apply -f -
openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
  -keyout "$CH06_TLS_DIR/nginx.key" -out "$CH06_TLS_DIR/nginx.crt" \
  -subj '/CN=ckaquestion.k8s.local' \
  -addext 'subjectAltName=DNS:ckaquestion.k8s.local'
kubectl create secret tls nginx-tls -n nginx-static \
  --cert="$CH06_TLS_DIR/nginx.crt" --key="$CH06_TLS_DIR/nginx.key" \
  --dry-run=client -o yaml | kubectl apply -f -
```

다음 완성된 매니페스트를 `nginx-tls-lab.yaml`로 저장합니다.

```yaml
# ConfigMap의 TLS 정책과 Secret 인증서를 사용하는 nginx 서버 생성
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config  # 설정 파일을 제공하는 ConfigMap
  namespace: nginx-static
data:
  nginx.conf: |  # nginx가 읽을 TLS 서버 설정
    events {}
    http {
      server {
        listen 443 ssl;
        ssl_certificate /etc/nginx/tls/tls.crt;
        ssl_certificate_key /etc/nginx/tls/tls.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        location / {
          return 200 "Hello TLS\n";
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-static
  namespace: nginx-static
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-static
  template:
    metadata:
      labels:
        app: nginx-static
    spec:
      containers:
      - name: nginx
        image: nginx:1.28
        ports:
        - containerPort: 443
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/nginx.conf  # 설정 파일을 읽을 위치
          subPath: nginx.conf  # ConfigMap의 해당 파일만 마운트
          readOnly: true
        - name: tls
          mountPath: /etc/nginx/tls  # 인증서와 개인 키를 읽을 디렉터리
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: nginx-config  # 설정 파일을 제공하는 ConfigMap
      - name: tls
        secret:
          secretName: nginx-tls  # 인증서와 개인 키를 제공하는 Secret
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: nginx-static
spec:
  selector:
    app: nginx-static
  ports:
  - name: https
    port: 443  # 클라이언트가 접속할 HTTPS 포트
    targetPort: 443  # nginx의 TLS 수신 포트
```

- `data.nginx.conf`: nginx가 직접 TLS를 처리할 설정입니다. `listen 443 ssl`로 HTTPS를 받고, `ssl_protocols`로 TLS 1.2와 1.3을 허용합니다.
- `volumeMounts[].mountPath`와 `subPath`: 설정 파일은 `/etc/nginx/nginx.conf`에, 인증서는 `/etc/nginx/tls`에 연결합니다. `subPath`는 설정 파일 하나만 마운트합니다.
- `volumes[].configMap.name`과 `secret.secretName`: 각각 설정을 담은 `nginx-config`와 인증서를 담은 `nginx-tls`를 참조합니다.
- Service의 `port`와 `targetPort`: 443번 연결을 nginx의 443번 포트로 전달합니다.

세 문서는 `nginx-static` Namespace의 ConfigMap, Deployment와 Service입니다. Deployment는 nginx Pod 하나를 실행하고 Service는 같은 Label을 선택합니다. 두 마운트는 읽기 전용입니다.

배포한 뒤 TLS 1.2와 1.3을 각각 고정해서 기준선을 확인합니다.

```bash
# nginx TLS 서버를 배포하고 TLS 1.2와 1.3 기준선 확인
kubectl apply -f nginx-tls-lab.yaml
kubectl rollout status deployment/nginx-static -n nginx-static --timeout=180s
kubectl exec -i -n echo-sound curl-client -- \
  sh -c 'cat > /tmp/nginx.crt' < "$CH06_TLS_DIR/nginx.crt"
kubectl exec -n echo-sound curl-client -- curl -sS -m 10 \
  --cacert /tmp/nginx.crt --tlsv1.2 --tls-max 1.2 \
  --connect-to ckaquestion.k8s.local:443:nginx-service.nginx-static.svc.cluster.local:443 \
  https://ckaquestion.k8s.local/
kubectl exec -n echo-sound curl-client -- curl -sS -m 10 \
  --cacert /tmp/nginx.crt --tlsv1.3 --tls-max 1.3 \
  --connect-to ckaquestion.k8s.local:443:nginx-service.nginx-static.svc.cluster.local:443 \
  https://ckaquestion.k8s.local/
```

```text
Hello TLS
Hello TLS
```

두 호출 모두 성공해야 합니다. curl과 curl이 사용하는 TLS 라이브러리가 TLS 1.3을 지원해야 하므로 클라이언트 옵션 오류를 서버의 차단 결과로 해석하지 않습니다.

이제 `nginx-tls-lab.yaml`의 `ssl_protocols` 한 줄을 다음 설정 조각처럼 바꿉니다.

```nginx
# nginx가 TLS 1.3 연결만 허용하도록 제한
ssl_protocols TLSv1.3;
```

- `ssl_protocols TLSv1.3`: nginx가 TLS 1.3만 협상하도록 허용합니다.

설정을 다시 적용하고 Pod를 재생성한 뒤 nginx 설정 문법을 확인합니다.

```bash
# ConfigMap 변경을 새 Pod에 반영하고 nginx 설정 검증
kubectl apply -f nginx-tls-lab.yaml
kubectl rollout restart deployment/nginx-static -n nginx-static
kubectl rollout status deployment/nginx-static -n nginx-static --timeout=180s
kubectl exec -n nginx-static deploy/nginx-static -- nginx -t
```

`subPath`로 마운트한 ConfigMap 파일은 기존 Pod에서 자동으로 바뀌지 않습니다. ConfigMap만 수정해도 nginx 프로세스가 설정을 자동 재로딩하지 않습니다. 이 실습에서는 새 Pod를 만들어 파일을 다시 마운트합니다. [[2]](#ref-2)

앞의 두 curl 명령을 다시 실행하면 TLS 1.2는 핸드셰이크에서 실패하고 TLS 1.3은 `Hello TLS`를 반환해야 합니다. TLS 1.2의 오류 문구와 종료 코드는 TLS 구현에 따라 다릅니다. HTTP 요청 전에 실패하므로 HTTP 403 같은 응답을 기대하지 않습니다.

## 3. Gateway API로 진입점과 경로 분리

Ingress는 구현 선택, TLS 진입점, 호스트와 경로 규칙을 한 리소스에 모읍니다. **Gateway API**는 이 역할을 `GatewayClass`, `Gateway`, `HTTPRoute`로 나눕니다. 이번 절은 앞의 echo HTTPS 구성을 옮기고, 경로 분기와 가중치 라우팅까지 한 번에 확인하는 통합 실습입니다. [[3]](#ref-3)

### 3.1 세 리소스와 실행 전제

| 리소스 | 범위와 역할 |
|---|---|
| `GatewayClass` | 클러스터 범위에서 요청 경로를 구현할 Controller를 선택 |
| `Gateway` | Namespace 안에서 주소, 포트, 프로토콜, TLS 인증서를 가진 리스너 선언 |
| `HTTPRoute` | 호스트, 경로, 백엔드 Service와 트래픽 비중 선언 |

세 리소스도 패킷이 통과하는 서버가 아니라 API 선언입니다. Gateway API CRD와 이를 처리하는 Controller가 설치되어 있어야 합니다. Ingress Controller가 있다는 사실만으로 Gateway API가 동작하지는 않습니다.

실제 설치된 `GatewayClass`와 Controller 수락 상태를 확인합니다. 다음 예시에서는 수락된 Class 이름이 `nginx`라고 가정합니다. 임의의 `controllerName`으로 GatewayClass 리소스만 만들어도 Controller가 설치되지는 않으므로, 실습에서 가짜 Class를 만들지 않습니다.

```bash
# Gateway API CRD와 Controller가 수락한 GatewayClass 확인
kubectl api-resources --api-group=gateway.networking.k8s.io
kubectl get gatewayclass
kubectl describe gatewayclass nginx
kubectl get secret echo-tls -n echo-sound
```

`GatewayClass` 상태의 `Accepted=True`를 확인합니다. API 리소스가 없거나 수락된 Class가 없다면 다음 매니페스트를 적용하기 전에 Gateway API와 호환 Controller를 설치해야 합니다.

### 3.2 HTTPS Gateway와 TLS Secret 재사용

다음 완성된 매니페스트를 `echo-gateway.yaml`로 저장합니다. 앞에서 만든 `echo-tls`를 같은 Namespace에서 재사용합니다.

```yaml
# echo.example.test의 HTTPS 진입점을 Gateway로 선언
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: echo-gateway
  namespace: echo-sound
spec:
  gatewayClassName: nginx  # 이 Gateway를 처리할 클래스
  listeners:
  - name: https  # HTTPRoute가 선택할 리스너 이름
    protocol: HTTPS  # HTTPS 연결 수신
    port: 443  # 외부 HTTPS 진입 포트
    hostname: echo.example.test  # 허용할 호스트 이름
    tls:
      mode: Terminate  # Gateway에서 TLS 종료
      certificateRefs:  # 인증서 Secret 참조
      - kind: Secret
        name: echo-tls  # 리스너 인증서와 개인 키
    allowedRoutes:
      namespaces:
        from: Same  # 같은 Namespace의 Route만 연결 허용
```

- `spec.gatewayClassName`: Gateway를 처리할 구현을 선택합니다.
- `listeners[].name`, `protocol`, `port`, `hostname`: `https` 리스너가 `echo.example.test`의 HTTPS 연결을 443번 포트에서 받도록 지정합니다.
- `tls.mode: Terminate`와 `certificateRefs`: Gateway에서 TLS를 종료하며 `echo-tls` Secret의 인증서를 사용합니다.
- `allowedRoutes.namespaces.from: Same`: 같은 Namespace의 Route만 이 리스너에 연결하도록 허용합니다.

Gateway 이름은 `echo-gateway`이며 TLS Secret과 함께 `echo-sound` Namespace에 둡니다.

### 3.3 경로와 가중치 라우팅

가중치 분배를 확인하려면 두 번째 백엔드가 필요합니다. 다음 완성된 매니페스트를 `echo-v2-app.yaml`로 저장합니다. 기존 `echo-service`는 요청 정보를 반환하고, 새 `echo-v2-service`는 `version v2`를 반환합니다.

```yaml
# Gateway 가중치 라우팅을 비교할 v2 백엔드와 Service 생성
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-v2
  namespace: echo-sound
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-v2  # Deployment 선택 조건, Pod Label과 Service 선택 조건 연결
  template:
    metadata:
      labels:
        app: echo-v2  # Deployment 선택 조건, Pod Label과 Service 선택 조건 연결
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:1.0
        args:  # v2 응답 내용과 수신 포트 설정
        - -text=version v2
        - -listen=:5678
        ports:
        - name: http
          containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo-v2-service
  namespace: echo-sound
spec:
  selector:
    app: echo-v2  # Deployment 선택 조건, Pod Label과 Service 선택 조건 연결
  ports:
  - name: http
    port: 80  # 라우팅 리소스가 참조할 Service 포트
    targetPort: http  # 이름이 http인 Pod 포트로 전달
```

- `containers[].args`: `-text=version v2`로 응답을 구분하고 `-listen=:5678`로 수신 포트를 정합니다.
- `selector`와 Pod 템플릿의 `labels`: `echo-v2` Label로 Deployment와 Service의 대상을 연결합니다.
- Service의 `port: 80`와 `targetPort: http`: 라우팅 리소스가 참조할 포트와 실제 Pod 포트를 연결합니다.

두 YAML 문서는 `echo-sound` Namespace의 Deployment와 Service입니다. Pod는 한 개이며, 컨테이너의 `http` 포트는 5678번입니다.

다음 완성된 `HTTPRoute`를 `echo-route.yaml`로 저장합니다. `/v2` 요청은 모두 v2 Service로 보내고, `/echo` 요청은 기존 Service와 v2 Service에 90 대 10의 상대 비중으로 나눕니다.

```yaml
# /v2 경로 분기와 /echo의 90:10 가중치 라우팅 선언
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: echo-route
  namespace: echo-sound
spec:
  parentRefs:  # 연결할 Gateway 지정
  - name: echo-gateway
    sectionName: https  # Gateway의 https 리스너 선택
  hostnames:  # 이 Route에 적용할 호스트 목록
  - echo.example.test
  rules:
  - matches:
    - path:
        type: PathPrefix  # 접두 경로로 요청 구분
        value: /v2  # v2 전용 경로
    backendRefs:  # 요청을 전달할 Service와 포트
    - name: echo-v2-service
      port: 80
  - matches:
    - path:
        type: PathPrefix  # 접두 경로로 요청 구분
        value: /echo  # 가중치를 적용할 경로
    backendRefs:  # 요청을 전달할 Service와 포트
    - name: echo-service
      port: 8080
      weight: 90  # 기존 백엔드의 상대 비중
    - name: echo-v2-service
      port: 80
      weight: 10  # v2 백엔드의 상대 비중
```

- `parentRefs`와 `sectionName`: `echo-gateway`의 `https` 리스너에 Route를 연결합니다.
- `hostnames`: 이 Route에 적용할 호스트를 `echo.example.test`로 제한합니다.
- `matches[].path`: `PathPrefix` 조건으로 `/v2`와 `/echo` 요청을 구분합니다.
- `backendRefs`의 `name`과 `port`: 각 규칙이 전달할 Service와 Service 포트를 지정합니다.
- `backendRefs[].weight`: `/echo` 요청을 기존 백엔드와 v2 백엔드에 90 대 10의 상대 비중으로 분배합니다.

HTTPRoute는 Gateway와 같은 `echo-sound` Namespace에 생성합니다. 공통 API 선언과 리소스 이름은 앞의 예시와 같은 역할입니다.

가중치는 각 요청을 정확히 90번과 10번으로 고정하는 값이 아니라 장기적인 상대 비중입니다. 적은 횟수의 결과는 비율과 다를 수 있으며, 세션 고정이나 Controller 기능이 결과에 영향을 줄 수 있습니다. Controller가 사용하는 Gateway API 적합성 프로필과 가중치 지원 여부도 확인해야 합니다. [[4]](#ref-4)

### 3.4 적용, 상태 확인, HTTPS 검증

백엔드, Gateway, Route를 적용하고 Controller가 기록한 상태 조건을 확인합니다.

```bash
# Gateway API 리소스를 적용하고 수락 및 참조 상태 확인
kubectl apply -f echo-v2-app.yaml
kubectl rollout status deployment/echo-v2 -n echo-sound --timeout=180s
kubectl apply -f echo-gateway.yaml -f echo-route.yaml
kubectl get gateway,httproute -n echo-sound
kubectl describe gateway echo-gateway -n echo-sound
kubectl describe httproute echo-route -n echo-sound
kubectl get gateway echo-gateway -n echo-sound -o wide
```

- Gateway의 `Accepted=True`는 Controller가 선언을 수락했다는 뜻입니다.
- Gateway의 `Programmed=True`는 실제 데이터 처리 구성에 반영되었다는 뜻입니다.
- HTTPRoute의 `Accepted=True`는 Route가 부모 리스너에 연결되었다는 뜻입니다.
- `ResolvedRefs=True`는 Service와 Secret 같은 참조를 해석했다는 뜻입니다.
- `status.addresses`는 Controller가 보고한 접속 주소이며 환경에 따라 IP 또는 호스트 이름입니다.

기존 Ingress의 NodePort가 Gateway에도 사용된다고 가정하지 않습니다. Gateway 주소나 Controller가 만든 진입용 Service를 확인한 뒤 새 진입점을 호출해야 전환을 검증할 수 있습니다.

다음 명령은 Gateway가 외부에서 접근 가능한 443번 주소를 제공할 때의 예시입니다.

```bash
# Gateway HTTPS 주소에서 경로 분기와 가중치 라우팅 확인
CH06_GW_ADDR=$(kubectl get gateway echo-gateway -n echo-sound \
  -o jsonpath='{.status.addresses[0].value}')
curl -sS --cacert "$CH06_TLS_DIR/echo.crt" \
  --connect-to "echo.example.test:443:${CH06_GW_ADDR}:443" \
  https://echo.example.test/v2
for i in $(seq 1 100); do
  response=$(curl -sS --cacert "$CH06_TLS_DIR/echo.crt" \
    --connect-to "echo.example.test:443:${CH06_GW_ADDR}:443" \
    https://echo.example.test/echo)
  case "$response" in
    *"version v2"*) echo "v2" ;;
    *) echo "v1" ;;
  esac
done | sort | uniq -c
```

```text
version v2
     91 v1
      9 v2
```

반복 결과는 예시입니다. 정확히 90 대 10이 되지 않아도 정상일 수 있습니다. 주소가 비어 있거나 사설 주소라면 Controller의 Service 노출 방식과 외부 연결 경로를 먼저 확인합니다. NodePort를 사용하는 Gateway 구현에서는 실제 HTTPS NodePort를 연결 대상 포트로 사용해야 합니다.

정상 응답과 인증서 검증을 끝낸 뒤에만 실제 DNS 대상을 새 진입점으로 옮깁니다. 기존 Ingress는 전환 확인 전까지 유지하고, 전환이 끝난 뒤 제거합니다. 리소스 생성 성공만으로 외부 HTTPS 전환이 끝난 것은 아닙니다.

## 4. 문제 확인과 실습 정리

### 4.1 실패 구간별 확인

| 증상 | 확인할 구간 | 확인할 내용 |
|---|---|---|
| 내부 Service 호출부터 실패 | Pod와 Service | Pod Ready, Selector, EndpointSlice, 실제 수신 포트 |
| Service는 성공하지만 Ingress 실패 | Controller와 규칙 | IngressClass, Host, `/echo`, Service 이름과 포트 |
| TLS 인증서 오류 | 이름과 신뢰 | SAN, SNI, URL 호스트, 공개 인증서와 Secret 일치 |
| 내부 Ingress는 성공하지만 외부 실패 | 외부 네트워크 | 공인 IP, HTTPS NodePort, 방화벽과 보안 그룹 |
| ConfigMap 변경 뒤 TLS 1.2도 성공 | 파일과 프로세스 | 실제 `data`, `subPath`, 새 Pod, nginx 설정 |
| Gateway 리소스만 있고 요청 실패 | Controller와 새 진입점 | GatewayClass 수락, `Programmed`, `ResolvedRefs`, 주소 |

앱, Service 대상, Ingress 이벤트를 한 번에 확인합니다.

```bash
# echo 앱부터 Ingress까지 실패 지점과 최근 이벤트 확인
kubectl get pods -n echo-sound -o wide
kubectl describe svc echo-service -n echo-sound
kubectl get endpointslices -n echo-sound \
  -l kubernetes.io/service-name=echo-service
kubectl describe ingress echo -n echo-sound
kubectl get events -n echo-sound --sort-by=.lastTimestamp
```

HTTP 404는 호스트나 경로 규칙이 맞지 않을 때, 503은 백엔드가 준비되지 않았을 때 나타날 수 있습니다. 그러나 상태 코드 하나로 원인을 확정하지 말고 Controller 이벤트와 로그를 함께 확인합니다. HTTP에서 HTTPS로의 리다이렉트 코드와 기본 동작도 Controller 구현에 따라 다릅니다.

Gateway API 상태와 Controller 이벤트도 별도로 확인합니다.

```bash
# Gateway와 HTTPRoute의 상태 조건 및 이벤트 확인
kubectl get gateway echo-gateway -n echo-sound -o yaml
kubectl get httproute echo-route -n echo-sound -o yaml
kubectl describe gateway echo-gateway -n echo-sound
kubectl describe httproute echo-route -n echo-sound
```

### 4.2 생성한 리소스 정리

실제로 진행한 단계의 파일만 삭제합니다. Gateway 또는 선택 심화 실습을 하지 않았다면 해당 명령은 생략합니다. 공유 Ingress Controller와 Gateway Controller는 다른 워크로드가 사용할 수 있으므로 삭제하지 않습니다.

```bash
# 이 실습에서 만든 앱, 라우팅, TLS 실습 리소스와 임시 파일 정리
kubectl delete -f echo-route.yaml -f echo-gateway.yaml --ignore-not-found
kubectl delete -f echo-v2-app.yaml --ignore-not-found
kubectl delete -f echo-ingress.yaml -f echo-app.yaml --ignore-not-found
kubectl delete pod curl-client -n echo-sound --ignore-not-found
kubectl delete secret echo-tls -n echo-sound --ignore-not-found
kubectl delete -f nginx-tls-lab.yaml --ignore-not-found
kubectl delete secret nginx-tls -n nginx-static --ignore-not-found
kubectl delete namespace nginx-static --ignore-not-found
kubectl delete namespace echo-sound --ignore-not-found
rm -rf "$CH06_TLS_DIR"
```

실습을 위해 별도 클라우드 서버, 공인 IP, 로드 밸런서, DNS 레코드, 방화벽 규칙을 만들었다면 Kubernetes 리소스와 별도로 정리합니다. 운영 Namespace에서 이름만 바꿔 실행했다면 Namespace 전체를 삭제하지 않습니다.

## 참고문헌

- <a id="ref-1"></a>[1] [curl 공식 매뉴얼: 연결 및 TLS 옵션](https://curl.se/docs/manpage.html)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: ConfigMap을 Pod에서 사용하기](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- <a id="ref-3"></a>[3] [Kubernetes Gateway API 공식 문서: API 개요](https://gateway-api.sigs.k8s.io/api-types/gatewayclass/)
- <a id="ref-4"></a>[4] [Kubernetes Gateway API 공식 문서: 트래픽 분할](https://gateway-api.sigs.k8s.io/guides/traffic-splitting/)
