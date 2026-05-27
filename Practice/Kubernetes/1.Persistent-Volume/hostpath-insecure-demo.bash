#!/bin/bash
# hostpath-insecure-demo.bash — hostPath로 노드 루트를 노출하는 위험 데모(학습용)
# 사용:
#   cd Practice/Kubernetes/1.Persistent-Volume && ./hostpath-insecure-demo.bash
set -euo pipefail

cleanup() {
  kubectl delete deploy/hostpath-insecure-demo --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hostpath-insecure-demo
  labels:
    app: hostpath-insecure-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hostpath-insecure-demo
  template:
    metadata:
      labels:
        app: hostpath-insecure-demo
    spec:
      containers:
        - name: app
          image: busybox:stable
          command: ["sleep", "infinity"]
          volumeMounts:
            - name: node-root
              mountPath: /node-root
      volumes:
        - name: node-root
          hostPath:
            path: /
            type: Directory
EOF

kubectl rollout status deploy/hostpath-insecure-demo --timeout=60s >/dev/null

echo "== [1] 노드 파일시스템 일부 조회 (/var/log) =="
kubectl exec deploy/hostpath-insecure-demo -- sh -c 'ls -l /node-root/var/log | head -n 20' || true

echo "== [2] 컨테이너 유저 확인(대개 root) =="
kubectl exec deploy/hostpath-insecure-demo -- whoami

echo "OK: hostPath로 노드 루트가 노출될 수 있음을 확인."

