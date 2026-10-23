from pathlib import Path
import hashlib,json
b=Path('build/ui009'); baseline=b/'before-shell'; current=Path('shell')
protected=['shell.qml','core/Ui.qml','core/Config.qml','modules/ControlSurface.qml','modules/AiLoader.qml','modules/deck/Deck.qml','modules/ground/GroundSurface.qml','modules/notices/NoticeColumn.qml','modules/strip/FlightStrip.qml','modules/settings/SettingsBay.qml','lib/config.mjs','schema/config.schema.json','lib/tokens.mjs']
protected += [str(p.relative_to(current)) for p in (current/'services').glob('*') if p.is_file()]
report={'protected':{},'unchanged_behaviour_prefixes':{},'snapshot_matches':True}
for rel in protected:
 a=baseline/rel;z=current/rel
 assert a.read_bytes()==z.read_bytes(),rel
 report['protected'][str(z)]=hashlib.sha256(z.read_bytes()).hexdigest()
for rel in ['modules/systems/SystemsBay.qml','modules/signal/SignalRack.qml','modules/routines/RoutineConsole.qml','modules/help/HelpBay.qml']:
 a=(baseline/rel).read_text().split('    Bezel {',1)[0];z=(current/rel).read_text().split('    Bezel {',1)[0]
 assert a==z,rel;report['unchanged_behaviour_prefixes'][rel]=True
p=Path('ai-bridge/qml/AiModule.qml');a=(b/'before-AiModule.qml').read_text();z=p.read_text()
assert a.split('        Bezel {',1)[0]==z.split('        Bezel {',1)[0]
report['unchanged_behaviour_prefixes'][str(p)]=True
for p in current.rglob('*'):
 if p.is_file():assert p.read_bytes()==(b/'verified-shell'/p.relative_to(current)).read_bytes(),str(p)
report['changed_visual_files']=[str(p) for p in current.rglob('*') if p.is_file() and (not (baseline/p.relative_to(current)).exists() or p.read_bytes()!=(baseline/p.relative_to(current)).read_bytes())]+['ai-bridge/qml/AiModule.qml']
Path('docs/design/review/verification/contracts.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
