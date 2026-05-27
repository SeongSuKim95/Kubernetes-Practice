#!/bin/bash
# writable-demo.bash — writable layer는 컨테이너 재시작 시 사라짐
# 사용:
#   cd Practice/Kubernetes/1.Persistent-Volume && ./writable-demo.bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=demo-restart-helper.bash
source "${SCRIPT_DIR}/demo-restart-helper.bash"

cleanup() {
  kubectl delete deploy/writable-demo --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: writable-demo
  labels:
    app: writable-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: writable-demo
  template:
    metadata:
      labels:
        app: writable-demo
    spec:
      containers:
        - name: app
          image: busybox:stable
          command: ["sleep", "infinity"]
EOF

kubectl rollout status deploy/writable-demo --timeout=60s >/dev/null

echo "== [1] writable layer에 파일 생성 =="
kubectl exec deploy/writable-demo -- sh -c 'echo "storage-lab-writable" > /tmp/marker.txt && cat /tmp/marker.txt'

echo "== [2] 컨테이너 재시작 (같은 Pod 유지) =="
force_container_restart writable-demo writable-demo || exit 1

echo "== [3] 파일 확인 (없어야 정상) =="
set +e
kubectl exec deploy/writable-demo -- cat /tmp/marker.txt
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  echo "WARN: marker.txt가 남아 있습니다." >&2
  exit 1
else
  echo "OK: marker.txt가 사라졌습니다 (writable layer 초기화)."
fi
