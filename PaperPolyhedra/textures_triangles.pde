// ============================================================================
// Strip Texturing (bend one image across the entire strip)
// 
// ============================================================================

import processing.opengl.*;

// Affine: track placement without mutating pg transforms mid-shape
class Affine {
  float c=1, s=0, tx=0, ty=0;
  PVector apply(float x, float y) { return new PVector(c*x - s*y + tx, s*x + c*y + ty); }
  void translate(float dx, float dy) { tx += c*dx - s*dy; ty += s*dx + c*dy; }
  void rotate(float ang) { float cc=cos(ang), ss=sin(ang), nc=c*cc - s*ss, ns=s*cc + c*ss; c=nc; s=ns; }
}

// Compute the angle needed to align current right slant with next left slant
float rotNeeded(float t, float b, float tNext, float bNext, float h) {
  PVector A_r = new PVector((t - b)/2f, h);
  PVector B_l = new PVector((bNext - tNext)/2f, h);
  return atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
}

// -------- PER-EDGE triangle strip ----------
void drawTriangleStripTexture_PerEdge(PGraphics pg, PImage img) {
  println("[drawTriangleStripTexture_PerEdge] Called - img=" + (img!=null) + ", edgeTop_px=" + (edgeTop_px!=null) + ", edgeBot_px=" + (edgeBot_px!=null));
  if (img == null || edgeTop_px == null || edgeBot_px == null) return;

  final int n = min(edgeTop_px.length, edgeBot_px.length);
  final float h = cylinderH_px;
  println("[drawTriangleStripTexture_PerEdge] n=" + n + ", h=" + h);
  if (n <= 0 || h <= 0) return;

  // Average widths → proportional U allocation across columns
  float[] t = new float[n], b = new float[n], wAvg = new float[n];
  float sumAvg = 0;
  for (int i = 0; i < n; i++) {
    t[i] = max(0.001f, edgeTop_px[i]);
    b[i] = max(0.001f, edgeBot_px[i]);
    wAvg[i] = 0.5f * (t[i] + b[i]);
    sumAvg += wAvg[i];
  }
  if (sumAvg <= 0) return;
  final float uScale = img.width / sumAvg;

  // Tessellated version: subdivide each column
  Affine T = new Affine();
  float uAcc = 0;
  int density = max(2, tessellationDensity / 2); // fewer divisions for strip (performance)

  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);
  pg.noStroke();

  // For each column, draw tessellated trapezoid
  for (int i = 0; i < n; i++) {
    float u0px = uAcc * uScale;
    float u1px = (uAcc + wAvg[i]) * uScale;
    
    // Column corners in local frame
    float bleed = textureBleed ? textureBleedMM * MM : 0;
    float xBL = -bleed, yBL = -bleed;
    float xBR = b[i] + bleed, yBR = -bleed;
    float xTL = (b[i] - t[i]) / 2f - bleed, yTL = h + bleed;
    float xTR = (b[i] - t[i]) / 2f + t[i] + bleed, yTR = h + bleed;
    
    // Transform to world space and draw tessellated
    pg.beginShape(TRIANGLES);
    pg.texture(img);
    
    for (int row = 0; row < density; row++) {
      for (int col = 0; col < density; col++) {
        float v0 = (float)row / density;
        float v1 = (float)(row + 1) / density;
        float localU0 = (float)col / density;
        float localU1 = (float)(col + 1) / density;
        
        // Local positions
        float lx00 = bilerp(xBL, xBR, xTL, xTR, localU0, v0);
        float ly00 = bilerp(yBL, yBR, yTL, yTR, localU0, v0);
        float lx10 = bilerp(xBL, xBR, xTL, xTR, localU1, v0);
        float ly10 = bilerp(yBL, yBR, yTL, yTR, localU1, v0);
        float lx01 = bilerp(xBL, xBR, xTL, xTR, localU0, v1);
        float ly01 = bilerp(yBL, yBR, yTL, yTR, localU0, v1);
        float lx11 = bilerp(xBL, xBR, xTL, xTR, localU1, v1);
        float ly11 = bilerp(yBL, yBR, yTL, yTR, localU1, v1);
        
        // Transform to world
        PVector p00 = T.apply(lx00, ly00);
        PVector p10 = T.apply(lx10, ly10);
        PVector p01 = T.apply(lx01, ly01);
        PVector p11 = T.apply(lx11, ly11);
        
        // UV coordinates (continuous across strip)
        float uvX0 = lerp(u0px, u1px, localU0);
        float uvX1 = lerp(u0px, u1px, localU1);
        float uvY0 = v0 * img.height;
        float uvY1 = v1 * img.height;
        
        // Two triangles
        pg.vertex(p00.x, p00.y, uvX0, uvY0);
        pg.vertex(p10.x, p10.y, uvX1, uvY0);
        pg.vertex(p01.x, p01.y, uvX0, uvY1);
        
        pg.vertex(p10.x, p10.y, uvX1, uvY0);
        pg.vertex(p11.x, p11.y, uvX1, uvY1);
        pg.vertex(p01.x, p01.y, uvX0, uvY1);
      }
    }
    
    pg.endShape();

    // Advance transform to next column frame
    if (i < n - 1) {
      float rot = rotNeeded(t[i], b[i], t[i+1], b[i+1], h);
      T.translate(b[i], 0);
      T.rotate(rot);
    }

    uAcc += wAvg[i];
  }
}

// -------- UNIFORM triangle strip ----------
void drawTriangleStripTexture_Uniform(PGraphics pg, PImage img) {
  println("[drawTriangleStripTexture_Uniform] Called - img=" + (img!=null));
  if (img == null) return;

  final int n = max(3, (rows - 1));   // == nSides
  final float h = cylinderH_px;
  final float t = cellTopL_px;
  final float b = cellBaseL_px;
  println("[drawTriangleStripTexture_Uniform] n=" + n + ", h=" + h + ", t=" + t + ", b=" + b);
  if (n <= 0 || h <= 0) return;

  final float wAvg = 0.5f * (t + b);
  final float sumAvg = wAvg * n;
  if (sumAvg <= 0) return;
  final float uScale = img.width / sumAvg;

  Affine T = new Affine();
  float uAcc = 0;
  int density = max(2, tessellationDensity / 2); // fewer divisions for strip
  println("[drawTriangleStripTexture_Uniform] density=" + density + ", starting to draw " + n + " columns");

  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);
  pg.noStroke();

  // For each column, draw tessellated trapezoid
  for (int i = 0; i < n; i++) {
    float u0px = uAcc * uScale;
    float u1px = (uAcc + wAvg) * uScale;
    
    // Column corners in local frame
    float bleed = textureBleed ? textureBleedMM * MM : 0;
    float xBL = -bleed, yBL = -bleed;
    float xBR = b + bleed, yBR = -bleed;
    float xTL = (b - t) / 2f - bleed, yTL = h + bleed;
    float xTR = (b - t) / 2f + t + bleed, yTR = h + bleed;
    
    // Transform to world space and draw tessellated
    pg.beginShape(TRIANGLES);
    pg.texture(img);
    
    for (int row = 0; row < density; row++) {
      for (int col = 0; col < density; col++) {
        float v0 = (float)row / density;
        float v1 = (float)(row + 1) / density;
        float localU0 = (float)col / density;
        float localU1 = (float)(col + 1) / density;
        
        // Local positions
        float lx00 = bilerp(xBL, xBR, xTL, xTR, localU0, v0);
        float ly00 = bilerp(yBL, yBR, yTL, yTR, localU0, v0);
        float lx10 = bilerp(xBL, xBR, xTL, xTR, localU1, v0);
        float ly10 = bilerp(yBL, yBR, yTL, yTR, localU1, v0);
        float lx01 = bilerp(xBL, xBR, xTL, xTR, localU0, v1);
        float ly01 = bilerp(yBL, yBR, yTL, yTR, localU0, v1);
        float lx11 = bilerp(xBL, xBR, xTL, xTR, localU1, v1);
        float ly11 = bilerp(yBL, yBR, yTL, yTR, localU1, v1);
        
        // Transform to world
        PVector p00 = T.apply(lx00, ly00);
        PVector p10 = T.apply(lx10, ly10);
        PVector p01 = T.apply(lx01, ly01);
        PVector p11 = T.apply(lx11, ly11);
        
        // UV coordinates (continuous across strip)
        float uvX0 = lerp(u0px, u1px, localU0);
        float uvX1 = lerp(u0px, u1px, localU1);
        float uvY0 = v0 * img.height;
        float uvY1 = v1 * img.height;
        
        // Two triangles
        pg.vertex(p00.x, p00.y, uvX0, uvY0);
        pg.vertex(p10.x, p10.y, uvX1, uvY0);
        pg.vertex(p01.x, p01.y, uvX0, uvY1);
        
        pg.vertex(p10.x, p10.y, uvX1, uvY0);
        pg.vertex(p11.x, p11.y, uvX1, uvY1);
        pg.vertex(p01.x, p01.y, uvX0, uvY1);
      }
    }
    
    pg.endShape();

    // Uniform advance (same as panels)
    if (i < n - 1) {
      PVector A_r = new PVector((t - b) / 2f, h);
      float offN = (b - t) / 2f;
      PVector B_l = new PVector(offN, h);
      float rot = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      T.translate(b, 0);
      T.rotate(rot);
    }

    uAcc += wAvg;
  }
}

// -------- Wrapper to choose mode ----------
void drawTriangleStripTextureForCurrentMode(PGraphics pg, PImage img) {
  if (img == null) return;
  if ((perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null) {
    drawTriangleStripTexture_PerEdge(pg, img);
  } else {
    drawTriangleStripTexture_Uniform(pg, img);
  }
}

// -------- RANGE: PER-EDGE triangle strip (panels [panelStart..panelEnd)) ----------
void drawTriangleStripTexture_PerEdge_Range(PGraphics pg, PImage img, int panelStart, int panelEnd) {
  if (img == null || edgeTop_px == null || edgeBot_px == null) return;
  final int n = min(edgeTop_px.length, edgeBot_px.length);
  final float h = cylinderH_px;
  if (n <= 0 || h <= 0) return;
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;

  float[] t = new float[n], b = new float[n], wAvg = new float[n];
  float sumAvg = 0;
  for (int i = 0; i < n; i++) {
    t[i] = max(0.001f, edgeTop_px[i]);
    b[i] = max(0.001f, edgeBot_px[i]);
    wAvg[i] = 0.5f * (t[i] + b[i]);
    sumAvg += wAvg[i];
  }
  if (sumAvg <= 0) return;
  final float uScale = img.width / sumAvg;

  Affine T = new Affine();
  float uAcc = 0;
  int density = max(2, tessellationDensity / 2);

  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);
  pg.noStroke();

  // Skip panels before panelStart (advance uAcc only, NOT the Affine transform)
  for (int i = 0; i < panelStart; i++) {
    uAcc += wAvg[i];
  }

  // Draw panels [panelStart..panelEnd)
  for (int i = panelStart; i < panelEnd && i < n; i++) {
    float u0px = uAcc * uScale;
    float u1px = (uAcc + wAvg[i]) * uScale;

    float bleed = textureBleed ? textureBleedMM * MM : 0;
    float xBL = -bleed, yBL = -bleed;
    float xBR = b[i] + bleed, yBR = -bleed;
    float xTL = (b[i] - t[i]) / 2f - bleed, yTL = h + bleed;
    float xTR = (b[i] - t[i]) / 2f + t[i] + bleed, yTR = h + bleed;

    pg.beginShape(TRIANGLES);
    pg.texture(img);
    for (int row = 0; row < density; row++) {
      for (int col = 0; col < density; col++) {
        float v0 = (float)row / density;
        float v1 = (float)(row + 1) / density;
        float localU0 = (float)col / density;
        float localU1 = (float)(col + 1) / density;

        float lx00 = bilerp(xBL, xBR, xTL, xTR, localU0, v0);
        float ly00 = bilerp(yBL, yBR, yTL, yTR, localU0, v0);
        float lx10 = bilerp(xBL, xBR, xTL, xTR, localU1, v0);
        float ly10 = bilerp(yBL, yBR, yTL, yTR, localU1, v0);
        float lx01 = bilerp(xBL, xBR, xTL, xTR, localU0, v1);
        float ly01 = bilerp(yBL, yBR, yTL, yTR, localU0, v1);
        float lx11 = bilerp(xBL, xBR, xTL, xTR, localU1, v1);
        float ly11 = bilerp(yBL, yBR, yTL, yTR, localU1, v1);

        PVector p00 = T.apply(lx00, ly00);
        PVector p10 = T.apply(lx10, ly10);
        PVector p01 = T.apply(lx01, ly01);
        PVector p11 = T.apply(lx11, ly11);

        float uvX0 = lerp(u0px, u1px, localU0);
        float uvX1 = lerp(u0px, u1px, localU1);
        float uvY0 = v0 * img.height;
        float uvY1 = v1 * img.height;

        pg.vertex(p00.x, p00.y, uvX0, uvY0);
        pg.vertex(p10.x, p10.y, uvX1, uvY0);
        pg.vertex(p01.x, p01.y, uvX0, uvY1);

        pg.vertex(p10.x, p10.y, uvX1, uvY0);
        pg.vertex(p11.x, p11.y, uvX1, uvY1);
        pg.vertex(p01.x, p01.y, uvX0, uvY1);
      }
    }
    pg.endShape();

    if (i < n - 1) {
      float rot = rotNeeded(t[i], b[i], t[i+1], b[i+1], h);
      T.translate(b[i], 0);
      T.rotate(rot);
    }
    uAcc += wAvg[i];
  }
}

// -------- RANGE: UNIFORM triangle strip (panels [panelStart..panelEnd)) ----------
void drawTriangleStripTexture_Uniform_Range(PGraphics pg, PImage img, int panelStart, int panelEnd) {
  if (img == null) return;
  final int totalN = max(3, (rows - 1));
  final float h = cylinderH_px;
  final float t = cellTopL_px;
  final float b = cellBaseL_px;
  if (totalN <= 0 || h <= 0) return;
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;

  final float wAvg = 0.5f * (t + b);
  final float sumAvg = wAvg * totalN;
  if (sumAvg <= 0) return;
  final float uScale = img.width / sumAvg;

  Affine T = new Affine();
  float uAcc = 0;
  int density = max(2, tessellationDensity / 2);

  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);
  pg.noStroke();

  // Skip panels before panelStart (advance uAcc only, NOT the Affine transform)
  for (int i = 0; i < panelStart; i++) {
    uAcc += wAvg;
  }

  // Draw panels [panelStart..panelEnd)
  for (int i = panelStart; i < panelEnd && i < totalN; i++) {
    float u0px = uAcc * uScale;
    float u1px = (uAcc + wAvg) * uScale;

    float bleed = textureBleed ? textureBleedMM * MM : 0;
    float xBL = -bleed, yBL = -bleed;
    float xBR = b + bleed, yBR = -bleed;
    float xTL = (b - t) / 2f - bleed, yTL = h + bleed;
    float xTR = (b - t) / 2f + t + bleed, yTR = h + bleed;

    pg.beginShape(TRIANGLES);
    pg.texture(img);
    for (int row = 0; row < density; row++) {
      for (int col = 0; col < density; col++) {
        float v0 = (float)row / density;
        float v1 = (float)(row + 1) / density;
        float localU0 = (float)col / density;
        float localU1 = (float)(col + 1) / density;

        float lx00 = bilerp(xBL, xBR, xTL, xTR, localU0, v0);
        float ly00 = bilerp(yBL, yBR, yTL, yTR, localU0, v0);
        float lx10 = bilerp(xBL, xBR, xTL, xTR, localU1, v0);
        float ly10 = bilerp(yBL, yBR, yTL, yTR, localU1, v0);
        float lx01 = bilerp(xBL, xBR, xTL, xTR, localU0, v1);
        float ly01 = bilerp(yBL, yBR, yTL, yTR, localU0, v1);
        float lx11 = bilerp(xBL, xBR, xTL, xTR, localU1, v1);
        float ly11 = bilerp(yBL, yBR, yTL, yTR, localU1, v1);

        PVector p00 = T.apply(lx00, ly00);
        PVector p10 = T.apply(lx10, ly10);
        PVector p01 = T.apply(lx01, ly01);
        PVector p11 = T.apply(lx11, ly11);

        float uvX0 = lerp(u0px, u1px, localU0);
        float uvX1 = lerp(u0px, u1px, localU1);
        float uvY0 = v0 * img.height;
        float uvY1 = v1 * img.height;

        pg.vertex(p00.x, p00.y, uvX0, uvY0);
        pg.vertex(p10.x, p10.y, uvX1, uvY0);
        pg.vertex(p01.x, p01.y, uvX0, uvY1);

        pg.vertex(p10.x, p10.y, uvX1, uvY0);
        pg.vertex(p11.x, p11.y, uvX1, uvY1);
        pg.vertex(p01.x, p01.y, uvX0, uvY1);
      }
    }
    pg.endShape();

    if (i < totalN - 1) {
      PVector A_r = new PVector((t - b) / 2f, h);
      float offN = (b - t) / 2f;
      PVector B_l = new PVector(offN, h);
      float rot = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      T.translate(b, 0);
      T.rotate(rot);
    }
    uAcc += wAvg;
  }
}

// -------- Where to call --------
// Preview (on screen), inside drawPlan(...) AFTER panels (and under same print transform):
//   drawTriangleStripTextureForCurrentMode(g, stripImg);
//
// Export (PDF), in drawTexturesForPrinting(pg) AFTER the panel loop's popMatrix(), from clean origin:
//   drawTriangleStripTextureForCurrentMode(pg, stripImg);
//
// Important: When using triangle strip for sides, disable per-panel images to avoid overdraw:
//   if (sideTextureMode == TEX_STRIP_BENT) return null;  // inside getEdgeImage(...)
