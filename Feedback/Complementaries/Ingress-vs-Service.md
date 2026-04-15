## Ingress와 Service의 관계

### 1) 한 문장 요약
- **Ingress**: “HTTP/HTTPS 요청을 어떤 **Service**로 보낼지”를 정하는 **L7 라우팅 규칙**
- **Service**: “어떤 **Pod 집합**으로 보낼지”를 정하는 **안정적인 엔드포인트(이름/ClusterIP) + 로드밸런싱**

즉, **Ingress는 Service로 라우팅**하고, **Service는 Pod로 로드밸런싱**합니다.

---

### 2) Ingress는 Pod를 직접 가리키지 않는다
Ingress의 backend는 항상 아래 조합을 가리킵니다.

- **Service 이름**
- **Service port** (`spec.ports[].port`)

Pod IP나 `containerPort`를 Ingress에 직접 적지 않습니다.

---

### 3) 실제 트래픽 흐름(외우기)

```text
Client
  → Ingress Controller (실행체)
  → Ingress 규칙(host/path 매칭)
  → Service (ClusterIP:port)
  → Pod (PodIP:targetPort)
```

여기서 “Ingress Controller”는 Ingress 리소스를 watch해서 실제 프록시/라우팅을 수행하는 컴포넌트입니다.

---

### 4) Ingress vs Ingress Controller (자주 하는 오해)
- **Ingress**: Kubernetes API에 저장되는 “규칙(설정)” 리소스
- **Ingress Controller**: 그 규칙을 보고 실제 트래픽을 처리하는 “프로그램(파드)”

Ingress 리소스만 만들면 자동으로 트래픽이 흐르는 것이 아니라, **Ingress Controller가 설치되어 있어야** 동작합니다.

---

### 5) Service type과 Ingress의 관계(핵심)
Ingress가 backend로 호출하는 Service는 보통 **`type: ClusterIP`면 충분**합니다.

- 이유: Ingress Controller가 이미 “진입점” 역할을 하고, 그 뒤는 클러스터 내부 통신(ClusterIP)으로 이어지기 때문

그래서 흔한 실무 패턴은 다음과 같습니다.

- **Ingress Controller 앞단 Service만** `LoadBalancer`(클라우드) 또는 `NodePort`(온프렘/특수)로 외부 노출
- **각 애플리케이션 Service는** `ClusterIP`로 유지

---

### 6) Ingress 매니페스트 예시 (Host + Path 라우팅)
아래 예시는 `web.example.com`으로 들어온 요청을 path에 따라 서로 다른 Service로 라우팅합니다.

- `/api` → `api-svc:80`
- `/` → `web-svc:80`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: web.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

> 포인트: Ingress backend는 Pod가 아니라 **Service 이름 + Service port(number)** 를 가리킵니다.

---

### 7) “Ingress 뒤에 NodePort Service를 두면 더 좋은가?”
대부분의 경우 **아니요(불필요)** 입니다.

- Ingress는 어차피 Service로만 붙고, 클러스터 내부에서는 `ClusterIP:port`면 충분합니다.
- backend Service를 NodePort로 바꿔도 Ingress의 라우팅 품질이 좋아지지 않습니다.
- 오히려 NodePort는 “노드에 포트 노출”이라는 운영 부담(보안/방화벽/포트 관리)을 늘릴 수 있습니다.

**정리**: Ingress를 쓰는 순간, 앱의 Service는 대개 ClusterIP로 두는 게 가장 단순합니다.

