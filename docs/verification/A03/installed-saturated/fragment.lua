-- AEROLITH Hyprland integration. Managed file, written by `aerolith` on 2026-10-26.
-- Edits here are replaced on the next `aerolith hypr apply`; change keys in
-- ~/.config/aerolith/hypr-binds.json instead. Remove with `aerolith uninstall`.

hl.on("hyprland.start", function()
  hl.exec_cmd("'/usr/sbin/qs' -p '/home/pilot/.local/share/aerolith/shell'")
end)

hl.bind("SUPER + SPACE", hl.dsp.global("aerolith:command"), { description = "AEROLITH: Command Core" })
hl.bind("SUPER + TAB", hl.dsp.global("aerolith:navigator"), { description = "AEROLITH: Spatial Navigator" })
hl.bind("SUPER + F9", hl.dsp.global("aerolith:systems"), { description = "AEROLITH: Systems Bay" })
hl.bind("SUPER + F10", hl.dsp.global("aerolith:signal"), { description = "AEROLITH: Signal Rack" })
hl.bind("SUPER + F11", hl.dsp.global("aerolith:routines"), { description = "AEROLITH: Routine Console" })
hl.bind("SUPER + F12", hl.dsp.global("aerolith:ai"), { description = "AEROLITH: AI Bridge" })
