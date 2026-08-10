//----------------------------------------------------------------------------------
// DISTANCE OVERLAY  (preview only, toggleable)
// Draws light dimension annotations over the pattern: each main piece's bounding box +
// size, the gaps between stacked pieces, and — for the base — each mounting cutout's
// distance to the base edges and to the other cutout. Never drawn into the export.
//----------------------------------------------------------------------------------

boolean showDistances = false;

// Captured piece bounding boxes in mm {x, y, w, h}; null when not captured this frame.
float[] _bbStrip = null, _bbBotLid = null, _bbTopLid = null;
boolean _piecesCapturedThisFrame = false;

final color DIM_COL = 0xFFC828A0;  // magenta

// Capture the main-piece bounding boxes (called once per frame from drawPlan, in px).
void captureMainPieceBBoxes(float stripW, float stripH,
                            float botX, float botY, float botW, float botH,
                            float topX, float topY, float topW, float topH) {
  float s = MM_current;
  _bbStrip  = new float[]{0,      0,      stripW / s, stripH / s};
  _bbBotLid = new float[]{botX/s, botY/s, botW / s,   botH / s};
  _bbTopLid = new float[]{topX/s, topY/s, topW / s,   topH / s};
  _piecesCapturedThisFrame = true;
}

// --- helpers (all coords are pattern px; labels are mm) ---

void _dimText(float xpx, float ypx, float mm) {
  pushStyle();
  fill(DIM_COL);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(9 / SCREEN_SCALE);
  text(nf(mm, 0, 1), xpx, ypx);
  popStyle();
}

// Dimension segment between two points, labelled with its length in mm.
void _dimSeg(float x1, float y1, float x2, float y2) {
  stroke(DIM_COL);
  strokeWeight(1 / SCREEN_SCALE);
  line(x1, y1, x2, y2);
  _dimText((x1 + x2) / 2, (y1 + y2) / 2, dist(x1, y1, x2, y2) / MM_current);
}

// Thin bbox outline + "W x H" size label (bb in mm {x,y,w,h}).
void _pieceBox(float[] bb, String label) {
  if (bb == null) return;
  float s = MM_current;
  float x = bb[0]*s, y = bb[1]*s, w = bb[2]*s, h = bb[3]*s;
  pushStyle();
  noFill();
  stroke(DIM_COL);
  strokeWeight(1 / SCREEN_SCALE);
  rect(x, y, w, h);
  fill(DIM_COL);
  noStroke();
  textAlign(LEFT, BOTTOM);
  textSize(9 / SCREEN_SCALE);
  text(label + "  " + nf(bb[2], 0, 1) + " x " + nf(bb[3], 0, 1), x + 2/SCREEN_SCALE, y - 2/SCREEN_SCALE);
  popStyle();
}

// Vertical gap between piece a (above) and piece b (below), drawn at their overlapping x.
void _vGap(float[] a, float[] b) {
  if (a == null || b == null) return;
  float s = MM_current;
  float aBottom = (a[1] + a[3]) * s;
  float bTop    = b[1] * s;
  if (bTop <= aBottom) return;                 // overlapping / no gap
  float x = (max(a[0], b[0]) + min(a[0]+a[2], b[0]+b[2])) / 2.0 * s;  // shared x
  _dimSeg(x, aBottom, x, bTop);
}

void drawDistanceOverlay() {
  if (!showDistances) return;
  pushStyle();
  rectMode(CORNER);
  float s = MM_current;

  // 1+2. Main pieces (bbox + size) and gaps — only when captured this frame (not base-only)
  if (_piecesCapturedThisFrame) {
    _pieceBox(_bbStrip,  "strip");
    _pieceBox(_bbBotLid, "bot lid");
    _pieceBox(_bbTopLid, "top lid");
    _vGap(_bbStrip, _bbBotLid);
    _vGap(_bbStrip, _bbTopLid);
  }

  // 3. Base: bbox + size, gap from the lids, and mounting-cutout distances
  if (_baseDrawnValid && (baseEnabled || baseOnly)) {
    float[] baseBB = { _baseBBoxX, _baseBBoxY, _baseBBoxW, _baseBBoxH };
    _pieceBox(baseBB, "base");
    _vGap(_bbBotLid, baseBB);

    // base edges (px)
    float bx = _baseBBoxX * s, by = _baseBBoxY * s;
    float bw = _baseBBoxW * s, bh = _baseBBoxH * s;
    float bcx = bx + bw / 2.0, bcy = by + bh / 2.0;   // base centre (px)

    ensureBaseSlitOffsets();
    // per-cutout distances to the 4 base edges
    for (int i = 0; i < baseSlitOffsets.size(); i++) {
      PVector off = baseSlitOffsets.get(i);
      float cx = bcx + off.x * s, cy = bcy + off.y * s;
      float r  = baseSlitRadiusMM(i) * s;
      pushStyle(); stroke(DIM_COL); strokeWeight(1/SCREEN_SCALE); noFill();
      ellipse(cx, cy, 2*r, 2*r);       // mark the cutout extent
      popStyle();
      _dimSeg(cx, cy, bx, cy);         // to left edge
      _dimSeg(cx, cy, bx + bw, cy);    // to right edge
      _dimSeg(cx, cy, cx, by);         // to top edge
      _dimSeg(cx, cy, cx, by + bh);    // to bottom edge
    }
    // cutout-to-cutout
    if (baseSlitOffsets.size() >= 2) {
      PVector a = baseSlitOffsets.get(0), b = baseSlitOffsets.get(1);
      _dimSeg(bcx + a.x*s, bcy + a.y*s, bcx + b.x*s, bcy + b.y*s);
    }
  }

  popStyle();
}
