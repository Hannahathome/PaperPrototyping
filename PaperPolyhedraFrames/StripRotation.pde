// STRIPROTATION.PDE - Rotating the bent-strip texture
//
// The strip renderers in textures_triangles.pde stretch the image to exactly fit the strip:
// uScale = img.width / (total perimeter) across, and v * img.height up the panel. Because
// the fit is derived from the image's own dimensions, rotating the SOURCE BITMAP is all
// that is needed — the strip re-fits to the new aspect on its own and not one line of the
// four strip renderers has to change. (Spinning the UVs instead would drag samples outside
// the image, and textureWrap(CLAMP) would smear the edge pixels across the panel.)
//
// stripImg stays the image everything else reads, so the ~36 existing read sites are
// untouched; stripImgSrc holds the unrotated original that the rotation is derived from.
// Both are per-shape, mirrored through ShapeSpec like the other texture fields.

float uiStripRotation = 0;      // degrees, per shape
PImage stripImgSrc = null;      // unrotated original for the current shape

PImage _stripRotOut = null;     // the image we last wrote into stripImg
float  _stripRotApplied = -1;   // the angle that produced it
PImage _stripRotSrcUsed = null; // the source it was produced from

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

// Rebuilds stripImg from stripImgSrc whenever the source or the angle changes.
//
// MUST be called from the top of draw(), never from inside a render: it may call
// createGraphics(), which cannot safely run nested inside another beginDraw() or inside the
// beginRecord() used for PDF/SVG export. Calling it there also means the rotated image is
// already built by the time an export runs.
void updateStripRotation() {
  // Adopt an image that was assigned straight into stripImg (first load, or a shape whose
  // source was never captured) as the unrotated original.
  if (stripImgSrc == null && stripImg != null && stripImg != _stripRotOut) {
    stripImgSrc = stripImg;
  }
  if (stripImgSrc == null) {
    _stripRotOut = null;
    _stripRotApplied = -1;
    return;
  }

  float a = ((uiStripRotation % 360) + 360) % 360;

  // Nothing to do when the angle and source are unchanged AND stripImg still holds our
  // output — the second test catches a shape switch swapping stripImg underneath us.
  if (a == _stripRotApplied && _stripRotSrcUsed == stripImgSrc && stripImg == _stripRotOut) return;

  stripImg = (a == 0) ? stripImgSrc : rotateImageCentred(stripImgSrc, a);
  _stripRotOut = stripImg;
  _stripRotApplied = a;
  _stripRotSrcUsed = stripImgSrc;
}

// Call after assigning a brand-new strip image (file load, crop) so the rotation is
// re-derived from it rather than from the previous source.
void setStripSource(PImage img, boolean resetRotation) {
  stripImgSrc = img;
  stripImg    = img;
  _stripRotOut = null;
  _stripRotApplied = -1;
  _stripRotSrcUsed = null;
  if (resetRotation) uiStripRotation = 0;
}
