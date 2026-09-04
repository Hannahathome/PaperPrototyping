//----------------------------------------------------------------------
// Top Toolbar UI - Quick access to modes, actions, and settings
// Created: 2025-12-01
//----------------------------------------------------------------------

class ToolbarButton {
  float x, y, w, h;
  String label;
  String id;
  boolean active, hover, enabled;
  color colorNormal, colorActive, colorHover, colorDisabled;
  int iconType;  // 0=none, 1=lock, 2=eye, 3=export, etc.
  
  ToolbarButton(String _id, float _x, float _y, float _w, float _h, String _label) {
    id = _id;
    x = _x;
    y = _y;
    w = _w;
    h = _h;
    label = _label;
    active = false;
    hover = false;
    enabled = true;
    iconType = 0;
    
    // Default colors (set by toolbar)
    colorNormal = color(100, 100, 110);
    colorActive = color(50, 150, 255);
    colorHover = color(120, 120, 130);
    colorDisabled = color(80, 80, 80);
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
    rect(x, y, w, h, 4);  // Rounded corners
    
    // Draw border for active state
    if (active) {
      stroke(255, 255, 255, 100);
      strokeWeight(2);
      noFill();
      rect(x, y, w, h, 4);
    }
    
    // Draw label
    fill(enabled ? 255 : 150);
    textAlign(CENTER, CENTER);
    uiText(12);
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
}

//======================================================================

class Toolbar {
  ArrayList<ToolbarButton> buttons;
  int height;
  color bgColor;
  color btnNormal, btnActive, btnHover;
  float separatorX1, separatorX2, separatorX3;
  
  // Dropdown menu state
  boolean dropdownOpen = false;
  ToolbarButton dimensionsBtn;
  float dropdownWidth = 280;  // Wide enough for all content
  float dropdownX = 0, dropdownY = 0;
  float dropdownBoxHeight = 0;  // Store for hit detection
  
  Toolbar() {
    buttons = new ArrayList<ToolbarButton>();
    height = TOOLBAR_HEIGHT;
    bgColor = color(30, 40, 80);  // Dark blue
    btnNormal = color(100, 100, 110);
    btnActive = color(50, 150, 255);
    btnHover = color(120, 120, 130);
  }
  
  void setup() {
    // Clear any existing buttons
    buttons.clear();
    
    // Calculate vertical center for buttons
    float btnY = (height - TOOLBAR_BTN_HEIGHT) / 2;
    float x = TOOLBAR_PADDING;
    
    // ===== WORKSHOP MODE BUTTON (LEFT SIDE, before Assembly) =====
    ToolbarButton workshopBtn = new ToolbarButton(
      "workshop_mode",
      x, btnY,
      TOOLBAR_BTN_WIDTH + 10,
      TOOLBAR_BTN_HEIGHT,
      workshopMode ? "Workshop ✓" : "Workshop"
    );
    workshopBtn.colorNormal  = color(160, 110, 40);
    workshopBtn.colorHover   = color(185, 130, 55);
    workshopBtn.colorActive  = color(210, 150, 60);
    workshopBtn.setActive(workshopMode);
    buttons.add(workshopBtn);

    x += TOOLBAR_BTN_WIDTH + 10 + TOOLBAR_SEPARATOR;

    // ===== ASSEMBLY MODE BUTTON (LEFT SIDE) =====
    // Hidden while in workshop mode
    if (!workshopMode) {
      ToolbarButton assemblyBtn = new ToolbarButton(
        "assembly_mode",
        x, btnY,
        TOOLBAR_BTN_WIDTH + 10,
        TOOLBAR_BTN_HEIGHT,
        assemblyMode ? "Assembly ✓" : "Assembly"
      );
      assemblyBtn.colorNormal  = color(110, 60, 160);
      assemblyBtn.colorHover   = color(130, 80, 185);
      assemblyBtn.colorActive  = color(150, 100, 210);
      assemblyBtn.setActive(assemblyMode);
      buttons.add(assemblyBtn);

      x += TOOLBAR_BTN_WIDTH + 10 + TOOLBAR_SEPARATOR;
    }

    // ===== DIMENSIONS INFO DROPDOWN (RIGHT SIDE) =====
    
    // Position dimensions button on right side
    float btnX = width - TOOLBAR_PADDING - (TOOLBAR_BTN_WIDTH + 15);
    
    dimensionsBtn = new ToolbarButton(
      "show_dimensions",
      btnX, btnY,
      TOOLBAR_BTN_WIDTH + 15,
      TOOLBAR_BTN_HEIGHT,
      "ⓘ Info"
    );
    dimensionsBtn.colorNormal = color(100, 130, 100);
    dimensionsBtn.colorHover = color(120, 150, 120);
    dimensionsBtn.colorActive = color(80, 180, 80);
    buttons.add(dimensionsBtn);
    
    println("[TOOLBAR] Setup complete. Info button created at x=" + dimensionsBtn.x + " y=" + dimensionsBtn.y);
    
    /* Buttons commented out for workshop - future reference
    // ===== GROUP 1: MODE CONTROL =====
    ToolbarButton modeBtn = new ToolbarButton(
      "toggle_mode",
      x, btnY,
      TOOLBAR_BTN_WIDTH + 20,
      TOOLBAR_BTN_HEIGHT,
      perEdgeMode ? "Per-Edge" : "Uniform"
    );
    modeBtn.setActive(perEdgeMode);
    buttons.add(modeBtn);
    
    x += TOOLBAR_BTN_WIDTH + 20 + TOOLBAR_SEPARATOR;
    separatorX1 = x - TOOLBAR_SEPARATOR/2;
    
    // ===== GROUP 2: ACTIONS (Texture buttons moved to sidebar) =====
    ToolbarButton exportBtn = new ToolbarButton(
      "export",
      x, btnY,
      TOOLBAR_BTN_WIDTH + 10,
      TOOLBAR_BTN_HEIGHT,
      "Export"
    );
    exportBtn.colorNormal = color(50, 150, 50);
    exportBtn.colorHover = color(60, 180, 60);
    exportBtn.colorActive = color(40, 120, 40);
    buttons.add(exportBtn);
    
    x += TOOLBAR_BTN_WIDTH + 10 + TOOLBAR_SEPARATOR;
    separatorX2 = x - TOOLBAR_SEPARATOR/2;
    */
    
    // Note: View preset buttons moved to bottom bar
  }
  
  void draw() {
    // Skip drawing entirely when cropper is active
    if (cropperActive) return;
    
    pushStyle();
    
    // Draw toolbar background
    fill(bgColor);
    noStroke();
    rect(0, 0, width, height);
    
    // Draw separator lines
    // stroke(100, 100, 110);
    // strokeWeight(1);
    // line(separatorX1, height * 0.2, separatorX1, height * 0.8);
    // line(separatorX2, height * 0.2, separatorX2, height * 0.8);
    
    // Draw bottom border
    stroke(40, 40, 50);
    strokeWeight(2);
    line(0, height, width, height);
    
    // Draw all buttons
    for (ToolbarButton btn : buttons) {
      btn.draw();
    }
    
    // Draw status text (right side)
    drawStatusText();
    
    popStyle();
  }
  
  void drawDropdown() {
    if (!dropdownOpen || dimensionsBtn == null) {
      if (dropdownOpen) {
        println("[TOOLBAR] drawDropdown: dropdownOpen=true but dimensionsBtn is null!");
      }
      return;
    }
    
    // Calculate dimensions info
    float inradiusTop  = calculatePolygonApothem(uiSides, uiTopW);
    float circumradiusTop = calculatePolygonCircumradius(uiSides, uiTopW);
    float inradiusBottom  = calculatePolygonApothem(uiSides, uiBotW);
    float circumradiusBottom = calculatePolygonCircumradius(uiSides, uiBotW);
    
    // Position dropdown to drop DOWN from the button (right-aligned)
    float lineHeight = 14;
    float padding = 12;
    float contentHeight = lineHeight * 11;  // More lines for full info
    dropdownBoxHeight = contentHeight + 2*padding;
    
    // Position: right-aligned to button, drops down from toolbar
    dropdownX = dimensionsBtn.x + dimensionsBtn.w - dropdownWidth;  // Align right edge
    dropdownX = max(10, dropdownX);  // Make sure it doesn't go off left side
    dropdownY = height;  // Start at bottom of toolbar
    
    pushStyle();
    
    // Draw dropdown background (light grey like sidebar) with shadow effect
    fill(0, 0, 0, 20);
    noStroke();
    rect(dropdownX + 1, dropdownY + 1, dropdownWidth, dropdownBoxHeight, 4);  // Shadow
    
    fill(240, 240, 245);
    stroke(100, 100, 110);
    strokeWeight(1);
    rect(dropdownX, dropdownY, dropdownWidth, dropdownBoxHeight, 4);
    
    // Draw text
    fill(0);
    textAlign(LEFT, TOP);
    uiText(9);
    
    float ty = dropdownY + padding;
    float tx = dropdownX + padding;
    
    // Header
    uiText(10);
    fill(40, 70, 120);  // Dark blue
    text("DIMENSIONS", tx, ty);
    ty += lineHeight * 1.3;
    
    // Content - full details
    fill(0);
    uiText(9);
    
    // Top Perimeter
    text("Top Perimeter: " + nf(cylinder.x, 1, 2) + " mm", tx, ty);
    ty += lineHeight;
    
    // Top inscribed radius
    text("Top r_in (inscribed):", tx, ty);
    ty += lineHeight;
    text("  " + nf(inradiusTop, 1, 2) + " mm  (ø " + nf(2*inradiusTop, 1, 2) + ")", tx, ty);
    ty += lineHeight;
    
    // Top circumscribed radius
    text("Top r_out (circumscribed):", tx, ty);
    ty += lineHeight;
    text("  " + nf(circumradiusTop, 1, 2) + " mm  (ø " + nf(2*circumradiusTop, 1, 2) + ")", tx, ty);
    ty += lineHeight * 1.2;
    
    // Bottom Perimeter
    text("Bottom Perimeter: " + nf(cylinder.y, 1, 2) + " mm", tx, ty);
    ty += lineHeight;
    
    // Bottom inscribed radius
    text("Bot r_in (inscribed):", tx, ty);
    ty += lineHeight;
    text("  " + nf(inradiusBottom, 1, 2) + " mm  (ø " + nf(2*inradiusBottom, 1, 2) + ")", tx, ty);
    ty += lineHeight;
    
    // Bottom circumscribed radius
    text("Bot r_out (circumscribed):", tx, ty);
    ty += lineHeight;
    text("  " + nf(circumradiusBottom, 1, 2) + " mm  (ø " + nf(2*circumradiusBottom, 1, 2) + ")", tx, ty);
    
    popStyle();
  }
  
  void drawStatusText() {
    fill(200, 200, 210);
    textAlign(RIGHT, CENTER);
    uiText(11);
    
    String status = "";
    if (cuboidMode) {
      status = "Cuboid Mode | " + nf(uiCubTopLen, 0, 1) + "x" + nf(uiCubTopWid, 0, 1) + "mm";
    } else if (perEdgeMode) {
      status = "Variable Mode | Edge " + (uiEdgeIdx + 1) + "/" + nSides;
    } else {
      status = nSides + "-sided " + (uiLock ? "Cylinder" : "Prism");
    }
    
    // Mode indicator
    text(status, width - 15, height / 2);
  }
  
  boolean mousePressed() {
    // Check if click is within toolbar area
    if (mouseY <= height) {
      // Check each button (in toolbar)
      for (ToolbarButton btn : buttons) {
        if (btn.isMouseOver() && btn.enabled) {
          handleButtonClick(btn.id);
          return true;
        }
      }
      return false;
    }
    
    // Click is below toolbar
    // Check if it's on the dropdown - if so, keep it open
    if (dropdownOpen && mouseX >= dropdownX && mouseX <= dropdownX + dropdownWidth &&
        mouseY >= height && mouseY <= height + dropdownBoxHeight) {
      // Clicked on dropdown, keep it open
      return true;
    }
    
    // Clicked outside dropdown area, but don't close it
    // Only close the dropdown by clicking the button again
    return false;
  }
  
  void mouseMoved() {
    // Update hover states
    for (ToolbarButton btn : buttons) {
      btn.hover = btn.isMouseOver() && btn.enabled;
    }
  }
  
  void handleButtonClick(String id) {
    // Workshop mode toggle (hides the Assembly button when active)
    if (id.equals("workshop_mode")) {
      workshopMode = !workshopMode;
      if (workshopMode) {
        // Leaving assembly behind when entering workshop mode
        if (assemblyMode) {
          assemblyMode = false;
          assemblyShowTemplate = false;
          if (sidebar != null) sidebar.refreshTabsForAssemblyMode();
        }
        // Hollow / double-wall mode is not available in workshop mode
        if (hollowMode) {
          hollowMode = false;
          if (tHollowMode != null) tHollowMode.setValue(0);
          setParams(false);
        }
      }
      updateSidebarControlsVisibility();  // apply hollow toggle show/hide
      setup();  // rebuild toolbar so the Assembly button appears/disappears
      update();
      println("[Toolbar] Workshop mode: " + workshopMode);
      return;
    }

    // Assembly mode toggle
    if (id.equals("assembly_mode")) {
      assemblyMode = !assemblyMode;
      if (assemblyMode) {
        view3DMode = true;          // always show 3D when entering assembly mode
        assemblyShowTemplate = false; // start in 3D view, not template
      }
      if (sidebar != null) sidebar.refreshTabsForAssemblyMode();
      update();
      println("[Toolbar] Assembly mode: " + assemblyMode);
      return;
    }

    // Dimensions dropdown toggle
    if (id.equals("show_dimensions")) {
      dropdownOpen = !dropdownOpen;
      dimensionsBtn.setActive(dropdownOpen);
      println("[TOOLBAR] Info button clicked! dropdownOpen=" + dropdownOpen);
      return;
    }
    
    // Mode toggle
    if (id.equals("toggle_mode")) {
      togglePerEdgeMode();
      update();
      return;
    }
    
    // Export button
    if (id.equals("export")) {
      bSavePDF = true;
      println("[Toolbar] Export triggered");
      return;
    }
    
    // 3D view toggle
    if (id.equals("toggle_3d")) {
      view3DMode = !view3DMode;
      update();
      println("[Toolbar] 3D view mode: " + view3DMode);
      return;
    }
  }
  
  void update() {
    // Sync all button states with global variables
    for (ToolbarButton btn : buttons) {
      if (btn.id.equals("template_editor")) {
        btn.setActive(platonicEditMode);
      }
      else if (btn.id.equals("workshop_mode")) {
        btn.setActive(workshopMode);
        btn.label = workshopMode ? "Workshop ✓" : "Workshop";
      }
      else if (btn.id.equals("assembly_mode")) {
        btn.setActive(assemblyMode);
        btn.label = assemblyMode ? "Assembly \u2713" : "Assembly";
      }
      else if (btn.id.equals("toggle_mode")) {
        btn.setActive(perEdgeMode);
        btn.label = perEdgeMode ? "Per-Edge" : "Uniform";
      }
      else if (btn.id.equals("toggle_3d")) {
        btn.setActive(view3DMode);
        btn.label = view3DMode ? "3D View" : "2D View";
      }
    }
  }
}

// Global toolbar instance
Toolbar toolbar;
