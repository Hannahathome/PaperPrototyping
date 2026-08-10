// SHAPESPEC.PDE - Per-Shape State Container
// Encapsulates all per-shape geometry, rendering, and placement state.
// Multiple ShapeSpec objects live in the global ArrayList<ShapeSpec> shapes.
//
// Global-swap pattern:
//   loadGlobalsFrom(s)   -> populate draw-time globals from this shape
//   saveGlobalsTo(s)     -> write current globals back into this shape
//
// Note: field names intentionally mirror global names; name shadowing inside
// ShapeSpec methods is avoided by keeping loadGlobalsFrom/saveGlobalsTo as
// standalone functions (not ShapeSpec instance methods).

class ShapeSpec {
  // --- Geometry ---
  int nSides;
  PVector cylinder;          // x=top perim mm, y=base perim mm, z=height mm
  float tabDepth, flapDepth, flapTaper, hookOffset, tab_neck_ratio, dashLen;
  boolean perEdgeMode;
  EdgeProfile edgesTop, edgesBottom;

  // --- UI mirrors ---
  int uiSides;
  float uiHeight, uiTopW, uiBotW;
  boolean uiLock, uiHidePanelFolds, uiLightGrayCutLines;

  // --- Lid positioning ---
  float uiLidOffsetX, uiLidOffsetY;
  float uiTopLidOffsetX, uiTopLidOffsetY, uiTopLidRotation;
  float uiBotLidOffsetX, uiBotLidOffsetY, uiBotLidRotation;
  float uiInnerWallOffsetX, uiInnerWallOffsetY;

  // --- Modes ---
  boolean splitStrip;
  float uiSplitHalf1OffsetX, uiSplitHalf1OffsetY, uiSplitHalf1Rotation;
  float uiSplitHalf2OffsetX, uiSplitHalf2OffsetY, uiSplitHalf2Rotation;
  boolean textureBleed;
  boolean hollowMode;
  float wallThickness;
  boolean enableInnerShape;
  int nSidesInner;
  float innerShapeScale, innerShapeRotation;

  // --- Cuboid Mode ---
  boolean cuboidMode;
  float uiCubTopLen, uiCubTopWid;
  float uiCubBotLen, uiCubBotWid;
  boolean uiCubRatioLock, uiCubAspectLock;

  // --- Textures (PImage references, not deep-copied) ---
  int sideTextureMode;
  PImage[] panelTextures;
  PImage stripImg;
  PImage lidImgTop, lidImgBot;
  boolean lidKeepAspect;
  int activeTextureTab; // sidebar texture sub-tab state

  // --- Sidebar texture toggles (mirrored from sidebar fields) ---
  boolean topLidEnabled, bottomLidEnabled;
  boolean[] perPanelEnabled;

  // --- Markers ---
  int markerStartIndex;  // aruco start ID for rep 0 of this shape

  // --- Label ---
  String label;          // optional display name (from JSON import)

  // --- Solid fill color ---
  color shapeColor;      // fill color for sides + lids (when no texture)
  boolean fillColorEnabled; // whether solid fill is active

  // --- Placement ---
  int nRep;
  PVector[] repPositions; // mm, relative to patX/patY; null = use auto-grid

  // --- Draw-time bbox cache (updated each draw pass) ---
  PVector cachedBBox;
  float cachedBBoxTop;  // actual Y top of the strip AABB (≤ -tabDepth; used for highlight rect)

  // Constructor: safe defaults matching the sketch's initial state.
  // Call saveGlobalsTo(this) immediately after to capture current globals.
  ShapeSpec() {
    nSides        = 4;
    cylinder      = new PVector(120, 120, 60);
    tabDepth      = 15;
    flapDepth     = 5;
    flapTaper     = 5;
    hookOffset    = -1;
    tab_neck_ratio = 0.8;
    dashLen       = 3;
    perEdgeMode   = false;
    edgesTop      = null;
    edgesBottom   = null;

    uiSides       = 4;
    uiHeight      = 60;
    uiTopW        = 30;
    uiBotW        = 30;
    uiLock        = false;
    uiHidePanelFolds    = false;
    uiLightGrayCutLines = false;

    uiLidOffsetX     = 0; uiLidOffsetY     = 0;
    uiTopLidOffsetX  = 0; uiTopLidOffsetY  = 0; uiTopLidRotation = 0;
    uiBotLidOffsetX  = 0; uiBotLidOffsetY  = 0; uiBotLidRotation = 0;
    uiInnerWallOffsetX = 0; uiInnerWallOffsetY = 0;

    splitStrip        = false;
    uiSplitHalf1OffsetX = 0; uiSplitHalf1OffsetY = 0; uiSplitHalf1Rotation = 0;
    uiSplitHalf2OffsetX = 0; uiSplitHalf2OffsetY = 0; uiSplitHalf2Rotation = 0;
    textureBleed      = false;
    hollowMode        = false;
    wallThickness     = 5.0;
    enableInnerShape  = false;
    nSidesInner       = 4;
    innerShapeScale   = 0.5;
    innerShapeRotation = 0;

    cuboidMode        = false;
    uiCubTopLen       = 35;
    uiCubTopWid       = 35;
    uiCubBotLen       = 35;
    uiCubBotWid       = 35;
    uiCubRatioLock    = false;
    uiCubAspectLock   = false;

    sideTextureMode  = 0; // TEX_NONE
    panelTextures    = null;
    stripImg         = null;
    lidImgTop        = null;
    lidImgBot        = null;
    lidKeepAspect    = true;
    activeTextureTab = 0;

    topLidEnabled    = false;
    bottomLidEnabled = false;
    perPanelEnabled  = null;

    markerStartIndex = 48;
    label            = "";
    shapeColor       = color(255);
    fillColorEnabled = false;

    nRep             = 1;
    repPositions     = null;
    cachedBBox       = null;
  }
}

// ---------------------------------------------------------------------------
// Deep-copy helper for EdgeProfile
// ---------------------------------------------------------------------------
EdgeProfile deepCopyEdgeProfile(EdgeProfile src) {
  if (src == null) return null;
  EdgeProfile dst = new EdgeProfile(src.n, 1.0, src.mmToPx);
  arrayCopy(src.mm, dst.mm);
  return dst;
}

// ---------------------------------------------------------------------------
// Save current global state into a ShapeSpec.
// Always call this before switching the selected shape.
// ---------------------------------------------------------------------------
void saveGlobalsTo(ShapeSpec s) {
  if (s == null) return;

  // Geometry
  s.nSides         = nSides;
  s.cylinder       = new PVector(cylinder.x, cylinder.y, cylinder.z);
  s.tabDepth       = tabDepth;
  s.flapDepth      = flapDepth;
  s.flapTaper      = flapTaper;
  s.hookOffset     = hookOffset;
  s.tab_neck_ratio = tab_neck_ratio;
  s.dashLen        = dash;
  s.perEdgeMode    = perEdgeMode;
  s.edgesTop       = deepCopyEdgeProfile(edgesTop);
  s.edgesBottom    = deepCopyEdgeProfile(edgesBottom);

  // UI mirrors
  s.uiSides             = uiSides;
  s.uiHeight            = uiHeight;
  s.uiTopW              = uiTopW;
  s.uiBotW              = uiBotW;
  s.uiLock              = uiLock;
  s.uiHidePanelFolds    = uiHidePanelFolds;
  s.uiLightGrayCutLines = uiLightGrayCutLines;

  // Lid positioning
  s.uiLidOffsetX      = uiLidOffsetX;
  s.uiLidOffsetY      = uiLidOffsetY;
  s.uiTopLidOffsetX   = uiTopLidOffsetX;
  s.uiTopLidOffsetY   = uiTopLidOffsetY;
  s.uiTopLidRotation  = uiTopLidRotation;
  s.uiBotLidOffsetX   = uiBotLidOffsetX;
  s.uiBotLidOffsetY   = uiBotLidOffsetY;
  s.uiBotLidRotation  = uiBotLidRotation;
  s.uiInnerWallOffsetX = uiInnerWallOffsetX;
  s.uiInnerWallOffsetY = uiInnerWallOffsetY;

  // Modes
  s.splitStrip       = splitStrip;
  s.uiSplitHalf1OffsetX = uiSplitHalf1OffsetX;
  s.uiSplitHalf1OffsetY = uiSplitHalf1OffsetY;
  s.uiSplitHalf1Rotation = uiSplitHalf1Rotation;
  s.uiSplitHalf2OffsetX = uiSplitHalf2OffsetX;
  s.uiSplitHalf2OffsetY = uiSplitHalf2OffsetY;
  s.uiSplitHalf2Rotation = uiSplitHalf2Rotation;
  s.textureBleed     = textureBleed;
  s.hollowMode       = hollowMode;
  s.wallThickness    = wallThickness;
  s.enableInnerShape = enableInnerShape;
  s.nSidesInner      = nSidesInner;
  s.innerShapeScale  = innerShapeScale;
  s.innerShapeRotation = innerShapeRotation;

  // Cuboid mode
  s.cuboidMode       = cuboidMode;
  s.uiCubTopLen      = uiCubTopLen;
  s.uiCubTopWid      = uiCubTopWid;
  s.uiCubBotLen      = uiCubBotLen;
  s.uiCubBotWid      = uiCubBotWid;
  s.uiCubRatioLock   = uiCubRatioLock;
  s.uiCubAspectLock  = uiCubAspectLock;

  // Textures (reference, not deep copy)
  s.sideTextureMode  = sideTextureMode;
  s.panelTextures    = panelTextures;
  s.stripImg         = stripImg;
  s.lidImgTop        = lidImgTop;
  s.lidImgBot        = lidImgBot;
  s.lidKeepAspect    = lidKeepAspect;

  // Sidebar state
  if (sidebar != null) {
    s.topLidEnabled    = sidebar.topLidEnabled;
    s.bottomLidEnabled = sidebar.bottomLidEnabled;
    s.activeTextureTab = sidebar.activeTextureTab;
    if (sidebar.perPanelEnabled != null) {
      s.perPanelEnabled = new boolean[sidebar.perPanelEnabled.length];
      arrayCopy(sidebar.perPanelEnabled, s.perPanelEnabled);
    }
  }

  // Markers
  s.markerStartIndex = Start_Index;

  // Solid fill color
  s.shapeColor       = shapeColor;
  s.fillColorEnabled = fillColorEnabled;

  // Placement
  s.nRep         = nRep;
  s.repPositions = repPositions;
}

// ---------------------------------------------------------------------------
// Load a ShapeSpec into the current global state.
// Call setParams(false) after this to recalculate all _px derived values.
// ---------------------------------------------------------------------------
void loadGlobalsFrom(ShapeSpec s) {
  if (s == null) return;

  // Geometry
  nSides         = s.nSides;
  cylinder.set(s.cylinder.x, s.cylinder.y, s.cylinder.z);
  tabDepth       = s.tabDepth;
  flapDepth      = s.flapDepth;
  flapTaper      = s.flapTaper;
  hookOffset     = s.hookOffset;
  tab_neck_ratio = s.tab_neck_ratio;
  dash           = s.dashLen;
  perEdgeMode    = s.perEdgeMode;
  edgesTop       = deepCopyEdgeProfile(s.edgesTop);
  edgesBottom    = deepCopyEdgeProfile(s.edgesBottom);

  // UI mirrors
  uiSides             = s.uiSides;
  uiHeight            = s.uiHeight;
  uiTopW              = s.uiTopW;
  uiBotW              = s.uiBotW;
  uiLock              = s.uiLock;
  uiHidePanelFolds    = s.uiHidePanelFolds;
  uiLightGrayCutLines = s.uiLightGrayCutLines;

  // Lid positioning
  uiLidOffsetX      = s.uiLidOffsetX;
  uiLidOffsetY      = s.uiLidOffsetY;
  uiTopLidOffsetX   = s.uiTopLidOffsetX;
  uiTopLidOffsetY   = s.uiTopLidOffsetY;
  uiTopLidRotation  = s.uiTopLidRotation;
  uiBotLidOffsetX   = s.uiBotLidOffsetX;
  uiBotLidOffsetY   = s.uiBotLidOffsetY;
  uiBotLidRotation  = s.uiBotLidRotation;
  uiInnerWallOffsetX = s.uiInnerWallOffsetX;
  uiInnerWallOffsetY = s.uiInnerWallOffsetY;

  // Modes
  splitStrip       = s.splitStrip;
  uiSplitHalf1OffsetX = s.uiSplitHalf1OffsetX;
  uiSplitHalf1OffsetY = s.uiSplitHalf1OffsetY;
  uiSplitHalf1Rotation = s.uiSplitHalf1Rotation;
  uiSplitHalf2OffsetX = s.uiSplitHalf2OffsetX;
  uiSplitHalf2OffsetY = s.uiSplitHalf2OffsetY;
  uiSplitHalf2Rotation = s.uiSplitHalf2Rotation;
  textureBleed     = s.textureBleed;
  hollowMode       = s.hollowMode;
  wallThickness    = s.wallThickness;
  enableInnerShape = s.enableInnerShape;
  nSidesInner      = s.nSidesInner;
  innerShapeScale  = s.innerShapeScale;
  innerShapeRotation = s.innerShapeRotation;

  // Cuboid mode
  cuboidMode       = s.cuboidMode;
  uiCubTopLen      = s.uiCubTopLen;
  uiCubTopWid      = s.uiCubTopWid;
  uiCubBotLen      = s.uiCubBotLen;
  uiCubBotWid      = s.uiCubBotWid;
  uiCubRatioLock   = s.uiCubRatioLock;
  uiCubAspectLock  = s.uiCubAspectLock;

  // Textures
  sideTextureMode  = s.sideTextureMode;
  panelTextures    = s.panelTextures;
  stripImg         = s.stripImg;
  lidImgTop        = s.lidImgTop;
  lidImgBot        = s.lidImgBot;
  lidKeepAspect    = s.lidKeepAspect;

  // Sidebar state
  if (sidebar != null) {
    sidebar.topLidEnabled    = s.topLidEnabled;
    sidebar.bottomLidEnabled = s.bottomLidEnabled;
    sidebar.activeTextureTab = s.activeTextureTab;
    if (s.perPanelEnabled != null) {
      sidebar.perPanelEnabled = new boolean[s.perPanelEnabled.length];
      arrayCopy(s.perPanelEnabled, sidebar.perPanelEnabled);
    } else {
      // Default: all enabled for this shape's nSides
      int np = max(3, s.nSides);
      sidebar.perPanelEnabled = new boolean[np];
      for (int i = 0; i < np; i++) sidebar.perPanelEnabled[i] = false;
    }
  }

  // Markers
  Start_Index = s.markerStartIndex;

  // Solid fill color
  shapeColor       = s.shapeColor;
  fillColorEnabled = s.fillColorEnabled;

  // Placement
  nRep         = s.nRep;
  repPositions = s.repPositions;
}

// ---------------------------------------------------------------------------
// Create a new ShapeSpec capturing all current global state.
// ---------------------------------------------------------------------------
ShapeSpec shapeFromCurrentGlobals() {
  ShapeSpec s = new ShapeSpec();
  saveGlobalsTo(s);
  return s;
}

// ---------------------------------------------------------------------------
// Initialise or reset repPositions for a single shape using its own bbox.
// Caller must have called loadGlobalsFrom(s) + setParams(false) first.
// ---------------------------------------------------------------------------
void initRepPositionsForShape(ShapeSpec s) {
  PVector bbox = (s.cachedBBox != null) ? s.cachedBBox : getTemplateBBox();
  s.repPositions = new PVector[s.nRep];
  for (int i = 0; i < s.nRep; i++) {
    s.repPositions[i] = new PVector(
      ((i % 2) * bbox.x) / MM_current,
      ((i / 2) * bbox.y) / MM_current
    );
  }
}

// ---------------------------------------------------------------------------
// Add a new shape to the shapes list, copying current globals as the template.
// Enables free placement mode so the new shape can be independently positioned.
// ---------------------------------------------------------------------------
void addShape() {
  if (shapes == null) return;

  // Persist any pending edits on the currently selected shape
  saveGlobalsTo(shapes.get(selectedShapeIdx));

  // Enable free placement so users can independently reposition shapes
  if (!freePlacementMode) {
    freePlacementMode = true;
    if (tFreePlacement != null) tFreePlacement.setValue(1);
    if (btnResetPlacement != null) btnResetPlacement.setVisible(true);
    // Initialise positions for all existing shapes
    for (int si = 0; si < shapes.size(); si++) {
      ShapeSpec existing = shapes.get(si);
      if (existing.repPositions == null) {
        loadGlobalsFrom(existing);
        setParams(false);
        initRepPositionsForShape(existing);
        saveGlobalsTo(existing); // persist repPositions
      }
    }
    // Restore selected shape globals
    loadGlobalsFrom(shapes.get(selectedShapeIdx));
    setParams(false);
  }

  // Build the new shape from current globals
  ShapeSpec ns = shapeFromCurrentGlobals();

  // Auto-place the new shape below all existing content
  float newYmm = 0;
  for (int si = 0; si < shapes.size(); si++) {
    ShapeSpec ex = shapes.get(si);
    float shapeH = (ex.cachedBBox != null) ? (ex.cachedBBox.y / MM) : 100;
    float maxRepY = 0;
    if (ex.repPositions != null) {
      for (PVector rp : ex.repPositions) maxRepY = max(maxRepY, rp.y);
    }
    newYmm = max(newYmm, maxRepY + shapeH + 5);
  }
  ns.nRep = 1;
  ns.repPositions = new PVector[] { new PVector(0, newYmm) };

  shapes.add(ns);
  selectedShapeIdx = shapes.size() - 1;

  loadGlobalsFrom(ns);
  setParams(false);
  syncUIToSelectedShape();
  redraw();
}

// ---------------------------------------------------------------------------
// Remove the currently selected shape (no-op if only one shape remains).
// ---------------------------------------------------------------------------
void removeShape() {
  if (shapes == null || shapes.size() <= 1) return;

  shapes.remove(selectedShapeIdx);
  selectedShapeIdx = constrain(selectedShapeIdx, 0, shapes.size() - 1);

  loadGlobalsFrom(shapes.get(selectedShapeIdx));
  setParams(false);
  syncUIToSelectedShape();
  redraw();
}
