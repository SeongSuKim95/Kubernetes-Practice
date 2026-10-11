#!/usr/bin/env python3
"""Render chapter 5 Fig 2: concurrent Pod termination and replacement."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

OUT=Path('images/articles/05/03-pod-termination.png')
im=Image.new('RGB',(1500,1460),'white'); d=ImageDraw.Draw(im)
FONT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
INK='#263b53'; BLUE='#2477e8'; GREEN='#07967f'; ORANGE='#ba661b'; EDGE='#b7c8da'
def text(x,y,t,size=23,color=INK):
 f=ImageFont.truetype(FONT,size)
 d.text((x,y),t,font=f,fill=color,anchor='mm')
def box(xy,lines,fill='white',color=EDGE,icon=None):
 d.rounded_rectangle(xy,12,fill=fill,outline=color,width=2)
 x1,y1,x2,y2=xy
 for i,t in enumerate(lines):
  f=ImageFont.truetype(FONT,23)
  assert d.textbbox((0,0),t,font=f)[2] < x2-x1-28,t
  text((x1+x2)/2,(y1+y2)/2+(i-(len(lines)-1)/2)*32,t)
 if icon:
  ic=Image.open('images/characters/refs/'+icon+'-official.png').convert('RGBA');ic.thumbnail((31,31));im.paste(ic,(x1+10,y1+10),ic)
def arrow(points,color=BLUE):
 d.line(points,fill=color,width=4)
 a,b=points[-2:];angle=math.atan2(b[1]-a[1],b[0]-a[0]);x,y=b
 d.polygon([(x,y),(x-13*math.cos(angle)+6*math.sin(angle),y-13*math.sin(angle)-6*math.cos(angle)),(x-13*math.cos(angle)-6*math.sin(angle),y-13*math.sin(angle)+6*math.cos(angle))],fill=color)
text(750,42,'Pod 삭제와 대체 생성',32)
box((600,85,900,155),['kubectl delete pod'])
box((480,225,1020,315),['API Server','기존 Pod 삭제 요청 기록'],fill='#edf3ff')
arrow([(750,155),(750,225)])
# Parallel lanes are processes, not physical Node containers.
d.rounded_rectangle((35,380,905,1345),18,fill='#fff8f1',outline=EDGE,width=2)
d.rounded_rectangle((965,380,1465,1345),18,fill='#eef8f3',outline=EDGE,width=2)
text(470,413,'기존 Pod의 종료',27,ORANGE);text(1215,413,'대체 Pod의 생성과 실행',27,GREEN)
text(750,351,'병행 진행',20)
box((250,465,690,555),['기존 Node의 Kubelet','API의 삭제 상태 확인'],icon='node')
box((1035,465,1395,555),['ReplicaSet Controller','API에 새 Pod 생성 요청'])
arrow([(480,270),(15,270),(15,445),(470,445),(470,465)],ORANGE)
arrow([(1020,270),(1480,270),(1480,445),(1215,445),(1215,465)],GREEN)
box((250,615,690,705),['Kubelet → 컨테이너 런타임','종료 요청'],color=ORANGE)
arrow([(470,555),(470,615)],ORANGE)
box((250,765,690,855),['기존 Pod의 애플리케이션','SIGTERM 수신과 작업 정리'],icon='pod')
arrow([(470,705),(470,765)],ORANGE)
text(146,700,'종료 유예 기간',21,ORANGE);text(146,733,'기본 30초',21,ORANGE)
# Two possible outcomes, not an obligatory force-kill sequence.
box((65,970,425,1080),['유예 기간 안의 작업 완료','프로세스 종료'])
box((515,970,875,1080),['유예 기간 초과','남은 프로세스 강제 종료'])
arrow([(470,855),(470,910),(245,910),(245,970)],ORANGE)
arrow([(470,855),(470,910),(695,910),(695,970)],ORANGE)
box((250,1190,690,1280),['Kubelet의 종료 결과 보고','API의 기존 Pod 정리'])
arrow([(245,1080),(245,1140),(470,1140),(470,1190)],ORANGE)
arrow([(695,1080),(695,1140),(470,1140),(470,1190)],ORANGE)
for xy,ls,ic in [((1035,615,1395,705),['Scheduler','Node 배정과 API 기록'],None),((1035,765,1395,855),['배정된 Node의 Kubelet','API 확인과 런타임 실행 요청'],'node'),((1035,915,1395,1005),['새 Pod의 컨테이너','애플리케이션 초기화'],'pod'),((1035,1065,1395,1155),['준비 검사 성공','요청 준비 완료'],None)]:
 box(xy,ls,icon=ic)
for y in [555,705,855,1005]:arrow([(1215,y),(1215,y+60)],GREEN)
text(750,1405,'Fig 2. 기존 Pod의 정상 종료와 대체 Pod 생성',23)
OUT.parent.mkdir(parents=True,exist_ok=True);im.save(OUT);print(OUT)
