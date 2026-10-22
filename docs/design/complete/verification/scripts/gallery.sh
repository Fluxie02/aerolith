# shellcheck shell=bash
sleep 3
shot g1-all-annunciators
ipc open command; sleep 1; shot g2-annunciators-over-deck
alive || exit 1
