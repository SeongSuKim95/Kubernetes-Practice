# Kubernetes 연습을 위한 레포지토리

**Kubernetes를 처음 배우는 사람이 차근차근 따라가기 좋은 학습 순서**로 개념이 정렬되어 있습니다.

### 학습 순서 (폴더 번호)
| 번호 | 주제 | 설명 |
|------|------|------|
| 1–2 | 스토리지 | PersistentVolume/PVC → StorageClass |
| 3–4 | 워크로드 | 리소스 요청/제한 → Sidecar(멀티컨테이너) |
| 5–7 | 서비스 노출 | NodePort → Ingress → TLS |
| 8–10 | 스케일/스케줄링 | HPA → Taints/Tolerations → PriorityClass |
| 11–12 | 네트워크 정책 | Network-Policy → CNI 설치 |
| 13–17 | 고급/운영 | Gateway API → ArgoCD → CRDs → Cri-Dockerd → Etcd 트러블슈팅 |

각 개념은 별도 폴더에 세 개의 bash 파일로 구성됩니다:

- `LabSetUp.bash` — Killercoda(또는 다른 Kubernetes 클러스터)에 복사/붙여넣기하여 환경을 준비합니다.
- `Questions.bash` — 시나리오 설명입니다.
- `SolutionNotes.bash` — 단계별 풀이입니다.

## 사용 방법
1. CKA Killercoda 플레이그라운드 또는 본인 클러스터를 실행합니다. (https://killercoda.com/)
2. 해당 환경 안에서 이 저장소를 클론합니다.
3. `N.주제이름` 형식의 폴더를 **1번부터 순서대로** 진행합니다. (예: `1.Persistent-Volume`, `6.Ingress`)
4. `./scripts/run-question.sh "1.Persistent-Volume"` 처럼 실행하면 LabSetUp 적용 후 문제 문구가 출력됩니다. 또는 해당 폴더에서 `bash LabSetUp.bash`를 직접 실행할 수 있습니다.
5. 문제를 풀고, 필요하면 `SolutionNotes.bash`를 참고합니다.

## 유용한 링크 모음
1. Kubernetes 공식 문서 : https://kubernetes.io/docs/reference/