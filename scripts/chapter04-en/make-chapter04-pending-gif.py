#!/usr/bin/env python3
"""Generate Fig 8: insufficient CPU or memory keeps a Pod Pending before Node assignment."""
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location('drawing', Path(__file__).with_name('make-chapter04-node-recovery-gif.py'))
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)
OUTPUT = Path('images/articles/04/en/18-pod-pending.gif')
STAGES = [
    'Worker Node 1\'s Kubelet reports Node resources and status to the API Server.',
    'Worker Node 2\'s Kubelet also reports Node resources and status to the API Server.',
    'The Scheduler reads unassigned Pods and Node information from the API Server.',
    'The Scheduler compares the Pod\'s 4 GiB request with each Node\'s remaining memory.',
    'The Scheduler finds no suitable Node and records a scheduling failure through the API.',
    'Without a Node assignment, no Kubelet starts the new Pod, so it remains Pending.',
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
    text(640,48,'Kubernetes cluster','node')
    box((35,85,595,765),g.CONTROL_BG)
    icon('node',50,102);text(310,120,'Control Plane Node','node')
    box((65,175,555,335))
    icon('pod',82,188);text(325,212,'New Pod / Memory request: 4 GiB','box',g.BLUE)
    for j in range(4):
        box((158+j*78,240,221+j*78,283),g.LIGHT_BLUE)
        text(189+j*78,261,'1GiB','small')
    text(310,309,'Waiting for a Node assignment','body',g.ORANGE)
    box((380,375,555,710),g.LIGHT_BLUE)
    text(467,488,'API Server','box')
    text(467,525,'Node information','body')
    text(467,555,'Pod spec and status','body')
    box((65,470,255,625),g.LIGHT_BLUE if stage>=2 else 'white')
    text(160,515,'Scheduler','box')
    text(160,555,'Compare free capacity','body')
    text(160,590,'Assignment failed' if stage>=4 else 'Select a Node','body',g.RED if stage>=4 else g.INK)
    for i,top,remaining in [(1,85,1),(2,435,2)]:
        box((805,top,1245,top+330),g.FAILED_BG if stage>=3 else g.WORKER_BG)
        icon('node',820,top+16);text(1040,top+39,f'Worker Node {i}','node')
        box((845,top+90,1205,top+160),g.LIGHT_GREEN)
        text(1025,top+125,'Kubelet','box')
        text(1025,top+202,f'Remaining memory: {remaining}GiB','box',g.RED if stage>=3 else g.GREEN)
        for j in range(4):
            box((878+j*76,top+232,940+j*76,top+272),g.LIGHT_GREEN if j<remaining else g.LIGHT_GRAY)
            text(909+j*76,top+252,'1GiB' if j<remaining else 'Short','small',g.GREEN if j<remaining else g.MUTED)
        text(1025,top+302,'No new Pod assigned','body',g.ORANGE)
    # Arrows show Kubelet reports and Scheduler API reads/writes, never direct scheduling to Kubelet.
    paths=[[(845,210),(700,210),(700,410),(555,410)],
           [(845,560),(555,560)],
           [(255,500),(380,500)],
           [(380,590),(255,590)],
           [(255,500),(380,500)]]
    for index,points in enumerate(paths[:4]):
        for a,b in zip(points,points[1:]): d.line((a,b),fill=g.BORDER,width=2)
        g.arrow(d,points[-2],points[-1],g.BORDER,2)
    text(683,438,'Report resources and status','small')
    text(684,538,'Report resources and status','small')
    text(317,478,'Record failure' if stage>=4 else 'Read requests','small')
    text(317,615,'Return information','small')
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
    text(640,918,'Fig 8. Kubelet status reports and failed scheduling due to insufficient memory','caption')
    return im


def main():
    frames=[]
    for stage in range(len(STAGES)):
        for i in range(24): frames.append(frame(stage,min(i/12,1)))
        frames[-1].save(f'/tmp/ch04-en-pending-stage-{stage+1}.png')
    frames[0].save(OUTPUT,save_all=True,append_images=frames[1:],duration=100,loop=0,disposal=2,optimize=True)
    print(f'Wrote {OUTPUT}')

if __name__=='__main__': main()
