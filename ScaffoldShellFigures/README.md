# ScaffoldShellFigures

A figure tool, not a fabrication tool. It draws a frustum **shell** and the 3D-printed
**scaffold** that goes inside it, as [ScaffoldShell](../ScaffoldShell/) builds them, in three
panels side by side:

| Panel | Shows |
|---|---|
| a, Shell | the closed paper shell on its own (opaque) |
| b, Scaffold | the strut cage and the component rigs, with each component as a translucent blue-outlined box |
| c, Shell + scaffold | the scaffold seen through a see-through shell |

All three use one camera, so they always face the same way. Nothing is cut or printed: the
only output is PNG, for papers and slides.

## Running

Open `ScaffoldShellFigures.pde` in Processing 4.3+ and press Run.
Requires the **ControlP5** library. It reads no files.

## Controls

| Input | Does |
|---|---|
| Left-drag on a panel | orbit (all panels) |
| Right-drag / Shift-drag | pan |
| Mouse wheel | zoom |
| `R` | reset the view |
| `O` | toggle orthographic / perspective |
| `H` | hide or show the sidebar, so the panels fill the window |
| `S` | save PNG |

The sidebar has these sections:

- **Shell:** sides, top and bottom diameter, height, and the top and bottom lids.
- **Scaffold:** strut radius, clearance, wall flap length (ScaffoldShell's
  `wall_flap_length_mm`, default 8), and two posts per rig face with their spacing.
- **Component rigs:** add or remove up to 4 rigs, `<` `>` to pick one, a **Preset** button
  that cycles through ScaffoldShell's M5Atom / M5Core footprints, and size, offset and
  rotation.
- **View:** overlay opacity (the shell in panel c; panel a is always opaque), edge weight,
  orthographic, and panel letters.
- **Export:** PNG scale (1–6×) and transparent background.

Diameters are **circumscribed** diameters (2 × centre-to-corner). ScaffoldShell's own
"diameter" field agrees, except for 4-sided shapes, where it reports the side length.

## Export

**Save PNG** draws the panels again off-screen at *PNG scale* × the on-screen size, with
the same camera, so the file frames exactly what you see. Written to `output/` (gitignored):

| File | Contents |
|---|---|
| `figure_<stamp>.png` | the three panels side by side, with letter tags if *Panel letters* is on |
| `figure_<stamp>_shell.png` | panel a alone, no tag |
| `figure_<stamp>_scaffold.png` | panel b alone, no tag |
| `figure_<stamp>_assembly.png` | panel c alone, no tag |

The single-panel files are for laying the figure out yourself (LaTeX subfigures, Illustrator).
The red warnings shown on screen are never included in an export.
To change the aspect ratio of a figure, resize the window or hide the sidebar (`H`) before
saving.

## Look

Matches the paper's folding figures: white background, light-grey paper faces with flat
shading (walls facing you near-white, the lid and turned-away walls a step darker), thin
dark-grey edges, blue as the single accent (component boxes), and a dark letter tag on a
thin rule under each panel. The controls follow `TEI27Software/SlidingFrustumBoxCP5`. Every
colour and light level is a constant at the top of `ScaffoldShellFigures.pde`.

## Relationship to ScaffoldShell

The scaffold geometry in `Geometry.pde` is a **copy** of `buildFrameGeometry()` and
`buildRigGeometry()` from [ScaffoldShell/Frame.pde](../ScaffoldShell/Frame.pde), including
its clearance and strut-radius insets and its rotational phase. So a figure shows the scaffold
ScaffoldShell would export for the same numbers.

The solid shapes follow the exported OpenSCAD (`ScaffoldShell/data/template_frame.txt`,
`template_helper.txt` and the assembly in `FrameSCAD.pde`), checked against an OpenSCAD
render of the same frame:

- **Flat, level tops.** Each wall strut runs one radius past its corner, has a wedge flap
  shaved off one side over its top `flap_length` (`_local_draw_half_edge()`), and is then
  cut by the top trimming slice along one horizontal plane. So all wall-strut tops end
  flat and at the same height, which is what the lid sits on. A rig post that reaches
  that plane is cut by it too.
- Every other strut is a plain `cylinder()` with flat ends. The only spheres are at the
  bottom cage corners and at each rig post's base.

**If the strut layout changes in Frame.pde, or the strut shapes or the trim change in
the OpenSCAD templates or FrameSCAD.pde, update Geometry.pde too.**

**Orientation:** figures show the printed part as it is. ScaffoldShell's 3D preview maps
frame space to the screen as `(x, -z, y)`, which on Processing's y-down screen is the
**mirror image**. This doesn't matter for a symmetric cage, but it swaps the side of each
wedge flap and the position of an off-centre rig. This tool uses `(x, -z, -y)` instead.

Scope: uniform regular frustums (and prisms, with equal diameters), the same shells
ScaffoldShell can give a scaffold.

## Files

| File | Responsible for |
|---|---|
| `ScaffoldShellFigures.pde` | settings, palette, panel layout, draw loop, keys |
| `Geometry.pde` | shell vertices; scaffold geometry ported from ScaffoldShell |
| `Camera.pde` | the shared orbit / pan / zoom camera and its mouse handling |
| `Render.pde` | drawing shell, struts and component boxes into a panel |
| `UI.pde` | ControlP5 sidebar and its events |
| `Export.pde` | high-resolution PNG export |
