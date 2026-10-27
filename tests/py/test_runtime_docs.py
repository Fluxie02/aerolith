"""Run the documented archive command and check the plotted coordinate closures."""

import ast
import re
import shlex
import subprocess
import sys

from conftest import ROOT


def test_documented_oxt_preserves_manifest_path(tmp_path):
    doc = (ROOT / "docs/design/thears-piyti/APP-FORMATS.md").read_text()
    command = re.search(r"\(cd themes/libreoffice && (python3 -m zipfile -c [^\n]+)\)", doc)[1]
    argv = shlex.split(command)
    archive = tmp_path / "appearance.oxt"
    argv[0] = sys.executable
    argv[4] = str(archive)
    subprocess.run(argv, cwd=ROOT / "themes/libreoffice", check=True)
    listing = subprocess.run([sys.executable, "-m", "zipfile", "-l", str(archive)],
                             capture_output=True, text=True, check=True).stdout
    assert "META-INF/manifest.xml" in listing, listing
    for name in ("description.xml", "thears.xcu", "piyti.xcu"):
        assert name in listing


def test_plot_coordinate_functions_keep_their_panel():
    # Evaluate the actual coordinate assignments without regenerating any plots.
    tree = ast.parse((ROOT / "docs/design/smooth/summarise-positions.py").read_text())
    loop = next(n for n in tree.body if isinstance(n, ast.For) and isinstance(n.target, ast.Tuple)
                and [t.id for t in n.target.elts] == ["panel", "rate"])
    assignments = [n for n in loop.body if isinstance(n, ast.Assign)
                   and isinstance(n.targets[0], ast.Name) and n.targets[0].id in {"x0", "y0", "w", "h", "sx", "sy"}]
    loop.body = assignments + ast.parse("saved.append((sx, sy))").body
    module = ast.fix_missing_locations(ast.Module(body=[loop], type_ignores=[]))
    scope = {"saved": []}
    exec(compile(module, "plot-coordinates", "exec"), scope)
    first, second = scope["saved"]
    assert first[0](-50) == 65
    assert second[0](-50) == 595
    # Also verify sy captures both values rather than consulting later globals.
    scope.update(y0=999, h=999)
    assert first[1](752) == second[1](752) == 100
