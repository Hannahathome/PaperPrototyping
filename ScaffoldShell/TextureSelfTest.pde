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
