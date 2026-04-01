# Question
# You are managing a WordPress application running in a Kubernetes cluster
# Your task is to adjust the Pod resource requests and limits to ensure stable operation
#
# 쿠버네티스 클러스터에서 실행 중인 WordPress 애플리케이션을 관리하고 있습니다.
# Pod의 리소스 requests와 limits를 조정하여 안정적으로 동작하도록 만드는 것이 과제입니다.

# Tasks
# 1. Scale down the wordpress deployment to 0 replicas
# 2. Edit the deployment and divide the node resource evenly across all 3 pods
# 3. Assign fair and equal CPU and memory to each Pod
# 4. Add sufficient overhead to avoid node instability
# Ensure both the init containers and the main containers use exactly the same resource requests and limits
# After making the changes scale the deployment back to 3 replicas
#
# 
# 1. wordpress Deployment의 replica 수를 0으로 줄이세요.
# 2. Deployment를 편집하고, 노드 자원을 3개의 Pod에 고르게 나누세요.
# 3. 각 Pod에 공정하고 동일한 CPU와 메모리를 할당하세요.
# 4. 노드가 불안정해지지 않도록 충분한 여유(오버헤드)를 두세요.
# init 컨테이너와 메인 컨테이너 모두에 **동일한** resource requests와 limits가 적용되도록 하세요.
# 변경을 마친 뒤 Deployment를 다시 3 replica로 늘리세요.
