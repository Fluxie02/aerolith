import configparser
import json
from pathlib import Path
import re
import sys
import tomllib
import xml.etree.ElementTree as ET

import tinycss2
import cssselect2

root = Path(__file__).resolve().parents[3] / 'themes/schemes'
counts = dict(css=0, rules=0, declarations=0, selectors=0, json=0, xml=0, toml=0, qt=0, kitty=0, btop=0)
errors = []
def css_rules(tokens, source):
    for rule in tinycss2.parse_stylesheet(tokens, skip_comments=True, skip_whitespace=True):
        if rule.type == 'error':
            errors.append((str(source), str(rule)))
        if rule.type == 'qualified-rule':
            counts['rules'] += 1
            selector = tinycss2.serialize(rule.prelude).strip()
            # Firefox alone uses a browser pseudo-class understood by Gecko.
            if not source.parent.name.startswith('gtk-'):
                try:
                    cssselect2.compile_selector_list(selector)
                    counts['selectors'] += 1
                except cssselect2.SelectorError as error:
                    errors.append((str(source), selector, str(error)))
            for declaration in tinycss2.parse_declaration_list(rule.content, skip_comments=True, skip_whitespace=True):
                if declaration.type == 'error':
                    errors.append((str(source), str(declaration)))
                elif declaration.type == 'declaration':
                    counts['declarations'] += 1
        elif rule.type == 'at-rule' and rule.content is not None:
            css_rules(rule.content, source)

for source in sorted(root.rglob('*')):
    if not source.is_file():
        continue
    contents = source.read_text()
    if source.suffix in {'.css', '.qss'}:
        # QSS intentionally uses Qt-only selectors/functions and is validated
        # by its unchanged existing template instead of web selector grammar.
        if source.suffix == '.css':
            counts['css'] += 1
            css_rules(contents, source)
    elif source.suffix == '.json':
        obj = json.loads(contents)
        counts['json'] += 1
        if source.name == 'manifest.json':
            assert all(re.fullmatch(r'#[0-9a-f]{6}', c) for c in obj['theme']['colors'].values())
        if source.name == 'skin.json':
            assert obj['UseDefaultPatches'] is True
            assert all((source.parent / file).is_file() for file in ['libraryroot.custom.css','friends.custom.css','bigpicture.custom.css'])
    elif source.suffix in {'.xml', '.xcu'}:
        tree = ET.fromstring(contents)
        counts['xml'] += 1
        for prop in tree.iter('prop'):
            if prop.attrib.get('{http://openoffice.org/2001/registry}name') == 'Color':
                value = int(prop.findtext('value'))
                assert 0 <= value <= 16777215
    elif source.suffix == '.toml':
        obj = tomllib.loads(contents)
        counts['toml'] += 1
        assert len(obj['colors']['normal']) == len(obj['colors']['bright']) == 8
    elif source.parent.name == 'qt' and source.suffix == '.conf':
        config = configparser.ConfigParser()
        config.read_string(contents)
        counts['qt'] += 1
        for name in ['active_colors','inactive_colors','disabled_colors']:
            roles = config['ColorScheme'][name].split(', ')
            assert len(roles) == 22
            assert all(re.fullmatch(r'#ff[0-9a-f]{6}', color) for color in roles)
    elif source.parent.name == 'kitty':
        counts['kitty'] += 1
        ansi = re.findall(r'^color(\d+) (#[0-9a-f]{6})$', contents, re.M)
        assert sorted(int(index) for index, _ in ansi) == list(range(16))
    elif source.parent.name == 'btop':
        counts['btop'] += 1
        original = (root.parent / 'btop/aerolith.theme').read_text()
        assert re.findall(r'^theme\[(\w+)\]=', contents, re.M) == re.findall(r'^theme\[(\w+)\]=', original, re.M)
        assert len(re.findall(r'^theme\[\w+\]="#[0-9a-f]{6}"$', contents, re.M)) == len(re.findall(r'^theme\[\w+\]=', original, re.M))

print('Command: PYTHONPATH=/tmp/aerolith-ui015-css python3 docs/design/schemes/verify-app-themes.py')
print('Parsers: tinycss2', tinycss2.__version__, '/ cssselect2', cssselect2.__version__, '/ Python stdlib json, tomllib, configparser, ElementTree')
print(json.dumps(counts, indent=2))
print('Errors:', len(errors))
for error in errors:
    print(error)
if errors:
    raise SystemExit(1)
