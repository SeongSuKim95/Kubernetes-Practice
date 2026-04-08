#!/bin/bash
set -e

# Step 1: Create namespace
kubectl create namespace relative || true

# Step 2: Create deployment from a manifest file (learners can open the YAML in vim)
cat <<'EOF' > nodeport-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeport-deployment
  namespace: relative
  labels:
    app: nodeport-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodeport-deployment
  template:
    metadata:
      labels:
        app: nodeport-deployment
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

kubectl apply -f nodeport-deployment.yaml

# Step 3: Expose deployment via NodePort
echo "Deployment 'nodeport-deployment' created in namespace 'relative'."
echo "Task: expose it via NodePort using a Service."