# demo-restart-helper.bash — sourced by *-demo.bash (do not run directly)
# Force in-pod container restart; verify via containerID / restartCount.

wait_for_container_restart() {
  local app_label="$1"
  local before_id="$2"
  local before_rc="$3"
  local max_wait="${4:-30}"

  local after_id="${before_id}"
  local after_rc="${before_rc}"
  local i

  for ((i = 1; i <= max_wait; i++)); do
    kubectl wait --for=condition=Ready "pod" -l "app=${app_label}" --timeout=60s >/dev/null 2>&1 || true
    after_id="$(kubectl get pod -l "app=${app_label}" -o jsonpath='{.items[0].status.containerStatuses[0].containerID}')"
    after_rc="$(kubectl get pod -l "app=${app_label}" -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')"
    if [[ "${after_id}" != "${before_id}" ]] || [[ "${after_rc}" -gt "${before_rc}" ]]; then
      echo "after=${after_id}"
      echo "restartCount=${after_rc}"
      return 0
    fi
    sleep 1
  done

  echo "after=${after_id}"
  echo "restartCount=${after_rc}"
  return 1
}

force_container_restart() {
  local deploy="$1"
  local app_label="$2"

  local before_id before_rc container_id
  before_id="$(kubectl get pod -l "app=${app_label}" -o jsonpath='{.items[0].status.containerStatuses[0].containerID}')"
  before_rc="$(kubectl get pod -l "app=${app_label}" -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')"
  container_id="${before_id#*://}"

  echo "before=${before_id}"
  echo "restartCount=${before_rc}"
  kubectl exec "deploy/${deploy}" -- sh -c 'tr "\0" " " < /proc/1/cmdline; echo' 2>/dev/null || true

  echo "== 컨테이너 재시작 유도 (exec: kill -9 PID 1) =="
  kubectl exec "deploy/${deploy}" -- sh -c 'kill -9 1 2>/dev/null || pkill -9 sleep' || true

  echo "== 컨테이너 재시작 대기 (containerID / restartCount 변경) =="
  if wait_for_container_restart "${app_label}" "${before_id}" "${before_rc}" 15; then
    return 0
  fi

  if command -v crictl &>/dev/null && [[ -n "${container_id}" ]]; then
    echo "== fallback: crictl stop (Killercoda·단일 노드 실습용) =="
    crictl stop "${container_id}" 2>/dev/null || true
    if wait_for_container_restart "${app_label}" "${before_id}" "${before_rc}" 30; then
      return 0
    fi
  fi

  echo "ERROR: 컨테이너가 재시작되지 않았습니다." >&2
  echo "  - containerID·restartCount가 변하지 않았습니다." >&2
  echo "  - 스크립트가 최신인지 확인하세요 (git pull)." >&2
  echo "  - 수동 확인: kubectl get pod -l app=${app_label} -o wide" >&2
  return 1
}
