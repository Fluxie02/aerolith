#!/usr/bin/env python3
"""Prepare disposable visual capture fixtures; never change production files."""
import shutil
from pathlib import Path
root=Path(__file__).resolve().parents[4]
build=root/'build/ui015'
build.mkdir(parents=True,exist_ok=True)
for p in (Path(__file__).parent/'fixtures').glob('*.json'): shutil.copyfile(p,build/p.name)
shutil.copytree(root/'shell',build/'thears-shell',dirs_exist_ok=True)
p=build/'thears-shell/core/Theme.qml'
p.write_text(p.read_text().replace('property string applicationDirection: "piyti"','property string applicationDirection: "thears"'))
print('Prepared build/ui015 capture configs and THEARS visual seam copy')
