#!/usr/bin/env python3
"""Archive UI-012's actual headless captures; never synthesize app previews.

Pillow is used only for lossless frame encoding, labelled contact sheets and
scaled animation previews. Source capture pixels are preserved in PNG files.
"""
from argparse import ArgumentParser
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[5]
SAMPLES = (0, 2, 4, 7, 11, 17)


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def iso(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).isoformat(timespec='milliseconds')


def copy_pngs(src, dest):
    dest.mkdir(parents=True, exist_ok=True)
    files = []
    for path in sorted(src.glob('*.png')):
        target = dest / path.name
        shutil.copy2(path, target)
        with Image.open(target) as image:
            size = list(image.size)
            image.verify()
        files.append({'file': target.name, 'sha256': digest(target), 'size': size})
    return files


def archive_motion(src, dest, prune):
    stills = copy_pngs(src, dest)
    gestures = []
    for gesture in sorted((src / 'frames').iterdir()):
        if not gesture.is_dir():
            continue
        paths = sorted(gesture.glob('frame-*.ppm'))
        if len(paths) != 18:
            raise ValueError('%s: expected 18 PPMs, got %d' % (gesture, len(paths)))
        times = [float(x) for x in (gesture / 'times.txt').read_text().splitlines()]
        trigger = float((gesture / 'trigger.txt').read_text().strip())
        if len(times) != len(paths) or any(b <= a for a, b in zip(times, times[1:])):
            raise ValueError('%s: invalid capture times' % gesture)
        target = dest / 'motion' / gesture.name
        target.mkdir(parents=True, exist_ok=True)
        shutil.copy2(gesture / 'times.txt', target / 'times.txt')
        shutil.copy2(gesture / 'trigger.txt', target / 'trigger.txt')
        previews = []
        sheet = Image.new('RGB', (1920, 3 * 206), '#101718')
        sheet_draw = ImageDraw.Draw(sheet)
        sources = []
        for n, path in enumerate(paths):
            with Image.open(path) as raw:
                frame = raw.convert('RGB')
            relative = (times[n] - trigger) * 1000
            sources.append({'frame': n, 'source_sha256': digest(path),
                            'capture_start_unix': times[n], 'capture_start_utc': iso(times[n]),
                            'relative_to_trigger_ms': round(relative, 3), 'size': list(frame.size)})
            if n in SAMPLES:
                frame.save(target / ('frame-%02d.png' % n), optimize=True)
            tile = frame.copy()
            tile.thumbnail((320, 180), Image.Resampling.LANCZOS)
            x, y = (n % 6) * 320, (n // 6) * 206
            sheet.paste(tile, (x, y))
            sheet_draw.text((x + 7, y + 183), '%02d   %+0.0f ms' % (n, relative), fill='#d9e5df')
            preview = frame.copy()
            preview.thumbnail((960, 540), Image.Resampling.LANCZOS)
            labelled = Image.new('RGB', (960, 562), '#101718')
            labelled.paste(preview, (0, 0))
            ImageDraw.Draw(labelled).text((8, 544), '%s / %02d / %+0.0f ms from IPC trigger' % (gesture.name, n, relative), fill='#d9e5df')
            previews.append(labelled)
        sheet.save(target / 'contact-sheet.png', optimize=True)
        durations = [max(1, round((b - a) * 1000)) for a, b in zip(times, times[1:])]
        durations.append(durations[-1])
        previews[0].save(target / 'motion.webp', save_all=True,
                         append_images=previews[1:], duration=durations,
                         loop=1, quality=85, method=5)
        manifest = {'source': str(src.relative_to(ROOT)), 'gesture': gesture.name,
                    'kind': 'actual shell capture; app/window data from Hyprland protocol fixture',
                    'trigger_unix': trigger, 'trigger_utc': iso(trigger),
                    'timestamp_semantics': 'date recorded immediately before each grim capture; not compositor presentation time',
                    'selected_full_resolution_frames': list(SAMPLES), 'all_frames': sources,
                    'preview_duration_ms': durations,
                    'last_frame_duration_note': 'last duration repeats the preceding interval; no subsequent timestamp exists'}
        (target / 'timing.json').write_text(json.dumps(manifest, indent=2) + '\n')
        # Reopen every output before deleting only known generated raw frames.
        for path in target.glob('*.png'):
            with Image.open(path) as result:
                result.verify()
        with Image.open(target / 'motion.webp') as result:
            if result.n_frames != 18:
                raise ValueError('WebP did not preserve every captured frame')
        if prune:
            for path in paths:
                path.unlink()
        gestures.append({'gesture': gesture.name, 'capture_start_utc': iso(times[0]),
                         'trigger_utc': iso(trigger), 'capture_end_start_utc': iso(times[-1]),
                         'source_frames': len(paths), 'full_resolution_samples': len(SAMPLES)})
    summary = {'source': str(src.relative_to(ROOT)), 'stills': stills, 'gestures': gestures,
               'raw_ppms_removed_after_archive': prune}
    (dest / 'capture-manifest.json').write_text(json.dumps(summary, indent=2) + '\n')
    print('%s: %d stills, %d gestures archived' % (dest, len(stills), len(gestures)))


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=('motion', 'stills'))
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--prune-raw', action='store_true')
    args = parser.parse_args()
    src, dest = args.source.resolve(), args.destination.resolve()
    if not src.is_relative_to(ROOT / 'build/ui012') or not dest.is_relative_to(ROOT / 'docs/design/thears-piyti'):
        parser.error('paths must be UI-012 build sources and design evidence destinations')
    if args.kind == 'motion':
        archive_motion(src, dest, args.prune_raw)
    else:
        files = copy_pngs(src, dest)
        (dest / 'capture-manifest.json').write_text(json.dumps({'source': str(src.relative_to(ROOT)), 'stills': files}, indent=2) + '\n')
        print('%s: %d stills archived' % (dest, len(files)))


if __name__ == '__main__':
    main()
