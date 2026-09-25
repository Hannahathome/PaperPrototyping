// LIDFRAME.PDE - Canonical lid coordinate frame
//
// One frame, two projections. Everything that places something ON a lid -- in the flat
// pattern or in the 3D preview -- goes through here, so the two can never drift apart.
//
// Lid-local ("LF") coordinates are millimetres, origin at the polygon CENTROID:
//   +u = right on the printed page
//   +v = down on the printed page
// measured BEFORE the lid's own rotation (uiTopLidRotation / uiBotLidRotation) is applied.
// Edge 0's midpoint therefore sits at (0, -apothem), matching drawPolygonLid() in api.pde.
//
// Why this frame is safe to share with the 3D view:
//   drawPolygonLid() places edge i by rotate(i*angleIncrement) then translate(0,-apothem),
//   so edge 0's midpoint is at (0, -apothem) in the piece's (x, y-down).
//   getPolygonVertices() in tools.pde instead walks vertex-to-vertex from the origin along
//   +x, turning by TWO_PI/n, then re-centres on the centroid. Those look like different
//   conventions but they land on the same rotational phase: for n=4, L=1 that walk gives
//   vertices (0,0),(1,0),(1,1),(0,1), centroid (0.5,0.5), so edge 0's midpoint is
//   (0.5,0) - (0.5,0.5) = (0, -apothem) in (x, z). Edge 1 agrees too: 2D gives
//   (apothem*sin(aI), -apothem*cos(aI)) = (0.5, 0), 3D gives (1,0.5)-(0.5,0.5) = (0.5, 0).
//   So u -> x and v -> z is an exact match for the TOP face, with no phase constant.
//
// The BOTTOM face is mirrored (v -> -z). That is not a fudge: a bottom lid is flipped over
// when it is folded onto the form, so the printed piece presents its mirror image to the
// outside world. Slit rings drawn on a bottom lid are mirrored to match (see Connection.pde).
//
// Scope (v1): uniform regular polygons only -- the same scope BasePlate.pde took for its
// mounting slits. perEdgeMode / cuboidMode / hollowMode lids are rejected by
// lidFrameAvailable() rather than silently mis-placed.

// ---------------------------------------------------------------------------
// Availability
// ---------------------------------------------------------------------------

// True when the CURRENT globals describe a lid this frame can address.
boolean lidFrameAvailable() {
  return !perEdgeMode && !cuboidMode && !hollowMode && nSides >= 3;
}

// Same test against a ShapeSpec, for callers that have not loaded its globals.
boolean lidFrameAvailable(ShapeSpec s) {
  if (s == null) return false;
  return !s.perEdgeMode && !s.cuboidMode && !s.hollowMode && s.nSides >= 3;
}

// ---------------------------------------------------------------------------
// Polygon metrics (current globals, current scale)
// ---------------------------------------------------------------------------

float lidEdgePx(boolean isTop) {
  return isTop ? cellTopL_px : cellBaseL_px;
}

float lidApothemPx(boolean isTop) {
  return (lidEdgePx(isTop) / 2.0) / tan(PI / (float)max(3, nSides));
}

float lidCircumradiusPx(boolean isTop) {
  return (lidEdgePx(isTop) / 2.0) / sin(PI / (float)max(3, nSides));
}

// Offset (px) from the lid piece's top-left corner to the polygon CENTROID.
// Mirrors the translate(rectWidth/2, rectWidth/2) at the top of drawPolygonLid() exactly.
// Note this is the centroid, NOT the bounding-box centre that getPolygonLidDimensions()
// implies -- the two differ for odd-sided polygons, where the bbox is not centred on the
// polygon. (getTopLidCenterMM() in Cutout.pde uses the bbox centre and is therefore
// slightly off for triangles; this function is the one to trust.)
PVector lidCentroidInPiecePx(boolean isTop) {
  float half = lidApothemPx(isTop) + tabDepth_px;
  return new PVector(half, half);
}

// ---------------------------------------------------------------------------
// Projections out of the canonical frame
// ---------------------------------------------------------------------------

// LF mm -> offset (px) from the lid piece's top-left corner.
// Call this inside the lid's own matrix in drawPlan(), where the origin is the piece
// corner and the lid's rotation has already been applied by the surrounding pushMatrix.
PVector lidLocalToPiecePx(PVector localMM, boolean isTop) {
  PVector c = lidCentroidInPiecePx(isTop);
  return new PVector(c.x + localMM.x * MM_current,
                     c.y + localMM.y * MM_current);
}

// LF mm -> a point on that face, in the shape's own local 3D frame (px).
// P3D is y-down, so the top face sits at -halfH. See the header for why v maps straight
// to z on the top face and to -z on the (flipped) bottom face.
PVector lidLocalTo3D(PVector localMM, boolean isTop) {
  float halfH = cylinderVertH_px / 2.0;
  float u = localMM.x * MM_current;
  float v = localMM.y * MM_current;
  if (isTop) return new PVector(u, -halfH,  v);
  else       return new PVector(u,  halfH, -v);
}

// The lid polygon's own vertices, in LF mm. Vertex angles match getPolygonLidDimensions().
PVector[] lidPolygonLocalMM(boolean isTop) {
  int n = max(3, nSides);
  float r  = lidCircumradiusPx(isTop) / MM_current;
  float aI = TWO_PI / n;
  float startAngle = -HALF_PI - aI / 2.0;
  PVector[] out = new PVector[n];
  for (int i = 0; i < n; i++) {
    float a = startAngle + i * aI;
    out[i] = new PVector(cos(a) * r, sin(a) * r);
  }
  return out;
}

// A regular n-gon's vertices in mm about its own centroid, for a given edge length (mm).
// Same phase as lidPolygonLocalMM(), so a child footprint can be tested against a parent lid.
PVector[] regularPolygonMM(int n, float edgeMM, float spinDeg) {
  n = max(3, n);
  float r  = (edgeMM / 2.0) / sin(PI / (float)n);
  float aI = TWO_PI / n;
  float startAngle = -HALF_PI - aI / 2.0 + radians(spinDeg);
  PVector[] out = new PVector[n];
  for (int i = 0; i < n; i++) {
    float a = startAngle + i * aI;
    out[i] = new PVector(cos(a) * r, sin(a) * r);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

// Standard ray-cast point-in-polygon test.
boolean pointInPoly(PVector[] poly, float x, float y) {
  if (poly == null || poly.length < 3) return false;
  boolean inside = false;
  for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    if (((poly[i].y > y) != (poly[j].y > y)) &&
        (x < (poly[j].x - poly[i].x) * (y - poly[i].y) / (poly[j].y - poly[i].y) + poly[i].x)) {
      inside = !inside;
    }
  }
  return inside;
}

// Point-in-polygon against a polygon given as parallel screen-coordinate arrays.
boolean pointInPolyXY(float[] px, float[] py, float x, float y) {
  if (px == null || px.length < 3) return false;
  boolean inside = false;
  for (int i = 0, j = px.length - 1; i < px.length; j = i++) {
    if (((py[i] > y) != (py[j] > y)) &&
        (x < (px[j] - px[i]) * (y - py[i]) / (py[j] - py[i]) + px[i])) {
      inside = !inside;
    }
  }
  return inside;
}
