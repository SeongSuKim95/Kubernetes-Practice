"""Service type diagrams with validated midpoint connections and orthogonal routes."""
from pathlib import Path
import base64,html
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'images/articles/05'
ICONS={k:base64.b64encode((ROOT/'images/characters/refs'/v).read_bytes()).decode() for k,v in {'node':'node-official.png','pod':'pod-official.png','svc':'svc.png','deploy':'deploy-unlabeled.png'}.items()}
C={'traffic':'#2464ce','external':'#bd650d','dns':'#7952b3','config':'#7b8798'}
def text(x,y,value,size=22,color='#20334d'):
 s.append(f'<text x="{x}" y="{y}" text-anchor="middle" font-size="{size}" fill="{color}">{html.escape(value)}</text>')
def box(name,x,y,w,h,fill='#fff',icon=None,container=False):
 s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="#b5c6d5" stroke-width="2"/>')
 if not container: boxes[name]=(x,y,w,h)
 if icon:s.append(f'<image x="{x+12}" y="{y+12}" width="36" height="36" href="data:image/png;base64,{ICONS[icon]}"/>')
def port(name,side):
 x,y,w,h=boxes[name];return {'l':(x,y+h/2),'r':(x+w,y+h/2),'t':(x+w/2,y),'b':(x+w/2,y+h)}[side]
def route(name,src,dst,key,via=(),dash=False):
 pts=[port(*src),*via,port(*dst)]
 for a,b in zip(pts,pts[1:]):
  assert a[0]==b[0] or a[1]==b[1],(name,a,b)
  for x,y,w,h in boxes.values():
   assert not(a[1]==b[1] and a[1] in (y,y+h) and min(max(a[0],b[0]),x+w)>max(min(a[0],b[0]),x)),name
   assert not(a[0]==b[0] and a[0] in (x,x+w) and min(max(a[1],b[1]),y+h)>max(min(a[1],b[1]),y)),name
 d='M'+' L'.join(f'{x} {y}' for x,y in pts)
 s.append(f'<path d="{d}" fill="none" stroke="{C[key]}" stroke-width="3" marker-end="url(#{key})"'+(' stroke-dasharray="7 6"' if dash else '')+'/>')
 routes[name]={'points':pts,'color':key}
def node(x,w,label):
 box(label,x,400,w,620,'#eef7f1','node',True);text(x+w/2+18,443,label,24)
def make(kind,figure_number,filename):
 global s,boxes,routes
 boxes={};routes={}
 s=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1150" viewBox="0 0 1600 1150"><defs>']
 for k,c in C.items():s.append(f'<marker id="{k}" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0L8 4L0 8Z" fill="{c}"/></marker>')
 s.append('</defs><rect width="1600" height="1150" fill="white"/><g font-family="Apple SD Gothic Neo,Noto Sans KR,sans-serif">')
 if kind=='ClusterIP':
  s=[part.replace('1600','1200').replace('1150','850') for part in s]
  text(600,35,'ClusterIP: 클러스터 내부의 Pod 통신',27)
  box('svc',40,60,510,100,'#fff8e8','svc');text(315,100,'Service: web / ClusterIP',23);text(295,138,'10.96.10.20:80',23)
  box('deploy',650,60,510,100,'#fff8e8','deploy');text(925,100,'Deployment: web-app',23);text(905,138,'replicas: 2 / app=web',21)
  for x,label in [(50,'Worker Node A'),(690,'Worker Node B')]:
   box(label,x,200,460,570,'#eef7f1','node',True);text(x+245,243,label,24)
  box('client',90,290,380,100,icon='pod');text(300,330,'클라이언트 Pod',23);text(280,368,'web:80',22)
  box('proxya',90,450,380,65,'#f0f3f7');text(280,477,'kube-proxy',22);text(280,503,'Node 안의 프로세스',17)
  box('rulesa',90,620,380,100,'#e9f0ff');text(280,658,'운영체제의 전달 규칙',22);text(280,698,'Service IP → Pod IP',21)
  box('proxyb',730,290,380,65,'#f0f3f7');text(920,317,'kube-proxy',22);text(920,343,'Node 안의 프로세스',17)
  box('pod1',730,620,380,100,icon='pod');text(940,658,'웹 Pod / app=web',22);text(920,698,'10.244.2.8:80',22)
  route('config-a',('proxya','b'),('rulesa','t'),'config',dash=True)
  route('internal-start',('client','b'),('rulesa','l'),'traffic',[(280,420),(70,420),(70,670)])
  route('internal-target',('rulesa','r'),('pod1','l'),'traffic')
  text(600,825,'Fig 5. ClusterIP의 요청 경로',24)
  OUT.joinpath(filename).write_text('\n'.join(s+['</g></svg>']))
  return
 text(800,35,f'{kind}: '+({'ClusterIP':'클러스터 내부에서 사용하는 접근점','NodePort':'Node의 포트로 들어오는 외부 요청','LoadBalancer':'AWS 외부 로드 밸런서로 들어오는 요청','ExternalName':'이름 조회 후 외부 서버에 직접 요청'}[kind]),28)
 box('svc',50,70,690,140,'#fff8e8','svc');box('deploy',810,70,740,140,'#fff8e8','deploy')
 text(410,111,'Service: '+('api / ExternalName' if kind=='ExternalName' else 'web / '+kind),24)
 text(395,155,'api → api.example.com' if kind=='ExternalName' else '10.96.10.20:80 / selector: app=web',23)
 text(395,190,'DNS 별칭 / Pod 선택과 트래픽 중계 없음' if kind=='ExternalName' else '가상 접근점과 대상 선택을 선언',18)
 text(1200,111,'Deployment: '+('api-client' if kind=='ExternalName' else 'web-app'),24)
 text(1180,155,'replicas: 2 / 두 Node에 한 개씩 배치한 예시',22)
 text(1180,190,'위 상자는 API에 저장된 선언이며 실행 중인 서버가 아님',18)
 node(50,450,'Worker Node A');node(650,420,'Worker Node B');node(1160,390,'Worker Node C')
 if kind=='ExternalName':
  box('client',90,500,370,120,icon='pod');text(290,540,'클라이언트 Pod 1',22);text(275,579,'api 이름으로 외부 API 호출',20);text(275,608,'Deployment의 복제본',17)
  box('replica',690,830,340,110,icon='pod');text(875,870,'클라이언트 Pod 2',22);text(860,910,'같은 Deployment의 복제본',18)
  box('dns',1190,660,330,160,icon='pod');text(1370,701,'CoreDNS Pod',22);text(1355,747,'api → api.example.com',21);text(1355,790,'CNAME 별칭 응답',18)
  box('api',50,270,350,80);text(225,302,'외부 API 서버',23);text(225,333,'api.example.com:80',20)
  route('dns-query',('client','b'),('dns','l'),'dns',[(275,650),(560,650),(560,740)])
  route('dns-response',('dns','t'),('client','t'),'dns',[(1355,470),(275,470)])
  route('external-request',('client','l'),('api','l'),'external',[(20,560),(20,310)])
  text(830,708,'1. api 이름 조회',21,C['dns']);text(830,505,'2. 외부 이름 응답',21,C['dns'])
  text(660,305,'3. 외부 이름의 IP를 알아낸 뒤 직접 요청',22,C['external'])
  text(800,1060,'Pod 1의 호출 예시 / 외부 이름의 IP 조회와 DNS용 Service의 세부 전달은 생략',19)
 else:
  box('client',90,500,370,120,icon='pod');text(290,542,'내부 클라이언트 Pod',22);text(275,585,'web:80으로 요청',21)
  for x,w,n in [(90,370,'a'),(690,340,'b'),(1190,330,'c')]:
   py=690 if n=='a' else 530
   box('proxy'+n,x,py,w,70,'#f0f3f7');text(x+w/2,py+29,'kube-proxy',22);text(x+w/2,py+55,'Node 안의 프로세스',17)
  box('rulesa',90,830,370,110,'#e9f0ff');text(275,868,'운영체제의 전달 규칙',22);text(275,908,'Service IP → Pod IP',21)
  box('rulesb',690,690,340,70,'#e9f0ff');text(860,719,'운영체제의 네트워크 처리',19);text(860,746,'Pod로 전달',18)
  for name,x,w,num,ip in [('pod1',690,340,1,'10.244.2.8'),('pod2',1190,330,2,'10.244.3.8')]:
   box(name,x,830,w,110,icon='pod');text(x+w/2+15,870,f'웹 Pod {num} / 복제본',21);text(x+w/2,910,ip+':80 / app=web',18)
  route('config-a',('proxya','b'),('rulesa','t'),'config',dash=True)
  route('config-b',('proxyb','b'),('rulesb','t'),'config',dash=True)
  route('internal-start',('client','b'),('rulesa','l'),'traffic',[(275,650),(70,650),(70,885)])
  route('internal-target',('rulesa','r'),('rulesb','l'),'traffic',[(580,885),(580,725)])
  route('to-pod',('rulesb','b'),('pod1','t'),'traffic')
  # One selected destination keeps the actual request path unambiguous.
  text(1355,974,'같은 Service의 다른 대상 후보',18)
  if kind=='ClusterIP':
   text(800,302,'내부 클라이언트는 Service IP로 접속 / 웹 Pod 1이 선택된 요청 예시',23)
  else:
   box('external',50,270,280,80);text(190,302,'외부 클라이언트',23);text(190,333,'Node IP:30080' if kind=='NodePort' else 'NLB 주소:80',20)
   if kind=='LoadBalancer':
    box('lb',480,270,420,80);text(690,302,'AWS LoadBalancer / NLB',23);text(690,333,'외부 로드 밸런서',20)
    route('client-lb',('external','r'),('lb','l'),'external')
    origin=('lb','r');via=[(1120,310),(1120,725)]
   else:origin=('external','r');via=[(1120,310),(1120,725)]
   route('external-node',origin,('rulesb','r'),'external',via)
   text(1300,378,'NodePort로 진입',20,C['external'])
   text(800,1090,'내부 요청과 외부 요청 모두 준비된 웹 Pod 중 하나로 전달',19)
 text(800,1130,f'Fig {figure_number}. {kind}의 요청 경로',24)
 OUT.joinpath(filename).write_text('\n'.join(s+['</g></svg>']))
make('ClusterIP',5,'03-clusterip-topology.svg')
make('NodePort',6,'02-nodeport-paths.svg')
make('LoadBalancer',7,'04-loadbalancer-aws-topology.svg')
make('ExternalName',8,'05-externalname-topology.svg')
