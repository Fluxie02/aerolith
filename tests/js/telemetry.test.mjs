import { suite } from "./harness.mjs";
import * as T from "../../shell/lib/telemetry.mjs";

const STAT_A = `cpu  100 0 100 800 0 0 0 0 0 0
cpu0 50 0 50 400 0 0 0 0 0 0
cpu1 50 0 50 400 0 0 0 0 0 0
intr 12345
ctxt 999`;

const STAT_B = `cpu  200 0 150 850 0 0 0 0 0 0
cpu0 140 0 60 400 0 0 0 0 0 0
cpu1 60 0 90 450 0 0 0 0 0 0
intr 12400`;

const MEMINFO = `MemTotal:       16000000 kB
MemFree:         2000000 kB
MemAvailable:    6000000 kB
Buffers:          500000 kB
Cached:          3000000 kB
SwapTotal:       8000000 kB
SwapFree:        6000000 kB
HugePages_Total:       0`;

const NETDEV = `Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 1000000     100    0    0    0     0          0         0  1000000     100    0    0    0     0       0          0
enp5s0: 5000000    4000    0    0    0     0          0         0   200000    1500    0    0    0     0       0          0
docker0: 900000      10    0    0    0     0          0         0   900000      10    0    0    0     0       0          0`;

const NETDEV2 = NETDEV.replace("enp5s0: 5000000", "enp5s0: 6000000").replace("200000    1500", "300000    1500").replace("lo: 1000000", "lo: 9000000");

export default suite("telemetry", (test) => {
  test("parses /proc/stat totals and per-core jiffies", (assert) => {
    const s = T.parseProcStat(STAT_A);
    assert.deepEqual(s.total, { busy: 200, idle: 800, all: 1000 });
    assert.equal(s.cpus.length, 2);
    assert.equal(T.parseProcStat("garbage"), null);
  });

  test("computes CPU utilisation from deltas", (assert) => {
    const u = T.cpuUsage(T.parseProcStat(STAT_A), T.parseProcStat(STAT_B));
    // total: busy +150 of +200 jiffies = 75%
    assert.approx(u.total, 75);
    assert.approx(u.cores[0], 100); // +100 busy, +0 idle
    assert.approx(u.cores[1], 50); // +50 busy of +100
  });

  test("first sample has no utilisation rather than zero", (assert) => {
    const u = T.cpuUsage(null, T.parseProcStat(STAT_A));
    assert.equal(u.total, null);
  });

  test("identical samples give unknown, not 0%", (assert) => {
    const s = T.parseProcStat(STAT_A);
    assert.equal(T.cpuUsage(s, s).total, null);
  });

  test("parses meminfo in bytes and computes usage from MemAvailable", (assert) => {
    const m = T.memoryUsage(T.parseMeminfo(MEMINFO));
    assert.equal(m.totalBytes, 16000000 * 1024);
    assert.equal(m.usedBytes, 10000000 * 1024);
    assert.approx(m.percent, 62.5);
    assert.approx(m.swapPercent, 25);
    assert.equal(T.parseMeminfo(MEMINFO).HugePages_Total, 0, "unitless fields are not scaled");
  });

  test("swap is unknown when the kernel does not report it", (assert) => {
    const m = T.memoryUsage(T.parseMeminfo("MemTotal: 1000 kB\nMemAvailable: 500 kB"));
    assert.equal(m.swapTotalBytes, null);
    assert.equal(m.swapPercent, null);
  });

  test("parses PSI pressure files and reports absence as null", (assert) => {
    const p = T.parsePressure("some avg10=1.50 avg60=0.75 avg300=0.10 total=123\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0");
    assert.approx(p.some.avg10, 1.5);
    assert.approx(p.full.avg300, 0);
    assert.equal(T.parsePressure(""), null);
  });

  test("network rates exclude loopback and virtual bridges", (assert) => {
    const r = T.netRates(T.parseNetDev(NETDEV), T.parseNetDev(NETDEV2), 2000);
    assert.approx(r.rxBps, 500000); // 1 MB over 2 s on enp5s0 only
    assert.approx(r.txBps, 50000);
    assert.approx(r.ifaces.lo.rxBps, 4000000, 1e-6, "loopback is still reported per interface");
  });

  test("counter resets do not produce negative rates", (assert) => {
    const r = T.netRates(T.parseNetDev(NETDEV2), T.parseNetDev(NETDEV), 1000);
    assert.equal(r.rxBps, 0);
  });

  test("nvidia-smi CSV parsing maps N/A to null", (assert) => {
    const g = T.parseNvidiaSmi("37, 2048, 8192, 61, [N/A], 1830, NVIDIA GeForce RTX 3070");
    assert.equal(g.utilPercent, 37);
    assert.equal(g.vramUsedBytes, 2048 * 1024 * 1024);
    assert.equal(g.powerW, null);
    assert.equal(g.name, "NVIDIA GeForce RTX 3070");
    assert.equal(T.parseNvidiaSmi("garbage"), null);
  });

  test("top processes use CPU-time deltas and skip reused PIDs", (assert) => {
    const a = T.parsePs("  100   10  2048 firefox\n  200    5  1024 foot\n  300    1   512 old");
    const b = T.parsePs("  100   14  2048 firefox\n  200    5  1024 foot\n  300    9   512 new");
    const top = T.topProcesses(a, b, 2000, 5);
    assert.equal(top[0].comm, "firefox");
    assert.approx(top[0].cpuPercent, 200); // 4 CPU-seconds in 2 s
    const reused = top.filter((p) => p.pid === 300)[0];
    assert.equal(reused.cpuPercent, null, "pid 300 changed command, so no delta");
  });

  test("ps parsing keeps command names with spaces", (assert) => {
    const p = T.parsePs("  42  3  100 Web Content");
    assert.equal(p[0].comm, "Web Content");
  });

  test("df parsing", (assert) => {
    const d = T.parseDf("Filesystem 1-blocks Used Available Capacity Mounted on\n/dev/nvme0n1p2 1000 250 750 25% /\n/dev/sda1 2000 2000 0 100% /mnt/My Disk");
    assert.equal(d.length, 2);
    assert.approx(d[0].percent, 25);
    assert.equal(d[1].mount, "/mnt/My Disk");
  });

  test("hwmon selection prefers package/edge sensors", (assert) => {
    const pick = T.pickHwmon([
      { name: "nvme", label: "Composite", path: "/n" },
      { name: "k10temp", label: "Tccd1", path: "/c1" },
      { name: "k10temp", label: "Tctl", path: "/c0" },
      { name: "amdgpu", label: "junction", path: "/gj" },
      { name: "amdgpu", label: "edge", path: "/ge" },
    ]);
    assert.deepEqual(pick, { cpu: "/c0", gpu: "/ge", nvme: "/n" });
  });

  test("history is bounded", (assert) => {
    const h = T.createHistory(3);
    for (let i = 0; i < 10; i++) h.push(i);
    assert.deepEqual(h.values(), [7, 8, 9]);
    assert.equal(h.last(), 9);
  });

  test("adaptive sampling: nothing when nobody watches", (assert) => {
    const iv = { stripMs: 5000, panelMs: 2000, detailMs: 1000 };
    assert.equal(T.samplingInterval({}, iv, false), 0);
    assert.equal(T.samplingInterval({ strip: true }, iv, false), 5000);
    assert.equal(T.samplingInterval({ strip: true, panel: true }, iv, false), 2000);
    assert.equal(T.samplingInterval({ panel: true, detail: true }, iv, false), 1000);
    assert.equal(T.samplingInterval({ detail: true }, iv, true), 2000, "performance mode slows down");
  });

  test("classification and formatting distinguish unknown from zero", (assert) => {
    assert.equal(T.classify(null, 80, 95), "unknown");
    assert.equal(T.classify(0, 80, 95), "nominal");
    assert.equal(T.classify(85, 80, 95), "caution");
    assert.equal(T.classify(99, 80, 95), "critical");
    assert.equal(T.formatPercent(null), "N/A");
    assert.equal(T.formatPercent(0), "0%");
    assert.equal(T.formatBytes(1536), "1.5 KiB");
    assert.equal(T.formatBytes(0), "0 B");
    assert.equal(T.formatTemp(61.6), "62°C");
    assert.equal(T.formatDuration(5400), "1h 30m");
  });
});
