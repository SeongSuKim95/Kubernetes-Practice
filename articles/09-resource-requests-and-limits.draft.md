# Chap09. 애플리케이션의 자원 관리: requests와 limits

> 16장 연재의 9번째 글입니다. CPU와 메모리 요청량이 Pod의 배정에 어떻게 쓰이는지, 실행 중 자원 제한이 어떤 결과로 이어지는지 살펴봅니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

8장에서는 Pod가 교체되어도 데이터를 이어서 사용하는 방법을 살펴봤습니다. 이제 저장 공간을 마련한 애플리케이션이 여러 Pod와 함께 실행되는 상황을 생각해 보겠습니다. 접속자가 몰린 웹 서버가 CPU를 많이 사용하거나, 데이터를 처리하는 프로그램의 메모리 사용량이 계속 늘어나면 같은 Node의 다른 애플리케이션도 영향을 받을 수 있습니다.

각 Pod를 어디에 배치할지 정하려면 먼저 실행에 필요한 자원을 알아야 합니다. 배치한 뒤에도 하나의 컨테이너가 사용할 수 있는 범위를 정해 두어야 여러 애플리케이션이 자원을 나눠 쓸 수 있습니다. Kubernetes에서는 이 두 판단을 자원 요청량인 `requests`와 사용 상한인 `limits`로 표현합니다.

5장에서 자원이 부족해 Pod가 `Pending`에 머무는 상황을 봤다면, 이번에는 그 판단의 기준을 직접 선언해 보겠습니다. Node의 자원을 세 Pod에 나누는 문제를 통해, 설정한 값이 배정과 실행에 어떻게 반영되는지 확인합니다.

## 1. 컨테이너의 자원 요청량과 사용 상한

### 1.1 CPU와 메모리의 단위

웹 서버는 요청을 처리하는 동안 CPU로 계산하고, 처리에 필요한 데이터를 메모리에 보관합니다. 두 자원은 사용 방식이 다르므로 매니페스트에서도 각각 필요한 양을 지정합니다.

CPU의 `1`은 CPU 코어 하나에 해당하는 처리 용량입니다. 이를 천분의 일 단위로 나타내는 `m`을 사용하면 `1000m`은 `1`, `500m`은 `0.5`가 됩니다. 메모리는 `Mi`, `Gi` 등의 단위로 표현하며, `1024Mi`는 `1Gi`입니다. 예를 들어 CPU `250m`과 메모리 `128Mi`는 CPU 0.25개에 해당하는 용량과 메모리 128Mi를 뜻합니다. [[1]](#ref-1)

이제 같은 단위를 사용해, 배정할 때 확보할 몫과 실행 중 사용할 수 있는 상한을 구분할 수 있습니다.

### 1.2 requests와 limits의 선언

평소에는 자원을 적게 쓰지만 요청이 몰리면 사용량이 늘어나는 웹 서버를 생각해 보겠습니다. 다음 Pod는 배정 기준으로 CPU `250m`과 메모리 `128Mi`를 요청하고, 실행 중에는 그보다 큰 범위까지 사용할 수 있도록 선언합니다.

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

- `resources.requests`: Scheduler가 Node에 이 컨테이너를 배정할 수 있는지 판단할 때 사용하는 요청량입니다.
- `resources.limits`: 컨테이너 실행 중 적용할 CPU와 메모리의 사용 상한입니다.

Scheduler는 Node에 이미 배정된 Pod들의 요청량에 새 Pod의 요청량을 더해, 배정 가능한 자원 안에 들어가는지 확인합니다. 이때 웹 서버가 잠시 한가하더라도 선언한 요청량을 기준으로 자리를 계산합니다. 실행 중 CPU가 부족해 여러 컨테이너가 경쟁하면 CPU 요청량은 각 컨테이너에 CPU 시간을 나눠 주는 비중에도 쓰입니다. [[1]](#ref-1)

위 컨테이너의 실제 메모리 사용량은 처리하는 작업에 따라 달라집니다. Node에 여유가 있으면 요청한 `128Mi`보다 많이 사용할 수도 있으므로, 실행 중 사용 범위는 `256Mi`라는 제한값과 함께 살펴봐야 합니다.

### 1.3 CPU 제한과 메모리 제한의 차이

Pod가 Node에 배정되면 Kubelet은 컨테이너 런타임에 자원 설정을 전달합니다. Linux Node에서는 운영체제가 이 설정을 바탕으로 CPU 시간과 메모리 사용을 제한합니다. 두 자원이 상한에 도달했을 때 나타나는 결과는 다릅니다. [[1]](#ref-1)

| 자원 | 제한이 적용되는 방식 | 애플리케이션에서 나타날 수 있는 결과 |
| --- | --- | --- |
| CPU | 일정 시간 동안 사용할 CPU 시간을 제한 | 처리가 지연되거나 응답 시간이 길어짐 |
| 메모리 | 메모리 부족 처리 과정에서 프로세스 종료 | 컨테이너가 종료되고 다시 시작됨 |

CPU 시간을 제한하는 동작을 **스로틀링**이라고 합니다. 앞의 웹 서버가 CPU를 더 필요로 하더라도 `500m`의 제한을 받으면 처리 속도가 느려질 수 있습니다. 메모리 사용이 제한을 넘어 종료된 컨테이너에서는 `OOMKilled`라는 종료 이유를 확인할 수 있습니다. [[2]](#ref-2) [[3]](#ref-3)

따라서 자원 설정을 조정할 때에는 실행 중 사용량과 증상을 함께 봅니다. 요청량이 너무 크면 배정 가능한 Pod 수가 줄고, 너무 작으면 많은 Pod가 같은 Node에서 자원을 두고 경쟁할 수 있습니다. 제한값도 애플리케이션의 정상적인 작업을 처리할 수 있는 수준인지 확인해야 합니다. 이를 판단하려면 먼저 Node의 어떤 값을 기준으로 계산하는지 알아야 합니다.

## 2. Node의 자원과 Pod의 배정 기준

### 2.1 배정 가능한 자원과 현재 사용량

Node의 전체 메모리가 8Gi라고 해서 이를 모두 애플리케이션에 나눠 줄 수 있는 것은 아닙니다. Node에는 운영체제와 Kubelet도 실행됩니다. Kubernetes는 Node의 전체 용량인 `Capacity`와 Pod에 배정할 수 있는 용량인 **Allocatable**을 구분하며, 시스템용으로 예약한 자원 등이 Allocatable에 반영됩니다. [[4]](#ref-4)

실제 계산에서는 Allocatable에서 이미 배정된 Pod들의 요청량을 뺀 뒤, 새 Pod의 요청량이 들어갈 수 있는지 확인합니다. 예를 들어 남은 요청량 기준 메모리가 `512Mi`인 Node에 `1Gi`를 요청하는 Pod는 배정할 수 없습니다. Node가 두 개 있어 각각 `512Mi`가 남아 있어도, 한 Pod는 하나의 Node에서 실행되므로 그 공간을 합쳐 사용할 수 없습니다.

현재 사용량은 별도로 관찰합니다. 다음 두 상황을 비교하면 차이가 분명해집니다.

| Node의 상태 | 새 Pod 배정에 미치는 영향 |
| --- | --- |
| 실제 CPU 사용량은 낮지만 기존 Pod의 요청량이 Allocatable을 대부분 차지함 | 추가 요청량이 들어갈 공간이 부족할 수 있음 |
| 요청량에는 여유가 있지만 기존 Pod가 요청량보다 많은 메모리를 사용함 | 새 Pod가 배정된 뒤 메모리 경쟁이 생길 수 있음 |

요청량은 배정 계획의 기준이고, 사용량은 실행 중 관찰한 결과입니다. 두 값을 비교해야 요청량을 현실에 맞게 조정할 수 있습니다. 여러 컨테이너를 가진 Pod라면 이 계획에 어떤 컨테이너의 몫을 포함하는지도 중요합니다.

### 2.2 init 컨테이너와 주 컨테이너의 요청량 계산

8장의 로그 수집 예시처럼 두 컨테이너가 함께 실행되면, Pod의 요청량에는 두 컨테이너의 요청량을 합산합니다. 웹 서버가 메모리 `512Mi`, 로그 수집기가 `128Mi`를 요청한다면 함께 실행되는 동안 필요한 몫은 `640Mi`입니다.

반면 실행을 마치고 종료하는 **init 컨테이너**는 애플리케이션 시작 전에 준비 작업을 수행합니다. 이런 init 컨테이너들이 순서대로 종료된 뒤 주 컨테이너들이 실행되므로, 초기화 시점과 애플리케이션 실행 시점 중 더 많은 자원이 필요한 쪽을 기준으로 계산합니다. CPU와 메모리는 각각 비교합니다. [[5]](#ref-5)

| 실행 구성 | CPU 요청량 | 메모리 요청량 |
| --- | --- | --- |
| 초기화 시점: init 컨테이너 하나 | 500m | 256Mi |
| 초기화 완료 후: 주 컨테이너 하나 | 250m | 512Mi |
| Pod 배정에 사용할 요청량 | 500m | 512Mi |

이 경우 CPU는 초기화 시점의 `500m`, 메모리는 주 컨테이너의 `512Mi`가 기준입니다. 일반 컨테이너가 여러 개라면 그 합계와 init 컨테이너별 최대 요청량을 비교합니다. 런타임 실행에 필요한 별도 Pod 오버헤드가 설정된 환경에서는 그 몫도 추가됩니다. [[5]](#ref-5)

이제 같은 자원 설정을 가진 init 컨테이너와 주 컨테이너가 있어도, 두 컨테이너가 순서대로 실행되면 요청량을 두 배로 계산하지 않는다는 것을 알 수 있습니다. 이 차이를 실제 자원 배분 문제에 적용해 보겠습니다.

## 3. 문제: WordPress 세 Pod의 자원 배분

[자원 할당 실습의 문제](../Practice/Kubernetes/3.Resource-Allocation/Questions.bash)는 `wordpress` Deployment의 Pod 세 개에 자원을 고르게 배분하는 상황입니다. [실습 구성](../Practice/Kubernetes/3.Resource-Allocation/LabSetUp.bash)에는 준비 작업을 수행하고 종료하는 `init-setup` 컨테이너와, 그 뒤 실행되는 `wordpress` 컨테이너가 있습니다.

문제의 조건은 다음과 같습니다.

- Deployment를 0개로 줄인 뒤 자원 설정을 변경합니다.
- 다른 Pod의 요청량과 운영 중 필요한 여유를 남기고, 세 Pod에 같은 양을 배분합니다.
- init 컨테이너와 주 컨테이너에 동일한 `resources` 설정을 적용합니다.
- Deployment를 다시 3개로 늘려 배정과 실행 결과를 확인합니다.

아래 해설은 이 실습이 `default` Namespace에 준비되어 있고, 대상 Pod를 배정할 수 있는 Worker Node가 하나인 환경을 기준으로 합니다. Deployment를 줄이는 동안 WordPress는 중단되므로 학습용 환경에서 진행합니다. 여러 Worker Node를 사용하는 경우에는 각 Node의 자원을 따로 확인해야 합니다.

여기서 동일하게 맞추는 대상은 두 컨테이너의 설정입니다. 요청량과 제한값을 얼마로 정할지는 Node의 자원과 애플리케이션의 사용량을 근거로 판단합니다.

## 4. 해설: 자원 계산과 Deployment 반영

### 4.1 기존 Pod 정리와 Node 자원 확인

먼저 기존 WordPress Pod를 내려, 이 Pod들이 차지하던 요청량을 제외한 상태에서 계산합니다.

```bash
kubectl scale deployment wordpress -n default --replicas=0
kubectl wait --for=delete pod -n default -l app=wordpress --timeout=120s
kubectl get nodes
```

`get nodes`에서 확인한 Worker Node 이름으로 상세 정보를 조회합니다. 아래에서는 `worker-1`을 사용합니다.

```bash
kubectl describe node worker-1
```

다음은 계산을 위한 출력 일부의 예시입니다.

```text
Allocatable:
  cpu:                4
  memory:             8Gi

Allocated resources:
  Resource           Requests      Limits
  --------           --------      ------
  cpu                500m (12%)    1000m (25%)
  memory             1Gi (12%)     2Gi (25%)
```

- `Allocatable`: Pod에 배정할 수 있는 CPU와 메모리입니다. 이 예시에서는 CPU `4000m`, 메모리 `8192Mi`입니다.
- `Allocated resources`의 `Requests`: 이 Node에 배정된 기존 Pod들의 요청량 합계입니다. 새 WordPress Pod의 몫을 계산할 때 이 값을 먼저 뺍니다.

시스템용 예약분은 이미 Allocatable에 반영된 만큼 다시 빼지 않습니다. 여기서 추가로 남길 여유는 앞으로 늘어날 Pod나 사용량 변화 등을 고려한 운영상의 여유입니다. 이를 얼마로 잡을지는 실행 중인 애플리케이션과 배포 방식에 따라 달라집니다.

### 4.2 세 Pod의 요청량 계산

위 Node에 추가 여유로 CPU `500m`과 메모리 `1Gi`를 남긴다고 가정하겠습니다. 남은 몫을 세 Pod에 나누면 다음과 같습니다.

| 계산 항목 | CPU | 메모리 |
| --- | --- | --- |
| Node의 Allocatable | 4000m | 8192Mi |
| 기존 Pod의 요청량 | −500m | −1024Mi |
| 추가 여유 | −500m | −1024Mi |
| 세 WordPress Pod에 배분할 몫 | 3000m | 6144Mi |
| WordPress Pod 하나의 요청량 | 1000m | 2048Mi |

이 실습에서는 배정한 몫을 사용 상한으로도 삼아 `requests`와 `limits`를 모두 CPU `1000m`, 메모리 `2Gi`로 설정하겠습니다. 앞의 웹 서버 예시처럼 제한값을 요청량보다 높게 잡을 수도 있지만, 그 경우 여러 컨테이너가 동시에 사용량을 늘렸을 때의 Node 여유도 함께 확인해야 합니다.

`init-setup`과 `wordpress`에 같은 설정을 넣으면 초기화할 때도, 웹 서버가 실행될 때도 Pod 하나의 요청량은 CPU `1000m`, 메모리 `2Gi`입니다. 세 Pod의 합계는 CPU `3000m`, 메모리 `6Gi`가 되어 위에서 계산한 몫에 들어갑니다. 사용 중인 Node의 수치가 다르면 이 계산으로 배분량을 먼저 구한 뒤 설정합니다.

### 4.3 두 컨테이너의 자원 설정 적용

계산한 값을 기존 Deployment에 반영하겠습니다. 다음 내용을 `wordpress-resources.patch.yaml`로 저장합니다. 이 파일은 앞서 준비한 Deployment에서 이름이 일치하는 컨테이너의 자원 설정을 변경하는 패치입니다.

```yaml
spec:
  template:
    spec:
      initContainers:
      - name: init-setup
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 1000m
            memory: 2Gi
      containers:
      - name: wordpress
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 1000m
            memory: 2Gi
```

- `initContainers`와 `containers`의 `name`: 기존 컨테이너 중 어느 항목에 설정을 반영할지 지정합니다.
- 두 `resources` 블록: 초기화와 애플리케이션 실행 시점에 같은 자원 요청량과 제한을 적용합니다.

컨테이너 이름을 기준으로 기존 설정에 병합하는 `strategic` 패치를 적용한 뒤, Pod 수를 다시 늘립니다.

```bash
kubectl patch deployment wordpress -n default \
  --type=strategic --patch-file wordpress-resources.patch.yaml
kubectl scale deployment wordpress -n default --replicas=3
kubectl rollout status deployment wordpress -n default --timeout=180s
kubectl get pods -n default -l app=wordpress -o wide
```

정상적으로 실행된 경우의 출력 예시입니다.

```text
NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE
wordpress-7c8b9d6f5b-2kq8m    1/1     Running   0          25s   10.244.1.5   worker-1
wordpress-7c8b9d6f5b-7hpx4    1/1     Running   0          25s   10.244.1.6   worker-1
wordpress-7c8b9d6f5b-n4b6r    1/1     Running   0          25s   10.244.1.7   worker-1
```

- `READY`와 `STATUS`: 주 컨테이너가 준비된 실행 상태인지 확인합니다. 먼저 종료된 init 컨테이너는 `READY`의 컨테이너 수에 포함되지 않습니다.
- `NODE`: 실제 배정된 Node를 확인합니다.

Pod 하나를 선택해 `kubectl describe pod <Pod 이름> -n default`를 실행하면 init 컨테이너와 주 컨테이너에 반영된 요청량과 제한도 확인할 수 있습니다. 세 Pod가 실행되었다면 배정 결과는 확인한 셈입니다. 이제 작업 부하가 생겼을 때 이 설정으로 안정적으로 실행되는지 살펴봐야 합니다.

## 5. 자원 부족의 원인과 실행 결과 확인

### 5.1 배정 전 자원 부족과 Pending

새 Pod가 `Pending`에 머문다면 먼저 이벤트를 확인합니다.

```bash
kubectl describe pod <Pod 이름> -n default
```

메모리 요청량을 수용할 Node가 없는 경우에는 다음과 같은 이벤트를 볼 수 있습니다. 아래는 한 Node로 구성된 클러스터의 메시지 일부를 발췌한 예시입니다.

```text
Warning  FailedScheduling  default-scheduler  0/1 nodes are available: 1 Insufficient memory.
```

- `Insufficient memory`: 해당 Pod의 메모리 요청량을 배정할 공간이 부족하다는 판단입니다.

이때는 Pod의 요청량과 Node의 Allocatable, 기존 Pod의 요청량을 다시 비교합니다. `Insufficient cpu`가 표시되면 같은 방식으로 CPU를 확인합니다. 애플리케이션에 필요한 요청량이라면 Node를 추가하거나 다른 워크로드의 배치를 조정하고, 필요 이상으로 크게 선언했다면 사용량을 근거로 요청량을 줄입니다.

배정은 성공했는데 컨테이너가 재시작되거나 응답이 느리다면, 실행 중 적용되는 제한과 실제 사용량을 확인할 차례입니다.

### 5.2 메모리 종료와 CPU 처리 지연

재시작된 Pod의 상세 정보에서 직전 종료 이유를 확인할 수 있습니다. 메모리 부족으로 종료된 경우의 출력 일부는 다음과 같습니다.

```text
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
Restart Count:  1
```

- `Last State`의 `Reason`: 직전 실행이 끝난 이유입니다. 여기서는 메모리 부족에 따른 종료를 보여 줍니다.

`OOMKilled`가 나타났다면 컨테이너의 메모리 제한과 사용량을 먼저 비교하고, Node 전체의 메모리 부족 여부도 확인합니다. 정상 작업에도 메모리가 부족하다면 제한과 Node의 여유를 함께 조정하고, 사용량이 계속 증가한다면 애플리케이션의 메모리 사용 원인도 점검합니다. [[3]](#ref-3)

CPU 제한의 영향은 주로 처리 지연으로 나타납니다. 부하가 늘 때 응답 시간이 길어지고 CPU 사용량이 제한 부근에 머문다면, 모니터링에서 CPU 스로틀링을 함께 확인할 수 있습니다. 메모리 종료와 달리 재시작 횟수만으로 파악하기 어려우므로, 실행 상태와 응답 속도를 함께 관찰해야 합니다.

### 5.3 사용량 관찰과 요청량 조정

배정과 실행 결과를 확인한 뒤에는 실제 사용량을 측정해 선언값을 조정합니다. Metrics Server가 설치되어 자원 메트릭을 제공하는 환경에서는 다음 명령으로 Pod별 사용량을 볼 수 있습니다. [[6]](#ref-6)

```bash
kubectl top pods -n default -l app=wordpress --containers
```

부하가 크지 않은 시점의 출력 예시입니다.

```text
POD                          NAME        CPU(cores)   MEMORY(bytes)
wordpress-7c8b9d6f5b-2kq8m    wordpress   120m         180Mi
wordpress-7c8b9d6f5b-7hpx4    wordpress   110m         175Mi
wordpress-7c8b9d6f5b-n4b6r    wordpress   130m         185Mi
```

- `CPU(cores)`와 `MEMORY(bytes)`: 최근 수집된 CPU와 메모리 사용량입니다. 앞에서 선언한 요청량과 비교할 수 있습니다.

이 예시에서는 사용량이 요청량보다 작지만, 한 번의 측정만으로 설정을 줄이기에는 정보가 부족합니다. 초기화할 때와 평소 실행할 때, 요청이 몰릴 때의 사용량을 관찰해야 합니다. 특히 메모리는 순간적으로 많이 필요한 작업도 처리할 수 있어야 하므로 관찰한 사용량에 필요한 여유를 더해 설정합니다.

이번 실습은 Node의 자원을 나누는 데서 출발했습니다. 운영에서는 이렇게 관찰한 애플리케이션의 필요량으로 요청량과 제한을 정하고, 필요한 Pod 수를 실행할 만큼 Node 자원을 마련하는 과정이 이어집니다. 요청량이 현실적인 기준이 되어야 다음 장에서 살펴볼 자동 확장의 판단도 의미를 갖습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다.

- `requests`는 Pod를 배정할 자원을 계산하는 기준이고, `limits`는 실행 중 자원 사용의 상한입니다.
- Node의 Allocatable과 기존 Pod의 요청량을 비교해 새 Pod가 들어갈 수 있는지 확인합니다.
- 함께 실행되는 컨테이너는 요청량을 합산하고, 먼저 종료되는 init 컨테이너는 실행 시점별 필요량을 비교합니다.
- 배정 실패, 메모리 부족에 따른 종료, CPU 처리 지연을 구분하고 실제 사용량으로 설정을 조정합니다.

Pod 하나가 사용할 자원을 정해도 접속자가 계속 늘면 여러 Pod가 작업을 나눠야 합니다. 다음 글에서는 부하의 변화에 맞춰 Pod 수를 자동으로 늘리고 줄이는 방법을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: Pod와 컨테이너의 자원 관리](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: 컨테이너의 CPU 자원 할당](https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/)
- <a id="ref-3"></a>[3] [Kubernetes 공식 문서: 컨테이너의 메모리 자원 할당](https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/)
- <a id="ref-4"></a>[4] [Kubernetes 공식 문서: Node의 시스템 자원 예약](https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/)
- <a id="ref-5"></a>[5] [Kubernetes 공식 문서: init 컨테이너의 자원 공유](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/#resource-sharing-within-containers)
- <a id="ref-6"></a>[6] [Kubernetes 공식 문서: 자원 메트릭 수집 경로](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)
