fail() { echo "FAIL: $*"; exit 1; }
# Start at Configuration Loaded, capturing the actual one-shot assembly.
for i in 01 02 03 04 05 06; do shot "boot-$i"; sleep .25; done
sleep 2
shot ground
for bay in command navigator systems signal routines help settings ai; do
 ipc open "$bay"; sleep .7; shot "$bay"
 case "$bay" in
  command) typ foot; sleep .2; shot command-search; key Tab; sleep .25; shot command-scope ;;
  systems|signal|help|settings) key Next; sleep .25; shot "$bay-scroll" ;;
 esac
done
ipc close; sleep .3
ipc run shell.notify '{"message":"AEROLITH · system ready"}'
sleep .25; shot notice
alive || fail 'shell died'
echo 'gallery: ok'
