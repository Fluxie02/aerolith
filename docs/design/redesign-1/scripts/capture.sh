# The same quiet desktop state used before and after the redesign.
sleep 5
shot desktop
ipc status >"$OUT/status.json"
alive || exit 1
