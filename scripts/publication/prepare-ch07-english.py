"""Prepare English chapter 7 Swift renderers in /tmp/ch07-english.
Run the emitted renderers from the repository root with Swift/AppKit.
Source diagrams retain their geometry; English labels fit their reserved areas.
"""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[2]
labels=json.loads(Path(__file__).with_name('ch07-labels.en.json').read_text())
out=ROOT/'images/articles/07/en';out.mkdir(exist_ok=True)
tmp=Path('/tmp/ch07-english');tmp.mkdir(exist_ok=True)
for name in ['concept-visuals','controller-figure','tls-gif','diagnosis-figure']:
 p=ROOT/'scripts'/f'make-chapter07-{name}.swift'
 s=p.read_text()
 def translate(m):
  value=m[1]
  if re.search('[가-힣]',value):
   assert value in labels,(p.name,value)
   return '"'+('Reference' if name == 'tls-gif' and value == '참조' else labels[value])+'"'
  return m[0]
 s=re.sub(r'"((?:[^"\\]|\\.)*)"',translate,s)
 s=s.replace('images/articles/07/','images/articles/07/en/').replace('/tmp/ch07-','/tmp/ch07-en-')
 s=s.replace('let size: CGFloat =','var size: CGFloat =').replace('let attrs:[NSAttributedString.Key:Any]=','var attrs:[NSAttributedString.Key:Any]=')
 s=s.replace(' let measured=(value as NSString).size(withAttributes:attrs)', ''' while (value as NSString).size(withAttributes:attrs).width > w && size > 16 {
  size -= 0.5; attrs[.font] = bold ? NSFont.boldSystemFont(ofSize:size):NSFont.systemFont(ofSize:size)
 }
 let measured=(value as NSString).size(withAttributes:attrs)''')
 # Reserve the icon and padding before sizing the centered card title.
 s=s.replace('let titleWidth=(title as NSString).size(withAttributes:[.font:NSFont.boldSystemFont(ofSize:21)]).width','let titleWidth=min(w-16-(key == nil ? 0:42),(title as NSString).size(withAttributes:[.font:NSFont.boldSystemFont(ofSize:21)]).width)')
 # Fig 7 uses the dedicated animated renderer, not the legacy static version.
 s=s.replace('savePNG(render{tlsFlow()},dir+"04-ingress-tls.png")','')
 (tmp/p.name).write_text(s)
print(tmp)
