"""Keep judged screenshots small; preserve capture dimensions in evidence.json."""
from pathlib import Path
import json
from PIL import Image, ImageChops

repo = Path(__file__).resolve().parents[4]
build = repo / 'build/redesign-1'
out = repo / 'docs/design/redesign-1'
screens = {}
for size, run in [('1920', '1080'), ('2560', '1440'), ('3840', '4k')]:
 for stage in ['before', 'after']:
  screens[f'{stage}-{size}'] = build / f'{stage}-{run}/desktop.png'
for name, source in {
 'media-cover': 'after-1080/media-cover', 'media-paused': 'after-1080/media-paused',
 'workspace-05': 'after-1080/workspace-05',
 'reduced-workspace-05': 'after-1080/reduced-workspace-05',
 'reduced-workspace-01': 'after-1080/reduced-workspace-01',
 'deck': 'after-1080/motion-off-command', 'compact': 'compact/media-cover',
 'compact-deck': 'compact/compact-command', 'thears': 'thears/thears-desktop',
 'media-3840': 'after-4k/media-cover',
}.items():
 screens[name] = build / (source + '.png')
evidence = {}
for name, source in screens.items():
 im = Image.open(source).convert('RGB')
 evidence[name] = {'source': str(source.relative_to(repo)), 'capture_pixels': im.size}
 im.thumbnail((1600, 900))
 im.save(out / (name + '.jpg'), quality=86, optimize=True)
 evidence[name]['archived_pixels'] = im.size
 evidence[name]['bytes'] = (out / (name + '.jpg')).stat().st_size
crop = (980, 350, 1270, 700)
a = Image.open(build / 'after-1080/reduced-workspace-05.png').crop(crop)
b = Image.open(build / 'after-1080/reduced-workspace-01.png').crop(crop)
evidence['reduced_motion'] = {'wing_crop': crop, 'identical_across_workspace_changes': ImageChops.difference(a, b).getbbox() is None}
(out / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')

# A compact contact sheet keeps all 24 judged palette/intensity views together.
from PIL import ImageDraw
names = 'limb bathyal corona cinder ferrite iris argent lichen helios umbra vellum glacial'.split()
canvas = Image.new('RGB', (1280, 1212), '#0d1215')
draw = ImageDraw.Draw(canvas)
for i, (intensity, scheme) in enumerate((i, s) for i in ['saturated', 'insane'] for s in names):
 source = build / 'schemes' / f'{intensity}-{scheme}.png'
 im = Image.open(source).convert('RGB')
 im.thumbnail((320, 180))
 x, y = (i % 4) * 320, (i // 4) * 202
 canvas.paste(im, (x, y + 22))
 draw.text((x + 8, y + 4), source.stem, fill='#edf3f5')
canvas.save(out / 'schemes.jpg', quality=85, optimize=True)
