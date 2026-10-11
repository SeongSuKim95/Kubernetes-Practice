# Chap11. Pod의 배치 조건: Taint와 Toleration

> 16장 연재의 11번째 글입니다. 전용 Node의 배치 제한과 Pod의 허용 조건을 연결합니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

자동 확장으로 Pod 수를 늘려도 모든 Node에 같은 애플리케이션을 실행하고 싶지는 않을 수 있습니다. 특정 작업에 사용할 Node를 따로 두었다면, 일반 Pod가 그 자리를 차지하지 않도록 배치 조건을 정해야 합니다.

이번에는 Node 쪽에서 배치를 제한하고, 그 제한을 허용받은 Pod가 실행 위치를 선택하는 과정을 살펴보겠습니다.

## 1. Node의 제한과 Pod의 허용 조건

**Taint**는 Node에 설정하는 배치 제한입니다. 예를 들어 `NoSchedule` 효과의 Taint가 있으면, Scheduler는 이를 허용하지 않는 새 Pod를 해당 Node에 배정하지 않습니다. Pod의 **Toleration**은 특정 Taint를 허용한다는 선언입니다. 기존에 실행 중인 Pod는 `NoSchedule` 추가만으로 퇴거되지 않습니다. [[1]](#ref-1)

Toleration으로 제한을 통과한 뒤에도 실행할 Node를 선택해야 합니다. 특정 Node에 배치하려면 Node의 Label과 Pod의 `nodeSelector`를 함께 사용할 수 있습니다. 허용 조건과 선택 조건을 조합해야 전용 Node의 목적이 분명해집니다. [[2]](#ref-2)

## 2. 문제: 전용 Node의 Pod 배치

[Taint와 Toleration 실습](../Practice/Kubernetes/9.Taints-Tolerations/Questions.bash)에서는 `node01`에 `PERMISSION=granted:NoSchedule`을 설정합니다. 같은 Node를 선택하는 Pod 두 개를 준비하되, 하나에만 해당 Toleration을 넣어 결과를 비교합니다.

Node에는 `workload=dedicated` Label을 붙였고, 이 Label을 가진 Node는 `node01` 하나라고 가정합니다. 기존 실행 중인 Pod 대신 새로 만드는 Pod로 비교하면 `NoSchedule`의 적용 시점을 확인할 수 있습니다.

## 3. 해설: 선택 조건과 배치 결과

아래 Pod는 Node 선택 조건과 Toleration을 함께 선언합니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: allowed-web
spec:
  nodeSelector:
    workload: dedicated
  tolerations:
  - key: PERMISSION
    operator: Equal
    value: granted
    effect: NoSchedule
  containers:
  - name: web
    image: nginx:stable
```

- `nodeSelector`: `workload=dedicated`인 Node를 실행 후보로 선택합니다.
- `tolerations`: 해당 Node의 `PERMISSION=granted:NoSchedule` 제한을 허용합니다.

다른 조건과 자원이 충족되면 이 Pod는 `node01`에 배정됩니다. 같은 선택 조건에서 Toleration만 뺀 Pod는 배정되지 못하고, 이벤트에서 허용하지 않은 Taint를 확인할 수 있습니다. 이 비교를 통해 자원 부족과 배치 정책에 의한 대기를 구분합니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Taint는 Node의 배치를 제한하고, Toleration은 Pod가 그 제한을 허용하도록 합니다. 특정 Node를 선택하는 조건은 별도로 함께 선언합니다.

배치 조건을 만족하는 Pod가 여러 개여도 남은 자원이 모두를 수용하지 못할 수 있습니다. 다음 글에서는 이런 상황에서 Pod의 실행 우선순위를 정하는 방법을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: Taint와 Toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: Pod의 Node 배정](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
