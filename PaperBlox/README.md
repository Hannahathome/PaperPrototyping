# PaperBlox

**Status: planned — no implementation yet.**

A stripped-down PaperPolyhedra. Simple blocks, few controls, fast path from
opening the sketch to a printable net — for workshops, teaching, and the common
case where the full parametric interface is more than the job needs.

## Where the code will come from

To be added from outside this repository.

Two candidates exist in the archived PaperVoxels repository if you would rather
start from something working than from scratch:

| Candidate | Notes |
|---|---|
| `workshop_v4` (Feb 2026) | Frozen teaching build — 15 sketches against PaperPolyhedra's 33. Simpler *interface*, which is probably the right axis. |
| `dev_V9B_RH_v2_1_H_cuboids_cutouts` (Jun 2026) | Cuboids plus cutouts. Simpler *geometry* rather than simpler interface. |

## Scope sketch

The value here is what it leaves out. Worth deciding up front:

- Which controls survive, and which get sensible fixed defaults
- Whether textures are supported at all, or blocks stay plain
- Whether it exports the full PDF + SVG + calibration trio, or just a printable PDF

Keep the mm/px conventions in
[docs/shared-concepts.md](../docs/shared-concepts.md) even if the interface is
simplified — output from this tool should cut on the same calibrated setup as
everything else.

## Getting started

Follow [docs/adding-a-tool.md](../docs/adding-a-tool.md). The main sketch must be
`PaperBlox.pde` in this folder for Processing to open it.
