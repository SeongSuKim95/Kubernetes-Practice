"""Shared display scale and typography for chapter 6 code-native diagrams."""
import re
DISPLAY_WIDTH = 1200

def normalize_svg(source):
    match = re.search(r'viewBox="0 0 (\d+) (\d+)"', source)
    width, height = map(int, match.groups())
    scale = DISPLAY_WIDTH / width
    source = re.sub(r'(<svg\b[^>]*?\bwidth=")[^"]+',r'\g<1>1200',source,count=1)
    source = re.sub(r'(<svg\b[^>]*?\bheight=")[^"]+',lambda m:m[1]+str(round(height*scale)),source,count=1)
    def font(m):
        tag, value, rest, label = m.groups()
        old=float(value)
        size=23 if label.startswith('Fig ') else 26 if old >= 27 else 21 if old >= 21 else 18
        return f'{tag}{size/scale:.2f}{rest}{label}'
    def icon(m):
        tag=m[0]
        values={k:float(v) for k,v in re.findall(r'(x|y|width|height)="([\d.]+)"',tag)}
        size=32/scale
        for k,value in [('x',values['x']+(values['width']-size)/2),('y',values['y']+(values['height']-size)/2),('width',size),('height',size)]:
            tag=re.sub(r'\b'+k+r'="[^"]+"',f'{k}="{value:.2f}"',tag,count=1)
        return tag
    source=re.sub(r'<image\b[^>]+>',icon,source)
    return re.sub(r'(<text\b[^>]*font-size=")([\d.]+)("[^>]*>)([^<]*)',font,source)
