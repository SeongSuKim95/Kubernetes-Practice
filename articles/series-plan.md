# Kubernetes 16장 연재 구성

1~7장은 실행과 통신의 기초를 유지합니다. 8~16장은 데이터 보존 → 자원과 확장 → 배치와 우선순위 → 통신 정책 → API 확장 → 배포 자동화 → 클러스터 장애 진단 순서로 구성합니다.

8~9장은 개념 설명, 문제 및 코드 해설을 구체화했습니다. 10~16장은 개념 설명, 문제, 해설과 결과 확인을 간단히 정리한 집필 출발점이며, 세부 코드와 그림은 각 장을 확장할 때 보완합니다.

| 장 | 초안 |
|---|---|
| 1 | [Container의 등장 배경과 Docker](01-background-and-docker-limits.draft.md) |
| 2 | [Kubernetes의 설계 철학](02-understanding-kubernetes.draft.md) |
| 3 | [Pod와 Deployment: 애플리케이션 실행 단위와 배포](03-pod-and-workload-management.draft.md) |
| 4 | [Pod의 실행과 상태 확인](04-pod-lifecycle-and-self-healing.draft.md) |
| 5 | [Pod의 장애와 자동 복구: 재시작부터 문제 진단까지](05-pod-failure-and-self-healing.draft.md) |
| 6 | [Service와 클러스터 통신](06-service-types.draft.md) |
| 7 | [Ingress와 HTTPS: 외부 요청을 Service로 연결하기](07-ingress-and-https.draft.md) |
| 8 | [Pod 교체 이후의 데이터 보존: PV·PVC와 StorageClass](08-persistent-storage.draft.md) |
| 9 | [애플리케이션의 자원 관리: requests와 limits](09-resource-requests-and-limits.draft.md) |
| 10 | [부하에 따른 Pod 수 조절: HPA](10-horizontal-pod-autoscaling.draft.md) |
| 11 | [Pod의 배치 조건: Taint와 Toleration](11-taints-and-tolerations.draft.md) |
| 12 | [Pod의 실행 우선순위: PriorityClass와 선점](12-priorityclass-and-preemption.draft.md) |
| 13 | [Pod 통신의 연결과 제한: CNI와 NetworkPolicy](13-cni-and-network-policy.draft.md) |
| 14 | [Kubernetes API의 확장: CRD와 Gateway API](14-crd-and-gateway-api.draft.md) |
| 15 | [매니페스트 관리와 배포 자동화: Helm과 Argo CD](15-helm-and-argocd.draft.md) |
| 16 | [클러스터 구성과 장애 진단: 런타임과 Control Plane](16-cluster-configuration-and-troubleshooting.draft.md) |

## 실습 연결

| 장 | Practice/Kubernetes 자료 |
|---|---|
| 8 | 1.Persistent-Volume, 2.Storage-Class, 4.Sidecar |
| 9 | 3.Resource-Allocation |
| 10 | 8.HPA |
| 11 | 9.Taints-Tolerations |
| 12 | 10.PriorityClass |
| 13 | 11.Network-Policy, 12.CNI&NetworkPolicy |
| 14 | 13.Gateway-API, 15.CRDs |
| 15 | 14.ArgoCD |
| 16 | 16.Cri-Dockerd, 17.Etcd-Fix |

## 실행 구조와 마지막 장의 범위

Kubelet·런타임·CRI·cri-dockerd의 기본 관계는 2~3장에서 설명합니다. 16장에서는 이를 반복 정의하지 않고 런타임 설치 및 연결 확인 문제에 적용합니다. API Server와 etcd의 접속 오류는 같은 장의 별도 문제로 다룹니다. RBAC은 별도 후속 주제로 남깁니다.

## 기존 상세 초안 보관

이전 장 번호를 사용한 상세 초안은 다음 위치에 보관합니다. 새 순서의 초안을 확장할 때 코드와 그림을 다시 검토해 활용합니다.

- [기존 8장: CRD와 Gateway API](archive/08-gateway-api-and-httproute.full.md) → 새 14장
- [기존 9장: Taint와 Toleration](archive/09-namespace-and-pod-placement.full.md) → 새 11장
- [기존 10장: NetworkPolicy](archive/10-network-policy.full.md) → 새 13장
