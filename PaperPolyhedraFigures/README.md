# PaperPolyhedraFigures

A figure tool, not a fabrication tool. It draws the flat template [PaperPolyhedra](../PaperPolyhedra/)
cuts for a shape, as a clean line figure for papers, in two panels:

| Panel | Shows |
|---|---|
| a, Template | the whole template: strip, glue flap, hook flap and both lids. Full cuts in red, folds dashed blue. Numbered frames show where each close-up comes from; the panel's height and its two edge widths are dimensioned on panel 2 of the strip |
| b, Details | four close-ups, each with its sizes dimensioned in millimetres: 1 a wall tab, 2 the glue flap, 3 the barbed end of the hook flap, 4 a lid tab |

Under each close-up, a note gives the rules PaperPolyhedra uses for the sizes that have no
slider of their own, such as inset = 1/4 edge, flare = inset / 3 and neck = 0.2 × tab depth.
*Notes* (or `N`) turns them off.

Dimension labels never overlap one another. A label that would land on one already placed
moves to the nearest free spot: along its dimension line, further out, or as a last resort
across it. A thin grey leader links it back once it has moved off its line. Checked on 168
shapes, from 3 to 20 sides, prisms and steep frustums, low and tall, whole and split strips.

Each close-up can be zoomed further: the mouse wheel zooms it about the cursor, up to 40×,
dragging pans it, and `R` puts them all back. Dimension lines and text keep their size as
you zoom, so a 1 mm detail gets room for its label. The zoom is part of the export; the
"3.2×" readout in the corner of a zoomed close-up is shown on screen only. The only output
is PNG.

It is the companion of [ScaffoldShellFigures](../ScaffoldShellFigures/), and looks and works
the same way.

## Running

Open `PaperPolyhedraFigures.pde` in Processing 4.3+ and press Run.
Requires the **ControlP5** library. It reads no files.

## Controls

| Input | Does |
|---|---|
| Mouse wheel over a close-up | zoom that close-up in or out, about the cursor |
| Drag in a close-up | pan it |
| `R` | reset every close-up's zoom |
| `D` | toggle the dimensions |
| `N` | toggle the notes under the close-ups |
| `H` | hide or show the sidebar, so the panels fill the window |
| `S` | save PNG |

The sidebar has these sections:

- **Shape:** sides, top and bottom diameter, height, and *Split strip in half*.
- **Tabs and flaps:** tab depth, tab neck ratio, flap depth and flap taper: PaperPolyhedra's
  own sliders, with its ranges.
- **View:** dimensions, notes, close-up frames, legend, panel letters, line weight.
- **Export:** PNG scale (1–6×) and transparent background.

Diameters work as PaperPolyhedra's do: the circumscribed diameter, except at 4 sides, where
PaperPolyhedra's "diameter" is the side length.

PaperPolyhedra limits some sizes: the tab depth to half the shortest edge and half the panel
height, the flap depth to half the shortest edge, the taper to a third of the panel height.
The figure draws the limited size, as PaperPolyhedra would cut it, and the legend under
panel a says when a limit applied.

## Export

**Save PNG** draws both panels again at *PNG scale* × the on-screen size. Lines, dashes and
text scale with it, so the file is the figure on screen, sharper. Written to `output/`
(gitignored):

| File | Contents |
|---|---|
| `template_<stamp>.png` | both panels side by side, with letter tags if *Panel letters* is on |
| `template_<stamp>_template.png` | panel a alone, no tag |
| `template_<stamp>_details.png` | panel b alone, no tag |

## Relationship to PaperPolyhedra

`Template.pde` is a **copy** of the PaperPolyhedra functions that draw the outline, with their
drawing calls recorded as cut and fold lines instead of drawn. The header of `Template.pde`
lists the functions and where they come from.

Checked against PaperPolyhedra itself. Its own `drawPlan()` and this tool's recording were drawn
at the same scale for a 6-sided prism, a 5-sided frustum and a split 6-sided frustum. Every
line of each lies within 1 px (0.35 mm) of a line of the other. The only exception is 5 pixels
where the last dash of a fold ends a fraction of a pixel differently.

The figure draws its own dashes, at a length that suits a figure, so a fold reads the same at
any size. The cut file's dash pattern is set for the cutter, not for the eye.

**If PaperPolyhedra's tab, flap or lid shapes change, update `Template.pde` too.**

### Scope

Stage 1: uniform regular prisms and frustums, whole or split strip. Cuboid and per-edge prisms,
hollow (double-wall) shapes and Kresling patterns are planned, in that order.

## Files

| File | Responsible for |
|---|---|
| `PaperPolyhedraFigures.pde` | settings, palette, panel layout, draw loop, keys |
| `Template.pde` | the template, copied from PaperPolyhedra and recorded as cuts and folds |
| `Render.pde` | drawing the template, panel a, and the close-up grid of panel b |
| `Dimensions.pde` | which close-ups there are, and their dimension lines and notes |
| `UI.pde` | ControlP5 sidebar and its events |
| `Export.pde` | high-resolution PNG export |
