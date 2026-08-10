# FrustumSupport

Generates 3D-printable internal support skeletons for frustum-shaped paper
shells. A tall frustum folded from paper cannot hold its own profile or carry
electronics; this tool produces the rigid frame that goes inside it.

Formerly `FrustumSupportGenerator_GUI_v3Toggle`.

## Different from the other tools

This is the only tool in the toolbox that does **not** produce print-and-cut
files. It emits **OpenSCAD** source, which you render and export to STL for a
3D printer. The paper shell comes from
[PaperPolyhedra](../PaperPolyhedra/); the frame inside it comes from here.

## Running

Open `FrustumSupport.pde` in Processing 4.3+ and press Run.
Requires the **ControlP5** library.

You will also need [OpenSCAD](https://openscad.org/) to turn the exported
`.scad` into a printable mesh.

## Workflow

1. Set the frustum to match the paper shell it goes inside:

   | Parameter | Meaning |
   |---|---|
   | `frustum_nside` | Number of sides |
   | `frustum_bottom_radius` | Bottom circumradius (mm) |
   | `frustum_top_radius` | Top circumradius (mm) |
   | `frustum_height` | Overall height (mm) |
   | `edge_radius` | Strut thickness — the printed wireframe edge radius |

   These must match the shell, or the frame will not seat. Note the tool works
   in **radii**, while PaperPolyhedra is driven by perimeters and edge widths.

2. Add rigs — cuboid mounts for components inside the frame. Each has width,
   depth, height, X/Y/Z offset, and a yaw rotation about its own offset point.

3. Pick a template for common hardware instead of typing dimensions:

   | Template | W × D × H (mm) |
   |---|---|
   | M5Atom / lying | 24 × 24 × 31.5 / 24 × 31.5 × 24 |
   | M5Core / lying | 54 × 17 × 54 / 54 × 54 × 17 |
   | M5Core+Ext / lying | 54 × 21 × 54 / 54 × 54 × 21 |

   `Custom` leaves the values alone.

4. Export. Writes a `.scad` next to the sketch — gitignored, along with any
   `.stl` you render from it.

5. Open the `.scad` in OpenSCAD, render (F6), export STL, print.

## Source layout

| File | Role |
|---|---|
| `FrustumSupport.pde` | The whole tool — GUI, geometry, preview, OpenSCAD export |
| `data/template_simple.txt` | `frustum()` module — wireframe with wedge-flap struts |
| `data/template_full.txt` | Fuller frustum module used by the alternate toggle mode |
| `data/template_helper.txt` | `_local_draw_edge` / `_local_draw_half_edge` primitives |

The `data/*.txt` files are OpenSCAD source loaded at runtime and pasted into
every export. They are committed because the tool cannot generate them — edit
them to change the printed geometry itself, rather than the parameters.

`flap_length` is written near the top of each exported file and can be tweaked
directly in OpenSCAD without re-exporting.

## Possible follow-up

Exports land in the sketch folder rather than `output/`, which is why
`.gitignore` carries a global `*.scad` / `*.stl` rule. Pointing `saveOpenSCADFile()`
at `output/` would bring this tool in line with the rest of the toolbox and let
that rule be narrowed. Left as-is for now to avoid changing behaviour during the
migration.
