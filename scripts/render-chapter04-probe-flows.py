"""Render Korean chapter 4 probe diagrams. Run with /usr/bin/python3 (Pillow)."""
from pathlib import Path
import math
import json
import re
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'images/articles/04'
FONT = '/System/Library/Fonts/AppleSDGothicNeo.ttc'
W,H=1200,1210
INK='#213650'; BLUE='#2563eb'; PURPLE='#8248cb'; GREEN='#087f65'; ORANGE='#bf510b'; GRAY='#8392a5'
LANG="ko"
TRANSLATIONS=json.loads((ROOT / "scripts/publication/probe-labels.en.json").read_text())
fonts={}
def font(size):
    if size not in fonts: fonts[size]=ImageFont.truetype(FONT,size)
    return fonts[size]
def text(d,box,value,size=23,color=INK):
    if LANG=='en':
        if re.search('[가-힣]',value):
            assert value in TRANSLATIONS, value
            value=TRANSLATIONS[value]
    x,y,r,b=box
    if LANG=='en':
        while font(size).getlength(value)>r-x-12 and size>14:
            size-=1
    bounds=d.textbbox((0,0),value,font=font(size))
    assert bounds[2]-bounds[0] <= r-x-12, (value,box)
    assert bounds[3]-bounds[1] <= b-y, (value,box)
    d.text(((x+r)/2,(y+b)/2),value,font=font(size),fill=color,anchor='mm')
def rect(d,box,fill='#ffffff',stroke='#b6c7db',width=2):
    d.rounded_rectangle(box,radius=14,fill=fill,outline=stroke,width=width)
def arrow(d,points,color,phase=None):
    d.line(points,fill=color,width=4,joint='curve')
    (x0,y0),(x,y)=points[-2:]; a=math.atan2(y-y0,x-x0)
    d.polygon([(x,y),(x-14*math.cos(a-.45),y-14*math.sin(a-.45)),(x-14*math.cos(a+.45),y-14*math.sin(a+.45))],fill=color)
    if phase is not None:
        lengths=[math.dist(a,b) for a,b in zip(points,points[1:])]; length=sum(lengths)*phase
        for a,b,l in zip(points,points[1:],lengths):
            if length<=l:
                t=length/l; x=a[0]+(b[0]-a[0])*t; y=a[1]+(b[1]-a[1])*t
                d.ellipse((x-7,y-7,x+7,y+7),fill=color,outline='white',width=2); break
            length-=l
icons={}
for n in ['node','pod']:
    im=Image.open(ROOT/f'images/characters/refs/{n}-official.png').convert('RGBA'); im.thumbnail((40,40)); icons[n]=im
# The original Fig 5 topology: Control Plane on the left, Worker Node on the right.
K=(720,270,1120,420); R=(720,495,1120,575); P=(720,660,1120,960)
API=(365,270,555,610)
HTTP=[(720,345),(650,345),(650,810),(720,810)]
KR=[(920,420),(920,495)]
RP=[(920,575),(920,660)]
REPORT=[(920,270),(920,235),(615,235),(615,440),(555,440)]
STORE=[(460,610),(460,685)]
def outline(d,points): d.line(points,fill='#bdc9d6',width=2,joint='curve')
def base(title,caption,tab,api_ready='True'):
    im=Image.new('RGB',(W,H),'white'); d=ImageDraw.Draw(im)
    text(d,(30,10,1170,57),title,29)
    rect(d,(330,65,870,108),'#eef3fc'); text(d,(330,65,870,108),tab,23,BLUE)
    rect(d,(20,125,1180,1015),'#ffffff')
    text(d,(40,135,310,178),'Kubernetes 클러스터',25)
    rect(d,(40,185,580,990),'#f0f5ff')
    rect(d,(600,185,1160,990),'#f1f9f5')
    text(d,(60,192,455,238),'Control Plane Node',26)
    text(d,(625,192,1000,230),'Worker Node',26)
    for x in (525,1105): im.paste(icons['node'],(x,194),icons['node'])
    # Controller and Scheduler share the API, without implying direct runtime control.
    rect(d,(65,270,305,610))
    for box,value,size in [((70,279,300,321),'컨트롤러 매니저',24),((70,348,300,382),'Deployment Controller',18),((70,385,300,421),'ReplicaSet 관리',21),((70,454,300,488),'ReplicaSet Controller',19),((70,491,300,527),'Pod 개수 유지',21),((70,555,300,590),'그 밖의 기본 컨트롤러',18)]: text(d,box,value,size)
    rect(d,API,'#deebff')
    for box,value,size in [((370,287,550,333),'API Server',25),((375,355,545,390),'선언과 배정 정보',20),((375,415,545,451),'Pod 상태',22),((375,473,545,509),'컨테이너 상태',18),((375,526,545,562),'Ready: '+api_ready,19)]: text(d,box,value,size)
    rect(d,(65,685,305,795)); text(d,(70,693,300,738),'Scheduler',25); text(d,(70,744,300,785),'Pod의 Node 배정',22)
    rect(d,(365,685,555,795)); text(d,(370,693,550,738),'etcd',26); text(d,(375,744,545,785),'선언과 상태 저장',20)
    outline(d,[(305,440),(365,440)])
    outline(d,[(305,740),(335,740),(335,440),(365,440)])
    outline(d,STORE); outline(d,REPORT)
    text(d,(365,622,450,660),'상태 저장',16,GRAY)
    text(d,(48,849,570,894),'클러스터의 선언과 상태 관리',23)
    text(d,(48,900,570,940),'정보 공유: API Server',22)
    rect(d,K,'#dcefe5'); text(d,(730,279,1110,325),'Kubelet',28)
    text(d,(730,334,1110,368),'컨테이너 상태 확인과 프로브 검사',23)
    text(d,(730,373,1110,411),'상태 보고 / 실행과 종료 요청',22)
    rect(d,R,'#edf3ff'); text(d,(730,498,1110,537),'컨테이너 런타임',25)
    text(d,(730,539,1110,571),'컨테이너 실행과 종료',21)
    rect(d,P); im.paste(icons['pod'],(1064,672),icons['pod'])
    text(d,(740,669,1040,711),'Pod / web',25)
    outline(d,KR); outline(d,RP); outline(d,HTTP)
    # Two visual keys aligned below the cluster; no explanatory footer paragraph.
    arrow(d,[(65,1043),(145,1043)],BLUE)
    text(d,(157,1023,570,1063),'Kubelet의 런타임 상태 확인',22,BLUE)
    arrow(d,[(625,1043),(705,1043)],PURPLE)
    text(d,(715,1023,1150,1063),'Kubelet의 Pod HTTP 검사',22,PURPLE)
    text(d,(35,1161,1165,1203),caption,22)
    return im,d

def render5(stage,t):
    titles=['런타임 실행 상태 조회','런타임 실행 상태 응답','Pod HTTP 검사 요청','Pod HTTP 검사 응답','Kubelet의 상태 보고','API의 상태 저장']
    im,d=base('Kubelet의 상태 검사와 API 상태 보고','Fig 5. 실행 상태 확인, HTTP 검사와 상태 보고',titles[stage])
    for box,value in [((740,724,1100,769),'애플리케이션 컨테이너'),((740,784,1100,829),'실행 상태: Running'),((740,844,1100,889),'HTTP 검사 응답: 200'),((740,904,1100,945),'요청 준비: True')]:
        rect(d,box,'#f7f9fd'); text(d,box,value,22)
    routes=[KR,KR[::-1],HTTP,HTTP[::-1],REPORT,STORE]
    color=BLUE if stage<2 else (PURPLE if stage<4 else GREEN)
    arrow(d,routes[stage],color,t)
    if stage<2: text(d,(725,429,902,474),'실행 상태 조회' if stage==0 else '실행 상태 응답',21,BLUE)
    elif stage<4: text(d,(940,593,1135,639),'HTTP 요청' if stage==2 else 'HTTP 응답',22,PURPLE)
    elif stage==4: text(d,(395,805,560,846),'상태 보고',21,GREEN)
    elif stage==5: text(d,(365,622,450,660),'상태 저장',16,GREEN)
    text(d,(60,1083,1140,1128),'컨테이너: Running     |     HTTP: 200     |     Ready: True',24)
    return im
# startup, readiness, liveness, runtime state, Ready, restart count, route, tab
states=[
 ('503 / 초기화 중','검사 대기','검사 대기','실행 중','False',0,'http','초기화 중'),
 ('200 / 기동 완료','검사 시작','검사 시작','실행 중','False',0,'http','기동 완료'),
 ('완료','200 / 준비 완료','200 / 정상','실행 중','True',0,'http','요청 처리 중'),
 ('완료','503 / 실패 1회','200 / 정상','실행 중','True',0,'http','일시적인 준비 실패'),
 ('완료','503 / 실패 2회','200 / 정상','실행 중','True',0,'http','일시적인 준비 실패'),
 ('완료','503 / 실패 3회','200 / 정상','실행 중','False',0,'http','요청 대상 제외'),
 ('완료','200 / 준비 회복','200 / 정상','실행 중','True',0,'http','요청 대상으로 복귀'),
 ('완료','응답 없음 / 실패 1회','응답 없음 / 실패 1회','실행 중','True',0,'http','애플리케이션 응답 불능'),
 ('완료','응답 없음 / 실패 2회','응답 없음 / 실패 2회','실행 중','True',0,'http','애플리케이션 응답 불능'),
 ('완료','응답 없음 / 실패 3회','응답 없음 / 실패 3회','실행 중','False',0,'http','생존 검사 실패 기준 도달'),
 ('검사 대기','검사 대기','검사 대기','종료 중','False',0,'kr','컨테이너 재시작 요청'),
 ('검사 대기','검사 대기','검사 대기','새 컨테이너 실행','False',1,'rp','같은 Pod 안의 컨테이너 재시작'),
 ('503 / 초기화 중','검사 대기','검사 대기','실행 중','False',1,'http','시작 검사 재개'),
 ('200 / 기동 완료','검사 시작','검사 시작','실행 중','False',1,'http','기동 완료'),
 ('완료','200 / 준비 완료','200 / 정상','실행 중','True',1,'http','요청 처리 재개'),
]
def render6(i,t):
    startup,ready,live,run,condition,restarts,route,tab=states[i]
    previous=states[max(i-1,0)][4]
    reporting=route=='http' and condition!=previous and i>=2 and t>=.8
    api_ready=condition if t>=.8 or condition==previous else previous
    im,d=base('프로브에 따른 준비 상태 변화와 컨테이너 재시작','Fig 6. 기동 확인, 요청 준비 상태와 컨테이너 재시작',tab,api_ready)
    for j,(key,path,status) in enumerate([('startupProbe','/startup',startup),('readinessProbe','/ready',ready),('livenessProbe','/healthz',live)]):
        y=720+j*66; box=(740,y,1100,y+60)
        color=GRAY if status in ('검사 대기','완료','검사 시작') else (ORANGE if ('503' in status or '응답 없음' in status) else GREEN)
        rect(d,box,'#fafbfd',color)
        text(d,(745,y,1095,y+29),key+' '+path,20,PURPLE)
        text(d,(745,y+29,1095,y+59),status,20,color)
    if reporting:
        arrow(d,REPORT,GREEN,(t-.8)/.2)
        text(d,(940,593,1135,639),'준비 상태 보고',21,GREEN)
    elif route=='http':
        timeout='응답 없음' in live
        reverse=t>=.4 and not timeout
        if timeout and t>=.4: outline(d,HTTP)
        else: arrow(d,HTTP[::-1] if reverse else HTTP,PURPLE,(t%.4)/.4)
        label='응답 대기 시간 초과' if timeout and t>=.4 else ('HTTP 검사 응답' if reverse else 'HTTP 검사 요청')
        text(d,(940,593,1135,639),label,20,ORANGE if timeout else PURPLE)
    elif route=='kr':
        arrow(d,KR,ORANGE,t); text(d,(725,429,903,476),'종료 / 재실행',21,ORANGE)
    else:
        arrow(d,RP,ORANGE,t); text(d,(730,593,902,639),'컨테이너 실행',21,ORANGE)
    text(d,(745,923,1095,956),'컨테이너 재시작 횟수: '+str(restarts),19)
    for box,label in [((45,1080,455,1135),'컨테이너: '+run),((470,1080,755,1135),'Ready: '+condition),((770,1080,1155,1135),'새 요청 대상: '+('포함' if condition=='True' else '제외'))]:
        rect(d,box,'#f1f5fb'); text(d,box,label,23)
    return im

def save(name,render,n,frames_per=12):
    frames=[]; previews=[]
    for i in range(n):
        for k in range(frames_per):
            im=render(i,(k+.5)/frames_per); frames.append(im)
        previews.append(render(i,.7))
    frames[0].save(OUT/name,save_all=True,append_images=frames[1:],duration=250,loop=0,disposal=2,optimize=False)
    check=Image.open(OUT/name)
    duration=0
    for i in range(check.n_frames):
        check.seek(i); check.load(); duration+=check.info["duration"]
    assert duration==len(frames)*250  # GIF merges identical hold frames.
    sheet=Image.new('RGB',(600*3,605*math.ceil(n/3)),'white')
    for i,im in enumerate(previews): sheet.paste(im.resize((600,605)),((i%3)*600,(i//3)*605))
    sheet.save('/tmp/'+name+'.contact.png'); previews[0].save('/tmp/'+name+'.first.png')
    print(name,check.n_frames,'frames',len(frames)*.25,'seconds',flush=True)
if __name__=='__main__':
    import sys
    if '--en' in sys.argv:
        LANG='en'; OUT=OUT/'en'; OUT.mkdir(exist_ok=True)
    save('15-state-check-paths.gif',render5,6)
    save('16-probe-state-changes.gif',render6,len(states))
