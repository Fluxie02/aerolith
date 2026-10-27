"""Archive only real headless captures; fail if any required capture is absent."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

repo = Path(__file__).resolve().parents[4]
build = repo / "build/redesign-2"
out = repo / "docs/design/redesign-2"
evidence = {}
captures = {}
captures["interface-unavailable"] = build / "after-1920/interface-state.png"
for size in [1920, 2560, 3840]:
    captures[f"before-{size}"] = build / f"before-{size}/desktop.png"
    for state in ["closed-empty", "open-empty", "closed-parked", "open-parked"]:
        captures[f"{size}-{state}"] = build / f"after-{size}/{state}.png"
missing = [str(p.relative_to(repo)) for p in captures.values() if not p.is_file()]
if missing:
    raise SystemExit("Missing real captures; no screenshots archived:\n" + "\n".join(missing))
for name, source in captures.items():
    image = Image.open(source).convert("RGB")
    native = image.size
    image.thumbnail((1280, 720))
    target = out / f"{name}.jpg"
    image.save(target, quality=85, optimize=True)
    evidence[name] = {"source": str(source.relative_to(repo)), "capture_pixels": native,
                      "archive_pixels": image.size, "bytes": target.stat().st_size}

def hatch_crop(run, state, scale=1.5):
    data = json.loads((run / f"{state}.json").read_text())
    x, y, w, h = [data[k] for k in ["x", "y", "width", "height"]]
    bounds = tuple(round(v * scale) for v in [x-w/2-16, y-h/2-44, x+w/2+16, y+h/2+100])
    return Image.open(run / f"{state}.png").convert("RGB").crop(bounds)

for state in ["closed-empty", "open-empty", "closed-parked", "open-parked",
              "reduced-closed", "reduced-open", "off-closed", "off-open"]:
    image = hatch_crop(build / "after-1920", state)
    target = out / f"detail-{state}.jpg"
    image.save(target, quality=88, optimize=True)
    evidence[target.stem] = {"source": f"build/redesign-2/after-1920/{state}.png",
                             "archive_pixels": image.size, "bytes": target.stat().st_size}

schemes = "limb bathyal corona cinder ferrite iris argent lichen helios umbra vellum glacial".split()
for direction in ["piyti", "thears"]:
    for intensity in ["saturated", "insane"]:
        sheet = Image.new("RGB", (960, 1072), "#101518")
        draw = ImageDraw.Draw(sheet)
        for i, scheme in enumerate(schemes):
            x, y = i % 3 * 320, i // 3 * 268
            draw.text((x+6, y+4), f"{scheme}: closed / open", fill="#edf3f5")
            for j, state in enumerate(["closed", "open"]):
                name = f"{direction}-{intensity}-{scheme}-{state}"
                image = hatch_crop(build / "matrix", name)
                image.thumbnail((158, 240))
                sheet.paste(image, (x+j*160+(160-image.width)//2, y+24))
        target = out / f"schemes-{direction}-{intensity}.jpg"
        sheet.save(target, quality=85, optimize=True)
        evidence[target.stem] = {"source": "build/redesign-2/matrix", "states": 24,
                                 "archive_pixels": sheet.size, "bytes": target.stat().st_size}

evidence["scope"] = {"after": "Real Quickshell rendering with visual-only scratch data and test Registry command in a disposable shell copy.",
                     "before": "Unmodified shell archived from 7f2908693f97868f807a22e5b9747321f42605ad.",
                     "scale": 1.5, "integration": "Actual Hyprland scratch dispatch/keybinds belong to Sol and are not exercised by the visual fixture."}
(out / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
