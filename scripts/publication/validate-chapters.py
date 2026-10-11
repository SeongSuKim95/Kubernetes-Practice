"""Check publication parity, references, local assets, and complete GIF decoding."""
from pathlib import Path
import importlib.util,json,re,xml.etree.ElementTree as ET
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('pub',Path(__file__).with_name('rebuild-chapters.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
assets=set()
for name in m.NAMES:
 draft=m.blocks((ROOT/'articles'/f'{name}.draft.md').read_text())
 trans=json.loads((ROOT/'scripts/publication'/f'{name}.translations.json').read_text())
 for lang in ['ko','en']:
  file=ROOT/'articles'/(name+'.publish'+('.en' if lang=='en' else '')+'.md')
  s=file.read_text(); b=m.blocks(s.replace(m.RAW+'images/','../images/'))
  assert b==(draft if lang=='ko' else [trans[v] for v in draft]),file
  if lang=='en':assert not re.search('[가-힣]',s),file
  ids=re.findall(r'<a id="ref-(\d+)"',s); refs=re.findall(r'\]\(#ref-(\d+)\)',s)
  assert len(ids)==len(set(ids)) and set(ids)==set(refs),file
  assert len(re.findall(r'^```',s,re.M))%2==0
  urls=re.findall(r'!\[[^\]]*\]\(([^)]+)\)',s)+re.findall(r'<img\b[^>]*\bsrc="([^"]+)"',s)
  for url in urls:
   if url.startswith('https://raw.githubusercontent.com/kubernetes/community/main/icons/'):
    continue  # Official upstream icons are shared by both languages.
   assert url.startswith(m.RAW),url
   p=ROOT/url[len(m.RAW):];assert p.exists(),p;assets.add(p)
   if lang=='en' and p.suffix in ['.svg','.gif']:assert '/en/' in str(p),p
  # Output blocks remain verbatim; executable YAML/Bash values remain unchanged.
  source_code=re.findall(r'```(\w+)\n(.*?)```','\n\n'.join(draft),re.S)
  dest_code=re.findall(r'```(\w+)\n(.*?)```',s,re.S)
  assert len(source_code)==len(dest_code)
  def clean(code):
   code=re.sub(r'<[^>\n]+>','<placeholder>',code)
   return '\n'.join(l.split('#')[0].rstrip() for l in code.splitlines() if l.split('#')[0].strip())
  for (sl,sc),(dl,dc) in zip(source_code,dest_code):
   # Translate explanatory output placeholders, but preserve actual output bytes.
   normalize_output=lambda v: re.sub(r'<[^>\n]+>','<placeholder>',v)
   assert sl==dl and (normalize_output(sc)==normalize_output(dc) if sl=='text' else clean(sc)==clean(dc)),(file,sl)
  print(file.name,'OK')
for p in sorted(assets):
 if p.suffix=='.svg':
  root=ET.parse(p).getroot()
  if '/en/' in str(p):
   assert not re.search('[가-힣]',' '.join(''.join(t.itertext()) for t in root.iter() if t.tag.endswith('}text'))),p
 elif p.suffix=='.gif':
  im=Image.open(p);duration=0
  assert im.info.get('loop')==0,p
  for i in range(im.n_frames): im.seek(i); im.load(); duration+=im.info['duration']
  print(p.relative_to(ROOT),im.n_frames,'frames',duration/1000,'seconds')
print('Verified',len(assets),'unique linked local assets')
