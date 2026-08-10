//----------------------------------------------------------------------
// code needed to be able to variate the length of the sides of the polygon without breaking the polygon
//
//------------------UPDATES---------------------
// 20251105 - pulled this code apart from the rest to make it slighly more readable.
// 20251105 - lids were turned 45 degrees, making them increasingly harder to draw, but might be a useful function to place more things on the page so ill keep  the code
// 20251105
//------------------------------------------------------------------------------------


void drawPolygonLidVar_Legacy(float[] sidePx, float neckDepth, float tabInset, float arrowFlare) {// We roteren het hele lid zodat chord 0 horizontaal is
  int n = (sidePx == null) ? 0 : sidePx.length;
  if (n < 3) return;
  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);

  float R    = solveRadiusForChordSet(sidePx);
  float ang0 = -HALF_PI;

  // Determine chord 0 orientation and align horizontally
  float s0   = sidePx[0];
  float th0  = 2.0f * (float)Math.asin(_clampf(s0/(2.0f*R), CLAMP_EPSILON, CLAMP_MAX));
  PVector p0a = new PVector(R * cos(ang0), R * sin(ang0));
  PVector p0b = new PVector(R * cos(ang0 + th0), R * sin(ang0 + th0));
  float angle0 = atan2(p0b.y - p0a.y, p0b.x - p0a.x);
  pushMatrix();
  rotate(-angle0); // chord 0 horizontaal

  float ang = ang0;
  for (int i = 0; i < n; i++) {
    float s     = sidePx[i];
    float theta = 2.0f * (float)Math.asin(_clampf(s/(2.0f*R), 1e-6f, 0.999999f));

    // chord-endpoints in wereldcoördinaten (vóór local rot/translate)
    PVector p0 = new PVector(R * cos(ang), R * sin(ang));
    PVector p1 = new PVector(R * cos(ang + theta), R * sin(ang + theta));
    PVector d  = PVector.sub(p1, p0);
    float   L  = d.mag();
    if (L <= 1e-6f) {
      ang += theta;
      continue;
    }

    float localInset = min(tabInset, TAB_INSET_RATIO * L);
    pushMatrix();
    translate(p0.x, p0.y);
    rotate(atan2(d.y, d.x));

    // met horizontale d=(L,0) en p=(0,0) zoals in uniform mode.
    PVector P = new PVector(0, 0);
    PVector D = new PVector(L, 0);

    // dashed fold
    drawBottomTabContour(P, D, tabDepth_px, localInset, arrowFlare, neckDepth);
    popMatrix();
    ang += theta;
  }
  popMatrix();
}

void drawTzFoldlinesPerEdge(float startX, float startY,
  float[] topLensPx, float[] botLensPx,
  float hPx, int m) {
  if (topLensPx == null || botLensPx == null) return;
  int n = min(topLensPx.length, botLensPx.length);
  if (n < 3) return;

  translate(startX, startY);

  for (int edgeIdx = 0; edgeIdx < n; edgeIdx++) {
    float wTop = max(0.001f, topLensPx[edgeIdx]);
    float wBot = max(0.001f, botLensPx[edgeIdx]);

    // 1:1 like original fold voor 1 paneel
    drawTzFoldlines(0, 0, wTop, wBot, hPx, m, /*n=*/1);

    if (edgeIdx < n-1) {
      PVector A_right   = new PVector((wTop - wBot)/2.0f, hPx);
      float   offsetNext= (wBot - wTop)/2.0f;
      PVector B_left    = new PVector(offsetNext, hPx);

      float angleA = atan2(A_right.y, A_right.x);
      float angleB = atan2(B_left.y, B_left.x);
      float rot    = angleA - angleB;

      translate(wBot, 0);
      rotate(rot);
    }
  }
}

void pe_SetNormalizeTargetToCurrentPerimeter() {
  uiNormalizeTarget = cylinder.x;
}
void pe_ClearNormalizeTarget() {
  uiNormalizeTarget = 0;
} // 0 = auto

// Clamp float value between bounds (uses constants from Param.pde)
float _clampf(float v, float lo, float hi) {
  return max(lo, min(hi, v));
}

// Draw horizontal fold lines on tabs at specified depth (for inner wall tabs in per-edge mode)
void drawTabFoldLinesPerEdge(float startX, float startY, float[] topLensPx, float[] botLensPx, float hPx, int m, float foldDepth) {
  if (topLensPx == null || botLensPx == null) return;
  int n = min(topLensPx.length, botLensPx.length);
  if (n < 3) return;
  
  pushMatrix();
  translate(startX, startY);
  
  pushStyle();
  stroke(uiLightGrayCutLines ? 180 : 0);
  
  for (int edgeIdx = 0; edgeIdx < n; edgeIdx++) {
    float wTop = max(0.001f, topLensPx[edgeIdx]);
    float wBot = max(0.001f, botLensPx[edgeIdx]);
    float mh   = hPx / (float)m;

    for (int i = 0; i < m; i++) {
      float segTop = ((wTop - wBot) * (i+1) / (float)m) + wBot;
      float segBot = ((wTop - wBot) *  i    / (float)m) + wBot;
      float off    = (segBot - segTop) / 2.0f;

      PVector pb = new PVector(off*i, mh*i);
      PVector db = new PVector(segBot, 0);
      PVector pt = new PVector(off*i + off, mh*i + mh);
      PVector dt = new PVector(segTop, 0);
      
      float localInsetBot = segBot / 4.0;
      float localInsetTop = segTop / 4.0;
      
      // Draw fold line on bottom tab
      drawDashedLine(pb.x + localInsetBot*2, pb.y + db.y + foldDepth,
                     pb.x + db.x - localInsetBot*0, pb.y + db.y + foldDepth,
                     dash_px, gap_px);
      
      // Draw fold line on top tab
      drawDashedLine(pt.x + localInsetTop*0, pt.y - foldDepth,
                     pt.x + dt.x - localInsetTop*2, pt.y - foldDepth,
                     dash_px, gap_px);
    }

    // Advance to next panel
    if (edgeIdx < n-1) {
      float wTopNext = max(0.001f, topLensPx[edgeIdx+1]);
      float wBotNext = max(0.001f, botLensPx[edgeIdx+1]);
      PVector A_right  = new PVector((wTop - wBot)/2.0f, hPx);
      float offNext    = (wBotNext - wTopNext)/2.0f;
      PVector B_left   = new PVector(offNext, hPx);
      float angleA     = atan2(A_right.y, A_right.x);
      float angleB     = atan2(B_left.y, B_left.x);
      float rotNeeded  = angleA - angleB;
      translate(wBot, 0);
      rotate(rotNeeded);
    }
  }
  
  popStyle();
  popMatrix();
}

void drawTrapezoidsPerEdge(float startX, float startY, float[] topLensPx, float[] botLensPx, float hPx, int m, boolean drawTabs) {
  // Build uniform height array and delegate
  if (topLensPx == null || botLensPx == null) return;
  int n = min(topLensPx.length, botLensPx.length);
  float[] hArr = new float[n];
  for (int i = 0; i < n; i++) hArr[i] = hPx;
  drawTrapezoidsPerEdge(startX, startY, topLensPx, botLensPx, hArr, m, drawTabs);
}

void drawTrapezoidsPerEdge(float startX, float startY, float[] topLensPx, float[] botLensPx, float[] hPxArr, int m, boolean drawTabs) {
  if (topLensPx == null || botLensPx == null || hPxArr == null) return;
  int n = min(topLensPx.length, min(botLensPx.length, hPxArr.length));
  if (n < 3) return;

  translate(startX, startY);
  stroke(uiLightGrayCutLines ? 180 : 0);
  noFill();

  for (int edgeIdx = 0; edgeIdx < n; edgeIdx++) {
    float wTop = max(0.001f, topLensPx[edgeIdx]);
    float wBot = max(0.001f, botLensPx[edgeIdx]);
    float hPx  = hPxArr[edgeIdx];
    float mh   = hPx / (float)m;

    float localInsetTop = TAB_INSET_RATIO * wTop;
    float localInsetBot = TAB_INSET_RATIO * wBot;
    float localTabDepth = min(tabDepth_px, 0.5f * min(wTop, wBot));

    // Bewaar outer contour (onder/ boven) van het paneel
    PVector pb0=null, db0=null;   // onderste linker hoek + onder vector
    PVector ptL=null, dtL=null;   // boven linker hoek (laatste subpaneel) + boven vector (laatste sub)

    for (int i = 0; i < m; i++) {
      float segTop = ((wTop - wBot) * (i+1) / (float)m) + wBot;
      float segBot = ((wTop - wBot) *  i    / (float)m) + wBot;
      float off    = (segBot - segTop) / 2.0f;

      PVector pb = new PVector(off*i, mh*i);            // bottom-left subpaneel i
      PVector db = new PVector(segBot, 0);
      PVector pt = new PVector(off*i + off, mh*i + mh); // top-left subpaneel i
      PVector dt = new PVector(segTop, 0);

      if (i == 0) {
        pb0 = pb.copy();
        db0 = db.copy();
      } // onderrand van VOL paneel
      if (i == m-1) {
        ptL = pt.copy();
        dtL = dt.copy();
      } // bovenrand van VOL paneel

      // Alleen tabs per segment:
      if (drawTabs) {
        drawBottomTabContour(pb, db, localTabDepth, localInsetBot, arrowheadFlare_bot_px, neckDepth_px);
        drawTopTabContour   (pt, dt, localTabDepth, localInsetTop, arrowheadFlare_top_px, neckDepth_px);
      }
    }

    // hier tekenen we de dashlijnen tussen de panelen
    if (pb0 != null && db0 != null && ptL != null && dtL != null) {
      PVector BL = pb0.copy();                  // bottom-left
      PVector BR = PVector.add(pb0, db0);       // bottom-right
      PVector TR = PVector.add(ptL, dtL);       // top-right
      PVector TL = ptL.copy();                  // top-left
      float inset = 0; // evt. tabInset_h_px

      // linkerrand ALLEEN als dit niet het eerste paneel is, of dus, alle panelen behalv de eerste
      if (edgeIdx > 0) {
        drawDashedLine(TL.x, TL.y - inset, BL.x, BL.y + inset, dash_px, gap_px);
      }
    }

    // Side flaps
    if (edgeIdx == 0 && pb0 != null && ptL != null) {
      drawLeftSlantFlap(pb0, ptL, flapDepth_px, flapTaper_px, tabInset_h_px);
    }
    if (edgeIdx == n-1 && pb0 != null && ptL != null && db0 != null && dtL != null) {
      PVector p2 = PVector.add(pb0, db0); // bottom-right
      PVector p3 = PVector.add(ptL, dtL); // top-right
      drawRightSlantFlap(p2, p3, flapDepth_px, tabInset_h_px, arrowheadFlare_h_px, neckDepth_hook_px, hookOffset_px);
    }

    // Rotatie/vertaling naar volgende paneel --> goal: naadloos aansluiten
    if (edgeIdx < n-1) {
      float wTopNext = max(0.001f, topLensPx[edgeIdx+1]);
      float wBotNext = max(0.001f, botLensPx[edgeIdx+1]);
      PVector A_right  = new PVector((wTop - wBot)/2.0f, hPx);
      float   offNext  = (wBotNext - wTopNext)/2.0f;
      PVector B_left   = new PVector(offNext, hPx);
      float angleA     = atan2(A_right.y, A_right.x);
      float angleB     = atan2(B_left.y, B_left.x);
      float rotNeeded  = angleA - angleB;
      translate(wBot, 0);
      rotate(rotNeeded);
    }
  }
}

// ---------------------------------------------------------------------------
// Split-aware version of drawTrapezoidsPerEdge: draws panels [panelStart..panelEnd)
// with optional left/right flaps.
// ---------------------------------------------------------------------------
void drawTrapezoidsPerEdge_Range(float startX, float startY, float[] topLensPx, float[] botLensPx, 
                                  float hPx, int m, boolean drawTabs, int panelStart, int panelEnd,
                                  boolean leftFlap, boolean rightFlap) {
  if (topLensPx == null || botLensPx == null) return;
  int totalN = min(topLensPx.length, botLensPx.length);
  if (totalN < 3) return;
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;

  translate(startX, startY);
  stroke(uiLightGrayCutLines ? 180 : 0);
  noFill();

  for (int localIdx = 0; localIdx < nPanels; localIdx++) {
    int edgeIdx = panelStart + localIdx;
    float wTop = max(0.001f, topLensPx[edgeIdx]);
    float wBot = max(0.001f, botLensPx[edgeIdx]);
    float mh   = hPx / (float)m;

    float localInsetTop = TAB_INSET_RATIO * wTop;
    float localInsetBot = TAB_INSET_RATIO * wBot;
    float localTabDepth = min(tabDepth_px, 0.5f * min(wTop, wBot));

    PVector pb0=null, db0=null;
    PVector ptL=null, dtL=null;

    for (int i = 0; i < m; i++) {
      float segTop = ((wTop - wBot) * (i+1) / (float)m) + wBot;
      float segBot = ((wTop - wBot) *  i    / (float)m) + wBot;
      float off    = (segBot - segTop) / 2.0f;

      PVector pb = new PVector(off*i, mh*i);
      PVector db = new PVector(segBot, 0);
      PVector pt = new PVector(off*i + off, mh*i + mh);
      PVector dt = new PVector(segTop, 0);

      if (i == 0) { pb0 = pb.copy(); db0 = db.copy(); }
      if (i == m-1) { ptL = pt.copy(); dtL = dt.copy(); }

      if (drawTabs) {
        drawBottomTabContour(pb, db, localTabDepth, localInsetBot, arrowheadFlare_bot_px, neckDepth_px);
        drawTopTabContour   (pt, dt, localTabDepth, localInsetTop, arrowheadFlare_top_px, neckDepth_px);
      }
    }

    // Fold lines between panels (left edge dashed line for non-first)
    if (pb0 != null && db0 != null && ptL != null && dtL != null) {
      PVector BL = pb0.copy();
      PVector TL = ptL.copy();
      if (localIdx > 0) {
        drawDashedLine(TL.x, TL.y, BL.x, BL.y, dash_px, gap_px);
      }
    }

    // Side flaps
    if (localIdx == 0 && leftFlap && pb0 != null && ptL != null) {
      drawLeftSlantFlap(pb0, ptL, flapDepth_px, flapTaper_px, tabInset_h_px);
    }
    if (localIdx == nPanels - 1 && rightFlap && pb0 != null && ptL != null && db0 != null && dtL != null) {
      PVector p2 = PVector.add(pb0, db0);
      PVector p3 = PVector.add(ptL, dtL);
      drawRightSlantFlap(p2, p3, flapDepth_px, tabInset_h_px, arrowheadFlare_h_px, neckDepth_hook_px, hookOffset_px);
    }

    // Transform to next panel
    if (localIdx < nPanels - 1) {
      int nextEdgeIdx = edgeIdx + 1;
      float wTopNext = max(0.001f, topLensPx[nextEdgeIdx]);
      float wBotNext = max(0.001f, botLensPx[nextEdgeIdx]);
      PVector A_right  = new PVector((wTop - wBot)/2.0f, hPx);
      float   offNext  = (wBotNext - wTopNext)/2.0f;
      PVector B_left   = new PVector(offNext, hPx);
      float angleA     = atan2(A_right.y, A_right.x);
      float angleB     = atan2(B_left.y, B_left.x);
      float rotNeeded  = angleA - angleB;
      translate(wBot, 0);
      rotate(rotNeeded);
    }
  }
}

// Split-aware per-edge fold lines: draws fold lines for panels [panelStart..panelEnd)
void drawTzFoldlinesPerEdge_Range(float startX, float startY, float[] topLensPx, float[] botLensPx, 
                                   float hPx, int m, int panelStart, int panelEnd) {
  if (topLensPx == null || botLensPx == null) return;
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;

  pushMatrix();
  translate(startX, startY);
  stroke(uiLightGrayCutLines ? 180 : 0);
  noFill();

  for (int localIdx = 0; localIdx < nPanels; localIdx++) {
    int edgeIdx = panelStart + localIdx;
    float wTop = max(0.001f, topLensPx[edgeIdx]);
    float wBot = max(0.001f, botLensPx[edgeIdx]);
    float mh   = hPx / (float)m;

    for (int i = 0; i < m; i++) {
      float segTop = ((wTop - wBot) * (i+1) / (float)m) + wBot;
      float segBot = ((wTop - wBot) *  i    / (float)m) + wBot;
      float off    = (segBot - segTop) / 2.0f;
      PVector pb = new PVector(off*i, mh*i);
      PVector pt = new PVector(off*i + off, mh*i + mh);
      // Right edge fold line (between this and next panel)
      if (localIdx < nPanels - 1 && !uiHidePanelFolds) {
        PVector p1 = new PVector(pb.x + segBot, pb.y);
        PVector p2 = new PVector(pt.x + segTop, pt.y);
        drawDashedLine(p1.x, p1.y, p2.x, p2.y, dash_px, gap_px);
      }
    }

    if (localIdx < nPanels - 1) {
      int nextEdgeIdx = edgeIdx + 1;
      float wTopNext = max(0.001f, topLensPx[nextEdgeIdx]);
      float wBotNext = max(0.001f, botLensPx[nextEdgeIdx]);
      PVector A_right  = new PVector((wTop - wBot)/2.0f, hPx);
      float   offNext  = (wBotNext - wTopNext)/2.0f;
      PVector B_left   = new PVector(offNext, hPx);
      float angleA     = atan2(A_right.y, A_right.x);
      float angleB     = atan2(B_left.y, B_left.x);
      float rotNeeded  = angleA - angleB;
      translate(wBot, 0);
      rotate(rotNeeded);
    }
  }
  popMatrix();
}

// ---- Variable lids-------------
// Solve for circumradius using binary search (constants from Param.pde)
float solveRadiusForChordSet(float[] chordPx) {
  float hi = 0;
  for (float s : chordPx) hi = max(hi, s);
  float lo = hi * RADIUS_SOLVER_MIN_RATIO;    // R > s/2
  hi *= RADIUS_SOLVER_MAX_RATIO;

  for (int it = 0; it < RADIUS_SOLVER_ITERATIONS; it++) {
    float mid = 0.5f*(lo+hi);
    double sum = 0.0;
    for (float s : chordPx) {
      double v = _clampf(s/(2.0f*mid), CLAMP_EPSILON, CLAMP_MAX);
      sum += 2.0 * Math.asin(v);
    }
    if (sum > TWO_PI) lo = mid;
    else hi = mid;
  }
  return 0.5f*(lo+hi);
}

//----------------------------------------------------------------------
// HOLLOW MODE: Polygon Offset Calculation
//----------------------------------------------------------------------
// Calculate inner edge lengths for hollow mode by scaling proportionally
// based on radius reduction. Returns null if inset is invalid.
float[] calculateInsetEdges(float[] outerEdges, float insetDistance) {
  if (outerEdges == null || outerEdges.length < 3) return null;
  if (insetDistance <= 0) return outerEdges.clone();
  
  // Solve for outer radius
  float outerRadius = solveRadiusForChordSet(outerEdges);
  
  // Calculate inner radius
  float innerRadius = outerRadius - insetDistance;
  
  // Check if inner radius is valid (must be positive and large enough)
  if (innerRadius <= 0.001f || innerRadius < insetDistance * 0.5f) {
    println("[WARNING] Wall thickness " + (insetDistance/MM) + "mm is too large for this polygon. Max allowed: ~" + (outerRadius * 0.8 / MM) + "mm");
    return null;
  }
  
  // Scale each edge proportionally: innerEdge = outerEdge * (innerRadius / outerRadius)
  float scaleFactor = innerRadius / outerRadius;
  float[] innerEdges = new float[outerEdges.length];
  
  for (int i = 0; i < outerEdges.length; i++) {
    innerEdges[i] = outerEdges[i] * scaleFactor;
  }
  
  // Verify the inner polygon closes properly (should sum to 2π)
  float innerRadiusCheck = solveRadiusForChordSet(innerEdges);
  if (abs(innerRadiusCheck - innerRadius) > 1.0f) {
    println("[WARNING] Inner polygon validation failed. Expected R=" + innerRadius + ", got R=" + innerRadiusCheck);
  }
  
  return innerEdges;
}

// Calculate uniform inset (for regular polygons in uniform mode)
void calculateUniformInset(float outerTop, float outerBot, float insetDistance, 
                           float[] result) {
  // result[0] = innerTop, result[1] = innerBot
  if (result == null || result.length < 2) return;
  
  // For uniform mode, we can use simple geometric calculation
  // Inner perimeter = outer perimeter - 2 * inset * nSides / tan(PI/nSides)
  float circumradiusTop = outerTop / (2.0 * sin(PI / nSides));
  float circumradiusBot = outerBot / (2.0 * sin(PI / nSides));
  
  float innerRadiusTop = circumradiusTop - insetDistance;
  float innerRadiusBot = circumradiusBot - insetDistance;
  
  if (innerRadiusTop <= 0 || innerRadiusBot <= 0) {
    println("[WARNING] Wall thickness too large for current polygon size");
    result[0] = outerTop * 0.5f;  // Fallback to 50% scale
    result[1] = outerBot * 0.5f;
    return;
  }
  
  result[0] = 2.0 * innerRadiusTop * sin(PI / nSides);
  result[1] = 2.0 * innerRadiusBot * sin(PI / nSides);
}

// Validate if hollow mode parameters are geometrically valid
boolean validateHollowModeParameters() {
  if (!hollowMode) return true;
  
  // Check uniform mode
  if (!perEdgeMode && !cuboidMode) {
    float circumradiusTop = (cylinderTP_px / nSides) / (2.0 * sin(PI / nSides));
    float circumradiusBot = (cylinderBP_px / nSides) / (2.0 * sin(PI / nSides));
    float minRadius = min(circumradiusTop, circumradiusBot);
    
    if (wallThickness_px >= minRadius * 0.8) {
      return false;
    }
    
    // Check inner shape parameters (if different inner shape is enabled)
    if (enableInnerShape) {
      if (!validateInnerShapeParameters()) {
        return false;
      }
    }
  } else {
    // Check per-edge mode
    float outerRadius = solveRadiusForChordSet(edgeTop_px);
    if (wallThickness_px >= outerRadius * 0.8) {
      return false;
    }
    
    // Note: Different inner shapes not supported in per-edge mode yet
  }
  
  return true;
}

void drawPolygonLidVar(float[] sidePx, float neckDepth, float tabInset, float arrowFlare) {
  int n = (sidePx == null) ? 0 : sidePx.length;
  if (n < 3) return;

  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);

  float R = solveRadiusForChordSet(sidePx);
  float ang0 = -HALF_PI;

  // Hoek van chord 0 bepalen (voor uitlijning)
  float s0    = sidePx[0];
  float th0   = 2.0f * (float)Math.asin(_clampf(s0/(2.0f*R), 1e-6f, 0.999999f));
  PVector p0a = new PVector(R * cos(ang0), R * sin(ang0));
  PVector p0b = new PVector(R * cos(ang0 + th0), R * sin(ang0 + th0));
  float angle0 = atan2(p0b.y - p0a.y, p0b.x - p0a.x); // huidige richting chord0

  pushMatrix();
  rotate(-angle0); // maak chord0 horizontaal zodat de lids niet gedraaid staan

  float ang = ang0;
  for (int i = 0; i < n; i++) {
    float s     = sidePx[i];
    float theta = 2.0f * (float)Math.asin(_clampf(s/(2.0f*R), 1e-6f, 0.999999f));

    PVector p0 = new PVector(R * cos(ang), R * sin(ang));
    PVector p1 = new PVector(R * cos(ang + theta), R * sin(ang + theta));

    float localInset = min(tabInset, TAB_INSET_RATIO * s);

    // Tab + dashed fold in chordframe
    drawTabOnChord(p0, p1, tabDepth_px, localInset, arrowFlare, neckDepth);

    // Optioneel: chord zelf
    line(p0.x, p0.y, p1.x, p1.y);

    ang += theta;
  }

  popMatrix();
}

// Tessellated textured variable polygon lid
void drawTessellatedPolygonLidVar(float[] sidePx, PImage img, int density, boolean keepAspect) {
  int n = (sidePx == null) ? 0 : sidePx.length;
  if (n < 3 || img == null || density < 1) return;

  float R = solveRadiusForChordSet(sidePx);
  float ang0 = -HALF_PI;

  // Align chord 0 horizontally
  float s0 = sidePx[0];
  float th0 = 2.0f * (float)Math.asin(_clampf(s0/(2.0f*R), 1e-6f, 0.999999f));
  PVector p0a = new PVector(R * cos(ang0), R * sin(ang0));
  PVector p0b = new PVector(R * cos(ang0 + th0), R * sin(ang0 + th0));
  float angle0 = atan2(p0b.y - p0a.y, p0b.x - p0a.x);

  pushMatrix();
  rotate(-angle0);

  // Center point
  float cx = 0, cy = 0;
  
  // Image center and UV radius
  float imgCX = img.width * 0.5f;
  float imgCY = img.height * 0.5f;
  float uvRadius = min(img.width, img.height) * 0.5f;

  noStroke();
  textureMode(IMAGE);
  textureWrap(CLAMP);
  hint(ENABLE_TEXTURE_MIPMAPS);

  beginShape(TRIANGLES);
  texture(img);

  float ang = ang0;
  for (int side = 0; side < n; side++) {
    float s = sidePx[side];
    float theta = 2.0f * (float)Math.asin(_clampf(s/(2.0f*R), 1e-6f, 0.999999f));

    float angle1 = ang;
    float angle2 = ang + theta;

    // Subdivide this wedge
    for (int ring = 0; ring < density; ring++) {
      float r0 = (float)ring / density;
      float r1 = (float)(ring + 1) / density;

      for (int arc = 0; arc < density; arc++) {
        float a0 = lerp(angle1, angle2, (float)arc / density);
        float a1 = lerp(angle1, angle2, (float)(arc + 1) / density);

        // World coordinates
        float x00 = cos(a0) * r0 * R;
        float y00 = sin(a0) * r0 * R;
        float x10 = cos(a1) * r0 * R;
        float y10 = sin(a1) * r0 * R;
        float x01 = cos(a0) * r1 * R;
        float y01 = sin(a0) * r1 * R;
        float x11 = cos(a1) * r1 * R;
        float y11 = sin(a1) * r1 * R;

        // UV coordinates - radial
        float u00 = imgCX + cos(a0) * r0 * uvRadius;
        float v00 = imgCY + sin(a0) * r0 * uvRadius;
        float u10 = imgCX + cos(a1) * r0 * uvRadius;
        float v10 = imgCY + sin(a1) * r0 * uvRadius;
        float u01 = imgCX + cos(a0) * r1 * uvRadius;
        float v01 = imgCY + sin(a0) * r1 * uvRadius;
        float u11 = imgCX + cos(a1) * r1 * uvRadius;
        float v11 = imgCY + sin(a1) * r1 * uvRadius;

        // Two triangles
        vertex(x00, y00, u00, v00);
        vertex(x10, y10, u10, v10);
        vertex(x01, y01, u01, v01);

        vertex(x10, y10, u10, v10);
        vertex(x11, y11, u11, v11);
        vertex(x01, y01, u01, v01);
      }
    }

    ang += theta;
  }

  endShape();
  popMatrix();
}


// LID BOUNDS/ALIGNMENT
PVector[] getPolygonLidVarBounds(float[] sidePx, float tabDepthPx) {
  // returns {minVec, maxVec} of chords; expanded by tabDepth in both axes
  int n = (sidePx == null) ? 0 : sidePx.length;
  if (n < 3) return new PVector[]{ new PVector(0, 0), new PVector(0, 0) };

  float R = solveRadiusForChordSet(sidePx);
  float ang = -HALF_PI;

  float minX =  1e9, minY =  1e9;
  float maxX = -1e9, maxY = -1e9;

  for (int i = 0; i < n; i++) {
    float s = sidePx[i];
    float theta = 2.0f * (float)Math.asin(_clampf(s/(2.0f*R), 1e-6f, 0.999999f));

    PVector p0 = new PVector( R * cos(ang), R * sin(ang) );
    PVector p1 = new PVector( R * cos(ang + theta), R * sin(ang + theta) );

    // update bounds with chord endpoints
    minX = min(minX, min(p0.x, p1.x));
    minY = min(minY, min(p0.y, p1.y));
    maxX = max(maxX, max(p0.x, p1.x));
    maxY = max(maxY, max(p0.y, p1.y));

    ang += theta;
  }

  // expand by tab depth
  minX -= tabDepthPx;
  minY -= tabDepthPx;
  maxX += tabDepthPx;
  maxY += tabDepthPx;

  return new PVector[]{ new PVector(minX, minY), new PVector(maxX, maxY) };
}

PVector getPolygonLidVarDimensions(float[] sidePx, float tabDepthPx) {
  PVector[] b = getPolygonLidVarBounds(sidePx, tabDepthPx);
  return new PVector(b[1].x - b[0].x, b[1].y - b[0].y);
}

PVector getPolygonLidVarOffset(float[] sidePx, float tabDepthPx) {
  PVector[] b = getPolygonLidVarBounds(sidePx, tabDepthPx);
  // translate so top-left aligns at (0,0)
  return new PVector(-b[0].x, -b[0].y);
}




///----------------------------
//might be useful later:

//old, not used now, might still be relevant later:
void drawTabOnChord(PVector p0, PVector p1, float tabDepth, float tabInset, float arrowFlare, float neckDepth) {
  PVector ex = PVector.sub(p1, p0);
  float   L  = ex.mag();
  if (L <= 1e-6f) return;
  ex.mult(1.0f / L);

  // Radiaal naar buiten: vanaf (0,0) naar chordmidden
  PVector mid = PVector.mult(PVector.add(p0, p1), 0.5f);
  PVector ey  = mid.copy();
  float mlen  = ey.mag();
  if (mlen <= 1e-6f) ey = new PVector(-ex.y, ex.x);
  else ey.mult(1.0f / mlen);

  float inset = min(tabInset, TAB_INSET_RATIO * L);

  // Binnenste punten (foldlijn) – dashed
  PVector fd0 = PVector.add(p0, PVector.mult(ex, inset));
  PVector fd1 = PVector.add(p1, PVector.mult(ex, -inset));
  drawDashedLine(fd0.x, fd0.y, fd1.x, fd1.y, dash_px, gap_px);

  // Contourpunten (let op: taper richting gecorrigeerd t.o.v. vorige versie)
  PVector a0 = p0.copy();
  PVector a1 = fd0.copy();
  PVector a2 = PVector.add(a1, PVector.mult(ey, neckDepth));
  PVector a3 = PVector.add(a1, PVector.add(PVector.mult(ey, tabDepth), PVector.mult(ex, +arrowFlare))); // <-- +flare

  PVector b7 = p1.copy();
  PVector b6 = fd1.copy();
  PVector b5 = PVector.add(b6, PVector.mult(ey, neckDepth));
  PVector b4 = PVector.add(b6, PVector.add(PVector.mult(ey, tabDepth), PVector.mult(ex, -arrowFlare))); // <-- -flare

  beginShape();
  vertex(a0.x, a0.y);
  vertex(a1.x, a1.y);
  vertex(a2.x, a2.y);
  vertex(a3.x, a3.y);
  vertex(b4.x, b4.y);
  vertex(b5.x, b5.y);
  vertex(b6.x, b6.y);
  vertex(b7.x, b7.y);
  endShape();
}
//----------------------------------------------------------------------
// HOLLOW MODE: Wrapper for variable prism double-wall drawing
//----------------------------------------------------------------------

// Draw variable trapezoid strip with cutouts for hollow mode (per-edge height array)
void drawTrapezoidsPerEdgeHollow(float startX, float startY, float[] edgeTop_px, 
                                 float[] edgeBot_px, float[] hPxArr, int m, boolean drawTabs) {
  if (!hollowMode) {
    // Normal single-wall mode
    drawTrapezoidsPerEdge(startX, startY, edgeTop_px, edgeBot_px, hPxArr, m, drawTabs);
    return;
  }
  // Hollow mode: use average height for inner wall calculation
  float hPx = 0;
  for (float h : hPxArr) hPx += h;
  hPx /= hPxArr.length;
  drawTrapezoidsPerEdgeHollow(startX, startY, edgeTop_px, edgeBot_px, hPx, m, drawTabs);
}

// Draw variable trapezoid strip with cutouts for hollow mode
void drawTrapezoidsPerEdgeHollow(float startX, float startY, float[] edgeTop_px, 
                                 float[] edgeBot_px, float hPx, int m, boolean drawTabs) {
  if (!hollowMode) {
    // Normal single-wall mode
    drawTrapezoidsPerEdge(startX, startY, edgeTop_px, edgeBot_px, hPx, m, drawTabs);
    return;
  }
  
  // NOTE: Per-edge mode with different inner shape (enableInnerShape) is not fully supported
  // Inner wall will use same number of sides as outer, with proportionally scaled edges
  if (enableInnerShape && nSidesInner != edgeTop_px.length) {
    println("[WARNING] Different inner shape not fully supported in per-edge mode.");
    println("          Inner wall will use " + edgeTop_px.length + " sides (same as outer).");
  }
  
  // Calculate inner edge dimensions
  float[] edgeTopInner = calculateInsetEdges(edgeTop_px, wallThickness_px);
  float[] edgeBotInner = calculateInsetEdges(edgeBot_px, wallThickness_px);
  
  if (edgeTopInner == null || edgeBotInner == null) {
    println("[ERROR] Cannot create hollow mode: wall thickness too large");
    // Fall back to normal mode
    drawTrapezoidsPerEdge(startX, startY, edgeTop_px, edgeBot_px, hPx, m, drawTabs);
    return;
  }
  
  int n = min(edgeTop_px.length, edgeBot_px.length);
  
  // === OUTER WALL ===
  pushStyle();
  fill(0);
  textAlign(LEFT, TOP);
  textSize(14);
  text("OUTER WALL", startX, startY - 20);
  popStyle();
  
  // Draw outer wall panels and all features using standard functions
  pushMatrix();
  drawTrapezoidsPerEdge(startX, startY, edgeTop_px, edgeBot_px, hPx, m, drawTabs);
  drawTzFoldlinesPerEdge(startX, startY, edgeTop_px, edgeBot_px, hPx, m);
  popMatrix();
  
  // === INNER WALL ===
  // Calculate spacing for inner wall
  float outerStripHeight = hPx + 100; // Approximate
  float innerWallX = startX + uiInnerWallOffsetX * MM_current;
  float innerWallY = startY + outerStripHeight + 50 + uiInnerWallOffsetY * MM_current;
  
  pushStyle();
  fill(0);
  textAlign(LEFT, TOP);
  textSize(14);
  text("INNER WALL", innerWallX, innerWallY - 20);
  popStyle();
  
  // Calculate custom parameters for inner wall  
  // All tab dimensions must match lid tab scaling
  // Lid inner tabs use: tabInset = (sideLength / 4) * 0.9
  // For variable polygons, use averages of inner edges
  float avgBottomInner = 0;
  float avgTopInner = 0;
  for (int i = 0; i < edgeBotInner.length; i++) {
    avgBottomInner += edgeBotInner[i];
  }
  for (int i = 0; i < edgeTopInner.length; i++) {
    avgTopInner += edgeTopInner[i];
  }
  avgBottomInner /= edgeBotInner.length;
  avgTopInner /= edgeTopInner.length;
  
  // Tab inset = 1/4 of panel width (gives tab width = 1/2 panel width)
  float innerTabInset_bot = avgBottomInner / 4.0;
  float innerTabInset_top = avgTopInner / 4.0;
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
  float lidTabWidth = avgBottomInner - 2 * innerTabInset_bot;
  float innerFlapDepth = (avgBottomInner - lidTabWidth) / 2.0;
  
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
  drawTrapezoidsPerEdge(innerWallX, innerWallY, edgeTopInner, edgeBotInner, hPx, m, drawTabs);
  drawTzFoldlinesPerEdge(innerWallX, innerWallY, edgeTopInner, edgeBotInner, hPx, m);
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
// Per-edge AABB simulation: mirrors drawTrapezoidsPerEdge transform loop.
// Returns float[4] = { minX, minY, maxX, maxY } in the strip's local frame.
// ---------------------------------------------------------------------------
float[] computeStripAABB_PerEdge(float[] topLensPx, float[] botLensPx, float hPx, int m) {
  if (topLensPx == null || botLensPx == null) return new float[]{0, 0, 0, 0};
  int n = min(topLensPx.length, botLensPx.length);
  if (n < 1) return new float[]{0, 0, 0, 0};

  float minX =  1e9, minY =  1e9;
  float maxX = -1e9, maxY = -1e9;

  // Running 2-D transform (position + rotation), starting at identity.
  float tx = 0, ty = 0, ca = 1, sa = 0;

  for (int edgeIdx = 0; edgeIdx < n; edgeIdx++) {
    float wTop = max(0.001f, topLensPx[edgeIdx]);
    float wBot = max(0.001f, botLensPx[edgeIdx]);

    // Full-panel corners in this panel's local frame (same as drawTrapezoidsPerEdge):
    //   BL = (0, 0),  BR = (wBot, 0)
    //   TL = ((wBot-wTop)/2, hPx),  TR = ((wBot+wTop)/2, hPx)
    float panelBLx = 0,              panelBLy = 0;
    float panelBRx = wBot,           panelBRy = 0;
    float panelTLx = (wBot-wTop)/2f, panelTLy = hPx;
    float panelTRx = (wBot+wTop)/2f, panelTRy = hPx;

    // Transform panel corners + tab extents to world space.
    // Bottom tabs extend in local -Y, top tabs in local +Y.
    // Transforming through the running rotation gives accurate world-space bounds.
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

    // First panel: include left flap outer corners.
    if (edgeIdx == 0) {
      float ex = panelTLx - panelBLx;
      float ey = panelTLy - panelBLy;
      float len = sqrt(ex*ex + ey*ey);
      float px = -(ey / len) * flapDepth_px;
      float py =  (ex / len) * flapDepth_px;
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

    // Last panel: include right flap outer corners.
    if (edgeIdx == n - 1) {
      float ex = panelTRx - panelBRx;
      float ey = panelTRy - panelBRy;
      float len = sqrt(ex*ex + ey*ey);
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

    // Advance transform to next panel (mirrors drawTrapezoidsPerEdge transform step).
    if (edgeIdx < n - 1) {
      float wTopNext = max(0.001f, topLensPx[edgeIdx + 1]);
      float wBotNext = max(0.001f, botLensPx[edgeIdx + 1]);
      float aA = atan2(hPx, (wTop - wBot) / 2.0f);
      float aB = atan2(hPx, (wBotNext - wTopNext) / 2.0f);
      float rot = aA - aB;
      float newTx = tx + ca * wBot;
      float newTy = ty + sa * wBot;
      float newCa = ca * cos(rot) - sa * sin(rot);
      float newSa = sa * cos(rot) + ca * sin(rot);
      tx = newTx; ty = newTy; ca = newCa; sa = newSa;
    }
  }

  return new float[]{ minX, minY, maxX, maxY };
}
