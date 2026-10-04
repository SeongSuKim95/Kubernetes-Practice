# 후속 초안. NetworkPolicy와 CNI 집행

> 이 글은 7장에서 분리한 후속 주제 초안이며 장 번호는 아직 정하지 않았습니다. Pod 통신 허용 규칙과 CNI의 실제 집행을 연결하며, 정식 장 번호는 아직 정하지 않았습니다.

## 들어가며

NetworkPolicy는 선택한 Pod의 Ingress와 Egress 통신을 IP·포트·프로토콜 수준에서 허용 목록으로 바꾸는 Kubernetes 리소스입니다.[[1]](#ref-1) Namespace와 RBAC으로 API 작업 범위를 제한해도 Kubernetes 네트워크 모델에서 Pod가 보내는 HTTP 요청은 자동으로 차단되지 않습니다. CNI와 NetworkPolicy를 별도로 구성해야 통신 허용 범위가 바뀝니다.

이 글은 정책을 적용하기 전에 CNI 집행 가능 여부와 EKS VPC CNI 조건을 먼저 확인합니다. 그 뒤 정책이 없는 기준선, 기본 차단, 필요한 출처 허용, Selector의 AND·OR, DNS를 포함한 Egress를 차례로 검증합니다. 출력은 예시이며 CNI와 클러스터 DNS 구성에 따라 세부 결과가 달라질 수 있습니다.

## 1. 선언과 집행의 구분

Kubernetes 네트워크 모델은 Pod와 Service가 통신할 기본 연결 조건을 정의합니다.[[2]](#ref-2) API Server는 NetworkPolicy 객체를 저장하지만 패킷을 직접 차단하지 않습니다. **CNI(Container Network Interface)** 구현 또는 별도 정책 에이전트가 선택된 Pod와 허용 규칙을 데이터플레인에 반영합니다.[[3]](#ref-3) NetworkPolicy를 지원하지 않는 CNI에서는 객체가 정상 생성돼도 트래픽이 차단되지 않을 수 있습니다.

정책의 핵심 동작은 다음과 같습니다.

- 어떤 정책에도 선택되지 않은 Pod 방향은 기본적으로 격리되지 않습니다.
- Pod가 Ingress 정책에 선택되면 명시적으로 허용한 수신 연결만 허용됩니다.
- Pod가 Egress 정책에 선택되면 명시적으로 허용한 송신 연결만 허용됩니다.
- 여러 정책이 같은 Pod와 방향을 선택하면 허용 범위는 합쳐집니다. 좁은 정책이 넓은 정책을 덮어쓰지 않습니다.
- 송신 측 Egress와 수신 측 Ingress가 모두 격리됐다면 양쪽이 모두 연결을 허용해야 합니다.
- 허용된 연결의 응답 패킷은 일반적으로 그 연결의 일부로 처리됩니다.

NetworkPolicy의 **Ingress**는 Pod로 들어오는 통신 방향입니다. HTTP 경로와 Host를 라우팅하는 `kind: Ingress` 리소스와는 이름만 비슷하며 목적과 계층이 다릅니다. NetworkPolicy는 `/admin` 같은 HTTP 경로를 판별하지 않습니다.

## 2. CNI와 EKS VPC CNI 선행 점검

일반 클러스터에서는 정책 집행을 지원하는 Calico, Cilium 또는 해당 환경의 네트워크 구현이 필요합니다. CNI를 교체하는 작업은 기존 Pod 네트워크 전체에 영향을 줄 수 있으므로 이 글의 정책 실습과 별도 변경 절차로 다룹니다.

```bash
# 현재 CNI와 정책 에이전트 후보를 읽기 전용으로 확인
kubectl get daemonset -A
kubectl get pods -A -o wide
kubectl get crd | grep -E 'calico|cilium' || true
```

EKS의 Amazon VPC CNI는 지원되는 버전과 플랫폼에서 NetworkPolicy 기능을 명시적으로 활성화해야 합니다.[[4]](#ref-4) 다음은 전체 eksctl 파일이 아니라 기존 ClusterConfig의 `addons` 부분입니다.

```yaml
# EKS VPC CNI의 NetworkPolicy 기능을 활성화하는 애드온 설정 조각
addons:
- name: vpc-cni
  configurationValues: |-
    enableNetworkPolicy: "true"
- name: coredns
- name: kube-proxy
```

- `addons`: EKS가 관리할 클러스터 애드온 목록입니다.
- 첫 `name: vpc-cni`: Pod에 VPC IP와 네트워크를 제공하는 Amazon VPC CNI 애드온입니다.
- `configurationValues`: 애드온에 전달할 구성값을 문자열로 지정합니다.
- `enableNetworkPolicy: "true"`: VPC CNI의 NetworkPolicy 기능을 활성화합니다.
- `name: coredns`: Service DNS를 제공하는 CoreDNS 애드온입니다.
- `name: kube-proxy`: Service 가상 IP 전달 규칙을 관리하는 kube-proxy 애드온입니다.

지원 버전, Linux Node 조건, 정책 에이전트 포트와 기존 애드온 구성의 병합 방법은 적용 전 EKS 공식 문서에서 확인합니다. 설정값만 보고 완료로 판단하지 않고 `aws-node`와 정책 에이전트 상태, 실제 허용·차단 결과를 확인합니다.

```bash
# EKS VPC CNI와 정책 에이전트 상태를 확인
kubectl get daemonset aws-node -n kube-system
kubectl get pods -n kube-system -l k8s-app=aws-node
kubectl describe daemonset aws-node -n kube-system
```

## 3. 세 Namespace의 통신 기준선

`frontend`에는 허용할 호출자, `client`에는 거부할 호출자, `backend`에는 nginx와 Service를 만듭니다.

```bash
# 통신 비교용 Namespace 세 개를 준비
for ns in frontend client backend; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
```

다음을 `network-workloads.yaml`로 저장합니다.

```yaml
# 허용·거부 출처와 백엔드 Service를 만드는 실습 워크로드
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: netshoot
        image: nicolaka/netshoot:latest
        command: ["sleep", "infinity"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
      - name: netshoot
        image: nicolaka/netshoot:latest
        command: ["sleep", "infinity"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: backend
spec:
  selector:
    app: backend
  ports:
  - name: http
    port: 80
    targetPort: 80
```

- 첫 세 객체의 `apiVersion: apps/v1`과 `kind: Deployment`: 호출자 둘과 백엔드 Deployment를 선언합니다.
- 각 `metadata.name`과 `metadata.namespace`: 워크로드 이름과 서로 다른 Namespace를 지정합니다.
- 각 `spec.replicas: 1`: 비교용 Pod 한 개를 유지합니다.
- 각 `spec.selector.matchLabels.app`: Deployment가 관리할 Pod Label입니다.
- 각 `spec.template.metadata.labels.app`: Selector와 NetworkPolicy가 선택할 Pod Label입니다.
- 각 `spec.template.spec.containers`: Pod의 컨테이너 목록입니다.
- 두 `netshoot` 컨테이너의 `name`, `image`, `command`: DNS와 HTTP 도구가 있는 컨테이너를 계속 실행합니다.
- 백엔드 컨테이너의 `name`과 `image`: HTTP 응답을 제공할 nginx를 실행합니다.
- `ports[].containerPort: 80`: nginx가 사용하는 컨테이너 포트를 표시합니다.
- 마지막 객체의 `apiVersion: v1`과 `kind: Service`: 핵심 API 그룹의 Service를 선언합니다.
- Service의 `metadata.name`과 `metadata.namespace`: DNS 이름과 소속 Namespace를 지정합니다.
- `spec.selector.app: backend`: 같은 Namespace의 백엔드 Pod를 선택합니다.
- `spec.ports[].name: http`: Service 포트 이름입니다.
- `spec.ports[].port: 80`: 클라이언트가 연결할 Service 포트입니다.
- `spec.ports[].targetPort: 80`: 백엔드 컨테이너로 전달할 포트입니다.
- 각 `---`: 네 API 객체를 구분합니다.

```bash
# 정책 적용 전 두 출처가 모두 백엔드에 접속하는지 확인
kubectl apply -f network-workloads.yaml
kubectl rollout status deployment/frontend -n frontend --timeout=180s
kubectl rollout status deployment/client -n client --timeout=180s
kubectl rollout status deployment/backend -n backend --timeout=180s
kubectl exec -n frontend deploy/frontend -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
kubectl exec -n client deploy/client -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
```

두 요청이 `200`이면 기준선을 확보한 것입니다. 이미 실패한다면 NetworkPolicy보다 Service, EndpointSlice, DNS, Pod 상태와 기존 정책을 먼저 조사합니다.

## 4. 기본 차단과 frontend 허용

다음을 `default-deny-ingress.yaml`로 저장합니다.

```yaml
# backend Namespace의 모든 Pod 수신 연결을 기본 차단
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

- `apiVersion: networking.k8s.io/v1`: NetworkPolicy의 안정화된 API 버전입니다.
- `kind: NetworkPolicy`: Pod 통신 허용 정책을 선언합니다.
- `metadata.name: default-deny-ingress`: 정책 이름입니다.
- `metadata.namespace: backend`: 정책과 대상 Pod가 속한 Namespace입니다.
- `spec.podSelector: {}`: `backend`의 모든 Pod를 선택합니다.
- `spec.policyTypes: [Ingress]`: 수신 방향을 격리합니다.
- `ingress` 생략: 이 정책 자체는 어떤 수신 연결도 허용하지 않습니다.

다음을 `allow-frontend.yaml`로 저장합니다.

```yaml
# frontend Namespace의 frontend Pod만 backend TCP 80에 허용
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
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

- `apiVersion`, `kind`, `metadata.name`: 허용용 NetworkPolicy의 버전, 종류와 이름입니다.
- `metadata.namespace: backend`: 정책 대상이 있는 Namespace입니다.
- `spec.podSelector.matchLabels.app: backend`: 백엔드 Pod만 정책 대상으로 선택합니다.
- `policyTypes: [Ingress]`: 수신 연결 허용 규칙입니다.
- `ingress`: 허용할 수신 규칙 목록입니다.
- `ingress[].from`: 허용할 출처 목록입니다.
- 같은 항목의 `namespaceSelector`: 자동 Namespace Label로 `frontend`를 선택합니다.
- 같은 항목의 `podSelector`: 선택된 Namespace 안에서 `app: frontend` Pod만 선택합니다.
- `ports`: 해당 출처에 허용할 포트 목록입니다.
- `protocol: TCP`: TCP 연결만 허용합니다.
- `port: 80`: 백엔드 80번 포트만 허용합니다.

```bash
# 기본 차단 후 두 출처가 실패하고 허용 정책 후 frontend만 성공하는지 확인
kubectl apply -f default-deny-ingress.yaml
kubectl exec -n frontend deploy/frontend -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
kubectl exec -n client deploy/client -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
kubectl apply -f allow-frontend.yaml
kubectl exec -n frontend deploy/frontend -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
kubectl exec -n client deploy/client -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
```

기본 차단 뒤에는 둘 다 시간 초과되고, 허용 정책 뒤에는 frontend가 `200`, client가 시간 초과여야 합니다. curl의 `000`은 HTTP 응답 코드가 아니라 응답을 받지 못했다는 표시입니다. 허용 경로의 성공과 거부 경로의 실패를 함께 확인해야 정책 집행을 검증할 수 있습니다.

## 5. Namespace와 Pod Selector의 AND와 OR

`from` 또는 `to` 아래 별도 목록 항목은 OR입니다.

```yaml
# 별도 출처 항목으로 Namespace 조건과 Pod 조건을 OR 결합
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: frontend
  - podSelector:
      matchLabels:
        app: frontend
```

- `ingress`: 수신 허용 규칙 목록입니다.
- `from`: 이 규칙이 허용할 출처 목록입니다.
- 첫 `namespaceSelector`: `frontend` Namespace의 모든 Pod를 허용합니다.
- 두 번째 `podSelector`: 정책과 같은 `backend` Namespace의 `app: frontend` Pod를 허용합니다.
- 두 항목의 별도 `-`: 두 출처 중 하나만 일치해도 되는 OR를 만듭니다.

4절처럼 같은 목록 항목에 `namespaceSelector`와 `podSelector`를 함께 두면 AND입니다. 즉 `frontend` Namespace에 있으면서 `app: frontend`인 Pod만 허용합니다. 최소 권한이 목적이면 불필요한 `ipBlock`, 전체 Namespace, `ingress: [{}]`가 포함되지 않았는지 확인합니다.

`ingress: [{}]`는 모든 출처와 모든 포트를 허용합니다. 반면 `ingress: []` 또는 허용 규칙 생략은 선택된 Pod에 이 정책이 추가하는 허용 경로가 없다는 뜻입니다. 중괄호와 빈 목록을 혼동하면 정책 의미가 반대로 바뀝니다.

## 6. Egress 제한과 DNS 예외

Egress를 격리하면 Service 호출 전에 필요한 DNS 질의도 차단될 수 있습니다. 다음 정책은 frontend Pod에서 backend TCP 80과 kube-system DNS TCP·UDP 53만 허용합니다. NodeLocal DNS 또는 별도 DNS를 쓰는 환경에서는 실제 DNS 목적지 Label과 주소에 맞게 수정해야 합니다.

```yaml
# frontend의 backend HTTP와 클러스터 DNS만 허용하는 Egress 정책
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
  namespace: frontend
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: backend
      podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 80
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

- `apiVersion`, `kind`, `metadata.name`: Egress NetworkPolicy의 버전, 종류와 이름입니다.
- `metadata.namespace: frontend`: 정책과 대상 Pod가 있는 Namespace입니다.
- `spec.podSelector.matchLabels.app: frontend`: frontend Pod만 선택합니다.
- `policyTypes: [Egress]`: 송신 방향을 격리합니다.
- `egress`: 허용할 송신 규칙 목록입니다.
- 첫 `to`의 같은 항목에 있는 두 Selector: `backend` Namespace의 `app: backend` Pod를 AND로 선택합니다.
- 첫 `ports`의 `TCP`와 `80`: 백엔드 HTTP 목적지만 허용합니다.
- 두 번째 `to.namespaceSelector`: `kube-system` Namespace를 DNS 목적지 범위로 선택합니다.
- 두 번째 `ports`의 `UDP 53`: 일반 DNS 질의를 허용합니다.
- 두 번째 `ports`의 `TCP 53`: 큰 응답과 재시도 등에 사용하는 TCP DNS를 허용합니다.

다음을 `frontend-egress.yaml`로 저장해 적용합니다.

```bash
# DNS, 허용 HTTP와 허용하지 않은 외부 HTTPS를 각각 검증
kubectl apply -f frontend-egress.yaml
kubectl exec -n frontend deploy/frontend -- nslookup backend-service.backend
kubectl exec -n frontend deploy/frontend -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
kubectl exec -n frontend deploy/frontend -- curl -sS -m 5 https://example.com
```

이름 조회와 백엔드 호출은 성공하고 외부 HTTPS는 실패해야 합니다. 외부 호출 실패만으로 DNS 차단인지 TCP 443 차단인지 구분할 수 없으므로 `nslookup`을 별도로 수행합니다.

## 7. 진단과 정리

정책 적용 후 결과가 예상과 다르면 다음 순서로 범위를 줄입니다.

- 모든 호출이 실패: Pod, Service, EndpointSlice, DNS를 확인한 뒤 Ingress와 Egress 양쪽 정책을 조사합니다.
- 모두 허용됨: `podSelector`와 Namespace Label, 다른 넓은 허용 정책, CNI 정책 에이전트를 확인합니다.
- 이름만 실패: DNS 목적지와 UDP·TCP 53 Egress 허용을 확인합니다.
- IP 호출은 되고 Service 이름만 실패: NetworkPolicy보다 DNS 경로를 먼저 조사합니다.
- Pod 시작 직후만 통과: CNI 구현의 정책 적용 시점과 fail-open 설정을 공식 문서에서 확인합니다.

```bash
# 정책 선택 대상, 전체 허용 합집합과 네트워크 경로를 조사
kubectl get networkpolicy -A
kubectl describe networkpolicy -n backend
kubectl get pods -A --show-labels
kubectl get endpointslice -n backend
kubectl get namespace --show-labels
```

NetworkPolicy의 `from`과 `to`에는 Service 이름을 직접 쓸 수 없습니다. Pod Selector, Namespace Selector, `ipBlock`을 사용합니다. AWS Security Group은 ENI와 VPC 경계에서 집행되므로 Pod 선택 기반 NetworkPolicy와 적용 위치가 다릅니다.

```bash
# 정책을 먼저 지운 뒤 워크로드와 실습 Namespace를 정리
kubectl delete -f frontend-egress.yaml --ignore-not-found
kubectl delete -f allow-frontend.yaml --ignore-not-found
kubectl delete -f default-deny-ingress.yaml --ignore-not-found
kubectl delete -f network-workloads.yaml --ignore-not-found
kubectl delete namespace frontend client backend --ignore-not-found
```

GitOps가 정책을 관리한다면 Application의 관리 상태를 먼저 확인해야 삭제한 정책이 자동 복구되지 않습니다. 공유 Namespace는 일괄 삭제하지 않습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. NetworkPolicy는 허용 규칙의 선언이고 CNI가 실제 패킷을 집행합니다. 기본 차단과 구체적 허용을 함께 적용하고, Namespace·Pod Selector의 AND·OR와 Egress DNS 예외를 정확히 구분해야 합니다.

이 주제는 CNI가 정상 동작하고 Service DNS 기준선이 성공한다는 조건에 의존합니다. 후속 글의 장 번호는 정하지 않았으며, 다음 주제로는 Git의 선언과 클러스터 상태를 지속해서 맞추는 GitOps 운영을 연결할 수 있습니다.

## 참고문헌

- <a id="ref-1"></a>[1] [NetworkPolicy 공식 문서](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- <a id="ref-2"></a>[2] [Kubernetes 네트워크 모델 공식 문서](https://kubernetes.io/docs/concepts/services-networking/)
- <a id="ref-3"></a>[3] [CNI 명세 공식 저장소](https://github.com/containernetworking/cni)
- <a id="ref-4"></a>[4] [Amazon VPC CNI NetworkPolicy 설정 문서](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy-configure.html)
