#!/usr/bin/env bash
# 단계별 부하 테스트 공통: k6 실행 → 결과 요약 파일 작성
# run-step.sh 에서 source 합니다.
set -euo pipefail

run_step_loadtest() {
  local target_rps="$1"
  local step_label="$2"      # 리포트 라벨 (보통 RPS 값)
  local report_file="$3"
  local duration_sec="${4:-10}"

  : "${APP_HOST:?APP_HOST 를 지정하세요 (예: loadtest.k8s-study.club)}"

  local script_dir reports_dir tmp_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  reports_dir="${script_dir}/reports"
  tmp_dir="$(mktemp -d)"
  mkdir -p "${reports_dir}"

  ulimit -n 1048576 2>/dev/null || true

  local summary_json="${tmp_dir}/summary.json"
  local k6_log="${tmp_dir}/k6.log"
  local stage_dur="${duration_sec}s"

  echo "=== ${target_rps} RPS 부하 (${duration_sec}초) → ${APP_HOST} ==="
  echo "리포트: ${report_file}"

  set +e
  k6 run \
    -e APP_HOST="${APP_HOST}" \
    -e TARGET_RATE="${target_rps}" \
    -e STAGE_DUR="${stage_dur}" \
    --summary-export="${summary_json}" \
    "${script_dir}/single-rate.js" 2>&1 | tee "${k6_log}"
  local k6_exit=$?
  set -e

  python3 - "${summary_json}" "${k6_log}" "${target_rps}" "${step_label}" "${duration_sec}" "${APP_HOST}" "${report_file}" "${k6_exit}" <<'PY'
import json, re, sys
from datetime import datetime, timezone

(summary_path, k6_log_path, target_rps_s, step_label, duration_sec_s,
 app_host, report_path, k6_exit_s) = sys.argv[1:9]
target_rps = int(target_rps_s)
duration_sec = int(duration_sec_s)
k6_exit = int(k6_exit_s)

def load_summary():
    try:
        with open(summary_path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

def metric_values(data, name):
    return data.get("metrics", {}).get(name, {}).get("values", {})

s = load_summary()
failed = metric_values(s, "http_req_failed")
checks = metric_values(s, "checks")
duration = metric_values(s, "http_req_duration")
req_count = metric_values(s, "http_reqs")
dropped = metric_values(s, "dropped_iterations")

fail_rate = float(failed.get("rate", 0) or 0)
fail_pct = fail_rate * 100
pass_checks = int(checks.get("passes", 0) or 0)
fail_checks = int(checks.get("fails", 0) or 0)
total_reqs = int(req_count.get("count", 0) or 0)
actual_rps = float(req_count.get("rate", 0) or 0)
dropped_n = int(dropped.get("count", 0) or 0)
avg_ms = float(duration.get("avg", 0) or 0)
p95_ms = float(duration.get("p(95)", 0) or 0)

log_text = ""
try:
    with open(k6_log_path) as f:
        log_text = f.read()
except FileNotFoundError:
    pass

if total_reqs == 0:
    m = re.search(r"http_reqs[^:]*:\s*(\d+)\s+([\d.]+)/s", log_text)
    if m:
        total_reqs = int(m.group(1))
        actual_rps = float(m.group(2))
    m = re.search(r"http_req_failed[^:]*:\s*([\d.]+)%", log_text)
    if m:
        fail_pct = float(m.group(1))
        fail_rate = fail_pct / 100
    m = re.search(r"checks[^:]*:\s*([\d.]+)%\s+✓\s*(\d+)\s+✗\s*(\d+)", log_text)
    if m:
        pass_checks = int(m.group(2))
        fail_checks = int(m.group(3))
    m = re.search(r"dropped_iterations[^:]*:\s*(\d+)", log_text)
    if m:
        dropped_n = int(m.group(1))
    m = re.search(r"http_req_duration[^:]*: avg=([\d.]+)(ms|s)", log_text)
    if m:
        val = float(m.group(1))
        avg_ms = val * 1000 if m.group(2) == "s" else val
    m = re.search(r"http_req_duration[^:]*:.*p\(95\)=([\d.]+)(ms|s)", log_text)
    if m:
        val = float(m.group(1))
        p95_ms = val * 1000 if m.group(2) == "s" else val

expected = target_rps * duration_sec
throughput_pct = (actual_rps / target_rps * 100) if target_rps else 0

if fail_rate == 0 and throughput_pct >= 95:
    verdict = "PASS"
elif fail_rate < 0.05 and throughput_pct >= 80:
    verdict = "WARN"
else:
    verdict = "FAIL"

lines = []
lines.append(f"# LoadTest 리포트 — RPS {step_label} / {duration_sec}s ({datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')} UTC)")
lines.append("")
lines.append("## 테스트 조건")
lines.append(f"- 대상: https://{app_host}/")
lines.append(f"- 목표 RPS: {target_rps}")
lines.append(f"- 지속 시간: {duration_sec}s")
lines.append(f"- k6 종료 코드: {k6_exit}")
lines.append("")
lines.append("## 결과 요약")
lines.append(f"- 판정: {verdict}")
lines.append(f"- HTTP 실패율: {fail_pct:.2f}%")
lines.append(f"- status 200 checks: ✓ {pass_checks} / ✗ {fail_checks}")
lines.append(f"- 총 요청 수: {total_reqs} (기대 ~{expected})")
lines.append(f"- 실제 처리량: {actual_rps:.1f} RPS ({throughput_pct:.0f}% of target)")
lines.append(f"- dropped iterations: {dropped_n}")
lines.append(f"- 응답 시간 avg: {avg_ms:.0f} ms, p95: {p95_ms:.0f} ms")

report = "\n".join(lines) + "\n"
with open(report_path, "w") as f:
    f.write(report)

print("")
print(report)
print(f"리포트 저장: {report_path}")
PY

  rm -rf "${tmp_dir}"
  return "${k6_exit}"
}
