#!/usr/bin/env bash
# 단계별 부하 테스트: RPS·지속시간(초) 파라미터 → k6 실행 → 결과 리포트
#
# 사용 (LoadTest EC2):
#   export APP_HOST=loadtest.k8s-study.club
#   ./run-step.sh <RPS> [지속시간_초]
#
# 예:
#   ./run-step.sh 100          # 100 RPS, 10초 (기본)
#   ./run-step.sh 100 30       # 100 RPS, 30초
#   ./run-step.sh 1000 10      # 1000 RPS, 10초
#
# 리포트: ./reports/step-<RPS>-<초>s-report.txt
set -euo pipefail

usage() {
  cat <<EOF
사용: APP_HOST=<호스트> $0 <RPS> [지속시간_초]

  RPS            목표 초당 요청 수 (양의 정수)
  지속시간_초    부하 지속 시간, 초 단위 (기본: 10)

예:
  APP_HOST=loadtest.k8s-study.club $0 100
  APP_HOST=loadtest.k8s-study.club $0 1000 30
EOF
}

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

TARGET_RPS="$1"
DURATION_SEC="${2:-10}"

if ! [[ "${TARGET_RPS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "RPS 는 양의 정수여야 합니다: ${TARGET_RPS}" >&2
  exit 1
fi
if ! [[ "${DURATION_SEC}" =~ ^[1-9][0-9]*$ ]]; then
  echo "지속시간(초)은 양의 정수여야 합니다: ${DURATION_SEC}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/step-report.sh
source "${SCRIPT_DIR}/lib/step-report.sh"

REPORT="${SCRIPT_DIR}/reports/step-${TARGET_RPS}-${DURATION_SEC}s-report.txt"
run_step_loadtest "${TARGET_RPS}" "${TARGET_RPS}" "${REPORT}" "${DURATION_SEC}"
