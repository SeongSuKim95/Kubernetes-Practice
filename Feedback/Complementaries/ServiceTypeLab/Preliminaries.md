# ServiceTypeLab: ClusterIP vs NodePort 

이 실습은 **클러스터 내부(curl-client Pod)** 에서만 테스트합니다.

목표는 다음 3가지를 “눈으로 확인”하는 것입니다.

1. **ClusterIP 타입 Service**는 내부에서 `service DNS:80`로 정상 호출된다.
2. **NodePort 타입 Service**도 내부에서 `service DNS:80`로 정상 호출된다.
  - 즉 NodePort는 “내부 서비스 호출 방식”을 바꾸는 게 아니라, **노드 진입 경로를 추가**하는 옵션이라는 점을 확인한다.
3. **Ingress**를 붙여 “Ingress(L7 라우팅) → Service → Pod” 흐름을 내부에서 직접 호출해본다.
  - 이때 Ingress의 backend는 Service를 바라보며, **서비스가 ClusterIP여도 충분**하다는 점을 확인한다.

---

## 파일 4개(+ Ingress 1개)를 vim으로 생성하세요

아래 파일명은 예시이며, 이름은 바꿔도 됩니다.

- `01-namespace.yaml`
- `02-backend-deployment.yaml`
- `03-services.yaml`
- `04-ingress.yaml`
- `05-networkpolicy.yaml` *(선택: 클러스터가 NetworkPolicy를 지원할 때만 의미 있음)*

네임스페이스는 예시로 `lab-servicetype`를 사용합니다.

---

## `01-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: lab-servicetype
```

---

## `02-backend-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: lab-servicetype
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
          protocol: TCP
```

---

## `03-services.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-cip
  namespace: lab-servicetype
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: web-np
  namespace: lab-servicetype
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
    nodePort: 30081
```

---

## `04-ingress.yaml`

Ingress는 **Ingress Controller가 설치되어 있어야** 동작합니다.

이 매니페스트는 하나의 Ingress에서 path 기반으로 두 Service로 라우팅합니다.

- `/cip` → `web-cip:80` (ClusterIP 서비스)
- `/np`  → `web-np:80`  (NodePort 서비스)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: lab-servicetype
spec:
  rules:
  - host: lab.local
    http:
      paths:
      - path: /cip
        pathType: Prefix
        backend:
          service:
            name: web-cip
            port:
              number: 80
      - path: /np
        pathType: Prefix
        backend:
          service:
            name: web-np
            port:
              number: 80
```

---

## `05-networkpolicy.yaml` (선택)

아래 NetworkPolicy는 `app=web` Pod에 대해 **TCP 80만 허용**하는 최소 예시입니다.

> 참고: `nodeIP:nodePort` 경로를 “내부에서 항상 실패/성공”으로 단정하기는 어렵습니다(클러스터/CNI/헤어핀 NAT 설정에 따라 달라질 수 있음).
> 이 실습의 핵심은 Ingress가 backend Service를 바라본다는 점과, 내부 호출은 DNS:80로 이루어진다는 점입니다.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-http-80
  namespace: lab-servicetype
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 80
```

---

## 실행/정리

실행은 같은 폴더의 `LabSetUp.bash`를 사용하세요.

정리(삭제):

```bash
kubectl delete namespace lab-servicetype
```

