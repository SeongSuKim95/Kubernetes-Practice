# Service 연결 진단 보관용 초안

> `Chap03. 서비스 운영에 필요한 핵심 리소스`에서 분리한 보관용 초안입니다. 정식 Chap 구성과 연재 순서는 정하지 않았습니다.

## Service에 연결할 Pod가 보이지 않을 때

Service의 가상 IP가 만들어졌는데 요청이 실패한다면, 먼저 Service 셀렉터와 Pod 레이블을 확인해야 합니다. Service 셀렉터가 Pod 레이블과 다르거나, 일치하는 Pod가 준비되지 않았으면 Service가 요청을 전달할 대상을 찾지 못합니다.

**EndpointSlice**(엔드포인트슬라이스)는 Service가 현재 요청을 전달할 Pod IP와 포트, 준비 상태를 저장하는 리소스입니다. Service와 Pod가 정상적으로 연결되었는지는 Service에 연결된 EndpointSlice에 대상 주소가 들어 있는지 확인해서 판단할 수 있습니다.

```bash
# Service 셀렉터와 일치하는 Pod와 요청 전달 대상을 확인하는 명령
kubectl -n dev get service web
kubectl -n dev get pods -l app=web --show-labels
kubectl -n dev get endpointslices \
  -l kubernetes.io/service-name=web
```

정상 상태에서는 Service 정보와 `app=web` 레이블을 가진 Pod가 보이고, EndpointSlice에 Pod IP와 애플리케이션 포트가 표시됩니다.

```text
NAME   TYPE        CLUSTER-IP      PORT(S)   AGE
web    ClusterIP   10.96.120.15    80/TCP    2m

NAME                   READY   STATUS    LABELS
web-7d9c7f8b6f-k2m4p    1/1     Running   app=web

NAME          ADDRESSTYPE   PORTS   ENDPOINTS      AGE
web-8x7pq     IPv4          8080    10.244.1.12   2m
```

EndpointSlice에 요청 대상이 없다면 Service의 `spec.selector`와 Pod의 `metadata.labels`가 같은지 확인합니다. 레이블이 맞는데도 요청 대상이 비어 있다면 Pod의 `READY` 상태와 Readiness Probe 결과를 확인합니다. Pod 이벤트에는 이미지 다운로드 실패와 Probe 실패처럼 Pod가 준비되지 못한 원인이 기록될 수 있습니다.

```bash
# 준비되지 않은 Pod의 상태와 이벤트를 확인하는 명령
kubectl -n dev describe pod -l app=web
kubectl -n dev get events --sort-by=.metadata.creationTimestamp
```

```text
Conditions:
  Type    Status
  Ready   False

Events:
  Type     Reason      Message
  Warning  Unhealthy   Readiness probe failed: HTTP probe failed with statuscode: 503
```

`describe` 출력의 `Conditions`와 `Events`에서 `Ready=False` 또는 `Readiness probe failed`를 확인할 수 있습니다. 이미지 이름이 잘못되었다면 `ErrImagePull`이나 `ImagePullBackOff` 상태가 나타날 수 있습니다. 증상을 확인한 뒤 Service 셀렉터, Pod 레이블, Readiness Probe, 컨테이너 이미지 순서로 원인을 좁히면 연결 문제를 찾기 쉽습니다.
