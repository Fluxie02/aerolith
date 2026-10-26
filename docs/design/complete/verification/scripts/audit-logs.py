from pathlib import Path
import re,json,collections
ansi=re.compile(r'\x1b\[[0-9;]*m')
regression=re.compile(r'TypeError|ReferenceError|Unable to assign|Binding loop|binding loop|Cannot assign|is not a type|Expected token|Cannot load library|Error loading QML|Cannot read property|Cannot call method')
rows=[]; families=collections.Counter();bad=[]
for p in sorted(Path('build/ui006').glob('*/qs.log')):
 raw=p.read_text(errors='replace');lines=ansi.sub('',raw).splitlines()
 issues=[s for s in lines if regression.search(s)]
 diagnostic=[s for s in lines if re.search(r'\b(WARN|ERROR)\b|\[aerolith:.*(?:failed|cancelled|problem|unknown)',s)]
 for s in diagnostic:
  s=re.sub(r'0x[0-9a-f]+','<address>',s)
  s=re.sub(r'qt\.qpa\.wayland.textinput.*','Qt Wayland input focus warning (also in baseline)',s)
  if '[aerolith:' not in s: families[s]+=1
 rows.append({'run':p.parent.name,'lines':len(lines),'qml_regressions':issues,'reloads':raw.count('Reloading configuration'),'diagnostics':diagnostic})
 if issues: bad.append(p.parent.name)
print(json.dumps({'logs_read':len(rows),'regression_runs':bad,'runs':[{k:v for k,v in r.items() if k!='diagnostics'} for r in rows],'diagnostic_families':dict(families)},indent=2))
Path('build/ui006/log-audit.json').write_text(json.dumps(rows,indent=2)+'\n')
if bad: raise SystemExit(1)
