# ScaffoldShell

Both halves of a prototype from one program: the **shell** — a foldable paper net, cut from
a 3D polygon specification — and the **scaffold** that goes inside it, a 3D-printable strut
frame carrying the electronics.

[PaperPolyhedra](../PaperPolyhedra/) and [FrustumSupport](../FrustumSupport/), merged.
The shell leaves as PDF and SVG, as before. The scaffold leaves as OpenSCAD.

Formerly developed as `PaperVoxels` / `kresling_dev_polyhdrea_V10`, plus
`FrustumSupportGenerator_GUI_v3Toggle`.

## Why merge them

FrustumSupport worked in circumradii and was driven by five numbers typed by hand. Its
README carried the warning that mattered: *"These must match the shell, or the frame will
not seat."* Nothing enforced it, and the two tools measured the same object in different
quantities — perimeters here, radii there.

In the merged tool the frustum is **derived** from the shape you already drew, so the two
cannot disagree. What is left to choose is what is genuinely about the frame: strut
thickness, clearance, and the component rigs inside it.

## Running

Open `ScaffoldShell.pde` in Processing 4.3+ and press Run.
Requires the **ControlP5** library. Rendering an exported frame needs
[OpenSCAD](https://openscad.org/).

On first run the sketch generates placeholder textures into `data/` so every
texture path has something to load — see [data/README.md](data/README.md).

## Features

- Uniform prisms and per-edge variable (irregular) prisms
- Frustums — independent top and bottom perimeters
- Kresling fold patterns, including haptic button variants
- Base plates, cutouts and internal bar assemblies
- Connected shapes — mount one form on another's lid **or side wall**, with the mounting slits cut automatically
- Automatic tab and flap generation for assembly
- Texture mapping: per-panel, one strip bent across the whole perimeter, or one image
  wrapped over the **entire surface** — both lids and the wall, continuous across the rims
- ArUco fiducial markers for tracked prototypes
- JSON shape import (from [DataPhysicalisation](../DataPhysicalisation/))
- Print-and-cut export with calibration marks
- **Internal support frames** — a 3D-printable strut cage with component mounts, sized
  automatically from the shell it goes inside, exported as OpenSCAD

## Export

Press `E`. Writes a timestamped set into `output/` (gitignored):

| File | Purpose |
|---|---|
| `<name>_<stamp>.pdf` | Print layer — artwork and fills |
| `<name>_fold_<stamp>.svg` | Cut and fold lines for the cutter |
| `<name>_calib_<stamp>.svg` | Registration marks for print/cut alignment |
| `<name>_<stamp>_frame_<shape>.scad` | Internal support frame — one per frame-enabled shape |

Print the calibration SVG first to verify alignment before committing material.

The `.scad` is source, not a mesh: open it in OpenSCAD, render with `F6`, export STL, print.
`flap_length` is written near the top of each file so it can be tweaked without re-exporting.

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
| `ScaffoldShell.pde` | Main sketch — setup, draw, export orchestration |
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
| `SidePanelFrame.pde` | The same, for one panel of the side strip |
| `Connection.pde` | Connected shapes — model, mounting slits, 3D face picking |
| `ConnectionUndo.pde` | Undo/redo for connection editing |
| `StripRotation.pde` | Rotating the bent-strip texture |
| `texturesnew.pde`, `textures_triangles.pde` | Texture loading, mapping, strip bending |
| `WrapFrame.pde` | Canonical surface frame for the whole-surface wrap |
| `textures_wrap.pde` | Drawing the wrap — flat pattern, export and 3D |
| `ImageCropper.pde`, `color_fill.pde` | Image cropping and solid fills |
| `marker.pde`, `marker_functions.pde` | ArUco marker generation |
| `PrintNCut.pde` | PDF/SVG export and calibration marks |
| `json_import.pde` | Shape import from DataPhysicalisation |
| `PlaceholderAssets.pde` | Generates placeholder textures on first run |
| `DistanceOverlay.pde` | On-canvas measurement overlay |
| `Frame.pde` | Internal support frame — model, the shell→frustum bridge, geometry |
| `FrameView.pde` | Drawing the frame in the 3D preview |
| `FrameSCAD.pde` | OpenSCAD export |
| `FrameSidebar.pde` | The Frame tab |
| `FrameSelfTest.pde` | Frame geometry regression checks (`FRAME_SELFTEST`) |
| `data/template_frame.txt` | `frustumCage()` / `rigSupport()` OpenSCAD modules |
| `data/template_helper.txt` | `_local_draw_edge` / `_local_draw_half_edge` primitives |

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

**Connections.** A connection mounts one shape on a **face** of another — either lid, or any
panel of the side strip. In the 3D preview the child is posed on the host face; in the flat
pattern a ring of tab-through slits is cut into that face, so the child's bottom-lid tabs
push through and lock — the same joint the base plate uses. Each kind of face has one
canonical coordinate frame, `LidFrame.pde` for the lids and `SidePanelFrame.pde` for the
walls, and the preview and the cut file both read it, so they cannot disagree about where a
connection sits.

## Connecting two shapes

1. Press `G` for the 3D view, then click **Connect**.
2. Click a **lid** on the shape you want to attach. It lights up blue — this is the child's
   **mating lid**.
3. Click any face on another shape — a lid or a side wall. The two are joined, and the child
   lands centred on that face.

Because step 2 picks the child's own face, picking its **top** lid gives a top-to-top
joint: the child is turned over, and the slit ring is sized to its top lid rather than its
bottom. `F` flips an existing connection between the two.

Step 2 only accepts a lid, because a child always mates by one of its own lids. A wall can
*host* a shape but cannot be the face that attaches; clicking one selects it (and whatever
is mounted on it) instead of starting a join.

| Action | Result |
|---|---|
| Click a face | Pick it (or join it to an already-picked lid) |
| Click the same face again | Deselect it |
| Drag on a face | Move the child; snaps to the face's guides |
| Drag the ring on the flat pattern | Move a wall-mounted child, exactly |
| Arrows (`Shift` = 5mm) | Nudge the child 1mm across its face |
| `,` / `.` | Spin the child on its face |
| `F` | Flip which lid of the child mates |
| `Del` or **Disconnect** | Detach the child — it becomes free-standing again |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo the last connection edit |

Dragging never deselects: the toggle only fires on a click that does not move.

**Undo** covers connection editing — joining, detaching, moving, spinning, flipping — in
either view, and nothing else: sliders, textures, cutouts and markers are not on the history.
A drag or a held arrow key is one step, not one per frame. Because a connection names its
shapes by index, deleting a shape or importing one clears the history rather than let undo
put back a connection pointing at the wrong shape; adding a shape is safe and keeps it.

**Selecting a shape in 3D.** With Connect off, clicking a shape selects it, the same as
clicking one on the flat pattern; `◄ ►` step through them too. The selected shape is outlined
in orange, matching the box the flat pattern draws around it, and the outline draws through
whatever is in front of it so a shape buried in an assembly still shows as selected. A drag
still orbits the camera — only a click that does not move changes the selection.

With Connect **on**, neither happens: clicks go to faces, and the face tints are the
highlight. A whole-shape outline there would compete with them for the same meaning.

## Pairing marks

Each connection prints the same coloured symbol at two places: the middle of the host's slit
ring, and the middle of the child lid that pushes through it. On the cut sheet those two
pieces can be far apart and look alike, so the mark is what tells you which goes with which
while you build.

Colour *and* symbol both change from one connection to the next — six colours against five
symbols, so a pairing does not repeat until the thirtieth connection and the marks stay
readable in a black-and-white print. The colours are the Okabe-Ito set, which stays
distinguishable for the common colour-vision deficiencies, and every symbol is
mirror-symmetric so it cannot be misread on the reverse of a lid that folds over.

Marks are artwork: they show on screen and print on the PDF, and are deliberately kept out of
the SVG cut file, which would otherwise cut them out. They matter most on a matching-rim
joint, where there are no slits to say which piece pairs with which.

**Placing a wall-mounted child.** The 3D view often shows a wall edge-on or hides it behind
the solid, and a face turned edge-on has no usable drag — so a drag there is ignored rather
than throwing the child across the panel. The arrow keys always work, and the slit ring can
be dragged directly on the flat pattern, which is the most precise way to place it.

A lid snaps to its centre. A wall snaps to three lines: its vertical midline, its horizontal
midline, and **flush against each fold line** — which is how you mount something right at the
rim. The guides are drawn on the face while you drag.

The 3D view shows **all** shapes by default; **Selected** narrows it to the assembly the
selected shape belongs to.

A red slit ring, and a warning next to the buttons, mean the child's footprint runs off its
host face; move it inward before cutting. On a wall this fires 2mm early, because all four
of a panel's boundaries are fold lines and a cut that reaches one ruins the fold.

**Matching rims cut nothing.** When the child mates by a lid that is the same polygon as the
host lid — same side count, same edge length — the two rims coincide and there is nothing to
cut: each form's own lid tabs already land where the other's are, so they tab together at the
rim. Slits there would run along the host's tab bases and cut them off. Such a joint shows in
the preview as a dashed outline with a centre cross, is fixed at the centre (two identical
polygons meet in exactly one way), and puts nothing on the page.

Scope: uniform regular polygons, matching the base plate's own scope. Per-edge, cuboid and
hollow shapes are refused rather than mis-placed, and so are kresling walls — the strip is
sheared as a whole, which would shear a slit ring without shearing the child pushing through
it. A shape can host many children and chains nest up to 8 deep, but a shape can only hang
off one parent. Giving a shape fewer sides detaches anything mounted on a wall that no longer
exists.

Connections live for the session only, like cutouts and marker placements — the sketch has
no shape-export format to persist them into.

## Whole-surface wrap

The **Wrap** tab in Texture puts a single image over a shape's entire outer surface — bottom
lid, wall, top lid — so artwork that crosses a rim stays continuous once the piece is folded.
Strip mode can only clothe the wall; the lids are separate images, and nothing makes the
three agree at the fold.

Every point on the surface gets a coordinate. **s** runs once around the perimeter, allocated
per panel by average width, with `s = 0` on panel 0's left fold — the edge that already
carries the glue tab, so the seam lands where the join is anyway. **t** runs along the
surface, measured on the paper: 0 at the bottom lid's centre, up the wall, 1 at the top
lid's centre. The wall therefore occupies the middle band of the image and each lid gets one
end of it, mapped radially.

Applying a wrap — picking the tab, or loading an image — switches both lid textures on,
since the image has nowhere to land at either end without them. Turning a lid off afterwards
still works; the wall simply keeps its band and that cap goes unprinted.

The lid's share of `t` is its apothem, which makes `t` constant along the whole rim — the
join is exact — at the cost of a little radial stretch towards the corners. The sidebar shows
the source aspect that maps without stretching (perimeter : total run), and the cropper opens
with that as its guide box.

The top of the image lands on the top of the model. Note this is the opposite of strip mode,
which maps image row 0 onto the model's *bottom* rim in both the pattern and the 3D view —
long-standing, and left alone rather than flip everyone's existing strip artwork.

At `t = 0` and `t = 1` a whole image row collapses to a point, so detail at the very top and
bottom disappears — the bargain any map projection makes at its poles. Keep the extremes of
the artwork quiet.

Scope is uniform regular prisms and frustums, the same line `LidFrame.pde` draws. Hollow is
refused because a donut lid has no centre to reach, kresling because the strip is sheared as
a whole, and per-edge and cuboid because their lids are not the regular polygons the cap mesh
walks; the tab says which of these is in the way rather than mis-mapping quietly. Split strip
works — it only changes where the halves sit on the page.

On the printed sheet the wall artwork appears upside down. That is the layout, not a fault:
the strip is drawn with the model's bottom rim along the top of the page.

`data/wrap.jpg` is generated on first run as a calibration sheet — hue around, brightness up,
a percentage grid, a red seam line down both edges and the two poles captioned. Print it and
fold it: the grid lines say where each rim and fold landed, and the two red edges must meet.

## Strip texture rotation

With the side texture in **strip** mode, *Strip Texture Rotation* in the View tab turns the
artwork on the strip. It rotates the source bitmap rather than the texture coordinates, so
the strip re-fits to the new aspect automatically and quarter turns stay pixel-exact —
useful when artwork is the wrong way round for a long, short strip. Angles that are not
multiples of 90 leave transparent corners, which show as gaps on the strip.

Cropping a strip texture resets its rotation, since the crop is taken from what you see.

## Internal support frames

A tall frustum folded from paper cannot hold its own profile or carry electronics. The
frame is the rigid wireframe that goes inside it: a strut cage following the shell's own
edges, plus cuboid rigs for mounting components. It is 3D printed, not cut.

Open the **Frame** tab, turn on *Build a frame for this shape*, and add rigs. The frustum
itself is not on the tab — it is read off the shape, and the tab shows you what it read:

```
8 sides   ·   R bottom 20.0   ·   R top 25.0   ·   H 40.0 mm
```

Change the shape's perimeters and those numbers follow. This is the whole point of the
merge, so there is deliberately no way to type them.

### Settings

| Setting | What it does |
|---|---|
| Strut radius | Thickness of every printed strut. Also the radius of the vertex spheres. |
| Clearance | Gap between the shell and the frame — see below. |
| Wall flap length | The wedge taper at the top of each wall strut. Tweakable in OpenSCAD afterwards. |
| Two posts per face | Two support posts on each side of a rig instead of one, spread by *Post spacing*. |

Each rig has a width, depth and height, an X/Y/Z offset from the frustum's axis and floor,
and a yaw about its own offset point. The *Component* selector fills the first three from a
preset: M5Atom, M5Core and M5Core+Ext, standing or lying.

### Clearance

**Set this from your own measurements before you print anything.** It is the one number the
merge could not derive, and the default of 0.4 mm is a starting guess, not a measurement.

FrustumSupport had no clearance setting: its radii were typed, so the slop between nominal
and folded paper was absorbed by typing a slightly smaller number. Derived radii leave
nowhere to do that, so the allowance has to be explicit. Fold a shell, measure it against
what the Shape tab says it should be, and set the difference here.

### Where the struts land

The wall struts are placed in the shell's **folded corners**, not in the middle of its
facets. This needs a rotation of `-90 - 180/n` degrees applied to the OpenSCAD vertex ring,
because the cut pattern and the OpenSCAD module use different conventions for where vertex
zero sits. It is written into every export as `phase` and is visible in the 3D preview: the
red vertex spheres sit on the shell's corners.

This is invisible at `n = 4` and obvious at `n = 3` and `n = 5`. If you edit
`data/template_frame.txt`, leave `phase` alone.

### Scope

Frames are built as uniform regular frustums — the same scope base plates and lid
connections take. Per-edge, cuboid and hollow shapes are refused with a note on the tab
rather than given a frame that cannot seat.

A shape connected to another gets its own frame, posed correctly in the preview, and its
own `.scad`. Frames of connected shapes are not joined into one print.

### Checking the geometry

`FrameSelfTest.pde` holds the regression checks: the perimeter↔radius round trip, the
strut ring against the shell's own 3D polygon at seven vertex counts, parity with
FrustumSupport's defaults, the written `.scad` itself, and the Frame tab's click targets
against the rows it drew. Flip `FRAME_SELFTEST` to `true` and run the sketch; it prints a
pass/fail table and exits. 67 checks at the time of writing.

The `.scad` check includes an assertion that no number was written with a decimal comma.
Processing's `nf()` formats through the machine's locale, so on a Dutch, German or French
machine it would emit `19,1` and produce a file OpenSCAD cannot parse. `scadNum()` pins
`Locale.US`; the test makes sure it stays pinned.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Texture seams visible | Raise tessellation density to 16; prefer power-of-2 image dimensions |
| Polygon will not close | In per-edge mode press `N` to normalise, or enable *Lock Strip Length* |
| Export fails | Check `output/` exists and the console for errors |
| Print and cut misaligned | Print with no scaling ("actual size"); check the cutter uses mm |
| Textures look wrong | Delete the generated placeholders in `data/` and re-run to regenerate |
| Frame will not drop into the shell | Increase *Clearance*; measure a folded shell rather than guessing |
| Frame rattles inside the shell | Decrease *Clearance* |
| Struts sit mid-facet, not in the corners | `phase` has been edited out of `data/template_frame.txt` |
| No `.scad` in `output/` | The shape is out of scope, or *Build a frame* is off — check the Frame tab for the reason |
| OpenSCAD reports a parse error | Check for decimal commas; run `FRAME_SELFTEST` |
| Wrap artwork stretched | Crop it to the aspect the Wrap tab names, or re-export the source at that shape |
| Wrap tab refuses the shape | Hollow, kresling, cuboid and per-edge are out of scope — use Strip or Per Panel |
