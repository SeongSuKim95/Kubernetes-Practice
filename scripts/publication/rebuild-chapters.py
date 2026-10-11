"""Rebuild the Korean and English publication copies of chapters 1 through 5.
English blocks are keyed by their source text; a changed draft requires translation review.
"""
from pathlib import Path
import re,json
ROOT=Path(__file__).resolve().parents[2]
RAW='https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/'
NAMES=['01-background-and-docker-limits','02-understanding-kubernetes','03-pod-and-workload-management','04-pod-lifecycle-and-self-healing','05-pod-failure-and-self-healing']
def blocks(s):
 s=re.sub(r'<!--.*?-->','',s,flags=re.S).replace('<div align="center">','').replace('</div>','')
 return [v.strip() for v in re.split(r'\n\s*\n',s.strip()) if v.strip()]
def raw(s):return s.replace('../images/',RAW+'images/')
def main():
 for name in NAMES:
  src=blocks((ROOT/'articles'/f'{name}.draft.md').read_text())
  translations=json.loads((ROOT/'scripts/publication'/f'{name}.translations.json').read_text())
  missing=[b[:100] for b in src if b not in translations]
  assert not missing,(name,missing)
  for lang in ['ko','en']:
   body='\n\n'.join(src if lang=='ko' else [translations[b] for b in src])+'\n'
   filename=f'{name}.publish'+('.en' if lang=='en' else '')+'.md'
   header=f'<!--\n  {"Korean" if lang=="ko" else "English"} publication based on {name}.draft.md.\n  GitHub Flavored Markdown; figures use GitHub raw URLs.\n-->\n\n'
   (ROOT/'articles'/filename).write_text(header+raw(body))
   print(filename)
if __name__=='__main__':main()
