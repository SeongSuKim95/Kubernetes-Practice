# Kubernetes 연습을 위한 레포지토리

**Kubernetes를 처음 배우는 사람이 차근차근 따라가기 좋은 학습 순서**로 개념이 정렬되어 있습니다.

### 학습 순서 (폴더 번호)
| 번호 | 주제 | 설명 |
|------|------|------|
| 1–2 | 스토리지 | PersistentVolume/PVC → StorageClass |
| 3–4 | 워크로드 | 리소스 요청/제한 → Sidecar(멀티컨테이너) |
| 5–7 | 서비스 노출 | NodePort → Ingress → TLS |
| 8–10 | 스케일/스케줄링 | HPA → Taints/Tolerations → PriorityClass |
| 11–12 | 네트워크 정책 | Network-Policy → CNI 설치 |
| 13–17 | 고급/운영 | Gateway API → ArgoCD → CRDs → Cri-Dockerd → Etcd 트러블슈팅 |

실습 파일은 각 개념의 폴더에 세 개의 bash 파일로 구성됩니다:

- `LabSetUp.bash` — Killercoda(또는 다른 Kubernetes 클러스터)에 복사/붙여넣기하여 환경을 준비합니다.
- `Questions.bash` — 시나리오 설명입니다.
- `SolutionNotes.bash` — 단계별 풀이입니다.

## 사용 방법
1. CKA Killercoda 플레이그라운드 또는 본인 클러스터를 실행합니다. (https://killercoda.com/)
2. 해당 환경 안에서 이 저장소를 클론합니다.
3. `N.주제이름` 형식의 폴더를 **1번부터 순서대로** 진행합니다. (예: `1.Persistent-Volume`, `6.Ingress`)
4. `./scripts/run-question.sh "1.Persistent-Volume"` 처럼 실행하면 LabSetUp 적용 후 문제 문구가 출력됩니다. 또는 해당 폴더에서 `bash LabSetUp.bash`를 직접 실행할 수 있습니다.
5. 문제를 풀고, 필요하면 `SolutionNotes.bash`를 참고합니다.

## 유용한 링크 모음
1. Kubernetes 공식 문서 : https://kubernetes.io/docs/reference/

---

## 챕터별 학습 주제 (WHAT) / 학습 목표

### Introduction (이론)

| 주제 | 학습 주제 (WHAT) | 학습 목표 (공부하고 나면 ~을 할 수 있다) |
|---|---|---|
| `Intro.md` | VM·컨테이너·Docker에서 다중 컨테이너·다중 서버 관리(Compose/Swarm/Kubernetes)로 이어지는 기술 흐름 | 컨테이너 생태계가 왜 단계적으로 복잡해졌는지 한 줄로 설명할 수 있다. |
| `AboutDocker.md` | VM 대비 컨테이너의 구조, Docker 철학·Engine/Daemon, 이미지·컨테이너·Dockerfile | VM과 컨테이너의 차이, 이미지 vs 컨테이너를 구분하고 설명할 수 있다. |
| `AboutDockerSwarm.md` | Compose의 한계와 오케스트레이션의 역할, Swarm의 Node·Service·Task 등 | 단일 호스트 한계와 오케스트레이션이 주는 기능을 예시로 말할 수 있다. |
| `AboutKubernetes.md` | K8s 등장 배경, Pod/Deployment/Service/Ingress/Namespace, 구성요소, 선언형 API·Control Loop·CRI | Kubernetes의 핵심 오브젝트·아키텍처·설계 철학을 개념도 수준으로 설명할 수 있다. |
| `Terminology.md` | Docker/Swarm/Kubernetes에서 쓰는 용어의 뜻과 서로 다른 점(예: Service 대응) | 같은 단어가 플랫폼마다 다른 의미를 갖는 경우를 구분해 말할 수 있다. |
| `Questions.md` | Pod와 컨테이너, dockershim·CRI·OCI, 선언형 vs 명령형, 장애 시 수동 vs 자동 | “왜 K8s는 Pod인가” 같은 핵심 질문에 답변 논리를 구성할 수 있다. |

### Practice (실습)

| 주제 | 학습 주제 (WHAT) | 학습 목표 (공부하고 나면 ~을 할 수 있다) |
|---|---|---|
| `Practice/Docker` | 단일 Docker에서 컨테이너 실행·점검·장애·수동 복구 시나리오 | 컨테이너 장애 시 무엇을 어떤 순서로 직접 복구하는지 체계적으로 설명할 수 있다. |
| `0.Basic-Practice` | Namespace, Pod, Deployment, Service, 라벨/셀렉터, DNS 스코프 | `kubectl`로 기본 리소스를 만들고 셀렉터/엔드포인트/DNS 차이를 증상 기반으로 진단할 수 있다. |
| `1.Persistent-Volume` | PV/PVC와 Deployment 연동, 데이터 보존 재배포 | PVC를 재사용해 워크로드를 재배포해도 데이터가 유지되는지 확인할 수 있다. |
| `2.Storage-Class` | StorageClass 정의·기본 클래스 지정·VolumeBindingMode | StorageClass를 만들고 기본값을 변경해 스토리지 정책을 조정할 수 있다. |
| `3.Resource-Allocation` | Deployment requests/limits, init·메인 컨테이너 리소스 정합 | 노드 안정성을 고려해 파드별 CPU/메모리를 균등·안전하게 설정할 수 있다. |
| `4.Sidecar` | 멀티 컨테이너 Pod, 공유 볼륨으로 로그 수집 사이드카 | 사이드카 컨테이너와 볼륨을 통해 동일 Pod 내 로그를 공유·확인할 수 있다. |
| `5.NodePort` | NodePort Service로 클러스터 외부 노출 | 컨테이너 포트와 NodePort를 연결해 외부 접근을 검증할 수 있다. |
| `6.Ingress` | NodePort 뒤 Ingress로 호스트/경로 라우팅 | Ingress 리소스로 도메인/경로 기반 라우팅을 구성할 수 있다. |
| `7.TLS-Config` | ConfigMap으로 TLS 버전 제한, Secret·HTTPS 동작 검증 | 허용/차단되는 TLS 프로토콜을 `curl` 결과로 검증할 수 있다. |
| `8.HPA` | HorizontalPodAutoScaler, CPU 목표, min/max, 다운스케일 안정화 | CPU 기준 오토스케일과 min/max/다운스케일 윈도우 동작을 설정하고 설명할 수 있다. |
| `9.Taints-Tolerations` | 노드 Taint와 Pod Toleration으로 스케줄링 제어 | Taint로 일반 Pod 배치를 막고, Toleration이 있는 Pod만 특정 노드에 스케줄되게 할 수 있다. |
| `10.PriorityClass` | PriorityClass 생성과 Deployment에 우선순위 적용 | 우선순위 클래스를 생성해 워크로드 스케줄링 우선순위를 조정할 수 있다. |
| `11.Network-Policy` | 네트워크 정책을 최소 권한으로 선택·배포 | 프론트–백엔드 통신만 허용하도록 “덜 허용적인” 정책을 선택해 배포할 수 있다. |
| `12.CNI&NetworkPolicy` | Flannel 또는 Calico 설치, Pod 통신·NetworkPolicy 적용 | CNI 설치 후 Pod 통신과 NetworkPolicy 적용 가능 여부를 확인할 수 있다. |
| `13.Gateway-API` | Ingress를 Gateway API로 마이그레이션(HTTPRoute/Gateway) | 기존 Ingress의 TLS/라우팅 구성을 Gateway API로 옮겨 동일 동작을 만들 수 있다. |
| `14.ArgoCD` | Helm으로 Argo CD 설치(특히 CRD 중복 방지 옵션) | CRD 중복 없이 Argo CD를 설치하고 Helm 템플릿을 생성·저장할 수 있다. |
| `15.CRDs` | cert-manager CRD 목록화 및 Custom Resource 필드 문서 추출 | CRD 목록을 파일로 남기고 특정 필드 문서를 `kubectl` 출력으로 뽑을 수 있다. |
| `16.Cri-Dockerd` | cri-dockerd 설치·서비스 기동 및 커널/네트워크 파라미터 튜닝 | cri-dockerd를 설치해 동작시키고 요구 커널 파라미터를 설정할 수 있다. |
| `17.Etcd-Fix` | etcd/peer 포트 설정 문제 등 kube-apiserver 장애 트러블슈팅 | 마이그레이션 후 apiserver가 etcd에 붙지 못하는 원인을 찾아 수정할 수 있다. |

### (스터디 일정 기반) 추가 주제

| 주제 | 학습 주제 (WHAT) | 학습 목표 (공부하고 나면 ~을 할 수 있다) |
|---|---|---|
| Kubernetes 공식 문서 탐방 | 공식 문서 구조/검색/버전별 문서 이해 | 시험·업무에서 필요한 스펙을 공식 문서만으로 빠르게 찾을 수 있다. |
| Amazon EKS | AWS 관리형 Kubernetes 클러스터 | EKS 기반으로 클러스터/워크로드 연동 개념을 실습 수준으로 이해할 수 있다. |

---

## AWS EKS로의 확장

아래는 이 레포의 `Introduction`/`Practice` 주제들을 **Amazon EKS 운영 관점**으로 확장했을 때의 강의 주제 예시입니다.

| 주제 | 학습 주제 (WHAT) | 학습 목표 (공부하고 나면 ~을 할 수 있다) |
|---|---|---|
| EKS 입문/구조 | EKS(Control Plane 관리형) 구조, Cluster/VPC/Subnet/SecurityGroup, kubeconfig/IRSA 개요 | EKS 클러스터를 만들고 `kubectl`로 접속해 Control Plane/Node 책임 경계를 설명할 수 있다. |
| 노드/런타임/이미지 | Managed Node Group vs Fargate, AMI/업그레이드, containerd, ECR | 워크로드 특성에 맞춰 노드 타입을 선택하고 이미지를 ECR에 올려 배포할 수 있다. |
| 기본 리소스 실습 확장 | Namespace/Deployment/Service, 라벨·셀렉터, CoreDNS | EKS에서 기본 리소스를 만들고 엔드포인트/서비스 디스커버리 문제를 증상 기반으로 진단할 수 있다. |
| 스토리지 확장 | PV/PVC/StorageClass를 EBS CSI로 동적 프로비저닝, (선택) EFS로 RWX | PVC 기반으로 스토리지를 자동 생성·재사용하고 데이터 보존을 검증할 수 있다. |
| 리소스/오토스케일 확장 | requests/limits, HPA, (선택) Cluster Autoscaler 또는 Karpenter | 파드/노드 오토스케일을 함께 구성해 트래픽 변화에 자동 대응하게 할 수 있다. |
| 서비스 노출 확장 | Service(LoadBalancer), AWS Load Balancer Controller, Ingress/ALB·NLB | 외부 트래픽을 ALB/NLB로 받아 서비스로 라우팅하고 검증할 수 있다. |
| TLS 확장 | ACM 인증서, (선택) cert-manager, TLS 종료 지점(ALB vs Ingress) | HTTPS를 구성하고 인증서 갱신/배포 흐름을 운영 관점에서 설명할 수 있다. |
| 네트워크/정책 확장 | AWS VPC CNI, 보안그룹/네트워크 경계, NetworkPolicy(지원 방식) | 보안그룹과 정책의 역할을 구분해 최소 권한 통신을 설계할 수 있다. |
| 스케줄링 심화 | Taints/Tolerations, PriorityClass, 노드풀 분리(워크로드 격리) | 중요 워크로드 우선 배치 및 특정 노드 전용 배치를 구성할 수 있다. |
| GitOps/배포 확장 | Argo CD로 GitOps, Helm/Kustomize, 멀티 환경(dev/prod) | Git 변경만으로 EKS에 선언형 배포/롤백이 되도록 구성할 수 있다. |
| CRD/확장 | CRD 기반 애드온 운용, `kubectl explain`로 스펙 파악 | CRD/Custom Resource를 이해하고 필요한 필드를 찾아 올바르게 작성할 수 있다. |
| 운영/트러블슈팅 | 로그/이벤트/노드/애드온 중심 진단, AWS 리소스와의 경계 | 문제를 “Control Plane vs Node vs 애드온 vs AWS 리소스”로 분리해 원인을 좁힐 수 있다. |