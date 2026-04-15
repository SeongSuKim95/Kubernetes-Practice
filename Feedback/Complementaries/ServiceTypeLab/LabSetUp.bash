#!/bin/bash
# ServiceTypeLab: ClusterIP vs NodePort (internal-only)
#
# 요구사항:
# - 매니페스트는 EOF로 생성하지 않고, 학습자가 vim으로 직접 작성
# - 클러스터 내부 테스트만 수행
# - NodePort vs ClusterIP "호출 차이"가 명확히 드러나도록 구성
#
# 사용:
#   bash LabSetUp.bash
#
# 정리:
#   kubectl delete namespace lab-servicetype

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${HERE}"

NS="lab-servicetype"
NODEPORT="30081"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "필수 명령이 없습니다: $1"
    exit 1
  }
}

require kubectl
require vim

echo ""
echo "=== ServiceTypeLab (ClusterIP vs NodePort) ==="
echo ""
echo "- 네임스페이스: ${NS}"
echo "- NodePort(고정): ${NODEPORT}"
echo "- 매니페스트는 vim으로 직접 작성합니다."
echo ""

echo "[1/6] 매니페스트 파일 준비"
echo "아래 파일들을 vim으로 작성합니다(비어있으면 템플릿 참고: MANIFEST_TEMPLATES.md)."
FILES=(01-namespace.yaml 02-backend-deployment.yaml 03-services.yaml 04-ingress.yaml 05-networkpolicy.yaml)
for f in "${FILES[@]}"; do
  if [[ ! -f "${f}" ]]; then
    : > "${f}"
  fi
done

echo ""
echo "템플릿 보기: ${HERE}/MANIFEST_TEMPLATES.md"
echo ""

for f in "${FILES[@]}"; do
  echo "--------------------------------------------"
  echo "vim ${f}"
  echo "저장 후 종료(:wq)하면 다음 단계로 진행합니다."
  echo "--------------------------------------------"
  vim "${f}"
done

echo ""
echo "[2/6] 매니페스트 적용"
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-backend-deployment.yaml
kubectl apply -f 03-services.yaml
kubectl apply -f 04-ingress.yaml

echo ""
echo "[3/6] 배포 완료 대기"
kubectl rollout status deployment/web -n "${NS}" --timeout=180s

echo ""
echo "[4/6] curl-client Pod 생성(내부 호출용)"
kubectl delete pod curl-client -n "${NS}" --ignore-not-found=true >/dev/null
kubectl run curl-client \
  -n "${NS}" \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --command -- sh -c "sleep 36000" >/dev/null
kubectl wait --for=condition=Ready pod/curl-client -n "${NS}" --timeout=180s

echo ""
echo "[5/6] (선택) NetworkPolicy 적용"
if [[ -s "05-networkpolicy.yaml" ]]; then
  kubectl apply -f 05-networkpolicy.yaml
else
  echo "05-networkpolicy.yaml 이 비어있어서 스킵합니다."
fi

echo ""
echo "[6/6] 내부 curl 테스트"
echo ""
echo "A) ClusterIP 타입 Service: web-cip (DNS:80) => 성공"
kubectl exec -n "${NS}" curl-client -- \
  curl -sS -o /dev/null -w "web-cip DNS => HTTP %{http_code}\n" "http://web-cip.${NS}.svc.cluster.local:80/"

echo ""
echo "B) NodePort 타입 Service: web-np (DNS:80) => 성공"
echo "   (NodePort라도 내부에서는 service port로 동일하게 호출됨)"
kubectl exec -n "${NS}" curl-client -- \
  curl -sS -o /dev/null -w "web-np  DNS => HTTP %{http_code}\n" "http://web-np.${NS}.svc.cluster.local:80/"

echo ""
echo "C) Ingress 경유 호출 (Ingress Controller가 설치되어 있어야 함)"
echo "   - /cip -> web-cip"
echo "   - /np  -> web-np"

INGRESS_SVC_NS=""
INGRESS_SVC_NAME=""

# 흔한 ingress-nginx 서비스 탐색(있으면 사용)
if kubectl get svc -n ingress-nginx ingress-nginx-controller >/dev/null 2>&1; then
  INGRESS_SVC_NS="ingress-nginx"
  INGRESS_SVC_NAME="ingress-nginx-controller"
fi

# 위 이름이 아니면 label 기반으로 한 번 더 탐색
if [[ -z "${INGRESS_SVC_NAME}" ]]; then
  # controller component 라벨을 가진 서비스 중 하나 선택
  INGRESS_SVC_NS="$(kubectl get svc -A -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || true)"
  INGRESS_SVC_NAME="$(kubectl get svc -A -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

if [[ -n "${INGRESS_SVC_NAME}" ]]; then
  echo "Ingress Controller Service: ${INGRESS_SVC_NS}/${INGRESS_SVC_NAME}"
  kubectl exec -n "${NS}" curl-client -- \
    curl -sS -o /dev/null -w "ingress /cip => HTTP %{http_code}\n" -H "Host: lab.local" "http://${INGRESS_SVC_NAME}.${INGRESS_SVC_NS}.svc.cluster.local/cip/"
  kubectl exec -n "${NS}" curl-client -- \
    curl -sS -o /dev/null -w "ingress /np  => HTTP %{http_code}\n" -H "Host: lab.local" "http://${INGRESS_SVC_NAME}.${INGRESS_SVC_NS}.svc.cluster.local/np/"
else
  echo "Ingress Controller Service를 찾지 못해 Ingress 호출을 스킵합니다."
  echo "  - ingress-nginx 등을 설치한 뒤 다시 시도하세요."
fi

echo ""
echo "요약"
echo "  - (A)(B): 내부 Pod->Service 호출은 type과 무관하게 DNS:servicePort 로 접근"
echo "  - (C): Ingress는 L7 진입/라우팅 계층이며, backend Service는 보통 ClusterIP면 충분"
echo ""
echo "정리(원할 때): kubectl delete namespace ${NS}"

