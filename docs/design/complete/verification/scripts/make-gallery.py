from pathlib import Path
import shutil,re
root=Path('build/ui006/gallery-shell');shutil.copytree('shell',root,dirs_exist_ok=True)
p=root/'modules/strip/FlightStrip.qml';s=p.read_text()
# Presentation-only stress fixture: display all existing annunciators together.
a=s.index('        // Annunciators');b=s.index('\n        StripDivider {}',a)
part=s[a:b]
part=re.sub(r'visible: [^\n]+','visible: true',part)
part=part.replace('Compositor.screencastOwner.toUpperCase()','"<B>RECORDER</B> · PRIVATE WINDOW"')
part=part.replace('"1/" + Ui.screenCount','"1/3"').replace('String(Config.errors.length + Routines.errors.length)','"2"')
part=part.replace('T.formatPercent(Telemetry.cpu.total)','"99%"').replace('status: Telemetry.cpuState === "unknown" ? "unknown" : Telemetry.cpuState','status: "caution"')
part=part.replace('T.formatPercent(Telemetry.memory ? Telemetry.memory.percent : null)','"95%"').replace('status: Telemetry.memState === "unknown" ? "unknown" : Telemetry.memState','status: "caution"')
part=part.replace('T.formatTemp(Telemetry.temps.cpu)','"99°C"').replace('status: Telemetry.tempState === "unknown" ? "unknown" : Telemetry.tempState','status: "critical"')
part=part.replace('Power.charging ? "CHG" : "BAT"','"BAT"').replace('Math.round(Power.batteryPercent) + "%"','"8%"').replace('Power.charging ? "nominal" : T.classify(100 - Power.batteryPercent, 80, 90)','"critical"')
part=part.replace('Notifications.doNotDisturb ? "DND" : "NTF"','"DND"').replace('String(Notifications.count)','"7"')
s=s[:a]+part+s[b:];p.write_text(s)
