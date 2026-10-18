"""Translate chapter 6 native assets; emit Swift renderers and SVG previews in /tmp."""
from pathlib import Path
import json,re,xml.etree.ElementTree as E
ROOT=Path(__file__).resolve().parents[2]
labels_path=Path(__file__).with_name('ch06-labels.en.json')
labels=json.loads(labels_path.read_text())
labels.update(dict(zip([
'Headless Service의 응용 사례: 데이터베이스 복제','애플리케이션','주문 저장 / 상품 조회','주 서버 전용 이름 → 주 서버 IP','일반 ClusterIP Service','읽기용 공통 주소','StatefulSet이 관리하는 데이터베이스 Pod','주 서버 Pod','변경 기록 / 읽기 처리','복제 서버 Pod','변경 사항 복제 / 읽기 처리','주문 생성 / 저장','주 서버 지정 / 쓰기','상품 목록 조회 / 읽기','주 서버 전용 이름으로 복제 연결','Fig 11. Headless Service의 응용 사례: 주 서버 지정과 데이터 복제'],[
'Headless Service Use Case: Database Replication','Application','Save orders / Browse products','Primary-specific name → Primary IP','ClusterIP Service','Shared read address','Database Pods managed by a StatefulSet','Primary Pod','Record changes / Serve reads','Replica Pod','Replicate changes / Serve reads','Save order','Primary / Write','Browse products / Read','Replication via the primary name','Fig 11. Headless Service Use Case: Primary Access and Replication'])))
labels_path.write_text(json.dumps(labels,ensure_ascii=False,indent=2)+'\n')
out=ROOT/'images/articles/06/en';out.mkdir(exist_ok=True)
tmp=Path('/tmp/ch06-english');tmp.mkdir(exist_ok=True)
E.register_namespace('','http://www.w3.org/2000/svg')
for p in (ROOT/'images/articles/06').glob('*.svg'):
 root=E.fromstring(p.read_text())
 for el in root.iter():
  if el.text and re.search('[가-힣]',el.text):
   assert el.text in labels,(p.name,el.text)
   el.text=labels[el.text]
 # Slightly smaller English typography leaves room for longer labels.
 for el in root.iter():
  if el.tag.endswith('text') and 'font-size' in el.attrib:
   el.set('font-size',str(round(float(el.get('font-size'))*.88,2)))
 (out/p.name).write_text(E.tostring(root,encoding='unicode'))
 if p.name=='05-externalname-topology.svg':
  for parent in root.iter():
   for el in list(parent):
    if el.tag.endswith('path') and 'marker-end' in el.attrib: parent.remove(el)
    elif el.tag.endswith('text') and el.text and (el.text.startswith(('1.','2.','3.')) or el.text==labels.get('api.example.com의 IP 조회 후 접속')):parent.remove(el)
 side=max(map(float,root.get('viewBox').split()[2:]))
 root.set('width',str(side));root.set('height',str(side));root.set('viewBox',f'0 0 {side} {side}')
 (tmp/p.name).write_text(E.tostring(root,encoding='unicode'))
for p in (ROOT/'scripts').glob('make-chapter06-*.swift'):
 s=p.read_text()
 def translate(m):
  value=m[1]
  if re.search('[가-힣]',value):
   assert value in labels,(p.name,value)
   return '"'+labels[value]+'"'
  return m[0]
 s=re.sub(r'"((?:[^"\\]|\\.)*)"',translate,s)
 s=s.replace('images/articles/06/','images/articles/06/en/').replace('/tmp/ch06-','/tmp/ch06-en-')
 # Keep labels inside their reserved widths, retaining overlap assertions.
 if 'let measured=(value as NSString).size(withAttributes:attrs)' in s:
  s=s.replace('let size: CGFloat =','var size: CGFloat =').replace('let attrs:[NSAttributedString.Key:Any]=','var attrs:[NSAttributedString.Key:Any]=')
  s=s.replace(' let measured=(value as NSString).size(withAttributes:attrs)', ''' while (value as NSString).size(withAttributes:attrs).width > w && size > 14 {
  size -= 0.5; attrs[.font] = bold ? NSFont.boldSystemFont(ofSize:size):NSFont.systemFont(ofSize:size)
 }
 let measured=(value as NSString).size(withAttributes:attrs)''')
 (tmp/p.name).write_text(s)
print(out,tmp)
