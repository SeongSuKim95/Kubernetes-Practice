<!--
  게시용 복사본입니다. GitHub Flavored Markdown용이며, 이미지 경로는 GitHub raw URL입니다.
  원본(로컬 미리보기용): 03-pod-and-workload-management.draft.md
  이미지 저장소: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap03. Pod와 Deployment: 애플리케이션 실행 단위와 배포

> 15주 연재의 셋째 글입니다. Kubernetes가 컨테이너를 실행하는 최소 단위인 Pod와 애플리케이션의 특성에 따라 Pod를 관리하는 Deployment, StatefulSet, DaemonSet을 살펴봅니다. 컨테이너 이미지에서 실행 설정을 분리하는 ConfigMap과 Secret도 함께 정리합니다.

## 들어가며

![Kubernetes 공식 로고](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/01-k8s-logo.svg)

2장에서는 사용자가 원하는 상태를 선언하면 Kubernetes가 실제 상태를 그 선언에 맞추는 방식을 살펴보았습니다. 이번 글에서는 컨테이너를 어떤 단위로 실행하고, 실행 중인 애플리케이션의 개수와 구성을 어떤 리소스로 관리하는지 알아봅니다.

먼저 매니페스트와 리소스를 구분하고, 컨테이너의 실행 단위인 Pod를 살펴봅니다. 이어서 Deployment를 중심으로 Pod 복제본과 배포 변경을 관리하는 방법을 알아보고, StatefulSet과 DaemonSet이 필요한 상황을 비교합니다. 마지막으로 ConfigMap과 Secret을 이용해 실행 설정을 컨테이너 이미지에서 분리하는 방법을 정리합니다.

## 1. 리소스와 매니페스트

애플리케이션을 배포하려면 원하는 상태를 선언으로 작성하고 API에 제출해야 합니다. 이때 작성하는 매니페스트와 API가 관리하는 리소스의 관계부터 살펴보겠습니다.

![Kubernetes 리소스와 매니페스트의 관계](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/01-resource-manifest.svg)

**매니페스트**(manifest)는 어떤 리소스를 어떤 상태로 두고 싶은지를 적은 선언입니다. 실무에서는 매니페스트를 YAML 형식으로 작성하는 경우가 많지만, JSON도 사용할 수 있습니다. YAML은 내용을 표현하는 파일 형식이고, 매니페스트는 Kubernetes API에 제출할 선언이라는 역할을 가리킵니다.

**리소스**(resource)는 Pod나 Deployment처럼 Kubernetes API로 관리하는 대상입니다. 특정 이름으로 생성된 개별 대상은 **객체**(object)라고 부릅니다. 이 글에서 리소스를 생성하거나 변경한다는 말은 이러한 객체를 API를 통해 관리한다는 뜻입니다. 각 리소스는 사용자가 선언한 원하는 상태인 `spec`과 Kubernetes가 관찰한 현재 상태인 `status`를 가질 수 있습니다. 제어 프로세스는 로컬 매니페스트 파일이 아니라 API에 저장된 리소스를 관찰하고, 리소스의 `spec`을 실제 상태로 만들기 위해 필요한 작업을 수행합니다. [[1]](#ref-1)

하나의 매니페스트 파일에는 여러 리소스 선언을 넣을 수 있고, 여러 파일로 애플리케이션에 필요한 리소스를 나누어 선언할 수도 있습니다.

Pod나 Deployment처럼 실행 상태를 선언하는 매니페스트는 다음 구조를 사용합니다. ConfigMap과 Secret처럼 `spec` 대신 다른 필드를 사용하는 리소스도 있습니다.

```yaml
# Kubernetes 매니페스트의 공통 구조를 보여 주는 예시
apiVersion: <API 그룹과 버전>
kind: <리소스 종류>
metadata:
  name: <리소스 이름>
spec:
  <원하는 상태>
```

- `apiVersion`: 사용할 API 그룹과 버전입니다.
- `kind`: 생성할 리소스의 종류입니다.
- `metadata.name`: 리소스의 이름입니다.
- `spec`: 사용자가 원하는 상태입니다.

현재 상태를 나타내는 `status`는 보통 Kubernetes가 기록하므로, 사용자가 작성하는 매니페스트에서는 생략합니다.

### 1.1 매니페스트를 통한 상태 관리의 이점

매니페스트를 사용하면 운영 설정이 터미널에 입력한 일회성 명령으로만 남지 않습니다. 어떤 리소스가 필요하고 각 리소스를 어떤 상태로 유지할지가 파일에 기록됩니다. 다른 환경에서도 같은 매니페스트를 제출하면 같은 원하는 상태를 다시 요청할 수 있으므로, 작업자의 기억에 의존하는 수동 설정을 줄일 수 있습니다.

파일로 남은 매니페스트는 Git으로 버전을 관리할 수 있습니다. 팀은 애플리케이션 코드처럼 매니페스트 변경 내용을 검토하고, 누가 어떤 설정을 바꾸었는지 변경 이력을 확인할 수 있습니다. 문제가 생기면 이전 버전의 매니페스트를 다시 제출해서 이전 매니페스트가 표현한 원하는 상태로 되돌리는 기준도 마련할 수 있습니다.

매니페스트는 자동화의 입력으로도 사용할 수 있습니다. 사람이 매번 같은 명령을 다시 조합하지 않아도 배포 파이프라인이 검토된 파일을 Kubernetes API에 제출할 수 있습니다.

파일에 기록한 설정을 클러스터에 반영하려면 `kubectl apply` 같은 명령으로 매니페스트를 제출해야 합니다. 로컬 파일을 수정하는 것만으로는 실행 중인 리소스가 바뀌지 않습니다.

### 1.2 kubectl apply를 통한 매니페스트 제출

![kubectl apply로 매니페스트를 제출하는 흐름](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/02-kubectl-apply.svg)

`kubectl apply -f`는 일반적으로 개발자의 로컬이나 CI 서버처럼 `kubectl`과 클러스터 접속 설정이 준비된 머신의 터미널에서 실행합니다. Worker Node에 직접 접속해서 명령을 실행하는 방식이 아닙니다. `kubectl`을 실행하는 머신이 네트워크를 통해 API Server에 접근할 수 있으면 됩니다.

`apply`는 매니페스트의 설정을 Kubernetes 리소스에 반영하라는 하위 명령입니다. `-f`는 `--filename`의 줄임말이며, 뒤에 적용할 매니페스트 파일의 경로를 받습니다. 아래 명령에서 `./app.yaml`은 터미널의 현재 디렉터리를 기준으로 찾는 로컬 파일입니다. 절대 경로를 적거나, 매니페스트가 들어 있는 디렉터리와 URL을 지정하는 방법도 있습니다. 즉 `-f`는 입력으로 읽을 매니페스트를 선택하고, kubeconfig의 현재 컨텍스트는 매니페스트를 제출할 클러스터를 선택합니다. [[2]](#ref-2)

```bash
# 현재 디렉터리의 매니페스트를 선택된 Kubernetes 클러스터에 제출하는 예시
kubectl apply -f ./app.yaml
```

명령을 실행하면 `kubectl`은 먼저 `app.yaml`의 매니페스트를 읽습니다. 이어서 **kubeconfig**(kubectl이 접속할 클러스터와 사용자 인증 정보를 찾는 설정)에서 현재 선택된 클러스터의 API Server 주소와 인증 정보를 확인합니다. `kubectl`은 매니페스트 내용을 API 요청으로 변환하고, 네트워크를 통해 선택된 API Server에 요청을 보냅니다.

API Server는 요청한 사용자의 신원과 권한을 확인하고, 매니페스트의 필드가 API 형식에 맞는지 검사합니다. 요청이 유효하면 API Server는 리소스가 없을 때 리소스를 새로 만들고, 같은 리소스가 있으면 매니페스트의 변경 내용을 기존 리소스에 반영합니다. 여기서 같은 리소스인지는 리소스 종류와 이름을 포함한 식별 정보로 판단합니다.

`kubectl apply`의 `created`, `configured`, `unchanged`는 각각 API 리소스가 생성되었거나 변경되었거나 변경할 내용이 없다는 뜻입니다. 애플리케이션의 실행 준비가 완료되었다는 뜻은 아니므로, 적용 후에는 Pod 상태를 따로 확인해야 합니다.

이제 매니페스트에 적은 선언이 어떤 Kubernetes 리소스로 표현되는지 하나씩 살펴보겠습니다. 먼저 컨테이너가 실제로 실행되는 최소 단위인 Pod를 살펴보고, 이어서 목적에 따라 Pod 집합을 관리하는 워크로드 리소스로 범위를 넓히겠습니다.

## 2. 컨테이너를 함께 실행하는 Pod

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/pod.svg" alt="Kubernetes 공식 Pod 리소스 마크" width="260">

### 2.1 Kubernetes가 배치하는 최소 실행 단위

![Kubernetes Pod](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/12-pod-scheduling-and-sharing.svg)

**Pod**(파드)는 하나 이상의 컨테이너를 묶어 Kubernetes가 생성하고 Node에 배치하는 최소 실행 단위입니다. 그림의 Container A와 B처럼 같은 Pod에 속한 컨테이너는 항상 같은 Node에 배치됩니다. [[3]](#ref-3)

그림 왼쪽의 **Scheduler**(스케줄러)는 Control Plane에서 실행되며, 아직 Node가 정해지지 않은 Pod에 적합한 Worker Node를 선택합니다. Scheduler는 배정 결과를 API Server에 기록합니다. Worker Node의 **Kubelet**은 자신이 실행되는 Node에 배정된 Pod를 API Server에서 확인하고, 컨테이너 런타임에 Pod 안의 컨테이너 실행을 요청합니다. 컨테이너 런타임은 이미지를 준비하고 컨테이너 프로세스를 실제로 실행하는 소프트웨어입니다. Kubelet은 이후에도 해당 Pod의 컨테이너 상태를 관리합니다.

실제로는 Pod에 애플리케이션 컨테이너 하나만 넣는 구성이 가장 흔합니다. 컨테이너가 하나뿐이어도 Kubernetes는 Pod를 통해 배치 위치와 네트워크, 스토리지, 수명주기를 일관된 단위로 관리할 수 있습니다.

컨테이너를 여러 개 넣는 기능은 서로 밀접하게 협력해야 하는 프로세스들을 하나의 실행 단위로 묶기 위해 존재합니다. 함께 배치되어야 하고 같은 네트워크나 파일을 사용해야 하며, Pod가 사라질 때 함께 정리되어야 하는 컨테이너들이 이 경계에 들어갑니다. 따라서 Pod는 단순히 컨테이너를 담는 형식이 아니라, 어떤 컨테이너들을 하나의 애플리케이션 실행 단위로 관리할지 정하는 경계입니다.

![여러 Container를 함께 묶는 Pod](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-pod.png)

Pod 안의 두 컨테이너는 위 그림처럼 실행 환경을 공유하지만, 모든 컨테이너가 언제나 동시에 재시작되는 것은 아닙니다. 컨테이너 하나가 종료되면 Kubelet은 Pod를 유지한 채 설정된 재시작 정책에 따라 해당 컨테이너만 다시 실행할 수 있습니다.

네트워크는 Pod 단위로 공유합니다. 같은 Pod의 컨테이너들은 하나의 Pod IP와 포트 공간을 함께 사용합니다. 같은 주소와 프로토콜에서 요청을 받는 프로세스는 서로 다른 포트를 사용해야 하며, 다른 컨테이너의 프로세스에는 `localhost`로 접근할 수 있습니다. 외부에서 컨테이너 하나를 직접 찾는 대신 Pod IP를 통해 Pod의 프로세스에 접근하는 이유도 이 공유 네트워크에 있습니다. [[3]](#ref-3)

스토리지도 Pod 안에서 공유할 수 있습니다. **볼륨**(volume)은 컨테이너가 사용할 저장 공간을 Pod에 연결하는 방식입니다. Pod에 볼륨을 한 번 선언하고 여러 컨테이너가 같은 볼륨을 각자의 경로에 연결하면, 컨테이너들이 같은 파일을 읽고 쓸 수 있습니다. 각 컨테이너의 기본 파일 시스템까지 하나로 합쳐지는 것은 아니며, 같은 볼륨을 연결한 경로만 공유합니다.

이러한 공유 범위 때문에 관련이 적은 애플리케이션을 하나의 Pod에 모아서는 안 됩니다. 웹 서버와 데이터베이스처럼 배포 시점과 확장 기준이 다른 애플리케이션은 서로 다른 Pod로 나누는 편이 좋습니다. 함께 배치하고 함께 삭제해야 하며 네트워크나 파일을 긴밀하게 공유하는 컨테이너만 같은 Pod에 둡니다.

### 2.2 사이드카 패턴

![사이드카가 애플리케이션 로그를 수집하는 구조](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/06-sidecar-logging.svg)

Pod의 공유 특성을 활용하는 대표 사례가 **사이드카 패턴**(sidecar pattern)입니다. 사이드카 패턴은 애플리케이션의 주 기능을 실행하는 컨테이너 옆에 보조 기능을 맡는 컨테이너를 함께 두는 구성입니다. 로그 수집, 프록시, 설정 갱신처럼 애플리케이션과 같은 실행 환경을 사용해야 하는 기능에 활용할 수 있습니다. [[4]](#ref-4)

예를 들어 애플리케이션 컨테이너가 파일에 로그를 쓰고, 로그 수집 컨테이너가 같은 파일을 읽어 외부 저장소로 보낼 수 있습니다. 두 컨테이너는 같은 Pod에 배치되고 같은 로그 볼륨을 연결하므로, 별도의 네트워크 파일 공유 없이 로그 파일을 함께 사용할 수 있습니다. 다음 매니페스트는 이러한 구조를 보여 주는 예시입니다.

```yaml
# 한 Pod 안의 두 컨테이너가 임시 볼륨을 공유하는 예시
apiVersion: v1
kind: Pod
metadata:
  name: api-app
spec:
  containers:
  - name: api
    image: my-api:1.0
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
  - name: log-agent
    image: fluentd:v1.18
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
  volumes:
  - name: app-logs
    emptyDir: {}
```

- `spec.containers`: 함께 실행할 애플리케이션 컨테이너와 로그 수집 컨테이너입니다.
- `volumeMounts`: 각 컨테이너가 사용할 볼륨을 지정합니다.
- `mountPath`: 컨테이너 안에서 볼륨을 연결할 경로입니다.
- `spec.volumes`: Pod에서 사용할 볼륨을 선언합니다.
- `emptyDir: {}`: Pod가 유지되는 동안 사용할 임시 저장 공간을 만듭니다.

두 컨테이너는 `app-logs` 볼륨을 각자의 `/var/log/app` 경로에 연결합니다. 이 예시는 볼륨 공유 구조를 보여 주며, 실제 로그 수집에는 애플리케이션의 파일 기록 설정과 로그 수집기의 입력 및 전송 설정이 추가로 필요합니다.

Pod는 교체될 수 있는 실행 단위입니다. 한 번 Worker Node에 배치된 Pod가 다른 노드로 이동하는 것은 아닙니다. 기존 Pod를 대체할 때는 새로운 고유 식별자(UID)를 가진 Pod가 만들어지며, 이름과 IP도 달라질 수 있습니다. 단독으로 만든 Pod를 삭제하면 Kubernetes가 같은 Pod를 자동으로 다시 만들지 않으므로, 장기간 운영할 애플리케이션에는 Pod 개수와 Pod 교체 과정을 관리하는 상위 리소스가 필요합니다.

이러한 역할을 위해 Kubernetes는 **Deployment**, **StatefulSet**, **DaemonSet** 같은 상위 리소스를 제공합니다. 어떤 리소스를 사용할지는 Pod를 유지하려는 목적에 따라 달라집니다. 웹 API처럼 같은 역할의 Pod를 원하는 개수만큼 유지하려면 Deployment를 사용합니다. 각 Pod에 구별되는 이름과 생성 순서가 필요하면 StatefulSet을 사용합니다. Node마다 로컬 기능을 제공해야 하면 DaemonSet을 사용합니다. 세 리소스 모두 Pod 템플릿을 사용하지만, 어떤 Pod 집합을 원하는 상태로 볼 것인지는 서로 다릅니다. 이제 이 세 가지 경우를 차례대로 살펴보겠습니다.

## 3. Pod 복제본과 배포를 관리하는 Deployment

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/deploy.svg" alt="Kubernetes 공식 Deployment 리소스 마크" width="260">

![Kubernetes Deployment](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/12-deployment.svg)

같은 역할의 Pod를 여러 개 운영할 때는 특정 Pod의 이름과 IP보다 애플리케이션을 실행할 Pod 집합을 유지하는 일이 중요합니다. Pod는 장애나 배포 과정에서 사라질 수 있고, 새로운 이름과 IP를 가진 Pod로 교체될 수 있습니다. 운영에서 유지해야 하는 대상은 특정 Pod 한 개의 정체성이 아니라, 같은 역할을 하는 Pod 집합의 상태입니다.

**Deployment**(디플로이먼트)는 이 Pod 집합의 원하는 상태를 선언하고 유지하는 상위 리소스입니다. 사용자는 어떤 구성의 Pod를 몇 개 유지할지와 Pod 구성을 어떤 방식으로 교체할지를 Deployment에 선언합니다. 이 선언을 읽는 컨트롤러가 Pod 집합의 개수와 구성을 맞춥니다. 2장에서 살펴본 제어 루프가 애플리케이션 배포에 적용되는 것입니다.

### 3.1 Deployment의 선언과 Pod 복제본 관리

아래는 웹 애플리케이션의 Pod 세 개를 유지하는 Deployment 매니페스트입니다. `replicas`에는 유지할 Pod 개수를, **Pod 템플릿**인 `template`에는 새 Pod에 적용할 이미지와 공통 설정을 적습니다. 예시에서 두 번 등장하는 `app: web`은 이 Deployment가 관리할 Pod 집합을 구분하는 데 사용합니다.

```yaml
# Pod 복제본 세 개와 Pod 템플릿을 선언하는 Deployment 예시
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: my-web:1.0
        ports:
        - containerPort: 8080
```

- `metadata.name: web`: Deployment의 이름입니다.
- `spec.replicas: 3`: 유지할 Pod 개수입니다.
- `spec.selector.matchLabels`: 관리 대상을 구분하는 조건인 **Selector**(셀렉터)입니다. 여기서는 `app: web`이라는 표시가 붙은 Pod 집합을 지정합니다.
- `spec.template`: 새 Pod에 적용할 공통 구성입니다.
- `spec.template.metadata.labels`: 새 Pod에 붙이는 키와 값 형태의 분류 정보인 **Label**(레이블)입니다. 여기서는 모든 새 Pod에 `app: web`을 붙여 Selector의 조건과 일치시킵니다.
- `spec.template.spec.containers`: 각 Pod에서 실행할 컨테이너 목록입니다.
- `image: my-web:1.0`: 애플리케이션 이미지의 예시 이름입니다.
- `containerPort: 8080`: 컨테이너가 사용할 포트를 나타냅니다. 이 선언만으로 애플리케이션이 포트를 열거나 외부 접근 경로가 만들어지지는 않습니다.

예시의 이미지는 자신의 애플리케이션 이미지로 바꿔야 합니다.

여기서 **복제본**(replica)은 같은 Pod 템플릿으로 만든 독립적인 Pod 하나를 뜻합니다. `replicas: 3`은 한 Pod 안에서 컨테이너 세 개를 실행한다는 뜻이 아니라, 같은 역할을 하는 Pod 세 개를 유지한다는 뜻입니다. 세 Pod는 각자 다른 이름과 IP를 가지며, 장애가 발생하거나 배포 구성이 바뀌면 서로 독립적으로 교체됩니다. 복제본은 Pod의 역할을 설명하는 말이며, `Replica Pod`라는 별도 리소스가 있는 것은 아닙니다.

Deployment는 내부에서 **ReplicaSet**(레플리카셋)을 만들어 Pod 개수를 유지합니다. ReplicaSet은 자신이 관리하는 Pod가 부족하면 새 Pod를 만들고, 너무 많으면 초과한 Pod를 줄입니다. 사용자는 ReplicaSet을 직접 수정하기보다 Deployment의 `replicas`와 Pod 템플릿을 변경해 원하는 상태를 전달합니다. [[5]](#ref-5)

![Deployment가 Label과 Selector로 Pod 집합을 선택하는 구조](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/07-deployment-selector.svg)

클러스터에는 웹 애플리케이션, 데이터베이스, 로그 수집기처럼 서로 다른 역할의 Pod가 함께 실행됩니다. 이때 “웹 Pod 세 개 유지”라는 요청을 처리하려면, 전체 Pod 중 어떤 Pod가 웹 애플리케이션에 속하는지 구분할 수 있어야 합니다. 개별 Pod의 이름은 서로 다르고 교체될 때 바뀔 수 있으므로, 이름 목록을 하나씩 지정하는 방식으로는 관리 대상을 계속 추적하기 어렵습니다.

**Label**의 목적은 리소스에 공통된 분류 정보를 붙여, 같은 애플리케이션이나 역할에 속한 대상을 묶어 구분하는 것입니다. 예를 들어 웹 Pod에는 `app: web`, 로그 수집기 Pod에는 `app: log-agent`를 붙일 수 있습니다. 여기서 `app`은 분류 항목을 나타내는 키이고, `web`은 그 값입니다. 이 이름은 사용자가 정하는 값이며, Kubernetes가 Pod 이름이나 컨테이너 이미지를 보고 자동으로 웹 애플리케이션이라고 판단하는 것은 아닙니다. Label을 붙이는 것만으로 Pod가 생성되거나 복제본 개수가 유지되지는 않습니다.

**Selector**의 목적은 붙어 있는 Label을 조건으로 읽어, 리소스가 관리하거나 조회할 대상의 범위를 지정하는 것입니다. Pod에 Label이 있더라도 Deployment에는 “어떤 Label이 붙은 Pod 집합을 관리할 것인가”라는 기준이 필요합니다. 위 예시의 `selector.matchLabels.app: web`은 `app`의 값이 `web`인 Pod 집합을 대상으로 삼겠다는 뜻입니다. `app: log-agent`인 Pod는 그 조건에 맞지 않으므로 웹 Pod의 복제본 개수에 포함하지 않습니다. Label이 대상에 붙이는 분류 정보라면, Selector는 그 정보로 대상을 고르는 조건입니다. [[6]](#ref-6)

이 때문에 매니페스트에 `app: web`이 두 번 등장합니다. `spec.selector.matchLabels`는 **관리 대상의 조건**을 선언하고, `spec.template.metadata.labels`는 **새로 만드는 Pod에 붙일 정보**를 선언합니다. 하나는 대상을 찾는 기준이고 다른 하나는 대상이 그 기준을 충족하도록 붙이는 값이므로, 같은 내용을 두 곳에 적더라도 역할은 다릅니다. Deployment에서는 Selector의 조건을 Pod 템플릿의 Label이 충족해야 하며, 조건이 맞지 않는 매니페스트는 API에서 거부됩니다.

예를 들어 웹 Pod 하나가 삭제되어 새 이름과 IP를 가진 Pod로 대체되어도, 새 Pod에는 템플릿에 선언된 `app: web`이 붙습니다. 따라서 기존 Selector를 바꾸지 않아도 새 Pod가 같은 관리 대상 조건을 충족합니다. 사용자가 교체될 때마다 Pod 이름 목록을 다시 작성하지 않아도 되는 이유입니다. 서로 독립적으로 관리할 애플리케이션에는 구별되는 Label 조건을 사용해 관리 범위가 겹치지 않도록 해야 합니다.

![여러 Pod의 개수와 배포 상태를 관리하는 Deployment](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-deployment.png)

Deployment에 선언한 이미지 버전을 바꾸면, 위 그림의 Pod들도 새 구성으로 교체해야 합니다. 이때 ReplicaSet을 어떻게 사용하는지 살펴보겠습니다.

### 3.2 ReplicaSet과 배포 변경

Pod 개수를 유지하던 웹 애플리케이션의 이미지를 새 버전으로 바꾼다고 가정해 보겠습니다. 이때는 기존 Pod와 새 버전의 Pod를 구분하고, 사용할 수 있는 Pod를 유지하면서 교체해야 합니다.

![Deployment가 ReplicaSet을 통해 Pod 템플릿을 교체하는 과정](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/09-deployment-replicaset-update.svg)

하나의 ReplicaSet은 특정 시점의 Pod 템플릿을 나타냅니다. Deployment의 컨테이너 이미지를 `my-web:1.0`에서 `my-web:1.1`로 바꾸면 기존 Pod를 직접 수정하지 않고 새 Pod 템플릿을 가진 ReplicaSet을 만듭니다. Deployment는 기존 ReplicaSet의 Pod 개수를 줄이는 동시에 새 ReplicaSet의 Pod 개수를 늘립니다. 기본 배포 방식에서 Deployment는 이처럼 Pod를 점진적으로 교체합니다. 이 과정을 **롤링 업데이트**(rolling update)라고 합니다. 이전 ReplicaSet의 배포 기록이 남아 있으면 사용자는 이전 Pod 템플릿으로 되돌리는 **롤백**(rollback)을 요청할 수 있습니다. [[7]](#ref-7)

## 4. 상태 저장 애플리케이션의 Pod 정체성을 유지하는 StatefulSet

![웹 서버와 데이터베이스 사례로 비교하는 Deployment와 StatefulSet](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/10-deployment-vs-statefulset-scenarios.svg)

Deployment의 Pod들은 같은 역할을 하며 서로 바꿔 쓸 수 있다는 전제를 가집니다. 웹 서버 Pod 하나가 사라지면 같은 템플릿으로 새 Pod를 만들면 되고, 클라이언트는 어느 Pod가 요청을 처리하는지 구분할 필요가 없습니다. 하지만 모든 애플리케이션을 이런 방식으로 운영할 수 있는 것은 아닙니다.

**StatefulSet**(스테이트풀셋)은 각 Pod가 구별되는 정체성을 가져야 하는 상태 저장 애플리케이션을 관리하는 워크로드 리소스입니다. StatefulSet이 만든 Pod에는 `database-0`, `database-1`처럼 순서가 있는 이름이 붙습니다. Pod가 교체되더라도 같은 순번의 이름을 다시 사용하므로 애플리케이션은 각 인스턴스를 구분할 수 있습니다.

이런 방식은 각 인스턴스를 이름으로 구분하고 정해진 순서대로 시작해야 하는 데이터베이스나 메시지 처리 애플리케이션에 활용할 수 있습니다. [[8]](#ref-8)

아래는 Pod 이름과 복제본 개수에 관련된 StatefulSet 매니페스트의 일부입니다. 배포에 필요한 전체 설정보다 Deployment와 다른 Pod 관리 방식을 확인하는 데 초점을 맞췄습니다.

```yaml
# Pod 이름과 복제본 구성을 보여 주는 StatefulSet 매니페스트 일부
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: database
        image: my-database:1.0
```

- `kind: StatefulSet`: Pod마다 구별되는 이름과 순번을 유지하는 리소스를 선택합니다.
- `metadata.name: database`: 생성되는 Pod 이름의 앞부분입니다.
- `replicas: 3`: `database-0`, `database-1`, `database-2`라는 Pod 세 개를 유지합니다.
- `selector.matchLabels`: 관리할 Pod의 Label 조건입니다.
- `template.metadata.labels`: 새 Pod에 붙일 Label이며 Selector와 일치해야 합니다.
- `template.spec.containers`: 각 Pod에서 실행할 컨테이너의 공통 구성입니다.
- `image: my-database:1.0`: 데이터베이스 이미지의 예시 이름입니다.

Deployment와 마찬가지로 Pod 템플릿과 복제본 개수를 선언하지만, Pod가 교체될 때 사용하는 이름은 다릅니다. `database-1`이 삭제되면 StatefulSet은 같은 이름의 새 Pod를 만듭니다. 이름을 다시 사용하더라도 기존 Pod가 되살아나는 것은 아니며, 새 Pod는 다른 UID를 가지고 IP도 바뀔 수 있습니다.

기본 생성 순서는 `database-0`, `database-1`, `database-2`입니다. 앞 순번의 Pod가 실행되고 준비 상태가 된 뒤 다음 Pod를 생성합니다. 복제본 개수를 3에서 2로 줄이면 가장 높은 순번인 `database-2`를 먼저 제거합니다. 이처럼 StatefulSet은 각 인스턴스를 이름으로 구분하고 순서를 지켜 관리해야 할 때 사용합니다. [[8]](#ref-8)

StatefulSet이 데이터베이스의 데이터 복제나 리더 선출까지 설정하는 것은 아닙니다. 이런 동작은 데이터베이스 자체나 별도의 운영 도구가 담당합니다.

## 5. Node마다 같은 역할을 배치하는 DaemonSet

![ReplicaSet의 애플리케이션 Pod와 Node마다 실행되는 DaemonSet Pod](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/11-daemonset-node-agents.svg)

**DaemonSet**(데몬셋)은 모든 Node 또는 조건에 맞는 일부 Node마다 Pod 하나씩을 실행하도록 관리하는 워크로드 리소스입니다. `replicas`에 고정된 개수를 선언하는 Deployment와 달리, DaemonSet의 Pod 개수는 대상 Node의 수에 따라 달라집니다. 새 Node가 추가되면 그 Node에도 Pod가 만들어지고, Node가 제거되면 해당 Pod도 정리됩니다. [[9]](#ref-9)

Node의 로그를 수집하거나 상태를 모니터링하려면 각 Node에서 같은 에이전트가 동작해야 합니다. 네트워크 플러그인이나 스토리지 드라이버처럼 Node 가까이에서 기능을 제공해야 하는 구성 요소도 같은 요구를 가집니다. 이런 프로그램을 Deployment로 몇 개만 실행하면 어떤 Node에는 에이전트가 없고 다른 Node에는 둘 이상 배치될 수 있으므로 DaemonSet이 알맞습니다.

```yaml
# app=log-agent Pod를 대상 Node마다 하나씩 실행하는 DaemonSet 예시
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-agent
spec:
  selector:
    matchLabels:
      app: log-agent
  template:
    metadata:
      labels:
        app: log-agent
    spec:
      containers:
      - name: log-agent
        image: my-log-agent:1.0
```

- `metadata.name: log-agent`: DaemonSet의 이름입니다.
- `spec.selector.matchLabels`: 관리할 Pod의 Label 조건입니다.
- `spec.template`: 대상 Node마다 생성할 Pod의 공통 구성입니다.
- `image: my-log-agent:1.0`: 로그 수집기 이미지의 예시 이름입니다.

이 예시는 Node마다 Pod를 배치하는 구조만 보여 줍니다. 실제 Node 로그 수집에는 로그 경로 연결과 수집기 설정이 추가로 필요합니다.

## 6. 실행 설정을 분리하는 ConfigMap과 Secret

지금까지 Pod를 어떤 방식으로 배치하고 유지할지 살펴보았습니다. 이제 같은 컨테이너 이미지를 서로 다른 환경에서 실행하기 위해 설정을 분리하는 방법을 알아봅니다.

컨테이너 이미지 안에 개발 환경과 운영 환경의 주소, 로그 수준, 비밀번호를 모두 넣으면 설정이 바뀔 때마다 이미지를 다시 만들어야 합니다. 민감한 값이 이미지나 매니페스트에 그대로 남을 위험도 있습니다. Kubernetes는 실행 코드와 환경별 설정을 분리하기 위해 ConfigMap과 Secret을 제공합니다.

### 6.1 일반 설정을 저장하는 ConfigMap

**ConfigMap**(컨피그맵)은 비밀이 아닌 설정을 키와 값 형태로 저장하는 리소스입니다. 같은 컨테이너 이미지를 사용하면서 개발 환경에서는 개발용 주소를, 운영 환경에서는 운영용 주소를 전달할 수 있습니다. Pod는 ConfigMap의 값을 환경 변수, 명령 인자 또는 볼륨의 설정 파일로 사용할 수 있습니다. [[10]](#ref-10)

```yaml
# 애플리케이션의 일반 설정을 저장하는 ConfigMap 예시
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  LOG_LEVEL: info
  DATABASE_HOST: database
```

- `metadata.name: web-config`: Pod에서 참조할 ConfigMap의 이름입니다.
- `data`: 애플리케이션에 전달할 설정값을 저장합니다.
- `LOG_LEVEL`: 로그 수준의 예시 값입니다.
- `DATABASE_HOST`: 데이터베이스 접속 주소의 예시 값입니다.

ConfigMap은 기밀성을 제공하지 않습니다. 비밀번호나 토큰처럼 노출되어서는 안 되는 값을 ConfigMap에 넣어서는 안 됩니다.

### 6.2 민감한 값을 저장하는 Secret

**Secret**(시크릿)은 비밀번호, 토큰, 인증서와 같은 민감한 데이터를 저장하기 위한 리소스입니다. ConfigMap처럼 Pod의 환경 변수나 볼륨 파일로 전달할 수 있지만, 민감한 값에 맞는 권한 관리와 취급 방식을 적용하기 위한 별도의 리소스 종류입니다. [[11]](#ref-11)

```yaml
# 데이터베이스 사용자 이름과 비밀번호를 저장하는 Secret 예시
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
type: Opaque
stringData:
  username: web
  password: "change-me"
```

- `metadata.name: database-credentials`: Pod에서 참조할 Secret의 이름입니다.
- `type: Opaque`: 사용자가 정의한 키와 값을 저장하는 일반적인 Secret 유형입니다.
- `stringData`: 인코딩 전 문자열을 입력하는 필드이며, API가 값을 변환해 `data`에 저장합니다.
- `username`과 `password`: 애플리케이션에 전달할 자격 증명의 예시이며, `change-me`는 실제 비밀번호가 아닙니다.

Secret을 사용한다고 값이 자동으로 완전히 보호되는 것은 아닙니다. 위처럼 `stringData`에 값을 적으면 매니페스트 파일에는 평문이 남으므로 실제 자격 증명을 담은 파일을 공개 저장소에 올려서는 안 됩니다. `data`에는 바이너리 데이터를 텍스트로 표현하는 Base64 인코딩 값을 적으며, Base64 인코딩은 암호화가 아닙니다. 기본 구성에서는 Secret이 Kubernetes API 리소스를 보관하는 데이터베이스인 **etcd**에 암호화되지 않은 형태로 저장될 수 있습니다. 운영 환경에서는 Secret을 읽을 수 있는 권한을 최소화하고, 저장 데이터 암호화와 외부 비밀 관리 방식도 함께 검토해야 합니다. [[11]](#ref-11)

### 6.3 Pod의 ConfigMap과 Secret 참조

다음 예시는 Deployment의 Pod 템플릿이 ConfigMap과 Secret의 값을 환경 변수로 가져오는 구조입니다.

```yaml
# ConfigMap과 Secret을 환경 변수로 사용하는 Deployment의 Pod 템플릿 일부
spec:
  template:
    spec:
      containers:
      - name: web
        image: my-web:1.0
        env:
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: web-config
              key: LOG_LEVEL
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: password
```

- `env[].name`: 컨테이너에 전달할 환경 변수의 이름입니다.
- `valueFrom.configMapKeyRef`: ConfigMap에서 값을 읽습니다.
- `valueFrom.secretKeyRef`: Secret에서 값을 읽습니다.
- 각 참조의 `name`: 값을 가져올 ConfigMap 또는 Secret의 이름입니다.
- 각 참조의 `key`: 해당 리소스에서 읽을 설정 항목입니다.

위 예시에서는 `web-config`의 `LOG_LEVEL`과 `database-credentials`의 `password` 값을 가져옵니다. 환경 변수로 전달한 값은 ConfigMap이나 Secret을 변경해도 이미 실행 중인 프로세스에 자동으로 갱신되지 않으므로, 새 값을 적용하려면 일반적으로 Pod를 다시 생성해야 합니다. 볼륨으로 연결한 값은 갱신될 수 있지만, 애플리케이션이 변경된 파일을 다시 읽는지도 별도로 확인해야 합니다. [[10]](#ref-10) [[11]](#ref-11)

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. 2장에서 살펴본 원하는 상태와 제어 루프가 Pod와 워크로드 리소스, 실행 설정 리소스에 어떻게 적용되는지 다음 순서로 확인했습니다.

- 매니페스트는 사용자가 원하는 상태를 API에 전달하는 입력이고, 리소스는 Kubernetes가 API에 저장하고 관리하는 객체입니다.
- Pod는 함께 실행할 컨테이너가 Node와 네트워크를 공유하고 같은 볼륨을 연결할 수 있는 최소 실행 단위입니다.
- Deployment는 같은 역할을 하는 Pod 복제본의 개수와 Pod 템플릿의 변경 과정을 관리합니다.
- StatefulSet은 각 Pod의 이름과 순번을 유지하며 상태 저장 애플리케이션의 Pod를 관리합니다.
- DaemonSet은 모든 Node 또는 조건에 맞는 Node마다 필요한 Pod를 실행합니다.
- ConfigMap과 Secret은 일반 설정과 민감한 설정을 컨테이너 이미지에서 분리합니다.

다음 글에서는 Deployment 선언이 Pod와 컨테이너 실행으로 이어지는 과정을 살펴봅니다. Pod와 컨테이너의 상태를 구분하고, 프로브를 통한 상태 검사와 정상 종료 과정을 알아봅니다. 이어서 Pod 내부의 장애와 Node 장애에 Kubernetes가 어떻게 대응하는지 확인합니다.

## 참고문헌

- <a id="ref-1"></a>[1] [리소스와 매니페스트 공식 문서](https://kubernetes.io/docs/concepts/overview/working-with-objects/)
- <a id="ref-2"></a>[2] [kubectl apply 공식 문서](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_apply/)
- <a id="ref-3"></a>[3] [Pod 공식 문서](https://kubernetes.io/docs/concepts/workloads/pods/)
- <a id="ref-4"></a>[4] [사이드카 컨테이너 공식 문서](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
- <a id="ref-5"></a>[5] [ReplicaSet 공식 문서](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- <a id="ref-6"></a>[6] [Label과 Selector 공식 문서](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- <a id="ref-7"></a>[7] [Deployment 공식 문서](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- <a id="ref-8"></a>[8] [StatefulSet 공식 문서](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- <a id="ref-9"></a>[9] [DaemonSet 공식 문서](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- <a id="ref-10"></a>[10] [ConfigMap 공식 문서](https://kubernetes.io/docs/concepts/configuration/configmap/)
- <a id="ref-11"></a>[11] [Secret 공식 문서](https://kubernetes.io/docs/concepts/configuration/secret/)
