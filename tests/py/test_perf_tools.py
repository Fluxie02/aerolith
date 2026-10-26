"""tools/perf/nvidia-process-mem.py: per-process GPU memory on the NVIDIA driver."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "tools" / "perf" / "nvidia-process-mem.py"

# Trimmed from `nvidia-smi -q -x` (driver 580): two graphics clients, one of
# them with no per-process figure.
REPORT = """<?xml version="1.0" ?>
<nvidia_smi_log>
  <gpu id="00000000:01:00.0">
    <product_name>NVIDIA GeForce RTX 4060 Ti</product_name>
    <processes>
      <process_info>
        <pid>4242</pid>
        <type>G</type>
        <process_name>/usr/bin/qs</process_name>
        <used_memory>187 MiB</used_memory>
      </process_info>
      <process_info>
        <pid>5151</pid>
        <type>G</type>
        <process_name>game.exe</process_name>
        <used_memory>N/A</used_memory>
      </process_info>
    </processes>
  </gpu>
</nvidia_smi_log>
"""


def run(pid, text=REPORT):
    return subprocess.run([sys.executable, "-I", str(TOOL), str(pid)], input=text,
                          capture_output=True, text=True, check=True).stdout.strip()


def test_reads_the_process_memory_in_kib():
    assert run(4242) == str(187 * 1024)


def test_prints_nothing_without_a_figure():
    assert run(5151) == ""
    assert run(9999) == ""
    assert run(4242, "not xml") == ""


def test_sums_the_process_over_several_gpus():
    two = REPORT.replace("</nvidia_smi_log>", """  <gpu id="00000000:02:00.0"><processes><process_info>
    <pid>4242</pid><type>G</type><used_memory>1 GiB</used_memory>
  </process_info></processes></gpu>
</nvidia_smi_log>""")
    assert run(4242, two) == str(187 * 1024 + 1024 * 1024)
