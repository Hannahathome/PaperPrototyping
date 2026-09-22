// SIDEPANELFRAME.PDE - Canonical side-panel coordinate frame
//
// What LidFrame.pde is to a lid, this is to one panel of the side strip: one frame, two
// projections (flat pattern and 3D preview), so a child mounted on a wall lands in the same
// place in the cut file as it does in the picture.
//
// Side-panel-local ("SF") coordinates are millimetres, origin at the MIDPOINT OF THE PANEL'S
// MEDIAN LINE:
//   +u = along the median, in the strip-walk direction (vertex i -> vertex i+1)
//   +v = along the axis of symmetry, toward the prism's TOP edge
// which on the printed page is +x to the right and +y downward, matching LidFrame's
// convention (the strip is drawn with the prism's BOTTOM edge at y = 0 and its TOP edge at
// y = h, so "toward the top of the prism" really is down the page).
//
// Why the two projections agree:
//   drawTrapezoids() walks the strip by translate(bottomLen, 0) then rotate(rotationNeeded);
//   getPolygonVertices() walks the 3D polygon from the origin along +x turning TWO_PI/n in
//   (x, z). Both walk the same polygon in the same order, so panel i is the SAME isosceles
//   trapezoid in both. Two exact consequences follow:
//
//   1. FLAT. With cols = 2 the vertical subdivision m = 1, so a panel is a single trapezoid
//      with corners BL(0,0), BR(bottomLen,0), TR(offset+topLen,h), TL(offset,h) where
//      offset = (bottomLen-topLen)/2. Its median midpoint is
//        x = ((0+bottomLen)/2 + (offset + offset+topLen)/2) / 2 = bottomLen/2
//      exactly -- the offset cancels -- and y = h/2. So the flat projection is a plain
//      translate with no rotation term (see sidePanelLocalToPanelPx).
//
//   2. 3D. The panel is isosceles, so its median direction and its axis of symmetry are
//      perpendicular: (u, v) is an orthonormal frame in the panel's plane, and the outward
//      normal is exactly u x v. That cross product also reproduces the two lid cases --
//      top lid (u,v,n) = (x, z, -y) and bottom lid (x, -z, +y) -- which is why one shared
//      pose matrix can serve lids and side panels alike (see applyFaceTransform3D).
//
// FRUSTUMS. Param.pde derives the panel's drawn height as
//   cylinderH_px = sqrt(cylinderVertH_px^2 + (cellBaseL_px - cellTopL_px)^2)
// using the EDGE-length difference where the true unrolled slant needs the APOTHEM
// difference, (b-t)/(2*tan(PI/n)). The flat panel is therefore slightly taller than the 3D
// panel it folds into. That is pre-existing and affects lid connections too, so this file
// does not "fix" it (that would silently change every frustum already cut). Instead the cut
// file stays authoritative -- v is exact millimetres in the flat pattern -- and the 3D
// projection maps v as a FRACTION of the panel's real slant, so the preview stays honest.
// For a right prism (top perimeter == bottom perimeter) the two are identical.
//
// Scope (v1): uniform regular prisms and frustums, matching lidFrameAvailable(). Per-edge,
// cuboid, hollow and kresling strips are refused by sidePanelFrameAvailable() rather than
// mis-placed -- kresling because drawPlan() shears the whole strip, which would shear a
// slit ring without shearing the child that pushes through it.

// ---------------------------------------------------------------------------
// Availability
// ---------------------------------------------------------------------------

// True when the CURRENT globals describe a side strip this frame can address.
boolean sidePanelFrameAvailable() {
  return !perEdgeMode && !cuboidMode && !hollowMode && !kreslingMode && nSides >= 3;
}

// Same test against a ShapeSpec, for callers that have not loaded its globals.
// kreslingMode is a sketch-wide global rather than per-shape, so it is read directly.
boolean sidePanelFrameAvailable(ShapeSpec s) {
  if (s == null) return false;
  return !s.perEdgeMode && !s.cuboidMode && !s.hollowMode && !kreslingMode && s.nSides >= 3;
}

// ---------------------------------------------------------------------------
// Panel metrics (current globals, current scale)
// ---------------------------------------------------------------------------

int sidePanelCount() {
  return max(3, nSides);
}

// The panel's two parallel edges, as drawn flat. Bottom = the prism's bottom lid edge.
float sidePanelBottomEdgePx() { return cellBaseL_px; }
float sidePanelTopEdgePx()    { return cellTopL_px;  }

// Panel height as DRAWN FLAT (the slant height). See the header note on frustums.
float sidePanelHeightPx() { return cylinderH_px; }

// Length of the median line -- the panel's width at half height, and the widest useful
// measure for centring something on it.
float sidePanelMedianPx() {
  return (sidePanelBottomEdgePx() + sidePanelTopEdgePx()) / 2.0;
}

// ---------------------------------------------------------------------------
// Projection 1: the flat pattern
// ---------------------------------------------------------------------------

// SF mm -> offset (px) from the PANEL's own origin, which is the panel's bottom-left corner
// -- exactly where the strip walk in drawTrapezoids() leaves the matrix for that panel.
// Call this inside that walk (see drawConnectionSlitsOnPanels_Range in Connection.pde).
PVector sidePanelLocalToPanelPx(PVector localMM) {
  return new PVector(sidePanelBottomEdgePx() / 2.0 + localMM.x * MM_current,
                     sidePanelHeightPx()     / 2.0 + localMM.y * MM_current);
}

// The panel outline in SF mm. Same winding as lidPolygonLocalMM(), so pointInPoly() works
// on it unchanged.
PVector[] sidePanelPolygonLocalMM() {
  float b = sidePanelBottomEdgePx() / 2.0 / MM_current;
  float t = sidePanelTopEdgePx()    / 2.0 / MM_current;
  float h = sidePanelHeightPx()     / 2.0 / MM_current;
  return new PVector[] {
    new PVector(-b, -h), new PVector(b, -h), new PVector(t, h), new PVector(-t, h)
  };
}

// The panel outline inset by a clearance, in SF mm. Unlike a lid, ALL FOUR of a side
// panel's boundaries are fold lines: a slit ring that reaches one ruins the fold, so the
// fit test uses this rather than the raw outline.
PVector[] sidePanelPolygonLocalMM(float clearanceMM) {
  float b = sidePanelBottomEdgePx() / 2.0 / MM_current - clearanceMM;
  float t = sidePanelTopEdgePx()    / 2.0 / MM_current - clearanceMM;
  float h = sidePanelHeightPx()     / 2.0 / MM_current - clearanceMM;
  b = max(b, 0.01);
  t = max(t, 0.01);
  h = max(h, 0.01);
  return new PVector[] {
    new PVector(-b, -h), new PVector(b, -h), new PVector(t, h), new PVector(-t, h)
  };
}

// ---------------------------------------------------------------------------
// Where each panel lands on the page
// ---------------------------------------------------------------------------
//
// drawTrapezoids() places panel i by an accumulated translate/rotate walk, so a panel's
// frame is not something a caller can compute from the panel index alone. This replays that
// exact walk in pure arithmetic (the same trick computeStripCorners_Uniform() uses for the
// strip texture) and hands back, for every panel, where SF (0,0) landed and how far the
// panel is turned.
//
// ONE source for two jobs: the slit pass draws through these poses, and the flat-pattern
// drag picks through them. Sharing them is what guarantees the ring you grab is the ring
// that gets cut.
//
// Coordinates are px in the shape's own pattern space -- the origin drawPlan() has when it
// starts the strip. Like getTopLidCenterMM(), this assumes the plain single-copy case; extra
// repetitions and free-placement offsets are applied by the caller's matrix, not here.

class SidePanelPose {
  int index;         // panel index
  PVector originPx;  // where SF (0,0) landed
  float rotRad;      // how far the panel is turned on the page
}

// Angle drawTrapezoids() turns through between one panel and the next.
float sidePanelStepRad(float topLen, float bottomLen, float h) {
  PVector aRight = new PVector((topLen - bottomLen) / 2.0, h);
  PVector bLeft  = new PVector((bottomLen - topLen) / 2.0, h);
  return atan2(aRight.y, aRight.x) - atan2(bLeft.y, bLeft.x);
}

// Walks panels [panelStart, panelEnd) from a strip origin, filling into out[].
void _fillSidePanelPoses(SidePanelPose[] out, int panelStart, int panelEnd,
                         float topLen, float bottomLen, float h,
                         float originX, float originY, float originRot) {
  Affine T = new Affine();
  T.translate(originX, originY);
  T.rotate(originRot);
  float step = sidePanelStepRad(topLen, bottomLen, h);
  int nPanels = panelEnd - panelStart;
  for (int count = 0; count < nPanels; count++) {
    SidePanelPose p = new SidePanelPose();
    p.index    = panelStart + count;
    p.originPx = T.apply(bottomLen / 2.0, h / 2.0);
    p.rotRad   = atan2(T.s, T.c);
    out[p.index] = p;
    if (count < nPanels - 1) {
      T.translate(bottomLen, 0);
      T.rotate(step);
    }
  }
}

// Every panel's pose, split strip included. Index i of the result is panel i.
SidePanelPose[] sidePanelPosesPx() {
  int n = sidePanelCount();
  SidePanelPose[] out = new SidePanelPose[n];
  float topLen = sidePanelTopEdgePx();
  float botLen = sidePanelBottomEdgePx();
  float h      = sidePanelHeightPx();

  boolean split = splitStrip && n >= 4;
  if (!split) {
    _fillSidePanelPoses(out, 0, n, topLen, botLen, h, 0, 0, 0);
    return out;
  }

  // Split strip: each half restarts the walk at its own origin, exactly as the two
  // drawTrapezoids_Range() blocks in drawPlan() do.
  int splitAt = (int)ceil(n / 2.0);
  float splitSpacing = getStripHeight() + tabDepth_px * 2 + 10 * MM_current;
  _fillSidePanelPoses(out, 0, splitAt, topLen, botLen, h,
                      uiSplitHalf1OffsetX * MM_current,
                      uiSplitHalf1OffsetY * MM_current,
                      radians(uiSplitHalf1Rotation));
  _fillSidePanelPoses(out, splitAt, n, topLen, botLen, h,
                      uiSplitHalf2OffsetX * MM_current,
                      splitSpacing + uiSplitHalf2OffsetY * MM_current,
                      radians(uiSplitHalf2Rotation));
  return out;
}

// SF mm on panel `pose` -> mm in the shape's pattern space. The inverse of what the flat
// drag needs, and the forward map the pick test compares against.
PVector sidePanelLocalToPatternMM(SidePanelPose pose, PVector localMM) {
  if (pose == null) return new PVector(0, 0);
  float cs = cos(pose.rotRad), sn = sin(pose.rotRad);
  return new PVector(pose.originPx.x / MM_current + localMM.x * cs - localMM.y * sn,
                     pose.originPx.y / MM_current + localMM.x * sn + localMM.y * cs);
}

// mm in the shape's pattern space -> SF mm on panel `pose`.
PVector sidePanelPatternToLocalMM(SidePanelPose pose, float xMM, float yMM) {
  if (pose == null) return new PVector(0, 0);
  float dx = xMM - pose.originPx.x / MM_current;
  float dy = yMM - pose.originPx.y / MM_current;
  float cs = cos(-pose.rotRad), sn = sin(-pose.rotRad);
  return new PVector(dx * cs - dy * sn, dx * sn + dy * cs);
}

// ---------------------------------------------------------------------------
// Projection 2: the 3D preview
// ---------------------------------------------------------------------------

// One panel's frame in the shape's own local 3D space (px). Axes are unit vectors; the two
// lengths are kept because the 3D panel and the flat panel can differ slightly on a frustum
// (see the header).
class SidePanelBasis {
  PVector c;        // median midpoint -- SF (0,0)
  PVector u, v, n;  // unit axes: along the median, up the panel, outward
  float medianPx;   // full median length
  float slantPx;    // full slant height, as the 3D solid actually has it
  PVector[] quad;   // the panel corners, in B0 B1 T1 T0 order
}

// Builds panel i's frame from polygon vertices the caller already has, so a loop over every
// panel does not rebuild them n times.
SidePanelBasis sidePanelBasis3D(PVector[] botVerts, PVector[] topVerts, int i) {
  if (botVerts == null || topVerts == null) return null;
  int n = min(botVerts.length, topVerts.length);
  if (n < 3) return null;
  // Fail rather than wrap: a connection left pointing at a panel that no longer exists
  // (the shape was given fewer sides) must disappear, not silently move to another wall.
  if (i < 0 || i >= n) return null;
  int j = (i + 1) % n;

  PVector B0 = botVerts[i], B1 = botVerts[j];
  PVector T0 = topVerts[i], T1 = topVerts[j];

  SidePanelBasis b = new SidePanelBasis();
  b.c = new PVector((B0.x + B1.x + T0.x + T1.x) / 4.0,
                    (B0.y + B1.y + T0.y + T1.y) / 4.0,
                    (B0.z + B1.z + T0.z + T1.z) / 4.0);

  // median: midpoint of the left slant edge -> midpoint of the right slant edge
  PVector mL = new PVector((B0.x + T0.x) / 2.0, (B0.y + T0.y) / 2.0, (B0.z + T0.z) / 2.0);
  PVector mR = new PVector((B1.x + T1.x) / 2.0, (B1.y + T1.y) / 2.0, (B1.z + T1.z) / 2.0);
  b.u = PVector.sub(mR, mL);
  b.medianPx = b.u.mag();

  // axis: midpoint of the bottom edge -> midpoint of the top edge
  PVector mB = new PVector((B0.x + B1.x) / 2.0, (B0.y + B1.y) / 2.0, (B0.z + B1.z) / 2.0);
  PVector mT = new PVector((T0.x + T1.x) / 2.0, (T0.y + T1.y) / 2.0, (T0.z + T1.z) / 2.0);
  b.v = PVector.sub(mT, mB);
  b.slantPx = b.v.mag();

  if (b.medianPx < 1e-4 || b.slantPx < 1e-4) return null;
  b.u.normalize();
  b.v.normalize();
  // The panel is isosceles, so u and v are already perpendicular and this is the OUTWARD
  // normal. See the header: the same u x v rule reproduces both lid cases.
  b.n = b.u.cross(b.v);
  b.n.normalize();

  b.quad = new PVector[] { B0.copy(), B1.copy(), T1.copy(), T0.copy() };
  return b;
}

SidePanelBasis sidePanelBasis3D(int i) {
  return sidePanelBasis3D(getPolygonVertices(false), getPolygonVertices(true), i);
}

// How much of a millimetre of SF v is worth in the 3D preview. The flat panel is drawn
// cylinderH_px tall; the 3D panel's real slant may differ slightly on a frustum, so v is
// carried across as a fraction of the panel's height rather than as raw length. 1.0 for a
// right prism.
float sidePanelVScale3D(SidePanelBasis b) {
  if (b == null || cylinderH_px <= 0) return 1.0;
  return b.slantPx / cylinderH_px;
}

// SF mm -> a point on that panel, in the shape's own local 3D frame (px).
PVector sidePanelLocalTo3D(SidePanelBasis b, PVector localMM) {
  if (b == null) return new PVector(0, 0, 0);
  float du = localMM.x * MM_current;
  float dv = localMM.y * MM_current * sidePanelVScale3D(b);
  return new PVector(b.c.x + b.u.x * du + b.v.x * dv,
                     b.c.y + b.u.y * du + b.v.y * dv,
                     b.c.z + b.u.z * du + b.v.z * dv);
}
