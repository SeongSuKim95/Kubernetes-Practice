#!/usr/bin/env bash
#
# echo Deployment + Service + Ingress(TLS) + curl-client 내부 검증
# 전제: ingress-nginx 설치됨, IngressClass 이름 "nginx"
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ▶ 실습자마다 반드시 바꿀 값 (export 후 실행하는 것을 권장)
#
#   NS        — 본인만 쓰는 네임스페이스 (다른 실습자와 절대 겹치지 않게. 예: lab-hong, team3-kim)
#   APP_HOST  — 도메인으로 외부 검증 시: 본인이 쓸 서브도메인 전체 FQDN (예: hong.k8s-study.club).
#               운영자에게 FQDN 사용을 요청 → 운영자가 Route53에 A 레코드(EIP) 등록 후,
#               그와 동일한 문자열을 export. (개인만: 생략 시 「공인IP.nip.io」 자동)
#
#   (선택) INGRESS_PATH — URL 경로 접두사. 기본 /echo. 겹치면 안 되지만 보통 공통으로 둬도 됨.
#   (선택) DEPLOY_NAME, SVC_NAME, INGRESS_NAME, CURL_POD, TLS_SECRET
#               — 한 NS 안에서만 유일하면 됨. 여러 Ingress를 나누지 않으면 기본값 그대로 두면 됨.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# 사용 예 (여러 명이 같은 EC2에서 실습):
#   export NS=lab-hong
#   export APP_HOST=hong.k8s-study.club
#   ./ingressLab.sh
#
# 사용 예 (혼자, Route53 없이):
#   export NS=lab-me
#   ./ingressLab.sh
#
set -euo pipefail

# ─── [실습자 필수] 동료와 겹치지 않는 네임스페이스 이름 ─────────────────
if [[ -z "${NS:-}" ]]; then
  echo "NS가 비어 있습니다. 예: export NS=lab-hong  후 다시 실행하세요." >&2
  exit 1
fi

# ─── [실습자 선택] 앱·Ingress 리소스 이름 (한 NS 안에서만 유일하면 됨) ───
DEPLOY_NAME="${DEPLOY_NAME:-echo}"
SVC_NAME="${SVC_NAME:-echo-service}"
INGRESS_NAME="${INGRESS_NAME:-echo}"
TLS_SECRET="${TLS_SECRET:-echo-tls}"
CURL_POD="${CURL_POD:-curl-client}"

# ─── [실습자 선택] 외부에서 붙일 URL 경로 (Ingress path) ─────────────────
INGRESS_PATH="${INGRESS_PATH:-/echo}"

# --- 공인 IP (메타데이터). EIP 연결 시 여기서 읽힌 값이 곧 외부 접속 IP ---
TOKEN=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true)
PUBLIC_IP=""
if [[ -n "${TOKEN}" ]]; then
  PUBLIC_IP=$(curl -fsS -H "X-aws-ec2-metadata-token: ${TOKEN}" "http://169.254.169.254/latest/meta-data/public-ipv4" 2>/dev/null || true)
fi

# ─── [실습자 필수에 가까움] Ingress TLS·Host에 쓸 FQDN ───────────────────
#   도메인 실습: 운영자가 Route53에 A 레코드 등록 후, 그 FQDN을 APP_HOST에 넣음.
#   단독 연습: 비워 두면 아래에서 「공인IP.nip.io」로 자동 설정.
if [[ -z "${APP_HOST:-}" ]]; then
  if [[ -n "${PUBLIC_IP}" ]]; then
    APP_HOST="${PUBLIC_IP}.nip.io"
    echo "APP_HOST 미지정 → nip.io 사용: ${APP_HOST}  (도메인 실습: 운영자에게 서브도메인 요청 후 export APP_HOST=...)"
  else
    echo "메타데이터에 public-ipv4가 없습니다. export APP_HOST=본인.서브도메인.example.org 를 지정하세요." >&2
    exit 1
  fi
else
  echo "APP_HOST=${APP_HOST}"
  if [[ "${APP_HOST}" == *.nip.io ]]; then
    echo "  (nip.io: 운영자 Route53 등록 없이 사용)"
  else
    echo "  (운영자가 Route53에 위 FQDN → A(EIP) 등록했는지 확인 후 외부 curl 권장)"
  fi
fi

if ! command -v kubectl &>/dev/null; then
  echo "kubectl 없음. ubuntu 사용자이거나: export KUBECONFIG=/etc/kubernetes/admin.conf" >&2
  exit 1
fi

if ! kubectl get ingressclass nginx &>/dev/null; then
  echo "IngressClass 'nginx' 없음. ingress-nginx 설치 필요." >&2
  exit 1
fi

echo "=== Namespace: ${NS} ==="
kubectl create namespace "${NS}" 2>/dev/null || true

echo "=== TLS Secret (호스트 ${APP_HOST}용 자체서명) ==="
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${TMP}/tls.key" -out "${TMP}/tls.crt" \
  -subj "/CN=${APP_HOST}" -addext "subjectAltName=DNS:${APP_HOST}"
kubectl -n "${NS}" delete secret "${TLS_SECRET}" 2>/dev/null || true
kubectl -n "${NS}" create secret tls "${TLS_SECRET}" \
  --cert="${TMP}/tls.crt" --key="${TMP}/tls.key"

echo "=== Deployment (echoserver) ==="
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEPLOY_NAME}
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: gcr.io/google_containers/echoserver:1.10
        ports:
        - containerPort: 8080
EOF
kubectl -n "${NS}" rollout status "deployment/${DEPLOY_NAME}" --timeout=300s

echo "=== Service (ClusterIP) ==="
kubectl -n "${NS}" delete svc "${SVC_NAME}" 2>/dev/null || true
kubectl -n "${NS}" expose deployment "${DEPLOY_NAME}" \
  --name="${SVC_NAME}" --port=8080 --target-port=8080

echo "=== Ingress (ingressClassName: nginx, TLS, host=${APP_HOST}) ==="
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${INGRESS_NAME}
  namespace: ${NS}
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ${APP_HOST}
    secretName: ${TLS_SECRET}
  rules:
  - host: ${APP_HOST}
    http:
      paths:
      - path: ${INGRESS_PATH}
        pathType: Prefix
        backend:
          service:
            name: ${SVC_NAME}
            port:
              number: 8080
EOF

echo "=== curl-client Pod (클러스터 내부 검증: 다른 Pod/Ingress로만 호출) ==="
kubectl -n "${NS}" delete pod "${CURL_POD}" --ignore-not-found --wait=true 2>/dev/null || true
kubectl -n "${NS}" run "${CURL_POD}" --image=curlimages/curl:8.5.0 --restart=Never --command -- sleep 3600
kubectl -n "${NS}" wait --for=condition=Ready "pod/${CURL_POD}" --timeout=120s

INGRESS_CTRL_SVC="ingress-nginx-controller.ingress-nginx.svc.cluster.local"

echo "=== 내부 ① curl-client Pod → echo Service 직통 (Ingress 비경유) ==="
kubectl -n "${NS}" exec "${CURL_POD}" -- curl -sS -o /dev/null -w "HTTP %{http_code}\n" "http://${SVC_NAME}.${NS}.svc.cluster.local:8080${INGRESS_PATH}"

echo "=== 내부 ② curl-client Pod → ingress-nginx(Service) → Ingress 규칙 → echo Pod ==="
kubectl -n "${NS}" exec "${CURL_POD}" -- curl -sS -k -o /dev/null -w "HTTP %{http_code}\n" -H "Host: ${APP_HOST}" "https://${INGRESS_CTRL_SVC}:443${INGRESS_PATH}"

HTTP_NP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null || true)
HTTPS_NP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || true)

if [[ -z "${PUBLIC_IP}" ]]; then
  PUBLIC_IP="<Elastic IP 또는 이 인스턴스 공인 IP>"
fi

echo ""
echo "=== 리소스 (${NS}) ==="
kubectl -n "${NS}" get deploy,svc,ingress,pod -o wide

cat <<ENDMSG

=== [실습자] 외부 HTTPS — PUBLIC_IP는 EIP(또는 공인 IP), 본인 PC 등에서 실행 ===
  curl -vk --resolve ${APP_HOST}:${HTTPS_NP}:${PUBLIC_IP} \\
    "https://${APP_HOST}:${HTTPS_NP}${INGRESS_PATH}"

=== [실습자] 내부 ②와 동일 — curl-client 안에서 Ingress 경유 HTTPS (수동 재실행 시) ===
  kubectl -n ${NS} exec ${CURL_POD} -- curl -sS -k -o /dev/null -w '%{http_code}\n' -H "Host: ${APP_HOST}" \\
    "https://ingress-nginx-controller.ingress-nginx.svc.cluster.local:443${INGRESS_PATH}"

=== [실습자] EC2 호스트(SSH)에서 NodePort로 검증할 때 — HTTP는 308, HTTPS는 200 ===
  curl -sS -k -o /dev/null -w '%{http_code}\n' -H "Host: ${APP_HOST}" \\
    "https://127.0.0.1:${HTTPS_NP}${INGRESS_PATH}"

NS=${NS}  APP_HOST=${APP_HOST}  CURL_POD=${CURL_POD}  HTTPS_NODEPORT=${HTTPS_NP}  HTTP_NODEPORT=${HTTP_NP}  PUBLIC_IP=${PUBLIC_IP}
ENDMSG
