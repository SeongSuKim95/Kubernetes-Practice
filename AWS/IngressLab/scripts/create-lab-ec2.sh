#!/usr/bin/env bash
# Creates one EC2 in the default VPC, security group for SSH/HTTP/HTTPS/NodePort/API,
# runs bootstrap-k8s.sh as user-data, optionally allocates an Elastic IP.
#
# Prerequisites: aws CLI v2, credentials configured, EC2 key pair exists in the region.
#
# Usage:
#   export AWS_REGION=ap-northeast-2
#   export KEY_NAME=my-keypair
#   ./create-lab-ec2.sh
#
# Optional:
#   export INSTANCE_TYPE=t3.medium
#   export ALLOCATE_EIP=true
#   export SECURITY_GROUP_NAME=k8s-lab-sg
#
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION (e.g. ap-northeast-2)}"
: "${KEY_NAME:?Set KEY_NAME to your EC2 key pair name in this region}"

INSTANCE_TYPE="${INSTANCE_TYPE:-t3.large}"
ALLOCATE_EIP="${ALLOCATE_EIP:-true}"
SECURITY_GROUP_NAME="${SECURITY_GROUP_NAME:-k8s-lab-sg}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP="${SCRIPT_DIR}/bootstrap-k8s.sh"

if [[ ! -f "${BOOTSTRAP}" ]]; then
  echo "Missing ${BOOTSTRAP}" >&2
  exit 1
fi

echo "Using region=${AWS_REGION} key=${KEY_NAME} type=${INSTANCE_TYPE}"

# describe-default-vpcs 는 구형 AWS CLI에 없을 수 있음 → describe-vpcs + isDefault 로 호환
VPC_ID=$(aws ec2 describe-vpcs --region "${AWS_REGION}" \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
if [[ -z "${VPC_ID}" || "${VPC_ID}" == "None" ]]; then
  echo "No default VPC in ${AWS_REGION}. Create a VPC or use a non-default-VPC variant of this script." >&2
  exit 1
fi

SUBNET_ID=$(aws ec2 describe-subnets --region "${AWS_REGION}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=default-for-az,Values=true" \
  --query 'Subnets[0].SubnetId' --output text)
if [[ -z "${SUBNET_ID}" || "${SUBNET_ID}" == "None" ]]; then
  echo "Could not find a default subnet in VPC ${VPC_ID}" >&2
  exit 1
fi

SG_ID=$(aws ec2 describe-security-groups --region "${AWS_REGION}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=${SECURITY_GROUP_NAME}" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)

if [[ -z "${SG_ID}" || "${SG_ID}" == "None" ]]; then
  SG_ID=$(aws ec2 create-security-group --region "${AWS_REGION}" \
    --group-name "${SECURITY_GROUP_NAME}" \
    --description "k8s lab: ssh, api, http(s), nodeports" \
    --vpc-id "${VPC_ID}" \
    --query 'GroupId' --output text)
  echo "Created security group ${SG_ID}"

  authorize() {
    aws ec2 authorize-security-group-ingress --region "${AWS_REGION}" --group-id "${SG_ID}" "$@"
  }
  authorize --protocol tcp --port 22 --cidr 0.0.0.0/0
  authorize --protocol tcp --port 6443 --cidr 0.0.0.0/0
  authorize --protocol tcp --port 80 --cidr 0.0.0.0/0
  authorize --protocol tcp --port 443 --cidr 0.0.0.0/0
  authorize --protocol tcp --port 30000-32767 --cidr 0.0.0.0/0
  echo "Opened 22, 6443, 80, 443, 30000-32767 (tighten CIDRs for production)"
else
  echo "Reusing security group ${SG_ID}"
fi

AMI_ID=$(aws ssm get-parameters --region "${AWS_REGION}" \
  --names /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id \
  --query 'Parameters[0].Value' --output text)

EIP_FOR_CERT=""
ALLOCATION_ID=""
if [[ "${ALLOCATE_EIP}" == "true" ]]; then
  ALLOCATION_ID=$(aws ec2 allocate-address --region "${AWS_REGION}" --domain vpc --query AllocationId --output text)
  EIP_FOR_CERT=$(aws ec2 describe-addresses --region "${AWS_REGION}" --allocation-ids "${ALLOCATION_ID}" \
    --query 'Addresses[0].PublicIp' --output text)
  echo "Pre-allocated Elastic IP for apiserver SANs: ${EIP_FOR_CERT}"
fi

TMP_USERDATA="$(mktemp)"
trap 'rm -f "${TMP_USERDATA}"' EXIT
sed "s|__BOOTSTRAP_EIP_PLACEHOLDER__|${EIP_FOR_CERT}|g" "${BOOTSTRAP}" > "${TMP_USERDATA}"
# AWS CLI base64-encodes user-data once when using file:// (do not pre-encode).

INSTANCE_ID=$(aws ec2 run-instances --region "${AWS_REGION}" \
  --image-id "${AMI_ID}" \
  --instance-type "${INSTANCE_TYPE}" \
  --key-name "${KEY_NAME}" \
  --subnet-id "${SUBNET_ID}" \
  --security-group-ids "${SG_ID}" \
  --user-data "file://${TMP_USERDATA}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k8s-lab-single-node}]' \
  --metadata-options "HttpTokens=optional,HttpPutResponseHopLimit=2,HttpEndpoint=enabled" \
  --query 'Instances[0].InstanceId' --output text)

echo "Launched instance: ${INSTANCE_ID}"
aws ec2 wait instance-running --region "${AWS_REGION}" --instance-ids "${INSTANCE_ID}"

PUBLIC_IP=""
if [[ "${ALLOCATE_EIP}" == "true" ]]; then
  aws ec2 associate-address --region "${AWS_REGION}" --instance-id "${INSTANCE_ID}" --allocation-id "${ALLOCATION_ID}"
  PUBLIC_IP="${EIP_FOR_CERT}"
  echo "Associated pre-allocated Elastic IP: ${PUBLIC_IP}"
else
  PUBLIC_IP=$(aws ec2 describe-instances --region "${AWS_REGION}" --instance-ids "${INSTANCE_ID}" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  echo "Public IP (ephemeral): ${PUBLIC_IP}"
fi

echo ""
echo "=== Next steps ==="
echo "1. Wait 5–10 minutes for cloud-init / kubeadm (check: ssh -i ... ubuntu@${PUBLIC_IP} 'tail -f /var/log/bootstrap-k8s.log')"
echo "2. SSH: ssh -i ~/.ssh/<your-key>.pem ubuntu@${PUBLIC_IP}"
echo "3. kubectl get nodes && kubectl -n ingress-nginx get svc"
echo "4. Route53: create A record for your domain -> ${PUBLIC_IP}"
echo ""
echo "InstanceId=${INSTANCE_ID} SecurityGroup=${SG_ID} Subnet=${SUBNET_ID}"
