from pathlib import Path
import re,json,hashlib,shutil
b=Path('build/ui009');o=Path('docs/design/review/verification');(o/'logs').mkdir(parents=True,exist_ok=True)
novel=set();report=[]
engine=re.compile(r'TypeError|ReferenceError|Unable to assign|Binding loop|binding loop|is not a type|Cannot assign|Cannot read property|Expected token|Cannot override|non-existent property|Duplicate method')
for p in sorted(b.rglob('qs.log')):
 raw=p.read_bytes();lines=re.sub(r'\x1b\[[0-9;]*m','',raw.decode(errors='replace')).splitlines()
 name=p.parent.name;errors=[l for l in lines if engine.search(l)]
 entry={'run':name,'lines':len(lines),'sha256':hashlib.sha256(raw).hexdigest(),'engine_diagnostics':errors,'startup_progress_events':sum('UI009_BOOT ' in l for l in lines)}
 report.append(entry)
 shutil.copy2(p,o/'logs'/f'{name}-qs.txt')
 print(f'{name}: {len(lines)} lines; {len(errors)} QML diagnostics')
 for line in lines:
  if 'UI009_BOOT ' in line:continue
  n=re.sub(r'0x[0-9a-f]+','<ptr>',line)
  n=re.sub(r'/by-id/[^/]+/','/by-id/<id>/',n)
  n=re.sub(r'\[\d\d:\d\d:\d\d\.\d+\]','[time]',n)
  if n not in novel:novel.add(n);print('  '+n)
(o/'log-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('TOTAL',len(report),'logs,',sum(r['lines'] for r in report),'lines')
