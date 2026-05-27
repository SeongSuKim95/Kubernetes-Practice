#!/bin/bash
# emptydir-demo.bash — emptyDir는 컨테이너 재시작 시 유지됨(같은 Pod)
# 사용:
#   cd Practice/Kubernetes/1.Persistent-Volume && ./emptydir-demo.bash
set -euo pipefail

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

echo "== [2] 재시작 전 containerID =="
before="$(kubectl get pod -l app=emptydir-demo -o jsonpath='{.items[0].status.containerStatuses[0].containerID}')"
echo "before=${before}"

echo "== [3] PID 1 kill -> 컨테이너 재시작 유도 =="
kubectl exec deploy/emptydir-demo -- sh -c 'kill 1' || true
sleep 3
kubectl wait --for=condition=Ready pod -l app=emptydir-demo --timeout=60s >/dev/null

echo "== [4] 재시작 후 containerID =="
after="$(kubectl get pod -l app=emptydir-demo -o jsonpath='{.items[0].status.containerStatuses[0].containerID}')"
echo "after=${after}"

echo "== [5] 파일 확인 (남아 있어야 정상) =="
kubectl exec deploy/emptydir-demo -- cat /emptydir/marker.txt
echo "OK: marker.txt 유지됨 (emptyDir는 같은 Pod에서 유지)."

