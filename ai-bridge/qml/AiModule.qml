import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core
import qs.services
import qs.components

// AEROLITH AI Bridge: shell side.
//
// Installed to <shell>/modules/ai/ only when the user chose an AI provider,
// and loaded by modules/AiLoader.qml. Everything it registers uses source
// "ai", so removing the directory removes every AI command.
//
// Flow for one request:
//   user types a prompt -> ask() starts bridge/aerolith-ai-bridge (lazily; no
//   process exists before or after) -> bridge calls the provider -> reply and
//   proposed actions come back -> each proposal is re-validated against the
//   live registry -> the user approves proposals one at a time -> approved
//   ones run through Registry.execute with origin "ai".
// Nothing is sent anywhere until the user submits a prompt.
Scope {
    id: ai

    readonly property string bridge: Quickshell.shellDir + "/modules/ai/bridge/aerolith-ai-bridge"
    property var cfg: null           // parsed ai.json (subset), null if missing/invalid
    property string cfgError: ""
    readonly property bool enabled: cfg !== null && cfg.enabled === true
    readonly property string providerId: cfg ? cfg.provider : ""
    readonly property var contextSwitches: cfg && cfg.context ? cfg.context : ({})
    readonly property var sharedContext: Object.keys(contextSwitches).filter(k => contextSwitches[k] === true)

    // Provider status from `aerolith-ai-bridge status` (local checks only).
    property var status: null
    property bool busy: false
    property real startedAt: 0
    property string lastPrompt: ""
    property var result: null        // last bridge result, proposals annotated
    property var transcript: []      // this session only, never written to disk

    // No AI bay without a valid ai.json (see commandsWanted below).
    readonly property Component bayComponent: cfg !== null ? consoleComponent : null
    Component {
        id: consoleComponent
        AiConsole {
            module: ai
        }
    }

    readonly property var providerNames: ({
            claude: "Claude Code",
            codex: "Codex",
            custom: "Custom provider"
        })
    readonly property string providerName: status && status.display ? status.display : (providerNames[providerId] || "AI provider")

    FileView {
        id: cfgFile
        path: Paths.aiConfigFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (!d || typeof d !== "object" || ["claude", "codex", "custom"].indexOf(d.provider) === -1)
                    throw new Error("unknown provider");
                ai.cfg = d;
                ai.cfgError = "";
            } catch (e) {
                ai.cfg = null;
                ai.cfgError = "ai.json is invalid: " + e.message;
            }
            ai.status = null;
        }
        onLoadFailed: {
            ai.cfg = null;
            ai.cfgError = "ai.json not found (run: aerolith ai configure)";
        }
    }

    // --- action catalogue and context ------------------------------------------

    // Only routine-capable, AI-allowed, non-sensitive commands can be proposed.
    function catalogue() {
        const list = Registry.list(c => c.routine === true && c.aiAllowed !== false && c.sensitive !== true && c.source !== "ai");
        return list.map(c => ({
                    id: c.id,
                    title: c.title,
                    params: (c.params || []).map(p => {
                        const o = {
                            name: p.name,
                            type: p.type,
                            required: p.required === true
                        };
                        if (p.min !== undefined)
                            o.min = p.min;
                        if (p.max !== undefined)
                            o.max = p.max;
                        if (p.type === "enum") {
                            const raw = typeof p.choices === "function" ? p.choices(Registry.context()) : p.choices;
                            o.choices = (raw || []).slice(0, 20).map(x => x && typeof x === "object" ? x.value : x);
                        }
                        return o;
                    })
                }));
    }

    // Only what the user switched on in ai.json. Off by default.
    function context() {
        const c = {};
        const on = contextSwitches;
        if (on.windowTitles)
            c.windowTitles = Compositor.windows().slice(0, 30).map(w => w.appId + ": " + w.title);
        if (on.workspaces)
            c.workspaces = Compositor.workspaces.map(w => ({
                        id: w.id,
                        windows: w.windows,
                        focused: w.focused
                    }));
        if (on.audioDevices)
            c.audioDevices = {
                outputs: Audio.sinks.map(n => n.name),
                defaultOutput: Audio.sink ? Audio.sink.name : null,
                volumePercent: Audio.volumePercent
            };
        if (on.mediaPlaying)
            c.mediaPlaying = Media.active ? {
                player: Media.active.identity,
                title: Media.title,
                artist: Media.artist,
                playing: Media.playing
            } : null;
        if (on.telemetrySummary)
            c.telemetrySummary = {
                cpuPercent: Telemetry.cpu.total,
                memoryPercent: Telemetry.memory ? Telemetry.memory.percent : null
            };
        return c;
    }

    // --- bridge processes --------------------------------------------------------

    Process {
        id: askProc
        command: [ai.bridge, "ask"]
        stdinEnabled: true
        stdout: StdioCollector {
            id: askOut
            onStreamFinished: ai.finish(text)
        }
        onExited: (code, status) => {
            if (ai.busy && code !== 0 && askOut.text.trim() === "")
                ai.finish("");
        }
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    ai.status = JSON.parse(text);
                } catch (e) {
                    ai.status = {
                        ok: false,
                        error: {
                            code: "bridge",
                            message: "AI bridge did not answer (is python3 installed?)"
                        }
                    };
                }
            }
        }
    }

    function refreshStatus(withAuth) {
        if (statusProc.running)
            return;
        statusProc.command = withAuth ? [bridge, "status", "--auth"] : [bridge, "status"];
        statusProc.running = true;
    }

    function ask(prompt) {
        const p = String(prompt || "").trim();
        if (p === "")
            return Registry.fail("Type a request first");
        if (!enabled)
            return Registry.fail(cfg ? "AI integration is disabled in ai.json" : cfgError);
        if (busy)
            return Registry.fail("A request is already running; press Esc to cancel it");
        lastPrompt = p;
        result = null;
        busy = true;
        startedAt = Date.now();
        const req = {
            version: 1,
            prompt: p,
            actions: (cfg.maxProposals === 0) ? [] : catalogue(),
            context: context()
        };
        askProc.running = true;
        askProc.write(JSON.stringify(req));
        askProc.stdinEnabled = false; // close stdin so the bridge sees EOF
        Log.info("ai", "request sent to " + providerId + " (" + p.length + " characters, context: " + (sharedContext.length ? sharedContext.join(", ") : "none") + ")");
        return Registry.ok("Asking " + providerName + "…");
    }

    function cancel() {
        if (askProc.running) {
            askProc.signal(15);
            Log.info("ai", "request cancelled by the user");
        }
    }

    function finish(text) {
        if (!busy)
            return;
        busy = false;
        askProc.stdinEnabled = true;
        let r;
        try {
            r = JSON.parse(text);
        } catch (e) {
            r = {
                ok: false,
                error: {
                    code: "bridge",
                    message: "The AI bridge ended without a result"
                }
            };
        }
        if (r.ok)
            r.proposals = (r.proposals || []).map(annotate);
        r.elapsedMs = Date.now() - startedAt;
        result = r;
        transcript = transcript.concat([{
                prompt: lastPrompt,
                result: r
            }]).slice(-20);
        Log.info("ai", r.ok ? "answer received (" + r.proposals.length + " proposals)" : "request failed: " + r.error.code);
    }

    // Second, independent validation of each proposal against the live
    // registry: known command, arguments valid now, command available now.
    function annotate(p) {
        const cmd = Registry.get(p.action);
        const v = Registry.api.validate(p.action, p.args, Registry.context());
        let avail = true;
        if (cmd && typeof cmd.available === "function") {
            const a = cmd.available(Registry.context());
            avail = a === true || a === undefined ? true : String(a);
        }
        const allowed = cmd && cmd.routine === true && cmd.aiAllowed !== false && cmd.sensitive !== true;
        return {
            action: p.action,
            args: v.ok ? v.values : p.args,
            reason: p.reason || "",
            title: cmd ? cmd.title : p.action,
            valid: !!cmd && allowed && v.ok,
            problem: !cmd ? "unknown action" : !allowed ? "not allowed for AI proposals" : !v.ok ? v.errors.map(e => e.param + " " + e.message).join("; ") : avail !== true ? "unavailable now: " + avail : "",
            available: avail === true,
            state: "proposed" // proposed | approved | done | failed | dismissed
        };
    }

    function approve(index) {
        if (!result || !result.ok || index < 0 || index >= result.proposals.length)
            return Promise.resolve(Registry.fail("No such proposal"));
        const p = result.proposals[index];
        if (!p.valid || !p.available || p.state !== "proposed")
            return Promise.resolve(Registry.fail("This proposal cannot be run: " + (p.problem || p.state)));
        setState(index, "approved");
        Log.info("ai", "user approved proposal " + p.action);
        return Registry.execute(p.action, p.args, {
            origin: "ai",
            title: "AI: " + p.title
        }).then(r => {
            ai.setState(index, r.ok ? "done" : "failed", r.message);
            return r;
        });
    }

    function dismiss(index) {
        if (result && result.proposals && result.proposals[index] && result.proposals[index].state === "proposed")
            setState(index, "dismissed");
    }

    function setState(index, state, message) {
        const r = Object.assign({}, result);
        r.proposals = result.proposals.slice();
        r.proposals[index] = Object.assign({}, r.proposals[index], {
            state: state,
            outcome: message || ""
        });
        result = r;
    }

    // --- commands ------------------------------------------------------------

    // Commands exist only while a valid ai.json exists. A machine where the
    // module is installed (e.g. by a system package) but this user chose
    // "None" has no ai.json, and sees no AI commands at all.
    property var unregisterFns: []
    readonly property bool commandsWanted: cfg !== null
    onCommandsWantedChanged: commandsWanted ? registerCommands() : unregisterCommands()

    function unregisterCommands() {
        for (let i = 0; i < unregisterFns.length; i++)
            unregisterFns[i]();
        unregisterFns = [];
    }

    function registerCommands() {
        if (unregisterFns.length > 0)
            return;
        const reg = (def, isProvider) => unregisterFns.push(isProvider ? Registry.registerProvider(def, "ai") : Registry.register(def, "ai"));
        reg({
            id: "ai.ask",
            title: "Ask AI",
            category: "ai",
            alias: "ai",
            keywords: ["assistant", "claude", "codex", "question"],
            description: "Send a request to the configured AI provider (explicit, visible)",
            params: [
                {
                    name: "prompt",
                    type: "string",
                    required: true,
                    maxLength: 4000
                }
            ],
            aiAllowed: false,
            record: false,
            available: () => ai.enabled ? (ai.busy ? "A request is running" : true) : (ai.cfg ? "AI integration is disabled in ai.json" : ai.cfgError),
            run: args => {
                Ui.open("ai");
                return ai.ask(args.prompt);
            }
        });
        reg({
            id: "ai.open",
            title: "Open AI Bridge",
            category: "ai",
            keywords: ["assistant", "claude", "codex"],
            aiAllowed: false,
            record: false,
            run: () => {
                Ui.open("ai");
                return Registry.ok("AI Bridge");
            }
        });
        reg({
            id: "ai.cancel",
            title: "Cancel AI request",
            category: "ai",
            aiAllowed: false,
            record: false,
            available: () => ai.busy ? true : "No AI request is running",
            run: () => {
                ai.cancel();
                return Registry.ok("Cancelling");
            }
        });
    }

    Component.onDestruction: {
        cancel();
        unregisterCommands();
    }

    // Global shortcut only on Hyprland; bound by the installer when AI is set up.
    LazyLoader {
        active: Compositor.available && ai.commandsWanted
        GlobalShortcut {
            appid: "aerolith"
            name: "ai"
            description: "AEROLITH: AI Bridge"
            onPressed: Ui.toggle("ai")
        }
    }

    // The console is an inline component: files loaded through a Loader
    // source do not resolve sibling QML types, so the module is one file.
    // AI-06 · AI Bridge console: the only place AI requests happen.
    //
    // Shows, before anything is sent: which provider, that it is a remote
    // service, and exactly which context (if any) goes with the prompt. While a
    // request runs it shows the active operation with elapsed time and Esc to
    // cancel. Proposals are listed with their validation result; each one must be
    // approved separately with A. Nothing runs automatically.
    component AiConsole: FocusScope {
        id: console_
        property var module: null
        property int selected: 0
        property bool inProposals: false
        property int tick: 0

        readonly property var result: module ? module.result : null
        readonly property var proposals: result && result.ok ? result.proposals : []

        Component.onCompleted: {
            if (module)
                module.refreshStatus(false);
            if (Ui.pendingQuery !== "")
                prompt.text = Ui.pendingQuery;
        }

        Timer {
            interval: 1000
            running: console_.module && console_.module.busy
            repeat: true
            onTriggered: console_.tick++
        }

        function errorText(r) {
            const hints = {
                not_installed: "Install the provider CLI or run: aerolith ai configure",
                not_authenticated: "Sign in with the provider's own command (claude / codex login) in a terminal",
                timeout: "Raise timeoutSeconds in ai.json if this provider is slow",
                incompatible_version: "Update AEROLITH or the provider CLI; see docs/INTEGRATIONS.md",
                config_error: "Check ~/.config/aerolith/ai.json (aerolith ai status)",
                disabled: "Enable with: aerolith ai enable"
            };
            return r.error.message + (hints[r.error.code] ? "  ·  " + hints[r.error.code] : "");
        }

        // Focus target while reviewing proposals. A FocusScope's
        // forceActiveFocus() hands focus back to the prompt, so keys go here
        // and propagate up to the handler below.
        Item {
            id: proposalKeys
        }

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape) {
                if (module && module.busy) {
                    module.cancel();
                    event.accepted = true;
                } else if (inProposals) {
                    inProposals = false;
                    prompt.forceActiveFocus();
                    event.accepted = true;
                }
                return;
            }
            if (k === Qt.Key_Tab && proposals.length > 0) {
                inProposals = !inProposals;
                if (!inProposals)
                    prompt.forceActiveFocus();
                else
                    proposalKeys.forceActiveFocus();
                event.accepted = true;
                return;
            }
            if (!inProposals)
                return;
            if (k === Qt.Key_Down || k === Qt.Key_J)
                selected = Math.min(proposals.length - 1, selected + 1);
            else if (k === Qt.Key_Up || k === Qt.Key_K)
                selected = Math.max(0, selected - 1);
            else if (k === Qt.Key_A)
                module.approve(selected);
            else if (k === Qt.Key_D)
                module.dismiss(selected);
            else
                return;
            event.accepted = true;
        }

        Bezel {
            anchors.centerIn: parent
            width: Math.min(Theme.px(1100), parent.width - Theme.pad * 4)
            height: Math.min(Theme.px(760), parent.height - Theme.pad)
            designation: "AI-06"
            title: "AI Bridge"
            status: {
                const s = console_.module ? console_.module.status : null;
                if (!console_.module || !console_.module.cfg)
                    return "NOT CONFIGURED";
                if (!console_.module.enabled)
                    return "DISABLED";
                if (!s)
                    return console_.module.providerName.toUpperCase() + " · CHECKING";
                if (!s.ok)
                    return "CONFIG PROBLEM";
                return console_.module.providerName.toUpperCase() + (s.remote ? " · REMOTE SERVICE" : " · LOCAL PROGRAM") + (s.installed ? " · " + (s.providerVersion || "installed") : " · NOT INSTALLED");
            }
            statusColor: console_.module && console_.module.enabled && console_.module.status && console_.module.status.installed ? Theme.textDim : Theme.caution

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.pad
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.gap

                // Data-flow disclosure, always visible before sending.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: disclosure.implicitHeight + Theme.pad
                    color: Theme.bg
                    border.color: Theme.grid
                    border.width: Theme.border
                    radius: Theme.radius
                    Column {
                        id: disclosure
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Theme.pad
                        spacing: Theme.px(2)
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            text: "SENT ON ⏎: your prompt + the list of allowed actions" + (console_.module && console_.module.sharedContext.length ? " + context: " + console_.module.sharedContext.join(", ") : " · no desktop context (enable per item in ai.json)")
                        }
                        Text {
                            visible: !!(console_.module && console_.module.status && console_.module.status.dataFlow)
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontXs
                            text: console_.module && console_.module.status ? (console_.module.status.dataFlow || "") : ""
                        }
                        Text {
                            visible: !!(console_.module && console_.module.status && console_.module.status.problem)
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: Theme.caution
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            text: console_.module && console_.module.status && console_.module.status.problem ? "⚠ " + console_.module.status.problem.message : ""
                        }
                    }
                }

                // Prompt
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(Theme.rowHeight * 1.25)
                    color: Theme.bg
                    border.color: prompt.activeFocus ? Theme.signal : Theme.grid
                    border.width: Theme.border
                    radius: Theme.radius
                    Text {
                        id: chevron
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.pad
                        anchors.verticalCenter: parent.verticalCenter
                        text: "?"
                        color: Theme.signal
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontLg
                    }
                    TextInput {
                        id: prompt
                        anchors.left: chevron.right
                        anchors.leftMargin: Theme.gap
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.pad
                        anchors.verticalCenter: parent.verticalCenter
                        focus: true
                        enabled: console_.module && !console_.module.busy
                        maximumLength: 4000
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontMd
                        clip: true
                        onAccepted: {
                            const r = console_.module.ask(text);
                            if (!r.ok)
                                Ui.report(r);
                            console_.selected = 0;
                        }
                        Text {
                            visible: prompt.text === ""
                            text: "Ask " + (console_.module ? console_.module.providerName : "the AI") + " — e.g. “set up a quiet focus session on workspace 3”"
                            color: Theme.textDim
                            font: prompt.font
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                // Active operation
                Text {
                    visible: !!(console_.module && console_.module.busy)
                    text: {
                        console_.tick;
                        return "◌ ACTIVE OPERATION · waiting for " + (console_.module ? console_.module.providerName : "") + " · " + Math.round((Date.now() - (console_.module ? console_.module.startedAt : 0)) / 1000) + " s · Esc cancels";
                    }
                    color: Theme.signal
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXs
                }

                // Reply
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 3
                    contentHeight: replyText.implicitHeight
                    clip: true
                    Text {
                        id: replyText
                        width: parent.width
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        color: console_.result && !console_.result.ok ? Theme.critical : Theme.text
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        text: !console_.result ? "" : console_.result.ok ? console_.result.reply : "FAULT · " + console_.errorText(console_.result)
                    }
                }
                Repeater {
                    model: console_.result && console_.result.ok ? (console_.result.warnings || []).slice(0, 3) : []
                    Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "note: " + modelData
                        color: Theme.caution
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontXs
                        elide: Text.ElideRight
                    }
                }

                // Proposals
                Label {
                    visible: console_.proposals.length > 0
                    text: "Proposed actions · nothing runs until you approve it (Tab, then A)"
                }
                Repeater {
                    model: console_.proposals
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool sel: console_.inProposals && index === console_.selected
                        Layout.fillWidth: true
                        implicitHeight: Math.round(Theme.rowHeight * 1.4)
                        color: sel ? Theme.surface2 : "transparent"
                        border.color: sel ? Theme.signal : Theme.grid
                        border.width: Theme.border
                        radius: Theme.radius
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.px(6)
                            spacing: Theme.gap
                            Text {
                                Layout.preferredWidth: Theme.px(90)
                                text: modelData.state === "done" ? "[ DONE ]" : modelData.state === "failed" ? "[ FAIL ]" : modelData.state === "dismissed" ? "[ SKIP ]" : modelData.state === "approved" ? "[ .... ]" : modelData.valid && modelData.available ? "[REVIEW]" : "[REJECT]"
                                color: modelData.state === "done" ? Theme.signal : modelData.state === "failed" || (!modelData.valid && modelData.state === "proposed") ? Theme.critical : Theme.caution
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontXs
                            }
                            Column {
                                Layout.fillWidth: true
                                Text {
                                    width: parent.width
                                    text: modelData.title + "  " + JSON.stringify(modelData.args)
                                    color: Theme.text
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontXs
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.outcome || modelData.problem || modelData.reason
                                    color: modelData.problem && modelData.state === "proposed" ? Theme.critical : Theme.textDim
                                    font.family: Theme.sans
                                    font.pixelSize: Theme.fontXs
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                text: modelData.action
                                color: Theme.textDim
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontXs
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console_.inProposals = true;
                                console_.selected = index;
                                proposalKeys.forceActiveFocus();
                            }
                        }
                    }
                }

                StatusLine {
                    Layout.fillWidth: true
                    hints: [
                        {
                            key: "⏎",
                            action: "send"
                        },
                        {
                            key: "TAB",
                            action: "proposals"
                        },
                        {
                            key: "A",
                            action: "approve"
                        },
                        {
                            key: "D",
                            action: "dismiss"
                        },
                        {
                            key: "ESC",
                            action: console_.module && console_.module.busy ? "cancel request" : "close"
                        }
                    ]
                    message: console_.result ? (console_.result.ok ? "answered in " + (console_.result.elapsedMs / 1000).toFixed(1) + " s" : console_.result.error.code) : ""
                    messageState: console_.result ? (console_.result.ok ? "ok" : "error") : ""
                }
            }
        }
    }
}
