#!/usr/bin/env bash
# LoadTestLab 로컬 사전 도구 설치 + 검증.
#
# 대상: aws CLI v2, eksctl, kubectl, helm, envsubst(gettext), curl
#
# 사용:
#   ./install-prerequisites.sh              # 없는 도구 설치 후 전체 검증
#   ./install-prerequisites.sh --check-only  # 설치 없이 검증만
#   ./install-prerequisites.sh --install-only # 설치만 (검증은 마지막에 1회)
#
# macOS: Homebrew 필요 (https://brew.sh)
# Linux: apt(Debian/Ubuntu) 또는 dnf/yum(RHEL/Amazon Linux) 지원
set -euo pipefail

CHECK_ONLY=false
INSTALL_ONLY=false
for arg in "$@"; do
  case "${arg}" in
    --check-only|-c) CHECK_ONLY=true ;;
    --install-only|-i) INSTALL_ONLY=true ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "알 수 없는 인자: ${arg} ( --help 참고)" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GETTEXT_PREFIX=""

# ── OS 감지 ───────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

OS="$(detect_os)"
if [[ "${OS}" == "unknown" ]]; then
  echo "지원하지 않는 OS 입니다 (macOS / Linux 만 지원)." >&2
  exit 1
fi

# envsubst 는 gettext 패키지에 포함. brew 로 설치 시 keg-only 경로에 있을 수 있음.
ensure_envsubst_path() {
  if command -v envsubst >/dev/null 2>&1; then
    return 0
  fi
  if [[ "${OS}" == "darwin" ]] && command -v brew >/dev/null 2>&1; then
    local prefix
    prefix="$(brew --prefix gettext 2>/dev/null || true)"
    if [[ -n "${prefix}" && -x "${prefix}/bin/envsubst" ]]; then
      export PATH="${prefix}/bin:${PATH}"
      GETTEXT_PREFIX="${prefix}"
    fi
  fi
}

# ── 패키지 매니저로 설치 ─────────────────────────────────────────
install_brew() {
  local pkg="$1"
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew 가 없습니다. https://brew.sh 에서 설치 후 다시 실행하세요." >&2
    return 1
  fi
  if brew list "${pkg}" &>/dev/null; then
    echo "[brew] 이미 설치됨: ${pkg}"
  else
    echo "[brew] 설치 중: ${pkg}"
    brew install "${pkg}"
  fi
}

install_apt() {
  local pkg="$1"
  if ! command -v apt-get >/dev/null 2>&1; then
    return 1
  fi
  echo "[apt] 설치 중: ${pkg}"
  sudo apt-get update -qq
  sudo apt-get install -y "${pkg}"
}

install_dnf_yum() {
  local pkg="$1"
  if command -v dnf >/dev/null 2>&1; then
    echo "[dnf] 설치 중: ${pkg}"
    sudo dnf install -y "${pkg}"
  elif command -v yum >/dev/null 2>&1; then
    echo "[yum] 설치 중: ${pkg}"
    sudo yum install -y "${pkg}"
  else
    return 1
  fi
}

install_eksctl_linux() {
  if command -v eksctl >/dev/null 2>&1; then
    echo "[eksctl] 이미 설치됨"
    return 0
  fi
  echo "[eksctl] 공식 설치 스크립트 실행"
  curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
    | tar xz -C /tmp
  sudo mv /tmp/eksctl /usr/local/bin/
  sudo chmod +x /usr/local/bin/eksctl
}

install_helm_linux() {
  if command -v helm >/dev/null 2>&1; then
    echo "[helm] 이미 설치됨"
    return 0
  fi
  echo "[helm] 공식 설치 스크립트 실행"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_kubectl_linux() {
  if command -v kubectl >/dev/null 2>&1; then
    echo "[kubectl] 이미 설치됨"
    return 0
  fi
  local ver
  ver="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  echo "[kubectl] 설치 중: ${ver}"
  curl -fsSL "https://dl.k8s.io/release/${ver}/bin/linux/amd64/kubectl" -o /tmp/kubectl
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
}

install_awscli_linux() {
  if command -v aws >/dev/null 2>&1 && aws --version 2>&1 | grep -q 'aws-cli/2'; then
    echo "[aws] CLI v2 이미 설치됨"
    return 0
  fi
  echo "[aws] CLI v2 설치 (공식 번들)"
  local tmpdir
  tmpdir="$(mktemp -d)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${tmpdir}/awscliv2.zip"
  unzip -q "${tmpdir}/awscliv2.zip" -d "${tmpdir}"
  sudo "${tmpdir}/aws/install" --update
  rm -rf "${tmpdir}"
}

install_tool() {
  local tool="$1"
  case "${tool}" in
    aws)
      if [[ "${OS}" == "darwin" ]]; then install_brew awscli
      else install_awscli_linux; fi ;;
    eksctl)
      if [[ "${OS}" == "darwin" ]]; then install_brew eksctl
      else install_eksctl_linux; fi ;;
    kubectl)
      if [[ "${OS}" == "darwin" ]]; then install_brew kubectl
      else install_kubectl_linux; fi ;;
    helm)
      if [[ "${OS}" == "darwin" ]]; then install_brew helm
      else install_helm_linux; fi ;;
    envsubst)
      if [[ "${OS}" == "darwin" ]]; then
        install_brew gettext
        ensure_envsubst_path
      else
        install_apt gettext-base 2>/dev/null || install_dnf_yum gettext || install_apt gettext
      fi ;;
    curl)
      if [[ "${OS}" == "darwin" ]]; then install_brew curl
      else install_apt curl 2>/dev/null || install_dnf_yum curl; fi ;;
    *) echo "내부 오류: 알 수 없는 도구 ${tool}" >&2; return 1 ;;
  esac
}

REQUIRED_TOOLS=(aws eksctl kubectl helm envsubst curl)

# ── 설치 단계 ─────────────────────────────────────────────────────
if [[ "${CHECK_ONLY}" != "true" ]]; then
  echo "=== LoadTestLab 사전 도구 설치 (${OS}) ==="
  ensure_envsubst_path
  for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      install_tool "${tool}" || {
        echo "설치 실패: ${tool}" >&2
        exit 1
      }
    else
      echo "[skip] ${tool} — PATH 에 있음"
    fi
  done
  ensure_envsubst_path
  echo ""
fi

# ── 검증 단계 ─────────────────────────────────────────────────────
echo "=== 사전 도구 검증 ==="
FAIL=0
PASS=0

check_ok() {
  echo "  ✓ $*"
  PASS=$((PASS + 1))
}

check_fail() {
  echo "  ✗ $*" >&2
  FAIL=$((FAIL + 1))
}

# 1) PATH 존재
ensure_envsubst_path
for tool in "${REQUIRED_TOOLS[@]}"; do
  if command -v "${tool}" >/dev/null 2>&1; then
    check_ok "${tool} — $(command -v "${tool}")"
  else
    check_fail "${tool} — 명령을 찾을 수 없음"
    if [[ "${tool}" == "envsubst" && "${OS}" == "darwin" ]]; then
      echo "    힌트: brew install gettext && export PATH=\"\$(brew --prefix gettext)/bin:\$PATH\"" >&2
    fi
  fi
done

# 2) 버전 / 동작 검증
if command -v aws >/dev/null 2>&1; then
  ver="$(aws --version 2>&1)"
  if echo "${ver}" | grep -qE 'aws-cli/2'; then
    check_ok "aws CLI v2 — ${ver}"
  else
    check_fail "aws CLI v2 가 아님 — ${ver} (v2 필요)"
  fi
fi

if command -v eksctl >/dev/null 2>&1; then
  ver="$(eksctl version 2>/dev/null || true)"
  [[ -n "${ver}" ]] && check_ok "eksctl — ${ver}" || check_fail "eksctl version 실패"
fi

if command -v kubectl >/dev/null 2>&1; then
  ver="$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)"
  [[ -n "${ver}" ]] && check_ok "kubectl — ${ver}" || check_fail "kubectl version 실패"
fi

if command -v helm >/dev/null 2>&1; then
  ver="$(helm version --short 2>/dev/null || helm version 2>/dev/null | head -1)"
  [[ -n "${ver}" ]] && check_ok "helm — ${ver}" || check_fail "helm version 실패"
fi

if command -v envsubst >/dev/null 2>&1; then
  export _LOADTEST_ENV_SUBST_CHECK=ok
  out="$(echo 'substituted=${_LOADTEST_ENV_SUBST_CHECK}' | envsubst)"
  unset _LOADTEST_ENV_SUBST_CHECK
  if [[ "${out}" == "substituted=ok" ]]; then
    check_ok "envsubst 동작 — 출력: ${out}"
  else
    check_fail "envsubst 치환 실패 — 기대: substituted=ok, 실제: ${out:-<empty>}"
  fi
fi

if command -v curl >/dev/null 2>&1; then
  check_ok "curl — $(curl --version 2>/dev/null | head -1)"
fi

# 3) cluster-config.yaml envsubst 치환 테스트
TEMPLATE="${SCRIPT_DIR}/cluster-config.yaml"
if [[ -f "${TEMPLATE}" ]] && command -v envsubst >/dev/null 2>&1; then
  rendered="$(AWS_REGION=ap-northeast-2 CLUSTER_NAME=loadtest-lab K8S_VERSION=1.33 \
     NODE_INSTANCE_TYPE=c5.2xlarge NODE_COUNT=5 NODE_MIN_SIZE=4 NODE_MAX_SIZE=6 \
     envsubst <"${TEMPLATE}")"
  if echo "${rendered}" | grep -q 'name: loadtest-lab' \
     && echo "${rendered}" | grep -q 'instanceType: c5.2xlarge' \
     && echo "${rendered}" | grep -qE 'minSize: 4' \
     && echo "${rendered}" | grep -qE 'maxSize: 6' \
     && echo "${rendered}" | grep -qE 'desiredCapacity: 5'; then
    check_ok "cluster-config.yaml envsubst 치환 — OK (c5.2xlarge×5, min/max 4/6)"
  else
    check_fail "cluster-config.yaml envsubst 치환 — NODE_MIN_SIZE/NODE_MAX_SIZE 등 export 누락 가능"
  fi
fi

# 4) AWS 자격 증명 (선택이지만 실습에 필수)
echo ""
echo "=== AWS 자격 증명 (aws configure) ==="
if command -v aws >/dev/null 2>&1; then
  if aws sts get-caller-identity &>/dev/null; then
    ident="$(aws sts get-caller-identity --output text 2>/dev/null)"
    check_ok "STS get-caller-identity — ${ident}"
  else
    check_fail "AWS 자격 증명 없음 또는 만료 — 'aws configure' 실행 필요"
    echo "    힌트: aws configure  (Access Key, Secret, region=ap-northeast-2)" >&2
  fi
else
  check_fail "aws CLI 없음 — 자격 증명 검증 건너뜀"
fi

# ── 결과 요약 ─────────────────────────────────────────────────────
echo ""
echo "=== 결과: ${PASS} passed, ${FAIL} failed ==="
if [[ "${FAIL}" -gt 0 ]]; then
  echo "일부 검증 실패. 위 ✗ 항목을 해결한 뒤 다시 실행하세요." >&2
  echo "  ./install-prerequisites.sh --check-only" >&2
  exit 1
fi

echo "모든 사전 도구가 준비되었습니다."
echo "다음: export AWS_REGION=ap-northeast-2 && ./create-eks-cluster.sh"
if [[ -n "${GETTEXT_PREFIX}" ]]; then
  echo ""
  echo "envsubst PATH (셸에 추가 권장):"
  echo "  export PATH=\"${GETTEXT_PREFIX}/bin:\$PATH\""
fi
