#!/usr/bin/env bash
# EKS 클러스터 생성 (private 노드 + NAT). eksctl 사용.
#
# 사전: aws CLI v2, eksctl, kubectl 설치 / aws configure 완료 / ACM 인증서 1회 발급.
#
# 사용:
#   export AWS_REGION=ap-northeast-2
#   ./create-eks-cluster.sh
#
# 선택(환경변수, 기본값 있음):
#   CLUSTER_NAME(loadtest-lab) NODE_INSTANCE_TYPE(t3.medium) NODE_COUNT(3)
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION (e.g. ap-northeast-2)}"
export CLUSTER_NAME="${CLUSTER_NAME:-loadtest-lab}"
export NODE_INSTANCE_TYPE="${NODE_INSTANCE_TYPE:-t3.medium}"
export NODE_COUNT="${NODE_COUNT:-3}"
export AWS_REGION

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/cluster-config.yaml"

for bin in eksctl kubectl aws envsubst; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

echo "=== EKS 생성: cluster=${CLUSTER_NAME} region=${AWS_REGION} node=${NODE_INSTANCE_TYPE} x${NODE_COUNT} ==="

RENDERED="$(mktemp)"
trap 'rm -f "${RENDERED}"' EXIT
envsubst <"${TEMPLATE}" >"${RENDERED}"

if eksctl get cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "이미 존재하는 클러스터(${CLUSTER_NAME}). 생성 건너뜀."
else
  eksctl create cluster -f "${RENDERED}"
fi

echo "=== kubeconfig 업데이트 ==="
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

echo "=== 검증 ==="
kubectl get nodes -o wide

cat <<EOF

다음 단계:
  ./install-addons.sh        # ALB Controller + metrics-server + gp3(EBS CSI)
EOF
