# PaperPrototyping

A toolbox of Processing tools for designing, generating and cutting **paper-based
physical prototypes** --> foldable polyhedra, voxel blocks, haptic widgets and the
data that drives them.

Each tool is a self-contained Processing sketch in its own top-level folder. Most
share a common print-and-cut workflow and can hand files to one another, but any
one of them can be opened and run on its own. FrustumSupport is the exception —
it exports OpenSCAD for the 3D-printed frame that goes *inside* a folded shell.

---

## The tools

| Tool | Status | What it does |
|---|---|---|
| **[PaperPolyhedra](PaperPolyhedra/)** | Active | The main tool. Turns 3D polygon/prism specs into printable, foldable nets with tabs, flaps, lids, Kresling patterns and fiducial markers. |
| **[PaperPhicons](PaperPhicons/)** | Active | The voxel cutter. Generates cut files for physical icon blocks (cuboids) with ArUco markers for tracking. |
| **[DataPhysicalisation](DataPhysicalisation/)** | Active | Maps CSV columns onto physical dimensions (height, diameter, sides, colour), previews the result in 3D, and exports JSON that PaperPolyhedra imports. |
| **[FrustrumSupport](FrustrumSupport/)** | To Be Uploaded | Internal support-structure generator for frustum-shaped shells. |
| **[WidgetGenerator](WidgetGenerator/)** | To Be Uploaded  | Standalone generator for button/widget templates used inside PaperPolyhedra. |
| **[PaperBlox](PaperBlox/)** | To Be Uploaded  | A stripped-down PaperPolyhedra for quick blocks and teaching contexts. |

Planned tools are scaffolded with a README describing scope and where the code is
expected to come from. They contain no implementation yet.

## Getting started

**Requirements**

- [Processing 4.3](https://processing.org/download) or newer
- Libraries via *Sketch → Import Library → Manage Libraries*:
  - **ControlP5** (all tools)
  - **PeasyCam** (DataPhysicalisation only)
- [OpenSCAD](https://openscad.org/) — FrustumSupport only, to turn its exported
  `.scad` into a printable mesh

**Running a tool**

```bash
git clone https://github.com/Hannahathome/PaperPrototyping.git
```

Open the `.pde` file that matches its folder name, e.g. `PaperPolyhedra/PaperPolyhedra.pde`
and press Run. Processing requires the sketch folder and main file to share a
name, which is why each tool is named this way.

On first run PaperPolyhedra generates its own placeholder textures, so it works
straight out of a clone with no extra assets. See [PaperPolyhedra/data/README.md](PaperPolyhedra/data/README.md).

## Repository conventions

Read [docs/adding-a-tool.md](docs/adding-a-tool.md) before adding a tool, and
[docs/shared-concepts.md](docs/shared-concepts.md) for the units, calibration and
export conventions the tools share.

Two rules matter more than the rest, because breaking them is what made the
predecessor repository unusable:

1. **Never commit exported output.** `output/` is gitignored. Exports are
   reproducible; they are not source.
2. **Never commit a dated copy of a folder as a "version".** Use a git branch,
   tag or commit. The old repo accumulated 15 parallel copies of the same sketch,
   four of which turned out to be byte-identical apart from line endings.

## History

This repository supersedes [PaperVoxels](https://github.com/Hannahathome/PaperVoxels), which is kept as a read-only archive.

## Author

Hannah van Iterson
