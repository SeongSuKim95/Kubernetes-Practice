#!/usr/bin/env bash
# 모니터링 스택 설치: kube-prometheus-stack (Prometheus + Grafana).
#   - CPU / 메모리 / Pod(replica) 수 / HPA 동작을 Grafana 기본 대시보드로 관찰.
#   - 200/500 응답 "로그"는 앱 Pod 의 fluentd 사이드카가 담당(별도).
#
# 사전: install-addons.sh 완료(gp3 StorageClass 존재), helm 설치.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES="${SCRIPT_DIR}/values-kube-prometheus.yaml"
NS="monitoring"
CHART_VERSION="${CHART_VERSION:-61.3.2}"

for bin in kubectl helm; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

kubectl create namespace "${NS}" 2>/dev/null || true

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace "${NS}" \
  --version "${CHART_VERSION}" \
  -f "${VALUES}"

echo ""
echo "=== 검증 ==="
kubectl -n "${NS}" rollout status deploy/kube-prometheus-stack-grafana --timeout=300s || true
kubectl -n "${NS}" get pods

cat <<EOF

=== Grafana 접속 (private → 포트포워드) ===
  kubectl -n ${NS} port-forward svc/kube-prometheus-stack-grafana 3000:80
  브라우저: http://localhost:3000  (admin / loadtest-admin)

추천 대시보드:
  - "Kubernetes / Compute Resources / Namespace (Pods)"  → loadtest 네임스페이스 CPU
  - kube-state-metrics 기반 replica 수 변화로 HPA 스케일 관찰
EOF
