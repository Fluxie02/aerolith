# C05 — Explicit application-theme deployment

Verified on 26 October 2026 in `codex/coding-c57f9d21`.
Base commit SHA: `9b60683e5b23779edf66741ccadbe11d4daf79dd`.
The commands below test the uncommitted C05 changes on that base. No commit
was created; the bridge assigns the implementation SHA after handoff.
Container image: `aerolith-dev`, ID
`sha256:69509c170e0a000289122461914b7bc117ce4b0b66cd83eaf0e5638988b27c7f`.
Logs are in the ignored `build/C05/` directory.

## Contract and implementation

ROADMAP.md:41–52 requires optional, reversible external themes from generated
assets, without whole-config replacement or silent modification-system
installation. This implementation changes no shell code, visual design or
fragment assets.

`installer/aerolith_install/themes.py:199` (`prepare_app`) is the single-app
scheme/direction preflight entry point. `selection()` reads C01's
`installation.json` and `config.json` `theme.scheme`, defaulting to PIYTI/Limb
only when metadata/keys are absent. Malformed JSON and invalid enum values
refuse before deployment; explicit `--scheme` overrides only the exported
scheme. `execute()` writes payloads before includes. Standalone multi-app apply
preflights the entire batch. Source installs copy the generated catalog as core
files into `data/theme-assets/schemes`, so later deployments need no checkout.
Packaged installs can use their read-only `themes/schemes` catalog; missing
catalogs are reported without writes.

`cli.py` adds `themes list`, `apply APP... [--scheme ID] [--dry-run]`,
`remove APP...`, and `status [--json]`. Install has an empty interactive
selection, `--themes APP,APP` and mutually exclusive `--no-themes`. Enter,
`--yes` and non-interactive installs apply nothing unless apps are explicitly
named. `--no-themes` preserves existing deployments. `--no-hypr` conflicts
with an explicit Hyprland theme request. There is no implicit app execution or
session configuration change.

The manifest adds `themes`, and edit fields `inserted` / `created`; old
version-1 records still load with defaults. Each supported app has a
`theme:<app>` component. Every modified user config gets a unique backup,
including before removal. `remove_edit()` removes the exact insertion,
including owned separators, or only its complete marker block if edited.
Unmarked content survives. Created minimal configs are deleted only when
empty after removal. Modified payloads remain recorded and are preserved even
on full uninstall with `--force`. Ambiguous/incomplete markers and symlinks
refuse rather than consume unrelated content. Full uninstall removes startup
integration before app blocks so minimal theme-created configs can be removed
when empty, including after a later install adds startup integration.
`hypr remove` touches only startup blocks.
Backups remain user data after removal.

| Target | User integration / owned payload | Activation and limits |
| --- | --- | --- |
| kitty | Marked `include` in `kitty/kitty.conf`; `data/themes/kitty/aerolith.conf` | Reload/restart; other includes preserved |
| Alacritty | Marked addition within `[general].import`, or a minimal table; `data/themes/alacritty/aerolith.toml` | Existing arrays/comments retained byte for byte; ambiguous/legacy/dotted/inline general forms refuse |
| foot | Marked `include=` at the start of `foot/foot.ini`; `data/themes/foot/aerolith.ini` | foot 1.26+; existing main-section settings win |
| btop | Owned `btop/themes/aerolith.theme`; no btop.conf edit | Manually select aerolith in theme chooser |
| Hyprland | Marked `dofile` or `source` of owned `data/themes/hyprland/aerolith.{lua,conf}` and `direction.{lua,conf}` | Existing dialect, Lua when absent; shared appearance plus installed direction rules; manual reload |
| GTK 3/4 | Marked `@import` before user rules in `gtk-{3,4}.0/gtk.css`; owned data CSS | User override only; restart apps; accessibility and sandbox coverage remain user choices |
| qt5ct/qt6ct | Owned manager `colors/aerolith.conf` and `qss/aerolith.qss`; no preference-file edit | Manually select palette/optional QSS and per-app platform plugin; no system theme/environment changes |

Config paths in this table are relative to `$XDG_CONFIG_HOME`; `data` means
`$XDG_DATA_HOME/aerolith`. Missing include configs are minimal and marked as
created. btop/Qt require only their theme search directories, so do not create
application preference files. Status `applied` means intact deployment; for
btop/Qt it does not claim the app selected the theme. Detection means a config
directory or app binary exists, not that the app/version is operational.

Alacritty import ordering/precedence was checked against the
[upstream configuration reference](https://alacritty.org/config-alacritty.html#general):
the importing user config loads last, so its explicit values retain precedence.
Other mechanisms follow the existing [theme placement documentation](../../../themes/README.md).
GTK imports are prepended, correcting the old placement prose without changing
any stylesheet.

## Exact commands and results

Run from the worktree root, with long output redirected:

```bash
python3 -m pytest -q > build/C05/pytest-full.log 2>&1
node tests/js/run-node.mjs > build/C05/node.log 2>&1
bash -n tests/scenarios/installed.sh tests/scenarios/themes.sh
git diff --check
mkdir -p build/C05/themes
docker run --rm -v "$PWD:/src:ro" -v "$PWD/build/C05/themes:/out" \
  aerolith-dev bash /src/tests/scenarios/themes.sh /out \
  > build/C05/themes.log 2>&1
INSTALL='--ai claude --startup hyprland --themes kitty,foot,hyprland' AUDIO=1 \
  tools/headless/run.sh tests/scenarios/installed.sh build/C05/installed-piyti \
  > build/C05/installed-piyti.log 2>&1
INSTALL='--ai claude --startup hyprland --direction thears --themes kitty,foot,hyprland' AUDIO=1 \
  tools/headless/run.sh tests/scenarios/installed.sh build/C05/installed-thears \
  > build/C05/installed-thears.log 2>&1
INSTALL='--ai claude --startup hyprland --themes kitty,foot,hyprland' AUDIO=1 \
  tools/headless/run.sh tests/scenarios/installed.sh build/C05/installed-piyti-final \
  > build/C05/installed-piyti-final.log 2>&1
node tools/gen-scheme-themes.mjs --check > build/C05/generator.log 2>&1
```

| Check | Result |
| --- | --- |
| Full pytest, including agent-sync tests | 205 passed, 1 skipped; exit 0 (29.30 s). Skip: host lacks `luac`; container runs native Lua checks. |
| Node | 135 passed, 0 failed; exit 0 |
| Bash syntax and whitespace | Both exit 0 |
| Focused container roundtrip | Exit 0: `themes: ok (PIYTI and THEARS; byte-exact uninstall)` |
| Installed THEARS headless scenario | Exit 0: `installed: ok`; AI request/removal, core shell and full uninstall pass |
| Installed PIYTI headless scenario, final rerun | Exit 0: `installed: ok`; AI request/removal, core shell and full uninstall pass. Initial run exited 1 at `core shell broken after ai remove` before uninstall; theme status/native foot check had passed. |
| Generator check | Exit 1: `MODULE_NOT_FOUND`; generator is absent in this base checkout |

The focused scenario installs with `--themes kitty,foot,hyprland` and current
scheme Iris in both directions. It calls the installed maintenance CLI,
checks applied status, applies twice (install plus explicit reapply),
runs `foot --check-config`, `luac -p` on the config and both loaded payloads,
and native `Hyprland --verify-config`. Both directions report `config ok`.
It then fully uninstalls and compares all three original config files with
`cmp`, including originals without final newlines. No data tree, CLI launcher,
manifest or installation metadata remains. Native Hyprland verification is
parse-only; the disposable root container passes its required root override.

The Python matrix uses temporary HOME/XDG directories for every supported
app: missing config, existing config, existing include, two applies, edits
outside the block, removal, dry-run, pre-existing theme refusal and full
uninstall restoring original bytes. Additional cases cover scheme/direction
changes, hyprlang, read-only packaged catalogs, removal after checkout loss,
legacy manifests, malformed metadata, invalid/unknown schemes, deferred apps,
symlinks, unrecorded includes, modified payloads, modified/incomplete markers,
Alacritty array forms and ambiguous TOML, install flag conflicts, empty
interactive choice and interrupted-write recovery. Native app rendering is
not inferred from these filesystem tests.

## Review and limits

One review of the existing installer integration found a P2 restoration bug
in `hypr.py:add_include/remove_include`: a config without a final newline
returned with an extra newline (the old test allowed this). C05 records the
exact inserted startup bytes, preserves CRLF and tightens that test to strict
equality. The focused native container roundtrip verifies the correction.
No further unrelated integration changes were made. Opus review is pending;
no agent dispatcher was invoked or claimed.

For Astra: `tools/gen-scheme-themes.mjs` is missing despite being named by
`themes/schemes/index.json`, `themes/README.md` and APP-THEMES.md. The catalog
and all twelve generated directories are present and used as-is. No broken
fragment was found in the exercised native parser checks. Generator freshness
could not be verified; no asset or generator repair was attempted.

Firefox, Steam, Discord, LibreOffice and ArtCraft remain listed but unsupported
for automated deployment. Firefox needs an explicit chosen profile plus the
stylesheet preference; no prefs.js/user.js is changed. Steam needs an existing
Millennium theme directory, Discord an existing Vencord theme directory, and
both need manual selection; neither mod is installed. LibreOffice needs exact
extension registration/removal. ArtCraft's adapter is debug-only.

C06 runtime refresh is intentionally absent. Includes in nonstandard config
locations are not followed. Alternate/legacy Alacritty files are refused before
creating a canonical config. Symlinked paths and include paths with unsafe
syntax characters are refused. Existing app-local settings can override imported
values; applied status confirms deployment integrity, not final appearance.
GTK accessibility themes, Flatpak/portal access and Qt plugin selection require
user verification. Real kitty/Alacritty/btop/GTK/Qt rendering, signed-in mod apps
and a real Hyprland compositor session were not tested.

Operations record progress for recovery but are not a cross-app filesystem
transaction and do not lock out simultaneous external config edits. Avoid
concurrent writers. The initial PIYTI run failed an audio assertion; its cause
is unverified. A final headless rerun passed without changing shell/audio code. The focused PIYTI
install/uninstall also passes independently. The repository was not committed and
no host/system configuration or global packages were changed.
