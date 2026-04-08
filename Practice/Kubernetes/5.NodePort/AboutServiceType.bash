#!/bin/bash
# AboutServiceType.bash
# 같은 nginx Pod를 가리키는 Service 두 개(ClusterIP 전용 vs NodePort)를 두고,
# 클러스터 안(curl-client Pod)과 클러스터 밖(스크립트를 실행한 호스트)에서 호출이 어떻게 다른지 확인합니다.
##
# 정리: 내부에서는 두 Service 모두 DNS 이름(또는 ClusterIP) + Service port(80)로 접근 가능합니다.
#       외부(노드 네트워크 밖/호스트)에서는 NodePort가 있는 Service만 노드IP:nodePort 경로가 열립니다.
#
# 사용: bash AboutServiceType.bash
# 정리: kubectl delete namespace compare-nodeport

set -euo pipefail

NS=compare-nodeport
NODEPORT=30081

echo "[1/5] Namespace: ${NS}"
kubectl create namespace "${NS}" 2>/dev/null || true

echo "[2/5] Backend Deployment (nginx)..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compare-nginx
  namespace: ${NS}
  labels:
    app: compare-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: compare-nginx
  template:
    metadata:
      labels:
        app: compare-nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
EOF

kubectl rollout status deployment/compare-nginx -n "${NS}" --timeout=120s

echo "[3/5] Services — 동일 selector, 타입만 다름..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: web-cip
  namespace: ${NS}
spec:
  type: ClusterIP
  selector:
    app: compare-nginx
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: web-np
  namespace: ${NS}
spec:
  type: NodePort
  selector:
    app: compare-nginx
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
    nodePort: ${NODEPORT}
EOF

echo "[4/5] curl-client Pod (Resource-Allocation LabSetUp.bash 와 동일 패턴)..."
kubectl delete pod curl-client -n "${NS}" --ignore-not-found=true
kubectl run curl-client \
  -n "${NS}" \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --command -- sh -c "sleep 36000"

kubectl wait --for=condition=Ready pod/curl-client -n "${NS}" --timeout=120s

echo "[5/5] Service 목록 (ClusterIP vs NodePort 열 비교)"
kubectl get svc -n "${NS}" -o wide

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
if [[ -z "${NODE_IP}" ]]; then
  NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
fi

CIP_CLUSTER=$(kubectl get svc web-cip -n "${NS}" -o jsonpath='{.spec.clusterIP}')
NP_CLUSTER=$(kubectl get svc web-np -n "${NS}" -o jsonpath='{.spec.clusterIP}')

echo ""
echo "========== 클러스터 안: curl-client Pod 에서 =========="
echo "--- (1) ClusterIP 타입 Service — DNS + port 80 ---"
kubectl exec -n "${NS}" curl-client -- curl -sS -o /dev/null -w "HTTP %{http_code}\n" "http://web-cip.${NS}.svc.cluster.local:80/"

echo "--- (2) NodePort 타입 Service — 역시 DNS + port 80 (내부에서는 nodePort 없이 Service port 로 충분) ---"
kubectl exec -n "${NS}" curl-client -- curl -sS -o /dev/null -w "HTTP %{http_code}\n" "http://web-np.${NS}.svc.cluster.local:80/"

echo "--- (3) NodePort 타입만 — 노드 IP + nodePort (${NODE_IP}:${NODEPORT}) 로도 접근 가능(환경에 따라 hairpin/NAT 정책 차이 있음) ---"
kubectl exec -n "${NS}" curl-client -- curl -sS -o /dev/null -w "HTTP %{http_code}\n" "http://${NODE_IP}:${NODEPORT}/" || echo "(일부 클러스터에서는 Pod 안에서 nodeIP:nodePort 가 실패할 수 있음 — 그 경우 (1)(2)만으로 내부 동작은 동일하게 이해하면 됩니다.)"

echo ""
echo "========== 클러스터 밖: 이 스크립트를 실행한 호스트에서 =========="
echo "--- (4) NodePort — 노드 IP + nodePort (${NODE_IP}:${NODEPORT}) ---"
if command -v curl >/dev/null 2>&1; then
  curl -sS -o /dev/null -w "HTTP %{http_code}\n" --connect-timeout 5 "http://${NODE_IP}:${NODEPORT}/" \
    || echo "curl 실패: 방화벽, kind/docker 네트워크, 또는 노드 주소가 호스트에서 안 보이는 경우일 수 있습니다. 수동으로 동일 URL을 시도해 보세요."
else
  echo "호스트에 curl 이 없습니다. 브라우저나 curl 로 다음을 시도: http://${NODE_IP}:${NODEPORT}/"
fi

echo "--- (5) ClusterIP 가상 주소로 직접 호출 — 보통 호스트에서는 실패(클러스터 내부 라우팅만 존재) ---"
if command -v curl >/dev/null 2>&1; then
  if curl -sS -o /dev/null -w "HTTP %{http_code}\n" --connect-timeout 3 "http://${CIP_CLUSTER}:80/" 2>/dev/null; then
    echo "(이 환경에서는 ClusterIP 가 호스트에서 열렸습니다. 대부분의 프로덕션 클러스터에서는 밖에서 ClusterIP 는 보이지 않습니다.)"
  else
    echo "예상과 같이 실패하거나 타임아웃: ClusterIP(${CIP_CLUSTER}) 는 클러스터 내부용입니다."
  fi
else
  echo "ClusterIP: ${CIP_CLUSTER} (호스트에서 일반적으로 사용 불가)"
fi

echo ""
echo "요약"
echo "  - web-cip (type=ClusterIP): 클러스터 안 O / 노드IP:고정포트 경로 X"
echo "  - web-np  (type=NodePort): 클러스터 안 O(동일하게 DNS:80) + 노드IP:${NODEPORT} 로 외부 유입 가능"
echo "  - 두 Service 의 spec.clusterIP 는 각각 다름: web-cip=${CIP_CLUSTER}, web-np=${NP_CLUSTER}"
echo ""
echo "정리: kubectl delete namespace ${NS}"
