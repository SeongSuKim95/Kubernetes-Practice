#!/usr/bin/env bash
# 클러스터 애드온 설치 (RoleBindingLab): metrics-server 만.
#   - 시나리오 3에서 'kubectl top nodes/pods' 로 자원 압박을 관측하기 위함.
#   - ALB Controller / EBS CSI 는 이 랩에 불필요하므로 설치하지 않음.
#
# 사전: create-eks-cluster.sh 완료.
#
# 사용:
#   export AWS_REGION=ap-northeast-2
#   ./install-addons.sh
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
CLUSTER_NAME="${CLUSTER_NAME:-payflow-lab}"

for bin in kubectl aws; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

metrics_server_present() {
  kubectl get deploy -n kube-system metrics-server &>/dev/null \
    || aws eks list-addons --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
         --query 'addons' --output text 2>/dev/null | grep -qw metrics-server
}

# EKS 애드온 Pod 라벨과 upstream manifest 의 Service selector 불일치 시
# endpoints 가 비어 Metrics API not available 가 난다. selector 를 EKS Pod 에 맞춘다.
fix_metrics_server_service() {
  if ! kubectl get svc -n kube-system metrics-server &>/dev/null; then
    return 0
  fi
  local endpoints
  endpoints="$(kubectl -n kube-system get endpoints metrics-server -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
  if [[ -n "${endpoints}" ]]; then
    echo "[metrics-server] Service endpoints 정상 — selector 수정 불필요"
    return 0
  fi
  if ! kubectl get deploy -n kube-system metrics-server &>/dev/null; then
    return 0
  fi
  echo "[metrics-server] endpoints 비어 있음 — Service selector 를 EKS 애드온 Pod 라벨에 맞춤"
  kubectl -n kube-system patch svc metrics-server --type=json -p='[
    {"op": "replace", "path": "/spec/selector", "value": {
      "app.kubernetes.io/instance": "metrics-server",
      "app.kubernetes.io/name": "metrics-server"
    }}
  ]'
}

wait_metrics_server_ready() {
  fix_metrics_server_service
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
  local i
  for i in 1 2 3 4 5 6; do
    if kubectl top nodes &>/dev/null; then
      echo "metrics API 동작 확인 (kubectl top nodes):"
      kubectl top nodes
      return 0
    fi
    echo "metrics API 준비 대기 (${i}/6)..."
    sleep 10
  done
  echo "metrics API 미동작 — 'kubectl get apiservice v1beta1.metrics.k8s.io' 확인" >&2
  kubectl get apiservice v1beta1.metrics.k8s.io 2>/dev/null || true
  return 1
}

echo "=== metrics-server ==="
if metrics_server_present; then
  echo "metrics-server 가 이미 설치됨. upstream manifest apply 건너뜀."
  wait_metrics_server_ready
else
  echo "metrics-server 없음 — upstream manifest 설치"
  kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  wait_metrics_server_ready
fi

echo ""
echo "완료. 다음: cd ../argocd && ./install-argocd.sh"
