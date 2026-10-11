# Chap12. Pod의 실행 우선순위: PriorityClass와 선점

> 16장 연재의 12번째 글입니다. 자원이 부족할 때 Pod의 중요도를 스케줄링 판단에 반영하는 방법을 살펴봅니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

11장에서는 Pod가 어느 Node에 배정될 수 있는지 정했습니다. 이제 배치 조건을 만족하는 두 애플리케이션이 마지막 남은 자원을 두고 기다린다고 가정해 보겠습니다. 운영에 중요한 작업을 먼저 실행하려면 Node 선택 조건에 더해 Pod의 우선순위가 필요합니다.

우선순위에 따라 배정 순서가 달라지는 과정과, 이미 실행 중인 낮은 우선순위 Pod의 자원을 확보하는 선점을 구분해 살펴보겠습니다.

## 1. Pod의 우선순위와 자원 확보

**PriorityClass**는 Pod가 사용할 우선순위 값을 정의하는 클러스터 범위 리소스입니다. Pod가 `priorityClassName`으로 이를 참조하면 해당 우선순위가 적용됩니다. Scheduler는 대기 중인 Pod를 처리할 때 우선순위를 고려합니다. [[1]](#ref-1)

높은 우선순위 Pod를 배정할 공간이 없으면 **선점**(preemption)을 검토할 수 있습니다. 낮은 우선순위 Pod를 제거했을 때 배치 조건과 자원을 충족하는 Node가 있는지 판단하는 과정입니다. 실행 위치의 조건이 맞지 않으면 우선순위만 높여도 배정 문제가 해결되지 않습니다.

이러한 판단을 이해하려면 PriorityClass가 선언된 값과 실제 새 Pod에 적용된 값을 함께 확인해야 합니다.

## 2. 문제: 기존 우선순위를 기준으로 한 설정

[PriorityClass 실습](../Practice/Kubernetes/10.PriorityClass/Questions.bash)에서는 기존 사용자 정의 PriorityClass 중 가장 높은 값보다 1 작은 값으로 `high-priority`를 만듭니다. 이를 `priority` Namespace의 `busybox-logger` Deployment에 적용하는 것이 목표입니다.

클러스터의 기본 시스템용 클래스는 비교에서 제외합니다. 먼저 실제 사용자 정의 값을 조회해야 새 클래스의 값을 결정할 수 있습니다.

## 3. 해설: 클래스 생성과 새 Pod 확인

사용자 정의 최고값이 1000인 학습 상황에서는 다음처럼 999를 선언합니다.

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 999
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: Priority for the logger workload
```

- `value`: Pod에 적용할 우선순위 값입니다. 실습에서는 조회한 최고값을 기준으로 계산합니다.
- `preemptionPolicy`: 낮은 우선순위 Pod에 대한 선점 검토를 허용합니다.

Deployment의 Pod 템플릿에 `priorityClassName: high-priority`를 설정하면 변경된 템플릿으로 새 Pod가 만들어집니다. 새 Pod의 클래스와 우선순위 값을 확인하고, 자원이 충분한 경우 정상 배정되는지 살펴봅니다.

이 설정 문제와 실제 선점 관찰은 구분합니다. 선점 동작을 관찰하려면 낮은 우선순위 Pod가 자원을 사용 중인 별도 학습 상황을 만들고, 새 Pod의 이벤트와 기존 Pod의 종료를 함께 확인해야 합니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. PriorityClass는 Pod의 중요도를 스케줄링에 반영하고, 선점은 필요한 경우 낮은 우선순위 Pod의 자원을 확보하는 과정입니다. 우선순위와 Node 배치 조건은 함께 충족되어야 합니다.

Pod의 실행 조건을 정했다면 애플리케이션 사이의 통신 범위도 정할 차례입니다. 다음 글에서는 필요한 상대와 포트만 허용하는 네트워크 정책을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: Pod 우선순위와 선점](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
