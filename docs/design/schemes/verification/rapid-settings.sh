# Exercise deferred containment across immediate bay creation and destruction.
set -e
sleep 3
for i in $(seq 1 20); do
  ipc open settings >/dev/null
  ipc open command >/dev/null
  ipc close
 done
ipc open settings >/dev/null
sleep .5
key End
sleep .15
key Return
sleep .3
shot rapid-settings-settled
alive || exit 1
echo 'rapid Settings containment: 20 open/switch/close cycles, survived and selected'
