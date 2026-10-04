# 5장 선택 실습: Service의 접근 경로 확인

> [5장 본문](../05-service-types.draft.md)의 개념을 직접 확인하기 위한 선택 실습입니다. 본문을 이해하는 데 실행이 필수는 아닙니다. Kubernetes 클러스터와 연결된 kubectl이 필요합니다.

ClusterIP → NodePort 순서로 같은 Pod에 접근합니다. LoadBalancer는 지원되는 환경에서만 선택적으로 진행합니다. 매니페스트는 아래에 포함되어 있으며, 이름과 Namespace는 이 실습 전용입니다.

## 1. 공통 nginx Deployment 준비

ClusterIP, NodePort, LoadBalancer의 접근 경로를 같은 조건에서 비교하기 위해 nginx Pod 두 개를 준비합니다. 세 Service는 모두 `app: service-demo` Label을 선택합니다. 실제 스케줄링 위치는 클러스터 상태에 따라 달라지며, 복제본을 두 개 선언했다고 해서 서로 다른 Node에 하나씩 배치된다고 보장되지는 않습니다.

먼저 실습용 Namespace를 만들고, 다음 매니페스트를 `nginx-deployment.yaml`로 저장합니다.

```bash
# Service 타입 실습을 분리할 Namespace 생성
kubectl create namespace service-lab
```

```yaml
# 세 Service가 공통으로 선택할 nginx Pod 두 개 생성
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: service-lab
spec:
  replicas: 2  # 같은 역할의 nginx Pod 두 개 유지
  selector:
    matchLabels:
      app: service-demo  # Deployment의 선택 조건과 Pod Label을 일치시킴
  template:
    metadata:
      labels:
        app: service-demo  # Deployment의 선택 조건과 Pod Label을 일치시킴
    spec:
      containers:
      - name: nginx
        image: nginx:1.28
        ports:
        - name: http  # Service의 targetPort에서 참조할 포트 이름
          containerPort: 80  # http라는 이름에 대응하는 컨테이너 포트
          protocol: TCP
```

- `spec.replicas: 2`: 요청을 나눠 받을 nginx Pod 두 개를 유지합니다.
- `spec.selector.matchLabels.app`과 `spec.template.metadata.labels.app`: `service-demo` Label로 Deployment와 Pod를 연결합니다. 뒤의 Service도 이 Label을 선택합니다.
- `ports[].name: http`와 `containerPort: 80`: Service가 `targetPort: http`로 참조할 포트를 지정합니다. 실제 수신은 nginx 설정이 담당합니다.

`service-lab` Namespace에 `nginx` Deployment를 만들며, 컨테이너는 `nginx:1.28` 이미지와 TCP 포트를 사용합니다.

Deployment를 적용한 뒤 두 Pod가 준비될 때까지 기다립니다.

```bash
# nginx Deployment 적용과 준비 상태 확인
kubectl apply -f nginx-deployment.yaml
kubectl rollout status deployment/nginx -n service-lab --timeout=120s
kubectl get pods -n service-lab -l app=service-demo -o wide
```

## 2. ClusterIP의 내부 호출

다음 선언을 `clusterip-service.yaml`로 저장합니다. 필드의 의미와 트래픽 흐름은 [5장 본문](../05-service-types.draft.md)에서 설명합니다.

```yaml
# nginx Pod에 클러스터 내부 접근점 제공
apiVersion: v1
kind: Service
metadata:
  name: clusterip-service
  namespace: service-lab
spec:
  type: ClusterIP  # 클러스터 내부 가상 IP 제공
  selector:
    app: service-demo  # 공통 nginx Pod의 Label 선택
  ports:
  - name: http
    port: 80  # 클라이언트가 사용할 Service 포트
    targetPort: http  # Pod의 http 포트인 80번으로 전달
    protocol: TCP
```

Service를 적용하고 내부 호출용 Pod에서 이름으로 요청합니다.

```bash
# ClusterIP Service 생성과 내부 이름 호출
kubectl apply -f clusterip-service.yaml
kubectl run service-client -n service-lab \
  --image=curlimages/curl:8.10.1 --restart=Never \
  --command -- sleep 3600
kubectl wait --for=condition=Ready pod/service-client \
  -n service-lab --timeout=120s
kubectl exec -n service-lab service-client -- \
  curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  http://clusterip-service:80/
```

```text
HTTP 200
```

위 출력은 정상 동작을 설명하기 위한 예시이며 실제 환경의 결과는 달라질 수 있습니다. `HTTP 200`은 클라이언트가 Service 이름을 해석하고 준비된 nginx Pod까지 요청을 전달했다는 뜻입니다. 일반적인 클러스터 외부 컴퓨터에는 ClusterIP로 가는 경로가 없지만, ClusterIP 자체를 보안 경계로 간주해서는 안 됩니다. 접근 제어는 네트워크와 권한 정책을 별도로 설계해야 합니다.

## 3. NodePort의 내부와 외부 호출

다음 선언을 `nodeport-service.yaml`로 저장합니다. 필드의 의미와 트래픽 흐름은 [5장 본문](../05-service-types.draft.md)에서 설명합니다.

```yaml
# 같은 nginx Pod를 Node의 30080번 포트로 노출
apiVersion: v1
kind: Service
metadata:
  name: nodeport-service
  namespace: service-lab
spec:
  type: NodePort  # Node 포트 진입점 추가
  selector:
    app: service-demo  # 공통 nginx Pod의 Label 선택
  ports:
  - name: http
    port: 80  # 클라이언트가 사용할 Service 포트
    targetPort: http  # Pod의 http 포트인 80번으로 전달
    protocol: TCP
    nodePort: 30080  # Node IP로 접속할 때 사용할 포트
```

Service를 적용하고 ClusterIP Service와 표시 내용을 비교합니다.

```bash
# NodePort Service 적용과 두 Service의 접근점 비교
kubectl apply -f nodeport-service.yaml
kubectl get svc -n service-lab \
  clusterip-service nodeport-service
```

```text
NAME                TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
clusterip-service   ClusterIP   10.96.10.20   <none>        80/TCP         2m
nodeport-service    NodePort    10.96.10.21   <none>        80:30080/TCP   10s
```

이 출력은 설명을 위한 예시이며 ClusterIP와 시간은 환경마다 달라집니다.

- `EXTERNAL-IP: <none>`: 별도 외부 로드 밸런서 주소가 없다는 뜻입니다. NodePort 진입점이 없다는 뜻은 아닙니다.
- `80:30080/TCP`: Service 포트는 80번이고 Node 포트는 30080번이라는 뜻입니다.

NodePort Service도 클러스터 안에서는 이름과 Service 포트로 호출할 수 있습니다.

```bash
# 내부 클라이언트에서 NodePort Service의 ClusterIP 접근점 호출
kubectl exec -n service-lab service-client -- \
  curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  http://nodeport-service:80/
```

```text
HTTP 200
```

클러스터 밖에서는 먼저 접근 가능한 Node 주소를 확인한 뒤 해당 주소의 30080번 포트를 호출합니다.

```bash
# 접근 가능한 Node 주소 확인과 외부 PC에서의 NodePort 호출 예시
kubectl get nodes -o wide
curl --connect-timeout 5 http://192.168.1.11:30080/
```

`192.168.1.11`은 예시 주소이므로 실제 클라이언트에서 접근 가능한 Node 주소로 바꿔야 합니다. NodePort를 만들었다고 Node에 공인 IP가 생기지는 않습니다. Node까지의 네트워크 경로와 30080번 포트를 허용하는 방화벽 또는 클라우드 보안 그룹도 필요합니다.

## 4. LoadBalancer의 외부 주소 확인

외부 로드 밸런서 구현이 설치된 환경에서만 진행합니다. 클라우드 자원 생성에는 비용이 발생할 수 있습니다.

다음 선언을 `loadbalancer-service.yaml`로 저장합니다. 필드의 의미와 트래픽 흐름은 [5장 본문](../05-service-types.draft.md)에서 설명합니다.

```yaml
# 외부 로드 밸런서 구현에 nginx 진입점 생성 요청
apiVersion: v1
kind: Service
metadata:
  name: loadbalancer-service
  namespace: service-lab
spec:
  type: LoadBalancer  # 외부 로드 밸런서 연결 요청
  selector:
    app: service-demo  # 공통 nginx Pod의 Label 선택
  ports:
  - name: http
    port: 80  # 클라이언트가 사용할 Service 포트
    targetPort: http  # Pod의 http 포트인 80번으로 전달
    protocol: TCP
```

지원되는 환경에서 Service를 적용하고 외부 주소를 확인합니다.

```bash
# LoadBalancer Service 적용과 외부 주소 확인
kubectl apply -f loadbalancer-service.yaml
kubectl get svc loadbalancer-service -n service-lab
```

```text
NAME                   TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)        AGE
loadbalancer-service   LoadBalancer   10.96.10.22   203.0.113.10    80:31234/TCP   1m
```

위 출력은 설명을 위한 예시입니다. `203.0.113.10`은 문서용 주소이며 실제로 접속할 수 없습니다.

- `EXTERNAL-IP`: 외부 로드 밸런서의 접근 주소입니다. 환경에 따라 IP 대신 호스트 이름이 표시됩니다.
- `80:31234/TCP`: 이 예시에서는 Service 포트 80번과 함께 NodePort 31234번이 할당되었습니다.

외부 주소 대신 `<pending>`이 계속 표시되면 로드 밸런서 구현과 생성 상태를 확인합니다. 이는 Pod의 `Pending` 단계와 다른 표시입니다.

## 5. Service 연결 문제의 진단과 정리

### 5.1 Pod와 EndpointSlice부터 확인하는 순서

Service 요청이 실패하면 외부 진입점부터 추측하기보다 Pod에서 바깥 방향으로 확인합니다. ClusterIP 내부 호출도 실패한다면 먼저 Service Selector, Pod Label, 준비 상태, EndpointSlice, 실제 수신 포트를 확인합니다. 내부 호출은 성공하고 외부 호출만 실패할 때 Node 주소, 방화벽, 로드 밸런서 상태를 확인하면 문제 구간을 빠르게 나눌 수 있습니다. [[1]](#ref-1)

```bash
# Service Selector와 Pod Label 및 EndpointSlice 연결 상태 확인
kubectl get svc clusterip-service -n service-lab
kubectl get pods -n service-lab \
  -l app=service-demo --show-labels
kubectl get endpointslices -n service-lab \
  -l kubernetes.io/service-name=clusterip-service
```

정상 상태에서는 Service와 Label이 일치하는 준비된 Pod가 보이고, EndpointSlice에 Pod IP와 애플리케이션 포트가 표시됩니다.

```text
NAME                TYPE        CLUSTER-IP     PORT(S)   AGE
clusterip-service   ClusterIP   10.96.120.15   80/TCP    2m

NAME                     READY   STATUS    LABELS
nginx-7d9c7f8b6f-k2m4p   1/1     Running   app=service-demo
nginx-7d9c7f8b6f-r7t9w   1/1     Running   app=service-demo

NAME                       ADDRESSTYPE   PORTS   ENDPOINTS                  AGE
clusterip-service-8x7pq    IPv4          80      10.244.1.12,10.244.2.9    2m
```

위 출력은 상태를 읽기 위한 예시이며 이름, IP, 시간은 환경마다 달라집니다.

- Pod의 `READY: 1/1`: 컨테이너가 요청을 받을 준비가 되었다는 뜻입니다.
- Pod의 `LABELS`: Service Selector와 일치해야 합니다.
- EndpointSlice의 `ENDPOINTS`와 `PORTS`: 실제 전달 후보인 Pod 주소와 포트입니다.

EndpointSlice에 주소가 없다면 Service의 `spec.selector`와 Pod의 `metadata.labels`가 같은지 확인합니다. Label이 맞는데도 준비된 대상이 없다면 Pod의 Ready Condition과 이벤트를 확인합니다.

```bash
# 준비되지 않은 Pod의 Condition과 실패 이벤트 확인
kubectl describe pod -n service-lab \
  -l app=service-demo
kubectl get events -n service-lab \
  --sort-by=.metadata.creationTimestamp
```

```text
Conditions:
  Type    Status
  Ready   False

Events:
  Type     Reason      Message
  Warning  Unhealthy   Readiness probe failed: HTTP probe failed with statuscode: 503
```

이 출력도 Readiness 실패를 설명하기 위한 예시입니다.

- `Ready: False`: Pod가 일반적인 Service 요청을 받을 준비가 되지 않았습니다.
- 이벤트의 `Message`: 준비 검사에 HTTP 503이 반환되어 실패했음을 보여 줍니다.

EndpointSlice에 준비된 주소가 있는데도 요청이 실패한다면 Service의 `port`와 `targetPort`, 컨테이너가 실제로 수신하는 포트를 비교합니다. `containerPort`는 포트 정보를 표시할 뿐 프로세스의 수신 설정을 바꾸지 않습니다.

NodePort의 내부 호출은 성공하지만 외부 호출만 실패한다면 클라이언트에서 Node IP까지의 경로와 NodePort 방화벽 허용을 확인합니다. LoadBalancer의 외부 주소가 `<pending>`이면 해당 타입을 처리할 Controller나 클라우드 연동의 상태와 이벤트를 확인합니다.

```bash
# Service 상세 정보와 최근 이벤트로 외부 진입점 문제 확인
kubectl describe svc nodeport-service -n service-lab
kubectl describe svc loadbalancer-service -n service-lab
kubectl get events -n service-lab \
  --sort-by=.metadata.creationTimestamp
```

### 5.2 실습 리소스 정리

LoadBalancer Service는 외부 자원과 비용을 만들 수 있으므로 실습이 끝나면 먼저 삭제 여부를 확인합니다. 다음 명령은 이 글에서 만든 Namespace 전체를 삭제합니다. `service-lab`을 다른 실습과 공유했다면 Namespace 전체를 삭제하지 말고 이 글에서 만든 개별 리소스만 삭제해야 합니다.

```bash
# 이 글 전용 Namespace와 내부 실습 리소스 전체 정리
kubectl delete namespace service-lab
```

LoadBalancer 구현이 외부 자원을 비동기로 삭제한다면 클라우드 콘솔이나 구현의 상태에서도 정리가 완료되었는지 확인합니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Service 문제 해결 공식 문서](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
