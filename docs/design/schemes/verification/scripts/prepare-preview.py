from pathlib import Path
import shutil
import hashlib
import json
root = next(p for p in Path(__file__).resolve().parents if (p / "AGENTS.md").exists())
base = root / "build/ui015/verification"
manifest = {}
for kind in ["lock", "osd", "session"]:
    target = base / ("preview-" + kind)
    if target.exists(): shutil.rmtree(target)
    shutil.copytree(root / "shell", target)
    text = (root / "prototypes/views" / kind / "shell.qml").read_text()
    text = text.replace("// UI-007 preview fixture only.", "// UI-015 preview fixture only.")
    text = text.replace('target: "preview"', 'target: "preview"\n        function scheme(id: string): string { return Config.setValue("theme.scheme", id); }')
    text = text.replace('sample:preview.sample,event:', 'scheme:Config.theme.scheme,sample:preview.sample,event:')
    text = text.replace('theme:{intensity:intensity,', 'theme:{scheme:Config.theme.scheme,intensity:intensity,')
    (target / "shell.qml").write_text(text)
    manifest[kind] = {str(p.relative_to(target)): hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob("*") if p.is_file()}
(base / "preview-source-hashes.json").write_text(json.dumps(manifest, indent=2) + "\n")
