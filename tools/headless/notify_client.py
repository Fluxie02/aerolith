#!/usr/bin/env python3
"""Send a desktop notification over D-Bus and record what happens to it.

Test helper for tests/scenarios/notify.sh. Prints the notification id on the
first line, then one line per ActionInvoked or NotificationClosed signal for
that id, and exits after --wait seconds or when the notification closes.
"""

import argparse
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

BUS = "org.freedesktop.Notifications"
PATH = "/org/freedesktop/Notifications"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--summary", required=True)
    ap.add_argument("--body", default="")
    ap.add_argument("--app", default="aerolith-test")
    ap.add_argument("--action", action="append", default=[], help="identifier:label, repeatable")
    ap.add_argument("--wait", type=float, default=10.0)
    ap.add_argument("--resident", action="store_true", help="ask the server to keep the notification after an action")
    args = ap.parse_args()

    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    loop = GLib.MainLoop()
    state = {"id": None}

    def on_signal(_conn, _sender, _path, _iface, name, params):
        values = params.unpack()
        if state["id"] is None or values[0] != state["id"]:
            return
        if name == "ActionInvoked":
            print(f"action {values[1]}", flush=True)
        elif name == "NotificationClosed":
            print(f"closed {values[1]}", flush=True)
            loop.quit()

    for signal in ("ActionInvoked", "NotificationClosed"):
        conn.signal_subscribe(BUS, BUS, signal, PATH, None, Gio.DBusSignalFlags.NONE, on_signal)

    actions = []
    for spec in args.action:
        ident, _, label = spec.partition(":")
        actions += [ident, label or ident]
    hints = {"resident": GLib.Variant("b", True)} if args.resident else {}
    reply = conn.call_sync(
        BUS, PATH, BUS, "Notify",
        GLib.Variant("(susssasa{sv}i)", (args.app, 0, "", args.summary, args.body, actions, hints, -1)),
        GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 5000, None,
    )
    state["id"] = reply.unpack()[0]
    print(state["id"], flush=True)
    GLib.timeout_add(int(args.wait * 1000), loop.quit)
    loop.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
