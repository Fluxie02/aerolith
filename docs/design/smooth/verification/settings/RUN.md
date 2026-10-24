# Settings readout check

Result: **passed**, eight actual headless screenshots visually inspected.
The initial output's saved Sway mode is `1920x1080`, `refresh: 144000` mHz;
the compact capture uses `1280x720@144Hz`, scale 1, with `theme.uiScale: 1.25`.

- Full: `Motion: synced to 144 Hz` and `HEADLESS-1 · 144 Hz` are legible.
- Reduced: `Motion: reduced · synced to 144 Hz` remains legible.
- Off and lowEffects: motion state changes immediately; detected output
  refresh remains visible as metadata.
- Missing exact monitor: remove `HEADLESS-1` from the Hyprland mock while a
  second monitor remains; the readout becomes `Refresh rate unavailable`.
  It does not borrow the other monitor's advertised rate.
- Compact Register and Spectra retain readable controls and a persistent
  refresh readout. The existing lists/grids scroll when their contents exceed
  the available height.

`qs.log` contains no QML parse, type, reference, assignment or binding-loop
errors. This no-audio check records expected missing PipeWire/UPower and
unsupported Sway/Hyprland-protocol warnings, plus Qt/Sway focus notices from
synthetic keyboard input. The screenshots establish presentation and
reactivity; achieved frame rate is measured by the separate timing runs.

The exact initial command was run from the repository root after the
provisional `build/ui016/after-shell` snapshot and diagnostic session were
prepared. The mounted scenario is archived here as `scenario.sh`:

```sh
mkdir -p build/ui016/verification/settings
chmod 777 build/ui016/verification/settings
docker run --rm --cap-add=SYS_NICE \
  -v "$PWD:/src:ro" \
  -v "$PWD/build/ui016/verification/settings:/out" \
  -v /tmp/ui016-settings-capture.sh:/tmp/ui016-settings-capture.sh:ro \
  -e UI016_HZ=144 -e UI016_KIND=capture \
  -e SHELL_PATH=build/ui016/after-shell -e RES=1920x1080@144Hz \
  aerolith-dev bash -c '
    set -e
    id pilot >/dev/null 2>&1 || useradd -m -u 1000 pilot
    mkdir -p /run/user/1000 /home/pilot/.config/aerolith
    chown pilot /run/user/1000
    chmod 700 /run/user/1000
    echo "{\"schemaVersion\":1,\"theme\":{\"intensity\":\"saturated\",\"motion\":\"full\"}}" > /home/pilot/.config/aerolith/config.json
    chown -R pilot /home/pilot
    exec su pilot -c "bash /src/build/ui016/session.sh /tmp/ui016-settings-capture.sh"
  ' > build/ui016/verification/settings/result.txt 2>&1
```

For replay, first copy the archived `scenario.sh` to
`/tmp/ui016-settings-capture.sh`; the remaining command is unchanged. The
diagnostic mock's exact output-name match is deliberate; ordinary smoke
fixtures advertising a different monitor name correctly show unavailable
refresh metadata.
