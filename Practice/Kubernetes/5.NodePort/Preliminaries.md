# NodePort: Preliminaries

이 실습은 **`relative` 네임스페이스**의 **Deployment `nodeport-deployment`**(nginx)에 **`containerPort`** 를 선언하고, **`type: NodePort`** 인 Service로 **`노드 IP + 고정 포트`** 에서도 접근할 수 있게 만드는 과정을 다룹니다. 아래는 **요청이 실제로 지나가는 순서**에 맞춰 개념을 이어서 설명합니다.

---

## Service란

**Service**는 **역할이 같은 Pod 여러 개**를 하나의 **안정적인 접근점**으로 묶는 쿠버네티스 API 객체입니다. Pod IP는 재시작·이동 때마다 바뀔 수 있지만, 클라이언트는 **고정된 Service 이름**이나 Service에 붙은 **가상 IP**로 계속 요청을 보낼 수 있습니다. Service는 **selector(라벨)** 로 “어떤 Pod가 내 백엔드인지” 정하고, 들어온 트래픽을 그 Pod들 사이로 나눕니다. 실제로 패킷을 어떻게 넘길지는 노드의 **kube-proxy**가 Service·Endpoints(또는 EndpointSlice) 정보를 보고 iptables/IPVS 등으로 맞춥니다.

> Pod만 있고 Service가 없으면, 클러스터 안에서 “이름으로 불리는 공통 진입점”이 없어 다른 워크로드와 맞추기 어렵습니다.

---

## ClusterIP와 NodePort

**ClusterIP**와 **NodePort**는 각각 **Service의 `spec.type`** 에 넣는 값입니다. Service라는 **한 종류의 API 객체** 안에서 “어떻게 노출할지”를 고르는 타입이지, ClusterIP·NodePort만의 별도 리소스 종류는 아닙니다. `type`을 생략하면 기본값은 **`ClusterIP`** 입니다.

- **ClusterIP**  
  Service를 만들면 클러스터는 그 Service에 **ClusterIP**라는 **가상 IP**를 붙입니다. **물리 NIC에 달린 주소가 아니라**, 클러스터 **내부**에서만 의미 있는 주소입니다. 클러스터 안의 클라이언트는 **DNS 이름** 또는 **이 가상 IP + Service의 `port`** 로 접속하고, kube-proxy가 **백엔드 Pod의 `targetPort`(보통 앱의 `containerPort`)** 로 넘깁니다.

- **NodePort**  
  **Service의 동작 방식(어떤 Pod로 보낼지)** 은 그대로 두고, **진입 경로만 하나 더 여는 설정**입니다. **`type: NodePort`** 로 두면, **모든(또는 정책상 해당하는) 노드의 같은 포트(`nodePort`)** 로도 요청이 들어올 수 있게 됩니다. 들어온 트래픽은 결국 **같은 Service의 ClusterIP:`port` 쪽 흐름**으로 합쳐져, 앞서 말한 것처럼 Pod로 전달됩니다. 그래서 **NodePort는 “노드 IP + 고정 포트”라는 추가 문**이고, **ClusterIP는 그 Service의 내부용 가상 주소**라고 보면 됩니다.

이제 위 개념을 바탕으로, **요청이 한 줄로 어떤 순서로 지나가는지**만 정리해 보겠습니다.

---

## 트래픽이 지나가는 순서

**클러스터 밖**에서 노드로 직접 붙는 경우(NodePort):

```text
클라이언트  →  노드IP:nodePort  →  (kube-proxy)  →  Service ClusterIP:port  →  Pod IP:targetPort(= containerPort)
```

**클러스터 안**의 Pod가 같은 Service로만 붙는 경우(`type: ClusterIP` 만 있어도 됨):

```text
클라이언트 Pod  →  DNS 이름 또는 ClusterIP:port  →  (kube-proxy)  →  Pod IP:targetPort(= containerPort)
```

앞줄에 **`nodePort`** 가 없습니다. **내부 통신에는 NodePort가 필수가 아닙니다.**

---

## 1단계: 노드에서 받기 — `type: NodePort`와 `nodePort`

클러스터 **밖**(또는 노드 네트워크 기준)에서 **노드의 실제 IP와 포트**로 들어오게 하려면 Service의 **`spec.type`** 을 **`NodePort`** 로 두고, **`spec.ports[].nodePort`** 로 노드 쪽 포트를 지정합니다(과제 예: **30080**). 들어온 트래픽은 kube-proxy가 **같은 Service의 ClusterIP:port 쪽**으로 이어 준 뒤, 뒤에서 설명하는 **`port` / `targetPort` / selector** 규칙을 그대로 탑니다.

- **`nodePort`** 는 **Service 매니페스트에만** 있습니다. Deployment·Pod·Ingress에는 이 필드가 없습니다. 별도 “NodePort” 리소스 종류도 없습니다.

#### (보강) `ClusterIP` 타입 vs `NodePort` 타입

둘 다 **같은 Service API**이고 **selector·targetPort·백엔드로 보내는 방식**은 같습니다. 차이는 **진입점**입니다.

| | **`type: ClusterIP`** | **`type: NodePort`** |
|---|----------------------|----------------------|
| **가상 IP(ClusterIP)** | 있음 | 있음(NodePort도 내부적으로 ClusterIP 유지) |
| **노드 IP + 고정 포트** | 없음(일반적으로 `노드IP:300xx`로 직접 붙기 어려움) | 있음(`nodePort`) |
| **용도** | 클러스터 **내부** 통신 | 내부 + **노드로의 외부 진입**(또는 Ingress/LB 경로의 일부) |

**비유:** ClusterIP만 있으면 **단지 안 내부 번호**로만 통하고, NodePort는 **입구(노드)에 공용 번호판**을 하나 더 두는 형태입니다.

#### (보강) `nodePort`를 비우면 vs 숫자를 적으면

- **비우면:** 제어 플레인이 **30000–32767** 등 허용 범위에서 **자동 할당**합니다. “노드 진입이 없다”는 뜻이 아니라 **번호를 내가 고르지 않은 것**입니다.
- **명시(예: 30080):** 문서·방화벽·`curl`에 **고정값**을 쓰기 쉽습니다.

**오해 방지:** `nodePort`의 역할은 **“이제야 ClusterIP:port로 내부에서 붙을 수 있게 된다”** 가 **아닙니다.** 내부 Pod → Service는 **`type: ClusterIP`만으로도** `서비스이름:port`로 됩니다. `nodePort`는 **노드 쪽 추가 진입점**입니다.

#### (보강) `LoadBalancer` 타입

클라우드 등에서 **외부 로드밸런서**를 붙일 때 쓰는 타입입니다. 이 문서에서는 다루지 않습니다.

---

## 2단계: Service가 트래픽을 모으고 Pod로 넘기기 — ClusterIP, `port`, `targetPort`, selector

**Service**는 라벨 **selector**로 고른 Pod들을 **하나의 안정적인 진입점**으로 묶습니다. Service를 만들면 **가상 IP(ClusterIP)** 가 붙습니다. **물리 NIC 주소가 아니라** 클러스터 안에서만 쓰는 **가상 주소**이며, kube-proxy가 **ClusterIP:`port` → 선택된 Pod IP:`targetPort`** 로 패킷을 넘깁니다(iptables/IPVS 등).

- **`spec.ports[].port`** — 클러스터 **내부**에서 이 Service로 붙을 때 쓰는 포트(서비스 “앞면”).
- **`spec.ports[].targetPort`** — 실제로 백엔드 Pod의 **어느 포트**로 보낼지. 보통 **컨테이너의 `containerPort`와 같은 숫자**이거나, 컨테이너 `ports[].name`(예: `http`)과 맞춥니다.

Pod IP는 자주 바뀌어도, 클라이언트는 **ClusterIP 또는 DNS 이름**으로 같은 Service를 계속 호출할 수 있습니다.

#### (보강) 이름·DNS(서비스 디스커버리)

**`metadata.name`** 이 클러스터 **내부 DNS**에 등록됩니다. 같은 네임스페이스에서는 `http://서비스이름:port` 처럼 쓰고, 여기서 **`port`** 는 **`spec.ports[].port`** 입니다. DNS가 이름을 **ClusterIP**로 풀어 주면, 이후 흐름은 위와 같이 kube-proxy가 Pod로 넘깁니다.

#### (보강) 내부에서 붙을 때 vs 밖에서 붙을 때

- **내부:** 위 DNS·`ClusterIP:port` 만으로 통신 가능. **`type: ClusterIP`만으로 충분**한 경우가 많습니다.
- **밖:** **ClusterIP는 보통 클러스터 밖에서 라우팅되지 않습니다.** 공개 DNS로 ClusterIP를 가리켜도 외부 클라이언트가 직접 붙기 어렵습니다. 그래서 **NodePort**, **LoadBalancer**, **Ingress** 등 **별도 진입 경로**를 둡니다.

#### (보강) 과제 문구 “individual pods를 NodePort로 노출”

Service가 selector로 고른 Pod들이 **엔드포인트**로 잡히고, NodePort(또는 ClusterIP:port)로 들어온 트래픽이 **그 Pod들**로 나뉘어 간다는 의미에 가깝습니다. Pod마다 **서로 다른** 노드 포트를 주는 것은 아닙니다.

---

## 3단계: 트래픽이 도착하는 곳 — Pod와 `containerPort`

컨테이너 프로세스는 Pod 네트워크 안에서 **특정 포트**로 리슨합니다. Deployment 매니페스트에서는 **`containers[].ports[].containerPort`**(와 선택적 **`name`**, **`protocol`**)로 그것을 **선언**합니다. 포트를 대신 열어 주는 것은 아니고, **앱이 실제로 그 포트에 바인드**해야 합니다.

과제에서 **`name: http`**, **80**, **TCP** 를 맞추면, Service의 **`targetPort: http`** 처럼 **이름으로 연결**하기 쉽습니다(솔루션은 `targetPort: 80`을 사용).

`kubectl patch`로 템플릿을 바꾸면 **롤링 업데이트**가 일어날 수 있습니다.

#### (보강) `containerPort` vs `nodePort`

| | **`containerPort`** (Deployment/Pod) | **`nodePort`** (Service, NodePort 타입) |
|---|--------------------------------------|----------------------------------------|
| **의미** | Pod **안**에서 앱이 리슨하는 포트 | **노드**에서 이 Service로 넘기기 위한 포트 |
| **외부 노출** | 이 필드만으로는 노출되지 않음 | 클러스터 밖에서 `노드IP:nodePort` 진입에 사용 |

#### (보강) `containerPort`는 꼭 매니페스트에 있어야 하나?

**`targetPort`를 숫자만** 쓰고 이미지가 그 포트에 바인드한다는 것을 알면 **없어도 동작하는 경우**가 있습니다. 다만 **문서화·이름 기반 targetPort·과제 요구**를 위해 두는 것이 일반적입니다.

---

## 매니페스트 필드 요약(한 표)

| 객체 | 필드 | 트래픽 흐름에서의 역할 |
|------|------|------------------------|
| Deployment | `containers[].ports[].containerPort` | **최종 수신** 포트(Pod 내부) |
| Deployment | `containers[].ports[].name` | `targetPort`에서 이름으로 참조 가능 |
| Service | `spec.selector` | 백엔드 Pod 고르기 |
| Service | `spec.ports[].port` | ClusterIP·내부 DNS·Ingress가 붙는 **서비스 포트** |
| Service | `spec.ports[].targetPort` | Pod 쪽 포트(숫자 또는 위 이름) |
| Service | `spec.type` / `spec.ports[].nodePort` | **NodePort:** 노드 진입 |
| Ingress | `backend.service` | **Service 이름 + Service `port`** 만 지정(Pod 직접 아님) |

---

## 통합 예시 YAML

실습은 **nginx:80** 기준이고, 아래는 **containerPort를 8080**으로 둔 **교육용** 예입니다(구조는 동일).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
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
          image: nginx:1.25
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
      nodePort: 30080
```

**이 예의 흐름:** `노드IP:30080` → kube-proxy → `ClusterIP:80` → Pod의 **8080**(`targetPort`가 이름 `http`로 연결).

실습용 Service만 따로 보면 다음과 같습니다(`relative`, `nodeport-deployment`).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodeport-service
  namespace: relative
spec:
  type: NodePort
  selector:
    app: nodeport-deployment
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
      nodePort: 30080
```

`selector`가 Pod 라벨과 맞지 않으면 Endpoints가 비어 **접속이 안 됩니다.**

#### (보강) Ingress — 또 다른 진입 경로

Ingress는 **Pod·`containerPort`를 직접 가리키지 않고**, **Service 이름 + Service의 `port`**(`spec.ports[].port`)만 지정합니다.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ing
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port:
                  number: 80
```

**흐름:** 인터넷 → Ingress Controller → **Service `web-svc:80`** → `targetPort` → **containerPort**. 사용자는 보통 Ingress **80/443** 만 쓰고, 뒤의 Service·NodePort는 숨겨집니다.

---

## 과제와 솔루션 흐름 정리

1. **Deployment 패치** — 컨테이너 이름이 **`nginx`** 인지 확인. `ports`에 `name: http`, `containerPort: 80`, `protocol: TCP`.
2. **Service 적용** — `type: NodePort`, `nodePort: 30080`, `port` / `targetPort` / `protocol` / `selector` 정합.
3. **검증** — `kubectl get svc`, `kubectl get endpoints` 후 **`curl http://<노드IP>:30080`** (환경별 노드 IP는 안내에 따름).

---

## 관련 kubectl 명령어

- **`kubectl get deployment,pods,svc -n relative`**
- **`kubectl patch deployment ... -n relative -p '...'`** — 이후 **`kubectl rollout status deployment/nodeport-deployment -n relative`**
- **`kubectl apply -f svc.yaml`**
- **`kubectl get svc nodeport-service -n relative -o wide`**
- **`kubectl get endpoints nodeport-service -n relative`**

---
