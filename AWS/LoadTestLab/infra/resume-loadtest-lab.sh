#!/usr/bin/env bash
# LoadTestLab 재개 — 저장된 노드 수로 scale 복원 + loadtest EC2 start
#
# 사용:
#   export AWS_REGION=ap-northeast-2
#   ./resume-loadtest-lab.sh
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION (e.g. ap-northeast-2)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${STATE_FILE:-${SCRIPT_DIR}/.loadtest-lab-pause-state.env}"

CLUSTER_NAME="${CLUSTER_NAME:-loadtest-lab}"
NODEGROUP_NAME="${NODEGROUP_NAME:-ng-workload}"
LOADTEST_EC2_TAG="${LOADTEST_EC2_TAG:-loadtest-ec2}"
NODE_COUNT="${NODE_COUNT:-5}"
NODE_MIN_SIZE="${NODE_MIN_SIZE:-4}"
NODE_MAX_SIZE="${NODE_MAX_SIZE:-6}"

if [[ -f "${STATE_FILE}" ]]; then
  echo "상태 파일 로드: ${STATE_FILE}"
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
fi

for bin in aws eksctl kubectl; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

if [[ "${NODE_MIN_SIZE}" -gt "${NODE_COUNT}" || "${NODE_COUNT}" -gt "${NODE_MAX_SIZE}" ]]; then
  echo "노드 수 불일치: NODE_MIN_SIZE(${NODE_MIN_SIZE}) <= NODE_COUNT(${NODE_COUNT}) <= NODE_MAX_SIZE(${NODE_MAX_SIZE})" >&2
  exit 1
fi

echo "=== LoadTestLab 재개 ==="
echo "  cluster=${CLUSTER_NAME} nodes=${NODE_COUNT} (${NODE_MIN_SIZE}..${NODE_MAX_SIZE})"

INSTANCE_IDS=$(aws ec2 describe-instances --region "${AWS_REGION}" \
  --filters \
    "Name=tag:Name,Values=${LOADTEST_EC2_TAG}" \
    "Name=instance-state-name,Values=stopped,stopping" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text | tr '\t' ' ')

if [[ -n "${INSTANCE_IDS// }" ]]; then
  echo "LoadTest EC2 start: ${INSTANCE_IDS}"
  # shellcheck disable=SC2086
  aws ec2 start-instances --region "${AWS_REGION}" --instance-ids ${INSTANCE_IDS}
  # shellcheck disable=SC2086
  aws ec2 wait instance-running --region "${AWS_REGION}" --instance-ids ${INSTANCE_IDS}
  PUBLIC_IP=$(aws ec2 describe-instances --region "${AWS_REGION}" \
    --instance-ids ${INSTANCE_IDS} \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  echo "LoadTest EC2 PublicIP: ${PUBLIC_IP}"
else
  echo "중지된 LoadTest EC2 없음 (이미 실행 중이거나 미생성)."
fi

if eksctl get cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "노드 그룹 scale 복원 ..."
  eksctl scale nodegroup \
    --cluster="${CLUSTER_NAME}" \
    --name="${NODEGROUP_NAME}" \
    --nodes="${NODE_COUNT}" \
    --nodes-min="${NODE_MIN_SIZE}" \
    --nodes-max="${NODE_MAX_SIZE}" \
    --region="${AWS_REGION}"

  aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null

  echo "노드 Ready 대기 (최대 10분) ..."
  kubectl wait --for=condition=Ready nodes --all --timeout=600s 2>/dev/null || {
    echo "일부 노드가 아직 Ready 아님. kubectl get nodes 로 확인하세요." >&2
  }
  kubectl get nodes -o wide
else
  echo "클러스터 ${CLUSTER_NAME} 없음. create-eks-cluster.sh 로 먼저 생성하세요." >&2
  exit 1
fi

cat <<EOF

=== 재개 완료 ===
다음 단계 (필요 시):
  kubectl get pods -A
  APP_HOST=loadtest.k8s-study.club ./loadtest/run-loadtest.sh
EOF
