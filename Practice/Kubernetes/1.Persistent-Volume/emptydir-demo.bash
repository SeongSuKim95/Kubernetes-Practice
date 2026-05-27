#!/bin/bash
# emptydir-demo.bash — emptyDir는 컨테이너 재시작 시 유지됨(같은 Pod)
# 사용:
#   cd Practice/Kubernetes/1.Persistent-Volume && ./emptydir-demo.bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=demo-restart-helper.bash
source "${SCRIPT_DIR}/demo-restart-helper.bash"

cleanup() {
  kubectl delete deploy/emptydir-demo --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: emptydir-demo
  labels:
    app: emptydir-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: emptydir-demo
  template:
    metadata:
      labels:
        app: emptydir-demo
    spec:
      containers:
        - name: app
          image: busybox:stable
          command: ["sleep", "infinity"]
          volumeMounts:
            - name: emptydir-vol
              mountPath: /emptydir
      volumes:
        - name: emptydir-vol
          emptyDir: {}
EOF

kubectl rollout status deploy/emptydir-demo --timeout=60s >/dev/null

echo "== [1] emptyDir에 파일 생성 =="
kubectl exec deploy/emptydir-demo -- sh -c 'echo "storage-lab-emptydir" > /emptydir/marker.txt && cat /emptydir/marker.txt'

echo "== [2] 컨테이너 재시작 (같은 Pod 유지) =="
force_container_restart emptydir-demo emptydir-demo || exit 1

echo "== [3] 파일 확인 (남아 있어야 정상) =="
kubectl exec deploy/emptydir-demo -- cat /emptydir/marker.txt
echo "OK: marker.txt 유지됨 (emptyDir는 같은 Pod에서 유지)."
