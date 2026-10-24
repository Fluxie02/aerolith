#!/usr/bin/env python3
"""Copy unmodified headless captures into the review package."""
import hashlib,json,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[4]
dst=root/'docs/design/schemes'
build=root/'build/ui015'
manifest=[]
def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,target)
    manifest.append({'path':str(target.relative_to(dst)),'source':str(source.relative_to(root)),'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
for p in sorted((build/'register-final').glob('scheme-*.png')): copy(p,dst/'spectra'/p.name.removeprefix('scheme-'))
for p in sorted((build/'register-final').glob('picker-*.png')): copy(p,dst/'picker'/p.name.removeprefix('picker-'))
for name in ['cursor-bathyal-active-limb','applied-bathyal','register','returned-spectrum','live-systems-cinder']:
    copy(build/'register-final'/f'{name}.png',dst/'picker'/f'{name}.png')
for p in sorted((build/'all-bays').glob('*.png')): copy(p,dst/'bays'/p.name)
for directory in sorted(build.glob('4k-*')):
    for p in sorted(directory.glob('*.png')): copy(p,dst/'4k'/directory.name.removeprefix('4k-')/p.name)
for p in sorted((build/'compact-final').glob('*.png')): copy(p,dst/'compact'/p.name)
copy(build/'compact'/'compact-active-glacial.png',dst/'compact'/'before-clipped-active.png')
for directory in ['register-final','compact-final','all-bays','live-switch-final','4k-piyti-saturated','4k-piyti-insane','4k-thears-saturated','4k-thears-insane']:
    copy(build/directory/'qs.log',dst/'verification'/'capture-logs'/f'{directory}.log')
copy(build/'register'/'cursor-bathyal-active-limb.png',dst/'picker'/'review-cursor-limb-active-glacial.png')
for p in sorted((dst/'live-switch').rglob('*')):
    if p.is_file(): manifest.append({'path':str(p.relative_to(dst)),'source':'build/ui015/live-switch-final (MP4 encodes unmodified 5fps samples)','bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
for p in sorted((dst/'verification/runs').rglob('*.png')):
    manifest.append({'path':str(p.relative_to(dst)),'source':'Disposable headless verification scenario; see verification/RESULTS.md','bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(dst/'capture-manifest.json').write_text(json.dumps({'method':'Unmodified screenshots from real Quickshell under headless sway/pixman. All-bay and lock/OSD/session data use fixtures; this is not real Hyprland/account/PAM verification.','files':manifest},indent=2)+'\n')
print(len(manifest),'review evidence files copied/registered')
