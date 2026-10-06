"""Concept diagrams: DNS lookup is separate from application traffic."""
from pathlib import Path
import base64, html, sys
ONLY = set(sys.argv[1:])
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'images/articles/05'
ICONS = {k: base64.b64encode((ROOT / 'images/characters/refs' / v).read_bytes()).decode() for k,v in {
    'node':'node-official.png','pod':'pod-official.png','svc':'svc.png','deploy':'deploy-unlabeled.png'}.items()}
PURPLE='#7952b3'; BLUE='#2464ce'; GRAY='#7b8798'; INK='#20334d'
def start(height):
    return [f'<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="{height}" viewBox="0 0 1400 {height}">',
            '<defs>'+''.join(f'<marker id="{key}" markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" refX="12" refY="6" orient="auto"><path d="M0 0L12 6L0 12Z" fill="{color}"/></marker>' for key,color in [('dns',PURPLE),('traffic',BLUE),('config',GRAY)])+'</defs>',
            f'<rect width="1400" height="{height}" fill="#fff"/><g font-family="Apple SD Gothic Neo,Noto Sans KR,sans-serif" fill="{INK}">']
def text(s,x,y,value,size=22,color=INK,anchor='middle'):
    s.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="{size}" fill="{color}">{html.escape(value)}</text>')
def box(s,x,y,w,h,fill='#fff',dash=False):
    s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{fill}" stroke="#afc1d2" stroke-width="2"'+(' stroke-dasharray="8 6"' if dash else '')+'/>')
def icon(s,key,x,y,size=42):
    s.append(f'<image x="{x}" y="{y}" width="{size}" height="{size}" href="data:image/png;base64,{ICONS[key]}"/>')
def arrow(s,d,key='traffic',dashed=False):
    color={'dns':PURPLE,'traffic':BLUE,'config':GRAY}[key]
    s.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="3" marker-end="url(#{key})"'+(' stroke-dasharray="7 6"' if dashed else '')+'/>')
def node(s,x,y,w,h,name):
    box(s,x,y,w,h,'#eef7f1');icon(s,'node',x+16,y+15);text(s,x+w/2+20,y+45,name,25)
def finish(s,name):
    if ONLY and name not in ONLY: return
    (OUT/name).write_text('\n'.join(s+['</g></svg>']))
# DNS server placement, information updates, and lookup are distinct.
s=start(900)
text(s,700,43,'CoreDNS: Service 이름에 해당하는 IP 주소를 알려 주는 서버',28)
box(s,25,70,1350,760,'#f7faff');text(s,80,108,'Kubernetes Cluster',22,anchor='start')
node(s,70,135,670,205,'Control Plane Node')
box(s,95,205,270,105);text(s,230,244,'API Server',24);text(s,230,282,'Service 정보 조회 창구',18)
box(s,405,205,300,105,'#fff8e8',True);icon(s,'svc',418,222)
text(s,575,245,'Service: web',23);text(s,555,282,'IP: 10.96.10.20',21)
box(s,815,150,490,120,'#fff8e8',True);icon(s,'deploy',830,169)
text(s,1080,194,'Deployment: coredns',24)
text(s,1060,237,'CoreDNS Pod 관리',19)
node(s,70,445,400,310,'Worker Node A')
node(s,930,445,400,310,'Worker Node B')
box(s,100,525,340,190);icon(s,'pod',115,541)
text(s,285,575,'클라이언트 Pod',24);text(s,270,625,'웹 애플리케이션',21)
text(s,270,679,'접속할 이름: web',20)
box(s,960,525,340,190);icon(s,'pod',975,541)
text(s,1145,575,'CoreDNS Pod',24)
text(s,1130,625,'컨테이너 안의 DNS 서버',21)
arrow(s,'M230 310 V375 H1360 V620 H1300','config',True)
text(s,705,363,'Service 정보 조회와 변경 반영',20,GRAY)
arrow(s,'M440 620 H500 V560 H900 V620 H960','dns');text(s,700,535,'1. web의 IP 주소 조회',22,PURPLE)
arrow(s,'M1130 715 V775 H270 V715','dns');text(s,700,811,'2. 10.96.10.20 응답',22,PURPLE)
text(s,700,865,'Fig 2. CoreDNS의 실행 위치와 Service IP 주소 조회',24)
finish(s,'06-service-dns-resolution.svg')
# Fig 3: two independent connections to one Service, each selecting a replica.
s=start(1110)
s.append('<defs><marker id="replica2" markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" refX="12" refY="6" orient="auto"><path d="M0 0L12 6L0 12Z" fill="#ba650b"/></marker></defs>')
text(s,700,42,'같은 Service IP로 보낸 요청이 서로 다른 복제본에 도달',28)
box(s,45,80,590,140,'#fff8e8',True);icon(s,'svc',60,96)
text(s,360,119,'Service: web',24)
text(s,340,158,'10.96.10.20:80',24)
text(s,340,193,'선택 조건: app=web',21)
box(s,765,80,590,140,'#fff8e8',True);icon(s,'deploy',780,96)
text(s,1080,119,'Deployment: web-app',24)
text(s,1060,158,'replicas: 2 / 두 Node에 한 개씩 배치한 예시',20)
text(s,1060,193,'두 Pod의 공통 Label: app=web',21)
text(s,700,254,'위 점선 상자는 API에 저장된 선언 / 아래 Node 안에서 애플리케이션 실행',19,GRAY)
node(s,40,290,520,720,'Worker Node A')
node(s,850,290,500,320,'Worker Node B')
node(s,850,650,500,320,'Worker Node C')
box(s,60,370,400,130);icon(s,'pod',74,384)
text(s,280,411,'클라이언트 Pod',24)
text(s,260,452,'요청 1과 요청 2의 목적지',20)
text(s,260,482,'모두 10.96.10.20:80',22,BLUE)
box(s,60,560,400,70,'#f0f3f7')
text(s,260,589,'kube-proxy',22)
text(s,260,614,'Node에서 전달 규칙을 설정하는 프로세스',17)
box(s,60,690,400,210,'#e9f0ff')
text(s,260,728,'운영체제의 Service 전달 규칙',22)
text(s,260,770,'준비된 Pod 선택 후 목적지 IP 변경',20)
text(s,260,818,'요청 1 → 10.244.2.8:80',22,BLUE)
text(s,260,861,'요청 2 → 10.244.3.8:80',22,'#ba650b')
arrow(s,'M260 630 V690','config',True)
text(s,353,665,'규칙 설정',18,GRAY)
arrow(s,'M60 435 H20 V795 H60')
text(s,680,380,'같은 Service IP',21,BLUE)
text(s,680,413,'두 요청을 복제본에 분배',20,BLUE)
for y,num,ip in [(435,1,'10.244.2.8'),(790,2,'10.244.3.8')]:
 box(s,890,y,400,120);icon(s,'pod',904,y+14)
 text(s,1110,y+40,f'웹 Pod {num} / Deployment 복제본',21)
 text(s,1090,y+79,ip+':80',23)
 text(s,1090,y+108,'app=web / 요청 준비 완료',17)
arrow(s,'M460 795 H700 V495 H890')
text(s,723,468,'요청 1',21,BLUE)
s.append('<path d="M260 900 V945 H780 V850 H890" fill="none" stroke="#ba650b" stroke-width="3" marker-end="url(#replica2)"/>')
text(s,723,827,'요청 2',21,'#ba650b')
text(s,700,1047,'Fig 3. 하나의 Service IP와 두 Worker Node의 Pod 복제본',24)
text(s,700,1082,'각 요청이 새 연결을 사용하는 예시 / 같은 연결을 재사용하면 같은 Pod로 전달될 수 있음',18,GRAY)
finish(s,'07-service-packet-path.svg')
# Figure 1: logical relationships before YAML or packet-level details.
s=start(880)
text(s,700,43,'Service의 선언: 접근할 이름과 연결할 Pod 집합',29)
box(s,450,115,400,135,'#fff8e8',True);icon(s,'svc',466,131)
text(s,675,155,'Service: web',25)
text(s,650,192,'접근할 이름과 포트',22)
text(s,650,227,'Pod 선택 조건: app=web',21)
box(s,930,115,420,135,'#fff8e8',True);icon(s,'deploy',946,131)
text(s,1160,155,'Deployment: web-app',23)
text(s,1140,192,'웹 Pod 두 개 유지',22)
text(s,1140,227,'새 Pod에 app=web Label 부여',20)
for x,w,name in [(40,380,'Worker Node A'),(510,400,'Worker Node B'),(970,400,'Worker Node C')]:
 node(s,x,395,w,355,name)
box(s,65,530,330,145);icon(s,'pod',80,545)
text(s,248,575,'클라이언트 Pod',23)
text(s,230,623,'웹 애플리케이션에 요청',20)
text(s,230,655,'접속 이름: web',20)
for x in [540,1000]:
 box(s,x,530,340,145);icon(s,'pod',x+12,545)
 text(s,x+190,575,'웹 Pod',24)
 text(s,x+170,623,'Label: app=web',22)
 text(s,x+170,655,'애플리케이션 수신 포트: 80',18)
# Management and selection are relations, not application traffic.
arrow(s,'M1140 250 V305 H940 V485 H710 V530','config',True)
arrow(s,'M1140 250 V305 H940 V485 H1170 V530','config',True)
text(s,1240,282,'Pod 생성과 유지',19,GRAY)
arrow(s,'M650 250 V350 H480 V775 H710 V675','dns',True)
arrow(s,'M650 250 V350 H480 V775 H1170 V675','dns',True)
text(s,650,380,'같은 Label을 가진 Pod 선택',20,PURPLE)
arrow(s,'M395 602.5 H440 V182.5 H450')
text(s,700,845,'Fig 1. Deployment의 Pod 관리와 Service의 대상 선택',24)
finish(s,'08-service-pod-relationship.svg')
