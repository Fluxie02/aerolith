pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.core
import "../lib/hyprdispatch.mjs" as HD

// Battery (UPower), power profiles (power-profiles-daemon) and session
// actions. UPower and power-profiles-daemon are optional: their absence is
// detected and reported, never treated as an error.
Singleton {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property real batteryPercent: hasBattery ? battery.percentage : NaN
    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property real timeToEmpty: hasBattery ? battery.timeToEmpty : 0

    // power-profiles-daemon presence is probed on the system bus once,
    // lazily, the first time a profile command needs it.
    property string profilesStatus: "unknown" // unknown | probing | available | unavailable
    readonly property string profileName: profilesStatus === "available" ? profileToName(PowerProfiles.profile) : ""

    function profileToName(p) {
        if (p === PowerProfile.Performance)
            return "performance";
        if (p === PowerProfile.PowerSaver)
            return "power-saver";
        return "balanced";
    }

    function nameToProfile(n) {
        if (n === "performance")
            return PowerProfile.Performance;
        if (n === "power-saver")
            return PowerProfile.PowerSaver;
        return PowerProfile.Balanced;
    }

    function probeProfiles() {
        if (profilesStatus === "available" || profilesStatus === "unavailable")
            return Promise.resolve(profilesStatus === "available");
        profilesStatus = "probing";
        return Exec.run(["busctl", "--system", "--timeout=2", "get-property", "org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles", "org.freedesktop.UPower.PowerProfiles", "ActiveProfile"], {
            timeoutMs: 4000
        }).then(r => {
            profilesStatus = r.code === 0 ? "available" : "unavailable";
            return r.code === 0;
        });
    }

    function setProfile(name) {
        return probeProfiles().then(present => {
            if (!present)
                return Registry.fail("power-profiles-daemon is not running");
            if (name === "performance" && !PowerProfiles.hasPerformanceProfile)
                return Registry.fail("This system has no performance profile");
            const before = profileToName(PowerProfiles.profile);
            const want = nameToProfile(name);
            PowerProfiles.profile = want;
            return Wait.until(() => PowerProfiles.profile === want, 3000).then(okay => okay ? Registry.ok("Power profile: " + name, {
                    undo: before !== name ? {
                        commandId: "power.profile.set",
                        args: {
                            profile: before
                        }
                    } : undefined
                }) : Registry.fail("power-profiles-daemon did not switch to " + name));
        });
    }

    function runChecked(argv, okMessage) {
        return Exec.run(argv, {
            timeoutMs: 15000
        }).then(r => r.code === 0 ? Registry.ok(okMessage) : Registry.fail(argv[0] + " failed (" + (r.timedOut ? "timed out" : "status " + r.code) + ")", {
                detail: r.stderr.trim().slice(0, 300)
            }));
    }

    Component.onCompleted: {
        Registry.register({
            id: "power.profile.set",
            title: "Set power profile",
            category: "system",
            alias: "power",
            keywords: ["performance", "balanced", "battery", "saver", "profile"],
            params: [
                {
                    name: "profile",
                    type: "enum",
                    required: true,
                    choices: ["balanced", "performance", "power-saver"]
                }
            ],
            routine: true,
            available: () => root.profilesStatus === "unavailable" ? "power-profiles-daemon is not running" : true,
            run: args => root.setProfile(args.profile)
        });
        Registry.register({
            id: "session.lock",
            title: "Lock session",
            category: "system",
            alias: "lock",
            keywords: ["lock", "screen", "away"],
            description: "loginctl lock-session (needs a locker such as hyprlock via hypridle)",
            routine: true,
            run: () => root.runChecked(["loginctl", "lock-session"], "Lock requested")
        });
        Registry.register({
            id: "system.suspend",
            title: "Suspend",
            category: "system",
            keywords: ["sleep", "standby"],
            sensitive: true,
            aiAllowed: false,
            run: () => root.runChecked(["systemctl", "suspend"], "Suspending")
        });
        Registry.register({
            id: "system.reboot",
            title: "Reboot",
            category: "system",
            keywords: ["restart"],
            sensitive: true,
            aiAllowed: false,
            run: () => root.runChecked(["systemctl", "reboot"], "Rebooting")
        });
        Registry.register({
            id: "system.poweroff",
            title: "Power off",
            category: "system",
            keywords: ["shutdown", "halt"],
            sensitive: true,
            aiAllowed: false,
            run: () => root.runChecked(["systemctl", "poweroff"], "Powering off")
        });
        Registry.register({
            id: "session.logout",
            title: "Log out (exit Hyprland)",
            category: "system",
            keywords: ["exit", "quit", "logout"],
            sensitive: true,
            aiAllowed: false,
            available: () => Compositor.available ? true : "Hyprland is not running",
            run: () => Compositor.dispatch(d => HD.exitSession(d)).then(r => r.ok ? Registry.ok("Exiting Hyprland") : Registry.fail(r.message))
        });
    }
}
