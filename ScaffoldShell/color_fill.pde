// COLOR_FILL.PDE
// Solid colour fill helpers for the PDF export preview.
//
// Functions are called from drawPlan() BEFORE the outline/fold-line drawing so
// that cut-lines always render on top of any fill.  They are skipped when
// bExportingCutFile is true so the SVG cut file stays clean.
//
// Palette: 8 standard colours + a "none / clear" slot used only for the UI.

// ---------------------------------------------------------------------------
// Palette (8 colours, index 0-7)
// ---------------------------------------------------------------------------
final color[] SWATCH_PALETTE = {
  color(230,  57,  70),  // 0 red
  color(244, 162,  97),  // 1 orange
  color(244, 208,  63),  // 2 yellow
  color( 46, 204, 113),  // 3 green
  color( 52, 152, 219),  // 4 blue
  color( 92, 107, 192),  // 5 indigo
  color(155,  89, 182),  // 6 purple
  color(233,  30, 140)   // 7 magenta
};

// ---------------------------------------------------------------------------
// parseHexColor  "#RRGGBB"  →  Processing color int
// ---------------------------------------------------------------------------
color parseHexColor(String hex) {
  try {
    hex = hex.trim().replace("#", "");
    if (hex.length() == 6) {
      int r = unhex(hex.substring(0, 2));
      int g = unhex(hex.substring(2, 4));
      int b = unhex(hex.substring(4, 6));
      return color(r, g, b);
    }
  } catch (Exception e) {
    // fall through to white default
  }
  return color(255);
}

// ---------------------------------------------------------------------------
// drawSolidColorPanels  –  uniform prism (non-perEdgeMode)
// Call from within the same pushMatrix() block as drawTrapezoidsHollow.
// ---------------------------------------------------------------------------
void drawSolidColorPanels(color c) {
  final float topLen    = cellTopL_px;
  final float bottomLen = cellBaseL_px;
  final float h         = cylinderH_px;
  final int   m         = max(1, (cols - 1));
  final int   n         = max(3, (rows - 1));
  final float mh        = h / (float)m;

  pushStyle();
  fill(c);
  noStroke();
  pushMatrix();
  for (int e = 0; e < n; e++) {
    for (int i = 0; i < m; i++) {
      float segTop = ((topLen - bottomLen) * (i + 1) / (float)m) + bottomLen;
      float segBot = ((topLen - bottomLen) *  i      / (float)m) + bottomLen;
      float off    = (segBot - segTop) / 2.0f;

      float xBL = off * i;
      float yBL = mh  * i;
      float xBR = off * i + segBot;
      float yBR = yBL;
      float xTR = off * i + off + segTop;
      float yTR = mh  * i + mh;
      float xTL = off * i + off;
      float yTL = yTR;

      beginShape();
      vertex(xBL, yBL);
      vertex(xBR, yBR);
      vertex(xTR, yTR);
      vertex(xTL, yTL);
      endShape(CLOSE);
    }

    if (e < n - 1) {
      PVector A_r  = new PVector((topLen - bottomLen) / 2.0f, h);
      float   offN = (bottomLen - topLen) / 2.0f;
      PVector B_l  = new PVector(offN, h);
      float rot    = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      translate(bottomLen, 0);
      rotate(rot);
    }
  }
  popMatrix();
  popStyle();
}

// Split-aware version: draw solid color for panels [panelStart..panelEnd)
void drawSolidColorPanels_Range(color c, int panelStart, int panelEnd) {
  final float topLen    = cellTopL_px;
  final float bottomLen = cellBaseL_px;
  final float h         = cylinderH_px;
  final int   m         = max(1, (cols - 1));
  final float mh        = h / (float)m;
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;

  pushStyle();
  fill(c);
  noStroke();
  pushMatrix();
  for (int count = 0; count < nPanels; count++) {
    for (int i = 0; i < m; i++) {
      float segTop = ((topLen - bottomLen) * (i + 1) / (float)m) + bottomLen;
      float segBot = ((topLen - bottomLen) *  i      / (float)m) + bottomLen;
      float off    = (segBot - segTop) / 2.0f;

      float xBL = off * i;
      float yBL = mh  * i;
      float xBR = off * i + segBot;
      float yBR = yBL;
      float xTR = off * i + off + segTop;
      float yTR = mh  * i + mh;
      float xTL = off * i + off;
      float yTL = yTR;

      beginShape();
      vertex(xBL, yBL);
      vertex(xBR, yBR);
      vertex(xTR, yTR);
      vertex(xTL, yTL);
      endShape(CLOSE);
    }

    if (count < nPanels - 1) {
      PVector A_r  = new PVector((topLen - bottomLen) / 2.0f, h);
      float   offN = (bottomLen - topLen) / 2.0f;
      PVector B_l  = new PVector(offN, h);
      float rot    = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      translate(bottomLen, 0);
      rotate(rot);
    }
  }
  popMatrix();
  popStyle();
}

// ---------------------------------------------------------------------------
// drawSolidColorPanelsPerEdge  –  variable prism (perEdgeMode)
// Call from within the same pushMatrix() block as drawTrapezoidsPerEdgeHollow.
// ---------------------------------------------------------------------------
void drawSolidColorPanelsPerEdge(color c) {
  if (edgeTop_px == null || edgeBot_px == null) return;
  final int n = min(edgeTop_px.length, edgeBot_px.length);
  drawSolidColorPanelsPerEdge_Range(c, 0, n);
}

void drawSolidColorPanelsPerEdge_Range(color c, int panelStart, int panelEnd) {
  if (edgeTop_px == null || edgeBot_px == null) return;
  final int   n  = min(edgeTop_px.length, edgeBot_px.length);
  final int   m  = max(1, (cols - 1));
  final float h  = cylinderH_px;
  final float mh = h / (float)m;
  if (panelEnd - panelStart <= 0) return;

  pushStyle();
  fill(c);
  noStroke();
  pushMatrix();
  // No skip — draw starts at local origin (matching drawTrapezoidsPerEdge_Range)
  // Draw panels [panelStart..panelEnd)
  for (int e = panelStart; e < panelEnd && e < n; e++) {
    float topLen    = max(0.001f, edgeTop_px[e]);
    float bottomLen = max(0.001f, edgeBot_px[e]);
    for (int i = 0; i < m; i++) {
      float segTop = ((topLen - bottomLen) * (i + 1) / (float)m) + bottomLen;
      float segBot = ((topLen - bottomLen) *  i      / (float)m) + bottomLen;
      float off    = (segBot - segTop) / 2.0f;
      float xBL = off * i;
      float yBL = mh  * i;
      float xBR = off * i + segBot;
      float yBR = yBL;
      float xTR = off * i + off + segTop;
      float yTR = mh  * i + mh;
      float xTL = off * i + off;
      float yTL = yTR;
      beginShape();
      vertex(xBL, yBL);
      vertex(xBR, yBR);
      vertex(xTR, yTR);
      vertex(xTL, yTL);
      endShape(CLOSE);
    }
    if (e < n - 1) {
      PVector A_r  = new PVector((topLen - bottomLen) / 2.0f, h);
      float   offN = (bottomLen - topLen) / 2.0f;
      PVector B_l  = new PVector(offN, h);
      float rot    = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      translate(bottomLen, 0);
      rotate(rot);
    }
  }
  popMatrix();
  popStyle();
}

// ---------------------------------------------------------------------------
// drawSolidColorLid  –  uniform polygon lid
// Must be called in the same matrix context as drawPolygonLidHollow() —
// i.e. AFTER the translate/rotate in drawPlan() but BEFORE the lid outline.
// ---------------------------------------------------------------------------
void drawSolidColorLid(int numSides, float sideLength, color c) {
  float radius        = (sideLength / 2.0f) / sin(PI / (float)numSides);
  float angleInc      = TWO_PI / (float)numSides;
  float startAngle    = -HALF_PI - angleInc / 2.0f;
  float rectWidth     = (radius * cos(angleInc / 2.0f) + tabDepth_px) * 2.0f;

  pushStyle();
  fill(c);
  noStroke();
  pushMatrix();
  translate(rectWidth / 2.0f, rectWidth / 2.0f); // same as drawPolygonLidHollow
  beginShape();
  for (int i = 0; i < numSides; i++) {
    float angle = startAngle + i * angleInc;
    vertex(radius * cos(angle), radius * sin(angle));
  }
  endShape(CLOSE);
  popMatrix();
  popStyle();
}

// ---------------------------------------------------------------------------
// drawSolidColorVarLid  –  variable-prism polygon lid
// Must be called in the same matrix context as drawPolygonLidVarHollow().
// ---------------------------------------------------------------------------
void drawSolidColorVarLid(float[] sidePx, color c) {
  if (sidePx == null || sidePx.length < 3) return;
  int n = sidePx.length;

  float R = solveRadiusForChordSet(sidePx);
  if (R <= 0) return;

  // Compute the same orientation angle as drawPolygonLidVarHollow
  float ang0 = -HALF_PI;
  float s0   = sidePx[0];
  float th0  = 2.0f * (float)Math.asin(_clampf(s0 / (2.0f * R), 1e-6f, 0.999999f));
  PVector p0a  = new PVector(R * cos(ang0),       R * sin(ang0));
  PVector p0b  = new PVector(R * cos(ang0 + th0), R * sin(ang0 + th0));
  float angle0 = atan2(p0b.y - p0a.y, p0b.x - p0a.x);

  pushStyle();
  fill(c);
  noStroke();
  pushMatrix();
  rotate(-angle0); // same as drawPolygonLidVarHollow
  beginShape();
  float ang = ang0;
  for (int i = 0; i < n; i++) {
    vertex(R * cos(ang), R * sin(ang));
    float theta = 2.0f * (float)Math.asin(_clampf(sidePx[i] / (2.0f * R), 1e-6f, 0.999999f));
    ang += theta;
  }
  endShape(CLOSE);
  popMatrix();
  popStyle();
}
