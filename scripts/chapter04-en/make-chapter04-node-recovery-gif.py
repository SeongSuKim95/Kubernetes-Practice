#!/usr/bin/env python3
"""Generate Fig 7 for chapter 4: container restart and Node failure recovery."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


WIDTH = 1120
HEIGHT = 1000
OUTPUT = Path("images/articles/04/en/17-node-failure-recovery.gif")
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
    if not hasattr(draw, '_text_boxes'): draw._text_boxes = []
    draw._text_boxes.append(xy)


def centered(draw, xy, text, style="body", fill=INK):
    x,y = xy
    containers = [r for r in getattr(draw, '_text_boxes', []) if r[0] < x < r[2] and r[1] < y < r[3]]
    available = 2 * min(x, draw._image.width-x) - 24
    if containers:
        r = min(containers, key=lambda r:(r[2]-r[0])*(r[3]-r[1]))
        available = min(available, 2*min(x-r[0],r[2]-x)-20)
    chosen = FONTS[style]
    while draw.textlength(text,font=chosen) > available and chosen.size > 11:
        chosen = font(chosen.size-1, style in ('node','box','stage','metric'))
    assert draw.textlength(text,font=chosen) <= available, (text, available)
    draw.text(xy, text, font=chosen, fill=fill, anchor="mm")


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
    "Pods A, B, and C are running across two Worker Nodes.",
    "Worker 1\'s Kubelet detects that Pod A\'s container has exited.",
    "The Kubelet restarts the container within the same Pod A.",
    "Worker 1 stops sending heartbeats and becomes NotReady.",
    "The failure persists, and removal of Worker 1\'s Pods begins.",
    "The ReplicaSet Controller requests a new Pod D.",
    "The Scheduler excludes Worker 1 and selects Worker 2.",
    "Worker 2\'s Kubelet starts Pod D\'s container through the runtime.",
    "Pod D passes readiness checks, so three replicas can receive requests again.",
]


def draw_frame(stage: int, subframe: int, frames_per_stage: int) -> Image.Image:
    image = Image.new('RGB', (WIDTH, HEIGHT), 'white')
    draw = ImageDraw.Draw(image)
    def icon(kind, x, y, size=34):
        im = Image.open(f'images/characters/refs/{kind}-official.png').convert('RGBA')
        im.thumbnail((size, size))
        image.paste(im, (x, y), im)
    def component(xy, title, detail='', active=False):
        box(draw, xy, LIGHT_BLUE if active else BOX_BG, BLUE if active else BORDER, 3 if active else 2)
        x1,y1,x2,y2=xy
        centered(draw, ((x1+x2)/2,(y1+y2)/2-(13 if detail else 0)), title, 'box')
        if detail: centered(draw,((x1+x2)/2,(y1+y2)/2+18),detail,'small')
    def flow(points, color=BLUE):
        for a,b in zip(points,points[1:]): draw.line((a,b),fill=color,width=5)
        arrow(draw,points[-2],points[-1],color,5)
    box(draw,(20,20,1100,820),'#fafcff')
    centered(draw,(560,50),'Kubernetes cluster','node')
    box(draw,(40,85,470,785),CONTROL_BG)
    icon('node',55,99)
    centered(draw,(275,120),'Control Plane Node','node')
    component((65,190,245,285),'Controller manager','Node status / Replicas',stage in (4,5))
    component((65,525,245,605),'Scheduler','Select a Node',stage==6)
    component((330,190,445,605),'API Server','Pod status',stage in (3,4,5,6))
    centered(draw,(255,708),'Desired replicas: 3','box')
    centered(draw,(255,743),'Components observe state through the API','small')
    # The API lanes stay in the gap between nodes; no lines cross a component.
    flow([(245,237),(330,237)],BLUE if stage in (4,5) else BORDER)
    flow([(245,565),(330,565)],PURPLE if stage==6 else BORDER)
    for worker,top in [(1,85),(2,445)]:
        failed=worker==1 and stage>=3
        box(draw,(515,top,1080,top+340),FAILED_BG if failed else WORKER_BG,RED if failed else BORDER)
        icon('node',530,top+14)
        centered(draw,(700,top+34),f'Worker Node {worker}','node')
        status_pill(draw,(987,top+34),'NotReady' if failed else 'Ready',LIGHT_RED if failed else LIGHT_GREEN,RED if failed else GREEN)
        component((550,top+78,745,top+145),'Kubelet',active=(worker==1 and stage in (1,2)) or (worker==2 and stage==7))
        component((830,top+78,1045,top+145),'Container runtime',active=(worker==1 and stage==2) or (worker==2 and stage==7))
        flow([(745,top+112),(830,top+112)],ORANGE if (worker==1 and stage==2) or (worker==2 and stage==7) else BORDER)
        # API observation and reporting, separate from the runtime execution path.
        if failed:
            arrow(draw,(550,top+112),(445,top+112),RED,3,True)
        elif worker==2 and stage==8:
            flow([(550,top+112),(445,top+112)],GREEN)
        else:
            flow([(445,top+112),(550,top+112)],GREEN if worker==2 and stage in (6,7) else BORDER)
        if worker==1:
            detail=['Running','Container exited','Container restarted','State unknown','Removal begins'][min(stage,4)]
            component((550,top+218,1045,top+305),'Pod A / Same UID' if stage<3 else 'Pod A',detail,stage in (1,2,4))
            icon('pod',570,top+235)
            flow([(935,top+145),(935,top+218)],ORANGE if stage==2 else BORDER)
        else:
            component((550,top+218,775,top+305),'Pod B / Pod C','Existing containers running')
            icon('pod',555,top+223,25)
            if stage>=6:
                component((825,top+218,1045,top+305),'New Pod D', 'Assigned' if stage==6 else 'Container starting' if stage==7 else 'Ready',True)
                icon('pod',831,top+223,25)
                flow([(935,top+145),(935,top+218)],GREEN if stage==8 else BLUE)
    box(draw,(25,835,1095,950),'#f4f7fb',None,0)
    category = 'Normal operation' if stage == 0 else 'Pod failure: restart the container in the same Pod' if stage < 3 else 'Node failure: start a new Pod on another Node'
    centered(draw,(560,860),category,'box',ORANGE if stage in (1,2) else BLUE)
    centered(draw,(560,901),f'{stage+1}. {STAGES[stage]}','stage',BLUE)
    for i in range(len(STAGES)):
        x=50+i*115
        box(draw,(x,933,x+100,939),BLUE if i==stage else BORDER,None,0,3)
    centered(draw,(560,975),'Fig 7. Container restart within a Pod and replacement after Node failure','caption')
    return image


def main():
    frames = []
    durations = []
    for stage in range(len(STAGES)):
        frames.append(draw_frame(stage, 1, 2))
        frames[-1].save(f"/tmp/ch04-en-simple-recovery-{stage}.png")
        durations.append(3000 if stage == len(STAGES) - 1 else 1800)

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
