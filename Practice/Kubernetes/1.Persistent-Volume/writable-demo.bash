#!/bin/bash
# writable-demo.bash — writable layer는 컨테이너 재시작 시 사라짐
# 사용:
#   cd Practice/Kubernetes/1.Persistent-Volume && ./writable-demo.bash
set -euo pipefail

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

echo "== [2] 재시작 전 containerID =="
before="$(kubectl get pod -l app=writable-demo -o jsonpath='{.items[0].status.containerStatuses[0].containerID}')"
echo "before=${before}"

echo "== [3] PID 1 kill -> 컨테이너 재시작 유도 =="
kubectl exec deploy/writable-demo -- sh -c 'kill 1' || true
sleep 3
kubectl wait --for=condition=Ready pod -l app=writable-demo --timeout=60s >/dev/null

echo "== [4] 재시작 후 containerID =="
after="$(kubectl get pod -l app=writable-demo -o jsonpath='{.items[0].status.containerStatuses[0].containerID}')"
echo "after=${after}"

echo "== [5] 파일 확인 (없어야 정상) =="
set +e
kubectl exec deploy/writable-demo -- cat /tmp/marker.txt
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  echo "WARN: marker.txt가 남아 있습니다. (환경에 따라 타이밍 이슈일 수 있음)"
else
  echo "OK: marker.txt가 사라졌습니다 (writable layer 초기화)."
fi

