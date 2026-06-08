#!/usr/bin/env bash
# 부하 생성용 EC2 1대 (클러스터 밖, public subnet).
# user-data 로 k6 설치 + TCP 튜닝(50k RPS keep-alive 대비).
#
# 사전: aws CLI v2, 해당 리전의 EC2 키페어.
#
# 사용:
#   export AWS_REGION=ap-northeast-2
#   export KEY_NAME=<키페어 이름>
#   ./create-loadtest-ec2.sh
#
# 선택:
#   LOADTEST_INSTANCE_TYPE(c5.2xlarge)  SECURITY_GROUP_NAME(loadtest-sg)
#   SSH_CIDR(0.0.0.0/0)  K6_VERSION(v0.49.0)
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${KEY_NAME:?Set KEY_NAME (해당 리전 EC2 키페어 이름)}"

INSTANCE_TYPE="${LOADTEST_INSTANCE_TYPE:-c5.2xlarge}"   # 50k 풀가동이면 c5.4xlarge 권장
SECURITY_GROUP_NAME="${SECURITY_GROUP_NAME:-loadtest-sg}"
SSH_CIDR="${SSH_CIDR:-0.0.0.0/0}"
K6_VERSION="${K6_VERSION:-v0.49.0}"

echo "Using region=${AWS_REGION} key=${KEY_NAME} type=${INSTANCE_TYPE}"

VPC_ID=$(aws ec2 describe-vpcs --region "${AWS_REGION}" \
  --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
if [[ -z "${VPC_ID}" || "${VPC_ID}" == "None" ]]; then
  echo "기본 VPC 없음(${AWS_REGION}). public subnet 가 있는 VPC 를 지정하도록 스크립트를 수정하세요." >&2
  exit 1
fi

SUBNET_ID=$(aws ec2 describe-subnets --region "${AWS_REGION}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=default-for-az,Values=true" \
  --query 'Subnets[0].SubnetId' --output text)

SG_ID=$(aws ec2 describe-security-groups --region "${AWS_REGION}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=${SECURITY_GROUP_NAME}" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)

if [[ -z "${SG_ID}" || "${SG_ID}" == "None" ]]; then
  SG_ID=$(aws ec2 create-security-group --region "${AWS_REGION}" \
    --group-name "${SECURITY_GROUP_NAME}" \
    --description "loadtest ec2: ssh" \
    --vpc-id "${VPC_ID}" --query 'GroupId' --output text)
  aws ec2 authorize-security-group-ingress --region "${AWS_REGION}" \
    --group-id "${SG_ID}" --protocol tcp --port 22 --cidr "${SSH_CIDR}"
  echo "Created SG ${SG_ID} (SSH 22 from ${SSH_CIDR})"
else
  echo "Reusing SG ${SG_ID}"
fi

AMI_ID=$(aws ssm get-parameters --region "${AWS_REGION}" \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text)

TMP_USERDATA="$(mktemp)"
trap 'rm -f "${TMP_USERDATA}"' EXIT
cat >"${TMP_USERDATA}" <<EOF
#!/bin/bash
set -euxo pipefail

# --- k6 (정적 바이너리) ---
cd /tmp
curl -fsSL "https://github.com/grafana/k6/releases/download/${K6_VERSION}/k6-${K6_VERSION}-linux-amd64.tar.gz" -o k6.tgz
tar xzf k6.tgz
install -m 0755 k6-*/k6 /usr/local/bin/k6

# --- TCP / fd 튜닝 (keep-alive 기반 고RPS) ---
cat >/etc/security/limits.d/99-loadtest.conf <<LIM
* soft nofile 1048576
* hard nofile 1048576
LIM

cat >/etc/sysctl.d/99-loadtest.conf <<SYS
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 65535
net.ipv4.tcp_fin_timeout = 15
SYS
sysctl --system || true

echo "loadtest-ec2 ready" >/var/log/loadtest-ready.log
EOF

INSTANCE_ID=$(aws ec2 run-instances --region "${AWS_REGION}" \
  --image-id "${AMI_ID}" --instance-type "${INSTANCE_TYPE}" \
  --key-name "${KEY_NAME}" --subnet-id "${SUBNET_ID}" \
  --security-group-ids "${SG_ID}" \
  --associate-public-ip-address \
  --user-data "file://${TMP_USERDATA}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=loadtest-ec2}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "Launched ${INSTANCE_ID}"
aws ec2 wait instance-running --region "${AWS_REGION}" --instance-ids "${INSTANCE_ID}"
PUBLIC_IP=$(aws ec2 describe-instances --region "${AWS_REGION}" --instance-ids "${INSTANCE_ID}" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

cat <<EOF

=== LoadTest EC2 준비 ===
  InstanceId : ${INSTANCE_ID}
  PublicIP   : ${PUBLIC_IP}
  SSH        : ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@${PUBLIC_IP}

부하 실행(SSH 접속 후):
  # 이 레포의 loadtest/ 파일을 EC2 로 복사하거나 git clone 후
  APP_HOST=loadtest.k8s-study.club ./run-loadtest.sh
EOF
