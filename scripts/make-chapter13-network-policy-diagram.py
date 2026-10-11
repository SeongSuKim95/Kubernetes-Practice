"""Pod-scoped traffic directions with Node placement and official resource icons."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'images/articles/13';OUT.mkdir(exist_ok=True)
im=Image.new('RGB',(1500,900),'white');d=ImageDraw.Draw(im)
FONT='/System/Library/Fonts/AppleSDGothicNeo.ttc';INK='#243b53';BLUE='#326ce5';PURPLE='#8055aa'
def txt(x,y,s,size=24,color=INK):d.text((x,y),s,font=ImageFont.truetype(FONT,size),fill=color,anchor='mm')
def rect(b,fill):d.rounded_rectangle(b,14,fill=fill,outline='#9aafc3',width=2)
def icon(kind,x,y):
 p=Image.open(ROOT/'images/characters/refs'/f'{kind}-official.png').convert('RGBA');p.thumbnail((44,44));im.paste(p,(x,y),p)
def arrow(pts,color):
 d.line(pts,fill=color,width=4,joint='curve');a,b=pts[-2:];t=math.atan2(b[1]-a[1],b[0]-a[0]);L=14
 d.polygon([b,(b[0]-L*math.cos(t-.45),b[1]-L*math.sin(t-.45)),(b[0]-L*math.cos(t+.45),b[1]-L*math.sin(t+.45))],fill=color)
txt(750,45,'한 요청의 송신 정책과 수신 정책',32)
for x,y,n in [(50,120,'A'),(950,120,'B'),(950,530,'C')]:
 rect((x,y,x+500,y+300),'#eef7f1');icon('node',x+15,y+15);txt(x+270,y+35,f'Worker Node {n}',26)
for x,y,name,ns in [(100,235,'frontend Pod','frontend'),(1000,235,'backend Pod','backend'),(1000,645,'CoreDNS Pod','kube-system')]:
 rect((x,y,x+400,y+120),'#f4f7fc');icon('pod',x+12,y+12);txt(x+225,y+43,name,25);txt(x+200,y+86,f'Namespace: {ns}',21)
arrow([(500,295),(1000,295)],BLUE)
txt(750,235,'2. backend 요청 / TCP 80',25,BLUE)
txt(635,335,'Egress 허용',23,BLUE);txt(875,335,'Ingress 허용',23,BLUE)
arrow([(300,355),(300,705),(1000,705)],PURPLE)
txt(660,663,'1. DNS 조회 / UDP / TCP 53',25,PURPLE)
txt(660,743,'frontend의 Egress 허용',23,PURPLE)
txt(300,200,'frontend Deployment의 Pod',20)
txt(1200,392,'backend Deployment의 Pod',20)
txt(1200,802,'CoreDNS Deployment의 Pod',20)
txt(750,867,'Fig 1. Frontend의 송신과 Backend의 수신 및 DNS 조회',25)
im.save(OUT/'01-network-policy-directions.png')
