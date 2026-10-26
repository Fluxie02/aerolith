pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "../lib/brightness.mjs" as B

// Display brightness (roadmap D02) through the kernel's backlight interface.
//
// - Detection: /sys/class/backlight is listed once at startup and the
//   preferred interface chosen (lib/brightness.mjs). Systems without one
//   (most desktops) report brightness as unavailable; nothing else runs.
// - Changes: `udevadm monitor` reports backlight change events, including
//   ones made by the firmware for a laptop's own brightness keys, so the
//   level is re-read on an event, never polled.
// - Setting: systemd-logind's Session.SetBrightness, which lets the active
//   session's user set the backlight without root; brightnessctl is the
//   fallback where logind refuses.
// External monitors (DDC/CI) are not handled here.
//
// AEROLITH_BACKLIGHT_ROOT replaces /sys/class/backlight for the headless
// tests, which have no backlight.
Singleton {
    id: root

    readonly property string sysRoot: Quickshell.env("AEROLITH_BACKLIGHT_ROOT") || "/sys/class/backlight"
    property string status: "probing" // probing | available | unavailable
    readonly property bool available: status === "available"
    property var device: null
    property int raw: 0
    readonly property real percent: available && device ? B.toPercent(raw, device.max) : NaN

    function probe() {
        return Exec.run(["sh", "-c", "for d in \"$1\"/*; do [ -r \"$d/max_brightness\" ] || continue; printf '%s\\t%s\\t%s\\t%s\\n' \"${d##*/}\" \"$(cat \"$d/type\" 2>/dev/null)\" \"$(cat \"$d/max_brightness\")\" \"$(cat \"$d/brightness\")\"; done", "probe", sysRoot], {
            timeoutMs: 3000
        }).then(r => {
            const d = B.pickDevice(B.parseDevices(r.stdout));
            device = d;
            raw = d ? d.value : 0;
            status = d ? "available" : "unavailable";
            Log.info("brightness", d ? "using backlight " + d.name + " (" + (d.type || "unknown type") + ", max " + d.max + ")" : "no backlight interface; brightness unavailable");
        });
    }

    function refresh() {
        if (!device)
            return Promise.resolve(false);
        return Exec.run(["cat", sysRoot + "/" + device.name + "/brightness"], {
            timeoutMs: 2000
        }).then(r => {
            const v = parseInt(r.stdout, 10);
            if (r.code === 0 && isFinite(v))
                raw = v;
            return r.code === 0;
        });
    }

    // Sets the level in percent (1-100); resolves a Registry result.
    function setPercent(level) {
        if (!available)
            return Promise.resolve(Registry.fail("No backlight to control on this system"));
        const target = B.fromPercent(level, device.max);
        const name = device.name;
        const logind = ["busctl", "--system", "--timeout=2", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", name, String(target)];
        return Exec.run(logind, {
            timeoutMs: 4000
        }).then(r => r.code === 0 ? r : Exec.run(["brightnessctl", "--quiet", "--device=" + name, "set", String(target)], {
                timeoutMs: 4000
            })).then(r => {
            if (r.code !== 0)
                return Registry.fail("Could not set brightness: neither logind nor brightnessctl accepted it");
            return refresh().then(() => Math.abs(raw - target) <= 1 ? Registry.ok("Brightness " + B.toPercent(target, device.max) + "%") : Registry.fail("The backlight did not take the new level"));
        });
    }

    Process {
        id: monitor
        running: root.available && root.sysRoot === "/sys/class/backlight"
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf(" change ") >= 0)
                    root.refresh();
            }
        }
    }

    readonly property var notAvailable: () => root.status === "unavailable" ? "No backlight to control on this system" : true

    Component.onCompleted: {
        probe();
        Registry.register({
            id: "brightness.set",
            title: "Set brightness",
            category: "system",
            alias: "bright",
            keywords: ["backlight", "screen", "display", "dim"],
            params: [
                {
                    name: "level",
                    type: "int",
                    min: 1,
                    max: 100,
                    required: true,
                    description: "Percent"
                }
            ],
            routine: true,
            available: notAvailable,
            run: args => root.setPercent(args.level)
        });
        Registry.register({
            id: "brightness.up",
            title: "Brightness up",
            category: "system",
            keywords: ["backlight", "brighter"],
            routine: true,
            available: notAvailable,
            run: () => root.setPercent(B.stepPercent(root.percent, 5))
        });
        Registry.register({
            id: "brightness.down",
            title: "Brightness down",
            category: "system",
            keywords: ["backlight", "dimmer"],
            routine: true,
            available: notAvailable,
            run: () => root.setPercent(B.stepPercent(root.percent, -5))
        });
    }
}
