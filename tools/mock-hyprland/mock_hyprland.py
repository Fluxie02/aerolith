#!/usr/bin/env python3
"""A protocol-level mock of Hyprland's IPC sockets, for tests only.

It serves the two UNIX sockets documented at https://wiki.hypr.land/IPC/:

* ``$XDG_RUNTIME_DIR/hypr/<HIS>/.socket.sock``: one request per connection,
  ``[flags]/command args``, response written and connection closed.
* ``$XDG_RUNTIME_DIR/hypr/<HIS>/.socket2.sock``: line events ``EVENT>>DATA``.

State (monitors, workspaces, clients) is held in memory. Dispatch requests in
both the legacy hyprlang form (``workspace 3``) and the Lua form
(``hl.dsp.focus({ workspace = "3" })``) are parsed for the subset of
dispatchers AEROLITH emits, applied to the state, and answered with ``ok``.
Anything unrecognised is answered the way Hyprland answers an invalid request,
so tests notice it.

Every request is appended as a JSON line to ``--log`` so tests can assert on
exactly what a client sent. A control socket (``.control.sock``) accepts JSON
commands to simulate external changes (open/close windows, add monitors).

This is not Hyprland. Passing tests against it shows protocol conformance with
the documented interface, not behaviour on a real compositor.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import socket
import sys
import threading
import time
from dataclasses import dataclass, field

LEGACY_DISPATCH = {
    "workspace": re.compile(r"^workspace (?P<ws>-?\d+|name:[\w .-]+)$"),
    "focuswindow": re.compile(r"^focuswindow address:(?P<addr>0x[0-9a-f]+)$"),
    "movetoworkspacesilent": re.compile(
        r"^movetoworkspacesilent (?P<ws>-?\d+|name:[\w .-]+),address:(?P<addr>0x[0-9a-f]+)$"
    ),
    "movetoworkspace": re.compile(
        r"^movetoworkspace (?P<ws>-?\d+|name:[\w .-]+),address:(?P<addr>0x[0-9a-f]+)$"
    ),
    "closewindow": re.compile(r"^closewindow address:(?P<addr>0x[0-9a-f]+)$"),
}

LUA_STR = r'"(?:[^"\\]|\\.)*"'
LUA_DISPATCH = {
    "focus_ws": re.compile(r"^hl\.dsp\.focus\(\{ workspace = (?P<ws>" + LUA_STR + r") \}\)$"),
    "focus_win": re.compile(r"^hl\.dsp\.focus\(\{ window = (?P<win>" + LUA_STR + r") \}\)$"),
    "move": re.compile(
        r"^hl\.dsp\.window\.move\(\{ workspace = (?P<ws>" + LUA_STR + r"), follow = (?P<follow>true|false), window = (?P<win>"
        + LUA_STR
        + r") \}\)$"
    ),
    "close": re.compile(r"^hl\.dsp\.window\.close\(\{ window = (?P<win>" + LUA_STR + r") \}\)$"),
    "no_op": re.compile(r"^hl\.dsp\.no_op\(\)$"),
}


def lua_unquote(s: str) -> str:
    body = s[1:-1]
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), body)


@dataclass
class Client:
    address: str
    cls: str
    title: str
    workspace: int
    pid: int
    at: tuple[int, int] = (0, 0)
    size: tuple[int, int] = (960, 1048)
    floating: bool = False
    focus_history_id: int = 0
    fullscreen: int = 0

    def to_json(self, ws_name: str, monitor_id: int) -> dict:
        return {
            "address": self.address,
            "mapped": True,
            "hidden": False,
            "at": list(self.at),
            "size": list(self.size),
            "workspace": {"id": self.workspace, "name": ws_name},
            "floating": self.floating,
            "pseudo": False,
            "monitor": monitor_id,
            "class": self.cls,
            "title": self.title,
            "initialClass": self.cls,
            "initialTitle": self.title,
            "pid": self.pid,
            "xwayland": False,
            "pinned": False,
            "fullscreen": self.fullscreen,
            "fullscreenClient": self.fullscreen,
            "grouped": [],
            "tags": [],
            "swallowing": "0x0",
            "focusHistoryID": self.focus_history_id,
            "inhibitingIdle": False,
            "xdgTag": "",
            "xdgDescription": "",
        }


def ws_name(wid: int) -> str:
    """Hyprland names numbered workspaces by their id; named workspaces get
    ids from -1337 down and keep their own name."""
    return str(wid) if wid > 0 else f"named{-wid}"


@dataclass
class State:
    lua: bool = True
    monitors: list[dict] = field(default_factory=list)
    clients: dict[str, Client] = field(default_factory=dict)
    persistent_ws: set[int] = field(default_factory=set)
    active_ws: int = 1
    active_addr: str = ""
    next_addr: int = 0x5A00_0000_0000
    lock: threading.RLock = field(default_factory=threading.RLock)

    def ws_ids(self) -> list[int]:
        ids = {c.workspace for c in self.clients.values()} | self.persistent_ws | {self.active_ws}
        return sorted(ids)

    def monitor(self) -> dict:
        return self.monitors[0]

    def workspaces_json(self) -> list[dict]:
        out = []
        mon = self.monitor()
        for wid in self.ws_ids():
            wins = [c for c in self.clients.values() if c.workspace == wid]
            last = max(wins, key=lambda c: -c.focus_history_id, default=None)
            out.append(
                {
                    "id": wid,
                    "name": ws_name(wid),
                    "monitor": mon["name"],
                    "monitorID": mon["id"],
                    "windows": len(wins),
                    "hasfullscreen": any(c.fullscreen & 2 for c in wins),
                    "lastwindow": last.address if last else "0x0",
                    "lastwindowtitle": last.title if last else "",
                    "ispersistent": wid in self.persistent_ws,
                }
            )
        return out

    def layout(self) -> None:
        """Tile windows like a simple master/stack layout so geometry is realistic."""
        mon = self.monitor()
        gap, top = 8, 36
        w, h = mon["width"], mon["height"]
        for wid in self.ws_ids():
            wins = [c for c in self.clients.values() if c.workspace == wid and not c.floating]
            if not wins:
                continue
            if len(wins) == 1:
                wins[0].at, wins[0].size = (gap, top), (w - 2 * gap, h - top - gap)
                continue
            half = (w - 3 * gap) // 2
            wins[0].at, wins[0].size = (gap, top), (half, h - top - gap)
            rest = wins[1:]
            each = (h - top - gap * (len(rest) + 1)) // len(rest)
            for i, c in enumerate(rest):
                c.at, c.size = (2 * gap + half, top + i * (each + gap)), (half, each)

    def clients_json(self) -> list[dict]:
        mon = self.monitor()
        self.layout()
        return [c.to_json(ws_name(c.workspace), mon["id"]) for c in self.clients.values()]

    def monitors_json(self) -> list[dict]:
        out = []
        for i, m in enumerate(self.monitors):
            d = dict(m)
            d["activeWorkspace"] = {"id": self.active_ws, "name": ws_name(self.active_ws)} if i == 0 else {"id": 1, "name": "1"}
            d["specialWorkspace"] = {"id": 0, "name": ""}
            d["focused"] = i == 0
            out.append(d)
        return out

    def new_address(self) -> str:
        self.next_addr += 0x1A0
        return hex(self.next_addr)


class Mock:
    def __init__(self, base: str, log_path: str | None, lua: bool, mode: tuple[int, int] = (1920, 1080), scale: float = 1.0, transform: int = 0):
        self.base = base
        self.log_path = log_path
        self.state = State(lua=lua)
        self.state.monitors = [
            {
                "id": 0,
                "name": "DP-1",
                "description": f"Mock Display {mode[0]}x{mode[1]}",
                "make": "Mock",
                "model": "Display",
                "serial": "0",
                "width": mode[0],
                "height": mode[1],
                "physicalWidth": 530,
                "physicalHeight": 300,
                "refreshRate": 60.0,
                "x": 0,
                "y": 0,
                "reserved": [0, 0, 0, 0],
                "scale": scale,
                "transform": transform,
                "dpmsStatus": True,
                "vrr": False,
                "solitary": "0",
                "activelyTearing": False,
                "disabled": False,
                "currentFormat": "XRGB8888",
                "mirrorOf": "none",
                "availableModes": ["1920x1080@60.00Hz"],
            }
        ]
        self.subscribers: list[socket.socket] = []
        self.sub_lock = threading.Lock()
        self.running = True

    # -- logging and events -------------------------------------------------
    def log(self, kind: str, payload: str, reply: str | None = None) -> None:
        if not self.log_path:
            return
        with open(self.log_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"t": time.time(), "kind": kind, "request": payload, "reply": reply}) + "\n")

    def emit(self, name: str, data: str) -> None:
        line = f"{name}>>{data}\n".encode()
        with self.sub_lock:
            dead = []
            for s in self.subscribers:
                try:
                    s.sendall(line)
                except OSError:
                    dead.append(s)
            for s in dead:
                self.subscribers.remove(s)
        self.log("event", f"{name}>>{data}")

    # -- state transitions ---------------------------------------------------
    def focus_workspace(self, wid: int) -> None:
        st = self.state
        created = wid not in st.ws_ids()
        old = st.active_ws
        st.active_ws = wid
        if created:
            self.emit("createworkspace", ws_name(wid))
            self.emit("createworkspacev2", f"{wid},{ws_name(wid)}")
        self.emit("workspace", ws_name(wid))
        self.emit("workspacev2", f"{wid},{ws_name(wid)}")
        self.emit("focusedmon", f"{st.monitor()['name']},{ws_name(wid)}")
        self.emit("focusedmonv2", f"{st.monitor()['name']},{ws_name(wid)}")
        self.maybe_destroy(old)

    def maybe_destroy(self, wid: int) -> None:
        st = self.state
        if wid != st.active_ws and wid not in st.persistent_ws and not any(c.workspace == wid for c in st.clients.values()):
            self.emit("destroyworkspace", ws_name(wid))
            self.emit("destroyworkspacev2", f"{wid},{ws_name(wid)}")

    def focus_window(self, addr: str) -> bool:
        st = self.state
        c = st.clients.get(addr)
        if not c:
            return False
        if c.workspace != st.active_ws:
            self.focus_workspace(c.workspace)
        st.active_addr = addr
        for other in st.clients.values():
            other.focus_history_id += 1
        c.focus_history_id = 0
        self.emit("activewindow", f"{c.cls},{c.title}")
        self.emit("activewindowv2", addr[2:])
        return True

    def move_window(self, addr: str, wid: int, follow: bool) -> bool:
        st = self.state
        c = st.clients.get(addr)
        if not c:
            return False
        old = c.workspace
        created = wid not in st.ws_ids()
        c.workspace = wid
        if created:
            self.emit("createworkspace", ws_name(wid))
            self.emit("createworkspacev2", f"{wid},{ws_name(wid)}")
        self.emit("movewindow", f"{addr[2:]},{ws_name(wid)}")
        self.emit("movewindowv2", f"{addr[2:]},{wid},{ws_name(wid)}")
        if follow:
            self.focus_workspace(wid)
        self.maybe_destroy(old)
        return True

    def open_window(self, cls: str, title: str, workspace: int | None = None, floating: bool = False) -> str:
        st = self.state
        addr = st.new_address()
        wid = workspace if workspace is not None else st.active_ws
        # Hyprland's focusHistoryID: 0 is the focused window, higher is older.
        # A new unfocused window goes to the back of the history.
        history = max((c.focus_history_id for c in st.clients.values()), default=-1) + 1
        st.clients[addr] = Client(addr, cls, title, wid, pid=4000 + len(st.clients), floating=floating, focus_history_id=history)
        self.emit("openwindow", f"{addr[2:]},{ws_name(wid)},{cls},{title}")
        if wid == st.active_ws:
            self.focus_window(addr)
        return addr

    def close_window(self, addr: str) -> bool:
        st = self.state
        c = st.clients.pop(addr, None)
        if not c:
            return False
        self.emit("closewindow", addr[2:])
        if st.active_addr == addr:
            st.active_addr = ""
            self.emit("activewindow", ",")
            self.emit("activewindowv2", "")
        self.maybe_destroy(c.workspace)
        return True

    @staticmethod
    def parse_ws(sel: str) -> int | None:
        if re.fullmatch(r"-?\d+", sel):
            return int(sel)
        return None

    def dispatch(self, body: str) -> str:
        st = self.state
        if st.lua:
            for kind, rx in LUA_DISPATCH.items():
                m = rx.match(body)
                if not m:
                    continue
                if kind == "no_op":
                    return "ok"
                if kind == "focus_ws":
                    wid = self.parse_ws(lua_unquote(m["ws"]))
                    if wid is None:
                        return "error: invalid workspace"
                    self.focus_workspace(wid)
                    return "ok"
                win = lua_unquote(m["win"])
                if not win.startswith("address:"):
                    return "error: invalid window"
                addr = win[len("address:") :]
                if kind == "focus_win":
                    return "ok" if self.focus_window(addr) else "error: no such window"
                if kind == "close":
                    return "ok" if self.close_window(addr) else "error: no such window"
                if kind == "move":
                    wid = self.parse_ws(lua_unquote(m["ws"]))
                    if wid is None:
                        return "error: invalid workspace"
                    return "ok" if self.move_window(addr, wid, m["follow"] == "true") else "error: no such window"
            return f'error: [string "{body[:40]}"]: lua dispatch not understood by mock'
        for name, rx in LEGACY_DISPATCH.items():
            m = rx.match(body)
            if not m:
                continue
            if name == "workspace":
                wid = self.parse_ws(m["ws"])
                if wid is None:
                    return "Invalid workspace"
                self.focus_workspace(wid)
                return "ok"
            addr = m["addr"]
            if name == "focuswindow":
                return "ok" if self.focus_window(addr) else "No such window found"
            if name == "closewindow":
                return "ok" if self.close_window(addr) else "No such window found"
            wid = self.parse_ws(m["ws"])
            if wid is None:
                return "Invalid workspace"
            return "ok" if self.move_window(addr, wid, name == "movetoworkspace") else "No such window found"
        return "Invalid dispatcher"

    def handle_request(self, raw: str) -> str:
        req = raw.strip()
        flags = ""
        if "/" in req.split(" ", 1)[0]:
            flags, req = req.split("/", 1)
        cmd, _, args = req.partition(" ")
        with self.state.lock:
            if cmd == "dispatch":
                return self.dispatch(args.strip())
            if cmd == "eval" and self.state.lua:
                inner = re.fullmatch(r"hl\.dispatch\((.*)\)", args.strip())
                return self.dispatch(inner.group(1)) if inner else "ok"
            payload = self.query(cmd, args)
        if payload is None:
            return "unknown request"
        return json.dumps(payload, indent=2) if "j" in flags else self.plain(cmd, payload)

    def query(self, cmd: str, args: str):
        st = self.state
        if cmd == "monitors":
            return st.monitors_json()
        if cmd == "workspaces":
            return st.workspaces_json()
        if cmd == "clients":
            return st.clients_json()
        if cmd == "activeworkspace":
            return next((w for w in st.workspaces_json() if w["id"] == st.active_ws), {})
        if cmd == "activewindow":
            c = st.clients.get(st.active_addr)
            return c.to_json(ws_name(c.workspace), 0) if c else {}
        if cmd == "version":
            return {
                "branch": "mock",
                "commit": "0000000",
                "version": "0.56.2",
                "dirty": False,
                "commit_message": "mock",
                "commit_date": "",
                "tag": "v0.56.2",
                "commits": "0",
                "buildAquamarine": "",
                "buildHyprlang": "",
                "buildHyprutils": "",
                "buildHyprcursor": "",
                "buildHyprgraphics": "",
                "systemAquamarine": "",
                "systemHyprlang": "",
                "systemHyprutils": "",
                "systemHyprcursor": "",
                "systemHyprgraphics": "",
                "abiHash": "mock",
                "flags": [],
            }
        if cmd == "status":
            # Shape taken from Quickshell 0.3.2's Hyprland IPC client
            # (src/wayland/hyprland/ipc/connection.cpp), which reads
            # "configProvider" to decide whether dispatches use Lua.
            return {"configProvider": "lua" if st.lua else "hyprlang"}
        if cmd == "binds":
            return []
        if cmd == "globalshortcuts":
            return []
        if cmd == "layers":
            return {}
        if cmd == "devices":
            return {"mice": [], "keyboards": [], "tablets": [], "touch": [], "switches": []}
        if cmd == "getoption":
            return {"option": args.strip(), "int": 0, "set": False}
        if cmd == "configerrors":
            return [""]
        return None

    @staticmethod
    def plain(cmd: str, payload) -> str:
        return json.dumps(payload)

    # -- control socket for tests ------------------------------------------
    def control(self, msg: dict) -> dict:
        op = msg.get("op")
        with self.state.lock:
            if op == "open":
                return {"address": self.open_window(msg["class"], msg["title"], msg.get("workspace"), bool(msg.get("floating", False)))}
            if op == "focus_window":
                # Reuse the dispatch path: activewindow (class,title), then
                # activewindowv2 (address without 0x). Floating clients may
                # focus above fullscreen without clearing its mode bit:
                # Hyprland v0.56.2, desktop/state/FocusState.cpp:27-41.
                return {"ok": self.focus_window(msg["address"])}
            if op == "close":
                return {"ok": self.close_window(msg["address"])}
            if op == "focus_workspace":
                self.focus_workspace(int(msg["workspace"]))
                return {"ok": True}
            if op == "state":
                return {
                    "active_workspace": self.state.active_ws,
                    "active_window": self.state.active_addr,
                    "workspaces": self.state.workspaces_json(),
                    "clients": self.state.clients_json(),
                }
            if op == "fullscreen":
                # Hyprland's mode bitmask: 0 none, 1 maximized, 2 fullscreen.
                c = self.state.clients.get(msg["address"])
                if not c:
                    return {"ok": False}
                c.fullscreen = int(msg.get("mode", 2))
                self.emit("fullscreen", "1" if c.fullscreen & 2 else "0")
                return {"ok": True}
            if op == "screencast":
                self.emit("screencast", f"{1 if msg.get('active') else 0},{msg.get('owner', 0)}")
                return {"ok": True}
            if op == "add_monitor":
                mid = len(self.state.monitors)
                mon = dict(self.state.monitors[0])
                mon.update({"id": mid, "name": msg.get("name", f"HDMI-A-{mid}"), "x": 1920 * mid})
                self.state.monitors.append(mon)
                self.emit("monitoradded", mon["name"])
                self.emit("monitoraddedv2", f"{mid},{mon['name']},{mon['description']}")
                return {"ok": True}
            if op == "remove_monitor":
                name = msg.get("name")
                keep = [m for m in self.state.monitors if m["name"] != name]
                if len(keep) == len(self.state.monitors) or not keep:
                    return {"ok": False}
                self.state.monitors = keep
                self.emit("monitorremoved", name)
                return {"ok": True}
        return {"error": f"unknown op {op!r}"}

    # -- socket loops ----------------------------------------------------------
    def serve(self) -> None:
        os.makedirs(self.base, exist_ok=True)
        req_path = os.path.join(self.base, ".socket.sock")
        ev_path = os.path.join(self.base, ".socket2.sock")
        ctl_path = os.path.join(self.base, ".control.sock")
        for p in (req_path, ev_path, ctl_path):
            if os.path.exists(p):
                os.unlink(p)
        req = self._listen(req_path)
        ev = self._listen(ev_path)
        ctl = self._listen(ctl_path)
        threading.Thread(target=self._accept_events, args=(ev,), daemon=True).start()
        threading.Thread(target=self._accept_control, args=(ctl,), daemon=True).start()
        while self.running:
            try:
                conn, _ = req.accept()
            except OSError:
                break
            threading.Thread(target=self._handle_req_conn, args=(conn,), daemon=True).start()

    @staticmethod
    def _listen(path: str) -> socket.socket:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.bind(path)
        os.chmod(path, 0o600)
        s.listen(16)
        return s

    def _handle_req_conn(self, conn: socket.socket) -> None:
        with conn:
            conn.settimeout(5)
            data = b""
            try:
                while True:
                    chunk = conn.recv(65536)
                    if not chunk:
                        break
                    data += chunk
                    if len(chunk) < 65536:
                        break
            except OSError:
                return
            text = data.decode("utf-8", "replace")
            reply = self.handle_request(text)
            self.log("request", text, reply if len(reply) < 400 else reply[:400] + "...")
            try:
                conn.sendall(reply.encode())
            except OSError:
                pass

    def _accept_events(self, ev: socket.socket) -> None:
        while self.running:
            try:
                conn, _ = ev.accept()
            except OSError:
                break
            with self.sub_lock:
                self.subscribers.append(conn)
            self.log("subscribe", "socket2")

    def _accept_control(self, ctl: socket.socket) -> None:
        while self.running:
            try:
                conn, _ = ctl.accept()
            except OSError:
                break
            with conn:
                try:
                    msg = json.loads(conn.recv(65536).decode())
                    reply = self.control(msg)
                except (ValueError, KeyError, OSError) as exc:
                    reply = {"error": str(exc)}
                try:
                    conn.sendall(json.dumps(reply).encode())
                except OSError:
                    pass


def control_client(base: str, msg: dict) -> dict:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(os.path.join(base, ".control.sock"))
    s.sendall(json.dumps(msg).encode())
    s.shutdown(socket.SHUT_WR)
    data = b""
    while chunk := s.recv(65536):
        data += chunk
    s.close()
    return json.loads(data.decode())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--signature", default="aerolith_mock")
    ap.add_argument("--runtime-dir", default=os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    ap.add_argument("--log", default=None)
    ap.add_argument("--hyprlang", action="store_true", help="emulate legacy hyprlang dispatch syntax")
    ap.add_argument("--seed", action="store_true", help="open a few windows at start")
    ap.add_argument("--control", default=None, help="send a JSON control message to a running mock and exit")
    ap.add_argument("--mode", default="1920x1080", help="monitor mode in physical pixels, WxH")
    ap.add_argument("--scale", type=float, default=1.0, help="monitor scale")
    ap.add_argument("--transform", type=int, default=0, choices=range(8), help="monitor transform (0-7)")
    args = ap.parse_args()
    base = os.path.join(args.runtime_dir, "hypr", args.signature)
    if args.control:
        print(json.dumps(control_client(base, json.loads(args.control))))
        return 0
    mw, mh = (int(v) for v in args.mode.lower().split("x", 1))
    mock = Mock(base, args.log, lua=not args.hyprlang, mode=(mw, mh), scale=args.scale, transform=args.transform)
    mock.state.persistent_ws = {1, 2, 3}
    if args.seed:
        with mock.state.lock:
            mock.open_window("foot", "pilot@aerolith: ~", 1)
            mock.open_window("firefox", "Hyprland Wiki — Mozilla Firefox", 2)
            mock.open_window("org.gnome.Nautilus", "Downloads", 2)
            mock.open_window("Code", "aerolith — Visual Studio Code", 3)
            mock.focus_workspace(1)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    print(f"mock hyprland listening in {base}", flush=True)
    mock.serve()
    return 0


if __name__ == "__main__":
    sys.exit(main())
