"""Chapter 3 Fig 4: placement, execution, and sharing within one Pod."""
from pathlib import Path
from html import escape
import base64
ROOT=Path(__file__).resolve().parents[1]
s=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="900" viewBox="0 0 1200 900"><defs><marker id="a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0L8 4L0 8Z" fill="#2563eb"/></marker></defs><rect width="1200" height="900" fill="#f7f9fc"/><g font-family="Apple SD Gothic Neo,Noto Sans KR,sans-serif" fill="#20334d">']
def box(x,y,w,h,fill='#fff'):
 s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{fill}" stroke="#a7bacd" stroke-width="2"/>')
def t(x,y,text,size=20):
 s.append(f'<text x="{x}" y="{y}" text-anchor="middle" font-size="{size}">{escape(text)}</text>')
def icon(key,x,y):
 data=base64.b64encode((ROOT/f'images/characters/refs/{key}-official.png').read_bytes()).decode()
 s.append(f'<image x="{x}" y="{y}" width="38" height="38" href="data:image/png;base64,{data}"/>')
def a(d):s.append(f'<path d="{d}" fill="none" stroke="#2563eb" stroke-width="3" marker-end="url(#a)"/>')
box(25,30,360,770,'#eef2ff');icon('node',42,43);t(218,73,'Control Plane Node',24)
box(55,130,300,110);t(205,170,'Scheduler',24);t(205,207,'Pod를 실행할 Node 선택',19)
box(55,380,300,120);t(205,426,'API Server',24);t(205,465,'Pod 선언과 Node 배정 정보',18)
a('M125 380V240');t(78,310,'Pod 조회',16)
a('M285 240V380');t(332,295,'배정 결과',16);t(332,320,'기록',16)
t(205,607,'Scheduler는 Node를 선택하고',18);t(205,640,'컨테이너 실행은 Node가 담당',18)
box(495,30,680,770,'#eef7f0');icon('node',512,43);t(837,73,'Worker Node',24)
box(525,130,275,110);t(662,171,'Kubelet',24);t(662,205,'배정된 Pod의 실행 관리',18)
box(875,130,275,110);t(1012,171,'컨테이너 런타임',23);t(1012,205,'컨테이너 프로세스 실행',17)
a('M355 440H435V185H525');t(439,486,'Pod 배정',17);t(439,510,'정보 확인',17)
a('M800 185H875');t(837,119,'실행 요청',16)
a('M1012 240V340');t(1083,302,'실행',17)
box(525,340,625,400,'#eff6ff');icon('pod',542,353);t(855,383,'Pod / 함께 배치되는 최소 실행 단위',22)
box(550,420,230,90);t(665,457,'Container A',22);t(665,488,'애플리케이션 프로세스',17)
box(895,420,230,90);t(1010,457,'Container B',22);t(1010,488,'함께 동작하는 프로세스',17)
a('M780 465H895');t(838,443,'localhost',16)
box(550,550,575,65,'#ecfdf5');t(837,578,'공유 네트워크',21);t(837,603,'하나의 Pod IP와 포트 공간',17)
box(550,640,575,65,'#ecfdf5');t(837,668,'공유 볼륨',21);t(837,693,'각 컨테이너가 같은 저장 공간을 자기 경로에 연결',17)
t(837,776,'컨테이너 하나만 종료되면 해당 컨테이너만 재시작 가능',17)
t(600,842,'Pod 배치와 실행에 필요한 구성요소만 표시 / Pod 안의 모든 컨테이너는 같은 Node에서 실행',18)
t(600,884,'Fig 4. Pod: Node 배정과 컨테이너 실행, 공유 환경',23)
s.append('</g></svg>')
(ROOT/'images/articles/03/12-pod-scheduling-and-sharing.svg').write_text('\n'.join(s))
