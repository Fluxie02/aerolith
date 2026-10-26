#!/usr/bin/env python3
"""Print the GPU memory one process holds on the NVIDIA driver, in KiB.

Reads `nvidia-smi -q -x` from stdin; the PID is the only argument. Prints
nothing when the process is not listed or the driver reports no figure
(some drivers show "N/A" per process). The NVIDIA driver does not fill DRM
fdinfo, so this is the only per-process source there.
"""
import sys
import xml.etree.ElementTree as ET

UNITS = {"KiB": 1, "MiB": 1024, "GiB": 1024 * 1024}


def process_kib(xml_text: str, pid: int) -> int | None:
    total, seen = 0, False
    for proc in ET.fromstring(xml_text).iter("process_info"):
        if (proc.findtext("pid") or "").strip() != str(pid):
            continue
        parts = (proc.findtext("used_memory") or "").split()
        if len(parts) == 2 and parts[1] in UNITS:
            try:
                total += int(float(parts[0]) * UNITS[parts[1]])
                seen = True
            except ValueError:
                pass
    return total if seen else None


if __name__ == "__main__":
    try:
        kib = process_kib(sys.stdin.read(), int(sys.argv[1]))
    except (ET.ParseError, IndexError, ValueError):
        kib = None
    if kib is not None:
        print(kib)
