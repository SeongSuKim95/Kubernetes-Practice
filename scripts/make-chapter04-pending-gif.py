#!/usr/bin/env python3
"""Generate Fig 8: insufficient CPU or memory keeps a Pod Pending before Node assignment."""
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location('drawing', Path(__file__).with_name('make-chapter04-node-recovery-gif.py'))
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)
OUTPUT = Path('images/articles/04/18-pod-pending.gif')
STAGES = [
    'Worker Node 1의 Kubelet이 Node의 자원과 상태를 API Server에 보고합니다.',
    'Worker Node 2의 Kubelet도 Node의 자원과 상태를 API Server에 보고합니다.',
    'Scheduler가 API Server에서 미배정 Pod와 Node 정보를 조회합니다.',
    'Scheduler가 새 Pod에 필요한 4GiB와 각 Node의 남은 메모리를 비교합니다.',
    'Scheduler가 조건에 맞는 Node를 찾지 못해 배정 실패를 API에 기록합니다.',
    'Node 배정이 없어 Kubelet은 새 Pod를 실행하지 못하고 Pod는 Pending에 머무릅니다.',
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
    text(310,309,'실행할 Node를 기다리는 중','body',g.ORANGE)
    box((380,375,555,710),g.LIGHT_BLUE)
    text(467,488,'API Server','box')
    text(467,525,'Node 정보','body')
    text(467,555,'Pod 선언과 상태','body')
    box((65,470,255,625),g.LIGHT_BLUE if stage>=2 else 'white')
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
    paths=[[(845,210),(700,210),(700,410),(555,410)],
           [(845,560),(555,560)],
           [(255,500),(380,500)],
           [(380,590),(255,590)],
           [(255,500),(380,500)]]
    for index,points in enumerate(paths[:4]):
        for a,b in zip(points,points[1:]): d.line((a,b),fill=g.BORDER,width=2)
        g.arrow(d,points[-2],points[-1],g.BORDER,2)
    text(683,438,'자원과 상태 보고','small')
    text(684,538,'자원과 상태 보고','small')
    text(317,478,'실패 기록' if stage>=4 else '조회 요청','small')
    text(317,615,'정보 응답','small')
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
    text(640,918,'Fig 8. Kubelet의 상태 보고와 Scheduler의 메모리 비교 및 배정 실패','caption')
    return im


def main():
    frames=[]
    for stage in range(len(STAGES)):
        for i in range(24): frames.append(frame(stage,min(i/12,1)))
        frames[-1].save(f'/tmp/ch04-pending-stage-{stage+1}.png')
    frames[0].save(OUTPUT,save_all=True,append_images=frames[1:],duration=100,loop=0,disposal=2,optimize=True)
    print(f'Wrote {OUTPUT}')

if __name__=='__main__': main()
