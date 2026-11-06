//----------------------------------------------------------------------
// TextureSelfTest.pde - Regression checks for per-shape texture state
//
// The sketch keeps draw-time state in globals and swaps them per shape through
// loadGlobalsFrom() / saveGlobalsTo(). Every frame, draw() walks every shape and calls
// loadGlobalsFrom() on it. So a texture edit written ONLY to a global survives exactly
// until the next frame, and then vanishes -- silently, with no error, looking for all the
// world like the edit did nothing.
//
// That is a whole class of bug rather than one bug, and it is invisible to a compiler and
// to any test that does not simulate a frame. These checks simulate one.
//
// Enable with TEXTURE_SELFTEST = true and run the sketch: it prints a pass/fail table and
// exits. Same shape as AUDIT_MODE and FRAME_SELFTEST.
//----------------------------------------------------------------------

final boolean TEXTURE_SELFTEST = false;   // flip to true to run the checks

int _ttChecks = 0, _ttFails = 0;

void textureSelfTestRun() {
  println("[TEXTURE SELFTEST]");
  textureTestStripPersistence();
  textureTestCropperEndToEnd();
  textureTestWrapChain();
  textureTestWrapStack();
  textureTestWrapOrientation();
  println("[TEXTURE SELFTEST] " + (_ttChecks - _ttFails) + "/" + _ttChecks + " passed"
        + (_ttFails == 0 ? "" : "   <-- " + _ttFails + " FAILED"));
  exit();
}

void ttCheck(String what, boolean ok, String detail) {
  _ttChecks++;
  if (!ok) _ttFails++;
  println("  [" + (ok ? "PASS" : "FAIL") + "] " + what + (detail.isEmpty() ? "" : "   " + detail));
}

// Stands in for one pass of draw(): the multi-shape loop loads every shape's globals in
// turn, then the selected shape's are restored at the end. Anything a texture edit left
// only in a global is gone by the time this returns.
void ttSimulateFrame() {
  updateStripRotation();
  for (int i = 0; i < shapes.size(); i++) {
    loadGlobalsFrom(shapes.get(i));
    setParams(false);
  }
  loadGlobalsFrom(shapes.get(selectedShapeIdx));
  setParams(false);
}

PImage ttMakeImage(int w, int h, color c) {
  PGraphics g = createGraphics(w, h, P2D);
  g.beginDraw();
  g.background(c);
  g.endDraw();
  return g.get();
}

void textureTestStripPersistence() {
  println(" strip texture survives a frame");

  // Two shapes, because the draw loop's per-shape swap is what destroys unsaved edits.
  if (shapes == null || shapes.isEmpty()) { ttCheck("shapes ready", false, ""); return; }
  while (shapes.size() < 2) shapes.add(shapeFromCurrentGlobals());
  selectedShapeIdx = 0;
  loadGlobalsFrom(shapes.get(0));
  setParams(false);

  // --- loading an image ---
  PImage loaded = ttMakeImage(400, 100, color(200, 40, 40));
  applyStripEdit(loaded, true);
  sideTextureMode = TEX_STRIP_BENT;
  saveGlobalsTo(shapes.get(0));
  ttSimulateFrame();
  ttCheck("a loaded strip image survives", stripImg != null && stripImg.width == 400,
          stripImg == null ? "null" : stripImg.width + "x" + stripImg.height);

  // --- cropping / zooming in ---
  // The cropper hands back a smaller image; the strip stretches whatever it is given, so a
  // crop IS the zoom. If the crop does not survive, zooming appears to do nothing.
  PImage cropped = ttMakeImage(120, 60, color(40, 200, 40));
  applyStripEdit(cropped, true);
  ttSimulateFrame();
  ttCheck("a crop survives", stripImg != null && stripImg.width == 120,
          stripImg == null ? "null" : stripImg.width + "x" + stripImg.height
            + (stripImg != null && stripImg.width == 400 ? "  <-- reverted to the uncropped image" : ""));

  // --- rotating ---
  // A quarter turn swaps the bitmap's dimensions, which is what the renderer re-fits to.
  uiStripRotation = 90;
  shapes.get(selectedShapeIdx).stripRotation = 90;
  ttSimulateFrame();
  ttCheck("a 90 degree rotation survives",
          stripImg != null && stripImg.width == 60 && stripImg.height == 120,
          stripImg == null ? "null" : stripImg.width + "x" + stripImg.height
            + (stripImg != null && stripImg.width == 120 ? "  <-- still unrotated" : ""));

  // --- rotation is not rebuilt every frame ---
  // The rotated bitmap is derived, so it should be cached. Rebuilding it per frame means a
  // createGraphics() per frame for as long as the angle is non-zero.
  PImage afterFirst = stripImg;
  ttSimulateFrame();
  ttSimulateFrame();
  ttCheck("the rotated bitmap is cached, not rebuilt each frame", stripImg == afterFirst,
          stripImg == afterFirst ? "" : "a new PImage was built");

  // --- per-shape independence ---
  // Shape 2 has its own (unset) strip. Selecting it must not show shape 1's artwork, and
  // going back must not have lost it.
  selectedShapeIdx = 1;
  ttSimulateFrame();
  boolean shape2Clean = (stripImg == null || stripImg.width != 60);
  ttCheck("a second shape does not inherit the first's strip", shape2Clean,
          stripImg == null ? "null" : stripImg.width + "x" + stripImg.height);

  selectedShapeIdx = 0;
  ttSimulateFrame();
  ttCheck("going back to the first shape still has its rotated crop",
          stripImg != null && stripImg.width == 60 && stripImg.height == 120,
          stripImg == null ? "null" : stripImg.width + "x" + stripImg.height);

  // --- clearing ---
  applyStripEdit(null, true);
  ttSimulateFrame();
  ttCheck("clearing the strip survives", stripImg == null,
          stripImg == null ? "" : "still " + stripImg.width + "x" + stripImg.height);
}

// The real path a user takes: open the cropper, zoom, apply. The checks above drive
// applyStripEdit() directly, which would still pass if the cropper stopped calling it --
// which is exactly the bug that was there. This one goes through ImageCropper itself.
void textureTestCropperEndToEnd() {
  println(" crop through the cropper, not the helper");
  if (imageCropper == null) { ttCheck("cropper ready", false, ""); return; }

  selectedShapeIdx = 0;
  ShapeSpec s0 = shapes.get(0);
  loadGlobalsFrom(s0);
  setParams(false);

  // Four distinct quadrants, so a zoomed crop cannot accidentally match the original.
  PGraphics g = createGraphics(400, 400, P2D);
  g.beginDraw();
  color[] quad = { color(255, 0, 0), color(0, 0, 255), color(0, 255, 0), color(255, 255, 0) };
  g.noStroke();
  for (int i = 0; i < 4; i++) { g.fill(quad[i]); g.rect((i % 2) * 200, (i / 2) * 200, 200, 200); }
  g.endDraw();
  PImage source = g.get();

  applyStripEdit(source, true);
  sideTextureMode = TEX_STRIP_BENT;
  saveGlobalsTo(s0);
  ttSimulateFrame();

  imageCropper.open(CROP_MODE_STRIP, -1, stripImg);
  ttCheck("cropper opened on the strip", cropperActive, "");

  // Zoom in, the way the scroll wheel does. Only part of the source can now reach the crop.
  imageCropper.imgScale *= 3.0;
  int wantW = int(imageCropper.cropWidth), wantH = int(imageCropper.cropHeight);
  imageCropper.applyAndClose();

  ttCheck("cropper closed", !cropperActive, "");
  ttSimulateFrame();

  ttCheck("the strip is the cropper's output, not the original",
          stripImg != null && stripImg.width == wantW && stripImg.height == wantH,
          stripImg == null ? "null"
            : stripImg.width + "x" + stripImg.height + ", wanted " + wantW + "x" + wantH
              + (stripImg.width == 400 ? "  <-- still the uncropped source" : ""));

  ttCheck("the source image itself is untouched", source.width == 400 && source.height == 400,
          source.width + "x" + source.height);

  // A zoomed crop of a four-colour image shows fewer colours than the whole of it.
  ttCheck("zooming changed what the strip shows",
          stripImg != null && ttDistinctColours(stripImg) < ttDistinctColours(source),
          stripImg == null ? "null"
            : ttDistinctColours(stripImg) + " colours in the crop vs "
              + ttDistinctColours(source) + " in the source");
}

// ---------------------------------------------------------------------------
// One wrap across connected shapes (WrapChain.pde)
// ---------------------------------------------------------------------------

// Reshapes the first `count` shapes into plain wrapped prisms and removes every connection.
void ttResetShapes(int count, int sides) {
  while (shapes.size() < count) shapes.add(shapeFromCurrentGlobals());
  connections.clear();
  for (int i = 0; i < count; i++) {
    ShapeSpec s = shapes.get(i);
    s.nSides = sides;
    s.uiSides = sides;
    s.cylinder = new PVector(sides * 30, sides * 30, 60);
    s.perEdgeMode = false;
    s.cuboidMode = false;
    s.hollowMode = false;
    s.sideTextureMode = TEX_WRAP_FULL;
    s.wrapImg = ttMakeImage(64, 64, color(200, 40, 40));
  }
}

Connection ttJoin(int parent, int child, int kind, boolean flipped, float spin) {
  int idx = addConnection(parent, child, kind, 0, new PVector(0, 0));
  if (idx < 0) return null;
  Connection c = connections.get(idx);
  c.childFlipped = flipped;
  c.spinDeg = spin;
  c.continueWrap = true;
  return c;
}

float ttRingDist(float a, float b) {
  float d = abs(a - b) % 1.0;
  return min(d, 1.0 - d);
}

// The actual claim. Poses the child's vertices with the same transforms drawShapeTree()
// applies, finds the parent vertex each one lands on, and compares the image coordinates
// the two shapes give that one point in space. Nothing here uses wrapJointVertexStep(), so
// a sign error in that derivation cannot pass by agreeing with itself.
void ttCheckJoint(String what, Connection c) {
  if (c == null) { ttCheck(what, false, "the join was refused"); return; }

  WrapChain chain = wrapChainFor(c.parentShapeIdx);
  WrapSegment ps = chain.segmentOf(c.parentShapeIdx), cs = chain.segmentOf(c.childShapeIdx);
  if (ps == null || cs == null) { ttCheck(what, false, "not chained"); return; }

  boolean parentTop = c.onTopLid();
  boolean childTop  = c.childFlipped;

  loadGlobalsFrom(shapes.get(c.parentShapeIdx));
  setParams(false);
  FaceBasis3D b = faceBasis3D(c.parentFaceKind, c.parentFaceIndex);
  PVector[] parentV = getPolygonVertices(parentTop);
  int n = parentV.length;
  float[][] parentS = wrapSegmentPanelEndsS(ps, n);

  loadGlobalsFrom(shapes.get(c.childShapeIdx));
  setParams(false);
  PVector[] childV = getPolygonVertices(childTop);
  float[][] childS = wrapSegmentPanelEndsS(cs, n);

  PMatrix3D m = new PMatrix3D();
  m.apply(b.u.x, -b.n.x, b.v.x, b.c.x,
          b.u.y, -b.n.y, b.v.y, b.c.y,
          b.u.z, -b.n.z, b.v.z, b.c.z,
          0, 0, 0, 1);
  m.rotateY(radians(c.spinDeg));
  m.translate(0, -(shapes.get(c.childShapeIdx).cylinder.z * MM_current) / 2.0, 0);
  if (c.childFlipped) m.rotateX(PI);

  float worstS = 0, worstGap = 0;
  for (int i = 0; i < n; i++) {
    PVector posed = m.mult(childV[i], null);
    int nearest = 0;
    float best = Float.MAX_VALUE;
    for (int j = 0; j < n; j++) {
      float d = PVector.dist(posed, parentV[j]);
      if (d < best) { best = d; nearest = j; }
    }
    worstGap = max(worstGap, best);
    worstS   = max(worstS, ttRingDist(childS[0][i], parentS[0][nearest]));
  }

  float tParent = parentTop ? ps.tTopRim : ps.tBotRim;
  float tChild  = childTop ? cs.tTopRim : cs.tBotRim;
  boolean hidden = (parentTop ? ps.topHidden : ps.botHidden) && (childTop ? cs.topHidden : cs.botHidden);

  ttCheck(what, worstGap < 0.5 && worstS < 0.001 && abs(tParent - tChild) < 0.001 && hidden,
          "gap " + nf(worstGap, 0, 3) + " px, s off " + nf(worstS, 0, 4)
            + ", t off " + nf(abs(tParent - tChild), 0, 4) + (hidden ? "" : ", lids not hidden"));
}

void textureTestWrapChain() {
  println(" one wrap across a stack");

  // --- a lone shape ---
  ttResetShapes(2, 4);
  selectedShapeIdx = 0;
  loadGlobalsFrom(shapes.get(0));
  setParams(false);
  float[][] ends = wrapPanelEndsS();
  float[] span = wrapPanelSpansS();
  boolean same = wrapSegmentLoaded() == null;
  for (int i = 0; i < 4; i++) same = same && ends[0][i] == span[i] && ends[1][i] == span[i + 1];
  ttCheck("a lone shape keeps its own s", same, "");

  // --- opting in ---
  Connection off = ttJoin(0, 1, FACE_LID_TOP, false, 0);
  off.continueWrap = false;
  ttCheck("a joint that has not opted in does not chain", wrapChainFor(0).segs.size() == 1, "");

  // --- the joints ---
  ttResetShapes(2, 4);
  ttCheckJoint("child on a top lid", ttJoin(0, 1, FACE_LID_TOP, false, 0));

  ttResetShapes(2, 6);
  ttCheckJoint("child on a bottom lid", ttJoin(0, 1, FACE_LID_BOT, false, 0));

  ttResetShapes(2, 4);
  ttCheckJoint("turned over, top to top", ttJoin(0, 1, FACE_LID_TOP, true, 0));

  ttResetShapes(2, 6);
  ttCheckJoint("turned over, bottom to bottom", ttJoin(0, 1, FACE_LID_BOT, true, 0));

  ttResetShapes(2, 4);
  ttCheckJoint("spun a quarter turn", ttJoin(0, 1, FACE_LID_TOP, false, 90));

  ttResetShapes(2, 6);
  ttCheckJoint("spun and turned over", ttJoin(0, 1, FACE_LID_TOP, true, 120));

  ttResetShapes(2, 5);
  ttCheckJoint("a pentagon on a pentagon", ttJoin(0, 1, FACE_LID_TOP, false, 0));

  ttResetShapes(2, 5);
  ttCheckJoint("a pentagon turned over and spun into line", ttJoin(0, 1, FACE_LID_TOP, true, 36));

  // --- a frustum on a prism: the rims match, the shapes do not ---
  ttResetShapes(2, 4);
  shapes.get(1).cylinder = new PVector(80, 120, 50);
  ttCheckJoint("a frustum on a prism", ttJoin(0, 1, FACE_LID_TOP, false, 0));

  // --- longer chains ---
  ttResetShapes(3, 4);
  Connection up   = ttJoin(0, 1, FACE_LID_TOP, false, 0);
  Connection next = ttJoin(1, 2, FACE_LID_TOP, true, 90);
  ttCheckJoint("three shapes, lower joint", up);
  ttCheckJoint("three shapes, upper joint", next);

  ttResetShapes(3, 4);
  Connection above = ttJoin(0, 1, FACE_LID_TOP, false, 0);
  Connection below = ttJoin(0, 2, FACE_LID_BOT, false, 90);
  WrapChain mid = wrapChainFor(1);
  ttCheck("the root can sit mid-chain", mid.segs.size() == 3 && mid.segs.get(1).shapeIdx == 0,
          mid.segs.size() + " segments");
  ttCheckJoint("mid-chain, joint above", above);
  ttCheckJoint("mid-chain, joint below", below);

  // --- the budget ---
  WrapSegment first = mid.segs.get(0), last = mid.segs.get(2);
  float ap = wrapApothemMM(shapes.get(0), false);
  float wantRun = 2 * ap + 3 * wrapSlantMM(shapes.get(0));
  ttCheck("t runs from one end cap to the other, skipping hidden lids",
          abs(mid.runMM - wantRun) < 0.01,
          nf(mid.runMM, 0, 2) + " mm, wanted " + nf(wantRun, 0, 2));
  ttCheck("the end caps reach the poles",
          abs((first.reversed ? first.tTopPole : first.tBotPole)) < 0.0001
            && abs((last.reversed ? last.tBotPole : last.tTopPole) - 1) < 0.0001, "");

  // --- the draw code sees it through the loaded shape, whoever loaded it ---
  loadGlobalsFrom(shapes.get(1));
  setParams(false);
  WrapSegment seen = mid.segmentOf(1);
  ttCheck("the wall reads the chain for the loaded shape",
          abs(wrapTBottomRim() - seen.tBotRim) < 0.0001 && abs(wrapTTopRim() - seen.tTopRim) < 0.0001, "");
  ttCheck("the buried lid is reported hidden", wrapCapHidden(false), "");

  // --- what must break a chain ---
  ttResetShapes(2, 5);
  ttJoin(0, 1, FACE_LID_TOP, true, 0);
  ttCheck("a joint half a panel out does not chain", wrapChainFor(0).segs.size() == 1,
          "step " + nf(wrapJointVertexStep(connections.get(0)), 0, 2));

  ttResetShapes(2, 4);
  ttJoin(0, 1, FACE_LID_TOP, false, 45);
  ttCheck("a joint twisted off the panels does not chain", wrapChainFor(0).segs.size() == 1, "");

  ttResetShapes(2, 4);
  ttJoin(0, 1, FACE_LID_TOP, false, 0);
  shapes.get(1).cylinder = new PVector(100, 100, 60);
  ttCheck("rims that stop matching break the chain", wrapChainFor(0).segs.size() == 1, "");

  ttResetShapes(2, 4);
  ttJoin(0, 1, FACE_LID_TOP, false, 0);
  shapes.get(1).sideTextureMode = TEX_STRIP_BENT;
  ttCheck("a shape that left wrap mode breaks the chain", wrapChainFor(0).segs.size() == 1, "");

  ttResetShapes(3, 4);
  ttJoin(0, 1, FACE_LID_TOP, false, 0);
  ttJoin(0, 2, FACE_LID_TOP, false, 0);
  ttCheck("two children on one lid do not chain", wrapChainFor(0).segs.size() == 1, "");

  // --- the printed bottom lid ---
  // Neighbouring edges of the mesh share a spoke, so they must agree on s there, or the
  // printed cap comes apart in wedges and cannot match the wall in any rotation.
  ttResetShapes(2, 6);
  selectedShapeIdx = 0;
  loadGlobalsFrom(shapes.get(0));
  setParams(false);
  float[][] capEnds = wrapPanelEndsS();
  float worstSpoke = 0;
  for (int i = 0; i < 6; i++) {
    float sEnd   = wrapCapEdgeS(i, true, capEnds)[1];
    float sStart = wrapCapEdgeS((i + 1) % 6, true, capEnds)[0];
    worstSpoke = max(worstSpoke, ttRingDist(sEnd, sStart));
  }
  ttCheck("a printed bottom lid has no wedge breaks", worstSpoke < 0.0001, "worst " + nf(worstSpoke, 0, 3));

  connections.clear();
}

// Text has to read the right way round on the finished model. Nothing about continuity can
// catch this: a mirrored wrap is perfectly continuous, and it is how the wrap first shipped.
// So this one goes to the model's own vertices and stands in front of each panel: from
// outside, the image must run left to right, with the top of the image at the top.
void textureTestWrapOrientation() {
  println(" the wrap reads the right way round");

  ttResetShapes(1, 6);
  selectedShapeIdx = 0;
  loadGlobalsFrom(shapes.get(0));
  setParams(false);

  PVector[] bot = getPolygonVertices(false);
  PVector[] top = getPolygonVertices(true);
  int n = bot.length;
  PVector centre = new PVector();
  for (PVector v : bot) centre.add(v);
  centre.div(n);

  float[][] uEnds = wrapPanelEndsU();
  int wrongWay = 0;
  for (int i = 0; i < n; i++) {
    PVector BL = bot[i], BR = bot[(i + 1) % n];
    PVector outward = PVector.sub(PVector.lerp(BL, BR, 0.5), centre);
    // Facing a surface whose normal is n, with up along -y, the viewer's right is n x up.
    PVector viewerRight = outward.cross(new PVector(0, -1, 0));
    float along = PVector.sub(BR, BL).dot(viewerRight);
    if (along * (uEnds[1][i] - uEnds[0][i]) <= 0) wrongWay++;
  }
  ttCheck("from outside, every panel reads left to right", wrongWay == 0, wrongWay + " of " + n + " backwards");

  ttCheck("the top of the image is at the top of the model",
          top[0].y < bot[0].y && wrapImgVFrac(wrapTTopRim()) < wrapImgVFrac(wrapTBottomRim()), "");

  // Three consumers, one projection: the wall takes wrapPanelEndsU(), the caps and the 3D
  // walls take wrapUV(), and if those disagree the artwork breaks at every rim.
  PImage img = shapes.get(0).wrapImg;
  float[][] sEnds = wrapPanelEndsS();
  float worst = 0;
  for (int i = 0; i < n; i++) {
    worst = max(worst, abs(wrapUV(sEnds[0][i], 0.5, img).x / img.width - uEnds[0][i]));
    worst = max(worst, abs(wrapUV(sEnds[1][i], 0.5, img).x / img.width - uEnds[1][i]));
  }
  ttCheck("the wall and the caps agree on the image column", worst < 0.0001, "worst " + nf(worst, 0, 4));
}

// The sidebar's route into all of that: the toggle, the shared image, and the spin keys.
void textureTestWrapStack() {
  println(" wrapping a stack from the sidebar");

  ttResetShapes(3, 4);
  shapes.get(1).sideTextureMode = TEX_STRIP_BENT;
  shapes.get(2).sideTextureMode = TEX_NONE;
  shapes.get(1).wrapImg = null;
  shapes.get(2).wrapImg = ttMakeImage(32, 32, color(0, 0, 200));
  Connection lower = ttJoin(0, 1, FACE_LID_TOP, false, 0);
  Connection upper = ttJoin(1, 2, FACE_LID_TOP, false, 0);
  lower.continueWrap = false;
  upper.continueWrap = false;

  selectedShapeIdx = 0;
  loadGlobalsFrom(shapes.get(0));
  setParams(false);
  ttCheck("the stack is found through the middle shape", wrapStackJoints(2).size() == 2,
          wrapStackJoints(2).size() + " joints");
  ttCheck("the toggle starts off", !wrapStackOn(0), "");

  // --- switching it on ---
  PImage chosen = wrapImg;
  setWrapAcrossStack(true);
  ttSimulateFrame();
  ttCheck("one switch chains the whole stack", wrapChainFor(0).segs.size() == 3,
          wrapChainFor(0).segs.size() + " segments");
  ttCheck("every shape took the selected image and wrap mode",
          shapes.get(1).wrapImg == chosen && shapes.get(2).wrapImg == chosen
            && shapes.get(1).sideTextureMode == TEX_WRAP_FULL && shapes.get(2).sideTextureMode == TEX_WRAP_FULL, "");
  ttCheck("no problem is reported", wrapStackProblem(0).isEmpty(), wrapStackProblem(0));

  // --- the cropper guide ---
  float want = wrapChainFor(0).perimMM / wrapChainFor(0).runMM;
  ttCheck("the crop guide is the stack's shape", abs(wrapIdealAspect() - want) < 0.001,
          nf(wrapIdealAspect(), 0, 3) + ", wanted " + nf(want, 0, 3));

  // --- a crop reaches every shape, and survives a frame ---
  imageCropper.open(CROP_MODE_WRAP, -1, wrapImg);
  ttCheck("the cropper opens with the stack's aspect", abs(imageCropper.cropAspectRatio - want) < 0.001,
          nf(imageCropper.cropAspectRatio, 0, 3));
  imageCropper.imgScale *= 2.0;
  imageCropper.applyAndClose();
  ttSimulateFrame();
  PImage cropped = shapes.get(0).wrapImg;
  ttCheck("a crop reaches every shape in the stack",
          cropped != chosen && shapes.get(1).wrapImg == cropped && shapes.get(2).wrapImg == cropped, "");

  // --- clearing ---
  wrapImg = null;
  saveGlobalsTo(shapes.get(0));
  wrapShareImage(null);
  ttCheck("clearing clears the whole stack", shapes.get(1).wrapImg == null && shapes.get(2).wrapImg == null, "");
  setParams(false);
  saveGlobalsTo(shapes.get(0));
  wrapShareImage(wrapImg);

  // --- breaking the chain ---
  shapes.get(2).sideTextureMode = TEX_STRIP_BENT;
  ttCheck("a shape that left wrap mode is named", wrapStackProblem(0).contains("not on Wrap"), wrapStackProblem(0));
  shapes.get(2).sideTextureMode = TEX_WRAP_FULL;

  // --- undo ---
  pushConnectionUndo("");
  lower.continueWrap = false;
  ttCheck("a new joint reads as off, not as silently left out", !wrapStackOn(0), "");
  ttCheck("an undo snapshot keeps the flag", copyConnection(upper).continueWrap, "");
  setWrapAcrossStack(false);
  ttCheck("off unchains", wrapChainFor(0).segs.size() == 1, "");
  ttCheck("off leaves each shape its image", shapes.get(1).wrapImg != null && shapes.get(2).wrapImg != null, "");

  // --- spin ---
  ttResetShapes(2, 5);
  selectedShapeIdx = 0;
  loadGlobalsFrom(shapes.get(0));
  setParams(false);
  Connection pent = ttJoin(0, 1, FACE_LID_TOP, true, 0);
  pent.continueWrap = false;
  setWrapAcrossStack(true);
  ttCheckJoint("switching on lines up a turned-over pentagon", pent);

  selectedConnectionIdx = 0;
  flipSelectedConnection();
  ttCheckJoint("flipping a wrapped pentagon keeps it lined up", pent);
  flipSelectedConnection();
  ttCheckJoint("and flipping it back", pent);

  float before = pent.spinDeg;
  ttCheck("the spin keys step one panel on a wrapped joint", abs(connectionSpinStepDeg(pent) - 72) < 0.01,
          nf(connectionSpinStepDeg(pent), 0, 1) + " degrees");
  pent.spinDeg += connectionSpinStepDeg(pent);
  wrapSnapJointSpin(pent);
  ttCheckJoint("a one-panel spin stays lined up", pent);
  ttCheck("and it did move", abs(pent.spinDeg - before) > 1, "");

  ttResetShapes(2, 5);
  Connection onBottom = ttJoin(0, 1, FACE_LID_BOT, false, 0);
  onBottom.spinDeg = 13;
  wrapSnapJointSpin(onBottom);
  ttCheckJoint("snapping works on a bottom lid, where spin runs the other way", onBottom);

  ttResetShapes(2, 5);
  Connection plain = ttJoin(0, 1, FACE_LID_TOP, false, 13);
  plain.continueWrap = false;
  wrapSnapJointSpin(plain);
  ttCheck("a joint that is not wrapped keeps its spin and 5 degree step",
          plain.spinDeg == 13 && connectionSpinStepDeg(plain) == 5, "");

  connections.clear();
  selectedConnectionIdx = -1;
}

// Rough count of distinct strong colours, sampled on a grid.
int ttDistinctColours(PImage img) {
  img.loadPixels();
  java.util.HashSet<Integer> seen = new java.util.HashSet<Integer>();
  for (int y = 2; y < img.height - 2; y += max(1, img.height / 24)) {
    for (int x = 2; x < img.width - 2; x += max(1, img.width / 24)) {
      color c = img.pixels[y * img.width + x];
      if (alpha(c) < 200) continue;
      // Quantise hard, so anti-aliased seams do not read as extra colours.
      seen.add((int(red(c) / 128) << 4) | (int(green(c) / 128) << 2) | int(blue(c) / 128));
    }
  }
  return seen.size();
}
