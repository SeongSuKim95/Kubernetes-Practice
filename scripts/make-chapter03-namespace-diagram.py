"""Namespace membership and Node placement as separate dimensions."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
EN='--en' in sys.argv
im=Image.new('RGB',(1400,850),'white');d=ImageDraw.Draw(im)
FONT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
def text(x,y,s,size=27,color='#243b53'):
 d.text((x,y),s,font=ImageFont.truetype(FONT,size),fill=color,anchor='mm')
def box(bounds,fill,outline,width=3):
 d.rounded_rectangle(bounds,20,fill=fill,outline=outline,width=width)
def icon(kind,x,y,size):
 p=Image.open(ROOT/'images/characters/refs'/f'{kind}-official.png').convert('RGBA');p.thumbnail((size,size));im.paste(p,(x,y),p)
box((45,35,1355,765),'#f8fafc','#71869b')
text(700,77,'Kubernetes Cluster',33)
for x,ns,col,bg in [(310,'dev','#2563b0','#eaf3ff'),(780,'prod','#98602d','#fff2df')]:
 box((x,120,x+310,178),bg,col,2);text(x+155,149,f'Namespace: {ns}',25,col)
for x,node,pod in [(100,'A','web-a'),(745,'B','web-b')]:
 box((x,220,x+555,710),'white','#72879b')
 icon('node',x+25,240,60);text(x+315,270,f'Worker Node {node}',30)
 for y,ns,col,bg in [(335,'dev','#2563b0','#eaf3ff'),(520,'prod','#98602d','#fff2df')]:
  box((x+45,y,x+510,y+145),bg,col)
  icon('pod',x+68,y+39,64)
  text(x+302,y+47,f'Pod: {pod}',29)
  text(x+302,y+100,f'Namespace: {ns}',25,col)
text(700,808,'Fig 4. Namespace membership and Node placement' if EN else 'Fig 4. Namespace의 소속과 Node의 실행 위치',27)
out=ROOT/'images/articles/03'
if EN: out=out/'en'
out.mkdir(parents=True,exist_ok=True)
im.save(out/'15-namespace-and-node-placement.png')
