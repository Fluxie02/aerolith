"""Check intermediate native frames and archive a small real-rendering strip."""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw
import json

repo = Path(__file__).resolve().parents[4]
run = repo / "build/redesign-2/motion"
out = repo / "docs/design/redesign-2"
d = json.loads((run / "closed.json").read_text())
x, y, w, h = [d[k] for k in ["x", "y", "width", "height"]]
bounds = tuple(round(v * 1.5) for v in [x-w/2+8, y-h/2+8, x+w/2-8, y+h/2-8])
closed = Image.open(run / "closed.png").convert("RGB").crop(bounds)
opened = Image.open(run / "open.png").convert("RGB").crop(bounds)
result = {}
sheet = Image.new("RGB", (1000, 564), "#101518")
draw = ImageDraw.Draw(sheet)
for row, direction in enumerate(["opening", "closing"]):
    intermediate = []
    for frame in range(1, 6):
        image = Image.open(run / f"{direction}-{frame}.png").convert("RGB").crop(bounds)
        if ImageChops.difference(image, closed).getbbox() and ImageChops.difference(image, opened).getbbox():
            intermediate.append(frame)
        image.thumbnail((192, 250))
        draw.text(((frame-1)*200+5, row*282+5), f"{direction} {frame}", fill="#edf3f5")
        sheet.paste(image, ((frame-1)*200+(200-image.width)//2, row*282+26))
    assert intermediate, f"no intermediate {direction} frame captured"
    result[direction] = intermediate
sheet.save(out / "motion.jpg", quality=85, optimize=True)
(out / "checks/motion-evidence.json").write_text(json.dumps(result, indent=2) + "\n")
print("PASS: intermediate opening and closing pixels captured", result)
