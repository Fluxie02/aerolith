#!/usr/bin/env python3
"""A05 inventory and conservative archival plan; no deletion without --apply.

Run from the repository root. Markdown links and existing backtick file references
throughout the repository protect design evidence, as do reproducibility inputs.
"""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote

ROOT = Path.cwd().resolve()
DESIGN = ROOT / 'docs/design'
LINK = re.compile(r'!?\[[^\]]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)')
REF = re.compile(r'^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)', re.M)
CODE = re.compile(r'`([^`\n]+)`')


def targets(md):
    text = md.read_text(errors='replace')
    for match in list(LINK.finditer(text)) + list(REF.finditer(text)):
        target = unquote(match.group(1).strip('<>')).split('#')[0].split('?')[0]
        if not target or re.match(r'^[a-zA-Z][\w+.-]*:', target):
            continue
        yield target, (ROOT / target.lstrip('/') if target.startswith('/') else md.parent / target).resolve()


def kind(p):
    name = p.name.lower()
    if name.endswith(('.tar.gz', '.tar', '.tgz', '.zip')):
        return 'tarballs'
    if p.suffix.lower() in ('.png', '.jpg', '.jpeg', '.svg'):
        return 'frame sequences' if re.search(r'frame|sequence|attempt', str(p)) else 'screenshots'
    if p.suffix.lower() in ('.mp4', '.webm', '.webp', '.gif', '.mkv'):
        return 'videos / motion previews'
    if p.suffix.lower() in ('.sh', '.py', '.js', '.mjs', '.qml', '.cpp'):
        return 'scripts / replay sources'
    if p.suffix.lower() in ('.json', '.jsonl', '.conf', '.csv') or re.search(r'hash|sha256|manifest', name):
        return 'manifests / structured data'
    if p.suffix.lower() in ('.txt', '.log'):
        return 'logs'
    return 'documents / other'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--check-links', action='store_true')
    args = parser.parse_args()
    tracked = [ROOT / p for p in subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0') if p]
    markdown = sorted({p for p in tracked if p.suffix.lower() == '.md' and p.exists()} | set(DESIGN.rglob('*.md')))
    broken = [(str(md.relative_to(ROOT)), t) for md in markdown for t, p in targets(md) if not p.exists()]
    if args.check_links:
        print(json.dumps({'scope': 'all tracked Markdown local file/directory targets (anchors and remote URLs excluded)', 'broken': broken}, indent=2))
        return bool(broken)
    if args.apply and (DESIGN / 'archive-manifest.json').exists():
        parser.error('archive already applied; restore baseline before regenerating its manifest')
    files = [p for p in tracked if p.is_relative_to(DESIGN) and p.is_file()]
    keep = {p for p in files if p.suffix.lower() in ('.md', '.json', '.jsonl', '.sh', '.py', '.js', '.mjs', '.qml', '.cpp', '.conf', '.csv') or re.search(r'hash|sha256|manifest', p.name, re.I)}
    keep.update(p for p in files if p.is_relative_to(DESIGN / 'counterphase/recordings') and p.suffix.lower() == '.mp4')
    for md in markdown:
        keep.update(p for _, p in targets(md) if p.is_file() and p.is_relative_to(DESIGN))
        # Plain code references are common in the historical reports. Resolve
        # repository-relative and document-relative paths without retaining entire runs.
        for raw in CODE.findall(md.read_text(errors='replace')):
            raw = raw.removeprefix('./').rstrip('.,:')
            for p in (md.parent / raw, ROOT / raw, DESIGN / raw):
                p = p.resolve()
                if p.is_file() and p.is_relative_to(DESIGN):
                    keep.add(p)
    # Reports also cite evidence in prose rather than Markdown links. Protect
    # explicit basenames, and the diagnostic captures beside failed-case reports.
    design_text = '\n'.join(p.read_text(errors='replace') for p in markdown if p.is_relative_to(DESIGN))
    keep.update(p for p in files if len(p.name) > 7 and p.name in design_text)
    for md in markdown:
        if md.is_relative_to(DESIGN) and re.search(r'attempt|reject|fail', str(md.relative_to(DESIGN)), re.I):
            keep.update(p for p in files if p.is_relative_to(md.parent))
    # Git does not retain empty directories. Preserve one representative in
    # each linked directory whose entire content would otherwise be removed.
    for md in markdown:
        for _, directory in targets(md):
            if directory.is_dir() and directory.is_relative_to(DESIGN):
                candidates = sorted(p for p in files if p.is_relative_to(directory))
                if candidates and not any(p in keep for p in candidates):
                    media = [p for p in candidates if p.suffix.lower() in ('.png', '.webp', '.mp4', '.jpg')]
                    keep.add((media or candidates)[0])
    removed = [p for p in files if p not in keep]
    inventory = defaultdict(lambda: [0, 0])
    rounds = defaultdict(lambda: [0, 0])
    for p in files:
        rel = p.relative_to(DESIGN)
        round_name = rel.parts[0] if len(rel.parts) > 1 else '(root)'
        row = inventory[(round_name, kind(p))]
        row[0] += 1
        row[1] += p.stat().st_size
    for p in removed:
        row = rounds[p.relative_to(DESIGN).parts[0]]
        row[0] += 1
        row[1] += p.stat().st_size
    report = {
        'baseline_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip(),
        'design_before_bytes': sum(p.stat().st_size for p in files),
        'fresh_checkout_before_bytes': sum(p.lstat().st_size for p in tracked if p.exists()),
        'inventory': [{'round': r, 'kind': k, 'files': v[0], 'bytes': v[1]} for (r, k), v in sorted(inventory.items())],
        'removed_by_round': {r: {'files': v[0], 'bytes': v[1]} for r, v in sorted(rounds.items())},
        'removed': [{'path': str(p.relative_to(ROOT)), 'bytes': p.stat().st_size} for p in removed],
        'baseline_broken_links': broken,
    }
    print(json.dumps({k: v for k, v in report.items() if k not in ('removed', 'inventory')}, indent=2))
    if args.apply:
        (DESIGN / 'archive-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
        for p in removed:
            p.unlink()


if __name__ == '__main__':
    raise SystemExit(main())
