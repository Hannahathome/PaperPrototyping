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
- Connected shapes — mount one form on another's lid, with the mounting slits cut automatically
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
| `LidFrame.pde` | Canonical lid coordinate frame shared by the pattern and the 3D view |
| `Connection.pde` | Connected shapes — model, mounting slits, 3D face picking |
| `StripRotation.pde` | Rotating the bent-strip texture |
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

**Connections.** A connection mounts one shape on a lid of another. In the 3D preview the
child is posed on the host face; in the flat pattern a ring of tab-through slits is cut into
the host's lid, so the child's bottom-lid tabs push through and lock — the same joint the
base plate uses. Both come from one shared coordinate frame (`LidFrame.pde`), so the preview
and the cut file cannot disagree about where a connection sits.

## Connecting two shapes

1. Press `G` for the 3D view, then click **Connect**.
2. Click a face on the shape you want to attach. It lights up blue — this is the child's
   **mating lid**.
3. Click a face on another shape. The two are joined, and the child lands centred.

Because step 2 picks the child's own face, picking its **top** face gives a top-to-top
joint: the child is turned over, and the slit ring is sized to its top lid rather than its
bottom. `F` flips an existing connection between the two.

| Action | Result |
|---|---|
| Click a face | Pick it (or join it to an already-picked face) |
| Click the same face again | Deselect it |
| Drag on a face | Move the child; snaps to centre near the middle |
| `,` / `.` | Spin the child on its face |
| `F` | Flip which lid of the child mates |
| `Del` or **Disconnect** | Detach the child — it becomes free-standing again |

Dragging never deselects: the toggle only fires on a click that does not move.

The 3D view shows **all** shapes by default; **Selected** narrows it to the assembly the
selected shape belongs to.

A red slit ring, and a warning next to the buttons, mean the child's footprint runs off the
edge of the host lid; move it inward before cutting.

Scope: uniform regular polygons, matching the base plate's own scope. Per-edge, cuboid and
hollow lids are refused rather than mis-placed. A shape can host many children and chains
nest up to 8 deep, but a shape can only hang off one parent.

Connections live for the session only, like cutouts and marker placements — the sketch has
no shape-export format to persist them into.

## Strip texture rotation

With the side texture in **strip** mode, *Strip Texture Rotation* in the View tab turns the
artwork on the strip. It rotates the source bitmap rather than the texture coordinates, so
the strip re-fits to the new aspect automatically and quarter turns stay pixel-exact —
useful when artwork is the wrong way round for a long, short strip. Angles that are not
multiples of 90 leave transparent corners, which show as gaps on the strip.

Cropping a strip texture resets its rotation, since the crop is taken from what you see.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Texture seams visible | Raise tessellation density to 16; prefer power-of-2 image dimensions |
| Polygon will not close | In per-edge mode press `N` to normalise, or enable *Lock Strip Length* |
| Export fails | Check `output/` exists and the console for errors |
| Print and cut misaligned | Print with no scaling ("actual size"); check the cutter uses mm |
| Textures look wrong | Delete the generated placeholders in `data/` and re-run to regenerate |
