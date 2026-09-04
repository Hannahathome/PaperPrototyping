# Quick Reference: Global Variables Location

All global variables are now centralized in `Param.pde`. This guide shows what lives where.

## Constants (Param.pde)

 **All constants are now in Param.pde**, organized by category:
- Unit conversion (MM, DPI values)
- Geometric ratios (TAB_INSET_RATIO, etc.)
- Layout spacing (LID_SPACING_MARGIN)
- Solver parameters (RADIUS_SOLVER_*)
- UI defaults (MIN_SIDES, STEP_FINE, etc.)

## State Variables by File

### Param.pde (PRIMARY)
**Geometry state**:
- `float[] edgeTop_px` - Per-edge top widths (pixels)
- `float[] edgeBot_px` - Per-edge bottom widths (pixels)
- `PVector cylinder` - (topPerimeter, bottomPerimeter, height) in mm
- `int rows, cols` - Grid dimensions (derived from nSides)

**Dimensions (derived from mm inputs)**:
- `float cylinderTP_px, cylinderBP_px, cylinderH_px` - Main dimensions in pixels
- `float cellTopL_px, cellBaseL_px` - Per-cell dimensions
- `float tabDepth_px, flapDepth_px, flapTaper_px` - Tab/flap sizes
- `float tabInset_*_px, arrowheadFlare_*_px` - Tab detail dimensions
- `float dash_px, gap_px` - Fold line pattern
- `float patX_px, patY_px` - Pattern offset

**Textures**:
- `int tessellationDensity` - Mesh subdivision level
- `PImage lidImgTop, lidImgBot` - Lid texture images
- `boolean lidKeepAspect` - Preserve image aspect ratio

### UI.pde
**UI State**:
- `ControlP5 cp5__prism` - UI controller instance
- `Slider s*` - All slider objects (sNSides, sSideLen, etc.)
- `Toggle t*` - All toggle objects (tLock, tAdvanced, etc.)
- `Button btn*` - Button objects (btnSidesMinus, btnSidesPlus)
- `Textlabel lbl*` - Label objects for display

**UI Values** (mirror of geometry for display):
- `int uiSides` - Current number of sides
- `float uiHeight, uiTopW, uiBotW` - Displayed dimensions
- `boolean uiLock, uiAdvanced, uiPerimLock` - Toggle states
- `float uiPerim` - Locked perimeter value
- `int uiEdgeIdx` - Selected edge for per-edge mode
- `float uiLidOffsetX, uiLidOffsetY` - Lid positioning
- `int uiTextureMode` - Texture mode selector

### dev_name.pde (MAIN)
**Core state**:
- `int nSides` - Number of polygon sides (4 default)
- `int controlMode` - Mouse drag mode selector
- `boolean bSavePDF` - Export trigger flag
- `String pdfFilename, svgFilename, timestamp` - Export paths

**Graphics contexts**:
- `PGraphicsPDF pdf` - PDF export buffer
- `PGraphics svg` - SVG export buffer

### edgeprofileclass.pde
**Per-edge mode state**:
- `boolean perEdgeMode` - Enable variable edge mode
- `EdgeProfile edgesTop, edgesBottom` - Edge length managers

**EdgeProfile class** (per instance):
- `int n` - Number of edges
- `float[] mm` - Edge lengths in mm
- `float mmToPx` - Conversion factor

### Connection.pde
**Connected shapes**:
- `ArrayList<Connection> connections` - all parent/child attachments (a relation, so NOT stored per-ShapeSpec)
- `int selectedConnectionIdx` - selected connection, -1 = none
- `boolean connectMode` - 3D view: clicks attach/drag instead of orbiting
- `int _drawingShapeIdx` - which shape `drawPlan()` is rendering, so slits know whose lid it is
- `ArrayList<FaceHit> faceHits` - per-frame screen projections of pickable lid faces
- `boolean _captureFaces` - only the main 3D view records pickable faces
- `int draggedConnectionIdx`, `FaceHit draggedFace`, `PVector connDragGrab` - drag state
- `int selectedFaceShapeIdx`, `boolean selectedFaceIsTop` - the highlighted face, -1 = none
- `boolean _facePressWasSelected`, `_connDragMoved` - click-vs-drag, for the deselect toggle

### StripRotation.pde
**Bent-strip texture rotation** (per shape, mirrored via ShapeSpec):
- `float uiStripRotation` - degrees applied to the strip texture
- `PImage stripImgSrc` - the unrotated original; `stripImg` holds the rotated result so the
  ~36 existing `stripImg` read sites need no change
- `updateStripRotation()` - rebuilds it; MUST be called from the top of `draw()`, never
  inside a render (it may `createGraphics()`, unsafe nested in `beginDraw`/`beginRecord`)
- `setStripSource(img, resetRotation)` - call after assigning a new strip image

### Param.pde (UI text)
- `HashMap<Integer,PFont> _uiFonts` + `uiFont(int)` / `uiText(int)` - cached exact-size fonts
  for raw `text()` calls. Use `uiText(n)` instead of `textSize(n)` for screen-space text;
  the default P2D font is a fixed-size bitmap and any mismatched `textSize()` resamples it.

### texturesnew.pde
**Texture system**:
- `int sideTextureMode` - TEX_NONE/TEX_PER_PANEL/TEX_STRIP_BENT
- `PImage[] _edgeImgs` - Cached per-panel images
- `PImage stripImg` - Bent strip texture

### PrintNCut.pde
**Export state** (derived from Param.pde constants):
- `float widthA4, heightA4` - Print page size (px)
- `float widthA4_V, heightA4_V` - Vinyl page size (px)
- `float offW_V_F, offH_V_F` - Vinyl offset (optional)

## Variable Naming Convention

| Prefix/Suffix | Meaning | Example |
|---------------|---------|---------|
| `_px` | Pixels | `cylinderH_px` |
| (no suffix) | Millimeters | `tabDepth = 5` |
| `ui*` | UI-mirrored value | `uiHeight` |
| `s*` | Slider object | `sNSides` |
| `t*` | Toggle object | `tLock` |
| `btn*` | Button object | `btnSidesPlus` |
| `lbl*` | Label object | `lblTopP` |

## Data Flow

```
User Input (UI.pde)
    ↓
controlEvent() updates → cylinder, nSides, tab/flap values (mm)
    ↓
setParams() converts → all *_px variables (Param.pde)
    ↓
draw() / drawPlan() → uses *_px for rendering
    ↓
exportPlan() → setParams(true) for vinyl scale → save PDF/SVG
```


