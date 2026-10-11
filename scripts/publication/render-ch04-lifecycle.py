"""Render Fig 3/4 using the same bilingual cluster layout as Fig 5/6."""
from pathlib import Path
import importlib.util, re, sys, math
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('probe',ROOT/'scripts/render-chapter04-probe-flows.py'); g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
EN='--en' in sys.argv
if EN:g.LANG='en';g.OUT=g.OUT/'en'
def text(d,box,ko,en,size=22,color=g.INK):
 v=en if EN else ko
 # Stage captions may use two lines rather than shrinking their font.
 if g.font(size).getlength(v)>box[2]-box[0]-15:
  words=v.split(); lines=['']
  for w in words:
   trial=(lines[-1]+' '+w).strip()
   if g.font(size).getlength(trial)>box[2]-box[0]-15:lines.append(w)
   else:lines[-1]=trial
  assert len(lines)<=2,v
  for n,line in enumerate(lines):g.text(d,(box[0],box[1]+n*32,box[2],box[1]+(n+1)*32),line,size,color)
 else:g.text(d,box,v,size,color)
CTRL=[(305,440),(365,440)];SCHED=[(305,740),(335,740),(335,440),(365,440)]
USER=[(460,110),(460,270)]
creation_ko=[
'사용자가 Deployment에 Pod 템플릿과 원하는 Pod 개수 3개를 선언합니다.',
'Deployment Controller가 API에 기록된 Deployment를 확인합니다.',
'Deployment Controller가 Pod 세 개를 유지할 ReplicaSet 생성을 요청합니다.',
'ReplicaSet Controller가 원하는 개수 3개와 현재 Pod 객체 수 0개를 비교합니다.',
'ReplicaSet Controller가 API Server에 Pod A, B, C 생성을 요청합니다.',
'Scheduler가 아직 배정되지 않은 Pod의 실행 조건을 확인합니다.',
'Scheduler가 실행할 Node를 선택하고 배정 결과를 API에 기록합니다.',
'Kubelet이 API에서 자신의 Node에 배정된 Pod를 확인합니다.',
'Kubelet이 런타임에 컨테이너 실행을 요청합니다.',
'런타임이 Pod A, B, C의 컨테이너를 실행합니다.',
'사용자의 삭제 요청을 받은 API Server가 Pod C를 삭제 중으로 표시합니다.',
'Kubelet이 API에서 Pod C의 삭제 요청을 확인합니다.',
'Kubelet이 런타임에 Pod C의 컨테이너 종료를 요청합니다.',
'런타임이 종료 절차를 거쳐 Pod C의 컨테이너를 중지합니다.',
'Kubelet이 종료 상태를 보고하고 Pod C 객체의 최종 삭제를 요청합니다.',
'API Server가 종료된 Pod C 객체를 제거합니다.',
'ReplicaSet Controller가 유지 중인 Pod 두 개를 확인합니다.',
'ReplicaSet Controller가 부족한 한 개를 채울 Pod D 생성을 요청합니다.',
'Scheduler가 새 Pod D의 자원 요청과 배치 조건을 확인합니다.',
'Scheduler가 Pod D의 Node 배정 결과를 API에 기록합니다.',
'배정된 Node의 Kubelet이 API에서 Pod D의 실행 설정을 확인합니다.',
'Kubelet이 런타임에 Pod D의 컨테이너 실행을 요청합니다.',
'런타임이 Pod D의 컨테이너를 실행해 실행 중인 Pod 수가 다시 세 개가 됩니다.'
]
creation_en=re.findall(r'Stage\(title:"([^"]+)"',(ROOT/'scripts/chapter04-en/render-ch04-fig3.swift').read_text())
status_en=re.findall(r'Stage\(title:"([^"]+)"',(ROOT/'scripts/chapter04-en/render-ch04-status.swift').read_text())
status_ko=['Kubelet이 컨테이너 실행 상태와 준비 검사 결과를 API Server에 보고합니다.','API Server가 보고된 Pod 상태를 etcd에 저장합니다.','kubectl이 app=web인 Pod 목록을 API Server에 요청합니다.','kubectl이 API Server의 응답을 목록으로 표시합니다.','kubectl이 Pod 목록을 조회하고 출력할 필드를 선택합니다.','kubectl이 status.phase를 PHASE 열로 표시합니다.','kubectl이 특정 Pod의 상세 정보와 관련 이벤트를 조회합니다.','kubectl이 상태와 이벤트를 표시해 준비되지 않은 원인을 보여 줍니다.']
assert len(creation_en)==len(creation_ko)==23
paths=[USER,CTRL[::-1],CTRL,CTRL[::-1],CTRL,SCHED[::-1],SCHED,g.REPORT[::-1],g.KR,g.RP,USER,g.REPORT[::-1],g.KR,g.RP,g.REPORT,g.STORE,CTRL[::-1],CTRL,SCHED[::-1],SCHED,g.REPORT[::-1],g.KR,g.RP]
def base(n):
 title=('Pod 생성과 실행, 복제본 유지','Pod Creation, Execution, and Replica Maintenance') if n==3 else ('Pod 상태 보고와 kubectl 조회','Pod Status Reporting and kubectl Queries')
 im,d=g.base(title[0] if not EN else title[1],'','',api_ready='False')
 # Increase the canvas to keep the status table readable in both languages.
 full=Image.new('RGB',(1200,1420),'white');full.paste(im,(0,0));d=ImageDraw.Draw(full)
 d.rectangle((0,60,1200,122),fill='white');g.rect(d,(365,60,555,110),'#edf3ff');text(d,(365,60,555,110),'사용자 / kubectl','User / kubectl',22)
 g.outline(d,USER)
 # Hide the prior probe legend and caption; this figure uses count/output panels.
 d.rectangle((0,1018,1200,1420),fill='white')
 return full,d

def render3(i,t):
 im,d=base(3)
 # Abstract Pod specifications remain in the API; only running containers appear on the Node.
 apicount=0 if i<4 else (2 if i in [15,16] else 3)
 running=0 if i<9 else (2 if 13<=i<22 else 3)
 g.rect(d,(375,453,545,590),'#deebff','#deebff')
 text(d,(380,466,540,508),'Pod 객체','Pod objects',21)
 text(d,(380,515,540,566),str(apicount),str(apicount),30,g.BLUE)
 g.rect(d,g.P)
 text(d,(730,670,1110,716),'실행 중인 Pod','Running Pods',24)
 for slot in range(3):
  y=733+slot*69
  present=slot<running
  g.rect(d,(740,y,1100,y+54),'#eef9f2' if present else '#f2f4f6')
  name=('Pod D' if slot==2 and i>=17 else 'Pod '+['A','B','C'][slot]) if present else '—'
  text(d,(795,y,1095,y+54),name,name,24,g.GREEN if present else g.GRAY)
  if present:im.paste(g.icons['pod'],(750,y+7),g.icons['pod'])
 color=g.ORANGE if 10<=i<=16 else (g.BLUE if i in [0,7,20] else g.GREEN)
 g.arrow(d,paths[i],color,t)
 # Current API objects and actual running Pods are displayed in separate rows.
 for row,(label,en,count,col) in enumerate([('API의 Pod 객체','Pod objects in API',apicount,g.BLUE),('Node에서 실행 중인 Pod','Pods running on Nodes',running,g.GREEN)]):
  y=1030+row*93;g.rect(d,(40,y,1160,y+78),'#f4f7fb')
  text(d,(50,y+5,495,y+73),label+': '+str(count),en+': '+str(count),24,col)
  for j in range(3):
   x=530+j*205;g.rect(d,(x,y+13,x+185,y+65),'#e5f1fb' if j<count else '#edf0f3')
   name='Pod D' if j==2 and i>=17 else 'Pod '+['A','B','C'][j]
   if row==0 and j==2 and 10<=i<=14:name='Pod C / 삭제 중' if not EN else 'Pod C / Deleting'
   text(d,(x,y+13,x+185,y+65),name if j<count else '—',name if j<count else '—',19,col)
 text(d,(45,1222,1155,1292),f'{i+1}. '+creation_ko[i],creation_en[i],23,color)
 for j in range(23):g.rect(d,(45+j*48,1320,82+j*48,1327),color if i==j else '#dce3ea',color if i==j else '#dce3ea',1)
 text(d,(30,1350,1170,1400),'Fig 3. Pod 객체와 컨테이너 실행의 구분','Fig 3. Pod objects, container execution, and replica maintenance',23)
 return im

def render4(i,t):
 im,d=base(4)
 # Show the running but unready Pod being queried.
 g.rect(d,g.P)
 text(d,(730,668,1110,710),'Pod / web','Pod / web',25)
 for j,(ko,en) in enumerate([('컨테이너: Running','Container: Running'),('Ready: False','Ready: False'),('readinessProbe: HTTP 503','readinessProbe: HTTP 503')]):
  y=730+j*64;g.rect(d,(740,y,1100,y+48),'#f5f7fa');text(d,(740,y,1100,y+48),ko,en,22)
 im.paste(g.icons['pod'],(1062,670),g.icons['pod'])
 route=[g.REPORT,g.STORE,USER,USER[::-1],USER,USER[::-1],USER,USER[::-1]][i]
 color=g.GREEN if i<2 else g.BLUE if i<4 else '#8248cb' if i<6 else g.ORANGE
 g.arrow(d,route,color,t)
 if i<2:lines=['Pod: web-7c8d9f6b5d-d3e4f','Container state: Running     Ready: False','Readiness check: HTTP 503']
 elif i<4:
  lines=['$ kubectl get pods -l app=web -o wide']
  lines+=['NAME                    READY  STATUS   RESTARTS  IP           NODE','web-7c8d9f6b5d-a1b2c     1/1    Running  0         10.244.1.8   worker-1','web-7c8d9f6b5d-d3e4f     0/1    Running  0         10.244.2.9   worker-2','web-7c8d9f6b5d-g5h6j     0/1    Pending  0         <none>       <none>'] if i==3 else ['Requesting Pod list...']
 elif i<6:
  lines=["$ kubectl get pods -l app=web -o custom-columns='NAME:.metadata.name,PHASE:.status.phase'"]
  lines+=['NAME                    PHASE','web-7c8d9f6b5d-a1b2c     Running','web-7c8d9f6b5d-d3e4f     Running','web-7c8d9f6b5d-g5h6j     Pending'] if i==5 else ['Requesting Pod list...']
 else:
  lines=['$ kubectl describe pod web-7c8d9f6b5d-d3e4f']
  lines+=['State: Running    Ready: False    Restart Count: 0','Conditions: Ready: False    ContainersReady: False','Events: Warning  Unhealthy  kubelet','Readiness probe failed: HTTP probe failed with statuscode: 503'] if i==7 else ['Requesting Pod details and events...']
 g.rect(d,(40,1030,1160,1210),'#f3f6fb')
 mono=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',18)
 for j,line in enumerate(lines):
  assert d.textlength(line,font=mono)<1080
  d.text((60,1045+j*31),line,font=mono,fill=g.INK)
 text(d,(45,1222,1155,1292),f'{i+1}. '+status_ko[i],status_en[i],23,color)
 for j in range(8):g.rect(d,(45+j*140,1320,172+j*140,1327),color if i==j else '#dce3ea',color if i==j else '#dce3ea',1)
 text(d,(30,1350,1170,1400),'Fig 4. 상태 보고와 목록 및 상세 조회','Fig 4. Status reporting, list queries, and detailed inspection',23)
 return im
if __name__=='__main__':
 g.save('12-pod-creation-and-replicas.gif',render3,23)
 g.save('14-pod-status-query.gif',render4,8)
