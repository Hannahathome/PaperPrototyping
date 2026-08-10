// CUTOUT.PDE - Cutout shapes for design patterns
// Supports 24x24mm and 54x54mm rounded rectangles
// Position is specified in mm relative to the pattern origin (patX, patY)

class Cutout {
  float x_mm;          // X position in mm (relative to pattern origin)
  float y_mm;          // Y position in mm (relative to pattern origin)
  float size_mm;       // Size in mm (24 or 54) - square cutout
  float cornerRadius_mm; // Corner radius in mm
  boolean selected;    // Whether this cutout is currently selected
  
  Cutout(float _x_mm, float _y_mm, float _size_mm, float _cornerRadius_mm) {
    x_mm = _x_mm;
    y_mm = _y_mm;
    size_mm = _size_mm;
    cornerRadius_mm = _cornerRadius_mm;
    selected = false;
  }
  
  // Draw the cutout outline on screen (inside pattern translate context)
  void drawPreview(float mmScale) {
    float px = x_mm * mmScale;
    float py = y_mm * mmScale;
    float ps = size_mm * mmScale;
    float pr = cornerRadius_mm * mmScale;
    
    pushStyle();
    noFill();
    
    if (selected) {
      stroke(255, 0, 0);
      strokeWeight(2.0 / SCREEN_SCALE);
    } else {
      stroke(0, 120, 255);
      strokeWeight(1.5 / SCREEN_SCALE);
    }
    
    rect(px, py, ps, ps, pr);
    
    // Draw center crosshair
    float cx = px + ps / 2;
    float cy = py + ps / 2;
    float crossSize = 3 * mmScale;
    stroke(selected ? color(255, 0, 0) : color(0, 120, 255, 150));
    strokeWeight(0.5 / SCREEN_SCALE);
    line(cx - crossSize, cy, cx + crossSize, cy);
    line(cx, cy - crossSize, cx, cy + crossSize);
    
    // Draw size label
    fill(selected ? color(255, 0, 0) : color(0, 120, 255));
    noStroke();
    textAlign(CENTER, BOTTOM);
    textSize(10 / SCREEN_SCALE);
    text(nf(size_mm, 0, 0) + "x" + nf(size_mm, 0, 0) + "mm", cx, py - 2 / SCREEN_SCALE);
    
    popStyle();
  }
  
  // Draw the cutout as a cut line for export (PDF/SVG)
  void drawExport(float mmScale) {
    float px = x_mm * mmScale;
    float py = y_mm * mmScale;
    float ps = size_mm * mmScale;
    float pr = cornerRadius_mm * mmScale;
    
    pushStyle();
    noFill();
    stroke(0);
    strokeWeight(0.5);
    rect(px, py, ps, ps, pr);
    popStyle();
  }
  
  // Check if a point (in mm) is inside this cutout
  boolean containsPoint(float mx_mm, float my_mm) {
    return mx_mm >= x_mm && mx_mm <= x_mm + size_mm &&
           my_mm >= y_mm && my_mm <= y_mm + size_mm;
  }
  
  // Get center position in mm
  PVector getCenter() {
    return new PVector(x_mm + size_mm / 2, y_mm + size_mm / 2);
  }
  
  // Set position by center (in mm)
  void setCenterPosition(float cx_mm, float cy_mm) {
    x_mm = cx_mm - size_mm / 2;
    y_mm = cy_mm - size_mm / 2;
  }
}

// ==================== CUTOUT MANAGER ====================
// Manages the list of cutouts and provides UI interaction

ArrayList<Cutout> cutouts = new ArrayList<Cutout>();
int selectedCutoutIndex = -1;  // -1 = none selected
int cutoutSizeOption = 0;      // 0 = 24mm, 1 = 54mm
float cutoutCornerRadius = 2.0; // Default corner radius in mm

// Predefined sizes
final float CUTOUT_SIZE_SMALL = 16.0;  // mm
final float CUTOUT_SIZE_LARGE = 50.0;  // mm

// Get the currently active cutout size based on selection
float getActiveCutoutSize() {
  return (cutoutSizeOption == 0) ? CUTOUT_SIZE_SMALL : CUTOUT_SIZE_LARGE;
}

// Keep the Cutouts-tab position controls (Move sliders + hidden numberboxes) in sync
// with a cutout's mm position, without re-triggering controlEvent.
void syncCutoutPosControls(float xmm, float ymm) {
  _syncingUI = true;
  if (nbCutoutX != null) nbCutoutX.setValue(xmm);
  if (nbCutoutY != null) nbCutoutY.setValue(ymm);
  if (sCutoutX != null) sCutoutX.setValue(xmm);
  if (sCutoutY != null) sCutoutY.setValue(ymm);
  _syncingUI = false;
}

// Add a new cutout at specified position (mm, relative to pattern origin)
void addCutout(float x_mm, float y_mm) {
  float size = getActiveCutoutSize();
  Cutout c = new Cutout(x_mm, y_mm, size, cutoutCornerRadius);
  cutouts.add(c);
  selectedCutoutIndex = cutouts.size() - 1;
  c.selected = true;
  deselectAllCutoutsExcept(selectedCutoutIndex);
  println("[Cutout] Added " + nf(size, 0, 0) + "x" + nf(size, 0, 0) + "mm cutout at (" + nf(x_mm, 0, 1) + ", " + nf(y_mm, 0, 1) + ") mm");
}

// Add a cutout centered at specified position (mm)
void addCutoutCentered(float cx_mm, float cy_mm) {
  float size = getActiveCutoutSize();
  float x = cx_mm - size / 2;
  float y = cy_mm - size / 2;
  addCutout(x, y);
}

// Remove selected cutout
void removeSelectedCutout() {
  if (selectedCutoutIndex >= 0 && selectedCutoutIndex < cutouts.size()) {
    println("[Cutout] Removed cutout " + selectedCutoutIndex);
    cutouts.remove(selectedCutoutIndex);
    selectedCutoutIndex = -1;
  }
}

// Remove cutout at specific index
void removeCutout(int index) {
  if (index >= 0 && index < cutouts.size()) {
    cutouts.remove(index);
    if (selectedCutoutIndex == index) selectedCutoutIndex = -1;
    else if (selectedCutoutIndex > index) selectedCutoutIndex--;
  }
}

// Deselect all cutouts except the specified index
void deselectAllCutoutsExcept(int exceptIdx) {
  for (int i = 0; i < cutouts.size(); i++) {
    cutouts.get(i).selected = (i == exceptIdx);
  }
}

// Select cutout at point (in mm relative to pattern origin)
int selectCutoutAt(float mx_mm, float my_mm) {
  // Search in reverse order (topmost first)
  for (int i = cutouts.size() - 1; i >= 0; i--) {
    if (cutouts.get(i).containsPoint(mx_mm, my_mm)) {
      selectedCutoutIndex = i;
      deselectAllCutoutsExcept(i);
      return i;
    }
  }
  selectedCutoutIndex = -1;
  deselectAllCutoutsExcept(-1);
  return -1;
}

// Draw all cutouts (call inside pattern translate context)
void drawAllCutouts(float mmScale) {
  for (Cutout c : cutouts) {
    c.drawPreview(mmScale);
  }
}

// Draw all cutouts for export (call inside pattern translate context)
void drawAllCutoutsExport(float mmScale) {
  for (Cutout c : cutouts) {
    c.drawExport(mmScale);
  }
}

// Update selected cutout position from UI numberboxes
void updateSelectedCutoutPosition(float newX_mm, float newY_mm) {
  if (selectedCutoutIndex >= 0 && selectedCutoutIndex < cutouts.size()) {
    Cutout c = cutouts.get(selectedCutoutIndex);
    c.x_mm = newX_mm;
    c.y_mm = newY_mm;
  }
}

// Update selected cutout size
void updateSelectedCutoutSize(float newSize_mm) {
  if (selectedCutoutIndex >= 0 && selectedCutoutIndex < cutouts.size()) {
    Cutout c = cutouts.get(selectedCutoutIndex);
    c.size_mm = newSize_mm;
  }
}

// Get the center of the top lid in mm (relative to pattern origin)
// Returns a PVector with x_mm, y_mm
PVector getTopLidCenterMM() {
  float mm = MM_current;
  
  float stripHeight = getStripHeight();
  
  if (cuboidMode && edgeTop_px != null && edgeBot_px != null) {
    // Cuboid mode
    float botLidW = edgeBot_px[0];
    float botLidD = edgeBot_px[1];
    float topLidW = edgeTop_px[0];
    float topLidD = edgeTop_px[1];
    
    PVector botDim = getRectangularLidDimensions(botLidW, botLidD, tabDepth_px);
    PVector topDim = getRectangularLidDimensions(topLidW, topLidD, tabDepth_px);
    
    // Match exact lidSpacing from drawPlan()
    float extraLidSpace = max(0, topDim.y - botDim.y);
    float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * mm);
    
    float topLidOriginX_px = (uiLidOffsetX + uiTopLidOffsetX) * mm + botDim.x;
    float topLidOriginY_px = lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * mm + (botDim.y - topDim.y);
    
    // Center of the inner rectangle (inside tabs)
    float centerX_px = topLidOriginX_px + tabDepth_px + topLidW / 2.0;
    float centerY_px = topLidOriginY_px + tabDepth_px + topLidD / 2.0;
    
    return new PVector(centerX_px / mm, centerY_px / mm);
    
  } else if (perEdgeMode && edgeTop_px != null && edgeBot_px != null) {
    // Variable polygon per-edge mode
    PVector botDim = getPolygonLidVarDimensions(edgeBot_px, tabDepth_px);
    PVector topDim = getPolygonLidVarDimensions(edgeTop_px, tabDepth_px);
    
    // Match exact lidSpacing from drawPlan()
    float extraLidSpace = max(0, topDim.y - botDim.y);
    float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * mm);
    
    float topLidOriginX_px = (uiLidOffsetX + uiTopLidOffsetX) * mm + botDim.x;
    float topLidOriginY_px = lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * mm + (botDim.y - topDim.y);
    
    float centerX_px = topLidOriginX_px + topDim.x / 2.0;
    float centerY_px = topLidOriginY_px + topDim.y / 2.0;
    
    return new PVector(centerX_px / mm, centerY_px / mm);
    
  } else {
    // Uniform polygon mode
    PVector lidBaseSize = getPolygonLidDimensions(nSides, cellBaseL_px, tabDepth_px);
    PVector lidTopSize  = getPolygonLidDimensions(nSides, cellTopL_px, tabDepth_px);
    
    // Match exact lidSpacing from drawPlan()
    float extraLidSpace = max(0, lidTopSize.y - lidBaseSize.y);
    float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * mm);
    
    float topLidOriginX_px = (uiLidOffsetX + uiTopLidOffsetX) * mm + lidBaseSize.x;
    float topLidOriginY_px = lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * mm + (lidBaseSize.y - lidTopSize.y);
    
    float centerX_px = topLidOriginX_px + lidTopSize.x / 2.0;
    float centerY_px = topLidOriginY_px + lidTopSize.y / 2.0;
    
    return new PVector(centerX_px / mm, centerY_px / mm);
  }
}
