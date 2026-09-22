// CONNECTION.PDE - Attaching one shape to a face of another
//
// A Connection says "shape C stands on face F of shape P, at this spot, at this angle".
// It does two things:
//   1. In the 3D preview, the child is posed on the parent's face (see drawShapeTree in
//      tools.pde) so you can see and drag the assembly.
//   2. In the flat pattern, a ring of tab-through slits is cut into the parent's face at
//      the matching spot, so the child's bottom-lid tabs push through and lock -- exactly
//      the mechanism BasePlate.pde already uses to mount a form on a base plate. The slit
//      drawing IS drawBaseSlits(); this file only positions it.
//
// A face is EITHER lid, or any panel of the side strip. Both live in one canonical
// coordinate frame -- LidFrame.pde for the lids, SidePanelFrame.pde for the walls.
// Positions are stored in that frame (mm from the face's centre), never as screen or page
// coordinates, so they survive resizing, re-placement and rotation of either shape.
//
// Connections are a RELATION between shapes, so they are held in one global list rather
// than inside ShapeSpec: saveGlobalsTo/loadGlobalsFrom copy scalars, so storing a
// connection on both ends would let the two copies drift apart.
//
// Scope: uniform regular polygons. Guarded by lidFrameAvailable() / sidePanelFrameAvailable().

// ---------------------------------------------------------------------------
// Face addresses
// ---------------------------------------------------------------------------
//
// A face used to be one boolean ("is it the top lid?"). Now it is a kind plus an index, so
// the same machinery -- picking, dragging, fitting, slitting -- addresses walls as well as
// lids. The index is only meaningful for FACE_SIDE; lids pass 0.

final int FACE_LID_TOP = 0;
final int FACE_LID_BOT = 1;
final int FACE_SIDE    = 2;

boolean faceIsLid(int kind)    { return kind == FACE_LID_TOP || kind == FACE_LID_BOT; }
boolean faceIsTopLid(int kind) { return kind == FACE_LID_TOP; }
int     lidFaceKind(boolean isTop) { return isTop ? FACE_LID_TOP : FACE_LID_BOT; }

String faceName(int kind, int index) {
  if (kind == FACE_LID_TOP) return "top";
  if (kind == FACE_LID_BOT) return "bottom";
  return "side " + (index + 1);
}

// A slit ring must not reach any of a side panel's boundaries: unlike a lid, all four of
// them are fold lines, and a cut that touches one ruins the fold.
final float SIDE_SLIT_CLEARANCE_MM = 2.0;

class Connection {
  int parentShapeIdx;       // index into shapes -- the shape that gets the slits cut into it
  int childShapeIdx;        // index into shapes -- the shape that stands on the face
  int parentFaceKind;       // FACE_LID_TOP / FACE_LID_BOT / FACE_SIDE
  int parentFaceIndex;      // side-panel index; 0 for a lid
  boolean childFlipped;     // false = the child's BOTTOM lid does the attaching (default)
  PVector posLocal;         // mm in the parent face's canonical frame
  float spinDeg;            // child's rotation about the face normal
  int markId;               // stable; picks the pairing mark's colour and symbol

  Connection(int _parent, int _child, int _kind, int _index, PVector _pos) {
    parentShapeIdx  = _parent;
    childShapeIdx   = _child;
    parentFaceKind  = _kind;
    parentFaceIndex = _index;
    childFlipped    = false;
    posLocal        = _pos.copy();
    spinDeg         = 0;
    markId          = 0;   // assigned by addConnection, or copied by copyConnection
  }

  boolean onLid()    { return faceIsLid(parentFaceKind); }
  boolean onTopLid() { return parentFaceKind == FACE_LID_TOP; }

  boolean onFace(int shapeIdx, int kind, int index) {
    if (parentShapeIdx != shapeIdx || parentFaceKind != kind) return false;
    return faceIsLid(kind) || parentFaceIndex == index;
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
int selectedFaceKind  = FACE_LID_TOP;
int selectedFaceIndex = 0;
boolean _facePressWasSelected = false;  // was the pressed face already selected?
boolean _connDragMoved = false;         // did the pointer move between press and release?

boolean isFaceSelected(int shapeIdx, int kind, int index) {
  if (selectedFaceShapeIdx != shapeIdx || selectedFaceKind != kind) return false;
  return faceIsLid(kind) || selectedFaceIndex == index;
}

void selectFace(int shapeIdx, int kind, int index) {
  selectedFaceShapeIdx = shapeIdx;
  selectedFaceKind     = kind;
  selectedFaceIndex    = index;
}

// Clears the highlight only. Any connection on the face is left in place — deselecting is
// a viewing action, not a destructive one; Del is what removes a connection.
void clearFaceSelection() {
  selectedFaceShapeIdx  = -1;
  selectedConnectionIdx = -1;
}

// Index of the shape drawPlan() is currently rendering. drawPlan() reads globals rather
// than taking the shape as an argument, so the slit code needs this to know whose face it
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

// The child's mating footprint in the host face's frame, mm.
PVector[] childFootprintMM(Connection c) {
  return regularPolygonMM(childMateSides(c), childMateEdgeMM(c), c.spinDeg);
}

// How far the footprint reaches along the face's v axis. Used by the flush-to-the-fold-line
// snaps: the exact vertex extent, not the circumradius, which would over-reserve on a
// polygon that has been spun.
float childFootprintHalfVMM(Connection c) {
  float m = 0;
  for (PVector p : childFootprintMM(c)) m = max(m, abs(p.y));
  return m;
}

// ---------------------------------------------------------------------------
// Lid-to-lid joints that need no cut at all
// ---------------------------------------------------------------------------
//
// When the child mates by a lid that is the SAME polygon as the host lid -- same side count,
// same edge length -- the two rims coincide. There is nothing to cut: the child's own lid
// tabs already land exactly where the host's lid tabs are, so the two forms tab together at
// the rim like any other lid. Worse than unnecessary, a slit ring drawn there would run
// straight along the host's own tab bases and cut them off.
//
// Position does not enter into it. Two identical polygons meet in exactly one way, so such a
// connection is pinned to the centre (see snapConnection).

final float LID_MATCH_TOLERANCE_MM = 0.2;   // paper-scale slop on the edge-length match

boolean connectionNeedsNoCut(Connection c) {
  if (c == null || !c.onLid() || shapes == null) return false;
  if (c.parentShapeIdx < 0 || c.parentShapeIdx >= shapes.size()) return false;
  if (c.childShapeIdx  < 0 || c.childShapeIdx  >= shapes.size()) return false;
  ShapeSpec p = shapes.get(c.parentShapeIdx);
  int pn = max(3, p.nSides);
  if (childMateSides(c) != pn) return false;
  float hostEdgeMM = (c.onTopLid() ? p.cylinder.x : p.cylinder.y) / pn;
  return abs(childMateEdgeMM(c) - hostEdgeMM) <= LID_MATCH_TOLERANCE_MM;
}

// Does the child's footprint sit entirely inside the parent's face?
// A slit ring that crosses an outline or a fold line destroys the piece, so this drives a
// warning and a red preview. Requires the PARENT's globals to be loaded.
boolean connectionFits(Connection c) {
  // Matching lids cut nothing, so nothing can be ruined. Without this the footprint would
  // sit exactly ON the host outline and the strict inside test would call it an overhang.
  if (connectionNeedsNoCut(c)) return true;

  PVector[] host;
  if (c.onLid()) {
    if (!lidFrameAvailable()) return false;
    host = lidPolygonLocalMM(c.onTopLid());
  } else {
    if (!sidePanelFrameAvailable()) return false;
    host = sidePanelPolygonLocalMM(SIDE_SLIT_CLEARANCE_MM);
  }
  for (PVector v : childFootprintMM(c)) {
    if (!pointInPoly(host, c.posLocal.x + v.x, c.posLocal.y + v.y)) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Snapping
// ---------------------------------------------------------------------------
// A child mounted dead-centre is by far the common case, so a new connection lands there
// and a drag is pulled back to it. On a wall there are two more positions worth hitting
// exactly: flush under the top fold line and flush above the bottom one, which is how you
// mount something at the rim. The radius scales with the host face (a fixed mm radius
// would be unmissable on a small face and invisible on a large one).

final float CONNECTION_SNAP_FRACTION = 0.20;  // of the host face's half-extent
final float CONNECTION_SNAP_MIN_MM   = 2.5;

// Arrow-key step, in face millimetres. Shift takes the coarse one.
final float CONNECTION_NUDGE_FINE_MM   = 1.0;
final float CONNECTION_NUDGE_COARSE_MM = 5.0;

// Computed from the ShapeSpec rather than the globals, so the highlight overlay can call it
// without swapping whose shape is loaded.
float connectionSnapRadiusMM(int parentShapeIdx, int faceKind) {
  if (shapes == null || parentShapeIdx < 0 || parentShapeIdx >= shapes.size()) return CONNECTION_SNAP_MIN_MM;
  ShapeSpec p = shapes.get(parentShapeIdx);
  int n = max(3, p.nSides);
  if (faceIsLid(faceKind)) {
    float perim = faceIsTopLid(faceKind) ? p.cylinder.x : p.cylinder.y;
    float apothem = (perim / n / 2.0) / tan(PI / (float)n);
    return max(CONNECTION_SNAP_MIN_MM, apothem * CONNECTION_SNAP_FRACTION);
  }
  // Side panel: half of whichever of its two extents is smaller. The slant height mirrors
  // the cylinderH_px formula in Param.pde.
  float tE = p.cylinder.x / n, bE = p.cylinder.y / n;
  float slant = sqrt(sq(p.cylinder.z) + sq(bE - tE));
  float half = min((tE + bE) / 4.0, slant / 2.0);
  return max(CONNECTION_SNAP_MIN_MM, half * CONNECTION_SNAP_FRACTION);
}

float connectionSnapRadiusMM(Connection c) {
  return connectionSnapRadiusMM(c.parentShapeIdx, c.parentFaceKind);
}

// The v positions a side connection snaps to: the panel's middle, and flush against each
// fold line. Requires the PARENT's globals to be loaded. Empty when the child is too tall
// for the panel to offer a flush position.
float[] sideSnapTargetsV(Connection c) {
  if (!sidePanelFrameAvailable()) return new float[]{ 0 };
  float halfH = sidePanelHeightPx() / 2.0 / MM_current;
  float reach = childFootprintHalfVMM(c) + SIDE_SLIT_CLEARANCE_MM;
  float flush = halfH - reach;
  if (flush <= 0.01) return new float[]{ 0 };
  return new float[]{ 0, flush, -flush };
}

// Pulls a connection onto its face's guides when it is dragged close, so a placed child is
// exact rather than eyeballed. Returns true when it snapped.
// Requires the PARENT's globals to be loaded.
// The pull a DRAG gets: the face's full snap radius, sized so an aimed gesture lands cleanly.
boolean snapConnection(Connection c) {
  return snapConnectionWithin(c, connectionSnapRadiusMM(c));
}

// The same guides, with the catchment given explicitly.
//
// A drag and a keypress want very different radii. A drag is imprecise, so it wants a wide
// pull. An arrow key already says exactly what it means, and on a typical wall the drag
// radius is several millimetres — wider than the step — so reusing it would swallow the
// first few presses whole and leave the arrows apparently dead at the centre, which is
// where every connection starts. The nudge therefore passes a fraction of its own step:
// enough to land exactly on a guide it has almost reached, never enough to eat a press.
boolean snapConnectionWithin(Connection c, float r) {
  // Two identical rims meet in exactly one way, so there is nowhere to move to.
  if (connectionNeedsNoCut(c)) {
    c.posLocal.set(0, 0);
    return true;
  }

  // A lid snaps radially: its guide is a single point, the centre.
  if (c.onLid()) {
    if (mag(c.posLocal.x, c.posLocal.y) <= r) {
      c.posLocal.set(0, 0);
      return true;
    }
    return false;
  }

  // A wall snaps per axis, because its guides are lines: the vertical midline, and three
  // horizontal ones (middle, flush top, flush bottom).
  boolean snapped = false;
  if (abs(c.posLocal.x) <= r) { c.posLocal.x = 0; snapped = true; }
  float best = 0, bestD = Float.MAX_VALUE;
  for (float t : sideSnapTargetsV(c)) {
    float d = abs(c.posLocal.y - t);
    if (d < bestD) { bestD = d; best = t; }
  }
  if (bestD <= r) { c.posLocal.y = best; snapped = true; }
  return snapped;
}

boolean isConnectionCentred(Connection c) {
  return abs(c.posLocal.x) < 1e-4 && abs(c.posLocal.y) < 1e-4;
}

// ---------------------------------------------------------------------------
// Editing
// ---------------------------------------------------------------------------

// Returns the new connection's index, or -1 if it was rejected.
int addConnection(int parentIdx, int childIdx, int faceKind, int faceIndex, PVector posLocal) {
  if (shapes == null) return -1;
  if (parentIdx < 0 || parentIdx >= shapes.size()) return -1;
  if (childIdx  < 0 || childIdx  >= shapes.size()) return -1;
  if (wouldCycle(parentIdx, childIdx)) {
    println("[Connection] Rejected: shape " + childIdx + " is already attached, or this would make a loop");
    return -1;
  }
  ShapeSpec p = shapes.get(parentIdx);
  if (faceIsLid(faceKind)) {
    if (!lidFrameAvailable(p)) {
      println("[Connection] Rejected: parent shape " + parentIdx + " is per-edge/cuboid/hollow (lids not supported)");
      return -1;
    }
  } else {
    if (!sidePanelFrameAvailable(p)) {
      println("[Connection] Rejected: parent shape " + parentIdx + " is per-edge/cuboid/hollow/kresling (walls not supported)");
      return -1;
    }
    if (faceIndex < 0 || faceIndex >= max(3, p.nSides)) {
      println("[Connection] Rejected: shape " + parentIdx + " has no side panel " + faceIndex);
      return -1;
    }
  }
  // Past every rejection, so a refused join does not cost an undo step.
  pushConnectionUndo("");
  Connection nc = new Connection(parentIdx, childIdx, faceKind, faceIndex, posLocal);
  nc.markId = nextFreeMarkId();
  connections.add(nc);
  selectedConnectionIdx = connections.size() - 1;
  println("[Connection] Shape " + childIdx + " -> " + faceName(faceKind, faceIndex) +
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

  // Every stored snapshot names shapes by an index that just moved, and deleting a shape is
  // not itself undoable — so the history cannot be trusted across it.
  invalidateConnectionUndo("shape deleted");
}

// A shape's side-panel connections are addressed by panel index, so cutting the shape down
// to fewer sides would leave them pointing at panels that no longer exist. Called from
// wherever nSides changes.
void clampConnectionsToPanelCount(int shapeIdx, int nPanels) {
  if (connections == null) return;
  boolean removedAny = false;
  for (int i = connections.size() - 1; i >= 0; i--) {
    Connection c = connections.get(i);
    if (c.parentShapeIdx != shapeIdx || c.onLid()) continue;
    if (c.parentFaceIndex >= max(3, nPanels)) {
      println("[Connection] Shape " + c.childShapeIdx + " detached: side panel " +
              (c.parentFaceIndex + 1) + " no longer exists");
      removeConnection(i);
      removedAny = true;
    }
  }
  // This detachment is a consequence of a geometry change, and geometry is outside what the
  // connection history can put back. Undoing to a state that expects walls the shape no
  // longer has would be a lie, so the history goes instead.
  if (removedAny) invalidateConnectionUndo("side count reduced");
}

// ---------------------------------------------------------------------------
// The cuts: slit rings
// ---------------------------------------------------------------------------

// Emits the slit ring for one connection, centred at the current origin.
// Style is set by the caller. `mirror` is applied AFTER the spin, not before — a mirror and
// a rotation do not commute, and swapping them would send the spin the wrong way round on
// a mirrored face.
void drawOneConnectionSlitRing(Connection c, boolean mirror) {
  int   n      = childMateSides(c);
  float edgePx = childMateEdgeMM(c) * MM_current;
  if (edgePx <= 0) return;
  pushMatrix();
  rotate(radians(c.spinDeg));
  if (mirror) scale(1, -1);
  // tabInset = edge/4 mirrors tabInset_bot_px, exactly as BasePlate.pde does for its
  // second shape's slit pattern.
  drawBaseSlits(n, edgePx, edgePx / 4.0);
  popMatrix();
}

// Marks a lid-to-lid joint that needs no cut: the shared rim, dashed, plus a centre cross.
// Preview only — it must never reach the page, or it would print as a guide line on the lid
// and be mistaken for a cut. Drawn centred at the current origin.
void drawNoCutMarker(Connection c, int connIdx) {
  int n = childMateSides(c);
  float rPx = (childMateEdgeMM(c) * MM_current / 2.0) / sin(PI / (float)n);
  if (rPx <= 0) return;

  pushStyle();
  noFill();
  boolean sel = (connIdx == selectedConnectionIdx);
  stroke(sel ? color(255, 0, 0) : color(60, 190, 120));
  strokeWeight((sel ? 2.0 : 1.5) / SCREEN_SCALE);

  float aI = TWO_PI / n;
  float start = -HALF_PI - aI / 2.0 + radians(c.spinDeg);
  float dash = 2.0 * MM_current, gap = 1.5 * MM_current;
  for (int i = 0; i < n; i++) {
    float a0 = start + i * aI, a1 = start + (i + 1) * aI;
    drawDashedLine(cos(a0) * rPx, sin(a0) * rPx, cos(a1) * rPx, sin(a1) * rPx, dash, gap);
  }
  float k = rPx * 0.18;
  line(-k, 0, k, 0);
  line(0, -k, 0, k);
  popStyle();
}

// ---------------------------------------------------------------------------
// Pairing marks: which piece goes on which
// ---------------------------------------------------------------------------
//
// The same coloured symbol is printed at the centre of the host's slit ring and at the
// centre of the child lid that pushes through it. On the cut sheet the two pieces can be
// far apart and look alike, so the mark is what says "this one goes here" while you build.
//
// ARTWORK, NOT GEOMETRY. It prints on the PDF and shows on screen, and is kept out of the
// SVG cut file — a cutter would happily cut it out.
//
// Colour AND symbol both change on every connection, so the pairing survives a greyscale
// print and never rests on telling two colours apart. That is why the counts are 6 and 5:
// being coprime, the pair only repeats after 30 connections, whereas equal counts would lock
// the two cues together and leave the symbol constant across the first six -- which is
// exactly no help to anyone printing in black and white.
//
// Colours are the Okabe-Ito set, which stays distinguishable for the common colour-vision
// deficiencies. Every symbol is mirror-symmetric, so a mark cannot be misread as a different
// one when seen on the reverse of a lid that folds over. There is no diamond, because at
// this size it is not tellable from the square.

final color[] CONNECTION_MARK_COLORS = {
  #D55E00, #0072B2, #009E73, #CC79A7, #E69F00, #56B4E9
};
final int CONNECTION_MARK_SYMBOLS = 5;

// The lowest id no live connection is using. A running counter would not do: the undo
// snapshots copy every connection, so anything incremented on construction races ahead
// unpredictably and two joints on the same model could end up wearing the same mark. Taking
// the lowest free id instead makes the first connection mark 0, the second mark 1, and
// reuses an id once its connection is detached.
int nextFreeMarkId() {
  if (connections == null) return 0;
  for (int id = 0; ; id++) {
    boolean taken = false;
    for (Connection c : connections) {
      if (c.markId == id) { taken = true; break; }
    }
    if (!taken) return id;
  }
}

color connectionMarkColor(Connection c) {
  int i = ((c.markId % CONNECTION_MARK_COLORS.length) + CONNECTION_MARK_COLORS.length)
          % CONNECTION_MARK_COLORS.length;
  return CONNECTION_MARK_COLORS[i];
}

int connectionMarkSymbol(Connection c) {
  return ((c.markId % CONNECTION_MARK_SYMBOLS) + CONNECTION_MARK_SYMBOLS) % CONNECTION_MARK_SYMBOLS;
}

// Radius (mm) of the mark. Scaled to the child's footprint so it sits comfortably inside the
// slit ring on any size of shape, then held to a range that stays legible without dominating
// a small lid.
float connectionMarkRadiusMM(Connection c) {
  int n = childMateSides(c);
  float apothem = (childMateEdgeMM(c) / 2.0) / tan(PI / (float)n);
  return constrain(apothem * 0.42, 2.0, 6.0);
}

// Draws the pairing mark centred at the current origin. Both ends of a connection call this,
// which is what makes them match.
void drawConnectionPairMark(Connection c) {
  if (bExportingCutFile) return;   // artwork only — never a cut line
  float r = connectionMarkRadiusMM(c) * MM_current;
  if (r <= 0) return;

  pushStyle();
  color col = connectionMarkColor(c);
  noStroke();
  fill(col);

  switch (connectionMarkSymbol(c)) {
    case 0:   // disc
      ellipse(0, 0, r * 2, r * 2);
      break;
    case 1: { // cross
      stroke(col);
      strokeWeight(r * 0.55);
      strokeCap(SQUARE);
      line(-r, 0, r, 0);
      line(0, -r, 0, r);
      break;
    }
    case 2:   // five-pointed star
      beginShape();
      for (int i = 0; i < 10; i++) {
        float a  = -HALF_PI + i * PI / 5.0;
        float rr = (i % 2 == 0) ? r : r * 0.42;
        vertex(cos(a) * rr, sin(a) * rr);
      }
      endShape(CLOSE);
      break;
    case 3: { // square
      pushStyle();
      rectMode(CENTER);
      rect(0, 0, r * 1.7, r * 1.7);
      popStyle();
      break;
    }
    default:  // triangle
      triangle(0, -r, r * 0.87, r * 0.5, -r * 0.87, r * 0.5);
      break;
  }
  popStyle();
}

// The mark on the OTHER end: the centre of the child lid that mates with a host face.
// Call from drawPlan() inside that lid's matrix, like drawConnectionSlits().
//
// A shape has at most one parent, so this draws at most one mark.
void drawChildMateMarks(boolean isTop) {
  if (bExportingCutFile) return;
  if (connections == null || connections.isEmpty()) return;
  if (_drawingShapeIdx < 0) return;
  if (!lidFrameAvailable()) return;

  for (Connection c : connections) {
    if (c.childShapeIdx != _drawingShapeIdx) continue;
    // childFlipped means the child mates by its TOP lid, so this is the mating lid exactly
    // when the two agree.
    if (c.childFlipped != isTop) continue;
    PVector at = lidLocalToPiecePx(new PVector(0, 0), isTop);
    pushMatrix();
    translate(at.x, at.y);
    drawConnectionPairMark(c);
    popMatrix();
  }
}

// Preview colouring, shared by the lid and the wall passes.
void styleConnectionSlits(int connIdx, boolean fits) {
  if (bSavePDF) {
    // Export: a real cut line, matching the rest of the plan.
    stroke(uiLightGrayCutLines ? 180 : 0);
    strokeWeight(0.5);
  } else {
    // Preview: blue like a cutout, red when the footprint overhangs the face.
    if (connIdx == selectedConnectionIdx)  stroke(255, 0, 0);
    else if (!fits)                        stroke(230, 60, 60);
    else                                   stroke(0, 120, 255);
    strokeWeight((connIdx == selectedConnectionIdx ? 2.0 : 1.5) / SCREEN_SCALE);
  }
}

// Draws every connection's mounting slits into the LID currently being drawn.
// Call from drawPlan() inside the lid's matrix -- origin at the piece's top-left corner,
// lid rotation already applied -- and BEFORE the lid outline, so inner cuts are emitted
// first and the sheet stays anchored until the perimeter is cut last. Same ordering rule
// the cutouts and the base plate already follow.
void drawConnectionSlits(boolean isTop) {
  if (connections == null || connections.isEmpty()) return;
  if (_drawingShapeIdx < 0) return;
  if (!lidFrameAvailable()) return;

  int kind = lidFaceKind(isTop);
  for (int i = 0; i < connections.size(); i++) {
    Connection c = connections.get(i);
    if (c.parentShapeIdx != _drawingShapeIdx) continue;
    if (c.parentFaceKind != kind) continue;
    if (shapes == null || c.childShapeIdx < 0 || c.childShapeIdx >= shapes.size()) continue;

    // Matching rims need no cut, and drawing one here would slice through the host's own
    // tab bases. Nothing at all goes to the page; on screen it gets a marker instead, so the
    // joint is still visible and selectable.
    boolean noCut = connectionNeedsNoCut(c);
    if (noCut && bSavePDF) continue;

    PVector at = lidLocalToPiecePx(c.posLocal, isTop);

    pushStyle();
    pushMatrix();
    translate(at.x, at.y);
    if (noCut) {
      drawNoCutMarker(c, i);
    } else {
      styleConnectionSlits(i, bSavePDF ? true : connectionFits(c));
      // A bottom lid is flipped over when it is folded on, so its printed face presents the
      // mirror image outward. Mirror the ring to match, or the asymmetric slits (which start
      // tabInset*2 in from one end) end up handed the wrong way against the child's tabs.
      drawOneConnectionSlitRing(c, !isTop);
    }
    // Names the joint, in the middle of the ring it belongs to. Matters most for a matching
    // rim, where there are no slits to say which piece pairs with which.
    drawConnectionPairMark(c);
    popMatrix();
    popStyle();
  }
}

// Draws every connection's mounting slits into the SIDE STRIP of the shape being drawn.
// Call from drawPlan() at the strip origin -- NOT inside the per-half matrices, because the
// poses already carry the split-strip offsets (see sidePanelPosesPx).
//
// No mirroring here, unlike a bottom lid: the strip's printed face is the outside of the
// prism, the same way round as the top lid.
void drawConnectionSlitsOnPanels() {
  if (connections == null || connections.isEmpty()) return;
  if (_drawingShapeIdx < 0) return;
  if (!sidePanelFrameAvailable()) return;

  SidePanelPose[] poses = sidePanelPosesPx();
  if (poses == null) return;

  for (int i = 0; i < connections.size(); i++) {
    Connection c = connections.get(i);
    if (c.parentShapeIdx != _drawingShapeIdx) continue;
    if (c.onLid()) continue;
    if (shapes == null || c.childShapeIdx < 0 || c.childShapeIdx >= shapes.size()) continue;
    if (c.parentFaceIndex < 0 || c.parentFaceIndex >= poses.length) continue;
    SidePanelPose pose = poses[c.parentFaceIndex];
    if (pose == null) continue;

    pushStyle();
    styleConnectionSlits(i, bSavePDF ? true : connectionFits(c));
    pushMatrix();
    translate(pose.originPx.x, pose.originPx.y);
    rotate(pose.rotRad);
    translate(c.posLocal.x * MM_current, c.posLocal.y * MM_current);
    drawOneConnectionSlitRing(c, false);
    drawConnectionPairMark(c);
    popMatrix();
    popStyle();
  }
}

// ---------------------------------------------------------------------------
// One pose for every kind of face
// ---------------------------------------------------------------------------
//
// A lid's normal is +-y, which is why the old code could pose a child with a couple of
// rotateX(PI) calls. A wall's normal is not, so the pose is built from the face's own basis
// instead. The basis reproduces the two lid cases exactly:
//
//   top lid     C = (0,-halfH,0)  u = x  v = z   n = u x v = -y   ->  identity
//   bottom lid  C = (0,+halfH,0)  u = x  v = -z  n = u x v = +y   ->  rotateX(PI)
//
// which are precisely the transforms drawShapeTree() used to apply by hand.
//
// ONE DELIBERATE CHANGE comes with it. The old code spun the child about WORLD y, which is
// the face normal on a top lid but its NEGATIVE on a bottom lid -- so , and . turned a
// bottom-mounted child the opposite way from a top-mounted one. Here spin is always about
// the face's own outward normal, which is the only definition that also generalises to a
// wall. Top lids behave exactly as before; on a bottom lid , and . now turn the other way.
// Nothing in the cut file moves: the slit ring's own rotation is untouched.

class FaceBasis3D {
  PVector c;       // face centre, in the shape's local 3D frame (px)
  PVector u, v, n; // unit axes: face +u, face +v, outward normal
  float vScale;    // extra factor on v; 1 for lids (see sidePanelVScale3D)
}

// Requires the face's OWNING shape's globals to be loaded. Null when the face has no frame.
FaceBasis3D faceBasis3D(int kind, int index) {
  FaceBasis3D b = new FaceBasis3D();
  if (faceIsLid(kind)) {
    if (!lidFrameAvailable()) return null;
    boolean isTop = faceIsTopLid(kind);
    b.c = lidLocalTo3D(new PVector(0, 0), isTop);
    b.u = PVector.sub(lidLocalTo3D(new PVector(1, 0), isTop), b.c);
    b.v = PVector.sub(lidLocalTo3D(new PVector(0, 1), isTop), b.c);
    if (b.u.mag() < 1e-6 || b.v.mag() < 1e-6) return null;
    b.u.normalize();
    b.v.normalize();
    b.n = b.u.cross(b.v);
    b.n.normalize();
    b.vScale = 1.0;
    return b;
  }
  if (!sidePanelFrameAvailable()) return null;
  SidePanelBasis s = sidePanelBasis3D(index);
  if (s == null) return null;
  b.c = s.c;
  b.u = s.u;
  b.v = s.v;
  b.n = s.n;
  b.vScale = sidePanelVScale3D(s);
  return b;
}

// Face-local mm -> the shape's local 3D frame (px).
PVector faceLocalTo3D(FaceBasis3D b, PVector localMM) {
  if (b == null) return new PVector(0, 0, 0);
  float du = localMM.x * MM_current;
  float dv = localMM.y * MM_current * b.vScale;
  return new PVector(b.c.x + b.u.x * du + b.v.x * dv,
                     b.c.y + b.u.y * du + b.v.y * dv,
                     b.c.z + b.u.z * du + b.v.z * dv);
}

// The face outline in face-local mm.
PVector[] facePolygonLocalMM(int kind, int index) {
  if (faceIsLid(kind)) return lidPolygonLocalMM(faceIsTopLid(kind));
  return sidePanelPolygonLocalMM();
}

// Applies the transform that stands a child on this face. After this call the child's own
// origin is at the mounting point with its mating lid on the face, so the caller only has
// to drop it by half its height and draw it.
void applyFaceTransform3D(PGraphics pg, FaceBasis3D b, PVector localMM, float spinDeg) {
  PVector at = faceLocalTo3D(b, localMM);
  // Columns (u, -n, v): the child's own +x runs along the face's +u, its -y (the direction
  // a child grows out of its bottom lid) runs along the outward normal, and its +z along
  // the face's +v. det = +1 for lids and walls alike, so the child is never mirrored.
  pg.applyMatrix(b.u.x, -b.n.x, b.v.x, at.x,
                 b.u.y, -b.n.y, b.v.y, at.y,
                 b.u.z, -b.n.z, b.v.z, at.z,
                 0,     0,      0,     1);
  pg.rotateY(radians(spinDeg));
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
//
// Back faces are captured too. They can only ever be picked where nothing covers them, and
// on a convex prism every back face projects inside the silhouette that the front faces
// already fill -- so the frontmost-by-meanZ rule in pickFace() settles it.

class FaceHit {
  int shapeIdx;
  int kind;              // FACE_LID_TOP / FACE_LID_BOT / FACE_SIDE
  int index;             // side-panel index; 0 for lids
  float[] sx, sy;        // projected face polygon, in view3DBuffer coordinates
  float meanZ;           // depth, for choosing the frontmost face under the cursor
  PVector originS;       // where face (0,0) landed on screen
  PVector uAxisS;        // screen delta for +1 mm along face +u
  PVector vAxisS;        // screen delta for +1 mm along face +v

  boolean isLid() { return faceIsLid(kind); }
  String  name()  { return faceName(kind, index); }
}

ArrayList<FaceHit> faceHits = new ArrayList<FaceHit>();

// Only the main 3D view records pickable faces. The mini previews draw the same trees but
// must not overwrite what the main view captured, or picking would follow the wrong buffer.
boolean _captureFaces = false;

// Records one face's screen projection. Call while the shape's own 3D matrix is applied
// and its globals are loaded.
void captureFaceHit(PGraphics pg, int shapeIdx, int kind, int index) {
  FaceBasis3D b = faceBasis3D(kind, index);
  if (b == null) return;
  PVector[] poly = facePolygonLocalMM(kind, index);
  if (poly == null || poly.length < 3) return;

  FaceHit f = new FaceHit();
  f.shapeIdx = shapeIdx;
  f.kind     = kind;
  f.index    = index;
  f.sx = new float[poly.length];
  f.sy = new float[poly.length];
  float zSum = 0;
  for (int i = 0; i < poly.length; i++) {
    PVector p = faceLocalTo3D(b, poly[i]);
    f.sx[i] = pg.screenX(p.x, p.y, p.z);
    f.sy[i] = pg.screenY(p.x, p.y, p.z);
    zSum   += pg.screenZ(p.x, p.y, p.z);
  }
  f.meanZ = zSum / poly.length;

  PVector o  = faceLocalTo3D(b, new PVector(0, 0));
  PVector pu = faceLocalTo3D(b, new PVector(1, 0));
  PVector pv = faceLocalTo3D(b, new PVector(0, 1));
  f.originS = new PVector(pg.screenX(o.x, o.y, o.z),   pg.screenY(o.x, o.y, o.z));
  f.uAxisS  = new PVector(pg.screenX(pu.x, pu.y, pu.z) - f.originS.x,
                          pg.screenY(pu.x, pu.y, pu.z) - f.originS.y);
  f.vAxisS  = new PVector(pg.screenX(pv.x, pv.y, pv.z) - f.originS.x,
                          pg.screenY(pv.x, pv.y, pv.z) - f.originS.y);
  faceHits.add(f);
}

// Records every pickable face of the shape whose globals are loaded: both lids, plus every
// wall when the strip has a frame to address.
void captureAllFaceHits(PGraphics pg, int shapeIdx) {
  captureFaceHit(pg, shapeIdx, FACE_LID_TOP, 0);
  captureFaceHit(pg, shapeIdx, FACE_LID_BOT, 0);
  if (sidePanelFrameAvailable()) {
    int n = sidePanelCount();
    for (int i = 0; i < n; i++) captureFaceHit(pg, shapeIdx, FACE_SIDE, i);
  }
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

// Drag state for moving a connection across a 3D face.
int draggedConnectionIdx = -1;
FaceHit draggedFace = null;
PVector connDragGrab = new PVector();

// An existing connection under this point on the face, or -1. Hit radius is the child's
// own circumradius, so you grab a connection by clicking anywhere on its footprint.
int pickConnectionOnFace(FaceHit f, PVector localMM) {
  if (connections == null) return -1;
  for (int i = connections.size() - 1; i >= 0; i--) {
    Connection c = connections.get(i);
    if (!c.onFace(f.shapeIdx, f.kind, f.index)) continue;
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
    if (!c.onFace(f.shapeIdx, f.kind, f.index)) continue;
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
  pushConnectionUndo("");
  removeConnection(selectedConnectionIdx);
}

// Flips which lid of the child mates with the host face. The 3D pose and the slit ring both
// read childFlipped, so they stay in step automatically.
void flipSelectedConnection() {
  if (connections == null || selectedConnectionIdx < 0 || selectedConnectionIdx >= connections.size()) return;
  pushConnectionUndo("");
  Connection c = connections.get(selectedConnectionIdx);
  c.childFlipped = !c.childFlipped;
  println("[Connection] Child mates by its " + (c.childFlipped ? "TOP" : "BOTTOM") + " lid");
}

// --- Working in a parent's frame ------------------------------------------
// snapConnection() and connectionFits() read the PARENT's geometry out of the globals, but
// most callers are running with the SELECTED shape loaded. These two do the swap and put it
// back, so no caller has to remember to -- forgetting leaves the sidebar showing another
// shape's numbers.

boolean _loadParentGlobals(Connection c) {
  if (shapes == null || c == null) return false;
  if (c.parentShapeIdx < 0 || c.parentShapeIdx >= shapes.size()) return false;
  loadGlobalsFrom(shapes.get(c.parentShapeIdx));
  setParams(false);
  return true;
}

void _restoreSelectedGlobals() {
  if (shapes == null || selectedShapeIdx < 0 || selectedShapeIdx >= shapes.size()) return;
  loadGlobalsFrom(shapes.get(selectedShapeIdx));
  setParams(false);
}

void snapConnectionInParentFrame(Connection c) {
  if (!_loadParentGlobals(c)) return;
  snapConnection(c);
  _restoreSelectedGlobals();
}

void snapConnectionInParentFrame(Connection c, float radiusMM) {
  if (!_loadParentGlobals(c)) return;
  snapConnectionWithin(c, radiusMM);
  _restoreSelectedGlobals();
}

boolean connectionFitsInParentFrame(Connection c) {
  if (!_loadParentGlobals(c)) return true;
  boolean fits = connectionFits(c);
  _restoreSelectedGlobals();
  return fits;
}

// Nudges the selected connection along its face's own axes. Shared by the arrow keys and
// anything else that wants to move it by a known amount.
void nudgeSelectedConnection(float du, float dv) {
  if (connections == null || selectedConnectionIdx < 0 || selectedConnectionIdx >= connections.size()) return;
  // Held arrows collapse into one undo step; a pause starts a new one.
  pushConnectionUndo("nudge:" + selectedConnectionIdx);
  Connection c = connections.get(selectedConnectionIdx);
  c.posLocal.add(du, dv, 0);
  // A quarter of the step: tidies a near-miss onto a guide without ever eating a press.
  snapConnectionInParentFrame(c, max(abs(du), abs(dv)) * 0.25);
}

// Does the selected connection fit its host face?
boolean selectedConnectionFits() {
  if (connections == null || selectedConnectionIdx < 0 || selectedConnectionIdx >= connections.size()) return true;
  return connectionFitsInParentFrame(connections.get(selectedConnectionIdx));
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

// A point on the face, in screen space.
PVector faceLocalToScreen(FaceHit f, float u, float v, float ox, float oy) {
  return new PVector(ox + f.originS.x + u * f.uAxisS.x + v * f.vAxisS.x,
                     oy + f.originS.y + u * f.uAxisS.y + v * f.vAxisS.y);
}

// Draws the snap zone in the face's own plane, so it follows the perspective. A lid gets
// the ring it always had; a wall gets its guide LINES instead, because that is what it
// actually snaps to.
void paintSnapZone(FaceHit f, float radiusMM, color strokeCol, float ox, float oy) {
  noFill();
  stroke(strokeCol);
  strokeWeight(1.5);

  if (f.isLid()) {
    final int SEG = 28;
    beginShape();
    for (int i = 0; i < SEG; i++) {
      float a = TWO_PI * i / SEG;
      PVector p = faceLocalToScreen(f, cos(a) * radiusMM, sin(a) * radiusMM, ox, oy);
      vertex(p.x, p.y);
    }
    endShape(CLOSE);
    float k = radiusMM * 0.45;
    PVector a0 = faceLocalToScreen(f, -k, 0, ox, oy), a1 = faceLocalToScreen(f, k, 0, ox, oy);
    PVector b0 = faceLocalToScreen(f, 0, -k, ox, oy), b1 = faceLocalToScreen(f, 0, k, ox, oy);
    line(a0.x, a0.y, a1.x, a1.y);
    line(b0.x, b0.y, b1.x, b1.y);
    return;
  }

  // Wall: the vertical midline plus every horizontal guide, drawn the full width/height of
  // the panel so each reads as a line to snap to rather than a target to hit. One globals
  // swap covers both the panel's extents and the flush positions, which depend on the child
  // sitting on it.
  if (shapes == null || f.shapeIdx < 0 || f.shapeIdx >= shapes.size()) return;

  Connection onThis = null;
  if (connections != null && selectedConnectionIdx >= 0 && selectedConnectionIdx < connections.size()) {
    Connection sc = connections.get(selectedConnectionIdx);
    if (sc.onFace(f.shapeIdx, f.kind, f.index)) onThis = sc;
  }

  loadGlobalsFrom(shapes.get(f.shapeIdx));
  setParams(false);
  boolean ok = sidePanelFrameAvailable();
  float halfU = ok ? sidePanelMedianPx() / 2.0 / MM_current : 0;
  float halfV = ok ? sidePanelHeightPx() / 2.0 / MM_current : 0;
  float[] vs  = (ok && onThis != null) ? sideSnapTargetsV(onThis) : new float[]{ 0 };
  _restoreSelectedGlobals();
  if (!ok) return;

  PVector m0 = faceLocalToScreen(f, 0, -halfV, ox, oy), m1 = faceLocalToScreen(f, 0, halfV, ox, oy);
  line(m0.x, m0.y, m1.x, m1.y);

  for (float vv : vs) {
    PVector h0 = faceLocalToScreen(f, -halfU, vv, ox, oy);
    PVector h1 = faceLocalToScreen(f,  halfU, vv, ox, oy);
    line(h0.x, h0.y, h1.x, h1.y);
  }
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
      if (isFaceSelected(f.shapeIdx, f.kind, f.index)) { selFace = f; break; }
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

  // Snap guides on whichever face is in play, brightening once it has actually snapped.
  FaceHit zoneOn = (hover != null) ? hover : selFace;
  if (zoneOn != null) {
    boolean snapped = (sel != null && selFace == zoneOn &&
                       sel.onFace(zoneOn.shapeIdx, zoneOn.kind, zoneOn.index) &&
                       isConnectionCentred(sel));
    paintSnapZone(zoneOn, connectionSnapRadiusMM(zoneOn.shapeIdx, zoneOn.kind),
                  snapped ? color(120, 230, 120, 240) : color(255, 255, 255, 130), ox, oy);
  }

  // Name the face in play at its centre — hovered if there is one, else the selected face.
  FaceHit lbl = (hover != null) ? hover : selFace;
  if (lbl != null && shapes != null && lbl.shapeIdx < shapes.size()) {
    ShapeSpec hs = shapes.get(lbl.shapeIdx);
    String nm = (hs.label != null && !hs.label.isEmpty()) ? hs.label : ("Shape " + (lbl.shapeIdx + 1));
    String txt = nm + " · " + lbl.name();
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

// Screen point (view3DBuffer coords) -> face mm.
// Solves [uAxisS vAxisS] * [u v]' = (point - originS).
//
// A wall turns edge-on far more readily than a lid does, and there the two projected axes
// collapse onto one line: the system stops having a usable solution well before the
// determinant reaches zero. faceMappingUsable() is what callers check before trusting this,
// so that a drag on an edge-on panel is ignored rather than flinging the child to (0,0).
final float FACE_MAPPING_MIN_DET = 4.0;   // px^2 per mm^2

boolean faceMappingUsable(FaceHit f) {
  if (f == null) return false;
  float det = f.uAxisS.x * f.vAxisS.y - f.uAxisS.y * f.vAxisS.x;
  return abs(det) >= FACE_MAPPING_MIN_DET;
}

PVector faceScreenToLocal(FaceHit f, float bx, float by) {
  float det = f.uAxisS.x * f.vAxisS.y - f.uAxisS.y * f.vAxisS.x;
  if (abs(det) < 1e-6) return new PVector(0, 0);   // face is edge-on; no usable mapping
  float dx = bx - f.originS.x;
  float dy = by - f.originS.y;
  float u = ( dx * f.vAxisS.y - dy * f.vAxisS.x) / det;
  float v = (-dx * f.uAxisS.y + dy * f.uAxisS.x) / det;
  return new PVector(u, v);
}

// ---------------------------------------------------------------------------
// Picking connections in the FLAT pattern
// ---------------------------------------------------------------------------
//
// The slit ring can be dragged on the page as well as in the 3D view — the same way
// cutouts, markers and base slits already move. Both the drawing and the picking go through
// sidePanelPosesPx(), so the ring you grab is the ring that gets cut.
//
// Like the cutout drag, this addresses the SELECTED shape's first copy: extra repetitions
// and free-placement offsets live in the caller's matrix, not in the pose.

int draggedPanelConnIdx = -1;      // connection being dragged on the page, -1 = none
PVector panelConnDragGrab = new PVector();

// Click-to-select in the 3D view, outside connect mode. A press on a shape arms it; an orbit
// disarms it, so only a click that does not move changes the selection.
int _shapePressIdx = -1;
boolean _shapePressMoved = false;

// Circumradius (mm) of a connection's footprint — the grab radius on the page.
float connectionFootprintRadiusMM(Connection c) {
  return (childMateEdgeMM(c) / 2.0) / sin(PI / (float)childMateSides(c));
}

// The connection under a point given in the selected shape's pattern mm, or -1.
// Requires the selected shape's globals to be loaded, which is the state draw() leaves.
int pickPanelConnectionAt(float xMM, float yMM) {
  if (connections == null || shapes == null) return -1;
  if (selectedShapeIdx < 0 || selectedShapeIdx >= shapes.size()) return -1;
  if (!sidePanelFrameAvailable()) return -1;

  SidePanelPose[] poses = sidePanelPosesPx();
  if (poses == null) return -1;

  for (int i = connections.size() - 1; i >= 0; i--) {
    Connection c = connections.get(i);
    if (c.parentShapeIdx != selectedShapeIdx || c.onLid()) continue;
    if (c.parentFaceIndex < 0 || c.parentFaceIndex >= poses.length) continue;
    SidePanelPose pose = poses[c.parentFaceIndex];
    if (pose == null) continue;
    PVector at = sidePanelLocalToPatternMM(pose, c.posLocal);
    if (dist(xMM, yMM, at.x, at.y) <= connectionFootprintRadiusMM(c)) return i;
  }
  return -1;
}

// Face mm of a point given in the selected shape's pattern mm, for the connection being
// dragged. Returns null when its panel has no pose.
PVector panelConnectionLocalAt(Connection c, float xMM, float yMM) {
  if (!sidePanelFrameAvailable()) return null;
  SidePanelPose[] poses = sidePanelPosesPx();
  if (poses == null || c.parentFaceIndex < 0 || c.parentFaceIndex >= poses.length) return null;
  SidePanelPose pose = poses[c.parentFaceIndex];
  if (pose == null) return null;
  return sidePanelPatternToLocalMM(pose, xMM, yMM);
}
