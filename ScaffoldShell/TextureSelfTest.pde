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
