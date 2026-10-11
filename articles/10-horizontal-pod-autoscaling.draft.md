# Chap10. 부하에 따른 Pod 수 조절: HPA

> 16장 연재의 10번째 글입니다. 자원 사용량을 기준으로 Deployment의 Pod 수를 늘리고 줄이는 흐름을 살펴봅니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

9장에서는 Pod 하나가 사용할 자원을 정했습니다. 그런데 접속자가 늘어 CPU 사용량이 높아졌다면, 같은 역할의 Pod를 더 실행해 요청을 나누는 방법도 필요합니다. 사용자가 줄어든 뒤에는 늘려 둔 Pod 수를 다시 조정할 수 있어야 합니다.

이때 Kubernetes가 부하를 어떤 값으로 읽고, 그 결과를 Deployment의 Pod 수에 어떻게 반영하는지 살펴보겠습니다.

## 1. 사용량과 원하는 Pod 수의 연결

**HPA**(HorizontalPodAutoscaler)는 관찰한 메트릭과 목표값을 비교해 워크로드의 원하는 복제본 수를 조절하는 리소스입니다. CPU 사용률을 기준으로 삼는 경우, 각 컨테이너의 CPU 요청량이 사용률 계산의 기준이 됩니다. 자원 메트릭은 일반적으로 Metrics Server를 통해 제공됩니다. [[1]](#ref-1)

HPA Controller가 Deployment의 복제본 수를 바꾸면 기존의 Deployment와 ReplicaSet 관리 흐름을 통해 Pod 수가 조정됩니다. 새 Pod가 준비 상태를 갖추면 요청을 나눠 처리합니다. 이때 새 Pod를 배정할 Node 자원도 충분해야 합니다.

## 2. 문제: CPU 부하에 따른 확장과 축소

[HPA 실습](../Practice/Kubernetes/8.HPA/Questions.bash)의 `autoscale` Namespace에는 `apache-deployment`가 있습니다. CPU 사용률 목표를 50%로 두고 Pod 수를 1~4개로 조절하며, 축소 안정화 시간을 30초로 설정하는 것이 목표입니다.

실습 전에 대상 컨테이너의 CPU 요청량과 메트릭 수집을 확인합니다. 부하를 주었을 때뿐 아니라 제거한 뒤의 변화를 비교해야 자동 확장의 전체 흐름을 확인할 수 있습니다.

## 3. 해설: 확장 범위와 안정화 설정

다음 선언은 실습의 기존 Deployment에 연결할 HPA입니다.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: apache-server
  namespace: autoscale
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: apache-deployment
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 30
```

- `scaleTargetRef`: Pod 수를 조절할 Deployment를 선택합니다.
- `minReplicas`와 `maxReplicas`: 조절 가능한 Pod 수의 범위를 정합니다.
- `averageUtilization`: CPU 요청량 대비 평균 사용률의 목표입니다.
- `stabilizationWindowSeconds`: 최근 권고값을 고려해 급격한 축소를 완화하는 기간입니다.

부하를 준 뒤에는 관찰한 사용률, HPA가 원하는 Pod 수, 실제 준비된 Pod 수를 비교합니다. 부하 제거 후의 축소 시점은 메트릭과 조절 주기의 영향을 받으므로, 안정화 시간을 정확한 축소 예약 시각으로 해석하지 않습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. HPA는 메트릭을 기준으로 원하는 Pod 수를 조절하고, 기존 워크로드 Controller가 실제 개수를 맞춥니다. CPU 요청량과 메트릭 수집이 이 판단의 기반입니다.

Pod가 늘어날수록 실행 위치도 중요해집니다. 다음 글에서는 특정 용도의 Node에 필요한 Pod만 배치하는 방법을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: HPA](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)
