#!/bin/bash
# Docker 실습: 컨테이너 운용 시 장애 상황과 복구
# 이 실습은 Kubernetes의 자동화 기능이 왜 필요한지 이해하기 위한 것입니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 함수 정의
print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_think() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}💭 이 시점에서 생각해보세요${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_solution() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ 해결 방법${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 실습 시작
print_section "Docker 컨테이너 운용 실습 시작"

# ============================================
# 시나리오 1: 기본 컨테이너 실행 및 관리
# ============================================
print_section "시나리오 1: 기본 컨테이너 실행 및 관리"

print_info "웹 서버 컨테이너 실행 중..."
docker run -d --name web-server-1 -p 8080:80 nginx:latest

sleep 2

print_info "실행 중인 컨테이너 확인"
docker ps

print_info "컨테이너 로그 확인"
docker logs web-server-1 | head -5

print_info "컨테이너 상태 확인"
docker inspect web-server-1 --format='{{.State.Status}}'

print_think
echo "  - 컨테이너가 정상 실행 중인지 확인하려면 어떻게 해야 할까요?"
echo "  - 컨테이너의 상태를 지속적으로 모니터링하려면 어떻게 해야 할까요?"
echo "  - Kubernetes에서는 어떻게 상태를 확인할 수 있을까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "Docker에서 컨테이너 상태 확인:"
echo "  docker ps                    # 실행 중인 컨테이너 확인"
echo "  docker ps -a                 # 모든 컨테이너 확인 (중지된 것 포함)"
echo "  docker logs <container-name> # 컨테이너 로그 확인"
echo "  docker inspect <container-name> # 상세 정보 확인"
echo ""
echo "Kubernetes에서는:"
echo "  kubectl get pods             # Pod 상태 자동 확인"
echo "  kubectl get pods -w          # 실시간 모니터링"
echo "  kubectl logs <pod-name>      # 로그 확인"
echo "  kubectl describe pod <pod-name> # 상세 정보 확인"

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 2: 컨테이너 비정상 종료 감지 및 복구
# ============================================
print_section "시나리오 2: 컨테이너 비정상 종료 감지 및 복구"

print_info "컨테이너를 강제로 종료합니다..."
docker stop web-server-1

sleep 1

print_info "종료된 컨테이너 확인"
docker ps -a | grep web-server-1

print_think
echo "  - 컨테이너가 종료되었습니다. 어떻게 감지할 수 있을까요?"
echo "  - 컨테이너가 자동으로 재시작될까요?"
echo "  - 수동으로 재시작하려면 어떻게 해야 할까요?"
echo "  - Kubernetes에서는 이런 상황을 어떻게 처리할까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "문제 상황: 컨테이너가 종료되었지만 자동으로 재시작되지 않습니다."
echo ""
echo "Docker에서 수동 복구:"
echo "  docker start web-server-1    # 컨테이너 재시작"
echo "  docker restart web-server-1  # 컨테이너 재시작 (중지 후 시작)"
echo ""
echo "자동 재시작 설정 (제한적):"
echo "  docker run -d --restart=always --name web-server-1 nginx:latest"
echo "  # 하지만 노드 자체가 다운되면 복구 불가능"
echo ""
echo "Kubernetes에서는:"
echo "  - Deployment가 Pod를 관리하면, Pod가 죽으면 자동으로 새 Pod 생성"
echo "  - 노드가 다운되어도 다른 노드에 자동으로 재스케줄링"
echo "  - kubectl get pods로 자동 복구 상태 확인 가능"

print_info "수동 복구 실행 중..."
docker start web-server-1
sleep 2
docker ps | grep web-server-1

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 3: 여러 컨테이너 관리의 어려움
# ============================================
print_section "시나리오 3: 여러 컨테이너 관리의 어려움"

print_info "여러 개의 웹 서버 컨테이너 실행 중..."
docker run -d --name web-server-2 -p 8081:80 nginx:latest
docker run -d --name web-server-3 -p 8082:80 nginx:latest
docker run -d --name web-server-4 -p 8083:80 nginx:latest

sleep 2

print_info "실행 중인 모든 웹 서버 컨테이너 확인"
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

print_info "이제 web-server-1의 이미지를 업데이트해야 합니다..."
docker stop web-server-1
docker rm web-server-1

print_think
echo "  - web-server-1을 새 버전(nginx:1.21)으로 업데이트하려면 어떻게 해야 할까요?"
echo "  - 다른 컨테이너들(web-server-2, 3, 4)도 함께 업데이트하려면 어떻게 해야 할까요?"
echo "  - 업데이트 중 서비스가 중단되지 않으려면 어떻게 해야 할까요?"
echo "  - Kubernetes에서는 어떻게 처리할까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "Docker에서 개별 컨테이너 업데이트:"
echo "  # web-server-1만 업데이트"
echo "  docker stop web-server-1"
echo "  docker rm web-server-1"
echo "  docker run -d --name web-server-1 -p 8080:80 nginx:1.21"
echo ""
echo "  # 모든 컨테이너 업데이트 (수동으로 하나씩)"
echo "  docker stop web-server-1 web-server-2 web-server-3 web-server-4"
echo "  docker rm web-server-1 web-server-2 web-server-3 web-server-4"
echo "  docker run -d --name web-server-1 -p 8080:80 nginx:1.21"
echo "  docker run -d --name web-server-2 -p 8081:80 nginx:1.21"
echo "  docker run -d --name web-server-3 -p 8082:80 nginx:1.21"
echo "  docker run -d --name web-server-4 -p 8083:80 nginx:1.21"
echo ""
echo "문제점:"
echo "  - 각 컨테이너를 개별적으로 관리해야 함"
echo "  - 업데이트 중 서비스 중단 발생"
echo "  - 롤백이 복잡함"
echo ""
echo "Kubernetes에서는:"
echo "  kubectl set image deployment/web nginx=nginx:1.21"
echo "  # 자동으로 롤링 업데이트 수행 (다운타임 없음)"
echo "  kubectl rollout undo deployment/web  # 한 번의 명령으로 롤백"

print_info "web-server-1을 새 버전으로 업데이트 중..."
docker run -d --name web-server-1 -p 8080:80 nginx:1.21
sleep 2
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 4: 컨테이너 리소스 부족 (OOM)
# ============================================
print_section "시나리오 4: 컨테이너 리소스 부족 (OOM Kill)"

print_info "메모리 제한이 매우 작은 컨테이너 실행 중..."
docker run -d --name memory-test --memory=10m --memory-swap=10m alpine sh -c "tail -f /dev/null & sleep 1 && dd if=/dev/zero of=/dev/null bs=1M"

sleep 3

print_info "컨테이너 상태 확인"
docker ps -a | grep memory-test

print_info "컨테이너 로그 확인 (OOM Kill 확인)"
docker logs memory-test 2>&1 | tail -5 || true

print_think
echo "  - 컨테이너가 메모리 부족으로 종료되었습니다. 어떻게 확인할 수 있을까요?"
echo "  - 이런 상황을 어떻게 방지할 수 있을까요?"
echo "  - 컨테이너가 자동으로 재시작될까요?"
echo "  - 더 많은 메모리를 할당하려면 어떻게 해야 할까요?"
echo "  - Kubernetes에서는 어떻게 처리할까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "문제 상황: 컨테이너가 메모리 부족(OOM Kill)으로 종료되었습니다."
echo ""
echo "Docker에서 확인 및 복구:"
echo "  # 컨테이너 상태 확인"
echo "  docker ps -a | grep memory-test"
echo "  docker inspect memory-test | grep -i oom"
echo ""
echo "  # 로그 확인"
echo "  docker logs memory-test"
echo ""
echo "  # 더 많은 메모리로 재시작"
echo "  docker rm memory-test"
echo "  docker run -d --name memory-test --memory=100m --memory-swap=100m alpine sh -c 'tail -f /dev/null'"
echo ""
echo "문제점:"
echo "  - 리소스 제한을 설정할 수 있지만, 부족 시 자동으로 조정하지 않음"
echo "  - 컨테이너가 죽어도 자동으로 재시작하지 않음"
echo "  - 다른 노드로 재스케줄링 불가능"
echo ""
echo "Kubernetes에서는:"
echo "  - ResourceQuota와 LimitRange로 클러스터 전체 리소스 관리"
echo "  - 리소스 부족 시 다른 노드로 Pod 자동 재스케줄링"
echo "  - OOM Kill 발생 시 자동으로 새 Pod 생성"

print_info "수동 복구 실행 중..."
docker rm memory-test 2>/dev/null || true
docker run -d --name memory-test --memory=100m --memory-swap=100m alpine sh -c "tail -f /dev/null"
sleep 2
docker ps | grep memory-test

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 5: 로드 밸런싱 설정의 복잡성
# ============================================
print_section "시나리오 5: 로드 밸런싱 설정의 복잡성"

print_info "현재 실행 중인 웹 서버들"
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Ports}}"

print_info "각 웹 서버가 다른 포트로 실행 중입니다..."
echo "  - web-server-1: localhost:8080"
echo "  - web-server-2: localhost:8081"
echo "  - web-server-3: localhost:8082"
echo "  - web-server-4: localhost:8083"

print_think
echo "  - 사용자가 여러 포트를 기억해야 하나요?"
echo "  - 트래픽을 여러 서버에 분산하려면 어떻게 해야 할까요?"
echo "  - 로드 밸런서를 설정하려면 어떻게 해야 할까요?"
echo "  - 컨테이너가 추가/제거될 때 로드 밸런서 설정을 어떻게 업데이트할까요?"
echo "  - Kubernetes에서는 어떻게 처리할까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "Docker에서 로드 밸런싱 설정:"
echo ""
echo "1. Nginx를 로드 밸런서로 사용하는 방법:"
echo ""
echo "   # nginx-lb.conf 파일 생성"
cat <<'EOF'
   upstream backend {
       server localhost:8080;
       server localhost:8081;
       server localhost:8082;
       server localhost:8083;
   }
   
   server {
       listen 80;
       location / {
           proxy_pass http://backend;
       }
   }
EOF
echo ""
echo "   # 로드 밸런서 컨테이너 실행"
echo "   docker run -d --name nginx-lb -p 80:80 \\"
echo "     -v \$(pwd)/nginx-lb.conf:/etc/nginx/conf.d/default.conf \\"
echo "     nginx:latest"
echo ""
echo "문제점:"
echo "  - 컨테이너가 추가/제거될 때마다 설정 파일을 수동으로 수정해야 함"
echo "  - 로드 밸런서를 별도로 관리해야 함"
echo "  - 설정 변경 후 로드 밸런서 재시작 필요"
echo ""
echo "Kubernetes에서는:"
echo "  - Service가 자동으로 로드 밸런싱 제공"
echo "  - Pod가 추가/제거될 때 자동으로 업데이트"
echo "  - 별도의 설정 파일 불필요"
echo "  - kubectl expose deployment web --port=80 --type=LoadBalancer"

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 6: 스케일링의 번거로움
# ============================================
print_section "시나리오 6: 스케일링의 번거로움"

print_info "현재 실행 중인 웹 서버 개수"
WEB_COUNT=$(docker ps --filter "name=web-server" --format "{{.Names}}" | wc -l)
echo "현재 웹 서버 개수: $WEB_COUNT"

print_warning "시나리오: 트래픽이 급증하여 웹 서버를 3개 더 추가해야 합니다!"

print_think
echo "  - 웹 서버를 3개 더 추가하려면 어떻게 해야 할까요?"
echo "  - 각 컨테이너에 포트를 어떻게 할당할까요?"
echo "  - 로드 밸런서 설정도 업데이트해야 할까요?"
echo "  - 트래픽이 감소하면 어떻게 축소할까요?"
echo "  - Kubernetes에서는 어떻게 처리할까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "Docker에서 수동 스케일링:"
echo ""
echo "  # 웹 서버 3개 추가"
echo "  docker run -d --name web-server-5 -p 8084:80 nginx:latest"
echo "  docker run -d --name web-server-6 -p 8085:80 nginx:latest"
echo "  docker run -d --name web-server-7 -p 8086:80 nginx:latest"
echo ""
echo "  # 로드 밸런서 설정 파일 수정 필요"
echo "  # nginx-lb.conf에 새 서버 추가"
echo "  # 로드 밸런서 재시작"
echo "  docker restart nginx-lb"
echo ""
echo "  # 스케일 다운 (3개 제거)"
echo "  docker stop web-server-5 web-server-6 web-server-7"
echo "  docker rm web-server-5 web-server-6 web-server-7"
echo "  # 로드 밸런서 설정 파일 수정 및 재시작 필요"
echo ""
echo "문제점:"
echo "  - 각 컨테이너를 개별적으로 실행/삭제해야 함"
echo "  - 포트를 수동으로 할당해야 함"
echo "  - 로드 밸런서 설정을 수동으로 업데이트해야 함"
echo "  - CPU/메모리 사용량에 따라 자동 스케일링 불가능"
echo ""
echo "Kubernetes에서는:"
echo "  # 수동 스케일링"
echo "  kubectl scale deployment web --replicas=7"
echo ""
echo "  # 자동 스케일링 (HPA)"
echo "  kubectl autoscale deployment web --min=3 --max=10 --cpu-percent=70"
echo "  # CPU 사용률이 70%를 넘으면 자동으로 확장"

print_info "수동으로 컨테이너 추가 중..."
docker run -d --name web-server-5 -p 8084:80 nginx:latest
docker run -d --name web-server-6 -p 8085:80 nginx:latest
docker run -d --name web-server-7 -p 8086:80 nginx:latest

sleep 2

print_info "업데이트된 웹 서버 개수"
NEW_COUNT=$(docker ps --filter "name=web-server" --format "{{.Names}}" | wc -l)
echo "업데이트된 웹 서버 개수: $NEW_COUNT"

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 7: 컨테이너 상태 모니터링
# ============================================
print_section "시나리오 7: 컨테이너 상태 모니터링"

print_info "web-server-2의 프로세스를 강제로 종료합니다..."
docker exec web-server-2 pkill nginx || true

sleep 2

print_info "컨테이너 상태 확인"
docker ps --filter "name=web-server-2"

print_info "컨테이너 내부 프로세스 확인"
docker exec web-server-2 ps aux || echo "컨테이너가 응답하지 않습니다"

print_think
echo "  - 컨테이너 내부의 프로세스가 종료되었습니다. 어떻게 감지할 수 있을까요?"
echo "  - 컨테이너가 비정상 상태인지 어떻게 확인할까요?"
echo "  - 헬스체크를 설정할 수 있을까요?"
echo "  - 헬스체크 실패 시 자동으로 재시작할 수 있을까요?"
echo "  - Kubernetes에서는 어떻게 처리할까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "Docker에서 상태 모니터링:"
echo ""
echo "  # 컨테이너 상태 확인"
echo "  docker ps"
echo "  docker ps -a"
echo ""
echo "  # 컨테이너 리소스 사용량 확인"
echo "  docker stats"
echo ""
echo "  # 컨테이너 내부 프로세스 확인"
echo "  docker top web-server-2"
echo "  docker exec web-server-2 ps aux"
echo ""
echo "  # 헬스체크 설정 (제한적)"
echo "  docker run -d --name web-health \\"
echo "    --health-cmd='curl -f http://localhost:80 || exit 1' \\"
echo "    --health-interval=30s \\"
echo "    --health-timeout=3s \\"
echo "    --health-retries=3 \\"
echo "    nginx:latest"
echo ""
echo "문제점:"
echo "  - 헬스체크를 설정할 수 있지만, 실패 시 자동으로 재시작하지 않음"
echo "  - 컨테이너 상태를 수동으로 확인해야 함"
echo "  - 비정상 상태 감지가 어려움"
echo ""
echo "Kubernetes에서는:"
echo "  # Liveness Probe: 컨테이너가 살아있는지 확인"
echo "  # 실패 시 Pod 재시작"
echo "  livenessProbe:"
echo "    httpGet:"
echo "      path: /health"
echo "      port: 8080"
echo "    initialDelaySeconds: 30"
echo "    periodSeconds: 10"
echo ""
echo "  # Readiness Probe: 요청을 받을 준비가 되었는지 확인"
echo "  # 실패 시 트래픽 차단"
echo "  readinessProbe:"
echo "    httpGet:"
echo "      path: /ready"
echo "      port: 8080"

print_info "web-server-2 재시작 중..."
docker restart web-server-2
sleep 2
docker ps | grep web-server-2

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 8: 컨테이너 간 통신 설정
# ============================================
print_section "시나리오 8: 컨테이너 간 통신 설정"

print_info "데이터베이스 컨테이너 실행 중..."
docker run -d --name mysql-db \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=testdb \
  mysql:8.0

sleep 5

print_info "데이터베이스 컨테이너 IP 확인"
DB_IP=$(docker inspect mysql-db --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "MySQL IP: $DB_IP"

print_info "애플리케이션 컨테이너에서 데이터베이스에 연결 시도..."
docker run --rm --name app-test alpine sh -c "apk add --no-cache mysql-client > /dev/null 2>&1 && mysql -h $DB_IP -uroot -ppassword -e 'SELECT 1' testdb 2>&1 || echo '연결 실패: IP 주소를 직접 지정해야 함'"

print_think
echo "  - 애플리케이션 컨테이너가 데이터베이스에 연결하려면 어떻게 해야 할까요?"
echo "  - 컨테이너 IP 주소가 변경되면 어떻게 될까요?"
echo "  - 컨테이너 간 통신을 어떻게 설정할까요?"
echo "  - 네트워크를 어떻게 구성할까요?"
echo "  - Kubernetes에서는 어떻게 처리할까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "Docker에서 컨테이너 간 통신 설정:"
echo ""
echo "방법 1: --link 사용 (deprecated)"
echo "  docker run -d --name app-server --link mysql-db:mysql \\"
echo "    -e MYSQL_HOST=mysql \\"
echo "    alpine sh -c 'tail -f /dev/null'"
echo ""
echo "방법 2: 사용자 정의 네트워크 사용 (권장)"
echo "  # 네트워크 생성"
echo "  docker network create app-network"
echo ""
echo "  # 컨테이너를 네트워크에 연결"
echo "  docker network connect app-network mysql-db"
echo "  docker run -d --name app-server --network app-network \\"
echo "    -e MYSQL_HOST=mysql-db \\"
echo "    alpine sh -c 'tail -f /dev/null'"
echo ""
echo "문제점:"
echo "  - 컨테이너 IP가 변경되면 설정을 수동으로 업데이트해야 함"
echo "  - 네트워크를 수동으로 관리해야 함"
echo "  - 서비스 디스커버리가 없음"
echo ""
echo "Kubernetes에서는:"
echo "  - Service Discovery로 자동 해석"
echo "  - Service 이름으로 DNS 자동 해석"
echo "  - Pod IP가 변경되어도 Service 이름으로 접근 가능"
echo "  - 예: mysql-service.default.svc.cluster.local"

print_info "사용자 정의 네트워크 생성 및 연결 중..."
docker network create app-network 2>/dev/null || true
docker network connect app-network mysql-db 2>/dev/null || true
docker run -d --name app-server --network app-network \
  -e MYSQL_HOST=mysql-db \
  alpine sh -c "apk add --no-cache mysql-client && tail -f /dev/null"

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 9: 볼륨 관리의 복잡성
# ============================================
print_section "시나리오 9: 볼륨 관리의 복잡성"

print_info "데이터베이스 컨테이너를 삭제합니다..."
docker stop mysql-db
docker rm mysql-db

print_info "데이터가 손실되었는지 확인"
echo "데이터베이스 컨테이너가 삭제되면서 데이터도 함께 삭제되었습니다."

print_think
echo "  - 컨테이너를 삭제하면 데이터도 함께 삭제될까요?"
echo "  - 데이터를 영구적으로 저장하려면 어떻게 해야 할까요?"
echo "  - 볼륨을 어떻게 생성하고 관리할까요?"
echo "  - 여러 서버에 분산된 경우 볼륨을 어떻게 관리할까요?"
echo "  - Kubernetes에서는 어떻게 처리할까요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "Docker에서 볼륨 관리:"
echo ""
echo "방법 1: 볼륨 생성 및 마운트"
echo "  # 볼륨 생성"
echo "  docker volume create db-data"
echo ""
echo "  # 볼륨 마운트"
echo "  docker run -d --name mysql-db \\"
echo "    -v db-data:/var/lib/mysql \\"
echo "    -e MYSQL_ROOT_PASSWORD=password \\"
echo "    mysql:8.0"
echo ""
echo "방법 2: 호스트 디렉토리 마운트"
echo "  docker run -d --name mysql-db \\"
echo "    -v /host/path:/var/lib/mysql \\"
echo "    -e MYSQL_ROOT_PASSWORD=password \\"
echo "    mysql:8.0"
echo ""
echo "문제점:"
echo "  - 볼륨을 수동으로 생성하고 관리해야 함"
echo "  - 볼륨 백업/복원을 수동으로 수행해야 함"
echo "  - 여러 서버에 분산된 경우 볼륨 관리가 복잡함"
echo "  - 동적 프로비저닝 불가능"
echo ""
echo "Kubernetes에서는:"
echo "  - PersistentVolume과 PersistentVolumeClaim으로 스토리지 추상화"
echo "  - StorageClass로 동적 프로비저닝 지원"
echo "  - 다양한 스토리지 타입 통합 관리 (로컬, NFS, 클라우드 스토리지)"
echo "  - 볼륨 자동 마운트 및 관리"

print_info "볼륨 생성 및 데이터베이스 재시작 중..."
docker volume create db-data
docker run -d --name mysql-db \
  -v db-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=testdb \
  mysql:8.0

sleep 3
print_info "볼륨 정보 확인"
docker volume inspect db-data

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 시나리오 10: 전체 정리 및 Kubernetes와의 비교
# ============================================
print_section "시나리오 10: 전체 정리 및 Kubernetes와의 비교"

print_info "현재 실행 중인 모든 컨테이너"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

print_think
echo "  - 지금까지 경험한 Docker의 문제점들을 정리해보세요"
echo "  - 각 문제를 Kubernetes에서는 어떻게 해결할 수 있을까요?"
echo "  - Kubernetes의 자동화 기능이 왜 필요한지 이해했나요?"

read -p "계속하려면 Enter를 누르세요..."

print_solution
echo "Docker의 한계 요약:"
echo ""
echo "1. 자동 복구 부재"
echo "   문제: 컨테이너가 죽으면 수동으로 재시작해야 함"
echo "   Docker: docker start <container> (수동)"
echo "   Kubernetes: Pod가 죽으면 자동으로 새 Pod 생성"
echo ""
echo "2. 수동 스케일링"
echo "   문제: 컨테이너를 추가/제거하려면 수동으로 실행/삭제해야 함"
echo "   Docker: docker run/rm (수동)"
echo "   Kubernetes: kubectl scale 또는 HPA로 자동 스케일링"
echo ""
echo "3. 로드 밸런싱 설정 복잡"
echo "   문제: 별도의 로드 밸런서를 설정하고 관리해야 함"
echo "   Docker: Nginx 설정 파일 수동 관리"
echo "   Kubernetes: Service가 자동으로 로드 밸런싱 제공"
echo ""
echo "4. 서비스 디스커버리 부재"
echo "   문제: 컨테이너 IP가 변경되면 수동으로 설정을 업데이트해야 함"
echo "   Docker: IP 주소 직접 지정 또는 네트워크 수동 관리"
echo "   Kubernetes: Service Discovery로 자동 해석"
echo ""
echo "5. 상태 모니터링 부족"
echo "   문제: 컨테이너 상태를 수동으로 확인해야 함"
echo "   Docker: docker ps, docker logs (수동)"
echo "   Kubernetes: 자동 헬스체크 및 상태 보고"
echo ""
echo "6. 롤링 업데이트 복잡"
echo "   문제: 각 컨테이너를 개별적으로 업데이트해야 함"
echo "   Docker: 각 컨테이너를 수동으로 중지/재시작"
echo "   Kubernetes: Deployment로 자동 롤링 업데이트"
echo ""
echo "7. 리소스 관리 제한"
echo "   문제: 리소스 제한을 설정할 수 있지만 자동 조정 불가"
echo "   Docker: --memory, --cpus 옵션 (수동 설정)"
echo "   Kubernetes: ResourceQuota, LimitRange로 클러스터 전체 관리"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Kubernetes의 핵심 장점:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "선언적 관리: 원하는 상태를 선언하면 자동으로 유지"
echo "자동 복구: Pod가 죽으면 자동으로 재생성"
echo "자동 스케일링: CPU/메모리 사용량에 따라 자동 확장/축소"
echo "자동 로드 밸런싱: Service가 자동으로 트래픽 분산"
echo "자동 서비스 디스커버리: DNS 기반 자동 해석"
echo "자동 헬스체크: Liveness/Readiness Probe로 자동 모니터링"
echo "롤링 업데이트: 다운타임 없이 자동 업데이트"
echo "리소스 관리: 클러스터 전체 리소스 통합 관리"

read -p "계속하려면 Enter를 누르세요..."

# ============================================
# 정리 작업
# ============================================
print_section "정리 작업"

print_info "실습에서 생성한 모든 컨테이너 정리 중..."

# 모든 컨테이너 중지 및 삭제
docker stop $(docker ps -q --filter "name=web-server") 2>/dev/null || true
docker stop mysql-db app-server memory-test 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=web-server") 2>/dev/null || true
docker rm mysql-db app-server memory-test 2>/dev/null || true

# 볼륨 삭제
docker volume rm db-data 2>/dev/null || true

# 네트워크 삭제
docker network rm app-network 2>/dev/null || true

print_info "정리 완료!"

print_section "실습 완료"
print_info "이제 Kubernetes를 배우면서 위에서 경험한 문제들이 어떻게 자동으로 해결되는지 확인할 수 있습니다!"
echo ""
print_warning "다음 단계: AboutKubernetes.md를 읽고 Kubernetes의 자동화 기능을 학습하세요!"
