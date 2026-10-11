#!/usr/bin/env python3
"""Animate the existing termination flowchart, with separate normal/timeout cases."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

FONT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
OUT=Path('images/articles/05/03-pod-termination.gif')
# Source diagram coordinates are compressed; font sizes remain readable.
SX,SY=.88,.72
BLUE='#2477e8';GREEN='#07967f';ORANGE='#ba661b';GRAY='#cbd4df';INK='#263b53'
BOXES=[
((600,85,900,155),['kubectl delete pod'],None),
((480,225,1020,315),['API Server','기존 Pod 삭제 요청 기록'],None),
((250,465,690,555),['기존 Node의 Kubelet','API의 삭제 상태 확인'],'node'),
((1035,465,1395,555),['ReplicaSet Controller','API에 새 Pod 생성 요청'],None),
((250,615,690,705),['Kubelet → 컨테이너 런타임','종료 요청'],None),
((250,765,690,855),['기존 Pod의 애플리케이션','SIGTERM 수신과 작업 정리'],'pod'),
((65,970,425,1080),['유예 기간 안의 작업 완료','프로세스 종료'],None),
((515,970,875,1080),['유예 기간 초과','남은 프로세스 강제 종료'],None),
((250,1190,690,1280),['Kubelet의 종료 결과 보고','API의 기존 Pod 정리'],None),
((1035,615,1395,705),['Scheduler','Node 배정과 API 기록'],None),
((1035,765,1395,855),['배정된 Node의 Kubelet','API 확인과 런타임 실행 요청'],'node'),
((1035,915,1395,1005),['새 Pod의 컨테이너','애플리케이션 초기화'],'pod'),
((1035,1065,1395,1155),['준비 검사 성공','요청 준비 완료'],None)]
EDGES=[
(0,1,[(750,155),(750,225)]),
(1,2,[(480,270),(15,270),(15,445),(470,445),(470,465)]),
(1,3,[(1020,270),(1480,270),(1480,445),(1215,445),(1215,465)]),
(2,4,[(470,555),(470,615)]),(4,5,[(470,705),(470,765)]),
(5,6,[(470,855),(470,910),(245,910),(245,970)]),
(5,7,[(470,855),(470,910),(695,910),(695,970)]),
(6,8,[(245,1080),(245,1140),(470,1140),(470,1190)]),
(7,8,[(695,1080),(695,1140),(470,1140),(470,1190)]),
(3,9,[(1215,555),(1215,615)]),(9,10,[(1215,705),(1215,765)]),
(10,11,[(1215,855),(1215,915)]),(11,12,[(1215,1005),(1215,1065)])]

def pt(p):return (p[0]*SX,p[1]*SY)
def rect(r):return (r[0]*SX,r[1]*SY,r[2]*SX,r[3]*SY)
def render(case,stage,progress):
 im=Image.new('RGB',(1320,1155),'white');d=ImageDraw.Draw(im)
 def text(x,y,s,size=20,color=INK):
  d.text(pt((x,y)),s,font=ImageFont.truetype(FONT,size),fill=color,anchor='mm')
 text(750,40,'Pod 삭제와 대체 생성',27)
 for r,fill in [((35,380,905,1345),'#fff8f1'),((965,380,1465,1345),'#eef8f3')]:
  d.rounded_rectangle(rect(r),14,fill=fill,outline=GRAY,width=1)
 text(470,410,'기존 Pod의 종료',23,ORANGE);text(1215,410,'대체 Pod의 생성과 실행',23,GREEN)
 text(750,352,'병행 진행',18)
 text(145,695,'종료 유예 기간',18,ORANGE);text(145,730,'기본 30초',18,ORANGE)
 end=6 if case==0 else 7;branch=5 if case==0 else 6;report=7 if case==0 else 8
 flows=[[0],[1,2],[3,9],[4,10],[branch,11],[report,12],[]]
 # The timeout example lets the replacement become ready while the old Pod is still stopping.
 if case==1:flows=[[0],[1,2],[3,9],[4,10],[11],[12],[branch],[report],[]]
 done=set([0]);past=set()
 for row in flows[:stage]:
  for e in row:done.add(EDGES[e][1]);past.add(e)
 active=set(flows[stage]);highlight={EDGES[e][1] for e in active}
 for i,(r,lines,icon) in enumerate(BOXES):
  color=GREEN if i in (3,9,10,11,12) else BLUE if i in (0,1) else ORANGE
  on=i in highlight;seen=i in done
  d.rounded_rectangle(rect(r),10,fill=('#e0f2ec' if color==GREEN else '#fff0da' if color==ORANGE else '#e4efff') if on or seen else 'white',outline=color if on else GRAY,width=3 if on else 1)
  l,t,rr,b=r
  for j,line in enumerate(lines):
   font=ImageFont.truetype(FONT,20)
   assert d.textbbox((0,0),line,font=font)[2] < (rr-l)*SX-22,line
   text((l+rr)/2,(t+b)/2+(j-(len(lines)-1)/2)*34,line,color=INK if on or seen else '#788594')
  if icon:
   ic=Image.open(f'images/characters/refs/{icon}-official.png').convert('RGBA');ic.thumbnail((25,25));im.paste(ic,(round(l*SX)+8,round(t*SY)+8),ic)
 def path(e,color,width,dot=False):
  pts=[pt(p) for p in EDGES[e][2]];d.line(pts,fill=color,width=width)
  a,b=pts[-2:];angle=math.atan2(b[1]-a[1],b[0]-a[0]);x,y=b
  d.polygon([(x,y),(x-10*math.cos(angle)+4*math.sin(angle),y-10*math.sin(angle)-4*math.cos(angle)),(x-10*math.cos(angle)-4*math.sin(angle),y-10*math.sin(angle)+4*math.cos(angle))],fill=color)
  if dot:
   lengths=[math.dist(a,b) for a,b in zip(pts,pts[1:])];dist=sum(lengths)*progress
   for a,b,length in zip(pts,pts[1:],lengths):
    if dist<=length:
     x=a[0]+(b[0]-a[0])*dist/length;y=a[1]+(b[1]-a[1])*dist/length
     d.ellipse((x-5,y-5,x+5,y+5),fill=color);break
    dist-=length
 for e in range(len(EDGES)):path(e,GRAY,2)
 for e in active:path(e,GREEN if e in (2,9,10,11,12) else BLUE if e==0 else ORANGE,4,True)
 titles=['삭제 요청의 API 기록','기존 Pod 종료와 대체 생성 시작','종료 요청과 새 Pod의 Node 배정','작업 정리와 새 컨테이너 실행 준비','기존 프로세스 종료와 새 Pod 초기화','기존 Pod 정리와 새 Pod 준비 완료','Pod 교체 완료']
 if case:titles=['삭제 요청의 API 기록','기존 Pod 종료와 대체 생성 시작','종료 요청과 새 Pod의 Node 배정','작업 정리와 새 컨테이너 실행 준비','기존 작업 정리 중 새 Pod 초기화','기존 작업 정리 중 새 Pod 준비 완료','종료 유예 기간 초과와 강제 종료','기존 Pod 종료 결과 보고','Pod 교체 완료']
 text(750,1390,'유예 기간 안의 종료' if case==0 else '유예 기간 초과 사례',23,ORANGE)
 text(750,1440,f'{stage+1}. {titles[stage]}',22,BLUE)
 text(750,1490,'Fig 2. 기존 Pod의 정상 종료와 대체 Pod 생성',20)
 return im

def main():
 for a,b,pts in EDGES:
  def mids(r):
   l,t,rr,bt=r;return {(l,(t+bt)/2),(rr,(t+bt)/2),((l+rr)/2,t),((l+rr)/2,bt)}
  assert pts[0] in mids(BOXES[a][0]) and pts[-1] in mids(BOXES[b][0])
 frames=[]
 for case,count in [(0,7),(1,9)]:
  for stage in range(count):
   for step in range(10):frames.append(render(case,stage,min(step/7,1)))
   frames[-1].save(f'/tmp/ch05-termination-{case}-{stage}.png')
 frames[0].save(OUT,save_all=True,append_images=frames[1:],duration=250,loop=0,disposal=2)
 print(OUT)
if __name__=='__main__':main()
