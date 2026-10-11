# Chap08. Pod 교체 이후의 데이터 보존: PV·PVC와 StorageClass

> 16장 연재의 8번째 글입니다. Pod와 데이터의 수명을 구분하고, 저장소를 요청해 애플리케이션에 연결하는 과정을 살펴봅니다.

## 들어가며

<div align="center">

![Kubernetes 공식 로고](../images/articles/02/01-k8s-logo.svg)

</div>

7장까지는 외부 요청이 애플리케이션에 도달하는 경로를 살펴보았습니다. 이제 그 요청으로 등록한 상품이나 주문 정보를 생각해 보겠습니다. 장애 복구로 웹 서버가 다시 실행되어도, 저장한 데이터가 사라진다면 서비스를 정상적으로 이어갈 수 없습니다.

Pod를 다시 만드는 일과 데이터를 유지하는 일은 따로 준비해야 합니다. 먼저 저장 공간이 언제 사라지는지 구분한 뒤, 새 Pod가 기존 데이터에 다시 접근하는 방법을 살펴보겠습니다.

## 1. Pod와 저장 공간의 수명

컨테이너 내부의 쓰기 영역에만 기록한 파일은 컨테이너가 새로 만들어질 때 유지되지 않습니다. 3장에서 사용한 `emptyDir`은 같은 Pod의 컨테이너들이 공유하며, 컨테이너 재시작 동안 유지됩니다. Pod 자체가 삭제되면 이 공간도 함께 사라집니다. 로그를 읽는 Sidecar에는 유용하지만, Pod 교체 뒤에도 보관할 데이터에는 별도의 저장소가 필요합니다. [[1]](#ref-1)

이 차이를 이해하면 저장할 위치를 애플리케이션의 데이터 수명에 맞춰 선택할 수 있습니다.

## 2. 저장소 요청과 연결

Pod와 별개로 관리할 저장소를 Kubernetes에 나타내는 리소스가 **PV**(PersistentVolume)입니다. 애플리케이션은 필요한 용량과 사용 조건을 **PVC**(PersistentVolumeClaim)에 선언합니다. 조건을 만족하는 PV와 PVC가 연결되면, Pod는 PVC를 참조해 저장소를 파일 경로에 마운트합니다. [[2]](#ref-2)

매번 PV를 미리 준비하는 대신 **StorageClass**에 저장소 생성 방식을 정할 수도 있습니다. 해당 방식을 지원하는 프로비저너가 PVC 요청에 맞춰 저장소를 준비합니다. `WaitForFirstConsumer`는 저장소를 사용할 Pod의 배치 조건까지 고려하도록 연결과 생성을 늦추는 설정입니다. [[3]](#ref-3)

Pod를 교체한 뒤에도 같은 데이터를 사용하려면 PVC와 실제 저장소가 유지되어야 합니다. PVC 삭제 이후의 처리는 PV의 회수 정책과 저장소 구성에 따라 달라지므로, 기존 데이터를 다시 연결할 때 함께 확인합니다.

## 3. 문제: 기존 데이터베이스 저장소의 재연결

[PV 실습](../Practice/Kubernetes/1.Persistent-Volume/Questions.bash)에서는 MariaDB Deployment가 삭제되었지만 기존 저장소가 남아 있습니다. `mariadb` Namespace에 250Mi, `ReadWriteOnce` 조건의 PVC를 만들고, 다시 생성한 Deployment가 그 저장소를 사용하도록 연결하는 것이 목표입니다.

이어서 [StorageClass 실습](../Practice/Kubernetes/2.Storage-Class/Questions.bash)에서는 `rancher.io/local-path` 프로비저너를 사용하는 `local-storage`를 구성하고 기본 StorageClass로 지정합니다. 해당 프로비저너가 설치된 환경에서 진행하며, 기본 클래스가 하나만 남는지 확인합니다.

## 4. 해설: 저장소 상태와 데이터 확인

먼저 기존 PV의 용량, 접근 모드, StorageClass와 연결 상태를 확인합니다. 이전 PVC의 연결 기록이 남은 `Released` PV라면 데이터 보존 상태를 확인한 뒤 재사용 절차를 진행해야 합니다. 조건에 맞는 PVC를 연결하고 Deployment의 `volumes`에서 이를 참조하면 새 Pod가 기존 파일을 읽을 수 있습니다.

Pod가 `Running`인지 확인하는 것에 더해, PVC가 `Bound`인지와 기존 데이터가 실제로 조회되는지를 확인해야 복구가 완료됩니다. 공유 볼륨의 수명은 [Sidecar 실습](../Practice/Kubernetes/4.Sidecar/Questions.bash)에서 두 컨테이너가 같은 로그 파일을 읽고 쓰는 사례로 비교할 수 있습니다.

## 다음 글로 넘어가기 전에

이번 글에서 다룬 내용은 이렇습니다. Pod 안의 임시 공간과 Pod 외부의 영구 저장소는 수명이 다릅니다. 애플리케이션은 PVC로 저장소를 요청하고, 연결된 볼륨을 통해 데이터를 사용합니다.

데이터를 유지할 수 있게 되었다면 애플리케이션이 실행 중에 사용할 자원도 정해야 합니다. 다음 글에서는 CPU와 메모리의 요청량과 사용 제한을 살펴봅니다.

## 참고문헌

- <a id="ref-1"></a>[1] [Kubernetes 공식 문서: 볼륨](https://kubernetes.io/docs/concepts/storage/volumes/)
- <a id="ref-2"></a>[2] [Kubernetes 공식 문서: PersistentVolume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- <a id="ref-3"></a>[3] [Kubernetes 공식 문서: StorageClass](https://kubernetes.io/docs/concepts/storage/storage-classes/)
