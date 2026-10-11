# 14장 선택 실습: Gateway API와 HTTPRoute

[14장 본문](../14-crd-and-gateway-api.draft.md)의 진입점과 경로 분리를 기존 echo 실습 환경에서 확인합니다. 먼저 [7장 실습의 1절](07-ingress-and-https.lab.md#1-echo-앱의-내부-호출과-외부-https-실습)에서 `echo-sound` Namespace의 앱, Service와 `echo-tls` Secret을 준비하고 유지합니다. 아래의 “앞에서 만든” 리소스는 이 환경을 가리킵니다. Gateway API 리소스 정의와 호환 Controller도 설치되어 있어야 합니다.

본문의 `web`·`api` 예시와 달리, 이 실습은 저장소의 기존 echo 앱으로 경로와 버전 분배를 확인합니다. 출력은 실행 결과의 예시입니다.

## 1. Gateway API로 진입점과 경로 분리

Ingress는 구현 선택, TLS 진입점, 호스트와 경로 규칙을 한 리소스에 모읍니다. **Gateway API**는 이 역할을 `GatewayClass`, `Gateway`, `HTTPRoute`로 나눕니다. 이번 절은 앞의 echo HTTPS 구성을 옮기고, 경로 분기와 가중치 라우팅까지 한 번에 확인하는 통합 실습입니다. [[1]](#ref-1)

### 1.1 세 리소스와 실행 전제

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

### 1.2 HTTPS Gateway와 TLS Secret 재사용

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

### 1.3 경로와 가중치 라우팅

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

가중치는 각 요청을 정확히 90번과 10번으로 고정하는 값이 아니라 장기적인 상대 비중입니다. 적은 횟수의 결과는 비율과 다를 수 있으며, 세션 고정이나 Controller 기능이 결과에 영향을 줄 수 있습니다. Controller가 사용하는 Gateway API 적합성 프로필과 가중치 지원 여부도 확인해야 합니다. [[2]](#ref-2)

### 1.4 적용, 상태 확인, HTTPS 검증

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

## 2. 실습 리소스 정리

이 실습에서 생성한 Gateway, HTTPRoute와 새 버전의 앱만 정리합니다.

```bash
kubectl delete -f echo-route.yaml -f echo-gateway.yaml --ignore-not-found
kubectl delete -f echo-v2-app.yaml --ignore-not-found
```

기본 echo 앱과 인증서까지 제거하려면 이후 [7장 실습의 정리 절](07-ingress-and-https.lab.md#32-생성한-리소스-정리)을 진행합니다. 공유 Gateway Controller는 유지합니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Gateway API 공식 문서: GatewayClass](https://gateway-api.sigs.k8s.io/reference/api-types/gatewayclass/)
- <a id="ref-2"></a>[2] [Gateway API 공식 문서: 요청 비중 분배](https://gateway-api.sigs.k8s.io/guides/user-guides/traffic-splitting/)
