# Phase 2 — three directions

Astra · UI-001. These are different organizations of the desktop, not interchangeable palettes. Every proposal keeps the existing command registry, bay identities, privacy indicator, confirmation flows and keyboard access. None implies fake metrics, automatic task classification or new Linux integration.

## 01 / Parallax — the computational observatory

1. **Artistic idea.** A surveying instrument aimed at the user's work. A single eccentric circle establishes a reference point; workspace position and selection become readings against it. No stars, radar sweep or telemetry wallpaper.
2. **Character.** Deliberate, quiet, exact. Good for terminal-heavy work and keeping the machine's status subordinate to a task.
3. **Colour and type.** Deep blue-black, chalk, muted brass. Inter for readable names; JetBrains Mono for coordinates, controls and small numeric readings. Large workspace numerals are spatial anchors, not technical decoration.
4. **Depth/material.** Opaque ink plates with etched rules. An incomplete static orbit behind windows; drawn Canvas strokes, no shader or blur. Thin double offsets indicate overlays.
5. **Motion.** Short radial-to-linear registration: a selected marker changes into a straight focus rule in 160 ms. No revolving elements. Reduced mode changes emphasis only; off/lowEffects is instantaneous.
6. **Navigation/workspaces.** A visible “Open” strip affordance, a left-aligned launch instrument, and a two-dimensional workspace map with actual titles. Left/right and up/down follow the map's geometry. Empty workspaces remain small labeled entries.
7. **Signature.** “Take a bearing”: a workspace numeral receives an open bracket, which resolves into a rule beneath its selected window title. The index number remains in the same part of the eye's path.
8. **Risk/cost.** Circular marks can become ornamental and force labels away from good reading positions. Few static Canvas paths and bounded property animations; no sampling. Radial keyboard selection is rejected. The prototype uses a rectangular map under the orbit, exposing that tension rather than hiding it.

| Proposed interaction | Practical problem | Advantage over the usual alternative | Discoverable operation |
|---|---|---|---|
| Bearing selection | Selection can disappear among window previews. | Large number plus bracket and readable title survive small previews. | Click labeled workspace; arrows select, Tab selects window, Enter focuses; hints remain visible. |
| Left launch instrument | A popup in the center can cover the active task. | A narrow left composition leaves a reference area to the right. | “Open” is clickable; existing shortcut; focused text input and result rows on first frame. |
| Measured audio rail | Small sliders conceal precise setting and unavailable volume. | Labeled linear track plus number; no waveform pretending to measure audio. | Click/drag track, arrows nudge, M mutes, Enter sets default. Unknown is “N/A”. |

## 02 / Cut — digital architecture

1. **Artistic idea.** A habitable section through a building: broad pale planes, an offset dark edge and one terracotta joint. The desktop is composed by displacement of planes rather than by many bordered cards.
2. **Character.** Warm, open, physical. Strong figure/ground separation and generous type make this the least intimidating direction.
3. **Colour and type.** Chalk and warm limestone surfaces, charcoal text, deep oxide for selection. Inter Display at environmental scale, Inter functional text, mono numbers only. Pale surfaces carry dark semantic inks, not bright warning yellow on white.
4. **Depth/material.** Three flat levels: ground, slab, inset. Hard offset seams replace soft shadows. Opaque material works identically on software rendering. Background has one static stepped silhouette.
5. **Motion.** A slab enters from the right by 18 logical pixels in 180 ms; selection sets into an inset without bounce. Reduced: opacity only. Off/lowEffects: immediate. The active application never moves or scales.
6. **Navigation/workspaces.** A right-side deck occupies about two-thirds of the display; the left remains a quiet environmental title. Workspaces are upright rooms, windows are titled openings, and the launcher is a broad list within the slab. A scrollable room sequence retains a strict rectangular keyboard order.
7. **Signature.** “Open the joint”: the terracotta seam widens into the active deck's edge; the same seam identifies focus and the selected audio device.
8. **Risk/cost.** Generous empty areas become waste at low resolution; very pale full-screen overlays can be tiring at night. No custom compositor transform required. Static rectangles are cheap; content scroll must clip, and the right slab must collapse to available width under scaling.

| Proposed interaction | Practical problem | Advantage over the usual alternative | Discoverable operation |
|---|---|---|---|
| Right slab | Centered overlays erase context equally in every direction. | Stable edge gives a predictable origin and preserves a visual reference on the left. | Labeled strip actions; Esc/outside click closes, rail always visible. |
| Workspace rooms | Tiny windows offer unreadable titles. | Larger labeled openings prioritize task identity. | Horizontal room order follows left/right; Tab windows; number keys jump; explicit move and close hints. |
| Recessed controls | System controls are often generic cards of equal size. | Audio output and media have different spatial weights according to action frequency. | “Output”, “Input”, “Application streams” and “Now playing” remain literal labels. |

## 03 / Interleaf — the unknown direction

1. **Artistic idea.** Treat the desktop as a readable index of intentions. Workspaces are numbered passages; applications are lines with titles, not miniature pictures. A narrow dark margin joins an expansive pale reading field. The defining form is a line that opens into a passage.
2. **Character.** Literate, assured, tactile without imitating paper grain. Dense where the user chooses; spacious where the user thinks. The familiar act is finding a line and following it.
3. **Colour and type.** Pale celadon ground and near-black green ink; a deep red editorial mark indicates interaction. Opaque green-black margin carries inverse text. Inter at 15–17 px for functional names, 28–48 px for identities, 96 px only for the idle environmental mark. Mono appears only in indices, key hints, time and values. No dependency on a special display font.
4. **Depth/material.** Meaning comes from ink, rule and field rather than simulated depth. Background contains a cropped typographic pair of strokes, one dark vertical index and a short red underline. No blur, glow or texture. Notices are compact marginal annotations, not floating dashboard cards.
5. **Motion.** “Unfold the line”: an index rule lengthens horizontally, then its content becomes legible in place (160 ms total, text never stretched). Selection moves one solid mark; applications themselves stay still. Reduced has a brief crossfade; off and lowEffects show final state immediately.
6. **Navigation/workspaces.** A persistent thin folio strip says “Open”, “Workspaces” and “Sound”; no hidden gesture. The Deck becomes a dark numbered navigation margin and an opaque pale reading field. The overview is a vertical index: one line per workspace, nested lines per window, empty workspaces condensed. Up/down move between workspace passages, Tab between their windows; left/right have no concealed grid destination. Production key geometry is preserved through `columns = 1`, not remapped infrastructure.
7. **Signature.** One number, one rule, then a passage of actual window titles: selecting workspace 2 reveals Firefox and Downloads beneath it. The line is both a visual identity and a useful grouping tool. No invented “research” or “creative” workspace names.
8. **Risk/cost.** Text-heavy navigation may disappoint users who recognize work by images, and very long lists need scrolling. Optional single-capture previews may supplement the selected passage later, never displace titles. Static rules, opaque fields and standard text are cheap. Background ownership, ordered notices and deck transitions need Claude; the visual model itself needs no new data service.

| Proposed interaction | Practical problem | Advantage over the usual alternative | Discoverable operation |
|---|---|---|---|
| Workspace passages | Four real windows get lost among empty thumbnail areas. | Readable application and title lines use space in proportion to actual contents; numbered workspaces remain familiar. | “Workspaces”; visible “↑↓ workspace · Tab window · Enter focus · M move · X X close · / filter”; each row clickable. Empty rows say “Empty”. |
| Search as a sentence | Search fields and result cards feel disconnected. | Large query sits above aligned result lines; a red rule marks the currently actionable result. Category and availability stay explicit. | First-frame focused input; scopes visible and cycle with Tab; existing >, @, !, ? prefixes displayed; sensitive actions require confirmation. |
| Marginal annotations | Toasts interrupt reading and reset in unstable stacks. | Small opaque annotations align with the same margin and show severity in words as well as colour. | Close affordance; keyboard never stolen. Actions only appear after Claude provides actual invocation. |
| Quiet working folio | Rich idle desktops can compete with active windows. | The environmental mark is behind windows; only the reserved strip stays present. The selected workspace index and title keep context. | Click Open, Workspaces or Sound; no hover-to-reveal or new gesture. No fake focus border drawn over applications. |
| Sound passage | Device and media controls compete with decorative meters. | Actual output devices form a list; now-playing title has its own readable region. Track length remains unknown for a live tone. | Familiar track plus percentage, M mute, Enter default/play/route, previous/next labels; no abstract-only status. |

## What reaches prototypes

All three get a distinct background, entry composition, launcher, overview, real foot working state, notices and sound controls. Shared presentation primitives and unchanged service imports avoid three forks of systems infrastructure. Search and navigator key/confirmation functions are retained from production; audio service-call functions are retained too. “Idle” means the overlay is closed and the desktop is exposed; the mock still owns its seeded window records. A screenshot is not evidence of real window creation, secure locking or Hyprland animation.

Evaluation priorities: title legibility first; unmistakable compositional identity second; consistency from idle to sound third; bounded CPU and event-driven behavior throughout. Phase 4 will choose after rendering, with concrete shortcomings recorded. No hybrid is presumed in advance.
