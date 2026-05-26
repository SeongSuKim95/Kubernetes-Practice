# Persistent Volume 실습 예비지식 — `1.Persistent-Volume/` (MariaDB + PV/PVC)

| 파일 | 역할 |
| --- | --- |
| `Preliminaries-Volume-StorageClass.md` | Volume·Sidecar·PV·StorageClass **공통 예비지식** |
| `cache-demo.bash` / `cache-demo.md` | emptyDir vs hostPath 캐시 비교 (PV Lab **선행** hands-on) |
| `LabSetUp.bash` | PV 생성 → PVC·Deployment로 데이터 적재 → Deployment·PVC 삭제 → PV `Retain`·재사용 준비 |
| `Questions.bash` | 기존 PV를 재사용해 PVC·Deployment 복구 |
| `SolutionNotes.bash` | PVC 생성 및 Deployment 적용 예시 |

**선행**: [Volume · Sidecar · PV · StorageClass 예비지식](Preliminaries-Volume-StorageClass.md) **6.1~6.2** (hostPath → PV/PVC). hostPath hands-on은 [`cache-demo.md`](cache-demo.md) (`./cache-demo.bash`).

---

## PV ↔ PVC 바인딩 흐름

Pod는 **PV 이름을 모릅니다.** `claimName`으로 **PVC만** 참조하고, 쿠버네티스가 PVC를 **조건에 맞는 PV 하나**와 1:1로 연결(Bound)합니다.

```text
[관리자]  PV 등록 (용량·accessMode·storageClassName·백엔드)
[개발자]  PVC 생성 (요청)
              ↓  바인딩 조건 일치
         PVC ──Bound──▶ PV ──▶ 실제 저장소 (이 Lab: hostPath)
              ↓
[Pod]     volumes.persistentVolumeClaim.claimName → PVC
          volumeMounts.mountPath → 컨테이너 경로 (/var/lib/mysql)
```

### 바인딩에 필요한 조건

| PVC | PV | 비고 |
| --- | --- | --- |
| `resources.requests.storage` | `capacity.storage` | 요청 ≤ PV 용량 |
| `accessModes` | `accessModes` | 교집합이 있어야 함 (Lab: **ReadWriteOnce**) |
| `storageClassName` (있으면) | `storageClassName` | **같아야** 바인딩 (Lab: PVC는 생략 → `standard` PV에 매칭) |

바인딩 후 MariaDB가 `/var/lib/mysql`에 쓰는 데이터는 PV 백엔드인 **노드의 `/mnt/data/mariadb`**(hostPath)에 남습니다.

---

## LabSetUp.bash가 하는 일

```bash
./LabSetUp.bash
```

### 1) 네임스페이스·PV

- `mariadb` 네임스페이스 생성
- PV `mariadb-pv` 생성

| PV 필드 | Lab 값 | 의미 |
| --- | --- | --- |
| `capacity.storage` | `250Mi` | 제공 용량 |
| `accessModes` | `ReadWriteOnce` | 한 노드·한 Pod read/write |
| `persistentVolumeReclaimPolicy` | `Retain` | PVC 삭제 후에도 PV·**데이터 유지** |
| `storageClassName` | `standard` | PVC와 이름 맞춰 바인딩 |
| `hostPath.path` | `/mnt/data/mariadb` | 실제 데이터가 쌓이는 **노드 로컬 경로** |

### 2) 초기 PVC·Deployment (데이터 시드)

- PVC `mariadb` (250Mi, RWO) → PV `mariadb-pv`와 **Bound**
- Deployment `mariadb` — `claimName: mariadb`, `/var/lib/mysql` 마운트
- MariaDB 기동 대기 → **한 번 DB 데이터가 PV에 기록**됨

### 3) “실수로 삭제” 시뮬레이션

```bash
kubectl delete deployment mariadb -n mariadb
kubectl delete pvc mariadb -n mariadb
```

- Deployment·Pod·PVC는 사라짐
- PV는 `Retain` → **Released** 상태로 남고, hostPath 데이터는 노드에 유지
- PV `spec.claimRef`가 남으면 재바인딩이 막히므로, 스크립트가 **claimRef 제거**로 PV를 재사용 가능하게 만듦

### 4) 과제용 Deployment 템플릿

`~/mariadb-deploy.yaml`을 다시 쓰되 **`claimName: ""`** 로 비워 둠 → 학습자가 PVC 이름을 채워 적용

**LabSetUp 종료 시 상태**

| 리소스 | 상태 |
| --- | --- |
| PV `mariadb-pv` | Available (또는 claimRef 제거 후 재사용 가능) |
| PVC `mariadb` | **없음** |
| Deployment `mariadb` | **없음** |
| `~/mariadb-deploy.yaml` | 존재, `claimName` 비어 있음 |
| 노드 `/mnt/data/mariadb` | **이전 DB 데이터 유지** |

---

## Questions.bash — 해야 할 일

1. **PVC `mariadb`** 를 `mariadb` 네임스페이스에 생성  
   - Access Mode: `ReadWriteOnce`  
   - Storage: `250Mi`  
   - (`storageClassName` 생략 — PV `standard`와 매칭)
2. **`~/mariadb-deploy.yaml`** 에 `claimName: mariadb` 설정 후 apply
3. Deployment가 **Running·Stable** 인지 확인

목표: **새 PVC가 기존 PV에 다시 바인딩**되어, Pod 재기동 후에도 **이전 MariaDB 데이터가 그대로** 보이는 것.

---

## 확인 명령

```bash
kubectl get pv mariadb-pv
# STATUS: Bound, CLAIM: mariadb/mariadb

kubectl get pvc mariadb -n mariadb
# STATUS: Bound, VOLUME: mariadb-pv

kubectl get pods -n mariadb
kubectl get deploy mariadb -n mariadb
```

---

## 이 Lab에서만 기억할 점

- **PV 실체는 Pod가 아님** — hostPath로 묶인 **노드 디스크 경로**가 데이터가 남는 곳.
- **`Retain`** — PVC를 지워도 PV·데이터는 남음. 재사용 전 `claimRef` 정리가 필요할 수 있음.
- **hostPath 한계** — Pod가 **다른 노드**로 가면 같은 경로 데이터를 못 봄. (개념·EBS 예시는 [예비지식 6.2](Preliminaries-Volume-StorageClass.md#62-외부-스토리지와-pv--pvc) 참고)
