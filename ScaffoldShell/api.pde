////----------------------------------------------------------------------
//// Slant Flaps and Tabs Drawing Functions
////------------------------------------------------------------------------------------


void drawLeftSlantFlap(PVector p1, PVector p4, float flapDepth, float taper, float inset) {
  PVector leftEdge = PVector.sub(p1, p4);
  PVector leftPerp = new PVector(leftEdge.y, -leftEdge.x);
  leftPerp.normalize();
  leftPerp.mult(flapDepth);

  PVector insetEdge = PVector.sub(p1, p4);
  float insetRatio = inset/insetEdge.mag();
  float insetMagnitudeEdge = insetEdge.mag() * insetRatio;
  insetEdge.normalize();
  PVector p1_edge_inset = PVector.sub(p1, PVector.mult(insetEdge, insetMagnitudeEdge));
  PVector p4_edge_inset = PVector.add(p4, PVector.mult(insetEdge, insetMagnitudeEdge));

  // Calculate the initial corners as if it were a rectangle
  PVector p1_flap_rect = PVector.add(p1, leftPerp);
  PVector p4_flap_rect = PVector.add(p4, leftPerp);

  // Taper the flap by shortening the outer edge
  PVector outerEdgeLeft = PVector.sub(p1_flap_rect, p4_flap_rect);
  float taperRatio = taper / outerEdgeLeft.mag();
  float insetMagnitudeLeft = outerEdgeLeft.mag() * taperRatio;
  outerEdgeLeft.normalize();

  PVector p1_flap = PVector.sub(p1_flap_rect, PVector.mult(outerEdgeLeft, insetMagnitudeLeft));
  PVector p4_flap = PVector.add(p4_flap_rect, PVector.mult(outerEdgeLeft, insetMagnitudeLeft));

  // Draw the trapezoidal flap shape

  drawDashedLine(p4.x, p4.y, p4_edge_inset.x, p4_edge_inset.y, dash_px, gap_px);
  line(p4_edge_inset.x, p4_edge_inset.y, p1_edge_inset.x, p1_edge_inset.y);
  drawDashedLine(p1_edge_inset.x, p1_edge_inset.y, p1.x, p1.y, dash_px, gap_px);

  beginShape();
  vertex(p4.x, p4.y);
  vertex(p4_flap.x, p4_flap.y);
  vertex(p1_flap.x, p1_flap.y);
  vertex(p1.x, p1.y);
  endShape();
}

void drawRightSlantFlap(PVector p2, PVector p3, float flapDepth, float inset, float arrowheadFlare, float neckDepth, float hookOffset) {
  PVector rightEdge = PVector.sub(p3, p2);

  float insetRatio = inset/rightEdge.mag();
  float insetMagnitudeEdge = rightEdge.mag() * insetRatio;
  rightEdge.normalize();
  PVector p2_edge_inset = PVector.add(p2, PVector.mult(rightEdge, insetMagnitudeEdge));
  PVector p3_edge_inset = PVector.sub(p3, PVector.mult(rightEdge, insetMagnitudeEdge));

  PVector insetEdge = PVector.sub(p3_edge_inset, p2_edge_inset);

  PVector insetPerp = new PVector(insetEdge.y, -insetEdge.x);
  insetPerp.normalize();
  insetPerp.mult(flapDepth);
  // Calculate the initial corners as if it were a rectangle
  PVector p2_flap_rect = PVector.add(p2_edge_inset, insetPerp);
  PVector p3_flap_rect = PVector.add(p3_edge_inset, insetPerp);

  insetPerp.normalize();
  insetPerp.mult(neckDepth);
  PVector p2_neck_Depth = PVector.add(p2_edge_inset, insetPerp);
  PVector p3_neck_Depth = PVector.add(p3_edge_inset, insetPerp);

  PVector outerNeckRight = PVector.sub(p3_neck_Depth, p2_neck_Depth);
  float hookRatio = hookOffset / outerNeckRight.mag();
  float hookMagnitudeRight = outerNeckRight.mag() * hookRatio;
  outerNeckRight.normalize();
  PVector p2_hook = PVector.add(p2_neck_Depth, PVector.mult(outerNeckRight, hookMagnitudeRight));
  PVector p3_hook = PVector.sub(p3_neck_Depth, PVector.mult(outerNeckRight, hookMagnitudeRight));


  PVector outerEdgeRight = PVector.sub(p3_flap_rect, p2_flap_rect);
  float arrowFlareRatio = arrowheadFlare / outerEdgeRight.mag();
  float insetMagnitudeRight = outerEdgeRight.mag() * arrowFlareRatio;
  outerEdgeRight.normalize();
  PVector p2_flap = PVector.add(p2_flap_rect, PVector.mult(outerEdgeRight, insetMagnitudeRight));
  PVector p3_flap = PVector.sub(p3_flap_rect, PVector.mult(outerEdgeRight, insetMagnitudeRight));

  //// Calculate the initial corners as if it were a rectangle
  // Taper the flap by shortening the outer edge
  drawDashedLine(p3_edge_inset.x, p3_edge_inset.y, p2_edge_inset.x, p2_edge_inset.y, dash_px, gap_px);
  // Draw the trapezoidal flap shape
  beginShape();
  vertex(p3.x, p3.y);
  vertex(p3_edge_inset.x, p3_edge_inset.y);
  //vertex(p3_neck_Depth.x, p3_neck_Depth.y);
  vertex(p3_hook.x, p3_hook.y);
  //vertex(p3_flap_rect.x, p3_flap_rect.y);
  //vertex(p2_flap_rect.x, p2_flap_rect.y);
  vertex(p3_flap.x, p3_flap.y);
  vertex(p2_flap.x, p2_flap.y);
  vertex(p2_hook.x, p2_hook.y);
  //vertex(p2_neck_Depth.x, p2_neck_Depth.y);
  vertex(p2_edge_inset.x, p2_edge_inset.y);
  vertex(p2.x, p2.y);
  endShape();
}



void drawBottomTabContour(PVector p, PVector d, float tabDepth, float tabInset, float arrowheadFlare, float neckDepth) {
  drawDashedLine(p.x + d.x - tabInset*0, p.y + d.y, p.x + tabInset*2, p.y + d.y, dash_px, gap_px);

  beginShape();
  vertex(p.x + d.x, p.y + d.y);
  vertex(p.x + d.x - tabInset*0, p.y + d.y);
  vertex(p.x + d.x - tabInset*0, p.y + d.y - neckDepth);
  vertex(p.x + d.x - tabInset*0 - arrowheadFlare, p.y + d.y - tabDepth);
  vertex(p.x + tabInset*2 + arrowheadFlare, p.y + d.y - tabDepth);
  vertex(p.x + tabInset*2, p.y + d.y - neckDepth);
  vertex(p.x + tabInset*2, p.y + d.y);
  vertex(p.x, p.y + d.y);
  endShape();
}

void drawTopTabContour(PVector p, PVector d, float tabDepth, float tabInset, float arrowheadFlare, float neckDepth) {

  drawDashedLine(p.x + tabInset*0, p.y, p.x + d.x - tabInset*2, p.y, dash_px, gap_px);

  beginShape();
  vertex(p.x, p.y);
  vertex(p.x + tabInset*0, p.y);
  vertex(p.x + tabInset*0, p.y + neckDepth);
  vertex(p.x + tabInset*0 + arrowheadFlare, p.y + tabDepth);
  vertex(p.x + d.x - tabInset*2 - arrowheadFlare, p.y + tabDepth);
  vertex(p.x + d.x - tabInset*2, p.y + neckDepth);
  vertex(p.x + d.x - tabInset*2, p.y);
  vertex(p.x + d.x, p.y);
  endShape();
}

void drawRightTabContour(PVector p0, PVector d0, float tabDepth, float tabInset, float arrowheadFlare, float neckDepth) {
  beginShape();
  vertex(p0.x + d0.x, p0.y);
  vertex(p0.x + d0.x, p0.y + tabInset);
  vertex(p0.x + d0.x + neckDepth, p0.y + tabInset);
  vertex(p0.x + d0.x + tabDepth, p0.y + tabInset + arrowheadFlare);
  vertex(p0.x + d0.x + tabDepth, p0.y + d0.y - tabInset - arrowheadFlare);
  vertex(p0.x + d0.x + neckDepth, p0.y + d0.y - tabInset);
  vertex(p0.x + d0.x, p0.y + d0.y - tabInset);
  vertex(p0.x + d0.x, p0.y + d0.y);
  endShape();
}

// Mirror of drawRightTabContour — draws an arrowhead tab pointing LEFT from x = p0.x.
// p0 = top-left anchor of the tab area; d0.y = total height of the section.
// Used as an additional glue tab on the first panel when panels are tall.
void drawLeftTabContour(PVector p0, PVector d0, float tabDepth, float tabInset, float arrowheadFlare, float neckDepth) {
  drawDashedLine(p0.x, p0.y + tabInset, p0.x, p0.y + d0.y - tabInset, dash_px, gap_px);
  beginShape();
  vertex(p0.x, p0.y);
  vertex(p0.x, p0.y + tabInset);
  vertex(p0.x - neckDepth, p0.y + tabInset);
  vertex(p0.x - tabDepth, p0.y + tabInset + arrowheadFlare);
  vertex(p0.x - tabDepth, p0.y + d0.y - tabInset - arrowheadFlare);
  vertex(p0.x - neckDepth, p0.y + d0.y - tabInset);
  vertex(p0.x, p0.y + d0.y - tabInset);
  vertex(p0.x, p0.y + d0.y);
  endShape();
}

void drawLeftFlapContour(PVector p, PVector d, float flapDepth, float flapTaper) {
  beginShape();
  vertex(p.x, p.y + d.y);
  vertex(p.x - flapDepth, p.y + d.y - flapTaper);
  vertex(p.x - flapDepth, p.y + flapTaper);
  vertex(p.x, p.y);
  endShape();
}

void drawLeftFlapSlotContour(PVector p, PVector d, float flapDepth, float flapTaper, float slotInset) {
  line(p.x, p.y + slotInset, p.x, p.y + d.y - slotInset);
  beginShape();
  vertex(p.x, p.y + d.y);
  vertex(p.x - flapDepth, p.y + d.y - flapTaper);
  vertex(p.x - flapDepth, p.y + flapTaper);
  vertex(p.x, p.y);
  endShape();
}

void drawRightHookTabContour(PVector p0, PVector d0, float tabDepth, float tabInset, float arrowheadFlare, float neckDepth, float arrowheadFlare2) {
  drawDashedLine(p0.x + d0.x, p0.y + tabInset, p0.x + d0.x, p0.y + d0.y - tabInset, dash_px, gap_px);
  beginShape();
  vertex(p0.x + d0.x, p0.y);
  vertex(p0.x + d0.x, p0.y + tabInset);
  vertex(p0.x + d0.x + neckDepth, p0.y + tabInset);
  vertex(p0.x + d0.x + tabDepth/2, p0.y + tabInset + arrowheadFlare2);
  vertex(p0.x + d0.x + tabDepth, p0.y + tabInset + arrowheadFlare);
  vertex(p0.x + d0.x + tabDepth, p0.y + d0.y - tabInset - arrowheadFlare);
  vertex(p0.x + d0.x + tabDepth/2, p0.y + d0.y - tabInset - arrowheadFlare2);
  vertex(p0.x + d0.x + neckDepth, p0.y + d0.y - tabInset);
  vertex(p0.x + d0.x, p0.y + d0.y - tabInset);
  vertex(p0.x + d0.x, p0.y + d0.y);
  endShape();
}

//----------------------------------------------------------------------
// HOLLOW MODE: Connection Cutout and Tab Drawing
//----------------------------------------------------------------------

// Draw a rectangular cutout (hole) in an edge for wall connection
// p1, p2: endpoints of the edge
// cutoutWidth: width of the cutout
// cutoutCenter: position along edge (0 to 1, where 0.5 is center)
PVector getPolygonLidDimensions(int numSides, float sideLength, float tabDepthValue) {
  // --- 1. Calculate basic polygon geometry ---
  // Radius is the distance from the center to any vertex.
  float radius = (sideLength / 2.0) / sin(PI / numSides);
  float angleIncrement = TWO_PI / numSides;

  // This start angle must match the drawing function to ensure the orientation is identical.
  float startAngle = -HALF_PI - angleIncrement / 2.0;

  // --- 2. Find the min/max coordinates of the polygon's own vertices ---
  float minX = Float.MAX_VALUE;
  float maxX = Float.MIN_VALUE;
  float minY = Float.MAX_VALUE;
  float maxY = Float.MIN_VALUE;

  for (int i = 0; i < numSides; i++) {
    float ang = startAngle + i * angleIncrement;
    float vx = cos(ang) * radius;
    float vy = sin(ang) * radius;

    if (vx < minX) minX = vx;
    if (vx > maxX) maxX = vx;
    if (vy < minY) minY = vy;
    if (vy > maxY) maxY = vy;
  }

  // --- 3. Calculate the polygon's core width and height from its bounds ---
  float polygonWidth = maxX - minX;
  float polygonHeight = maxY - minY;

  // --- 4. Add the tab depth to find the total dimensions ---
  // The tabs stick out from all sides, effectively padding the bounding box.
  float totalWidth = polygonWidth + (2 * tabDepthValue);
  float totalHeight = polygonHeight + (2 * tabDepthValue);

  // --- 5. Return the final dimensions as a PVector ---
  return new PVector(totalWidth, totalHeight);
}

void drawPolygonLid(int numSides, float sideLength, float neckDepth, float tabInset, float arrowheadFlare) {
  float radius = (sideLength / 2.0) / sin(PI / (float)numSides);
  float angleIncrement = TWO_PI / (float)numSides;
  //float startAngle = -HALF_PI - angleIncrement / 2.0; // Start angle to make bottom edge horizontal
  float rectWidth = (radius*cos(angleIncrement/2)+tabDepth_px)*2;
  pushMatrix();
  translate(rectWidth/2., rectWidth/2.);
  pushStyle();
  rectMode(CENTER);
  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);

  for (int i = 0; i < numSides; i++) {
    pushMatrix();
    rotate(i * angleIncrement);
    translate(0, -radius*cos(angleIncrement/2)); // Move to the midpoint of the side
    drawDashedLine(-sideLength/2. + tabInset*2, 0, sideLength/2., 0, dash_px, gap_px);

    popMatrix();
  }

  for (int i = 0; i < numSides; i++) {
    pushMatrix();
    rotate(i * angleIncrement);
    translate(0, -radius*cos(angleIncrement/2)); // Move to the midpoint of the side
    beginShape();
    vertex(-sideLength/2., 0);
    vertex(-sideLength/2 + tabInset*2, 0);
    vertex(-sideLength/2 + tabInset*2, -neckDepth);
    vertex(-sideLength/2 + tabInset*2 + arrowheadFlare, -tabDepth_px);
    vertex(sideLength/2  - arrowheadFlare, -tabDepth_px);
    vertex(sideLength/2, -neckDepth);
    vertex(sideLength/2, 0);
    vertex(sideLength/2., 0);
    endShape();


    popMatrix();
  }

  popStyle();
  popMatrix();
}

// Tessellated textured polygon lid (triangle fan from center with radial UV mapping)
void drawTessellatedPolygonLid(int numSides, float sideLength, PImage img, int density, boolean keepAspect) {
  if (img == null || numSides < 3 || density < 1) return;
  
  float radius = (sideLength / 2.0) / sin(PI / (float)numSides);
  float angleIncrement = TWO_PI / (float)numSides;
  float rectWidth = (radius * cos(angleIncrement/2) + tabDepth_px) * 2;
  
  pushMatrix();
  translate(rectWidth/2., rectWidth/2.);
  
  // Center point in world space
  float cx = 0, cy = 0;
  
  // Image center and scaling for aspect ratio
  float imgCX = img.width * 0.5f;
  float imgCY = img.height * 0.5f;
  
  // Scale factor to fit image while maintaining aspect
  float uvRadius = min(img.width, img.height) * 0.5f;
  if (!keepAspect) {
    // If not keeping aspect, use full image dimensions
    uvRadius = min(img.width, img.height) * 0.5f;
  }
  
  noStroke();
  textureMode(IMAGE);
  textureWrap(CLAMP);
  hint(ENABLE_TEXTURE_MIPMAPS);
  
  beginShape(TRIANGLES);
  texture(img);
  
  // For each side of the polygon
  for (int side = 0; side < numSides; side++) {
    float angle1 = side * angleIncrement;
    float angle2 = (side + 1) * angleIncrement;
    
    // Edge vertices of this polygon side (at the polygon perimeter, not including tabs)
    float x1 = cos(angle1) * radius;
    float y1 = sin(angle1) * radius;
    float x2 = cos(angle2) * radius;
    float y2 = sin(angle2) * radius;
    
    // Subdivide this triangular wedge radially
    for (int ring = 0; ring < density; ring++) {
      float r0 = (float)ring / density;        // inner radius ratio
      float r1 = (float)(ring + 1) / density;  // outer radius ratio
      
      // Subdivide angularly along the arc
      for (int arc = 0; arc < density; arc++) {
        float a0 = lerp(angle1, angle2, (float)arc / density);
        float a1 = lerp(angle1, angle2, (float)(arc + 1) / density);
        
        // Four corners of this subdivided quad (in polar coords, then cartesian)
        float x00 = cos(a0) * r0 * radius;
        float y00 = sin(a0) * r0 * radius;
        float x10 = cos(a1) * r0 * radius;
        float y10 = sin(a1) * r0 * radius;
        float x01 = cos(a0) * r1 * radius;
        float y01 = sin(a0) * r1 * radius;
        float x11 = cos(a1) * r1 * radius;
        float y11 = sin(a1) * r1 * radius;
        
        // UV coordinates - radial mapping from center
        // Map radius [0,1] and angle to UV space
        float u00 = imgCX + cos(a0) * r0 * uvRadius;
        float v00 = imgCY + sin(a0) * r0 * uvRadius;
        float u10 = imgCX + cos(a1) * r0 * uvRadius;
        float v10 = imgCY + sin(a1) * r0 * uvRadius;
        float u01 = imgCX + cos(a0) * r1 * uvRadius;
        float v01 = imgCY + sin(a0) * r1 * uvRadius;
        float u11 = imgCX + cos(a1) * r1 * uvRadius;
        float v11 = imgCY + sin(a1) * r1 * uvRadius;
        
        // Two triangles per quad
        vertex(x00, y00, u00, v00);
        vertex(x10, y10, u10, v10);
        vertex(x01, y01, u01, v01);
        
        vertex(x10, y10, u10, v10);
        vertex(x11, y11, u11, v11);
        vertex(x01, y01, u01, v01);
      }
    }
  }
  
  endShape();
  popMatrix();
}


// Simpler version that calculates dimensions without screen coordinates
PVector getTrapezoidsDimensionsSimple(float topLen, float bottomLen, float h, int n) {
  // For a strip of n trapezoids, calculate total width and height
  // Width is approximately the bottom length (widest part)
  // Height is h (the trapezoid height)
  float totalWidth = max(topLen, bottomLen) * n;
  float totalHeight = h;
  return new PVector(totalWidth, totalHeight);
}

PVector getTrapezoidsDimensions(float startX, float startY, float topLen, float bottomLen, float h, int m, int n) {
  // Use push/pop to encapsulate our transformations
  PVector box = new PVector(0, 0);
  pushMatrix();
  
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
      // Compute per-row top/bottom widths by linear interpolation 
      float mtop    = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float mbottom = ((topLen - bottomLen) *  i    / (float)m) + bottomLen;
      // Center the shorter edge horizontally
      float offset  = (mbottom - mtop) / 2.0;
      PVector pb = new PVector(offset*i, mh*i);
      PVector db = new PVector(mbottom, 0);
      PVector pt = new PVector(offset*i+offset, mh*i + mh);
      PVector dt = new PVector(mtop, 0);

      PVector[] v = new PVector[4];
      v[0] = new PVector(pb.x,pb.y);
      v[1] = new PVector(pb.x+db.x ,pb.y+db.y);
      v[2] = new PVector(pt.x,pt.y);
      v[3] = new PVector(pt.x+dt.x, pt.y+dt.y);

      PVector[] global_v = new PVector[4];
      for (int j = 0; j < 4; j++) {
        global_v[j] = new PVector(screenX(v[j].x, v[j].y), screenY(v[j].x, v[j].y));
        box.set(max(box.x, global_v[j].x), max(box.y, global_v[j].y));
        //line(v[0].x,v[0].y,v[3].x,v[3].y);
        //line(v[1].x,v[1].y,v[2].x,v[2].y);
      }
      if (count < n-1) {
        translate(bottomLen, 0);
        rotate(rotationNeeded);
      }
    }
  }
  // Restore the original transformation state
  popMatrix();
  return new PVector(box.x-patX_px,box.y-patY_px);
}
//----------------------------------------------------------------------
// HOLLOW MODE: Lid Drawing Wrappers
//----------------------------------------------------------------------

// Draw polygon lid with hollow mode support (uniform polygons)
void drawPolygonLidHollow(int numSides, float sideLength, float neckDepth, 
                          float tabInset, float arrowheadFlare, boolean isTop) {
  if (!hollowMode) {
    // Normal single lid
    drawPolygonLid(numSides, sideLength, neckDepth, tabInset, arrowheadFlare);
    return;
  }
  
  // Determine inner shape parameters
  int innerSides = (enableInnerShape) ? nSidesInner : numSides;
  float sideLengthInner;
  
  if (enableInnerShape) {
    // Use different inner shape with specified scale
    float outerPerimeter = sideLength * numSides;
    sideLengthInner = calculateInnerEdgeLength(outerPerimeter, innerShapeScale, innerSides);
  } else {
    // Traditional concentric polygon (backward compatibility)
    float[] insetResult = new float[2];
    calculateUniformInset(sideLength, sideLength, wallThickness_px, insetResult);
    sideLengthInner = insetResult[0];
  }
  
  // Calculate geometry
  float radius = (sideLength / 2.0) / sin(PI / (float)numSides);
  float radiusInner = (sideLengthInner / 2.0) / sin(PI / (float)innerSides);
  float angleIncrement = TWO_PI / (float)numSides;
  float angleIncrementInner = TWO_PI / (float)innerSides;
  float startAngle = -HALF_PI - angleIncrement / 2.0;
  float startAngleInner = -HALF_PI - angleIncrementInner / 2.0;
  
  // Draw label
  pushStyle();
  fill(0);
  textSize(12);
  textAlign(CENTER, BOTTOM);
  PVector lidSize = getPolygonLidDimensions(numSides, sideLength, tabDepth_px);
  String labelText = isTop ? "DONUT LID (TOP)" : "DONUT LID (BOTTOM)";
  if (enableInnerShape && innerSides != numSides) {
    labelText += " - " + numSides + " outer / " + innerSides + " inner sides";
  }
  text(labelText, lidSize.x/2, -10);
  popStyle();
  
  pushMatrix();
  // Center the donut lid
  float rectWidth = (radius * cos(angleIncrement/2) + tabDepth_px) * 2;
  translate(rectWidth/2., rectWidth/2.);
  
  pushStyle();
  stroke(uiLightGrayCutLines ? 180 : 0);
  noFill();
  
  // === OUTER POLYGON WITH ARROWHEAD TABS ===
  for (int i = 0; i < numSides; i++) {
    pushMatrix();
    rotate(i * angleIncrement);
    translate(0, -radius*cos(angleIncrement/2)); // Move to the midpoint of the side
    
    // Draw dashed line for tab base
    drawDashedLine(-sideLength/2. + tabInset*2, 0, sideLength/2., 0, dash_px, gap_px);
    
    // Draw arrowhead tab shape extending outward
    beginShape();
    vertex(-sideLength/2., 0);  // Edge start
    vertex(-sideLength/2 + tabInset*2, 0);  // Tab base start
    vertex(-sideLength/2 + tabInset*2, -neckDepth);  // Neck depth
    vertex(-sideLength/2 + tabInset*2 + arrowheadFlare, -tabDepth_px);  // Arrow flare
    vertex(sideLength/2  - arrowheadFlare, -tabDepth_px);  // Arrow flare (other side)
    vertex(sideLength/2, -neckDepth);  // Neck depth (other side)
    vertex(sideLength/2, 0);  // Tab base end
    vertex(sideLength/2., 0);  // Edge end
    endShape();
    
    popMatrix();
  }
  popStyle();
  
  // === INNER CUTOUT POLYGON WITH ARROWHEAD TABS ===
  // Draw inner tabs (connect to inner wall, pointing inward toward center)
  // Tab dimensions must scale with inner polygon size to match panel tabs
  pushStyle();
  stroke(uiLightGrayCutLines ? 180 : 0);
  noFill();
  
  // Apply inner shape rotation if enabled
  if (enableInnerShape) {
    pushMatrix();
    rotate(radians(innerShapeRotation));
  }
  
  // Tab inset = 1/4 of side length (gives tab width = 1/2 side length)
  float tabInsetInner = sideLengthInner / 4.0;
  
  // Adaptive tab depth: limit to available radial space to prevent overlap
  // Use apothem (perpendicular distance from center to edge) as reference
  float apothemInner = radiusInner * cos(angleIncrementInner / 2.0);
  float maxTabDepthRadial = apothemInner * 0.9;  // Use 90% of distance to center
  
  // Tab depth: ALWAYS 10mm for easy construction (but limited by radial space)
  // Two fold lines: one at base, one at wall thickness - 2x paper thickness
  float fixedInnerTabDepth_px = INNER_TAB_DEPTH_MM * MM_current;
  float tabDepthInner = min(fixedInnerTabDepth_px, maxTabDepthRadial);
  
  // Calculate second fold line position (wall thickness minus 2x paper thickness)
  float foldLineDepth = (wallThickness - 2 * PAPER_THICKNESS_MM) * MM_current;
  
  float neckDepthInner = min(neckDepth * 0.9, tabDepthInner * 0.5);  // Neck should be less than tab depth
  
  // Calculate max flare to prevent angular overlap
  // Tab base width = sideLengthInner - 2*tabInsetInner
  float tabBaseWidth = sideLengthInner - 2 * tabInsetInner;
  float maxFlare = tabBaseWidth * 0.2;  // Flare should be fraction of tab base
  float arrowheadFlareInner = min(tabInsetInner / 3.0, maxFlare);
  
  for (int i = 0; i < innerSides; i++) {
    pushMatrix();
    rotate(i * angleIncrementInner);
    translate(0, -radiusInner*cos(angleIncrementInner/2)); // Move to midpoint of inner edge
    
    // Draw fold line at tab base (where tab meets lid edge)
    drawDashedLine(-sideLengthInner/2. + tabInsetInner*2, 0, sideLengthInner/2., 0, dash_px, gap_px);
    
    // Draw arrowhead tab shape extending inward (positive Y direction)
    beginShape();
    vertex(-sideLengthInner/2., 0);  // Edge start
    vertex(-sideLengthInner/2 + tabInsetInner*2, 0);  // Tab base start
    vertex(-sideLengthInner/2 + tabInsetInner*2, neckDepthInner);  // Neck depth (inward)
    vertex(-sideLengthInner/2 + tabInsetInner*2 + arrowheadFlareInner, tabDepthInner);  // Arrow flare
    vertex(sideLengthInner/2  - arrowheadFlareInner, tabDepthInner);  // Arrow flare (other side)
    vertex(sideLengthInner/2, neckDepthInner);  // Neck depth (other side)
    vertex(sideLengthInner/2, 0);  // Tab base end
    vertex(sideLengthInner/2., 0);  // Edge end
    endShape();
    
    // Draw second fold line at wall thickness position (for bending to match wall)
    if (foldLineDepth < tabDepthInner) {
      drawDashedLine(-sideLengthInner/2. + tabInsetInner*2, foldLineDepth, 
                     sideLengthInner/2., foldLineDepth, 
                     dash_px, gap_px);
    }
    
    popMatrix();
  }
  
  if (enableInnerShape) {
    popMatrix(); // Close inner rotation matrix
  }
  
  popStyle();
  
  popMatrix();
}

// Draw variable polygon lid with hollow mode support (donut-shaped)
void drawPolygonLidVarHollow(float[] sidePx, float neckDepth, float tabInset, 
                             float arrowFlare, boolean isTop) {
  if (!hollowMode) {
    // Normal single lid
    drawPolygonLidVar_Legacy(sidePx, neckDepth, tabInset, arrowFlare);
    return;
  }
  
  // NOTE: In variable prism mode, inner shape always uses proportionally scaled edges
  // (concentric polygon with same number of sides as outer).
  // Different inner shape geometry (enableInnerShape) is only supported in uniform mode.
  // Future enhancement: Implement edge-to-edge mapping for different inner shapes in variable mode.
  
  // Calculate inner edge dimensions
  float[] sidePxInner = calculateInsetEdges(sidePx, wallThickness_px);
  
  if (sidePxInner == null) {
    println("[WARNING] Cannot create hollow mode lid: wall thickness too large");
    drawPolygonLidVar_Legacy(sidePx, neckDepth, tabInset, arrowFlare);
    return;
  }
  
  int n = sidePx.length;
  float R = solveRadiusForChordSet(sidePx);
  float RInner = solveRadiusForChordSet(sidePxInner);
  
  // Draw label
  pushStyle();
  fill(0);
  textSize(12);
  textAlign(CENTER, BOTTOM);
  PVector lidSize = getPolygonLidVarDimensions(sidePx, tabDepth_px);
  text(isTop ? "DONUT LID (TOP)" : "DONUT LID (BOTTOM)", lidSize.x/2, -10);
  popStyle();
  
  pushMatrix();
  
  // Align to first chord (same orientation as standard lid)
  float ang0 = -HALF_PI;
  float s0  = sidePx[0];
  float th0 = 2.0f * (float)Math.asin(_clampf(s0/(2.0f*R), 1e-6f, 0.999999f));
  PVector p0a = new PVector(R * cos(ang0), R * sin(ang0));
  PVector p0b = new PVector(R * cos(ang0 + th0), R * sin(ang0 + th0));
  float angle0 = atan2(p0b.y - p0a.y, p0b.x - p0a.x);
  
  rotate(-angle0);
  
  // === OUTER POLYGON WITH ARROWHEAD TABS ===
  // Draw outer tabs (connect to outer wall)
  pushStyle();
  stroke(uiLightGrayCutLines ? 180 : 0);
  noFill();
  
  float ang = ang0;
  for (int i = 0; i < n; i++) {
    float s = sidePx[i];
    float theta = 2.0f * (float)Math.asin(_clampf(s/(2.0f*R), 1e-6f, 0.999999f));
    
    PVector p1 = new PVector(R * cos(ang), R * sin(ang));
    PVector p2 = new PVector(R * cos(ang + theta), R * sin(ang + theta));
    
    // Calculate edge direction and perpendicular (outward)
    PVector midpoint = PVector.add(p1, p2).mult(0.5);
    PVector edgeDir = PVector.sub(p2, p1);
    float edgeLen = edgeDir.mag();
    edgeDir.normalize();
    PVector perpOut = new PVector(-edgeDir.y, edgeDir.x);
    
    // Calculate arrowhead tab vertices
    float tabWidth = max(0.001f, edgeLen - tabInset * 2.0);
    float insetDist = (edgeLen - tabWidth) / 2.0;
    
    PVector edgeStart = PVector.add(midpoint, PVector.mult(edgeDir, -edgeLen/2.0));
    PVector edgeEnd = PVector.add(midpoint, PVector.mult(edgeDir, edgeLen/2.0));
    PVector tabBase1 = PVector.add(edgeStart, PVector.mult(edgeDir, insetDist));
    PVector tabBase2 = PVector.add(edgeEnd, PVector.mult(edgeDir, -insetDist));
    PVector neckPt1 = PVector.add(tabBase1, PVector.mult(perpOut, neckDepth));
    PVector neckPt2 = PVector.add(tabBase2, PVector.mult(perpOut, neckDepth));
    PVector arrowPt1 = PVector.add(tabBase1, PVector.mult(edgeDir, arrowFlare));
    arrowPt1.add(PVector.mult(perpOut, tabDepth_px));
    PVector arrowPt2 = PVector.add(tabBase2, PVector.mult(edgeDir, -arrowFlare));
    arrowPt2.add(PVector.mult(perpOut, tabDepth_px));
    
    // Draw dashed line for tab base
    drawDashedLine(tabBase1.x, tabBase1.y, tabBase2.x, tabBase2.y, dash_px, gap_px);
    
    // Draw arrowhead tab shape
    beginShape();
    vertex(edgeStart.x, edgeStart.y);
    vertex(tabBase1.x, tabBase1.y);
    vertex(neckPt1.x, neckPt1.y);
    vertex(arrowPt1.x, arrowPt1.y);
    vertex(arrowPt2.x, arrowPt2.y);
    vertex(neckPt2.x, neckPt2.y);
    vertex(tabBase2.x, tabBase2.y);
    vertex(edgeEnd.x, edgeEnd.y);
    endShape();
    
    ang += theta;
  }
  popStyle();
  
  // === INNER CUTOUT POLYGON WITH ARROWHEAD TABS ===
  // Draw inner tabs (connect to inner wall, pointing inward)
  // Tab dimensions must scale with inner edge lengths
  pushStyle();
  stroke(uiLightGrayCutLines ? 180 : 0);
  noFill();
  
  // Note: for variable polygons, tabInset scales per edge (edgeLength / 4)
  // We'll calculate it per edge below
  
  // Adaptive tab depth: limit to available radial space
  // Use a safe fraction of the inner radius
  float maxTabDepthRadial = RInner * 0.9;  // Use 90% of inner radius
  // Tab depth must also not exceed wall thickness to ensure proper connection
  float maxTabDepthWall = wallThickness_px;
  float tabDepthInner = min(tabDepth_px * 0.9, min(maxTabDepthRadial, maxTabDepthWall));
  float neckDepthInner = min(neckDepth * 0.9, tabDepthInner * 0.5);  // Neck should be less than tab depth
  
  ang = ang0;
  for (int i = 0; i < n; i++) {
    float sInner = sidePxInner[i];
    float theta = 2.0f * (float)Math.asin(_clampf(sInner/(2.0f*RInner), 1e-6f, 0.999999f));
    
    // Tab inset = 1/4 of side length (gives tab width = 1/2 side length)
    float tabInsetInner = sInner / 4.0;
    
    // Adaptive arrowhead flare to prevent overlap
    float tabBaseWidth = sInner - 2 * tabInsetInner;
    float maxFlare = tabBaseWidth * 0.2;  // Flare should be fraction of tab base
    float arrowFlareInner = min(tabInsetInner / 3.0, maxFlare);
    
    PVector p1 = new PVector(RInner * cos(ang), RInner * sin(ang));
    PVector p2 = new PVector(RInner * cos(ang + theta), RInner * sin(ang + theta));
    
    // Calculate edge direction and perpendicular (inward)
    PVector midpoint = PVector.add(p1, p2).mult(0.5);
    PVector edgeDir = PVector.sub(p2, p1);
    float edgeLen = edgeDir.mag();
    edgeDir.normalize();
    PVector perpIn = new PVector(edgeDir.y, -edgeDir.x); // Inward toward center
    
    // Calculate arrowhead tab vertices
    float tabWidth = max(0.001f, edgeLen - tabInsetInner * 2.0);
    float insetDist = (edgeLen - tabWidth) / 2.0;
    
    PVector edgeStart = PVector.add(midpoint, PVector.mult(edgeDir, -edgeLen/2.0));
    PVector edgeEnd = PVector.add(midpoint, PVector.mult(edgeDir, edgeLen/2.0));
    PVector tabBase1 = PVector.add(edgeStart, PVector.mult(edgeDir, insetDist));
    PVector tabBase2 = PVector.add(edgeEnd, PVector.mult(edgeDir, -insetDist));
    PVector neckPt1 = PVector.add(tabBase1, PVector.mult(perpIn, neckDepthInner));
    PVector neckPt2 = PVector.add(tabBase2, PVector.mult(perpIn, neckDepthInner));
    PVector arrowPt1 = PVector.add(tabBase1, PVector.mult(edgeDir, arrowFlareInner));
    arrowPt1.add(PVector.mult(perpIn, tabDepthInner));
    PVector arrowPt2 = PVector.add(tabBase2, PVector.mult(edgeDir, -arrowFlareInner));
    arrowPt2.add(PVector.mult(perpIn, tabDepthInner));
    
    // Draw dashed line for tab base
    drawDashedLine(tabBase1.x, tabBase1.y, tabBase2.x, tabBase2.y, dash_px, gap_px);
    
    // Draw arrowhead tab shape
    beginShape();
    vertex(edgeStart.x, edgeStart.y);
    vertex(tabBase1.x, tabBase1.y);
    vertex(neckPt1.x, neckPt1.y);
    vertex(arrowPt1.x, arrowPt1.y);
    vertex(arrowPt2.x, arrowPt2.y);
    vertex(neckPt2.x, neckPt2.y);
    vertex(tabBase2.x, tabBase2.y);
    vertex(edgeEnd.x, edgeEnd.y);
    endShape();
    
    ang += theta;
  }
  popStyle();
  
  popMatrix();
}

//------------------------------------------------------------------------------------
// INNER SHAPE GEOMETRY CALCULATORS (for donut lids with different inner shapes)
//------------------------------------------------------------------------------------

// Calculate inner edge length for a different inner polygon shape
// outerPerimeter: total perimeter of outer polygon (mm or px)
// innerScale: fraction of outer perimeter for inner (0.3-0.8)
// nSidesInner: number of sides for inner polygon
// returns: edge length for inner polygon
float calculateInnerEdgeLength(float outerPerimeter, float innerScale, int nSidesInner) {
  float innerPerimeter = outerPerimeter * innerScale;
  return innerPerimeter / (float)nSidesInner;
}

// Get dimensions of inner polygon for donut lid
// nSidesOuter: number of sides for outer polygon
// outerEdge: edge length of outer polygon
// nSidesInner: number of sides for inner polygon
// innerScale: fraction of outer perimeter
// wallThickness: minimum wall thickness
// returns: PVector(width, height) or null if invalid
PVector getInnerPolygonDimensions(int nSidesOuter, float outerEdge, int nSidesInner, 
                                  float innerScale, float wallThickness) {
  // Calculate outer circumradius
  float outerRadius = (outerEdge / 2.0) / sin(PI / nSidesOuter);
  
  // Calculate inner perimeter and edge length
  float outerPerimeter = outerEdge * nSidesOuter;
  float innerEdge = calculateInnerEdgeLength(outerPerimeter, innerScale, nSidesInner);
  
  // Calculate inner circumradius
  float innerRadius = (innerEdge / 2.0) / sin(PI / nSidesInner);
  
  // Validate: inner must fit inside outer with wall thickness
  if (innerRadius + wallThickness >= outerRadius * 0.95) {
    println("[WARNING] Inner shape too large - doesn't fit inside outer with wall thickness");
    return null;
  }
  
  // Calculate bounding box of inner polygon
  float angleIncrement = TWO_PI / nSidesInner;
  float startAngle = -HALF_PI - angleIncrement / 2.0;
  
  float minX = Float.MAX_VALUE;
  float maxX = Float.MIN_VALUE;
  float minY = Float.MAX_VALUE;
  float maxY = Float.MIN_VALUE;
  
  for (int i = 0; i < nSidesInner; i++) {
    float ang = startAngle + i * angleIncrement;
    float vx = cos(ang) * innerRadius;
    float vy = sin(ang) * innerRadius;
    
    if (vx < minX) minX = vx;
    if (vx > maxX) maxX = vx;
    if (vy < minY) minY = vy;
    if (vy > maxY) maxY = vy;
  }
  
  float width = maxX - minX;
  float height = maxY - minY;
  
  return new PVector(width, height);
}

// Validate that inner shape parameters are geometrically valid
// returns: true if valid, false if inner shape doesn't fit
boolean validateInnerShapeParameters() {
  if (!hollowMode || !enableInnerShape) return true;
  
  // For uniform mode
  if (!perEdgeMode && !cuboidMode) {
    float outerEdge = cellBaseL_px;
    PVector innerDims = getInnerPolygonDimensions(nSides, outerEdge, nSidesInner, 
                                                   innerShapeScale, wallThickness_px);
    return (innerDims != null);
  }
  
  // For per-edge mode, check against smallest edge
  if (edgeBot_px != null && edgeBot_px.length > 0) {
    float minEdge = Float.MAX_VALUE;
    for (float edge : edgeBot_px) {
      if (edge < minEdge) minEdge = edge;
    }
    PVector innerDims = getInnerPolygonDimensions(nSides, minEdge, nSidesInner, 
                                                   innerShapeScale, wallThickness_px);
    return (innerDims != null);
  }
  
  return true;
}

// ==================== RECTANGULAR LID (Cuboid Mode) ====================

PVector getRectangularLidDimensions(float lidWidth, float lidDepth, float tabDepthValue) {
  float totalWidth = lidWidth + (2 * tabDepthValue);
  float totalHeight = lidDepth + (2 * tabDepthValue);
  return new PVector(totalWidth, totalHeight);
}

void drawRectangularLid(float lidWidth, float lidDepth, float neckDepth, float tabInset, float arrowheadFlare) {
  float totalWidth = lidWidth + 2 * tabDepth_px;
  float totalHeight = lidDepth + 2 * tabDepth_px;
  
  pushMatrix();
  translate(totalWidth / 2.0, totalHeight / 2.0);
  pushStyle();
  noFill();
  stroke(0);
  
  // --- Draw fold lines (dashed) on all 4 edges ---
  float[] edgeLengths = { lidWidth, lidDepth, lidWidth, lidDepth };
  float[] edgeDists = { lidDepth / 2.0, lidWidth / 2.0, lidDepth / 2.0, lidWidth / 2.0 };
  
  for (int i = 0; i < 4; i++) {
    float edgeLen = edgeLengths[i];
    float dist = edgeDists[i];
    float localInset = TAB_INSET_RATIO * edgeLen;
    
    pushMatrix();
    rotate(i * HALF_PI);
    translate(0, -dist);
    drawDashedLine(-edgeLen / 2.0 + localInset * 2, 0, edgeLen / 2.0, 0, dash_px, gap_px);
    popMatrix();
  }
  
  // --- Draw tab contours on all 4 edges ---
  for (int i = 0; i < 4; i++) {
    float edgeLen = edgeLengths[i];
    float dist = edgeDists[i];
    float localInset = TAB_INSET_RATIO * edgeLen;
    float localFlare = min(arrowheadFlare, localInset / 2.0);
    
    pushMatrix();
    rotate(i * HALF_PI);
    translate(0, -dist);
    beginShape();
    vertex(-edgeLen / 2.0, 0);
    vertex(-edgeLen / 2.0 + localInset * 2, 0);
    vertex(-edgeLen / 2.0 + localInset * 2, -neckDepth);
    vertex(-edgeLen / 2.0 + localInset * 2 + localFlare, -tabDepth_px);
    vertex(edgeLen / 2.0 - localFlare, -tabDepth_px);
    vertex(edgeLen / 2.0, -neckDepth);
    vertex(edgeLen / 2.0, 0);
    endShape();
    popMatrix();
  }
  
  popStyle();
  popMatrix();
}
