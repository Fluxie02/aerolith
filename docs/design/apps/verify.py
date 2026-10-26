"""UI-010 evidence: emitted colour pairs plus the available native GTK 3 parser.

Run from the repository root with Python 3; writes contrast.json and gtk3-parser.txt
next to this script. GTK 4 runtime validation is intentionally not claimed.
"""
import configparser
import ctypes as ct
import ctypes.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def luminance(color):
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels]
    return sum(c * w for c, w in zip(linear, (.2126, .7152, .0722)))


def ratio(a, b):
    lo, hi = sorted((luminance(a), luminance(b)))
    return (hi + .05) / (lo + .05)


def named_colors(path):
    declarations = re.findall(r"@define-color\s+([\w]+)\s+([^;]+);", path.read_text())
    raw = dict(declarations)
    def resolve(name):
        value = raw[name]
        return resolve(value[1:]) if value.startswith('@') else value
    return {name: resolve(name) for name in raw}


checks = []


def check(label, fg, bg, minimum=4.5):
    value = ratio(fg, bg)
    checks.append(dict(pair=label, foreground=fg, background=bg,
                       ratio=round(value, 4), minimum=minimum, passed=value >= minimum))


for version in ('3.0', '4.0'):
    colors = named_colors(ROOT / f'themes/gtk-{version}/gtk.css')
    for fg in ('aerolith_text', 'aerolith_dim', 'aerolith_signal', 'warning_color', 'error_color', 'success_color'):
        for bg in ('aerolith_obsidian', 'aerolith_surface', 'aerolith_surface2'):
            check(f'GTK {version} {fg} / {bg}', colors[fg], colors[bg])
    for bg in ('aerolith_obsidian', 'aerolith_surface', 'aerolith_surface2', 'aerolith_grid'):
        check(f'GTK {version} focus / {bg}', colors['aerolith_signal'], colors[bg], 3)
    for bg in ('aerolith_signal', 'error_color'):
        check(f'GTK {version} filled control + inset focus / {bg}', colors['aerolith_obsidian'], colors[bg])
    check(f'GTK {version} hovered button', colors['aerolith_text'], colors['aerolith_grid'])
    for state in ('', 'unfocused_'):
        check(f'GTK {version} {state}selection', colors[f'theme_{state}selected_fg_color'],
              colors[f'theme_{state}selected_bg_color'])

roles = ['WindowText', 'Button', 'Light', 'Midlight', 'Dark', 'Mid', 'Text',
         'BrightText', 'ButtonText', 'Base', 'Window', 'Shadow', 'Highlight',
         'HighlightedText', 'Link', 'LinkVisited', 'AlternateBase', 'NoRole',
         'ToolTipBase', 'ToolTipText', 'PlaceholderText', 'Accent']
ini = configparser.ConfigParser()
ini.read(ROOT / 'themes/qt/aerolith.conf')
for group in ('active', 'inactive', 'disabled'):
    raw = [c.strip() for c in ini['ColorScheme'][group + '_colors'].split(',')]
    assert len(raw) == len(roles), (group, len(raw))
    assert all(re.fullmatch(r'#ff[\da-f]{6}', c) for c in raw), 'Qt colours must be opaque'
    colors = dict(zip(roles, ['#' + c[3:] for c in raw]))
    for fg, bg in [('WindowText', 'Window'), ('Text', 'Base'), ('Text', 'AlternateBase'),
                   ('ButtonText', 'Button'), ('ToolTipText', 'ToolTipBase'),
                   ('PlaceholderText', 'Base'), ('Link', 'Base'), ('LinkVisited', 'Base'),
                   ('HighlightedText', 'Highlight')]:
        check(f'Qt {group} {fg} / {bg} (palette values)', colors[fg], colors[bg])
    if group != 'disabled':
        for bg in ('Base', 'Button', 'Light', 'Window'):
            check(f'Qt {group} focus / {bg}', colors['Highlight'], colors[bg], 3)
        check(f'Qt {group} hovered button', colors['ButtonText'], colors['Light'])

(HERE / 'contrast.json').write_text(json.dumps({
    'method': 'WCAG sRGB relative luminance; opaque emitted colour pairs',
    'scope': 'Enabled text >=4.5, focus >=3. Toolkit disabled opacity, private app CSS and compositor pixels are excluded.',
    'checks': checks,
    'passed': all(c['passed'] for c in checks)
}, indent=2) + '\n')
assert all(c['passed'] for c in checks), [c for c in checks if not c['passed']]
print(f'Contrast: {len(checks)}/{len(checks)} passed')

# GTK 3 library is present on the host, without development headers or demo apps.
# Load user CSS using its own parser, including parsing-error signals (warnings).
gtk = ct.CDLL(ctypes.util.find_library('gtk-3'))
gobject = ct.CDLL(ctypes.util.find_library('gobject-2.0'))
gtk.gtk_css_provider_new.restype = ct.c_void_p
gtk.gtk_css_provider_load_from_path.argtypes = [ct.c_void_p, ct.c_char_p, ct.POINTER(ct.c_void_p)]
gtk.gtk_css_provider_load_from_path.restype = ct.c_int
gtk.gtk_css_section_get_start_line.argtypes = [ct.c_void_p]
gtk.gtk_css_section_get_start_line.restype = ct.c_uint
gobject.g_signal_connect_data.argtypes = [ct.c_void_p, ct.c_char_p, ct.c_void_p, ct.c_void_p, ct.c_void_p, ct.c_int]
gobject.g_object_unref.argtypes = [ct.c_void_p]


class GError(ct.Structure):
    _fields_ = [('domain', ct.c_uint32), ('code', ct.c_int), ('message', ct.c_char_p)]


errors = []


@ct.CFUNCTYPE(None, ct.c_void_p, ct.c_void_p, ct.POINTER(GError), ct.c_void_p)
def parsing_error(provider, section, error, data):
    errors.append(f"line {gtk.gtk_css_section_get_start_line(section) + 1}: {error.contents.message.decode()}")


provider = gtk.gtk_css_provider_new()
gobject.g_signal_connect_data(provider, b'parsing-error', ct.cast(parsing_error, ct.c_void_p), None, None, 0)
error = ct.c_void_p()
ok = gtk.gtk_css_provider_load_from_path(provider, str(ROOT / 'themes/gtk-3.0/gtk.css').encode(), ct.byref(error))
gobject.g_object_unref(provider)
gtk.gtk_get_major_version.restype = gtk.gtk_get_minor_version.restype = gtk.gtk_get_micro_version.restype = ct.c_uint
version = '.'.join(str(f()) for f in (gtk.gtk_get_major_version, gtk.gtk_get_minor_version, gtk.gtk_get_micro_version))
result = f'GTK {version} native CSS parser: ' + ('PASS; no errors or warnings' if ok and not errors else '\n'.join(errors))
(HERE / 'gtk3-parser.txt').write_text(result + '\n')
print(result)
assert ok and not errors, errors
