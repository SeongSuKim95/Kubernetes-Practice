#!/usr/bin/env bash
# EKS 클러스터 생성 (private 노드 + NAT). eksctl 사용.
#
# 사전: ./install-prerequisites.sh 완료 / aws configure / ACM 인증서 1회 발급.
#
# 사용:
#   export AWS_REGION=ap-northeast-2
#   ./create-eks-cluster.sh
#
# 선택(환경변수, 기본값 있음):
#   CLUSTER_NAME(loadtest-lab) K8S_VERSION(1.33)
#   NODE_INSTANCE_TYPE(c5.2xlarge) NODE_COUNT(5) NODE_MIN_SIZE(4) NODE_MAX_SIZE(6)
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION (e.g. ap-northeast-2)}"
export CLUSTER_NAME="${CLUSTER_NAME:-loadtest-lab}"
export K8S_VERSION="${K8S_VERSION:-1.33}"
export NODE_INSTANCE_TYPE="${NODE_INSTANCE_TYPE:-c5.2xlarge}"
export NODE_COUNT="${NODE_COUNT:-5}"
export NODE_MIN_SIZE="${NODE_MIN_SIZE:-4}"
export NODE_MAX_SIZE="${NODE_MAX_SIZE:-6}"
export AWS_REGION

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/cluster-config.yaml"

for bin in eksctl kubectl aws envsubst; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

echo "=== EKS 생성: cluster=${CLUSTER_NAME} region=${AWS_REGION} k8s=${K8S_VERSION} node=${NODE_INSTANCE_TYPE} x${NODE_COUNT} ==="

RENDERED="$(mktemp)"
trap 'rm -f "${RENDERED}"' EXIT
envsubst <"${TEMPLATE}" >"${RENDERED}"

for field in minSize maxSize desiredCapacity; do
  if ! grep -qE "${field}: [0-9]+" "${RENDERED}"; then
    echo "cluster-config 렌더 실패: ${field} 가 비어 있습니다." >&2
    echo "  NODE_MIN_SIZE / NODE_MAX_SIZE / NODE_COUNT 가 export 되었는지 확인하세요." >&2
    exit 1
  fi
done
if [[ "${NODE_MIN_SIZE}" -gt "${NODE_COUNT}" || "${NODE_COUNT}" -gt "${NODE_MAX_SIZE}" ]]; then
  echo "노드 수 불일치: NODE_MIN_SIZE(${NODE_MIN_SIZE}) <= NODE_COUNT(${NODE_COUNT}) <= NODE_MAX_SIZE(${NODE_MAX_SIZE}) 이어야 합니다." >&2
  exit 1
fi

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
