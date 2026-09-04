// CONNECTION.PDE - Attaching one shape to a face of another
//
// A Connection says "shape C stands on face F of shape P, at this spot, at this angle".
// It does two things:
//   1. In the 3D preview, the child is posed on the parent's face (see drawShapeTree in
//      tools.pde) so you can see and drag the assembly.
//   2. In the flat pattern, a ring of tab-through slits is cut into the parent's lid at
//      the matching spot, so the child's bottom-lid tabs push through and lock -- exactly
//      the mechanism BasePlate.pde already uses to mount a form on a base plate. The slit
//      drawing IS drawBaseSlits(); this file only positions it.
//
// Both live in one canonical coordinate frame -- see LidFrame.pde. Positions are stored in
// that frame (mm from the lid's centroid), never as screen or page coordinates, so they
// survive resizing, re-placement and rotation of either shape.
//
// Connections are a RELATION between shapes, so they are held in one global list rather
// than inside ShapeSpec: saveGlobalsTo/loadGlobalsFrom copy scalars, so storing a
// connection on both ends would let the two copies drift apart.
//
// Scope (v1): uniform regular polygons, top and bottom lids. Guarded by lidFrameAvailable().

class Connection {
  int parentShapeIdx;       // index into shapes -- the shape that gets the slits cut into it
  int childShapeIdx;        // index into shapes -- the shape that stands on the face
  boolean parentFaceIsTop;  // which lid of the parent hosts it
  boolean childFlipped;     // false = the child's BOTTOM lid does the attaching (default)
  PVector posLocal;         // mm in the parent's canonical lid frame (see LidFrame.pde)
  float spinDeg;            // child's rotation about the face normal

  Connection(int _parent, int _child, boolean _isTop, PVector _pos) {
    parentShapeIdx  = _parent;
    childShapeIdx   = _child;
    parentFaceIsTop = _isTop;
    childFlipped    = false;
    posLocal        = _pos.copy();
    spinDeg         = 0;
  }
}

ArrayList<Connection> connections = new ArrayList<Connection>();
int selectedConnectionIdx = -1;   // -1 = none selected
boolean connectMode = false;      // 3D view: clicks attach/drag instead of orbiting

// --- Face selection -------------------------------------------------------
// A clicked face stays highlighted until it is clicked again. The toggle is resolved on
// RELEASE rather than press, so that pressing a selected face and dragging still moves the
// connection — only a click that does not move deselects.
int selectedFaceShapeIdx = -1;          // -1 = no face selected
boolean selectedFaceIsTop = true;
boolean _facePressWasSelected = false;  // was the pressed face already selected?
boolean _connDragMoved = false;         // did the pointer move between press and release?

boolean isFaceSelected(int shapeIdx, boolean isTop) {
  return selectedFaceShapeIdx == shapeIdx && selectedFaceIsTop == isTop;
}

void selectFace(int shapeIdx, boolean isTop) {
  selectedFaceShapeIdx = shapeIdx;
  selectedFaceIsTop    = isTop;
}

// Clears the highlight only. Any connection on the face is left in place — deselecting is
// a viewing action, not a destructive one; Del is what removes a connection.
void clearFaceSelection() {
  selectedFaceShapeIdx  = -1;
  selectedConnectionIdx = -1;
}

// Index of the shape drawPlan() is currently rendering. drawPlan() reads globals rather
// than taking the shape as an argument, so the slit code needs this to know whose lid it
// is drawing. Set by every loop that calls drawPlan(): draw(), drawFrontPDF(), saveFrontFold().
int _drawingShapeIdx = -1;

final int CONNECTION_MAX_DEPTH = 8;  // recursion guard for chains of connected shapes

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

ArrayList<Connection> childrenOf(int parentIdx) {
  ArrayList<Connection> out = new ArrayList<Connection>();
  if (connections == null) return out;
  for (Connection c : connections) {
    if (c.parentShapeIdx == parentIdx) out.add(c);
  }
  return out;
}

// The connection that attaches this shape to a parent, or null if it is a root.
Connection parentOf(int childIdx) {
  if (connections == null) return null;
  for (Connection c : connections) {
    if (c.childShapeIdx == childIdx) return c;
  }
  return null;
}

boolean isRootShape(int idx) {
  return parentOf(idx) == null;
}

// Walk up to the topmost ancestor, so "show selected" can display the whole assembly the
// selected shape belongs to. Depth-guarded in case a cycle ever slips in.
int rootAncestorOf(int idx) {
  int cur = idx;
  for (int guard = 0; guard < CONNECTION_MAX_DEPTH; guard++) {
    Connection p = parentOf(cur);
    if (p == null) return cur;
    cur = p.parentShapeIdx;
  }
  return cur;
}

// Would attaching child to parent create a cycle (or a second parent for the child)?
boolean wouldCycle(int parentIdx, int childIdx) {
  if (parentIdx == childIdx) return true;
  if (parentOf(childIdx) != null) return true;   // a shape may only hang off one parent
  int cur = parentIdx;
  for (int guard = 0; guard < CONNECTION_MAX_DEPTH; guard++) {
    Connection p = parentOf(cur);
    if (p == null) return false;
    if (p.parentShapeIdx == childIdx) return true;
    cur = p.parentShapeIdx;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Child footprint
// ---------------------------------------------------------------------------

// Edge length (mm) of the child lid that mates with the parent's face.
float childMateEdgeMM(Connection c) {
  if (shapes == null || c.childShapeIdx < 0 || c.childShapeIdx >= shapes.size()) return 0;
  ShapeSpec ch = shapes.get(c.childShapeIdx);
  int n = max(3, ch.nSides);
  // cylinder.x = top perimeter, cylinder.y = bottom perimeter
  float perim = c.childFlipped ? ch.cylinder.x : ch.cylinder.y;
  return perim / (float)n;
}

int childMateSides(Connection c) {
  if (shapes == null || c.childShapeIdx < 0 || c.childShapeIdx >= shapes.size()) return 3;
  return max(3, shapes.get(c.childShapeIdx).nSides);
}

// Does the child's footprint sit entirely inside the parent's lid face?
// A slit ring that crosses the lid outline destroys the piece, so this drives a warning
// and a red preview. Requires the PARENT's globals to be loaded.
boolean connectionFits(Connection c) {
  if (!lidFrameAvailable()) return false;
  PVector[] lid   = lidPolygonLocalMM(c.parentFaceIsTop);
  PVector[] child = regularPolygonMM(childMateSides(c), childMateEdgeMM(c), c.spinDeg);
  for (PVector v : child) {
    if (!pointInPoly(lid, c.posLocal.x + v.x, c.posLocal.y + v.y)) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Centre snapping
// ---------------------------------------------------------------------------
// A child mounted dead-centre is by far the common case, so a new connection lands there
// and a drag is pulled back to it. The radius scales with the host lid (a fixed mm radius
// would be unmissable on a small lid and invisible on a large one).

final float CONNECTION_SNAP_FRACTION = 0.20;  // of the host lid's apothem
final float CONNECTION_SNAP_MIN_MM   = 2.5;

float connectionSnapRadiusMM(int parentShapeIdx, boolean isTop) {
  if (shapes == null || parentShapeIdx < 0 || parentShapeIdx >= shapes.size()) return CONNECTION_SNAP_MIN_MM;
  ShapeSpec p = shapes.get(parentShapeIdx);
  int n = max(3, p.nSides);
  float perim = isTop ? p.cylinder.x : p.cylinder.y;
  float apothem = (perim / n / 2.0) / tan(PI / (float)n);
  return max(CONNECTION_SNAP_MIN_MM, apothem * CONNECTION_SNAP_FRACTION);
}

float connectionSnapRadiusMM(Connection c) {
  return connectionSnapRadiusMM(c.parentShapeIdx, c.parentFaceIsTop);
}

// Pulls a connection to the exact centre of its host face when it is dragged close, so a
// centred mount is exact rather than eyeballed. Returns true when it snapped.
boolean snapConnectionToCentre(Connection c) {
  float r = connectionSnapRadiusMM(c);
  if (mag(c.posLocal.x, c.posLocal.y) <= r) {
    c.posLocal.set(0, 0);
    return true;
  }
  return false;
}

boolean isConnectionCentred(Connection c) {
  return abs(c.posLocal.x) < 1e-4 && abs(c.posLocal.y) < 1e-4;
}

// ---------------------------------------------------------------------------
// Editing
// ---------------------------------------------------------------------------

// Returns the new connection's index, or -1 if it was rejected.
int addConnection(int parentIdx, int childIdx, boolean isTop, PVector posLocal) {
  if (shapes == null) return -1;
  if (parentIdx < 0 || parentIdx >= shapes.size()) return -1;
  if (childIdx  < 0 || childIdx  >= shapes.size()) return -1;
  if (wouldCycle(parentIdx, childIdx)) {
    println("[Connection] Rejected: shape " + childIdx + " is already attached, or this would make a loop");
    return -1;
  }
  if (!lidFrameAvailable(shapes.get(parentIdx))) {
    println("[Connection] Rejected: parent shape " + parentIdx + " is per-edge/cuboid/hollow (not supported in v1)");
    return -1;
  }
  connections.add(new Connection(parentIdx, childIdx, isTop, posLocal));
  selectedConnectionIdx = connections.size() - 1;
  println("[Connection] Shape " + childIdx + " -> " + (isTop ? "top" : "bottom") +
          " face of shape " + parentIdx + " at (" + nf(posLocal.x, 0, 1) + ", " + nf(posLocal.y, 0, 1) + ") mm");
  return selectedConnectionIdx;
}

void removeConnection(int idx) {
  if (connections == null || idx < 0 || idx >= connections.size()) return;
  connections.remove(idx);
  if (selectedConnectionIdx == idx) selectedConnectionIdx = -1;
  else if (selectedConnectionIdx > idx) selectedConnectionIdx--;
}

void removeSelectedConnection() {
  removeConnection(selectedConnectionIdx);
}

// Keep connection indices valid after a shape is deleted from the shapes list.
// Called from removeShape() -- without this, connections silently retarget to whatever
// shape slid into the deleted index.
void reindexConnectionsAfterRemoval(int removedIdx) {
  if (connections == null) return;
  for (int i = connections.size() - 1; i >= 0; i--) {
    Connection c = connections.get(i);
    if (c.parentShapeIdx == removedIdx || c.childShapeIdx == removedIdx) {
      connections.remove(i);
      continue;
    }
    if (c.parentShapeIdx > removedIdx) c.parentShapeIdx--;
    if (c.childShapeIdx  > removedIdx) c.childShapeIdx--;
  }
  selectedConnectionIdx = constrain(selectedConnectionIdx, -1, connections.size() - 1);

  // The face highlight holds a shape index too, so it shifts with everything else.
  if (selectedFaceShapeIdx == removedIdx)     selectedFaceShapeIdx = -1;
  else if (selectedFaceShapeIdx > removedIdx) selectedFaceShapeIdx--;
}

// ---------------------------------------------------------------------------
// The cuts: slit rings in the parent's lid
// ---------------------------------------------------------------------------

// Draws every connection's mounting slits into the lid currently being drawn.
// Call from drawPlan() inside the lid's matrix -- origin at the piece's top-left corner,
// lid rotation already applied -- and BEFORE the lid outline, so inner cuts are emitted
// first and the sheet stays anchored until the perimeter is cut last. Same ordering rule
// the cutouts and the base plate already follow.
void drawConnectionSlits(boolean isTop) {
  if (connections == null || connections.isEmpty()) return;
  if (_drawingShapeIdx < 0) return;
  if (!lidFrameAvailable()) return;

  for (int i = 0; i < connections.size(); i++) {
    Connection c = connections.get(i);
    if (c.parentShapeIdx != _drawingShapeIdx) continue;
    if (c.parentFaceIsTop != isTop) continue;
    if (shapes == null || c.childShapeIdx < 0 || c.childShapeIdx >= shapes.size()) continue;

    int   n       = childMateSides(c);
    float edgePx  = childMateEdgeMM(c) * MM_current;
    if (edgePx <= 0) continue;

    PVector at = lidLocalToPiecePx(c.posLocal, isTop);

    pushStyle();
    if (bSavePDF) {
      // Export: a real cut line, matching the rest of the plan.
      stroke(uiLightGrayCutLines ? 180 : 0);
      strokeWeight(0.5);
    } else {
      // Preview: blue like a cutout, red when the footprint overhangs the lid edge.
      boolean fits = connectionFits(c);
      if (i == selectedConnectionIdx)  stroke(255, 0, 0);
      else if (!fits)                  stroke(230, 60, 60);
      else                             stroke(0, 120, 255);
      strokeWeight((i == selectedConnectionIdx ? 2.0 : 1.5) / SCREEN_SCALE);
    }

    pushMatrix();
    translate(at.x, at.y);
    rotate(radians(c.spinDeg));
    // A bottom lid is flipped over when it is folded on, so its printed face presents the
    // mirror image outward. Mirror the ring to match, or the asymmetric slits (which start
    // tabInset*2 in from one end) end up handed the wrong way against the child's tabs.
    if (!isTop) scale(1, -1);
    // tabInset = edge/4 mirrors tabInset_bot_px, exactly as BasePlate.pde does for its
    // second shape's slit pattern.
    drawBaseSlits(n, edgePx, edgePx / 4.0);
    popMatrix();

    popStyle();
  }
}

// ---------------------------------------------------------------------------
// 3D face-hit cache -- populated during draw3DView(), consumed by mouse picking
// ---------------------------------------------------------------------------
//
// Rather than inverting the projection matrix, we record where each candidate face landed
// on screen while the 3D transform was still in effect (PGraphics3D.screenX/Y/Z). Picking
// is then a point-in-polygon test, and dragging solves a 2x2 system against the face's own
// axes projected to screen -- an affine approximation that is exact enough at these zoom
// levels and far more stable than a full unprojection.

class FaceHit {
  int shapeIdx;
  boolean isTop;
  float[] sx, sy;        // projected lid polygon, in view3DBuffer coordinates
  float meanZ;           // depth, for choosing the frontmost face under the cursor
  PVector originS;       // where LF (0,0) landed on screen
  PVector uAxisS;        // screen delta for +1 mm along LF +u
  PVector vAxisS;        // screen delta for +1 mm along LF +v
}

ArrayList<FaceHit> faceHits = new ArrayList<FaceHit>();

// Only the main 3D view records pickable faces. The mini previews draw the same trees but
// must not overwrite what the main view captured, or picking would follow the wrong buffer.
boolean _captureFaces = false;

// Records one face's screen projection. Call while the shape's own 3D matrix is applied
// and its globals are loaded.
void captureFaceHit(PGraphics pg, int shapeIdx, boolean isTop) {
  if (!lidFrameAvailable()) return;
  PVector[] poly = lidPolygonLocalMM(isTop);
  FaceHit f = new FaceHit();
  f.shapeIdx = shapeIdx;
  f.isTop    = isTop;
  f.sx = new float[poly.length];
  f.sy = new float[poly.length];
  float zSum = 0;
  for (int i = 0; i < poly.length; i++) {
    PVector p = lidLocalTo3D(poly[i], isTop);
    f.sx[i] = pg.screenX(p.x, p.y, p.z);
    f.sy[i] = pg.screenY(p.x, p.y, p.z);
    zSum   += pg.screenZ(p.x, p.y, p.z);
  }
  f.meanZ = zSum / poly.length;

  PVector o  = lidLocalTo3D(new PVector(0, 0), isTop);
  PVector pu = lidLocalTo3D(new PVector(1, 0), isTop);
  PVector pv = lidLocalTo3D(new PVector(0, 1), isTop);
  f.originS = new PVector(pg.screenX(o.x, o.y, o.z),   pg.screenY(o.x, o.y, o.z));
  f.uAxisS  = new PVector(pg.screenX(pu.x, pu.y, pu.z) - f.originS.x,
                          pg.screenY(pu.x, pu.y, pu.z) - f.originS.y);
  f.vAxisS  = new PVector(pg.screenX(pv.x, pv.y, pv.z) - f.originS.x,
                          pg.screenY(pv.x, pv.y, pv.z) - f.originS.y);
  faceHits.add(f);
}

// Frontmost face under a point given in view3DBuffer coordinates, or null.
FaceHit pickFace(float bx, float by) {
  FaceHit best = null;
  for (FaceHit f : faceHits) {
    if (!pointInPolyXY(f.sx, f.sy, bx, by)) continue;
    if (best == null || f.meanZ < best.meanZ) best = f;
  }
  return best;
}

// Drag state for moving a connection across a face in the 3D view.
int draggedConnectionIdx = -1;
FaceHit draggedFace = null;
PVector connDragGrab = new PVector();

// An existing connection under this point on the face, or -1. Hit radius is the child's
// own circumradius, so you grab a connection by clicking anywhere on its footprint.
int pickConnectionOnFace(FaceHit f, PVector localMM) {
  if (connections == null) return -1;
  for (int i = connections.size() - 1; i >= 0; i--) {
    Connection c = connections.get(i);
    if (c.parentShapeIdx != f.shapeIdx || c.parentFaceIsTop != f.isTop) continue;
    float r = (childMateEdgeMM(c) / 2.0) / sin(PI / (float)childMateSides(c));
    if (dist(localMM.x, localMM.y, c.posLocal.x, c.posLocal.y) <= r) return i;
  }
  return -1;
}

// Nearest connection anywhere on this face, or -1. Used so that clicking a face that hosts
// a child selects it even when the click misses the footprint — otherwise there would be
// no way to select, and therefore no way to disconnect, a child you clicked slightly off.
int nearestConnectionOnFace(FaceHit f, PVector localMM) {
  if (connections == null) return -1;
  int best = -1;
  float bestD = Float.MAX_VALUE;
  for (int i = 0; i < connections.size(); i++) {
    Connection c = connections.get(i);
    if (c.parentShapeIdx != f.shapeIdx || c.parentFaceIsTop != f.isTop) continue;
    float d = dist(localMM.x, localMM.y, c.posLocal.x, c.posLocal.y);
    if (d < bestD) { bestD = d; best = i; }
  }
  return best;
}

// Detaches the child, which becomes a free-standing root again and goes back to drawing
// on its own. The shapes themselves are untouched — only the relation goes.
void disconnectSelected() {
  if (connections == null || selectedConnectionIdx < 0 || selectedConnectionIdx >= connections.size()) {
    println("[Connection] Nothing selected to disconnect");
    return;
  }
  Connection c = connections.get(selectedConnectionIdx);
  println("[Connection] Disconnected shape " + c.childShapeIdx + " from shape " + c.parentShapeIdx);
  removeConnection(selectedConnectionIdx);
}

// Flips which lid of the child mates with the host face. The 3D pose and the slit ring both
// read childFlipped, so they stay in step automatically.
void flipSelectedConnection() {
  if (connections == null || selectedConnectionIdx < 0 || selectedConnectionIdx >= connections.size()) return;
  Connection c = connections.get(selectedConnectionIdx);
  c.childFlipped = !c.childFlipped;
  println("[Connection] Child mates by its " + (c.childFlipped ? "TOP" : "BOTTOM") + " lid");
}

// ---------------------------------------------------------------------------
// Face highlighting — shows which face a click will act on
// ---------------------------------------------------------------------------
//
// Drawn in screen space over the already-composited 3D buffer, using the same projected
// polygons that picking uses. That guarantees the highlight and the hit test can never
// disagree: if it lights up, clicking it does what you expect.

// True when the cursor is over one of the 3D overlay buttons, which sit on top of the
// view and swallow the click before it can reach a face.
boolean mouseOver3DOverlay() {
  float[][] rects = {
    get3DViewBtnRect(0), get3DViewBtnRect(1), getWireframeBtnRect(), getConnectBtnRect(),
    get3DViewArrowRect(0), get3DViewArrowRect(1)
  };
  for (float[] r : rects) {
    if (mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3]) return true;
  }
  return false;
}

// Fills and outlines one face's projected polygon, offset into screen space.
void paintFace(FaceHit f, color fillCol, color strokeCol, float ox, float oy) {
  fill(fillCol);
  stroke(strokeCol);
  strokeWeight(2);
  beginShape();
  for (int i = 0; i < f.sx.length; i++) vertex(ox + f.sx[i], oy + f.sy[i]);
  endShape(CLOSE);
}

// Draws the snap zone as a ring in the face's own plane, so it follows the perspective.
void paintSnapZone(FaceHit f, float radiusMM, color strokeCol, float ox, float oy) {
  final int SEG = 28;
  noFill();
  stroke(strokeCol);
  strokeWeight(1.5);
  beginShape();
  for (int i = 0; i < SEG; i++) {
    float a = TWO_PI * i / SEG;
    float u = cos(a) * radiusMM, v = sin(a) * radiusMM;
    vertex(ox + f.originS.x + u * f.uAxisS.x + v * f.vAxisS.x,
           oy + f.originS.y + u * f.uAxisS.y + v * f.vAxisS.y);
  }
  endShape(CLOSE);
  // centre cross
  float k = radiusMM * 0.45;
  line(ox + f.originS.x - k * f.uAxisS.x, oy + f.originS.y - k * f.uAxisS.y,
       ox + f.originS.x + k * f.uAxisS.x, oy + f.originS.y + k * f.uAxisS.y);
  line(ox + f.originS.x - k * f.vAxisS.x, oy + f.originS.y - k * f.vAxisS.y,
       ox + f.originS.x + k * f.vAxisS.x, oy + f.originS.y + k * f.vAxisS.y);
}

// Call from draw(), after the 3D buffer is composited and before the overlay buttons.
void drawFaceHighlights() {
  if (!connectMode || faceHits == null || faceHits.isEmpty()) return;
  float ox = LEFT_SIDEBAR_WIDTH, oy = TOOLBAR_HEIGHT;

  FaceHit hover = mouseOver3DOverlay() ? null : pickFace(mouseX - ox, mouseY - oy);

  // The selected face — stays lit until it is clicked again.
  FaceHit selFace = null;
  if (selectedFaceShapeIdx >= 0) {
    for (FaceHit f : faceHits) {
      if (f.shapeIdx == selectedFaceShapeIdx && f.isTop == selectedFaceIsTop) { selFace = f; break; }
    }
  }
  Connection sel = null;
  if (connections != null && selectedConnectionIdx >= 0 && selectedConnectionIdx < connections.size()) {
    sel = connections.get(selectedConnectionIdx);
  }

  pushStyle();

  // Selected face — cool, persistent. Drawn under the hover tint when they coincide, so a
  // selected face you are also pointing at reads as both.
  if (selFace != null) {
    paintFace(selFace, color(80, 130, 200, 70), color(90, 150, 230, 235), ox, oy);
  }

  // Face under the cursor — warm; this is the one a click acts on.
  if (hover != null && hover != selFace) {
    paintFace(hover, color(230, 140, 40, 70), color(255, 170, 60, 235), ox, oy);
  } else if (hover != null) {
    // Same face: just thicken the outline rather than muddying the fill.
    noFill();
    stroke(255, 170, 60, 235);
    strokeWeight(3);
    beginShape();
    for (int i = 0; i < hover.sx.length; i++) vertex(ox + hover.sx[i], oy + hover.sy[i]);
    endShape(CLOSE);
  }

  // Snap zone on whichever face is in play, brightening once it has actually snapped.
  FaceHit zoneOn = (hover != null) ? hover : selFace;
  if (zoneOn != null) {
    boolean snapped = (sel != null && selFace == zoneOn &&
                       sel.parentShapeIdx == zoneOn.shapeIdx && sel.parentFaceIsTop == zoneOn.isTop &&
                       isConnectionCentred(sel));
    paintSnapZone(zoneOn, connectionSnapRadiusMM(zoneOn.shapeIdx, zoneOn.isTop),
                  snapped ? color(120, 230, 120, 240) : color(255, 255, 255, 130), ox, oy);
  }

  // Name the face in play at its centre — hovered if there is one, else the selected face.
  FaceHit lbl = (hover != null) ? hover : selFace;
  if (lbl != null && shapes != null && lbl.shapeIdx < shapes.size()) {
    ShapeSpec hs = shapes.get(lbl.shapeIdx);
    String nm = (hs.label != null && !hs.label.isEmpty()) ? hs.label : ("Shape " + (lbl.shapeIdx + 1));
    String txt = nm + " · " + (lbl.isTop ? "top" : "bottom");
    textAlign(CENTER, CENTER);
    uiText(12);
    // Processing has no text halo, so lay a dark offset pass down first for legibility
    // against whatever face tint is behind it.
    noStroke();
    fill(0, 180);
    text(txt, ox + lbl.originS.x + 1, oy + lbl.originS.y + 1);
    fill(255);
    text(txt, ox + lbl.originS.x, oy + lbl.originS.y);
  }

  popStyle();
}

// Screen point (view3DBuffer coords) -> LF mm on that face.
// Solves [uAxisS vAxisS] * [u v]' = (point - originS).
PVector faceScreenToLocal(FaceHit f, float bx, float by) {
  float det = f.uAxisS.x * f.vAxisS.y - f.uAxisS.y * f.vAxisS.x;
  if (abs(det) < 1e-6) return new PVector(0, 0);   // face is edge-on; no usable mapping
  float dx = bx - f.originS.x;
  float dy = by - f.originS.y;
  float u = ( dx * f.vAxisS.y - dy * f.vAxisS.x) / det;
  float v = (-dx * f.uAxisS.y + dy * f.uAxisS.x) / det;
  return new PVector(u, v);
}
