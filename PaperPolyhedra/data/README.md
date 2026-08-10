# data/

Runtime assets for PaperPolyhedra.

## Artwork is not committed

Panel, lid and strip artwork is personal media and was roughly **100 MB** in the
old repository — individual `.tif` files ran over 12 MB each. Committing it would
bloat this repository's history permanently and irreversibly, so image files in
`data/` are gitignored.

Instead, `PlaceholderAssets.pde` generates usable placeholders on first run. A
fresh clone is immediately runnable and every texture code path has real image
data to work with. Nothing is ever overwritten: drop in your own file and it wins.

## What gets generated

| Path | Used for |
|---|---|
| `top.jpg` | Top lid texture |
| `bottom.jpg` | Bottom lid texture |
| `strip.jpg` | Strip texture bent across the full perimeter |
| `panels/edge_<N>.png` | Per-edge panel textures, `N` = 0–11 |

The placeholders are diagnostic rather than decorative — they carry an index, an
orientation arrow, a grid and a hue sweep, so a mirrored, rotated or seam-broken
mapping is obvious immediately.

## Using your own artwork

Either drop files into `data/` using the names above, or load them at runtime
through the sidebar's image pickers, which accept any path.

To regenerate placeholders, delete the file and restart the sketch.

## What *is* committed

| File | Why |
|---|---|
| `platonic_templates_production.txt` | Curated template library, small and hand-maintained |

`marker_data.txt` lives in the sketch root alongside the marker source.
