# FrustrumSupport

**Status: planned — no implementation yet.**

Internal support-structure generator for frustum-shaped shells. A tall frustum
folded from paper collapses under its own lid; this tool generates the internal
ribs, cross-braces or stacked rings that hold the profile.

## Where the code will come from

Nothing standalone exists yet. In the old repository this was only ever a
placeholder: `frustum_visualization.pde` was created but left empty (0 bytes).

The relevant geometry currently lives inside [PaperPolyhedra](../PaperPolyhedra/):

| Source | What it contributes |
|---|---|
| `Param.pde` | `edgeSlantH_px[]`, `cylinderH_px` — slant-height maths for frustums where top ≠ bottom |
| `KreslingPattern.pde` | Per-panel interpolation across frustum profiles |
| `BasePlate.pde` | Base plate generation, the closest existing analogue to a support |
| `BarAssembly.pde` | Internal bar/cell structures |

So this is an **extraction**, not a migration: lift the frustum profile maths out
of PaperPolyhedra rather than starting from scratch.

## Scope sketch

- Input: frustum profile — top perimeter, bottom perimeter, height, sides
- Output: flat cut patterns for internal supports, in the standard PDF + SVG trio
- Must respect the same mm/px conventions as the rest of the toolbox
  (see [docs/shared-concepts.md](../docs/shared-concepts.md))

## Getting started

Follow [docs/adding-a-tool.md](../docs/adding-a-tool.md). The main sketch must be
`FrustrumSupport.pde` in this folder for Processing to open it.
