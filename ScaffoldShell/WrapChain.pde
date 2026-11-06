// WRAPCHAIN.PDE - One wrap across a stack of connected shapes
//
// WrapFrame.pde wraps a single image over a single shape. This file lets several shapes
// share one: a stack joined lid to lid is treated as one long surface, so artwork crossing
// a joint stays continuous when the pieces are folded and tabbed together.
//
// WHICH JOINTS QUALIFY
//
// Only rims that coincide - connectionNeedsNoCut(), same side count and same edge length.
// Then the two walls meet corner to corner with no step, so nothing has to be invented at
// the joint. A connection also has to opt in through continueWrap. A chain stops at the
// first joint or shape that fails wrapJointLive(), and whatever lies beyond it wraps alone.
//
// THE COORDINATES
//
//   t   The budget in WrapFrame.pde, extended: the chain's two end caps, plus every wall in
//       between. The lids hidden inside a joint take no share, so the picture runs straight
//       from one wall into the next. Each shape keeps its own bottom-to-top sense in its
//       WrapSegment, so a shape mounted upside down simply has tBotRim > tTopRim.
//
//   s   Every shape spans the full image width, so a narrower shape squeezes the artwork
//       rather than cropping it, the same bargain a frustum already makes. All shapes in a
//       chain have the same side count, so s is decided by which CHAIN VERTEX a shape's
//       vertex lands on: vertex i of a segment is chain vertex vertexBase +/- i, and s there
//       is that number over n. A shape turned by whole panels gets a different vertexBase;
//       a shape turned over walks the chain backwards.
//
// wrapJointVertexStep() derives all of this from the pose drawShapeTree() applies, and the
// self test checks the result against the posed vertices themselves.
//
// CURRENT SHAPE
//
// The draw code reads globals and is not told whose they are. _drawingShapeIdx is no use:
// the 3D view and the PDF texture pass never set it. They do all go through
// loadGlobalsFrom(), so that is what records the shape. A chain is rebuilt on each query
// rather than cached, so it cannot outlive an edit to a connection or a shape.

int _loadedShapeIdx = -1;   // the shape whose globals are loaded; set by loadGlobalsFrom()

// How far a joint may sit from a whole number of panels and still count as aligned.
final float WRAP_JOINT_ALIGN_TOLERANCE = 0.02;

class WrapSegment {
  int shapeIdx;
  boolean reversed;            // this shape's bottom-to-top runs against the chain's
  int vertexBase;              // the chain vertex this shape's own vertex 0 sits on
  float tBotRim, tTopRim;      // chain t at this shape's own rims
  float tBotPole, tTopPole;    // chain t at this shape's own lid centres; meaningless if hidden
  boolean botHidden, topHidden;  // lid buried inside a joint
}

class WrapChain {
  ArrayList<WrapSegment> segs = new ArrayList<WrapSegment>();  // chain bottom to chain top
  float runMM;                 // the whole t budget
  float perimMM;               // wall perimeter, averaged over the run

  WrapSegment segmentOf(int shapeIdx) {
    for (WrapSegment s : segs) {
      if (s.shapeIdx == shapeIdx) return s;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Which joints carry a wrap
// ---------------------------------------------------------------------------

// ShapeSpec twin of wrapFrameAvailable(). Kresling is not per shape, so that one is the global.
boolean wrapShapeEligible(int idx) {
  if (shapes == null || idx < 0 || idx >= shapes.size()) return false;
  ShapeSpec s = shapes.get(idx);
  return s.sideTextureMode == TEX_WRAP_FULL && lidFrameAvailable(s) && !kreslingMode;
}

// The parent vertex that the child's vertex 0 lands on, as a real number of panels. A whole
// number means the corners meet.
//
// Vertices sit at angle phi0 + i * step in the xz plane, and the pose changes that angle
// the way drawShapeTree() and applyFaceTransform3D() apply it, child outwards:
//   rotateX(PI) when flipped    phi -> -phi
//   rotateY(spin)               phi -> phi - spin
//   mounting on a bottom lid    phi -> -phi
float wrapJointVertexStep(Connection c) {
  int n = childMateSides(c);
  float step = TWO_PI / n;
  float phi0 = -HALF_PI - step / 2.0;
  float a = c.childFlipped ? -phi0 : phi0;
  a -= radians(c.spinDeg);
  if (!c.onTopLid()) a = -a;
  return (a - phi0) / step;
}

// Two identical polygons mate in n rotations. Anywhere else the rims do not coincide, and an
// odd-sided child that has been turned over lands half a panel out until it is spun.
boolean wrapJointAligned(Connection c) {
  float step = wrapJointVertexStep(c);
  return abs(step - round(step)) <= WRAP_JOINT_ALIGN_TOLERANCE;
}

// Does the child's own winding run against its parent's?
boolean wrapJointReverses(Connection c) {
  return c.onTopLid() == c.childFlipped;
}

// Two children on one lid would both claim to be the continuation of the wall below it.
boolean wrapJointContested(Connection c) {
  int count = 0;
  for (Connection o : connections) {
    if (o.continueWrap && o.onFace(c.parentShapeIdx, c.parentFaceKind, 0)) count++;
  }
  return count > 1;
}

boolean wrapJointLive(Connection c) {
  if (c == null || !c.continueWrap || !c.onLid() || !connectionNeedsNoCut(c)) return false;
  if (!wrapShapeEligible(c.parentShapeIdx) || !wrapShapeEligible(c.childShapeIdx)) return false;
  return !wrapJointContested(c) && wrapJointAligned(c);
}

// The live joint on one lid of a shape, or null.
Connection wrapJointOn(int shapeIdx, int lidKind) {
  for (Connection c : childrenOf(shapeIdx)) {
    if (c.parentFaceKind == lidKind && wrapJointLive(c)) return c;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Building a chain
// ---------------------------------------------------------------------------

float wrapEdgeMM(ShapeSpec s, boolean isTop) {
  return (isTop ? s.cylinder.x : s.cylinder.y) / max(3, s.nSides);
}

float wrapApothemMM(ShapeSpec s, boolean isTop) {
  return (wrapEdgeMM(s, isTop) / 2.0) / tan(PI / (float)max(3, s.nSides));
}

// Mirrors the cylinderH_px formula in Param.pde.
float wrapSlantMM(ShapeSpec s) {
  return sqrt(sq(s.cylinder.z) + sq(wrapEdgeMM(s, false) - wrapEdgeMM(s, true)));
}

// Walks one way out of a shape, through the far lid of each shape it reaches.
void wrapChainWalk(WrapChain chain, WrapSegment from, int lidKind, boolean upwards) {
  WrapSegment cur = from;
  int kind = lidKind;
  for (int guard = 0; guard < CONNECTION_MAX_DEPTH; guard++) {
    Connection c = wrapJointOn(cur.shapeIdx, kind);
    if (c == null) return;
    int n = childMateSides(c);
    int p = round(wrapJointVertexStep(c));

    WrapSegment next = new WrapSegment();
    next.shapeIdx   = c.childShapeIdx;
    next.reversed   = cur.reversed != wrapJointReverses(c);
    next.vertexBase = Math.floorMod(cur.vertexBase + (cur.reversed ? -p : p), n);

    // Both lids at the joint are buried. childFlipped means the child mates by its top.
    if (kind == FACE_LID_TOP) cur.topHidden = true; else cur.botHidden = true;
    if (c.childFlipped) next.topHidden = true; else next.botHidden = true;

    if (upwards) chain.segs.add(next); else chain.segs.add(0, next);
    cur  = next;
    kind = c.childFlipped ? FACE_LID_BOT : FACE_LID_TOP;
  }
}

// Shares out t along the finished chain.
void wrapChainAssignT(WrapChain chain) {
  int count = chain.segs.size();
  WrapSegment first = chain.segs.get(0), last = chain.segs.get(count - 1);
  float capLow  = wrapApothemMM(shapes.get(first.shapeIdx), first.reversed);
  float capHigh = wrapApothemMM(shapes.get(last.shapeIdx), !last.reversed);

  float run = capLow + capHigh;
  for (WrapSegment s : chain.segs) run += wrapSlantMM(shapes.get(s.shapeIdx));
  chain.runMM = run;
  if (run <= 0) return;

  // The artwork gets one width, so the source aspect can only suit an average shape.
  float wallRun = 0, weighted = 0;
  for (WrapSegment s : chain.segs) {
    ShapeSpec spec = shapes.get(s.shapeIdx);
    float slant = wrapSlantMM(spec);
    wallRun  += slant;
    weighted += slant * (spec.cylinder.x + spec.cylinder.y) / 2.0;
  }
  chain.perimMM = wallRun <= 0 ? 0 : weighted / wallRun;

  float acc = capLow;
  for (int i = 0; i < count; i++) {
    WrapSegment s = chain.segs.get(i);
    float low  = acc / run;
    acc += wrapSlantMM(shapes.get(s.shapeIdx));
    float high = acc / run;
    float poleLow  = (i == 0) ? 0 : low;
    float poleHigh = (i == count - 1) ? 1 : high;

    s.tBotRim  = s.reversed ? high : low;
    s.tTopRim  = s.reversed ? low : high;
    s.tBotPole = s.reversed ? poleHigh : poleLow;
    s.tTopPole = s.reversed ? poleLow : poleHigh;
  }
}

// The chain a shape belongs to. A lone shape comes back as a chain of one.
WrapChain wrapChainFor(int idx) {
  int anchor = idx;
  for (int guard = 0; guard < CONNECTION_MAX_DEPTH; guard++) {
    Connection up = parentOf(anchor);
    if (!wrapJointLive(up)) break;
    anchor = up.parentShapeIdx;
  }

  WrapChain chain = new WrapChain();
  WrapSegment start = new WrapSegment();
  start.shapeIdx = anchor;
  chain.segs.add(start);
  wrapChainWalk(chain, start, FACE_LID_TOP, true);
  wrapChainWalk(chain, start, FACE_LID_BOT, false);
  wrapChainAssignT(chain);
  return chain;
}

// ---------------------------------------------------------------------------
// What the draw code asks
// ---------------------------------------------------------------------------

// The loaded shape's chain, or null when it wraps alone. Null is what sends WrapFrame.pde
// down its single-shape path, so a lone shape reads the same numbers it always did.
WrapChain wrapChainLoaded() {
  if (connections == null || connections.isEmpty()) return null;
  if (shapes == null || _loadedShapeIdx < 0 || _loadedShapeIdx >= shapes.size()) return null;
  WrapChain chain = wrapChainFor(_loadedShapeIdx);
  return chain.segs.size() < 2 ? null : chain;
}

WrapSegment wrapSegmentLoaded() {
  WrapChain chain = wrapChainLoaded();
  return chain == null ? null : chain.segmentOf(_loadedShapeIdx);
}

// s at each end of each panel, for a segment of n panels: {left[], right[]}.
float[][] wrapSegmentPanelEndsS(WrapSegment seg, int n) {
  float[][] out = new float[2][n];
  for (int i = 0; i < n; i++) {
    float low = seg.reversed ? Math.floorMod(seg.vertexBase - i - 1, n)
                             : Math.floorMod(seg.vertexBase + i, n);
    out[0][i] = (seg.reversed ? low + 1 : low) / (float)n;
    out[1][i] = (seg.reversed ? low : low + 1) / (float)n;
  }
  return out;
}

// ---------------------------------------------------------------------------
// The stack, for the sidebar
// ---------------------------------------------------------------------------
//
// A chain is what is live; a stack is what COULD be one: every shape reachable through
// matching lids, whether or not those joints have opted in. The sidebar works on the stack,
// so that a shape added later shows the toggle as off rather than being silently left out.

boolean wrapJointMatches(Connection c) {
  return c != null && c.onLid() && connectionNeedsNoCut(c);
}

ArrayList<Connection> wrapStackJoints(int idx) {
  ArrayList<Connection> out = new ArrayList<Connection>();
  java.util.HashSet<Integer> seen = new java.util.HashSet<Integer>();
  seen.add(idx);
  boolean grew = true;
  while (grew) {
    grew = false;
    for (Connection c : connections) {
      if (out.contains(c) || !wrapJointMatches(c)) continue;
      if (seen.contains(c.parentShapeIdx) || seen.contains(c.childShapeIdx)) {
        out.add(c);
        seen.add(c.parentShapeIdx);
        seen.add(c.childShapeIdx);
        grew = true;
      }
    }
  }
  return out;
}

boolean wrapStackOn(int idx) {
  ArrayList<Connection> joints = wrapStackJoints(idx);
  for (Connection c : joints) {
    if (!c.continueWrap) return false;
  }
  return !joints.isEmpty();
}

// One image and one mode for the whole stack. wrapImg comes from the globals and not the
// ShapeSpec: a shape that has never been given an image only has the fallback setParams()
// loaded into the global, and that is the picture on screen. Turning it off leaves every
// shape holding the image, wrapping alone.
void setWrapAcrossStack(boolean on) {
  if (shapes == null || selectedShapeIdx < 0 || selectedShapeIdx >= shapes.size()) return;
  pushConnectionUndo("");
  for (Connection c : wrapStackJoints(selectedShapeIdx)) {
    c.continueWrap = on;
    if (!on) continue;
    wrapSnapJointSpin(c);
    for (int idx : new int[]{ c.parentShapeIdx, c.childShapeIdx }) {
      ShapeSpec s = shapes.get(idx);
      s.sideTextureMode  = TEX_WRAP_FULL;
      s.activeTextureTab = TEX_TAB_WRAP;
      s.wrapImg          = wrapImg;
      s.topLidEnabled    = true;   // same reason as enableLidsForWrap()
      s.bottomLidEnabled = true;
    }
  }
}

// Writes the selected shape's new image to everything chained to it. An image left on one
// shape alone would show as a break at the joint.
void wrapShareImage(PImage img) {
  if (shapes == null || selectedShapeIdx < 0 || selectedShapeIdx >= shapes.size()) return;
  for (WrapSegment s : wrapChainFor(selectedShapeIdx).segs) {
    shapes.get(s.shapeIdx).wrapImg = img;
  }
}

String wrapShapeName(int idx) {
  ShapeSpec s = shapes.get(idx);
  return (s.label != null && !s.label.isEmpty()) ? s.label : ("Shape " + (idx + 1));
}

// Why a stack that has been switched on is not one continuous wrap. "" when it is.
String wrapStackProblem(int idx) {
  if (!wrapStackOn(idx)) return "";
  for (Connection c : wrapStackJoints(idx)) {
    if (wrapJointLive(c)) continue;
    if (wrapJointContested(c)) return "Two shapes share one lid";
    for (int end : new int[]{ c.parentShapeIdx, c.childShapeIdx }) {
      if (shapes.get(end).sideTextureMode != TEX_WRAP_FULL) return wrapShapeName(end) + " is not on Wrap";
      if (!wrapShapeEligible(end)) return wrapShapeName(end) + " cannot be wrapped";
    }
    return "A joint is not lined up";
  }
  return "";
}

// ---------------------------------------------------------------------------
// Keeping joints on the panels
// ---------------------------------------------------------------------------

// The spin keys' step. A wrapped joint moves a panel at a time: 5 degrees would leave the
// rims apart, and on a pentagon it could never land on one again.
float connectionSpinStepDeg(Connection c) {
  if (c.continueWrap && wrapJointMatches(c)) return 360.0 / childMateSides(c);
  return 5;
}

// Moves a wrapped joint's spin to the nearest position where the corners meet.
// wrapJointVertexStep() falls as spin rises on a top lid and rises with it on a bottom lid.
void wrapSnapJointSpin(Connection c) {
  if (!c.continueWrap || !wrapJointMatches(c)) return;
  float step = wrapJointVertexStep(c);
  float off = (step - round(step)) * 360.0 / childMateSides(c);
  c.spinDeg += c.onTopLid() ? off : -off;
}
