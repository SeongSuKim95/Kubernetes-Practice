#!/usr/bin/env python3
"""Generate Fig 1 for chapter 5: container restart and Node failure recovery."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


WIDTH = 1120
HEIGHT = 1000
OUTPUT = Path("images/articles/05/01-node-failure-recovery.gif")
FONT_PATH = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

INK = "#263b53"
MUTED = "#526680"
BORDER = "#b7c8da"
CONTROL_BG = "#edf3ff"
WORKER_BG = "#edf8f1"
FAILED_BG = "#fff1f1"
BOX_BG = "#ffffff"
BLUE = "#2477e8"
GREEN = "#07967f"
RED = "#d94b4b"
ORANGE = "#e88920"
PURPLE = "#8b4ed8"
LIGHT_BLUE = "#dce9ff"
LIGHT_GREEN = "#dff4e7"
LIGHT_RED = "#ffe0e0"
LIGHT_GRAY = "#edf0f3"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_PATH, size, index=1 if bold else 0)


FONTS = {
    "node": font(24, True),
    "box": font(20, True),
    "body": font(17),
    "small": font(15),
    "stage": font(22, True),
    "caption": font(16),
    "metric": font(17, True),
}


def box(draw, xy, fill=BOX_BG, outline=BORDER, width=2, radius=12):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def centered(draw, xy, text, style="body", fill=INK):
    draw.text(xy, text, font=FONTS[style], fill=fill, anchor="mm")


def text_lines(draw, center_x, start_y, lines, gap=27, style="body", fill=INK):
    for index, line in enumerate(lines):
        centered(draw, (center_x, start_y + index * gap), line, style, fill)


def arrow(draw, start, end, color=MUTED, width=3, dashed=False):
    x1, y1 = start
    x2, y2 = end
    if dashed:
        segments = 14
        for i in range(0, segments, 2):
            t1 = i / segments
            t2 = min((i + 1) / segments, 1)
            draw.line(
                (
                    x1 + (x2 - x1) * t1,
                    y1 + (y2 - y1) * t1,
                    x1 + (x2 - x1) * t2,
                    y1 + (y2 - y1) * t2,
                ),
                fill=color,
                width=width,
            )
    else:
        draw.line((start, end), fill=color, width=width)

    dx = x2 - x1
    dy = y2 - y1
    length = max((dx * dx + dy * dy) ** 0.5, 1)
    ux, uy = dx / length, dy / length
    px, py = -uy, ux
    size = 11
    tip = (x2, y2)
    left = (x2 - ux * size + px * size * 0.55, y2 - uy * size + py * size * 0.55)
    right = (x2 - ux * size - px * size * 0.55, y2 - uy * size - py * size * 0.55)
    draw.polygon((tip, left, right), fill=color)


def moving_dot(draw, start, end, phase, color):
    x = start[0] + (end[0] - start[0]) * phase
    y = start[1] + (end[1] - start[1]) * phase
    draw.ellipse((x - 6, y - 6, x + 6, y + 6), fill=color)


def status_pill(draw, center, text, fill, color):
    x, y = center
    width = 118 if text == "NotReady" else 90
    box(draw, (x - width / 2, y - 17, x + width / 2, y + 17), fill, color, 2, 17)
    centered(draw, (x, y), text, "small", color)


def pod(draw, xy, name, detail, state, highlight=False):
    x1, y1, x2, y2 = xy
    fills = {
        "ready": LIGHT_GREEN,
        "restarting": "#fff2d8",
        "unknown": LIGHT_GRAY,
        "terminating": LIGHT_RED,
        "pending": LIGHT_BLUE,
    }
    colors = {
        "ready": GREEN,
        "restarting": ORANGE,
        "unknown": MUTED,
        "terminating": RED,
        "pending": BLUE,
    }
    color = colors[state]
    box(draw, xy, fills[state], color if highlight else BORDER, 4 if highlight else 2)
    centered(draw, ((x1 + x2) / 2, y1 + 29), name, "box", color)
    centered(draw, ((x1 + x2) / 2, y1 + 62), detail, "small", INK)


STAGES = [
    "두 Worker Node의 Pod 세 개 정상 실행",
    "Kubelet의 Pod A 컨테이너 종료 확인",
    "같은 Pod A 안의 컨테이너 재실행",
    "Worker Node 1의 생존 신호 단절과 NotReady 전환",
    "장애 지속에 따른 기존 Pod 제거 처리",
    "ReplicaSet Controller의 Pod D 생성 요청",
    "Scheduler의 Worker Node 2 배정과 API 기록",
    "Worker Node 2 Kubelet의 Pod D 배정 확인",
    "런타임을 통한 Pod D 컨테이너 실행",
    "Pod D의 준비 완료와 요청 처리 재개",
]


# Exact midpoint routes; independent Worker Node lanes.
COMPONENTS = {
    'controllers': (100,170,450,290), 'scheduler': (850,170,1200,290),
    'api': (550,330,750,430),
    'k1': (180,620,520,700), 'r1': (180,770,520,850), 'p1': (180,940,520,1040),
    'k2': (880,620,1220,700), 'r2': (880,770,1220,850), 'p2': (880,940,1220,1040),
}
PATHS = {
    'controller': ('controllers','api',[(450,230),(500,230),(500,380),(550,380)]),
    'scheduler': ('scheduler','api',[(1025,290),(1025,380),(750,380)]),
    'worker1': ('api','k1',[(650,430),(650,490),(350,490),(350,620)]),
    'worker2': ('api','k2',[(750,380),(780,380),(780,490),(1050,490),(1050,620)]),
    'runtime1': ('k1','r1',[(350,700),(350,770)]),
    'runtime2': ('k2','r2',[(1050,700),(1050,770)]),
    'pod1': ('r1','p1',[(350,850),(350,940)]),
    'pod2': ('r2','p2',[(1050,850),(1050,940)]),
}

def validate_routes():
    def mids(rect):
        l,t,r,b=rect
        return {(l,(t+b)/2),(r,(t+b)/2),((l+r)/2,t),((l+r)/2,b)}
    for name,(source,target,points) in PATHS.items():
        assert points[0] in mids(COMPONENTS[source]), name
        assert points[-1] in mids(COMPONENTS[target]), name
        for a,b in zip(points,points[1:]):
            assert a[0]==b[0] or a[1]==b[1], name
            for key,(l,t,r,bt) in COMPONENTS.items():
                if a[0]==b[0]:
                    assert not (l<a[0]<r and max(min(a[1],b[1]),t)<min(max(a[1],b[1]),bt)),(name,key)
                else:
                    assert not (t<a[1]<bt and max(min(a[0],b[0]),l)<min(max(a[0],b[0]),r)),(name,key)


# Compact geometry without shrinking text or resource icons.
LAYOUT_X = 0.90
LAYOUT_Y = 0.75

class CompactDraw:
    def __init__(self, image):
        self.raw = ImageDraw.Draw(image)

    @staticmethod
    def coords(value):
        if isinstance(value[0], (tuple, list)):
            return [(x * LAYOUT_X, y * LAYOUT_Y) for x, y in value]
        return tuple(v * (LAYOUT_X if i % 2 == 0 else LAYOUT_Y) for i, v in enumerate(value))

    def text(self, xy, *args, **kwargs):
        return self.raw.text(self.coords(xy), *args, **kwargs)

    def textbbox(self, *args, **kwargs):
        return self.raw.textbbox(*args, **kwargs)

    def line(self, xy, *args, **kwargs):
        return self.raw.line(self.coords(xy), *args, **kwargs)

    def polygon(self, xy, *args, **kwargs):
        return self.raw.polygon(self.coords(xy), *args, **kwargs)

    def rectangle(self, xy, *args, **kwargs):
        return self.raw.rectangle(self.coords(xy), *args, **kwargs)

    def rounded_rectangle(self, xy, *args, **kwargs):
        return self.raw.rounded_rectangle(self.coords(xy), *args, **kwargs)


def draw_frame(stage: int, subframe: int, frames_per_stage: int) -> Image.Image:
    image = Image.new('RGB', (1188,953), 'white')
    draw = CompactDraw(image)
    def icon(kind,x,y):
        im=Image.open(f'images/characters/refs/{kind}-official.png').convert('RGBA')
        im.thumbnail((32,32));image.paste(im,(round(x*LAYOUT_X),round(y*LAYOUT_Y)),im)
    def component(key,title,detail='',active=False):
        xy=COMPONENTS[key];l,t,r,b=xy
        box(draw,xy,LIGHT_BLUE if active else BOX_BG,BLUE if active else BORDER,3 if active else 2)
        for string,yy,style in [(title,(t+b)/2-(14 if detail else 0),'box'),(detail,(t+b)/2+20,'small')]:
            assert draw.textbbox((0,0),string,font=FONTS[style])[2]<(r-l)*LAYOUT_X-24,string
            centered(draw,((l+r)/2,yy),string,style)
    def flow(name,color=BORDER,reverse=False,broken=False):
        pts=PATHS[name][2]
        if reverse:pts=pts[::-1]
        if broken:
            # A broken heartbeat is not a delivered message: no arrowhead.
            for a,b in zip(pts,pts[1:]):
                length=abs(a[0]-b[0])+abs(a[1]-b[1])
                for offset in range(0,int(length),18):
                    t=offset/length;u=min(offset+9,length)/length
                    draw.line([(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t),(a[0]+(b[0]-a[0])*u,a[1]+(b[1]-a[1])*u)],fill=color,width=3)
            draw.rectangle((335,477,365,503),fill='white')
            draw.line([(342,482),(358,498)],fill=RED,width=3)
            draw.line([(342,498),(358,482)],fill=RED,width=3)
            return
        for a,b in zip(pts,pts[1:]):draw.line((a,b),fill=color,width=4 if color!=BORDER else 2)
        if color!=BORDER:arrow(draw,pts[-2],pts[-1],color,4)
    centered(draw,(660,30),'Kubernetes 클러스터','node')
    box(draw,(60,65,1260,460),CONTROL_BG)
    icon('node',80,85);centered(draw,(660,105),'Control Plane Node','node')
    component('controllers','컨트롤러 매니저','Node 장애 처리 / ReplicaSet Controller',stage in (4,5))
    component('scheduler','Scheduler','실행 가능한 Node 선택',stage==6)
    component('api','API Server','Pod 생성과 배정 기록',stage in (3,4,5,6,7,9))
    centered(draw,(650,210),'Deployment','box')
    centered(draw,(650,244),'원하는 Pod 수: 3','body')
    for w,l,r in [(1,60,620),(2,700,1260)]:
        failed=w==1 and stage>=3
        box(draw,(l,525,r,1085),FAILED_BG if failed else WORKER_BG,RED if failed else BORDER)
        icon('node',l+18,545)
        centered(draw,(l+158,561),f'Worker Node {w}','node')
        status_pill(draw,(r-78,561),'NotReady' if failed else 'Ready',LIGHT_RED if failed else LIGHT_GREEN,RED if failed else GREEN)
        component(f'k{w}','Kubelet','API 확인과 실행 관리',(w==1 and stage in (1,2)) or (w==2 and stage in (7,8,9)))
        component(f'r{w}','컨테이너 런타임','컨테이너 프로세스 실행',(w==1 and stage==2) or (w==2 and stage==8))
    detail=['실행 중','컨테이너 종료','컨테이너 재실행','상태 확인 불가','API에서 제거 처리'][min(stage,4)]
    component('p1','Pod A / UID A',detail,stage in (1,2));icon('pod',192,950)
    # Existing Pods remain visually separate from the replacement Pod.
    box(draw,(720,750,855,1040),'white')
    icon('pod',732,764)
    centered(draw,(788,820),'Pod B','box');centered(draw,(788,885),'Pod C','box')
    centered(draw,(788,962),'실행 유지','small')
    if stage>=6:
        component('p2','새 Pod D','배정 완료' if stage==6 else '배정 확인' if stage==7 else '컨테이너 실행' if stage==8 else 'Ready',stage>=8)
        icon('pod',892,950)
    else:
        centered(draw,(1050,980),'새 Pod 실행 전','body',MUTED)
    # Draw neutral routes first, then only the active path. Failure color lasts
    # for the failure scene; Node status carries the failure in later scenes.
    for name in ['controller','scheduler','worker2','runtime1','runtime2','pod1']:
        flow(name)
    if stage<3:flow('worker1')
    if stage>=6:flow('pod2')
    if stage==1:flow('runtime1',BLUE,reverse=True)
    if stage==2:flow('runtime1',ORANGE);flow('pod1',ORANGE)
    if stage==3:flow('worker1',RED,reverse=True,broken=True)
    if stage in (4,5):flow('controller',BLUE)
    if stage==6:flow('scheduler',PURPLE)
    if stage==7:flow('worker2',GREEN)
    if stage==8:flow('runtime2',ORANGE);flow('pod2',ORANGE)
    if stage==9:flow('worker2',GREEN,reverse=True)
    box(draw,(60,1110,1260,1220),'#f4f7fb',None,0)
    category='정상 실행' if stage==0 else 'Pod 장애: 컨테이너 재시작' if stage<3 else 'Node 장애: 대체 Pod 생성과 실행'
    centered(draw,(660,1135),category,'box')
    centered(draw,(660,1171),f'{stage+1}. {STAGES[stage]}','stage',BLUE)
    for i in range(len(STAGES)):
        x=95+i*114;box(draw,(x,1204,x+100,1210),BLUE if i==stage else BORDER,None,0,3)
    centered(draw,(660,1245),'Fig 1. Pod 장애와 Node 장애의 복구 경로','caption')
    return image


def main():
    validate_routes()
    frames = []
    durations = []
    for stage in range(len(STAGES)):
        frames.append(draw_frame(stage, 1, 2))
        frames[-1].save(f"/tmp/ch05-simple-recovery-{stage}.png")
        durations.append(3000 if stage == len(STAGES) - 1 else 2600)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        OUTPUT,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=True,
    )
    print(f"wrote {OUTPUT} ({len(frames)} frames)")


if __name__ == "__main__":
    main()
