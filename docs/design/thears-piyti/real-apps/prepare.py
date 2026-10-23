"""Container-only disposable profiles, archive and GTK preparation."""
from pathlib import Path
import json
import shutil
import zipfile
import xml.etree.ElementTree as ET

home = Path('/home/pilot')
src = Path('/src')
with zipfile.ZipFile('/tmp/aerolith-appearance.oxt', 'w') as archive:
    for name in ['thears.xcu', 'piyti.xcu', 'description.xml', 'META-INF/manifest.xml']:
        archive.write(src / 'themes/libreoffice' / name, name)

gtk = home / '.config/gtk-3.0'
gtk.mkdir(parents=True, exist_ok=True)
shutil.copy(src / 'themes/gtk-3.0/gtk.css', gtk / 'gtk.css')
(gtk / 'settings.ini').write_text('[Settings]\ngtk-application-prefer-dark-theme=1\ngtk-font-name=Inter 10\n')
for direction in ['thears', 'piyti']:
    profile = home / ('libreoffice-' + direction) / 'user'
    profile.mkdir(parents=True, exist_ok=True)
    (profile / 'registrymodifications.xcu').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry">
<item oor:path="/org.openoffice.Office.UI/ColorScheme"><prop oor:name="CurrentColorScheme" oor:op="fuse"><value>AEROLITH %s</value></prop></item>
<item oor:path="/org.openoffice.Office.Common/Appearance"><prop oor:name="ApplicationAppearance" oor:op="fuse"><value>2</value></prop><prop oor:name="LibreOfficeTheme" oor:op="fuse"><value>1</value></prop></item>
<item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="FirstRun" oor:op="fuse"><value>false</value></prop></item>
<item oor:path="/org.openoffice.Office.Common/Setup"><prop oor:name="OfficeRestartInProgress" oor:op="fuse"><value>false</value></prop></item>
</oor:items>''' % direction.upper())

    cfg = home / (direction + '.json')
    cfg.write_text(json.dumps({'schemaVersion': 1, 'theme': {'intensity': 'saturated', 'motion': 'full'}}))

# Archive exact installed registry metadata around the appearance flags.
registry = ET.parse('/usr/lib/libreoffice/share/registry/main.xcd')
oor = '{http://openoffice.org/2001/registry}'
lines = []
def walk(node, ancestors):
    name = node.get(oor + 'name', '')
    path = ancestors + ([name] if name else [])
    if name in ['ApplicationAppearance', 'LibreOfficeTheme']:
        lines.append('/'.join(path) + '\n' + ET.tostring(node, encoding='unicode'))
    for child in node:
        walk(child, path)
walk(registry.getroot(), [])
Path('/out/libreoffice-registry-metadata.txt').write_text('\n\n'.join(lines))
