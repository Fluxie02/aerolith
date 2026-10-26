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
// - Only a PAM result of Success unlocks. Failure, error, abort, a lost or
//   stalled conversation, a configuration reload and writes to Ui never do:
//   the protocol lock follows `kept.locked`, which only this file writes.
// - The lock command reports success only once the compositor confirms the
//   lock (`secure`), and failure if it does not within acquireMs.
// - The password is held in one property only between submission and PAM
//   asking for it (normally the same event-loop turn), is handed to PAM for
//   one hidden prompt and cleared, and is never logged or written anywhere.
//   A visible or second prompt ends the attempt.
// - After five failures input pauses for 30 s, on top of PAM's own faillock.
// - Every output gets a lock surface; the prompt is on the shell's output,
//   the others show the plain background.
Scope {
    id: host

    // Survives a configuration reload. It must stay the first child: Scope
    // reloads its children in order, matched by position (Quickshell 0.3.2,
    // ReloadPropagator::onReload), so this state is back before the lock
    // below reloads. A fresh lock reading `false` would release the
    // compositor lock it takes over, without authentication.
    PersistentProperties {
        id: kept
        property bool locked: false
        property int attempts: 0
        property real cooldownUntil: 0 // epoch ms; 0 when no pause
        onReloaded: host.restore()
    }

    readonly property int maxAttempts: 5
    readonly property int cooldownMs: 30000
    readonly property int acquireMs: 3000
    readonly property int conversationMs: 20000
    property string viewState: "idle" // idle | checking | failed | locked-out
    property string message: ""
    readonly property string userName: Quickshell.env("USER") || ""

    // The secret waits here only until PAM asks for it.
    property var secret: null
    // One PAM conversation per submission; results after it ended (an abort
    // can still report) are ignored, so a failure never counts twice.
    property bool conversing: false
    // Lock requests waiting for the compositor: functions (ok, text).
    property var waiting: []

    function request(done) {
        if (kept.locked && lock.secure) {
            done(true, "Already locked");
            return;
        }
        waiting.push(done);
        if (!kept.locked) {
            Log.info("lock", "locking");
            reset();
            Ui.close();
            Ui.sessionOpen = false;
            kept.locked = true;
        }
        // One deadline per acquisition: a repeated request does not extend it.
        if (!acquire.running)
            acquire.start();
    }

    // The compositor ended the lock (another locker, or ext-session-lock
    // "finished"), confirmed or not: follow it. Only once no protocol lock
    // object is left, so clearing the state sends no unlock request.
    function followCompositor() {
        if (!kept.locked || lock.locked || lock.secure)
            return;
        Log.warn("lock", "the compositor ended the lock");
        reset();
        kept.locked = false;
        settle(false, "The compositor ended the lock");
    }

    function settle(ok, text) {
        const w = waiting;
        waiting = [];
        acquire.stop();
        for (let i = 0; i < w.length; i++)
            w[i](ok, text);
    }

    function restore() {
        const left = kept.cooldownUntil - Date.now();
        if (kept.locked && left > 0) {
            startCooldown(left);
        } else if (kept.cooldownUntil !== 0) {
            kept.cooldownUntil = 0;
            kept.attempts = 0;
        }
        Log.info("lock", "reloaded; " + (kept.locked ? "locked" : "unlocked"));
    }

    function submit(password) {
        // Nothing is checked before the compositor holds the lock.
        if (!lock.secure || viewState === "checking" || viewState === "locked-out")
            return;
        viewState = "checking";
        message = "";
        secret = password;
        conversing = true;
        watchdog.restart();
        if (!pam.start()) {
            conversing = false;
            watchdog.stop();
            fail("Could not start authentication");
        }
    }

    // End the conversation without unlocking.
    function stop(text) {
        Log.warn("lock", "authentication stopped: " + text);
        conversing = false;
        watchdog.stop();
        if (pam.active)
            pam.abort();
        fail(text);
    }

    function fail(text) {
        secret = null;
        kept.attempts++;
        if (kept.attempts >= maxAttempts)
            startCooldown(cooldownMs);
        else {
            viewState = "failed";
            message = text;
        }
    }

    function startCooldown(ms) {
        kept.cooldownUntil = Date.now() + ms;
        viewState = "locked-out";
        message = "Too many attempts. Try again in " + Math.round(ms / 1000) + " seconds.";
        cooldown.interval = Math.max(1, ms);
        cooldown.restart();
    }

    function reset() {
        secret = null;
        conversing = false;
        watchdog.stop();
        if (pam.active)
            pam.abort();
        cooldown.stop();
        kept.attempts = 0;
        kept.cooldownUntil = 0;
        viewState = "idle";
        message = "";
    }

    PamContext {
        id: pam
        // /etc/pam.d/login: the password the user logs in with. Only the
        // auth stack runs; no session is opened.
        config: "login"
        user: host.userName
        // pamMessage fires for every PAM message; responseRequiredChanged
        // would miss a second prompt right after the first.
        onPamMessage: {
            if (!host.conversing || !responseRequired)
                return;
            // Only a hidden prompt gets the password, once. A visible prompt
            // (a user name, a one-time code) or a second prompt is a step
            // this lock screen does not support: stop rather than send the
            // password where it would be shown or reused.
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
            watchdog.stop();
            if (result === PamResult.Success) {
                Log.info("lock", "unlocked");
                host.reset();
                kept.locked = false;
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
            watchdog.stop();
            Log.warn("lock", "authentication error " + error);
            host.fail("Authentication is not available");
        }
    }

    // A conversation that never finishes (a hung module, a prompt this
    // screen cannot see) is ended without unlocking.
    Timer {
        id: watchdog
        interval: host.conversationMs
        onTriggered: if (host.conversing)
            host.stop("Authentication took too long")
    }

    Timer {
        id: cooldown
        onTriggered: {
            kept.attempts = 0;
            kept.cooldownUntil = 0;
            host.viewState = "idle";
            host.message = "";
        }
    }

    // The compositor has acquireMs to confirm a requested lock. Past that,
    // the waiting commands fail, but a pending protocol lock is never
    // withdrawn: before `locked` an unlock is a protocol error, and a
    // confirmation already on its way would be undone without PAM. Only a
    // lock Quickshell never created (no protocol object) is cleared.
    Timer {
        id: acquire
        interval: host.acquireMs
        onTriggered: {
            if (lock.secure)
                return;
            if (!lock.locked) {
                Log.warn("lock", "the compositor refused the lock");
                host.reset();
                kept.locked = false;
                host.settle(false, "The compositor did not lock the session");
            } else {
                Log.warn("lock", "the compositor has not confirmed the lock yet; still waiting");
                host.settle(false, "The compositor has not confirmed the lock yet");
            }
        }
    }

    Connections {
        target: lock
        function onSecureStateChanged() {
            if (lock.secure)
                host.settle(true, "Locked");
            else if (kept.locked)
                // Quickshell drops its lock object after this signal.
                Qt.callLater(host.followCompositor);
        }
    }

    Connections {
        target: Ui
        function onLockRequested(done) {
            host.request(done);
        }
    }

    // No configuration reload while locked. Quickshell 0.3.2 recreates the
    // lock surfaces on reload without reusing the old windows
    // (WlSessionLock::realizeLockTarget calls updateSurfaces without the old
    // instance), the compositor rejects the duplicate surface and the shell
    // exits, leaving the session locked with no prompt. So file watching
    // pauses for the duration of the lock; `kept` above still makes a
    // reload that happens anyway fail closed rather than open.
    Binding {
        target: Quickshell
        property: "watchFiles"
        value: !kept.locked
    }

    // For the shell and diagnostics (ControlSurface status); no secrets.
    Binding {
        target: Ui
        property: "locked"
        value: kept.locked
    }
    Binding {
        target: Ui
        property: "lockSecure"
        value: lock.secure
    }
    Binding {
        target: Ui
        property: "lockState"
        value: kept.locked ? host.viewState : ""
    }
    Binding {
        target: Ui
        property: "lockAttempts"
        value: kept.attempts
    }

    WlSessionLock {
        id: lock
        locked: kept.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.bg

            // The view sits in a Loader so that a problem creating it can
            // never fail the surface: Quickshell 0.3.2 releases the whole
            // lock when a surface cannot be created (on output hotplug too).
            Loader {
                anchors.fill: parent
                active: surface.screen === Ui.screen || Ui.screen === null
                focus: active
                onStatusChanged: if (status === Loader.Error)
                    Log.warn("lock", "the lock view failed to load; the session stays locked")
                sourceComponent: LockView {
                    focus: true
                    state: host.viewState
                    message: host.message
                    user: host.userName
                    attempts: kept.attempts
                    onSubmitted: password => host.submit(password)
                }
            }
        }
    }
}
