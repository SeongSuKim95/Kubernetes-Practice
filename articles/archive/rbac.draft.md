# RBAC 보관용 초안

> Service와 Ingress 초안에서 분리한 내용입니다. 정식 장 번호와 연재 순서는 정하지 않았습니다.

## 1. Kubernetes API 접근 권한을 정하는 RBAC

Service와 Ingress는 애플리케이션으로 들어오는 네트워크 요청의 경로를 만듭니다. 반면 **RBAC**(Role-Based Access Control, 역할 기반 접근 제어)은 사용자나 프로그램이 Kubernetes API에서 어떤 작업을 할 수 있는지를 제한하는 권한 체계입니다. 웹 애플리케이션 사용자의 로그인 권한을 관리하는 기능과는 목적이 다릅니다.

RBAC 규칙은 **누가**, **어떤 API 리소스에**, **어떤 동작을 할 수 있는지**를 표현합니다. 권한을 받는 주체에는 사용자, 그룹, Pod가 사용하는 ServiceAccount가 있습니다. `get`, `list`, `watch`, `create`, `update`, `delete` 같은 API 동작을 리소스별로 허용할 수 있습니다.

### 1.1 권한을 정의하는 Role과 ClusterRole

**Role**은 특정 Namespace 안에서 사용할 권한을 정의합니다. 다음 Role은 `dev` Namespace의 Pod 목록과 개별 Pod 정보를 읽을 수 있도록 허용하지만, Pod를 만들거나 삭제할 권한은 포함하지 않습니다.

```yaml
# dev Namespace의 Pod를 읽을 수 있는 Role 예시
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

**ClusterRole**은 Node처럼 Namespace에 속하지 않는 리소스의 권한이나 여러 Namespace에서 재사용할 권한 집합을 정의할 때 사용합니다. ClusterRole을 만들었다고 사용자에게 즉시 권한이 생기는 것은 아닙니다. Role과 ClusterRole은 권한 규칙만 정의하며, 실제 주체와 연결하는 Binding이 필요합니다.

### 1.2 주체와 권한을 연결하는 RoleBinding과 ClusterRoleBinding

**RoleBinding**은 Role 또는 ClusterRole의 권한을 지정한 주체에게 해당 Namespace 안에서 행사할 권한으로 부여합니다. 주체가 반드시 같은 Namespace에 속해야 하는 것은 아니며, 다른 Namespace의 ServiceAccount도 지정할 수 있습니다. `dev` Namespace와 `developer` ServiceAccount가 이미 생성되어 있다고 가정합니다. 다음 예시는 이 ServiceAccount에 앞에서 만든 `pod-reader` Role을 연결합니다.

```yaml
# ServiceAccount에 dev Namespace의 Pod 읽기 권한을 부여하는 예시
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: dev
subjects:
- kind: ServiceAccount
  name: developer
  namespace: dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

**ClusterRoleBinding**은 ClusterRole의 권한을 클러스터 전체 범위로 부여합니다. 이름이 비슷하지만 범위가 크게 다르므로, 한 Namespace에서만 필요한 권한이라면 RoleBinding을 우선 고려해야 합니다. 필요 이상의 읽기와 쓰기 권한을 넓게 부여하지 않는 **최소 권한 원칙**이 RBAC 설계의 기준입니다.

Secret 권한은 특히 주의해야 합니다. Secret을 `list`하거나 `watch`할 수 있으면 해당 Namespace의 여러 민감한 값을 읽을 수 있으며, Pod를 생성할 권한도 Pod가 Secret을 참조하도록 만들어 간접적으로 값을 읽는 데 사용될 수 있습니다. 따라서 워크로드가 실제로 필요한 리소스와 동작만 허용해야 합니다.

권한 범위와 주체의 관계는 [RBAC 공식 문서](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#rolebinding-and-clusterrolebinding)를 참고할 수 있습니다.
