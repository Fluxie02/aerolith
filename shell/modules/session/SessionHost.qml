import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

// Host for the session menu (roadmap D06): lock, suspend, log out, reboot and
// power off through the existing Power commands.
//
// - SessionView owns the deliberate confirmation: a sensitive action needs a
//   second activation there. Only then does this host run the command, with
//   `confirmed`, so the registry does not ask a second time.
// - Availability is read from the registry each time the menu opens, so an
//   action that cannot run (no Hyprland for logout) is shown as unavailable
//   with its reason instead of failing after confirmation.
// - The surface exists only while the menu is open. It is an explicit
//   summons, so it also opens over a fullscreen window; it takes exclusive
//   keyboard focus while open and gives it back on close.
Scope {
    id: host

    readonly property var actionIds: ["session.lock", "system.suspend", "session.logout", "system.reboot", "system.poweroff"]
    property var actions: []

    function buildActions() {
        const ctx = {
            config: Config.data,
            now: Date.now()
        };
        const out = [];
        for (let i = 0; i < actionIds.length; i++) {
            const cmd = Registry.get(actionIds[i]);
            if (!cmd)
                continue;
            let avail = true;
            if (typeof cmd.available === "function") {
                try {
                    avail = cmd.available(ctx);
                } catch (e) {
                    avail = "Unavailable";
                }
            }
            out.push({
                id: cmd.id,
                label: cmd.title,
                sensitive: cmd.sensitive === true,
                available: avail === true,
                reason: avail === true ? "" : String(avail)
            });
        }
        return out;
    }

    function run(id) {
        Ui.sessionOpen = false;
        // Let the surface go before the action (a lock screen or logout must
        // not find the menu holding keyboard focus).
        Qt.callLater(() => Registry.execute(id, {}, {
                confirmed: true,
                origin: "session"
            }).then(r => {
                if (!r.ok)
                    Ui.report(r);
            }));
    }

    Connections {
        target: Ui
        function onSessionOpenChanged() {
            if (Ui.sessionOpen) {
                host.actions = host.buildActions();
                Ui.close();
            }
        }
        // Opening the Deck takes over from the menu.
        function onDeckOpenChanged() {
            if (Ui.deckOpen)
                Ui.sessionOpen = false;
        }
    }

    LazyLoader {
        active: Ui.sessionOpen && Ui.screen !== null
        PanelWindow {
            screen: Ui.screen
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "aerolith-session"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            onClosed: Ui.sessionOpen = false

            SessionView {
                anchors.fill: parent
                focus: true
                actions: host.actions
                onActivated: id => host.run(id)
                onCancelled: Ui.sessionOpen = false
            }
        }
    }
}
