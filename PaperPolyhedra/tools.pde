//----------------------------------------------------------------------
// page with all the different tools we need for drawing the trapezoids, names are given to the tools to make them clear
//
//--------------------------------------------------------------

// Draw horizontal fold lines on tabs at specified depth (for inner wall tabs)
void drawTabFoldLines(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int n, float foldDepth) {
  pushMatrix();
  translate(startX, startY);
  
  pushStyle();
  stroke(uiLightGrayCutLines ? 180 : 0);
  
  for (int count = 0; count < n; count++) {
    float mh = h / (float)m;
    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      
      PVector pb = new PVector(offset*i, mh*i);
      PVector db = new PVector(mbottom, 0);
      PVector pt = new PVector(offset*i+offset, mh*i + mh);
      PVector dt = new PVector(mtop, 0);
      
      float botTabInset = mbottom / 4.0;
      float topTabInset = mtop / 4.0;
      
      // Draw fold line on bottom tab (horizontal line at foldDepth below panel edge)
      drawDashedLine(pb.x + botTabInset*2, pb.y + db.y + foldDepth, 
                     pb.x + db.x - botTabInset*0, pb.y + db.y + foldDepth, 
                     dash_px, gap_px);
      
      // Draw fold line on top tab (horizontal line at foldDepth above panel edge)
      drawDashedLine(pt.x + topTabInset*0, pt.y - foldDepth, 
                     pt.x + dt.x - topTabInset*2, pt.y - foldDepth, 
                     dash_px, gap_px);
    }

    // Advance to next panel
    if (count < n-1) {
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      translate(bottomLen, 0);
      rotate(rotationNeeded);
    }
  }
  
  popStyle();
  popMatrix();
}

float calculateInscribedRadius(int n, float s) {
  // The formula is r = s / (2 * tan(180/n)).
  // in Processing, tan() uses radians, so we use PI instead of 180 degrees.
  float angle = PI / n;
  float radius = s / (2 * tan(angle));
  return radius;
}

void exportTrapezoids(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int n) {
  beginRecord(pdf);
  drawTrapezoids(startX, startY, topLen, bottomLen, h, m, n, false);
  endRecord();
  //println("File saved:", filename);
}

void drawTzFlapSlot(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int n) {
  pushMatrix();
  translate(startX, startY);
  for (int count = 0; count < n; count++) {
    float mh = h / (float)m;
    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      stroke(uiLightGrayCutLines ? 180 : 0);
      noFill();
      PVector pb = new PVector(offset*i, mh*i);
      PVector db = new PVector(mbottom, 0);
      PVector pt = new PVector(offset*i+offset, mh*i + mh);
      PVector dt = new PVector(mtop, 0);

      drawBottomTabContour(pb, db, tabDepth_px, tabInset_bot_px, arrowheadFlare_bot_px, neckDepth_px);
      drawTopTabContour(pt, dt, tabDepth_px, tabInset_top_px, arrowheadFlare_top_px, neckDepth_px);
    }

    // 2) If there's another trapezoid to draw, set up the next transform
    if (count < n-1) {
      // Vector representing the right slanted edge of this trapezoid
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      translate(bottomLen, 0);
      rotate(rotationNeeded);
    }
  }
  popMatrix();
}

void drawTzTopFolds(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int n) {
  pushMatrix();  // Use push/pop to encapsulate our transformations
  translate(startX, startY);
  for (int count = 0; count < n; count++) {
    float mh = h / (float)m;
    PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
    float offsetNext = (bottomLen - topLen) / 2.0;
    PVector B_left   = new PVector(offsetNext, h);
    float angleA         = atan2(A_right.y, A_right.x);
    float angleB         = atan2(B_left.y, B_left.x);
    float rotationNeeded = angleA - angleB;

    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      stroke(uiLightGrayCutLines ? 180 : 0);
      noFill();
      PVector cb = new PVector(offset*i+mbottom/2, mh*i);
      PVector ct = new PVector(offset*i+offset+mtop/2, mh*i + mh);
      PVector dc = new PVector(0, mh);
      PVector pb = new PVector(offset*i, mh*i);
      PVector db = new PVector(mbottom, 0);
      PVector pt = new PVector(offset*i+offset, mh*i + mh);
      PVector dt = new PVector(mtop, 0);
      drawBottomTabContour(pb, db, tabDepth_px, tabInset_bot_px, arrowheadFlare_bot_px, neckDepth_px);
      drawTopTabContour(pt, dt, tabDepth_px, tabInset_top_px, arrowheadFlare_top_px, neckDepth_px);
      if (count==0) {
        pushMatrix();
        //stroke(255, 0, 0);
        drawLeftSlantFlap(pb, pt, flapDepth_px, flapTaper_px, tabInset_h_px);
        popMatrix();
      }

      if (count == n-1) {
        pushMatrix();
        float hookOffset_px = hookOffset*MM;
        drawRightSlantFlap(PVector.add(pb, db), PVector.add(pt, dt), flapDepth_px, tabInset_h_px, arrowheadFlare_h_px, neckDepth_hook_px, hookOffset_px);
        //drawRightHookTabContour(cb, dc, tabDepth_px, tabInset_h_px, arrowheadFlare_h_px, neckDepth_hook_px, hookOffset_px);
        popMatrix();
      }
    }
    //if there's another trapezoid to draw, set up the next transform
    if (count < n-1) {
      // Vector representing the right slanted edge of this trapezoid
      translate(bottomLen, 0);
      rotate(rotationNeeded);
    }
  }
  popMatrix();
}

// ---------------------------------------------------------------------------
// Split-aware version of drawTzTopFolds: draws panels [startPanel..endPanel)
// with optional left/right flaps.
// ---------------------------------------------------------------------------
void drawTzTopFolds_Range(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int panelStart, int panelEnd, boolean leftFlap, boolean rightFlap) {
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;
  pushMatrix();
  translate(startX, startY);
  for (int count = 0; count < nPanels; count++) {
    float mh = h / (float)m;
    PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
    float offsetNext = (bottomLen - topLen) / 2.0;
    PVector B_left   = new PVector(offsetNext, h);
    float angleA         = atan2(A_right.y, A_right.x);
    float angleB         = atan2(B_left.y, B_left.x);
    float rotationNeeded = angleA - angleB;

    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      stroke(uiLightGrayCutLines ? 180 : 0);
      noFill();
      PVector pb = new PVector(offset*i, mh*i);
      PVector db = new PVector(mbottom, 0);
      PVector pt = new PVector(offset*i+offset, mh*i + mh);
      PVector dt = new PVector(mtop, 0);
      drawBottomTabContour(pb, db, tabDepth_px, tabInset_bot_px, arrowheadFlare_bot_px, neckDepth_px);
      drawTopTabContour(pt, dt, tabDepth_px, tabInset_top_px, arrowheadFlare_top_px, neckDepth_px);
      if (count == 0 && leftFlap) {
        pushMatrix();
        drawLeftSlantFlap(pb, pt, flapDepth_px, flapTaper_px, tabInset_h_px);
        popMatrix();
      }
      if (count == nPanels - 1 && rightFlap) {
        pushMatrix();
        float hookOff_px = hookOffset*MM;
        drawRightSlantFlap(PVector.add(pb, db), PVector.add(pt, dt), flapDepth_px, tabInset_h_px, arrowheadFlare_h_px, neckDepth_hook_px, hookOff_px);
        popMatrix();
      }
    }
    if (count < nPanels - 1) {
      translate(bottomLen, 0);
      rotate(rotationNeeded);
    }
  }
  popMatrix();
}

// Split-aware version of drawTrapezoids: draws panels [panelStart..panelEnd)
void drawTrapezoids_Range(float startX, float startY, float topLen, float bottomLen,
                          float h, int m, int panelStart, int panelEnd, boolean showMesh) {
  pushMatrix();
  translate(startX, startY);
  int nPanels = panelEnd - panelStart;
  for (int count = 0; count < nPanels; count++) {
    float mh = h / (float)m;
    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      if (showMesh) {
        noStroke();
        float xBL = offset*i, yBL = mh*i;
        float xBR = offset*i + mbottom, yBR = mh*i;
        float xTR = offset*i + offset + mtop, yTR = mh*i + mh;
        float xTL = offset*i + offset, yTL = mh*i + mh;
        int globalPanelIdx = panelStart + count;
        PImage img = getEdgeImage(globalPanelIdx, nSides);
        if (img != null && canTexture()) {
          drawTessellatedTrapezoid(xBL, yBL, xBR, yBR, xTR, yTR, xTL, yTL, img, tessellationDensity);
        } else if (img != null) {
          float xMin = min(min(xBL, xBR), min(xTR, xTL));
          float yMin = min(min(yBL, yBR), min(yTR, yTL));
          float xMax = max(max(xBL, xBR), max(xTR, xTL));
          float yMax = max(max(yBL, yBR), max(yTR, yTL));
          image(img, xMin, yMin, xMax - xMin, yMax - yMin);
        }
      }
    }
    if (count < nPanels - 1) {
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      translate(bottomLen, 0);
      rotate(rotationNeeded);
    }
  }
  popMatrix();
}

// Split-aware version of drawTzFoldlines: draws fold lines for panels [panelStart..panelEnd)
void drawTzFoldlines_Range(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int panelStart, int panelEnd) {
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;
  pushMatrix();
  translate(startX, startY);
  for (int count = 0; count < nPanels; count++) {
    float mh = h / (float)m;
    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      stroke(uiLightGrayCutLines ? 180 : 0);
      noFill();
      PVector p1 = new PVector(offset*i+mbottom, mh*i);
      PVector p2 = new PVector(offset*i+offset + mtop, mh*i + mh);
      if (count < nPanels-1 && !uiHidePanelFolds) {
        drawDashedLine(p1.x, p1.y, p2.x, p2.y, dash_px, gap_px);
      }
    }
    if (count < nPanels - 1) {
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      translate(bottomLen, 0);
      rotate(rotationNeeded);
    }
  }
  popMatrix();
}

void drawTzFoldlines(float startX, float startY,
  float topLen, float bottomLen,
  float h, int m, int n) {

  pushMatrix();
  translate(startX, startY);
  for (int count = 0; count < n; count++) {
    float mh = h / (float)m;
    for (int i = 0; i < m; i++) {
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      stroke(uiLightGrayCutLines ? 180 : 0);
      noFill();
      PVector p1 = new PVector(offset*i+mbottom, mh*i);
      PVector p2 = new PVector(offset*i+offset + mtop, mh*i + mh);
      //if (count< n-1) drawDashedLine(p1.x, p1.y, p2.x, p2.y, dash_px, gap_px);
      if (count < n-1 && !uiHidePanelFolds) {                                   // updated now with the additional option to hide the panel folds
        drawDashedLine(p1.x, p1.y, p2.x, p2.y, dash_px, gap_px);
      }
    }

    //If there's another trapezoid to draw, set up the next transform
    if (count < n-1) {
      // Vector representing the right slanted edge of this trapezoid
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      translate(bottomLen, 0);
      rotate(rotationNeeded);
    }
  }
  popMatrix();
}

void drawTrapezoids(float startX, float startY, float topLen, float bottomLen, float h, int m, int n, boolean showMesh) {
  pushMatrix();                                                                // Save current drawing settings - so we can restore it later.
  translate(startX, startY);

  for (int count = 0; count < n; count++) {                                    // drawing one side of the polygon at a time (so one trapezoid  at the time)
    float mh = h / (float)m;
    for (int i = 0; i < m; i++) {                                              // loop through each trapezoid in the column
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      float offset  = (mbottom - mtop) / 2.0;
      if (showMesh) {
        {
          noStroke();

          // 1) panel corners (you already compute these)
          float xBL = offset*i, yBL = mh*i;
          float xBR = offset*i + mbottom, yBR = mh*i;
          float xTR = offset*i + offset + mtop, yTR = mh*i + mh;
          float xTL = offset*i + offset, yTL = mh*i + mh;

          // 2) per-edge image
          PImage img = getEdgeImage(count, n); // 'count' = current edge idx, 'n' = total edges

          if (img != null && canTexture()) {
            // 3) Tessellated trapezoid for better texture detail
            drawTessellatedTrapezoid(xBL, yBL, xBR, yBR, xTR, yTR, xTL, yTL, img, tessellationDensity);
          } else if (img != null) {
            // 4) fallback for PDF/SVG/JAVA2D: draw the image in the quad's bbox (no warp)
            float xMin = min(min(xBL, xBR), min(xTR, xTL));
            float yMin = min(min(yBL, yBR), min(yTR, yTL));
            float xMax = max(max(xBL, xBR), max(xTR, xTL));
            float yMax = max(max(yBL, yBR), max(yTR, yTL));
            image(img, xMin, yMin, xMax - xMin, yMax - yMin);
          }
          // TEX_NONE: no fill drawn here — solid color handled by drawSolidColorPanels(), white paper shows through
        }
      }
    }

    // 2) If there's another trapezoid to draw, set up the next transform
    if (count < n-1) {
      // Vector representing the right slanted edge of this trapezoid
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      translate(bottomLen, 0); // Move to the next side
      rotate(rotationNeeded);
    }
  }
  popMatrix();  // Restore drawing settings
}


void drawDashedLine(float x1, float y1, float x2, float y2, float dashLength, float gapLength) {
  float totalLength = dist(x1, y1, x2, y2);

  // If the total line is too short to fit even the two end gaps, do nothing
  if (totalLength <= 2 * gapLength) {
    return;
  }

  // Calculate the direction of the line
  float dx = (x2 - x1) / totalLength;
  float dy = (y2 - y1) / totalLength;

  pushStyle();
  stroke(uiLightGrayCutLines ? 180 : 0);

  //sstart the drawing position after the first gap.
  float currentPos = gapLength;

  // The loop should stop before the drawing position enters the final gap area
  while (currentPos < totalLength - gapLength) {
    float startX = x1 + dx * currentPos;
    float startY = y1 + dy * currentPos;

    // determine the end of the current dash, ensuring it doesn't go past the final gap
    float endPos = min(currentPos + dashLength, totalLength - gapLength);
    float endX = x1 + dx * endPos;
    float endY = y1 + dy * endPos;

    line(startX, startY, endX, endY);

    // Move the current position forward by the length of a dash and a gap
    currentPos += dashLength + gapLength;
  }
  popStyle();
}

// Tessellated trapezoid drawing for improved texture detail
// Uses rectangular grid subdivision with bilinear interpolation
void drawTessellatedTrapezoid(float xBL, float yBL, float xBR, float yBR, 
                               float xTR, float yTR, float xTL, float yTL,
                               PImage img, int density) {
  if (img == null || density < 2) return;
  
  noStroke();
  beginShape(TRIANGLES);
  texture(img);
  
  // Create a rectangular grid subdividing the trapezoid
  for (int row = 0; row < density; row++) {
    for (int col = 0; col < density; col++) {
      // Normalized coordinates (0 to 1) for each grid cell corner
      float v0 = (float)row / density;        // bottom of cell
      float v1 = (float)(row + 1) / density;  // top of cell
      float u0 = (float)col / density;        // left of cell
      float u1 = (float)(col + 1) / density;  // right of cell
      
      // Bilinear interpolation for world space positions
      // Bottom-left corner of cell
      float x00 = bilerp(xBL, xBR, xTL, xTR, u0, v0);
      float y00 = bilerp(yBL, yBR, yTL, yTR, u0, v0);
      
      // Bottom-right corner of cell
      float x10 = bilerp(xBL, xBR, xTL, xTR, u1, v0);
      float y10 = bilerp(yBL, yBR, yTL, yTR, u1, v0);
      
      // Top-left corner of cell
      float x01 = bilerp(xBL, xBR, xTL, xTR, u0, v1);
      float y01 = bilerp(yBL, yBR, yTL, yTR, u0, v1);
      
      // Top-right corner of cell
      float x11 = bilerp(xBL, xBR, xTL, xTR, u1, v1);
      float y11 = bilerp(yBL, yBR, yTL, yTR, u1, v1);
      
      // UV coordinates map linearly to image
      float uvX0 = u0 * img.width;
      float uvX1 = u1 * img.width;
      float uvY0 = v0 * img.height;
      float uvY1 = v1 * img.height;
      
      // Draw two triangles for this grid cell
      // Alternate diagonal direction (checkerboard) to prevent diagonal seams
      if ((row + col) % 2 == 0) {
        // Diagonal from BL to TR
        // Triangle 1: BL, BR, TR
        vertex(x00, y00, uvX0, uvY0);
        vertex(x10, y10, uvX1, uvY0);
        vertex(x11, y11, uvX1, uvY1);
        
        // Triangle 2: BL, TR, TL
        vertex(x00, y00, uvX0, uvY0);
        vertex(x11, y11, uvX1, uvY1);
        vertex(x01, y01, uvX0, uvY1);
      } else {
        // Diagonal from BR to TL (original)
        // Triangle 1: BL, BR, TL
        vertex(x00, y00, uvX0, uvY0);
        vertex(x10, y10, uvX1, uvY0);
        vertex(x01, y01, uvX0, uvY1);
        
        // Triangle 2: BR, TR, TL
        vertex(x10, y10, uvX1, uvY0);
        vertex(x11, y11, uvX1, uvY1);
        vertex(x01, y01, uvX0, uvY1);
      }
    }
  }
  
  endShape();
  
  // Draw mesh overlay if toggle is enabled
  if (uiShowTessellationMesh) {
    stroke(0, 200, 255, 150);  // Cyan with transparency
    strokeWeight(0.5);
    noFill();
    
    // Draw grid lines
    for (int row = 0; row <= density; row++) {
      float v = (float)row / density;
      beginShape();
      for (int col = 0; col <= density; col++) {
        float u = (float)col / density;
        float x = bilerp(xBL, xBR, xTL, xTR, u, v);
        float y = bilerp(yBL, yBR, yTL, yTR, u, v);
        vertex(x, y);
      }
      endShape();
    }
    
    for (int col = 0; col <= density; col++) {
      float u = (float)col / density;
      beginShape();
      for (int row = 0; row <= density; row++) {
        float v = (float)row / density;
        float x = bilerp(xBL, xBR, xTL, xTR, u, v);
        float y = bilerp(yBL, yBR, yTL, yTR, u, v);
        vertex(x, y);
      }
      endShape();
    }
  }
}

// Bilinear interpolation helper
// Interpolates between four corners: BL, BR, TL, TR
// u: horizontal position (0=left, 1=right)
// v: vertical position (0=bottom, 1=top)
float bilerp(float BL, float BR, float TL, float TR, float u, float v) {
  float bottom = lerp(BL, BR, u);
  float top = lerp(TL, TR, u);
  return lerp(bottom, top, v);
}

//----------------------------------------------------------------------
// 3D VIEW FUNCTIONS
//----------------------------------------------------------------------

void draw3DView() {
  // Drop last frame's pickable faces up front, so assembly mode (which returns early
  // below) cannot leave a stale cache that would let clicks pick invisible faces.
  faceHits.clear();

  view3DBuffer.beginDraw();
  view3DBuffer.background(200);
  view3DBuffer.lights();

  view3DBuffer.pushMatrix();
  float centerX = view3DBuffer.width / 2;
  float centerY = view3DBuffer.height / 2;
  view3DBuffer.translate(centerX, centerY, 0);

  // ---------- BAR ASSEMBLY 3D ----------
  if (assemblyMode && activeAssembly != null) {
    float cellPx = activeAssembly.cellSizeMM * MM_current;
    float gridSpanX = activeAssembly.gridW * cellPx;
    float gridSpanZ = activeAssembly.gridH * cellPx;
    float maxH = cellPx; // fallback
    for (int _r = 0; _r < activeAssembly.gridH; _r++)
      for (int _c = 0; _c < activeAssembly.gridW; _c++) {
        int _si = activeAssembly.getCell(_r, _c);
        if (_si >= 0 && shapes != null && _si < shapes.size())
          maxH = max(maxH, shapes.get(_si).uiHeight * MM_current);
      }
    float maxDim = max(max(gridSpanX, gridSpanZ), maxH);
    float viewSize = min(view3DBuffer.width, view3DBuffer.height);
    float autoZoom = viewSize / (maxDim * 2.5f);
    view3DBuffer.scale(autoZoom * zoom3D / 100.0);
    view3DBuffer.rotateX(angleX);
    view3DBuffer.rotateY(angleY);
    view3DBuffer.rotateZ(angleZ);
    draw3DAssembly(activeAssembly, view3DBuffer);
    view3DBuffer.popMatrix();
    view3DBuffer.endDraw();
    return;
  }
  // ---------- END ASSEMBLY 3D ----------

  // Connections turn the flat shape list into a set of trees: a root shape plus everything
  // posed on its faces. "All" lays the roots out in a row; "Selected" shows the whole
  // assembly the selected shape belongs to, so a child stays visible in context.
  _captureFaces = true;

  ArrayList<Integer> roots = new ArrayList<Integer>();
  if (shapes != null && shapes.size() > 0) {
    if (view3DShowAll) {
      for (int si = 0; si < shapes.size(); si++) if (isRootShape(si)) roots.add(si);
    } else {
      roots.add(rootAncestorOf(selectedShapeIdx));
    }
  }
  if (roots.isEmpty()) roots.add(selectedShapeIdx);

  // One scale for everything on screen, sized to the largest assembly.
  float maxDim = 0;
  for (int r : roots) maxDim = max(maxDim, treeSpanPx(r, 0));
  if (maxDim <= 0) maxDim = 100;

  float gap = maxDim * 1.4;
  float viewSize = min(view3DBuffer.width, view3DBuffer.height);
  // Single assembly keeps the original framing; a row of them packs to the row width.
  float autoZoom = (roots.size() == 1)
                 ? viewSize / (maxDim * 1.8)
                 : viewSize / (roots.size() * gap * 0.9);
  view3DBuffer.scale(autoZoom * zoom3D / 100.0);
  view3DBuffer.rotateX(angleX);
  view3DBuffer.rotateY(angleY);
  view3DBuffer.rotateZ(angleZ);

  float rowW = (roots.size() - 1) * gap;
  float startX = -rowW / 2;
  for (int i = 0; i < roots.size(); i++) {
    view3DBuffer.pushMatrix();
    view3DBuffer.translate(startX + i * gap, 0, 0);
    drawShapeTree(view3DBuffer, roots.get(i), 0);
    view3DBuffer.popMatrix();
  }

  _captureFaces = false;
  // Restore globals to selected shape — drawShapeTree swaps them as it recurses
  if (shapes != null && shapes.size() > 0) {
    loadGlobalsFrom(shapes.get(selectedShapeIdx));
    setParams(false);
  }

  view3DBuffer.popMatrix();
  view3DBuffer.endDraw();
}

// Draws a shape and, recursively, everything connected to it. Each child is posed on its
// parent's face through the canonical lid frame (LidFrame.pde), which is the same frame
// the cut slits use — so the preview and the pattern can never disagree about where a
// connection sits.
//
// drawPrismWireframe() reads globals and the recursion swaps them via loadGlobalsFrom(),
// so the parent's globals are restored before each sibling; the caller restores the
// selected shape at the end.
void drawShapeTree(PGraphics pg, int idx, int depth) {
  if (shapes == null || idx < 0 || idx >= shapes.size()) return;
  if (depth > CONNECTION_MAX_DEPTH) return;

  loadGlobalsFrom(shapes.get(idx));
  setParams(false);
  drawPrismWireframe(pg);

  // Record where this shape's faces landed on screen, while its transform is still applied.
  if (_captureFaces) {
    captureFaceHit(pg, idx, true);
    captureFaceHit(pg, idx, false);
  }

  for (Connection c : childrenOf(idx)) {
    if (c.childShapeIdx < 0 || c.childShapeIdx >= shapes.size()) continue;

    // Attach point, computed while the PARENT's globals are still loaded.
    PVector p = lidLocalTo3D(c.posLocal, c.parentFaceIsTop);
    float childHalfH = (shapes.get(c.childShapeIdx).cylinder.z * MM_current) / 2.0;

    pg.pushMatrix();
    pg.translate(p.x, p.y, p.z);
    pg.rotateY(radians(c.spinDeg));
    // P3D is y-down: the top face is at -halfH and a child grows upward off it. Off the
    // bottom face the child hangs downward instead — a half-turn about x. childFlipped
    // means the child mates by its top lid, which is another half-turn; on a bottom face
    // the two cancel and the child hangs the right way up.
    if (!c.parentFaceIsTop) pg.rotateX(PI);
    if (c.childFlipped)     pg.rotateX(PI);
    // The child draws centred on its own origin, so drop it by half its height and its
    // mating lid lands exactly on the parent's face.
    pg.translate(0, -childHalfH, 0);
    drawShapeTree(pg, c.childShapeIdx, depth + 1);
    pg.popMatrix();

    // Restore the parent's globals for the next sibling.
    loadGlobalsFrom(shapes.get(idx));
    setParams(false);
  }
}

// Rough extent (px) of a connected assembly, for the 3D auto-zoom: the deepest stack of
// heights against the widest cross-section anywhere in the tree. Perimeter stands in for
// width, matching the proxy the single-shape auto-zoom already used.
float treeSpanPx(int idx, int depth) {
  if (shapes == null || idx < 0 || idx >= shapes.size() || depth > CONNECTION_MAX_DEPTH) return 0;
  ShapeSpec s = shapes.get(idx);
  float ownW = max(s.cylinder.x, s.cylinder.y) * MM_current;
  float ownH = s.cylinder.z * MM_current;
  float childW = 0;
  float childH = 0;
  for (Connection c : childrenOf(idx)) {
    childW = max(childW, treeSpanPx(c.childShapeIdx, depth + 1));
    childH = max(childH, treeStackHeightPx(c.childShapeIdx, depth + 1));
  }
  return max(max(ownW, childW), ownH + childH);
}

float treeStackHeightPx(int idx, int depth) {
  if (shapes == null || idx < 0 || idx >= shapes.size() || depth > CONNECTION_MAX_DEPTH) return 0;
  float h = shapes.get(idx).cylinder.z * MM_current;
  float childH = 0;
  for (Connection c : childrenOf(idx)) {
    childH = max(childH, treeStackHeightPx(c.childShapeIdx, depth + 1));
  }
  return h + childH;
}

void drawMini3DView() {
  // Render 3D view to mini buffer
  mini3DBuffer.beginDraw();
  mini3DBuffer.background(220);
  mini3DBuffer.lights();
  
  mini3DBuffer.pushMatrix();
  // Center in the mini 3D buffer
  float centerX = mini3DBuffer.width / 2;
  float centerY = mini3DBuffer.height / 2;
  mini3DBuffer.translate(centerX, centerY, 0);
  
  // Auto-scale based on prism size to fit in mini view
  float maxDimension = max(cylinderTP_px, cylinderBP_px, cylinderVertH_px); // <-- height fix
  float viewSize = min(mini3DBuffer.width, mini3DBuffer.height);
  float autoZoom = viewSize / (maxDimension * 1.8);
  mini3DBuffer.scale(autoZoom * zoom3D / 100.0);
  
  mini3DBuffer.rotateX(angleX);
  mini3DBuffer.rotateY(angleY);
  mini3DBuffer.rotateZ(angleZ);

  // Show the whole connected assembly, not just the one shape
  drawShapeTree(mini3DBuffer, rootAncestorOf(selectedShapeIdx), 0);
  loadGlobalsFrom(shapes.get(selectedShapeIdx));  // drawShapeTree swaps globals as it recurses
  setParams(false);

  mini3DBuffer.popMatrix();
  mini3DBuffer.endDraw();

  // Calculate position in top-right corner, aligned below toolbar
  float availableWidth = width - LEFT_SIDEBAR_WIDTH;
  float miniX = LEFT_SIDEBAR_WIDTH + availableWidth - MINI_3D_WIDTH - MINI_3D_MARGIN;
  float miniY = TOOLBAR_HEIGHT;  // Position directly below toolbar
  
  pushStyle();
  
  // Draw outer frame with toolbar matching color
  color toolbarBg = color(30, 40, 80);  // Match toolbar background
  float borderWidth = 4;
  float inset = 8;
  
  // Outer border frame
  fill(toolbarBg);
  stroke(100, 120, 180);  // Lighter blue outline for visibility
  strokeWeight(borderWidth);
  rect(miniX, miniY, MINI_3D_WIDTH, MINI_3D_HEIGHT, 0, 0, 8, 8);  // Round bottom corners only
  
  // Inner content area (white background for 3D view)
  fill(255);
  noStroke();
  rect(miniX + inset, miniY + inset + 12, MINI_3D_WIDTH - inset*2, MINI_3D_HEIGHT - inset*2 - 12, 4);
  
  // Draw the 3D view
  image(mini3DBuffer, miniX + inset, miniY + inset + 12, MINI_3D_WIDTH - inset*2, MINI_3D_HEIGHT - inset*2 - 12);
  
  // Draw label inside box at top
  fill(200, 200, 210);
  textAlign(CENTER, CENTER);
  textSize(10);
  text("3D PREVIEW", miniX + MINI_3D_WIDTH / 2, miniY + inset - 1);
  
  popStyle();
}

// Helper function to check if mouse is inside mini 3D view
boolean isMouseInMini3DView() {
  if (view3DMode) return false;  // Mini view only visible in 2D mode
  if (kreslingMode) return false;  // Mini view hidden in Kresling mode

  // Only check if on Shape tab (activeMainTab == 0)
  if (sidebar != null && sidebar.activeMainTab != 0) return false;
  
  // Calculate position at bottom of sidebar (matching drawMini3DViewInSidebar)
  float miniW = (LEFT_SIDEBAR_WIDTH - SIDEBAR_PADDING * 2) * 0.7;  // 70% of sidebar width
  float miniH = miniW;  // Keep it square
  float miniX = SIDEBAR_PADDING + (LEFT_SIDEBAR_WIDTH - SIDEBAR_PADDING * 2 - miniW) / 2;  // Center horizontally
  float miniY = height - BOTTOM_EXPORT_HEIGHT - miniH - SIDEBAR_PADDING + 80;
  
  return mouseX >= miniX && mouseX <= miniX + miniW &&
         mouseY >= miniY && mouseY <= miniY + miniH;
}

void drawMini3DViewInSidebar() {
  // Render 3D view to mini buffer
  mini3DBuffer.beginDraw();
  mini3DBuffer.background(220);
  mini3DBuffer.lights();
  
  mini3DBuffer.pushMatrix();
  // Center in the mini 3D buffer
  float centerX = mini3DBuffer.width / 2;
  float centerY = mini3DBuffer.height / 2;
  mini3DBuffer.translate(centerX, centerY, 0);
  
  // Auto-scale based on prism size to fit in mini view
  float maxDimension = max(cylinderTP_px, cylinderBP_px, cylinderVertH_px); // <-- height fix
  float viewSize = min(mini3DBuffer.width, mini3DBuffer.height);
  float autoZoom = viewSize / (maxDimension * 1.4);  // Zoomed in more (was 1.8)
  mini3DBuffer.scale(autoZoom * zoom3D / 100.0);
  
  mini3DBuffer.rotateX(angleX);
  mini3DBuffer.rotateY(angleY);
  mini3DBuffer.rotateZ(angleZ);
  
  // Show the whole connected assembly, not just the one shape
  drawShapeTree(mini3DBuffer, rootAncestorOf(selectedShapeIdx), 0);
  loadGlobalsFrom(shapes.get(selectedShapeIdx));  // drawShapeTree swaps globals as it recurses
  setParams(false);

  mini3DBuffer.popMatrix();
  mini3DBuffer.endDraw();

  // Calculate position at bottom of sidebar
  float miniW = (LEFT_SIDEBAR_WIDTH - SIDEBAR_PADDING * 2) * 0.7;  // 70% of sidebar width
  float miniH = miniW;  // Keep it square
  float miniX = SIDEBAR_PADDING + (LEFT_SIDEBAR_WIDTH - SIDEBAR_PADDING * 2 - miniW) / 2;  // Center horizontally
  float miniY = height - BOTTOM_EXPORT_HEIGHT - miniH - SIDEBAR_PADDING + 80; // move it down 
  
  pushStyle();
  
  // Draw outer frame with sidebar matching color
  color sidebarBg = color(60, 60, 70);  // Match sidebar background
  float borderWidth = 3;
  float inset = 8;
  
  // Outer border frame
  fill(sidebarBg);
  stroke(100, 120, 180);  // Blue outline for visibility
  strokeWeight(borderWidth);
  rect(miniX, miniY, miniW, miniH, 5);
  
  // Inner content area (white background for 3D view)
  fill(255);
  noStroke();
  rect(miniX + inset, miniY + inset + 15, miniW - inset*2, miniH - inset*2 - 15, 4);
  
  // Draw the 3D view
  image(mini3DBuffer, miniX + inset, miniY + inset + 15, miniW - inset*2, miniH - inset*2 - 15);
  
  // Draw label inside box at top
  fill(200, 200, 210);
  textAlign(CENTER, CENTER);
  textSize(11);
  text("3D PREVIEW", miniX + miniW / 2, miniY + inset);
  
  popStyle();
}



void drawPrismWireframe(PGraphics pg) {
  // Calculate polygon vertices for top and bottom (outer walls)
  PVector[] topVerts = getPolygonVertices(true);   // top
  PVector[] botVerts = getPolygonVertices(false);  // bottom
  
  // Generate inner wall vertices if in hollow mode
  PVector[] topVertsInner = null;
  PVector[] botVertsInner = null;
  if (hollowMode) {
    topVertsInner = getPolygonVerticesInner(true);
    botVertsInner = getPolygonVerticesInner(false);
  }
  
  // Draw outer textured side panels
  if (!wireframeMode) {
    if (sideTextureMode != TEX_NONE) {
      drawTexturedPrismFaces(pg, topVerts, botVerts, false);  // false = outer wall
    } else {
      // Draw faces: use solid fill color if enabled, otherwise gray
      pg.noStroke();
      pg.fill(fillColorEnabled ? shapeColor : color(180));
      for (int i = 0; i < topVerts.length; i++) {
        int next = (i + 1) % topVerts.length;
        pg.beginShape();
        pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
        pg.vertex(botVerts[next].x, botVerts[next].y, botVerts[next].z);
        pg.vertex(topVerts[next].x, topVerts[next].y, topVerts[next].z);
        pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
        pg.endShape(CLOSE);
      }
    }
  }
  
  // Draw inner walls if in hollow mode
  if (hollowMode && topVertsInner != null && botVertsInner != null) {
    if (!wireframeMode) {
      if (sideTextureMode != TEX_NONE) {
        drawTexturedPrismFaces(pg, topVertsInner, botVertsInner, true);  // true = inner wall (darker)
      } else {
        // Draw solid gray faces (inner, darker)
        pg.noStroke();
        pg.fill(120);  // Darker gray for inner wall
        for (int i = 0; i < topVertsInner.length; i++) {
          int next = (i + 1) % topVertsInner.length;
          pg.beginShape();
          // Note: reverse winding order for inner wall (faces outward)
          pg.vertex(botVertsInner[i].x, botVertsInner[i].y, botVertsInner[i].z);
          pg.vertex(topVertsInner[i].x, topVertsInner[i].y, topVertsInner[i].z);
          pg.vertex(topVertsInner[next].x, topVertsInner[next].y, topVertsInner[next].z);
          pg.vertex(botVertsInner[next].x, botVertsInner[next].y, botVertsInner[next].z);
          pg.endShape(CLOSE);
        }
      }
    }
  }
  
  // Draw top lid (donut shape if hollow)
  if (!wireframeMode) {
  if (sidebar != null && sidebar.topLidEnabled && lidImgTop != null) {
    if (hollowMode && topVertsInner != null) {
      drawTexturedLidDonut(pg, topVerts, topVertsInner, lidImgTop, false);
    } else {
      drawTexturedLid(pg, topVerts, lidImgTop, false);  // false = no flip
    }
  } else {
    pg.fill(fillColorEnabled ? shapeColor : color(200));
    pg.noStroke();
    if (hollowMode && topVertsInner != null) {
      // Draw donut top cap
      if (topVerts.length == topVertsInner.length) {
        // Same vertex count - use quad strips
        for (int i = 0; i < topVerts.length; i++) {
          int next = (i + 1) % topVerts.length;
          pg.beginShape();
          pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
          pg.vertex(topVerts[next].x, topVerts[next].y, topVerts[next].z);
          pg.vertex(topVertsInner[next].x, topVertsInner[next].y, topVertsInner[next].z);
          pg.vertex(topVertsInner[i].x, topVertsInner[i].y, topVertsInner[i].z);
          pg.endShape(CLOSE);
        }
      } else {
        // Different vertex counts - map proportionally with triangles
        for (int i = 0; i < topVerts.length; i++) {
          int nextOuter = (i + 1) % topVerts.length;
          float outerRatio = (float)i / topVerts.length;
          int innerIdx = ((int)(outerRatio * topVertsInner.length)) % topVertsInner.length;
          int innerIdxNext = (innerIdx + 1) % topVertsInner.length;
          
          pg.beginShape(TRIANGLES);
          pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
          pg.vertex(topVerts[nextOuter].x, topVerts[nextOuter].y, topVerts[nextOuter].z);
          pg.vertex(topVertsInner[innerIdx].x, topVertsInner[innerIdx].y, topVertsInner[innerIdx].z);
          
          pg.vertex(topVerts[nextOuter].x, topVerts[nextOuter].y, topVerts[nextOuter].z);
          pg.vertex(topVertsInner[innerIdxNext].x, topVertsInner[innerIdxNext].y, topVertsInner[innerIdxNext].z);
          pg.vertex(topVertsInner[innerIdx].x, topVertsInner[innerIdx].y, topVertsInner[innerIdx].z);
          pg.endShape();
        }
      }
    } else {
      // Draw solid top
      pg.beginShape();
      for (int i = 0; i < topVerts.length; i++) {
        pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
      }
      pg.endShape(CLOSE);
    }
  }
  } // end !wireframeMode
  
  // Draw bottom lid (donut shape if hollow)
  if (!wireframeMode) {
  if (sidebar != null && sidebar.bottomLidEnabled && lidImgBot != null) {
    if (hollowMode && botVertsInner != null) {
      drawTexturedLidDonut(pg, botVerts, botVertsInner, lidImgBot, true);
    } else {
      drawTexturedLid(pg, botVerts, lidImgBot, true);  // true = flip texture
    }
  } else {
    pg.fill(fillColorEnabled ? shapeColor : color(200));
    pg.noStroke();
    if (hollowMode && botVertsInner != null) {
      // Draw donut bottom cap (reverse winding)
      if (botVerts.length == botVertsInner.length) {
        // Same vertex count - use quad strips
        for (int i = 0; i < botVerts.length; i++) {
          int next = (i + 1) % botVerts.length;
          pg.beginShape();
          pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
          pg.vertex(botVertsInner[i].x, botVertsInner[i].y, botVertsInner[i].z);
          pg.vertex(botVertsInner[next].x, botVertsInner[next].y, botVertsInner[next].z);
          pg.vertex(botVerts[next].x, botVerts[next].y, botVerts[next].z);
          pg.endShape(CLOSE);
        }
      } else {
        // Different vertex counts - map proportionally with triangles
        for (int i = 0; i < botVerts.length; i++) {
          int nextOuter = (i + 1) % botVerts.length;
          float outerRatio = (float)i / botVerts.length;
          int innerIdx = ((int)(outerRatio * botVertsInner.length)) % botVertsInner.length;
          int innerIdxNext = (innerIdx + 1) % botVertsInner.length;
          
          pg.beginShape(TRIANGLES);
          pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
          pg.vertex(botVertsInner[i].x, botVertsInner[i].y, botVertsInner[i].z);
          pg.vertex(botVerts[nextOuter].x, botVerts[nextOuter].y, botVerts[nextOuter].z);
          
          pg.vertex(botVerts[nextOuter].x, botVerts[nextOuter].y, botVerts[nextOuter].z);
          pg.vertex(botVertsInner[innerIdx].x, botVertsInner[innerIdx].y, botVertsInner[innerIdx].z);
          pg.vertex(botVertsInner[innerIdxNext].x, botVertsInner[innerIdxNext].y, botVertsInner[innerIdxNext].z);
          pg.endShape();
        }
      }
    } else {
      // Draw solid bottom
      pg.beginShape();
      for (int i = botVerts.length - 1; i >= 0; i--) {  // Reverse for correct face orientation
        pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
      }
      pg.endShape(CLOSE);
    }
  }
  } // end !wireframeMode
  
  // Draw wireframe edges over everything
  pg.stroke(0);
  pg.strokeWeight(2);
  pg.noFill();
  
  // Outer wall wireframe
  // Top polygon outline
  pg.beginShape();
  for (int i = 0; i < topVerts.length; i++) {
    pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
  }
  pg.endShape(CLOSE);
  
  // Bottom polygon outline
  pg.beginShape();
  for (int i = 0; i < botVerts.length; i++) {
    pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
  }
  pg.endShape(CLOSE);
  
  // Vertical edges (outer)
  for (int i = 0; i < topVerts.length; i++) {
    pg.line(topVerts[i].x, topVerts[i].y, topVerts[i].z,
            botVerts[i].x, botVerts[i].y, botVerts[i].z);
  }
  
  // Inner wall wireframe (if hollow mode)
  if (hollowMode && topVertsInner != null && botVertsInner != null) {
    pg.stroke(60);  // Slightly lighter stroke for inner edges
    
    // Top inner polygon outline
    pg.beginShape();
    for (int i = 0; i < topVertsInner.length; i++) {
      pg.vertex(topVertsInner[i].x, topVertsInner[i].y, topVertsInner[i].z);
    }
    pg.endShape(CLOSE);
    
    // Bottom inner polygon outline
    pg.beginShape();
    for (int i = 0; i < botVertsInner.length; i++) {
      pg.vertex(botVertsInner[i].x, botVertsInner[i].y, botVertsInner[i].z);
    }
    pg.endShape(CLOSE);
    
    // Vertical edges (inner)
    for (int i = 0; i < topVertsInner.length; i++) {
      pg.line(topVertsInner[i].x, topVertsInner[i].y, topVertsInner[i].z,
              botVertsInner[i].x, botVertsInner[i].y, botVertsInner[i].z);
    }
    
    // Radial connections on top cap (donut ring edges)
    pg.stroke(80);  // Even lighter for cap connections
    for (int i = 0; i < topVerts.length; i++) {
      // Map outer vertex to corresponding inner vertex proportionally
      float outerRatio = (float)i / topVerts.length;
      int innerIdx = ((int)(outerRatio * topVertsInner.length)) % topVertsInner.length;
      pg.line(topVerts[i].x, topVerts[i].y, topVerts[i].z,
              topVertsInner[innerIdx].x, topVertsInner[innerIdx].y, topVertsInner[innerIdx].z);
    }
    
    // Radial connections on bottom cap
    for (int i = 0; i < botVerts.length; i++) {
      // Map outer vertex to corresponding inner vertex proportionally
      float outerRatio = (float)i / botVerts.length;
      int innerIdx = ((int)(outerRatio * botVertsInner.length)) % botVertsInner.length;
      pg.line(botVerts[i].x, botVerts[i].y, botVerts[i].z,
              botVertsInner[innerIdx].x, botVertsInner[innerIdx].y, botVertsInner[innerIdx].z);
    }
  }
}

void drawTexturedPrismFaces(PGraphics pg, PVector[] topVerts, PVector[] botVerts, boolean isInnerWall) {
  println("[drawTexturedPrismFaces] Called with sideTextureMode=" + sideTextureMode + " (TEX_PER_PANEL=" + TEX_PER_PANEL + "), isInnerWall=" + isInnerWall);
  pg.noStroke();
  pg.textureMode(NORMAL);
  
  // Apply darker tint for inner walls
  if (isInnerWall) {
    pg.tint(150, 150, 150);  // 60% brightness for visual distinction
  } else {
    pg.noTint();
  }
  
  // Check if we're in strip mode
  boolean useStrip = (sideTextureMode == TEX_STRIP_BENT && stripImg != null);
  
  // Calculate total perimeter for strip UV mapping
  float totalPerim = 0;
  float[] edgeLengths = new float[topVerts.length];
  if (useStrip) {
    for (int i = 0; i < topVerts.length; i++) {
      int next = (i + 1) % topVerts.length;
      edgeLengths[i] = dist(botVerts[i].x, botVerts[i].z, botVerts[next].x, botVerts[next].z);
      totalPerim += edgeLengths[i];
    }
  }
  
  float uOffset = 0;  // Running U coordinate for strip texture
  
  for (int i = 0; i < topVerts.length; i++) {
    int next = (i + 1) % topVerts.length;
    
    PImage panelTexture = null;
    float u0 = 0, u1 = 1;
    
    if (useStrip) {
      // Use strip texture with continuous UV mapping
      panelTexture = stripImg;
      u0 = uOffset / totalPerim;
      u1 = (uOffset + edgeLengths[i]) / totalPerim;
      uOffset += edgeLengths[i];
    } else if (sideTextureMode == TEX_PER_PANEL) {
      // Use per-panel texture
      panelTexture = getEdgeImage(i, topVerts.length);
      println("[drawTexturedPrismFaces] Panel " + i + " texture: " + (panelTexture != null ? (panelTexture.width + "x" + panelTexture.height) : "NULL"));
    }
    
    if (panelTexture != null) {
      println("[drawTexturedPrismFaces] Drawing textured panel " + i);
      pg.beginShape();
      pg.texture(panelTexture);
      
      if (isInnerWall) {
        // Inner wall: reverse winding order (faces inward)
        pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z, u0, 0);
        pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z, u0, 1);
        pg.vertex(topVerts[next].x, topVerts[next].y, topVerts[next].z, u1, 1);
        pg.vertex(botVerts[next].x, botVerts[next].y, botVerts[next].z, u1, 0);
      } else {
        // Outer wall: normal winding order (faces outward)
        pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z, u0, 0);
        pg.vertex(botVerts[next].x, botVerts[next].y, botVerts[next].z, u1, 0);
        pg.vertex(topVerts[next].x, topVerts[next].y, topVerts[next].z, u1, 1);
        pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z, u0, 1);
      }
      
      pg.endShape(CLOSE);
    } else {
      // No texture: use solid fill color if enabled, otherwise gray
      pg.fill(fillColorEnabled && !isInnerWall ? shapeColor : color(isInnerWall ? 120 : 180));
      pg.beginShape();
      if (isInnerWall) {
        // Reverse winding for inner wall
        pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
        pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
        pg.vertex(topVerts[next].x, topVerts[next].y, topVerts[next].z);
        pg.vertex(botVerts[next].x, botVerts[next].y, botVerts[next].z);
      } else {
        pg.vertex(botVerts[i].x, botVerts[i].y, botVerts[i].z);
        pg.vertex(botVerts[next].x, botVerts[next].y, botVerts[next].z);
        pg.vertex(topVerts[next].x, topVerts[next].y, topVerts[next].z);
        pg.vertex(topVerts[i].x, topVerts[i].y, topVerts[i].z);
      }
      pg.endShape(CLOSE);
    }
  }
  
  // Reset tint after drawing
  pg.noTint();
}

// Draw textured donut-shaped lid for hollow mode
void drawTexturedLidDonut(PGraphics pg, PVector[] outerVerts, PVector[] innerVerts, PImage lidImg, boolean flipTexture) {
  // Calculate bounding box for UV mapping (using outer vertices)
  float minX = Float.MAX_VALUE, maxX = -Float.MAX_VALUE;
  float minZ = Float.MAX_VALUE, maxZ = -Float.MAX_VALUE;
  
  for (PVector v : outerVerts) {
    minX = min(minX, v.x);
    maxX = max(maxX, v.x);
    minZ = min(minZ, v.z);
    maxZ = max(maxZ, v.z);
  }
  
  float rangeX = maxX - minX;
  float rangeZ = maxZ - minZ;
  
  pg.noStroke();
  pg.textureMode(NORMAL);
  
  // Check if inner and outer have same number of vertices
  if (outerVerts.length == innerVerts.length) {
    // Simple case: same vertex count - use quad strips
    drawDonutQuadStrips(pg, outerVerts, innerVerts, lidImg, flipTexture, minX, minZ, rangeX, rangeZ);
  } else {
    // Complex case: different vertex counts - use triangulation
    drawDonutTriangulated(pg, outerVerts, innerVerts, lidImg, flipTexture, minX, minZ, rangeX, rangeZ);
  }
}

// Draw donut ring with matching vertex counts (original method)
void drawDonutQuadStrips(PGraphics pg, PVector[] outerVerts, PVector[] innerVerts, PImage lidImg, 
                         boolean flipTexture, float minX, float minZ, float rangeX, float rangeZ) {
  for (int i = 0; i < outerVerts.length; i++) {
    int next = (i + 1) % outerVerts.length;
    
    pg.beginShape();
    pg.texture(lidImg);
    
    // Calculate UV coords for each vertex
    float u0 = (outerVerts[i].x - minX) / rangeX;
    float v0 = (outerVerts[i].z - minZ) / rangeZ;
    float u1 = (outerVerts[next].x - minX) / rangeX;
    float v1 = (outerVerts[next].z - minZ) / rangeZ;
    float u2 = (innerVerts[next].x - minX) / rangeX;
    float v2 = (innerVerts[next].z - minZ) / rangeZ;
    float u3 = (innerVerts[i].x - minX) / rangeX;
    float v3 = (innerVerts[i].z - minZ) / rangeZ;
    
    if (flipTexture) {
      u0 = 1.0 - u0; u1 = 1.0 - u1; u2 = 1.0 - u2; u3 = 1.0 - u3;
    }
    
    // Quad connecting outer to inner edge
    if (flipTexture) {
      // Bottom lid: reverse winding
      pg.vertex(outerVerts[i].x, outerVerts[i].y, outerVerts[i].z, u0, v0);
      pg.vertex(innerVerts[i].x, innerVerts[i].y, innerVerts[i].z, u3, v3);
      pg.vertex(innerVerts[next].x, innerVerts[next].y, innerVerts[next].z, u2, v2);
      pg.vertex(outerVerts[next].x, outerVerts[next].y, outerVerts[next].z, u1, v1);
    } else {
      // Top lid: normal winding
      pg.vertex(outerVerts[i].x, outerVerts[i].y, outerVerts[i].z, u0, v0);
      pg.vertex(outerVerts[next].x, outerVerts[next].y, outerVerts[next].z, u1, v1);
      pg.vertex(innerVerts[next].x, innerVerts[next].y, innerVerts[next].z, u2, v2);
      pg.vertex(innerVerts[i].x, innerVerts[i].y, innerVerts[i].z, u3, v3);
    }
    
    pg.endShape(CLOSE);
  }
}

// Draw donut ring with different vertex counts (triangulated method)
void drawDonutTriangulated(PGraphics pg, PVector[] outerVerts, PVector[] innerVerts, PImage lidImg,
                           boolean flipTexture, float minX, float minZ, float rangeX, float rangeZ) {
  // For each outer edge, connect to proportionally mapped inner vertices
  for (int i = 0; i < outerVerts.length; i++) {
    int nextOuter = (i + 1) % outerVerts.length;
    
    // Map outer index to inner index proportionally
    float outerRatio = (float)i / outerVerts.length;
    float innerIdxFloat = outerRatio * innerVerts.length;
    int innerIdx = ((int)innerIdxFloat) % innerVerts.length;
    int innerIdxNext = (innerIdx + 1) % innerVerts.length;
    
    pg.beginShape(TRIANGLES);
    pg.texture(lidImg);
    
    // Calculate UV coordinates
    float u0 = (outerVerts[i].x - minX) / rangeX;
    float v0 = (outerVerts[i].z - minZ) / rangeZ;
    float u1 = (outerVerts[nextOuter].x - minX) / rangeX;
    float v1 = (outerVerts[nextOuter].z - minZ) / rangeZ;
    float u2 = (innerVerts[innerIdx].x - minX) / rangeX;
    float v2 = (innerVerts[innerIdx].z - minZ) / rangeZ;
    float u3 = (innerVerts[innerIdxNext].x - minX) / rangeX;
    float v3 = (innerVerts[innerIdxNext].z - minZ) / rangeZ;
    
    if (flipTexture) {
      u0 = 1.0 - u0; u1 = 1.0 - u1; u2 = 1.0 - u2; u3 = 1.0 - u3;
    }
    
    // Create two triangles to form a quad-like structure
    if (flipTexture) {
      // Triangle 1
      pg.vertex(outerVerts[i].x, outerVerts[i].y, outerVerts[i].z, u0, v0);
      pg.vertex(innerVerts[innerIdx].x, innerVerts[innerIdx].y, innerVerts[innerIdx].z, u2, v2);
      pg.vertex(outerVerts[nextOuter].x, outerVerts[nextOuter].y, outerVerts[nextOuter].z, u1, v1);
      
      // Triangle 2
      pg.vertex(outerVerts[nextOuter].x, outerVerts[nextOuter].y, outerVerts[nextOuter].z, u1, v1);
      pg.vertex(innerVerts[innerIdx].x, innerVerts[innerIdx].y, innerVerts[innerIdx].z, u2, v2);
      pg.vertex(innerVerts[innerIdxNext].x, innerVerts[innerIdxNext].y, innerVerts[innerIdxNext].z, u3, v3);
    } else {
      // Triangle 1
      pg.vertex(outerVerts[i].x, outerVerts[i].y, outerVerts[i].z, u0, v0);
      pg.vertex(outerVerts[nextOuter].x, outerVerts[nextOuter].y, outerVerts[nextOuter].z, u1, v1);
      pg.vertex(innerVerts[innerIdx].x, innerVerts[innerIdx].y, innerVerts[innerIdx].z, u2, v2);
      
      // Triangle 2
      pg.vertex(outerVerts[nextOuter].x, outerVerts[nextOuter].y, outerVerts[nextOuter].z, u1, v1);
      pg.vertex(innerVerts[innerIdxNext].x, innerVerts[innerIdxNext].y, innerVerts[innerIdxNext].z, u3, v3);
      pg.vertex(innerVerts[innerIdx].x, innerVerts[innerIdx].y, innerVerts[innerIdx].z, u2, v2);
    }
    
    pg.endShape();
  }
}

void drawTexturedLid(PGraphics pg, PVector[] verts, PImage lidImg, boolean flipTexture) {
  // Calculate bounding box for UV mapping
  float minX = Float.MAX_VALUE, maxX = -Float.MAX_VALUE;
  float minZ = Float.MAX_VALUE, maxZ = -Float.MAX_VALUE;
  
  for (PVector v : verts) {
    minX = min(minX, v.x);
    maxX = max(maxX, v.x);
    minZ = min(minZ, v.z);
    maxZ = max(maxZ, v.z);
  }
  
  float rangeX = maxX - minX;
  float rangeZ = maxZ - minZ;
  
  pg.noStroke();
  pg.beginShape();
  pg.texture(lidImg);
  pg.textureMode(NORMAL);
  
  for (PVector v : verts) {
    float u = (v.x - minX) / rangeX;
    float v_coord = (v.z - minZ) / rangeZ;
    
    // Flip U coordinate if needed (for bottom lid)
    if (flipTexture) {
      u = 1.0 - u;
    }
    
    pg.vertex(v.x, v.y, v.z, u, v_coord);
  }
  
  pg.endShape(CLOSE);
}

PVector[] getPolygonVertices(boolean isTop) {
  float[] edges = isTop ? edgeTop_px : edgeBot_px;
  int n = nSides;
  
  // Use per-edge arrays if in per-edge mode or cuboid mode, otherwise use uniform
  if ((!perEdgeMode && !cuboidMode) || edges == null) {
    float edgeLen = isTop ? cellTopL_px : cellBaseL_px;
    edges = new float[n];
    for (int i = 0; i < n; i++) {
      edges[i] = edgeLen;
    }
  }
  
  // Calculate vertices by walking around the polygon
  PVector[] verts = new PVector[n];
  float halfH = cylinderVertH_px / 2.0; // <-- height fix
  float yPos = isTop ? -halfH : halfH;
  
  // Start at origin, walk around computing vertices
  float angle = 0;
  PVector currentPos = new PVector(0, yPos, 0);
  
  for (int i = 0; i < n; i++) {
    verts[i] = currentPos.copy();
    
    if (i < n - 1) {
      // Move to next vertex
      float edgeLength = edges[i];
      currentPos.x += edgeLength * cos(angle);
      currentPos.z += edgeLength * sin(angle);
      
      // Calculate turn angle for next edge
      angle += calculateTurnAngle(edges, i, n);
    }
  }
  
  // Center the polygon
  PVector center = new PVector(0, 0, 0);
  for (PVector v : verts) {
    center.add(v);
  }
  center.div(n);
  center.y = 0; // Keep y at correct height
  
  for (PVector v : verts) {
    v.sub(center);
  }
  
  return verts;
}

float calculateTurnAngle(float[] edges, int i, int n) {
  // For a regular polygon: turn angle = TWO_PI / n
  // For irregular polygon: use inscribed circle approximation
  return TWO_PI / n;
}

// Generate inner polygon vertices for hollow mode
PVector[] getPolygonVerticesInner(boolean isTop) {
  if (!hollowMode) return null;
  
  int nInner; // Number of sides for inner polygon
  float[] innerEdges;
  
  if (enableInnerShape) {
    // Use different inner shape
    nInner = nSidesInner;
    
    // Calculate inner edge length from scale
    float[] outerEdges = isTop ? edgeTop_px : edgeBot_px;
    int n = nSides;
    
    // Calculate total outer perimeter
    float outerPerimeter = 0;
    if ((!perEdgeMode && !cuboidMode) || outerEdges == null) {
      float edgeLen = isTop ? cellTopL_px : cellBaseL_px;
      outerPerimeter = edgeLen * n;
    } else {
      for (int i = 0; i < outerEdges.length; i++) {
        outerPerimeter += outerEdges[i];
      }
    }
    
    // Calculate inner perimeter and edge length
    float innerPerimeter = outerPerimeter * innerShapeScale;
    float innerEdgeLen = innerPerimeter / (float)nInner;
    
    innerEdges = new float[nInner];
    for (int i = 0; i < nInner; i++) {
      innerEdges[i] = innerEdgeLen;
    }
  } else {
    // Traditional concentric polygon (same number of sides)
    float[] outerEdges = isTop ? edgeTop_px : edgeBot_px;
    nInner = nSides;
    
    // Use per-edge arrays if in per-edge mode, otherwise use uniform
    if ((!perEdgeMode && !cuboidMode) || outerEdges == null) {
      float edgeLen = isTop ? cellTopL_px : cellBaseL_px;
      outerEdges = new float[nInner];
      for (int i = 0; i < nInner; i++) {
        outerEdges[i] = edgeLen;
      }
    }
    
    // Calculate inner edges using proportional scaling
    innerEdges = calculateInsetEdges(outerEdges, wallThickness_px);
    if (innerEdges == null) {
      println("[WARNING] Cannot generate inner vertices - wall thickness too large");
      return null;
    }
  }
  
  // Calculate vertices by walking around the inner polygon
  PVector[] verts = new PVector[nInner];
  float halfH = cylinderVertH_px / 2.0; // <-- height fix
  float yPos = isTop ? -halfH : halfH;
  
  // Start at origin, walk around computing vertices
  float angle = 0;
  PVector currentPos = new PVector(0, yPos, 0);
  
  for (int i = 0; i < nInner; i++) {
    verts[i] = currentPos.copy();
    
    if (i < nInner - 1) {
      // Move to next vertex
      float edgeLength = innerEdges[i];
      currentPos.x += edgeLength * cos(angle);
      currentPos.z += edgeLength * sin(angle);
      
      // Calculate turn angle for next edge
      angle += TWO_PI / nInner;
    }
  }
  
  // Center the polygon
  PVector center = new PVector(0, 0, 0);
  for (PVector v : verts) {
    center.add(v);
  }
  center.div(nInner);
  center.y = 0; // Keep y at correct height
  
  for (PVector v : verts) {
    v.sub(center);
  }
  
  // Apply inner shape rotation if enabled
  if (enableInnerShape && innerShapeRotation != 0) {
    float rotAngle = radians(innerShapeRotation);
    for (PVector v : verts) {
      float newX = v.x * cos(rotAngle) - v.z * sin(rotAngle);
      float newZ = v.x * sin(rotAngle) + v.z * cos(rotAngle);
      v.x = newX;
      v.z = newZ;
    }
  }
  
  return verts;
}

void reset3DView() {
  angleX = radians(60);
  angleY = radians(0);
  angleZ = radians(45);
  zoom3D = 100.0;
}
//----------------------------------------------------------------------
// HOLLOW MODE: Wrapper functions for double-wall drawing
//----------------------------------------------------------------------

// Draw trapezoid strip with cutouts for hollow mode (uniform polygons)
void drawTrapezoidsHollow(float startX, float startY, float topLen, float bottomLen, 
                          float h, int m, int n, boolean showMesh) {
  if (!hollowMode) {
    // Normal single-wall mode
    drawTrapezoids(startX, startY, topLen, bottomLen, h, m, n, showMesh);
    return;
  }
  
  // Calculate inner dimensions
  float topLenInner, bottomLenInner;
  int nInner; // Number of sides for inner wall
  
  if (enableInnerShape) {
    // Use different inner shape with specified number of sides
    nInner = nSidesInner;
    // Calculate inner edge length from inner perimeter
    float outerPerimeterTop = topLen * n;
    float outerPerimeterBottom = bottomLen * n;
    float innerPerimeterTop = outerPerimeterTop * innerShapeScale;
    float innerPerimeterBottom = outerPerimeterBottom * innerShapeScale;
    topLenInner = innerPerimeterTop / (float)nInner;
    bottomLenInner = innerPerimeterBottom / (float)nInner;
  } else {
    // Traditional concentric polygon (same number of sides)
    nInner = n;
    float[] insetResult = new float[2];
    calculateUniformInset(topLen, bottomLen, wallThickness_px, insetResult);
    topLenInner = insetResult[0];
    bottomLenInner = insetResult[1];
  }
  
  // === OUTER WALL ===
  pushStyle();
  fill(0);
  textAlign(LEFT, TOP);
  textSize(14);
  text("OUTER WALL", startX, startY - 20);
  popStyle();
  
  // Draw outer wall panels and all features using standard functions
  pushMatrix();
  drawTrapezoids(startX, startY, topLen, bottomLen, h, m, n, showMesh);
  drawTzFoldlines(startX, startY, topLen, bottomLen, h, m, n);
  drawTzTopFolds(startX, startY, topLen, bottomLen, h, m, n);
  popMatrix();
  

  
  // === INNER WALL ===
  // Calculate spacing for inner wall (place it below outer wall)
  float outerStripHeight = h + abs((topLen - bottomLen) / (2.0 * tan(PI / n))) * 2;
  float innerWallX = startX + uiInnerWallOffsetX * MM_current;
  float innerWallY = startY + outerStripHeight + 50 + uiInnerWallOffsetY * MM_current; // 50px base spacing
  
  pushStyle();
  fill(0);
  textAlign(LEFT, TOP);
  textSize(14);
  text("INNER WALL", innerWallX, innerWallY - 20);
  popStyle();
  
  // Calculate custom parameters for inner wall
  // Tab inset = 1/4 of panel width (gives tab width = 1/2 panel width)
  float innerTabInset_bot = bottomLenInner / 4.0;
  float innerTabInset_top = topLenInner / 4.0;
  float innerArrowheadFlare_bot = innerTabInset_bot / 3.0;  // arrowheadFlare = tabInset / 3
  float innerArrowheadFlare_top = innerTabInset_top / 3.0;
  
  // Tab depth: ALWAYS 10mm for easy construction
  // A fold line will be added at wall thickness
  float innerTabDepth = INNER_TAB_DEPTH_MM * MM_current;
  
  // Scale neck depth proportionally
  float scaleRatio = innerTabDepth / tabDepth_px;
  float innerNeckDepth = neckDepth_px * scaleRatio;
  
  // Calculate fold line position (at wall thickness)
  float foldLineDepth = wallThickness * MM_current;
  
  // Flap depth: space on each side not covered by lid tab
  float lidTabWidth = bottomLenInner - 2 * innerTabInset_bot;
  float innerFlapDepth = (bottomLenInner - lidTabWidth) / 2.0;
  
  // Temporarily save and replace global parameters
  float savedFlapDepth = flapDepth_px;
  float savedTabInset_bot = tabInset_bot_px;
  float savedTabInset_top = tabInset_top_px;
  float savedArrowheadFlare_bot = arrowheadFlare_bot_px;
  float savedArrowheadFlare_top = arrowheadFlare_top_px;
  float savedTabDepth = tabDepth_px;
  float savedNeckDepth = neckDepth_px;
  
  flapDepth_px = innerFlapDepth;
  tabInset_bot_px = innerTabInset_bot;
  tabInset_top_px = innerTabInset_top;
  arrowheadFlare_bot_px = innerArrowheadFlare_bot;
  arrowheadFlare_top_px = innerArrowheadFlare_top;
  tabDepth_px = innerTabDepth;
  neckDepth_px = innerNeckDepth;
  
  // Draw inner wall panels and all features using standard functions
  pushMatrix();
  drawTrapezoids(innerWallX, innerWallY, topLenInner, bottomLenInner, h, m, nInner, showMesh);
  drawTzFoldlines(innerWallX, innerWallY, topLenInner, bottomLenInner, h, m, nInner);
  drawTzTopFolds(innerWallX, innerWallY, topLenInner, bottomLenInner, h, m, nInner);
  popMatrix();
  
  // Restore original parameters
  flapDepth_px = savedFlapDepth;
  tabInset_bot_px = savedTabInset_bot;
  tabInset_top_px = savedTabInset_top;
  arrowheadFlare_bot_px = savedArrowheadFlare_bot;
  arrowheadFlare_top_px = savedArrowheadFlare_top;
  tabDepth_px = savedTabDepth;
  neckDepth_px = savedNeckDepth;
}

// ---------------------------------------------------------------------------
// AABB (axis-aligned bounding box) helpers for the strip + flaps.
// These simulate the transform loop without actually calling pushMatrix/rotate,
// so they can be called at any time without side effects on the draw state.
//
// Returns float[4] = { minX, minY, maxX, maxY } in the local coordinate frame
// that drawTrapezoids / drawTrapezoidsPerEdge receives (i.e. relative to origin
// 0,0 which is the bottom-left of the first panel at y=0).
// ---------------------------------------------------------------------------

// Uniform-polygon mode: all panels share the same topLen / bottomLen.
float[] computeStripAABB_Uniform(float topLen, float bottomLen, float h, int m, int n) {
  float minX =  1e9, minY =  1e9;
  float maxX = -1e9, maxY = -1e9;

  // Running 2-D transform: position (tx,ty) + rotation (ca=cos, sa=sin), start at identity.
  float tx = 0, ty = 0, ca = 1, sa = 0;

  for (int count = 0; count < n; count++) {
    float mh = h / (float)m;

    // Corners of the full panel in its local frame (i=0..m-1 sub-panels)
    // Bottom-left of sub-panel 0: (offset*0, 0) = (0, 0) -- BUT offset for sub 0 is:
    //   offset(0) = (bottom0 - top0)/2  where bottom0 = ((top-bot)*0/m + bot) = bot,  top0 = ((top-bot)*1/m + bot)
    // The full panel corners in local frame are:
    //   BL = (0, 0)  (offset of sub 0 at i=0 with i multiplied)
    //   BR = (bottomLen, 0)
    //   TR = ((bottomLen-topLen)/2 + topLen, h) = ((bottomLen+topLen)/2, h)  ... simplified: right top of last sub
    //   TL = (bottomLen-topLen)/2, h)
    // For sub-panel i=0: offset = (bot-top)/2, BL = (0,0), BR=(bot,0), TL=(offset,mh), TR=(offset+top_sub,mh)
    // For the full panel: BL=(0,0), BR=(bot,0), TR=((bot+top)/2, h) [conceptually], TL=((bot-top)/2, h)
    // Actually the formula accumulates per row; full-panel corners:
    float panelBLx = 0, panelBLy = 0;
    float panelBRx = bottomLen, panelBRy = 0;
    float panelTLx = (bottomLen - topLen) / 2.0, panelTLy = h;
    float panelTRx = (bottomLen + topLen) / 2.0, panelTRy = h;

    // Transform the 4 corners to world space and accumulate AABB.
    // Also include the tab extents: bottom tabs extend -tabDepth in local Y (above the strip on screen),
    // top tabs extend +tabDepth in local Y (below the strip on screen).
    // Transforming these through the running rotation matrix gives geometrically accurate world-space bounds.
    float[][] corners = {
      {panelBLx, panelBLy},
      {panelBRx, panelBRy},
      {panelTLx, panelTLy},
      {panelTRx, panelTRy},
      {panelBLx, panelBLy - tabDepth_px},  // bottom-tab top-left
      {panelBRx, panelBRy - tabDepth_px},  // bottom-tab top-right
      {panelTLx, panelTLy + tabDepth_px},  // top-tab bottom-left
      {panelTRx, panelTRy + tabDepth_px}   // top-tab bottom-right
    };
    for (float[] c : corners) {
      float wx = tx + ca * c[0] - sa * c[1];
      float wy = ty + sa * c[0] + ca * c[1];
      if (wx < minX) minX = wx;
      if (wx > maxX) maxX = wx;
      if (wy < minY) minY = wy;
      if (wy > maxY) maxY = wy;
    }

    // First panel: include the left flap corners.
    // Left edge runs from BL=(0,0) to TL=((bot-top)/2, h).
    // The flap is a trapezoid perpendicular to this edge, going outward (negative x side).
    if (count == 0) {
      float ex = panelTLx - panelBLx;   // edge vector
      float ey = panelTLy - panelBLy;
      float len = sqrt(ex*ex + ey*ey);
      // Left perpendicular (pointing left = outward for left flap)
      float px = -(ey / len) * flapDepth_px;
      float py =  (ex / len) * flapDepth_px;
      // Outer corners of flap
      float[][] flapCorners = {
        {panelBLx + px, panelBLy + py},
        {panelTLx + px, panelTLy + py}
      };
      for (float[] c : flapCorners) {
        float wx = tx + ca * c[0] - sa * c[1];
        float wy = ty + sa * c[0] + ca * c[1];
        if (wx < minX) minX = wx;
        if (wx > maxX) maxX = wx;
        if (wy < minY) minY = wy;
        if (wy > maxY) maxY = wy;
      }
    }

    // Last panel: include the right flap corners.
    // Right edge runs from BR=(bot,0) to TR=((bot+top)/2, h).
    if (count == n - 1) {
      float ex = panelTRx - panelBRx;
      float ey = panelTRy - panelBRy;
      float len = sqrt(ex*ex + ey*ey);
      // Right perpendicular (pointing right = outward for right flap)
      float px =  (ey / len) * flapDepth_px;
      float py = -(ex / len) * flapDepth_px;
      float[][] flapCorners = {
        {panelBRx + px, panelBRy + py},
        {panelTRx + px, panelTRy + py}
      };
      for (float[] c : flapCorners) {
        float wx = tx + ca * c[0] - sa * c[1];
        float wy = ty + sa * c[0] + ca * c[1];
        if (wx < minX) minX = wx;
        if (wx > maxX) maxX = wx;
        if (wy < minY) minY = wy;
        if (wy > maxY) maxY = wy;
      }
    }

    // Advance transform to next panel (mirrors drawTrapezoids transform step).
    if (count < n - 1) {
      // Same formula as in drawTrapezoids / drawTzTopFolds / drawTzFoldlines
      float aA = atan2(h, (topLen - bottomLen) / 2.0);
      float aB = atan2(h, (bottomLen - topLen) / 2.0);
      float rot = aA - aB;
      // Apply translate(bottomLen, 0) in local frame, then rotate(rot)
      float newTx = tx + ca * bottomLen;
      float newTy = ty + sa * bottomLen;
      float newCa = ca * cos(rot) - sa * sin(rot);
      float newSa = sa * cos(rot) + ca * sin(rot);
      tx = newTx; ty = newTy; ca = newCa; sa = newSa;
    }
  }

  return new float[]{ minX, minY, maxX, maxY };
}

// Dispatcher: picks uniform or per-edge based on current globals.
float[] computeStripAABB() {
  if ((perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null) {
    return computeStripAABB_PerEdge(edgeTop_px, edgeBot_px, cylinderH_px, cols - 1);
  } else {
    return computeStripAABB_Uniform(cellTopL_px, cellBaseL_px, cylinderH_px, cols - 1, rows - 1);
  }
}
