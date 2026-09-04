// SIDEBARPANEL.PDE - LEFT SIDEBAR UI
// Manages the left sidebar with tabs for Shape, Texture, and View controls
// Created: 2025-12-04
//
// FILE ORGANIZATION:
// Section 1: Global Variables - Upload tracking
// Section 2: SidebarButton Class - Reusable button component
// Section 3: SidebarPanel Class - Main sidebar container
//            - Constructor & Setup
//            - Drawing Functions (draw(), drawShapeControlContent(), etc.)
//            - Texture Upload Area (drawTextureUploadArea(), drawPerPanelUploadButtons())
//            - Mouse Event Handling (mousePressed(), mouseMoved())
//            - Tab Click Handlers (handleMainTabClick(), handleTextureTabClick())
// Section 4: Texture File Selection Callbacks - File picker callbacks
// Section 5: Texture Editing Functions - Image cropper integration


// GLOBAL VARIABLES
int currentPanelUploadIndex = 0;


//SIDEBAR BUTTON CLASS
class SidebarButton {
  float x, y, w, h;
  String label;
  String id;
  boolean active, hover, enabled;
  color colorNormal, colorActive, colorHover, colorDisabled, colorText;
  
  SidebarButton(String _id, float _x, float _y, float _w, float _h, String _label) {
    id = _id;
    x = _x;
    y = _y;
    w = _w;
    h = _h;
    label = _label;
    active = false;
    hover = false;
    enabled = true;
    
    // Default colors
    colorNormal = color(100, 100, 110);
    colorActive = color(50, 150, 255);
    colorHover = color(120, 120, 130);
    colorDisabled = color(80, 80, 80);
    colorText = color(255);
  }
  
  void draw() {
    pushStyle();
    
    // Determine button color
    color btnColor = colorNormal;
    if (!enabled) {
      btnColor = colorDisabled;
    } else if (active) {
      btnColor = colorActive;
    } else if (hover) {
      btnColor = colorHover;
    }
    
    // Draw button background
    fill(btnColor);
    noStroke();
    rect(x, y, w, h, 4);
    
    // Draw label
    fill(enabled ? colorText : color(150));
    textAlign(CENTER, CENTER);
    textSize(12);
    text(label, x + w/2, y + h/2);
    
    popStyle();
  }
  
  boolean isMouseOver() {
    return mouseX >= x && mouseX <= x + w && 
           mouseY >= y && mouseY <= y + h;
  }
  
  void setActive(boolean state) {
    active = state;
  }
  
  void setEnabled(boolean state) {
    enabled = state;
  }
  
  void setTabColor(color tabColor) {
    colorNormal = tabColor;
    colorActive = tabColor;
    // Make hover slightly brighter
    colorHover = lerpColor(tabColor, color(255), 0.2);
  }
}


//SIDEBARPANEL CLASS
// the main sidebar container with tab management is done here
class SidebarPanel {
  ArrayList<SidebarButton> buttons;
  ArrayList<SidebarButton> mainTabs;
  float x, y, w, h;
  color bgColor, sectionColor;
  
  //  tab state: 0=Shape, 1=Texture, 2=View
  int activeMainTab = 0;
  
  // texture sub-tab state (when in texture tab)
  int activeTextureTab = 0; // 0=Per-Panel, 1=Strip
  
  // print sub-tab state (when in print tab)
  int activePrintTab = 0; // 0=Placement, 1=Cutouts
  
  // Texture toggle states
  boolean[] perPanelEnabled; // Array for each panel
  boolean topLidEnabled = false;
  boolean bottomLidEnabled = false;
  
  // Tab dimensions
  float tabAreaHeight = 50;
  float contentY;
  float contentHeight;
   
  SidebarPanel() {
    buttons = new ArrayList<SidebarButton>();
    mainTabs = new ArrayList<SidebarButton>();
    x = 0;
    y = TOOLBAR_HEIGHT;
    w = LEFT_SIDEBAR_WIDTH;
    h = height - TOOLBAR_HEIGHT;  // Extend to bottom of window (removed BOTTOM_EXPORT_HEIGHT)
    bgColor = color(240, 240, 245);
    sectionColor = color(255, 255, 255);
    
    contentY = y + tabAreaHeight;
    contentHeight = h - tabAreaHeight;
    
    // Initialize per-panel enabled states - all OFF by default
    int numPanels = max(3, nSides);
    perPanelEnabled = new boolean[numPanels];
    for (int i = 0; i < numPanels; i++) {
      perPanelEnabled[i] = false;
    }
  }
  
  void setup() {
    buttons.clear();
    mainTabs.clear();
    setupMainTabs();
  }
  
  void setupMainTabs() {
    // Show "Assem" tab only when assembly mode is active.
    int nTabs = assemblyMode ? 4 : 3;
    float tabWidth = (w - (nTabs + 1) * SIDEBAR_PADDING) / nTabs;
    float tabHeight = 36;
    float sx = x + SIDEBAR_PADDING;
    float sy = y + SIDEBAR_PADDING;

    String[] tabLabels = {"Shape", "Texture", "Print", "Assem"};
    color[] tabColors = {
      color(100, 180, 220),  // Blue for Shape
      color(190, 80, 140),   // Pink/Magenta for Texture
      color(130, 190, 100),  // Green for Print
      color(130, 80, 190)    // Purple for Assemblyyy
    };
    for (int i = 0; i < nTabs; i++) {
      SidebarButton tab = new SidebarButton(
        "main_tab_" + i,
        sx + i * (tabWidth + SIDEBAR_PADDING / 2),
        sy,
        tabWidth,
        tabHeight,
        tabLabels[i]
      );
      tab.setTabColor(tabColors[i]);
      tab.setActive(i == activeMainTab);
      mainTabs.add(tab);
    }
  }

  // Call this whenever assemblyMode is toggled to rebuild tabs.
  void refreshTabsForAssemblyMode() {
    if (!assemblyMode && activeMainTab == 3) activeMainTab = 0;
    if (assemblyMode) activeMainTab = 3;  // jump straight to Assem tab
    mainTabs.clear();
    setupMainTabs();
    updateSidebarControlsVisibility();  // immediately hide/show ControlP5 elements
  }
  
  // Main Draw Function 
    void draw() {
    // Skip drawing when cropper is active
    if (cropperActive) return;
    
    pushStyle();
    
    // Draw sidebar background - ensure it extends to the bottom of the window
    fill(bgColor);
    noStroke();
    rect(x, y, w, height - y);  // Use height - y to ensure it reaches the bottom
    
    // Draw main tabs
    for (SidebarButton tab : mainTabs) {
      tab.draw();
    }
    
    // Draw divider line below tabs
    stroke(200);
    strokeWeight(2);
    line(x, contentY, x + w, contentY);
    
    // Draw content based on active main tab
    if (activeMainTab == 0) {
      drawShapeControlContent();
    } else if (activeMainTab == 1) {
      drawTextureContent();
    } else if (activeMainTab == 2) {
      drawViewControlContent();
    } else if (activeMainTab == 3) {
      drawAssemblyContent();
    }
    
    popStyle();
  }
  
  // tab Content Drawing Functions 
  void drawShapeControlContent() {
    // Shape controls content area
    // ControlP5 elements are positioned in UI.pde
    // This just provides the background area
    
    pushStyle();
    fill(0);
    textAlign(LEFT, TOP);
    textSize(15);
    text("SHAPE PARAMETERS", round(x + SIDEBAR_PADDING), round(contentY + SIDEBAR_PADDING));
    
    // --- Multi-shape counter + Add/Remove buttons ---
    int shapeCount = (shapes != null) ? shapes.size() : 1;
    int selIdx     = (shapes != null) ? selectedShapeIdx + 1 : 1;
    float ctrBtnSize = 26;
    float ctrBtnGap  = 6;
    float ctrY       = contentY + SIDEBAR_PADDING + 20;
    // "Shape N of M" label (include shape label if set)
    fill(60);
    textAlign(LEFT, CENTER);
    textSize(12);
    String shapeLabel = (shapes != null && shapes.size() > 0) ? shapes.get(selectedShapeIdx).label : "";
    String shapeLine  = "Shape " + selIdx + (shapeLabel != null && !shapeLabel.isEmpty() ? ": " + shapeLabel : "") + " of " + shapeCount;
    // "+ Add" button (left-anchored)
    float addBtnX = x + SIDEBAR_PADDING;
    boolean addHover = mouseX >= addBtnX && mouseX <= addBtnX + ctrBtnSize + ctrBtnGap + 10 &&
                       mouseY >= ctrY     && mouseY <= ctrY + ctrBtnSize;
    fill(addHover ? color(50, 170, 70) : color(40, 140, 55));
    noStroke();
    rect(addBtnX, ctrY, ctrBtnSize + ctrBtnGap + 10, ctrBtnSize, 4);
    fill(255); textAlign(CENTER, CENTER); textSize(13);
    text("+", addBtnX + (ctrBtnSize + ctrBtnGap + 10) / 2, ctrY + ctrBtnSize / 2);
    // "- Remove" button (disabled when only 1 shape)
    float remBtnX = addBtnX + ctrBtnSize + ctrBtnGap + 10 + 4;
    boolean canRemove = shapeCount > 1;
    boolean remHover  = canRemove && mouseX >= remBtnX && mouseX <= remBtnX + ctrBtnSize + ctrBtnGap + 10 &&
                        mouseY >= ctrY && mouseY <= ctrY + ctrBtnSize;
    fill(canRemove ? (remHover ? color(200, 60, 60) : color(160, 50, 50)) : color(100, 80, 80));
    noStroke();
    rect(remBtnX, ctrY, ctrBtnSize + ctrBtnGap + 10, ctrBtnSize, 4);
    fill(canRemove ? color(255) : color(150)); textAlign(CENTER, CENTER); textSize(13);
    text("\u2212", remBtnX + (ctrBtnSize + ctrBtnGap + 10) / 2, ctrY + ctrBtnSize / 2);
    // "Shape N of M" label to the right of the buttons
    fill(60);
    textAlign(LEFT, CENTER);
    textSize(12);
    float labelX = remBtnX + ctrBtnSize + ctrBtnGap + 10 + 6;
    text(shapeLine, round(labelX), round(ctrY + ctrBtnSize / 2));
    
    // Draw "Reset to Default" button below the counter row
    float btnX = x + SIDEBAR_PADDING;
    float btnY = ctrY + ctrBtnSize + 6;
    float btnW = w - 2 * SIDEBAR_PADDING;
    float btnH = 28;
    boolean btnHover = mouseX >= btnX && mouseX <= btnX + btnW &&
                       mouseY >= btnY && mouseY <= btnY + btnH;
    
    fill(btnHover ? color(180, 70, 70) : color(160, 60, 60));
    noStroke();
    rect(btnX, btnY, btnW, btnH, 4);
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11);
    text("Reset to Default (30mm)", btnX + btnW/2, btnY + btnH/2);
    
    // "Load JSON" button below Reset
    float jsonBtnY = btnY + btnH + 4;
    boolean jsonHover = mouseX >= btnX && mouseX <= btnX + btnW &&
                        mouseY >= jsonBtnY && mouseY <= jsonBtnY + btnH;
    fill(jsonHover ? color(30, 130, 160) : color(25, 110, 140));
    noStroke();
    rect(btnX, jsonBtnY, btnW, btnH, 4);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11);
    text("Load JSON", btnX + btnW/2, jsonBtnY + btnH/2);
    
    popStyle();

    // Tab length preset buttons (sit just above the secondary toggle group)
    drawTabLengthButtons();

    // Kresling haptic-behavior selector (only in Kresling mode)
    if (kreslingMode) drawKreslingHapticUI();

    // Draw mini 3D view at the bottom of shape control when in 2D mode
    // (hidden in Kresling mode — the 3D preview doesn't reflect the flat pattern)
    if (!view3DMode && !kreslingMode) {
      drawMini3DViewInSidebar();
    }
  }

  // Draws the Kresling haptic selector: "Feel" + 3 type buttons, Generate / Check,
  // and a readout. Positioned via kreslingHapticUIY() so it sits between the Kresling
  // toggle and the manual override sliders (which layoutSecondaryToggles places below it).
  void drawKreslingHapticUI() {
    pushStyle();
    float x0 = x + SIDEBAR_PADDING;
    float fullW = w - 2 * SIDEBAR_PADDING;
    float uiY = kreslingHapticUIY();
    float btnH = 24, gap = 5;

    // "Feel" label + 3 type buttons
    fill(0); textAlign(LEFT, TOP); textSize(12);
    text("Feel", round(x0), round(uiY));
    float btnY = uiY + 16;
    float bW = (fullW - 2 * gap) / 3;
    String[] labels = {"Springy", "Boundary", "Bi-Stable"};
    for (int i = 0; i < 3; i++) {
      float bx = x0 + i * (bW + gap);
      boolean active = (kreslingTargetType == i);
      boolean hov = mouseX >= bx && mouseX <= bx + bW && mouseY >= btnY && mouseY <= btnY + btnH;
      fill(active ? color(50, 150, 255) : (hov ? color(120, 120, 130) : color(100, 100, 110)));
      noStroke(); rect(bx, btnY, bW, btnH, 4);
      fill(255); textAlign(CENTER, CENTER); textSize(10);
      text(labels[i], bx + bW / 2, btnY + btnH / 2);
    }

    // Generate (search + apply) / Check (classify current, no change)
    float genY = btnY + btnH + 8;
    float gW = (fullW - gap) / 2;
    boolean gHov = mouseX >= x0 && mouseX <= x0 + gW && mouseY >= genY && mouseY <= genY + btnH;
    fill(gHov ? color(60, 180, 60) : color(50, 150, 50));
    noStroke(); rect(x0, genY, gW, btnH, 4);
    fill(255); textAlign(CENTER, CENTER); textSize(11);
    text("Generate", x0 + gW / 2, genY + btnH / 2);
    float rx = x0 + gW + gap;
    boolean rHov = mouseX >= rx && mouseX <= rx + gW && mouseY >= genY && mouseY <= genY + btnH;
    fill(rHov ? color(90, 90, 180) : color(75, 75, 150));
    noStroke(); rect(rx, genY, gW, btnH, 4);
    fill(255); textAlign(CENTER, CENTER); textSize(11);
    text("Check", rx + gW / 2, genY + btnH / 2);

    // Live bistability readout — reflects the CURRENT fold height, updates as you drag
    float liveY = genY + btnH + 6;
    fill(kreslingCurrentIsBistable() ? color(30, 150, 60) : color(90));
    textAlign(LEFT, TOP); textSize(10);
    text(kreslingLiveText(), round(x0), round(liveY), fullW, 16);

    // Last Generate/Check result: red when "not possible", amber when may buckle, else neutral
    float roY = liveY + 16;
    boolean fail = (kreslingLastResult != null && !kreslingLastResultOk());
    boolean warn = kreslingLastResultOk() && kreslingLastResult.bucklingRisk;
    fill(fail ? color(190, 40, 40) : (warn ? color(200, 120, 20) : color(60)));
    textAlign(LEFT, TOP); textSize(10);
    text(kreslingReadoutText(), round(x0), round(roY), fullW, 34);

    popStyle();
  }

  // Y of the TAB LENGTH row — shared by drawing and click handling so they stay aligned.
  float tabLengthRowY() {
    return cuboidMode ? togglesYWhenCuboidOn : togglesYWhenCuboidOff;
  }

  // Draws the "TAB LENGTH" label + preset buttons (5 / 10 / 15 mm) on the Shape tab.
  void drawTabLengthButtons() {
    pushStyle();
    float rowY = tabLengthRowY();

    fill(0);
    textAlign(LEFT, TOP);
    textSize(13);
    text("TAB LENGTH", round(x + SIDEBAR_PADDING), round(rowY));

    float btnY = rowY + 18;
    float btnH = 26;
    float gap  = 6;
    float btnW = (w - 2 * SIDEBAR_PADDING - 2 * gap) / 3;
    for (int i = 0; i < TAB_LEN_PRESETS.length; i++) {
      float bx = x + SIDEBAR_PADDING + i * (btnW + gap);
      boolean active = abs(tabDepth - TAB_LEN_PRESETS[i]) < 0.01;
      boolean hov = mouseX >= bx && mouseX <= bx + btnW && mouseY >= btnY && mouseY <= btnY + btnH;
      color bg = active ? color(50, 150, 255) : (hov ? color(120, 120, 130) : color(100, 100, 110));
      fill(bg);
      noStroke();
      rect(bx, btnY, btnW, btnH, 4);
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(12);
      text(TAB_LEN_PRESETS[i] + "mm", bx + btnW / 2, btnY + btnH / 2);
    }
    popStyle();
  }
  
  void drawTextureContent() {
    pushStyle();
    
    // --- SOLID FILL swatch row ---
    final int SW_SIZE = 22;
    final int SW_GAP  = 4;
    final int SW_SECTION_H = 44; // 14 (label) + 22 (swatch row) + 8 (gap)
    float sx = x + SIDEBAR_PADDING;
    float swLabelY = contentY + SIDEBAR_PADDING;
    float swRowY   = swLabelY + 16;

    fill(60);
    noStroke();
    textAlign(LEFT, TOP);
    textSize(11);
    text("SOLID FILL", sx, swLabelY);

    ShapeSpec _swSel = (shapes != null && shapes.size() > 0) ? shapes.get(selectedShapeIdx) : null;
    for (int _i = 0; _i < 9; _i++) {
      float swX = sx + _i * (SW_SIZE + SW_GAP);
      if (_i < 8) {
        stroke(160); strokeWeight(1);
        fill(SWATCH_PALETTE[_i]);
        rect(swX, swRowY, SW_SIZE, SW_SIZE, 3);
      } else {
        // "none" swatch: white with diagonal X
        stroke(160); strokeWeight(1);
        fill(245);
        rect(swX, swRowY, SW_SIZE, SW_SIZE, 3);
        stroke(180); strokeWeight(1.5);
        line(swX + 3, swRowY + 3, swX + SW_SIZE - 3, swRowY + SW_SIZE - 3);
        line(swX + SW_SIZE - 3, swRowY + 3, swX + 3, swRowY + SW_SIZE - 3);
      }
      // Active ring
      if (_swSel != null) {
        boolean active;
        if (_i == 8) {
          active = !_swSel.fillColorEnabled;
        } else {
          active = _swSel.fillColorEnabled && (_swSel.shapeColor == SWATCH_PALETTE[_i]);
        }
        if (active) {
          noFill();
          stroke(255); strokeWeight(2.5);
          rect(swX + 1, swRowY + 1, SW_SIZE - 2, SW_SIZE - 2, 2);
          stroke(80); strokeWeight(1);
          rect(swX, swRowY, SW_SIZE, SW_SIZE, 3);
        }
      }
    }
    
    // Draw texture sub-tabs (shifted down by SW_SECTION_H)
    float sy = contentY + SIDEBAR_PADDING + SW_SECTION_H;
    float tabWidth = (w - 3 * SIDEBAR_PADDING) / 2;
    float tabHeight = 31;
    
    // Clear and recreate texture sub-tabs
    buttons.clear();
    String[] tabLabels = {"Per Panel", "Strip"};
    for (int i = 0; i < 2; i++) {
      SidebarButton tabBtn = new SidebarButton(
        "texture_tab_" + i,
        sx + i * (tabWidth + SIDEBAR_PADDING/2),
        sy,
        tabWidth,
        tabHeight,
        tabLabels[i]
      );
      tabBtn.setActive(i == activeTextureTab);
      buttons.add(tabBtn);
    }
    
    // Draw sub-tabs
    for (SidebarButton btn : buttons) {
      btn.draw();
    }
    
    // Draw texture upload area based on active sub-tab
    drawTextureUploadArea();
    
    // Draw texture bleed toggle
    drawTextureBleedToggle();
    
    // Draw lid texture controls at bottom
    drawLidTextureControls();
    
    popStyle();
  }
  
  void drawViewControlContent() {
    // View control content - positioning controls for 2D view
    pushStyle();
    
    float sx = x + SIDEBAR_PADDING;
    float sy = contentY + SIDEBAR_PADDING;

    // --- Draw Print sub-tabs (Placement / Cutouts / Base) ---
    float tabWidth = (w - 4 * SIDEBAR_PADDING) / 3;
    float tabHeight = 31;
    String[] printTabLabels = {"Placement", "Cutouts", "Base"};
    for (int i = 0; i < 3; i++) {
      float tx = sx + i * (tabWidth + SIDEBAR_PADDING/2);
      boolean active = (activePrintTab == i);
      boolean hov = mouseX >= tx && mouseX <= tx + tabWidth && mouseY >= sy && mouseY <= sy + tabHeight;
      color bg = active ? color(130, 190, 100) : (hov ? color(200, 210, 200) : color(220, 220, 225));
      fill(bg);
      noStroke();
      rect(tx, sy, tabWidth, tabHeight, 4);
      fill(active ? 255 : 60);
      textAlign(CENTER, CENTER);
      textSize(13);
      text(printTabLabels[i], tx + tabWidth/2, sy + tabHeight/2);
    }
    sy += tabHeight + 12;

    if (activePrintTab == 0) {
      // ========== PLACEMENT TAB ==========
      drawPlacementContent(sx, sy);
    } else if (activePrintTab == 1) {
      // ========== CUTOUTS TAB ==========
      drawCutoutControls();
    } else {
      // ========== BASE TAB ==========
      drawBaseContent(sx, sy);
    }

    popStyle();
  }

  // Header + hint for the Base tab; its controls are cp5 sliders positioned in
  // updateSidebarControlsVisibility() when this sub-tab is active.
  void drawBaseContent(float sx, float sy) {
    pushStyle();
    fill(0);
    textAlign(LEFT, TOP);
    textSize(15);
    text("BASE PLATE", round(sx), round(sy));
    fill(90);
    textSize(11);
    text("A plate with a slit at each bottom-lid tab base. Enable it to add to the cut page.",
         round(sx), round(sy + 22), w - 2 * SIDEBAR_PADDING, 40);
    popStyle();
  }

  void drawPlacementContent(float sx, float sy) {
    // --- PAGE SIZE section (hidden in workshop mode) ---
    if (!workshopMode) {
      fill(0);
      textAlign(LEFT, TOP);
      textSize(15);
      text("PAGE SIZE", round(sx), round(sy));
      sy += 22;

      float btnW = (w - 2 * SIDEBAR_PADDING - 3 * 6) / 4;  // 4 buttons, 6px gaps
      float btnH = 30;
      for (int i = 0; i < PAGE_SIZE_NAMES.length; i++) {
        float bx = sx + i * (btnW + 6);
        boolean active = (pageSizeIdx == i);
        boolean hov = mouseX >= bx && mouseX <= bx + btnW && mouseY >= sy && mouseY <= sy + btnH;
        color bg = active ? color(50, 150, 255) : (hov ? color(120, 120, 130) : color(100, 100, 110));
        fill(bg);
        noStroke();
        rect(bx, sy, btnW, btnH, 4);
        fill(255);
        textAlign(CENTER, CENTER);
        textSize(13);
        text(PAGE_SIZE_NAMES[i], bx + btnW/2, sy + btnH/2);
      }
      sy += btnH + 14;  // = PAGE_SIZE_BLOCK_H total advance
    }

    // --- 2D VIEW POSITIONING section ---
    fill(0);
    textAlign(LEFT, TOP);
    textSize(15);
    //text("2D VIEW POSITIONING", round(sx), round(sy));
    
    // REPEAT / FREE PLACEMENT section header — positioned below the lid d-pads
    int btnSz = 26, btnGp = 4, sY = placementBaseY(), rw = 29;  // clears PAGE SIZE (hidden in workshop mode)
    float baseYP = sY + 0.5*rw + 5*(rw + 20) + 10;
    float freePlaceY = baseYP + 3*(btnSz + btnGp) + 25;
    fill(60);
    textSize(12);
    text("REPEATS", round(sx), round(freePlaceY - 18));
    
    // Note: ControlP5 sliders (sPatX, sPatY, sLidOffsetX, sLidOffsetY) have their own labels
    
    // Draw labels for independent lid movement buttons
    // These buttons are positioned below the lid offset sliders
    int startY = placementBaseY();  // clears PAGE SIZE (hidden in workshop mode)
    int row = 29;
    int btnSize = 26;
    int btnGap = 4;
    float baseY = startY + 0.5*row + 5*(row + 20) + 10;
    
    fill(80);
    textAlign(CENTER, TOP);
    textSize(11);
    
    // Top lid label - centered above the D-pad
    float topCenterX = sx + btnSize + btnGap + btnSize/2;
    text("Top Lid", topCenterX, baseY - 15);
    
    // Bottom lid label - centered above the second D-pad
    float botBaseX = sx + 3*(btnSize + btnGap) + 30;
    float botCenterX = botBaseX + btnSize + btnGap + btnSize/2;
    text("Bottom Lid", botCenterX, baseY - 15);
    
    // Inner wall label - only in hollow mode
    if (hollowMode) {
      float innerWallBaseY = baseY + 3*(btnSize + btnGap) + 20;
      float innerWallCenterX = sx + btnSize + btnGap + btnSize/2;
      fill(100, 100, 150);
      text("Inner Wall", innerWallCenterX, innerWallBaseY - 15);
    }
    
    // Split strip half labels - only in split mode
    if (splitStrip) {
      float splitBaseY = baseY + 3*(btnSize + btnGap) + 20;
      if (hollowMode) splitBaseY += 2*(btnSize + btnGap) + 20;
      
      float h1CenterX = sx + btnSize + btnGap + btnSize/2;
      fill(120, 100, 80);
      text("Half 1", h1CenterX, splitBaseY - 15);
      
      float h2BaseX = sx + 3*(btnSize + btnGap) + 30;
      float h2CenterX = h2BaseX + btnSize + btnGap + btnSize/2;
      fill(80, 100, 120);
      text("Half 2", h2CenterX, splitBaseY - 15);
    }
  }

  // ---------------------------------------------------------------------------
  // Assembly Tab (tab index 3)
  // ---------------------------------------------------------------------------
  // Layout constants (shared with mousePressed for hit detection):
  //   ASM_SY0  = contentY + SIDEBAR_PADDING          (top of content)
  //   ASM_SX   = x + SIDEBAR_PADDING
  //   ASM_CTRL_BTN = 24   (size of +/- buttons)
  //   ASM_CTRL_VAL = 130  (x offset to controls from ASM_SX)
  //   ASM_ROW  = 36       (height of each control row)
  //   ASM_GRID_START_Y = ASM_SY0 + 24 + 2*ASM_ROW + 46   (top of grid)
  //   ASM_CELL_PX      = computed per draw call

  void drawAssemblyContent() {
    if (activeAssembly == null) return;

    pushStyle();
    float sx    = x + SIDEBAR_PADDING;
    float sy    = contentY + SIDEBAR_PADDING;
    float availW = w - 2 * SIDEBAR_PADDING;
    final int ROW_H = 28;
    final int SQ = 20;  // color-square side
    final int BTN = 22;

    // =====================================================================
    // Section 1 — SHAPE PALETTE
    // =====================================================================
    fill(0); noStroke(); textAlign(LEFT, TOP); textSize(12);
    text("SHAPE PALETTE", round(sx), round(sy));
    sy += 18;

    int shapeCount = (shapes != null) ? shapes.size() : 0;
    if (shapeCount == 0) {
      fill(140); textSize(10); textAlign(LEFT, TOP);
      text("No shapes loaded.\nImport a JSON file first.", sx, sy);
      sy += 36;
    } else {
      int maxVisible = min(shapeCount, 5);
      float listY = sy;
      for (int i = 0; i < maxVisible; i++) {
        ShapeSpec s = shapes.get(i);
        float rowY = listY + i * ROW_H;
        boolean isSel = (i == activeAssembly.paintShapeIdx);
        boolean hov   = mouseX >= sx && mouseX <= sx + availW &&
                        mouseY >= rowY && mouseY <= rowY + ROW_H;
        if (isSel)     fill(50, 50, 60);
        else if (hov)  fill(210, 215, 220);
        else           fill(230, 232, 235);
        noStroke(); rect(sx, rowY, availW, ROW_H - 2, 3);
        fill(getAsmShapeColor(i));
        rect(sx + 4, rowY + (ROW_H - SQ) / 2, SQ, SQ, 3);
        String lbl = (s.label != null && s.label.length() > 0) ? s.label : ("Shape " + (i + 1));
        fill(isSel ? color(255) : color(30));
        textAlign(LEFT, CENTER); textSize(11);
        text(lbl, sx + 4 + SQ + 6, rowY + ROW_H / 2);
        fill(isSel ? color(200) : color(100));
        textAlign(RIGHT, CENTER); textSize(10);
        text(nf(s.uiTopW, 1, 0) + "x" + nf(s.uiHeight, 1, 0) + "mm", sx + availW - 4, rowY + ROW_H / 2);
      }
      sy = listY + maxVisible * ROW_H + 4;
      // Erase row
      boolean eraseSel = (activeAssembly.paintShapeIdx < 0);
      boolean eraseHov = mouseX >= sx && mouseX <= sx + availW &&
                         mouseY >= sy && mouseY <= sy + ROW_H - 2;
      fill(eraseSel ? color(100, 30, 30) : (eraseHov ? color(210, 195, 195) : color(220, 210, 210)));
      noStroke(); rect(sx, sy, availW, ROW_H - 2, 3);
      fill(eraseSel ? color(255) : color(80));
      textAlign(CENTER, CENTER); textSize(11);
      text("Erase", sx + availW / 2, sy + (ROW_H - 2) / 2);
      sy += ROW_H + 4;
    }

    // ---- Divider ----
    stroke(200); strokeWeight(1); line(sx, sy + 4, sx + availW, sy + 4); noStroke(); sy += 12;

    // =====================================================================
    // Section 2 — GRID
    // =====================================================================
    fill(0); textAlign(LEFT, TOP); textSize(12);
    text("GRID", round(sx), round(sy));
    sy += 18;

    // W and H controls on one row
    fill(80); textAlign(LEFT, CENTER); textSize(11); text("W:", sx, sy + BTN / 2);
    float bxW = sx + 18;
    fill((mouseX >= bxW && mouseX <= bxW + BTN && mouseY >= sy && mouseY <= sy + BTN) ? color(180) : color(150));
    noStroke(); rect(bxW, sy, BTN, BTN, 3);
    fill(255); textAlign(CENTER, CENTER); textSize(14); text("-", bxW + BTN/2, sy + BTN/2);
    fill(30); textAlign(CENTER, CENTER); textSize(12); text("" + activeAssembly.gridW, bxW + BTN + 14, sy + BTN/2);
    float pxW = bxW + BTN + 28;
    fill((mouseX >= pxW && mouseX <= pxW + BTN && mouseY >= sy && mouseY <= sy + BTN) ? color(180) : color(150));
    noStroke(); rect(pxW, sy, BTN, BTN, 3);
    fill(255); textAlign(CENTER, CENTER); textSize(14); text("+", pxW + BTN/2, sy + BTN/2);

    float hStart = sx + 110;
    fill(80); textAlign(LEFT, CENTER); textSize(11); text("H:", hStart, sy + BTN / 2);
    float bxH = hStart + 18;
    fill((mouseX >= bxH && mouseX <= bxH + BTN && mouseY >= sy && mouseY <= sy + BTN) ? color(180) : color(150));
    noStroke(); rect(bxH, sy, BTN, BTN, 3);
    fill(255); textAlign(CENTER, CENTER); textSize(14); text("-", bxH + BTN/2, sy + BTN/2);
    fill(30); textAlign(CENTER, CENTER); textSize(12); text("" + activeAssembly.gridH, bxH + BTN + 14, sy + BTN/2);
    float pxH = bxH + BTN + 28;
    fill((mouseX >= pxH && mouseX <= pxH + BTN && mouseY >= sy && mouseY <= sy + BTN) ? color(180) : color(150));
    noStroke(); rect(pxH, sy, BTN, BTN, 3);
    fill(255); textAlign(CENTER, CENTER); textSize(14); text("+", pxH + BTN/2, sy + BTN/2);
    sy += 30;

    // 2D grid
    int dispCols = min(activeAssembly.gridW, 12);
    int dispRows = min(activeAssembly.gridH, 8);
    float cellPx = min(30.0, (availW - (dispCols - 1) * 2.0) / dispCols);
    for (int r = 0; r < dispRows; r++) {
      for (int c = 0; c < dispCols; c++) {
        float cellX = sx + c * (cellPx + 2);
        float cellY = sy + r * (cellPx + 2);
        int si = activeAssembly.shapeGrid[r][c];
        boolean hov = mouseX >= cellX && mouseX <= cellX + cellPx &&
                      mouseY >= cellY && mouseY <= cellY + cellPx;
        color baseCol = (si >= 0) ? getAsmShapeColor(si) : color(160, 160, 175);
        fill(hov ? lerpColor(baseCol, color(255), 0.3) : baseCol);
        noStroke(); rect(cellX, cellY, cellPx, cellPx, 3);
      }
    }
    sy += dispRows * (cellPx + 2) + 6;

    // Clear / Fill buttons
    float btnW = (availW - 6) / 2;
    float btnH = 26;
    fill((mouseX >= sx && mouseX <= sx + btnW && mouseY >= sy && mouseY <= sy + btnH)
         ? color(190, 65, 65) : color(155, 50, 50)); noStroke(); rect(sx, sy, btnW, btnH, 4);
    fill(255); textAlign(CENTER, CENTER); textSize(11); text("Clear All", sx + btnW / 2, sy + btnH / 2);
    float fillBtnX = sx + btnW + 6;
    fill((mouseX >= fillBtnX && mouseX <= fillBtnX + btnW && mouseY >= sy && mouseY <= sy + btnH)
         ? color(50, 160, 55) : color(40, 125, 45)); noStroke(); rect(fillBtnX, sy, btnW, btnH, 4);
    fill(255); textAlign(CENTER, CENTER); textSize(11); text("Fill All", fillBtnX + btnW / 2, sy + btnH / 2);
    sy += btnH + 8;

    // ---- Divider ----
    stroke(200); strokeWeight(1); line(sx, sy + 4, sx + availW, sy + 4); noStroke(); sy += 12;

    // =====================================================================
    // Section 3 — VIEW
    // =====================================================================
    fill(0); textAlign(LEFT, TOP); textSize(12);
    text("VIEW", round(sx), round(sy));
    sy += 18;

    float viewBtnW = (availW - 6) / 2;
    float viewBtnH = 30;
    boolean is3D = !assemblyShowTemplate;
    fill(is3D ? color(40, 120, 200)
              : ((mouseX >= sx && mouseX <= sx + viewBtnW && mouseY >= sy && mouseY <= sy + viewBtnH)
                 ? color(160, 180, 210) : color(120, 140, 170)));
    noStroke(); rect(sx, sy, viewBtnW, viewBtnH, 4);
    fill(255); textAlign(CENTER, CENTER); textSize(11);
    text(is3D ? "3D View \u2713" : "3D View", sx + viewBtnW / 2, sy + viewBtnH / 2);

    float tplBtnX = sx + viewBtnW + 6;
    boolean isTpl = assemblyShowTemplate;
    fill(isTpl ? color(40, 150, 80)
               : ((mouseX >= tplBtnX && mouseX <= tplBtnX + viewBtnW && mouseY >= sy && mouseY <= sy + viewBtnH)
                  ? color(160, 210, 170) : color(120, 160, 130)));
    noStroke(); rect(tplBtnX, sy, viewBtnW, viewBtnH, 4);
    fill(255); textAlign(CENTER, CENTER); textSize(11);
    text(isTpl ? "Template \u2713" : "Template", tplBtnX + viewBtnW / 2, sy + viewBtnH / 2);
    sy += viewBtnH + 6;

    // True Colour toggle (full-width)
    float tcBtnH = 26;
    fill(assemblyTrueColor ? color(180, 100, 20)
                           : ((mouseX >= sx && mouseX <= sx + availW && mouseY >= sy && mouseY <= sy + tcBtnH)
                              ? color(190, 145, 80) : color(140, 100, 50)));
    noStroke(); rect(sx, sy, availW, tcBtnH, 4);
    fill(255); textAlign(CENTER, CENTER); textSize(11);
    text(assemblyTrueColor ? "True Colours \u2713" : "True Colours", sx + availW / 2, sy + tcBtnH / 2);

    popStyle();
  }

  // ---------------------------------------------------------------------------
  // Cutout Controls (drawn in Print/View tab)
  // ---------------------------------------------------------------------------
  
  void drawCutoutControls() {
    pushStyle();
    
    float sx = x + SIDEBAR_PADDING;
    float sy = contentY + SIDEBAR_PADDING + 31 + 12; // Below sub-tab buttons
    float areaWidth = w - 2 * SIDEBAR_PADDING;
    
    // Section header
    fill(0);
    textAlign(LEFT, TOP);
    textSize(15);
    text("CUTOUTS", round(sx), round(sy));
    sy += 25;
    
    // Size selection buttons (24mm / 54mm)
    float btnW = (areaWidth - 10) / 2;
    float btnH = 28;
    
    // 24mm button
    boolean is24 = (cutoutSizeOption == 0);
    boolean hover24 = mouseX >= sx && mouseX <= sx + btnW &&
                      mouseY >= sy && mouseY <= sy + btnH;
    fill(is24 ? color(50, 150, 50) : (hover24 ? color(120, 120, 130) : color(100, 100, 110)));
    noStroke();
    rect(sx, sy, btnW, btnH, 4);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11);
    text("16 x 16 mm", sx + btnW/2, sy + btnH/2);
    
    // 54mm button
    boolean is54 = (cutoutSizeOption == 1);
    float btn54X = sx + btnW + 10;
    boolean hover54 = mouseX >= btn54X && mouseX <= btn54X + btnW &&
                      mouseY >= sy && mouseY <= sy + btnH;
    fill(is54 ? color(50, 150, 50) : (hover54 ? color(120, 120, 130) : color(100, 100, 110)));
    rect(btn54X, sy, btnW, btnH, 4);
    fill(255);
    text("50 x 50 mm", btn54X + btnW/2, sy + btnH/2);
    sy += btnH + 10;
    
    // Corner radius display
    fill(80);
    textAlign(LEFT, CENTER);
    textSize(11);
    text("Corner radius: " + nf(cutoutCornerRadius, 0, 1) + " mm", sx, sy + 8);
    sy += 25;
    
    // Add cutout button
    float addBtnW = areaWidth;
    float addBtnH = 30;
    boolean addHover = mouseX >= sx && mouseX <= sx + addBtnW &&
                       mouseY >= sy && mouseY <= sy + addBtnH;
    fill(addHover ? color(60, 180, 60) : color(50, 150, 50));
    noStroke();
    rect(sx, sy, addBtnW, addBtnH, 4);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(12);
    text("+ ADD CUTOUT", sx + addBtnW/2, sy + addBtnH/2);
    sy += addBtnH + 15;
    
    // List of existing cutouts
    fill(0);
    textAlign(LEFT, TOP);
    textSize(12);
    text("Placed cutouts: " + cutouts.size(), sx, sy);
    sy += 20;
    
    // Draw each cutout entry with position info and delete button
    for (int i = 0; i < cutouts.size(); i++) {
      Cutout c = cutouts.get(i);
      float rowH = 26;
      float rowY = sy + i * (rowH + 4);
      
      // Highlight selected
      if (i == selectedCutoutIndex) {
        fill(220, 230, 255);
        noStroke();
        rect(sx, rowY, areaWidth, rowH, 3);
      }
      
      // Cutout info
      fill(i == selectedCutoutIndex ? color(0, 60, 180) : color(60));
      textAlign(LEFT, CENTER);
      textSize(10);
      String info = "#" + (i+1) + "  " + nf(c.size_mm, 0, 0) + "mm  X:" + nf(c.x_mm, 0, 1) + "  Y:" + nf(c.y_mm, 0, 1);
      text(info, sx + 4, rowY + rowH/2);
      
      // Delete button
      float delX = sx + areaWidth - 24;
      float delH = 20;
      float delY = rowY + (rowH - delH) / 2;
      boolean delHover = mouseX >= delX && mouseX <= delX + 24 &&
                         mouseY >= delY && mouseY <= delY + delH;
      fill(delHover ? color(220, 50, 50) : color(180, 60, 60));
      noStroke();
      rect(delX, delY, 24, delH, 3);
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(10);
      text("X", delX + 12, delY + delH/2);
    }
    
    popStyle();
  }
  
  // Handle cutout control clicks (called from mousePressed)
  boolean handleCutoutControlClick() {
    if (activeMainTab != 2) return false;
    
    float sx = x + SIDEBAR_PADDING;
    float sy = contentY + SIDEBAR_PADDING + 31 + 12 + 25; // Match drawCutoutControls layout (below sub-tabs + header)
    float areaWidth = w - 2 * SIDEBAR_PADDING;
    float btnW = (areaWidth - 10) / 2;
    float btnH = 28;
    
    // Check 24mm button
    if (mouseX >= sx && mouseX <= sx + btnW &&
        mouseY >= sy && mouseY <= sy + btnH) {
      cutoutSizeOption = 0;
      println("[Cutout] Size set to 16x16mm");
      return true;
    }
    
    // Check 54mm button
    float btn54X = sx + btnW + 10;
    if (mouseX >= btn54X && mouseX <= btn54X + btnW &&
        mouseY >= sy && mouseY <= sy + btnH) {
      cutoutSizeOption = 1;
      println("[Cutout] Size set to 50x50mm");
      return true;
    }
    sy += btnH + 10 + 25; // Skip corner radius row
    
    // Check Add button
    float addBtnW = areaWidth;
    float addBtnH = 30;
    if (mouseX >= sx && mouseX <= sx + addBtnW &&
        mouseY >= sy && mouseY <= sy + addBtnH) {
      // Add cutout centered on the top lid
      PVector lidCenter = getTopLidCenterMM();
      float cutSize = getActiveCutoutSize();
      float defaultX = lidCenter.x - cutSize / 2.0;
      float defaultY = lidCenter.y - cutSize / 2.0;
      addCutout(defaultX, defaultY);
      syncCutoutPosControls(defaultX, defaultY);
      return true;
    }
    sy += addBtnH + 15 + 20; // Skip header
    
    // Check cutout list entries (select or delete)
    for (int i = 0; i < cutouts.size(); i++) {
      float rowH = 26;
      float rowY = sy + i * (rowH + 4);
      
      // Check delete button
      float delX = sx + areaWidth - 24;
      float delH = 20;
      float delY2 = rowY + (rowH - delH) / 2;
      if (mouseX >= delX && mouseX <= delX + 24 &&
          mouseY >= delY2 && mouseY <= delY2 + delH) {
        removeCutout(i);
        // Sync position controls to the newly-selected cutout (if any)
        if (selectedCutoutIndex >= 0 && selectedCutoutIndex < cutouts.size()) {
          Cutout sel = cutouts.get(selectedCutoutIndex);
          syncCutoutPosControls(sel.x_mm, sel.y_mm);
        }
        return true;
      }
      
      // Check row click (select)
      if (mouseX >= sx && mouseX <= sx + areaWidth - 28 &&
          mouseY >= rowY && mouseY <= rowY + rowH) {
        selectedCutoutIndex = i;
        deselectAllCutoutsExcept(i);
        // Sync position controls with the selected cutout
        Cutout sel = cutouts.get(i);
        syncCutoutPosControls(sel.x_mm, sel.y_mm);
        return true;
      }
    }
    
    return false;
  }

  // texture upload area functions
  
  void drawTextureUploadArea() {
    float sx = x + SIDEBAR_PADDING;
    float sy = contentY + SIDEBAR_PADDING + 116; // Below solid-fill row (44px) + texture sub-tabs (72px)
    float areaWidth = w - 2 * SIDEBAR_PADDING;
    float areaHeight = contentHeight - 200; // Space for upload area - leaves room for lid controls
    
    // Make sure area doesn't overlap with lid controls (which start at contentY + contentHeight - 110)
    float maxAreaHeight = (contentY + contentHeight - 110) - sy - 10; // 10px gap
    areaHeight = min(areaHeight, maxAreaHeight);
    
    pushStyle();
    
    fill(245);
    stroke(200);
    strokeWeight(1);
    rect(sx, sy, areaWidth, areaHeight, 4);
    
    fill(100);
    textAlign(CENTER, TOP);
    textSize(11);
    
    if (activeTextureTab == 0) {
      // Per-panel texture
      text("Upload texture for each panel", sx + areaWidth/2, sy + 10);
      drawPerPanelUploadButtons(sx, sy + 30, areaWidth, areaHeight - 40);
    } else if (activeTextureTab == 1) {
      // Strip texture
      text("Upload continuous strip texture", sx + areaWidth/2, sy + 10);
      drawStripUploadButton(sx, sy + 30, areaWidth, areaHeight - 40);
    }
    
    popStyle();
  }
  
  void drawPerPanelUploadButtons(float sx, float sy, float areaWidth, float areaHeight) {
    // Draw individual toggle+upload for each panel
    pushStyle();
    
    int numPanels = max(3, nSides);
    
    // Ensure arrays are sized correctly
    if (perPanelEnabled == null || perPanelEnabled.length != numPanels) {
      boolean[] newEnabled = new boolean[numPanels];
      // Initialize all to false (OFF by default)
      for (int i = 0; i < numPanels; i++) {
        newEnabled[i] = false;
      }
      // Copy existing states if available
      if (perPanelEnabled != null) {
        for (int i = 0; i < min(perPanelEnabled.length, numPanels); i++) {
          newEnabled[i] = perPanelEnabled[i];
        }
      }
      perPanelEnabled = newEnabled;
    }
    
    // Draw Restore to Default button at the top
    float restoreBtnWidth = areaWidth - 10;
    float restoreBtnHeight = 28;
    float restoreBtnX = sx + 5;
    float restoreBtnY = sy;
    boolean restoreHover = mouseX >= restoreBtnX && mouseX <= restoreBtnX + restoreBtnWidth &&
                           mouseY >= restoreBtnY && mouseY <= restoreBtnY + restoreBtnHeight;
    
    fill(restoreHover ? color(180, 70, 70) : color(160, 60, 60));
    noStroke();
    rect(restoreBtnX, restoreBtnY, restoreBtnWidth, restoreBtnHeight, 4);
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11);
    text("Restore All to Default", restoreBtnX + restoreBtnWidth/2, restoreBtnY + restoreBtnHeight/2);
    
    // Adjust starting Y position for panel rows
    sy += restoreBtnHeight + 10;
    
    float rowHeight = 35;
    float labelWidth = 72;
    float toggleW = 50;
    float toggleH = 24;
    float spacing = 7;
    
    for (int i = 0; i < numPanels; i++) {
      float controlY = sy + i * rowHeight;
      
      // Panel label
      fill(80);
      textAlign(LEFT, CENTER);
      textSize(11);
      text("Panel " + (i + 1) + ":", sx, controlY + toggleH/2);
      
      // Toggle button
      float toggleX = sx + labelWidth;
      boolean toggleHover = mouseX >= toggleX && mouseX <= toggleX + toggleW &&
                            mouseY >= controlY && mouseY <= controlY + toggleH;
      
      fill(perPanelEnabled[i] ? color(50, 150, 50) : color(150, 150, 150));
      if (toggleHover && !perPanelEnabled[i]) fill(color(170, 170, 170));
      noStroke();
      rect(toggleX, controlY, toggleW, toggleH, 4);
      
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(10);
      text(perPanelEnabled[i] ? "ON" : "OFF", toggleX + toggleW/2, controlY + toggleH/2);
      
      // Check if texture is loaded
      boolean hasTexture = panelTextures != null && i < panelTextures.length && panelTextures[i] != null;
      
      // Combined Upload/Edit button
      float uploadX = toggleX + toggleW + spacing;
      float buttonW = areaWidth - (uploadX - sx);  // Full width for single button
      float uploadH = toggleH;
      boolean uploadHover = mouseX >= uploadX && mouseX <= uploadX + buttonW &&
                            mouseY >= controlY && mouseY <= controlY + uploadH;
      
      if (hasTexture) {
        fill(uploadHover ? color(120, 120, 130) : color(100, 100, 110));
      } else {
        fill(uploadHover ? color(120, 120, 130) : color(100, 100, 110));
      }
      rect(uploadX, controlY, buttonW, uploadH, 4);
      
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(10);
      text(hasTexture ? "Edit" : "Upload", uploadX + buttonW/2, controlY + uploadH/2);
    }
    
    popStyle();
  }
  
  void drawStripUploadButton(float sx, float sy, float areaWidth, float areaHeight) {
    float btnWidth = (areaWidth - 2 * SIDEBAR_PADDING - 7) / 2;  // Split into two buttons
    float btnHeight = 44;
    float bx = sx + SIDEBAR_PADDING;
    float by = sy + 20;
    float spacing = 7;
    
    pushStyle();
    
    // Draw Restore to Default button at the top
    float restoreBtnWidth = areaWidth - 2 * SIDEBAR_PADDING;
    float restoreBtnHeight = 28;
    float restoreBtnX = bx;
    float restoreBtnY = by;
    boolean restoreHover = mouseX >= restoreBtnX && mouseX <= restoreBtnX + restoreBtnWidth &&
                           mouseY >= restoreBtnY && mouseY <= restoreBtnY + restoreBtnHeight;
    
    fill(restoreHover ? color(180, 70, 70) : color(160, 60, 60));
    noStroke();
    rect(restoreBtnX, restoreBtnY, restoreBtnWidth, restoreBtnHeight, 4);
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11);
    text("Restore to Default", restoreBtnX + restoreBtnWidth/2, restoreBtnY + restoreBtnHeight/2);
    
    // Adjust Y position for upload/edit button
    by += restoreBtnHeight + 10;
    
    // Combined Upload/Edit button
    boolean hasStripTexture = stripImg != null;
    float fullBtnWidth = areaWidth - 2 * SIDEBAR_PADDING;
    boolean uploadHover = mouseX >= bx && mouseX <= bx + fullBtnWidth &&
                          mouseY >= by && mouseY <= by + btnHeight;
    fill(uploadHover ? color(120, 120, 130) : color(100, 100, 110));
    noStroke();
    rect(bx, by, fullBtnWidth, btnHeight, 4);
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(13);
    text(hasStripTexture ? "Edit Strip" : "Upload Strip", bx + fullBtnWidth/2, by + btnHeight/2);
    
    // Show current texture info if loaded
    if (stripImg != null) {
      fill(80);
      textSize(10);
      text(stripImg.width + "x" + stripImg.height + " px", bx + (areaWidth - 2 * SIDEBAR_PADDING)/2, by + btnHeight + 15);
    }
    
    // Click detection moved to mousePressed() method
    
    popStyle();
  }
  
  void drawTextureBleedToggle() {
    float sx = x + SIDEBAR_PADDING;
    float sy = contentY + contentHeight - 145; // Position above lid controls
    float areaWidth = w - 2 * SIDEBAR_PADDING;
    float toggleW = 55;
    float toggleH = 24;
    
    pushStyle();
    
    // Toggle button
    float toggleX = sx;
    boolean hov = mouseX >= toggleX && mouseX <= toggleX + toggleW &&
                  mouseY >= sy && mouseY <= sy + toggleH;
    fill(textureBleed ? color(100, 180, 100) : (hov ? color(180) : color(200)));
    stroke(160);
    strokeWeight(1);
    rect(toggleX, sy, toggleW, toggleH, 4);
    fill(textureBleed ? 255 : 60);
    textAlign(CENTER, CENTER);
    textSize(11);
    text(textureBleed ? "ON" : "OFF", toggleX + toggleW/2, sy + toggleH/2);
    
    // Label
    fill(80);
    textAlign(LEFT, CENTER);
    textSize(12);
    text("Texture bleed (" + nf(textureBleedMM, 0, 0) + "mm)", toggleX + toggleW + 8, sy + toggleH/2);
    
    popStyle();
  }
  
  void drawLidTextureControls() {
    float sx = x + SIDEBAR_PADDING;
    float sy = contentY + contentHeight - 110; // Position at bottom of content area
    float areaWidth = w - 2 * SIDEBAR_PADDING;
    float areaHeight = 100; // Height to contain both lid rows + padding
    
    pushStyle();
    
    // Draw background box for lid section
    fill(245);
    stroke(200);
    strokeWeight(1);
    rect(sx, sy, areaWidth, areaHeight, 4);
    
    // Section header with spacing
    fill(80);
    textAlign(LEFT, TOP);
    textSize(15);
    text("LID TEXTURES", round(sx + 5), round(sy + 5));
    
    sy += 25;
    
    // Top lid row
    drawLidRow("Top Lid", sx + 5, sy, areaWidth - 10, true);
    
    sy += 35;
    
    // Bottom lid row
    drawLidRow("Bottom Lid", sx + 5, sy, areaWidth - 10, false);
    
    popStyle();
  }
  
  void drawLidRow(String label, float sx, float sy, float areaWidth, boolean isTop) {
    pushStyle();
    
    // Label
    fill(60);
    textAlign(LEFT, CENTER);
    textSize(11);
    text(label, sx, sy + 15);
    
    // Toggle button
    float toggleX = sx + 77;
    float toggleW = 55;
    float toggleH = 26;
    boolean toggleState = isTop ? topLidEnabled : bottomLidEnabled;
    boolean toggleHover = mouseX >= toggleX && mouseX <= toggleX + toggleW &&
                          mouseY >= sy && mouseY <= sy + toggleH;
    
    fill(toggleState ? color(50, 150, 50) : color(150, 150, 150));
    if (toggleHover && !toggleState) fill(color(170, 170, 170));
    noStroke();
    rect(toggleX, sy, toggleW, toggleH, 4);
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11);
    text(toggleState ? "ON" : "OFF", toggleX + toggleW/2, sy + toggleH/2);
    
    // Handle toggle click (stored for mousePressed event handler)
    // Click detection moved to mousePressed() to avoid continuous triggering
    
    // Check if texture is loaded
    PImage lidImg = isTop ? lidImgTop : lidImgBot;
    boolean hasTexture = lidImg != null;
    
    // Combined Upload/Edit button (full width)
    float uploadX = toggleX + toggleW + 11;
    float buttonW = areaWidth - (uploadX - sx);
    float uploadH = 26;
    boolean uploadHover = mouseX >= uploadX && mouseX <= uploadX + buttonW &&
                          mouseY >= sy && mouseY <= sy + uploadH;
    
    fill(uploadHover ? color(120, 120, 130) : color(100, 100, 110));
    rect(uploadX, sy, buttonW, uploadH, 4);
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(10);
    text(hasTexture ? "Edit" : "Upload", uploadX + buttonW/2, sy + uploadH/2);
    
    // Show image info if loaded
    if (lidImg != null) {
      fill(80);
      textSize(9);
      text(lidImg.width + "x" + lidImg.height, uploadX + (areaWidth - (uploadX - sx))/2, sy + uploadH + 10);
    }
    
    // Handle upload/edit click (stored for mousePressed event handler)
    // Click detection moved to mousePressed() to avoid continuous triggering
    
    popStyle();
  }
  
  // Helper function to draw a custom toggle
  void drawCustomToggle(float sx, float sy, String label, boolean state, String id) {
    pushStyle();
    
    // Label
    fill(60);
    textAlign(LEFT, CENTER);
    textSize(11);
    text(label, sx, sy + 15);
    
    // Toggle button
    float toggleX = sx + w - SIDEBAR_PADDING - 65; // Right-aligned
    float toggleW = 55;
    float toggleH = 26;
    boolean toggleHover = mouseX >= toggleX && mouseX <= toggleX + toggleW &&
                          mouseY >= sy && mouseY <= sy + toggleH;
    
    fill(state ? color(50, 150, 50) : color(150, 150, 150));
    if (toggleHover && !state) fill(color(170, 170, 170));
    noStroke();
    rect(toggleX, sy, toggleW, toggleH, 4);
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11);
    text(state ? "ON" : "OFF", toggleX + toggleW/2, sy + toggleH/2);
    
    popStyle();
  }
  
  // Mouse event handling
  
  boolean mousePressed() {
    // Check if click is within sidebar area
    if (mouseX < x || mouseX > x + w || mouseY < y || mouseY > y + h) {
      return false;
    }
    
    // Check main tab buttons
    for (SidebarButton tab : mainTabs) {
      if (tab.isMouseOver()) {
        handleMainTabClick(tab.id);
        return true;
      }
    }
    
    // Check Add / Remove shape buttons and Reset to Default on Shape tab
    if (activeMainTab == 0) {
      float ctrBtnSize = 26;
      float ctrBtnGap  = 6;
      float ctrY       = contentY + SIDEBAR_PADDING + 20;

      // "+ Add" button (left-anchored)
      float addBtnX = x + SIDEBAR_PADDING;
      if (mouseX >= addBtnX && mouseX <= addBtnX + ctrBtnSize + ctrBtnGap + 10 &&
          mouseY >= ctrY     && mouseY <= ctrY + ctrBtnSize) {
        addShape();
        return true;
      }
      // "- Remove" button
      float remBtnX = addBtnX + ctrBtnSize + ctrBtnGap + 10 + 4;
      if (shapes != null && shapes.size() > 1 &&
          mouseX >= remBtnX && mouseX <= remBtnX + ctrBtnSize + ctrBtnGap + 10 &&
          mouseY >= ctrY     && mouseY <= ctrY + ctrBtnSize) {
        removeShape();
        return true;
      }
      // "Reset to Default" button (positioned below the counter row)
      float btnY = ctrY + ctrBtnSize + 6;
      float btnW = w - 2 * SIDEBAR_PADDING;
      float btnH = 28;
      if (mouseX >= x + SIDEBAR_PADDING && mouseX <= x + SIDEBAR_PADDING + btnW &&
          mouseY >= btnY && mouseY <= btnY + btnH) {
        resetShapeToDefault();
        return true;
      }
      // "Load JSON" button (below Reset)
      float jsonBtnY = btnY + btnH + 4;
      if (mouseX >= x + SIDEBAR_PADDING && mouseX <= x + SIDEBAR_PADDING + btnW &&
          mouseY >= jsonBtnY && mouseY <= jsonBtnY + btnH) {
        loadJSONShapes();
        return true;
      }
      // TAB LENGTH preset buttons (5 / 10 / 15 mm) — must match drawTabLengthButtons()
      float tlBtnY = tabLengthRowY() + 18;
      float tlBtnH = 26;
      float tlGap  = 6;
      float tlBtnW = (w - 2 * SIDEBAR_PADDING - 2 * tlGap) / 3;
      for (int i = 0; i < TAB_LEN_PRESETS.length; i++) {
        float bx = x + SIDEBAR_PADDING + i * (tlBtnW + tlGap);
        if (mouseX >= bx && mouseX <= bx + tlBtnW &&
            mouseY >= tlBtnY && mouseY <= tlBtnY + tlBtnH) {
          tabDepth = TAB_LEN_PRESETS[i];
          if (sTabDepth != null) sTabDepth.setValue(tabDepth);  // keep hidden slider in sync
          setParams(false);
          if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
          redraw();
          return true;
        }
      }

      // Kresling haptic selector buttons — must match drawKreslingHapticUI()
      if (kreslingMode) {
        float khX0 = x + SIDEBAR_PADDING;
        float khFullW = w - 2 * SIDEBAR_PADDING;
        float khUiY = kreslingHapticUIY();
        float khBtnH = 24, khGap = 5;
        float khBtnY = khUiY + 16;
        float khBW = (khFullW - 2 * khGap) / 3;
        for (int i = 0; i < 3; i++) {
          float bx = khX0 + i * (khBW + khGap);
          if (mouseX >= bx && mouseX <= bx + khBW && mouseY >= khBtnY && mouseY <= khBtnY + khBtnH) {
            kreslingTargetType = i;
            redraw();
            return true;
          }
        }
        float khGenY = khBtnY + khBtnH + 8;
        float khGW = (khFullW - khGap) / 2;
        if (mouseX >= khX0 && mouseX <= khX0 + khGW && mouseY >= khGenY && mouseY <= khGenY + khBtnH) {
          kreslingGenerateAndApply();   // Generate
          return true;
        }
        float khRx = khX0 + khGW + khGap;
        if (mouseX >= khRx && mouseX <= khRx + khGW && mouseY >= khGenY && mouseY <= khGenY + khBtnH) {
          kreslingCheckCurrent();   // Check current settings (no change)
          return true;
        }
      }
    }
    
    // Check print sub-tab buttons and page size buttons (Print tab)
    if (activeMainTab == 2) {
      // Print sub-tab buttons
      float ptSx = x + SIDEBAR_PADDING;
      float ptSy = contentY + SIDEBAR_PADDING;
      float ptTabWidth = (w - 4 * SIDEBAR_PADDING) / 3;
      float ptTabHeight = 31;
      for (int i = 0; i < 3; i++) {
        float tx = ptSx + i * (ptTabWidth + SIDEBAR_PADDING/2);
        if (mouseX >= tx && mouseX <= tx + ptTabWidth &&
            mouseY >= ptSy && mouseY <= ptSy + ptTabHeight) {
          activePrintTab = i;
          updateSidebarControlsVisibility();
          redraw();
          return true;
        }
      }
      
      // Page size buttons (only on Placement sub-tab; hidden in workshop mode)
      if (activePrintTab == 0 && !workshopMode) {
        float psSy = contentY + SIDEBAR_PADDING + ptTabHeight + 12 + 22;  // after sub-tabs + gap + label
        float psBtnW = (w - 2 * SIDEBAR_PADDING - 3 * 6) / 4;
        float psBtnH = 30;
        float psSx = x + SIDEBAR_PADDING;
        for (int i = 0; i < PAGE_SIZE_NAMES.length; i++) {
          float bx = psSx + i * (psBtnW + 6);
          if (mouseX >= bx && mouseX <= bx + psBtnW &&
              mouseY >= psSy && mouseY <= psSy + psBtnH) {
            applyPageSize(i);
            return true;
          }
        }
      }
      // Check cutout controls (only on Cutouts sub-tab)
      if (activePrintTab == 1) {
        if (handleCutoutControlClick()) {
          return true;
        }
      }
    }

    // Assembly tab click handling
    if (activeMainTab == 3) {
      if (activeAssembly == null) return true;
      float sx      = x + SIDEBAR_PADDING;
      float availW2 = w - 2 * SIDEBAR_PADDING;
      float sy      = contentY + SIDEBAR_PADDING;
      final int ROW_H = 28;
      final int BTN   = 22;
      int shapeCount2 = (shapes != null) ? shapes.size() : 0;

      // ---- Section 1: SHAPE PALETTE ----
      sy += 18; // title
      if (shapeCount2 == 0) {
        sy += 36;
      } else {
        int maxVisible2 = min(shapeCount2, 5);
        float listY2 = sy;
        for (int i = 0; i < maxVisible2; i++) {
          float rowY = listY2 + i * ROW_H;
          if (mouseX >= sx && mouseX <= sx + availW2 &&
              mouseY >= rowY && mouseY <= rowY + ROW_H) {
            activeAssembly.paintShapeIdx = i;
            activeAssembly.cellSizeMM = shapes.get(i).uiTopW;
            return true;
          }
        }
        sy = listY2 + maxVisible2 * ROW_H + 4;
        // Erase row
        if (mouseX >= sx && mouseX <= sx + availW2 &&
            mouseY >= sy && mouseY <= sy + ROW_H - 2) {
          activeAssembly.paintShapeIdx = -1;
          return true;
        }
        sy += ROW_H + 4;
      }

      // ---- Divider + Section 2: GRID ----
      sy += 12 + 18; // divider + title

      // W/H +/-
      float bxW = sx + 18;
      if (mouseX >= bxW && mouseX <= bxW + BTN && mouseY >= sy && mouseY <= sy + BTN) {
        activeAssembly.resizeGrid(max(1, activeAssembly.gridW - 1), activeAssembly.gridH); return true;
      }
      float pxW = bxW + BTN + 28;
      if (mouseX >= pxW && mouseX <= pxW + BTN && mouseY >= sy && mouseY <= sy + BTN) {
        activeAssembly.resizeGrid(min(16, activeAssembly.gridW + 1), activeAssembly.gridH); return true;
      }
      float hStart = sx + 110;
      float bxH = hStart + 18;
      if (mouseX >= bxH && mouseX <= bxH + BTN && mouseY >= sy && mouseY <= sy + BTN) {
        activeAssembly.resizeGrid(activeAssembly.gridW, max(1, activeAssembly.gridH - 1)); return true;
      }
      float pxH = bxH + BTN + 28;
      if (mouseX >= pxH && mouseX <= pxH + BTN && mouseY >= sy && mouseY <= sy + BTN) {
        activeAssembly.resizeGrid(activeAssembly.gridW, min(16, activeAssembly.gridH + 1)); return true;
      }
      sy += 30;

      // Grid cells
      int dispCols = min(activeAssembly.gridW, 12);
      int dispRows = min(activeAssembly.gridH, 8);
      float cellPx = min(30.0, (availW2 - (dispCols - 1) * 2.0) / dispCols);
      for (int r = 0; r < dispRows; r++) {
        for (int c = 0; c < dispCols; c++) {
          float cellX = sx + c * (cellPx + 2);
          float cellY = sy + r * (cellPx + 2);
          if (mouseX >= cellX && mouseX <= cellX + cellPx &&
              mouseY >= cellY && mouseY <= cellY + cellPx) {
            int cur = activeAssembly.shapeGrid[r][c];
            if (activeAssembly.paintShapeIdx < 0) {
              activeAssembly.shapeGrid[r][c] = -1;
            } else {
              activeAssembly.shapeGrid[r][c] =
                (cur == activeAssembly.paintShapeIdx) ? -1 : activeAssembly.paintShapeIdx;
            }
            // Sync cellSizeMM from paint shape if not yet set
            if (activeAssembly.paintShapeIdx >= 0 && shapes != null &&
                activeAssembly.paintShapeIdx < shapes.size())
              activeAssembly.cellSizeMM = shapes.get(activeAssembly.paintShapeIdx).uiTopW;
            return true;
          }
        }
      }
      sy += dispRows * (cellPx + 2) + 6;

      // Clear / Fill buttons
      float btnW = (availW2 - 6) / 2;
      float btnH = 26;
      if (mouseX >= sx && mouseX <= sx + btnW && mouseY >= sy && mouseY <= sy + btnH) {
        activeAssembly.clearAll(); return true;
      }
      float fillBtnX = sx + btnW + 6;
      if (mouseX >= fillBtnX && mouseX <= fillBtnX + btnW &&
          mouseY >= sy && mouseY <= sy + btnH) {
        activeAssembly.fillAll(); return true;
      }
      sy += btnH + 8;

      // ---- Divider + Section 3: VIEW ----
      sy += 12 + 18; // divider + title
      float viewBtnW = (availW2 - 6) / 2;
      float viewBtnH = 30;
      if (mouseX >= sx && mouseX <= sx + viewBtnW &&
          mouseY >= sy && mouseY <= sy + viewBtnH) {
        assemblyShowTemplate = false;
        view3DMode = true;
        return true;
      }
      float tplBtnX = sx + viewBtnW + 6;
      if (mouseX >= tplBtnX && mouseX <= tplBtnX + viewBtnW &&
          mouseY >= sy && mouseY <= sy + viewBtnH) {
        assemblyShowTemplate = true;
        view3DMode = false;
        return true;
      }
      sy += viewBtnH + 6;

      // True Colour toggle
      float tcBtnH = 26;
      if (mouseX >= sx && mouseX <= sx + availW2 &&
          mouseY >= sy && mouseY <= sy + tcBtnH) {
        assemblyTrueColor = !assemblyTrueColor;
        return true;
      }

      return true; // consume all assembly tab clicks
    }

    // Only check content buttons if in texture tab
    if (activeMainTab != 1) {
      return false;
    }
    
    // Check texture sub-tab buttons
    for (SidebarButton btn : buttons) {
      if (btn.isMouseOver() && btn.enabled) {
        handleTextureTabClick(btn.id);
        return true;
      }
    }
    
    // Check solid-fill swatch row
    {
      final int SW_SIZE = 22;
      final int SW_GAP  = 4;
      float swRowY = contentY + SIDEBAR_PADDING + 16;
      if (mouseY >= swRowY && mouseY <= swRowY + SW_SIZE) {
        for (int _i = 0; _i < 9; _i++) {
          float swX = x + SIDEBAR_PADDING + _i * (SW_SIZE + SW_GAP);
          if (mouseX >= swX && mouseX <= swX + SW_SIZE) {
            ShapeSpec _sel = (shapes != null && shapes.size() > 0) ? shapes.get(selectedShapeIdx) : null;
            if (_sel != null) {
              if (_i == 8) {
                // "none" swatch — clear fill
                _sel.fillColorEnabled = false;
                fillColorEnabled = false;
              } else {
                _sel.shapeColor    = SWATCH_PALETTE[_i];
                _sel.fillColorEnabled = true;
                shapeColor        = SWATCH_PALETTE[_i];
                fillColorEnabled  = true;
              }
              saveGlobalsTo(_sel);
              redraw();
            }
            return true;
          }
        }
      }
    }
    
    // Check texture upload area buttons (per-panel and strip)
    float sx = x + SIDEBAR_PADDING;
    float sy = contentY + SIDEBAR_PADDING + 116; // Must match drawTextureUploadArea()
    float areaWidth = w - 2 * SIDEBAR_PADDING;
    
    // Check per-panel toggle and upload buttons for each panel
    if (activeTextureTab == 0) {
      // Check Restore to Default button
      float restoreBtnWidth = areaWidth - 10;
      float restoreBtnHeight = 28;
      float restoreBtnX = sx + 5;
      float restoreBtnY = sy + 30;
      if (mouseX >= restoreBtnX && mouseX <= restoreBtnX + restoreBtnWidth &&
          mouseY >= restoreBtnY && mouseY <= restoreBtnY + restoreBtnHeight) {
        restorePerPanelTexturesToDefault();
        return true;
      }
      
      int numPanels = max(3, nSides);
      float rowHeight = 35;
      float labelWidth = 72;
      float toggleW = 50;
      float toggleH = 24;
      float spacing = 7;
      
      for (int i = 0; i < numPanels; i++) {
        float controlY = sy + 30 + restoreBtnHeight + 10 + i * rowHeight; // Offset for restore button
        float toggleX = sx + labelWidth;
        
        // Check toggle for this panel
        if (mouseX >= toggleX && mouseX <= toggleX + toggleW &&
            mouseY >= controlY && mouseY <= controlY + toggleH) {
          perPanelEnabled[i] = !perPanelEnabled[i];
          saveGlobalsTo(shapes != null && shapes.size() > 0 ? shapes.get(selectedShapeIdx) : null);
          return true;
        }
        
        // Check combined upload/edit button for this panel
        float uploadX = toggleX + toggleW + spacing;
        float buttonW = areaWidth - (uploadX - sx);
        if (mouseX >= uploadX && mouseX <= uploadX + buttonW &&
            mouseY >= controlY && mouseY <= controlY + toggleH) {
          boolean hasTexture = panelTextures != null && i < panelTextures.length && panelTextures[i] != null;
          if (hasTexture) {
            editPanelTexture(i);
          } else {
            selectPanelTexture(i);
          }
          return true;
        }
      }
    }
    
    // Check strip upload and edit buttons
    if (activeTextureTab == 1) {
      float bx = sx + SIDEBAR_PADDING;
      float by = sy + 50;
      float btnWidth = (areaWidth - 2 * SIDEBAR_PADDING - 7) / 2;
      float btnHeight = 44;
      float spacing = 7;
      
      // Check Restore to Default button
      float restoreBtnWidth = areaWidth - 2 * SIDEBAR_PADDING;
      float restoreBtnHeight = 28;
      float restoreBtnX = bx;
      float restoreBtnY = by;
      if (mouseX >= restoreBtnX && mouseX <= restoreBtnX + restoreBtnWidth &&
          mouseY >= restoreBtnY && mouseY <= restoreBtnY + restoreBtnHeight) {
        restoreStripTextureToDefault();
        return true;
      }
      
      // Adjust Y for upload/edit button
      by += restoreBtnHeight + 10;
      
      // Combined Upload/Edit button
      float fullBtnWidth = areaWidth - 2 * SIDEBAR_PADDING;
      if (mouseX >= bx && mouseX <= bx + fullBtnWidth &&
          mouseY >= by && mouseY <= by + btnHeight) {
        boolean hasStripTexture = stripImg != null;
        if (hasStripTexture) {
          editStripTexture();
        } else {
          selectStripTexture();
        }
        return true;
      }
    }
    
    // Check texture bleed toggle
    {
      float bleedSy = contentY + contentHeight - 145;
      float bleedToggleW = 55;
      float bleedToggleH = 24;
      float bleedToggleX = x + SIDEBAR_PADDING;
      if (mouseX >= bleedToggleX && mouseX <= bleedToggleX + bleedToggleW &&
          mouseY >= bleedSy && mouseY <= bleedSy + bleedToggleH) {
        textureBleed = !textureBleed;
        saveGlobalsTo(shapes != null && shapes.size() > 0 ? shapes.get(selectedShapeIdx) : null);
        return true;
      }
    }
    
    // Check lid texture controls
    if (checkLidTextureClick()) return true;
    
    return true; // Consumed the click (within sidebar bounds)
  }
  
  boolean checkLidTextureClick() {
    float sx = x + SIDEBAR_PADDING;
    float sy = contentY + contentHeight - 110; // Match drawLidTextureControls()
    float areaWidth = w - 2 * SIDEBAR_PADDING;
    
    sy += 25; // Account for header spacing (matches drawLidTextureControls)
    sx += 5; // Account for padding (matches drawLidRow)
    
    // Top lid toggle
    float toggleX = sx + 77;
    float toggleW = 55;
    float toggleH = 26;
    if (mouseX >= toggleX && mouseX <= toggleX + toggleW &&
        mouseY >= sy && mouseY <= sy + toggleH) {
      topLidEnabled = !topLidEnabled;
      saveGlobalsTo(shapes != null && shapes.size() > 0 ? shapes.get(selectedShapeIdx) : null);
      return true;
    }
    
    // Top lid upload and edit buttons
    float uploadX = toggleX + toggleW + 11;
    float buttonW = areaWidth - 10 - (uploadX - sx);
    
    // Top lid combined upload/edit button
    if (mouseX >= uploadX && mouseX <= uploadX + buttonW &&
        mouseY >= sy && mouseY <= sy + toggleH) {
      boolean hasTexture = lidImgTop != null;
      if (hasTexture) {
        editLidTexture(true);
      } else {
        selectLidTexture(true);
      }
      return true;
    }
    
    sy += 35; // Move to bottom lid row (matches drawLidTextureControls)
    
    // Bottom lid toggle
    if (mouseX >= toggleX && mouseX <= toggleX + toggleW &&
        mouseY >= sy && mouseY <= sy + toggleH) {
      bottomLidEnabled = !bottomLidEnabled;
      saveGlobalsTo(shapes != null && shapes.size() > 0 ? shapes.get(selectedShapeIdx) : null);
      return true;
    }
    
    // Bottom lid combined upload/edit button
    if (mouseX >= uploadX && mouseX <= uploadX + buttonW &&
        mouseY >= sy && mouseY <= sy + toggleH) {
      boolean hasTexture = lidImgBot != null;
      if (hasTexture) {
        editLidTexture(false);
      } else {
        selectLidTexture(false);
      }
      return true;
    }
    return false;
  }
  
  void mouseMoved() {
    // Update main tab hover states
    for (SidebarButton tab : mainTabs) {
      tab.hover = tab.isMouseOver();
    }
    
    // Update button hover states
    for (SidebarButton btn : buttons) {
      btn.hover = btn.isMouseOver() && btn.enabled;
    }
  }
  
  void handleMainTabClick(String id) {
    if (id.startsWith("main_tab_")) {
      int tabIndex = int(id.charAt(9)) - '0';
      activeMainTab = tabIndex;
      
      // Update main tab button states
      for (SidebarButton tab : mainTabs) {
        if (tab.id.startsWith("main_tab_")) {
          int btnIndex = int(tab.id.charAt(9)) - '0';
          tab.setActive(btnIndex == activeMainTab);
        }
      }
      
      // Update control visibility based on active tab
      updateSidebarControlsVisibility();
      
      redraw();
    }
  }
  
  void handleTextureTabClick(String id) {
    // Texture sub-tab selection
    if (id.startsWith("texture_tab_")) {
      int tabIndex = int(id.charAt(12)) - '0';
      activeTextureTab = tabIndex;
      
      // Map tab index to texture mode constant
      // Tab 0 = Per-Panel (TEX_PER_PANEL = 1)
      // Tab 1 = Strip (TEX_STRIP_BENT = 2)
      if (tabIndex == 0) {
        sideTextureMode = TEX_PER_PANEL;
        uiTextureMode = 1;
      } else if (tabIndex == 1) {
        sideTextureMode = TEX_STRIP_BENT;
        uiTextureMode = 2;
      }
      
      // Update tab button states
      for (SidebarButton btn : buttons) {
        if (btn.id.startsWith("texture_tab_")) {
          int btnIndex = int(btn.id.charAt(12)) - '0';
          btn.setActive(btnIndex == activeTextureTab);
        }
      }
      
      // Sync with UI slider if it exists
      if (sTextureMode != null) {
        sTextureMode.setValue(uiTextureMode);
      }
      
      // Persist the change so loadGlobalsFrom() doesn't revert it next frame
      saveGlobalsTo(shapes != null && shapes.size() > 0 ? shapes.get(selectedShapeIdx) : null);
      
      redraw();
      return;
    }
  }
  
  // Restore per-panel textures to default (clear all)
  void restorePerPanelTexturesToDefault() {
    int numPanels = max(3, nSides);
    
    // Clear all panel textures
    if (panelTextures != null) {
      for (int i = 0; i < panelTextures.length; i++) {
        panelTextures[i] = null;
      }
    }
    
    // Reset all toggles to ON (default state)
    if (perPanelEnabled == null || perPanelEnabled.length != numPanels) {
      perPanelEnabled = new boolean[numPanels];
    }
    for (int i = 0; i < numPanels; i++) {
      perPanelEnabled[i] = false;
    }
    
    println("[Sidebar] Per-panel textures restored to default");
  }
  
  // Restore strip texture to default (clear)
  void restoreStripTextureToDefault() {
    setStripSource(null, true);
    println("[Sidebar] Strip texture restored to default");
  }
  
  void update() {
    // Sync sidebar state with global variables
    // Map texture mode constant to tab index
    // TEX_PER_PANEL (1) -> Tab 0
    // TEX_STRIP_BENT (2) -> Tab 1
    if (sideTextureMode == TEX_PER_PANEL) {
      activeTextureTab = 0;
    } else if (sideTextureMode == TEX_STRIP_BENT) {
      activeTextureTab = 1;
    }
    
    // Don't override local lid enabled states - they control independently
    uiShowLidTextures = topLidEnabled || bottomLidEnabled;
    
    // Update tab button states
    for (SidebarButton btn : buttons) {
      if (btn.id.startsWith("texture_tab_")) {
        int btnIndex = int(btn.id.charAt(12)) - '0';
        btn.setActive(btnIndex == activeTextureTab);
      }
    }
  }
  
  void resetShapeToDefault() {
    // Reset shape parameters to default values (30mm circumscribed diameter)
    if (sTopSize != null) sTopSize.setValue(30);
    if (sBotSize != null) sBotSize.setValue(30);
    if (sSideLen != null) sSideLen.setValue(30);
    
    // Update UI variables (diameter values)
    uiTopW = 30;
    uiBotW = 30;
    uiHeight = 30;
    
    applyToModel(); // writes cylinder + calls setParams + saveGlobalsTo selected shape
    println("[Sidebar] Shape reset to default: 30mm diameter x 30mm diameter x 30mm height");
  }
}

// Global sidebar instance
SidebarPanel sidebar;

// TEXTURE FILE SELECTION CALLBACKS
// Functions called when user selects texture files

// Texture upload callbacks
void selectPanelTexture(int panelIndex) {
  // Store the panel index globally so callback can access it
  currentPanelUploadIndex = panelIndex;
  selectInput("Select texture for panel " + (panelIndex + 1), "panelTextureSelected");
}

void panelTextureSelected(File selection) {
  int panelIndex = currentPanelUploadIndex;
  
  println("[Sidebar] panelTextureSelected callback triggered for panel " + (panelIndex + 1));
  
  if (selection == null) {
    println("[Sidebar] Panel " + (panelIndex + 1) + " texture selection cancelled");
    return;
  }
  
  println("[Sidebar] Loading texture for panel " + (panelIndex + 1) + ": " + selection.getAbsolutePath());
  PImage panelImg = loadImage(selection.getAbsolutePath());
  
  if (panelImg == null) {
    println("[Sidebar] ERROR: Failed to load texture for panel " + (panelIndex + 1));
    return;
  }
  
  println("[Sidebar] SUCCESS: Panel " + (panelIndex + 1) + " texture loaded: " + panelImg.width + "x" + panelImg.height + " px");
  
  // Ensure arrays are sized correctly
  int numPanels = max(3, nSides);
  if (panelTextures == null) {
    panelTextures = new PImage[numPanels];
  } else if (panelTextures.length != numPanels) {
    PImage[] newArray = new PImage[numPanels];
    for (int i = 0; i < min(panelTextures.length, numPanels); i++) {
      newArray[i] = panelTextures[i];
    }
    panelTextures = newArray;
  }
  
  // Store texture for this specific panel
  panelTextures[panelIndex] = panelImg;
  println("[Sidebar] Stored texture in panelTextures[" + panelIndex + "] = " + (panelTextures[panelIndex] != null ? "SUCCESS" : "FAILED"));
  println("[Sidebar] New texture dimensions: " + panelImg.width + "x" + panelImg.height);
  println("[Sidebar] panelTextures array length: " + panelTextures.length);
  
  // Persist to selected ShapeSpec
  if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
    shapes.get(selectedShapeIdx).panelTextures = panelTextures;
  }
  
  // Enable toggle for this panel
  if (sidebar != null && sidebar.perPanelEnabled != null && panelIndex < sidebar.perPanelEnabled.length) {
    sidebar.perPanelEnabled[panelIndex] = true;
    println("[Sidebar] Enabled toggle for panel " + (panelIndex + 1));
  }
  
  // Switch to per-panel mode
  sideTextureMode = TEX_PER_PANEL;
  uiTextureMode = TEX_PER_PANEL;
  if (sidebar != null) {
    sidebar.activeTextureTab = 0;
  }
  if (sTextureMode != null) {
    sTextureMode.setValue(TEX_PER_PANEL);
  }
  
  // Persist mode and toggle state so loadGlobalsFrom() doesn't revert it
  saveGlobalsTo(shapes != null && shapes.size() > 0 ? shapes.get(selectedShapeIdx) : null);
  
  println("[Sidebar] Mode: sideTextureMode=" + sideTextureMode + " (TEX_PER_PANEL=" + TEX_PER_PANEL + ")");
  println("[Sidebar] panelTextures array length: " + (panelTextures != null ? panelTextures.length : "NULL"));
  println("[Sidebar] Panel " + (panelIndex + 1) + " texture enabled, triggering redraw");
  
  // If cropper was active (uploading from within editor), reopen it with the new image
  if (cropperActive && imageCropper.cropperMode == CROP_MODE_PANEL && imageCropper.cropperPanelIndex == panelIndex) {
    println("[Sidebar] Reopening cropper with new image");
    imageCropper.open(CROP_MODE_PANEL, panelIndex, panelImg);
  }
  
  redraw();
  loop(); // Force continuous rendering
}

void selectStripTexture() {
  println("[Sidebar] Upload strip texture");
  selectInput("Select strip texture image", "stripTextureSelected");
}

void stripTextureSelected(File selection) {
  if (selection == null) {
    println("[Sidebar] Strip texture selection cancelled");
  } else {
    println("[Sidebar] Strip texture: " + selection.getAbsolutePath());
    setStripSource(loadImage(selection.getAbsolutePath()), true);
    if (stripImg != null) {
      println("[Sidebar] Strip texture loaded: " + stripImg.width + "x" + stripImg.height);
      // Switch to strip mode and persist everything
      sideTextureMode = TEX_STRIP_BENT;
      uiTextureMode = TEX_STRIP_BENT;
      if (sTextureMode != null) sTextureMode.setValue(TEX_STRIP_BENT);
      // Persist to selected ShapeSpec
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
        shapes.get(selectedShapeIdx).stripImg = stripImg;
      }
      saveGlobalsTo(shapes != null && shapes.size() > 0 ? shapes.get(selectedShapeIdx) : null);
      // Open cropper so user can select the region to use
      originalStripImg = stripImg.get();
      imageCropper.open(CROP_MODE_STRIP, -1, stripImg);
    }
    redraw();
  }
}

void selectLidTexture(boolean isTop) {
  println("[Sidebar] Upload " + (isTop ? "top" : "bottom") + " lid texture");
  if (isTop) {
    selectInput("Select top lid texture", "topLidTextureSelected");
  } else {
    selectInput("Select bottom lid texture", "bottomLidTextureSelected");
  }
}

void topLidTextureSelected(File selection) {
  if (selection == null) {
    println("[Sidebar] Top lid texture selection cancelled");
  } else {
    println("[Sidebar] Top lid texture: " + selection.getAbsolutePath());
    lidImgTop = loadImage(selection.getAbsolutePath());
    if (lidImgTop != null) {
      println("[Sidebar] Top lid texture loaded: " + lidImgTop.width + "x" + lidImgTop.height);
      sidebar.topLidEnabled = true;
      uiShowLidTextures = true;
      if (tShowLidTextures != null) tShowLidTextures.setValue(1);
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
        shapes.get(selectedShapeIdx).lidImgTop      = lidImgTop;
        shapes.get(selectedShapeIdx).topLidEnabled  = true;
      }
      
      // If cropper was active (uploading from within editor), reopen it with the new image
      if (cropperActive && imageCropper.cropperMode == CROP_MODE_LID && imageCropper.cropperPanelIndex == 0) {
        println("[Sidebar] Reopening cropper with new image");
        imageCropper.open(CROP_MODE_LID, 0, lidImgTop);
      }
    }
    redraw();
  }
}

void bottomLidTextureSelected(File selection) {
  if (selection == null) {
    println("[Sidebar] Bottom lid texture selection cancelled");
  } else {
    println("[Sidebar] Bottom lid texture: " + selection.getAbsolutePath());
    lidImgBot = loadImage(selection.getAbsolutePath());
    if (lidImgBot != null) {
      println("[Sidebar] Bottom lid texture loaded: " + lidImgBot.width + "x" + lidImgBot.height);
      sidebar.bottomLidEnabled = true;
      uiShowLidTextures = true;
      if (tShowLidTextures != null) tShowLidTextures.setValue(1);
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
        shapes.get(selectedShapeIdx).lidImgBot         = lidImgBot;
        shapes.get(selectedShapeIdx).bottomLidEnabled  = true;
      }
      
      // If cropper was active (uploading from within editor), reopen it with the new image
      if (cropperActive && imageCropper.cropperMode == CROP_MODE_LID && imageCropper.cropperPanelIndex == 1) {
        println("[Sidebar] Reopening cropper with new image");
        imageCropper.open(CROP_MODE_LID, 1, lidImgBot);
      }
    }
    redraw();
  }
}


// TEXTURE EDITING FUNCTIONS
// Open image cropper for editing loaded textures

// Edit texture functions (open cropper)
void editPanelTexture(int panelIndex) {
  if (panelTextures == null || panelIndex < 0 || panelIndex >= panelTextures.length || panelTextures[panelIndex] == null) {
    println("[Sidebar] Cannot edit panel " + (panelIndex + 1) + " - no texture loaded");
    return;
  }
  
  println("[Sidebar] Edit panel " + (panelIndex + 1) + " texture");
  
  // Store original texture if not already stored
  if (originalPanelTextures == null) {
    originalPanelTextures = new PImage[panelTextures.length];
  } else if (originalPanelTextures.length != panelTextures.length) {
    PImage[] newArray = new PImage[panelTextures.length];
    for (int i = 0; i < min(originalPanelTextures.length, panelTextures.length); i++) {
      newArray[i] = originalPanelTextures[i];
    }
    originalPanelTextures = newArray;
  }
  
  if (originalPanelTextures[panelIndex] == null) {
    originalPanelTextures[panelIndex] = panelTextures[panelIndex].get();
  }
  
  // Open cropper
  imageCropper.open(CROP_MODE_PANEL, panelIndex, panelTextures[panelIndex]);
}

void editStripTexture() {
  if (stripImg == null) {
    println("[Sidebar] Cannot edit strip texture - no texture loaded");
    return;
  }
  
  println("[Sidebar] Edit strip texture");
  
  // Store original texture if not already stored
  if (originalStripImg == null) {
    originalStripImg = stripImg.get();
  }
  
  // Open cropper
  imageCropper.open(CROP_MODE_STRIP, -1, stripImg);
}

void editLidTexture(boolean isTop) {
  PImage lidImg = isTop ? lidImgTop : lidImgBot;
  
  if (lidImg == null) {
    println("[Sidebar] Cannot edit " + (isTop ? "top" : "bottom") + " lid texture - no texture loaded");
    return;
  }
  
  println("[Sidebar] Edit " + (isTop ? "top" : "bottom") + " lid texture");
  
  // Store original texture if not already stored
  if (isTop) {
    if (originalLidImgTop == null) {
      originalLidImgTop = lidImgTop.get();
    }
  } else {
    if (originalLidImgBot == null) {
      originalLidImgBot = lidImgBot.get();
    }
  }
  
  // Open cropper (0 for top, 1 for bottom)
  imageCropper.open(CROP_MODE_LID, isTop ? 0 : 1, lidImg);
}
