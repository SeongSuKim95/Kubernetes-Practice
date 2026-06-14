#!/usr/bin/env bash
# Argo CD 설치 + PayFlow Application 등록(app-manifests/ 를 GitOps 로 동기화).
# 시나리오별 Application 4개(bootstrap/rbac/taint/priority)를 등록합니다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="argocd"

command -v kubectl >/dev/null 2>&1 || { echo "kubectl 없음" >&2; exit 1; }

echo "=== Argo CD 설치 ==="
kubectl create namespace "${NS}" 2>/dev/null || true
# server-side apply: ApplicationSet CRD 가 커서 client-side apply 시 annotation 256KB 초과 방지
kubectl apply --server-side --force-conflicts -n "${NS}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== argocd-server 기동 대기 ==="
kubectl -n "${NS}" rollout status deploy/argocd-server --timeout=300s

echo "=== PayFlow Application 등록 ==="
kubectl apply -f "${SCRIPT_DIR}/applications.yaml"

echo ""
echo "=== 초기 admin 비밀번호 ==="
kubectl -n "${NS}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(secret 없음 - 이미 변경됨?)"
echo ""

cat <<EOF

=== Argo CD UI 접속 (포트포워드) ===
  kubectl -n ${NS} port-forward svc/argocd-server 8080:443
  브라우저: https://localhost:8080  (admin / 위 비밀번호)

등록된 Application:
  payflow-bootstrap  (namespaces)
  payflow-rbac       (시나리오 1)
  payflow-taint      (시나리오 2)
  payflow-priority   (시나리오 3)

app-manifests/ 를 수정→git push 하면 Argo CD 가 자동 sync 합니다.
EOF
