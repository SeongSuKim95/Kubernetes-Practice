# Step 0: 노드 자원 확인 (requests/limits 숫자를 정하기 전)
# 문제는 "노드 자원을 3개 Pod에 고르게 나누고 여유분을 둔다"이므로, 먼저 노드에 얼마나 스케줄 여유가 있는지 본다.
kubectl get nodes
kubectl describe nodes
# 한 노드만 보려면: kubectl describe node <노드이름>
# (선택) metrics-server가 있으면 실제 사용량 참고: kubectl top nodes

# describe 출력에서 참고할 것:
# - Allocatable … 스케줄에 쓸 수 있는 CPU·메모리 상한(보통 Capacity보다 작음)
# - Allocated resources … 이미 Pod들이 예약한 requests 합(남은 여유 추정에 사용)
# - 남는 여유를 보수적으로 잡은 뒤, 시스템·버스트용으로 일부를 여유분(오버헤드)으로 빼고,
#   나머지를 3개 Pod에 나눈다.
# - Pod 하나에는 init + 메인 컨테이너가 있고, 둘 다 같은 requests를 쓰므로
#   Pod당 스케줄 요청(CPU/memory request) ≈ (컨테이너 1개의 request) × 2

# Step 1: pause workload
kubectl scale deployment wordpress --replicas 0

# Step 2: edit deployment (set same resources on all init + main containers)
kubectl edit deployment wordpress
# In spec.template.spec.containers[] and spec.template.spec.initContainers[] set:
# resources:
#   requests:
#     cpu: "300m"
#     memory: "600Mi"
#   limits:
#     cpu: "400m"
#     memory: "700Mi"
# (아래 숫자는 예시이다. Step 0에서 본 Allocatable·다른 워크로드·여유분에 맞게 조정할 것.
#  init과 메인은 반드시 동일한 requests/limits.)

# Step 3: resume replicas
kubectl scale deployment wordpress --replicas 3
kubectl rollout status deployment wordpress
kubectl get pods -l app=wordpress

# Step 4: call each Pod's port 80 to verify it responds
# (LabSetUp에서 만든 curl-client Pod를 이용해 각 Pod IP:80으로 호출한다.)
for ip in $(kubectl get pods -l app=wordpress -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}'); do
  echo "==> curl http://${ip}:80/"
  kubectl exec curl-client -- curl -fsS "http://${ip}:80/" >/dev/null
done
