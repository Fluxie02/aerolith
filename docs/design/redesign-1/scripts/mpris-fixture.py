"""Disposable headless-only MPRIS player; no production service changes."""
import sys
from gi.repository import Gio, GLib

ROOT = 'org.mpris.MediaPlayer2'
PLAYER = ROOT + '.Player'
PATH = '/org/mpris/MediaPlayer2'
xml = '''<node>
<interface name="org.mpris.MediaPlayer2">
 <property name="Identity" type="s" access="read"/>
 <property name="CanQuit" type="b" access="read"/>
 <property name="CanRaise" type="b" access="read"/>
 <property name="HasTrackList" type="b" access="read"/>
 <property name="DesktopEntry" type="s" access="read"/>
 <property name="SupportedUriSchemes" type="as" access="read"/>
 <property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
 <method name="PlayPause"/><method name="Play"/><method name="Pause"/><method name="Next"/>
 <property name="PlaybackStatus" type="s" access="read"/>
 <property name="Metadata" type="a{sv}" access="read"/>
 <property name="Position" type="x" access="read"/>
 <property name="Rate" type="d" access="read"/>
 <property name="MinimumRate" type="d" access="read"/>
 <property name="MaximumRate" type="d" access="read"/>
 <property name="Volume" type="d" access="read"/>
 <property name="LoopStatus" type="s" access="read"/>
 <property name="Shuffle" type="b" access="read"/>
 <property name="CanGoNext" type="b" access="read"/>
 <property name="CanGoPrevious" type="b" access="read"/>
 <property name="CanPlay" type="b" access="read"/>
 <property name="CanPause" type="b" access="read"/>
 <property name="CanSeek" type="b" access="read"/>
 <property name="CanControl" type="b" access="read"/>
</interface></node>'''
v = GLib.Variant
metadata = {
 'mpris:trackid': v('o', '/track/1'), 'mpris:artUrl': v('s', sys.argv[1]),
 'xesam:title': v('s', 'Orbit • A live session'),
 'xesam:artist': v('as', ['Aerolith Ensemble']), 'mpris:length': v('x', 240000000),
}
props = {
 ROOT: {'Identity': v('s', 'Redesign fixture'), 'CanQuit': v('b', False),
        'CanRaise': v('b', False), 'HasTrackList': v('b', False),
        'DesktopEntry': v('s', ''), 'SupportedUriSchemes': v('as', []),
        'SupportedMimeTypes': v('as', [])},
 PLAYER: {'PlaybackStatus': v('s', 'Playing'), 'Metadata': v('a{sv}', metadata),
          'Position': v('x', 30000000), 'Rate': v('d', 1.), 'MinimumRate': v('d', 1.),
          'MaximumRate': v('d', 1.), 'Volume': v('d', 1.), 'LoopStatus': v('s', 'None'),
          'Shuffle': v('b', False)}
}
for key in ['CanGoNext', 'CanPlay', 'CanPause', 'CanControl']:
 props[PLAYER][key] = v('b', True)
for key in ['CanGoPrevious', 'CanSeek']:
 props[PLAYER][key] = v('b', False)

def method(conn, sender, path, interface, name, params, invocation):
 if name in ('PlayPause', 'Play', 'Pause'):
  state = props[PLAYER]['PlaybackStatus'].unpack()
  playing = name == 'Play' or (name == 'PlayPause' and state != 'Playing')
  changed = {'PlaybackStatus': v('s', 'Playing' if playing else 'Paused')}
 else:
  metadata['xesam:title'] = v('s', 'Next track <live>')
  changed = {'Metadata': v('a{sv}', metadata)}
 props[PLAYER].update(changed)
 conn.emit_signal(None, PATH, 'org.freedesktop.DBus.Properties', 'PropertiesChanged',
                  v('(sa{sv}as)', (PLAYER, changed, [])))
 print(name, flush=True)
 invocation.return_value(None)

def acquired(conn, name):
 for iface in Gio.DBusNodeInfo.new_for_xml(xml).interfaces:
  conn.register_object(PATH, iface, method,
    lambda c, s, p, i, prop: props[i][prop], None)

Gio.bus_own_name(Gio.BusType.SESSION, ROOT + '.redesign', Gio.BusNameOwnerFlags.NONE,
                 acquired, None, None)
GLib.MainLoop().run()
