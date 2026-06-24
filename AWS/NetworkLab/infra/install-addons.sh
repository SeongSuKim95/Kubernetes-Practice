#!/usr/bin/env bash
# 클러스터 애드온 설치 (NetworkLab):
#   1) Gateway API 표준 CRD (v1.1.0)
#   2) NGINX Gateway Fabric (Gateway API 컨트롤러 — GatewayClass 'nginx' 생성)
#   3) VPC CNI NetworkPolicy 집행 활성 확인
#
# 사전: create-eks-cluster.sh 완료, helm 설치.
#
# 사용:
#   ./install-addons.sh
set -euo pipefail

GW_API_VERSION="${GW_API_VERSION:-v1.1.0}"   # Gateway API 표준 CRD 버전
NGF_VERSION="${NGF_VERSION:-1.4.0}"          # NGINX Gateway Fabric chart 버전
NGF_NS="nginx-gateway"

for bin in kubectl helm; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

echo "=== [1/3] Gateway API 표준 CRD (${GW_API_VERSION}) ==="
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GW_API_VERSION}/standard-install.yaml"

echo "=== [2/3] NGINX Gateway Fabric (${NGF_VERSION}) ==="
helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version "${NGF_VERSION}" \
  --create-namespace -n "${NGF_NS}"

echo "=== nginx-gateway 컨트롤러 기동 대기 ==="
kubectl -n "${NGF_NS}" rollout status deploy/ngf-nginx-gateway-fabric --timeout=300s 2>/dev/null || \
  kubectl -n "${NGF_NS}" rollout status deploy -l app.kubernetes.io/name=nginx-gateway-fabric --timeout=300s

echo "=== GatewayClass 확인 (nginx 존재해야 함) ==="
kubectl get gatewayclass

echo ""
echo "=== [3/3] VPC CNI NetworkPolicy 집행 활성 확인 (true 여야 함) ==="
kubectl -n kube-system get ds aws-node \
  -o jsonpath='{range .spec.template.spec.containers[*].env[?(@.name=="ENABLE_NETWORK_POLICY")]}{.name}={.value}{"\n"}{end}' || true

echo ""
echo "완료. 다음: cd ../argocd && ./install-argocd.sh"
