# Basic Practice: Preliminaries — Probe (Liveness / Readiness)

`0.Basic-Practice` 는 Namespace·Pod·Deployment·Service·DNS를 다룹니다.
이 문서는 Deployment를 이해할 때 함께 알아야 할 **Probe(프로브)** 개념을 보강합니다.
(Introduction의 Liveness/Readiness 용어와 연결됩니다.)

| 파일 | 역할 |
| --- | --- |
| `LabSetUp.bash` | `dev`/`prod` 환경 구성 |
| `Questions.bash` | Pod vs Deployment, Service/Endpoints, DNS 과제 |
| `SolutionNotes.bash` | 풀이·검증 명령 |
| `kubectl-commands.md` | 이 실습에서 쓰는 `kubectl` 요약 |

---

## Probe란?

**Probe** 는 kubelet이 **컨테이너가 살아 있는지 / 트래픽을 받을 준비가 됐는지**를 주기적으로 확인하는 검사입니다.

| Probe | 질문 | 실패 시 |
|-------|------|---------|
| **livenessProbe** | “이 컨테이너가 **살아 있나**?” | 컨테이너 **재시작** (죽은 프로세스 복구) |
| **readinessProbe** | “지금 **요청을 받아도 되나**?” | Pod를 Service Endpoints에서 **제외** (재시작하지 않음) |
| **startupProbe** (선택) | “기동이 **끝났나**?” | 기동 중에는 liveness를 보류. 오래 뜨는 앱용 |

```text
kubelet
  ├─ startupProbe  (기동 완료까지)
  ├─ livenessProbe → 실패면 restart
  └─ readinessProbe → 실패면 Endpoints에서 제외 (트래픽 차단)
```

> **핵심:** Liveness 실패 = **프로세스 복구**, Readiness 실패 = **트래픽만 끊기**.  
> 둘을 섞어 쓰면 안 됩니다. “아직 워밍업 중”인데 liveness로 재시작하면 영원히 재시작 루프에 빠질 수 있습니다.

---

## 왜 Deployment 실습에서 Probe가 중요한가?

`0.Basic-Practice`에서 Service는 **Ready인 Pod만** Endpoints에 올립니다.

```text
Deployment → Pod
              ├─ Ready=True  → Service Endpoints에 포함 → curl 성공
              └─ Ready=False → Endpoints에서 제외      → 트래픽 안 감
```

Probe가 없어도 컨테이너가 시작되면 곧 Ready가 됩니다.
하지만 앱이 “포트는 열렸는데 DB 연결은 아직”인 경우, readiness가 없으면 **준비 안 된 Pod로도 요청이 갑니다.**

---

## Probe 종류 (검사 방식)

| 방식 | 필드 | 용도 |
|------|------|------|
| **httpGet** | `path`, `port` | HTTP 200~399면 성공 (웹앱) |
| **tcpSocket** | `port` | 포트가 열리면 성공 |
| **exec** | `command` | 컨테이너 안 명령 exit 0이면 성공 |

```yaml
# Deployment Pod template 안 (spec.template.spec.containers[].…)
livenessProbe:
  httpGet:
    path: /healthz
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 3
```

| 필드 | 의미 |
|------|------|
| `initialDelaySeconds` | 첫 검사까지 대기 |
| `periodSeconds` | 검사 주기 |
| `timeoutSeconds` | 한 번 검사 타임아웃 |
| `failureThreshold` | 연속 실패 N회 후 판정 |
| `successThreshold` | 연속 성공 N회 후 성공 (readiness에서 자주 사용) |

---

## Ready와 Service의 관계 (이 Lab과 직결)

```bash
# Pod Ready 조건
kubectl get pods -n dev -o wide
# READY 1/1 → Ready

# Service가 가리키는 대상
kubectl get endpoints -n dev hello-svc
# Ready가 아닌 Pod IP는 여기 안 나옴
```

진단 순서 (`get → describe → events`):

```bash
kubectl get pod -n dev -l app=hello-nginx
kubectl describe pod -n dev -l app=hello-nginx
# Events / Conditions: Ready=False, Liveness/Readiness probe failed …
kubectl logs -n dev -l app=hello-nginx --tail=50
```

| 증상 | 먼저 볼 곳 |
|------|------------|
| Service curl 타임아웃, Endpoints 비어 있음 | Pod `Ready`, readinessProbe, selector |
| Pod가 CrashLoopBackOff | livenessProbe가 너무 빡센지, 앱 기동 실패인지 |
| 재시작만 반복 | liveness를 readiness 용도로 쓴 경우 |

---

## 최소 예시 — nginx에 Probe 붙이기

이 실습의 nginx에 붙일 수 있는 최소 형태입니다. (과제 필수 아님, 개념 보강용)

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 2
      periodSeconds: 5
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 10
```

확인:

```bash
kubectl describe pod -n dev -l app=hello-nginx | grep -A5 -i 'Liveness\|Readiness\|Ready'
```

---

## 이후 실습과의 연결

| 실습 | Probe와의 관계 |
|------|----------------|
| **0.Basic-Practice** (여기) | Ready ↔ Service Endpoints |
| **8.HPA** | 스케일 아웃된 Pod도 Ready여야 트래픽·메트릭에 포함 |
| **6.Ingress / 13.Gateway-API** | 백엔드 Service Endpoints = Ready Pod만 |

한 줄 요약:

```text
liveness = 살았나? (실패 → 재시작)
readiness = 받을 준비됐나? (실패 → Endpoints 제외, 트래픽만 차단)
Service는 Ready Pod에만 요청을 보낸다.
```
