#!/bin/bash
set -euo pipefail

# setup-wordpress.sh
# Create a WordPress deployment with 3 replicas and an init container
# Also create a curl client pod to test PodIP:80 connectivity.

echo "[1/3] Apply wordpress deployment..."
cat <<EOF | kubectl apply -f -
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
        command: ["sh", "-c", "echo 'Preparing environment...' && sleep 5"]
      containers:
      - name: wordpress
        image: wordpress:6.2-apache
        ports:
        - containerPort: 80
EOF

echo "[2/3] Create curl client pod (cleanup old one if exists)..."
kubectl delete pod curl-client --ignore-not-found=true
kubectl run curl-client \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --command -- sh -c "sleep 36000"

echo "[3/3] Wait curl-client ready..."
kubectl wait --for=condition=Ready pod/curl-client --timeout=120s

echo "Setup done."
