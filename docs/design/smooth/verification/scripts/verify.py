#!/usr/bin/env python3
"""UI-016 verification driver. Does not change production or existing tests."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, os, shlex, shutil, subprocess, time

ROOT = Path(__file__).resolve().parents[5]
DOC = ROOT / 'docs/design/smooth/verification'
BUILD = ROOT / 'build/ui016/verification'


def manifest(path):
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob('*')) if p.is_file()}


def run(name, command, env=None):
    target = DOC / name
    target.parent.mkdir(parents=True, exist_ok=True)
    overrides = env or {}
    display = ' '.join(f'{k}={shlex.quote(v)}' for k, v in overrides.items())
    display = (display + ' ' if display else '') + shlex.join(command)
    start = time.monotonic()
    began = datetime.now(timezone.utc).isoformat()
    with target.with_suffix('.txt').open('w') as log:
        log.write('$ ' + display + '\n\n'); log.flush()
        process = subprocess.run(command, cwd=ROOT, env={**os.environ, **overrides},
                                 stdout=log, stderr=subprocess.STDOUT)
        elapsed = time.monotonic() - start
        log.write(f'\nEXIT {process.returncode}\nELAPSED {elapsed:.3f} s\n')
    result = {'name': name, 'command': command, 'environment': overrides,
              'display_command': display, 'started_at': began,
              'exit_code': process.returncode, 'elapsed_seconds': elapsed}
    if overrides.get('SHELL_PATH'):
        source_manifest = manifest(ROOT/overrides['SHELL_PATH'])
        result['shell_source_manifest_sha256'] = hashlib.sha256(
            json.dumps(source_manifest,sort_keys=True).encode()).hexdigest()
    target.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result), flush=True)
    return process.returncode


def freeze():
    destination = BUILD / 'final-shell'
    if destination.exists(): shutil.rmtree(destination)
    shutil.copytree(ROOT / 'shell', destination)
    source = manifest(ROOT / 'shell')
    (DOC / 'source-hashes.json').write_text(json.dumps(source, indent=2) + '\n')
    (DOC / 'source-comparison.json').write_text(json.dumps({
        'production_files': len(source), 'snapshot_files': len(manifest(destination)),
        'matches': source == manifest(destination)}, indent=2) + '\n')
    thears = BUILD / 'final-thears-shell'
    if thears.exists(): shutil.rmtree(thears)
    shutil.copytree(destination, thears)
    theme = thears / 'core/Theme.qml'
    theme.write_text(theme.read_text().replace('property string applicationDirection: "piyti"',
                                               'property string applicationDirection: "thears"'))
    (DOC / 'thears-source-hashes.json').write_text(json.dumps(manifest(thears), indent=2) + '\n')
    for intensity in ('saturated', 'insane'):
        for motion in ('full', 'reduced', 'off'):
            config = {'schemaVersion': 1, 'theme': {'intensity': intensity, 'motion': motion}}
            (BUILD / f'{intensity}-{motion}.json').write_text(json.dumps(config, indent=2) + '\n')
    print('Final shell frozen; source hashes and configs saved.', flush=True)


def units(round_name):
    commands = {
        'node': ['node', 'tests/js/run-node.mjs'],
        'qt-v4': ['docker', 'run', '--rm', '-v', str(ROOT)+':/src:ro', 'aerolith-dev', 'bash', '-c',
                  'cd /src && QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 tests/js/run-qt.qml'],
        'pytest': ['python3', '-m', 'pytest', '-q', 'tests/py'],
    }
    return commands


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['freeze', 'node', 'qt-v4', 'pytest', 'smoke', 'full', 'deck', 'ai', 'notify', 'audit', 'custom'])
    parser.add_argument('--round', default='final')
    parser.add_argument('--intensity', choices=['saturated', 'insane'], default='saturated')
    parser.add_argument('--motion', choices=['full', 'reduced', 'off'], default='full')
    parser.add_argument('--direction', choices=['piyti', 'thears'], default='piyti')
    parser.add_argument('--custom-script')
    parser.add_argument('--shell-path')
    parser.add_argument('--case-name')
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    DOC.mkdir(parents=True, exist_ok=True)
    if args.action == 'freeze': freeze(); return
    if args.action in units(args.round):
        raise SystemExit(run('unit-' + args.round + '/' + args.action, units(args.round)[args.action]))
    if args.action == 'audit':
        import re
        pattern = re.compile(r'TypeError|ReferenceError|SyntaxError|Unable to assign|Binding loop|binding loop|is not a type|Cannot assign|Error loading QML|Failed to load component|SIGSEGV|Segmentation fault')
        findings = []
        logs = sorted((DOC/'runs').rglob('qs.txt'))
        for path in logs:
            for number, line in enumerate(path.read_text(errors='replace').splitlines(), 1):
                if pattern.search(line): findings.append({'file': str(path.relative_to(DOC)), 'line': number, 'text': line})
        result = {'logs_checked': len(logs), 'findings': findings}
        (DOC/'log-audit.json').write_text(json.dumps(result, indent=2)+'\n')
        print(json.dumps(result), flush=True)
        raise SystemExit(bool(findings))
    if args.action == 'custom':
        assert args.custom_script and args.shell_path and args.case_name
        env = {'SHELL_PATH': args.shell_path}
        out = BUILD/args.case_name
        code = run('results/'+args.case_name, ['tools/headless/run.sh', args.custom_script, str(out.relative_to(ROOT))], env)
        dest = DOC/'runs'/args.case_name
        if dest.exists(): shutil.rmtree(dest)
        shutil.copytree(out,dest)
        if (dest/'qs.log').exists(): shutil.copyfile(dest/'qs.log', dest/'qs.txt')
        raise SystemExit(code)
    name = '-'.join([args.direction, args.intensity, args.motion, args.action])
    frozen = 'final-shell' if args.direction == 'piyti' else 'final-thears-shell'
    env = {'SHELL_PATH': str((BUILD/frozen).relative_to(ROOT)),
           'CONFIG': str(BUILD/f'{args.intensity}-{args.motion}.json')}
    if args.action in ('full', 'deck', 'ai'): env['AUDIO'] = '1'
    if args.action == 'full': env.update(MEDIA='1', MPV_AO='pipewire', ROUTINES='tests/fixtures/routines.json')
    if args.action == 'deck': env['HYPR_MOCK_ARGS'] = '--mode 2560x1440 --scale 1.5 --transform 1'
    if args.action == 'ai': env['AI'] = '1'
    if args.action == 'notify': env['CONFIG'] = 'tests/fixtures/notify-config.json'
    out = BUILD/name
    code = run('results/'+name, ['tools/headless/run.sh', f'tests/scenarios/{args.action}.sh', str(out.relative_to(ROOT))], env)
    dest = DOC/'runs'/name
    if dest.exists(): shutil.rmtree(dest)
    shutil.copytree(out, dest)
    if (dest/'qs.log').exists(): shutil.copyfile(dest/'qs.log', dest/'qs.txt')
    raise SystemExit(code)

if __name__ == '__main__': main()
