# Hands-on: emptyDir vs hostPath — 계산 캐시 응답 시간 비교

**CPU 집약 HTTP 앱**으로 emptyDir vs hostPath 캐시 동작을 비교합니다.

| 동작 | 이 데모 |
| --- | --- |
| 계산 결과 파일 캐시 | Python HTTP + `/cache` |
| 반복 요청으로 캐시 히트 확인 | `GET /compute?n=<반복횟수>` |
| Pod 삭제 후 캐시 소실 | Phase 1 (emptyDir) |
| hostPath로 캐시 유지 | Phase 2 (hostPath) |

**선행**: [`Preliminaries-Volume-StorageClass.md`](Preliminaries-Volume-StorageClass.md) **[6.1 hostPath·보안 취약성](Preliminaries-Volume-StorageClass.md#hostpath의-보안-취약성--노드-전체-노출)** 을 본 뒤 실행하세요.

**실행**: [`cache-demo.bash`](cache-demo.bash) 한 번으로 배포·요청·검증·정리까지 수행합니다. (매니페스트는 스크립트 heredoc)

---

## 목차

1. [목표](#1-목표)
2. [실행](#2-실행)
3. [스크립트가 하는 일](#3-스크립트가-하는-일)
4. [기대 결과](#4-기대-결과)
5. [환경·주의](#5-환경주의)
6. [다음 단계](#6-다음-단계)

---

## 1. 목표

| 단계 | Volume | Pod 삭제 후 캐시 |
| --- | --- | --- |
| Phase 1 | `emptyDir` | **소실** → 1회차 다시 느림 (`X-Cache-Hit: false`) |
| Phase 2 | `hostPath` (`DirectoryOrCreate`) | **유지** → 1회차도 빠름 (`X-Cache-Hit: true`) |

앱은 무거운 루프를 돌린 뒤 결과를 `/cache/<n>.json`에 저장합니다.  
응답 헤더 **`X-Cache-Hit`**, **`X-Elapsed-Sec`** 로 1·2회차 차이를 확인합니다.

| 헤더 | 의미 |
| --- | --- |
| `X-Cache-Hit: false` | 계산 후 파일 저장 (느림) |
| `X-Cache-Hit: true` | 캐시 파일 읽기 (빠름) |

스크립트는 각 단계마다 **`X-Cache-Hit` 값을 assert** 하며, 실패 시 종료 코드 1로 끝납니다.

---

## 2. 실행

```bash
cd Practice/Kubernetes/1.Persistent-Volume
chmod +x cache-demo.bash   # 최초 1회
./cache-demo.bash
```

성공 시 마지막에 `All assertions passed.` 가 출력됩니다. 별도 `kubectl exec`·`curl` 없이 **이 명령 하나**로 데모 전체를 확인할 수 있습니다.

### 환경 변수 (선택)

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `N` | `400000` | 루프 반복 횟수. 클수록 1회차가 더 느림 |
| `HOST_CACHE_PATH` | `/tmp/calc-cache-demo` | Phase 2 hostPath가 쓰는 **노드** 경로 |

```bash
N=500000 HOST_CACHE_PATH=/tmp/calc-cache-demo ./cache-demo.bash
```

1·2회차 차이가 작으면 `N`을 키우고, 너무 느리면 줄이세요.

---

## 3. 스크립트가 하는 일

### Phase 1: emptyDir

1. ConfigMap + Deployment(`emptyDir`) + Service 배포  
2. `port-forward` 후 동일 `n`으로 **2회** 요청 → 2회차 `X-Cache-Hit: true` assert  
3. Pod 삭제 → `/cache` 비움 확인  
4. 다시 1회 요청 → **`X-Cache-Hit: false`** assert

### Phase 2: hostPath

1. Deployment를 `hostPath`(`${HOST_CACHE_PATH}`)로 교체  
2. 이전 실행 잔여 파일 제거 후 2회 요청 → 2회차 히트 assert  
3. Pod 삭제  
4. 다시 1회 요청 → **`X-Cache-Hit: true`** assert (노드 디스크에 파일 유지)

### 종료

`trap`으로 Deployment·Service·ConfigMap 정리.

---

## 4. 기대 결과

| 호출 | emptyDir | hostPath |
| --- | --- | --- |
| 2회차 (같은 Pod) | `X-Cache-Hit: true` (빠름) | `X-Cache-Hit: true` (빠름) |
| Pod 삭제 후 1회차 | `false` (느림) | `true` (빠름, 노드 경로 유지) |

출력 예 (값은 환경마다 다름):

```text
--- emptyDir — 1회차 (캐시 미스, 느림) ---
HTTP/1.0 200 OK
X-Cache-Hit: false
X-Elapsed-Sec: 1.2345
OK: X-Cache-Hit=false

--- emptyDir — 2회차 (캐시 히트, 빠름) ---
HTTP/1.0 200 OK
X-Cache-Hit: true
X-Elapsed-Sec: 0.0012
OK: X-Cache-Hit=true
```

---

## 5. 환경·주의

- **Killercoda·minikube·kind**: `port-forward`만 있으면 됨 (LoadBalancer 불필요).
- **hostPath Phase 2**: Pod가 **같은 노드**에 다시 스케줄되어야 캐시가 남습니다. 단일 노드 실습에 적합합니다.
- **멀티 노드**: Pod가 다른 노드로 가면 hostPath 캐시는 보이지 않습니다 → [`Preliminaries-Volume-StorageClass.md`](Preliminaries-Volume-StorageClass.md) [6.1 “다른 노드에 Replica”](Preliminaries-Volume-StorageClass.md#pod가-죽고-다른-노드에-replica가-뜨면) 참고.
- Phase 2 시작 시 스크립트가 `/cache/*`를 비워 **1회차 캐시 미스**가 재현 가능하도록 합니다. (이전 데모의 hostPath 잔여 파일 방지)

---

## 6. 다음 단계

emptyDir·hostPath만으로는 **클러스터 공유·영구 스토리지**가 부족합니다.  
→ **PV/PVC** ([`Preliminaries.md`](Preliminaries.md)), **StorageClass** ([예비지식 6.2~](Preliminaries-Volume-StorageClass.md#62-외부-스토리지와-pv--pvc), [`2.Storage-Class/`](../2.Storage-Class/))
