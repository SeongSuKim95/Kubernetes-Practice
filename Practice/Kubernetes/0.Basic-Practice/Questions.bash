# Question Basic Practice (Namespace / Pod / Deployment / Service / Labels)
#
# Namespace: dev, prod
#
# 목표
# - Introduction/AboutKubernetes.md 2장의 핵심 내용을 kubectl로 직접 검증한다.
#
# Tasks
# 1) Namespace 생성
#    - dev, prod 네임스페이스 생성
#
# 2) Pod 최소 단위 실습
#    - 단일 Pod(web-pod) 생성
#    - Pod IP/상태 확인
#    - 단일 Pod 삭제 후 재생성되지 않는 것 확인
#
# 3) Deployment 실습 (Desired State / Self-Healing)
#    - hello-nginx Deployment(replicas=3) 생성
#    - Deployment가 생성한 Pod 1개 강제 삭제 후 자동 복구(Self-Healing) 확인
#    - rollout history 확인
#
# 4) Service 실습 (고정 접근점 / selector 매칭)
#    - hello-svc(ClusterIP) 생성, endpoint 확인
#    - curl-client Pod에서 "Pod 직접 호출(Pod IP)"과 "Service 호출(DNS)" 비교
#    - 특정 Pod 삭제 후 Pod 직접 호출은 실패하고, Service 호출은 계속 성공하는지 확인
#
# 5) 라벨 매칭 오류 시나리오
#    5-1) Deployment selector.matchLabels != template.metadata.labels (검증 에러)
#    5-2) Service metadata.labels만 다름 (통신 정상)
#    5-3) Service spec.selector 불일치 (endpoint 없음)
#         - kubectl get ep로 endpoints <none> 확인
#         - curl-client에서 해당 Service 호출 시 실패/timeout 확인
#
# 6) Namespace 경계 실습
#    - prod 네임스페이스에 동일 이름 Service 생성
#    - DNS 스코프(service.namespace.svc.cluster.local) 차이 확인
#
# 검증 포인트
# - kubectl get ns,po,deploy,svc,ep -A
# - kubectl describe / logs / events로 원인 추적
# - 각 실패 시나리오의 원인 설명 가능해야 함
