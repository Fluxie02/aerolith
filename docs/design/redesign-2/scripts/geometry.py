"""Arithmetic layout audit at default UI scale; this is not a render check."""
import json
import math

results = []
for physical_width, physical_height, scale in [(1920, 1080, 1.5), (2560, 1440, 1.5),
                                               (3840, 2160, 1.5), (1920, 1080, 1)]:
    w, h = physical_width / scale, physical_height / scale
    width, height = min(w * .18, 360), min(h * .34, 380)
    left, top = w * .59 - width / 2, h * .49 - height / 2
    # Includes the header and the full hit area beneath the aperture.
    bounds = [left, top - 28, left + width, top + height + 88]
    assert 0 <= bounds[0] < bounds[2] <= w * .69, bounds
    assert 52 < bounds[1] < bounds[3] < h - 64, bounds
    compact = w < 1500 or h < 850
    station_width = min(76, w * .47 / 5 - 6)
    stations = []
    for i in range(5):
        angle = -.92 + i * 1.84 / 4
        x = w * (.055 + .47 * (i + .5) / 5) if compact else w * .27 + math.sin(angle) * h * .29
        y = h - 125 if compact else h * .55 + math.cos(angle) * h * .29
        station = [x - station_width / 2, y - 28, x + station_width / 2, y + 28]
        assert bounds[2] <= station[0] or station[2] <= bounds[0] or bounds[3] <= station[1] or station[3] <= bounds[1], (bounds, station)
        stations.append(station)
    results.append({"physical": [physical_width, physical_height], "scale": scale,
                    "logical": [w, h], "hatch_bounds": bounds, "stations": stations,
                    "result": "no geometric overlap with stations, media column or app bar"})
print(json.dumps({"scope": "default uiScale/density; arithmetic only, no font or rendering validation", "layouts": results}, indent=2))
