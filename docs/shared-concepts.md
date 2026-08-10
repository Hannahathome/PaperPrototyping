# Shared concepts

Conventions the tools have in common. A tool that follows these produces output
that cuts correctly on a setup calibrated for any other tool.

## Units

User-facing input is **millimetres**. Drawing happens in **pixels**. Conversion
runs through a small set of constants that appear in every tool:

```java
final float MM        = 2.8346;              // mm → px at 72 DPI (print)
final float PRINT_DPI = 72.0;
final float VINYL_DPI = 96.0;
final float MM_V      = MM * (VINYL_DPI / PRINT_DPI);   // mm → px at 96 DPI (cutter)
```

Print geometry and cut geometry are computed at **different scales**. Mixing
`MM` and `MM_V` produces output that looks right on screen and is 33% wrong on
the cutting mat. When adding geometry, check which scale the surrounding code is
working in.

Page defaults are A4 landscape:

```java
final float PAGE_W_MM = 297.0;
final float PAGE_H_MM = 210.0;
```

The vinyl cutting area is smaller than the printable page (roughly 280 × 200 mm),
because the cutter needs margin to grip the sheet.

## The print-and-cut workflow

Print and cut are separate machines, so every export ships three files:

| File | Consumed by | Contains |
|---|---|---|
| `<name>_<stamp>.pdf` | Printer | Artwork, fills, labels — everything with ink |
| `<name>_fold_<stamp>.svg` | Cutter | Cut lines and fold lines, no fill |
| `<name>_calib_<stamp>.svg` | Cutter | Registration marks only |

The timestamp is `M_D_H_MM_SS`. The order that matters in practice:

1. Cut the calibration SVG first and check it against the printed sheet. Cheap.
2. Print the PDF at **actual size** — any "fit to page" scaling invalidates the
   calibration.
3. Cut the fold SVG using the same origin.

Fold lines are conventionally dashed and cut lines solid, so the cutter can be
configured to score rather than cut through. Check the dash-pattern setting
before a long run.

## Fiducial markers

Tools that produce trackable artefacts (PaperPolyhedra, PaperPhicons) place ArUco
markers from a fixed dictionary. Two rules:

- **Never scale marker artwork independently.** Detection depends on printed
  dimensional accuracy.
- **Load marker images before `beginRecord(PDF)`.** Calling `loadImage()` after
  it corrupts the PDF graphics state — this is documented at the top of
  `marker_functions.pde` and was a real bug, not a theoretical one.

## Geometry

**Trapezoid strips.** Panels are trapezoids: a top edge, a bottom edge, and a
height that is the *slant* height when top ≠ bottom. Each panel connects to its
neighbour by a rotation derived from its edge vectors; after `n` panels the
rotations sum to 360° and the shape closes.

**Frustums.** When top and bottom perimeters differ, panel height is the
hypotenuse, not the vertical rise. Using vertical height gives a shape that is
subtly too short and will not close cleanly.

**Variable polygons.** For per-edge widths, the circumradius `R` is found by
binary search so that `Σ 2·arcsin(s[i]/(2R)) = 2π`. If it fails to converge the
requested perimeter is not physically realisable — normalise the edges.

**Tessellation.** Textured panels subdivide into a `density × density` grid.
World positions come from bilinear interpolation of the panel corners; UVs map
linearly. Density 4 is fast, 16 removes visible seams.

## Assets

Bulk artwork is not committed — see
[PaperPolyhedra/data/README.md](../PaperPolyhedra/data/README.md). Tools that
need textures should generate placeholders at startup so a fresh clone runs
immediately.

Small fixed reference data *is* committed: marker dictionaries, template
libraries, example exchange files. The test is whether the tool can produce it
itself. If it can, generate it. If it cannot, commit it.

## Exchange formats

Tools hand work to each other as JSON. The current format is a flat array of
shape objects:

```json
[
  { "label": "Dragonfly", "height": 15.02, "width": 4, "depth": 4, "color": "#B4E522" }
]
```

Produced by DataPhysicalisation, consumed by PaperPolyhedra's `loadJSONShapes()`.
Unknown keys are ignored and missing keys fall back to defaults, so the format
can gain fields without breaking existing files. Keep it that way — and when you
add a field, add an example to `DataPhysicalisation/examples/`.
