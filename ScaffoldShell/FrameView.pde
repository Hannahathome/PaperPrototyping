// FRAMEVIEW.PDE - Drawing the internal support frame in the 3D preview
//
// Draws what buildFrameGeometry() produced, projected out of frame space into the sketch's
// own 3D space by frameToLocalPx(). It computes nothing -- if a strut looks wrong here, the
// bug is in Frame.pde and the exported .scad has it too. That is the point of the split.
//
// This hangs off drawShapeTree() in tools.pde, so a frame inside a shape that is itself
// connected to another shape is posed correctly for free: the parent's transform is still
// applied when the child's frame is drawn.

// Shown only in the 3D view's Scaffold style (View3DStyle.pde). It is drawn through the walls
// rather than depth-tested against them, the same treatment FrustumSupport gave its
// translucent reference boxes.

// Strut cylinders are drawn per segment, every frame, for every shape on screen. 8 sides
// reads as round at preview scale and costs half what FrustumSupport's 16 did.
final int FRAME_CYL_DETAIL = 8;

// Colours carried over from FrustumSupport, so the parts stay recognisable between tools.
final color FRAME_COL_VERTEX    = #E65A5A;
final color FRAME_COL_CAGE      = #DCDCDC;
final color FRAME_COL_SPOKE     = #82AAFF;
final color FRAME_COL_SPINE     = #F0BE6E;
final color FRAME_COL_POST      = #C3E88D;
final color FRAME_COL_BASELINK  = #F478BE;
final color FRAME_COL_BOX       = #8ABEB7;
final color FRAME_COL_BOX_SEL   = #FFD282;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

// Draws shape `idx`'s frame in the shape's own local space. The caller must already have
// loaded that shape's globals (drawShapeTree does), because the projection reads MM_current.
void drawFrameWireframe(PGraphics pg, int idx) {
  if (!scaffoldVisible3D()) return;
  if (shapes == null || idx < 0 || idx >= shapes.size()) return;

  ShapeSpec s = shapes.get(idx);
  if (s.frame == null || !s.frame.enabled) return;
  if (!frameAvailable(s)) return;

  FrameGeometry g = buildFrameGeometry(s);
  if (!g.valid) return;

  float rPx = g.strutRadius * MM_current;
  boolean isSelected = (idx == selectedShapeIdx);

  pg.hint(DISABLE_DEPTH_TEST);
  pg.noStroke();

  pg.fill(FRAME_COL_CAGE);
  for (PVector[] e : g.cageRing)       frameCylinder(pg, e[0], e[1], rPx);
  for (PVector[] e : g.cageWallStruts) frameCylinder(pg, e[0], e[1], rPx);

  pg.fill(FRAME_COL_VERTEX);
  for (PVector v : g.cageVertices) frameSphere(pg, v, rPx);

  pg.fill(FRAME_COL_SPOKE);
  for (PVector[] e : g.floorSpokes) frameCylinder(pg, e[0], e[1], rPx);

  pg.fill(FRAME_COL_SPINE);
  for (PVector[] e : g.rigSpines) frameCylinder(pg, e[0], e[1], rPx);

  pg.fill(FRAME_COL_POST);
  for (PVector[] e : g.rigPosts) {
    frameCylinder(pg, e[0], e[1], rPx);
    frameSphere(pg, e[0], rPx);
  }
  for (PVector[] e : g.rigBottomConnectors) frameCylinder(pg, e[0], e[1], rPx);

  pg.fill(FRAME_COL_BASELINK);
  for (PVector[] e : g.rigBaseLinks) frameCylinder(pg, e[0], e[1], rPx);

  drawFrameRigBoxes(pg, s, g, isSelected);

  pg.hint(ENABLE_DEPTH_TEST);
}

// Translucent component envelopes. The selected rig is highlighted, so the numbers in the
// Frame tab can be tied to a box on screen.
void drawFrameRigBoxes(PGraphics pg, ShapeSpec s, FrameGeometry g, boolean shapeIsSelected) {
  int selIdx = s.frame.selectedRigIdx;
  for (int i = 0; i < g.rigBoxes.size(); i++) {
    float[] b = g.rigBoxes.get(i);
    boolean hot = shapeIsSelected && i == selIdx;

    pg.fill(hot ? FRAME_COL_BOX_SEL : FRAME_COL_BOX, hot ? 80 : 60);
    pg.stroke(hot ? FRAME_COL_BOX_SEL : FRAME_COL_BOX, hot ? 220 : 160);
    pg.strokeWeight(0.5);

    PVector c = frameToLocalPx(new PVector(b[0], b[1], b[2]));
    pg.pushMatrix();
    pg.translate(c.x, c.y, c.z);
    // Yaw is about frame-space +z. That axis projects to the sketch's -y, so the sign flips.
    pg.rotateY(radians(-b[6]));
    // Sizes shift axis along with the projection: (w, d, h)_FS -> (w, h, d) here.
    pg.box(b[3] * MM_current, b[5] * MM_current, b[4] * MM_current);
    pg.popMatrix();
  }
  pg.noStroke();
}

// ---------------------------------------------------------------------------
// Primitives -- frame space in, sketch 3D space out
// ---------------------------------------------------------------------------

void frameSphere(PGraphics pg, PVector fsPos, float rPx) {
  PVector p = frameToLocalPx(fsPos);
  pg.pushMatrix();
  pg.translate(p.x, p.y, p.z);
  pg.sphereDetail(FRAME_CYL_DETAIL);
  pg.sphere(rPx);
  pg.popMatrix();
}

// A capped-off cylinder between two frame-space points. Same construction FrustumSupport
// used, rewritten to take a PGraphics -- the sketch renders 3D into an offscreen buffer
// (view3DBuffer / mini3DBuffer), never straight onto the surface.
void frameCylinder(PGraphics pg, PVector fsA, PVector fsB, float rPx) {
  PVector p1 = frameToLocalPx(fsA);
  PVector p2 = frameToLocalPx(fsB);
  PVector v = PVector.sub(p2, p1);
  float d = v.mag();
  if (d < 0.0001) return;

  float phi   = atan2(v.y, v.x);
  float theta = acos(constrain(v.z / d, -1, 1));

  pg.pushMatrix();
  pg.translate(p1.x, p1.y, p1.z);
  pg.rotateZ(phi);
  pg.rotateY(theta);
  pg.beginShape(QUAD_STRIP);
  for (int i = 0; i <= FRAME_CYL_DETAIL; i++) {
    float a = TWO_PI * i / FRAME_CYL_DETAIL;
    pg.vertex(rPx * cos(a), rPx * sin(a), 0);
    pg.vertex(rPx * cos(a), rPx * sin(a), d);
  }
  pg.endShape();
  pg.popMatrix();
}
