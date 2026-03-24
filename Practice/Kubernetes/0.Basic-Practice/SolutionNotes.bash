#!/bin/bash
set -euo pipefail

NS="dev"
OTHER_NS="prod"

# 1) Namespace 생성
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "${OTHER_NS}" --dry-run=client -o yaml | kubectl apply -f -
kubectl get ns

# 2) Pod 기본 실습
cat <<'EOF' > pod-web.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
  namespace: dev
  labels:
    app: web-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
EOF
kubectl apply -f pod-web.yaml
kubectl -n "${NS}" get pod web-pod

# 단일 Pod 삭제 비교: 자동 복구되지 않음
kubectl -n "${NS}" delete pod web-pod
kubectl -n "${NS}" get pod web-pod || echo "web-pod not found (expected)"

# 3) Deployment 기본 실습
cat <<'EOF' > deploy-ok.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-nginx
  namespace: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-nginx
  template:
    metadata:
      labels:
        app: hello-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
EOF
kubectl apply -f deploy-ok.yaml
kubectl -n "${NS}" get deploy,pod -l app=hello-nginx

# Deployment Pod 삭제 비교: 자동 복구됨 (self-healing)
POD_TO_DELETE=$(kubectl -n "${NS}" get pod -l app=hello-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl -n "${NS}" delete pod "${POD_TO_DELETE}"
kubectl -n "${NS}" get pod -l app=hello-nginx

# 4) Service 기본 실습
cat <<'EOF' > svc-ok.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-svc
  namespace: dev
spec:
  type: ClusterIP
  selector:
    app: hello-nginx
  ports:
  - port: 80
    targetPort: 80
EOF
kubectl apply -f svc-ok.yaml
kubectl -n "${NS}" get svc,ep hello-svc

# Pod 직접 호출 vs Service 호출 비교
TARGET_POD=$(kubectl -n "${NS}" get pod -l app=hello-nginx -o jsonpath='{.items[0].metadata.name}')
TARGET_POD_IP=$(kubectl -n "${NS}" get pod "${TARGET_POD}" -o jsonpath='{.status.podIP}')
echo "Target Pod: ${TARGET_POD} (${TARGET_POD_IP})"

# 4-1) Pod IP 직접 호출: 특정 Pod 인스턴스를 직접 때림
kubectl -n "${NS}" exec curl-client -- sh -c "curl -sS ${TARGET_POD_IP} | head -n 1"

# 4-2) Service DNS 호출: Service가 선택한 Pod들로 라우팅
kubectl -n "${NS}" exec curl-client -- sh -c "curl -sS hello-svc | head -n 1"

# 특정 Pod 삭제 후 비교
kubectl -n "${NS}" delete pod "${TARGET_POD}"
sleep 3
kubectl -n "${NS}" get pod -l app=hello-nginx

# Pod IP 직접 호출은 실패(삭제된 Pod IP)
kubectl -n "${NS}" exec curl-client -- sh -c "curl -m 3 -sS ${TARGET_POD_IP} || echo 'direct pod ip failed (expected)'"

# Service 호출은 계속 성공(새 Pod로 라우팅)
kubectl -n "${NS}" exec curl-client -- sh -c "curl -sS hello-svc | head -n 1"

# 5) Label 매칭 핵심 실습

# 5-1) Deployment selector mismatch (실패 예시)
cat <<'EOF' > deploy-bad-selector.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-deploy-selector
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mismatch-a
  template:
    metadata:
      labels:
        app: mismatch-b
    spec:
      containers:
      - name: nginx
        image: nginx:latest
EOF
kubectl apply -f deploy-bad-selector.yaml || true

# 5-2) Service metadata.labels가 달라도 selector가 맞으면 정상
cat <<'EOF' > svc-bad-metadata-label.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-svc-badmeta
  namespace: dev
  labels:
    app: different-meta
spec:
  selector:
    app: hello-nginx
  ports:
  - port: 80
    targetPort: 80
EOF
kubectl apply -f svc-bad-metadata-label.yaml
kubectl -n "${NS}" get svc,ep hello-svc-badmeta

# 5-3) Service selector 불일치 시 endpoint 없음
cat <<'EOF' > svc-bad-selector.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-svc-badselector
  namespace: dev
spec:
  selector:
    app: no-such-pod
  ports:
  - port: 80
    targetPort: 80
EOF
kubectl apply -f svc-bad-selector.yaml
kubectl -n "${NS}" get svc,ep hello-svc-badselector
# expected: endpoints <none>
kubectl -n "${NS}" exec curl-client -- sh -c 'curl -m 3 -sS hello-svc-badselector || echo "curl failed (expected: no endpoints)"'

# 6) Namespace 경계 실습 (prod)
cat <<'EOF' > ns-boundary.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-nginx
  namespace: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-nginx
  template:
    metadata:
      labels:
        app: hello-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
---
apiVersion: v1
kind: Service
metadata:
  name: hello-svc
  namespace: prod
spec:
  selector:
    app: hello-nginx
  ports:
  - port: 80
    targetPort: 80
EOF
kubectl apply -f ns-boundary.yaml
kubectl -n "${OTHER_NS}" get deploy,svc,ep

# 최종 확인
kubectl -n "${NS}" get pod,deploy,svc,ep
kubectl -n "${OTHER_NS}" get deploy,svc,ep
