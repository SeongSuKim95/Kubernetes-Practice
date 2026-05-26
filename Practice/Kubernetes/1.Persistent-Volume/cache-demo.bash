#!/bin/bash
# cache-demo.bash — emptyDir vs hostPath 계산 캐시 비교 (Killercoda·단일 노드)
# 사용: cd Practice/Kubernetes/1.Persistent-Volume && ./cache-demo.bash
# 환경 변수: N (반복 횟수, 기본 400000), HOST_CACHE_PATH (노드 경로, 기본 /tmp/calc-cache-demo)
set -euo pipefail

N="${N:-400000}"
HOST_CACHE_PATH="${HOST_CACHE_PATH:-/tmp/calc-cache-demo}"
APP_LABEL="calc-cache-demo"
DEPLOY_NAME="calc-cache-demo"
SVC_NAME="calc-cache-demo"
CM_NAME="calc-cache-demo-script"
PF_PID=""

cleanup() {
  kill "${PF_PID}" 2>/dev/null || true
  kubectl delete deploy,svc,cm -l "demo=calc-cache" --ignore-not-found 2>/dev/null || true
  kubectl delete "deployment/${DEPLOY_NAME}" "service/${SVC_NAME}" "configmap/${CM_NAME}" \
    --ignore-not-found 2>/dev/null || true
}

trap cleanup EXIT

apply_configmap() {
  kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: calc-cache-demo-script
  labels:
    demo: calc-cache
data:
  server.py: |
    import hashlib
    import http.server
    import json
    import os
    import socketserver
    import time
    import urllib.parse

    CACHE_DIR = os.environ.get("CACHE_DIR", "/cache")
    os.makedirs(CACHE_DIR, exist_ok=True)

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            return

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path not in ("/", "/compute", "/health"):
                self.send_error(404)
                return
            if parsed.path == "/health":
                self._respond(200, {"ok": True}, False, 0.0)
                return

            params = urllib.parse.parse_qs(parsed.query)
            n = int(params.get("n", ["300000"])[0])
            if n < 1 or n > 5_000_000:
                self.send_error(400, "n must be 1..5000000")
                return

            cache_file = os.path.join(CACHE_DIR, f"{n}.json")
            started = time.perf_counter()

            if os.path.exists(cache_file):
                with open(cache_file, encoding="utf-8") as f:
                    payload = json.load(f)
                cached = True
            else:
                acc = 0
                for i in range(n):
                    acc = (acc + (i * 31) % 1_000_003) % 1_000_003
                digest = hashlib.sha256(f"{acc}:{n}".encode()).hexdigest()
                payload = {
                    "n": n,
                    "digest": digest,
                    "iterations": n,
                    "note": "expensive loop result",
                }
                with open(cache_file, "w", encoding="utf-8") as f:
                    json.dump(payload, f)
                cached = False

            elapsed = time.perf_counter() - started
            self._respond(200, payload, cached, elapsed)

        def _respond(self, code, payload, cached, elapsed):
            body = json.dumps(payload).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("X-Cache-Hit", "true" if cached else "false")
            self.send_header("X-Elapsed-Sec", f"{elapsed:.4f}")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    port = int(os.environ.get("PORT", "8080"))
    with socketserver.TCPServer(("", port), Handler) as httpd:
        httpd.serve_forever()
EOF
}

apply_emptydir() {
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEPLOY_NAME}
  labels:
    app: ${APP_LABEL}
    demo: calc-cache
    cache-backend: emptyDir
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP_LABEL}
  template:
    metadata:
      labels:
        app: ${APP_LABEL}
        demo: calc-cache
        cache-backend: emptyDir
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/server.py"]
          env:
            - name: PORT
              value: "8080"
            - name: CACHE_DIR
              value: "/cache"
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: cache-vol
              mountPath: /cache
            - name: script
              mountPath: /app
              readOnly: true
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 2
            periodSeconds: 3
      volumes:
        - name: cache-vol
          emptyDir: {}
        - name: script
          configMap:
            name: ${CM_NAME}
            items:
              - key: server.py
                path: server.py
---
apiVersion: v1
kind: Service
metadata:
  name: ${SVC_NAME}
  labels:
    demo: calc-cache
spec:
  selector:
    app: ${APP_LABEL}
  ports:
    - port: 80
      targetPort: 8080
EOF
}

apply_hostpath() {
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEPLOY_NAME}
  labels:
    app: ${APP_LABEL}
    demo: calc-cache
    cache-backend: hostPath
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP_LABEL}
  template:
    metadata:
      labels:
        app: ${APP_LABEL}
        demo: calc-cache
        cache-backend: hostPath
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/server.py"]
          env:
            - name: PORT
              value: "8080"
            - name: CACHE_DIR
              value: "/cache"
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: cache-vol
              mountPath: /cache
            - name: script
              mountPath: /app
              readOnly: true
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 2
            periodSeconds: 3
      volumes:
        - name: cache-vol
          hostPath:
            path: ${HOST_CACHE_PATH}
            type: DirectoryOrCreate
        - name: script
          configMap:
            name: ${CM_NAME}
            items:
              - key: server.py
                path: server.py
EOF
}

wait_ready() {
  kubectl wait --for=condition=Ready pod -l "app=${APP_LABEL}" --timeout=120s
}

start_port_forward() {
  kill "${PF_PID}" 2>/dev/null || true
  kubectl port-forward "svc/${SVC_NAME}" 8080:80 >/dev/null 2>&1 &
  PF_PID=$!
  for _ in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: port-forward to svc/${SVC_NAME} did not become ready" >&2
  exit 1
}

curl_cache() {
  local label="$1"
  local expect_hit="${2:-}"
  local headers
  echo "--- ${label} ---"
  headers=$(curl -s -D- "http://127.0.0.1:8080/compute?n=${N}" -o /dev/null \
    | grep -E '^(HTTP/|X-Cache-Hit|X-Elapsed-Sec)' || true)
  echo "${headers}"

  if [[ -n "${expect_hit}" ]]; then
    local actual
    actual=$(echo "${headers}" | awk -F': ' '/^X-Cache-Hit:/ {print $2}' | tr -d '\r')
    if [[ "${actual}" != "${expect_hit}" ]]; then
      echo "ASSERT FAIL: expected X-Cache-Hit=${expect_hit}, got '${actual}' (${label})" >&2
      exit 1
    fi
    echo "OK: X-Cache-Hit=${actual}"
  fi
}

delete_pod() {
  local pod
  pod=$(kubectl get pod -l "app=${APP_LABEL}" -o jsonpath='{.items[0].metadata.name}')
  echo "Deleting pod: ${pod}"
  kubectl delete pod "${pod}" --wait=true
  wait_ready
}

clear_pod_cache() {
  kubectl exec "deploy/${DEPLOY_NAME}" -- sh -c 'rm -rf /cache/*' 2>/dev/null || true
}

echo "=============================================="
echo " Phase 1: emptyDir — Pod 삭제 시 캐시 소실"
echo "=============================================="
apply_configmap
apply_emptydir
wait_ready
start_port_forward

curl_cache "emptyDir — 1회차 (캐시 미스, 느림)" "false"
curl_cache "emptyDir — 2회차 (캐시 히트, 빠름)" "true"
echo "Pod /cache:"
kubectl exec "deploy/${DEPLOY_NAME}" -- ls -l /cache

delete_pod
echo "Pod /cache after delete (emptyDir — 비어 있음 기대):"
if kubectl exec "deploy/${DEPLOY_NAME}" -- ls -l /cache 2>&1 | grep -q 'total 0'; then
  echo "OK: /cache is empty after pod recreate"
else
  kubectl exec "deploy/${DEPLOY_NAME}" -- ls -l /cache 2>&1 || true
  echo "WARN: expected empty /cache on fresh emptyDir pod" >&2
fi

curl_cache "emptyDir — Pod 삭제 후 1회차 (캐시 미스, 다시 느림)" "false"

kill "${PF_PID}" 2>/dev/null || true
PF_PID=""
kubectl delete "deployment/${DEPLOY_NAME}" --wait=true

echo
echo "=============================================="
echo " Phase 2: hostPath — Pod 삭제 후에도 캐시 유지"
echo " (노드 경로: ${HOST_CACHE_PATH})"
echo "=============================================="
apply_hostpath
wait_ready
clear_pod_cache
start_port_forward

curl_cache "hostPath — 1회차 (캐시 미스, 느림)" "false"
curl_cache "hostPath — 2회차 (캐시 히트, 빠름)" "true"

delete_pod
curl_cache "hostPath — Pod 삭제 후 1회차 (캐시 히트 유지, 빠름)" "true"

echo "Pod /cache after delete (hostPath — 파일 유지 기대):"
kubectl exec "deploy/${DEPLOY_NAME}" -- ls -l /cache

echo
echo "All assertions passed."
echo "emptyDir: Pod 삭제 → 캐시 소실 | hostPath: 같은 노드 → 캐시 유지"
echo "Cleanup on exit (deploy, svc, cm removed)."
