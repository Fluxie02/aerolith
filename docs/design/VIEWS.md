# UI-007: standalone surface views

Astra · 22 October 2026 · ready for Claude's hosts.

The production deliverables are `shell/modules/lock/LockView.qml`,
`shell/modules/osd/OsdView.qml`, and `shell/modules/session/SessionView.qml`.
Each file starts with its property/signal contract. They use Theme and the
existing Bezel, with no service imports, command dispatch, processes,
authentication, expiry timers, IPC, or surface ownership. Lock alone uses
Quickshell's minute-precision SystemClock, as requested.

Both Saturated and Insane inherit the production palette, density, fonts,
uiScale and motion tokens. Insane adds radial registrations and edge marks
on lock, denser gauge divisions on OSD, and more session field registrations.
The controls occupy the same positions in both intensities. Lock is opaque;
OSD uses the production mineral plane; session uses a nearly opaque field.
lowEffects makes every plane opaque and disables motion. There are no
shadows, shader dependencies, or ambient animations.

## LockView

Fill the host's single display. This is a FocusScope with a masked, focused
TextInput. It draws only the authentication view and clock; it has no window
metadata, thumbnails, or references to the desktop. At smaller widths the
clock moves above the authentication plane. Short screens use compact
spacing; long prompts scroll above a permanently visible unlock button.

| Property | Type/default | Contract |
| --- | --- | --- |
| `state` | inherited Item string, `idle` | `idle`, `checking`, `failed`, `locked-out`; host owns transitions |
| `message` | string, empty | Plain PAM prompt/error; wrapped; view supplies an explicit failure/lockout prefix |
| `user` | string, empty | Plain display name; empty shows “Your session”; long names elide |
| `attempts` | int, 0 | Host's failed-attempt count; positive values are shown without inferring a retry policy |
| `password` | alias to TextInput.text | Sensitive, transient buffer; prefer the signal; do not log or persist |
| `submitted(password)` | signal(string) | Emitted on Return or Unlock when editable and nonempty |

The view clears its buffer **before** emitting `submitted`, on every state
change, and on hide. The host must set `state = "checking"` synchronously in
the submission handler and pass the signal argument to authentication.
Checking and locked-out disable editing and submission. Failed restores
focus and permits a fresh entry. There is no client-side unlock success,
PAM validation, retry timer, or lockout duration. Use `message` for the actual
retry instruction; the view never promises a countdown it cannot know.

Claude must provide the secure session-lock host and PAM lifecycle. A
PanelWindow preview is not a session lock. Display selection, security while
outputs change, successful unlock and destruction, and clearing any host-held
credential belong to the host. The host must preserve the lock until real
authentication succeeds; the view has no escape-to-dismiss action.

## OsdView

Size to `implicitWidth` × `implicitHeight` (408 × 158 design units), center
horizontally near the lower display edge, clear of reserved strips. This is
a passive Item: it never takes keyboard focus or changes a device value.

| Property | Type/default | Contract |
| --- | --- | --- |
| `kind` | string, `volume` | `volume`, `brightness`, `mic` |
| `value` | real, NaN | Normalized value; 1 = 100%; NaN/nonfinite shows N/A |
| `muted` | bool, false | Mute is explicit, independent of the last known level; suppresses fill |
| `maxValue` | real, 1 | Positive normalized ceiling; invalid ceilings fall back to 1 |
| `label` | string, empty | Plain device name, one line/elided; empty shows “Device not reported” |
| `presentationOpen` | bool, true | Host requests entry/exit; keep mapped for exit |
| `exitMs` | readonly int | Theme.fast, or 0 when motion is off/lowEffects |
| `presenting` | readonly bool | Requested open or any remaining exit opacity |
| `settled()` | signal | Exit is visually complete; host may unmap/destroy |

The gauge and percentage clamp to [0,maxValue]. A value above 100% is amber,
with a physically positioned 100% mark and ceiling label. Zero is an empty
known gauge with `0%`; unknown is a hollow gauge marked `N/A`. Muted is amber
and explicitly labeled, including when the underlying level is unknown.

The host owns mapping, expiry and event coalescing. Create with
`presentationOpen: true`; update properties in place on repeated events.
On expiry set it false, then release the surface on `settled()`. Reopening
interrupts exit without a stale completion. A short opacity transition uses
Theme.fast; full motion also travels 8 design units, reduced motion only
fades, and off/lowEffects settle without animation. The host should not make
`visible` false at exit start. It must select `Ui.screen`, avoid focus/input
capture, and apply its own display/window lifecycle policy.

## SessionView

Fill the host and focus this FocusScope on entry. The action list scrolls
and follows keyboard selection; unavailable actions remain readable with
their reason, and cannot activate. A selected unavailable row is deliberate:
users can inspect why an option is unavailable. An empty model explicitly
says no actions are available.

| Property/signal | Type/default | Contract |
| --- | --- | --- |
| `actions` | JS array, `[]` | Replace array when host availability/labels change |
| `activated(id)` | signal(string) | User accepted an available action, after confirmation when needed |
| `cancelled()` | signal | Escape from the chooser; host closes |

Each action is `{id, label, sensitive, available, reason}`: string id,
plain string label, bool sensitive, bool available, plain string reason.
Only `available === true` can activate; missing availability is unavailable.
Ids pass through unchanged. Prefer the registry's ids (`session.lock`,
`session.logout`, `system.suspend`, `system.reboot`, `system.poweroff`) and
its sensitive flags; the preview uses short fixture ids. All sensitive
entries get confirmation; logout/reboot/shutdown/poweroff and their registry
ids also get confirmation even if a host accidentally omits `sensitive`.
Suspend follows its supplied sensitive flag (the preview marks it sensitive,
matching the current Power registry).

Up/Down and Tab/Shift+Tab select rows. Return/Space chooses. Sensitive actions
open a confirmation with **Go back selected**. Left/Right or Tab changes
that selection; Return/Space accepts it. Escape backs out first, then cancels.
Auto-repeated Return/Space is ignored, so holding the opening key cannot
confirm an action. Pointer and accessibility activation use the same guards.
The model is rechecked on final acceptance; replacing it cancels a pending
confirmation, so an availability refresh cannot approve an old record.

`selected`, `pendingId`, `confirmSelected`, `choose()`, `confirm()` and
`back()` are view interaction state/helpers, used by the fixture to show
states; they are not a host command API. Hosts should create a fresh view
on opening, connect the two public signals, and close after activation or
cancellation. The host owns authorization, inhibitors, actual operations,
error reporting and lifecycle. Do not dispatch an action when merely opening
confirmation.

## Previews, screenshots and verification

Complete copied shells live in `prototypes/views/{lock,osd,session}/`.
Their fixture roots show only the corresponding view with sample inputs;
production shell roots/hosts and services are untouched. See
[`prototypes/views/README.md`](../../prototypes/views/README.md) for exact
rendering commands and preview IPC. Screenshots live in
[`views/`](views/); the manifest records state, size and intensity.

The matrix covers every lock state plus entry, prompt and literal text;
OSD volume/brightness/mic, zero, maximum, amplification, clamp, mute, unknown
and exit; session all selections, unavailable/empty models and both choices
for each confirmation. Each runs in both intensities at 1920×1080 and
1280×720, plus reduced motion, off/lowEffects and uiScale 1.25 with Noto fonts.
Long content is intentionally scrollable and controls remain reachable.

Exact commands/results and log audit are in
[`views/verification/RESULTS.md`](views/verification/RESULTS.md). Rendering
uses Quickshell on headless sway with software rendering. Actual Hyprland,
secure session locking, PAM, backlight and logind actions remain Claude's
integration work and have not been exercised by a visual preview.

## Single systems review

Reviewed Claude's `Power.qml` registry semantics, Deck lifecycle/focus and
NoticeColumn display policy once for this handoff. No actionable visual
integration findings. The existing Power registry marks suspend sensitive;
the supplied preview matches it. The new hosts should preserve those
registry flags and use the contracts above. UI-007 requests no schema,
configuration, service or AI changes. One systems/performance review and one
revision are available to Claude after `design_complete`; no agent was
started or dispatched by recording the handoff.
