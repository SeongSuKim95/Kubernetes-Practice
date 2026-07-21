# Kubernetes Practice

Docker에서 Kubernetes 기본 리소스, 스토리지, 네트워크, 스케줄링과 운영까지 순서대로 학습하고, AWS 환경에서 EKS·Ingress·GitOps·HPA를 실습하는 저장소입니다.

## 학습 경로

```text
Introduction
  → Docker 장애 대응
  → Kubernetes 기본(0)
  → Storage(1–2)
  → Workload(3–4)
  → Service / Ingress / TLS(5–7)
  → HPA / Scheduling(8–10)
  → NetworkPolicy / CNI / Gateway API(11–13)
  → Argo CD / CRD / Runtime / etcd(14–17)
  → AWS 실전 LAB
```

| 순서 | 영역 | 주제 |
|------|------|------|
| 0 | 기본 | Namespace, Pod, Deployment, Service, DNS, 라벨·셀렉터 |
| 1–2 | 스토리지 | PV/PVC → StorageClass |
| 3–4 | 워크로드 | requests/limits → Sidecar |
| 5–7 | 서비스 노출 | NodePort → Ingress → TLS |
| 8–10 | 스케일링·스케줄링 | HPA → Taints/Tolerations → PriorityClass |
| 11–13 | 네트워크 | NetworkPolicy → CNI → Gateway API |
| 14–17 | 배포·확장·운영 | Argo CD → CRD → cri-dockerd → etcd 복구 |

## 저장소 구조

```text
.
├── Introduction/          # Docker·Swarm·Kubernetes 이론과 용어
├── Practice/
│   ├── Docker/            # Docker 장애·수동 복구 실습
│   └── Kubernetes/        # 0–17 단계별 Kubernetes 실습
├── AWS/
│   ├── IngressLab/        # EC2 단일 노드 kubeadm + Ingress/TLS
│   ├── RoleBindingLab/    # EKS + Argo CD + RBAC/Taint/Priority
│   └── LoadTestLab/       # EKS + ALB + HPA + k6 + 모니터링
├── Feedback/              # 스터디 질문·답변·보충 자료
├── images/                # 문서 이미지
├── milestone/             # 스터디 일정
└── scripts/               # 실습 실행 도우미
```

## 시작하기

### 준비물

- Linux 기반 Kubernetes 실습 환경(예: [Killercoda](https://killercoda.com/)) 또는 개인 클러스터
- `bash`, `kubectl`
- 실습에 따라 Docker, Helm, OpenSSL, 인터넷 연결
- AWS LAB은 별도로 AWS CLI v2, `eksctl`, 유효한 AWS 자격 증명이 필요

> `LabSetUp.bash`는 Namespace·워크로드·클러스터 리소스를 생성하거나 기존 설정을 변경합니다. 개인/운영 클러스터보다 일회성 실습 환경에서 실행하는 것을 권장합니다.

### Kubernetes 실습 실행

저장소 루트에서:

```bash
git clone https://github.com/SeongSuKim95/Kubernetes-Practice.git
cd Kubernetes-Practice

# LabSetUp 실행 후 Questions 출력
./scripts/run-question.sh "Practice/Kubernetes/1.Persistent-Volume"
```

또는 각 파일을 직접 사용합니다.

```bash
cd Practice/Kubernetes/11.Network-Policy
bash LabSetUp.bash
less Questions.bash
# 직접 풀이한 뒤
less SolutionNotes.bash
```

대부분의 Kubernetes 실습 폴더는 다음 파일로 구성됩니다.

| 파일 | 역할 |
|------|------|
| `Preliminaries.md` | 실습 전 개념 설명(있는 주제만 제공) |
| `LabSetUp.bash` | 실습 환경과 문제 상황 구성 |
| `Questions.bash` | 수행할 과제 |
| `SolutionNotes.bash` | 풀이와 확인 명령 |

## 이론 문서

| 문서 | 내용 |
|------|------|
| [`Introduction/Intro.md`](Introduction/Intro.md) | VM → 컨테이너 → 오케스트레이션으로 이어지는 흐름 |
| [`Introduction/AboutDocker.md`](Introduction/AboutDocker.md) | Docker 구조, 이미지와 컨테이너 |
| [`Introduction/AboutDockerSwarm.md`](Introduction/AboutDockerSwarm.md) | Compose의 한계와 Swarm 오케스트레이션 |
| [`Introduction/AboutKubernetes.md`](Introduction/AboutKubernetes.md) | Kubernetes 등장 배경, 리소스와 아키텍처 |
| [`Introduction/Terminology.md`](Introduction/Terminology.md) | Docker·Swarm·Kubernetes 용어 비교 |
| [`Introduction/Questions.md`](Introduction/Questions.md) | 핵심 개념 점검 질문 |

Docker 장애 대응 실습은 [`Practice/Docker/docker-practice.sh`](Practice/Docker/docker-practice.sh)에서 진행합니다.

## Kubernetes 실습 목록

| # | 실습 | 핵심 목표 | 개념 문서 |
|---|------|-----------|-----------|
| 0 | [`Basic-Practice`](Practice/Kubernetes/0.Basic-Practice/) | 기본 리소스, 라벨·셀렉터, Service/DNS 진단 | [`Preliminaries.md`](Practice/Kubernetes/0.Basic-Practice/Preliminaries.md) (Probe), [`kubectl-commands.md`](Practice/Kubernetes/0.Basic-Practice/kubectl-commands.md) |
| 1 | [`Persistent-Volume`](Practice/Kubernetes/1.Persistent-Volume/) | PV/PVC 연결과 데이터 보존 | [`Preliminaries.md`](Practice/Kubernetes/1.Persistent-Volume/Preliminaries.md) |
| 2 | [`Storage-Class`](Practice/Kubernetes/2.Storage-Class/) | StorageClass와 동적 프로비저닝 | — |
| 3 | [`Resource-Allocation`](Practice/Kubernetes/3.Resource-Allocation/) | requests/limits와 안전한 리소스 배분 | [`Preliminaries.md`](Practice/Kubernetes/3.Resource-Allocation/Preliminaries.md) |
| 4 | [`Sidecar`](Practice/Kubernetes/4.Sidecar/) | 멀티 컨테이너, 공유 볼륨, ConfigMap/Secret 주입 | [`Preliminaries.md`](Practice/Kubernetes/4.Sidecar/Preliminaries.md) |
| 5 | [`NodePort`](Practice/Kubernetes/5.NodePort/) | Service 타입과 외부 노출 | [`Preliminaries.md`](Practice/Kubernetes/5.NodePort/Preliminaries.md) |
| 6 | [`Ingress`](Practice/Kubernetes/6.Ingress/) | host/path 기반 L7 라우팅 | — |
| 7 | [`TLS-Config`](Practice/Kubernetes/7.TLS-Config/) | ConfigMap TLS 정책과 TLS Secret 검증 | [`Preliminaries.md`](Practice/Kubernetes/7.TLS-Config/Preliminaries.md) |
| 8 | [`HPA`](Practice/Kubernetes/8.HPA/) | CPU 기반 수평 확장, Probe와 Ready | [`README.md`](Practice/Kubernetes/8.HPA/README.md) |
| 9 | [`Taints-Tolerations`](Practice/Kubernetes/9.Taints-Tolerations/) | 전용 노드 배치와 toleration | [`Preliminaries.md`](Practice/Kubernetes/9.Taints-Tolerations/Preliminaries.md) |
| 10 | [`PriorityClass`](Practice/Kubernetes/10.PriorityClass/) | Pod 우선순위와 preemption | [`Preliminaries.md`](Practice/Kubernetes/10.PriorityClass/Preliminaries.md) |
| 11 | [`Network-Policy`](Practice/Kubernetes/11.Network-Policy/) | 최소 권한 Pod 통신 정책 | [`Preliminaries.md`](Practice/Kubernetes/11.Network-Policy/Preliminaries.md) |
| 12 | [`CNI & NetworkPolicy`](Practice/Kubernetes/12.CNI%26NetworkPolicy/) | CNI와 NetworkPolicy 집행 | [`Preliminaries.md`](Practice/Kubernetes/12.CNI%26NetworkPolicy/Preliminaries.md) |
| 13 | [`Gateway-API`](Practice/Kubernetes/13.Gateway-API/) | Ingress를 Gateway/HTTPRoute로 이전 | [`Preliminaries.md`](Practice/Kubernetes/13.Gateway-API/Preliminaries.md) |
| 14 | [`ArgoCD`](Practice/Kubernetes/14.ArgoCD/) | RBAC 기초, Helm Argo CD 설치, CRD 처리 | [`Preliminaries.md`](Practice/Kubernetes/14.ArgoCD/Preliminaries.md) |
| 15 | [`CRDs`](Practice/Kubernetes/15.CRDs/) | CRD 탐색과 Custom Resource 스펙 확인 | — |
| 16 | [`Cri-Dockerd`](Practice/Kubernetes/16.Cri-Dockerd/) | cri-dockerd 설치와 런타임 설정 | — |
| 17 | [`Etcd-Fix`](Practice/Kubernetes/17.Etcd-Fix/) | etcd 연결 장애와 API Server 복구 | — |

## AWS 실전 LAB

AWS LAB은 로컬 개념 실습과 별도이며 실제 AWS 리소스와 비용을 발생시킵니다. 각 가이드의 **사전 준비와 cleanup 절차**를 먼저 확인하세요.

| LAB | 환경 | 학습 내용 | 시작 문서 |
|-----|------|-----------|-----------|
| **IngressLab** | EC2 한 대 + kubeadm + Calico | ingress-nginx, NodePort, TLS, Route53, 내부/외부 호출 | [`LAB-GUIDE.md`](AWS/IngressLab/LAB-GUIDE.md) |
| **RoleBindingLab** | EKS 노드그룹 2개 + Argo CD | RBAC RoleBinding, Taint/Toleration, PriorityClass/preemption | [`LAB-GUIDE.md`](AWS/RoleBindingLab/LAB-GUIDE.md), [`RBAC.md`](AWS/RoleBindingLab/RBAC.md) |
| **LoadTestLab** | EKS + ALB/ACM + Argo CD + k6 | 부하 단계, HPA, 리소스 튜닝, Prometheus/Grafana | [`LAB-GUIDE.md`](AWS/LoadTestLab/LAB-GUIDE.md), [`architecture.md`](AWS/LoadTestLab/architecture.md), [`test-guide.md`](AWS/LoadTestLab/test-guide.md) |

예시(RoleBindingLab):

```bash
cd AWS/RoleBindingLab/infra
./install-prerequisites.sh
export AWS_REGION=ap-northeast-2
./create-eks-cluster.sh
./install-addons.sh
```

클러스터 생성·삭제 명령과 기본값은 반드시 해당 LAB 가이드를 기준으로 사용하세요.

## 보충 자료

- [`Feedback/`](Feedback/) — 스터디 질문, 답변, Ingress·Service 보충 자료
- [`milestone/study-schedule.md`](milestone/study-schedule.md) — 스터디 일정
- [`images/`](images/) — Service/NodePort 등 문서용 이미지

## 참고 링크

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/)
- [Amazon EKS 문서](https://docs.aws.amazon.com/eks/)
- [Gateway API 문서](https://gateway-api.sigs.k8s.io/)