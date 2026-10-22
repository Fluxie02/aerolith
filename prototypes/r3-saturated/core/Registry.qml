pragma Singleton

import QtQuick
import Quickshell
import "../lib/registry.mjs" as R

// QML front for the command registry (lib/registry.mjs). Services register
// commands and providers here; the Command Core, routines, IPC and the
// optional AI module all execute through execute().
Singleton {
    id: root

    // Bumped whenever commands/providers change, so bindings re-query.
    property int revision: 0

    // V4 has no setTimeout; give the registry Timer-backed scheduling so
    // slow commands can time out.
    readonly property var scheduler: ({
            setTimeout: (fn, ms) => {
                const t = timerComponent.createObject(root, {
                    interval: ms
                });
                t.triggered.connect(() => {
                    t.destroy();
                    fn();
                });
                t.start();
                return t;
            },
            clearTimeout: t => {
                if (t) {
                    t.stop();
                    t.destroy();
                }
            }
        })

    readonly property var api: R.createRegistry({
        scheduler: scheduler,
        historyLimit: 200,
        timeoutMs: 15000
    })

    Component {
        id: timerComponent
        Timer {}
    }

    Component.onCompleted: api.onChanged(() => revision++)

    function register(def, source) {
        return api.register(def, source);
    }

    function registerProvider(def, source) {
        return api.registerProvider(def, source);
    }

    function unregisterSource(source) {
        return api.unregisterSource(source);
    }

    // Context handed to availability checks, choices and run functions.
    function context() {
        return {
            config: Config.data,
            now: Date.now()
        };
    }

    function search(query, options) {
        const opts = options || {};
        return api.search(query, context(), {
            limit: opts.limit === undefined ? Config.commandCore.maxResults : opts.limit,
            scope: opts.scope || null,
            usage: key => Store.usageScore(key)
        });
    }

    // Execute and record. Resolves with { ok, message, ... }; never rejects.
    function execute(commandId, args, options) {
        const opts = options || {};
        return api.execute(commandId, args || {}, context(), opts).then(r => {
            if (opts.record !== false && !r.needsConfirmation) {
                const cmd = api.get(commandId);
                if (r.ok && cmd && cmd.record !== false)
                    Store.recordAction({
                        commandId: commandId,
                        args: args || {},
                        title: opts.title || (cmd ? cmd.title : commandId),
                        at: Date.now()
                    });
            }
            return r;
        });
    }

    // Execute and show the result as a notice.
    function run(commandId, args, options) {
        return execute(commandId, args, options).then(r => {
            if (r.needsConfirmation)
                Ui.notify(r.message, "caution");
            else
                Ui.report(r);
            return r;
        });
    }

    function get(id) {
        return api.get(id);
    }

    function list(filter) {
        return api.list(filter);
    }

    // Common result constructors for service code.
    function ok(message, extra) {
        return R.ok(message, extra);
    }
    function fail(message, extra) {
        return R.fail(message, extra);
    }
}
