# D05 — managed Hyprland layer animation rules

Verified 2026-10-26 UTC by Sol in `codex/coding-7194fbb8`.
Base commit (`git rev-parse HEAD`): `57f6e7c6b483622e8513b4c2fb6d837be6927b77`.
Results cover that commit plus this uncommitted worktree diff. No commit was
created; the bridge will assign the resulting commit SHA.

## Change and upstream contract

`installer/aerolith_install/hypr.py:106`, `fragment()`, emits five exact,
anchored namespace rules in the existing owned fragment. Lua uses
`hl.layer_rule({ match = { namespace = "^aerolith-deck$" }, no_anim = true })`;
hyprlang uses `layerrule = no_anim on, match:namespace ^aerolith-deck$`.
The same rules cover ground, strip, notices and OSD. No blur or shell changes.

Upstream syntax checked against the
[Hyprland v0.55.0 Lua implementation](https://github.com/hyprwm/Hyprland/blob/v0.55.0/src/config/lua/bindings/LuaBindingsConfigRules.cpp#L169)
(`no_anim` boolean effect; `hlLayerRule` at line 1080), the
[current upstream layer-rule documentation](https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/rules/layer-rules.md),
and the [0.54.0 hyprlang layer rules](https://wiki.hypr.land/0.54.0/Configuring/Window-Rules/#layer-rules).
The latter is the pre-Lua dialect retained by the installer; no claim of
compatibility with older legacy `noanim` syntax is made.

Read SR-016-1 in `docs/design/smooth/SYSTEMS-REQUESTS.md` and confirmed with
`rg -n 'WlrLayershell.namespace' shell/`: GroundSurface.qml:24,
FlightStrip.qml:27, Deck.qml:105, NoticeColumn.qml:32 and OsdHost.qml:134.

Reviewed the existing systems integration once: `cli.py` `plan_hypr():359`,
`regenerate_fragment():719`, `cmd_hypr():1019`, and manifest removal all
reuse the owned fragment. No additional systems correction was needed for
this request. Opus's independent D05 review remains pending; none was dispatched.

## Commands and results

All commands ran from the worktree root. Exit 0 unless specified.

| Exact command | Result |
| --- | --- |
| `python3 -m pytest -q tests/py` | Initial run: 2 failed, 189 passed, 1 skipped. New test's reinstall omitted required `--startup`; corrected the test. |
| `python3 -m pytest -q` | Initial run: same 2 failures, 206 passed, 1 skipped. |
| `python3 -m pytest -q tests/py/test_installer.py -k 'layer_rules or no_hypr'` | After correction: 4 passed, 156 deselected. |
| `python3 -m pytest -q` | Final: **208 passed, 1 skipped**, 35.62 s. Includes agent-sync tests. |
| `node tests/js/run-node.mjs` | **135 passed, 0 failed**. |
| `AUDIO=1 INSTALL='--ai claude --startup hyprland' CONFIG=docs/verification/A03/saturated.json tools/headless/run.sh tests/scenarios/installed.sh build/D05/installed-saturated` | `installed: ok`. |
| `AUDIO=1 INSTALL='--ai claude --startup hyprland' CONFIG=docs/verification/A03/insane.json tools/headless/run.sh tests/scenarios/installed.sh build/D05/installed-insane` | `installed: ok`. |
| `bash -n tests/scenarios/installed.sh` | Passed. |
| `git diff --check` | Passed. |
| `docker run --rm aerolith-dev bash -c 'Hyprland --version; Hyprland --help; luac -v'` | Hyprland 0.56.2, Lua 5.5.1. |
| `docker image inspect aerolith-dev --format '{{.Id}}'` | `sha256:69509c170e0a000289122461914b7bc117ce4b0b66cd83eaf0e5638988b27c7f`. |

The installed scenario now runs these exact commands inside each disposable
container (the prior scenario had only `luac`, despite the request's wording):

```bash
luac -p "$hypr/hyprland.lua" "$hypr/aerolith/aerolith.lua"
Hyprland --verify-config --config "$hypr/aerolith/aerolith.lua"
Hyprland --verify-config --config "$OUT/fragment.conf"
```

Both native parser logs report `config ok` in both runs. `fragment.conf` is
generated through `hypr.fragment()` with AI/media binds and autostart; Lua
is the actual installed fragment. Scenario artifacts, including fragments,
parser logs and qs.log, remain in ignored `build/D05/`. Both complete qs.log
files were read: no QML type/reference/assignment/binding errors. Expected
headless diagnostics include missing Hyprland protocols/system bus/RTKit,
unavailable backlight and Qt Wayland keyboard/text-input warnings.

`test_layer_rules_managed_roundtrip` tests both dialects through first
install, upgrade from a fragment without rules, repeated apply, preservation
of unrelated rules added before/after install, and exact uninstall.
`--no-hypr` is checked for both dialects. The installed scenario asserts
all five rules before removal and no managed fragment/rules after uninstall.
The host skips `test_lua_fragment_compiles` because `luac` is absent; actual
Lua compilation is covered inside the dev image.

## Coordination and limits

Used the shared `/home/user/aerolith` hub through agent_sync. The initial
hub named Claude/UI-016 with no locks; the explicit user assignment
authorized transition to `Claude_Integration_Phase`, owner Sol. `status
--agent Sol` is unsupported (exit 2); read the hub directly instead.
Transition uses `--owner Sol` because that command has no `--agent` option.
Published the D05 start/completion events as Sol, locked all four changed
paths before editing and released them before F02.

No real Hyprland session or GPU animation behavior was tested. Parser
acceptance and Sway interactions cannot establish that map/unmap has one
transition with full motion or none with off/lowEffects. That SR-016-1
acceptance needs real-session review. Hyprland 0.54 itself was not run;
its documented hyprlang syntax was checked by 0.56.2's real legacy parser.
No packages, host configuration, provider credentials or visual design changed.
