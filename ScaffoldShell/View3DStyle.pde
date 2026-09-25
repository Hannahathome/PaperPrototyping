// VIEW3DSTYLE.PDE - What the 3D view shows: textured casing, scaffold, or wireframe
//
// Four looks, picked by the switch in the 3D view's bottom-right corner:
//
//   TEXTURED   the paper casing as it will look -- fills, strip, per-panel, wrap and lid
//              textures -- with each rig cutout shown as a dark opening. No scaffold.
//   OVERLAY    the textured casing with the scaffold drawn through it: the in-between view
//              the preview always had before the switch existed.
//   SCAFFOLD   the casing as plain see-through paper, with the rig cutouts (RigCutout.pde)
//              cut out of it as real holes, and the scaffold drawn inside. For checking a
//              component lines up with its window.
//   WIREFRAME  edges only, to see how the shapes sit together. Cutouts show as outlines.
//
// wireframeMode (Param.pde) is kept as the flag drawPrismWireframe() reads, and is only ever
// set through setView3DStyle(), so the two cannot disagree.

final int VIEW3D_TEXTURED  = 0;
final int VIEW3D_OVERLAY   = 1;
final int VIEW3D_SCAFFOLD  = 2;
final int VIEW3D_WIREFRAME = 3;
final int VIEW3D_STYLE_COUNT = 4;
String[] VIEW3D_STYLE_NAMES = { "Textured", "Overlay", "Scaffold", "Wireframe" };

int view3DStyle = VIEW3D_TEXTURED;

void setView3DStyle(int style) {
  view3DStyle   = constrain(style, 0, VIEW3D_STYLE_COUNT - 1);
  wireframeMode = (view3DStyle == VIEW3D_WIREFRAME);
  redraw();
}

boolean scaffoldVisible3D() {
  return view3DStyle == VIEW3D_SCAFFOLD || view3DStyle == VIEW3D_OVERLAY;
}

// ---------------------------------------------------------------------------
// The switch -- bottom right of the 3D view, just above the export bar
// ---------------------------------------------------------------------------

final float VIEW3D_STYLE_BTN_W = 90;
final float VIEW3D_STYLE_BTN_H = 28;

float[] get3DStyleBtnRect(int i) {
  float right = width - 10;
  float y = height - BOTTOM_EXPORT_HEIGHT - 10 - VIEW3D_STYLE_BTN_H;
  float x = right - VIEW3D_STYLE_COUNT * VIEW3D_STYLE_BTN_W + i * VIEW3D_STYLE_BTN_W;
  return new float[]{ x, y, VIEW3D_STYLE_BTN_W, VIEW3D_STYLE_BTN_H };
}

boolean mouseOver3DStyleSwitch() {
  for (int i = 0; i < VIEW3D_STYLE_COUNT; i++) {
    float[] r = get3DStyleBtnRect(i);
    if (mouseX >= r[0] && mouseX <= r[0] + r[2] && mouseY >= r[1] && mouseY <= r[1] + r[3]) return true;
  }
  return false;
}

// One segmented control: the buttons joined, the active one lit.
void draw3DStyleSwitch() {
  pushStyle();
  textAlign(CENTER, CENTER);
  uiText(12);
  int last = VIEW3D_STYLE_COUNT - 1;
  for (int i = 0; i < VIEW3D_STYLE_COUNT; i++) {
    float[] r = get3DStyleBtnRect(i);
    boolean on  = (view3DStyle == i);
    boolean hov = mouseX >= r[0] && mouseX <= r[0] + r[2] && mouseY >= r[1] && mouseY <= r[1] + r[3];
    fill(on ? color(80, 130, 200) : (hov ? color(60, 70, 100) : color(40, 50, 80)));
    noStroke();
    float rl = (i == 0) ? 5 : 0, rr = (i == last) ? 5 : 0;
    rect(r[0], r[1], r[2], r[3], rl, rr, rr, rl);
    if (i > 0) {
      stroke(25, 30, 55);
      strokeWeight(1);
      line(r[0], r[1] + 4, r[0], r[1] + r[3] - 4);
    }
    fill(255);
    text(VIEW3D_STYLE_NAMES[i], r[0] + r[2] / 2, r[1] + r[3] / 2);
  }

  // A scaffold view with nothing to show is otherwise indistinguishable from a bug.
  if (scaffoldVisible3D() && !anyScaffoldEnabled()) {
    float[] r = get3DStyleBtnRect(0);
    textAlign(LEFT, BOTTOM);
    uiText(11);
    fill(80);
    text("No scaffold yet: turn one on in the Scaffold tab", r[0], r[1] - 6);
  }
  popStyle();
}

boolean anyScaffoldEnabled() {
  if (shapes == null) return false;
  for (ShapeSpec s : shapes) if (s.frame != null && s.frame.enabled && frameAvailable(s)) return true;
  return false;
}

// Returns true when the click landed on the switch.
boolean handle3DStyleClick() {
  for (int i = 0; i < VIEW3D_STYLE_COUNT; i++) {
    float[] r = get3DStyleBtnRect(i);
    if (mouseX >= r[0] && mouseX <= r[0] + r[2] && mouseY >= r[1] && mouseY <= r[1] + r[3]) {
      setView3DStyle(i);
      return true;
    }
  }
  return false;
}

// Draws shape `idx`'s shell in the current style. Its globals must be loaded
// (drawShapeTree does). The scaffold itself is drawn by the caller, after this.
void drawShell3D(PGraphics pg, int idx) {
  if (view3DStyle == VIEW3D_SCAFFOLD) {
    drawCasing3D(pg, idx);
    return;
  }
  drawPrismWireframe(pg);
  drawCutoutMarks3D(pg, idx, view3DStyle != VIEW3D_WIREFRAME);
}

// ---------------------------------------------------------------------------
// Rig cutouts, as 3D quads on the shell
// ---------------------------------------------------------------------------

class CutoutHole3D {
  PVector[] quad;   // corners in the face's own u/v order
  int face;         // -1 = top lid, else the wall panel
  boolean fits;
}

// Every cutout of shape `idx` that actually cuts, placed on the shell through the same frames
// the flat pattern uses -- so the hole in the preview is the hole in the cut file.
ArrayList<CutoutHole3D> cutoutHoles3D(int idx, PVector[] botVerts, PVector[] topVerts) {
  ArrayList<CutoutHole3D> out = new ArrayList<CutoutHole3D>();
  if (shapes == null || idx < 0 || idx >= shapes.size()) return out;
  int n = min(topVerts.length, botVerts.length);
  for (RigCutoutPlan p : planRigCutouts(shapes.get(idx))) {
    if (!p.reaches) continue;
    PVector[] q = null;
    if (p.onLid) {
      if (lidFrameAvailable()) q = rigCutoutQuad3DOnLid(p);
    } else if (sidePanelFrameAvailable() && p.panel >= 0 && p.panel < n) {
      q = rigCutoutQuad3DOnPanel(p, sidePanelBasis3D(botVerts, topVerts, p.panel));
    }
    if (q == null) continue;
    CutoutHole3D h = new CutoutHole3D();
    h.quad = q;
    h.face = p.onLid ? -1 : p.panel;
    h.fits = p.fits;
    out.add(h);
  }
  return out;
}

void strokeCutout3D(PGraphics pg, CutoutHole3D h) {
  pg.stroke(h.fits ? color(0, 120, 255) : color(230, 60, 60));
  pg.strokeWeight(2);
}

void drawCutoutOutline3D(PGraphics pg, PVector[] q) {
  pg.beginShape();
  for (PVector v : q) pg.vertex(v.x, v.y, v.z);
  pg.endShape(CLOSE);
}

// The opaque styles cannot cut a hole into the textured faces -- those are drawn by half a
// dozen texture paths -- so the opening is painted on instead: dark, like looking into the
// box, lifted a hair off the face so it does not fight the texture for depth.
final color CUTOUT_OPENING_FILL = 0xFF2D3037;   // (45, 48, 55)
final float CUTOUT_LIFT_MM = 0.2;

void drawCutoutMarks3D(PGraphics pg, int idx, boolean filled) {
  PVector[] topVerts = getPolygonVertices(true);
  PVector[] botVerts = getPolygonVertices(false);
  if (topVerts == null || botVerts == null) return;
  ArrayList<CutoutHole3D> holes = cutoutHoles3D(idx, botVerts, topVerts);
  if (holes.isEmpty()) return;

  pg.pushStyle();
  for (CutoutHole3D h : holes) {
    PVector[] q = liftOffFace(h.quad, CUTOUT_LIFT_MM * MM_current);
    if (filled) pg.fill(CUTOUT_OPENING_FILL); else pg.noFill();
    strokeCutout3D(pg, h);
    drawCutoutOutline3D(pg, q);
  }
  pg.popStyle();
}

// The quad moved outward along its own normal. Outward is away from the shape's centre,
// which is the origin of its local space.
PVector[] liftOffFace(PVector[] q, float d) {
  PVector c = new PVector();
  for (PVector v : q) c.add(v);
  c.div(q.length);
  PVector nrm = PVector.sub(q[1], q[0]).cross(PVector.sub(q[3], q[0]));
  nrm.normalize();
  if (nrm.dot(c) < 0) nrm.mult(-1);
  PVector off = PVector.mult(nrm, d);
  PVector[] out = new PVector[q.length];
  for (int k = 0; k < q.length; k++) out[k] = PVector.add(q[k], off);
  return out;
}

// ---------------------------------------------------------------------------
// Scaffold view: the casing as see-through paper, with the rig cutouts as holes
// ---------------------------------------------------------------------------

final color CASING_FILL = 0x6EEBEEF5;   // (235, 238, 245) at alpha 110

// Hollow shapes show their outer skin only, which is what a rig cuts.
void drawCasing3D(PGraphics pg, int idx) {
  PVector[] topVerts = getPolygonVertices(true);
  PVector[] botVerts = getPolygonVertices(false);
  if (topVerts == null || botVerts == null) return;
  int n = min(topVerts.length, botVerts.length);
  if (n < 3) return;

  ArrayList<CutoutHole3D> holes = cutoutHoles3D(idx, botVerts, topVerts);

  pg.pushStyle();
  // Translucent faces are drawn without writing depth, so a far wall still shows through a
  // near one whatever order they come in. Edges and the scaffold are depth-tested as usual.
  pg.hint(DISABLE_DEPTH_MASK);
  pg.noStroke();
  pg.fill(CASING_FILL);

  for (int i = 0; i < n; i++) {
    int j = (i + 1) % n;
    pg.beginShape();
    pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
    pg.vertex(botVerts[j].x, botVerts[j].y, botVerts[j].z);
    pg.vertex(topVerts[j].x, topVerts[j].y, topVerts[j].z);
    pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
    casingHoleContours(pg, holes, i);
    pg.endShape(CLOSE);
  }

  pg.beginShape();
  for (int i = 0; i < n; i++) pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
  casingHoleContours(pg, holes, -1);
  pg.endShape(CLOSE);

  pg.beginShape();
  for (int i = n - 1; i >= 0; i--) pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
  pg.endShape(CLOSE);

  pg.hint(ENABLE_DEPTH_MASK);

  // Folds.
  pg.noFill();
  pg.stroke(60);
  pg.strokeWeight(1.5);
  pg.beginShape();
  for (int i = 0; i < n; i++) pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
  pg.endShape(CLOSE);
  pg.beginShape();
  for (int i = 0; i < n; i++) pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
  pg.endShape(CLOSE);
  for (int i = 0; i < n; i++) {
    pg.line(topVerts[i].x, topVerts[i].y, topVerts[i].z, botVerts[i].x, botVerts[i].y, botVerts[i].z);
  }

  // Cut edges, in the flat pattern's colours: blue, red where it crosses a fold.
  for (CutoutHole3D h : holes) {
    strokeCutout3D(pg, h);
    drawCutoutOutline3D(pg, h.quad);
  }
  pg.popStyle();
}

// Adds every hole on `face` to the shape being built, as contours. Wound the other way to the
// face (the corners are listed in the face's own u/v order, so reversing them is enough).
void casingHoleContours(PGraphics pg, ArrayList<CutoutHole3D> holes, int face) {
  for (CutoutHole3D h : holes) {
    if (h.face != face) continue;
    pg.beginContour();
    for (int k = h.quad.length - 1; k >= 0; k--) pg.vertex(h.quad[k].x, h.quad[k].y, h.quad[k].z);
    pg.endContour();
  }
}

PVector[] rigCutoutQuad3DOnLid(RigCutoutPlan p) {
  PVector[] out = new PVector[4];
  float rad = radians(p.rotDeg), c = cos(rad), sn = sin(rad), hs = p.sizeMM / 2;
  float[][] corners = { {-hs, -hs}, {hs, -hs}, {hs, hs}, {-hs, hs} };
  for (int k = 0; k < 4; k++) {
    float lx = corners[k][0], ly = corners[k][1];
    out[k] = lidLocalTo3D(new PVector(p.localMM.x + lx * c - ly * sn,
                                      p.localMM.y + lx * sn + ly * c), true);
  }
  return out;
}

PVector[] rigCutoutQuad3DOnPanel(RigCutoutPlan p, SidePanelBasis b) {
  if (b == null) return null;
  float hs = p.sizeMM / 2;
  float[][] corners = { {-hs, -hs}, {hs, -hs}, {hs, hs}, {-hs, hs} };
  PVector[] out = new PVector[4];
  for (int k = 0; k < 4; k++) {
    out[k] = sidePanelLocalTo3D(b, new PVector(p.localMM.x + corners[k][0],
                                               p.localMM.y + corners[k][1]));
  }
  return out;
}
