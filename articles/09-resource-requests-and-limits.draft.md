# Chap09. 애플리케이션의 자원 관리: requests와 limits

> 16장 연재의 9번째 글입니다. 컨테이너의 CPU와 메모리 설정을 Node 배정과 실행 중 사용량에 연결합니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

저장한 데이터를 유지하더라도 애플리케이션이 사용할 메모리가 부족하면 실행이 불안정해질 수 있습니다. 여러 Pod가 같은 Node에서 동작하므로, 각 애플리케이션에 필요한 자원과 Node에 남길 여유를 함께 생각해야 합니다.

5장에서 살펴본 메모리 부족에 따른 배정 실패도 이 설정과 연결됩니다. 필요한 양을 선언하는 기준과 실행 중 사용을 제한하는 기준을 구분해 보겠습니다.

## 1. 배정 기준과 사용 제한

**requests**는 컨테이너가 필요로 하는 자원 요청량입니다. Scheduler는 이 요청량을 Node의 배정 가능한 자원과 비교해 실행 위치를 고릅니다. 반면 **limits**는 실행 중 사용할 수 있는 자원의 상한입니다. CPU 제한에 도달하면 실행 시간이 제한될 수 있고, 메모리 제한을 넘기면 메모리 부족에 따른 프로세스 종료가 발생할 수 있습니다. [[1]](#ref-1)

요청량을 너무 크게 잡으면 실제 사용량이 낮아도 새 Pod를 배정하기 어려워집니다. 너무 작게 잡으면 같은 Node에 많은 Pod가 모여 자원을 두고 경쟁할 수 있습니다. 따라서 사용량을 관찰하고 운영에 필요한 여유를 포함해 값을 정합니다.

## 2. 문제: 세 Pod의 자원 배분

[자원 할당 실습](../Practice/Kubernetes/3.Resource-Allocation/Questions.bash)에서는 WordPress Pod 세 개가 실행될 자원을 조정합니다. Node의 자원을 모두 나눠 쓰는 대신 시스템과 다른 Pod에 필요한 몫을 남기고, init 컨테이너와 주 컨테이너에 문제에서 요구하는 동일한 설정을 적용합니다.

실습에서는 Deployment를 0개로 줄여 설정을 수정한 뒤 다시 3개로 늘립니다. 이 과정에는 애플리케이션 중단이 생기므로, 학습 환경에서 자원 계산과 적용 결과를 확인합니다.

## 3. 해설: 요청량 계산과 실행 결과

Node가 Pod에 제공할 수 있는 자원에서 기존 Pod들의 요청량과 추가 여유를 먼저 고려합니다. 그 안에서 WordPress 세 Pod의 요청량이 들어가는지 확인하고, 메모리 사용량과 CPU 부하를 바탕으로 제한값을 정합니다. 일반적인 init 컨테이너는 순서대로 실행되므로, Pod의 배정 요청량을 계산할 때는 주 컨테이너들과 동시에 실행하는 것으로 단순 합산하지 않습니다. [[2]](#ref-2)

다음은 요청량과 제한을 구분하는 간단한 Pod 선언입니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
spec:
  containers:
  - name: web
    image: nginx:stable
    resources:
      requests:
        cpu: 250m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
```

- `requests`: 이 컨테이너의 배정 기준으로 CPU 0.25개와 메모리 128Mi를 요청합니다.
- `limits`: 실행 중 CPU 0.5개와 메모리 256Mi를 상한으로 설정합니다.

적용 후에는 배정 실패 이벤트, 컨테이너 종료 이유와 실제 사용량을 함께 확인합니다. 실행이 안정되어도 요청이 늘면 기존 Pod 수만으로 처리하기 어려워질 수 있습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. requests는 Node 배정의 기준이고 limits는 실행 중 자원 사용의 상한입니다. 설정은 애플리케이션의 사용량과 Node의 여유를 함께 고려해야 합니다.

다음 글에서는 부하가 변할 때 필요한 Pod 수를 자동으로 조절하는 방법을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: 컨테이너 자원 관리](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: init 컨테이너의 자원 공유](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/#resource-sharing-within-containers)
