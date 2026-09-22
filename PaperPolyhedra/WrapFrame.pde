// WRAPFRAME.PDE - Canonical whole-surface texture frame
//
// One frame, three projections. TEX_WRAP_FULL puts a SINGLE image over a shape's entire
// outer surface - bottom lid, side wall, top lid - so artwork crossing a rim stays
// continuous when the piece is folded. The flat pattern, the 3D preview and the PDF export
// all read the coordinates below and nothing else, which is what stops them drifting apart.
// Same arrangement as LidFrame.pde and SidePanelFrame.pde; see those for the house style.
//
// SURFACE COORDINATES
//
//   s  0..1   once around the perimeter. Allocated per panel in proportion to the panel's
//             AVERAGE width, (top + bottom) / 2, then linear inside the panel. Panel 0's
//             left fold is s = 0 - that edge already carries the glue tab, so the seam
//             lands where the join is anyway.
//
//   t  0..1   arc length along the surface, measured ON THE PAPER: 0 at the bottom lid's
//             centre, up over the wall, 1 at the top lid's centre. The wall therefore uses
//             cylinderH_px (the SLANT height) and not cylinderVertH_px - the texture is
//             printed on the panel, and the panel is the slant.
//
//              t=1     top lid centre
//              t=tTop  top rim      <- fold. Artwork must not break here.
//              t=tBot  bottom rim   <- fold. Artwork must not break here.
//              t=0     bottom lid centre
//
// WHY THE CAPS USE THE APOTHEM
//
// A cap's rim is a polygon, so the distance from centre to rim varies between an edge
// midpoint (the apothem) and a corner (the circumradius). The t budget takes the APOTHEM,
// and inside the cap t runs linearly along the radial ray out to whatever the rim actually
// is at that s. That makes t CONSTANT along the whole rim - the join is exact - at the cost
// of a little radial stretch towards the corners. Continuity at the fold is the thing worth
// buying; nobody can see a few percent of radial stretch.
//
// At t = 0 and t = 1 a whole image row collapses to a point. That pinch is inherent to
// wrapping a rectangle onto a closed surface, the same bargain a globe makes at its poles.
//
// IMAGE ORIENTATION
//
// The top of the image lands on the top of the model: v = (1 - t) * img.height.
//
// Note this is the opposite of TEX_STRIP_BENT, which maps image row 0 onto the model's
// BOTTOM rim (see drawTriangleStripTexture_Uniform, and the 3D twin in
// drawTexturedPrismFaces which agrees with it). Strip mode is left alone - changing it
// would flip every strip texture anyone has already cropped - but a new mode has no such
// debt, and "up in the picture is up on the model" is what people expect.
//
// SCOPE
//
// Uniform regular prisms and frustums only, matching lidFrameAvailable(). Hollow is
// rejected because a donut lid has no centre and so never reaches t = 1; kresling because
// the strip is sheared as a whole; per-edge and cuboid because their lids are not the
// regular polygons the cap mesh walks. wrapFrameAvailable() refuses rather than mis-map.

// ---------------------------------------------------------------------------
// State (per shape, mirrored through ShapeSpec like the other texture fields)
// ---------------------------------------------------------------------------

PImage wrapImg = null;          // the image wrapped over the whole surface
PImage originalWrapImg = null;  // pre-crop original, for the cropper's Reset

// ---------------------------------------------------------------------------
// Availability
// ---------------------------------------------------------------------------

boolean wrapFrameAvailable() {
  return !perEdgeMode && !cuboidMode && !hollowMode && !kreslingMode && nSides >= 3;
}

// True when wrap mode is selected AND able to draw. Every draw site tests this.
boolean wrapActive() {
  return sideTextureMode == TEX_WRAP_FULL && wrapImg != null && wrapFrameAvailable();
}

// Why the current shape cannot be wrapped, for the sidebar to show. "" when it can.
String wrapUnavailableReason() {
  if (perEdgeMode) return "Per-edge mode";
  if (cuboidMode)  return "Cuboid mode";
  if (hollowMode)  return "Hollow mode";
  if (kreslingMode) return "Kresling folds";
  if (nSides < 3)  return "Needs 3+ sides";
  return "";
}

// ---------------------------------------------------------------------------
// s - around the perimeter
// ---------------------------------------------------------------------------

// Panel boundaries in s: n+1 values from 0 to 1, so panel i spans [out[i], out[i+1]].
// THE single allocation - the flat pattern, the 3D wall and both caps all read this, which
// is what keeps them from disagreeing. Written to handle variable edge widths even though
// wrapFrameAvailable() currently refuses them, so per-edge support is a scope change here
// and not a rewrite.
float[] wrapPanelSpansS() {
  int n = max(3, nSides);
  boolean variable = (perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null;

  float[] w = new float[n];
  float sum = 0;
  for (int i = 0; i < n; i++) {
    float t = (variable && i < edgeTop_px.length) ? edgeTop_px[i] : cellTopL_px;
    float b = (variable && i < edgeBot_px.length) ? edgeBot_px[i] : cellBaseL_px;
    w[i] = 0.5 * (max(0.001, t) + max(0.001, b));
    sum += w[i];
  }
  if (sum <= 0) sum = 1;

  float[] out = new float[n + 1];
  float acc = 0;
  for (int i = 0; i < n; i++) {
    out[i] = acc / sum;
    acc += w[i];
  }
  out[n] = 1;
  return out;
}

// Total perimeter (px) under the same average-width measure s is allocated by.
float wrapPerimeterPx() {
  int n = max(3, nSides);
  boolean variable = (perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null;
  float sum = 0;
  for (int i = 0; i < n; i++) {
    float t = (variable && i < edgeTop_px.length) ? edgeTop_px[i] : cellTopL_px;
    float b = (variable && i < edgeBot_px.length) ? edgeBot_px[i] : cellBaseL_px;
    sum += 0.5 * (max(0.001, t) + max(0.001, b));
  }
  return sum;
}

// ---------------------------------------------------------------------------
// t - along the surface
// ---------------------------------------------------------------------------

// Total run of t, in px: bottom apothem + slant height + top apothem.
float wrapSurfaceRunPx() {
  return lidApothemPx(false) + cylinderH_px + lidApothemPx(true);
}

float wrapTBottomRim() {
  float run = wrapSurfaceRunPx();
  return run <= 0 ? 0 : lidApothemPx(false) / run;
}

float wrapTTopRim() {
  float run = wrapSurfaceRunPx();
  return run <= 0 ? 1 : (lidApothemPx(false) + cylinderH_px) / run;
}

// ---------------------------------------------------------------------------
// Projection into the image
// ---------------------------------------------------------------------------

// t -> vertical position in the image, as a 0..1 fraction. Top of the image is the top of
// the model; see IMAGE ORIENTATION above.
float wrapImgVFrac(float t) {
  return 1.0 - t;
}

// (s, t) -> IMAGE-mode texture coordinates for img.
PVector wrapUV(float s, float t, PImage img) {
  if (img == null) return new PVector(0, 0);
  return new PVector(s * img.width, wrapImgVFrac(t) * img.height);
}

// The source aspect that maps onto the surface without stretching: perimeter : surface run.
// Shown in the sidebar and used as the cropper's guide box.
float wrapIdealAspect() {
  float run = wrapSurfaceRunPx();
  return run <= 0 ? 1 : wrapPerimeterPx() / run;
}

// ---------------------------------------------------------------------------
// Cap geometry
// ---------------------------------------------------------------------------

// A lid's vertices (px) about its centroid, in the lid's own plane. Same phase as
// lidPolygonLocalMM(): edge i runs from vertex i to vertex i+1, and edge 0's midpoint sits
// at (0, -apothem), which is where drawPolygonLid() puts it. Getting this phase right is
// the whole game - the mesh has to sit on the outline it is printed inside.
PVector[] wrapCapVertsPx(boolean isTop) {
  int n = max(3, nSides);
  float r  = lidCircumradiusPx(isTop);
  float aI = TWO_PI / n;
  float a0 = -HALF_PI - aI / 2.0;
  PVector[] out = new PVector[n];
  for (int i = 0; i < n; i++) {
    float a = a0 + i * aI;
    out[i] = new PVector(cos(a) * r, sin(a) * r);
  }
  return out;
}
