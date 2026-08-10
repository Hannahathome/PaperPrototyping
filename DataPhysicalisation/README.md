# DataPhysicalisation

Turns a dataset into a set of physical shape specifications. Load a CSV, map its
columns onto physical dimensions, check the result in 3D, and export JSON that
[PaperPolyhedra](../PaperPolyhedra/) turns into cut files.

This is the front of the pipeline: it decides *what shapes to make*,
PaperPolyhedra decides *how to cut them*.

Formerly `csv upload / csv_testcode`.

## Running

Open `DataPhysicalisation.pde` in Processing 4.3+ and press Run.
Requires **ControlP5** and **PeasyCam**.

## Workflow

1. Load a CSV.
2. Assign columns to physical dimensions in the sidebar:

   | Dimension | Meaning |
   |---|---|
   | `label` | Name shown on and exported with the shape |
   | `height` | Shape height |
   | `diameter` | Diameter — polyhedron mode, or linked-bar mode |
   | `width` / `depth` | Footprint — separate-bar mode |
   | `sides` | Polygon sides, 3–30 |
   | `color` | Fill colour, exported as a hex string |

   Unassigned dimensions fall back to defaults, so a partial mapping still works.
3. Inspect the layout in 3D — drag to orbit (PeasyCam), scroll to zoom.
4. Tune the scale controls. `scaleH`, `scaleDiam` and `scaleSides` set the
   maximum values a column maps onto; the `min…Pct` controls set the floor, so
   small values stay physically buildable instead of collapsing to nothing.
5. Export JSON.

## Handing off to PaperPolyhedra

The export is a flat JSON array, one object per shape:

```json
[
  { "label": "Dragonfly", "height": 15.02, "width": 4, "depth": 4, "color": "#B4E522" },
  { "label": "Hummingbird", "height": 24.66, "width": 4, "depth": 4, "color": "#B4E522" }
]
```

In PaperPolyhedra, import it via the sidebar — this calls `loadJSONShapes()` in
`json_import.pde`, which appends each object to the shape list.

## Examples

`examples/` holds sample exports kept as a format reference and as fixtures for
testing the import path. `polyhedra_export.json` is the canonical example of the
handoff format.
