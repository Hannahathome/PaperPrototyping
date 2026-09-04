//----------------------------------------------------------------------
// UI.PDE - USER INTERFACE CONTROLS
// This file manages all UI elements including sliders, buttons, and toggles
//-----------------------------------------------------------------------

import controlP5.*;
ControlP5 cp5__prism;

// CONTROLS

// --- Shape Control Sliders & Buttons ---
Slider sNSides;       // n sides
Button btnSidesMinus; // decrement sides
Button btnSidesPlus;  // increment sides
Slider sSideLen;      // height (mm)
Slider sPanelW;      // panel width (mm)
Toggle tLock;         // lock top & bottom
Slider sTopSize;      // top edge width (mm)
Slider sBotSize;      // bottom edge width (mm)
Toggle tCuboidMode;   // toggle cuboid mode (rectangular lids)
Slider sCubTopLen;    // cuboid top lid length (mm)
Slider sCubTopWid;    // cuboid top lid width (mm)
Slider sCubBotLen;    // cuboid bottom lid length (mm)
Slider sCubBotWid;    // cuboid bottom lid width (mm)
Toggle tCubRatioLock; // lock top and bottom to be exactly the same
Toggle tCubAspectLock; // lock bottom aspect ratio to match top
Slider  sTotalLen;    //slider om lengte direct te zetten
Toggle  tPerimLock; 
Toggle tAdvanced;
//Toggle perEdgeMode;   // switch to per-edge mode 

// Input textfields for precise values
Textfield tfHeight;
Textfield tfTopSize;
Textfield tfBotSize;
Textfield tfCubTopLen;
Textfield tfCubTopWid;
Textfield tfCubBotLen;
Textfield tfCubBotWid;

//advanced sliders
Slider sTabDepth;
Slider sFlapDepth;
Slider sFlapTaper;
Slider sTabNeckRatio;
Slider sDash;
Slider sPatX;
Slider sPatY;
Slider sPatRotation;
Slider sStripRotation;
Slider sTessDensity;

// Hollow mode controls
Toggle tHollowMode;
Slider sWallThickness;

// Inner shape controls (for donut lids)
Toggle tEnableInnerShape;

// Dimension display toggle
Toggle tShowExtraDimensions;
Slider sInnerSides;
Slider sInnerScale;
Slider sInnerRotation;

// UI PARAMETERS & DEFAULT VALUES
// Edit these values to change default settings

int   uiSides   = max(3, (nSides > 0 ? nSides : 6));
int   uiTessDensity = 16;  // Set to highest tessellation quality by default !! 
float uiHeight  = (cylinder != null && cylinder.z > 0) ? cylinder.z : 100;

// BELANGRIJKE NOTITIE: uiTopW en uiBotW zijn CIRCUMSCRIBED DIAMETER (uitgeschreven cirkel)
// Dit betekent: de cirkel die om de polygoon heen past, niet de zijde-lengte!
// 
// Bij init: simpele benadering om te starten
// applyToModel() zal dit direct corrigeren naar de juiste diameter-based waarde
// Dit voorkomt problemen met oude opgeslagen data
float uiTopW    = (cylinder != null && cylinder.x > 0) ? (cylinder.x / max(3, uiSides)) : 40;
float uiBotW    = (cylinder != null && cylinder.y > 0) ? (cylinder.y / max(3, uiSides)) : 40;
boolean uiLock  = false;
boolean uiAdvanced = false; // collapsed by default
boolean uiPerimLock = false;     // lock totale strip-lengte
float   uiPerim     = 0;         // vastgezette lengte (mm)
boolean uiHidePanelFolds = false;
Toggle tHidePanelFolds;
boolean uiLightGrayCutLines = false;
Toggle tLightGrayCutLines;
Toggle tSplitStrip;
Toggle tKresling;
Slider sKreslingUnits;      // Kresling fold height (base/shear angle)
Slider sKreslingSegments;   // Kresling vertical segments (tiers per panel)
boolean uiShowExtraDimensions = false;

// Y anchors for the secondary toggle group (hide folds / cut lines / split / hollow ...).
// When cuboid mode is off the group moves up into the space the cuboid controls would use,
// so it doesn't overlap the 3D preview; when on, it drops below the cuboid controls.
float togglesYWhenCuboidOff = 0;
float togglesYWhenCuboidOn = 0;

// Vertical space reserved (below the Kresling toggle) for the haptic selector UI
// (feel buttons + generate/check + live γ line + up to ~2 lines of result readout).
final int KRESLING_HAPTIC_BLOCK_H = 134;

// Y where the Kresling haptic selector UI starts — one grid row below the Kresling toggle.
// Shared by layoutSecondaryToggles() (to place the sliders under it) and the sidebar draw
// + click code (to place/hit-test the buttons), so they stay aligned.
float kreslingHapticUIY() {
  float startY = (cuboidMode ? togglesYWhenCuboidOn : togglesYWhenCuboidOff) + TAB_LEN_ROW_H;
  return startY + (29 + 12);  // row + 12 = one gridRowH below the toggle
}

// Height reserved for the TAB LENGTH preset row (label + button row) drawn on the Shape
// tab just above the secondary toggle group.
final int TAB_LEN_ROW_H = 52;
// Tab length presets (mm) offered as quick buttons on the Shape tab.
final int[] TAB_LEN_PRESETS = {5, 10, 15};

// Height of the PAGE SIZE section on the print Placement panel (header + button row).
final int PAGE_SIZE_BLOCK_H = 66;

// Extra breathing room between the "2D VIEW POSITIONING" header and the pattern-offset
// sliders (and everything below them) on the print Placement panel.
final int PLACEMENT_TOP_GAP = 24;

// Base Y for the print placement controls. In workshop mode the PAGE SIZE section is
// hidden, so everything below it shifts up by the section's height.
int placementBaseY() {
  return TOOLBAR_HEIGHT + 161 - (workshopMode ? PAGE_SIZE_BLOCK_H : 0) + PLACEMENT_TOP_GAP;
}

// --- Texture & Display Options ---
boolean uiShowLidTextures = false;
Toggle tShowLidTextures;
boolean uiShowTessellationMesh = false;
Toggle tShowTessellationMesh;

// --- Lid Positioning ---
float uiLidOffsetX = 0;
float uiLidOffsetY = 0;
Slider sLidOffsetX;
Slider sLidOffsetY;

// Base plate tool controls (Print → Base sub-tab)
Toggle tBaseEnabled, tBaseTwoPlates, tBaseFoldLine, tBaseBoxMode, tBaseOnly, tBaseSlitFree;
Slider sBaseWidth, sBaseLength, sBaseOffsetX, sBaseOffsetY, sBaseCorner, sBaseWallHeight;

// --- Independent Lid Positioning ---
float uiTopLidOffsetX = 0;
float uiTopLidOffsetY = 0;
float uiBotLidOffsetX = 0;
float uiBotLidOffsetY = 0;
float uiTopLidRotation = 0; // Rotation in degrees
float uiBotLidRotation = 0; // Rotation in degrees
Button btnTopLidLeft, btnTopLidRight, btnTopLidUp, btnTopLidDown, btnTopLidRotate;
Button btnBotLidLeft, btnBotLidRight, btnBotLidUp, btnBotLidDown, btnBotLidRotate;

// --- Inner Wall Positioning (Hollow Mode) ---
float uiInnerWallOffsetX = 0;
float uiInnerWallOffsetY = 0;
Button btnInnerWallLeft, btnInnerWallRight, btnInnerWallUp, btnInnerWallDown;

// --- Split Strip Half Positioning ---
float uiSplitHalf1OffsetX = 0;
float uiSplitHalf1OffsetY = 0;
float uiSplitHalf1Rotation = 0;
float uiSplitHalf2OffsetX = 0;
float uiSplitHalf2OffsetY = 0;
float uiSplitHalf2Rotation = 0;
Button btnHalf1Left, btnHalf1Right, btnHalf1Up, btnHalf1Down, btnHalf1Rotate;
Button btnHalf2Left, btnHalf2Right, btnHalf2Up, btnHalf2Down, btnHalf2Rotate;

// Track which lid button is currently held down
String heldLidButton = "";
float lidMoveSpeed = 2.0; // Movement speed in mm per frame
float lidRotateSpeed = 2.0; // Rotation speed in degrees per frame

// 2D/3D view toggle in bottom strip
Toggle tView3D;

Toggle tShowDistances;   // Distance/dimension overlay toggle (bottom bar)

//--RH-- Fiducial Marker Controls
Toggle tEnableMarkers;
Toggle tAutoMarkerIDs;      // Auto-increment marker IDs across all shapes
Toggle tMarkerFreePlace;   // Drag markers freely on the lid
Numberbox m_idNumbox;
Numberbox m_sizeNumbox;
Numberbox m_gridNumbox;   // NxN marker grid count
Numberbox nRepNumbox;   // Repeat count numberbox
Textfield tfNRep;       // Typable field for repeat count
Toggle tFreePlacement;      // Free placement drag toggle
Button btnResetPlacement;   // Reset free placement to grid
Textfield tfMarkerID;
Textfield tfMarkerSize;
boolean markersEnabled = false;
boolean autoMarkerIDs  = false;  // When true, IDs are auto-assigned sequentially across all shapes
//--RH--

// Cutout controls
Numberbox nbCutoutX;
Numberbox nbCutoutY;
Numberbox nbCutoutCornerR;
Slider sCutoutX;   // Move selected cutout — X (Cutouts sub-tab only)
Slider sCutoutY;   // Move selected cutout — Y (Cutouts sub-tab only)

// View preset buttons in bottom strip (commented out for now)
// Button btnViewTop, btnViewFront, btnViewRight, btnViewIso;

// Export filename
Textfield tfExportFilename;
String uiExportFilename = "output";
Button btnExportMain;

int uiTextureMode = 0;        // 0=none, 1=per-panel, 2=strip
Slider sTextureMode;

int uiEdgeIdx = 0;            // selected edge index
float stepFine = STEP_FINE;   // fine adjustment step (mm) - defined in Param.pde
float stepCoarse = STEP_COARSE; // coarse adjustment step (mm) - defined in Param.pde
float uiNormalizeTarget = 0;  // 0 => use uiPerim or cylinder.x

Textlabel lblTopP, lblBotP;           // top and bottom perimiters of the shapes
//Textlabel lblTopA, lblBotA;         // top and bottom oppervlakte (werkt niet!!!!)
Textlabel lblTopRin, lblTopRout;      // ingeschreven cirkel en uitgeschreven cirkel  top
Textlabel lblBotRin, lblBotRout;      // ingeschreven cirkel en uitgeschreven cirkel  bottom

// Advanced section labelss
Textlabel lblAdvHdr;
//Button btnAdvReset;

//  UI INITIALIZATION
// This function creates and positions all UI controls
void initShapeUI() {
  if (cp5__prism != null) return;
  cp5__prism = new ControlP5(this);
  
  // Position controls in sidebar (Shape Control tab content area)
  // Starting Y increased to make room for shape counter row + Reset + Load JSON buttons
  int x = SIDEBAR_PADDING, y = TOOLBAR_HEIGHT + 202, w = LEFT_SIDEBAR_WIDTH - 2*SIDEBAR_PADDING - 120, h = 20, row = 29;

  drawPerEdgeHUD();

  // HIDDEN: Texture mode slider - now controlled by sidebar tabs
  sTextureMode = cp5__prism.addSlider("ui_texture_mode")
    .setPosition(-1000, -1000)  // Hidden off-screen
    .setSize(250, h)
    .setLabel("Texture Mode")
    .setColorLabel(0)
    .setRange(0, 2)
    .setNumberOfTickMarks(3)
    .setSliderMode(Slider.FLEXIBLE)
    .snapToTickMarks(true)
    .setDecimalPrecision(0)
    .setValue(uiTextureMode)
    .setVisible(false);
  
  // HIDDEN: Lid textures toggle - now in sidebar
  tShowLidTextures = cp5__prism.addToggle("ui_show_lid_textures")
    .setPosition(-1000, -1000)  // Hidden off-screen
    .setSize(50, h)
    .setLabel("Show Lid Textures")
    .setColorLabel(0)
    .setValue(uiShowLidTextures ? 1 : 0)
    .setVisible(false);
  
  // HIDDEN: Tessellation density slider
  sTessDensity = cp5__prism.addSlider("ui_tessDensity")
    .setPosition(-1000, -1000)  // Hidden off-screen
    .setSize(250, h)
    .setLabel("Tessellation Density")
    .setColorLabel(0)
    .setRange(4, 16)
    .setNumberOfTickMarks(4)
    .setDecimalPrecision(0)
    .setValue(uiTessDensity)
    .setVisible(false);
  
  // Show tessellation mesh toggle (positioned next to 2D/3D toggle in bottom bar)
  tShowTessellationMesh = cp5__prism.addToggle("ui_show_tessellation_mesh")
    .setPosition(-1000, -1000)  // Position set in updateExportControlPositions()
    .setSize(90, 34)
    .setLabel("Mesh")
    .setColorLabel(color(255))
    .setColorBackground(color(80, 80, 150))      // Same as toolbar normal
    .setColorForeground(color(90, 90, 180))      // Same as toolbar hover
    .setColorActive(color(100, 100, 255))        // Same as toolbar active
    .setValue(uiShowTessellationMesh ? 1 : 0);
  tShowTessellationMesh.getCaptionLabel().setFont(createFont("Arial", 12))
    .alignX(CENTER)
    .alignY(CENTER);

  // n sides with +/- buttons
  final int UI_BTN_SIZE = 26;
  final int UI_GAP = 4;
  int sliderWidth = w - (2 * UI_BTN_SIZE) - (2 * UI_GAP);  // slider width adjusted to fit buttons
  y += 0.5*row;
  btnSidesMinus = cp5__prism.addButton("btn_sides_minus")
    .setPosition(x, y)
    .setSize(UI_BTN_SIZE, h)
    .setLabel("-")
    .setColorLabel(255);
  
  sNSides = cp5__prism.addSlider("ui_n_sides")
    .setPosition(x + UI_BTN_SIZE + UI_GAP, y).setSize(sliderWidth, h)
    .setLabel("NUMBER OF SIDES")
    .setColorLabel(0)
    .setRange(MIN_SIDES, 30)
    .setDecimalPrecision(0)
    .setValue(uiSides);
  sNSides.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(-UI_BTN_SIZE - UI_GAP)
    .setPaddingY(6);
  
  btnSidesPlus = cp5__prism.addButton("btn_sides_plus")
    .setPosition(x + UI_BTN_SIZE + UI_GAP + sliderWidth + UI_GAP, y)
    .setSize(UI_BTN_SIZE, h)
    .setLabel("+")
    .setColorLabel(255);
  
  y += row + 20;

  // Height slider with input field
  int inputW = 50;
  int inputGap = 8;
  sSideLen = cp5__prism.addSlider("ui_side_length")
    .setPosition(x, y).setSize(w - inputW - inputGap, h)
    .setLabel("HEIGHT")
    .setColorLabel(0)
    .setRange(1, 120)
    .setValue(uiHeight);
  sSideLen.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);
  
  tfHeight = cp5__prism.addTextfield("tf_height")
    .setPosition(x + w - inputW, y)
    .setSize(inputW, h)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(nf(uiHeight, 0, 1))
    .setFocus(false);
  tfHeight.getCaptionLabel().setVisible(false);
  
  y += row + 20;

  ////width
  //sPanelW = cp5__prism.addSlider("ui_panel_w")
  //  .setPosition(x, y).setSize(w, h)
  //  .setLabel("Paneelbreedte (mm)")
  //  .setColorLabel(0)
  //  .setRange(5, 50)            // kies bereik dat logisch is voor jouw vormen
  //  .setValue(uiTopW);           // startwaarde gelijk aan huidige top-paneelbreedte

  //y += row;

  // --- Perimeter lock toggle (side-by-side with Lock toggle below) ---
  // tPerimLock = cp5__prism.addToggle("ui_perim_lock")
  //   .setPosition(x, y)
  //   .setSize(40, 18)
  //   .setLabel("Lock Perimeter")
  //   .setColorLabel(0)
  //   .setValue(uiPerimLock ? 1 : 0);
  // tPerimLock.getCaptionLabel().align(ControlP5.LEFT, ControlP5.CENTER).setPaddingX(50);
  // y += row;

  // --- (optioneel) slider om de vaste lengte te kunnen kiezen/editen ---
  // float currentTopPerim = uiSides * uiTopW;
  // if (uiPerim == 0) uiPerim = currentTopPerim;

  // sTotalLen = cp5__prism.addSlider("ui_total_len")
  //   .setPosition(x, y).setSize(w, h)
  //   .setLabel("Total Length (mm)")
  //   .setColorLabel(0)
  //   .setRange(10, 200)
  //   .setValue(uiPerim);
  // y += row;

  // Two-column layout for top/bottom lid sizes
  int lockbuttonsize = 24;
  int inputW2 = 45;
  int inputGap2 = 5;
  int halfW = (w - UI_GAP - UI_GAP - lockbuttonsize - 2*(inputW2 + inputGap2)) / 2;
  
  // Top lid size slider with input
  sTopSize = cp5__prism.addSlider("ui_top_size")
    .setPosition(x, y).setSize(halfW, h)
    .setLabel("TOP DIAMETER")
    .setColorLabel(0)
    .setRange(1, 120)
    .setValue(uiTopW);
  sTopSize.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);
  
  tfTopSize = cp5__prism.addTextfield("tf_top_size")
    .setPosition(x + halfW + inputGap2, y)
    .setSize(inputW2, h)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(nf(uiTopW, 0, 1))
    .setFocus(false);
  tfTopSize.getCaptionLabel().setVisible(false);
  
  // Lock toggle in the middle
  tLock = cp5__prism.addToggle("ui_lock_equal")
    .setPosition(x + halfW + inputW2 + inputGap2 + UI_GAP, y)
    .setSize(lockbuttonsize, 22)
    .setLabel("=")
    .setColorLabel(0)
    .setValue(uiLock ? 1 : 0);
  tLock.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.CENTER, ControlP5.TOP_OUTSIDE)
    .setPaddingY(6);
  
  // Bottom lid size slider with input
  int botSliderX = x + halfW + inputW2 + inputGap2 + UI_GAP + lockbuttonsize + UI_GAP;
  sBotSize = cp5__prism.addSlider("ui_bottom_size")
    .setPosition(botSliderX, y).setSize(halfW, h)
    .setLabel("BOTTOM DIAMETER")
    .setColorLabel(0)
    .setRange(1, 120)
    .setValue(uiBotW);
  sBotSize.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);
  
  tfBotSize = cp5__prism.addTextfield("tf_bot_size")
    .setPosition(botSliderX + halfW + inputGap2, y)
    .setSize(inputW2, h)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(nf(uiBotW, 0, 1))
    .setFocus(false);
  tfBotSize.getCaptionLabel().setVisible(false);
  
  y += row +5;

  // Cuboid mode toggle (only shown when nSides==4)
  tCuboidMode = cp5__prism.addToggle("ui_cuboid_mode")
    .setPosition(x, y)
    .setSize(22, 22)
    .setLabel("CUBOID MODE (RECTANGULAR LIDS)")
    .setColorLabel(color(0))
    .setValue(cuboidMode ? 1 : 0);
  tCuboidMode.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(31);
  tCuboidMode.setVisible(nSides == 4);
  y += row + 20;

  // Compact anchor for the secondary toggle group (used when cuboid mode is off,
  // so the toggles sit here instead of overlapping the 3D preview lower down).
  togglesYWhenCuboidOff = y;

  // === CUBOID MODE CONTROLS (only visible when cuboidMode is on) ===
  // Row 1: Top lid length + Top lid width
  sCubTopLen = cp5__prism.addSlider("ui_cub_top_len")
    .setPosition(x, y).setSize(halfW, h)
    .setLabel("TOP LENGTH")
    .setColorLabel(0)
    .setDecimalPrecision(1)
    .setRange(1, 120)
    .setValue(uiCubTopLen);
  sCubTopLen.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);

  tfCubTopLen = cp5__prism.addTextfield("tf_cub_top_len")
    .setPosition(x + halfW + inputGap2, y)
    .setSize(inputW2, h)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(nf(uiCubTopLen, 0, 1))
    .setFocus(false);
  tfCubTopLen.getCaptionLabel().setVisible(false);

  sCubTopWid = cp5__prism.addSlider("ui_cub_top_wid")
    .setPosition(botSliderX, y).setSize(halfW, h)
    .setLabel("TOP WIDTH")
    .setColorLabel(0)
    .setDecimalPrecision(1)
    .setRange(1, 120)
    .setValue(uiCubTopWid);
  sCubTopWid.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);

  tfCubTopWid = cp5__prism.addTextfield("tf_cub_top_wid")
    .setPosition(botSliderX + halfW + inputGap2, y)
    .setSize(inputW2, h)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(nf(uiCubTopWid, 0, 1))
    .setFocus(false);
  tfCubTopWid.getCaptionLabel().setVisible(false);
  y += row;

  // Row 2: Two lock buttons side by side
  int cubBtnGap = 6;
  int cubBtnW = (w - cubBtnGap) / 2;
  
  tCubRatioLock = cp5__prism.addToggle("ui_cub_ratio_lock")
    .setPosition(x, y)
    .setSize(cubBtnW, 24)
    .setLabel("SAME SIZE")
    .setColorLabel(color(255))
    .setColorBackground(color(80, 80, 150))
    .setColorForeground(color(100, 100, 180))
    .setColorActive(color(50, 150, 50))
    .setValue(uiCubRatioLock ? 1 : 0);
  tCubRatioLock.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.CENTER, ControlP5.CENTER);

  tCubAspectLock = cp5__prism.addToggle("ui_cub_aspect_lock")
    .setPosition(x + cubBtnW + cubBtnGap, y)
    .setSize(cubBtnW, 24)
    .setLabel("LOCK RATIO")
    .setColorLabel(color(255))
    .setColorBackground(color(80, 80, 150))
    .setColorForeground(color(100, 100, 180))
    .setColorActive(color(50, 150, 50))
    .setValue(uiCubAspectLock ? 1 : 0);
  tCubAspectLock.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.CENTER, ControlP5.CENTER);
  y += row + 20;

  // Row 3: Bottom lid length + Bottom lid width
  sCubBotLen = cp5__prism.addSlider("ui_cub_bot_len")
    .setPosition(x, y).setSize(halfW, h)
    .setLabel("BOTTOM LENGTH")
    .setColorLabel(0)
    .setDecimalPrecision(1)
    .setRange(1, 120)
    .setValue(uiCubBotLen);
  sCubBotLen.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);

  tfCubBotLen = cp5__prism.addTextfield("tf_cub_bot_len")
    .setPosition(x + halfW + inputGap2, y)
    .setSize(inputW2, h)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(nf(uiCubBotLen, 0, 1))
    .setFocus(false);
  tfCubBotLen.getCaptionLabel().setVisible(false);

  sCubBotWid = cp5__prism.addSlider("ui_cub_bot_wid")
    .setPosition(botSliderX, y).setSize(halfW, h)
    .setLabel("BOTTOM WIDTH")
    .setColorLabel(0)
    .setDecimalPrecision(1)
    .setRange(1, 120)
    .setValue(uiCubBotWid);
  sCubBotWid.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);

  tfCubBotWid = cp5__prism.addTextfield("tf_cub_bot_wid")
    .setPosition(botSliderX + halfW + inputGap2, y)
    .setSize(inputW2, h)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(nf(uiCubBotWid, 0, 1))
    .setFocus(false);
  tfCubBotWid.getCaptionLabel().setVisible(false);
  y += row ;

  // Lower anchor for the secondary toggle group (used when cuboid mode is on,
  // so the toggles clear the cuboid controls above).
  togglesYWhenCuboidOn = y;

  // Set initial visibility of cuboid controls
  setCuboidControlsVisible(cuboidMode);

  // Hide panel folds toggle
  tHidePanelFolds = cp5__prism.addToggle("ui_hide_panel_folds")
    .setPosition(x, y)
    .setSize(22, 22)
    .setLabel("Hide panel folds")
    .setColorLabel(color(0))
    .setValue(uiHidePanelFolds ? 1 : 0);
  tHidePanelFolds.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(28);

  // Light gray cutting lines toggle
  tLightGrayCutLines = cp5__prism.addToggle("ui_light_gray_cut_lines")
    .setPosition(x, y)
    .setSize(22, 22)
    .setLabel("Light gray cut lines")
    .setColorLabel(color(0))
    .setValue(uiLightGrayCutLines ? 1 : 0);
  tLightGrayCutLines.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(28);

  // --- SPLIT STRIP TOGGLE ---
  tSplitStrip = cp5__prism.addToggle("ui_split_strip")
    .setPosition(x, y)
    .setSize(22, 22)
    .setLabel("Split strip in half")
    .setColorLabel(color(0))
    .setValue(splitStrip ? 1 : 0);
  tSplitStrip.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(28);

  // --- HOLLOW MODE CONTROLS ---
  // Hollow/Double-Wall mode toggle
  tHollowMode = cp5__prism.addToggle("ui_hollow_mode")
    .setPosition(x, y)
    .setSize(22, 22)
    .setLabel("Hollow / double wall")
    .setColorLabel(color(0))
    .setValue(hollowMode ? 1 : 0);
  tHollowMode.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(28);

  // --- KRESLING PATTERN TOGGLE ---
  tKresling = cp5__prism.addToggle("ui_kresling")
    .setPosition(x, y)
    .setSize(22, 22)
    .setLabel("Kresling pattern")
    .setColorLabel(color(0))
    .setValue(kreslingMode ? 1 : 0);
  tKresling.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(28);
  y += row;

  // Kresling fold height slider (mm) — sets the base/shear angle, like Stijn's foldHeight
  sKreslingUnits = cp5__prism.addSlider("ui_kresling_units")
    .setPosition(x, y)
    .setSize(w, h)
    .setLabel("Kresling fold height (mm)")
    .setColorLabel(color(0))
    .setRange(30, 200)
    .setValue(kreslingFoldHeight)
    .setDecimalPrecision(1);
  sKreslingUnits.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0);
  sKreslingUnits.setVisible(kreslingMode);

  // Kresling segments slider — vertical split (tiers) per panel
  sKreslingSegments = cp5__prism.addSlider("ui_kresling_segments")
    .setPosition(x, y)
    .setSize(w, h)
    .setLabel("Kresling segments")
    .setColorLabel(color(0))
    .setRange(1, 8)
    .setNumberOfTickMarks(8)
    .snapToTickMarks(true)
    .setValue(kreslingSegments)
    .setDecimalPrecision(0);
  sKreslingSegments.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0);
  sKreslingSegments.setVisible(kreslingMode);

  // Fit the fold-height slider to the shape's valid (shear-producing) range
  updateKreslingFoldHeightRange();

  // Wall thickness slider (shown when hollow mode is enabled)
  sWallThickness = cp5__prism.addSlider("ui_wall_thickness")
    .setPosition(x, y)
    .setSize(w, h)
    .setLabel("Wall Thickness (mm)")
    .setColorLabel(color(0))
    .setRange(1, 20)
    .setValue(wallThickness)
    .setDecimalPrecision(1);
  sWallThickness.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0);
  sWallThickness.setVisible(hollowMode);
  y += row;
  
  // --- INNER SHAPE CONTROLS (for donut lids with different inner polygon) ---
  // Enable Inner Shape toggle
  tEnableInnerShape = cp5__prism.addToggle("ui_enable_inner_shape")
    .setPosition(x, y)
    .setSize(22, 22)
    .setLabel("ENABLE DIFFERENT INNER SHAPE")
    .setColorLabel(color(0))
    .setValue(enableInnerShape ? 1 : 0);
  tEnableInnerShape.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(31);
  tEnableInnerShape.setVisible(hollowMode);
  y += row;
  
  // Inner Sides slider
  sInnerSides = cp5__prism.addSlider("ui_inner_sides")
    .setPosition(x, y)
    .setSize(w, h)
    .setLabel("Inner Polygon Sides")
    .setColorLabel(color(0))
    .setRange(3, 10)
    .setValue(nSidesInner)
    .setDecimalPrecision(0);
  sInnerSides.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0);
  sInnerSides.setVisible(hollowMode && enableInnerShape);
  y += row;
  
  // Inner Scale slider
  sInnerScale = cp5__prism.addSlider("ui_inner_scale")
    .setPosition(x, y)
    .setSize(w, h)
    .setLabel("Inner Scale (fraction of outer)")
    .setColorLabel(color(0))
    .setRange(0.3, 0.8)
    .setValue(innerShapeScale)
    .setDecimalPrecision(2);
  sInnerScale.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0);
  sInnerScale.setVisible(hollowMode && enableInnerShape);
  y += row;
  
  // Inner Rotation slider
  sInnerRotation = cp5__prism.addSlider("ui_inner_rotation")
    .setPosition(x, y)
    .setSize(w, h)
    .setLabel("Inner Shape Rotation (degrees)")
    .setColorLabel(color(0))
    .setRange(0, 360)
    .setValue(innerShapeRotation)
    .setDecimalPrecision(0);
  sInnerRotation.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0);
  sInnerRotation.setVisible(hollowMode && enableInnerShape);
  y += row;

  // Position the secondary toggle group at the correct anchor for the current mode
  layoutSecondaryToggles();

  // --- SHOW EXTRA DIMENSIONS TOGGLE (now in toolbar dropdown) ---
  // Moved to Toolbar as a dropdown menu
  // tShowExtraDimensions is no longer needed in sidebar

  //  Advanced toggle header
  //lblAdvHdr = cp5__prism.addTextlabel("lbl_adv_hdr")
  //  .setPosition(x, y)
  //  .setText("Advanced");
  //y += 18;
  
  // HIDDEN: Advanced toggle (hidden but code preserved)
  tAdvanced = cp5__prism.addToggle("ui_adv_toggle")
    .setPosition(-1000, -1000)
    .setSize(50, 18)
    .setLabel("Show Advanced")
    .setColorLabel(0)
    .setValue(false)  // Always start hidden
    .setVisible(false);


  // Export controls at bottom right
  float exportBarY = height - BOTTOM_EXPORT_HEIGHT + 10;
  float exportBarX = width - 320;
  
  // 2D/3D view toggle (bottom strip, left side) - styled like toolbar buttons
  float bottomControlX = LEFT_SIDEBAR_WIDTH + 20;
  float bottomControlY = exportBarY + 8;
  
  tView3D = cp5__prism.addToggle("toggle_view_3d")
    .setPosition(bottomControlX, bottomControlY)
    .setSize(80, 34)
    .setLabel(view3DMode ? "View in 2D" : "View in 3D")
    .setColorLabel(color(255))
    .setColorBackground(color(80, 80, 150))      // Same as toolbar normal
    .setColorForeground(color(90, 90, 180))      // Same as toolbar hover
    .setColorActive(color(100, 100, 255))        // Same as toolbar active
    .setValue(view3DMode ? 1 : 0);
  tView3D.getCaptionLabel().setFont(createFont("Arial", 12))
    .alignX(CENTER)
    .alignY(CENTER);

  tShowDistances = cp5__prism.addToggle("toggle_distances")
    .setPosition(bottomControlX + 640, bottomControlY)
    .setSize(80, 34)
    .setLabel("Distances")
    .setColorLabel(color(255))
    .setColorBackground(color(80, 80, 150))
    .setColorForeground(color(90, 90, 180))
    .setColorActive(color(100, 100, 255))
    .setValue(showDistances ? 1 : 0);
  tShowDistances.getCaptionLabel().setFont(createFont("Arial", 12)).alignX(CENTER).alignY(CENTER);
  
  /* View preset buttons (commented out for now - future reference)
  // View preset buttons (right after 3D toggle)
  float presetX = bottomControlX + 90;
  int presetBtnW = 45;
  int presetBtnH = 34;
  
  btnViewTop = cp5__prism.addButton("view_top")
    .setPosition(presetX, bottomControlY)
    .setSize(presetBtnW, presetBtnH)
    .setLabel("Top")
    .setColorBackground(color(70, 70, 90))
    .setColorForeground(color(90, 90, 110))
    .setColorActive(color(90, 120, 255))
    .setColorLabel(color(255));
  btnViewTop.getCaptionLabel().setFont(createFont("Arial", 11))
    .alignX(CENTER).alignY(CENTER);
  
  presetX += presetBtnW + 5;
  btnViewFront = cp5__prism.addButton("view_bottom")
    .setPosition(presetX, bottomControlY)
    .setSize(presetBtnW, presetBtnH)
    .setLabel("Bottom")
    .setColorBackground(color(70, 70, 90))
    .setColorForeground(color(90, 90, 110))
    .setColorActive(color(90, 120, 255))
    .setColorLabel(color(255));
  btnViewFront.getCaptionLabel().setFont(createFont("Arial", 11))
    .alignX(CENTER).alignY(CENTER);
  
  presetX += presetBtnW + 5;
  btnViewRight = cp5__prism.addButton("view_side")
    .setPosition(presetX, bottomControlY)
    .setSize(presetBtnW, presetBtnH)
    .setLabel("Side")
    .setColorBackground(color(70, 70, 90))
    .setColorForeground(color(90, 90, 110))
    .setColorActive(color(90, 120, 255))
    .setColorLabel(color(255));
  btnViewRight.getCaptionLabel().setFont(createFont("Arial", 11))
    .alignX(CENTER).alignY(CENTER);
  
  presetX += presetBtnW + 5;
  btnViewIso = cp5__prism.addButton("view_iso")
    .setPosition(presetX, bottomControlY)
    .setSize(presetBtnW, presetBtnH)
    .setLabel("Iso")
    .setColorBackground(color(70, 70, 90))
    .setColorForeground(color(90, 90, 110))
    .setColorActive(color(90, 120, 255))
    .setColorLabel(color(255));
  btnViewIso.getCaptionLabel().setFont(createFont("Arial", 11))
    .alignX(CENTER).alignY(CENTER);
  
  // Update initial visibility
  updateViewPresetButtonsVisibility();
  */
  
  // Lid offset controls in bottom strip (after toggle)
  float lidControlX = bottomControlX + 100;
  int lidSliderW = 140;
  int lidSliderH = 12;
  // Align bottom of sliders with bottom of buttons (button height = 34px)
  float lidControlY = bottomControlY + 34 - lidSliderH;
  
  sLidOffsetX = cp5__prism.addSlider("adv_lidOffsetX")
    .setPosition(lidControlX, lidControlY)
    .setSize(lidSliderW, lidSliderH)
    .setLabel("LID OFFSET X (MM)")
    .setColorLabel(0)
    .setRange(-200, 200)
    .setValue(uiLidOffsetX);
  sLidOffsetX.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);
  
  sLidOffsetY = cp5__prism.addSlider("adv_lidOffsetY")
    .setPosition(lidControlX + lidSliderW + 20, lidControlY)
    .setSize(lidSliderW, lidSliderH)
    .setLabel("LID OFFSET Y (MM)")
    .setColorLabel(0)
    .setRange(-200, 200)
    .setValue(uiLidOffsetY);
  sLidOffsetY.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);

  // --- Base plate tool controls (created off-screen; shown on Print → Base sub-tab) ---
  tBaseEnabled = cp5__prism.addToggle("ui_base_enabled")
    .setPosition(-1000, -1000)
    .setSize(22, 22)
    .setLabel("ADD BASE TO CUT PAGE")
    .setColorLabel(color(0))
    .setValue(baseEnabled ? 1 : 0);
  tBaseEnabled.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(30);

  tBaseTwoPlates = cp5__prism.addToggle("ui_base_two_plates")
    .setPosition(-1000, -1000)
    .setSize(22, 22)
    .setLabel("CONNECT SECOND PLATE (FOLD)")
    .setColorLabel(color(0))
    .setValue(baseTwoPlates ? 1 : 0);
  tBaseTwoPlates.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(30);

  tBaseFoldLine = cp5__prism.addToggle("ui_base_fold_line")
    .setPosition(-1000, -1000)
    .setSize(22, 22)
    .setLabel("FOLD LINE BETWEEN PLATES")
    .setColorLabel(color(0))
    .setValue(baseFoldLine ? 1 : 0);
  tBaseFoldLine.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(30);

  tBaseBoxMode = cp5__prism.addToggle("ui_base_box_mode")
    .setPosition(-1000, -1000)
    .setSize(22, 22)
    .setLabel("BOX BASE (WITH WALLS)")
    .setColorLabel(color(0))
    .setValue(baseBoxMode ? 1 : 0);
  tBaseBoxMode.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(30);

  sBaseWallHeight = cp5__prism.addSlider("ui_base_wall_height")
    .setPosition(-1000, -1000).setSize(200, 20)
    .setLabel("WALL HEIGHT (MM)").setColorLabel(0).setRange(5, 100).setValue(baseWallHeightMM);
  sBaseWallHeight.getCaptionLabel().setFont(createFont("Arial", 13)).align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(6);

  tBaseOnly = cp5__prism.addToggle("ui_base_only")
    .setPosition(-1000, -1000)
    .setSize(22, 22)
    .setLabel("BASE ONLY (HIDE THE REST)")
    .setColorLabel(color(0))
    .setValue(baseOnly ? 1 : 0);
  tBaseOnly.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(30);

  tBaseSlitFree = cp5__prism.addToggle("ui_base_slit_free")
    .setPosition(-1000, -1000)
    .setSize(22, 22)
    .setLabel("FREE PLACE MOUNTING CUTOUTS")
    .setColorLabel(color(0))
    .setValue(baseSlitFreePlace ? 1 : 0);
  tBaseSlitFree.getCaptionLabel()
    .setFont(createFont("Arial", 13))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(30);

  sBaseWidth = cp5__prism.addSlider("ui_base_width")
    .setPosition(-1000, -1000).setSize(200, 20)
    .setLabel("BASE WIDTH (MM)").setColorLabel(0).setRange(10, 200).setValue(baseWidthMM);
  sBaseWidth.getCaptionLabel().setFont(createFont("Arial", 13)).align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(6);

  sBaseLength = cp5__prism.addSlider("ui_base_length")
    .setPosition(-1000, -1000).setSize(200, 20)
    .setLabel("BASE LENGTH (MM)").setColorLabel(0).setRange(10, 200).setValue(baseLengthMM);
  sBaseLength.getCaptionLabel().setFont(createFont("Arial", 13)).align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(6);

  sBaseOffsetX = cp5__prism.addSlider("ui_base_offset_x")
    .setPosition(-1000, -1000).setSize(200, 20)
    .setLabel("BASE OFFSET X (MM)").setColorLabel(0).setRange(-200, 200).setValue(baseOffsetX);
  sBaseOffsetX.getCaptionLabel().setFont(createFont("Arial", 13)).align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(6);

  sBaseOffsetY = cp5__prism.addSlider("ui_base_offset_y")
    .setPosition(-1000, -1000).setSize(200, 20)
    .setLabel("BASE OFFSET Y (MM)").setColorLabel(0).setRange(-200, 200).setValue(baseOffsetY);
  sBaseOffsetY.getCaptionLabel().setFont(createFont("Arial", 13)).align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(6);

  sBaseCorner = cp5__prism.addSlider("ui_base_corner")
    .setPosition(-1000, -1000).setSize(200, 20)
    .setLabel("BASE CORNER RADIUS (MM)").setColorLabel(0).setRange(0, 50).setValue(baseCornerRadiusMM);
  sBaseCorner.getCaptionLabel().setFont(createFont("Arial", 13)).align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE).setPaddingX(0).setPaddingY(6);

  // Independent lid movement buttons (positioned off-screen initially, moved by updateSidebarControlPositions)
  int btnSize = 26;
  int btnGap = 5;
  
  // Top lid controls
  btnTopLidLeft = cp5__prism.addButton("btn_top_lid_left")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("←")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 100))
    .setColorForeground(color(130, 130, 130))
    .setColorActive(color(150, 150, 150))
    .setVisible(false);
  
  btnTopLidRight = cp5__prism.addButton("btn_top_lid_right")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("→")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 100))
    .setColorForeground(color(130, 130, 130))
    .setColorActive(color(150, 150, 150))
    .setVisible(false);
  
  btnTopLidUp = cp5__prism.addButton("btn_top_lid_up")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("↑")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 100))
    .setColorForeground(color(130, 130, 130))
    .setColorActive(color(150, 150, 150))
    .setVisible(false);
  
  btnTopLidDown = cp5__prism.addButton("btn_top_lid_down")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("↓")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 100))
    .setColorForeground(color(130, 130, 130))
    .setColorActive(color(150, 150, 150))
    .setVisible(false);
  
  btnTopLidRotate = cp5__prism.addButton("btn_top_lid_rotate")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("↻")
    .setColorLabel(255)
    .setColorBackground(color(70, 120, 70))
    .setColorForeground(color(90, 150, 90))
    .setColorActive(color(110, 180, 110))
    .setVisible(false);
  
  // Bottom lid controls
  btnBotLidLeft = cp5__prism.addButton("btn_bot_lid_left")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("←")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 100))
    .setColorForeground(color(130, 130, 130))
    .setColorActive(color(150, 150, 150))
    .setVisible(false);
  
  btnBotLidRight = cp5__prism.addButton("btn_bot_lid_right")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("→")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 100))
    .setColorForeground(color(130, 130, 130))
    .setColorActive(color(150, 150, 150))
    .setVisible(false);
  
  btnBotLidUp = cp5__prism.addButton("btn_bot_lid_up")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("↑")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 100))
    .setColorForeground(color(130, 130, 130))
    .setColorActive(color(150, 150, 150))
    .setVisible(false);
  
  btnBotLidDown = cp5__prism.addButton("btn_bot_lid_down")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("↓")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 100))
    .setColorForeground(color(130, 130, 130))
    .setColorActive(color(150, 150, 150))
    .setVisible(false);
  
  btnBotLidRotate = cp5__prism.addButton("btn_bot_lid_rotate")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("↻")
    .setColorLabel(255)
    .setColorBackground(color(70, 120, 70))
    .setColorForeground(color(90, 150, 90))
    .setColorActive(color(110, 180, 110))
    .setVisible(false);
  
  // Inner wall controls (for hollow mode)
  btnInnerWallLeft = cp5__prism.addButton("btn_inner_wall_left")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("←")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 120))
    .setColorForeground(color(130, 130, 150))
    .setColorActive(color(150, 150, 180))
    .setVisible(false);
  
  btnInnerWallRight = cp5__prism.addButton("btn_inner_wall_right")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("→")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 120))
    .setColorForeground(color(130, 130, 150))
    .setColorActive(color(150, 150, 180))
    .setVisible(false);
  
  btnInnerWallUp = cp5__prism.addButton("btn_inner_wall_up")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("↑")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 120))
    .setColorForeground(color(130, 130, 150))
    .setColorActive(color(150, 150, 180))
    .setVisible(false);
  
  btnInnerWallDown = cp5__prism.addButton("btn_inner_wall_down")
    .setPosition(-1000, -1000)
    .setSize(btnSize, btnSize)
    .setLabel("↓")
    .setColorLabel(255)
    .setColorBackground(color(100, 100, 120))
    .setColorForeground(color(130, 130, 150))
    .setColorActive(color(150, 150, 180))
    .setVisible(false);
  
  // Split strip half controls (D-pad + rotate for each half)
  // Half 1
  btnHalf1Left = cp5__prism.addButton("btn_half1_left")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("←")
    .setColorLabel(255).setColorBackground(color(120, 100, 80))
    .setColorForeground(color(150, 130, 100)).setColorActive(color(180, 160, 120))
    .setVisible(false);
  btnHalf1Right = cp5__prism.addButton("btn_half1_right")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("→")
    .setColorLabel(255).setColorBackground(color(120, 100, 80))
    .setColorForeground(color(150, 130, 100)).setColorActive(color(180, 160, 120))
    .setVisible(false);
  btnHalf1Up = cp5__prism.addButton("btn_half1_up")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("↑")
    .setColorLabel(255).setColorBackground(color(120, 100, 80))
    .setColorForeground(color(150, 130, 100)).setColorActive(color(180, 160, 120))
    .setVisible(false);
  btnHalf1Down = cp5__prism.addButton("btn_half1_down")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("↓")
    .setColorLabel(255).setColorBackground(color(120, 100, 80))
    .setColorForeground(color(150, 130, 100)).setColorActive(color(180, 160, 120))
    .setVisible(false);
  btnHalf1Rotate = cp5__prism.addButton("btn_half1_rotate")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("↻")
    .setColorLabel(255).setColorBackground(color(70, 120, 70))
    .setColorForeground(color(90, 150, 90)).setColorActive(color(110, 180, 110))
    .setVisible(false);
  // Half 2
  btnHalf2Left = cp5__prism.addButton("btn_half2_left")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("←")
    .setColorLabel(255).setColorBackground(color(80, 100, 120))
    .setColorForeground(color(100, 130, 150)).setColorActive(color(120, 160, 180))
    .setVisible(false);
  btnHalf2Right = cp5__prism.addButton("btn_half2_right")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("→")
    .setColorLabel(255).setColorBackground(color(80, 100, 120))
    .setColorForeground(color(100, 130, 150)).setColorActive(color(120, 160, 180))
    .setVisible(false);
  btnHalf2Up = cp5__prism.addButton("btn_half2_up")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("↑")
    .setColorLabel(255).setColorBackground(color(80, 100, 120))
    .setColorForeground(color(100, 130, 150)).setColorActive(color(120, 160, 180))
    .setVisible(false);
  btnHalf2Down = cp5__prism.addButton("btn_half2_down")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("↓")
    .setColorLabel(255).setColorBackground(color(80, 100, 120))
    .setColorForeground(color(100, 130, 150)).setColorActive(color(120, 160, 180))
    .setVisible(false);
  btnHalf2Rotate = cp5__prism.addButton("btn_half2_rotate")
    .setPosition(-1000, -1000).setSize(btnSize, btnSize).setLabel("↻")
    .setColorLabel(255).setColorBackground(color(70, 120, 70))
    .setColorForeground(color(90, 150, 90)).setColorActive(color(110, 180, 110))
    .setVisible(false);

  // Filename text field
  tfExportFilename = cp5__prism.addTextfield("export_filename")
    .setPosition(exportBarX, exportBarY + 8)
    .setSize(180, 30)
    .setLabel("")
    .setColorLabel(0)
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(uiExportFilename)
    .setFocus(false);
  tfExportFilename.getCaptionLabel().setVisible(false);
  
  // Export button
  btnExportMain = cp5__prism.addButton("btn_export_main")
    .setPosition(exportBarX + 190, exportBarY + 8)
    .setSize(120, 30)
    .setLabel("EXPORT")
    .setColorLabel(color(255))
    .setColorBackground(color(50, 150, 50))
    .setColorForeground(color(60, 180, 60))
    .setColorActive(color(40, 120, 40));

  //  Advanced controls (hidden off-screen but code preserved)
  int advX = -1000, advY = -1000;

  sTabDepth = cp5__prism.addSlider("adv_tabDepth")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("Tab Depth (mm)")  .setColorLabel(0)
    .setRange(0, 50)
    .setValue(max(0, tabDepth));
  sTabDepth.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(2);
  advY += row + 10;

  sFlapDepth = cp5__prism.addSlider("adv_flapDepth")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("Flap Depth (mm)")  .setColorLabel(0)
    .setRange(0, 50)
    .setValue(max(0, flapDepth));
  sFlapDepth.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(2);
  advY += row + 10;

  sFlapTaper = cp5__prism.addSlider("adv_flapTaper")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("Flap Taper (mm)")  .setColorLabel(0)
    .setRange(0, 50)
    .setValue(max(0, flapTaper));
  sFlapTaper.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(2);
  advY += row + 10;

  sTabNeckRatio = cp5__prism.addSlider("adv_tab_neck_ratio")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("Tab Neck Ratio")  .setColorLabel(0)
    .setRange(0.2f, 1.5f)
    .setValue(constrain(tab_neck_ratio, 0.2, 1.5));
  sTabNeckRatio.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(2);
  advY += row + 10;

  sDash = cp5__prism.addSlider("adv_dash")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("Dash (mm)")  .setColorLabel(0)
    .setRange(0.5f, 50f)
    .setValue(max(0.5f, dash));
  sDash.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(2);
  advY += row + 10;

  sPatX = cp5__prism.addSlider("adv_patX")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("FULL PATTERN OFFSET X (MM)")  .setColorLabel(0)
    .setRange(-200, 200)
    .setValue(patX);
  sPatX.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);
  advY += row + 10;

  sPatY = cp5__prism.addSlider("adv_patY")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("FULL PATTERN OFFSET Y (MM)")  .setColorLabel(0)
    .setRange(-200, 200)
    .setValue(patY);
  sPatY.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);
  advY += row + 10;

  sPatRotation = cp5__prism.addSlider("adv_patRotation")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("TEMPLATE ROTATION (\u00B0)")  .setColorLabel(0)
    .setRange(-180, 180)
    .setValue(patRotation);
  sPatRotation.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);
  advY += row + 10;

  // Rotates the bent-strip texture. Rotates the source bitmap rather than the UVs, so the
  // strip re-fits to the new aspect — see StripRotation.pde.
  sStripRotation = cp5__prism.addSlider("adv_stripRotation")
    .setPosition(advX, advY).setSize(w, h)
    .setLabel("STRIP TEXTURE ROTATION (°)")  .setColorLabel(0)
    .setRange(0, 360)
    .setValue(uiStripRotation)
    .setDecimalPrecision(0);
  sStripRotation.getCaptionLabel()
    .setFont(createFont("Arial", 15))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(6);
  advY += row + 10;

  //------------------------------------------------------------------------------------
  //-----------------------------EXTRA INFO LABELS (HIDDEN)-----------------------------
  // Hidden but code preserved
  lblAdvHdr = cp5__prism.addTextlabel("lbl_adv_hdr")
    .setPosition(-1000, -1000)
    .setText("EXTRA INFORMATION")
    .setColorValue(0)
    .setVisible(false);

  lblTopP = cp5__prism.addTextlabel("lbl_top_p").setPosition(-1000, -1000).setColorValue(0).setVisible(false);
  lblBotP = cp5__prism.addTextlabel("lbl_bot_p").setPosition(-1000, -1000).setColorValue(0).setVisible(false);
  lblTopRin  = cp5__prism.addTextlabel("lbl_top_rin").setPosition(-1000, -1000).setColorValue(0).setVisible(false);
  lblTopRout = cp5__prism.addTextlabel("lbl_top_rout").setPosition(-1000, -1000).setColorValue(0).setVisible(false);
  lblBotRin  = cp5__prism.addTextlabel("lbl_bot_rin").setPosition(-1000, -1000).setColorValue(0).setVisible(false);
  lblBotRout = cp5__prism.addTextlabel("lbl_bot_rout").setPosition(-1000, -1000).setColorValue(0).setVisible(false);
  //------------------------------------------------------------------------------------
  
  //--RH-- Fiducial Marker UI Controls (in bottom bar next to 3D/Mesh buttons)
  float markerControlX = LEFT_SIDEBAR_WIDTH + 240;
  float markerControlY = exportBarY + 8;
  
  tEnableMarkers = cp5__prism.addToggle("enable_markers_toggle")
    .setPosition(markerControlX - 30, markerControlY)
    .setSize(22, 22)
    .setLabel("ENABLE MARKERS")
    .setColorLabel(color(0))
    .setValue(false);
  tEnableMarkers.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(31);
  
  m_idNumbox = cp5__prism.addNumberbox("marker_id_start")
    .setPosition(markerControlX, markerControlY)
    .setSize(70, 22)
    .setColorLabel(color(0))
    .setRange(0, 255)
    .setValue(Start_Index)
    .setDecimalPrecision(0)
    .setLabel("ID");
  m_idNumbox.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.CENTER, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingY(2);
  
  m_sizeNumbox = cp5__prism.addNumberbox("marker_size")
    .setPosition(markerControlX + 95, markerControlY)
    .setSize(70, 22)
    .setColorLabel(color(0))
    .setRange(5, 50)
    .setValue(Marker_Size)
    .setDecimalPrecision(0)
    .setLabel("Size");
  m_sizeNumbox.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.CENTER, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingY(2);
  
  // Textfield for Marker ID (next to numberbox)
  tfMarkerID = cp5__prism.addTextfield("tf_marker_id")
    .setPosition(markerControlX + 73, markerControlY)
    .setSize(20, 18)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(str(int(Start_Index)))
    .setFocus(false);
  tfMarkerID.getCaptionLabel().setVisible(false);
  
  // Textfield for Marker Size (next to numberbox)
  tfMarkerSize = cp5__prism.addTextfield("tf_marker_size")
    .setPosition(markerControlX + 168, markerControlY)
    .setSize(20, 18)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(str(int(Marker_Size)))
    .setFocus(false);
  tfMarkerSize.getCaptionLabel().setVisible(false);
  
  // Auto marker ID toggle — assigns unique sequential IDs across all shapes
  tAutoMarkerIDs = cp5__prism.addToggle("auto_marker_ids_toggle")
    .setPosition(markerControlX + 195, markerControlY)
    .setSize(22, 22)
    .setLabel("AUTO IDs")
    .setColorLabel(color(0))
    .setValue(false);
  tAutoMarkerIDs.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(28);

  // NxN marker grid (tile multiple markers onto large lids)
  m_gridNumbox = cp5__prism.addNumberbox("marker_grid")
    .setPosition(markerControlX + 285, markerControlY)
    .setSize(50, 22)
    .setColorLabel(color(0))
    .setRange(1, 5)
    .setValue(markerGrid)
    .setDecimalPrecision(0)
    .setLabel("Grid");
  m_gridNumbox.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.CENTER, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingY(2);

  tMarkerFreePlace = cp5__prism.addToggle("marker_free_place_toggle")
    .setPosition(markerControlX + 345, markerControlY)
    .setSize(22, 22)
    .setLabel("FREE")
    .setColorLabel(color(0))
    .setValue(markerFreePlace ? 1 : 0);
  tMarkerFreePlace.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.LEFT, ControlP5.CENTER)
    .setPaddingX(28);

  nRepNumbox = cp5__prism.addNumberbox("n_repeat")
    .setPosition(-1000, -1000)
    .setSize(100, 22)
    .setColorLabel(color(255))
    .setRange(1, 16)
    .setValue(nRep)
    .setDecimalPrecision(0)
    .setLabel("Repeats");
  nRepNumbox.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.CENTER, ControlP5.CENTER)
    .setPaddingY(0);
  
  tfNRep = cp5__prism.addTextfield("tf_n_repeat")
    .setPosition(-1000, -1000)
    .setSize(44, 22)
    .setLabel("")
    .setColorBackground(color(255))
    .setColorForeground(color(200))
    .setColorActive(color(50, 150, 255))
    .setColorValue(color(0))
    .setColorCursor(color(0))
    .setAutoClear(false)
    .setText(str(nRep))
    .setFocus(false);
  tfNRep.getCaptionLabel().setVisible(false);
  
  tFreePlacement = cp5__prism.addToggle("free_placement_toggle")
    .setPosition(-1000, -1000)
    .setSize(100, 26)
    .setLabel("FREE PLACE")
    .setColorLabel(color(255))
    .setColorBackground(color(80, 80, 150))
    .setColorForeground(color(90, 90, 180))
    .setColorActive(color(100, 180, 100))
    .setValue(false)
    .setVisible(false);
  tFreePlacement.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.CENTER, ControlP5.CENTER)
    .setPaddingY(0);
  
  btnResetPlacement = cp5__prism.addButton("btn_reset_placement")
    .setPosition(-1000, -1000)
    .setSize(100, 26)
    .setLabel("RESET GRID")
    .setColorLabel(color(255))
    .setColorBackground(color(160, 90, 40))
    .setColorForeground(color(190, 110, 50))
    .setColorActive(color(200, 120, 60))
    .setVisible(false);
  btnResetPlacement.getCaptionLabel()
    .setFont(createFont("Arial", 11))
    .align(ControlP5.CENTER, ControlP5.CENTER)
    .setPaddingY(0);
  //--RH--
  
  // --- Cutout position numberboxes ---
  int cutX = SIDEBAR_PADDING;
  int cutY = TOOLBAR_HEIGHT + 790;
  int nbW = 80;
  int nbH = 18;
  int cutGap = 10;
  
  nbCutoutX = cp5__prism.addNumberbox("cutout_pos_x")
    .setPosition(cutX, cutY)
    .setSize(nbW, nbH)
    .setColorLabel(color(0))
    .setRange(-200, 300)
    .setValue(10)
    .setDecimalPrecision(1)
    .setMultiplier(0.5)
    .setLabel("X (mm)");
  nbCutoutX.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(4);
  
  nbCutoutY = cp5__prism.addNumberbox("cutout_pos_y")
    .setPosition(cutX + nbW + cutGap, cutY)
    .setSize(nbW, nbH)
    .setColorLabel(color(0))
    .setRange(-200, 300)
    .setValue(10)
    .setDecimalPrecision(1)
    .setMultiplier(0.5)
    .setLabel("Y (mm)");
  nbCutoutY.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(4);
  
  nbCutoutCornerR = cp5__prism.addNumberbox("cutout_corner_r")
    .setPosition(cutX + 2*(nbW + cutGap), cutY)
    .setSize(nbW, nbH)
    .setColorLabel(color(0))
    .setRange(0, 15)
    .setValue(cutoutCornerRadius)
    .setDecimalPrecision(1)
    .setMultiplier(0.25)
    .setLabel("Radius (mm)");
  nbCutoutCornerR.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(4);

  // Sliders to move the selected cutout (Cutouts sub-tab only)
  int cutSlW = LEFT_SIDEBAR_WIDTH - 2 * SIDEBAR_PADDING;
  sCutoutX = cp5__prism.addSlider("cutout_move_x")
    .setPosition(SIDEBAR_PADDING, cutY)
    .setSize(cutSlW, 18)
    .setRange(-200, 300)
    .setValue(10)
    .setColorLabel(color(0))
    .setLabel("Move selected cutout  X (mm)");
  sCutoutX.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(4);
  sCutoutY = cp5__prism.addSlider("cutout_move_y")
    .setPosition(SIDEBAR_PADDING, cutY)
    .setSize(cutSlW, 18)
    .setRange(-200, 300)
    .setValue(10)
    .setColorLabel(color(0))
    .setLabel("Move selected cutout  Y (mm)");
  sCutoutY.getCaptionLabel()
    .setFont(createFont("Arial", 12))
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingY(4);

  // Initially hidden (only shown when Print tab is active)
  nbCutoutX.setVisible(false);
  nbCutoutY.setVisible(false);
  nbCutoutCornerR.setVisible(false);
  sCutoutX.setVisible(false);
  sCutoutY.setVisible(false);
  
  setAdvancedVisible(false);  // Keep advanced hidden
  applyToModel();
  refreshLabels();
  updateDimensionLabelsVisibility();  // Initialize dimension info visibility
  updateSidebarControlsVisibility(); // Set initial visibility
}


// CONTROL VISIBILITY MANAGEMENT
// Updates which controls are visible based on active sidebar tab
// Clamp the Kresling fold-height slider to the range that actually produces a shear for
// the current shape (0 .. kreslingFoldHeightMax). Keeps the whole slider usable instead of
// only a sub-range. Snaps the current value down if the shape change made it invalid.
void updateKreslingFoldHeightRange() {
  if (sKreslingUnits == null) return;
  float lo = 5;
  float hi = max(lo + 1, kreslingFoldHeightMax());
  sKreslingUnits.setRange(lo, hi);
  kreslingFoldHeight = constrain(kreslingFoldHeight, lo, hi);
  boolean prevSync = _syncingUI;
  _syncingUI = true;
  sKreslingUnits.setValue(kreslingFoldHeight);
  _syncingUI = prevSync;
}

void updateSidebarControlsVisibility() {
  if (sidebar == null || cp5__prism == null) return;
  
  int activeTab = sidebar.activeMainTab;
  
  // Shape controls (visible in tab 0)
  boolean shapeVisible = (activeTab == 0);
  if (sNSides != null) sNSides.setVisible(shapeVisible);
  if (btnSidesMinus != null) btnSidesMinus.setVisible(shapeVisible);
  if (btnSidesPlus != null) btnSidesPlus.setVisible(shapeVisible);
  if (sSideLen != null) sSideLen.setVisible(shapeVisible);
  if (sTopSize != null) sTopSize.setVisible(shapeVisible);
  if (sBotSize != null) sBotSize.setVisible(shapeVisible);
  if (tLock != null) tLock.setVisible(shapeVisible);
  // Kresling is its own mode — hide the other strip options that don't apply to it
  if (tHidePanelFolds != null) tHidePanelFolds.setVisible(shapeVisible && !kreslingMode);
  // Light gray cutting lines is hidden in workshop mode (and in Kresling mode)
  if (tLightGrayCutLines != null) tLightGrayCutLines.setVisible(shapeVisible && !workshopMode && !kreslingMode);
  if (tSplitStrip != null) tSplitStrip.setVisible(shapeVisible && !kreslingMode);
  if (tKresling != null) tKresling.setVisible(shapeVisible);
  if (sKreslingUnits != null) sKreslingUnits.setVisible(shapeVisible && kreslingMode);
  if (sKreslingSegments != null) sKreslingSegments.setVisible(shapeVisible && kreslingMode);
  // Hollow / double-wall mode is hidden in workshop mode (and in Kresling mode)
  if (tHollowMode != null) tHollowMode.setVisible(shapeVisible && !workshopMode && !kreslingMode);
  if (sWallThickness != null) sWallThickness.setVisible(shapeVisible && hollowMode);
  if (tEnableInnerShape != null) tEnableInnerShape.setVisible(shapeVisible && hollowMode);
  if (sInnerSides != null) sInnerSides.setVisible(shapeVisible && hollowMode && enableInnerShape);
  if (sInnerScale != null) sInnerScale.setVisible(shapeVisible && hollowMode && enableInnerShape);
  if (sInnerRotation != null) sInnerRotation.setVisible(shapeVisible && hollowMode && enableInnerShape);
  
  // Cuboid mode controls
  if (tCuboidMode != null) tCuboidMode.setVisible(shapeVisible && nSides == 4);
  if (shapeVisible) {
    setCuboidControlsVisible(cuboidMode);
  } else {
    if (sCubTopLen != null) sCubTopLen.setVisible(false);
    if (sCubTopWid != null) sCubTopWid.setVisible(false);
    if (sCubBotLen != null) sCubBotLen.setVisible(false);
    if (sCubBotWid != null) sCubBotWid.setVisible(false);
    if (tfCubTopLen != null) tfCubTopLen.setVisible(false);
    if (tfCubTopWid != null) tfCubTopWid.setVisible(false);
    if (tfCubBotLen != null) tfCubBotLen.setVisible(false);
    if (tfCubBotWid != null) tfCubBotWid.setVisible(false);
    if (tCubRatioLock != null) tCubRatioLock.setVisible(false);
    if (tCubAspectLock != null) tCubAspectLock.setVisible(false);
  }
  
  // Shape input textfields (also visible in tab 0, but respect cuboid mode)
  if (tfHeight != null) tfHeight.setVisible(shapeVisible);
  if (tfTopSize != null) tfTopSize.setVisible(shapeVisible && !cuboidMode);
  if (tfBotSize != null) tfBotSize.setVisible(shapeVisible && !cuboidMode);
  
  // View controls (visible in tab 2)
  boolean viewVisible = (activeTab == 2 && (sidebar == null || sidebar.activePrintTab == 0));
  int viewControlWidth = LEFT_SIDEBAR_WIDTH - 2*SIDEBAR_PADDING - 120;
  int row = 29;
  int startY = placementBaseY();  // clears the PAGE SIZE section (hidden in workshop mode)

  // Base plate tool controls (visible on Print → Base sub-tab)
  boolean baseVisible = (activeTab == 2 && sidebar != null && sidebar.activePrintTab == 2);
  {
    int baseX = SIDEBAR_PADDING;
    int baseW = LEFT_SIDEBAR_WIDTH - 2*SIDEBAR_PADDING;
    float baseCtrlY = (sidebar != null ? sidebar.contentY : TOOLBAR_HEIGHT) + SIDEBAR_PADDING + 31 + 12 + 60;

    // Toggles at fixed slots
    if (tBaseEnabled != null) {
      tBaseEnabled.setVisible(baseVisible);
      tBaseEnabled.setPosition(baseVisible ? baseX : -1000, baseVisible ? baseCtrlY : -1000);
    }
    if (tBaseOnly != null) {
      tBaseOnly.setVisible(baseVisible);
      tBaseOnly.setPosition(baseVisible ? baseX : -1000, baseVisible ? baseCtrlY + 28 : -1000);
    }
    if (tBaseBoxMode != null) {
      tBaseBoxMode.setVisible(baseVisible);
      tBaseBoxMode.setPosition(baseVisible ? baseX : -1000, baseVisible ? baseCtrlY + 56 : -1000);
    }
    if (tBaseTwoPlates != null) {
      tBaseTwoPlates.setVisible(baseVisible);            // works in both flat and box mode
      tBaseTwoPlates.setPosition(baseVisible ? baseX : -1000, baseVisible ? baseCtrlY + 84 : -1000);
    }
    if (tBaseFoldLine != null) {
      boolean vis = baseVisible && baseTwoPlates;
      tBaseFoldLine.setVisible(vis);
      tBaseFoldLine.setPosition(vis ? baseX : -1000, vis ? baseCtrlY + 112 : -1000);
    }
    if (tBaseSlitFree != null) {
      boolean vis = baseVisible && baseTwoPlates;   // slot below fold-line when two-plate
      float yy = vis ? baseCtrlY + 140 : baseCtrlY + 112;   // move up if fold-line row is hidden
      tBaseSlitFree.setVisible(baseVisible);
      tBaseSlitFree.setPosition(baseVisible ? baseX : -1000, baseVisible ? yy : -1000);
    }

    // Sliders — only the relevant ones for the current mode, stacked with no gaps
    Slider[] all = { sBaseWidth, sBaseLength, sBaseWallHeight, sBaseCorner, sBaseOffsetX, sBaseOffsetY };
    boolean[] vis = {
      baseVisible, baseVisible,
      baseVisible && baseBoxMode,      // wall height — box mode only
      baseVisible && !baseBoxMode,     // corner radius — flat plate only
      baseVisible, baseVisible
    };
    float by = (baseTwoPlates ? baseCtrlY + 172 : baseCtrlY + 144);
    for (int i = 0; i < all.length; i++) {
      if (all[i] == null) continue;
      all[i].setVisible(vis[i]);
      if (vis[i]) { all[i].setPosition(baseX, by); all[i].setSize(baseW, 20); by += row + 20; }
      else all[i].setPosition(-1000, -1000);
    }
  }

  if (sPatX != null) {
    sPatX.setVisible(viewVisible);
    if (viewVisible) {
      sPatX.setPosition(SIDEBAR_PADDING, startY + 0.5*row);
      sPatX.setSize(viewControlWidth, 20);
      sPatX.getCaptionLabel()
        .setFont(createFont("Arial", 15))
        .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
        .setPaddingX(0)
        .setPaddingY(6);
    } else {
      sPatX.setPosition(-1000, -1000);
    }
  }
  if (sPatY != null) {
    sPatY.setVisible(viewVisible);
    if (viewVisible) {
      sPatY.setPosition(SIDEBAR_PADDING, startY + 0.5*row + row + 20);
      sPatY.setSize(viewControlWidth, 20);
      sPatY.getCaptionLabel()
        .setFont(createFont("Arial", 15))
        .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
        .setPaddingX(0)
        .setPaddingY(6);
    } else {
      sPatY.setPosition(-1000, -1000);
    }
  }
  if (sStripRotation != null) {
    boolean stripVis = viewVisible && sideTextureMode == TEX_STRIP_BENT;
    sStripRotation.setVisible(stripVis);
    if (stripVis) {
      sStripRotation.setPosition(SIDEBAR_PADDING, startY + 0.5*row + 3*(row + 20));
      sStripRotation.setSize(viewControlWidth, 20);
      sStripRotation.getCaptionLabel()
        .setFont(createFont("Arial", 15))
        .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
        .setPaddingX(0)
        .setPaddingY(6);
    } else {
      sStripRotation.setPosition(-1000, -1000);
    }
  }
  if (sPatRotation != null) {
    sPatRotation.setVisible(viewVisible);
    if (viewVisible) {
      sPatRotation.setPosition(SIDEBAR_PADDING, startY + 0.5*row + 2*(row + 20));
      sPatRotation.setSize(viewControlWidth, 20);
      sPatRotation.getCaptionLabel()
        .setFont(createFont("Arial", 15))
        .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
        .setPaddingX(0)
        .setPaddingY(6);
    } else {
      sPatRotation.setPosition(-1000, -1000);
    }
  }
  if (sLidOffsetX != null) {
    sLidOffsetX.setVisible(viewVisible);
    if (viewVisible) {
      sLidOffsetX.setPosition(SIDEBAR_PADDING, startY + 0.5*row + 3*(row + 20));
      sLidOffsetX.setSize(viewControlWidth, 20);
      sLidOffsetX.setRange(-200, 200);  // Match pattern X range
      sLidOffsetX.getCaptionLabel()
        .setFont(createFont("Arial", 15))
        .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
        .setPaddingX(0)
        .setPaddingY(6);
    } else {
      sLidOffsetX.setPosition(-1000, -1000);
    }
  }
  if (sLidOffsetY != null) {
    sLidOffsetY.setVisible(viewVisible);
    if (viewVisible) {
      sLidOffsetY.setPosition(SIDEBAR_PADDING, startY + 0.5*row + 4*(row + 20));
      sLidOffsetY.setSize(viewControlWidth, 20);
      sLidOffsetY.setRange(-200, 200);  // Match pattern Y range
      sLidOffsetY.getCaptionLabel()
        .setFont(createFont("Arial", 15))
        .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
        .setPaddingX(0)
        .setPaddingY(6);
    } else {
      sLidOffsetY.setPosition(-1000, -1000);
    }
  }
  
  // Position independent lid movement buttons below lid offset sliders
  if (btnTopLidLeft != null) {
    btnTopLidLeft.setVisible(viewVisible);
    btnTopLidRight.setVisible(viewVisible);
    btnTopLidUp.setVisible(viewVisible);
    btnTopLidDown.setVisible(viewVisible);
    btnTopLidRotate.setVisible(viewVisible);
    btnBotLidLeft.setVisible(viewVisible);
    btnBotLidRight.setVisible(viewVisible);
    btnBotLidUp.setVisible(viewVisible);
    btnBotLidDown.setVisible(viewVisible);
    btnBotLidRotate.setVisible(viewVisible);
    
    // Inner wall buttons only visible in hollow mode
    boolean innerWallVisible = viewVisible && hollowMode;
    btnInnerWallLeft.setVisible(innerWallVisible);
    btnInnerWallRight.setVisible(innerWallVisible);
    btnInnerWallUp.setVisible(innerWallVisible);
    btnInnerWallDown.setVisible(innerWallVisible);
    
    if (viewVisible) {
      int btnSize = 26;
      int btnGap = 4;
      float baseY = startY + 0.5*row + 5*(row + 20) + 10;
      
      // Top lid D-pad pattern - centered cross
      float topCenterX = SIDEBAR_PADDING + btnSize + btnGap;
      
      btnTopLidUp.setPosition(topCenterX, baseY);                           // Up (center top)
      btnTopLidLeft.setPosition(SIDEBAR_PADDING, baseY + btnSize + btnGap); // Left
      btnTopLidRotate.setPosition(topCenterX, baseY + btnSize + btnGap);    // Rotate (center)
      btnTopLidRight.setPosition(topCenterX + btnSize + btnGap, baseY + btnSize + btnGap); // Right  
      btnTopLidDown.setPosition(topCenterX, baseY + 2*(btnSize + btnGap));  // Down (center bottom)
      
      // Bottom lid D-pad pattern - same layout, positioned to the right
      float botBaseX = SIDEBAR_PADDING + 3*(btnSize + btnGap) + 30; // Offset to the right
      float botCenterX = botBaseX + btnSize + btnGap;
      
      btnBotLidUp.setPosition(botCenterX, baseY);                           // Up (center top)
      btnBotLidLeft.setPosition(botBaseX, baseY + btnSize + btnGap);        // Left
      btnBotLidRotate.setPosition(botCenterX, baseY + btnSize + btnGap);    // Rotate (center)
      btnBotLidRight.setPosition(botCenterX + btnSize + btnGap, baseY + btnSize + btnGap); // Right
      btnBotLidDown.setPosition(botCenterX, baseY + 2*(btnSize + btnGap));  // Down (center bottom)
      
      // Inner wall D-pad pattern - positioned below the lid controls
      if (innerWallVisible) {
        float innerWallBaseY = baseY + 3*(btnSize + btnGap) + 20; // Below lid buttons
        float innerWallCenterX = SIDEBAR_PADDING + btnSize + btnGap;
        
        btnInnerWallUp.setPosition(innerWallCenterX, innerWallBaseY);                           
        btnInnerWallLeft.setPosition(SIDEBAR_PADDING, innerWallBaseY + btnSize + btnGap);        
        btnInnerWallRight.setPosition(innerWallCenterX + btnSize + btnGap, innerWallBaseY + btnSize + btnGap);
        btnInnerWallDown.setPosition(innerWallCenterX, innerWallBaseY + btnSize + btnGap);
      }
      
      // Split strip half D-pads - positioned below lid/inner wall controls
      boolean splitVisible = viewVisible && splitStrip;
      if (btnHalf1Left != null) {
        btnHalf1Left.setVisible(splitVisible);
        btnHalf1Right.setVisible(splitVisible);
        btnHalf1Up.setVisible(splitVisible);
        btnHalf1Down.setVisible(splitVisible);
        btnHalf1Rotate.setVisible(splitVisible);
        btnHalf2Left.setVisible(splitVisible);
        btnHalf2Right.setVisible(splitVisible);
        btnHalf2Up.setVisible(splitVisible);
        btnHalf2Down.setVisible(splitVisible);
        btnHalf2Rotate.setVisible(splitVisible);
        
        if (splitVisible) {
          float splitBaseY = baseY + 3*(btnSize + btnGap) + 20;
          if (innerWallVisible) splitBaseY += 2*(btnSize + btnGap) + 20;
          
          // Half 1 D-pad
          float h1CenterX = SIDEBAR_PADDING + btnSize + btnGap;
          btnHalf1Up.setPosition(h1CenterX, splitBaseY);
          btnHalf1Left.setPosition(SIDEBAR_PADDING, splitBaseY + btnSize + btnGap);
          btnHalf1Rotate.setPosition(h1CenterX, splitBaseY + btnSize + btnGap);
          btnHalf1Right.setPosition(h1CenterX + btnSize + btnGap, splitBaseY + btnSize + btnGap);
          btnHalf1Down.setPosition(h1CenterX, splitBaseY + 2*(btnSize + btnGap));
          
          // Half 2 D-pad
          float h2BaseX = SIDEBAR_PADDING + 3*(btnSize + btnGap) + 30;
          float h2CenterX = h2BaseX + btnSize + btnGap;
          btnHalf2Up.setPosition(h2CenterX, splitBaseY);
          btnHalf2Left.setPosition(h2BaseX, splitBaseY + btnSize + btnGap);
          btnHalf2Rotate.setPosition(h2CenterX, splitBaseY + btnSize + btnGap);
          btnHalf2Right.setPosition(h2CenterX + btnSize + btnGap, splitBaseY + btnSize + btnGap);
          btnHalf2Down.setPosition(h2CenterX, splitBaseY + 2*(btnSize + btnGap));
        } else {
          btnHalf1Left.setPosition(-1000, -1000); btnHalf1Right.setPosition(-1000, -1000);
          btnHalf1Up.setPosition(-1000, -1000); btnHalf1Down.setPosition(-1000, -1000);
          btnHalf1Rotate.setPosition(-1000, -1000);
          btnHalf2Left.setPosition(-1000, -1000); btnHalf2Right.setPosition(-1000, -1000);
          btnHalf2Up.setPosition(-1000, -1000); btnHalf2Down.setPosition(-1000, -1000);
          btnHalf2Rotate.setPosition(-1000, -1000);
        }
      }
    } else {
      btnTopLidLeft.setPosition(-1000, -1000);
      btnTopLidRight.setPosition(-1000, -1000);
      btnTopLidUp.setPosition(-1000, -1000);
      btnTopLidDown.setPosition(-1000, -1000);
      btnTopLidRotate.setPosition(-1000, -1000);
      btnBotLidLeft.setPosition(-1000, -1000);
      btnBotLidRight.setPosition(-1000, -1000);
      btnBotLidUp.setPosition(-1000, -1000);
      btnBotLidDown.setPosition(-1000, -1000);
      btnBotLidRotate.setPosition(-1000, -1000);
      btnInnerWallLeft.setPosition(-1000, -1000);
      btnInnerWallRight.setPosition(-1000, -1000);
      btnInnerWallUp.setPosition(-1000, -1000);
      btnInnerWallDown.setPosition(-1000, -1000);
    }
  }  // end if (btnTopLidLeft != null)
  
  // Print tab controls — repeat count
  // Placed below the lid d-pads (baseY + 3 button rows + margin)
  int btnSize3 = 26;
  int btnGap3 = 4;
  float baseYPrint = startY + 0.5*row + 5*(row + 20) + 10;
  float freePlaceY = baseYPrint + 3*(btnSize3 + btnGap3) + 25;
  if (hollowMode) freePlaceY += 2*(btnSize3 + btnGap3) + 20;
  if (splitStrip) freePlaceY += 3*(btnSize3 + btnGap3) + 20;
  boolean printVisible = (activeTab == 2 && (sidebar == null || sidebar.activePrintTab == 0));
  if (nRepNumbox != null) nRepNumbox.setVisible(printVisible);
  if (tFreePlacement != null) {
    tFreePlacement.setVisible(false);
    tFreePlacement.setPosition(-1000, -1000);
  }
  if (btnResetPlacement != null) {
    btnResetPlacement.setVisible(false);
    btnResetPlacement.setPosition(-1000, -1000);
  }
  if (nRepNumbox != null) {
    if (printVisible) {
      nRepNumbox.setPosition(SIDEBAR_PADDING, freePlaceY);
    } else {
      nRepNumbox.setPosition(-1000, -1000);
    }
  }
  if (tfNRep != null) {
    tfNRep.setVisible(printVisible);
    if (printVisible) {
      tfNRep.setPosition(SIDEBAR_PADDING + 108, freePlaceY);
    } else {
      tfNRep.setPosition(-1000, -1000);
    }
  }
  
  // Cutout controls (visible in Print tab, Cutouts sub-tab only)
  boolean cutoutVisible = (activeTab == 2 && sidebar != null && sidebar.activePrintTab == 1);
  if (nbCutoutX != null) {
    // X/Y numberboxes are superseded by the Move sliders — keep them updated but off-screen.
    nbCutoutX.setVisible(false);
    nbCutoutY.setVisible(false);
    nbCutoutX.setPosition(-1000, -1000);
    nbCutoutY.setPosition(-1000, -1000);
    // Radius numberbox stays.
    nbCutoutCornerR.setVisible(cutoutVisible);
    if (cutoutVisible) {
      int cutY2 = TOOLBAR_HEIGHT + 810;
      nbCutoutCornerR.setPosition(SIDEBAR_PADDING, cutY2);
    } else {
      nbCutoutCornerR.setPosition(-1000, -1000);
    }
  }
  if (sCutoutX != null) {
    sCutoutX.setVisible(cutoutVisible);
    sCutoutY.setVisible(cutoutVisible);
    if (cutoutVisible) {
      sCutoutX.setPosition(SIDEBAR_PADDING, TOOLBAR_HEIGHT + 720);
      sCutoutY.setPosition(SIDEBAR_PADDING, TOOLBAR_HEIGHT + 762);
    } else {
      sCutoutX.setPosition(-1000, -1000);
      sCutoutY.setPosition(-1000, -1000);
    }
  }
}
// Guard flag: when true, controlEvent handlers must not fire (set during syncUIToSelectedShape)
boolean _syncingUI = false;

// Responds to user interactions with UI controls

void controlEvent(ControlEvent e) {
  // Suppress all callbacks while syncing sliders to a new selected shape
  if (_syncingUI) return;
  // Always resync uiLock from the actual toggle button — it is the ground truth
  // (loadGlobalsFrom in the draw loop may have loaded a stale stored value)
  if (tLock != null) uiLock = tLock.getState();
  
  // --- Shape Control Events ---
  if (e.isFrom(btnSidesMinus)) {
    uiSides = max(3, uiSides - 1);
    sNSides.setValue(uiSides);
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(btnSidesPlus)) {
    uiSides = min(30, uiSides + 1);
    sNSides.setValue(uiSides);
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sNSides)) {
    uiSides = round(sNSides.getValue());
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sSideLen)) {
    uiHeight = sSideLen.getValue();
    if (tfHeight != null) tfHeight.setText(nf(uiHeight, 0, 1));
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(tLock)) {
    uiLock = tLock.getState();
    if (uiLock) {
      uiBotW = uiTopW;
      sBotSize.setValue(uiBotW);
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sPanelW)) {
    float panelWidthMillimeters = sPanelW.getValue();
    // zet top op nieuwe breedte
    uiTopW = panelWidthMillimeters;
    uiBotW = panelWidthMillimeters;
    sBotSize.setValue(uiBotW);

    sTopSize.setValue(uiTopW);

    // als lock aan staat, neem bottom mee
    if (uiLock) {
      uiBotW = panelWidthMillimeters;
      sBotSize.setValue(uiBotW);
    }

    applyToModel();
    refreshLabels();
    return;
  }

  if (e.isFrom(sTopSize)) {
    uiTopW = sTopSize.getValue();
    if (tfTopSize != null) tfTopSize.setText(nf(uiTopW, 0, 1));
    if (uiLock) {
      uiBotW = uiTopW;
      _syncingUI = true;
      if (sBotSize != null) sBotSize.setValue(uiBotW);
      if (tfBotSize != null) tfBotSize.setText(nf(uiBotW, 0, 1));
      _syncingUI = false;
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sBotSize)) {
    uiBotW = sBotSize.getValue();
    if (tfBotSize != null) tfBotSize.setText(nf(uiBotW, 0, 1));
    if (uiLock) {
      uiTopW = uiBotW;
      _syncingUI = true;
      if (sTopSize != null) sTopSize.setValue(uiTopW);
      if (tfTopSize != null) tfTopSize.setText(nf(uiTopW, 0, 1));
      _syncingUI = false;
    }
    applyToModel();
    refreshLabels();
    return;
  }
  // --- Cuboid Mode Events ---
  if (e.isFrom(tCuboidMode)) {
    cuboidMode = tCuboidMode.getState();
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sCubTopLen)) {
    uiCubTopLen = sCubTopLen.getValue();
    if (tfCubTopLen != null) tfCubTopLen.setText(nf(uiCubTopLen, 0, 1));
    if (uiCubRatioLock) {
      uiCubBotLen = uiCubTopLen;
      sCubBotLen.setValue(uiCubBotLen);
      if (tfCubBotLen != null) tfCubBotLen.setText(nf(uiCubBotLen, 0, 1));
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sCubTopWid)) {
    uiCubTopWid = sCubTopWid.getValue();
    if (tfCubTopWid != null) tfCubTopWid.setText(nf(uiCubTopWid, 0, 1));
    if (uiCubRatioLock) {
      uiCubBotWid = uiCubTopWid;
      sCubBotWid.setValue(uiCubBotWid);
      if (tfCubBotWid != null) tfCubBotWid.setText(nf(uiCubBotWid, 0, 1));
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sCubBotLen)) {
    uiCubBotLen = sCubBotLen.getValue();
    if (tfCubBotLen != null) tfCubBotLen.setText(nf(uiCubBotLen, 0, 1));
    if (uiCubRatioLock) {
      uiCubTopLen = uiCubBotLen;
      sCubTopLen.setValue(uiCubTopLen);
      if (tfCubTopLen != null) tfCubTopLen.setText(nf(uiCubTopLen, 0, 1));
    }
    if (uiCubAspectLock && uiCubTopLen > 0) {
      float ratio = uiCubTopWid / uiCubTopLen;
      uiCubBotWid = constrain(uiCubBotLen * ratio, 1, 120);
      sCubBotWid.setValue(uiCubBotWid);
      if (tfCubBotWid != null) tfCubBotWid.setText(nf(uiCubBotWid, 0, 1));
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sCubBotWid)) {
    uiCubBotWid = sCubBotWid.getValue();
    if (tfCubBotWid != null) tfCubBotWid.setText(nf(uiCubBotWid, 0, 1));
    if (uiCubRatioLock) {
      uiCubTopWid = uiCubBotWid;
      sCubTopWid.setValue(uiCubTopWid);
      if (tfCubTopWid != null) tfCubTopWid.setText(nf(uiCubTopWid, 0, 1));
    }
    if (uiCubAspectLock && uiCubTopWid > 0) {
      float ratio = uiCubTopLen / uiCubTopWid;
      uiCubBotLen = constrain(uiCubBotWid * ratio, 1, 120);
      sCubBotLen.setValue(uiCubBotLen);
      if (tfCubBotLen != null) tfCubBotLen.setText(nf(uiCubBotLen, 0, 1));
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(tCubRatioLock)) {
    uiCubRatioLock = tCubRatioLock.getState();
    if (uiCubRatioLock) {
      uiCubAspectLock = false;
      if (tCubAspectLock != null) tCubAspectLock.setValue(0);
      uiCubBotLen = uiCubTopLen;
      uiCubBotWid = uiCubTopWid;
      sCubBotLen.setValue(uiCubBotLen);
      sCubBotWid.setValue(uiCubBotWid);
      if (tfCubBotLen != null) tfCubBotLen.setText(nf(uiCubBotLen, 0, 1));
      if (tfCubBotWid != null) tfCubBotWid.setText(nf(uiCubBotWid, 0, 1));
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(tCubAspectLock)) {
    uiCubAspectLock = tCubAspectLock.getState();
    if (uiCubAspectLock) {
      uiCubRatioLock = false;
      if (tCubRatioLock != null) tCubRatioLock.setValue(0);
      if (uiCubTopLen > 0) {
        float ratio = uiCubTopWid / uiCubTopLen;
        uiCubBotWid = constrain(uiCubBotLen * ratio, 1, 120);
        sCubBotWid.setValue(uiCubBotWid);
        if (tfCubBotWid != null) tfCubBotWid.setText(nf(uiCubBotWid, 0, 1));
      }
    }
    applyToModel();
    refreshLabels();
    return;
  }
  // --- Cuboid Textfield Events ---
  if (e.isFrom(tfCubTopLen)) {
    try {
      float val = Float.parseFloat(tfCubTopLen.getText());
      val = constrain(val, 1, 120);
      uiCubTopLen = val;
      sCubTopLen.setValue(val);
      tfCubTopLen.setText(nf(val, 0, 1));
      if (uiCubRatioLock) {
        uiCubBotLen = val;
        sCubBotLen.setValue(val);
        if (tfCubBotLen != null) tfCubBotLen.setText(nf(val, 0, 1));
      }
      applyToModel();
      refreshLabels();
    } catch (Exception ex) { tfCubTopLen.setText(nf(uiCubTopLen, 0, 1)); }
    return;
  }
  if (e.isFrom(tfCubTopWid)) {
    try {
      float val = Float.parseFloat(tfCubTopWid.getText());
      val = constrain(val, 1, 120);
      uiCubTopWid = val;
      sCubTopWid.setValue(val);
      tfCubTopWid.setText(nf(val, 0, 1));
      if (uiCubRatioLock) {
        uiCubBotWid = val;
        sCubBotWid.setValue(val);
        if (tfCubBotWid != null) tfCubBotWid.setText(nf(val, 0, 1));
      }
      applyToModel();
      refreshLabels();
    } catch (Exception ex) { tfCubTopWid.setText(nf(uiCubTopWid, 0, 1)); }
    return;
  }
  if (e.isFrom(tfCubBotLen)) {
    try {
      float val = Float.parseFloat(tfCubBotLen.getText());
      val = constrain(val, 1, 120);
      uiCubBotLen = val;
      sCubBotLen.setValue(val);
      tfCubBotLen.setText(nf(val, 0, 1));
      if (uiCubRatioLock) {
        uiCubTopLen = val;
        sCubTopLen.setValue(val);
        if (tfCubTopLen != null) tfCubTopLen.setText(nf(val, 0, 1));
      }
      applyToModel();
      refreshLabels();
    } catch (Exception ex) { tfCubBotLen.setText(nf(uiCubBotLen, 0, 1)); }
    return;
  }
  if (e.isFrom(tfCubBotWid)) {
    try {
      float val = Float.parseFloat(tfCubBotWid.getText());
      val = constrain(val, 1, 120);
      uiCubBotWid = val;
      sCubBotWid.setValue(val);
      tfCubBotWid.setText(nf(val, 0, 1));
      if (uiCubRatioLock) {
        uiCubTopWid = val;
        sCubTopWid.setValue(val);
        if (tfCubTopWid != null) tfCubTopWid.setText(nf(val, 0, 1));
      }
      applyToModel();
      refreshLabels();
    } catch (Exception ex) { tfCubBotWid.setText(nf(uiCubBotWid, 0, 1)); }
    return;
  }
  if (e.isFrom(tPerimLock)) {
    uiPerimLock = tPerimLock.getState();

    // bij aanzetten: “bevries” op huidige top-perimeter (de strip-lengte)
    if (uiPerimLock) {
      uiPerim = max(1, uiSides * uiTopW);
      sTotalLen.setValue(uiPerim);
      // forceer directe herberekening volgens lock
      uiTopW = uiPerim / uiSides;
      sTopSize.setValue(uiTopW);
      sPanelW.setValue(uiTopW);
      if (uiLock) {
        uiBotW = uiTopW;
        sBotSize.setValue(uiBotW);
      }
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sTotalLen)) {
    uiPerim = max(1, sTotalLen.getValue());
    if (uiPerimLock) {
      // herverdeel over huidige n
      uiTopW = uiPerim / uiSides;
      sTopSize.setValue(uiTopW);
      sPanelW.setValue(uiTopW);
      if (uiLock) {
        uiBotW = uiTopW;
        sBotSize.setValue(uiBotW);
      }
      applyToModel();
      refreshLabels();
    }
    return;
  }
  if (e.isFrom(sNSides)) {
    uiSides = round(sNSides.getValue());

    if (uiPerimLock) {
      // herbereken paneelbreedte zodat n * breedte = uiPerim
      uiTopW = max(1, uiPerim / uiSides);
      sTopSize.setValue(uiTopW);
      sPanelW.setValue(uiTopW);
      if (uiLock) {
        uiBotW = uiTopW;
        sBotSize.setValue(uiBotW);
      }
    }
    applyToModel();
    refreshLabels();
    return;
  }
  if (e.isFrom(sPanelW) || e.isFrom(sTopSize)) {
    float edgeWidthMillimeters = (e.isFrom(sPanelW) ? sPanelW.getValue() : sTopSize.getValue());

    if (uiPerimLock) {
      // herleid n = round(L / w), begrens 3..30
      int newNumberOfSides = constrain(round(uiPerim / max(1, edgeWidthMillimeters)), 3, 30);
      uiSides = newNumberOfSides;
      sNSides.setValue(uiSides);

      // “quantize” breedte terug naar exact uiPerim/uiSides om drift te voorkomen
      uiTopW = uiPerim / uiSides;
      sTopSize.setValue(uiTopW);
      sPanelW.setValue(uiTopW);

      if (uiLock) {
        uiBotW = uiTopW;
        sBotSize.setValue(uiBotW);
      }
    } else {
      // geen perimeter lock: normale flow
      uiTopW = edgeWidthMillimeters;
      sTopSize.setValue(uiTopW);
      if (uiLock) {
        uiBotW = edgeWidthMillimeters;
        sBotSize.setValue(uiBotW);
      }
    }

    applyToModel();
    refreshLabels();
    return;
  }




  //-----------------------------ADVANCED SECTION --------------------------------------
  if (e.isFrom(tAdvanced)) {
    uiAdvanced = tAdvanced.getState();
    setAdvancedVisible(uiAdvanced);
    return;
  }
  if (e.isFrom(tHidePanelFolds)) {
    uiHidePanelFolds = tHidePanelFolds.getState();
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(tLightGrayCutLines)) {
    uiLightGrayCutLines = tLightGrayCutLines.getState();
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sTabDepth)) {
    tabDepth      = max(0, sTabDepth.getValue());
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sFlapDepth)) {
    flapDepth     = max(0, sFlapDepth.getValue());
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sFlapTaper)) {
    flapTaper     = max(0, sFlapTaper.getValue());
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sTabNeckRatio)) {
    tab_neck_ratio= constrain(sTabNeckRatio.getValue(), 0.2, 1.5);
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sDash)) {
    dash          = max(0.5f, sDash.getValue());
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  
  // --- Hollow Mode Events ---
  if (e.isFrom(tSplitStrip)) {
    splitStrip = tSplitStrip.getState();
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(tKresling)) {
    kreslingMode = tKresling.getState();
    if (kreslingMode) {
      // Kresling needs the single strip with its folds visible — turn off the options
      // we're hiding so they can't leave the strip in an incompatible state.
      splitStrip = false;
      uiHidePanelFolds = false;
      boolean prevSync = _syncingUI;
      _syncingUI = true;
      if (tSplitStrip != null) tSplitStrip.setValue(0);
      if (tHidePanelFolds != null) tHidePanelFolds.setValue(0);
      _syncingUI = prevSync;
      setParams(false);
      updateKreslingFoldHeightRange();  // fit the slider to the current shape
    }
    updateSidebarControlsVisibility();  // apply show/hide of the affected controls
    layoutSecondaryToggles();           // move Kresling controls up / restore the grid
    redraw();
    return;
  }
  if (e.isFrom(sKreslingUnits)) {
    kreslingFoldHeight = sKreslingUnits.getValue();
    redraw();
    return;
  }
  if (e.isFrom(sKreslingSegments)) {
    kreslingSegments = (int) sKreslingSegments.getValue();
    redraw();
    return;
  }
  if (e.isFrom(tHollowMode)) {
    hollowMode = tHollowMode.getState();
    // Toggle visibility of hollow mode sliders (only if in Shape tab)
    boolean shapeVisible = (sidebar.activeMainTab == 0);
    if (sWallThickness != null) sWallThickness.setVisible(hollowMode && shapeVisible);
    if (tEnableInnerShape != null) tEnableInnerShape.setVisible(hollowMode && shapeVisible);
    if (sInnerSides != null) sInnerSides.setVisible(hollowMode && enableInnerShape && shapeVisible);
    if (sInnerScale != null) sInnerScale.setVisible(hollowMode && enableInnerShape && shapeVisible);
    if (sInnerRotation != null) sInnerRotation.setVisible(hollowMode && enableInnerShape && shapeVisible);
    // Validate parameters
    if (hollowMode && !validateHollowModeParameters()) {
      println("[WARNING] Hollow mode parameters are invalid for current geometry");
    }
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sWallThickness)) {
    wallThickness = max(1.0, min(20.0, sWallThickness.getValue()));
    // Validate that wall thickness isn't too large
    if (!validateHollowModeParameters()) {
      println("[WARNING] Wall thickness too large for current polygon size");
    }
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  
  // --- Inner Shape Events ---
  if (e.isFrom(tEnableInnerShape)) {
    enableInnerShape = tEnableInnerShape.getState();
    // Toggle visibility of inner shape sliders (only if in Shape tab and hollow mode is on)
    boolean shapeVisible = (sidebar.activeMainTab == 0);
    if (sInnerSides != null) sInnerSides.setVisible(hollowMode && enableInnerShape && shapeVisible);
    if (sInnerScale != null) sInnerScale.setVisible(hollowMode && enableInnerShape && shapeVisible);
    if (sInnerRotation != null) sInnerRotation.setVisible(hollowMode && enableInnerShape && shapeVisible);
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sInnerSides)) {
    nSidesInner = round(sInnerSides.getValue());
    nSidesInner = constrain(nSidesInner, 3, 10);
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sInnerScale)) {
    innerShapeScale = max(0.3, min(0.8, sInnerScale.getValue()));
    // Validate that inner shape fits inside outer
    if (!validateHollowModeParameters()) {
      println("[WARNING] Inner shape too large or doesn't fit properly");
    }
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sInnerRotation)) {
    innerShapeRotation = sInnerRotation.getValue();
    innerShapeRotation = innerShapeRotation % 360; // Keep in 0-360 range
    setParams(false);
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  
  if (e.isFrom(sPatX)) {
    patX = sPatX.getValue();
    setParams(false);
    redraw();
    return;
  }
  if (e.isFrom(sPatY)) {
    patY = sPatY.getValue();
    setParams(false);
    redraw();
    return;
  }
  if (e.isFrom(sPatRotation)) {
    patRotation = sPatRotation.getValue();
    redraw();
    return;
  }
  if (e.isFrom(sLidOffsetX)) {
    uiLidOffsetX = sLidOffsetX.getValue();
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  if (e.isFrom(sLidOffsetY)) {
    uiLidOffsetY = sLidOffsetY.getValue();
    if (shapes != null && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    redraw();
    return;
  }
  // --- Base plate tool ---
  if (e.isFrom(tBaseEnabled)) { baseEnabled = tBaseEnabled.getState(); redraw(); return; }
  if (e.isFrom(tBaseTwoPlates)) { baseTwoPlates = tBaseTwoPlates.getState(); updateSidebarControlsVisibility(); redraw(); return; }
  if (e.isFrom(tBaseFoldLine)) { baseFoldLine = tBaseFoldLine.getState(); redraw(); return; }
  if (e.isFrom(tBaseBoxMode)) { baseBoxMode = tBaseBoxMode.getState(); updateSidebarControlsVisibility(); redraw(); return; }
  if (e.isFrom(tBaseOnly)) { baseOnly = tBaseOnly.getState(); redraw(); return; }
  if (e.isFrom(tBaseSlitFree)) { baseSlitFreePlace = tBaseSlitFree.getState(); redraw(); return; }
  if (e.isFrom(sBaseWallHeight)) { baseWallHeightMM = sBaseWallHeight.getValue(); redraw(); return; }
  if (e.isFrom(sBaseWidth))   { baseWidthMM  = sBaseWidth.getValue();   redraw(); return; }
  if (e.isFrom(sBaseLength))  { baseLengthMM = sBaseLength.getValue();  redraw(); return; }
  if (e.isFrom(sBaseOffsetX)) { baseOffsetX  = sBaseOffsetX.getValue(); redraw(); return; }
  if (e.isFrom(sBaseOffsetY)) { baseOffsetY  = sBaseOffsetY.getValue(); redraw(); return; }
  if (e.isFrom(sBaseCorner))  { baseCornerRadiusMM = sBaseCorner.getValue(); redraw(); return; }
  
  // Note: Lid movement buttons now use direct mouse detection in checkLidButtonPress()
  // for proper hold-and-drag functionality
  
  if (e.isFrom(sTessDensity)) {
    uiTessDensity = round(sTessDensity.getValue());
    setParams(false);  // update global tessellationDensity
    redraw();
    return;
  }
  if (e.isFrom(sStripRotation)) {
    uiStripRotation = sStripRotation.getValue();
    // updateStripRotation() rebuilds the bitmap at the top of the next draw()
    if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
      shapes.get(selectedShapeIdx).stripRotation = uiStripRotation;
    }
    redraw();
    return;
  }
  if (e.isFrom(sTextureMode)) {
    uiTextureMode = round(sTextureMode.getValue());
    // Update global texture mode
    if (uiTextureMode == 0) {
      sideTextureMode = TEX_NONE;  // No texture
    } else if (uiTextureMode == 1) {
      sideTextureMode = TEX_PER_PANEL;  // Per-panel
    } else {
      sideTextureMode = TEX_STRIP_BENT;  // Strip
    }
    redraw();
    return;
  }
  if (e.isFrom(tShowLidTextures)) {
    uiShowLidTextures = tShowLidTextures.getState();
    redraw();
    return;
  }
  
  if (e.isFrom(tShowTessellationMesh)) {
    uiShowTessellationMesh = tShowTessellationMesh.getState();
    redraw();
    return;
  }
  
  if (e.isFrom(tView3D)) {
    view3DMode = tView3D.getState();
    // Update label to match state
    tView3D.setLabel(view3DMode ? "View in 2D" : "View in 3D");
    toolbar.update();
    // updateViewPresetButtonsVisibility();  // Commented out
    redraw();
    return;
  }
  
  /* View preset button handlers (commented out for now)
  if (btnViewTop != null) {
    if (e.isFrom(btnViewTop)) {
      setViewPreset("Top");
      return;
    }
    if (e.isFrom(btnViewFront)) {
      setViewPreset("Bottom");
      return;
    }
    if (e.isFrom(btnViewRight)) {
      setViewPreset("Side");
      return;
    }
    if (e.isFrom(btnViewIso)) {
      setViewPreset("Isometric");
      return;
    }
  }
  */
  
  // Export button handler
  if (e.isFrom(btnExportMain)) {
    uiExportFilename = tfExportFilename.getText();
    bSavePDF = true;
    println("[Export] Exporting with filename: " + uiExportFilename);
    return;
  }
  
  // Export filename text field handler
  if (e.isFrom(tfExportFilename)) {
    uiExportFilename = tfExportFilename.getText();
    return;
  }
  
  // --- Cutout position controls ---
  if (sCutoutX != null && e.isFrom(sCutoutX)) {
    if (selectedCutoutIndex >= 0 && selectedCutoutIndex < cutouts.size()) {
      cutouts.get(selectedCutoutIndex).x_mm = sCutoutX.getValue();
      if (nbCutoutX != null) { _syncingUI = true; nbCutoutX.setValue(sCutoutX.getValue()); _syncingUI = false; }
    }
    redraw();
    return;
  }
  if (sCutoutY != null && e.isFrom(sCutoutY)) {
    if (selectedCutoutIndex >= 0 && selectedCutoutIndex < cutouts.size()) {
      cutouts.get(selectedCutoutIndex).y_mm = sCutoutY.getValue();
      if (nbCutoutY != null) { _syncingUI = true; nbCutoutY.setValue(sCutoutY.getValue()); _syncingUI = false; }
    }
    redraw();
    return;
  }
  if (nbCutoutX != null && e.isFrom(nbCutoutX)) {
    if (selectedCutoutIndex >= 0 && selectedCutoutIndex < cutouts.size()) {
      cutouts.get(selectedCutoutIndex).x_mm = nbCutoutX.getValue();
    }
    redraw();
    return;
  }
  if (nbCutoutY != null && e.isFrom(nbCutoutY)) {
    if (selectedCutoutIndex >= 0 && selectedCutoutIndex < cutouts.size()) {
      cutouts.get(selectedCutoutIndex).y_mm = nbCutoutY.getValue();
    }
    redraw();
    return;
  }
  if (nbCutoutCornerR != null && e.isFrom(nbCutoutCornerR)) {
    cutoutCornerRadius = nbCutoutCornerR.getValue();
    // Update all cutouts with new corner radius
    for (Cutout c : cutouts) {
      c.cornerRadius_mm = cutoutCornerRadius;
    }
    redraw();
    return;
  }
  
  // Size textfield handlers - update sliders and model when user types exact values
  if (e.isFrom(tfHeight)) {
    try {
      float val = Float.parseFloat(tfHeight.getText());
      val = constrain(val, 1, 120);
      uiHeight = val;
      sSideLen.setValue(val);
      tfHeight.setText(nf(val, 0, 1));
      applyToModel();
      refreshLabels();
      redraw();
    } catch (Exception ex) {
      tfHeight.setText(nf(uiHeight, 0, 1));
    }
    return;
  }
  
  if (e.isFrom(tfTopSize)) {
    try {
      float val = Float.parseFloat(tfTopSize.getText());
      val = constrain(val, 1, 120);
      uiTopW = val;
      sTopSize.setValue(val);
      tfTopSize.setText(nf(val, 0, 1));
      if (uiLock) {
        uiBotW = val;
        sBotSize.setValue(val);
        tfBotSize.setText(nf(val, 0, 1));
      }
      applyToModel();
      refreshLabels();
      redraw();
    } catch (Exception ex) {
      tfTopSize.setText(nf(uiTopW, 0, 1));
    }
    return;
  }
  
  if (e.isFrom(tfBotSize)) {
    try {
      float val = Float.parseFloat(tfBotSize.getText());
      val = constrain(val, 1, 120);
      uiBotW = val;
      sBotSize.setValue(val);
      tfBotSize.setText(nf(val, 0, 1));
      if (uiLock) {
        uiTopW = val;
        sTopSize.setValue(val);
        tfTopSize.setText(nf(val, 0, 1));
      }
      applyToModel();
      refreshLabels();
      redraw();
    } catch (Exception ex) {
      tfBotSize.setText(nf(uiBotW, 0, 1));
    }
    return;
  }
  
  //--RH-- Fiducial Marker Event Handlers
  if (e.isFrom(tEnableMarkers)) {
    markersEnabled = tEnableMarkers.getState();
    if (markersEnabled && m == null) {
      // Lazy load markers when first enabled
      initMarkers("aruco1024_px.png");
    }
    redraw();
    return;
  }
  if (e.isFrom(tMarkerFreePlace)) {
    markerFreePlace = tMarkerFreePlace.getState();
    redraw();
    return;
  }
  if (e.isFrom(tShowDistances)) {
    showDistances = tShowDistances.getState();
    redraw();
    return;
  }
  if (e.isFrom(tAutoMarkerIDs)) {
    autoMarkerIDs = tAutoMarkerIDs.getState();
    redraw();
    return;
  }
  
  if (e.isController()) {
    String name = e.getController().getName();
    if (name.equals("marker_size")) {
      Marker_Size = int(e.getValue());
      redraw();
      return;
    }
    if (name.equals("marker_grid")) {
      markerGrid = max(1, int(e.getValue()));
      redraw();
      return;
    }
    if (name.equals("marker_id_start")) {
      Start_Index = int(e.getValue());
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size())
        shapes.get(selectedShapeIdx).markerStartIndex = Start_Index;
      if (tfMarkerID != null) {
        tfMarkerID.setText(str(Start_Index));
      }
      redraw();
      return;
    }
    if (name.equals("n_repeat")) {
      nRep = max(1, int(e.getValue()));
      if (tfNRep != null) tfNRep.setText(str(nRep));
      // Sync to selected shape and reset free placement positions
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
        shapes.get(selectedShapeIdx).nRep = nRep;
        if (freePlacementMode) initRepPositions();
      }
      redraw();
      return;
    }
  }
  //--RH--
  
  if (e.isFrom(tFreePlacement)) {
    freePlacementMode = tFreePlacement.getState();
    if (freePlacementMode) {
      // Initialise positions for ALL shapes
      if (shapes != null) {
        for (int _si = 0; _si < shapes.size(); _si++) {
          ShapeSpec _fs = shapes.get(_si);
          if (_fs.repPositions == null) {
            loadGlobalsFrom(_fs);
            setParams(false);
            initRepPositionsForShape(_fs);
          }
        }
        // Restore selected shape
        loadGlobalsFrom(shapes.get(selectedShapeIdx));
        setParams(false);
      }
      initRepPositions(); // also refresh global repPositions
    } else {
      repPositions = null;
      draggedShapeIdx = -1;
      draggedRepIdx   = -1;
      // Clear per-shape positions too
      if (shapes != null) {
        for (ShapeSpec _cs : shapes) _cs.repPositions = null;
      }
    }
    if (btnResetPlacement != null) btnResetPlacement.setVisible(freePlacementMode);
    redraw();
    return;
  }
  
  if (e.isFrom(btnResetPlacement)) {
    // Reset positions for ALL shapes
    if (shapes != null) {
      for (int _ri = 0; _ri < shapes.size(); _ri++) {
        ShapeSpec _rs = shapes.get(_ri);
        loadGlobalsFrom(_rs);
        setParams(false);
        initRepPositionsForShape(_rs);
      }
      loadGlobalsFrom(shapes.get(selectedShapeIdx));
      setParams(false);
    } else {
      initRepPositions();
    }
    redraw();
    return;
  }
  
  if (e.isFrom(tfNRep)) {
    try {
      int val = int(tfNRep.getText());
      val = constrain(val, 1, 16);
      nRep = val;
      nRepNumbox.setValue(val);
      tfNRep.setText(str(val));
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
        shapes.get(selectedShapeIdx).nRep = nRep;
      }
      if (freePlacementMode) initRepPositions();
      redraw();
    } catch (Exception ex) {
      tfNRep.setText(str(nRep));
    }
    return;
  }
  
  // Marker ID textfield handler - update slider and variable when user types exact values
  if (e.isFrom(tfMarkerID)) {
    try {
      int val = int(tfMarkerID.getText());
      val = constrain(val, 0, 255);
      Start_Index = val;
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size())
        shapes.get(selectedShapeIdx).markerStartIndex = val;
      m_idNumbox.setValue(val);
      tfMarkerID.setText(str(val));
      redraw();
    } catch (Exception ex) {
      tfMarkerID.setText(str(Start_Index));
    }
    return;
  }
  
  // Marker Size textfield handler - update slider and variable when user types exact values
  if (e.isFrom(tfMarkerSize)) {
    try {
      int val = int(tfMarkerSize.getText());
      val = constrain(val, 5, 50);
      Marker_Size = val;
      m_sizeNumbox.setValue(val);
      tfMarkerSize.setText(str(val));
      redraw();
    } catch (Exception ex) {
      tfMarkerSize.setText(str(Marker_Size));
    }
    return;
  }
  //--RH--
}

//------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Sync all CP5 sliders/toggles to reflect the currently selected ShapeSpec.
// Call this whenever selectedShapeIdx changes.
// ---------------------------------------------------------------------------
void syncUIToSelectedShape() {
  if (shapes == null || shapes.size() == 0 || cp5__prism == null) return;
  ShapeSpec _ss = shapes.get(selectedShapeIdx);
  loadGlobalsFrom(_ss);
  setParams(false);

  _syncingUI = true;  // suppress controlEvent callbacks while updating sliders
  try {
    if (sNSides        != null) sNSides.setValue(uiSides);
    if (sSideLen       != null) sSideLen.setValue(uiHeight);
    if (sTopSize       != null) sTopSize.setValue(uiTopW);
    if (sBotSize       != null) sBotSize.setValue(uiBotW);
    if (tLock          != null) tLock.setValue(uiLock ? 1 : 0);
    if (tHidePanelFolds    != null) tHidePanelFolds.setValue(uiHidePanelFolds ? 1 : 0);
    if (tLightGrayCutLines != null) tLightGrayCutLines.setValue(uiLightGrayCutLines ? 1 : 0);
    if (tSplitStrip    != null) tSplitStrip.setValue(splitStrip ? 1 : 0);
    if (tKresling      != null) tKresling.setValue(kreslingMode ? 1 : 0);
    if (sKreslingUnits != null) sKreslingUnits.setValue(kreslingFoldHeight);
    if (sKreslingSegments != null) sKreslingSegments.setValue(kreslingSegments);
    if (tHollowMode    != null) tHollowMode.setValue(hollowMode ? 1 : 0);
    if (sWallThickness != null) sWallThickness.setValue(wallThickness);
    if (tEnableInnerShape != null) tEnableInnerShape.setValue(enableInnerShape ? 1 : 0);
    if (sInnerSides    != null) sInnerSides.setValue(nSidesInner);
    if (sInnerScale    != null) sInnerScale.setValue(innerShapeScale);
    if (sInnerRotation != null) sInnerRotation.setValue(innerShapeRotation);
    // Cuboid mode
    if (tCuboidMode    != null) tCuboidMode.setValue(cuboidMode ? 1 : 0);
    if (sCubTopLen     != null) sCubTopLen.setValue(uiCubTopLen);
    if (sCubTopWid     != null) sCubTopWid.setValue(uiCubTopWid);
    if (sCubBotLen     != null) sCubBotLen.setValue(uiCubBotLen);
    if (sCubBotWid     != null) sCubBotWid.setValue(uiCubBotWid);
    if (tCubRatioLock  != null) tCubRatioLock.setValue(uiCubRatioLock ? 1 : 0);
    if (tCubAspectLock != null) tCubAspectLock.setValue(uiCubAspectLock ? 1 : 0);
    if (tfCubTopLen    != null) tfCubTopLen.setText(nf(uiCubTopLen, 0, 1));
    if (tfCubTopWid    != null) tfCubTopWid.setText(nf(uiCubTopWid, 0, 1));
    if (tfCubBotLen    != null) tfCubBotLen.setText(nf(uiCubBotLen, 0, 1));
    if (tfCubBotWid    != null) tfCubBotWid.setText(nf(uiCubBotWid, 0, 1));
    if (tfHeight   != null) tfHeight.setText(nf(uiHeight, 0, 1));
    if (tfTopSize  != null) tfTopSize.setText(nf(uiTopW, 0, 1));
    if (tfBotSize  != null) tfBotSize.setText(nf(uiBotW, 0, 1));
    // Repeat count (Print tab)
    if (nRepNumbox != null) nRepNumbox.setValue(nRep);
    if (tfNRep     != null) tfNRep.setText(str(nRep));
    // Marker ID (per-shape)
    if (m_idNumbox != null) m_idNumbox.setValue(_ss.markerStartIndex);
    if (tfMarkerID != null) tfMarkerID.setText(str(_ss.markerStartIndex));
    // Lid offsets
    if (sLidOffsetX != null) sLidOffsetX.setValue(uiLidOffsetX);
    if (sLidOffsetY != null) sLidOffsetY.setValue(uiLidOffsetY);
  } finally {
    _syncingUI = false;  // always re-enable, even if an exception occurred
  }
  // Visibility refresh
  updateSidebarControlsVisibility();
}

void setAdvancedVisible(boolean visible) {
  // tHidePanelFolds is always visible in main section, not advanced
  sTabDepth.setVisible(visible);
  sFlapDepth.setVisible(visible);
  sFlapTaper.setVisible(visible);
  sTabNeckRatio.setVisible(visible);
  sDash.setVisible(visible);
  //sPatX.setVisible(visible);
  //sPatY.setVisible(visible);
  // Lid offset controls are now always visible in bottom strip
}

//------------------------------------------------------------------------------------
void updateExportControlPositions() {
  if (tfExportFilename != null && btnExportMain != null) {
    float exportBarY = height - BOTTOM_EXPORT_HEIGHT + 10;
    float exportBarX = width - 320;
    
    tfExportFilename.setPosition(exportBarX, exportBarY + 8);
    btnExportMain.setPosition(exportBarX + 190, exportBarY + 8);
    
    // Update 2D/3D toggle position
    float bottomControlX = LEFT_SIDEBAR_WIDTH + 20;
    float bottomControlY = exportBarY + 8;
    tView3D.setPosition(bottomControlX, bottomControlY);
    if (tShowDistances != null) tShowDistances.setPosition(bottomControlX + 640, bottomControlY);
    
    // Update tessellation mesh toggle position (next to 2D/3D toggle)
    if (tShowTessellationMesh != null) {
      tShowTessellationMesh.setPosition(bottomControlX + 90, bottomControlY);
    }
    
    // Update marker controls position (next to mesh/3D buttons)
    float markerControlX = LEFT_SIDEBAR_WIDTH + 240;
    float markerControlY = exportBarY + 8;
    if (tEnableMarkers != null) {
      tEnableMarkers.setPosition(markerControlX - 30, markerControlY);
    }
    if (m_idNumbox != null) {
      m_idNumbox.setPosition(markerControlX, markerControlY);
    }
    if (m_sizeNumbox != null) {
      m_sizeNumbox.setPosition(markerControlX + 95, markerControlY);
    }
    if (tfMarkerID != null) {
      tfMarkerID.setPosition(markerControlX + 73, markerControlY);
    }
    if (tfMarkerSize != null) {
      tfMarkerSize.setPosition(markerControlX + 168, markerControlY);
    }
    if (tAutoMarkerIDs != null) {
      tAutoMarkerIDs.setPosition(markerControlX + 195, markerControlY);
    }
    if (m_gridNumbox != null) {
      m_gridNumbox.setPosition(markerControlX + 285, markerControlY);
    }
    if (tMarkerFreePlace != null) {
      tMarkerFreePlace.setPosition(markerControlX + 345, markerControlY);
    }

    /* Update view preset button positions (commented out for now)
    if (btnViewTop != null) {
      float presetX = bottomControlX + 90;
      int presetBtnW = 45;
      btnViewTop.setPosition(presetX, bottomControlY);
      presetX += presetBtnW + 5;
      btnViewFront.setPosition(presetX, bottomControlY);
      presetX += presetBtnW + 5;
      btnViewRight.setPosition(presetX, bottomControlY);
      presetX += presetBtnW + 5;
      btnViewIso.setPosition(presetX, bottomControlY);
    }
    */
    
    // Update lid offset control positions
    float lidControlX = bottomControlX + 100;
    int lidSliderW = 140;
    int lidSliderH = 12;
    // Align bottom of sliders with bottom of buttons (button height = 34px)
    float lidControlY = bottomControlY + 34 - lidSliderH;
    
    sLidOffsetX.setPosition(lidControlX, lidControlY);
    sLidOffsetY.setPosition(lidControlX + lidSliderW + 20, lidControlY);
  }
}

// Update lid positions when buttons are held down
void updateHeldLidButton() {
  // Check if mouse is still pressed over any button
  if (!mousePressed) {
    heldLidButton = "";
    return;
  }
  
  // If we had a held button, keep moving in that direction
  if (!heldLidButton.equals("")) {
    boolean needsRedraw = false;
    
    if (heldLidButton.equals("topLeft")) {
      uiTopLidOffsetX -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("topRight")) {
      uiTopLidOffsetX += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("topUp")) {
      uiTopLidOffsetY -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("topDown")) {
      uiTopLidOffsetY += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("topRotate")) {
      // handled on press, not continuous
      needsRedraw = false;
    } else if (heldLidButton.equals("botLeft")) {
      uiBotLidOffsetX -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("botRight")) {
      uiBotLidOffsetX += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("botUp")) {
      uiBotLidOffsetY -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("botDown")) {
      uiBotLidOffsetY += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("botRotate")) {
      // handled on press, not continuous
      needsRedraw = false;
    } else if (heldLidButton.equals("innerWallLeft")) {
      uiInnerWallOffsetX -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("innerWallRight")) {
      uiInnerWallOffsetX += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("innerWallUp")) {
      uiInnerWallOffsetY -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("innerWallDown")) {
      uiInnerWallOffsetY += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half1Left")) {
      uiSplitHalf1OffsetX -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half1Right")) {
      uiSplitHalf1OffsetX += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half1Up")) {
      uiSplitHalf1OffsetY -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half1Down")) {
      uiSplitHalf1OffsetY += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half1Rotate")) {
      // handled on press, not continuous
      needsRedraw = false;
    } else if (heldLidButton.equals("half2Left")) {
      uiSplitHalf2OffsetX -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half2Right")) {
      uiSplitHalf2OffsetX += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half2Up")) {
      uiSplitHalf2OffsetY -= lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half2Down")) {
      uiSplitHalf2OffsetY += lidMoveSpeed;
      needsRedraw = true;
    } else if (heldLidButton.equals("half2Rotate")) {
      // handled on press, not continuous
      needsRedraw = false;
    }
    
    if (needsRedraw) {
      // Persist lid offset changes to the selected ShapeSpec
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
        saveGlobalsTo(shapes.get(selectedShapeIdx));
      }
      redraw();
    }
  }
}

// Check which lid button is under mouse (called from mousePressed in events.pde)
boolean checkLidButtonPress() {
  if (sidebar == null || sidebar.activeMainTab != 2) return false;
  
  // Calculate button positions (must match updateSidebarControlPositions)
  int startY = placementBaseY();  // clears the PAGE SIZE section (hidden in workshop mode)
  int row = 29;
  int btnSize = 26;
  int btnGap = 4;
  float baseY = startY + 0.5*row + 5*(row + 20) + 10;
  
  // Top lid D-pad
  float topCenterX = SIDEBAR_PADDING + btnSize + btnGap;
  
  // Check each button
  if (isMouseOver(topCenterX, baseY, btnSize, btnSize)) {
    heldLidButton = "topUp";
    return true;
  }
  if (isMouseOver(SIDEBAR_PADDING, baseY + btnSize + btnGap, btnSize, btnSize)) {
    heldLidButton = "topLeft";
    return true;
  }
  if (isMouseOver(topCenterX, baseY + btnSize + btnGap, btnSize, btnSize)) {
    heldLidButton = "topRotate";
    uiTopLidRotation += 90;
    if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    return true;
  }
  if (isMouseOver(topCenterX + btnSize + btnGap, baseY + btnSize + btnGap, btnSize, btnSize)) {
    heldLidButton = "topRight";
    return true;
  }
  if (isMouseOver(topCenterX, baseY + 2*(btnSize + btnGap), btnSize, btnSize)) {
    heldLidButton = "topDown";
    return true;
  }
  
  // Bottom lid D-pad
  float botBaseX = SIDEBAR_PADDING + 3*(btnSize + btnGap) + 30;
  float botCenterX = botBaseX + btnSize + btnGap;
  
  if (isMouseOver(botCenterX, baseY, btnSize, btnSize)) {
    heldLidButton = "botUp";
    return true;
  }
  if (isMouseOver(botBaseX, baseY + btnSize + btnGap, btnSize, btnSize)) {
    heldLidButton = "botLeft";
    return true;
  }
  if (isMouseOver(botCenterX, baseY + btnSize + btnGap, btnSize, btnSize)) {
    heldLidButton = "botRotate";
    uiBotLidRotation += 90;
    if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
    return true;
  }
  if (isMouseOver(botCenterX + btnSize + btnGap, baseY + btnSize + btnGap, btnSize, btnSize)) {
    heldLidButton = "botRight";
    return true;
  }
  if (isMouseOver(botCenterX, baseY + 2*(btnSize + btnGap), btnSize, btnSize)) {
    heldLidButton = "botDown";
    return true;
  }
  
  // Inner wall D-pad (only if hollow mode is active)
  if (hollowMode) {
    float innerWallBaseY = baseY + 3*(btnSize + btnGap) + 20;
    float innerWallCenterX = SIDEBAR_PADDING + btnSize + btnGap;
    
    if (isMouseOver(innerWallCenterX, innerWallBaseY, btnSize, btnSize)) {
      heldLidButton = "innerWallUp";
      return true;
    }
    if (isMouseOver(SIDEBAR_PADDING, innerWallBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "innerWallLeft";
      return true;
    }
    if (isMouseOver(innerWallCenterX + btnSize + btnGap, innerWallBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "innerWallRight";
      return true;
    }
    if (isMouseOver(innerWallCenterX, innerWallBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "innerWallDown";
      return true;
    }
  }
  
  // Split strip half D-pads (only if split mode is active)
  if (splitStrip) {
    float splitBaseY = baseY + 3*(btnSize + btnGap) + 20;
    if (hollowMode) splitBaseY += 2*(btnSize + btnGap) + 20;
    
    // Half 1 D-pad
    float h1CenterX = SIDEBAR_PADDING + btnSize + btnGap;
    if (isMouseOver(h1CenterX, splitBaseY, btnSize, btnSize)) {
      heldLidButton = "half1Up"; return true;
    }
    if (isMouseOver(SIDEBAR_PADDING, splitBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "half1Left"; return true;
    }
    if (isMouseOver(h1CenterX, splitBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "half1Rotate";
      uiSplitHalf1Rotation += 90;
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
      return true;
    }
    if (isMouseOver(h1CenterX + btnSize + btnGap, splitBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "half1Right"; return true;
    }
    if (isMouseOver(h1CenterX, splitBaseY + 2*(btnSize + btnGap), btnSize, btnSize)) {
      heldLidButton = "half1Down"; return true;
    }
    
    // Half 2 D-pad
    float h2BaseX = SIDEBAR_PADDING + 3*(btnSize + btnGap) + 30;
    float h2CenterX = h2BaseX + btnSize + btnGap;
    if (isMouseOver(h2CenterX, splitBaseY, btnSize, btnSize)) {
      heldLidButton = "half2Up"; return true;
    }
    if (isMouseOver(h2BaseX, splitBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "half2Left"; return true;
    }
    if (isMouseOver(h2CenterX, splitBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "half2Rotate";
      uiSplitHalf2Rotation += 90;
      if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) saveGlobalsTo(shapes.get(selectedShapeIdx));
      return true;
    }
    if (isMouseOver(h2CenterX + btnSize + btnGap, splitBaseY + btnSize + btnGap, btnSize, btnSize)) {
      heldLidButton = "half2Right"; return true;
    }
    if (isMouseOver(h2CenterX, splitBaseY + 2*(btnSize + btnGap), btnSize, btnSize)) {
      heldLidButton = "half2Down"; return true;
    }
  }
  
  return false;
}

boolean isMouseOver(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

void applyToModel() {
  nSides = max(3, uiSides);
  
  // === ENFORCE TOP/BOTTOM LOCK ===
  // Read lock state directly from the toggle button (ground truth),
  // not from the global which may be stale after a loadGlobalsFrom call.
  if (tLock != null) uiLock = tLock.getState();
  if (uiLock) {
    uiBotW = uiTopW;
  }

  // --- Cuboid mode: only allowed when nSides==4, controlled by toggle ---
  if (nSides != 4) cuboidMode = false;
  
  // Update visibility of cuboid controls
  if (tCuboidMode != null) {
    tCuboidMode.setVisible(nSides == 4);
  }
  setCuboidControlsVisible(cuboidMode);

  float topPerim, botPerim;
  float sideLength;

  if (cuboidMode) {
    // === CUBOID MODE: perimeter = 2*(length + width) for a rectangle ===
    topPerim = 2 * (uiCubTopLen + uiCubTopWid);
    botPerim = 2 * (uiCubBotLen + uiCubBotWid);
    sideLength = uiCubTopLen;
  } else if (nSides == 4) {
    // === SQUARE MODE: diameter = side length ===
    topPerim = 4 * max(1, uiTopW);
    botPerim = 4 * max(1, uiBotW);
    sideLength = uiTopW;
  } else {
    // === POLYGON MODE: circumscribed diameter ===
    topPerim = nSides * max(1, uiTopW) * sin(PI / nSides);
    botPerim = nSides * max(1, uiBotW) * sin(PI / nSides);
    sideLength = uiTopW * sin(PI / nSides);
  }

  // Schrijf naar model
  cylinder.x = topPerim;
  cylinder.y = botPerim;
  cylinder.z = max(1, uiHeight);

  // Houd per-edge arrays in sync met huidige perimeters/locks
  syncEdgesFromPerimeters();
  setParams(false);
  
  // Persist changes to the currently selected ShapeSpec
  if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
    saveGlobalsTo(shapes.get(selectedShapeIdx));
  }

  // Keep the Kresling fold-height slider within the shape's valid (shear-producing) range
  updateKreslingFoldHeightRange();

  redraw();
}

/* View preset helper functions (commented out for now - future reference)
void updateViewPresetButtonsVisibility() {
  if (btnViewTop == null) return;
  
  // Show/hide view preset buttons based on 3D mode
  if (view3DMode) {
    btnViewTop.show();
    btnViewFront.show();
    btnViewRight.show();
    btnViewIso.show();
  } else {
    btnViewTop.hide();
    btnViewFront.hide();
    btnViewRight.hide();
    btnViewIso.hide();
  }
  updateViewPresetButtonHighlight();
}

void updateViewPresetButtonHighlight() {
  if (btnViewTop == null) return;
  
  // Highlight active view preset
  color activeColor = color(90, 120, 255);
  color normalColor = color(70, 70, 90);
  
  btnViewTop.setColorBackground(currentViewPreset.equals("Top") ? activeColor : normalColor);
  btnViewFront.setColorBackground(currentViewPreset.equals("Bottom") ? activeColor : normalColor);
  btnViewRight.setColorBackground(currentViewPreset.equals("Side") ? activeColor : normalColor);
  btnViewIso.setColorBackground(currentViewPreset.equals("Isometric") ? activeColor : normalColor);
}

void setViewPreset(String preset) {
  currentViewPreset = preset;
  
  switch(preset) {
    case "Top":
      // Top view - looking down at top lid
      angleX = radians(0);
      angleY = radians(0);
      angleZ = radians(0);
      break;
    case "Bottom":
      // Bottom view - looking up at bottom lid
      angleX = radians(180);
      angleY = radians(0);
      angleZ = radians(0);
      break;
    case "Side":
      // Side view - looking at panel 0 (front face)
      angleX = radians(90);
      angleY = radians(0);
      angleZ = radians(0);
      break;
    case "Isometric":
    default:
      angleX = radians(60);
      angleY = radians(0);
      angleZ = radians(45);
      break;
  }
  
  println("[UI] View preset: " + preset);
  updateViewPresetButtonHighlight();
}
*/

//------------ geometry------------------------
float calculatePolygonArea(int numberOfSides, float sideLength) {
  numberOfSides = max(3, numberOfSides);
  sideLength = max(0, sideLength);
  if (sideLength == 0) return 0;
  return (float)(numberOfSides * sideLength * sideLength / (4.0 * Math.tan(Math.PI / (double)numberOfSides)));
}
float calculatePolygonApothem(int numberOfSides, float sideLength) {
  numberOfSides = max(3, numberOfSides);
  sideLength = max(0, sideLength);
  if (sideLength == 0) return 0;
  return (float)(sideLength / (2.0 * Math.tan(Math.PI / (double)numberOfSides))); // r_in
}
float calculatePolygonCircumradius(int numberOfSides, float sideLength) {
  numberOfSides = max(3, numberOfSides);
  sideLength = max(0, sideLength);
  if (sideLength == 0) return 0;
  return (float)(sideLength / (2.0 * Math.sin(Math.PI / (double)numberOfSides))); // r_out
}

//----------------------------------------------------------
// Helper: show/hide cuboid-specific controls
// Reposition the secondary toggle group (hide folds / cut lines / split strip / hollow
// + hollow sub-controls) so it clears the cuboid controls when cuboid mode is on, and
// sits higher (clear of the 3D preview) when cuboid mode is off. Increments here must
// match the vertical steps used when these controls are first created in initShapeUI.
void layoutSecondaryToggles() {
  int row = 29;
  // Leave room for the TAB LENGTH preset row that sits above this group
  float startY = (cuboidMode ? togglesYWhenCuboidOn : togglesYWhenCuboidOff) + TAB_LEN_ROW_H;

  // Two-column grid for the four toggles
  float col1X = SIDEBAR_PADDING;
  float col2X = SIDEBAR_PADDING + (LEFT_SIDEBAR_WIDTH - 2 * SIDEBAR_PADDING) / 2.0;
  float gridRowH = row + 12;  // vertical space per toggle row

  // In Kresling mode it's the only strip option shown — put its toggle at the top
  // (the other toggles are hidden) and stack its sliders right below.
  if (kreslingMode) {
    if (tKresling != null) tKresling.setPosition(col1X, startY);
    // The haptic selector UI is drawn manually between the toggle and the sliders;
    // put the manual-override sliders below the space it reserves.
    float ky = kreslingHapticUIY() + KRESLING_HAPTIC_BLOCK_H;
    if (sKreslingUnits    != null) { sKreslingUnits.setPosition(col1X, ky);    ky += gridRowH; }
    if (sKreslingSegments != null) { sKreslingSegments.setPosition(col1X, ky); ky += gridRowH; }
    return;
  }

  //  [ Hide panel folds ]   [ Light gray cut lines ]
  //  [ Split strip in half] [ Hollow / double wall ]   (hollow hidden in workshop mode)
  //  [ Kresling pattern   ]
  if (tHidePanelFolds    != null) tHidePanelFolds.setPosition(col1X, startY);
  if (tLightGrayCutLines != null) tLightGrayCutLines.setPosition(col2X, startY);
  if (tSplitStrip        != null) tSplitStrip.setPosition(col1X, startY + gridRowH);
  if (tHollowMode        != null) tHollowMode.setPosition(col2X, startY + gridRowH);
  if (tKresling          != null) tKresling.setPosition(col1X, startY + 2 * gridRowH);

  // Sub-controls stacked in a single column below the grid
  float y = startY + 3 * gridRowH + 8;
  if (sKreslingUnits    != null) { sKreslingUnits.setPosition(col1X, y);    y += row; }
  if (sKreslingSegments != null) { sKreslingSegments.setPosition(col1X, y); y += row; }
  if (sWallThickness    != null) { sWallThickness.setPosition(col1X, y);    y += row; }
  if (tEnableInnerShape != null) { tEnableInnerShape.setPosition(col1X, y); y += row; }
  if (sInnerSides       != null) { sInnerSides.setPosition(col1X, y);       y += row; }
  if (sInnerScale       != null) { sInnerScale.setPosition(col1X, y);       y += row; }
  if (sInnerRotation    != null) { sInnerRotation.setPosition(col1X, y);    y += row; }
}

void setCuboidControlsVisible(boolean vis) {
  boolean inShapeTab = (sidebar == null || sidebar.activeMainTab == 0);
  boolean show = vis && inShapeTab;
  if (sCubTopLen != null) sCubTopLen.setVisible(show);
  if (sCubTopWid != null) sCubTopWid.setVisible(show);
  if (sCubBotLen != null) sCubBotLen.setVisible(show);
  if (sCubBotWid != null) sCubBotWid.setVisible(show);
  if (tfCubTopLen != null) tfCubTopLen.setVisible(show);
  if (tfCubTopWid != null) tfCubTopWid.setVisible(show);
  if (tfCubBotLen != null) tfCubBotLen.setVisible(show);
  if (tfCubBotWid != null) tfCubBotWid.setVisible(show);
  if (tCubRatioLock != null) tCubRatioLock.setVisible(show);
  if (tCubAspectLock != null) tCubAspectLock.setVisible(show);
  // Hide the diameter sliders when cuboid mode is on
  boolean showDiam = !vis && inShapeTab;
  if (sTopSize != null) sTopSize.setVisible(showDiam);
  if (sBotSize != null) sBotSize.setVisible(showDiam);
  if (tLock != null) tLock.setVisible(showDiam);
  if (tfTopSize != null) tfTopSize.setVisible(showDiam);
  if (tfBotSize != null) tfBotSize.setVisible(showDiam);

  // Keep the secondary toggle group at the anchor matching the current cuboid state
  layoutSecondaryToggles();
}

//----------------------------------------------------------
void refreshLabels() {
  lblTopP.setText("Top Perimeter:    " + nf(cylinder.x, 1, 2) + " mm");
  lblBotP.setText("Bottom Perimeter: " + nf(cylinder.y, 1, 2) + " mm");

  // === CONVERTEER DIAMETER NAAR ZIJDE-LENGTE ===
  // uiTopW/uiBotW zijn circumscribed DIAMETER
  // Maar calculatePolygonArea() en andere functies verwachten ZIJDE-LENGTE
  // Dus converteren we: zijde = diameter × sin(π/n)
  float topSideLength = uiTopW * sin(PI / uiSides);
  float botSideLength = uiBotW * sin(PI / uiSides);
  
  // Bereken oppervlaktes met de geconverteerde zijde-lengtes
  float areaTop = calculatePolygonArea(uiSides, topSideLength);
  float areaBottom = calculatePolygonArea(uiSides, botSideLength);

  // === BEREKEN RADII VOOR INFO LABELS ===
  // Ook hier: eerst diameter omzetten naar zijde-lengte
  // Dan kunnen we inscribed (ingeschreven) en circumscribed (uitgeschreven) radii berekenen
  float inradiusTop  = calculatePolygonApothem(uiSides, topSideLength);
  float circumradiusTop = calculatePolygonCircumradius(uiSides, topSideLength);
  float inradiusBottom  = calculatePolygonApothem(uiSides, botSideLength);
  float circumradiusBottom = calculatePolygonCircumradius(uiSides, botSideLength);


  lblTopRin.setText( "Top r_in (inscribed):    " + nf(inradiusTop, 1, 2) + " mm  |  d=" + nf(2*inradiusTop, 1, 2) + " mm");
  lblTopRout.setText("Top r_out (circumscribed): " + nf(circumradiusTop, 1, 2) + " mm  |  d=" + nf(2*circumradiusTop, 1, 2) + " mm");
  lblBotRin.setText( "Bottom r_in (inscribed): " + nf(inradiusBottom, 1, 2) + " mm  |  d=" + nf(2*inradiusBottom, 1, 2) + " mm");
  lblBotRout.setText("Bottom r_out (circumscribed): " + nf(circumradiusBottom, 1, 2) + " mm  |  d=" + nf(2*circumradiusBottom, 1, 2) + " mm");
  
  // Update visibility and positioning if toggle is on
  updateDimensionLabelsVisibility();
}

// Position and show/hide dimension labels based on toggle state
void updateDimensionLabelsVisibility() {
  // Labels are now drawn as an overlay on the 3D view, not in the sidebar
  // Always keep them hidden
  lblAdvHdr.setVisible(false);
  lblTopP.setVisible(false);
  lblTopRin.setVisible(false);
  lblTopRout.setVisible(false);
  lblBotP.setVisible(false);
  lblBotRin.setVisible(false);
  lblBotRout.setVisible(false);
}


//----------------------------all the tools needed for the per-edge control mode------------------------------------
void togglePerEdgeMode() { // the mode to edit each edge length seperately (demo) 
  perEdgeMode = !perEdgeMode;
  syncEdgesFromPerimeters();  // why: consistent wisselen
  uiEdgeIdx = constrain(uiEdgeIdx, 0, max(3, nSides) - 1);
}

void selectPreviousEdge() {
  uiEdgeIdx = (uiEdgeIdx - 1 + max(3, nSides)) % max(3, nSides);
}
void selectNextEdge() {
  uiEdgeIdx = (uiEdgeIdx + 1) % max(3, nSides);
}

void incrementTopEdge(float deltaMillimeters) {
  setEdgeTopAtIndex(uiEdgeIdx, max(0.001, edgeTopMm(uiEdgeIdx) + deltaMillimeters));
}
void incrementBottomEdge(float deltaMillimeters) {
  setEdgeBottomAtIndex(uiEdgeIdx, max(0.001, edgeBottomMm(uiEdgeIdx) + deltaMillimeters));
}

void copyTopEdgesToBottom() {
  for (int i = 0; i < max(3, nSides); i++) edgesBottom.set(i, edgesTop.getMm(i));
  cylinder.y = edgesBottom.perimeterMm();
}

void setAllEdgesFromUniformSliders() {
  setAllTop(max(1, uiTopW));
  setAllBottom(max(1, uiBotW));
}

void normalizeTopEdgesToTarget() {
  float targetPerimeter = uiNormalizeTarget > 0 ? uiNormalizeTarget : (uiPerimLock ? max(1, uiPerim) : cylinder.x);
  edgesTop.normalizeToPerimeter(targetPerimeter);
  cylinder.x = edgesTop.perimeterMm();
  if (uiLock) {
    copyTopEdgesToBottom();
  } // why: lock behouden
}

void drawPerEdgeHUD() {
  if (!perEdgeMode) return;
  initEdgeProfilesIfNeeded();

  pushStyle();
  rectMode(CORNER);
  textAlign(LEFT, TOP);

  // panel (below toolbar)
  float padding = 8;
  float panelX = width - 320;
  float panelY = TOOLBAR_HEIGHT + 12;
  float panelWidth = 308;
  float panelHeight = 170;
  fill(255, 245);
  stroke(0);
  rect(panelX, panelY, panelWidth, panelHeight);

  fill(0);
  String headerText = "Per-edge editor (E toggle)";
  text(headerText, panelX + padding, panelY + padding);

  int totalSides = max(3, nSides);
  float currentTopEdgeLength = edgeTopMm(uiEdgeIdx);
  float currentBottomEdgeLength = edgeBottomMm(uiEdgeIdx);

  String info =
    "Edge: " + uiEdgeIdx + " / " + (totalSides-1) + "\n" +
    "Top mm: " + nf(currentTopEdgeLength, 1, 2) + "\n" +
    "Bot mm: " + nf(currentBottomEdgeLength, 1, 2) + "\n" +
    "Top perim: " + nf(topPerimeterMm(), 1, 2) + " mm\n" +
    "Bot perim: " + nf(bottomPerimeterMm(), 1, 2) + " mm\n" +
    "Keys: [ / ]  select\n" +
    "T/t ±" + stepFine + " | B/b ±" + stepFine + "\n" +
    "SHIFT+T/B = ±" + stepCoarse + "\n" +
    "C copy top→bottom, A set-all, N normalize";
  text(info, panelX + padding, panelY + 28);

  popStyle();
}
