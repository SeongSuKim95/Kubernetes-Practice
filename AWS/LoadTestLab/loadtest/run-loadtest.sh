#!/usr/bin/env bash
# k6 부하 실행 래퍼. LoadTest EC2 에서 실행.
#
# 사용:
#   APP_HOST=loadtest.k8s-study.club ./run-loadtest.sh            # 전체 램프(100→1k→10k→50k)
#   APP_HOST=loadtest.k8s-study.club ./run-loadtest.sh 1000       # 단일 RPS 단계만 고정
#
# 선택: STAGE_DUR(기본 2m), MAX_VUS(기본 20000)
set -euo pipefail

: "${APP_HOST:?APP_HOST 를 지정하세요 (예: loadtest.k8s-study.club)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUR="${STAGE_DUR:-2m}"

command -v k6 >/dev/null 2>&1 || { echo "k6 없음. create-loadtest-ec2.sh 로 만든 EC2 에서 실행하세요." >&2; exit 1; }

# fd 한도 상향(현재 셸)
ulimit -n 1048576 2>/dev/null || true

if [[ $# -ge 1 ]]; then
  RATE="$1"
  echo "=== 단일 단계 부하: ${RATE} RPS, ${DUR}, host=${APP_HOST} ==="
  k6 run -e APP_HOST="${APP_HOST}" -e TARGET_RATE="${RATE}" -e STAGE_DUR="${DUR}" \
    "${SCRIPT_DIR}/single-rate.js"
else
  echo "=== 전체 램프 부하: 100→1k→10k→50k (각 ${DUR}), host=${APP_HOST} ==="
  k6 run -e APP_HOST="${APP_HOST}" -e STAGE_DUR="${DUR}" "${SCRIPT_DIR}/script.js"
fi
