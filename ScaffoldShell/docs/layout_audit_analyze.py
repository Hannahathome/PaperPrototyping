#!/usr/bin/env python
"""Analyse layout_boxes.csv: space consumed per zone, overlaps, off-window elements."""
import csv, collections, io, os, sys

# Reads the sweep written by LayoutAudit.pde. Pass a directory to override.
SP = (sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))).rstrip("/\\") + "/"

TOOLBAR_H, SIDEBAR_W, EXPORT_H = 50, 420, 90

rows = []
with io.open(SP + "layout_boxes.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        if r["kind"] == "cp5abs":          # unreliable in this ControlP5 build
            continue
        for k in ("x", "y", "w", "h"):
            r[k] = float(r[k])
        r["win_w"], r["win_h"] = int(r["win_w"]), int(r["win_h"])
        r["visible"] = (r["visible"] == "true")
        r["x2"], r["y2"] = r["x"] + r["w"], r["y"] + r["h"]
        rows.append(r)

by_cfg = collections.defaultdict(list)
for r in rows:
    by_cfg[r["config"]].append(r)

PAGE_DRAWERS = ("drawa4paper", "drawplan", "drawshapeinfonote", "drawcalibcross",
                "drawassemblyplan", "drawbase", "drawcutout", "drawmarker", "drawlid",
                "drawtab", "drawflap", "drawgrid", "drawstrip", "drawdistance",
                "drawrepeat", "drawpanel", "drawtess", "drawhollow", "drawinner")

def is_chrome(r):
    if r["kind"] == "region":
        return False
    s = r["source"].lower()
    return not any(p in s for p in PAGE_DRAWERS)

def is_parked(r):
    return r["x"] < -900 or r["y"] < -900

def is_background(r, W, H):
    """Full-panel fills: the sidebar/toolbar/export-bar grounds, not content."""
    return r["kind"] == "rect" and (r["w"] >= SIDEBAR_W - 1 and r["h"] > 200)

def overlap(a, b):
    ox = min(a["x2"], b["x2"]) - max(a["x"], b["x"])
    oy = min(a["y2"], b["y2"]) - max(a["y"], b["y"])
    return (ox, oy) if ox > 1 and oy > 1 else None

out = []
def p(s=""):
    out.append(s); print(s)

order = sorted(by_cfg, key=lambda c: (by_cfg[c][0]["win_w"], by_cfg[c][0]["mode"], by_cfg[c][0]["tab"]))

# ------------------------------------------------------- 1. zone extents
p("=" * 92)
p("1.  MEASURED CONTENT EXTENT PER ZONE (visible chrome, panel backgrounds excluded)")
p("=" * 92)
p()
p("%-24s %9s %9s %9s %9s %9s %7s" % ("config", "sbar_bot", "sbar_max_x",
                                     "tbar_max_x", "export_top", "export_max_x", "widgets"))
p("-" * 92)

Z = {}
for cfg in order:
    rs = [r for r in by_cfg[cfg] if is_chrome(r) and r["visible"] and not is_parked(r)]
    W, H = by_cfg[cfg][0]["win_w"], by_cfg[cfg][0]["win_h"]
    content = [r for r in rs if not is_background(r, W, H)]
    sb = [r for r in content if (r["x"] + r["x2"]) / 2 < SIDEBAR_W and (r["y"] + r["y2"]) / 2 > TOOLBAR_H
          and (r["y"] + r["y2"]) / 2 < H - EXPORT_H]
    tb = [r for r in content if (r["y"] + r["y2"]) / 2 <= TOOLBAR_H]
    ex = [r for r in content if (r["y"] + r["y2"]) / 2 >= H - EXPORT_H]
    Z[cfg] = dict(W=W, H=H, all=rs, content=content, sb=sb, tb=tb, ex=ex,
                  sbar_bot=max([r["y2"] for r in sb], default=0),
                  sbar_x=max([r["x2"] for r in sb], default=0),
                  tbar_x=max([r["x2"] for r in tb], default=0),
                  ex_top=min([r["y"] for r in ex], default=H),
                  ex_x=max([r["x2"] for r in ex], default=0))
    z = Z[cfg]
    p("%-24s %9.0f %9.0f %9.0f %9.0f %9.0f %7d"
      % (cfg, z["sbar_bot"], z["sbar_x"], z["tbar_x"], z["ex_top"], z["ex_x"],
         len([r for r in content if r["kind"] == "cp5"])))

# ------------------------------------------------------- 2. sidebar vertical budget
p()
p("=" * 92)
p("2.  SIDEBAR VERTICAL BUDGET  (content bottom vs window height)")
p("=" * 92)
p()
p("%-24s %7s %12s %10s  %s" % ("config", "win_h", "content_bot", "overflow", "verdict"))
p("-" * 92)
worst = []
for cfg in order:
    z = Z[cfg]
    ov = z["sbar_bot"] - z["H"]
    worst.append((ov, cfg))
    p("%-24s %7d %12.0f %10.0f  %s"
      % (cfg, z["H"], z["sbar_bot"], ov,
         "CLIPPED by %.0f px" % ov if ov > 0 else "fits (%.0f px spare)" % -ov))
p()
worst.sort(reverse=True)
p("Worst case: %s overflows by %.0f px" % (worst[0][1], worst[0][0]))

# ------------------------------------------------------- 3. off-window
p()
p("=" * 92)
p("3.  VISIBLE ELEMENTS DRAWN OUTSIDE THE WINDOW")
p("=" * 92)
p()
seen = collections.defaultdict(list)
for cfg in order:
    z = Z[cfg]
    for r in z["all"]:
        if r["x"] < -1 or r["y"] < -1 or r["x2"] > z["W"] + 1 or r["y2"] > z["H"] + 1:
            seen[(r["kind"], r["source"], r["label"])].append(
                (cfg, r["x"], r["y"], r["w"], r["h"], z["W"], z["H"]))
if not seen:
    p("  none")
for k, v in sorted(seen.items(), key=lambda kv: -len(kv[1]))[:20]:
    p("  [%s] %s :: %s   (%d configs)" % (k[0], k[1], k[2], len(v)))
    for s in v[:2]:
        p("        %-24s box=(%.0f,%.0f %.0fx%.0f)  window=%dx%d" % s)

# ------------------------------------------------------- 4. widget overlaps
p()
p("=" * 92)
p("4.  WIDGET-ON-WIDGET OVERLAPS  (visible ControlP5 controls)")
p("=" * 92)
p()
pair = collections.defaultdict(list)
for cfg in order:
    cp5 = [r for r in Z[cfg]["content"] if r["kind"] == "cp5"]
    for i, a in enumerate(cp5):
        for b in cp5[i + 1:]:
            o = overlap(a, b)
            if o:
                pair[tuple(sorted([a["label"], b["label"]]))].append((cfg, o[0], o[1]))
if not pair:
    p("  none")
for k, v in sorted(pair.items(), key=lambda kv: -len(kv[1]))[:30]:
    p("  %-28s x %-28s %3d cfgs  overlap %.0fx%.0f px (e.g. %s)"
      % (k[0], k[1], len(v), v[0][1], v[0][2], v[0][0]))

# ------------------------------------------------------- 5. escaping the sidebar
p()
p("=" * 92)
p("5.  SIDEBAR CONTENT CROSSING INTO THE CANVAS (x2 > %d)" % SIDEBAR_W)
p("=" * 92)
p()
esc = collections.defaultdict(list)
for cfg in order:
    for r in Z[cfg]["sb"]:
        if r["x2"] > SIDEBAR_W + 1:
            esc[(r["kind"], r["source"], r["label"])].append((cfg, r["x"], r["x2"]))
if not esc:
    p("  none")
for k, v in sorted(esc.items(), key=lambda kv: -len(kv[1]))[:20]:
    p("  [%s] %-34s %-22s %2d cfgs  x=%.0f..%.0f (over by %.0f)"
      % (k[0], k[1], k[2], len(v), v[0][1], v[0][2], v[0][2] - SIDEBAR_W))

# ------------------------------------------------------- 6. export bar collisions
p()
p("=" * 92)
p("6.  BOTTOM EXPORT BAR: content vs available width")
p("=" * 92)
p()
p("Export bar spans x=%d..win_w, y=win_h-%d..win_h" % (SIDEBAR_W, EXPORT_H))
p()
p("%-24s %8s %12s %12s  %s" % ("config", "win_w", "left_group", "right_group", "gap"))
p("-" * 92)
for cfg in order:
    z = Z[cfg]
    if not z["ex"]:
        continue
    left = [r for r in z["ex"] if r["kind"] == "cp5" and r["x"] < z["W"] - 340]
    right = [r for r in z["ex"] if r["kind"] == "cp5" and r["x"] >= z["W"] - 340]
    if not left or not right:
        continue
    lmax = max(r["x2"] for r in left)
    rmin = min(r["x"] for r in right)
    p("%-24s %8d %12.0f %12.0f  %s"
      % (cfg, z["W"], lmax, rmin,
         "OVERLAP %.0f px" % (lmax - rmin) if lmax > rmin else "%.0f px clear" % (rmin - lmax)))

# ------------------------------------------------------- 7. responsiveness
p()
p("=" * 92)
p("7.  RESPONSIVENESS: which widgets follow the window edges")
p("=" * 92)
p()
p("1500x800 -> 2560x1440: right-anchored widgets should move +1060 x, bottom-anchored +640 y.")
p()
for mode, tab in [("2D", 0), ("2D", 1), ("2D", 2), ("3D", 0), ("ASSEMBLY", 3)]:
    a_cfg, b_cfg = "1500x800|%s|tab%d" % (mode, tab), "2560x1440|%s|tab%d" % (mode, tab)
    if a_cfg not in by_cfg or b_cfg not in by_cfg:
        continue
    A = {r["label"]: r for r in by_cfg[a_cfg] if r["kind"] == "cp5" and r["visible"] and not is_parked(r)}
    B = {r["label"]: r for r in by_cfg[b_cfg] if r["kind"] == "cp5" and r["visible"] and not is_parked(r)}
    moved, fixed = [], []
    for k in A:
        if k not in B:
            continue
        dx, dy = B[k]["x"] - A[k]["x"], B[k]["y"] - A[k]["y"]
        (moved if (abs(dx) > 1 or abs(dy) > 1) else fixed).append((k, dx, dy))
    p("  %-12s tab%d : %2d follow the window, %2d pinned to fixed coordinates"
      % (mode, tab, len(moved), len(fixed)))
    if moved:
        p("        follow : " + ", ".join("%s(%+.0f,%+.0f)" % m for m in sorted(moved)[:6]))
    if fixed:
        p("        pinned : " + ", ".join(k for k, _, _ in sorted(fixed)[:10])
          + (" ..." if len(fixed) > 10 else ""))

# ------------------------------------------------------- 8. canvas usage
p()
p("=" * 92)
p("8.  CANVAS USE: how much of the free area the page actually fills")
p("=" * 92)
p()
p("%-24s %14s %16s %10s %10s" % ("config", "canvas WxH", "page WxH", "fill %", "SCREEN_SCALE"))
p("-" * 92)
for cfg in order:
    if by_cfg[cfg][0]["mode"] != "2D" or by_cfg[cfg][0]["tab"] != 0:
        continue
    regs = {r["label"]: r for r in by_cfg[cfg] if r["kind"] == "region"}
    c, pg = regs.get("CANVAS_AREA"), regs.get("PAGE_DISPLAY")
    if not c or not pg:
        continue
    fill = 100.0 * (pg["w"] * pg["h"]) / (c["w"] * c["h"]) if c["w"] * c["h"] else 0
    p("%-24s %14s %16s %9.1f%% %10.3f"
      % (cfg, "%.0fx%.0f" % (c["w"], c["h"]), "%.0fx%.0f" % (pg["w"], pg["h"]),
         fill, pg["w"] / 841.89 if pg["w"] else 0))

# ------------------------------------------------------- 9. buffers
p()
p("=" * 92)
p("9.  OFFSCREEN 3D BUFFER vs AVAILABLE AREA")
p("=" * 92)
p()
p("%-24s %16s %16s  %s" % ("config", "buffer", "expected", "status"))
p("-" * 92)
for cfg in order:
    if by_cfg[cfg][0]["mode"] != "3D" or by_cfg[cfg][0]["tab"] != 0:
        continue
    regs = {r["label"]: r for r in by_cfg[cfg] if r["kind"] == "region"}
    b = regs.get("VIEW3D_BUFFER")
    if not b:
        continue
    W, H = by_cfg[cfg][0]["win_w"], by_cfg[cfg][0]["win_h"]
    ew, eh = W - SIDEBAR_W, H - TOOLBAR_H
    ok = "matches" if abs(b["w"] - ew) < 2 and abs(b["h"] - eh) < 2 else "STALE / wrong size"
    p("%-24s %16s %16s  %s" % (cfg, "%.0fx%.0f" % (b["w"], b["h"]), "%dx%d" % (ew, eh), ok))

# ------------------------------------------------------- 10. tallest sidebar items
p()
p("=" * 92)
p("10. LOWEST SIDEBAR ITEMS AT THE SMALLEST WINDOW (1280x720) - what gets cut first")
p("=" * 92)
p()
for tab in (0, 1, 2):
    cfg = "1280x720|2D|tab%d" % tab
    if cfg not in Z:
        continue
    items = sorted(Z[cfg]["sb"], key=lambda r: -r["y2"])[:10]
    p("  tab%d:" % tab)
    for r in items:
        p("      y=%7.1f..%7.1f  [%s] %-34s %s" % (r["y"], r["y2"], r["kind"], r["source"], r["label"]))

with io.open(SP + "layout_report.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print("\n[written] " + SP + "layout_report.txt")
