#!/usr/bin/env bash
clear
printf '\n  \033[1;32mAEROLITH\033[0m   /   Terminal\n\n'
printf '  One palette. Your usual tools.\n\n'
printf '  \033[90mSystem\033[0m     '; uname -srm
printf '  \033[90mUser\033[0m       '; id -un
printf '  \033[90mDirectory\033[0m  %s\n\n' "$PWD"
printf '  \033[32m● Ready\033[0m   \033[33m● Caution\033[0m   \033[31m● Error\033[0m   \033[36m● Information\033[0m\n\n'
printf '  \033[90mApplication themes\033[0m\n'
ls --color=always /src/themes
printf '\n  \033[90mANSI colour register\033[0m\n  '
for i in {0..15}; do printf '\033[38;5;%sm%02d  ' "$i" "$i"; done
printf '\033[0m\n\n  \033[32mpilot\033[0m@aerolith \033[36m~\033[0m $ '
sleep 30
