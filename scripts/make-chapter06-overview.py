"""Generate the chapter 6 introductory topology with embedded official icons."""
from pathlib import Path
import base64
from html import escape
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'images/articles/06/01-service-ingress-overview.svg'
s = ['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1100" viewBox="0 0 1440 1100">', '<defs>']
for name, color in [('control', '#64748b'), ('traffic', '#e07819')]:
    s.append(f'<marker id="{name}" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0L8 4L0 8Z" fill="{color}"/></marker>')
s += ['</defs><rect width="1440" height="1100" fill="white"/>', '<g font-family="Apple SD Gothic Neo,Noto Sans KR,sans-serif" fill="#20334d">']
def box(x,y,w,h,fill='#fff'):
    s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{fill}" stroke="#b7c8da" stroke-width="2"/>')
def text(x,y,t,size=21):
    s.append(f'<text x="{x}" y="{y}" text-anchor="middle" font-size="{size}">{escape(t)}</text>')
def icon(name,x,y):
    path = 'images/k8s-icon-color.png' if name=='k8s' else f'images/characters/refs/{name}.png'
    data = base64.b64encode((ROOT/path).read_bytes()).decode()
    s.append(f'<image x="{x}" y="{y}" width="38" height="38" href="data:image/png;base64,{data}"/>')
def arrow(d,kind='control'):
    color = '#64748b' if kind=='control' else '#e07819'
    s.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="3" marker-end="url(#{kind})"/>')
def doc(x,w,title,sub,mark=None):
    y=160
    s.append(f'<path d="M{x} {y}H{x+w-20}L{x+w} {y+20}V{y+112}H{x}Z" fill="#fff8e8" stroke="#cbb988" stroke-width="2"/>')
    if mark: icon(mark,x+10,y+10)
    text(x+w/2+(15 if mark else 0),y+40,title,20)
    text(x+w/2,y+82,sub,17)
box(220,20,1195,985,'#f7faff'); icon('k8s',240,35);text(840,65,'Kubernetes Cluster',26)
box(245,95,1145,385,'#edf2ff'); icon('node-official',260,107);text(530,137,'Control Plane Node / Master Node',24)
text(1080,137,'API 리소스 / 실행 프로세스가 아닌 선언과 상태',18)
doc(270,245,'Service','접근 주소와 대상 조건','svc')
doc(535,245,'Ingress','도메인과 경로 규칙','ing')
doc(800,265,'EndpointSlice','Pod IP / 포트 / 준비 상태')
doc(1085,280,'Deployment / Pod','복제본 선언 / Pod 상태')
box(270,325,450,120,'#fff');text(495,357,'kube-controller-manager',22)
box(288,373,414,55,'#e8efff');text(495,408,'EndpointSlice Controller',22)
box(980,325,385,120);text(1172,374,'API Server',26);text(1172,410,'리소스 조회와 변경의 창구',19)
s.append('<path d="M392 272V290H1225V272 M657 272V290 M932 272V290" fill="none" stroke="#64748b" stroke-width="2"/>')
arrow('M1172 325V290');text(1280,313,'조회 / 기록',17)
arrow('M980 357H735');text(840,343,'Service와 Pod 관찰',17)
arrow('M720 410H965');text(845,440,'EndpointSlice 갱신',17)
# API watches reach node processes without running through traffic paths.

box(245,545,410,405,'#eef7f0');icon('node-official',260,560);text(455,592,'Worker Node A',24)
box(270,625,360,155);icon('pod-official',281,640);text(465,662,'Ingress Controller Pod',21)
text(450,709,'Ingress 규칙을 반영하는 프로세스',18)
text(450,747,'HTTP 요청을 전달하는 프록시',19)
text(450,839,'별도로 설치한 Controller',20)
text(450,874,'프록시를 함께 실행하는 구성 예시',18)
box(925,545,465,405,'#eef7f0');icon('node-official',940,560);text(1120,592,'Worker Node B',24)
box(950,620,415,100);text(1157,658,'kube-proxy',23);text(1157,692,'Node의 Service 전달 규칙 설정',18)

box(950,805,415,115);icon('pod-official',964,825);text(1170,848,'애플리케이션 Pod',23);text(1157,886,'Deployment가 유지하는 복제본',19)
arrow('M1090 445V510H680V690H630');text(804,501,'Ingress / Service / EndpointSlice 관찰',17)
arrow('M1260 445V620');text(1150,537,'Service / EndpointSlice 관찰',17)
box(20,630,175,100);text(108,670,'외부 클라이언트',19);text(108,705,'HTTP / HTTPS',17)
arrow('M195 680H270','traffic')
arrow('M630 740H795V862H950','traffic')
text(790,715,'HTTP 요청 전달',20)
text(793,906,'Service가 가리키는 Pod',18)
text(790,932,'Pod IP로 직접 전달하는 예시',16)
text(815,984,'외부 진입점의 세부 경로와 다른 Node의 동일 프로세스는 생략',17)
arrow('M300 1030H370');text(538,1037,'API 관찰과 설정 반영',20)
arrow('M790 1030H860','traffic');text(1040,1037,'애플리케이션 요청',20)
text(720,1080,'Fig 1. Service와 Ingress의 전체 구성: API 리소스와 실행 주체',23)
s.append('</g></svg>')
OUT.write_text('\n'.join(s))
