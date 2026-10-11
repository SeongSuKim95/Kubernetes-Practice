"""Gateway API reference relationships and runtime traffic, drawn with native assets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'images/articles/14'; OUT.mkdir(exist_ok=True)
FONT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
INK='#233750'; GRAY='#60748b'; BLUE='#326ce5'; ORANGE='#bd5a14'
def canvas(w,h):
 im=Image.new('RGB',(w,h),'white');return im,ImageDraw.Draw(im)
def text(d,xy,s,size=23,color=INK):
 d.text(xy,s,font=ImageFont.truetype(FONT,size),fill=color,anchor='mm')
def box(d,b,lines,fill='#f4f7fc',outline='#9db0c5',size=24):
 d.rounded_rectangle(b,12,fill=fill,outline=outline,width=2)
 cx=(b[0]+b[2])/2; cy=(b[1]+b[3])/2
 for i,line in enumerate(lines): text(d,(cx,cy+(i-(len(lines)-1)/2)*33),line,size)
def icon(im,kind,x,y):
 f={'node':'node-official.png','pod':'pod-official.png','deploy':'deploy-unlabeled.png'}[kind]
 ico=Image.open(ROOT/'images/characters/refs'/f).convert('RGBA');ico.thumbnail((40,40));im.paste(ico,(x,y),ico)
def arrow(d,points,color=BLUE):
 d.line(points,fill=color,width=4,joint='curve');a,b=points[-2:];t=math.atan2(b[1]-a[1],b[0]-a[0]);L=13
 d.polygon([b,(b[0]-L*math.cos(t-.45),b[1]-L*math.sin(t-.45)),(b[0]-L*math.cos(t+.45),b[1]-L*math.sin(t+.45))],fill=color)
im,d=canvas(1200,810)
text(d,(600,36),'Gateway API 리소스의 참조 관계',30)
box(d,(400,80,800,180),['GatewayClass: nginx','Controller 구현 선택'])
box(d,(400,260,800,360),['Gateway: shop-gateway','리스너: web / example.com:80'])
arrow(d,[(600,260),(600,180)]);text(d,(810,220),'gatewayClassName',21)
for x,name,path,svc in [(80,'web-route','/web','web'),(720,'api-route','/api','api')]:
 box(d,(x,450,x+400,560),[f'HTTPRoute: {name}',path])
 arrow(d,[(x+200,450),(x+200,310),((400 if x==80 else 800),310)])
 text(d,(x+60 if x==80 else x+340,404),'parentRefs / sectionName',20)
 box(d,(x,650,x+400,740),[f'Service: {svc}:80','Selector → 애플리케이션 Pod'])
 arrow(d,[(x+200,560),(x+200,650)]);text(d,(x+355,605),'backendRefs',19)
text(d,(600,782),'Fig 1. 공유 Gateway와 애플리케이션별 HTTPRoute',24)
im.save(OUT/'01-gateway-resources.png')
im,d=canvas(1500,1080)
text(d,(750,35),'Gateway의 설정 반영과 실제 요청 경로',30)
box(d,(620,70,1450,340),[],fill='#f5f8fe');text(d,(1035,96),'Control Plane Node',25);icon(im,'node',636,80)
box(d,(660,125,1410,295),['API Server','GatewayClass / Gateway / HTTPRoute','Service / EndpointSlice / Secret'],size=24)
box(d,(40,100,320,200),['외부 클라이언트','example.com'])
box(d,(40,245,320,345),['AWS NLB','외부 로드 밸런서'])
arrow(d,[(180,200),(180,245)],ORANGE)
box(d,(40,400,610,940),[],fill='#eef7f1');text(d,(400,427),'Worker Node A',26);icon(im,'node',55,410)
box(d,(80,475,520,585),['Gateway Controller Pod','선언 관찰과 프록시 설정'],size=23);icon(im,'pod',90,489)
box(d,(80,750,520,890),['프록시 Pod','호스트와 경로 규칙','web → 웹 / api → 상품 API'],size=23);icon(im,'pod',90,763)
arrow(d,[(660,210),(565,210),(565,365),(300,365),(300,475)],GRAY)
text(d,(437,386),'API 변경 정보',20,GRAY)
arrow(d,[(300,585),(300,750)],GRAY);text(d,(440,675),'설정 반영',23,GRAY)
arrow(d,[(40,295),(20,295),(20,820),(80,820)],ORANGE)
for y,node,app in [(400,'B','웹'),(680,'C','API')]:
 box(d,(910,y,1450,y+240),[],fill='#eef7f1');text(d,(1180,y+28),f'Worker Node {node}',25);icon(im,'node',922,y+10)
 box(d,(950,y+75,1410,y+175),[f'{app} Pod',f'{app} Deployment의 복제본'],size=23);icon(im,'pod',960,y+85)
 text(d,(1180,y+207),f'{app} Service의 선택 대상',21)
arrow(d,[(520,820),(730,820),(730,525),(950,525)],ORANGE)
text(d,(829,502),'/web 요청',23,ORANGE)
arrow(d,[(300,890),(300,980),(820,980),(820,805),(950,805)],ORANGE)
text(d,(833,775),'/api 요청',23,ORANGE)
text(d,(750,1043),'Fig 2. 프록시 Pod를 통한 웹 및 API 요청 전달',25)
im.save(OUT/'02-gateway-traffic.png')
