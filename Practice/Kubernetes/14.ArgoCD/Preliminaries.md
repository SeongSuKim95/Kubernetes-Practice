# Argo CD 예비지식 — `14.ArgoCD/` · LoadTestLab 연계

| 파일 | 역할 |
| --- | --- |
| `LabSetUp.bash` | Killercoda 등 사전 준비된 클러스터에서 실습 |
| `Questions.bash` | Helm으로 Argo CD 설치 (CRD 제외 옵션) |
| `SolutionNotes.bash` | Helm template + namespace 생성 예시 |

**LoadTestLab에서의 Argo CD:** [AWS/LoadTestLab/argocd/](../../../AWS/LoadTestLab/argocd/) — EKS 위 GitOps로 `app-manifests/`를 `loadtest` 네임스페이스에 배포

**관련 문서:** [LoadTestLab LAB-GUIDE](../../../AWS/LoadTestLab/LAB-GUIDE.md) · [test-guide](../../../AWS/LoadTestLab/test-guide.md) · [architecture](../../../AWS/LoadTestLab/architecture.md)

---

## 목차

1. [Argo CD란 무엇인가](#1-argo-cd란-무엇인가)
2. [GitOps — Argo CD가 지키는 원칙](#2-gitops--argo-cd가-지키는-원칙)
3. [핵심 개념 한눈에](#3-핵심-개념-한눈에)
4. [Argo CD 내부 구성요소 — 클러스터 안 Pod](#4-argo-cd-내부-구성요소--클러스터-안-pod)
5. [Application CR — 가장 중요한 리소스](#5-application-cr--가장-중요한-리소스)
6. [동기화(Sync)와 상태](#6-동기화sync와-상태)
7. [kubectl apply vs Argo CD](#7-kubectl-apply-vs-argo-cd)
8. [LoadTestLab에서의 Argo CD](#8-loadtestlab에서의-argo-cd)
9. [UI·CLI로 확인하기](#9-uicli로-확인하기)
10. [흔한 실수와 주의점](#10-흔한-실수와-주의점)
11. [이 실습·LoadTestLab과의 연결](#11-이-실습loadtestlab과의-연결)

---

## 1. Argo CD란 무엇인가

**Argo CD**는 Kubernetes용 **선언적 GitOps continuous delivery** 도구입니다.

| 역할 | 설명 |
| --- | --- |
| **Git을 단일 진실 공급원(Single Source of Truth)** | Deployment, Service, Ingress 등 **원하는 상태**를 Git 저장소의 YAML에 둡니다 |
| **클러스터와 Git을 지속 비교** | 클러스터에 **실제로 떠 있는 상태(live state)** 와 Git의 **원하는 상태(desired state)** 를 비교합니다 |
| **차이를 감지·반영** | 차이가 있으면 **Sync**로 Git 내용을 클러스터에 적용하거나, 설정에 따라 **자동 복구(selfHeal)** 합니다 |

한 줄로: **“Git에 적힌 매니페스트대로 클러스터를 맞춰 두는 컨트롤러 + UI”** 입니다.

> **Argo CD는 클러스터 밖 별도 서버가 아니라, Kubernetes 클러스터 *안*에 Pod로 떠 있는 애플리케이션입니다.**  
> `install-argocd.sh` 또는 Helm으로 설치하면 `argocd` 네임스페이스에 Deployment·StatefulSet 등이 생성되고, 각 컴포넌트(server, repo-server, application-controller 등)가 **일반 Pod**처럼 스케줄됩니다. Argo CD Pod들이 Kubernetes API를 호출해 `loadtest` 같은 **다른 네임스페이스**에 Deployment·Ingress 등을 sync합니다.

LoadTestLab에서는 부하 테스트 중 `deployment.yaml`·`hpa.yaml`을 수정 → `git push` → Argo CD가 EKS에 반영하는 **실습 루프**의 중심입니다.

---

## 2. GitOps — Argo CD가 지키는 원칙

**GitOps**는 운영·배포를 **Git 저장소의 선언적 설정**으로 관리하는 방식입니다.

```text
운영자 / CI
    │  git commit & push (매니페스트 변경)
    ▼
Git 저장소  ◄───────  Argo CD (주기적 fetch + diff)
    │                      │
    │  desired state       │  sync / selfHeal
    ▼                      ▼
              Kubernetes 클러스터 (live state)
```

| 원칙 | Argo CD에서의 의미 |
| --- | --- |
| **선언적(Declarative)** | `kubectl run` 같은 명령이 아니라 YAML/Helm/Kustomize로 “어떻게 있어야 하는지” 기술 |
| **Git이 SSOT** | 클러스터를 직접 `kubectl edit`하기보다 Git을 먼저 수정 |
| **자동화·감사** | 커밋 이력 = 배포 이력, PR 리뷰 가능 |
| **드리프트 감지** | 누군가 `kubectl patch`로 바꿔도 Git과 다르면 **OutOfSync**로 표시 |

---

## 3. 핵심 개념 한눈에

| 용어 | 의미 |
| --- | --- |
| **Application** | “이 Git 경로 → 이 클러스터/네임스페이스”를 묶는 **Argo CD CR** |
| **Source** | Git URL, branch/tag(`targetRevision`), path, Helm/Kustomize 설정 |
| **Destination** | 배포 대상 클러스터 API 주소 + **namespace** |
| **Sync** | Git desired state → 클러스터에 `kubectl apply`에 해당하는 반영 |
| **Health** | Pod/Deployment 등 **리소스가 정상 동작하는지** (Running, Progressing 등) |
| **Sync Status** | Git과 live state **일치 여부** (Synced / OutOfSync) |
| **Project** | Application 묶음 + **허용 repo/클러스터/리소스** 정책 (멀티팀·운영 격리) |
| **Prune** | Git에서 **삭제된** 리소스를 클러스터에서도 삭제 |
| **SelfHeal** | Git과 다른 **수동 변경**을 되돌려 Git 상태로 맞춤 |
| **Revision** | Application이 마지막으로 sync한 **Git commit SHA** |

**Health vs Sync Status** (헷갈리기 쉬움):

| | Sync Status | Health |
| --- | --- | --- |
| 질문 | Git과 클러스터 **내용이 같은가?** | 워크로드가 **정상 기동 중인가?** |
| 예 | OutOfSync — replicas를 Git과 다르게 patch함 | Degraded — Pod CrashLoopBackOff |
| 예 | Synced — Git과 일치 | Healthy — Deployment rollout 완료 |

---

## 4. Argo CD 내부 구성요소 — 클러스터 안 Pod

### Argo CD는 Pod로 클러스터 내부에 설치된다

Argo CD는 **in-cluster** 방식으로 동작합니다. 즉, **관리 대상과 같은 Kubernetes 클러스터**(또는 별도 관리 클러스터) **안에** 컨트롤러 Pod들이 올라갑니다.

| 구분 | 설명 |
| --- | --- |
| **설치 위치** | `argocd` **네임스페이스** (LoadTestLab: EKS private 워커 노드 위) |
| **실행 형태** | `argocd-server`, `argocd-repo-server`, `argocd-application-controller` 등 **Deployment / StatefulSet → Pod** |
| **배포 대상과의 관계** | Argo CD Pod(`argocd` NS) ≠ 앱 Pod(`loadtest` NS). **같은 클러스터, 다른 namespace** |
| **클러스터 밖인 것** | GitHub(Git), 운영자 PC(`kubectl`), LoadTest EC2(k6) — Argo CD **본체는 아님** |

```text
EKS 클러스터 (LoadTestLab)
├── namespace: argocd
│   ├── Pod argocd-server-xxx          ← Argo CD (UI/API)
│   ├── Pod argocd-repo-server-xxx     ← Git clone / manifest 렌더
│   ├── Pod argocd-application-controller-xxx  ← sync·health
│   └── ...
├── namespace: loadtest
│   └── Pod echo-cpu-xxx               ← Argo CD가 Git에서 sync한 앱
├── namespace: monitoring
│   └── Pod grafana-xxx                ← Argo CD와 무관 (별도 install)
└── ...
         ▲
         │ Kubernetes API (in-cluster)
         │
    argocd-application-controller 가 loadtest NS 리소스 create/update
```

LoadTestLab EKS는 **private**이므로 Argo CD UI도 클러스터 **내부 Service**(ClusterIP)로만 노출됩니다. 운영자는 **`kubectl port-forward`** 로 로컬 브라우저에서 접속합니다 — Argo CD가 클러스터 밖에 있다는 뜻이 **아닙니다**.

```bash
# Argo CD가 Pod로 떠 있는지 확인
kubectl -n argocd get pods
kubectl -n argocd get deploy,statefulset,svc
```

### 컴포넌트별 역할

Argo CD는 보통 `argocd` 네임스페이스에 설치됩니다. LoadTestLab은 `install-argocd.sh`로 upstream manifest를 적용합니다.

| 컴포넌트 | K8s 리소스 (일반적) | 역할 |
| --- | --- | --- |
| **argocd-server** | Deployment → Pod | API + **Web UI** + CLI(`argocd`) 진입점 |
| **argocd-repo-server** | Deployment → Pod | Git clone, Helm template, Kustomize build — **manifest 렌더링** |
| **argocd-application-controller** | StatefulSet → Pod | Application CR watch, **diff·sync·health** 판정 |
| **argocd-redis** | Deployment 또는 StatefulSet → Pod | 캐시 (성능) |
| **argocd-dex** (선택) | Deployment → Pod | SSO 연동 |

```text
                    ┌─────────────────┐
  운영자 ──────────►│ argocd-server   │◄── Web UI / CLI
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
  application-controller  repo-server        redis
         │                   │
         │                   │ git fetch / helm / kustomize
         │                   ▼
         │              Git 저장소
         │
         ▼
  Kubernetes API (대상 클러스터)
```

**Application CR** 하나가 “어떤 Git → 어디에 sync할지”를 정의하고, **application-controller**가 그 정의를 실행합니다.

---

## 5. Application CR — 가장 중요한 리소스

Argo CD에서 실무·실습 모두 **Application** 리소스가 핵심입니다.

LoadTestLab 예시 (`AWS/LoadTestLab/argocd/application.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loadtest-app
  namespace: argocd          # Application CR 자체는 argocd NS에 둠
spec:
  project: default
  source:
    repoURL: https://github.com/SeongSuKim95/Kubernetes-Practice.git
    targetRevision: main
    path: AWS/LoadTestLab/app-manifests
  destination:
    server: https://kubernetes.default.svc   # in-cluster
    namespace: loadtest                      # 배포 대상 NS
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

| 필드 | LoadTestLab에서의 의미 |
| --- | --- |
| `source.repoURL` + `path` | Git의 `app-manifests/` 디렉터리가 **배포 정의** |
| `source.targetRevision` | `main` 브랜치 HEAD를 추적 |
| `destination.namespace` | Deployment·Service·Ingress 등이 **`loadtest`** 에 생성 |
| `syncPolicy.automated` | push 후 **자동 sync** (수동 Sync 버튼 불필요) |
| `prune: true` | Git에서 파일 삭제 시 클러스터 리소스도 삭제 |
| `selfHeal: true` | `kubectl edit` 등 수동 drift → Git으로 **되돌림** |
| `CreateNamespace=true` | `loadtest` NS가 없으면 생성 |

`app-manifests/` 안에는 일반 Kubernetes 매니페스트만 있습니다 (Deployment, HPA, Ingress 등). **Application은 Argo CD 전용 CR**이고, **sync 대상**은 평범한 K8s YAML입니다.

---

## 6. 동기화(Sync)와 상태

### Sync가 하는 일

1. Git에서 `path` 아래 manifest를 가져옴 (repo-server)
2. 클러스터 live state와 **diff**
3. 차이를 apply (create / update / delete)
4. 각 리소스 **Health** 재계산

### Sync 정책 옵션 (자주 쓰는 것)

| 옵션 | 동작 |
| --- | --- |
| **Manual sync** | UI/CLI에서 Sync 클릭 시에만 반영 |
| **Automated sync** | Git 변경 감지 시 자동 반영 |
| **prune** | Git에 없는 리소스 **삭제** (주의: 실수로 YAML 지우면 클러스터에서도 삭제) |
| **selfHeal** | 클러스터 수동 변경을 Git으로 **복구** |
| **CreateNamespace** | destination namespace 자동 생성 |

### UI 리소스 트리에서 보이는 것

LoadTestLab `loadtest-app`을 펼치면 대략:

```text
loadtest-app (Application)
├── Namespace loadtest
├── ConfigMap fluentd-config
├── Service echo-cpu / echo-cpu-metrics
├── Deployment echo-cpu
│   └── ReplicaSet → Pod (app + fluentd)
├── HorizontalPodAutoscaler echo-cpu
├── Ingress echo-cpu
└── ServiceMonitor echo-cpu-fluentd
```

- **Deployment 아래 ReplicaSet**은 Kubernetes가 rollout마다 만드는 **정상 하위 리소스**입니다.
- Pod 0개인 **옛 ReplicaSet**은 Deployment `revisionHistoryLimit`으로 정리합니다 (LoadTestLab `deployment.yaml` 참고).

---

## 7. kubectl apply vs Argo CD

| | `kubectl apply` | Argo CD |
| --- | --- | --- |
| **진실 공급원** | 로컬 YAML / CI 스크립트 | **Git** |
| **지속 감시** | 없음 (한 번 apply하고 끝) | 주기적 diff + automated sync |
| **드리프트** | 수동 변경이 남음 | OutOfSync 표시, selfHeal 가능 |
| **롤백** | 이전 YAML 찾아 다시 apply | Git revert / 이전 revision sync |
| **멀티 클러스터** | 컨텍스트마다 수동 | Application별 destination |
| **UI·가시성** | `kubectl get` | 리소스 트리, diff, health |

LoadTestLab 실습 루프:

```text
./run-step.sh 300 → 처리량 부족
  → deployment.yaml / hpa.yaml 수정
  → git commit && git push
  → Argo CD sync (자동)
  → 동일 RPS 재테스트
```

**`kubectl apply`로 직접 배포하면** Argo CD는 곧 Git과 다르다고 **OutOfSync**를 표시하고, `selfHeal: true`이면 **Git 내용으로 덮어씁니다.** 실습·운영 모두 **Git 먼저 수정**이 원칙입니다.

---

## 8. LoadTestLab에서의 Argo CD

### 설치·등록

```bash
cd AWS/LoadTestLab/argocd
./install-argocd.sh
# 1) argocd NS + Argo CD 컴포넌트 설치
# 2) application.yaml 적용 → loadtest-app 등록
```

### GitOps 대상 (`app-manifests/`)

| 파일 | 역할 |
| --- | --- |
| `deployment.yaml` | echo-cpu (hpa-example + fluentd sidecar) |
| `hpa.yaml` | CPU 기반 autoscale |
| `ingress.yaml` | ALB + HTTPS (`loadtest.k8s-study.club`) |
| `service.yaml` / `metrics-service.yaml` | 트래픽·메트릭 |
| `fluentd-config.yaml` | 200/500 로그 + Prometheus counter |
| `servicemonitor.yaml` | Prometheus scrape |

Argo CD는 **이 디렉터리 전체**를 `loadtest` NS에 sync합니다. Ingress 변경 → AWS Load Balancer Controller → ALB 갱신까지 **연쇄**됩니다.

### private 클러스터에서 UI 접속

워커·Argo CD server가 private이면 **Load Balancer 없이** port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# https://localhost:8080  (admin / initial-admin-secret)
```

---

## 9. UI·CLI로 확인하기

### 자주 쓰는 kubectl

```bash
# Application 목록·상태
kubectl -n argocd get applications
kubectl -n argocd get application loadtest-app -o yaml

# sync된 워크로드 확인
kubectl -n loadtest get deploy,svc,ingress,hpa,pod

# 초기 admin 비밀번호
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### Argo CD CLI (선택)

```bash
argocd login localhost:8080 --insecure
argocd app get loadtest-app
argocd app diff loadtest-app
argocd app sync loadtest-app
argocd app history loadtest-app
```

### UI에서 확인할 것

| 화면 | 확인 내용 |
| --- | --- |
| **App Details → Sync Status** | Synced / OutOfSync |
| **Health** | Healthy / Progressing / Degraded |
| **Resource tree** | Deployment → RS → Pod, Ingress, HPA 연결 |
| **Diff** | Git vs live state 차이 (OutOfSync일 때) |
| **History** | 과거 sync revision (Git commit) |

---

## 10. 흔한 실수와 주의점

1. **Git 없이 `kubectl edit`**  
   - `selfHeal: true`면 변경이 **되돌아감**. 반드시 Git → push → sync.

2. **Application `path` / `targetRevision` 오류**  
   - sync는 되는데 **다른 디렉터리·브랜치**를 보고 있음.

3. **OutOfSync인데 Health는 Healthy**  
   - Pod는 떠 있지만 **replicas·image·env** 등 Git과 다름. Diff 탭 확인.

4. **Sync는 됐는데 Health Degraded**  
   - manifest 문법은 맞지만 Pod가 CrashLoop, Ingress가 ALB 미연동 등 **런타임 문제**.

5. **prune: true + YAML 실수로 삭제**  
   - Git에서 리소스 파일을 지우면 **클러스터에서도 삭제**됨.

6. **ReplicaSet이 UI에 많이 보임**  
   - Argo CD 버그가 아니라 Deployment **revision history**. `revisionHistoryLimit` 조정.

7. **private repo 접근**  
   - LoadTestLab은 public GitHub. private repo는 Argo CD에 **repository credentials** 등록 필요.

8. **Helm/Kustomize 혼동**  
   - `source.path`가 plain YAML이면 Helm 없이 apply. LoadTestLab `app-manifests/`는 **plain YAML**.

---

## 11. 이 실습·LoadTestLab과의 연결

| 구분 | `14.ArgoCD/` (Practice) | LoadTestLab |
| --- | --- | --- |
| 목표 | Helm으로 Argo CD **설치** (CRD 옵션) | EKS 위 GitOps **운영** |
| 설치 | `helm template` + manifest | `install-argocd.sh` (upstream YAML) |
| Application | (실습자가 정의) | `loadtest-app` → `app-manifests/` |
| 배포 대상 | Playground / Killercoda | EKS `loadtest` NS + ALB Ingress |
| 실습 루프 | 설치·매니페스트 생성 | HPA·리소스 튜닝 → git push → 부하 재테스트 |

```text
[Practice 14.ArgoCD]          [LoadTestLab]
  Argo CD 설치 개념      →      EKS + app-manifests GitOps
  Application CR       →      loadtest-app (automated sync)
  Helm / CRD           →      echo-cpu + HPA + Ingress 실전
```

**선행 권장:** [Deployment·리소스](../3.Resource-Allocation/Preliminaries.md) · [Ingress](../6.Ingress/) · [HPA](../8.HPA/) — Argo CD는 이 매니페스트들을 **Git에서 클러스터로 옮기는 배달 계층**입니다.

---

## 참고 명령어

```bash
# Argo CD Pod
kubectl -n argocd get pods

# Application 상태
kubectl -n argocd get application loadtest-app

# sync 후 rollout
kubectl -n loadtest rollout status deploy/echo-cpu

# port-forward (UI)
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

**공식 문서:** [https://argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)
