# Question
# There is a deployment named nodeport-deployment in the relative namespace
#
# [한국어 번역]
# 질문
# relative 네임스페이스에 nodeport-deployment 라는 Deployment가 있다.

# Tasks:
# 1. Configure the deployment so it can be exposed on port 80, name=http, protocol TCP
# 2. Create a new Service named nodeport-service exposing the container port 80, protocol TCP, Node Port 30080
# 3. Configure the new Service to also expose the individual pods using NodePort
#
# [한국어 번역]
# 작업:
# 1. Deployment가 80 포트로 노출될 수 있도록 설정한다. name=http, protocol=TCP 로 지정한다.
# 2. nodeport-service 라는 새 Service를 생성한다. 컨테이너 포트 80/TCP를 노출하고, NodePort는 30080으로 설정한다.
# 3. 새 Service가 NodePort를 사용해 개별 Pod들도(엔드포인트로 잡힌 Pod들) 노출되도록 설정한다.
