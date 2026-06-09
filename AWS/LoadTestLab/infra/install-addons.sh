#!/usr/bin/env bash
# 클러스터 애드온 설치:
#   1) AWS Load Balancer Controller (ALB Ingress용, IRSA)
#   2) metrics-server (HPA CPU 메트릭 — eksctl/EKS 애드온이 있으면 skip)
#   3) EBS CSI driver + gp3 기본 StorageClass (Prometheus PVC용)
#
# 사전: create-eks-cluster.sh 완료(OIDC 활성), helm 설치.
#
# 사용:
#   export AWS_REGION=ap-northeast-2
#   ./install-addons.sh
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
CLUSTER_NAME="${CLUSTER_NAME:-loadtest-lab}"
LBC_VERSION="${LBC_VERSION:-v2.7.2}"   # AWS Load Balancer Controller IAM policy 버전

for bin in eksctl kubectl helm aws curl; do
  command -v "${bin}" >/dev/null 2>&1 || { echo "필요한 명령 없음: ${bin}" >&2; exit 1; }
done

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# ───────────────────────────────────────────────────────────────
# 1) AWS Load Balancer Controller
# ───────────────────────────────────────────────────────────────
echo "=== [1/3] AWS Load Balancer Controller ==="
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

if ! aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  TMP_POLICY="$(mktemp)"
  curl -fsSL -o "${TMP_POLICY}" \
    "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json"
  aws iam create-policy --policy-name "${POLICY_NAME}" --policy-document "file://${TMP_POLICY}"
  rm -f "${TMP_POLICY}"
else
  echo "IAM policy 재사용: ${POLICY_ARN}"
fi

eksctl create iamserviceaccount \
  --cluster "${CLUSTER_NAME}" --region "${AWS_REGION}" \
  --namespace kube-system --name aws-load-balancer-controller \
  --attach-policy-arn "${POLICY_ARN}" \
  --approve --override-existing-serviceaccounts

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${AWS_REGION}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# ───────────────────────────────────────────────────────────────
# 2) metrics-server (eksctl create cluster 가 EKS 애드온으로 이미 설치한 경우 skip)
# ───────────────────────────────────────────────────────────────
metrics_server_present() {
  kubectl get deploy -n kube-system metrics-server &>/dev/null \
    || aws eks list-addons --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
         --query 'addons' --output text 2>/dev/null | grep -qw metrics-server
}

# EKS 애드온 Pod 라벨과 upstream manifest 가 패치한 Service selector 불일치 시
# endpoints 가 비어 Metrics API not available 가 난다. selector 를 EKS Pod 에 맞춘다.
fix_metrics_server_service() {
  if ! kubectl get svc -n kube-system metrics-server &>/dev/null; then
    return 0
  fi
  local endpoints
  endpoints="$(kubectl -n kube-system get endpoints metrics-server -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
  if [[ -n "${endpoints}" ]]; then
    echo "[metrics-server] Service endpoints 정상 — selector 수정 불필요"
    return 0
  fi
  if ! kubectl get deploy -n kube-system metrics-server &>/dev/null; then
    return 0
  fi
  echo "[metrics-server] endpoints 비어 있음 — Service selector 를 EKS 애드온 Pod 라벨에 맞춤"
  # merge patch 는 upstream manifest 가 남긴 k8s-app selector 키를 제거하지 못함 → json replace
  kubectl -n kube-system patch svc metrics-server --type=json -p='[
    {"op": "replace", "path": "/spec/selector", "value": {
      "app.kubernetes.io/instance": "metrics-server",
      "app.kubernetes.io/name": "metrics-server"
    }}
  ]'
}

wait_metrics_server_ready() {
  fix_metrics_server_service
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
  echo "metrics-server Pod:"
  kubectl -n kube-system get pods -l app.kubernetes.io/name=metrics-server -o wide 2>/dev/null \
    || kubectl -n kube-system get pods -l k8s-app=metrics-server -o wide
  echo "metrics-server endpoints:"
  kubectl -n kube-system get endpoints metrics-server 2>/dev/null || true
  local i
  for i in 1 2 3 4 5 6; do
    if kubectl top nodes &>/dev/null; then
      echo "metrics API 동작 확인 (kubectl top nodes):"
      kubectl top nodes
      return 0
    fi
    echo "metrics API 준비 대기 (${i}/6)..."
    sleep 10
  done
  echo "metrics API 미동작 — 'kubectl get apiservice v1beta1.metrics.k8s.io' 확인" >&2
  kubectl get apiservice v1beta1.metrics.k8s.io 2>/dev/null || true
  return 1
}

echo "=== [2/3] metrics-server ==="
if metrics_server_present; then
  echo "metrics-server 가 이미 설치됨 (EKS 애드온). upstream manifest apply 건너뜀."
  wait_metrics_server_ready
else
  echo "metrics-server 없음 — upstream manifest 설치"
  kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  wait_metrics_server_ready
fi

# ───────────────────────────────────────────────────────────────
# 3) EBS CSI driver + gp3 StorageClass
# ───────────────────────────────────────────────────────────────
echo "=== [3/3] EBS CSI driver + gp3 ==="
EBS_ROLE_NAME="AmazonEKS_EBS_CSI_DriverRole_${CLUSTER_NAME}"
eksctl create iamserviceaccount \
  --cluster "${CLUSTER_NAME}" --region "${AWS_REGION}" \
  --namespace kube-system --name ebs-csi-controller-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --role-only --role-name "${EBS_ROLE_NAME}" \
  --approve --override-existing-serviceaccounts

eksctl create addon --cluster "${CLUSTER_NAME}" --region "${AWS_REGION}" \
  --name aws-ebs-csi-driver \
  --service-account-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${EBS_ROLE_NAME}" \
  --force

# gp3 를 기본 StorageClass 로 (기존 gp2 기본 해제)
kubectl patch storageclass gp2 \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' 2>/dev/null || true

kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
EOF

echo ""
echo "=== 검증 ==="
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=180s || true
kubectl -n kube-system get deploy metrics-server 2>/dev/null || true
kubectl get sc
echo ""
echo "완료. 다음: monitoring/install-monitoring.sh 그리고 argocd/install-argocd.sh"
