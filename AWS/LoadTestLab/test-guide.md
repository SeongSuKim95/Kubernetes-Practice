# LoadTestLab — Grafana / Argo CD / 부하 테스트 가이드

노드 스펙업 이후 **Grafana → Argo CD → 앱 확인 → 부하 테스트** 순서입니다.  
클러스터(`loadtest-lab`)와 애드온(ALB Controller, metrics-server 등)은 이미 구축되어 있다고 가정합니다.

전체 인프라 구축은 [LAB-GUIDE.md](./LAB-GUIDE.md)를 참고하세요.

---

## 0. 사전 확인 (로컬 Mac)

```bash
export AWS_REGION=ap-northeast-2
export CLUSTER_NAME=loadtest-lab

aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
kubectl get nodes          # 5대 Ready (c5.2xlarge)
kubectl -n kube-system get deploy aws-load-balancer-controller metrics-server
kubectl top nodes          # Metrics API 동작 확인 (HPA 필수)
```

---

## 1. Grafana 띄우기

이미 설치되어 있으면 **재설치 없이** port-forward만 해도 됩니다.

```bash
# (필요할 때만) 재설치 — Helm upgrade 이므로 기존 설정 유지
cd AWS/LoadTestLab/monitoring
./install-monitoring.sh

# Pod 확인
kubectl -n monitoring get pods
kubectl -n monitoring rollout status deploy/kube-prometheus-stack-grafana --timeout=300s
```

**Grafana 접속** (로컬 터미널, 별도 창에서 유지):

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

| 항목 | 값 |
|------|-----|
| URL | http://localhost:3000 |
| ID | `admin` |
| PW | `loadtest-admin` |
| 추천 대시보드 | **LoadTest — HTTP 200/500** |

---

## 2. Argo CD 띄우기 + 앱 sync

```bash
cd AWS/LoadTestLab/argocd
./install-argocd.sh

# 앱 상태 확인
kubectl -n argocd get application loadtest-app
kubectl -n loadtest get deploy,svc,ingress,hpa,pod
```

**Argo CD UI** (별도 터미널):

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

| 항목 | 값 |
|------|-----|
| URL | https://localhost:8080 |
| ID | `admin` |
| PW | `./install-argocd.sh` 출력 또는 아래 명령 |

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

**OutOfSync** 이면 Git push 후 자동 sync 되거나, UI에서 **Sync** 클릭.

**앱 HTTPS 확인:**

```bash
curl -sk -o /dev/null -w "HTTP %{http_code}\n" https://loadtest.k8s-study.club/
# → 200
```

---

## 3. 부하 테스트 준비 (LoadTest EC2)

EC2가 없으면:

```bash
cd AWS/LoadTestLab/infra
export KEY_NAME=<키페어 이름>   # 예: EKS_loadtest
./create-loadtest-ec2.sh
```

**SSH 접속** (예시):

```bash
ssh -i ~/.ssh/EKS_loadtest.pem ec2-user@<LoadTest-EC2-Public-IP>
```

EC2에 `loadtest/` 디렉터리가 없으면 Mac에서 복사:

```bash
scp -r -i ~/.ssh/EKS_loadtest.pem \
  AWS/LoadTestLab/loadtest ec2-user@<LoadTest-EC2-Public-IP>:~/
```

---

## 4. LoadTest 실행 순서

### 터미널 배치

| 터미널 | 용도 |
|--------|------|
| 1 | Grafana port-forward (3000) |
| 2 | `kubectl -n loadtest get hpa -w` |
| 3 | LoadTest EC2 SSH → k6 실행 |

### 단계별 부하 (권장)

LoadTest EC2에서:

```bash
cd ~/loadtest
export APP_HOST=loadtest.k8s-study.club

# 100 RPS → 200 OK 확인
./run-step.sh 100 10

# 1000 RPS
./run-step.sh 1000 10
```

결과 리포트: `~/loadtest/reports/step-<RPS>-<초>s-report.txt`

### 전체 램프 (100 → 1k → 10k → 50k)

```bash
APP_HOST=loadtest.k8s-study.club ./run-loadtest.sh
```

단일 RPS만 고정:

```bash
APP_HOST=loadtest.k8s-study.club ./run-loadtest.sh 1000
```

---

## 5. 테스트 중 관찰 포인트

### Grafana (`LoadTest — HTTP 200/500`)

- **200 RPS**, **500 RPS**, **200 성공률(%)** 패널 확인

### HPA / Pod (터미널 2)

```bash
kubectl -n loadtest get hpa echo-cpu -w
kubectl -n loadtest get pods -w
kubectl top pods -n loadtest
```

### 검증 지표 요약

| 무엇 | 어디서 |
|------|--------|
| 200 비율 / 실패율 | k6 출력, `run-step.sh` 리포트 |
| 200/500 RPS·성공률 | Grafana 대시보드 |
| CPU / replica 수 | Grafana, `kubectl top`, HPA |
| HPA 상태 | `kubectl -n loadtest get hpa -w` |
| 200/500 로그 | `kubectl -n loadtest logs <pod> -c fluentd` |

---

## 6. 5xx / 타임아웃 발생 시

1. `app-manifests/deployment.yaml`, `hpa.yaml` 수정 (replicas, resources, maxReplicas 등)
2. `git commit && git push`
3. Argo CD sync 확인
4. 같은 RPS로 `./run-step.sh` 재실행

---

## 한 줄 요약

```
install-monitoring.sh → Grafana port-forward(3000)
→ install-argocd.sh → Argo CD port-forward(8080) + 앱 sync
→ EC2 SSH → run-step.sh 100 → 1000
→ Grafana / HPA 동시 관찰
```

Grafana·Argo CD Pod가 이미 `Running`이면 **1~2단계는 port-forward + sync 확인만** 하면 됩니다.
