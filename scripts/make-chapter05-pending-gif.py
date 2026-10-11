#!/usr/bin/env python3
"""Generate Fig 3 for chapter 5: insufficient memory keeps a Pod Pending before Node assignment."""
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location('drawing', Path(__file__).with_name('make-chapter05-node-recovery-gif.py'))
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)
OUTPUT = Path('images/articles/05/02-pod-pending.gif')
STAGES = [
    'Worker Node 1 Kubelet의 자원과 상태 보고',
    'Worker Node 2 Kubelet의 자원과 상태 보고',
    'Scheduler의 미배정 Pod와 Node 정보 조회',
    'Pod 요청량 4GiB와 각 Node의 배정 가능 메모리 비교',
    'Scheduler의 메모리 부족 판정과 배정 실패 기록',
    'Node 미배정과 Pod의 Pending 유지',
]
ICONS = {}
for kind in ['node', 'pod']:
    im = Image.open(f'images/characters/refs/{kind}-official.png').convert('RGBA')
    im.thumbnail((36,36)); ICONS[kind] = im


def frame(stage, progress):
    im=Image.new('RGB',(1280,940),'white'); d=ImageDraw.Draw(im)
    def text(x,y,s,style='body',color=g.INK): g.centered(d,(x,y),s,style,color)
    def box(xy,fill=g.BOX_BG,color=g.BORDER): g.box(d,xy,fill,color)
    def icon(kind,x,y): im.paste(ICONS[kind],(x,y),ICONS[kind])
    box((15,20,1265,790),'#fafcff')
    text(640,48,'Kubernetes 클러스터','node')
    box((35,85,595,765),g.CONTROL_BG)
    icon('node',50,102);text(310,120,'Control Plane Node','node')
    box((65,175,555,335))
    icon('pod',82,188);text(325,212,'새 Pod / 필요한 메모리 4GiB','box',g.BLUE)
    for j in range(4):
        box((158+j*78,240,221+j*78,283),g.LIGHT_BLUE)
        text(189+j*78,261,'1GiB','small')
    text(310,309,'Node 배정 대기','body',g.ORANGE)
    box((380,375,555,710),g.LIGHT_BLUE)
    text(467,488,'API Server','box')
    text(467,525,'Node 정보','body')
    text(467,555,'Pod 선언과 상태','body')
    box((65,465,255,620),g.LIGHT_BLUE if stage>=2 else 'white')
    text(160,515,'Scheduler','box')
    text(160,555,'남은 메모리 비교','body')
    text(160,590,'배정 실패' if stage>=4 else 'Node 선택','body',g.RED if stage>=4 else g.INK)
    for i,top,remaining in [(1,85,1),(2,435,2)]:
        box((805,top,1245,top+330),g.FAILED_BG if stage>=3 else g.WORKER_BG)
        icon('node',820,top+16);text(1040,top+39,f'Worker Node {i}','node')
        box((845,top+90,1205,top+160),g.LIGHT_GREEN)
        text(1025,top+125,'Kubelet','box')
        text(1025,top+202,f'남은 메모리 {remaining}GiB','box',g.RED if stage>=3 else g.GREEN)
        for j in range(4):
            box((878+j*76,top+232,940+j*76,top+272),g.LIGHT_GREEN if j<remaining else g.LIGHT_GRAY)
            text(909+j*76,top+252,'1GiB' if j<remaining else '부족','small',g.GREEN if j<remaining else g.MUTED)
        text(1025,top+302,'새 Pod 배정 없음','body',g.ORANGE)
    # Arrows show Kubelet reports and Scheduler API reads/writes, never direct scheduling to Kubelet.
    paths=[[(845,210),(700,210),(700,350),(467.5,350),(467.5,375)],
           [(845,560),(700,560),(700,542.5),(555,542.5)],
           [(255,542.5),(380,542.5)],
           [(380,542.5),(255,542.5)],
           [(255,542.5),(380,542.5)]]
    for index,points in enumerate(paths[:3]):
        for a,b in zip(points,points[1:]): d.line((a,b),fill=g.BORDER,width=2)
        g.arrow(d,points[-2],points[-1],g.BORDER,2)
    text(700,185,'자원과 상태 보고','small')
    text(700,595,'자원과 상태 보고','small')
    text(317,515,'실패 기록' if stage>=4 else '조회 요청','small')
    text(317,585,'정보 응답','small')
    if stage<5:
        points=paths[stage];color=g.RED if stage==4 else g.BLUE
        for a,b in zip(points,points[1:]): d.line((a,b),fill=color,width=5)
        g.arrow(d,points[-2],points[-1],color,5)
        lengths=[abs(a[0]-b[0])+abs(a[1]-b[1]) for a,b in zip(points,points[1:])]
        remaining=sum(lengths)*progress
        for a,b,length in zip(points,points[1:],lengths):
            if remaining<=length:
                g.moving_dot(d,a,b,remaining/length,color);break
            remaining-=length
    text(640,832,f'{stage+1}. {STAGES[stage]}','stage',g.BLUE)
    for i in range(len(STAGES)):
        x=45+i*200;g.box(d,(x,870,x+182,876),g.BLUE if i==stage else g.BORDER,None,0,3)
    text(640,918,'Fig 3. Kubelet의 상태 보고와 Scheduler의 메모리 비교 및 배정 실패','caption')
    return im


def main():
    frames=[]
    for stage in range(len(STAGES)):
        for i in range(24): frames.append(frame(stage,min(i/12,1)))
        frames[-1].save(f'/tmp/ch05-pending-stage-{stage+1}.png')
    frames[0].save(OUTPUT,save_all=True,append_images=frames[1:],duration=100,loop=0,disposal=2,optimize=True)
    print(f'Wrote {OUTPUT}')

if __name__=='__main__': main()
