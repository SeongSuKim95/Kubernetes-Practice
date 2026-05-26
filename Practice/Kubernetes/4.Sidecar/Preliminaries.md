# Sidecar 실습 예비지식 — `4.Sidecar/` (WordPress + busybox)

| 파일 | 역할 |
| --- | --- |
| `LabSetUp.bash` | Volume **없이** WordPress Deployment·Service 생성 |
| `Questions.bash` | Sidecar + 공유 Volume 과제 |
| `SolutionNotes.bash` | emptyDir + sidecar 패치 예시 |

**선행**: [Volume · Sidecar · PV · StorageClass 예비지식](../1.Persistent-Volume/Preliminaries-Volume-StorageClass.md) **1~4절** (writable layer, Volume API, emptyDir)

---

## 목차

1. [선행 개념 요약](#1-선행-개념-요약)
2. [Sidecar 패턴 — 컨테이너 간 Volume 공유](#2-sidecar-패턴--컨테이너-간-volume-공유)
3. [LabSetUp.bash — 초기 상태](#3-labsetupbash--초기-상태)
4. [Questions.bash — 과제](#4-questionsbash--과제)
5. [해결 구조 (SolutionNotes.bash)](#5-해결-구조-solutionnotesbash)
6. [적용·확인](#6-적용확인)
7. [흔한 실수](#7-흔한-실수)
8. [이후 실습과의 연결](#8-이후-실습과의-연결)

---

## 1. 선행 개념 요약

| 개념 | 핵심 |
| --- | --- |
| writable layer | Volume 없이 컨테이너 경로에만 쓰면 **컨테이너 재시작 시** 파일 소실 |
| Volume API | Pod `spec.volumes` + 각 컨테이너 `volumeMounts` |
| emptyDir | Pod가 노드에 붙어 있는 동안 유지, **Pod 삭제 시 제거** |

이 실습은 **emptyDir**을 “**한 Pod 안 두 컨테이너가 같은 디렉터리를 본다**”는 용도로 씁니다.

---

## 2. Sidecar 패턴 — 컨테이너 간 Volume 공유

### 한 Pod, 여러 컨테이너

쿠버네티스 Pod는 **하나 이상의 컨테이너**를 같은 네트워크·스토리지 컨텍스트로 묶습니다. 메인 컨테이너 옆 보조 역할 컨테이너를 **Sidecar(사이드카)** 라고 부릅니다.

| 역할 | 예 |
| --- | --- |
| 메인 | WordPress, API 서버, DB |
| Sidecar | 로그 `tail`, 프록시, 메트릭 수집, 설정 동기화 |

Sidecar는 **별도 이미지·별도 프로세스**이므로 **파일시스템이 기본적으로 분리**됩니다. 메인이 `/var/log/wordpress.log`에 쓰면, 그 내용은 메인 컨테이너 **writable layer** 안에만 있습니다. Sidecar에서 **같은 경로**를 열어도 **다른 파일**입니다.

**공유하려면** Pod `spec.volumes`에 **emptyDir**을 하나 두고, **두 컨테이너 모두** 같은 `name`으로 `volumeMounts` 해야 합니다.

```text
Pod
├── volumes: [ emptyDir "log" ]
├── container: wordpress  → mount /var/log  →  .../wordpress.log 쓰기
└── container: sidecar    → mount /var/log  →  tail -f .../wordpress.log 읽기
         ↑___________________ 같은 emptyDir ___________________↑
```

이 실습의 초점: **서로 다른 컨테이너가 같은 디렉터리·파일을 보게 만드는 설계**.

### 왜 Sidecar 실습에 emptyDir인가

| 요구 | emptyDir 적합 여부 |
| --- | --- |
| 같은 Pod 안에서 로그 파일 **공유** | ✅ |
| Pod 재시작 전까지 Sidecar가 `tail -f` 가능 | ✅ |
| Pod 삭제 후에도 로그 **영구 보존** | ❌ → hostPath / PV·PVC 필요 |

로그 **수집·전달**은 보통 “Pod가 살아 있는 동안”이면 되므로 emptyDir이 흔합니다. **장기 보관**은 PV·로그 스택 등으로 넘깁니다.

---

## 3. LabSetUp.bash — 초기 상태

```bash
./LabSetUp.bash
```

**Volume 없이** WordPress Deployment·Service만 `default` 네임스페이스에 생성합니다.

```yaml
# 초기: volumes / volumeMounts 없음
containers:
  - name: wordpress
    image: wordpress:php8.2-apache
    command: ["/bin/sh", "-c",
      "while true; do echo 'WordPress is running...' >> /var/log/wordpress.log; sleep 5; done"]
```

| 항목 | 상태 |
| --- | --- |
| Deployment `wordpress` | 메인 컨테이너 1개, `/var/log/wordpress.log`에 5초마다 append |
| Service `wordpress` | 80 포트 노출 |
| Sidecar | **없음** |
| 공유 Volume | **없음** → 과제에서 추가 |

---

## 4. Questions.bash — 과제

1. 기존 `wordpress` Deployment에 **sidecar** 컨테이너 추가  
   - 이름: `sidecar`  
   - 이미지: `busybox:stable`  
   - 명령: `"/bin/sh -c tail -f /var/log/wordpress.log"`
2. **`/var/log`에 마운트된 Volume**으로 메인·Sidecar가 **같은 로그 파일**을 보도록 구성

---

## 5. 해결 구조 (SolutionNotes.bash)

**핵심**: `volumes`에 **emptyDir** 하나, **두 컨테이너**가 같은 `name: log`로 `/var/log` 마운트.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
spec:
  template:
    spec:
      volumes:
        - name: log
          emptyDir: {}          # Pod 수명 동안 공유, Pod 삭제 시 제거
      containers:
        - name: wordpress
          volumeMounts:
            - name: log
              mountPath: /var/log
          # command는 LabSetUp과 동일 — /var/log/wordpress.log 에 기록
        - name: sidecar
          image: busybox:stable
          command: ["/bin/sh", "-c", "tail -f /var/log/wordpress.log"]
          volumeMounts:
            - name: log
              mountPath: /var/log   # wordpress와 동일 mountPath → 같은 파일
```

| 체크 | 설명 |
| --- | --- |
| `volumes[].name` ↔ `volumeMounts[].name` | Pod 안 Volume **별칭** 짝 맞추기 |
| 두 컨테이너 **같은** `name: log` | **한 emptyDir** 공유 |
| `mountPath: /var/log` | 컨테이너 안 경로 (둘 다 동일해야 함) |
| Sidecar만 추가하고 Volume 없음 | Sidecar의 `/var/log/wordpress.log` **없음** → tail 실패 |

---

## 6. 적용·확인

```bash
# LabSetUp.bash 실행 후
# SolutionNotes.bash 의 패치 적용 (또는 직접 편집 후 apply)

kubectl rollout status deployment wordpress
kubectl get pods -l app=wordpress
# READY 2/2 — wordpress + sidecar

# Sidecar 로그 스트림 확인
kubectl logs deployment/wordpress -c sidecar
# WordPress is running... 가 주기적으로 보이면 공유 성공

# 메인 컨테이너에서 파일 존재 확인
kubectl exec deploy/wordpress -c wordpress -- ls -l /var/log/wordpress.log
```

---

## 7. 흔한 실수

1. **Sidecar만 추가**하고 `volumes` / `volumeMounts` 누락  
2. **한쪽만** `volumeMounts` (wordpress만 또는 sidecar만)  
3. `mountPath` 불일치 (예: 메인 `/var/log`, Sidecar `/logs`)  
4. Volume `name` 오타 (`log` vs `logs`)  
5. emptyDir을 **영구 로그 저장**으로 오해 → Pod 재생성 시 로그 소실

---

## 8. 이후 실습과의 연결

| 순서 | 실습 | 내용 |
| --- | --- | --- |
| **4.Sidecar** (이 실습) | emptyDir + **Pod 내 공유** (휘발, 로그 tail) |
| **[cache-demo](../1.Persistent-Volume/cache-demo.md)** | emptyDir 캐시 소실 → hostPath 비교 ([예비지식 6.1](../1.Persistent-Volume/Preliminaries-Volume-StorageClass.md#61-hostpath--노드-디스크에-붙이기)) |
| **1.Persistent-Volume** | PV/PVC로 **Pod 밖** 영구 스토리지 |
| **2.Storage-Class** | StorageClass로 볼륨 **동적 생성** |

Sidecar로 “**왜 Volume API가 Pod 스펙에 있는지**”를 체감한 뒤, [`1.Persistent-Volume/cache-demo`](../1.Persistent-Volume/cache-demo.md)·PV 실습으로 “**왜 emptyDir만으로는 부족한지**”로 이어집니다.

---

## 참고 명령어

```bash
kubectl get pods -l app=wordpress
kubectl logs deployment/wordpress -c sidecar
kubectl logs deployment/wordpress -c wordpress
kubectl exec deploy/wordpress -c wordpress -- ls -l /var/log
kubectl delete deployment wordpress
kubectl delete service wordpress
```
