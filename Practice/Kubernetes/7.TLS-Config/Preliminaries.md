# TLS Config: Preliminaries — ConfigMap · Secret · TLS

`Questions.bash` / `SolutionNotes.bash` 를 풀 때 필요한 개념을 정리합니다.
이 Lab은 **ConfigMap으로 TLS 프로토콜을 제한**하고, **Secret으로 인증서를 제공**한 뒤 HTTPS를 검증합니다.

| 파일 | 역할 |
| --- | --- |
| `LabSetUp.bash` | nginx + ConfigMap(TLS 버전) + TLS Secret + Service 환경 구성 |
| `Questions.bash` | ConfigMap을 TLSv1.3만 허용하도록 수정 · hosts · curl 검증 |
| `SolutionNotes.bash` | 설정 변경·검증 풀이 |

**선행:** [4.Sidecar ConfigMap/Secret 보강](../4.Sidecar/Preliminaries.md#3-보강--configmap과-secret으로-설정-주입) · [6.Ingress](../6.Ingress/)

---

## 1. ConfigMap vs Secret (이 Lab에서의 역할)

| | **ConfigMap** | **Secret** |
|--|---------------|------------|
| 이 Lab에서의 역할 | nginx가 허용할 **TLS 프로토콜 목록** (설정) | **서버 인증서·개인키** (`tls.crt`, `tls.key`) |
| 민감도 | 낮음 (프로토콜 정책) | 높음 (개인키) |
| Pod 연결 | Volume 마운트 또는 env | Volume 마운트 (TLS는 보통 파일) |
| API type | `ConfigMap` | `Secret` (`Opaque` 또는 `kubernetes.io/tls`) |

```text
Client (curl --tlsv1.3 / --tls-max 1.2)
  → Service (nginx-service)
  → Pod
       ├─ ConfigMap  → nginx TLS 설정 (어느 프로토콜 허용?)
       └─ Secret     → 인증서/키 (HTTPS 핸드셰이크)
```

> 4.Sidecar에서 “설정을 Volume으로 주입한다”를 봤다면, 이 Lab은 그 패턴을 **TLS 프로토콜(ConfigMap) + 인증서(Secret)** 에 적용한 것입니다.

---

## 2. ConfigMap — TLS 프로토콜 정책

ConfigMap은 **키가 아닌 설정**을 담습니다. 이 Lab에서는 nginx가 참조하는 TLS 버전 허용 목록이 ConfigMap에 있습니다.

과제:

```text
초기: TLSv1.2 + TLSv1.3 허용
목표: TLSv1.3 만 허용
```

검증:

```bash
curl -vk --tls-max 1.2 https://ckaquestion.k8s.local   # 실패해야 함
curl -vk --tlsv1.3   https://ckaquestion.k8s.local   # 성공해야 함
```

ConfigMap을 수정한 뒤 nginx가 설정을 **다시 읽는지**(재시작/reload) 확인하세요.  
마운트된 ConfigMap 파일은 kubelet이 주기적으로 갱신하지만, 프로세스가 파일을 다시 안 읽으면 반영이 안 된 것처럼 보일 수 있습니다.

```bash
kubectl -n nginx-static get configmap
kubectl -n nginx-static describe configmap
kubectl -n nginx-static edit configmap <name>   # 또는 apply로 패치
```

---

## 3. Secret — TLS 인증서

### `kubernetes.io/tls` 타입

HTTPS 서버용 Secret은 보통 다음 키를 가집니다.

| Secret 키 | 내용 |
|-----------|------|
| `tls.crt` | 서버 인증서 (PEM) |
| `tls.key` | 개인키 (PEM) |

```bash
kubectl create secret tls web-tls \
  --cert=tls.crt --key=tls.key \
  -n nginx-static
```

YAML:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: web-tls
  namespace: nginx-static
type: kubernetes.io/tls
data:
  tls.crt: <base64>
  tls.key: <base64>
```

### Pod에 마운트

```yaml
volumes:
- name: tls
  secret:
    secretName: web-tls
containers:
- name: nginx
  volumeMounts:
  - name: tls
    mountPath: /etc/nginx/ssl
    readOnly: true
```

Ingress/Gateway의 `tls.secretName` / `certificateRefs`도 **같은 TLS Secret**을 가리킵니다. (6·13번 Lab)

---

## 4. TLS 검증에 쓰는 curl

| 명령 | 의미 |
|------|------|
| `curl -vk https://…` | 인증서 검증 완화(`-k`) + 상세(`-v`) |
| `--tls-max 1.2` | 클라이언트가 TLS 1.2 이하만 시도 |
| `--tlsv1.3` | TLS 1.3으로 시도 |
| `/etc/hosts`에 Service IP + 이름 | 로컬에서 `ckaquestion.k8s.local`로 접근 |

```bash
# Service ClusterIP를 hosts에 등록 (과제)
kubectl -n nginx-static get svc nginx-service -o wide
# /etc/hosts 예: 10.96.x.x ckaquestion.k8s.local
```

| 결과 | 해석 |
|------|------|
| `--tls-max 1.2` 실패 | ConfigMap이 1.2를 막음 → **의도된 성공** |
| `--tlsv1.3` 성공 | 1.3 허용 + Secret 인증서 정상 |
| 둘 다 실패 | Secret/Service/hosts/방화벽 문제 가능 |

---

## 5. 자주 헷갈리는 점

| 질문 | 답 |
|------|-----|
| ConfigMap만 고치면 끝? | nginx가 설정을 **재로드/재시작**해야 할 수 있음 |
| Secret은 암호화되나? | 기본은 base64. etcd encryption은 별도 |
| Ingress TLS Secret과 이 Lab Secret | 같은 **타입·키 이름** 관례. 어디에 붙이느냐(Pod vs Ingress)만 다름 |
| ConfigMap에 키를 넣어도 되나? | 가능하지만 **비권장**. 키·비밀번호는 Secret |

---

## 6. 과제와의 대응

| 과제 | 할 일 |
|------|--------|
| ConfigMap → TLS 1.3만 | 허용 프로토콜에서 1.2 제거·반영 |
| hosts | Service IP → `ckaquestion.k8s.local` |
| 검증 | 1.2 실패 / 1.3 성공 |

한 줄 요약:

```text
ConfigMap = TLS “정책”(어느 버전 허용)
Secret    = TLS “재료”(인증서·키)
이 Lab = 정책을 1.3만 남기고, curl로 핸드셰이크를 검증한다
```
