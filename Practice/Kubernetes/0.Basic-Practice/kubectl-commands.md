# 0.Basic-Practice에서 사용하는 kubectl 명령어 요약

이 실습은 `dev`/`prod` 네임스페이스에서 **Pod vs Deployment**, **Service vs Endpoints**, **라벨/셀렉터**, **네임스페이스 경계(DNS 스코프)**를 `kubectl`로 직접 검증합니다.

---

## 네임스페이스 생성/확인

- `kubectl get ns`
  - 네임스페이스 목록을 조회합니다.

- `kubectl get namespace <name>`
  - 특정 네임스페이스가 존재하는지 확인합니다.

- `kubectl create namespace <name> --dry-run=client -o yaml | kubectl apply -f -`
  - “있으면 유지/없으면 생성” 스타일로 네임스페이스를 만들기 위한 패턴입니다.
  - `--dry-run=client -o yaml`로 YAML을 출력하고, 그 YAML을 `apply`로 적용합니다.

- `kubectl -n <namespace> ...`
  - 이후 모든 조회/생성/삭제/실행을 특정 네임스페이스 범위로 제한합니다. (예: `-n dev`)

---

## 리소스 생성/변경(선언형)과 삭제

- `kubectl apply -f <file.yaml>`
  - YAML(선언형)로 리소스를 생성/변경합니다.
  - 같은 파일을 여러 번 적용해도 “원하는 상태(Desired State)”로 맞추는 방식입니다.

- `kubectl delete <resource> <name> --ignore-not-found=true`
  - 리소스를 삭제하되, 없어도 에러를 내지 않고 넘어갑니다.
  - 실습 재시작 시 기존 리소스 정리(클린업)에 사용됩니다.

---

## 조회(get)와 핵심 리소스들

- `kubectl -n <ns> get pod <name>`
  - 특정 Pod의 존재/상태를 확인합니다.

- `kubectl -n <ns> get deploy,pod -l app=<label>`
  - 라벨 셀렉터(`-l`)로 Deployment와 Pod를 한 번에 조회합니다.

- `kubectl -n <ns> get svc,ep <service-name>`
  - Service(`svc`)와 Endpoints(`ep`)를 함께 봅니다.
  - **Service selector가 Pod labels와 매칭**되면 Endpoints에 대상(Pod IP:Port)이 잡힙니다.
  - selector가 불일치하면 `endpoints <none>`처럼 비어있을 수 있습니다.

---

## Pod vs Deployment: 삭제 시 동작 차이(Self-Healing)

- `kubectl -n <ns> delete pod <pod-name>`
  - **단독 Pod**는 삭제하면 그대로 사라집니다(자동 복구 없음).
  - **Deployment가 만든 Pod**는 삭제해도 Deployment의 Desired State에 의해 새 Pod가 다시 생성됩니다(Self-Healing).

---

## 임시/보조 Pod 실행과 대기

- `kubectl -n <ns> run curl-client --image=curlimages/curl:8.10.1 --restart=Never --command -- sh -c "sleep 36000"`
  - 클러스터 내부에서 `curl` 테스트를 하기 위한 “클라이언트 Pod”를 띄웁니다.
  - `--restart=Never`는 Deployment가 아닌 **Pod 1개**로 실행한다는 의미입니다.

- `kubectl -n <ns> wait --for=condition=Ready pod/curl-client --timeout=120s`
  - Pod가 Ready 상태가 될 때까지 기다립니다.
  - 바로 `exec`를 해야 하는 실습 흐름에서 “준비될 때까지 대기”용으로 사용합니다.

---

## Pod 내부에서 실행(exec): Pod IP 직접 호출 vs Service 호출

- `kubectl -n <ns> exec curl-client -- sh -c "curl -sS <pod-ip> | head -n 1"`
  - 특정 **Pod IP**로 직접 호출합니다(해당 Pod 인스턴스에 고정).
  - 그 Pod가 삭제/재생성되면 해당 IP는 무효가 될 수 있습니다.

- `kubectl -n <ns> exec curl-client -- sh -c "curl -sS hello-svc | head -n 1"`
  - **Service DNS**로 호출합니다(고정 접근점).
  - Pod가 교체되어도 Service가 Endpoints를 따라가므로 일반적으로 계속 성공합니다.

- `kubectl -n <ns> exec curl-client -- sh -c "curl -m 3 -sS <target> || echo 'failed (expected)'" `
  - `-m 3`은 타임아웃(최대 3초)으로, “엔드포인트 없음/대상 삭제” 같은 상황에서 오래 멈추지 않게 합니다.

---

## jsonpath로 값 추출(스크립트 자동화에서 자주 사용)

- `kubectl -n <ns> get pod -l app=hello-nginx -o jsonpath='{.items[0].metadata.name}'`
  - 조회 결과(JSON)에서 첫 번째 Pod 이름만 뽑습니다.

- `kubectl -n <ns> get pod <pod-name> -o jsonpath='{.status.podIP}'`
  - 해당 Pod의 IP를 뽑습니다.

이 패턴은 스크립트에서 “대상 Pod를 찾고 → IP를 뽑고 → curl로 테스트” 같은 흐름을 자동화할 때 유용합니다.

---

## 라벨/셀렉터 실수 시나리오에서 보는 포인트

- Deployment의 `spec.selector.matchLabels`와 `spec.template.metadata.labels`가 다르면
  - 검증 에러로 생성이 실패하거나, 의도한 매칭이 깨집니다.

- Service는 `metadata.labels`가 달라도
  - `spec.selector`만 맞으면 Endpoints가 잡히고 통신은 정상입니다.

- Service의 `spec.selector`가 Pod labels와 불일치하면
  - Endpoints가 비어서 `curl`이 실패/타임아웃될 수 있습니다.

---

## 네임스페이스 경계

같은 이름의 `hello-nginx` Deployment / `hello-svc` Service라도 `dev`와 `prod`에 각각 만들면 **서로 다른 리소스**입니다.
실습에서는 이를 통해 네임스페이스가 운영 경계(격리 단위)임을 확인합니다.

