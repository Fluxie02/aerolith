"""The generated type labels distinguish colour overrides from output maps."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def test_generated_map_labels_match_their_values():
    subprocess.run(["node", "tools/gen-config-doc.mjs", "--check"], cwd=ROOT, check=True)
    text = (ROOT / "docs/CONFIGURATION.md").read_text()
    assert "| `display.outputs` | map of objects |" in text
    assert "| `theme.palette` | object of colours |" in text
