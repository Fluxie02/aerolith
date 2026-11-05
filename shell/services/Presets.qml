pragma Singleton

import QtQuick
import Quickshell
import qs.core
import "../lib/presets.mjs" as P

// Service only: the Settings owner supplies presentation. Synchronous preview
// returns an error string ("" means accepted). File operations return a promise
// of the same string, also exposing busy/error and completed for QML callers.
Singleton {
    id: root
    property var users: []
    property bool ready: false
    property bool busy: false
    property string error: ""
    property string lastBackup: ""
    signal completed(string action, bool ok, string detail)

    // Bounded file I/O, argv only. Match the installer's state/backups/<stamp>/
    // config.json convention; mkdtemp adds collision resistance and mode 0700.
    // Copy the exact fresh-read snapshot before Config submits its atomic write.
    readonly property string ioScript: [
        "import os,sys,json,tempfile,datetime,stat",
        "from pathlib import Path",
        "op,path=sys.argv[1:3]; p=Path(path); limit=65536",
        "if op=='read':",
        " if not p.exists(): sys.exit(3)",
        " if not stat.S_ISREG(p.stat().st_mode): raise ValueError('Expected a regular file')",
        " with p.open('rb') as f: data=f.read(limit+1)",
        " if len(data)>limit: raise ValueError('File exceeds 65536 bytes')",
        " sys.stdout.write(data.decode('utf-8'))",
        "elif op=='backup':",
        " p.mkdir(parents=True,exist_ok=True,mode=0o700)",
        " stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f-')",
        " folder=Path(tempfile.mkdtemp(prefix=stamp,dir=p))",
        " with (folder/'config.json').open('x',encoding='utf-8') as f:",
        "  os.chmod(f.name,0o600); f.write(sys.argv[3]); f.flush(); os.fsync(f.fileno())",
        " print(json.dumps({'path':str(folder/'config.json')}))",
        "elif op in ('write','export'):",
        " if op=='export' and os.path.realpath(p) in [os.path.realpath(x) for x in sys.argv[4:]]: raise ValueError('Choose a separate preset export file')",
        " data=sys.argv[3].encode('utf-8')",
        " if len(data)>limit: raise ValueError('File exceeds 65536 bytes')",
        " fd,tmp=tempfile.mkstemp(prefix='.'+p.name+'-',dir=p.parent)",
        " try:",
        "  with os.fdopen(fd,'wb') as f: f.write(data); f.flush(); os.fsync(f.fileno())",
        "  os.replace(tmp,p)",
        " finally:",
        "  if os.path.exists(tmp): os.unlink(tmp)",
        " print('{}')",
        "else: raise ValueError('Unknown file operation')"
    ].join("\n")

    function fileJob(op, path, text) {
        if (typeof path !== "string" || path[0] !== "/" || path.length > 4096 || path.indexOf("\0") >= 0)
            return Promise.resolve({error: "Choose an absolute file path"});
        return Exec.run(["python3", "-c", ioScript, op, path, text || "",
            Paths.configFile, Paths.presetsFile, Paths.installationFile, Paths.routinesFile, Paths.aiConfigFile],
            {timeoutMs: 5000, maxOutput: P.MAX_BYTES}).then(result => {
                if (op === "read" && result.code === 3) return {missing: true};
                if (result.code !== 0) return {error: result.stderr.trim() || "Preset file operation failed"};
                if (op === "read") return {text: result.stdout};
                try { return JSON.parse(result.stdout); }
                catch (e) { return {error: "Invalid preset file response"}; }
            });
    }
    function finish(action, message) {
        error = message || "";
        busy = false;
        completed(action, !error, error);
        return error;
    }
    function available() { return busy ? "Wait for the current preset operation" : !ready ? "Wait for presets to load" : ""; }
    function list() { return P.builtins().concat(users).map(p => ({id: p.id, name: p.name, builtin: p.builtin === true})); }
    function reload() {
        if (busy) return Promise.resolve("Wait for the current preset operation");
        busy = true;
        return fileJob("read", Paths.presetsFile, "").then(result => {
            const checked = result.error ? result : result.missing ? {presets: []} : P.readStore(result.text);
            ready = !checked.error;
            if (ready) users = checked.presets;
            return finish("load", checked.error);
        });
    }
    function stage(checked, imported) {
        if (checked.error) return error = checked.error;
        let message = "";
        const began = !Config.previewActive;
        if (began) message = Config.beginPreview();
        if (!message) message = Config.setPreviewValues(checked.values);
        if (message) {
            if (began && Config.previewActive) Config.cancelPreview();
            return error = message;
        }
        // Preserve an existing import guard when another preset is layered on
        // that draft. Cancel/Apply and the next begin clear it in Config.
        if (imported) Config.previewBeforeWrite = text => root.backup(text);
        error = "";
        return "";
    }
    function preview(id) {
        const message = available();
        if (message) return error = message;
        const preset = P.builtins().concat(users).find(p => p.id === id);
        if (!preset) return error = "Unknown preset: " + id;
        return stage(P.validate(JSON.stringify({formatVersion: P.FORMAT_VERSION, name: preset.name, values: preset.values})), false);
    }
    function persist(next, action) {
        const encoded = P.writeStore(next);
        if (encoded.error) return Promise.resolve(finish(action, encoded.error));
        busy = true;
        return fileJob("write", Paths.presetsFile, encoded.text).then(result => {
            if (!result.error) users = next;
            return finish(action, result.error);
        });
    }
    function saveCurrent(name, includeOutputs) {
        const message = available();
        if (message) return Promise.resolve(error = message);
        const encoded = P.encode(Config.data, name, includeOutputs === true);
        if (encoded.error) return Promise.resolve(error = encoded.error);
        if (users.length >= P.MAX_PRESETS) return Promise.resolve(error = "At most " + P.MAX_PRESETS + " user presets are allowed");
        let id;
        do { id = "user-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 12); }
        while (users.some(p => p.id === id));
        return persist(users.concat([{id: id, name: encoded.preset.name, values: encoded.preset.values}]), "save");
    }
    function remove(id) {
        const message = available();
        if (message) return Promise.resolve(error = message);
        if (!users.some(p => p.id === id)) return Promise.resolve(error = "Only user presets can be removed");
        return persist(users.filter(p => p.id !== id), "remove");
    }
    function importFile(path) {
        const message = available();
        if (message) return Promise.resolve(error = message);
        busy = true;
        return fileJob("read", path, "").then(result => {
            const message = result.error || (result.missing ? "Preset file does not exist" : stage(P.validate(result.text), true));
            return finish("import", message);
        });
    }
    function exportFile(path, includeOutputs) {
        const message = available();
        if (message) return Promise.resolve(error = message);
        // Avoid overwriting the live configuration/store or installation files.
        if ([Paths.configFile, Paths.presetsFile, Paths.installationFile, Paths.routinesFile, Paths.aiConfigFile].indexOf(path) >= 0)
            return Promise.resolve(error = "Choose a separate preset export file");
        const encoded = P.encode(Config.data, "Exported appearance", includeOutputs === true);
        if (encoded.error) return Promise.resolve(error = encoded.error);
        busy = true;
        return fileJob("export", path, encoded.text).then(result => finish("export", result.error));
    }
    function backup(text) {
        return fileJob("backup", Paths.stateDir + "/backups", text).then(result => {
            if (result.error) return "Could not back up configuration: " + result.error;
            lastBackup = result.path;
            return "";
        });
    }
    Component.onCompleted: reload()
}
