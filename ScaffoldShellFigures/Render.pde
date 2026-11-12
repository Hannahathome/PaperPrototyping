// RENDER.PDE - Drawing the three panels
//
// Geometry arrives in frame space (mm, z-up, right-handed -- OpenSCAD's space, see
// Geometry.pde) and is drawn in Processing's space, which is y-DOWN and therefore
// left-handed on screen. The mapping
//     (x, y, z)_FS -> (x, -z, -y)
// flips two axes, so the figure is the printed part as it really is, not its mirror image.
// (ScaffoldShell's preview uses (x, -z, y), which shows the mirror image: harmless on a
// symmetric cage, but it swaps the side of each wedge flap and the place of an off-centre
// rig. Checked against an OpenSCAD render of the same frame.)
//
// Lighting is ambient plus two directional lights (constants in ScaffoldShellFigures.pde),
// and the shell's faces carry explicit outward normals.
//
// Translucency: opaque parts first (struts), then translucent ones (component boxes, shell)
// with the depth MASK off, so a translucent face lets what is behind it show through instead
// of hiding it. Edges are drawn last as plain lines.
//
// k is the export scale; applyModelView() scales the geometry by it. Stroke weights are NOT
// multiplied by k: an off-screen P3D buffer already widens its lines with the export, so
// an exported figure keeps the on-screen proportions (measured: 1 px on screen -> ~3 px at 3x).

final int STRUT_DETAIL = 16;
final int SPHERE_DETAIL = 12;

void renderPanel(PGraphics pg, int kind, ShellGeometry sg, FrameGeometry fg, float k, boolean transparent) {
  pg.beginDraw();
  if (transparent) pg.clear(); else pg.background(CLR_PANEL);

  applyProjection(pg);
  // Lights in view space (before the orbit), so the lit side stays the side facing you.
  pg.ambientLight(LIGHT_AMBIENT, LIGHT_AMBIENT, LIGHT_AMBIENT);
  pg.directionalLight(LIGHT_KEY, LIGHT_KEY, LIGHT_KEY, 0.45, -0.1, -1);   // from front left, level: lids stay a step darker
  pg.directionalLight(LIGHT_FILL, LIGHT_FILL, LIGHT_FILL, -0.7, 0.2, -0.3);
  applyModelView(pg, k);
  pg.sphereDetail(SPHERE_DETAIL);

  if (kind == PANEL_SHELL) {
    drawShell(pg, sg, 255, k);   // opaque: the closed paper enclosure
  } else {
    if (fg.valid) {
      drawScaffold(pg, fg);
      if (showRigBoxes) drawRigBoxes(pg, fg, k);
    }
    if (kind == PANEL_ASSEMBLY) drawShell(pg, sg, overlayAlpha, k);
  }
  pg.endDraw();
}

// Panel letter, as in the paper's figures: a dark square tag with a white letter at the
// bottom left, sitting on a thin rule along the bottom of the panel. Used on screen and on
// the exported composite; (x, y, w, h) is the panel's rectangle in t.
void drawPanelLabel(PGraphics t, float x, float y, float w, float h, int i, float k) {
  float m    = 14 * k;               // margin from the panel edge
  float tag  = 20 * k;               // tag size
  float base = y + h - m;            // the rule, and the bottom of the tag
  t.pushStyle();
  t.stroke(CLR_TAG);
  t.strokeWeight(1 * k);
  t.line(x + m, base, x + w - m, base);
  t.noStroke();
  t.fill(CLR_TAG);
  t.rect(x + m, base - tag, tag, tag);
  t.fill(CLR_TAG_TEXT);
  t.textFont(fontLabel);
  t.textSize(14 * k);
  t.textAlign(CENTER, CENTER);
  t.text(PANEL_LETTERS[i], x + m + tag / 2, base - tag / 2 - 2 * k);
  t.popStyle();
}

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------

void drawShell(PGraphics pg, ShellGeometry s, float alpha, float k) {
  int n = s.n;
  boolean seeThrough = alpha < 255;

  pg.pushStyle();
  pg.noStroke();
  pg.fill(CLR_SHELL, alpha);
  if (seeThrough) pg.hint(DISABLE_DEPTH_MASK);

  pg.beginShape(QUADS);
  for (int i = 0; i < n; i++) {
    int j = (i + 1) % n;
    PVector nw = toP(wallNormalFS(s.bot[i], s.bot[j], s.top[i]));
    quadP(pg, toP(s.bot[i]), toP(s.bot[j]), toP(s.top[j]), toP(s.top[i]), nw, nw, nw, nw);
  }
  pg.endShape();

  if (showTopLid)    polygonP(pg, toP(s.top), new PVector(0, -1, 0));   // faces up
  if (showBottomLid) polygonP(pg, toP(s.bot), new PVector(0,  1, 0));   // faces down

  if (seeThrough) pg.hint(ENABLE_DEPTH_MASK);

  pg.noFill();
  pg.stroke(CLR_EDGE);
  pg.strokeWeight(edgeWeight);
  for (int i = 0; i < n; i++) {
    int j = (i + 1) % n;
    lineFS(pg, s.bot[i], s.bot[j]);
    lineFS(pg, s.top[i], s.top[j]);
    lineFS(pg, s.bot[i], s.top[i]);
  }
  pg.popStyle();
}

// Outward normal of the wall face spanned by a -> b (along the ring) and a -> c (up the wall),
// pointing away from the shell's axis. Frame space.
PVector wallNormalFS(PVector a, PVector b, PVector c) {
  PVector n = PVector.sub(b, a).cross(PVector.sub(c, a));
  PVector out = new PVector(a.x + b.x, a.y + b.y, 0);   // horizontal, away from the axis
  if (n.dot(out) < 0) n.mult(-1);
  return n.normalize();
}

// ---------------------------------------------------------------------------
// Scaffold
// ---------------------------------------------------------------------------

void drawScaffold(PGraphics pg, FrameGeometry g) {
  float r = g.strutRadius;
  pg.pushStyle();
  pg.noStroke();

  // Mirrors the OpenSCAD: plain cylinders with flat ends, spheres only where the .scad puts
  // them, and the wall struts as their trimmed, flat-topped solids (Geometry.pde).
  pg.fill(CLR_CAGE);
  closedStruts(pg, g.cageRing, r);
  for (StrutMesh m : g.wallStrutMeshes) drawStrutMesh(pg, m);
  for (PVector v : g.cageVertices) joint(pg, v, r);
  closedStruts(pg, g.floorSpokes, r);

  pg.fill(CLR_RIG);
  closedStruts(pg, g.rigSpines, r);
  closedStruts(pg, g.rigBaseLinks, r);
  closedStruts(pg, g.rigBottomConnectors, r);
  closedStruts(pg, g.rigPosts, r);
  for (PVector v : g.rigPostBases) joint(pg, v, r);

  pg.popStyle();
}

// OpenSCAD cylinder(): flat caps on both ends.
void closedStruts(PGraphics pg, ArrayList<PVector[]> segs, float r) {
  for (PVector[] e : segs) strut(pg, e[0], e[1], r);
}

// A wall strut: its round and cut surfaces, a cap at the foot, and the flat horizontal top.
void drawStrutMesh(PGraphics pg, StrutMesh m) {
  int nL = m.pts.length;
  int nS = m.pts[0].length;
  PVector[][] p = new PVector[nL][nS];
  PVector[][] n = new PVector[nL][nS];
  for (int j = 0; j < nL; j++) for (int s = 0; s < nS; s++) {
    p[j][s] = toP(m.pts[j][s]);
    n[j][s] = toP(m.nrm[j][s]);
  }

  pg.beginShape(QUADS);
  for (int j = 0; j < nL - 1; j++) {
    if (j == m.arcLines - 1) continue;           // seam between the round part and the cut
    for (int s = 0; s < nS - 1; s++) {
      quadP(pg, p[j][s], p[j + 1][s], p[j + 1][s + 1], p[j][s + 1],
                n[j][s], n[j + 1][s], n[j + 1][s + 1], n[j][s + 1]);
    }
  }
  pg.endShape();

  PVector[] foot = new PVector[nL], top = new PVector[nL];
  for (int j = 0; j < nL; j++) { foot[j] = p[j][0]; top[j] = p[j][nS - 1]; }
  polygonP(pg, foot, toP(m.bottomNormal));
  polygonP(pg, top, new PVector(0, -1, 0));      // trimmed top: flat and horizontal
}

// The component each rig carries, as a translucent box.
void drawRigBoxes(PGraphics pg, FrameGeometry g, float k) {
  pg.pushStyle();
  pg.fill(CLR_BOX, BOX_ALPHA);
  pg.stroke(CLR_ACCENT);
  pg.strokeWeight(edgeWeight * 0.75);
  pg.hint(DISABLE_DEPTH_MASK);
  for (float[] b : g.rigBoxes) {
    pg.pushMatrix();
    pg.translate(b[0], -b[2], -b[1]);
    pg.rotateY(radians(b[6]));      // yaw about FS z, through the (x, -z, -y) mapping
    pg.box(b[3], b[5], b[4]);       // FS (w, d, h) -> Processing (x, y, z) = (w, h, d)
    pg.popMatrix();
  }
  pg.hint(ENABLE_DEPTH_MASK);
  pg.popStyle();
}

// ---------------------------------------------------------------------------
// Primitives
// ---------------------------------------------------------------------------
//
// FACING. Processing's light shader decides front / back per face from the order of its
// corners, and lights a "back" face with its normal flipped -- so a face listed the wrong way
// round gets ambient light only. Because the frame-space mapping is a reflection, a face's
// corner order cannot be trusted to survive it. So every face goes through quadP() /
// polygonP(), which take Processing-space points plus the outward normal and list the
// corners in whichever order agrees with that normal. (Processing's own sphere() and box()
// are drawn under ordinary transforms and are unaffected.)

PVector toP(PVector fs) {
  return new PVector(fs.x, -fs.z, -fs.y);
}

PVector[] toP(PVector[] fs) {
  PVector[] out = new PVector[fs.length];
  for (int i = 0; i < fs.length; i++) out[i] = toP(fs[i]);
  return out;
}

void lineFS(PGraphics pg, PVector a, PVector b) {
  pg.line(a.x, -a.z, -a.y, b.x, -b.z, -b.y);
}

// Newell normal: the winding normal of a polygon, robust to collapsed corners.
PVector windingNormal(PVector[] q) {
  PVector w = new PVector();
  for (int i = 0; i < q.length; i++) {
    PVector a = q[i], b = q[(i + 1) % q.length];
    w.x += (a.y - b.y) * (a.z + b.z);
    w.y += (a.z - b.z) * (a.x + b.x);
    w.z += (a.x - b.x) * (a.y + b.y);
  }
  return w;
}

// One quad inside a beginShape(QUADS), corners ordered to agree with the normals.
void quadP(PGraphics pg, PVector a, PVector b, PVector c, PVector d,
           PVector na, PVector nb, PVector nc, PVector nd) {
  PVector nSum = PVector.add(PVector.add(na, nb), PVector.add(nc, nd));
  if (windingNormal(new PVector[]{ a, b, c, d }).dot(nSum) >= 0) {
    vertexN(pg, a, na); vertexN(pg, b, nb); vertexN(pg, c, nc); vertexN(pg, d, nd);
  } else {
    vertexN(pg, a, na); vertexN(pg, d, nd); vertexN(pg, c, nc); vertexN(pg, b, nb);
  }
}

// A flat convex polygon with one normal, corners ordered to agree with it.
void polygonP(PGraphics pg, PVector[] pts, PVector n) {
  boolean forward = windingNormal(pts).dot(n) >= 0;
  pg.beginShape();
  pg.normal(n.x, n.y, n.z);
  for (int i = 0; i < pts.length; i++) {
    PVector v = pts[forward ? i : pts.length - 1 - i];
    pg.vertex(v.x, v.y, v.z);
  }
  pg.endShape(CLOSE);
}

void vertexN(PGraphics pg, PVector v, PVector n) {
  pg.normal(n.x, n.y, n.z);
  pg.vertex(v.x, v.y, v.z);
}

void joint(PGraphics pg, PVector fs, float r) {
  PVector p = toP(fs);
  pg.pushMatrix();
  pg.translate(p.x, p.y, p.z);
  pg.sphere(r);
  pg.popMatrix();
}

// A closed cylinder of radius r from a to b, like OpenSCAD's cylinder(): flat at both ends.
void strut(PGraphics pg, PVector aFS, PVector bFS, float r) {
  PVector a = toP(aFS), b = toP(bFS);
  PVector dir = PVector.sub(b, a);
  float len = dir.mag();
  if (len < 1e-4) return;
  dir.div(len);

  PVector ref = abs(dir.y) < 0.99 ? new PVector(0, 1, 0) : new PVector(1, 0, 0);
  PVector u = dir.cross(ref).normalize();
  PVector v = dir.cross(u).normalize();

  PVector[] ring = new PVector[STRUT_DETAIL];
  for (int i = 0; i < STRUT_DETAIL; i++) {
    float t = TWO_PI * i / STRUT_DETAIL;
    ring[i] = PVector.add(PVector.mult(u, cos(t)), PVector.mult(v, sin(t)));
  }

  pg.beginShape(QUADS);
  for (int i = 0; i < STRUT_DETAIL; i++) {
    PVector n0 = ring[i], n1 = ring[(i + 1) % STRUT_DETAIL];
    quadP(pg, PVector.add(a, PVector.mult(n0, r)), PVector.add(a, PVector.mult(n1, r)),
              PVector.add(b, PVector.mult(n1, r)), PVector.add(b, PVector.mult(n0, r)),
              n0, n1, n1, n0);
  }
  pg.endShape();

  PVector[] capA = new PVector[STRUT_DETAIL], capB = new PVector[STRUT_DETAIL];
  for (int i = 0; i < STRUT_DETAIL; i++) {
    capA[i] = PVector.add(a, PVector.mult(ring[i], r));
    capB[i] = PVector.add(b, PVector.mult(ring[i], r));
  }
  polygonP(pg, capA, PVector.mult(dir, -1));
  polygonP(pg, capB, dir);
}
