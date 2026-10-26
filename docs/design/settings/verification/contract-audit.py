import hashlib,json,re,subprocess
from pathlib import Path

def head(path): return subprocess.check_output(['git','show','HEAD:'+path],text=True)
def block(text,start):
    begin=text.index('{',start); depth=0; quote=None; escaped=False
    for i in range(begin,len(text)):
        c=text[i]
        if quote:
            if escaped: escaped=False
            elif c=='\\': escaped=True
            elif c==quote: quote=None
        elif c in ['"',"'",'`']: quote=c
        elif c=='{': depth+=1
        elif c=='}':
            depth-=1
            if depth==0:return text[start:i+1]
    raise ValueError('unclosed block')

def functions(text):
    return {m.group(1):block(text,m.start()) for m in re.finditer(r'\bfunction\s+(\w+)\s*\(',text)}
checks={}
a=Path('build/ui008/SettingsBay.original.qml').read_text();b=Path('build/ui008/final-shell/modules/settings/SettingsBay.qml').read_text()
for name in ['buildRows','valueOf','display','apply','stepOf','change','commitText','move']:
    checks['SettingsBay.'+name]=functions(a)[name]==functions(b)[name]
checks['SettingsBay.Keys.onPressed']=block(a,a.index('Keys.onPressed:'))==block(b,b.index('Keys.onPressed:'))
for key in ['Keys.onReturnPressed:','Keys.onEnterPressed:','Keys.onEscapePressed:']:
    if key.endswith('EscapePressed:'):
        checks['editor.'+key]=block(a,a.index(key))==block(b,b.index(key))
    else:
        checks['editor.'+key]=next(x.strip() for x in a.splitlines() if key in x)==next(x.strip() for x in b.splitlines() if key in x)
for path in ['shell/modules/command/CommandCore.qml','shell/modules/lock/LockView.qml','shell/modules/session/SessionView.qml','shell/modules/osd/OsdView.qml','shell/modules/signal/DeviceRow.qml','shell/modules/signal/StreamRow.qml','shell/modules/strip/WorkspaceTape.qml']:
    old=head(path);new=Path(path).read_text();checks[path+'.functions']=functions(old)==functions(new)
    if 'Keys.onPressed:' in old:checks[path+'.keys']=block(old,old.index('Keys.onPressed:'))==block(new,new.index('Keys.onPressed:'))
p='ai-bridge/qml/AiModule.qml';old=head(p);new=Path(p).read_text();sep='    component AiConsole:'
checks['AI systems prefix']=old[:old.index(sep)]==new[:new.index(sep)]
checks['AI functions']=functions(old)==functions(new)
for p in ['shell/core/Ui.qml','shell/core/Config.qml','shell/modules/deck/Deck.qml','shell/modules/ground/GroundSurface.qml','shell/modules/notices/NoticeColumn.qml','shell/modules/ControlSurface.qml','shell/lib/config.mjs','shell/schema/config.schema.json','shell/modules/strip/FlightStrip.qml']:
    checks[p+' unchanged']=head(p)==Path(p).read_text()
assert all(checks.values()),checks
Path('docs/design/settings/verification/contract-audit.json').write_text(json.dumps(checks,indent=2)+'\n')
print('Contract audit:',len(checks),'checks passed')
