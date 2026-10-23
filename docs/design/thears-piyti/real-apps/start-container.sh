#!/usr/bin/env bash
# Run from the repository root. Installation exists only in this --rm layer.
# The read-only host CA bundle trusts this environment's HTTPS proxy.
set -euo pipefail
out="$PWD/docs/design/thears-piyti/real-apps"
mkdir -p "$out"
chmod 777 "$out"
rm -f "$out/install.ready"
docker run --rm -d --name aerolith-ui012-apps --cap-add=SYS_NICE \
  -v "$PWD:/src:ro" -v "$out:/out" \
  -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/cert.pem:ro \
  aerolith-dev bash -c '
    set -e
    pacman -Sy --noconfirm firefox libreoffice-fresh >/out/install.log 2>&1
    pacman -Scc --noconfirm >>/out/install.log 2>&1
    id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
    mkdir -p /run/user/1000
    chown pilot /run/user/1000
    chmod 700 /run/user/1000
    touch /out/install.ready
    tail -f /dev/null'
# Run capture commands once install.ready appears. Always finish with:
# docker stop aerolith-ui012-apps
