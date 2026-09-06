# Namespace 보관용 초안

> `Chap03. 서비스 운영에 필요한 핵심 리소스`에서 분리한 보관용 초안입니다. 정식 Chap 구성과 연재 순서는 정하지 않았습니다.

## 리소스 이름과 정책 범위를 나누는 Namespace

<div align="center">

![Kubernetes Namespace](../../images/articles/02/08-namespace.svg)

</div>

**Namespace**(네임스페이스)는 하나의 클러스터 안에서 리소스 이름과 정책 적용 범위를 논리적으로 나누는 리소스입니다. 같은 클러스터를 여러 팀이나 서비스, 개발 환경이 함께 사용할 때 리소스를 구분하는 기준으로 사용합니다.

```yaml
# dev Namespace를 선언하는 매니페스트 예시
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```

Namespace에 속하는 리소스의 `metadata.namespace`에 `dev`를 적으면 해당 리소스가 `dev` Namespace에 만들어집니다. 매니페스트와 명령에 Namespace를 지정하지 않으면 현재 kubectl 문맥에 설정된 Namespace를 사용하며, 별도 설정이 없을 때는 보통 `default` Namespace를 사용합니다.

리소스 이름은 Namespace 안에서 고유하면 됩니다. `dev` Namespace와 `prod` Namespace에는 이름이 같은 `web` Deployment와 `web` Service가 각각 존재할 수 있습니다. 따라서 리소스를 정확히 식별하려면 Namespace와 리소스 이름을 함께 확인해야 합니다.

Service의 짧은 DNS 이름도 Namespace를 기준으로 해석됩니다. 같은 Namespace에 있는 Pod는 `web`이라는 이름으로 같은 Namespace의 Service에 접근할 수 있습니다. 다른 Namespace의 Service에 접근하려면 `web.prod`처럼 Service 이름과 Namespace 이름을 함께 적을 수 있습니다. 전체 DNS 이름은 `web.prod.svc.cluster.local`과 같은 형태입니다.

Namespace는 클러스터를 물리적으로 분리하지 않습니다. Namespace를 나눈 것만으로 서로 다른 Namespace 사이의 네트워크 통신이 자동으로 차단되거나 노드가 분리되는 것도 아닙니다. 권한을 제한하려면 역할 기반 접근 제어 정책을, 자원 사용량을 제한하려면 리소스 할당량을, 네트워크 통신을 제한하려면 네트워크 정책을 별도로 적용해야 합니다.

Pod와 Deployment, Service, Ingress는 특정 Namespace에 속합니다. 반면 Node처럼 클러스터 전체를 대상으로 하는 리소스도 있습니다. 따라서 모든 Kubernetes 리소스가 Namespace에 속한다고 이해하면 안 됩니다.
