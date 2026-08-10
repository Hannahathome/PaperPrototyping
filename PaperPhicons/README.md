# PaperPhicons

The voxel cutter. Generates print-and-cut files for physical icon blocks —
cuboid paper voxels carrying ArUco fiducial markers so they can be tracked by
camera during a study or demo.

Formerly `PaperPhicons_PaperCutCuboids_v1`. Succeeds the earlier `VoxelCutterV8`,
which remains in the archived PaperVoxels repository.

## Running

Open `PaperPhicons.pde` in Processing 4.3+ and press Run.
Requires the **ControlP5** library.

## Output

Exports to `output/` (gitignored) using the toolbox print-and-cut convention:
a PDF print layer plus SVG cut and calibration layers. Print at actual size —
marker detection depends on the printed markers being dimensionally accurate.

Both print (72 DPI) and vinyl (96 DPI) scales are handled; see
[docs/shared-concepts.md](../docs/shared-concepts.md).

## Source layout

| File | Role |
|---|---|
| `PaperPhicons.pde` | Main sketch — setup, draw, export |
| `UI.pde` | ControlP5 controls |
| `Tools.pde` | Cuboid net geometry |
| `ScanNCut.pde` | Cutter-specific export path |
| `marker.pde` | ArUco marker placement |

## Marker assets

| File | Purpose |
|---|---|
| `aruco1024_px.png` | ArUco dictionary sheet, 1024 px |
| `4x4_1000_px.png` | 4×4 marker dictionary, 1000 px |

These are committed because they are small, fixed reference data — the tool
cannot generate correct markers without them.
