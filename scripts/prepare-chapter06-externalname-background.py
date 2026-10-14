from pathlib import Path
import xml.etree.ElementTree as ET
p=Path('images/articles/06/05-externalname-topology.svg')
r=ET.fromstring(p.read_text());r.set('height','1200');r.set('viewBox','0 0 1200 1200')
for parent in r.iter():
 for el in list(parent):
  if el.tag.endswith('path') and 'marker-end' in el.attrib:parent.remove(el)
  elif el.tag.endswith('text') and el.text and (el.text.startswith(('1.','2.','3.')) or el.text=='api.example.com의 IP 조회 후 접속'):parent.remove(el)
ET.register_namespace('','http://www.w3.org/2000/svg')
Path('/tmp/fig9-animation-base.svg').write_text(ET.tostring(r,encoding='unicode'))
