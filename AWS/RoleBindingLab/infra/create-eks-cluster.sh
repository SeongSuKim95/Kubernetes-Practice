#!/usr/bin/env bash
# EKS 클러스터 생성 (PayFlow RoleBindingLab). eksctl 사용.
# 노드그룹 2개(general 1 + payments 1), 총 2노드.
#
# 사전: ./install-prerequisites.sh 완료 / aws configure
#
# 사용:
#   export AWS_REGION=ap-northeast-2
#   ./create-eks-cluster.sh
#
# 선택(환경변수, 기본값 있음):
#   CLUSTER_NAME(payflow-lab) K8S_VERSION(1.33) NODE_INSTANCE_TYPE(t3.medium)
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION (e.g. ap-northeast-2)}"
export CLUSTER_NAME="${CLUSTER_NAME:-payflow-lab}"
export K8S_VERSION="${K8S_VERSION:-1.33}"
export NODE_INSTANCE_TYPE="${NODE_INSTANCE_TYPE:-t3.medium}"
export AWS_REGION

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/cluster-config.yaml"

for bin in eksctl kubectl aws envsubst; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

echo "=== EKS 생성: cluster=${CLUSTER_NAME} region=${AWS_REGION} k8s=${K8S_VERSION} node=${NODE_INSTANCE_TYPE} x2 ==="

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

echo "=== 검증 (노드 pool 라벨 확인) ==="
kubectl get nodes -L payflow.io/pool -o wide

cat <<EOF

다음 단계:
  ./install-addons.sh        # metrics-server (시나리오 3 kubectl top 용)
  cd ../argocd && ./install-argocd.sh
EOF
