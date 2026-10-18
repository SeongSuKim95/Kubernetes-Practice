# -*- coding: utf-8 -*-
"""Additional chapter 8 diagrams; run with /usr/bin/python3."""
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw
spec=importlib.util.spec_from_file_location('base',Path(__file__).with_name('make-chapter08-storage-diagrams.py'))
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)

def canvas(h):
 im=Image.new('RGB',(1200,h),'white');return im,ImageDraw.Draw(im)
def label(d,r,s,color=b.INK,size=22):b.text(d,r,s,size,color)
def node(im,d,r,name):
 b.box(d,r,fill='#eef6ff');b.icon(im,'node',(r[0]+15,r[1]+15));label(d,(r[0]+60,r[1]+10,r[2]-10,r[1]+55),name,size=24)
def pod(im,d,r,name,fill='#f3effb'):
 b.box(d,r,name,fill=fill);b.icon(im,'pod',(r[0]+12,r[1]+12))
def save(im,n,name):im.save(b.OUT/name)

def lifecycle():
 im,d=canvas(760)
 pod(im,d,(65,50,375,160),'이전 Pod',fill='#f1f2f4')
 pod(im,d,(825,50,1135,160),'새 Pod')
 label(d,(410,65,790,145),'Pod 교체',size=28)
 b.box(d,(370,265,830,655),fill='#f1f8f2',outline='#8fb69b')
 label(d,(390,280,810,320),'유지되는 저장소 연결',size=25)
 b.box(d,(460,345,740,415),['기존 PVC / Bound'])
 b.box(d,(460,475,740,545),'기존 PV / Bound')
 b.box(d,(460,590,740,640),'저장소 / 기존 데이터',fill='#fff4da',outline='#c7a452',size=22)
 b.arrow(d,[(220,160),(220,380),(460,380)],b.GRAY,True)
 b.arrow(d,[(980,160),(980,380),(740,380)],b.PURPLE,True)
 label(d,(225,205,445,255),'이전 PVC 참조',b.GRAY)
 label(d,(750,205,975,255),'같은 PVC 참조',b.PURPLE)
 b.arrow(d,[(600,415),(600,475)],b.PURPLE,True)
 b.arrow(d,[(600,545),(600,590)],b.PURPLE,True)
 label(d,(30,695,1170,745),'Fig 3. Pod 교체 이후에도 유지되는 저장소 연결',size=23)
 save(im,3,'03-pod-replacement-storage.png')

def provisioning():
 im,d=canvas(700)
 b.box(d,(30,25,1170,235),fill='#f1f5fc')
 label(d,(55,35,1145,75),'API에 저장되는 선언',size=25)
 b.box(d,(70,105,350,195),['PVC','저장 공간 요청'])
 b.box(d,(460,105,740,195),['StorageClass','생성 방식'])
 b.box(d,(850,105,1130,195),['새 PV','저장소 연결 정보'])
 b.arrow(d,[(350,150),(460,150)],b.PURPLE,True)
 label(d,(345,200,465,235),'클래스 선택',b.PURPLE,18)
 b.box(d,(460,350,740,450),['프로비저너','저장소 준비'],fill='#edf8f1')
 b.box(d,(850,350,1130,450),['실제 저장소','새 데이터 공간'],fill='#fff4da',outline='#c7a452')
 b.arrow(d,[(210,195),(210,400),(460,400)],b.BLUE)
 label(d,(220,260,445,305),'1. 요청 확인',b.BLUE)
 b.arrow(d,[(600,350),(600,195)],b.PURPLE,True)
 label(d,(615,265,820,305),'생성 방식 참조',b.PURPLE,21)
 b.arrow(d,[(600,450),(600,550),(990,550),(990,450)],b.GREEN)
 label(d,(675,565,1005,610),'2. 저장소 생성',b.GREEN)
 b.arrow(d,[(740,400),(795,400),(795,275),(990,275),(990,195)],b.BLUE)
 label(d,(850,290,1150,330),'3. PV 등록',b.BLUE)
 label(d,(30,645,1170,690),'Fig 4. StorageClass를 이용한 저장소와 PV의 준비',size=23)
 save(im,4,'04-dynamic-provisioning.png')

def placement():
 im,d=canvas(700)
 # Separate snapshots: arrows inside each show dependency, middle arrow shows time.
 b.box(d,(30,35,455,620),fill='#f5f7fb')
 label(d,(50,45,435,90),'1. PVC 생성 / 사용 Pod 대기',size=24)
 b.box(d,(110,140,375,235),['PVC','Pending'],size=21)
 label(d,(55,250,430,315),['StorageClass','WaitForFirstConsumer'],size=22)
 label(d,(65,400,420,470),['사용 Pod 없음','저장소 위치 결정 전'],size=24)
 b.arrow(d,[(455,327.5),(575,327.5)],b.BLUE)
 label(d,(455,260,575,305),'Pod 생성',b.BLUE,18)
 b.box(d,(575,35,1170,620),fill='#f5f7fb')
 label(d,(595,45,1150,90),'2. Pod의 배치 조건과 저장소 준비',size=24)
 b.box(d,(610,120,810,220),['Pod 선언','Node B 배치 조건'],size=21)
 b.box(d,(905,120,1135,220),['Scheduler','배치 조건 검토'],size=21)
 b.arrow(d,[(810,170),(905,170)],b.PURPLE,True)
 node(im,d,(620,335,1125,590),'Worker Node B')
 pod(im,d,(650,420,850,530),'Pod')
 b.box(d,(925,420,1095,530),['로컬 저장소','데이터'],fill='#fff4da',outline='#c7a452',size=21)
 b.arrow(d,[(1020,220),(1020,290),(872.5,290),(872.5,335)],b.BLUE)
 label(d,(615,245,865,285),'배치와 저장소 위치 조율',b.BLUE,20)
 b.arrow(d,[(850,475),(925,475)],b.GREEN)
 label(d,(835,540,945,575),'마운트',b.GREEN,18)
 label(d,(30,645,1170,690),'Fig 5. Pod 배치 조건을 고려하는 저장소 준비',size=23)
 save(im,5,'05-wait-for-first-consumer.png')

if __name__=='__main__':
 lifecycle();provisioning();placement()
