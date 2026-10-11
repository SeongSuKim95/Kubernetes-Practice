"""Reuse chapter 5's native layouts with reviewed English labels and bounds checks."""
import ast,json,re,os
from pathlib import Path
from PIL import ImageDraw
ROOT=Path(__file__).resolve().parents[2]
LABELS=json.loads((Path(__file__).with_name('ch05-labels.en.json')).read_text())
class Translate(ast.NodeTransformer):
 def visit_Constant(self,node):
  if isinstance(node.value,str) and re.search('[가-힣]',node.value):
   assert node.value in LABELS,node.value
   return ast.copy_location(ast.Constant(LABELS[node.value]),node)
  return node

def load(name):
 p=ROOT/'scripts'/f'make-chapter05-{name}-gif.py'
 tree=Translate().visit(ast.parse(p.read_text()));ast.fix_missing_locations(tree)
 ns={'__file__':str(p),'__name__':'translated_renderer'}
 exec(compile(tree,str(p),'exec'),ns)
 key='OUT' if name=='termination' else 'OUTPUT'
 ns[key]=ROOT/'images/articles/05/en'/ns[key].name
 ns[key].parent.mkdir(parents=True,exist_ok=True)
 return ns

def main():
 os.chdir(ROOT)
 for name in ['node-recovery','pending','termination']:
  ns=load(name)
  # All three renderers preserve Korean box/arrow geometry. Check every text run
  # against the smallest containing component, with room for its official icon.
  original=ImageDraw.ImageDraw.text
  def checked(draw,xy,text,*args,**kw):
   font=kw.get('font');x,y=xy
   if name=='node-recovery':
    boxes=[tuple(v*(ns['LAYOUT_X'] if i%2==0 else ns['LAYOUT_Y']) for i,v in enumerate(r)) for r in ns['COMPONENTS'].values()]
   elif name=='termination':boxes=[ns['rect'](r) for r,_,_ in ns['BOXES']]
   else:boxes=[(65,175,555,335),(380,375,555,710),(65,465,255,620),(845,175,1205,245),(845,525,1205,595)]
   matches=[r for r in boxes if r[0]<x<r[2] and r[1]<y<r[3]]
   if matches:
    r=min(matches,key=lambda r:(r[2]-r[0])*(r[3]-r[1]))
    bounds=draw.textbbox(xy,text,font=font,anchor=kw.get('anchor'))
    assert bounds[0]>=r[0]+8 and bounds[2]<=r[2]-8,(name,text,r,bounds)
    assert bounds[1]>=r[1]+5 and bounds[3]<=r[3]-5,(name,text,r,bounds)
   bounds=draw.textbbox(xy,text,font=font,anchor=kw.get('anchor'))
   assert bounds[0]>=0 and bounds[2]<=draw.im.size[0],(name,text,bounds)
   return original(draw,xy,text,*args,**kw)
  ImageDraw.ImageDraw.text=checked
  try:ns['main']()
  finally:ImageDraw.ImageDraw.text=original
if __name__=='__main__':main()
