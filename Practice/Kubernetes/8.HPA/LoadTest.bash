#!/bin/bash
# Generate HTTP load against apache-deployment to trigger HPA scale-up.
#
# Usage:
#   ./LoadTest.bash start   # create load generator Deployment
#   ./LoadTest.bash stop    # remove load generator
#   ./LoadTest.bash status  # show HPA, apache pods, load generator
#
# Recommended: in another terminal, run:
#   kubectl get hpa,pods -n autoscale -w

set -e

NAMESPACE="${NAMESPACE:-autoscale}"
TARGET_SERVICE="${TARGET_SERVICE:-apache-deployment}"
LOAD_DEPLOY="${LOAD_DEPLOY:-hpa-load-generator}"
LOAD_REPLICAS="${LOAD_REPLICAS:-2}"
PARALLEL_WORKERS="${PARALLEL_WORKERS:-20}"
TARGET_URL="http://${TARGET_SERVICE}.${NAMESPACE}.svc.cluster.local"

usage() {
  echo "Usage: $0 {start|stop|status}"
  echo ""
  echo "  start   Deploy ${LOAD_DEPLOY} and hammer ${TARGET_URL}"
  echo "  stop    Delete ${LOAD_DEPLOY}"
  echo "  status  Show HPA, deployment replicas, and load pods"
  exit 1
}

check_lab() {
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "❌ Namespace '${NAMESPACE}' not found. Run LabSetUp.bash first."
    exit 1
  fi
  if ! kubectl get deployment apache-deployment -n "$NAMESPACE" &>/dev/null; then
    echo "❌ Deployment 'apache-deployment' not found in '${NAMESPACE}'. Run LabSetUp.bash first."
    exit 1
  fi
  if ! kubectl get svc "$TARGET_SERVICE" -n "$NAMESPACE" &>/dev/null; then
    echo "❌ Service '${TARGET_SERVICE}' not found in '${NAMESPACE}'. Run LabSetUp.bash first."
    exit 1
  fi
}

warn_hpa() {
  if ! kubectl get hpa apache-server -n "$NAMESPACE" &>/dev/null; then
    echo "⚠️  HPA 'apache-server' not found. Create it (see Questions.bash / SolutionNotes.bash) before expecting scale-up."
  fi
}

start_load() {
  check_lab
  warn_hpa

  echo "🔹 Starting load generator (${LOAD_REPLICAS} replicas, ${PARALLEL_WORKERS} workers each)"
  echo "   Target: ${TARGET_URL}"

  kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${LOAD_DEPLOY}
  namespace: ${NAMESPACE}
  labels:
    app: ${LOAD_DEPLOY}
spec:
  replicas: ${LOAD_REPLICAS}
  selector:
    matchLabels:
      app: ${LOAD_DEPLOY}
  template:
    metadata:
      labels:
        app: ${LOAD_DEPLOY}
    spec:
      containers:
      - name: load
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          URL="${TARGET_URL}"
          WORKERS=${PARALLEL_WORKERS}
          echo "Load generator -> \$URL (\$WORKERS parallel workers)"
          i=1
          while [ "\$i" -le "\$WORKERS" ]; do
            (
              while true; do
                wget -q -O /dev/null "\$URL" 2>/dev/null || true
              done
            ) &
            i=\$((i + 1))
          done
          wait
EOF

  echo "🔹 Waiting for load generator rollout..."
  kubectl rollout status deployment/"$LOAD_DEPLOY" -n "$NAMESPACE" --timeout=120s

  echo ""
  echo "✅ Load started."
  echo "   Watch scaling:  kubectl get hpa,pods -n ${NAMESPACE} -w"
  echo "   CPU metrics:    kubectl top pods -n ${NAMESPACE}"
  echo "   Stop load:      $0 stop"
}

stop_load() {
  echo "🔹 Stopping load generator..."
  kubectl delete deployment "$LOAD_DEPLOY" -n "$NAMESPACE" --ignore-not-found
  echo "✅ Load stopped. Watch HPA scale-down (stabilization window may apply)."
}

show_status() {
  check_lab
  echo "=== HPA ==="
  kubectl get hpa -n "$NAMESPACE" 2>/dev/null || echo "(no HPA in ${NAMESPACE})"
  echo ""
  echo "=== apache-deployment ==="
  kubectl get deploy apache-deployment -n "$NAMESPACE"
  kubectl get pods -n "$NAMESPACE" -l app=apache -o wide
  echo ""
  echo "=== load generator (${LOAD_DEPLOY}) ==="
  kubectl get deploy "$LOAD_DEPLOY" -n "$NAMESPACE" 2>/dev/null || echo "(not running — use: $0 start)"
  kubectl get pods -n "$NAMESPACE" -l app="$LOAD_DEPLOY" 2>/dev/null || true
  echo ""
  echo "=== metrics (if metrics-server is ready) ==="
  kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "(kubectl top not available yet)"
}

case "${1:-}" in
  start)  start_load ;;
  stop)   stop_load ;;
  status) show_status ;;
  *)      usage ;;
esac
