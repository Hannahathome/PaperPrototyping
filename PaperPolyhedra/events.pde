////----------------------------------------------------------------------
//// all actions done with buttons and mouse drag
////--------------------------------------------------------------

void mousePressed() {
  // Face-selection toggle bookkeeping — reset on every press so a press that never reaches
  // a face (a button, the sidebar) cannot leave a stale flag for mouseReleased to act on.
  _facePressWasSelected = false;
  _connDragMoved = false;

  // Check cropper first (highest priority when active)
  if (cropperActive && imageCropper != null) {
    imageCropper.handleMousePressed();
    return;
  }
  
  // Assembly template piece drag — check before UI so clicks on the canvas work
  if (assemblyMode && assemblyShowTemplate && activeAssembly != null && !view3DMode) {
    float pxX = (mouseX - canvasOffsetX) / SCREEN_SCALE - patX_px;
    float pxY = (mouseY - canvasOffsetY) / SCREEN_SCALE - patY_px;
    int piece = pickAsmPiece(activeAssembly, pxX, pxY);
    if (piece >= 0) {
      asmDragPiece = piece;
      asmDragOffset.set(pxX - activeAssembly._pieceTX[piece],
                        pxY - activeAssembly._pieceTY[piece]);
      return;
    }
  }

  // Marker free-placement pick — drag individual markers on the selected shape's top lid
  if (markerFreePlace && markersEnabled && !view3DMode) {
    PVector mMM = screenToPatternMM(mouseX, mouseY);
    PVector lidC = getTopLidCenterMM();
    float angle = -radians(uiTopLidRotation);       // un-rotate mouse around the lid centre
    float dx = mMM.x - lidC.x, dy = mMM.y - lidC.y;
    float rmx = lidC.x + dx * cos(angle) - dy * sin(angle);
    float rmy = lidC.y + dx * sin(angle) + dy * cos(angle);
    float half = Marker_Size * (9.0 / 7.0) / 2.0;
    ensureMarkerOffsets();
    for (int i = markerOffsets.size() - 1; i >= 0; i--) {
      PVector off = markerOffsets.get(i);
      float cx = lidC.x + off.x, cy = lidC.y + off.y;
      if (abs(rmx - cx) <= half && abs(rmy - cy) <= half) {
        draggedMarkerIdx = i;
        markerDragOffset.set(rmx - cx, rmy - cy);
        return;
      }
    }
  }

  // Base slit (mounting cutout) drag pick — move each shape's slit pattern within the base
  if (baseSlitFreePlace && (baseEnabled || baseOnly) && _baseDrawnValid && !view3DMode) {
    PVector mMM = screenToPatternMM(mouseX, mouseY);
    float bcx = _baseBBoxX + _baseBBoxW / 2.0;
    float bcy = _baseBBoxY + _baseBBoxH / 2.0;
    ensureBaseSlitOffsets();
    for (int i = baseSlitOffsets.size() - 1; i >= 0; i--) {
      PVector off = baseSlitOffsets.get(i);
      float cx = bcx + off.x, cy = bcy + off.y;
      if (dist(mMM.x, mMM.y, cx, cy) <= baseSlitRadiusMM(i)) {
        draggedSlitIdx = i;
        slitDragGrab.set(mMM.x - cx, mMM.y - cy);
        return;
      }
    }
  }

  // Base plate drag pick — move the whole base cutout in the preview
  if ((baseEnabled || baseOnly) && _baseDrawnValid && !view3DMode) {
    PVector mMM = screenToPatternMM(mouseX, mouseY);
    if (mMM.x >= _baseBBoxX && mMM.x <= _baseBBoxX + _baseBBoxW &&
        mMM.y >= _baseBBoxY && mMM.y <= _baseBBoxY + _baseBBoxH) {
      draggedBase = true;
      baseDragGrab.set(mMM.x - _baseBBoxX, mMM.y - _baseBBoxY);
      return;
    }
  }

  // Free placement drag pick — check before UI so clicks on the canvas work
  if (freePlacementMode && !view3DMode) {
    int[] picked = pickShape(mouseX, mouseY);
    if (picked[0] >= 0) {
      // Select the tapped shape if it's different
      if (picked[0] != selectedShapeIdx) {
        saveGlobalsTo(shapes.get(selectedShapeIdx));
        selectedShapeIdx = picked[0];
        loadGlobalsFrom(shapes.get(selectedShapeIdx));
        setParams(false);
        syncUIToSelectedShape();
      }
      draggedShapeIdx = picked[0];
      draggedRepIdx   = picked[1];
      PVector mMM = screenToPatternMM(mouseX, mouseY);
      PVector rp  = shapes.get(draggedShapeIdx).repPositions[draggedRepIdx];
      dragOffset.set(mMM.x - rp.x, mMM.y - rp.y);
      return;
    }
  }
  
  // Cutout drag pick — check on canvas in 2D mode
  if (!view3DMode && cutouts != null && cutouts.size() > 0) {
    PVector mMM = screenToPatternMM(mouseX, mouseY);
    // Transform mouse into lid-rotated coordinate space
    PVector lidC = getTopLidCenterMM();
    float angle = -radians(uiTopLidRotation);
    float dx = mMM.x - lidC.x;
    float dy = mMM.y - lidC.y;
    float rmx = lidC.x + dx * cos(angle) - dy * sin(angle);
    float rmy = lidC.y + dx * sin(angle) + dy * cos(angle);
    int picked = selectCutoutAt(rmx, rmy);
    if (picked >= 0) {
      draggedCutoutIdx = picked;
      cutoutDragOffset.set(rmx - cutouts.get(picked).x_mm, rmy - cutouts.get(picked).y_mm);
      syncCutoutPosControls(cutouts.get(picked).x_mm, cutouts.get(picked).y_mm);
      return;
    }
  }
  
  // Reset bottom export button click state
  bottomExportClicked = false;
  
  // 3D view mode overlay buttons (Selected / All) + shape nav arrows
  if (view3DMode) {
    // Mode toggle buttons
    for (int i = 0; i < 2; i++) {
      float[] r = get3DViewBtnRect(i);
      if (mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3]) {
        view3DShowAll = (i == 1);
        return;
      }
    }
    // Wireframe toggle button
    {
      float[] r = getWireframeBtnRect();
      if (mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3]) {
        wireframeMode = !wireframeMode;
        return;
      }
    }
    // Connect toggle button
    {
      float[] r = getConnectBtnRect();
      if (mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3]) {
        connectMode = !connectMode;
        if (!connectMode) clearFaceSelection();
        println("[Connection] Connect mode: " + connectMode);
        return;
      }
    }
    // Disconnect button
    {
      float[] r = getDisconnectBtnRect();
      if (mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3]) {
        if (connectMode) disconnectSelected();
        return;
      }
    }
    // Shape navigation arrows
    if (shapes != null && shapes.size() > 1) {
      for (int i = 0; i < 2; i++) {
        float[] r = get3DViewArrowRect(i);
        if (mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3]) {
          int next = selectedShapeIdx + (i == 0 ? -1 : 1);
          if (next >= 0 && next < shapes.size()) {
            selectedShapeIdx = next;
            loadGlobalsFrom(shapes.get(selectedShapeIdx));
            setParams(false);
          }
          return;
        }
      }
    }

    // Connect mode: click a lid face to attach the SELECTED shape to it, or to grab a
    // connection that is already there. faceHits was filled by draw3DView() while the 3D
    // transform was applied, so this is a plain point-in-polygon test.
    if (connectMode && shapes != null) {
      float bx = mouseX - LEFT_SIDEBAR_WIDTH;
      float by = mouseY - TOOLBAR_HEIGHT;
      FaceHit f = pickFace(bx, by);
      if (f != null) {
        PVector local = faceScreenToLocal(f, bx, by);

        // Precedence on a face click:
        //   1. a connection under the pointer  -> grab it (drag / select for Del)
        //   2. a face already picked on ANOTHER shape -> join them
        //   3. otherwise -> make this the picked face
        int hit = pickConnectionOnFace(f, local);

        if (hit < 0 && selectedFaceShapeIdx >= 0 && selectedFaceShapeIdx != f.shapeIdx) {
          // Two-click connect. The FIRST face picked is the child's mating lid, so picking
          // the child's top face gives a top-to-top joint and the child is turned over —
          // that is what childFlipped means to the 3D pose and to the slit ring.
          int childIdx = selectedFaceShapeIdx;
          boolean childUsesTop = selectedFaceIsTop;
          hit = addConnection(f.shapeIdx, childIdx, f.isTop, new PVector(0, 0));
          if (hit >= 0) {
            connections.get(hit).childFlipped = childUsesTop;
            println("[Connection] " + (childUsesTop ? "top" : "bottom") + " of shape " + childIdx +
                    " -> " + (f.isTop ? "top" : "bottom") + " of shape " + f.shapeIdx);
          }
          _facePressWasSelected = false;
          selectFace(f.shapeIdx, f.isTop);   // host face stays lit, ready for the next join
        } else {
          // Remember whether it was already picked; mouseReleased turns that into a
          // deselect if the pointer never moved.
          _facePressWasSelected = isFaceSelected(f.shapeIdx, f.isTop);
          selectFace(f.shapeIdx, f.isTop);
          // Clicking a face that hosts a child, but missing its footprint, still selects
          // that child — otherwise it could not be disconnected.
          if (hit < 0) hit = nearestConnectionOnFace(f, local);
        }

        selectedConnectionIdx = hit;   // -1 when the face holds nothing
        if (hit >= 0) {
          draggedConnectionIdx = hit;
          draggedFace          = f;
          Connection c = connections.get(hit);
          connDragGrab.set(local.x - c.posLocal.x, local.y - c.posLocal.y);
        }
        return;
      }
    }
  }

  // Template edit mode - handle thumbnail clicks
  if (platonicEditMode) {
    handleTemplateEditModeClick();
    return; // Don't process other UI when in edit mode
  }
  
  // Check if clicking in mini 3D view
  if (isMouseInMini3DView()) {
    isDraggingMini3D = true;
    return;
  }
  
  // Check toolbar first (before other UI)
  if (toolbar != null && toolbar.mousePressed()) {
    return;  // Toolbar handled the click
  }
  
  // Check sidebar next
  if (sidebar != null && sidebar.mousePressed()) {
    return;  // Sidebar handled the click
  }
  
  // Check lid movement buttons (must be after sidebar check to allow proper visibility)
  if (checkLidButtonPress()) {
    return;  // Lid button was pressed
  }
  
  // Other mouse handling can go here if needed
}

void mouseMoved() {
  // Update toolbar hover states
  if (toolbar != null) {
    toolbar.mouseMoved();
  }
  
  // Update sidebar hover states
  if (sidebar != null) {
    sidebar.mouseMoved();
  }
}

void keyPressed() {
  // When the texture cropper is open, route all key events to it
  if (cropperActive && imageCropper != null) {
    imageCropper.handleKeyPressed(key, keyCode);
    return;
  }
  
  // Check if any ControlP5 textfield has focus - if so, ignore keyboard shortcuts
  if (cp5__prism != null && cp5__prism.isMouseOver()) {
    return; // Let ControlP5 handle the key event
  }
  
  if (key == 'e' || key == 'E') {
    bSavePDF = true;
  }
  if (key == 'g' || key == 'G') {
    view3DMode = !view3DMode;
    if (toolbar != null) toolbar.update();
    println("[Keys] 3D view mode: " + view3DMode);
  }
  if (key == 'm' || key == 'M') {
    showMini3DView = !showMini3DView;
    println("[Keys] Mini 3D view toggle: " + showMini3DView);
  }
  if (key == 'r' || key == 'R') {
    reset3DView();
    println("[Keys] 3D view reset");
  }
  
  // Platonic solids test mode controls
  if (key == 'k' || key == 'K') {
    platonicTestMode = !platonicTestMode;
    if (toolbar != null) toolbar.update();
    println("[Keys] Platonic test mode: " + platonicTestMode);
  }
  if (platonicTestMode && (key == 't' || key == 'T')) {
    platonicShowTabs = !platonicShowTabs;
    println("[Keys] Platonic tabs: " + platonicShowTabs);
  }
  if (platonicTestMode && key == '0') {
    platonicSelectedSolid = -1;
    println("[Keys] Platonic: Gallery view");
  }
  if (platonicTestMode && key >= '1' && key <= '5') {
    platonicSelectedSolid = key - '1';
    println("[Keys] Platonic: " + SOLID_NAMES[platonicSelectedSolid]);
  }
  if (platonicTestMode && (key == '+' || key == '=')) {
    platonicTestScale += 20;
    println("[Keys] Platonic scale: " + platonicTestScale);
  }
  if (platonicTestMode && (key == '-' || key == '_')) {
    platonicTestScale = max(50, platonicTestScale - 20);
    println("[Keys] Platonic scale: " + platonicTestScale);
  }
  // Template system test
  if (key == 'p' || key == 'P') {
    println("[Keys] Generating production templates...");
    generateProductionTemplates();
  }
  
  // Zoom controls (Ctrl+ and Ctrl-)
  if (view3DMode && keyCode == CONTROL) {
    // Control key is held, check for +/- or =/minus
  }
  if (view3DMode && (key == '+' || key == '=')) {
    zoom3D += 5.0;
    zoom3D = constrain(zoom3D, 20, 300);
    println("[Zoom] 3D zoom in: " + zoom3D);
  }
  if (view3DMode && (key == '-' || key == '_')) {
    zoom3D -= 5.0;
    zoom3D = constrain(zoom3D, 20, 300);
    println("[Zoom] 3D zoom out: " + zoom3D);
  }
  
  // Skip per-edge and control mode if in platonic test mode
  if (platonicTestMode) return;
  
  // Template edit mode controls
  if (platonicEditMode) {
    // Size adjustment with +/- keys
    if (key == '+' || key == '=') {
      if (selectedTemplate != null) {
        selectedTemplate.edgeLength_mm = min(200, selectedTemplate.edgeLength_mm + 1);
        println("[Edit Mode] Edge length: " + selectedTemplate.edgeLength_mm + " mm");
      }
    }
    if (key == '-' || key == '_') {
      if (selectedTemplate != null) {
        selectedTemplate.edgeLength_mm = max(10, selectedTemplate.edgeLength_mm - 1);
        println("[Edit Mode] Edge length: " + selectedTemplate.edgeLength_mm + " mm");
      }
    }
    return; // Block other controls when in edit mode
  }
  
  // Connect mode: DELETE removes the selected connection, , / . spin the child on its face
  if (connectMode && connections != null &&
      selectedConnectionIdx >= 0 && selectedConnectionIdx < connections.size()) {
    if (key == DELETE || key == BACKSPACE) {
      disconnectSelected();
      return;
    }
    if (key == 'f' || key == 'F') {
      flipSelectedConnection();   // swap which lid of the child mates with the host face
      return;
    }
    if (key == ',' || key == '<') {
      connections.get(selectedConnectionIdx).spinDeg -= 5;
      return;
    }
    if (key == '.' || key == '>') {
      connections.get(selectedConnectionIdx).spinDeg += 5;
      return;
    }
  }

  // Delete selected cutout with DELETE or BACKSPACE
  if ((key == DELETE || key == BACKSPACE) && selectedCutoutIndex >= 0) {
    removeSelectedCutout();
    return;
  }
  
  if (key >= '1' && key <= '4') {
    controlMode = key-'0';
  }
  // --- Per-edge controls--> now kinda  janky but he they work
  if (key == 'P' || key == 'p') {
    togglePerEdgeMode();
    return;
  }

  if (!perEdgeMode) return;
  if (key == '[') {
    selectPreviousEdge();
    return;
  }
  if (key == ']') {
    selectNextEdge();
    return;
  }
  boolean shift = keyEvent != null && (keyEvent.isShiftDown());
  if (key == 'T') {
    incrementTopEdge(+ (shift ? stepCoarse : stepFine));
    return;
  }
  if (key == 't') {
    incrementTopEdge(- (shift ? stepCoarse : stepFine));
    return;
  }

  if (key == 'B') {
    incrementBottomEdge(+ (shift ? stepCoarse : stepFine));
    return;
  }
  if (key == 'b') {
    incrementBottomEdge(- (shift ? stepCoarse : stepFine));
    return;
  }

  if (key == 'C' || key == 'c') {
    copyTopEdgesToBottom();
    return;
  }
  if (key == 'A' || key == 'a') {
    setAllEdgesFromUniformSliders();
    return;
  }
  if (key == 'N' || key == 'n') {
    normalizeTopEdgesToTarget();
    return;
  }
}
void keyReleased() {
  if (key >= '1' && key <= '4') {
    controlMode = 0;
  }
}

void mouseReleased() {
  // Connect mode: a click that did not drag, on a face that was ALREADY selected, clears
  // the selection. Resolving this on release (not press) is what lets you still press a
  // selected face and drag its connection.
  if (connectMode && _facePressWasSelected && !_connDragMoved) {
    clearFaceSelection();
  }
  _facePressWasSelected = false;
  _connDragMoved = false;

  // Reset assembly piece drag
  asmDragPiece = -1;
  // Reset free placement drag
  draggedShapeIdx = -1;
  draggedRepIdx   = -1;
  // Reset cutout drag
  draggedCutoutIdx = -1;
  // Reset marker drag
  draggedMarkerIdx = -1;
  // Reset base plate drag
  draggedBase = false;
  // Reset base slit drag
  draggedSlitIdx = -1;
  // Reset connection drag
  draggedConnectionIdx = -1;
  draggedFace = null;

  // Check cropper first
  if (cropperActive && imageCropper != null) {
    imageCropper.handleMouseReleased();
    return;
  }
  
  // Release mini 3D dragging
  isDraggingMini3D = false;
}

void mouseWheel(MouseEvent event) {
  // Check cropper first
  if (cropperActive && imageCropper != null) {
    imageCropper.handleMouseWheel(event.getCount());
    return;
  }
  
  // Handle 3D zoom (only in canvas area, not in bottom bar)
  boolean in3DView = view3DMode || (assemblyMode && !assemblyShowTemplate);
  if (in3DView && mouseY < height - BOTTOM_EXPORT_HEIGHT) {
    float e = event.getCount();
    zoom3D -= e * 5.0;  // Scroll down = zoom out, scroll up = zoom in
    zoom3D = constrain(zoom3D, 20, 300);  // Limit zoom range
    println("[Zoom] 3D zoom: " + zoom3D);
  }
}

void mouseDragged() {
  // Check cropper first
  if (cropperActive && imageCropper != null) {
    imageCropper.handleMouseDragged();
    return;
  }

  // Assembly piece drag
  if (assemblyMode && assemblyShowTemplate && activeAssembly != null && asmDragPiece >= 0) {
    float pxX = (mouseX - canvasOffsetX) / SCREEN_SCALE - patX_px;
    float pxY = (mouseY - canvasOffsetY) / SCREEN_SCALE - patY_px;
    float newTX = pxX - asmDragOffset.x;
    float newTY = pxY - asmDragOffset.y;
    BarAssembly a = activeAssembly;
    // Offsets are stored in mm; recover natural base (in px) then divide by MM_current.
    if (asmDragPiece == 0) {
      a.stripOffset.set(newTX / MM_current, newTY / MM_current);
    } else if (asmDragPiece == 1) {
      float lidSpacing = a._pieceTY[1] - a.bottomLidOffset.y * MM_current;
      a.bottomLidOffset.set(newTX / MM_current, (newTY - lidSpacing) / MM_current);
    } else {
      float topLidBaseX = a._pieceTX[2] - a.topLidOffset.x * MM_current;
      float topLidBaseY = a._pieceTY[2] - a.topLidOffset.y * MM_current;
      a.topLidOffset.set((newTX - topLidBaseX) / MM_current, (newTY - topLidBaseY) / MM_current);
    }
    redraw();
    return;
  }

  // Free placement drag
  if (freePlacementMode && draggedShapeIdx >= 0 && draggedRepIdx >= 0) {
    ShapeSpec _ds = shapes.get(draggedShapeIdx);
    if (_ds.repPositions != null && draggedRepIdx < _ds.repPositions.length) {
      PVector mMM = screenToPatternMM(mouseX, mouseY);
      _ds.repPositions[draggedRepIdx].set(mMM.x - dragOffset.x, mMM.y - dragOffset.y);
      // Keep global repPositions in sync for the selected shape
      if (draggedShapeIdx == selectedShapeIdx) repPositions = _ds.repPositions;
    }
    redraw();
    return;
  }
  
  // Base slit (mounting cutout) drag
  if (draggedSlitIdx >= 0 && draggedSlitIdx < baseSlitOffsets.size()) {
    PVector mMM = screenToPatternMM(mouseX, mouseY);
    float bcx = _baseBBoxX + _baseBBoxW / 2.0;
    float bcy = _baseBBoxY + _baseBBoxH / 2.0;
    baseSlitOffsets.get(draggedSlitIdx).set(mMM.x - slitDragGrab.x - bcx, mMM.y - slitDragGrab.y - bcy);
    redraw();
    return;
  }

  // Base plate drag
  if (draggedBase) {
    PVector mMM = screenToPatternMM(mouseX, mouseY);
    baseOffsetX = constrain(mMM.x - baseDragGrab.x, -200, 200);
    baseOffsetY = constrain(mMM.y - baseDragGrab.y - _baseAnchorYmm, -200, 200);
    boolean prev = _syncingUI;
    _syncingUI = true;
    if (sBaseOffsetX != null) sBaseOffsetX.setValue(baseOffsetX);
    if (sBaseOffsetY != null) sBaseOffsetY.setValue(baseOffsetY);
    _syncingUI = prev;
    redraw();
    return;
  }

  // Marker drag
  if (draggedMarkerIdx >= 0 && draggedMarkerIdx < markerOffsets.size()) {
    PVector mMM = screenToPatternMM(mouseX, mouseY);
    PVector lidC = getTopLidCenterMM();
    float angle = -radians(uiTopLidRotation);
    float dx = mMM.x - lidC.x, dy = mMM.y - lidC.y;
    float rmx = lidC.x + dx * cos(angle) - dy * sin(angle);
    float rmy = lidC.y + dx * sin(angle) + dy * cos(angle);
    markerOffsets.get(draggedMarkerIdx).set(rmx - lidC.x - markerDragOffset.x,
                                            rmy - lidC.y - markerDragOffset.y);
    redraw();
    return;
  }

  // Cutout drag
  if (draggedCutoutIdx >= 0 && draggedCutoutIdx < cutouts.size()) {
    PVector mMM = screenToPatternMM(mouseX, mouseY);
    // Transform mouse into lid-rotated coordinate space
    PVector lidC = getTopLidCenterMM();
    float angle = -radians(uiTopLidRotation);
    float dx = mMM.x - lidC.x;
    float dy = mMM.y - lidC.y;
    float rmx = lidC.x + dx * cos(angle) - dy * sin(angle);
    float rmy = lidC.y + dx * sin(angle) + dy * cos(angle);
    Cutout c = cutouts.get(draggedCutoutIdx);
    c.x_mm = rmx - cutoutDragOffset.x;
    c.y_mm = rmy - cutoutDragOffset.y;
    // Keep the Move sliders (and hidden numberboxes) in sync with the drag
    syncCutoutPosControls(c.x_mm, c.y_mm);
    redraw();
    return;
  }
  
  // Handle mini 3D view rotation
  if (isDraggingMini3D) {
    float deltaX = mouseX - pmouseX;
    float deltaY = mouseY - pmouseY;
    angleX -= deltaY * 0.01;
    angleZ -= deltaX * 0.01;
    // Mark as custom view when user manually rotates
    currentViewPreset = "Custom";
    return;
  }
  
  // Connection drag across a 3D face. MUST come before the camera-orbit handler below,
  // or dragging a connection would spin the view instead of moving it.
  if (connectMode && draggedConnectionIdx >= 0 && draggedFace != null &&
      connections != null && draggedConnectionIdx < connections.size()) {
    float bx = mouseX - LEFT_SIDEBAR_WIDTH;
    float by = mouseY - TOOLBAR_HEIGHT;
    PVector local = faceScreenToLocal(draggedFace, bx, by);
    Connection c = connections.get(draggedConnectionIdx);
    c.posLocal.set(local.x - connDragGrab.x, local.y - connDragGrab.y);
    snapConnectionToCentre(c);   // magnetic pull back to the middle of the face
    _connDragMoved = true;       // a real drag, so the release must not toggle the selection
    return;
  }

  // Handle 3D rotation (only in canvas area, not in sidebar or bottom bar)
  boolean in3DRotateArea = (view3DMode || (assemblyMode && !assemblyShowTemplate))
                           && mouseY > TOOLBAR_HEIGHT
                           && mouseY < height - BOTTOM_EXPORT_HEIGHT
                           && mouseX > LEFT_SIDEBAR_WIDTH;
  if (in3DRotateArea) {
    float deltaX = mouseX - pmouseX;
    float deltaY = mouseY - pmouseY;
    angleX -= deltaY * 0.01;
    angleZ -= deltaX * 0.01;
    // Mark as custom view when user manually rotates
    currentViewPreset = "Custom";
    return;
  }
  
  if (controlMode == 1) {
    float rate = 0.3;
    cylinder.x -= (mouseY - pmouseY) * rate;
    cylinder.x = max(cylinder.x, 0);
    println("TopPerimeter: ", nf(cylinder.x, 0, 2), "mm");
  }
  if (controlMode == 2) {
    float rate = 0.3; // Control the sensitivity of the mouse drag
    cylinder.y += (mouseY - pmouseY) * rate;
    cylinder.y = max(cylinder.y, 0);
    println("BasePerimeter: ", nf(cylinder.y, 0, 2), "mm");
  }
  if (controlMode == 3) {
    float rate = 0.3; // Control the sensitivity of the mouse drag
    cylinder.z += (mouseY - pmouseY) * rate;
    cylinder.z = max(cylinder.z, 0);
    println("Height: ", nf(cylinder.z, 0, 2), "mm");
  }
  if (controlMode == 4) {
    float rate = 0.3;
    cylinder.x += (mouseX - pmouseX) * rate;
    cylinder.x = max(cylinder.x, 0);
    cylinder.y += (mouseX - pmouseX) * rate;
    cylinder.y = max(cylinder.y, 0);
    println("TopPerimeter: ", nf(cylinder.x, 0, 2), "mm");
    println("BasePerimeter: ", nf(cylinder.y, 0, 2), "mm");
  }
}

// Route printable key events to the cropper's text-input handler
void keyTyped() {
  if (cropperActive && imageCropper != null && imageCropper.textEditMode) {
    imageCropper.handleKeyTyped(key);
  }
}

//----------------------------------------------------------------------
// TEMPLATE EDIT MODE EVENT HANDLERS
//----------------------------------------------------------------------

/**
 * Handle mouse clicks in template edit mode
 * Detects thumbnail selection clicks
 */
void handleTemplateEditModeClick() {
  // Calculate thumbnail positions (must match drawThumbnailGrid in snippet.pde)
  float thumbnailSize = 80;
  float thumbnailSpacing = 10;
  float topMargin = TOOLBAR_HEIGHT + 20;
  float thumbnailY = topMargin;
  
  float totalThumbnailWidth = (thumbnailSize + thumbnailSpacing) * 5 - thumbnailSpacing;
  float thumbnailStartX = (width - totalThumbnailWidth) / 2;
  
  // Check if clicking on a thumbnail
  for (int i = 0; i < 5; i++) {
    float x = thumbnailStartX + i * (thumbnailSize + thumbnailSpacing);
    float y = thumbnailY;
    
    if (mouseX >= x && mouseX <= x + thumbnailSize &&
        mouseY >= y && mouseY <= y + thumbnailSize) {
      // Thumbnail clicked!
      selectedThumbnailIndex = i;
      selectedTemplateType = SOLID_NAMES[i];
      
      // Create new template for selected solid
      selectedTemplate = new PlatonicSolidTemplate(selectedTemplateType, 40.0);
      selectedTemplate.templateName = selectedTemplateType + "_custom";
      
      println("[Edit Mode] Selected: " + selectedTemplateType);
      return;
    }
  }
}

// ---------------------------------------------------------------------------
// Hit-test all shapes and their rep copies.
// Returns int[2] = {shapeIdx, repIdx}, or {-1, -1} if nothing was hit.
// Checks in reverse draw order so the topmost-drawn copy is picked first.
// Requires each shape's cachedBBox to be populated by the draw loop.
// ---------------------------------------------------------------------------
int[] pickShape(float sx, float sy) {
  if (shapes == null) return new int[]{-1, -1};
  PVector mMM = screenToPatternMM(sx, sy);
  for (int si = shapes.size() - 1; si >= 0; si--) {
    ShapeSpec _ps = shapes.get(si);
    if (_ps.repPositions == null || _ps.cachedBBox == null) continue;
    float bboxWmm = _ps.cachedBBox.x / MM_current;
    float bboxHmm = _ps.cachedBBox.y / MM_current;
    // cachedBBox.z = overallLeft in px (≤ 0); cachedBBoxTop = overallTop in px (≤ -tabDepth)
    float leftOffMm = _ps.cachedBBox.z / MM_current;
    float topOffMm  = _ps.cachedBBoxTop / MM_current;
    for (int ri = _ps.repPositions.length - 1; ri >= 0; ri--) {
      float px = _ps.repPositions[ri].x + leftOffMm;
      float py = _ps.repPositions[ri].y + topOffMm;
      if (mMM.x >= px && mMM.x <= px + bboxWmm &&
          mMM.y >= py && mMM.y <= py + bboxHmm) {
        return new int[]{si, ri};
      }
    }
  }
  return new int[]{-1, -1};
}

// Legacy single-shape helper (kept for callers that still reference it).
int pickRepeat(float sx, float sy) {
  int[] hit = pickShape(sx, sy);
  return (hit[0] == selectedShapeIdx) ? hit[1] : -1;
}
