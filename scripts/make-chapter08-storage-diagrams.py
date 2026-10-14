"""Chapter 8 storage relationships, with separate declarations and file I/O."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'images/articles/08';OUT.mkdir(exist_ok=True)
FONT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
INK='#233750';BLUE='#326ce5';GREEN='#16816a';GRAY='#a6b6c8';PURPLE='#8254b4'
def text(d,box,lines,size=24,color=INK):
 if isinstance(lines,str):lines=[lines]
 f=ImageFont.truetype(FONT,size)
 assert max(d.textlength(s,font=f) for s in lines)<box[2]-box[0]-16,lines
 for i,s in enumerate(lines):
  y=(box[1]+box[3])/2+(i-(len(lines)-1)/2)*(size+10)
  d.text(((box[0]+box[2])/2,y),s,font=f,fill=color,anchor='mm')
def box(d,r,lines=None,fill='white',outline=GRAY,size=24):
 d.rounded_rectangle(r,radius=14,fill=fill,outline=outline,width=2)
 if lines:text(d,r,lines,size)
def icon(im,kind,xy):
 p=Image.open(ROOT/f'images/characters/refs/{kind}-official.png').convert('RGBA');p.thumbnail((38,38));im.paste(p,xy,p)
def arrow(d,points,color=BLUE,dashed=False):
 for a,b in zip(points,points[1:]):
  assert a[0]==b[0] or a[1]==b[1]
  if dashed:
   distance=abs(b[0]-a[0])+abs(b[1]-a[1])
   for n in range(0,int(distance),14):
    t=n/distance;u=min(n+7,distance)/distance
    d.line([(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t),(a[0]+(b[0]-a[0])*u,a[1]+(b[1]-a[1])*u)],fill=color,width=3)
  else:d.line([a,b],fill=color,width=4)
 a,b=points[-2:];dx=0 if b[0]==a[0] else (1 if b[0]>a[0] else -1);dy=0 if b[1]==a[1] else (1 if b[1]>a[1] else -1)
 d.polygon([b,(b[0]-dx*12-dy*5,b[1]-dy*12+dx*5),(b[0]-dx*12+dy*5,b[1]-dy*12-dx*5)],fill=color)
def save1():
 im=Image.new('RGB',(1140,700),'white');d=ImageDraw.Draw(im)
 box(d,(30,25,1110,630),fill='#f0f7ff');icon(im,'node',(48,43));text(d,(95,38,410,80),'Worker Node',27)
 box(d,(110,105,1030,590),fill='#f3f0fc');icon(im,'pod',(130,122));text(d,(180,115,970,158),'Pod / log-demo',27)
 box(d,(200,200,490,300),['앱 컨테이너','/var/log/wordpress.log'],size=22)
 box(d,(650,200,940,300),['Sidecar 컨테이너','/var/log/wordpress.log'],size=22)
 box(d,(425,440,715,540),['공유 볼륨 / log','emptyDir'],fill='#e4f5eb',outline=GREEN)
 arrow(d,[(345,300),(345,490),(425,490)],GREEN)
 arrow(d,[(715,490),(795,490),(795,300)],BLUE)
 text(d,(215,350,330,400),'기록',22,GREEN);text(d,(815,350,930,400),'읽기',22,BLUE)
 text(d,(30,644,1110,690),'Fig 1. 같은 Pod의 두 컨테이너와 공유 볼륨',23)
 im.save(OUT/'01-shared-volume.png')
def save2():
 im=Image.new('RGB',(1200,840),'white');d=ImageDraw.Draw(im)
 box(d,(30,20,1170,385),fill='#f1f5fc');text(d,(70,33,1130,76),'API에 저장된 저장소 선언',27)
 box(d,(60,95,525,355),fill='#f5f0fc');text(d,(80,105,500,149),'Namespace / mariadb',23)
 box(d,(155,195,435,295),['PVC / mariadb','저장소 요청'],fill='white')
 box(d,(765,195,1045,295),['PV / mariadb-pv','클러스터 범위'],fill='white')
 arrow(d,[(435,245),(765,245)],PURPLE,True);text(d,(455,185,745,230),'바인딩 / Bound',22,PURPLE)
 box(d,(60,460,535,750),fill='#edf8f1');icon(im,'node',(80,480));text(d,(130,473,500,514),'Worker Node',26)
 box(d,(155,555,435,680),['Pod / MariaDB','컨테이너 경로','/var/lib/mysql'],fill='white',size=22);icon(im,'pod',(168,565))
 box(d,(765,555,1045,680),['실제 저장소','데이터베이스 파일'],fill='#fff6df',outline='#c7a452')
 arrow(d,[(155,617.5),(125,617.5),(125,420),(295,420),(295,295)],PURPLE,True)
 text(d,(320,396,595,440),'PVC 참조',21,PURPLE)
 arrow(d,[(905,295),(905,555)],PURPLE,True);text(d,(915,396,1155,440),'저장소 연결 정보',21,PURPLE)
 arrow(d,[(435,617.5),(765,617.5)],GREEN);text(d,(470,565,730,605),'파일 읽기와 쓰기',22,GREEN)
 text(d,(25,783,1175,827),'Fig 2. PVC와 PV의 선언 관계 및 실제 파일 접근',23)
 im.save(OUT/'02-pvc-pv-and-storage.png')
if __name__=='__main__':save1();save2()
