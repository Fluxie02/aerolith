# C03/C04 — Installer intensity and Spectra selection

Verified on 26 October 2026 in `codex/coding-c40ff140`.
Base commit SHA: `60bf8b9dc541a818a07e97f32e26f0cc371a5c92`.
Checks include the uncommitted changes on that base. No commit was created;
the bridge assigns the implementation SHA after handoff.
Dev image: `aerolith-dev`, ID
`sha256:69509c170e0a000289122461914b7bc117ce4b0b66cd83eaf0e5638988b27c7f`.
Full local logs and scenario artifacts are in ignored `build/C03/`.

## Implementation

`installer/aerolith_install/cli.py:436` (`cmd_install`) selects intensity
first, then scheme. Fresh interactive installs offer Saturated first as the
default, with a one-line description for each intensity, and the catalog's
12 scheme names with Limb as default. Existing settings win without flags;
reinstalls do not prompt for them. Non-interactive installs and `--yes` use
the existing values or Saturated/Limb schema defaults. Missing keys in an
existing config may remain omitted, preserving its original bytes and using
the shell's defaults. Explicit flags intentionally override just their keys.

`read_live_config()` and `write_theme_values()` at lines 222/229 are shared
with `cmd_intensity()` (1048) and `cmd_scheme()` (1068). JSON must be an
object, and an existing `theme` must be an object. Empty/malformed JSON and
invalid supplied values refuse before install writes. Other config keys
survive atomic updates. Invalid stored enum values require repair or an
explicit install override. A new config is recorded after applying selections
so uninstall's hash protection remains correct; an existing user's config
retains its ownership/protection. Neither setting enters `installation.json`.

`scheme_choices()` (236) reads IDs, names and descriptions from the generated
`themes/schemes/index.json`, using C05's `assets_root()` lookup. No scheme list
or palette was copied into Python. `shell/lib/schemes.mjs` and the generated
catalog are unchanged. C05 preflight receives the selected scheme explicitly;
live settings are saved before the planned app exports execute.

`aerolith scheme [id]` shows or saves `theme.scheme`. Both live commands
support `--dry-run`. For existing app-theme consents, the scheme command
preflights before saving, acquires C06's refresh lock, re-reads the manifest,
and calls the existing refresh implementation. Busy/global refusal occurs
before config writes. Per-app errors retain protected payloads and return 2;
the shell's selected scheme remains saved, and `aerolith themes refresh` can
retry after correction. No new app consent or include is added by refresh.

The only shell change is one diagnostic `theme` object in
`shell/modules/ControlSurface.qml:71`, exposing the actual running
`Theme.intensity` and `Theme.scheme`. No design tokens, layout, typography,
colours, palettes, animation, Settings implementation or services changed.

## Exact commands and results

Run from the worktree root; installed scenarios ran one at a time:

```bash
mkdir -p build/C03
python3 -m pytest -q > build/C03/pytest-full.log 2>&1
node tests/js/run-node.mjs > build/C03/node.log 2>&1
INSTALL='--ai claude --startup hyprland --intensity insane --scheme iris --themes kitty,foot,hyprland' AUDIO=1 \
  tools/headless/run.sh tests/scenarios/installed.sh build/C03/installed-insane-iris-final \
  > build/C03/installed-insane-iris-final.log 2>&1
INSTALL='--ai claude --startup hyprland' AUDIO=1 \
  tools/headless/run.sh tests/scenarios/installed.sh build/C03/installed-default \
  > build/C03/installed-default.log 2>&1
INSTALL='--ai claude --startup hyprland --direction thears --intensity saturated --scheme limb --themes kitty,foot,hyprland' AUDIO=1 \
  tools/headless/run.sh tests/scenarios/installed.sh build/C03/installed-thears \
  > build/C03/installed-thears.log 2>&1
bash -n tests/scenarios/installed.sh
git diff --check
```

| Check | Result |
| --- | --- |
| Full pytest | 274 passed, 1 skipped, exit 0 (44.27 s). Local `luac` is absent; installed scenarios run Lua grammar and Hyprland parser checks in the image. |
| Node | 135 passed, 0 failed, exit 0. |
| PIYTI / Insane / Iris + themes | `installed: ok`, exit 0; startup IPC reports `insane`/`iris`; all three app exports report Iris. Live CLI switches to Saturated/Limb and refreshes opted-in exports, then restores. |
| Default PIYTI / Saturated / Limb | `installed: ok`, exit 0; no app themes applied. Live CLI switches to Insane/Iris without creating app consent, then restores. |
| THEARS / Saturated / Limb + themes | `installed: ok`, exit 0; startup IPC reports `thears`, `saturated`/`limb`. Live CLI switches to Insane/Iris with app refresh, then restores. |
| Bash syntax / whitespace | Both exit 0. |

Every installed scenario also checks the chosen values against `config.json`,
uses the config watch without `ipc reload`, checks app-theme status after the
live switch, restores the original configuration, exercises the fake AI
provider and AI removal, and completes full uninstall with byte-exact
Hyprland restoration. foot and Hyprland fragments pass their native parsers.

Pytest covers interactive Enter/explicit selection, one prompt per missing
setting, no selection prompts on reinstall, non-interactive/`--yes` defaults,
explicit flags, invalid flag/stored values, preservation of unrelated keys,
all 12 catalog IDs, custom catalog lookup, malformed/empty/non-object JSON,
invalid theme objects, dry runs without writes, reinstall preservation,
intentional overrides, selected-scheme export bytes, C06 consent/lock handling,
unchanged includes and idempotent refresh. Existing package-mode tests pass.

The shell-log audit command was:

```bash
python3 - <<'PY'
import json
from pathlib import Path
names = ('installed-default', 'installed-insane-iris-final', 'installed-thears')
patterns = ('TypeError', 'ReferenceError', 'Unable to assign', 'binding loop', 'SyntaxError', 'Cannot assign')
for name in names:
    root = Path('build/C03') / name
    errors = [line for line in (root / 'qs.log').read_text().splitlines()
              if any(p.lower() in line.lower() for p in patterns)]
    assert not errors, (name, errors)
    initial = json.loads((root / 'shell-status.json').read_text())
    live = json.loads((root / 'shell-status-live.json').read_text())
    print(name, initial['direction'], initial['theme'], 'live:', live['theme'], 'QML errors:', len(errors))
PY
```

All three logs had zero matching QML errors, exit 0. Expected container
warnings include missing system bus/RTKit and sway keyboard/text-input warnings.

The initial installer-only command
`python3 -m pytest -q tests/py/test_installer.py > build/C03/pytest-installer.log 2>&1`
reported 224 passed, 1 skipped, 1 failed (30.34 s): the new test used the
nonexistent `Layout.config_home` attribute. It was corrected to
`lay.config.parent`; the full suite above includes that correction. An earlier
Insane/Iris installed run passed before the live-switch assertions were added;
the final three runs include those assertions. No final check failed.

## Review, scope and limits

Reviewed the existing other-agent C06 contract once:
`themes.py`'s `refresh_lock()`, `refresh_plans()` and `refresh()`, plus
`shell/services/AppThemes.qml`'s persisted-config observation. No actionable
defect found in the reused path; the integration uses the existing lock,
consent records, per-app rollback and activation policy. Independent Opus
review remains pending; no reviewer or cloud agent was dispatched.

Verification uses software-rendered sway, mock Hyprland IPC and a fake AI
provider. Real Hyprland sessions, running third-party app appearance/reloads,
GPU performance and a real Arch package install were not verified. Catalog
assets must be shipped with installations, as with C05. Global refresh errors
refuse; app-local failures can leave some opted-in apps on an older scheme,
which the CLI reports without overwriting user-modified payloads.

Shared coordination used `--agent Sol --task-id C03` against
`/home/user/aerolith`, as explicitly requested. The hub had integration phase,
current owner Sol and no active locks. The explicit assignment was recorded;
the unrelated global task identifier was retained. All six changed paths were
locked before editing. Completion and lock release are published at handoff.
ROADMAP.md, ui.py, themes.py, config.mjs, schemes.mjs, the catalog and the
C01/C05 verification documents were read and left unchanged.

Changed paths: `installer/aerolith_install/cli.py`,
`shell/modules/ControlSurface.qml` (status only), `tests/py/test_installer.py`,
`tests/scenarios/installed.sh`, `README.md`, `docs/verification/C03/README.md`.
