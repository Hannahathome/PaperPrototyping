// TEMPLATE.PDE - The flat template, copied from PaperPolyhedra and recorded instead of drawn
//
// ---------------------------------------------------------------------------
// COPIED FROM PaperPolyhedra -- KEEP IN STEP
// ---------------------------------------------------------------------------
// The functions under "Copied" are PaperPolyhedra's own, from tools.pde (drawTzFoldlines,
// drawTzTopFolds and their _Range versions), api.pde (the tab contours, both slant flaps,
// drawPolygonLid, getPolygonLidDimensions), texturesnew.pde (computeStripHeight_Uniform) and
// the uniform branch of drawPlan() in PaperPolyhedra.pde. The derived sizes in
// setTemplateParams() are setParams() from Param.pde, including its clamps.
//
// They are copied as they are, with three changes:
//   1. Drawing calls go to the recorder below: rLine / rBegin, rVertex, rEnd are full CUTS,
//      rFold (PaperPolyhedra's drawDashedLine) is a FOLD. pushMatrix, translate and rotate
//      become rPush, rTranslate, rRotate, so every point lands in template millimetres.
//   2. They also call rAnchor() at the points the close-ups and dimensions are measured
//      from: panel corners, one wall tab, both flaps, one lid tab.
//   3. Units: PaperPolyhedra multiplies millimetres by MM to get pixels. Here MM is 1, so
//      every *_px variable holds millimetres. The names are kept so the code reads the same.
// Textures, colour fills, markers, connections and offsets/rotations set by dragging in
// PaperPolyhedra play no part in the outline and are left out.
//
// Stage 1 covers the uniform template: regular prisms and frustums, whole or split strip.
// If PaperPolyhedra's tab, flap or lid shapes change, change them here too.

final int K_CUT  = 0;   // a full cut: solid
final int K_FOLD = 1;   // a fold: dashed

class TStroke {
  PVector[] pts;
  int kind;
  TStroke(PVector[] pts, int kind) { this.pts = pts; this.kind = kind; }
}

class Template {
  ArrayList<TStroke> strokes = new ArrayList<TStroke>();
  HashMap<String, PVector> anchors = new HashMap<String, PVector>();
  float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE, maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE;

  // The sizes as PaperPolyhedra uses them, after its clamps (mm).
  float edgeTop, edgeBot, panelH, vertH;
  float tabDepthUsed, neckWall, neckLid, neckHook;
  float flapDepthUsed, flapTaperUsed, hookOffsetUsed;
  float insetTop, insetBot, insetH, flareTop, flareBot, flareH;
  boolean tabClamped, flapClamped, taperClamped;

  PVector a(String key) { return anchors.get(key); }
  boolean has(String... keys) {
    for (String k : keys) if (!anchors.containsKey(k)) return false;
    return true;
  }
}

// ---------------------------------------------------------------------------
// The recorder
// ---------------------------------------------------------------------------

Template rT;                                    // the template being recorded
float[] rM = { 1, 0, 0, 0, 1, 0 };              // current transform: x' = m0 x + m1 y + m2
ArrayList<float[]> rStack = new ArrayList<float[]>();
ArrayList<PVector> rShape = null;               // open beginShape()
int rPanel = -1;                                // global index of the panel being drawn
String rLid = "";                               // "top" / "bot" while a lid is drawn

PVector rApply(float x, float y) {
  return new PVector(rM[0] * x + rM[1] * y + rM[2], rM[3] * x + rM[4] * y + rM[5]);
}

void rPush() { rStack.add(rM.clone()); }
void rPop()  { rM = rStack.remove(rStack.size() - 1); }

void rTranslate(float x, float y) {
  rM[2] += rM[0] * x + rM[1] * y;
  rM[5] += rM[3] * x + rM[4] * y;
}

void rRotate(float ang) {
  float c = cos(ang), s = sin(ang);
  float m0 = rM[0] * c + rM[1] * s, m1 = -rM[0] * s + rM[1] * c;
  float m3 = rM[3] * c + rM[4] * s, m4 = -rM[3] * s + rM[4] * c;
  rM[0] = m0; rM[1] = m1; rM[3] = m3; rM[4] = m4;
}

void rAdd(PVector[] pts, int kind) {
  rT.strokes.add(new TStroke(pts, kind));
  for (PVector p : pts) {
    rT.minX = min(rT.minX, p.x); rT.maxX = max(rT.maxX, p.x);
    rT.minY = min(rT.minY, p.y); rT.maxY = max(rT.maxY, p.y);
  }
}

void rLine(float x1, float y1, float x2, float y2) {
  rAdd(new PVector[]{ rApply(x1, y1), rApply(x2, y2) }, K_CUT);
}

// drawDashedLine(): recorded as the whole line. The figure draws its own dashes, so a fold
// reads the same at any size.
void rFold(float x1, float y1, float x2, float y2, float dashLength, float gapLength) {
  if (dist(x1, y1, x2, y2) <= 2 * gapLength) return;   // drawDashedLine draws nothing then
  rAdd(new PVector[]{ rApply(x1, y1), rApply(x2, y2) }, K_FOLD);
}

void rBegin() { rShape = new ArrayList<PVector>(); }
void rVertex(float x, float y) { rShape.add(rApply(x, y)); }
void rEnd() {
  if (rShape != null && rShape.size() > 1) rAdd(rShape.toArray(new PVector[0]), K_CUT);
  rShape = null;
}

// The first point recorded under a key wins.
void rAnchor(String key, float x, float y) {
  if (!rT.anchors.containsKey(key)) rT.anchors.put(key, rApply(x, y));
}

// ---------------------------------------------------------------------------
// Parameters: PaperPolyhedra's globals, in millimetres (MM = 1)
// ---------------------------------------------------------------------------

final float MM = 1;
final float TAB_DEPTH_FRACTION = 0.2;   // lid tab neck, as a fraction of the tab depth
final float FOLD_DASH_SCALE = 0.4;
final float dash = 3, gap = 3;

int   nSides, rows, cols;
float cellTopL_px, cellBaseL_px, cylinderH_px, cylinderVertH_px;
float flapDepth_px, flapTaper_px, tabDepth_px;
float tabInset_h_px, tabInset_top_px, tabInset_bot_px;
float arrowheadFlare_h_px, arrowheadFlare_top_px, arrowheadFlare_bot_px;
float dash_px, gap_px, neckDepth_px, neckDepth_hook_px, hookOffset_px;
float tab_neck_ratio, tab_neck_ratio_hook = 0.2;
boolean uiHidePanelFolds = false;

// PaperPolyhedra's perimeter from a diameter slider (UI.pde applyToModel()): the
// circumscribed diameter, except at 4 sides, where the "diameter" is the side length.
float perimeterFromDiameter(int n, float d) {
  return n == 4 ? 4 * max(1, d) : n * max(1, d) * sin(PI / n);
}

// setParams() from Param.pde, the parts the outline uses.
void setTemplateParams() {
  nSides = max(3, sides);
  rows = nSides + 1;
  cols = 1 + 1;
  float cylinderTP_px = perimeterFromDiameter(nSides, topDiameter) * MM;
  float cylinderBP_px = perimeterFromDiameter(nSides, bottomDiameter) * MM;
  cellTopL_px  = cylinderTP_px / (float)nSides;
  cellBaseL_px = cylinderBP_px / (float)nSides;
  float sideDiff_px = abs(cellBaseL_px - cellTopL_px);
  cylinderVertH_px = shellHeight * MM;
  cylinderH_px = sqrt(sq(cylinderVertH_px) + sq(sideDiff_px));

  flapDepth_px = flapDepth * MM;
  flapDepth_px = min(flapDepth_px, cellTopL_px * 0.5, cellBaseL_px * 0.5);
  flapTaper_px = flapTaper * MM;
  if (flapTaper_px > cylinderH_px * .33) flapTaper_px = cylinderH_px * 0.33;
  tabDepth_px = tabDepth * MM;
  tabDepth_px = min(tabDepth_px, min(cellTopL_px * 0.5, cellBaseL_px * 0.5));
  tabDepth_px = min(tabDepth_px, cylinderH_px * 0.5);
  tabInset_h_px   = cylinderH_px / 4.;
  tabInset_top_px = cellTopL_px / 4.;
  tabInset_bot_px = cellBaseL_px / 4.;
  arrowheadFlare_h_px   = tabInset_h_px / 3.;
  arrowheadFlare_top_px = tabInset_top_px / 3.;
  arrowheadFlare_bot_px = tabInset_bot_px / 3.;
  dash_px = dash * MM * FOLD_DASH_SCALE;
  gap_px  = gap * MM * FOLD_DASH_SCALE;
  tab_neck_ratio = tabNeckRatio;
  neckDepth_px      = tabDepth_px * tab_neck_ratio;
  neckDepth_hook_px = tabDepth_px * tab_neck_ratio_hook;
  hookOffset_px = hookOffset * MM;
}

// ---------------------------------------------------------------------------
// The template, as the uniform branch of drawPlan() lays it out
// ---------------------------------------------------------------------------

Template buildTemplate() {
  rT = new Template();
  rM = new float[]{ 1, 0, 0, 0, 1, 0 };
  rStack.clear();
  setTemplateParams();

  if (splitStrip && nSides >= 4) {
    int splitAt = (int)ceil(nSides / 2.0);
    float stripHeight = computeStripHeight_Uniform();
    float splitSpacing = stripHeight + tabDepth_px * 2 + 10 * MM;
    rPush();
    drawTzFoldlines_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), 0, splitAt);
    drawTzTopFolds_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), 0, splitAt, true, true);
    rPop();
    rPush();
    rTranslate(0, splitSpacing);
    drawTzFoldlines_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), splitAt, nSides);
    drawTzTopFolds_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), splitAt, nSides, true, true);
    rPop();
  } else {
    drawTzFoldlines(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1));
    drawTzTopFolds(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1));
  }

  float stripHeight = computeStripHeight_Uniform();
  if (splitStrip && nSides >= 4) {
    float splitSpacingLid = stripHeight + tabDepth_px * 2 + 10 * MM;
    stripHeight = splitSpacingLid + stripHeight;
  }
  PVector lidBaseSize = getPolygonLidDimensions(nSides, cellBaseL_px, tabDepth_px);
  PVector lidTopSize  = getPolygonLidDimensions(nSides, cellTopL_px, tabDepth_px);
  float extraLidSpace = max(0, lidTopSize.y - lidBaseSize.y);
  float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * MM);
  float neckDepth_px2 = tabDepth_px * TAB_DEPTH_FRACTION;

  rPush();
  rTranslate(0, lidSpacing);
  rLid = "bot";
  drawPolygonLid(nSides, cellBaseL_px, neckDepth_px2, tabInset_bot_px, arrowheadFlare_bot_px);
  rPop();

  rPush();
  rTranslate(0, lidSpacing);
  rTranslate(lidBaseSize.x, lidBaseSize.y - lidTopSize.y);
  rLid = "top";
  drawPolygonLid(nSides, cellTopL_px, neckDepth_px2, tabInset_top_px, arrowheadFlare_top_px);
  rPop();
  rLid = "";

  Template t = rT;
  t.edgeTop = cellTopL_px;          t.edgeBot = cellBaseL_px;
  t.panelH = cylinderH_px;          t.vertH = cylinderVertH_px;
  t.tabDepthUsed = tabDepth_px;
  t.neckWall = neckDepth_px;        t.neckLid = neckDepth_px2;    t.neckHook = neckDepth_hook_px;
  t.flapDepthUsed = flapDepth_px;   t.flapTaperUsed = flapTaper_px;
  t.hookOffsetUsed = hookOffset_px;
  t.insetTop = tabInset_top_px;     t.insetBot = tabInset_bot_px;  t.insetH = tabInset_h_px;
  t.flareTop = arrowheadFlare_top_px; t.flareBot = arrowheadFlare_bot_px; t.flareH = arrowheadFlare_h_px;
  t.tabClamped   = tabDepth_px < tabDepth * MM - 1e-3;
  t.flapClamped  = flapDepth_px < flapDepth * MM - 1e-3;
  t.taperClamped = flapTaper_px < flapTaper * MM - 1e-3;
  return t;
}

final float LID_SPACING_MARGIN = 1.25;

// ===========================================================================
// Copied (see the header). Drawing calls renamed to the recorder; rAnchor() added.
// ===========================================================================

// --- texturesnew.pde ---

float computeStripHeight_Uniform() {
  final int n = max(3, (rows - 1));
  final float h = cylinderH_px;
  final float t = cellTopL_px;
  final float b = cellBaseL_px;
  Affine T = new Affine();
  float maxY = h;
  maxY = max(maxY, T.apply(0, 0).y);
  maxY = max(maxY, T.apply(b, 0).y);
  maxY = max(maxY, T.apply((b-t)/2.0f, h).y);
  maxY = max(maxY, T.apply((b-t)/2.0f + t, h).y);
  for (int e = 0; e < n - 1; e++) {
    T.translate(b, 0);
    PVector A_r = new PVector((t - b)/2.0f, h);
    float offN = (b - t)/2.0f;
    PVector B_l = new PVector(offN, h);
    float rot = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
    T.rotate(rot);
    maxY = max(maxY, T.apply(0, 0).y);
    maxY = max(maxY, T.apply(b, 0).y);
    maxY = max(maxY, T.apply((b-t)/2.0f, h).y);
    maxY = max(maxY, T.apply((b-t)/2.0f + t, h).y);
  }
  return maxY;
}

class Affine {
  float c=1, s=0, tx=0, ty=0;
  PVector apply(float x, float y) { return new PVector(c*x - s*y + tx, s*x + c*y + ty); }
  void translate(float dx, float dy) { tx += c*dx - s*dy; ty += s*dx + c*dy; }
  void rotate(float ang) { float cc=cos(ang), ss=sin(ang), nc=c*cc - s*ss, ns=s*cc + c*ss; c=nc; s=ns; }
}

// --- tools.pde ---

void drawTzFoldlines(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int n) {
  rPush();
  rTranslate(startX, startY);
  for (int count = 0; count < n; count++) {
    float mh = h / (float)m;
    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      PVector p1 = new PVector(offset*i+mbottom, mh*i);
      PVector p2 = new PVector(offset*i+offset + mtop, mh*i + mh);
      if (count < n-1 && !uiHidePanelFolds) {
        rFold(p1.x, p1.y, p2.x, p2.y, dash_px, gap_px);
      }
    }
    if (count < n-1) {
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      rTranslate(bottomLen, 0);
      rRotate(rotationNeeded);
    }
  }
  rPop();
}

void drawTzFoldlines_Range(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int panelStart, int panelEnd) {
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;
  rPush();
  rTranslate(startX, startY);
  for (int count = 0; count < nPanels; count++) {
    float mh = h / (float)m;
    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      PVector p1 = new PVector(offset*i+mbottom, mh*i);
      PVector p2 = new PVector(offset*i+offset + mtop, mh*i + mh);
      if (count < nPanels-1 && !uiHidePanelFolds) {
        rFold(p1.x, p1.y, p2.x, p2.y, dash_px, gap_px);
      }
    }
    if (count < nPanels - 1) {
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      rTranslate(bottomLen, 0);
      rRotate(rotationNeeded);
    }
  }
  rPop();
}

void drawTzTopFolds(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int n) {
  drawTzTopFolds_Range(startX, startY, topLen, bottomLen, h, m, 0, n, true, true);
}

// PaperPolyhedra's drawTzTopFolds() is this with panelStart 0, panelEnd n and both flaps;
// the two bodies are otherwise the same, so the range version serves both here.
void drawTzTopFolds_Range(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int panelStart, int panelEnd, boolean leftFlap, boolean rightFlap) {
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;
  rPush();
  rTranslate(startX, startY);
  for (int count = 0; count < nPanels; count++) {
    float mh = h / (float)m;
    PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
    float offsetNext = (bottomLen - topLen) / 2.0;
    PVector B_left   = new PVector(offsetNext, h);
    float angleA         = atan2(A_right.y, A_right.x);
    float angleB         = atan2(B_left.y, B_left.x);
    float rotationNeeded = angleA - angleB;
    rPanel = panelStart + count;

    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      PVector pb = new PVector(offset*i, mh*i);
      PVector db = new PVector(mbottom, 0);
      PVector pt = new PVector(offset*i+offset, mh*i + mh);
      PVector dt = new PVector(mtop, 0);
      rAnchor("panel" + rPanel + ".BL", pb.x, pb.y);
      rAnchor("panel" + rPanel + ".BR", pb.x + db.x, pb.y + db.y);
      rAnchor("panel" + rPanel + ".TL", pt.x, pt.y);
      rAnchor("panel" + rPanel + ".TR", pt.x + dt.x, pt.y + dt.y);
      drawBottomTabContour(pb, db, tabDepth_px, tabInset_bot_px, arrowheadFlare_bot_px, neckDepth_px);
      drawTopTabContour(pt, dt, tabDepth_px, tabInset_top_px, arrowheadFlare_top_px, neckDepth_px);
      if (count == 0 && leftFlap) {
        rPush();
        drawLeftSlantFlap(pb, pt, flapDepth_px, flapTaper_px, tabInset_h_px);
        rPop();
      }
      if (count == nPanels - 1 && rightFlap) {
        rPush();
        drawRightSlantFlap(PVector.add(pb, db), PVector.add(pt, dt), flapDepth_px, tabInset_h_px, arrowheadFlare_h_px, neckDepth_hook_px, hookOffset_px);
        rPop();
      }
    }
    if (count < nPanels - 1) {
      rTranslate(bottomLen, 0);
      rRotate(rotationNeeded);
    }
  }
  rPanel = -1;
  rPop();
}

// --- api.pde ---

void drawLeftSlantFlap(PVector p1, PVector p4, float flapDepth, float taper, float inset) {
  PVector leftEdge = PVector.sub(p1, p4);
  PVector leftPerp = new PVector(leftEdge.y, -leftEdge.x);
  leftPerp.normalize();
  leftPerp.mult(flapDepth);

  PVector insetEdge = PVector.sub(p1, p4);
  float insetRatio = inset/insetEdge.mag();
  float insetMagnitudeEdge = insetEdge.mag() * insetRatio;
  insetEdge.normalize();
  PVector p1_edge_inset = PVector.sub(p1, PVector.mult(insetEdge, insetMagnitudeEdge));
  PVector p4_edge_inset = PVector.add(p4, PVector.mult(insetEdge, insetMagnitudeEdge));

  PVector p1_flap_rect = PVector.add(p1, leftPerp);
  PVector p4_flap_rect = PVector.add(p4, leftPerp);

  PVector outerEdgeLeft = PVector.sub(p1_flap_rect, p4_flap_rect);
  float taperRatio = taper / outerEdgeLeft.mag();
  float insetMagnitudeLeft = outerEdgeLeft.mag() * taperRatio;
  outerEdgeLeft.normalize();

  PVector p1_flap = PVector.sub(p1_flap_rect, PVector.mult(outerEdgeLeft, insetMagnitudeLeft));
  PVector p4_flap = PVector.add(p4_flap_rect, PVector.mult(outerEdgeLeft, insetMagnitudeLeft));

  String k = "glue.";
  rAnchor(k + "p1", p1.x, p1.y);                         rAnchor(k + "p4", p4.x, p4.y);
  rAnchor(k + "p1_inset", p1_edge_inset.x, p1_edge_inset.y);
  rAnchor(k + "p4_inset", p4_edge_inset.x, p4_edge_inset.y);
  rAnchor(k + "p1_rect", p1_flap_rect.x, p1_flap_rect.y);
  rAnchor(k + "p1_flap", p1_flap.x, p1_flap.y);         rAnchor(k + "p4_flap", p4_flap.x, p4_flap.y);

  rFold(p4.x, p4.y, p4_edge_inset.x, p4_edge_inset.y, dash_px, gap_px);
  rLine(p4_edge_inset.x, p4_edge_inset.y, p1_edge_inset.x, p1_edge_inset.y);
  rFold(p1_edge_inset.x, p1_edge_inset.y, p1.x, p1.y, dash_px, gap_px);

  rBegin();
  rVertex(p4.x, p4.y);
  rVertex(p4_flap.x, p4_flap.y);
  rVertex(p1_flap.x, p1_flap.y);
  rVertex(p1.x, p1.y);
  rEnd();
}

void drawRightSlantFlap(PVector p2, PVector p3, float flapDepth, float inset, float arrowheadFlare, float neckDepth, float hookOffset) {
  PVector rightEdge = PVector.sub(p3, p2);

  float insetRatio = inset/rightEdge.mag();
  float insetMagnitudeEdge = rightEdge.mag() * insetRatio;
  rightEdge.normalize();
  PVector p2_edge_inset = PVector.add(p2, PVector.mult(rightEdge, insetMagnitudeEdge));
  PVector p3_edge_inset = PVector.sub(p3, PVector.mult(rightEdge, insetMagnitudeEdge));

  PVector insetEdge = PVector.sub(p3_edge_inset, p2_edge_inset);

  PVector insetPerp = new PVector(insetEdge.y, -insetEdge.x);
  insetPerp.normalize();
  insetPerp.mult(flapDepth);
  PVector p2_flap_rect = PVector.add(p2_edge_inset, insetPerp);
  PVector p3_flap_rect = PVector.add(p3_edge_inset, insetPerp);

  insetPerp.normalize();
  insetPerp.mult(neckDepth);
  PVector p2_neck_Depth = PVector.add(p2_edge_inset, insetPerp);
  PVector p3_neck_Depth = PVector.add(p3_edge_inset, insetPerp);

  PVector outerNeckRight = PVector.sub(p3_neck_Depth, p2_neck_Depth);
  float hookRatio = hookOffset / outerNeckRight.mag();
  float hookMagnitudeRight = outerNeckRight.mag() * hookRatio;
  outerNeckRight.normalize();
  PVector p2_hook = PVector.add(p2_neck_Depth, PVector.mult(outerNeckRight, hookMagnitudeRight));
  PVector p3_hook = PVector.sub(p3_neck_Depth, PVector.mult(outerNeckRight, hookMagnitudeRight));

  PVector outerEdgeRight = PVector.sub(p3_flap_rect, p2_flap_rect);
  float arrowFlareRatio = arrowheadFlare / outerEdgeRight.mag();
  float insetMagnitudeRight = outerEdgeRight.mag() * arrowFlareRatio;
  outerEdgeRight.normalize();
  PVector p2_flap = PVector.add(p2_flap_rect, PVector.mult(outerEdgeRight, insetMagnitudeRight));
  PVector p3_flap = PVector.sub(p3_flap_rect, PVector.mult(outerEdgeRight, insetMagnitudeRight));

  String k = "hook.";
  rAnchor(k + "p2", p2.x, p2.y);                         rAnchor(k + "p3", p3.x, p3.y);
  rAnchor(k + "p2_inset", p2_edge_inset.x, p2_edge_inset.y);
  rAnchor(k + "p3_inset", p3_edge_inset.x, p3_edge_inset.y);
  rAnchor(k + "p2_neck", p2_neck_Depth.x, p2_neck_Depth.y);
  rAnchor(k + "p2_hook", p2_hook.x, p2_hook.y);         rAnchor(k + "p3_hook", p3_hook.x, p3_hook.y);
  rAnchor(k + "p2_rect", p2_flap_rect.x, p2_flap_rect.y);
  rAnchor(k + "p2_flap", p2_flap.x, p2_flap.y);         rAnchor(k + "p3_flap", p3_flap.x, p3_flap.y);

  rFold(p3_edge_inset.x, p3_edge_inset.y, p2_edge_inset.x, p2_edge_inset.y, dash_px, gap_px);
  rBegin();
  rVertex(p3.x, p3.y);
  rVertex(p3_edge_inset.x, p3_edge_inset.y);
  rVertex(p3_hook.x, p3_hook.y);
  rVertex(p3_flap.x, p3_flap.y);
  rVertex(p2_flap.x, p2_flap.y);
  rVertex(p2_hook.x, p2_hook.y);
  rVertex(p2_edge_inset.x, p2_edge_inset.y);
  rVertex(p2.x, p2.y);
  rEnd();
}

void drawBottomTabContour(PVector p, PVector d, float tabDepth, float tabInset, float arrowheadFlare, float neckDepth) {
  rFold(p.x + d.x - tabInset*0, p.y + d.y, p.x + tabInset*2, p.y + d.y, dash_px, gap_px);

  rBegin();
  rVertex(p.x + d.x, p.y + d.y);
  rVertex(p.x + d.x - tabInset*0, p.y + d.y);
  rVertex(p.x + d.x - tabInset*0, p.y + d.y - neckDepth);
  rVertex(p.x + d.x - tabInset*0 - arrowheadFlare, p.y + d.y - tabDepth);
  rVertex(p.x + tabInset*2 + arrowheadFlare, p.y + d.y - tabDepth);
  rVertex(p.x + tabInset*2, p.y + d.y - neckDepth);
  rVertex(p.x + tabInset*2, p.y + d.y);
  rVertex(p.x, p.y + d.y);
  rEnd();
}

void drawTopTabContour(PVector p, PVector d, float tabDepth, float tabInset, float arrowheadFlare, float neckDepth) {
  // The wall tab the close-up measures: panel 1's, clear of the glue flap on panel 0.
  if (rPanel == 1) {
    String k = "walltab.";
    rAnchor(k + "e0", p.x, p.y);
    rAnchor(k + "b0", p.x + tabInset*0, p.y);
    rAnchor(k + "n0", p.x + tabInset*0, p.y + neckDepth);
    rAnchor(k + "t0", p.x + tabInset*0 + arrowheadFlare, p.y + tabDepth);
    rAnchor(k + "t1", p.x + d.x - tabInset*2 - arrowheadFlare, p.y + tabDepth);
    rAnchor(k + "n1", p.x + d.x - tabInset*2, p.y + neckDepth);
    rAnchor(k + "b1", p.x + d.x - tabInset*2, p.y);
    rAnchor(k + "e1", p.x + d.x, p.y);
  }

  rFold(p.x + tabInset*0, p.y, p.x + d.x - tabInset*2, p.y, dash_px, gap_px);

  rBegin();
  rVertex(p.x, p.y);
  rVertex(p.x + tabInset*0, p.y);
  rVertex(p.x + tabInset*0, p.y + neckDepth);
  rVertex(p.x + tabInset*0 + arrowheadFlare, p.y + tabDepth);
  rVertex(p.x + d.x - tabInset*2 - arrowheadFlare, p.y + tabDepth);
  rVertex(p.x + d.x - tabInset*2, p.y + neckDepth);
  rVertex(p.x + d.x - tabInset*2, p.y);
  rVertex(p.x + d.x, p.y);
  rEnd();
}

PVector getPolygonLidDimensions(int numSides, float sideLength, float tabDepthValue) {
  float radius = (sideLength / 2.0) / sin(PI / numSides);
  float angleIncrement = TWO_PI / numSides;
  float startAngle = -HALF_PI - angleIncrement / 2.0;
  float minX = Float.MAX_VALUE;
  float maxX = Float.MIN_VALUE;
  float minY = Float.MAX_VALUE;
  float maxY = Float.MIN_VALUE;
  for (int i = 0; i < numSides; i++) {
    float ang = startAngle + i * angleIncrement;
    float vx = cos(ang) * radius;
    float vy = sin(ang) * radius;
    if (vx < minX) minX = vx;
    if (vx > maxX) maxX = vx;
    if (vy < minY) minY = vy;
    if (vy > maxY) maxY = vy;
  }
  float polygonWidth = maxX - minX;
  float polygonHeight = maxY - minY;
  float totalWidth = polygonWidth + (2 * tabDepthValue);
  float totalHeight = polygonHeight + (2 * tabDepthValue);
  return new PVector(totalWidth, totalHeight);
}

void drawPolygonLid(int numSides, float sideLength, float neckDepth, float tabInset, float arrowheadFlare) {
  float radius = (sideLength / 2.0) / sin(PI / (float)numSides);
  float angleIncrement = TWO_PI / (float)numSides;
  float rectWidth = (radius*cos(angleIncrement/2)+tabDepth_px)*2;
  rPush();
  rTranslate(rectWidth/2., rectWidth/2.);

  for (int i = 0; i < numSides; i++) {
    rPush();
    rRotate(i * angleIncrement);
    rTranslate(0, -radius*cos(angleIncrement/2));
    rFold(-sideLength/2. + tabInset*2, 0, sideLength/2., 0, dash_px, gap_px);
    rPop();
  }

  for (int i = 0; i < numSides; i++) {
    rPush();
    rRotate(i * angleIncrement);
    rTranslate(0, -radius*cos(angleIncrement/2));
    // The lid tab the close-up measures: the top lid's first edge.
    if (i == 0 && rLid.equals("top")) {
      String k = "lidtab.";
      rAnchor(k + "e0", -sideLength/2., 0);
      rAnchor(k + "b0", -sideLength/2 + tabInset*2, 0);
      rAnchor(k + "n0", -sideLength/2 + tabInset*2, -neckDepth);
      rAnchor(k + "t0", -sideLength/2 + tabInset*2 + arrowheadFlare, -tabDepth_px);
      rAnchor(k + "t1", sideLength/2  - arrowheadFlare, -tabDepth_px);
      rAnchor(k + "n1", sideLength/2, -neckDepth);
      rAnchor(k + "b1", sideLength/2, 0);
      rAnchor(k + "e1", sideLength/2., 0);
    }
    rBegin();
    rVertex(-sideLength/2., 0);
    rVertex(-sideLength/2 + tabInset*2, 0);
    rVertex(-sideLength/2 + tabInset*2, -neckDepth);
    rVertex(-sideLength/2 + tabInset*2 + arrowheadFlare, -tabDepth_px);
    rVertex(sideLength/2  - arrowheadFlare, -tabDepth_px);
    rVertex(sideLength/2, -neckDepth);
    rVertex(sideLength/2, 0);
    rVertex(sideLength/2., 0);
    rEnd();
    rPop();
  }

  rPop();
}
