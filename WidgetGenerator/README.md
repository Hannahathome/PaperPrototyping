# WidgetGenerator

**Status: planned — no implementation yet.**

Standalone generator for the button and widget templates used in PaperPolyhedra
builds — haptic Kresling buttons, base plates that seat them, and the interactive
elements mounted into a polyhedron shell.

## Where the code will come from

This capability already works, but only as a mode inside
[PaperPolyhedra](../PaperPolyhedra/). The old repository's `output/` folder is
full of its results — `buttons_*.pdf`, `higher kresling buttons *.pdf`,
`buttons + base place_*.pdf`, `inner box buttons v2_*.pdf`.

| Source | What it contributes |
|---|---|
| `KreslingHaptics.pde` | Haptic button geometry — the core of this tool |
| `KreslingPattern.pde` | Underlying Kresling fold pattern |
| `BasePlate.pde` | Base plates the buttons mount into |
| `Cutout.pde` | Cutouts for seating widgets in a shell |

So this is an **extraction**: pull these into a focused tool so buttons can be
designed without loading the full polyhedra UI, and so PaperPolyhedra can shed a
responsibility rather than keep growing.

## Open design question

Decide early whether PaperPolyhedra keeps its button mode after extraction or
delegates to this tool. Two tools generating the same geometry from two copies of
the maths is exactly the divergence that made the old repository hard to manage.

## Getting started

Follow [docs/adding-a-tool.md](../docs/adding-a-tool.md). The main sketch must be
`WidgetGenerator.pde` in this folder for Processing to open it.
