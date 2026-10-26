import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.core

// Secure session lock (roadmap D07), opt-in with lock.enabled.
//
// Security model:
// - The lock is the Wayland ext-session-lock protocol (WlSessionLock). The
//   compositor, not the shell, keeps the session locked: if the shell
//   crashes or is killed while locked, the outputs stay locked.
// - Only a PAM result of Success unlocks. Failure, error, abort or a lost
//   conversation never does.
// - The password is held in one property only between submission and PAM
//   asking for it (normally the same event-loop turn), is handed to PAM and
//   cleared, and is never logged or written anywhere.
// - After five failures input pauses for 30 s, on top of PAM's own faillock.
// - Every output gets a lock surface; the prompt is on the shell's output,
//   the others show the plain background.
Scope {
    id: host

    readonly property int maxAttempts: 5
    readonly property int cooldownMs: 30000
    property int attempts: 0
    property string viewState: "idle" // idle | checking | failed | locked-out
    property string message: ""
    readonly property string userName: Quickshell.env("USER") || ""

    // The secret waits here only until PAM asks for it.
    property var secret: null
    // One PAM conversation per submission; results after it ended (an abort
    // can still report) are ignored, so a failure never counts twice.
    property bool conversing: false

    function submit(password) {
        if (viewState === "checking" || viewState === "locked-out")
            return;
        viewState = "checking";
        message = "";
        secret = password;
        conversing = true;
        if (!pam.start()) {
            conversing = false;
            fail("Could not start authentication");
        }
    }

    // End the conversation without unlocking.
    function stop(text) {
        conversing = false;
        if (pam.active)
            pam.abort();
        fail(text);
    }

    function fail(text) {
        secret = null;
        attempts++;
        if (attempts >= maxAttempts) {
            viewState = "locked-out";
            message = "Too many attempts. Try again in " + Math.round(cooldownMs / 1000) + " seconds.";
            cooldown.restart();
        } else {
            viewState = "failed";
            message = text;
        }
    }

    function reset() {
        secret = null;
        conversing = false;
        if (pam.active)
            pam.abort();
        cooldown.stop();
        attempts = 0;
        viewState = "idle";
        message = "";
    }

    PamContext {
        id: pam
        // /etc/pam.d/login: the password the user logs in with. Only the
        // auth stack runs; no session is opened.
        config: "login"
        user: host.userName
        onResponseRequiredChanged: {
            if (!responseRequired || !host.conversing)
                return;
            // Only a hidden prompt gets the password. A visible prompt (a user
            // name, a one-time code) or a second prompt is a step this lock
            // screen does not support: stop rather than send the password
            // where it would be shown or reused.
            if (responseVisible || host.secret === null) {
                host.stop("This sign-in needs a step the lock screen does not support");
                return;
            }
            const s = host.secret;
            host.secret = null;
            respond(s);
        }
        onCompleted: result => {
            if (!host.conversing)
                return;
            host.conversing = false;
            host.secret = null;
            if (result === PamResult.Success) {
                Log.info("lock", "unlocked");
                host.reset();
                Ui.locked = false;
            } else {
                Log.info("lock", "authentication failed");
                host.fail(result === PamResult.MaxTries ? "Too many attempts for PAM" : "Wrong password");
            }
        }
        onError: error => {
            if (!host.conversing)
                return;
            host.conversing = false;
            host.secret = null;
            Log.warn("lock", "authentication error " + error);
            host.fail("Authentication is not available");
        }
    }

    Timer {
        id: cooldown
        interval: host.cooldownMs
        onTriggered: {
            host.attempts = 0;
            host.viewState = "idle";
            host.message = "";
        }
    }

    // For diagnostics and tests (ControlSurface status); no secrets.
    Binding {
        target: Ui
        property: "lockState"
        value: Ui.locked ? host.viewState : ""
    }
    Binding {
        target: Ui
        property: "lockAttempts"
        value: host.attempts
    }

    Connections {
        target: Ui
        function onLockedChanged() {
            if (Ui.locked) {
                Log.info("lock", "locking");
                host.reset();
                Ui.close();
                Ui.sessionOpen = false;
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: Ui.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.bg

            LockView {
                anchors.fill: parent
                visible: surface.screen === Ui.screen || Ui.screen === null
                focus: visible
                state: host.viewState
                message: host.message
                user: host.userName
                attempts: host.attempts
                onSubmitted: password => host.submit(password)
            }
        }
    }
}
