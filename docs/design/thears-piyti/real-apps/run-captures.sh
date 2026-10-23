#!/usr/bin/env bash
# After start-container.sh finishes. Every process and package stays inside
# the disposable container. No accounts, host configuration or image commit.
set -euo pipefail
docker exec aerolith-ui012-apps python3 /src/docs/design/thears-piyti/real-apps/prepare.py
docker exec aerolith-ui012-apps chown -R pilot:pilot /home/pilot
for direction in thears piyti; do
  docker exec aerolith-ui012-apps su pilot -c \
    "unopkg -env:UserInstallation=file:///home/pilot/libreoffice-$direction add --force --suppress-license /tmp/aerolith-appearance.oxt" \
    >"docs/design/thears-piyti/real-apps/unopkg-$direction.log" 2>&1
  docker exec aerolith-ui012-apps bash -c 'pkill -u 1000 || true; rm -f /run/user/1000/bus /run/user/1000/wayland-* /run/user/1000/sway-ipc.*.sock'
  shell_path=shell
  [ "$direction" = piyti ] && shell_path=build/ui012/piyti-shell
  docker exec aerolith-ui012-apps bash -c \
    "mkdir -p /out/$direction /home/pilot/.config/aerolith; cp /home/pilot/$direction.json /home/pilot/.config/aerolith/config.json; chown -R pilot:pilot /home/pilot /out/$direction"
  docker exec aerolith-ui012-apps su pilot -c \
    "DIRECTION=$direction OUT=/out/$direction RES=1920x1080 SHELL_PATH=$shell_path HYPR_MOCK=1 bash /src/tools/headless/session.sh /src/docs/design/thears-piyti/real-apps/capture.sh" \
    >"docs/design/thears-piyti/real-apps/capture-$direction.log" 2>&1
done
# Stop separately after reviewing images/logs: docker stop aerolith-ui012-apps
