#!/usr/bin/env bash
# NetworkLab 로컬 사전 도구 검증.
#   필요한 도구: aws CLI v2, eksctl, kubectl, helm, envsubst(gettext)
#   (helm 은 NGINX Gateway Fabric 설치에 필요)
#
# 사용:
#   ./install-prerequisites.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_TOOLS=(aws eksctl kubectl helm envsubst)

FAIL=0
ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL + 1)); }

echo "=== 사전 도구 검증 ==="
for tool in "${REQUIRED_TOOLS[@]}"; do
  if command -v "${tool}" >/dev/null 2>&1; then
    ok "${tool} — $(command -v "${tool}")"
  else
    bad "${tool} — 명령을 찾을 수 없음"
    if [[ "${tool}" == "envsubst" ]]; then
      echo "    힌트(macOS): brew install gettext && export PATH=\"\$(brew --prefix gettext)/bin:\$PATH\"" >&2
    fi
  fi
done

# aws CLI v2 확인
if command -v aws >/dev/null 2>&1; then
  ver="$(aws --version 2>&1)"
  echo "${ver}" | grep -qE 'aws-cli/2' && ok "aws CLI v2 — ${ver}" || bad "aws CLI v2 가 아님 — ${ver}"
fi

# envsubst 동작 + cluster-config 렌더 테스트
TEMPLATE="${SCRIPT_DIR}/cluster-config.yaml"
if [[ -f "${TEMPLATE}" ]] && command -v envsubst >/dev/null 2>&1; then
  rendered="$(AWS_REGION=ap-northeast-2 CLUSTER_NAME=network-lab K8S_VERSION=1.33 \
     NODE_INSTANCE_TYPE=t3.medium envsubst <"${TEMPLATE}")"
  if echo "${rendered}" | grep -q 'name: network-lab' \
     && echo "${rendered}" | grep -q 'enableNetworkPolicy'; then
    ok "cluster-config.yaml envsubst 치환 — OK"
  else
    bad "cluster-config.yaml envsubst 치환 실패"
  fi
fi

# AWS 자격 증명
echo ""
echo "=== AWS 자격 증명 (aws configure) ==="
if command -v aws >/dev/null 2>&1; then
  if aws sts get-caller-identity &>/dev/null; then
    ok "STS — $(aws sts get-caller-identity --output text 2>/dev/null)"
  else
    bad "AWS 자격 증명 없음 또는 만료 — 'aws configure' 실행 필요"
  fi
fi

echo ""
if [[ "${FAIL}" -gt 0 ]]; then
  echo "=== 실패 ${FAIL}건 — 위 ✗ 항목 해결 후 재실행 ===" >&2
  exit 1
fi
echo "=== 모든 사전 도구 준비 완료 ==="
echo "다음: export AWS_REGION=ap-northeast-2 && ./create-eks-cluster.sh"
