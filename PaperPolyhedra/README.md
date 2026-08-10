# PaperPolyhedra

The main tool of the toolbox. Converts 3D polygon specifications (sides, height,
per-edge widths) into flat 2D cutting patterns that fold into 3D shapes.

Formerly developed as `PaperVoxels` / `kresling_dev_polyhdrea_V10`.

## Running

Open `PaperPolyhedra.pde` in Processing 4.3+ and press Run.
Requires the **ControlP5** library.

On first run the sketch generates placeholder textures into `data/` so every
texture path has something to load — see [data/README.md](data/README.md).

## Features

- Uniform prisms and per-edge variable (irregular) prisms
- Frustums — independent top and bottom perimeters
- Kresling fold patterns, including haptic button variants
- Base plates, cutouts and internal bar assemblies
- Automatic tab and flap generation for assembly
- Texture mapping: per-panel, or one strip bent across the whole perimeter
- ArUco fiducial markers for tracked prototypes
- JSON shape import (from [DataPhysicalisation](../DataPhysicalisation/))
- Print-and-cut export with calibration marks

## Export

Press `E`. Writes a timestamped set into `output/` (gitignored):

| File | Purpose |
|---|---|
| `<name>_<stamp>.pdf` | Print layer — artwork and fills |
| `<name>_fold_<stamp>.svg` | Cut and fold lines for the cutter |
| `<name>_calib_<stamp>.svg` | Registration marks for print/cut alignment |

Print the calibration SVG first to verify alignment before committing material.

## Keyboard controls

**Per-edge mode**

| Key | Action |
|---|---|
| `P` | Toggle per-edge (variable prism) mode |
| `[` / `]` | Select previous / next edge |
| `T` / `t` | Increase / decrease top width (Shift = coarse) |
| `B` / `b` | Increase / decrease bottom width |
| `C` | Copy top widths to bottom |
| `N` | Normalise edges to the target perimeter |
| `E` | Export PDF + SVG |

## Source layout

| File | Role |
|---|---|
| `PaperPolyhedra.pde` | Main sketch — setup, draw, export orchestration |
| `Param.pde` | Global state, constants, mm/px conversion |
| `UI.pde`, `SidebarPanel.pde`, `Toolbar.pde` | ControlP5 interface |
| `events.pde` | Mouse and keyboard handling |
| `api.pde` | Tab, flap and lid drawing |
| `tools.pde` | Trapezoid drawing and tessellation |
| `variableprismtools.pde` | Per-edge mode and variable polygon solver |
| `edgeprofileclass.pde` | `EdgeProfile` — per-edge storage |
| `ShapeSpec.pde` | Shape definition passed between UI and geometry |
| `KreslingPattern.pde`, `KreslingHaptics.pde` | Kresling folds and haptic buttons |
| `BasePlate.pde`, `Cutout.pde`, `BarAssembly.pde` | Base plates, cutouts, assemblies |
| `texturesnew.pde`, `textures_triangles.pde` | Texture loading, mapping, strip bending |
| `ImageCropper.pde`, `color_fill.pde` | Image cropping and solid fills |
| `marker.pde`, `marker_functions.pde` | ArUco marker generation |
| `PrintNCut.pde` | PDF/SVG export and calibration marks |
| `json_import.pde` | Shape import from DataPhysicalisation |
| `PlaceholderAssets.pde` | Generates placeholder textures on first run |
| `DistanceOverlay.pde` | On-canvas measurement overlay |

`GLOBALS_REFERENCE.md` documents the shared global variables.

### Known dead weight

Carried over from the old repository and safe to delete once confirmed unused:

- `zz_old_tesselation.pde` — superseded tessellation code
- `FoldingAnimationWindow.pde` — empty file
- `snippet.pde` — scratch code, though it holds the `platonic_templates_production.txt` writer

## Concepts

**Units.** User input is millimetres; drawing happens in pixels.
`MM = 2.8346` converts at 72 DPI. Vinyl cutter output uses 96 DPI —
`MM_V = MM * (96/72)`.

**Geometry.** Panels are trapezoid strips. Each connects to the next by a
rotation derived from its edge vectors; after `n` panels the total rotation
reaches 360° and the polygon closes.

**Variable polygons.** For irregular edge lengths the circumradius `R` is found
by binary search such that `Σ 2·arcsin(s[i]/(2R)) = 2π`, guaranteeing closure.

**Tessellation.** Panels subdivide into a `density × density` grid; world
positions come from bilinear interpolation of the corners, UVs map linearly.
Raise the density to 16 if texture seams appear.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Texture seams visible | Raise tessellation density to 16; prefer power-of-2 image dimensions |
| Polygon will not close | In per-edge mode press `N` to normalise, or enable *Lock Strip Length* |
| Export fails | Check `output/` exists and the console for errors |
| Print and cut misaligned | Print with no scaling ("actual size"); check the cutter uses mm |
| Textures look wrong | Delete the generated placeholders in `data/` and re-run to regenerate |
