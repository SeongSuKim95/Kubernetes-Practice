#!/usr/bin/env bash
# LoadTestLab 일시 중지 — 워커 노드 scale 0 + loadtest EC2 stop
# EKS 컨트롤 플레인 / NAT / ALB 비용은 계속 발생합니다.
#
# 사용:
#   export AWS_REGION=ap-northeast-2
#   ./pause-loadtest-lab.sh
#
# 선택:
#   CLUSTER_NAME(loadtest-lab)  NODEGROUP_NAME(ng-workload)
#   LOADTEST_EC2_TAG(loadtest-ec2)  STATE_FILE(.loadtest-lab-pause-state.env)
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION (e.g. ap-northeast-2)}"

CLUSTER_NAME="${CLUSTER_NAME:-loadtest-lab}"
NODEGROUP_NAME="${NODEGROUP_NAME:-ng-workload}"
LOADTEST_EC2_TAG="${LOADTEST_EC2_TAG:-loadtest-ec2}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${STATE_FILE:-${SCRIPT_DIR}/.loadtest-lab-pause-state.env}"

for bin in aws eksctl; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

echo "=== LoadTestLab 일시 중지 ==="
echo "  cluster=${CLUSTER_NAME} region=${AWS_REGION} nodegroup=${NODEGROUP_NAME}"

if ! eksctl get cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "클러스터 ${CLUSTER_NAME} 없음. EKS 단계 건너뜀." >&2
else
  MIN_SIZE=$(aws eks describe-nodegroup \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --region "${AWS_REGION}" \
    --query 'nodegroup.scalingConfig.minSize' \
    --output text)
  MAX_SIZE=$(aws eks describe-nodegroup \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --region "${AWS_REGION}" \
    --query 'nodegroup.scalingConfig.maxSize' \
    --output text)
  DESIRED=$(aws eks describe-nodegroup \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --region "${AWS_REGION}" \
    --query 'nodegroup.scalingConfig.desiredSize' \
    --output text)

  cat >"${STATE_FILE}" <<EOF
# LoadTestLab pause state — resume-loadtest-lab.sh 가 사용합니다
AWS_REGION=${AWS_REGION}
CLUSTER_NAME=${CLUSTER_NAME}
NODEGROUP_NAME=${NODEGROUP_NAME}
NODE_MIN_SIZE=${MIN_SIZE}
NODE_MAX_SIZE=${MAX_SIZE}
NODE_COUNT=${DESIRED}
LOADTEST_EC2_TAG=${LOADTEST_EC2_TAG}
PAUSED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  echo "상태 저장: ${STATE_FILE} (desired=${DESIRED} min=${MIN_SIZE} max=${MAX_SIZE})"

  if [[ "${DESIRED}" == "0" ]]; then
    echo "노드 그룹 이미 desired=0. scale 건너뜀."
  else
    echo "노드 그룹 scale → 0 ..."
    eksctl scale nodegroup \
      --cluster="${CLUSTER_NAME}" \
      --name="${NODEGROUP_NAME}" \
      --nodes=0 \
      --nodes-min=0 \
      --nodes-max=1 \
      --region="${AWS_REGION}"
    echo "노드 그룹 중지 완료."
  fi
fi

INSTANCE_IDS=$(aws ec2 describe-instances --region "${AWS_REGION}" \
  --filters \
    "Name=tag:Name,Values=${LOADTEST_EC2_TAG}" \
    "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text | tr '\t' ' ')

if [[ -n "${INSTANCE_IDS// }" ]]; then
  echo "LoadTest EC2 stop: ${INSTANCE_IDS}"
  # shellcheck disable=SC2086
  aws ec2 stop-instances --region "${AWS_REGION}" --instance-ids ${INSTANCE_IDS}
  # shellcheck disable=SC2086
  aws ec2 wait instance-stopped --region "${AWS_REGION}" --instance-ids ${INSTANCE_IDS}
  echo "LoadTest EC2 중지 완료."
else
  echo "실행 중인 LoadTest EC2(tag:Name=${LOADTEST_EC2_TAG}) 없음."
fi

cat <<EOF

=== 일시 중지 완료 ===
다음 주 재개:
  export AWS_REGION=${AWS_REGION}
  ./resume-loadtest-lab.sh

참고: EKS 컨트롤 플레인 / NAT / ALB 비용은 계속 청구됩니다.
완전 삭제는 LAB-GUIDE.md §7 (eksctl delete cluster) 참고.
EOF
