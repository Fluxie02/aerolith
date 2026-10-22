sleep 4
ipc open command; sleep .6
key Tab
shot 01-full-start
sleep .05; shot 02-full-middle
sleep .2; shot 03-full-settled
ipc run settings.motion '{"motion":"reduced"}' >/dev/null
sleep .3
key Tab; shot 04-reduced-immediate
sleep .2; shot 05-reduced-settled
ipc run settings.motion '{"motion":"off"}' >/dev/null
sleep .3
key Tab; shot 06-off-immediate
sleep .2; shot 07-off-settled
ipc close; sleep .3
ipc open settings; sleep .4
shot 08-off-settings
alive
echo 'tabs-motion: ok'
