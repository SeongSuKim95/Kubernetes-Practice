# Resource-Allocation: Preliminaries

이 실습은 **워드프레스 형태의 애플리케이션**을 쿠버네티스에 올려 두고, **Pod마다 CPU·메모리를 얼마나 요청하고, 상한을 어디까지 둘지**를 조정하는 것을 다룹니다. 앞선 이론에서 말한 것처럼 Deployment는 “원하는 개수와 원하는 Pod 모양”을 유지하는 객체이고, **실제로 노드에 얼마나 자원을 예약할지**는 Pod 안의 **각 컨테이너**에 적는 `resources`로 결정됩니다.

---

## 매니페스트(manifest)란

**매니페스트**는 쿠버네티스 API에 **어떤 리소스를 어떤 모습으로 두고 싶은지**를 담아 제출하는 정의를 가리킵니다. Deployment, Pod, Service처럼 `kind`로 구분되는 객체 하나하나가 매니페스트로 기술된 내용이며, `apiVersion`, `metadata`, `spec` 등이 **원하는 상태(desired state)** 를 구체화합니다.

> 실무에서는 **YAML 형식**으로 쓰는 경우가 많아 “YAML 파일”이라고도 부르지만, **YAML은 표현 형식(문법)** 이고, **매니페스트는 그 안에 담긴 내용의 역할**—API에 넘기는 객체 선언—을 가리키는 말입니다. 같은 내용을 JSON으로 적어도 매니페스트입니다. 이 문서부터는 그 구분을 살리기 위해 **Deployment 매니페스트**처럼 용어를 사용합니다.

---

## Deployment 매니페스트 예시

아래는 이 챕터에서 다루는 것과 비슷한 구조의 **Deployment 매니페스트** 예입니다. `spec` 아래 필드와 `template`의 `metadata` / `spec`의 역할은 **이어지는 소제목**에서 YAML 계층에 맞춰 설명합니다. 여기 적힌 CPU·메모리 숫자는 **예시**이며, 실제 클러스터의 노드 크기와 부하에 맞게 조정해야 합니다.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
spec:
  replicas: 3
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      initContainers:
        - name: init-setup
          image: busybox
          command: ["sh", "-c", "echo 'Preparing...' && sleep 5"]
          resources:
            requests:
              cpu: "300m"
              memory: "600Mi"
            limits:
              cpu: "400m"
              memory: "700Mi"
      containers:
        - name: wordpress
          image: wordpress:6.2-apache
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "300m"
              memory: "600Mi"
            limits:
              cpu: "400m"
              memory: "700Mi"
```

### `spec` — Deployment가 말하는 “목표 상태”

Deployment의 `spec`은 **이 Deployment가 관리할 Pod를 몇 개 둘지**, **어떤 라벨을 가진 Pod를 자신의 것으로 볼지**, **그 Pod를 새로 만들 때 어떤 모양으로 만들지**를 한데 묶습니다. 이 세 덩어리가 `replicas`, `selector`, `template`입니다.

#### `spec.replicas`

**언제나 유지하고 싶은 Pod의 개수(원하는 복제 수)** 입니다. 컨트롤러는 현재 실행 중인 Pod 수가 이 숫자와 다르면 부족하면 늘리고, 넘치면 줄이는 방향으로 맞춥니다. `replicas`만 바꾸는 것은 “Pod의 내용(이미지, 리소스 등)은 그대로 두고 개수만 조정”하는 경우가 많습니다.

#### `spec.selector` / `matchLabels`

Deployment가 **어떤 Pod가 “내가 관리하는 Pod”인지** 고르는 기준입니다. 보통 `matchLabels`로 `app: wordpress` 같은 **키–값 라벨**을 적고, 그 라벨이 붙은 Pod만 이 Deployment의 ReplicaSet이 관리 대상으로 삼습니다. **반드시** 아래 `template.metadata.labels`와 **같은 라벨**이 맞아야 합니다. 다르면 생성이 거부되거나, 의도치 않게 Pod가 관리되지 않을 수 있습니다.

#### `spec.template` — Pod 템플릿의 루트

`template`은 **앞으로 만든 Pod마다 공통으로 적용할 “Pod 설계도”** 입니다. Deployment는 여기에 적힌 내용으로 Pod 오브젝트를 만들고, `replicas`만큼 그런 Pod를 유지하려고 합니다. `template` 안에는 **Pod의 메타데이터**와 **Pod의 스펙**을 나누어 담는 **`metadata`**와 **`spec`** 이 다시 한 번 나옵니다(Deployment 최상위의 `metadata` / `spec`과는 **다른 단계**입니다).

##### `template.metadata` (및 Pod의 `labels`)

여기 `metadata`는 **생성되는 각 Pod**에 붙는 이름·라벨·어노테이션 등을 정의합니다. 예시의 `labels.app: wordpress`는 `spec.selector.matchLabels`와 짝을 이루어 “이 Deployment가 만든 Pod”를 식별합니다. Service가 나중에 같은 라벨로 트래픽을 보낼 때도 이 라벨이 쓰입니다.

##### `template.spec` — Pod 스펙

`template.spec`은 **Pod의 본체**에 해당합니다. `initContainers`(선행 실행), `containers`(메인·사이드카), `volumes`, `securityContext` 등 **Pod가 기동될 때의 실제 동작**을 여기에 둡니다. 이 실습에서는 **컨테이너마다 `resources`** 를 두어, 스케줄링과 실행 시 상한을 이 단계에서 정합니다.

### Init container와 일반 container의 차이

**Init container**는 같은 Pod 안에서 **메인 컨테이너가 시작되기 전에만** 순서대로 실행됩니다. 여러 개가 있으면 배열에 적힌 순서대로 하나씩 돌고, 앞 단계가 성공적으로 끝나야 다음 init이, 그리고 모든 init이 끝나야 **일반(container) 컨테이너**가 시작됩니다. 그래서 init에는 “DB 마이그레이션”, “설정 파일 복사”, “다른 서비스가 뜰 때까지 대기”처럼 **앱이 기동되기 전에 한 번 끝내야 할 준비 작업**을 두는 경우가 많습니다. init이 실패하면 Pod는 정상 기동 단계로 넘어가지 않고, 재시도·이벤트 로그 등으로 원인을 찾게 됩니다.

**일반 container**(`spec.containers`)는 우리가 흔히 말하는 **애플리케이션 본체**가 돌아가는 컨테이너입니다. init이 모두 끝난 뒤에 기동하며, 기본적으로는 **동시에 함께** 실행됩니다(사이드카 패턴처럼 Pod 안에 여러 개를 두는 경우). 네트워크·스토리지 관점에서는 같은 Pod에 속한 컨테이너들이 **같은 네트워크 네임스페이스** 등 Pod 단위 자원을 공유합니다.

리소스 관점에서는 init이든 일반이든 **각 컨테이너마다 requests와 limits를 따로 둘 수 있고**, 스케줄러가 보는 Pod의 요청량은 **init과 메인을 합친 값**입니다. 이 실습에서 “init과 메인에 **같은** requests/limits를 맞추라”고 하는 것은, 준비 단계와 서비스 단계를 **동일한 자원 기준**으로 두어 계산과 운영을 단순하게 하려는 의도에 가깝습니다.

### (보충) `command`와 `containerPort`

예시 매니페스트에 나오는 **`command`** 와 **`ports.containerPort`** 는 리소스(`resources`)와는 별개로, 컨테이너가 **무엇을 실행하고·어떤 포트로 서비스하는지**를 적는 필드입니다.

#### Init container의 `command`

`command`는 해당 컨테이너가 시작될 때 **실행할 프로세스의 명령줄**을, 이미지에 기본으로 정해진 `ENTRYPOINT`/`CMD` 대신 **덮어써서** 지정할 때 씁니다. 배열 `["실행파일", "인자1", …]` 형태는 쉘 없이 그대로 실행하기 위한 것이고, `["sh", "-c", "…"]`처럼 쉘에 한 줄짜리 스크립트를 넘기는 패턴도 흔합니다. 이 프로세스가 컨테이너 안의 PID 1이 되며, **정상 종료(exit 0)** 해야 그 init 단계가 성공입니다. 0이 아니면 실패로 처리되고, init 단계에서 Pod 진행이 막힐 수 있습니다.

#### 메인 container의 `ports` / `containerPort`

`ports` 아래의 **`containerPort`** 는 **그 컨테이너 프로세스가 Pod 안에서 리슨하는 포트 번호**를 나타낸다고 선언하는 값입니다. 예를 들어 웹 서버가 80번에서 요청을 받는다면 `80`을 적습니다. 다만 이 필드만으로 포트가 자동으로 열리거나 방화벽이 바뀌는 것은 아니고, 실제로는 애플리케이션이 그 포트에 바인드해야 합니다. `containerPort`는 **문서화·도구 연동**에 가깝고, 클러스터 안·밖으로 트래픽을 붙이려면 보통 **Service**의 `port` / `targetPort` 등으로 이어 줍니다.

---

## 컨테이너에 붙는 두 가지 숫자: requests와 limits

쿠버네티스에서 말하는 **requests**는 “이 컨테이너가 최소한 이만큼은 쓸 것이라고 가정하고, 스케줄러가 노드를 고를 때 반영하는 양”에 가깝습니다. 노드에는 CPU와 메모리마다 “남은 수용량”이 있고, 스케줄러는 새 Pod를 올릴 때 **그 Pod 안의 모든 컨테이너의 요청을 합친 값**이 그 노드에 들어갈 수 있는지를 본 뒤 배치합니다.

 그래서 “요청을 너무 크게 잡으면” 아무 노드에도 못 올라가 **스케줄되지 않은 상태**로 남을 수 있고, “요청을 작게 잡으면” 스케줄은 잘 되지만 나중에 실제 사용량이 늘었을 때 노드 전체가 빡빡해질 수 있습니다.

**limits**는 “이 컨테이너가 이 자원을 **넘어서는 안 되는 상한**”입니다. kubelet과 컨테이너 런타임이 이 값을 커널(cgroup 등)에 넘겨서 적용합니다. CPU와 메모리는 성격이 다릅니다. CPU는 상한에 가까워지면 **시간을 나누어 쓰는 방식으로 제한(스로틀)** 되는 경우가 많고, 메모리는 상한을 넘기면 **OOM(메모리 부족)으로 프로세스나 컨테이너가 죽을 수** 있습니다. 공식 문서에서는 메모리 한도가 “즉시”가 아니라 **압박이 감지될 때까지 반응적으로** 걸릴 수 있다고도 설명합니다.

---

## Pod 단위로 생각하기: 합산

requests와 limits는 **컨테이너마다** 적지만, 운영에서는 **Pod 하나가 노드에 얼마를 요구하는지**로 생각하는 편이 편합니다. 같은 리소스 타입에 대해 **Pod의 요청(또는 제한)은 각 컨테이너의 값을 더한 것**으로 이해하면 됩니다. **init 컨테이너와 메인 컨테이너가 같이 있는 Pod**에서는, “Pod 하나가 차지하는 스케줄 요청”이 **두 컨테이너의 requests를 합친 값**이 됩니다. “노드 자원을 여러 Pod에 공평히 나눈다”고 할 때도, 실제로 스케줄러가 보는 것은 **Pod당(그 안의 모든 컨테이너 포함) 합산**입니다.

---

## CPU를 할당할 때

CPU는 보통 `1`이 한 코어(또는 클라우드에서 말하는 vCPU 한 개)에 대응하고, `100m`처럼 **밀리 단위**로 잘게 씁니다. 공식 문서에서는 **너무 잘게 쓰는 값은 허용되지 않는다**고도 안내합니다. 스케줄링은 앞서 말한 대로 **요청 합**으로 이루어지고, 실행 중에는 limit 근처에서 **더 쓰고 싶어도 제한**되는 현상을 CPU 쪽에서 관찰할 수 있습니다. limit을 아예 두지 않으면, 노드에 CPU가 남아 있을 때 **다른 워크로드와 경쟁**하며 많이 쓸 수 있습니다.

---

## 메모리를 할당할 때

메모리는 바이트 기준이며 `Mi`, `Gi` 같은 접미사로 씁니다. 메모리는 요청보다 많이 쓰는 것이 **노드에 여유가 있으면** 가능하지만, limit을 넘는 사용은 **OOM으로 종료**될 수 있습니다. limit이 없으면 한 컨테이너가 노드 메모리를 크게 잡아먹어 **전체 불안정**으로 이어질 수 있고, OOM이 났을 때 **limit이 없는 워크로드가 더 불리할 수 있다**는 식의 설명도 공식 문서에 나옵니다.

---

## 관련 kubectl 명령어

- **`kubectl scale deployment`** — 지정한 Deployment의 **`spec.replicas`** 를 바꿉니다. Pod **개수**만 조정할 때 쓰며, 이미지나 `resources` 같은 **Pod 템플릿 내용**은 건드리지 않습니다(템플릿은 그대로 두고 몇 개 둘지만).

- **`kubectl edit deployment`** — 클러스터에 올라가 있는 Deployment 객체를 **에디터로 열어** 수정하고, 저장하면 API에 **적용**됩니다. 이 실습에서는 **`spec.template`** 아래 컨테이너·init 컨테이너의 **`resources`** 를 넣는 데 사용합니다. 템플릿이 바뀌면 이후 Pod 교체가 **롤링 업데이트**로 이어질 수 있습니다.

- **`kubectl rollout status deployment`** — 그 Deployment에 대한 **롤링 업데이트가 끝났는지**(진행 중·완료·실패 등)를 **끝날 때까지 기다리며** 보여 줍니다. replica를 늘린 직후나 템플릿을 바꾼 뒤에는 Pod가 아직 만들어지거나 교체되는 중일 수 있어, **검증 전에** 쓰는 편이 안전합니다.

### (보충) Deployment rollout(롤아웃)이란?

쿠버네티스에서 **Deployment의 rollout**은 Deployment가 관리하는 **Pod 템플릿(`spec.template`)** 이 바뀌었을 때, 기존 Pod들을 **새 템플릿을 가진 Pod로 점진적으로 교체**해 원하는 상태에 도달하는 과정을 말합니다. 보통은 다음 상황에서 rollout이 발생합니다.

- **이미지/환경변수/커맨드/포트/리소스(`resources`)** 등 `spec.template` 아래 내용 변경
- `kubectl set image`, `kubectl apply`로 템플릿이 바뀐 경우

이 과정에서 Deployment는 새 ReplicaSet을 만들고, 새 Pod를 늘리면서(old → new) 교체합니다(기본은 RollingUpdate 전략).

반대로 **`spec.replicas`만 바꾸는 `scale`** 은 “Pod 개수 조정”이지, Pod 템플릿 자체를 바꾸는 것이 아니므로 “새 버전으로의 교체” 의미의 rollout과는 구분해서 이해하는 편이 좋습니다.

rollout이 진행 중인지/완료됐는지를 확인할 때는 다음을 함께 자주 봅니다.

- `kubectl rollout status deployment <name>`: 완료될 때까지 대기하며 상태 출력
- `kubectl rollout history deployment <name>`: 리비전(배포 이력) 확인
- `kubectl describe deployment <name>`: 이벤트/진행 조건(Progressing/Available) 확인

---

## 이 챕터에서의 실무적 목표


1. requests는 **배치(스케줄링)** 와 직결되고, limits는 **실행 중 상한·OOM·CPU 제한**과 직결
2. Pod에 컨테이너가 여러 개면 **합산**으로 노드 부담을 계산해야 한다는 점입니다. 

