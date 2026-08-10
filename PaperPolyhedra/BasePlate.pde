//----------------------------------------------------------------------------------
// BASE PLATE TOOL
// A flat rectangular base ("cuboid cutout") carrying a slit at each bottom-lid tab base.
// The bottom lid's tabs fold down and push through these slits, mounting the form onto the
// base. Only the tab-base fold segments are cut (the inverse of the lid) — nothing else:
// no lid outline, no tab shapes.
//
// Two-plate mode: one double-height piece (no cut between the plates, just a fold line).
// The TOP plate carries the current (first) shape's slits; the BOTTOM plate carries the
// SECOND shape's slits (shapes.get(1)) — so folded together it mounts one form on each side.
//
// Scope (v1): uniform bottom lids (regular polygon). Per-edge / cuboid lids are deferred.
//----------------------------------------------------------------------------------

boolean baseEnabled = false;   // toggle: add the base plate to the cut page + preview
float baseWidthMM  = 60;       // base plate width  (mm), user-set
float baseLengthMM = 60;       // base plate length (mm), user-set
float baseOffsetX  = 0;        // placement offset X (mm), like the lid offsets
float baseOffsetY  = 0;        // placement offset Y (mm)
float baseCornerRadiusMM = 0;  // rounded-corner radius of the plate (mm)
boolean baseTwoPlates = false; // two plates stacked & connected (fold line between, no cut)
boolean baseFoldLine  = true;  // draw the fold line between the two plates (off = one flat piece)
boolean baseBoxMode   = false; // draw the base as a box tray (base + fold-up walls + diagonal corners)
float baseWallHeightMM = 20;   // box wall height (mm)
boolean baseOnly      = false; // print/cut ONLY the base (skip strip, lids, cutouts, markers)

// Free-placement of the mounting slit patterns: per-pattern CENTRE offset (mm) from the base
// centre. Index 0 = current/first shape, index 1 = second shape (two-plate). Draggable.
ArrayList<PVector> baseSlitOffsets = new ArrayList<PVector>();
boolean baseSlitFreePlace = false;
int draggedSlitIdx = -1;
PVector slitDragGrab = new PVector();

boolean _baseDrawnThisFrame = false;  // draw the base ONCE even though drawPlan runs per shape

// Drag/hit-test state for moving the base plate in the preview
float _baseBBoxX, _baseBBoxY, _baseBBoxW, _baseBBoxH;  // pattern-mm bbox captured when drawn
float _baseAnchorYmm;                                   // base Y-anchor (mm) at offset 0
boolean _baseDrawnValid = false;
boolean draggedBase = false;
PVector baseDragGrab = new PVector();

// Draws the base plate. Piece origin = top-left corner (caller translates to the page pos).
void drawBasePlate() {
  float wPx = baseWidthMM  * MM_current;
  float hPx = baseLengthMM * MM_current;
  float totalH = baseTwoPlates ? 2 * hPx : hPx;
  float cornerPx = constrain(baseCornerRadiusMM * MM_current, 0, min(wPx, hPx) / 2.0);

  pushMatrix();
  pushStyle();
  translate(wPx / 2.0, totalH / 2.0);       // centre of the whole piece

  strokeWeight(1);
  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);

  // --- INTERNAL CUTS FIRST (so they are cut before the outer outline, keeping the sheet
  //     anchored until the perimeter is cut last) ---

  // Mounting slit patterns (per shape) at their free-placed offsets
  drawBaseAllSlits();

  // Fold line between the two plates (dashed score, not a cut) — optional
  if (baseTwoPlates && baseFoldLine) {
    drawDashedLine(-wPx / 2.0, 0, wPx / 2.0, 0, dash_px, gap_px);
  }

  // --- OUTER OUTLINE LAST (solid cut, rounded corners). When doubled this is one tall
  //     rectangle — no cut between the two plates, so they stay joined. ---
  rectMode(CENTER);
  rect(0, 0, wPx, totalH, cornerPx);

  popStyle();
  popMatrix();
}

// Draws the base as a box tray: central base face + 4 fold-up walls + diagonal tuck corners.
// One piece, centred; piece origin = top-left corner (caller translates to the page position).
void drawBaseBox() {
  float W = baseWidthMM  * MM_current;            // base face width
  float baseL = baseLengthMM * MM_current;        // one shape's base length
  float L = baseTwoPlates ? 2 * baseL : baseL;    // total base length (two shapes = 2x, connected)
  float H = baseWallHeightMM * MM_current;
  float outerW = W + 2 * H;
  float outerL = L + 2 * H;

  pushMatrix();
  pushStyle();
  translate(outerW / 2.0, outerL / 2.0);  // centre of the whole net
  strokeWeight(1);
  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);

  // 1. Slits on the base face — cut FIRST. Two-plate box = one long base holding both shapes.
  drawBaseAllSlits();
  // Middle base fold connecting the two shape areas (optional, like the flat two-plate)
  if (baseTwoPlates && baseFoldLine) drawDashedLine(-W / 2, 0, W / 2, 0, dash_px, gap_px);

  // 2. Base/wall fold lines — extended to the FULL outer extent so each corner square gets its
  //    two straight fold lines (bounding the corner) in addition to the diagonal.
  drawDashedLine(-W / 2, -outerL / 2, -W / 2,  outerL / 2, dash_px, gap_px);  // left, full height
  drawDashedLine( W / 2, -outerL / 2,  W / 2,  outerL / 2, dash_px, gap_px);  // right, full height
  drawDashedLine(-outerW / 2, -L / 2,  outerW / 2, -L / 2, dash_px, gap_px);  // top, full width
  drawDashedLine(-outerW / 2,  L / 2,  outerW / 2,  L / 2, dash_px, gap_px);  // bottom, full width

  // 3. Diagonal corner folds — base corner out to the sheet corner (self-tucking corners)
  drawDashedLine(-W / 2, -L / 2, -outerW / 2, -outerL / 2, dash_px, gap_px);
  drawDashedLine( W / 2, -L / 2,  outerW / 2, -outerL / 2, dash_px, gap_px);
  drawDashedLine(-W / 2,  L / 2, -outerW / 2,  outerL / 2, dash_px, gap_px);
  drawDashedLine( W / 2,  L / 2,  outerW / 2,  outerL / 2, dash_px, gap_px);

  // 4. Outer outline — solid cut, LAST
  rectMode(CENTER);
  rect(0, 0, outerW, outerL);

  popStyle();
  popMatrix();
}

// Rebuilds baseSlitOffsets to the default layout ONLY when the pattern count changed, so
// free-placed positions survive unless single/two-plate changes. Offsets are mm from base centre.
void ensureBaseSlitOffsets() {
  int count = baseTwoPlates ? 2 : 1;
  if (baseSlitOffsets.size() == count) return;
  baseSlitOffsets.clear();
  if (baseTwoPlates) {
    baseSlitOffsets.add(new PVector(0, -baseLengthMM / 2.0));  // shape 1 (top half)
    baseSlitOffsets.add(new PVector(0,  baseLengthMM / 2.0));  // shape 2 (bottom half)
  } else {
    baseSlitOffsets.add(new PVector(0, 0));                    // single, centred
  }
}

// Draws every shape's slit pattern at its stored offset from the base centre (which is the
// current origin). Shared by the flat plate and the box tray.
void drawBaseAllSlits() {
  ensureBaseSlitOffsets();
  PVector o0 = baseSlitOffsets.get(0);
  pushMatrix();
  translate(o0.x * MM_current, o0.y * MM_current);
  drawBaseSlits(nSides, cellBaseL_px, tabInset_bot_px);
  popMatrix();

  if (baseTwoPlates && shapes != null && shapes.size() >= 2 && baseSlitOffsets.size() >= 2) {
    ShapeSpec s2 = shapes.get(1);
    int   n2    = max(3, s2.nSides);
    float edge2 = (s2.cylinder.y / n2) * MM_current;
    PVector o1  = baseSlitOffsets.get(1);
    pushMatrix();
    translate(o1.x * MM_current, o1.y * MM_current);
    drawBaseSlits(n2, edge2, edge2 / 4.0);
    popMatrix();
  }
}

// Circumradius (mm) of slit pattern i — used as the drag hit radius.
float baseSlitRadiusMM(int i) {
  int n; float edgeMM;
  if (i == 0) { n = max(3, nSides); edgeMM = cylinder.y / n; }
  else if (shapes != null && shapes.size() >= 2) {
    ShapeSpec s2 = shapes.get(1); n = max(3, s2.nSides); edgeMM = s2.cylinder.y / n;
  } else return 10;
  return (edgeMM / 2.0) / sin(PI / n);
}

// Draws one polygon arrangement of tab-base slits, centred at the current origin.
// Segment matches the tab base drawn in drawPolygonLid().
void drawBaseSlits(int n, float edgePx, float tabInsetPx) {
  n = max(3, n);
  float angleIncrement = TWO_PI / n;
  float radius  = (edgePx / 2.0) / sin(PI / n);
  float apothem = radius * cos(angleIncrement / 2.0);
  for (int i = 0; i < n; i++) {
    pushMatrix();
    rotate(i * angleIncrement);
    translate(0, -apothem);                 // to the midpoint of edge i
    line(-edgePx / 2.0 + tabInsetPx * 2, 0, edgePx / 2.0, 0);
    popMatrix();
  }
}
