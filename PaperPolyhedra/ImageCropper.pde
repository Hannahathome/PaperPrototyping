////----------------------------------------------------------------------
//// ImageCropper class for texture editing
//// Allows users to position, zoom, and crop images to fit panel dimensions
////----------------------------------------------------------------------

// Cropper mode enumeration
final int CROP_MODE_PANEL = 0;
final int CROP_MODE_STRIP = 1;
final int CROP_MODE_LID = 2;

// Global cropper instance and state
ImageCropper imageCropper;
boolean cropperActive = false;

class ImageCropper {
  // State variables
  int cropperMode = CROP_MODE_PANEL;
  int cropperPanelIndex = -1;  // Which panel/lid index
  PImage cropperSourceImage = null;
  PImage workingImage = null;  // The image being edited
  
  // Image transform
  float imgX, imgY;  // Image position
  float imgScale = 1.0;  // Image scale factor
  
  // Crop area
  float cropX, cropY;  // Crop rectangle position (center of screen)
  float cropWidth, cropHeight;  // Crop rectangle dimensions
  float cropAspectRatio = 1.0;
  
  // UI state
  boolean dragging = false;
  float dragOffsetX, dragOffsetY;
  
  // Rotation
  float imgRotation = 0;  // degrees — increments of 90
  
  // Text overlay
  String overlayText = "";
  boolean textEditMode = false;
  float textRelX = 0.5;          // normalised position inside crop (0..1)
  float textRelY = 0.5;
  float overlayTextSize = 28;    // font size in screen pixels
  color[] textColors = {color(0), color(255), color(255, 60, 60), color(60, 160, 255)};
  int textColorIndex = 0;
  color overlayTextColor = color(0);
  float overlayTextRotation = 0;  // degrees
  boolean textDragging = false;
  float textDragOX, textDragOY;
  
  // ArUco marker overlay
  boolean markerEnabled = false;
  int markerOverlayID = 0;
  float markerOverlaySizeMm = 20;      // Physical size in mm — matches Marker_Size units
  float cropPhysicalWidthMm = 50;      // Physical width of crop area in mm (set by calculateAspectRatio)
  float markerRelX = 0.75;
  float markerRelY = 0.25;
  boolean markerDragging = false;
  float markerDragOX, markerDragOY;
  PImage cachedMarkerImg = null;
  
  // Buttons
  float buttonWidth = 120;
  float buttonHeight = 40;
  float buttonSpacing = 15;
  float buttonY;
  
  // Colors (matching SidebarButton style)
  color colorNormal = color(100, 100, 110);
  color colorActive = color(50, 150, 255);
  color colorHover = color(120, 120, 130);
  color colorDisabled = color(80, 80, 80);
  color colorText = color(255);
  color colorOverlay = color(0, 0, 0, 200);
  
  ImageCropper() {
    // Constructor
  }
  
  // Open the cropper with a texture
  void open(int mode, int panelIndex, PImage sourceImg) {
    if (sourceImg == null) return;
    
    cropperMode = mode;
    cropperPanelIndex = panelIndex;
    cropperSourceImage = sourceImg;
    workingImage = sourceImg.get();  // Create a copy
    
    // Calculate aspect ratio based on mode
    calculateAspectRatio();
    
    // Calculate crop rectangle dimensions
    calculateCropDimensions();
    
    // Auto-fit image to crop area
    autoFitImage();
    
    // Reset rotation and text for fresh session
    imgRotation = 0;
    overlayText = "";
    textEditMode = false;
    textRelX = 0.5;
    textRelY = 0.5;
    overlayTextSize = 28;
    textColorIndex = 0;
    overlayTextColor = textColors[0];
    overlayTextRotation = 0;
    
    // Reset marker overlay
    markerEnabled = false;
    markerOverlayID = 0;
    markerOverlaySizeMm = 20;
    markerRelX = 0.75;
    markerRelY = 0.25;
    cachedMarkerImg = null;
    
    // Activate cropper
    cropperActive = true;
    
    // Hide ControlP5 UI elements
    if (cp5__prism != null) {
      cp5__prism.hide();
    }
  }
  
  void calculateAspectRatio() {
    switch (cropperMode) {
      case CROP_MODE_PANEL:
        // Use bottom edge width / height for trapezoid panels
        float panelWidth = (perEdgeMode || cuboidMode) ? edgeBottomPx(cropperPanelIndex) : cellBaseL_px;
        cropAspectRatio = panelWidth / cylinderH_px;
        cropPhysicalWidthMm = panelWidth / MM;
        break;
        
      case CROP_MODE_STRIP:
        // Sum all bottom edges for full unwrapped strip
        float stripWidth = 0;
        if (perEdgeMode || cuboidMode) {
          for (int i = 0; i < nSides; i++) {
            stripWidth += edgeBottomPx(i);
          }
        } else {
          stripWidth = cellBaseL_px * nSides;
        }
        cropAspectRatio = stripWidth / cylinderH_px;
        cropPhysicalWidthMm = stripWidth / MM;
        break;
        
      case CROP_MODE_LID:
        // Square aspect ratio for lids (1:1)
        cropAspectRatio = 1.0;
        // Use lid polygon bounding box as physical reference
        PVector lidDim = getPolygonLidDimensions(nSides, cellBaseL_px, tabDepth_px);
        cropPhysicalWidthMm = lidDim.x / MM;
        break;
    }
  }
  
  void calculateCropDimensions() {
    // Available screen space (accounting for buttons and padding)
    float availableWidth = width * 0.7;
    float availableHeight = height * 0.7;
    buttonY = height - 80;
    
    // Scale crop rectangle to fit screen while maintaining aspect ratio
    if (cropAspectRatio > 1.0) {
      // Wide rectangle
      cropWidth = min(availableWidth, availableHeight * cropAspectRatio);
      cropHeight = cropWidth / cropAspectRatio;
    } else {
      // Tall rectangle
      cropHeight = min(availableHeight, availableWidth / cropAspectRatio);
      cropWidth = cropHeight * cropAspectRatio;
    }
    
    // Center the crop rectangle
    cropX = (width - cropWidth) / 2;
    cropY = (height - cropHeight) / 2;
  }
  
  void autoFitImage() {
    // Calculate scale to fit crop area
    float scaleW = cropWidth / workingImage.width;
    float scaleH = cropHeight / workingImage.height;
    
    // Use the larger scale to ensure crop area is filled
    imgScale = max(scaleW, scaleH);
    
    // Center the image
    float imgWidth = workingImage.width * imgScale;
    float imgHeight = workingImage.height * imgScale;
    
    imgX = (width / 2) - (imgWidth / 2);
    imgY = (height / 2) - (imgHeight / 2);
  }
  
  void draw() {
    // Draw semi-transparent overlay background
    fill(colorOverlay);
    noStroke();
    rect(0, 0, width, height);
    
    // Draw the image with current transform (rotation around crop centre)
    if (workingImage != null) {
      pushMatrix();
      translate(cropX + cropWidth/2, cropY + cropHeight/2);
      rotate(radians(imgRotation));
      translate(-(cropX + cropWidth/2), -(cropY + cropHeight/2));
      translate(imgX, imgY);
      scale(imgScale);
      image(workingImage, 0, 0);
      popMatrix();
    }
    
    // Draw text overlay on top of image (inside crop area)
    drawTextOverlay();
    
    // Draw ArUco marker overlay
    drawMarkerOverlay();
    
    // Draw crop rectangle with mask
    drawCropMask();
    
    // Draw crop rectangle outline
    noFill();
    stroke(255);
    strokeWeight(3);
    rect(cropX, cropY, cropWidth, cropHeight);
    
    // Draw corner guides
    drawCornerGuides();
    
    // Draw aspect ratio label (top-right corner)
    drawAspectRatioLabel();
    
    // Draw buttons
    drawButtons();
    
    // Draw instructions
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(13);
    if (textEditMode) {
      fill(255, 230, 80);
      text("TEXT MODE — Type to add text  •  Backspace to delete  •  Enter or Esc to finish", width / 2, cropY - 30);
    } else {
      fill(255);
      text("Drag image to move  •  Scroll to zoom  •  Drag text label to reposition", width / 2, cropY - 30);
    }
  }
  
  void drawCropMask() {
    // Darken everything outside the crop rectangle
    fill(0, 0, 0, 150);
    noStroke();
    
    // Top
    rect(0, 0, width, cropY);
    // Bottom
    rect(0, cropY + cropHeight, width, height - (cropY + cropHeight));
    // Left
    rect(0, cropY, cropX, cropHeight);
    // Right
    rect(cropX + cropWidth, cropY, width - (cropX + cropWidth), cropHeight);
  }
  
  void drawCornerGuides() {
    stroke(255);
    strokeWeight(2);
    float guideLen = 20;
    
    // Top-left
    line(cropX, cropY, cropX + guideLen, cropY);
    line(cropX, cropY, cropX, cropY + guideLen);
    
    // Top-right
    line(cropX + cropWidth, cropY, cropX + cropWidth - guideLen, cropY);
    line(cropX + cropWidth, cropY, cropX + cropWidth, cropY + guideLen);
    
    // Bottom-left
    line(cropX, cropY + cropHeight, cropX + guideLen, cropY + cropHeight);
    line(cropX, cropY + cropHeight, cropX, cropY + cropHeight - guideLen);
    
    // Bottom-right
    line(cropX + cropWidth, cropY + cropHeight, cropX + cropWidth - guideLen, cropY + cropHeight);
    line(cropX + cropWidth, cropY + cropHeight, cropX + cropWidth, cropY + cropHeight - guideLen);
  }
  
  void drawAspectRatioLabel() {
    String label = "";
    if (cropperMode == CROP_MODE_PANEL) {
      label = "Panel " + (cropperPanelIndex + 1) + " • ";
    } else if (cropperMode == CROP_MODE_STRIP) {
      label = "Strip • ";
    } else if (cropperMode == CROP_MODE_LID) {
      label = "Lid • ";
    }
    
    label += nf(cropAspectRatio, 1, 2) + ":1";
    
    fill(255);
    textAlign(RIGHT, TOP);
    textSize(14);
    text(label, width - 20, 20);
  }
  
  void drawButtons() {
    float totalWidth = 4 * buttonWidth + 3 * buttonSpacing;
    float startX = (width - totalWidth) / 2;
    
    // ── Tertiary row: ArUco marker controls ──────────────────────────────
    float terRowY = buttonY - 110;
    float terCtrlH = 40;
    float markerToggleW = 105;
    // Marker toggle - highlight green when active
    boolean mToggleHover = isButtonHovered(startX, terRowY, markerToggleW, terCtrlH);
    fill(markerEnabled ? color(50, 160, 80) : (mToggleHover ? colorHover : colorNormal));
    stroke(50); strokeWeight(2);
    rect(startX, terRowY, markerToggleW, terCtrlH, 5);
    fill(colorText); noStroke();
    textAlign(CENTER, CENTER); textSize(13);
    text(markerEnabled ? "Marker ON" : "Add Marker", startX + markerToggleW/2, terRowY + terCtrlH/2);
    
    if (markerEnabled) {
      float mx = startX + markerToggleW + 12;
      // ID: ◄  42  ►
      drawButton(mx, terRowY, 30, terCtrlH, "\u25C4", true);
      fill(220); noStroke(); rect(mx + 30, terRowY, 80, terCtrlH, 3);
      fill(50); textAlign(CENTER, CENTER); textSize(13);
      text("ID: " + markerOverlayID, mx + 30 + 40, terRowY + terCtrlH/2);
      drawButton(mx + 110, terRowY, 30, terCtrlH, "\u25BA", true);
      // Size: -  60px  +
      float sx = mx + 150;
      drawButton(sx, terRowY, 30, terCtrlH, "-", true);
      fill(220); noStroke(); rect(sx + 30, terRowY, 90, terCtrlH, 3);
      fill(50); textAlign(CENTER, CENTER); textSize(13);
      text(int(markerOverlaySizeMm) + "mm", sx + 30 + 45, terRowY + terCtrlH/2);
      drawButton(sx + 120, terRowY, 30, terCtrlH, "+", true);
      // Hint
      fill(180); textAlign(LEFT, CENTER); textSize(11);
      text("Drag marker to reposition", sx + 158, terRowY + terCtrlH/2);
    }
    
    // ── Secondary row: rotation + text controls ───────────────────────────
    float secRowY = buttonY - 55;
    float rotBtnW = 85;
    float ctrlH   = 40;
    
    // Rotation buttons
    drawButton(startX, secRowY, rotBtnW, ctrlH, "\u21BA L90", true);
    drawButton(startX + rotBtnW + 8, secRowY, rotBtnW, ctrlH, "\u21BB R90", true);
    
    // Text mode toggle
    float textBtnX = startX + 2*(rotBtnW + 8) + 16;
    float textBtnW = 110;
    drawButton(textBtnX, secRowY, textBtnW, ctrlH, textEditMode ? "Done Typing" : "Add Text", true);
    
    // Size, colour & rotation controls (only visible once text exists or text mode active)
    if (overlayText.length() > 0 || textEditMode) {
      float x2 = textBtnX + textBtnW + 8;
      drawButton(x2,      secRowY, 38, ctrlH, "A-", true);
      drawButton(x2 + 46, secRowY, 38, ctrlH, "A+", true);
      // Colour swatch button
      float swatchX = x2 + 92;
      boolean swatchHover = isButtonHovered(swatchX, secRowY, 38, ctrlH);
      fill(swatchHover ? lerpColor(overlayTextColor, color(255), 0.3) : overlayTextColor);
      stroke(200); strokeWeight(2);
      rect(swatchX, secRowY, 38, ctrlH, 5);
      fill(brightness(overlayTextColor) > 128 ? color(0) : color(255));
      noStroke();
      textAlign(CENTER, CENTER); textSize(11);
      text("Color", swatchX + 19, secRowY + ctrlH/2);
      // Text rotation buttons
      float rotTxtX = swatchX + 46;
      drawButton(rotTxtX,      secRowY, 38, ctrlH, "\u21BA", true);  // CCW 15°
      drawButton(rotTxtX + 46, secRowY, 38, ctrlH, "\u21BB", true);  // CW  15°
      // Rotation hint
      fill(220);
      textAlign(LEFT, CENTER);
      textSize(11);
      text(int(overlayTextRotation) + "\u00B0", rotTxtX + 92 + 4, secRowY + ctrlH/2);
    }
    
    // Show current text size hint
    fill(220);
    textAlign(LEFT, CENTER);
    textSize(11);
    text("Size: " + int(overlayTextSize) + "px", textBtnX + textBtnW + 8, secRowY + ctrlH + 8);
    
    // ── Main buttons row ──────────────────────────────────────────────────
    drawButton(startX, buttonY, buttonWidth, buttonHeight, "Upload New", true);
    drawButton(startX + buttonWidth + buttonSpacing, buttonY, buttonWidth, buttonHeight, "Reset", true);
    drawButton(startX + 2 * (buttonWidth + buttonSpacing), buttonY, buttonWidth, buttonHeight, "Cancel", true);
    drawButton(startX + 3 * (buttonWidth + buttonSpacing), buttonY, buttonWidth, buttonHeight, "Apply", true);
  }
  
  void drawButton(float x, float y, float w, float h, String label, boolean enabled) {
    boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;
    
    if (enabled) {
      fill(hover ? colorHover : colorNormal);
    } else {
      fill(colorDisabled);
    }
    
    stroke(50);
    strokeWeight(2);
    rect(x, y, w, h, 5);
    
    fill(colorText);
    noStroke();
    textAlign(CENTER, CENTER);
    textSize(14);
    text(label, x + w/2, y + h/2);
  }
  
  boolean isButtonHovered(float x, float y, float w, float h) {
    return mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;
  }
  
  // Mouse handlers
  boolean handleMousePressed() {
    if (!cropperActive) return false;
    
    float totalWidth = 4 * buttonWidth + 3 * buttonSpacing;
    float startX = (width - totalWidth) / 2;
    
    // ── Tertiary row: marker button checks ─────────────────────────────
    float terRowY = buttonY - 110;
    float terCtrlH = 40;
    float markerToggleW = 105;
    if (isButtonHovered(startX, terRowY, markerToggleW, terCtrlH)) {
      markerEnabled = !markerEnabled;
      if (markerEnabled && m == null) initMarkers("");
      cachedMarkerImg = null; // force re-render
      redraw();
      return true;
    }
    if (markerEnabled) {
      float mx = startX + markerToggleW + 12;
      // ID ◄
      if (isButtonHovered(mx, terRowY, 30, terCtrlH)) {
        markerOverlayID = max(0, markerOverlayID - 1);
        cachedMarkerImg = null;
        redraw(); return true;
      }
      // ID ►
      if (isButtonHovered(mx + 110, terRowY, 30, terCtrlH)) {
        markerOverlayID = min(m != null ? m.length - 1 : 1023, markerOverlayID + 1);
        cachedMarkerImg = null;
        redraw(); return true;
      }
      // Size -
      float sx = mx + 150;
      if (isButtonHovered(sx, terRowY, 30, terCtrlH)) {
        markerOverlaySizeMm = max(1, markerOverlaySizeMm - 1);
        cachedMarkerImg = null;
        redraw(); return true;
      }
      // Size +
      if (isButtonHovered(sx + 120, terRowY, 30, terCtrlH)) {
        markerOverlaySizeMm = min(200, markerOverlaySizeMm + 1);
        cachedMarkerImg = null;
        redraw(); return true;
      }
    }
    
    // ── Secondary row button checks ─────────────────────────────────────
    float secRowY = buttonY - 55;
    float rotBtnW = 85;
    float ctrlH   = 40;
    
    // Rotate Left 90
    if (isButtonHovered(startX, secRowY, rotBtnW, ctrlH)) {
      rotateLeft();
      return true;
    }
    // Rotate Right 90
    if (isButtonHovered(startX + rotBtnW + 8, secRowY, rotBtnW, ctrlH)) {
      rotateRight();
      return true;
    }
    // Text mode toggle
    float textBtnX = startX + 2*(rotBtnW + 8) + 16;
    float textBtnW = 110;
    if (isButtonHovered(textBtnX, secRowY, textBtnW, ctrlH)) {
      textEditMode = !textEditMode;
      redraw();
      return true;
    }
    // Size/colour/rotation buttons (only when text is present or mode active)
    if (overlayText.length() > 0 || textEditMode) {
      float x2 = textBtnX + textBtnW + 8;
      // Size –
      if (isButtonHovered(x2, secRowY, 38, ctrlH)) {
        overlayTextSize = max(8, overlayTextSize - 4);
        redraw();
        return true;
      }
      // Size +
      if (isButtonHovered(x2 + 46, secRowY, 38, ctrlH)) {
        overlayTextSize = min(120, overlayTextSize + 4);
        redraw();
        return true;
      }
      // Colour cycle
      float swatchX = x2 + 92;
      if (isButtonHovered(swatchX, secRowY, 38, ctrlH)) {
        textColorIndex = (textColorIndex + 1) % textColors.length;
        overlayTextColor = textColors[textColorIndex];
        redraw();
        return true;
      }
      // Text rotate CCW 15°
      float rotTxtX = swatchX + 46;
      if (isButtonHovered(rotTxtX, secRowY, 38, ctrlH)) {
        overlayTextRotation = (overlayTextRotation - 15 + 360) % 360;
        redraw();
        return true;
      }
      // Text rotate CW 15°
      if (isButtonHovered(rotTxtX + 46, secRowY, 38, ctrlH)) {
        overlayTextRotation = (overlayTextRotation + 15) % 360;
        redraw();
        return true;
      }
    }
    
    // ── Check marker drag initiation ──────────────────────────────────────
    if (markerEnabled && cachedMarkerImg != null) {
      float msx = cropX + markerRelX * cropWidth;
      float msy = cropY + markerRelY * cropHeight;
      float hw = cachedMarkerImg.width / 2.0;
      float hh = cachedMarkerImg.height / 2.0;
      if (mouseX >= msx - hw - 4 && mouseX <= msx + hw + 4 &&
          mouseY >= msy - hh - 4 && mouseY <= msy + hh + 4) {
        markerDragging = true;
        markerDragOX = mouseX - msx;
        markerDragOY = mouseY - msy;
        return true;
      }
    }
    
    // ── Check text label drag initiation ───────────────────────────────
    if (overlayText.length() > 0 && !textEditMode) {
      float textScreenX = cropX + textRelX * cropWidth;
      float textScreenY = cropY + textRelY * cropHeight;
      float hitZone = max(20, overlayTextSize * 0.8);
      if (abs(mouseX - textScreenX) < hitZone && abs(mouseY - textScreenY) < hitZone) {
        textDragging = true;
        textDragOX = mouseX - textScreenX;
        textDragOY = mouseY - textScreenY;
        return true;
      }
    }
    
    // ── Main row button checks ──────────────────────────────────────────
    // Check Upload New button
    if (isButtonHovered(startX, buttonY, buttonWidth, buttonHeight)) {
      uploadNewImage();
      return true;
    }
    
    // Check Reset button
    if (isButtonHovered(startX + buttonWidth + buttonSpacing, buttonY, buttonWidth, buttonHeight)) {
      reset();
      return true;
    }
    
    // Check Cancel button
    if (isButtonHovered(startX + 2 * (buttonWidth + buttonSpacing), buttonY, buttonWidth, buttonHeight)) {
      close();
      return true;
    }
    
    // Check Apply button
    if (isButtonHovered(startX + 3 * (buttonWidth + buttonSpacing), buttonY, buttonWidth, buttonHeight)) {
      applyAndClose();
      return true;
    }
    
    // Start dragging image if clicking in canvas (above button area)
    if (mouseY < buttonY - 65) {
      dragging = true;
      dragOffsetX = mouseX - imgX;
      dragOffsetY = mouseY - imgY;
    }
    
    return true;
  }
  
  boolean handleMouseReleased() {
    if (!cropperActive) return false;
    dragging = false;
    textDragging = false;
    markerDragging = false;
    return true;
  }
  
  boolean handleMouseDragged() {
    if (!cropperActive) return false;
    
    if (markerDragging) {
      float msx = mouseX - markerDragOX;
      float msy = mouseY - markerDragOY;
      markerRelX = constrain((msx - cropX) / cropWidth,  0.01, 0.99);
      markerRelY = constrain((msy - cropY) / cropHeight, 0.01, 0.99);
      return true;
    }
    
    if (textDragging) {
      float textScreenX = mouseX - textDragOX;
      float textScreenY = mouseY - textDragOY;
      textRelX = constrain((textScreenX - cropX) / cropWidth,  0.01, 0.99);
      textRelY = constrain((textScreenY - cropY) / cropHeight, 0.01, 0.99);
      return true;
    }
    
    if (dragging) {
      imgX = mouseX - dragOffsetX;
      imgY = mouseY - dragOffsetY;
    }
    
    return true;
  }
  
  boolean handleMouseWheel(float delta) {
    if (!cropperActive) return false;
    
    float zoomFactor = 1.0 - (delta * 0.05);  // 5% zoom per scroll step
    
    // Calculate new scale
    float newScale = imgScale * zoomFactor;
    
    // Limit zoom range
    if (newScale > 0.1 && newScale < 10.0) {
      // Zoom towards mouse position
      float mouseXRelative = mouseX - imgX;
      float mouseYRelative = mouseY - imgY;
      
      imgScale = newScale;
      
      imgX = mouseX - (mouseXRelative * zoomFactor);
      imgY = mouseY - (mouseYRelative * zoomFactor);
    }
    
    return true;
  }
  
  void reset() {
    // Restore from original image
    if (cropperMode == CROP_MODE_PANEL && originalPanelTextures != null && 
        cropperPanelIndex >= 0 && cropperPanelIndex < originalPanelTextures.length &&
        originalPanelTextures[cropperPanelIndex] != null) {
      workingImage = originalPanelTextures[cropperPanelIndex].get();
    } else if (cropperMode == CROP_MODE_STRIP && originalStripImg != null) {
      workingImage = originalStripImg.get();
    } else if (cropperMode == CROP_MODE_LID) {
      if (cropperPanelIndex == 0 && originalLidImgTop != null) {
        workingImage = originalLidImgTop.get();
      } else if (cropperPanelIndex == 1 && originalLidImgBot != null) {
        workingImage = originalLidImgBot.get();
      }
    }
    
    // Reset rotation and text
    imgRotation = 0;
    overlayText = "";
    textEditMode = false;
    textRelX = 0.5;
    textRelY = 0.5;
    overlayTextSize = 28;
    textColorIndex = 0;
    overlayTextColor = textColors[0];
    overlayTextRotation = 0;
    
    // Reset marker overlay
    markerEnabled = false;
    markerOverlayID = 0;
    markerOverlaySizeMm = 20;
    markerRelX = 0.75;
    markerRelY = 0.25;
    cachedMarkerImg = null;
    
    // Reset transform
    autoFitImage();
  }
  
  void close() {
    cropperActive = false;
    cropperSourceImage = null;
    workingImage = null;
    dragging = false;
    
    // Show ControlP5 UI elements again
    if (cp5__prism != null) {
      cp5__prism.show();
    }
  }
  
  void applyAndClose() {
    // Create cropped image
    PImage croppedImg = createCroppedImage();
    
    if (croppedImg != null) {
      // Apply to appropriate texture based on mode
      switch (cropperMode) {
        case CROP_MODE_PANEL:
          if (panelTextures != null && cropperPanelIndex >= 0 && cropperPanelIndex < panelTextures.length) {
            panelTextures[cropperPanelIndex] = croppedImg;
          }
          break;
          
        case CROP_MODE_STRIP:
          // The crop is taken from what the user sees, so it becomes the new unrotated
          // source and the angle starts over — otherwise the rotation would be applied twice.
          setStripSource(croppedImg, true);
          break;
          
        case CROP_MODE_LID:
          if (cropperPanelIndex == 0) {
            lidImgTop = croppedImg;
          } else if (cropperPanelIndex == 1) {
            lidImgBot = croppedImg;
          }
          // Persist cropped lid image to the shape spec
          if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
            saveGlobalsTo(shapes.get(selectedShapeIdx));
          }
          break;
      }
    }
    
    close();
    redraw();
  }
  
  PImage createCroppedImage() {
    // Create off-screen graphics buffer for crop
    PGraphics pg = createGraphics(int(cropWidth), int(cropHeight), JAVA2D);
    
    pg.beginDraw();
    pg.background(255);
    
    float offsetX = cropX;
    float offsetY = cropY;
    
    // Draw the image with rotation around the crop centre
    pg.pushMatrix();
    pg.translate(cropWidth/2, cropHeight/2);
    pg.rotate(radians(imgRotation));
    pg.translate(-cropWidth/2, -cropHeight/2);
    pg.translate(imgX - offsetX, imgY - offsetY);
    pg.scale(imgScale);
    pg.image(workingImage, 0, 0);
    pg.popMatrix();
    
    // Bake text overlay into the image (with rotation)
    if (overlayText.length() > 0) {
      float tx = textRelX * cropWidth;
      float ty = textRelY * cropHeight;
      pg.pushMatrix();
      pg.translate(tx, ty);
      pg.rotate(radians(overlayTextRotation));
      // shadow
      pg.fill(0, 0, 0, 100);
      pg.noStroke();
      pg.textAlign(CENTER, CENTER);
      pg.textSize(overlayTextSize);
      pg.text(overlayText, 2, 2);
      // main text
      pg.fill(overlayTextColor);
      pg.text(overlayText, 0, 0);
      pg.popMatrix();
    }
    
    // Bake ArUco marker into the image
    if (markerEnabled) {
      PImage markerImg = renderMarkerImage(markerOverlayID, markerSizeToCropPx());
      if (markerImg != null) {
        pg.imageMode(CENTER);
        pg.image(markerImg, markerRelX * cropWidth, markerRelY * cropHeight);
        pg.imageMode(CORNER);
      }
    }
    
    pg.endDraw();
    
    return pg.get();
  }
  
  void uploadNewImage() {
    // Trigger file picker based on current mode
    switch (cropperMode) {
      case CROP_MODE_PANEL:
        selectPanelTexture(cropperPanelIndex);
        break;
        
      case CROP_MODE_STRIP:
        selectStripTexture();
        break;
        
      case CROP_MODE_LID:
        selectLidTexture(cropperPanelIndex == 0);  // true for top, false for bottom
        break;
    }
    // Note: cropper will be closed and reopened when new image is selected
  }
  
  // ── ArUco marker rendering ──────────────────────────────────────────────
  PImage renderMarkerImage(int id, int sizePx) {
    if (m == null) return null;
    id = constrain(id, 0, m.length - 1);
    if (m[id] == null || m[id].payload == null) return null;
    
    float actualSize = sizePx * (9.0 / 7.0);
    int pgSize = ceil(actualSize);
    PGraphics pg = createGraphics(pgSize, pgSize, JAVA2D);
    pg.beginDraw();
    pg.background(255);
    pg.noStroke();
    
    float gridSize = actualSize / 9.0;
    
    for (int pi = 0; pi < 8; pi++) {
      for (int pj = 0; pj < 8; pj++) {
        boolean isBlack = false;
        if (pi > 0 && pi < 8 && pj > 0 && pj < 8) {
          if (pi > 1 && pi < 7 && pj > 1 && pj < 7) {
            isBlack = m[id].payload[pi - 2][pj - 2] <= 0;
          } else {
            isBlack = true;
          }
        }
        pg.fill(isBlack ? 0 : 255);
        pg.rect(round(pj * gridSize), round(pi * gridSize), ceil(gridSize), ceil(gridSize));
      }
    }
    
    pg.endDraw();
    return pg.get();
  }
  
  void drawMarkerOverlay() {
    if (!markerEnabled) return;
    if (m == null) initMarkers("");
    if (cachedMarkerImg == null) {
      cachedMarkerImg = renderMarkerImage(markerOverlayID, markerSizeToCropPx());
    }
    if (cachedMarkerImg == null) return;
    
    float msx = cropX + markerRelX * cropWidth;
    float msy = cropY + markerRelY * cropHeight;
    
    clip(cropX, cropY, cropWidth, cropHeight);
    imageMode(CENTER);
    image(cachedMarkerImg, msx, msy);
    imageMode(CORNER);
    noClip();
    
    // Drag handle outline (cyan)
    float hw = cachedMarkerImg.width / 2.0;
    float hh = cachedMarkerImg.height / 2.0;
    noFill();
    stroke(0, 200, 255, 200);
    strokeWeight(2);
    rect(msx - hw - 3, msy - hh - 3, hw*2 + 6, hh*2 + 6, 3);
    // ID label below
    fill(0, 200, 255);
    noStroke();
    textAlign(CENTER, TOP);
    textSize(11);
    text("Marker " + markerOverlayID, msx, msy + hh + 5);
  }
  
  // ── Marker size helper: convert mm to crop-window pixels ─────────────────
  int markerSizeToCropPx() {
    if (cropPhysicalWidthMm <= 0 || cropWidth <= 0) return 60;
    return max(4, int(markerOverlaySizeMm * cropWidth / cropPhysicalWidthMm));
  }
  
  // ── Rotation helpers ────────────────────────────────────────────────────
  void rotateLeft() {
    imgRotation = (imgRotation - 90 + 360) % 360;
    redraw();
  }
  
  void rotateRight() {
    imgRotation = (imgRotation + 90) % 360;
    redraw();
  }
  
  // ── Text overlay rendering ──────────────────────────────────────────────
  void drawTextOverlay() {
    if (overlayText.length() == 0 && !textEditMode) return;
    
    float textScreenX = cropX + textRelX * cropWidth;
    float textScreenY = cropY + textRelY * cropHeight;
    String display = overlayText + (textEditMode ? "|" : "");
    
    // Clip drawing to crop rect
    clip(cropX, cropY, cropWidth, cropHeight);
    
    pushMatrix();
    translate(textScreenX, textScreenY);
    rotate(radians(overlayTextRotation));
    
    // Shadow for legibility
    fill(0, 0, 0, 120);
    noStroke();
    textAlign(CENTER, CENTER);
    textSize(overlayTextSize);
    text(display, 2, 2);
    
    // Main text
    fill(overlayTextColor);
    text(display, 0, 0);
    
    // Drag handle indicator when not typing
    if (!textEditMode && overlayText.length() > 0) {
      float tw = textWidth(overlayText);
      stroke(255, 200, 0, 180);
      strokeWeight(1);
      noFill();
      rect(-tw/2 - 4, -overlayTextSize/2 - 2, tw + 8, overlayTextSize + 4, 3);
    }
    
    popMatrix();
    noClip();
  }
  
  // ── Keyboard handlers (called from events.pde) ──────────────────────────
  void handleKeyPressed(char k, int kCode) {
    if (textEditMode) {
      if (kCode == BACKSPACE) {
        if (overlayText.length() > 0) {
          overlayText = overlayText.substring(0, overlayText.length() - 1);
        }
      } else if (k == ENTER || k == RETURN || kCode == ESC) {
        textEditMode = false;
        // Prevent Processing from closing the sketch on ESC
        if (kCode == ESC) key = 0;
      }
      redraw();
    } else {
      // When not in text mode, ESC does nothing inside the cropper
      if (kCode == ESC) key = 0;
    }
  }
  
  void handleKeyTyped(char c) {
    if (textEditMode && c >= ' ') {
      overlayText += c;
      redraw();
    }
  }
}
