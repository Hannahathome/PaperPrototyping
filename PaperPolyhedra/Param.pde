//----------------------------------------------------------------------------------
// GLOBAL PARAMETERS AND CONSTANTS
// This file contains all global variables, magic numbers, and derived values
// Organized by: Units/Conversion → Geometry → Tabs/Flaps → UI → Textures
//----------------------------------------------------------------------------------

// ==================== UNIT CONVERSION & PAGE DIMENSIONS ====================
float[] edgeTop_px;
float[] edgeBot_px;
float[] edgeSlantH_px;  // Per-edge slant height (px) for cuboid frustum

// --- Cuboid Mode ---
boolean cuboidMode = false;          // Toggle for rectangular lids when nSides==4
float uiCubTopLen = 35;              // Cuboid top lid length (mm)
float uiCubTopWid = 35;              // Cuboid top lid width (mm)
float uiCubBotLen = 35;              // Cuboid bottom lid length (mm)
float uiCubBotWid = 35;              // Cuboid bottom lid width (mm)
boolean uiCubRatioLock = false;      // Lock top and bottom to be exactly the same
boolean uiCubAspectLock = false;     // Lock bottom aspect ratio to match top's ratio

float MM = 2.8346;  // Non-final to allow temporary 300 DPI switching during export
float MM_current = MM;  // Current MM value based on export mode (updated by setParams)
final float PRINT_DPI = 72;
final float VINYL_DPI = 96;
final float VINYL_TO_PRINT_RATIO = VINYL_DPI/PRINT_DPI;
final float MM_V = MM*VINYL_TO_PRINT_RATIO;
// Page size lookup: A4, A3, A2, A1 (landscape, width × height in mm)
float[][] PAGE_SIZES      = {{297,210}, {420,297}, {594,420}, {841,594}};
// Vinyl usable area per page size (smaller than paper — margin for mat/cutter limits)
float[][] VINYL_SIZES     = {{280,200}, {400,280}, {570,400}, {810,570}};
String[]  PAGE_SIZE_NAMES = {"A4", "A3", "A2", "A1"};
int pageSizeIdx = 0;  // 0=A4 (default)

float PRINT_W = 297;
float PRINT_H = 210;
float VINYL_W = 280;  // Usable cutting area (smaller than paper for mat margin)
float VINYL_H = 200;
float widthA4 = PRINT_W*MM;
float heightA4 = PRINT_H*MM;
float widthA4_V = VINYL_W*MM_V;
float heightA4_V = VINYL_H*MM_V;
float widthA4_C = VINYL_W*MM; //print for calibration
float heightA4_C = VINYL_H*MM;//print for calibration

// High-resolution texture rendering (300 DPI)
final float TEXTURE_DPI = 300;
final float TEXTURE_SCALE = TEXTURE_DPI / PRINT_DPI;  // 4.166667
float widthA4_render = PRINT_W * (TEXTURE_DPI / 25.4);
float heightA4_render = PRINT_H * (TEXTURE_DPI / 25.4);

// Screen display dimensions (auto-scaled to fit viewport)
float SCREEN_SCALE = 1.0;
float widthA4_display = widthA4 * SCREEN_SCALE;
float heightA4_display = heightA4 * SCREEN_SCALE;

float offW_V_F = 0*MM_V;
float offH_V_F = 0*MM_V;

// --- Define Dimensions ---
PVector cylinder = new PVector(120, 120, 60); //bp, tp, h
float flapDepth = 5;
float flapTaper = 5;
float tabDepth = 15;
float hookOffset = -1;
float dash = 3;
float gap = 3;  //space between dashes
final float FOLD_DASH_SCALE = 0.4;  // small fold dashes everywhere (match the Kresling folding cuts)
float patX = 10;
float patY = 20; //padding top
float patRotation = 0; // template rotation in degrees
float tab_neck_ratio = 0.8;

int rows = nSides+1;
int cols = 1+1;

float cylinderTopPerimeter = (cylinder.x);  // Total height of the cylinder
float cylinderBasePerimeter = (cylinder.y);  // Total height of the cylinder
float cylinderHeight = cylinder.z;  // Total height of the cylinder
float cylinderTP_px = cylinderTopPerimeter*MM; // Width of the front/back faces
float cylinderBP_px = cylinderBasePerimeter*MM; // Height of the front/back/left/right faces
float cylinderH_px = cylinderHeight*MM;  // Panel height (slant height for frustums) <-- height fix
float cylinderVertH_px = cylinderHeight*MM;  // True vertical height of 3D shape <-- height fix
float cellTopL_px = cylinderTP_px/(float)(nSides);
float cellBaseL_px = cylinderBP_px/(float)(nSides);

float flapDepth_px = flapDepth*MM;    // Depth for basic flaps
float flapTaper_px = flapTaper*MM;    // Taper for basic flaps
float tabDepth_px = tabDepth*MM; // How far the tabs stick out
float tabInset_h_px = cylinderH_px/4.; // Inset from the edge corners for the tabs/slots
float tabInset_top_px = cellTopL_px/4.; // Inset from the edge corners for the tabs/slots
float tabInset_bot_px = cellBaseL_px/4.; // Inset from the edge corners for the tabs/slots
float arrowheadFlare_h_px = tabInset_h_px/3.; // How much the arrowhead flares out
float arrowheadFlare_top_px = tabInset_top_px/3.; // How much the arrowhead flares out
float arrowheadFlare_bot_px = tabInset_bot_px/3.; // How much the arrowhead flares out

float hookOffset_px = hookOffset*MM;
float tab_neck_ratio_hook = 0.2;
float neckDepth_hook_px = tabDepth_px * tab_neck_ratio_hook;

float dash_px = dash*MM*FOLD_DASH_SCALE;
float gap_px = gap*MM*FOLD_DASH_SCALE;
float neckDepth_px = tabDepth_px * tab_neck_ratio;

float patX_px = patX*MM;
float patY_px = patY*MM;

int tessellationDensity = 16; // subdivisions per panel (highest quality)

// ==================== MAGIC NUMBERS & RATIOS ====================
// Geometric ratios
final float TAB_INSET_RATIO = 0.25;              // Tab inset as fraction of edge length
final float TAB_NECK_RATIO_DEFAULT = 0.8;        // Default neck-to-tab depth ratio
final float TAB_NECK_RATIO_HOOK = 0.2;           // Hook tab neck ratio
final float ARROWHEAD_FLARE_RATIO = 1.0/3.0;     // Arrowhead flare relative to inset
final float TAB_DEPTH_FRACTION = 0.2;            // Lid tab neck depth ratio
final float INNER_TAB_DEPTH_MM = 10.0;           // Fixed depth for inner wall tabs (mm)
final float PAPER_THICKNESS_MM = 0.25;           // Typical paper thickness (mm)

// Layout spacing
final float LID_SPACING_MARGIN = 1.25;           // 25% margin between strip and lids
final float VERTICAL_SUBDIV_DEFAULT = 1;         // Default vertical subdivisions (m)

// Solver parameters
final int RADIUS_SOLVER_ITERATIONS = 60;         // Binary search iterations for variable polygon
final float RADIUS_SOLVER_MIN_RATIO = 0.51;     // Min radius = max_chord * this ratio
final float RADIUS_SOLVER_MAX_RATIO = 1000.0;   // Max radius = max_chord * this ratio
final float CLAMP_EPSILON = 1e-6;                // Small value for clamping calculations
final float CLAMP_MAX = 0.999999;                // Max value for arc calculations

// UI defaults
final int MIN_SIDES = 3;                         // Minimum polygon sides
final int DEFAULT_SIDES = 4;                     // Default starting sides
final float STEP_FINE = 0.5;                     // Fine adjustment step (mm)
final float STEP_COARSE = 5.0;                   // Coarse adjustment step (mm)

// ==================== TOOLBAR UI ====================
final int TOOLBAR_HEIGHT = 50;                   // Height of top toolbar strip
final int TOOLBAR_PADDING = 8;                   // Internal padding
final int TOOLBAR_BTN_WIDTH = 80;                // Standard button width
final int TOOLBAR_BTN_HEIGHT = 34;               // Standard button height
final int TOOLBAR_SEPARATOR = 12;                // Space between button groups

// ==================== SIDEBAR UI ====================
final int LEFT_SIDEBAR_WIDTH = 420;              // Width of left control sidebar
final int BOTTOM_EXPORT_HEIGHT = 90;             // Height of bottom export button area
final int SIDEBAR_PADDING = 12;                  // Internal sidebar padding
final float SIDEBAR_TOP_SECTION_RATIO = 0.25;    // Top 1/3 for shape controls

PImage lidImgTop = null;
PImage lidImgBot = null;
boolean lidKeepAspect = true; // true=preserve aspect inside lid box
boolean showExtraDimensions = false;  // Toggle to show/hide diameter, radius, and perimeter info

// ==================== ORIGINAL TEXTURE STORAGE (for undo/reset) ====================
PImage[] originalPanelTextures = null;
PImage originalStripImg = null;
PImage originalLidImgTop = null;
PImage originalLidImgBot = null;

// ==================== STRIP SPLIT MODE ====================
boolean splitStrip = false;                    // Split strip into two halves at ceil(n/2)

// ==================== TEXTURE BLEED ====================
boolean textureBleed = false;                  // Extend textures slightly beyond panel edges
float textureBleedMM = 3.0;                    // Bleed amount in mm

// ==================== HOLLOW/DOUBLE-WALL MODE PARAMETERS ====================
boolean hollowMode = false;                    // false=single wall, true=double wall with inner/outer panels
float wallThickness = 5.0;                     // Gap between inner and outer walls (mm)
boolean showInnerWall = true;                  // Toggle to show/hide inner wall in preview
float wallThickness_px;                        // Derived pixel value

// ==================== INNER SHAPE PARAMETERS (for donut lids) ====================
int nSidesInner = 4;                           // Number of sides for inner polygon (default same as outer)
float innerShapeScale = 0.5;                   // Inner perimeter as fraction of outer (0.3-0.8)
float innerShapeRotation = 0.0;                // Inner polygon rotation in degrees (0-360)
float cellInnerL_px;                           // Calculated inner edge length in pixels (derived)
boolean enableInnerShape = false;              // Enable different inner shape (only in hollow mode)

// ==================== 3D VIEW PARAMETERS ====================
boolean view3DMode = false;                    // false=2D pattern, true=3D preview
boolean view3DShowAll = false;                 // false=selected shape only, true=all shapes side by side
boolean wireframeMode = false;                 // false=solid faces, true=wireframe only (see-through)
float angleX = radians(60);                    // Camera rotation X
float angleY = radians(0);                     // Camera rotation Y  
float angleZ = radians(45);                    // Camera rotation Z
float zoom3D = 100.0;                          // Zoom level for 3D view
PGraphics view3DBuffer;                        // Offscreen P3D buffer
String currentViewPreset = "Custom";           // Track active view preset

// Mini 3D view in 2D mode
boolean showMini3DView = true;                 // Toggle mini 3D view in 2D mode
final int MINI_3D_WIDTH = 250;                 // Mini view width
final int MINI_3D_HEIGHT = 250;                // Mini view height
final int MINI_3D_MARGIN = 15;                 // Margin from edges
PGraphics mini3DBuffer;                        // Offscreen P3D buffer for mini view
boolean isDraggingMini3D = false;              // Track if user is dragging in mini 3D view

// Applies a new paper/page size by index (0=A4, 1=A3, 2=A2, 3=A1).
// Updates all page-dimension globals and auto-fits SCREEN_SCALE to the current window.
void applyPageSize(int idx) {
  idx = constrain(idx, 0, PAGE_SIZES.length - 1);
  pageSizeIdx = idx;
  PRINT_W = PAGE_SIZES[idx][0];
  PRINT_H = PAGE_SIZES[idx][1];
  VINYL_W = VINYL_SIZES[idx][0];  // Usable cutting area with margin
  VINYL_H = VINYL_SIZES[idx][1];

  // Derived page dimensions
  widthA4        = PRINT_W * MM;
  heightA4       = PRINT_H * MM;
  widthA4_V      = VINYL_W * MM_V;
  heightA4_V     = VINYL_H * MM_V;
  widthA4_C      = VINYL_W * MM;
  heightA4_C     = VINYL_H * MM;
  widthA4_render  = PRINT_W * (TEXTURE_DPI / 25.4);
  heightA4_render = PRINT_H * (TEXTURE_DPI / 25.4);

  // Auto-fit SCREEN_SCALE so the page fills the available canvas area (5% margin)
  float availW = width  - LEFT_SIDEBAR_WIDTH;
  float availH = height - TOOLBAR_HEIGHT - BOTTOM_EXPORT_HEIGHT;
  SCREEN_SCALE = min(availW / widthA4, availH / heightA4) * 0.95;

  widthA4_display  = widthA4  * SCREEN_SCALE;
  heightA4_display = heightA4 * SCREEN_SCALE;

  setParams(false);
  println("[applyPageSize] " + PAGE_SIZE_NAMES[idx] + "  " + PRINT_W + "x" + PRINT_H + "mm  SCREEN_SCALE=" + nf(SCREEN_SCALE, 1, 3));
}

void setParams(boolean cut) {
  //-------------------set the image you want to use---------------------------------- 
  if (lidImgTop == null) lidImgTop = loadImage("top.jpg");      // in data/lids/top.png
  if (lidImgBot == null) lidImgBot = loadImage("bottom.jpg");   // in data/lids/bottom.png
  
  // Load strip image if not already loaded
  if (stripImg == null) {
    stripImg = loadImage("strip.jpg"); // place in data/
    if (stripImg != null) {
      println("[setParams] Strip image loaded: " + stripImg.width + "x" + stripImg.height);
    } else {
      println("[setParams] WARNING: Failed to load strip image 'ruler.png'");
    }
  }

  float MM_I = (cut? MM_V: MM);
  MM_current = MM_I;  // Update current MM for correct lid offset scaling
  rows = nSides+1;
  cols = 1+1;
  cylinderTopPerimeter = (cylinder.x);  // Total height of the cylinder
  cylinderBasePerimeter = (cylinder.y);  // Total height of the cylinder
  cylinderHeight = cylinder.z;  // Total height of the cylinder
  cylinderTP_px = cylinderTopPerimeter*MM_I; // Width of the front/back faces
  cylinderBP_px = cylinderBasePerimeter*MM_I; // Height of the front/back/left/right faces
  cellTopL_px = cylinderTP_px/(float)nSides;
  cellBaseL_px = cylinderBP_px/(float)nSides;
  // Panel height = slant height (hypotenuse) for frustums where top != bottom <-- height fix
  float sideDiff_px = abs(cellBaseL_px - cellTopL_px); // <-- height fix
  cylinderVertH_px = cylinderHeight*MM_I;  // True vertical height for 3D rendering <-- height fix
  cylinderH_px = sqrt(sq(cylinderVertH_px) + sq(sideDiff_px));  // Slant height for template panels <-- height fix

  // --- Per-edge arrays (px) opbouwen voor tekenfase -----
  initEdgeProfilesIfNeeded();
  edgesTop.mmToPx = (cut ? MM_V : MM);
  edgesBottom.mmToPx = (cut ? MM_V : MM);

  if (edgeTop_px == null || edgeTop_px.length != max(3, nSides)) edgeTop_px = new float[max(3, nSides)];
  if (edgeBot_px == null || edgeBot_px.length != max(3, nSides)) edgeBot_px = new float[max(3, nSides)];

  for (int i = 0; i < max(3, nSides); i++) {
    edgeTop_px[i] = edgesTop.getPx(i);
    edgeBot_px[i] = edgesBottom.getPx(i);
  }

  // --- Compute per-edge slant heights (Pythagoras) ---
  if (edgeSlantH_px == null || edgeSlantH_px.length != max(3, nSides)) edgeSlantH_px = new float[max(3, nSides)];
  if (cuboidMode && nSides == 4) {
    // For Length panels (edge 0,2): offset comes from Width difference
    float offsetW = (edgeTop_px[1] - edgeBot_px[1]) / 2.0;
    // For Width panels (edge 1,3): offset comes from Length difference
    float offsetL = (edgeTop_px[0] - edgeBot_px[0]) / 2.0;
    edgeSlantH_px[0] = sqrt(cylinderH_px * cylinderH_px + offsetW * offsetW);
    edgeSlantH_px[1] = sqrt(cylinderH_px * cylinderH_px + offsetL * offsetL);
    edgeSlantH_px[2] = edgeSlantH_px[0];
    edgeSlantH_px[3] = edgeSlantH_px[1];
  } else {
    for (int i = 0; i < max(3, nSides); i++) {
      edgeSlantH_px[i] = cylinderH_px;
    }
  }

  initEdgeProfilesIfNeeded();
  edgesTop.resize(max(3, nSides), max(1, uiTopW));
  edgesBottom.resize(max(3, nSides), max(1, uiBotW));
  uiEdgeIdx = constrain(uiEdgeIdx, 0, max(3, nSides) - 1);
  flapDepth_px = flapDepth*MM_I;    // Depth for basic flaps
  flapDepth_px = min(flapDepth_px, cellTopL_px * 0.5, cellBaseL_px * 0.5);
  flapTaper_px = flapTaper*MM_I;    // Taper for basic flaps
  if (flapTaper_px>cylinderH_px*.33) flapTaper_px = cylinderH_px*0.33;
  tabDepth_px = tabDepth*MM_I; // How far the tabs stick out
  // Clamp to 50% of shortest uniform side and 50% of panel height
  tabDepth_px = min(tabDepth_px, min(cellTopL_px * 0.5, cellBaseL_px * 0.5));
  tabDepth_px = min(tabDepth_px, cylinderH_px * 0.5);
  // In per-edge or cuboid mode, also clamp to 50% of shortest edge
  if ((perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null) {
    for (int i = 0; i < edgeTop_px.length; i++) {
      tabDepth_px = min(tabDepth_px, edgeTop_px[i] * 0.5, edgeBot_px[i] * 0.5);
    }
    // Also clamp to 50% of shortest panel slant height
    if (edgeSlantH_px != null) {
      for (int i = 0; i < edgeSlantH_px.length; i++) {
        tabDepth_px = min(tabDepth_px, edgeSlantH_px[i] * 0.5);
      }
    }
  }
  tabInset_h_px = cylinderH_px/4.; // Inset from the edge corners for the tabs/slots
  tabInset_top_px = cellTopL_px/4.; // Inset from the edge corners for the tabs/slots
  tabInset_bot_px = cellBaseL_px/4.; // Inset from the edge corners for the tabs/slots
  arrowheadFlare_h_px = tabInset_h_px/3.; // How much the arrowhead flares out
  arrowheadFlare_top_px = tabInset_top_px/3.; // How much the arrowhead flares out
  arrowheadFlare_bot_px = tabInset_bot_px/3.; // How much the arrowhead flares out
  dash_px = dash*MM_I*FOLD_DASH_SCALE;
  gap_px = gap*MM_I*FOLD_DASH_SCALE;
  neckDepth_px = tabDepth_px * tab_neck_ratio;
  neckDepth_hook_px = tabDepth_px * tab_neck_ratio_hook;
  hookOffset_px = hookOffset*MM_I;
  patX_px = patX*MM_I;
  patY_px = patY*MM_I;
  tessellationDensity = max(4, uiTessDensity);
  
  // Hollow mode derived values
  wallThickness_px = wallThickness*MM_I;
  
  // Inner shape derived values (for donut lids)
  if (enableInnerShape && hollowMode) {
    float innerPerimeter = cylinderBasePerimeter * innerShapeScale;
    cellInnerL_px = (innerPerimeter * MM_I) / (float)nSidesInner;
  } else {
    // Default to scaled version of outer shape (backward compatibility)
    cellInnerL_px = cellBaseL_px * innerShapeScale;
  }
}
