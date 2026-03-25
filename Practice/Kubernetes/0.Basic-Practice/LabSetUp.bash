#!/bin/bash
set -euo pipefail

NS="dev"
OTHER_NS="prod"

echo "[1/5] Check required namespaces..."
echo "[1/5] Ensure required namespaces exist..."
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "${OTHER_NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "[2/5] Cleanup old resources in ${NS}..."
kubectl -n "${NS}" delete svc hello-svc hello-svc-badmeta hello-svc-badselector web-pod-svc --ignore-not-found=true
kubectl -n "${NS}" delete deploy hello-nginx --ignore-not-found=true
kubectl -n "${NS}" delete pod web-pod curl-client --ignore-not-found=true

echo "[3/5] Cleanup old resources in ${OTHER_NS}..."
kubectl -n "${OTHER_NS}" delete svc hello-svc --ignore-not-found=true
kubectl -n "${OTHER_NS}" delete deploy hello-nginx --ignore-not-found=true

echo "[4/5] Create curl client pod..."
kubectl -n "${NS}" run curl-client \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --command -- sh -c "sleep 36000"

echo "[5/5] Wait curl-client ready..."
kubectl -n "${NS}" wait --for=condition=Ready pod/curl-client --timeout=120s

echo "Setup done."
echo "Current namespace: ${NS}"
