# 후속 초안. Argo CD와 GitOps 운영

> 이 글은 7장에서 분리한 후속 주제 초안이며 장 번호는 아직 정하지 않았습니다. Git의 원하는 상태와 클러스터의 실제 상태를 Argo CD가 비교하고 복구하는 운영 흐름을 구성합니다.

## 들어가며

`kubectl apply`는 매니페스트를 한 번 API에 반영하지만 이후의 수동 변경을 계속 감시하지 않습니다. Argo CD는 Git의 선언을 원하는 상태로 삼고 클러스터의 실제 상태와 비교하여 `Synced`·`OutOfSync`와 Health를 표시하며, 설정에 따라 자동 동기화와 self-heal을 수행합니다.[[1]](#ref-1) 자동 동기화는 Git 변경과 클러스터 드리프트를 반영하는 범위를 별도로 설정합니다.[[2]](#ref-2)

이 글은 Argo CD 설치 전체를 설명하지 않는 스테이징 초안입니다. 설치된 Argo CD와 학습용 Git 저장소가 있다는 전제에서 Application, `kubectl` 직접 변경과 self-heal 비교, AWS 환경 범위, 진단과 정리를 다룹니다. 장 번호와 실제 저장소 경로는 연재 편성 때 확정해야 합니다.

## 1. GitOps의 원하는 상태와 실제 상태

Argo CD에서 구분할 핵심 상태는 다음과 같습니다.

- Source: Git 저장소 URL, revision, 매니페스트 경로입니다.[[3]](#ref-3)
- Destination: 배포 대상 클러스터와 Namespace입니다.
- Sync Status: Git과 클러스터 객체 내용이 일치하는지 나타냅니다.
- Health: Deployment와 Pod 같은 리소스가 정상 동작하는지 나타냅니다.
- Prune: Git에서 삭제된 관리 리소스를 클러스터에서도 삭제합니다.
- SelfHeal: 클러스터의 수동 변경을 Git 선언으로 되돌립니다.

`Synced`이면서 `Degraded`일 수 있습니다. Git과 같은 매니페스트가 적용됐더라도 Image 오류로 Pod가 실패할 수 있기 때문입니다. 반대로 `OutOfSync`이면서 `Healthy`일 수도 있습니다. 수동으로 복제본 수를 바꿨지만 Pod 자체는 정상인 경우입니다.

Argo CD는 Kubernetes 안에서 실행되는 컨트롤러이며 Application과 Project 같은 리소스를 선언적으로 관리할 수 있습니다.[[4]](#ref-4) `argocd-application-controller`의 ServiceAccount가 대상 Namespace의 Kubernetes API를 호출하므로 Git 설정이 맞아도 RBAC 권한이 부족하면 동기화가 `Forbidden`으로 실패합니다.

## 2. AWS 환경과 실습 범위

EKS에서 이 실습을 진행하려면 다음 범위를 구분합니다.

- AWS CLI, kubectl과 클러스터 인증은 운영자 환경에 필요합니다.
- Argo CD 컴포넌트는 일반적으로 EKS의 `argocd` Namespace에 Pod로 실행됩니다.
- Application이 관리하는 워크로드는 `payments`, `backend` 같은 별도 Namespace에 배포됩니다.
- Git 저장소는 클러스터 외부의 원하는 상태 저장소입니다.
- private EKS에서 Argo CD UI는 `kubectl port-forward`로 임시 접근할 수 있습니다.
- Node, NAT Gateway, Load Balancer와 저장소 서비스에는 비용이 발생할 수 있습니다.

이 글은 EKS 클러스터, VPC CNI, Load Balancer Controller를 생성하지 않습니다. NetworkPolicy를 GitOps로 관리한다면 정책 집행 가능한 CNI가 먼저 준비되어야 하며, Node Taint는 Application의 매니페스트가 관리하지 않는 한 수동 변경으로 남습니다.

```bash
# 클러스터 연결과 Argo CD 컴포넌트 및 Application CRD를 확인
kubectl config current-context
kubectl get pods -n argocd
kubectl get crd applications.argoproj.io
kubectl get applications -n argocd
```

private 클러스터에서 UI를 확인할 때는 다음 명령을 별도 터미널에서 실행합니다.

```bash
# 로컬 8080 포트로 Argo CD API와 UI를 임시 전달
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

## 3. Application으로 Git 경로와 대상을 연결

다음은 Application 명세의 구조를 보여 주는 스테이징 예시입니다.[[3]](#ref-3) `repoURL`, `targetRevision`, `path`, 대상 Namespace는 실제 학습 저장소에 맞게 바꿔 `payflow-networkpolicy-application.yaml`로 저장합니다.

```yaml
# Git의 NetworkPolicy 실습 경로를 backend Namespace에 동기화하는 Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payflow-networkpolicy
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/kubernetes-practice.git
    targetRevision: main
    path: gitops/networkpolicy
  destination:
    server: https://kubernetes.default.svc
    namespace: backend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

- `apiVersion: argoproj.io/v1alpha1`: Argo CD Application CR의 API 버전입니다.
- `kind: Application`: Git Source와 배포 Destination을 연결하는 Argo CD 객체입니다.
- `metadata.name: payflow-networkpolicy`: Application 이름입니다.
- `metadata.namespace: argocd`: Application CR 자체를 저장할 Namespace입니다.
- `spec.project: default`: 저장소와 대상 범위를 허용할 Argo CD Project입니다.
- `spec.source`: 원하는 상태를 읽을 Git Source 설정입니다.
- `source.repoURL`: 실제 Git 저장소 URL입니다.
- `source.targetRevision: main`: 추적할 브랜치, 태그 또는 커밋입니다.
- `source.path: gitops/networkpolicy`: 저장소에서 렌더링할 매니페스트 경로입니다.
- `spec.destination`: 렌더링한 리소스를 적용할 대상입니다.
- `destination.server: https://kubernetes.default.svc`: Argo CD가 실행 중인 같은 클러스터의 API 주소입니다.
- `destination.namespace: backend`: Namespace가 없는 매니페스트의 기본 배포 대상입니다.
- `spec.syncPolicy`: 동기화 방식과 옵션입니다.
- `syncPolicy.automated`: 자동 동기화를 활성화합니다.
- `automated.prune: true`: Git에서 사라진 관리 리소스를 클러스터에서도 삭제합니다.
- `automated.selfHeal: true`: Git과 다른 클러스터 수동 변경을 원래 선언으로 복구합니다.
- `syncOptions`: 동기화 추가 옵션 목록입니다.
- `CreateNamespace=true`: 대상 Namespace가 없으면 생성하도록 요청합니다.

`prune`과 `selfHeal`은 편리하지만 삭제와 덮어쓰기를 자동화합니다.[[2]](#ref-2) 운영 저장소에서는 PR 검토, Project의 Source·Destination 제한과 RBAC을 함께 적용해야 합니다.

```bash
# Application을 적용하고 Source, Destination과 초기 상태를 확인
kubectl apply -f payflow-networkpolicy-application.yaml
kubectl get application payflow-networkpolicy -n argocd
kubectl describe application payflow-networkpolicy -n argocd
```

## 4. `kubectl` 변경과 self-heal 비교

먼저 Git에 선언된 NetworkPolicy가 동기화됐고 허용 출처와 거부 출처의 기준선이 준비됐다고 가정합니다. Application이 실제로 관리하는 리소스 이름은 Git 경로의 매니페스트와 일치해야 합니다.

```bash
# self-heal 비교 전 Application과 관리 정책의 기준 상태를 기록
kubectl get application payflow-networkpolicy -n argocd
kubectl get networkpolicy -n backend
kubectl get application payflow-networkpolicy -n argocd \
  -o jsonpath='{.spec.syncPolicy}{"\n"}'
```

`selfHeal: true` 상태에서 관리 중인 정책을 직접 삭제하면 잠시 `OutOfSync`가 된 뒤 Argo CD가 Git 선언을 다시 생성해야 합니다.

```bash
# 관리 정책을 직접 삭제하고 Argo CD의 OutOfSync 및 self-heal 복구를 관찰
kubectl delete networkpolicy default-deny-ingress -n backend
kubectl get application payflow-networkpolicy -n argocd -w
kubectl get networkpolicy default-deny-ingress -n backend
```

watch는 정책이 복구된 뒤 `Ctrl-C`로 종료합니다. 조정 주기와 저장소 갱신 상태에 따라 복구까지 시간이 걸릴 수 있습니다. Git에 해당 객체가 없거나 Application 경로가 다르면 복구되지 않습니다.

정책이 복구된 전후로 허용과 거부 출처를 함께 테스트합니다.

```bash
# self-heal 뒤 허용 frontend와 거부 client의 통신을 비교
kubectl exec -n frontend deploy/frontend -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
kubectl exec -n client deploy/client -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://backend-service.backend
```

frontend는 `200`, client는 시간 초과여야 합니다. NetworkPolicy 객체의 복구와 데이터플레인 집행에는 짧은 시차가 있을 수 있습니다.

자동 복구를 끈 비교가 꼭 필요하다면 실습 전 `syncPolicy` 전체를 파일로 백업하고, 해당 Application만 잠시 수동 동기화로 바꿉니다. 공유 Application이나 운영 환경에서는 수행하지 않습니다.

```bash
# 원래 동기화 정책을 백업하고 실습 Application의 automated 설정만 잠시 제거
kubectl get application payflow-networkpolicy -n argocd -o yaml \
  > payflow-networkpolicy.application.before.yaml
kubectl patch application payflow-networkpolicy -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
kubectl delete networkpolicy default-deny-ingress -n backend
kubectl get application payflow-networkpolicy -n argocd
```

이 상태에서는 정책이 자동 복구되지 않고 Application이 `OutOfSync`여야 합니다. 비교를 마친 뒤 임의의 예시 설정을 쓰지 말고 백업한 원래 Application을 적용합니다.

```bash
# 실습 전 저장한 Application 설정으로 자동 동기화 정책을 복구
kubectl apply -f payflow-networkpolicy.application.before.yaml
kubectl get application payflow-networkpolicy -n argocd
kubectl get networkpolicy -n backend
```

Git을 원하는 상태로 사용하는 정상 변경 흐름은 로컬 YAML을 바로 `kubectl apply`하는 것이 아니라 저장소의 매니페스트 수정, 검토, commit과 push, Argo CD 동기화 확인 순서입니다. 긴급 직접 변경이 필요했다면 Git에도 같은 결정을 반영하지 않는 한 self-heal이 되돌릴 수 있습니다.

## 5. 상태와 권한 진단

Application이 기대대로 동작하지 않으면 Source, 렌더링, RBAC, Sync Status, Health를 분리해서 확인합니다.

- `ComparisonError`: 저장소 인증, `repoURL`, revision, path와 매니페스트 렌더링을 확인합니다.
- `OutOfSync`가 계속됨: Diff에서 무시 필드와 Controller가 기본값을 넣는 필드를 확인합니다.
- `SyncFailed` 또는 `Forbidden`: application-controller ServiceAccount의 대상 Namespace 권한을 확인합니다.
- `Synced`이지만 `Degraded`: Pod 이벤트, Image, 프로브와 requests를 조사합니다.
- 삭제한 객체가 즉시 복구됨: `selfHeal`이 켜진 Application이 관리하는지 확인합니다.
- Git에서 삭제한 객체까지 사라짐: `prune: true`의 정상 동작일 수 있으므로 commit과 Application 이벤트를 확인합니다.

```bash
# Application 상태, 이벤트, Diff 대상과 컨트롤러 권한을 조사
kubectl get application payflow-networkpolicy -n argocd -o yaml
kubectl describe application payflow-networkpolicy -n argocd
kubectl logs -n argocd statefulset/argocd-application-controller --tail=200
kubectl auth can-i create networkpolicies -n backend \
  --as=system:serviceaccount:argocd:argocd-application-controller
kubectl auth can-i patch networkpolicies -n backend \
  --as=system:serviceaccount:argocd:argocd-application-controller
```

설치 방식에 따라 application-controller의 리소스 종류나 ServiceAccount 이름이 다를 수 있으므로 실제 Pod와 ServiceAccount를 먼저 확인합니다. 위 `--as` 검사에는 현재 사용자의 임퍼소네이션 권한도 필요합니다.

Argo CD CLI가 준비됐다면 다음 읽기 명령으로 상태와 차이를 확인할 수 있습니다.

```bash
# Argo CD CLI로 Application 상태와 Git·클러스터 차이를 확인
argocd app get payflow-networkpolicy
argocd app diff payflow-networkpolicy
argocd app history payflow-networkpolicy
```

## 6. 정리

Application을 삭제할 때 Argo CD finalizer와 cascade 설정에 따라 관리 리소스도 삭제될 수 있습니다. 보존할 리소스가 있다면 삭제 동작을 먼저 확인합니다. 스테이징 실습에서는 Git에서 Application 선언을 제거하는 방식과 클러스터에서 직접 삭제하는 방식을 섞지 않습니다.

```bash
# Application과 백업 파일의 정리 전 삭제 영향을 확인
kubectl get application payflow-networkpolicy -n argocd -o yaml
kubectl delete -f payflow-networkpolicy-application.yaml --dry-run=server
```

실제 삭제가 목적이고 관리 리소스 삭제 영향도 확인했다면 `--dry-run=server`를 제거합니다. Argo CD 자체가 다른 Application도 관리한다면 이 글의 정리 과정에서 `argocd` Namespace나 Argo CD 설치를 삭제하지 않습니다. AWS 실습 클러스터를 별도로 만들었다면 Node, Load Balancer, NAT Gateway와 EIP 같은 잔여 비용 리소스도 확인합니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Argo CD Application은 Git Source와 클러스터 Destination을 연결하고, Sync Status와 Health를 별도로 계산합니다. self-heal은 수동 드리프트를 Git 선언으로 되돌리므로 직접 `kubectl` 변경과 Git 기반 변경의 운영 의미가 다릅니다.

이 주제는 Git 저장소 구조, 대상 Namespace의 RBAC과 배포할 Kubernetes 매니페스트가 준비됐다는 조건에 의존합니다. 후속 글의 장 번호는 정하지 않았으며, 다음 주제로는 Project와 저장소 자격 증명, 다중 환경 승격 전략을 다룰 수 있습니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Argo CD 공식 문서](https://argo-cd.readthedocs.io/en/stable/)
- <a id="ref-2"></a>[2] [Argo CD 자동 동기화 공식 문서](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- <a id="ref-3"></a>[3] [Argo CD Application 명세](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- <a id="ref-4"></a>[4] [Argo CD 선언적 설정 공식 문서](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
