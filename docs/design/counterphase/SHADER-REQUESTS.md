# COUNTERPHASE / UI-013 shading requests for Claude

No shader, blur, layer effect or GPU effect was added in UI-013. The current
geometry, state marks and readable surfaces stand on their own. These are
optional shading directions; S1 fullscreen teardown takes priority.

| Place | Look | Colours | Reacts to |
| --- | --- | --- | --- |
| The three/five SHEAR faces, especially the exposed leading plane | Very shallow directional mineral shading, making opposed bevels read as separate load-bearing skins; no external glow | Theme.bg, surface, surface2 and a restrained signal reflection; PIYTI reflection uses appLink | Workspace/focus impulse; carrier stroke only while Theme.ambient; otherwise a stable material |
| Left workspace annulus, behind the numeral | Etched relief at the fixed radial index and inner ring; keep the numeral's background dark and uniform | grid against bg, a fine signal edge at the real workspace registration | Actual focused workspace and occupancy changes; no synthetic radar sweep |
| Right return vernier and opposed datum rails | A very short recessed light catch around the existing native carrier, giving it thickness without enlarging its luminous footprint | signal in THEARS, appLink in PIYTI, surface2 recess | Existing finite escapement beat; reduced amplitude .07; off/lowEffects stays native and static |
| Deck undercarriage outside the rectangular functional bay | Grounded, shallow occlusion between the rigid bay and airframe; do not shade text or tab labels | bg through surface2; no tinted glass wash | Actual enter/exit/cross-bay transform; settle entirely after docking |

Use existing colour roles and the one `Theme.ambient` gate. Do not add an
independent animation clock. Keep native geometry as the fallback and retain
opaque lowEffects surfaces. Shader loaders/textures must unload with the
fullscreen suspension hook; measure real GPU memory rather than assuming
invisible means released. No textures or generated raster assets are needed.
