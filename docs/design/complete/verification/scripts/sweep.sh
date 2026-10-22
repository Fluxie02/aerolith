# shellcheck shell=bash
sleep 3
shot 00-strip
for bay in command navigator systems signal routines help ai; do
 ipc open "$bay"; sleep 1.2; shot "01-$bay"
 if [ "$bay" = systems ] || [ "$bay" = help ] || [ "$bay" = signal ] || [ "$bay" = routines ]; then key Next; sleep .3; shot "02-$bay-scrolled"; fi
done
ipc close; sleep .5
ipc run shell.notify '{"message":"Flight register updated"}'; sleep .3; shot 03-notice
alive || exit 1
