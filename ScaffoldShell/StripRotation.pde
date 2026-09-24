// STRIPROTATION.PDE - The bent-strip texture: its source image, and rotating it
//
// The strip renderers in textures_triangles.pde stretch the image to exactly fit the strip:
// uScale = img.width / (total perimeter) across, and v * img.height up the panel. The whole
// image always covers the whole strip, by design — "zooming in" on a strip means handing it
// a smaller source image, which is what the cropper does.
//
// Because the fit is derived from the image's own dimensions, rotating the SOURCE BITMAP is
// all that is needed — the strip re-fits to the new aspect on its own and not one line of
// the four strip renderers has to change. (Spinning the UVs instead would drag samples
// outside the image, and textureWrap(CLAMP) would smear the edge pixels across the panel.)
//
// stripImg stays the image everything else reads, so the ~36 existing read sites are
// untouched; stripImgSrc holds the unrotated original that the rotation is derived from.
//
// ---------------------------------------------------------------------------
// WHERE STRIP STATE LIVES, AND WHY IT IS NOT THE GLOBALS
// ---------------------------------------------------------------------------
// stripImg / stripImgSrc / uiStripRotation are draw-time GLOBALS, and draw() reloads them
// from a ShapeSpec for every shape, every frame (see the multi-shape loop). A global is
// therefore a scratch register with a lifetime of one shape, not somewhere an edit can be
// kept. An edit written only to a global is silently reverted on the next frame, which
// looks exactly like the edit having done nothing at all.
//
// That is what broke cropping and rotation: the cropper called setStripSource() and stopped
// there, and the rotated bitmap was rebuilt into the global and then immediately overwritten
// by the next loadGlobalsFrom(). So:
//
//   - every UI path that changes the artwork calls applyStripEdit(), which writes THROUGH
//     to the selected shape;
//   - the rotation is derived per shape, into each shape's own stripImg, before the draw
//     loop runs — so it is already in place whichever shape is loaded next.
//
// setStripSource() remains for the one caller that legitimately wants globals only: the
// default-texture load inside setParams(), which runs with another shape's globals loaded
// and must not write into the selected shape.

float uiStripRotation = 0;      // degrees, for the shape currently in the globals
PImage stripImgSrc = null;      // unrotated original for the shape currently in the globals

// Rotates an image about its centre onto a canvas grown to contain the rotated bounds, so
// nothing is cropped. Multiples of 90 come out pixel-exact and fill the canvas completely;
// other angles leave transparent corners, which the strip renders as gaps — that is honest
// rather than hidden, and 90-degree steps are the case that matters for sideways artwork.
PImage rotateImageCentred(PImage src, float deg) {
  float r = radians(deg);
  float ca = abs(cos(r)), sa = abs(sin(r));
  // cos(radians(90)) is about -4.4e-8, not 0, so the ceil() below would otherwise add a
  // one-pixel transparent sliver at every right angle — which the strip stretches into a
  // visible seam. Snap the near-zero term so quarter turns stay pixel-exact.
  if (ca < 1e-6) ca = 0;
  if (sa < 1e-6) sa = 0;
  int w = max(1, ceil(src.width * ca + src.height * sa));
  int h = max(1, ceil(src.width * sa + src.height * ca));
  PGraphics buf = createGraphics(w, h, P2D);
  buf.beginDraw();
  buf.clear();
  buf.imageMode(CENTER);
  buf.translate(w / 2.0, h / 2.0);
  buf.rotate(r);
  buf.image(src, 0, 0);
  buf.endDraw();
  return buf.get();
}

// ---------------------------------------------------------------------------
// Per-frame derivation
// ---------------------------------------------------------------------------

// Brings every shape's stripImg up to date with its own source and angle, then refreshes
// the globals from the selected shape.
//
// MUST be called from the top of draw(), before the multi-shape loop, and never from inside
// a render: it may call createGraphics(), which cannot safely run nested inside another
// beginDraw() or inside the beginRecord() used for PDF/SVG export. Calling it there also
// means every rotated image is already built by the time an export runs.
void updateStripRotation() {
  if (shapes == null || shapes.isEmpty()) return;

  // Every shape, not just the selected one: a shape drawn later in the frame needs its own
  // rotation applied too, and it is never "current" at the moment the user turns the dial.
  for (int i = 0; i < shapes.size(); i++) updateStripRotationFor(shapes.get(i));

  ShapeSpec sel = shapes.get(constrain(selectedShapeIdx, 0, shapes.size() - 1));
  stripImg    = sel.stripImg;
  stripImgSrc = sel.stripImgSrc;
}

// Rebuilds one shape's stripImg from its stripImgSrc and stripRotation, if anything changed.
void updateStripRotationFor(ShapeSpec s) {
  if (s == null) return;

  // Adopt an image that was assigned straight into stripImg (an older shape, or a JSON
  // import) as the unrotated original.
  if (s.stripImgSrc == null && s.stripImg != null && s.stripImg != s._stripRotOut) {
    s.stripImgSrc = s.stripImg;
  }
  if (s.stripImgSrc == null) {
    s._stripRotOut     = null;
    s._stripRotApplied = -1;
    s._stripRotSrcUsed = null;
    return;
  }

  float a = ((s.stripRotation % 360) + 360) % 360;

  // Nothing to do when the angle and source are unchanged AND stripImg still holds our
  // output — the third test catches stripImg being replaced from somewhere else.
  if (a == s._stripRotApplied && s._stripRotSrcUsed == s.stripImgSrc
      && s.stripImg == s._stripRotOut) return;

  s.stripImg         = (a == 0) ? s.stripImgSrc : rotateImageCentred(s.stripImgSrc, a);
  s._stripRotOut     = s.stripImg;
  s._stripRotApplied = a;
  s._stripRotSrcUsed = s.stripImgSrc;
}

// ---------------------------------------------------------------------------
// Changing the artwork
// ---------------------------------------------------------------------------

// Every UI path that changes the strip artwork goes through here: loading a file, applying
// a crop, clearing it. Writes the globals AND the selected shape, so the edit survives the
// next frame's loadGlobalsFrom(). Pass null to clear.
//
// resetRotation is for edits taken from what the user can already see — a crop is made from
// the rotated image on screen, so keeping the angle would apply it twice.
void applyStripEdit(PImage img, boolean resetRotation) {
  setStripSource(img, resetRotation);

  if (shapes == null || shapes.isEmpty()) return;
  ShapeSpec s = shapes.get(constrain(selectedShapeIdx, 0, shapes.size() - 1));
  s.stripImgSrc      = stripImgSrc;
  s.stripImg         = stripImg;
  s.stripRotation    = uiStripRotation;
  s._stripRotOut     = null;   // force the next updateStripRotation() to rebuild
  s._stripRotApplied = -1;
  s._stripRotSrcUsed = null;
}

// Globals only. The default-texture load in setParams() is the one caller that wants this:
// it runs once per shape inside the draw loop, with that shape's globals loaded, so writing
// through to the SELECTED shape would drop another shape's artwork onto it. Everything the
// user drives should call applyStripEdit() instead.
void setStripSource(PImage img, boolean resetRotation) {
  stripImgSrc = img;
  stripImg    = img;
  if (resetRotation) uiStripRotation = 0;
}
