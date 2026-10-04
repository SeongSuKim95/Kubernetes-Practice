"""Static topology; named SVG route groups are reserved for later animation."""
from pathlib import Path
import base64,html
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'images/articles/05'
ICONS={k:base64.b64encode((ROOT/p).read_bytes()).decode() for k,p in {'pod':'images/characters/refs/pod-official.png','node':'images/characters/refs/node-official.png','svc':'images/characters/refs/svc.png','deploy':'images/characters/refs/deploy-unlabeled.png','ing':'images/characters/refs/ing.png','k8s':'images/k8s-icon-color.png'}.items()}
C={'internal':'#2563eb','external':'#db791c','dns':'#8752c6','config':'#788496'}
def text(s,x,y,t,size=20):s.append(f'<text x="{x}" y="{y}" text-anchor="middle" font-size="{size}">{html.escape(t)}</text>')
def box(s,x,y,w,h,fill='#fff'):s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="#bdcbd9" stroke-width="2"/>')
def icon(s,k,x,y):s.append(f'<image x="{x}" y="{y}" width="38" height="38" href="data:image/png;base64,{ICONS[k]}"/>')
def card(s,x,y,w,title,sub,k=None,h=95):
 box(s,x,y,w,h)
 if k:icon(s,k,x+10,y+10)
 text(s,x+w/2+(15 if k else 0),y+35,title,20);text(s,x+w/2,y+69,sub,17)
def route(s,key,d,color):s.append(f'<g id="route-{key}"><path d="{d}" stroke="{C[color]}" stroke-width="3" fill="none" marker-end="url(#{color})"/></g>')
def document(s,x,y,w,title,lines,k):
 s.append(f'<path d="M{x} {y} H{x+w-24} L{x+w} {y+24} V{y+150} H{x}Z" fill="#fff9eb" stroke="#c9b98d" stroke-width="2"/>')
 s.append(f'<path d="M{x+w-24} {y} V{y+24} H{x+w}" fill="none" stroke="#c9b98d"/>');icon(s,k,x+12,y+12)
 text(s,x+w/2+15,y+36,title,21)
 for i,line in enumerate(lines):text(s,x+w/2,y+72+i*28,line,17)
def node(s,x,name,client=False,dns=False):
 w=330 if client else 350;box(s,x,430,w,620,'#eef7f0');icon(s,'node',x+14,443);text(s,x+w/2+16,474,name,23)
 box(s,x+25,505,w-50,72,'#e8efff');text(s,x+w/2,533,'kube-proxy',22);text(s,x+w/2,560,'Node에서 실행되는 프로세스',17)
 route(s,name.replace(' ','-')+'-configure',f'M{x+w/2} 577 V610','config');text(s,x+w/2+95,599,'규칙 설정',16)
 box(s,x+25,610,w-50,95,'#f2f4f7');text(s,x+w/2,640,'운영체제의 패킷 처리',19)
 text(s,x+w/2,676,'DNS Service 접근 규칙' if dns else ('Service 접근 규칙' if client else ENTRY),17)
def make(kind,number,filename,title):
 global ENTRY
 ENTRY={'cip':'ClusterIP:80','np':'ClusterIP:80 / NodePort:30080','lb':'ClusterIP:80 / NodePort:31234','dns':'일반 Service 접근 규칙'}[kind]
 s=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1210" viewBox="0 0 1600 1210"><defs>']
 for k,c in C.items():s.append(f'<marker id="{k}" markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto"><path d="M0 0 L7 3.5 L0 7Z" fill="{c}"/></marker>')
 s.append('</defs><rect width="1600" height="1210" fill="white"/><g font-family="Apple SD Gothic Neo,Noto Sans KR,sans-serif" fill="#20334d">')
 text(s,945,35,'선언된 Kubernetes 리소스 — 실행되는 서버나 트래픽 중계 지점이 아님',22)
 document(s,350,65,360,'Deployment D1',['replicas: 2','ReplicaSet을 통한 복제본 관리','아래 D1 표식의 Pod 두 개'],'deploy')
 typ={'cip':'ClusterIP','np':'NodePort','lb':'LoadBalancer','dns':'ExternalName'}[kind]
 document(s,760,65,370,'Service S1 / '+typ,['external-api' if kind=='dns' else {'cip':'clusterip-service','np':'nodeport-service','lb':'loadbalancer-service'}[kind],'externalName: api.example.com' if kind=='dns' else 'selector: app=nodeport-deployment','DNS 별칭 선언' if kind=='dns' else '아래 S1 표식의 Pod 선택'],'svc')
 if kind=='cip':document(s,1180,65,370,'Ingress I1',['shop.example.com /','백엔드: clusterip-service:80','Controller가 적용할 HTTP 규칙'],'ing')
 else:text(s,1365,120,'D1: Deployment의 복제본',18);text(s,1365,160,'S1: Service의 선택 대상' if kind!='dns' else 'S1: 외부 이름의 DNS 별칭',18)
 text(s,945,266,'문서의 D1 / S1 표식과 실행 영역의 Pod 표식을 연결해 읽습니다.',18)
 box(s,325,315,1250,785,'#f7faff');icon(s,'k8s',345,330);text(s,920,360,'Kubernetes Cluster / 실제 실행 위치',24)
 node(s,350,'Worker Node A',True,kind=='dns');node(s,790,'Worker Node B');node(s,1190,'Worker Node C')
 for x,n in [(815,1),(1215,2)]:
  card(s,x,820,300,('클라이언트 Pod ' if kind=='dns' else 'nginx Pod ')+str(n),'app: api-client' if kind=='dns' else 'http:80 / app: nodeport-deployment','pod')
  text(s,x+150,960,'D1 복제본' + ('' if kind=='dns' else ' / S1 선택 대상'),18)
 if kind!='dns':
  card(s,375,755,280,'내부 클라이언트 Pod','Service 이름:80','pod')
  route(s,'internal-to-node-network','M515 755 V705','internal')
  route(s,'internal-to-backend','M655 656 H735 V735 H765 V670 H815','internal')
  text(s,711,790,'내부 호출',17)
  route(s,'selected-pod-1','M965 705 V820','internal')
  route(s,'selected-pod-2','M1115 680 H1165 V865 H1215','internal')
  text(s,1030,784,'준비된 Pod 선택',17)
  text(s,1150,1029,'파란 분기는 가능한 대상이며 한 연결은 Pod 하나로 전달',17)
 else:
  card(s,375,820,280,'CoreDNS Pod','S1의 외부 이름 응답','pod')
  route(s,'dns-query','M815 845 H755 V675 H655','dns')
  route(s,'dns-delivery','M515 705 V820','dns')
  route(s,'dns-answer','M655 885 H730 V898 H815','dns')
  text(s,715,798,'1. DNS 조회',16);text(s,729,942,'2. 별칭 응답',16)
  card(s,30,730,260,'기존 외부 API 서버','api.example.com:80')
  route(s,'external-api-request','M1115 885 H1150 V1075 H160 V825','external')
  text(s,500,1067,'3. 외부 이름의 IP 확인 후 직접 요청',17)
  text(s,1365,1006,'Pod 1의 호출을 대표로 표시',17)
 if kind in ('cip','np','lb'):
  card(s,30,320,260,'외부 클라이언트','Node IP:30080' if kind=='np' else '외부 로드 밸런서 주소:80')
  if kind!='np':
   card(s,30,525,260,'AWS LoadBalancer','외부 로드 밸런서 / NLB')
   route(s,'client-to-lb','M160 415 V525','external');text(s,245,475,'외부 요청',17)
  if kind=='cip':
   card(s,375,925,280,'Ingress Controller Pod','I1 적용 / ClusterIP:80 호출','pod')
   route(s,'nlb-to-ingress','M290 575 H310 V975 H375','external')
   route(s,'ingress-to-backend','M655 975 H705 V750 H780 V690 H815','external')
   text(s,161,689,'Controller Pod IP로 전달',17)
   text(s,161,728,'NLB는 Ingress의 진입점',17)
  else:
   route(s,'external-to-node','M290 '+('367' if kind=='np' else '575')+' H310 V395 H1165 V635 H1115','external')
   text(s,960,414,'NodePort로 들어오는 외부 요청',17)
 text(s,800,1134,'파랑: 내부 요청과 Pod 전달    주황: 외부 요청    보라: DNS 조회와 응답    회색: kube-proxy의 규칙 설정',18)
 text(s,800,1166,'표시한 경로는 대표 경로이며 반환 패킷과 일부 네트워크 세부 과정은 생략',17)
 text(s,800,1200,f'Fig {number}. {title}',22)
 OUT.joinpath(filename).write_text('\n'.join(s+['</g></svg>']))
make('cip',2,'03-clusterip-topology.svg','ClusterIP: 선언된 리소스와 Node 내부의 요청 처리')
make('np',3,'02-nodeport-paths.svg','NodePort: 내부 호출과 Node 포트의 외부 진입')
make('lb',4,'04-loadbalancer-aws-topology.svg','LoadBalancer: AWS 외부 로드 밸런서와 Node 내부 처리')
make('dns',5,'05-externalname-topology.svg','ExternalName: Node 내부의 DNS 조회와 외부 API 호출')
