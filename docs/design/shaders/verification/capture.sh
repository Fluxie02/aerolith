# Fallback-only scene captures. Finite existing motion; no new visual clock.
sleep 5
shot 01-idle
mock '{"op":"focus_workspace","workspace":2}' > "$OUT/workspace-event.txt"
sleep .12; shot 02-workspace-motion
sleep .8; shot 03-workspace-settled
ipc open command
sleep .10; shot 04-deck-motion
sleep .6; shot 05-deck-docked
ipc open systems
sleep .12; shot 06-bay-motion
sleep .6; shot 07-bay-docked
ipc close
sleep 1
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.43
sleep .22; shot 08-osd
sleep 2
shot 09-carrier
alive
