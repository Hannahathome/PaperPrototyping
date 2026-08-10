import controlP5.*;
import processing.svg.*;
import processing.pdf.*;
boolean bSavePDF = false;
String pdfFilename = "output/results.pdf";
String svgFilename = "output/results.svg";
int exportNotifyTimer = 0;    // frames remaining to show export notification
String exportNotifyPath = ""; // path shown in export notification
String timestamp = "";
PGraphicsPDF pdf;
PGraphics svg;
int nSides = 4; //starting number of sides
int controlMode = 0;

//--RH-- Fiducial Marker Variables
PImage img;             // Declare variable for the image
int[][] pixelArray;     // 2D integer array to store pixel values
Marker[] m = null;      // Will be initialized on demand (lazy loading)
color ck = color(0);
int Start_Index = 48;   // Marker starting index
int Marker_Size = 20;   // Marker size in mm
int Marker_Pos = 1;     // Marker position
int markerGrid = 1;     // markers per side (NxN grid) — >1 tiles multiple markers on large lids
// Free-placement of markers: per-marker CENTRE offset (mm) from the lid centre. Initialised
// to the grid layout; the user can drag each marker when markerFreePlace is on.
ArrayList<PVector> markerOffsets = new ArrayList<PVector>();
boolean markerFreePlace = false;
int draggedMarkerIdx = -1;
PVector markerDragOffset = new PVector();
int nRep = 1;           // Number of template repeats (mirrors selectedShape.nRep)
boolean freePlacementMode = true;  // Always use free placement for repeat copies
PVector[] repPositions = null;      // Per-copy positions in MM (mirrors selectedShape.repPositions)
int draggedRepIdx = -1;             // Which copy is being dragged (-1 = none)
int draggedShapeIdx = -1;           // Which shape is being dragged (-1 = none)
PVector dragOffset = new PVector(); // Mouse offset within the dragged copy (in mm)
int draggedCutoutIdx = -1;          // Which cutout is being dragged (-1 = none)
PVector cutoutDragOffset = new PVector(); // Mouse offset within the dragged cutout (in mm)
float canvasOffsetX = 0;            // Current screen X of the A4 canvas top-left (updated each draw)
float canvasOffsetY = 0;            // Current screen Y of the A4 canvas top-left (updated each draw)

// --- Multi-shape support ---
ArrayList<ShapeSpec> shapes = null; // All shapes on the page
int selectedShapeIdx = 0;           // Index of the currently selected / edited shape

// --- Bar Assembly mode ---
BarAssembly activeAssembly = null;     // Current assembly definition
boolean assemblyMode = false;          // True while in assembly mode
boolean workshopMode = false;          // True = simplified "workshop" UI (hides Assembly button)
boolean assemblyShowTemplate = false;  // True = show flat template, false = show 3D view
boolean assemblyTrueColor = false;     // True = use shape's own colour/texture in 3D assembly view
// Assembly piece drag (0=strip, 1=bottomLid, 2=topLid, -1=none)
int asmDragPiece = -1;
PVector asmDragOffset = new PVector(); // mouse offset from piece translate origin at drag start (px)

// --- Solid fill color (per-shape, mirrored from ShapeSpec via global-swap) ---
color shapeColor = color(255);      // Active fill color
boolean fillColorEnabled = false;   // Whether solid fill is active for current shape
boolean bExportingCutFile = false;  // True while writing SVG cut file — suppresses color fill
//--RH--
//----------------------------------------------------------------------------------

void setup() {
  size(1500, 800, P2D);
  ensurePlaceholderAssets();  // data/ artwork is gitignored; generate it if absent
  setParams(false);
  background(200);
  toolbar = new Toolbar();
  toolbar.setup();
  sidebar = new SidebarPanel();
  sidebar.setup();
  initShapeUI();
  
  // Initialize 3D buffer (adjust for sidebar)
  view3DBuffer = createGraphics(width - LEFT_SIDEBAR_WIDTH, height - TOOLBAR_HEIGHT, P3D);
  
  // Initialize mini 3D buffer for 2D mode
  mini3DBuffer = createGraphics(MINI_3D_WIDTH, MINI_3D_HEIGHT, P3D);
  
  // Initialize image cropper
  imageCropper = new ImageCropper();
  
  // Initialize the shapes list with the current (default) shape
  shapes = new ArrayList<ShapeSpec>();
  shapes.add(shapeFromCurrentGlobals());
  selectedShapeIdx = 0;
  
  // Initialize free placement positions for the first shape
  initRepPositions();

  // Initialize bar assembly with a 2-bar default (2x1)
  activeAssembly = new BarAssembly(5, 1);
  activeAssembly.setCell(0, 0, 0);
  activeAssembly.setCell(0, 1, 0);
  
  //--RH-- Markers: Lazy loaded when user enables toggle (not in setup to avoid PDF issues)
  //--RH--
}

void draw() {
  // Update continuous lid movement if button is held
  updateHeldLidButton();
  
  if (!bSavePDF) {
    background(200);
    
    // PLATONIC SOLIDS TEST MODE
    if (platonicTestMode) {
      if (platonicSelectedSolid < 0) {
        drawPlatonicSolidGallery();
      } else {
        drawPlatonicSolidDetailed(platonicSelectedSolid);
      }
      return;  // Skip normal rendering
    }
    
    // PLATONIC SOLIDS EDIT MODE
    if (platonicEditMode) {
      drawTemplateEditMode();
      return;  // Skip normal rendering
    }

    // BAR ASSEMBLY MODE — flat template view (only when assemblyShowTemplate is on)
    if (assemblyMode && assemblyShowTemplate) {
      float availW2 = width - LEFT_SIDEBAR_WIDTH;
      float availH2 = height - TOOLBAR_HEIGHT - BOTTOM_EXPORT_HEIGHT;
      float cOffX = LEFT_SIDEBAR_WIDTH + (availW2 - widthA4_display) / 2;
      float cOffY = TOOLBAR_HEIGHT + (availH2 - heightA4_display) / 2;
      canvasOffsetX = cOffX;
      canvasOffsetY = cOffY;
      pushMatrix();
      translate(cOffX, cOffY);
      scale(SCREEN_SCALE);
      drawA4Paper();
      setParams(false);
      pushMatrix();
      drawCalibCrosses();
      translate(patX_px, patY_px);
      rotate(radians(patRotation));
      drawAssemblyPlan(activeAssembly);
      popMatrix();
      popMatrix();
      toolbar.draw();
      toolbar.drawDropdown();
      sidebar.draw();
      drawBottomExportButton();
      return;
    }

    // Check if in 3D mode
    if (view3DMode) {
      draw3DView();
      // Position 3D view to the right of sidebar
      image(view3DBuffer, LEFT_SIDEBAR_WIDTH, TOOLBAR_HEIGHT);
      
      // --- Show Selected / Show All overlay buttons ---
      draw3DViewModeButtons();
      
      toolbar.draw();
      toolbar.drawDropdown();  // Draw dropdown menu if active
      sidebar.draw();
      drawBottomExportButton();
      
      // Draw cropper overlay last (if active)
      if (cropperActive && imageCropper != null) {
        imageCropper.draw();
      }
      return;
    }
    
    // Calculate available space and center the A4 canvas
    float availableWidth = width - LEFT_SIDEBAR_WIDTH;
    float availableHeight = height - TOOLBAR_HEIGHT - BOTTOM_EXPORT_HEIGHT;
    float centerOffsetX = LEFT_SIDEBAR_WIDTH + (availableWidth - widthA4_display) / 2;
    float centerOffsetY = TOOLBAR_HEIGHT + (availableHeight - heightA4_display) / 2;
    canvasOffsetX = centerOffsetX;  // save for mouse coordinate transforms
    canvasOffsetY = centerOffsetY;
    
    pushMatrix();
    translate(centerOffsetX, centerOffsetY);
    scale(SCREEN_SCALE);  // Scale down for screen display
    
    drawA4Paper();
    setParams(false);
    pushMatrix();
    drawCalibCrosses();
    translate(patX_px, patY_px);
    rotate(radians(patRotation));
    
    // --- Multi-shape draw loop ---
    _baseDrawnThisFrame = false;   // base plate draws once, during the first shape
    _piecesCapturedThisFrame = false;  // distance-overlay bboxes captured once
    int _autoIdx = (shapes.size() > 0) ? shapes.get(0).markerStartIndex : Start_Index;
    for (int si = 0; si < shapes.size(); si++) {
      ShapeSpec _s = shapes.get(si);
      loadGlobalsFrom(_s);
      setParams(false);
      _s.cachedBBox    = getTemplateBBox();
      _s.cachedBBoxTop = _bboxTopTemp;
      PVector bbox = _s.cachedBBox;
      
      for (int rep = 0; rep < _s.nRep; rep++) {
        if (autoMarkerIDs) { Start_Index = _autoIdx; _autoIdx += max(1, markerGrid*markerGrid); }
        else Start_Index = _s.markerStartIndex + rep;
        pushMatrix();
        if (freePlacementMode && _s.repPositions != null && rep < _s.repPositions.length) {
          translate(_s.repPositions[rep].x * MM_current, _s.repPositions[rep].y * MM_current);
        } else {
          translate((rep % 2) * bbox.x, (rep / 2) * bbox.y);
        }
        
        // Selection highlight (orange) when multiple shapes exist.
        // bbox.z = overallLeft (≤ 0), _s.cachedBBoxTop = overallTop (the actual top of the AABB).
        float bboxTop = _s.cachedBBoxTop;
        if (shapes.size() > 1 && si == selectedShapeIdx) {
          pushStyle();
          noFill();
          stroke(255, 160, 0);
          strokeWeight(2.5 / SCREEN_SCALE);
          rect(bbox.z - 2 / SCREEN_SCALE, bboxTop - 2 / SCREEN_SCALE,
               bbox.x + 4 / SCREEN_SCALE,
               bbox.y + 4 / SCREEN_SCALE);
          popStyle();
        }
        
        // Drag highlight (blue) for the copy being dragged
        if (freePlacementMode && si == draggedShapeIdx && rep == draggedRepIdx) {
          pushStyle();
          noFill();
          stroke(50, 150, 255);
          strokeWeight(2 / SCREEN_SCALE);
          rect(bbox.z - 2 / SCREEN_SCALE, bboxTop - 2 / SCREEN_SCALE,
               bbox.x + 4 / SCREEN_SCALE,
               bbox.y + 4 / SCREEN_SCALE);
          popStyle();
        }
        
        // Shape label: small text at top-left of bounding box
        if (_s.label != null && !_s.label.isEmpty()) {
          pushStyle();
          fill(80);
          noStroke();
          textAlign(LEFT, BOTTOM);
          textSize(10 / SCREEN_SCALE);
          text(_s.label, 0, -tabDepth_px - 3 / SCREEN_SCALE);
          popStyle();
        }
        
        // Draw textured lids for preview (if any lid textures are enabled)
        if (sidebar != null && (_s.topLidEnabled || _s.bottomLidEnabled)) {
          if ((perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null) {
            texturedLidsForPrint_PerEdge(g);
          } else {
            texturedLidsForPrint_Uniform(g);
          }
        }
        
        drawPlan(true);
        popMatrix();
      }
    }
    // Restore globals to selected shape so the sidebar reflects correct values
    loadGlobalsFrom(shapes.get(selectedShapeIdx));
    setParams(false);
    // Always trust the actual toggle state — loadGlobalsFrom may carry a stale uiLock
    if (tLock != null) uiLock = tLock.getState();
    // Distance overlay (preview only, in the pattern frame)
    drawDistanceOverlay();
    popMatrix();  // Close drawCalibCrosses/translate matrix
    
    // Draw shape parameter info note at the bottom of the A4 page
    drawShapeInfoNote();
    
    popMatrix();  // Close sidebar/toolbar offset matrix
    
    // Draw UI elements AFTER everything else (on top)
    toolbar.draw();
    toolbar.drawDropdown();  // Draw dropdown menu if active
    sidebar.draw();
    drawBottomExportButton();
    
    // Draw cropper overlay last (if active)
    if (cropperActive && imageCropper != null) {
      imageCropper.draw();
    }
  } else {
    exportPlan();
    bSavePDF = false;
    exportNotifyTimer = 240;  // ~4 seconds at 60fps
    exportNotifyPath = pdfFilename;
  }
}

void drawA4Paper() {
  background(200);
  pushMatrix();
  fill(255);
  stroke(0);
  rect(0, 0, widthA4, heightA4);
  popMatrix();
}

void drawPlan(boolean img) {
  pushStyle();
  rectMode(CORNER);
  // Only compensate for screen scaling when NOT exporting to PDF
  // (SVG exports call this via beginRecord, so strokeWeight is already set by caller)
  if (!bSavePDF) {
    strokeWeight(1 / SCREEN_SCALE);  // Compensate for screen scaling
  }
  // For PDF/SVG exports, strokeWeight is set by the caller

  // BASE ONLY: print/cut just the base plate — skip the strip, lids, cutouts and markers.
  if (baseOnly) {
    if (!bSavePDF) strokeWeight(1 / SCREEN_SCALE);
    if (!_baseDrawnThisFrame) {
      pushMatrix();
      float baseAnchorY = 20 * MM_current;   // small top margin (no lids to sit below)
      translate(baseOffsetX * MM_current, baseAnchorY + baseOffsetY * MM_current);
      if (baseBoxMode) drawBaseBox(); else drawBasePlate();
      popMatrix();
      _baseDrawnThisFrame = true;
      _baseAnchorYmm = baseAnchorY / MM_current;
      _baseBBoxX = baseOffsetX;
      _baseBBoxY = _baseAnchorYmm + baseOffsetY;
      float _blT = baseTwoPlates ? 2 * baseLengthMM : baseLengthMM;
      _baseBBoxW = baseBoxMode ? (baseWidthMM + 2 * baseWallHeightMM) : baseWidthMM;
      _baseBBoxH = baseBoxMode ? (_blT + 2 * baseWallHeightMM) : _blT;
      _baseDrawnValid = true;
    }
    popStyle();
    return;
  }

  // Draw cutouts FIRST so inner cuts are processed before outlines on cutting machines
  if (cutouts != null && cutouts.size() > 0) {
    // Apply top lid rotation so cutouts rotate with the lid
    PVector lidCenter = getTopLidCenterMM();
    float lcx = lidCenter.x * MM_current;
    float lcy = lidCenter.y * MM_current;
    pushMatrix();
    translate(lcx, lcy);
    rotate(radians(uiTopLidRotation));
    translate(-lcx, -lcy);
    if (bSavePDF) {
      drawAllCutoutsExport(MM_current);
    } else {
      drawAllCutouts(MM_current);
    }
    popMatrix();
  }
  
  pushMatrix();

  if ((perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null) { //variable prisms / cuboid
    int nEdges = min(edgeTop_px.length, edgeBot_px.length);
    float hPxPerEdge = cuboidMode && edgeSlantH_px != null ? edgeSlantH_px[0] : cylinderH_px;

    if (splitStrip && nEdges >= 4) {
      // --- SPLIT STRIP MODE (per-edge / cuboid) ---
      int splitAt = (int)ceil(nEdges / 2.0);
      float stripHeight = getStripHeight();
      float splitSpacing = stripHeight + tabDepth_px * 2 + 10 * MM_current;

      // === HALF 1: panels [0..splitAt) ===
      pushMatrix();
      translate(uiSplitHalf1OffsetX * MM_current, uiSplitHalf1OffsetY * MM_current);
      rotate(radians(uiSplitHalf1Rotation));
      if (sideTextureMode == TEX_STRIP_BENT && stripImg != null) {
        drawTriangleStripTexture_PerEdge_Range(g, stripImg, 0, splitAt);
      } else if (sideTextureMode == TEX_PER_PANEL) {
        drawPerPanelTexturesPerEdge_Range(g, 0, splitAt);
      }
      if (fillColorEnabled && !bExportingCutFile) {
        drawSolidColorPanelsPerEdge_Range(shapeColor, 0, splitAt);
      }
      drawTrapezoidsPerEdge_Range(0, 0, edgeTop_px, edgeBot_px, hPxPerEdge, (cols-1), true, 0, splitAt, true, true);
      popMatrix();
      pushMatrix();
      translate(uiSplitHalf1OffsetX * MM_current, uiSplitHalf1OffsetY * MM_current);
      rotate(radians(uiSplitHalf1Rotation));
      drawTzFoldlinesPerEdge_Range(0, 0, edgeTop_px, edgeBot_px, hPxPerEdge, (cols-1), 0, splitAt);
      popMatrix();

      // === HALF 2: panels [splitAt..nEdges) ===
      pushMatrix();
      translate(uiSplitHalf2OffsetX * MM_current, splitSpacing + uiSplitHalf2OffsetY * MM_current);
      rotate(radians(uiSplitHalf2Rotation));
      if (sideTextureMode == TEX_STRIP_BENT && stripImg != null) {
        drawTriangleStripTexture_PerEdge_Range(g, stripImg, splitAt, nEdges);
      } else if (sideTextureMode == TEX_PER_PANEL) {
        drawPerPanelTexturesPerEdge_Range(g, splitAt, nEdges);
      }
      if (fillColorEnabled && !bExportingCutFile) {
        drawSolidColorPanelsPerEdge_Range(shapeColor, splitAt, nEdges);
      }
      drawTrapezoidsPerEdge_Range(0, 0, edgeTop_px, edgeBot_px, hPxPerEdge, (cols-1), true, splitAt, nEdges, true, true);
      popMatrix();
      pushMatrix();
      translate(uiSplitHalf2OffsetX * MM_current, splitSpacing + uiSplitHalf2OffsetY * MM_current);
      rotate(radians(uiSplitHalf2Rotation));
      drawTzFoldlinesPerEdge_Range(0, 0, edgeTop_px, edgeBot_px, hPxPerEdge, (cols-1), splitAt, nEdges);
      popMatrix();
    } else {
      // --- NORMAL SINGLE STRIP (per-edge / cuboid) ---
      // Panels + folds
      pushMatrix();
      // Draw textured side panels based on mode
      if (sideTextureMode == TEX_STRIP_BENT && stripImg != null) {
        drawTriangleStripTexture_PerEdge(g, stripImg);
      } else if (sideTextureMode == TEX_PER_PANEL) {
        drawPerPanelTexturesPerEdge(g);
      }
      if (fillColorEnabled && !bExportingCutFile) {
        drawSolidColorPanelsPerEdge(shapeColor);
      }
      if (cuboidMode && edgeSlantH_px != null) {
        drawTrapezoidsPerEdgeHollow(0, 0, edgeTop_px, edgeBot_px, edgeSlantH_px, (cols-1), true);
        drawTzFoldlinesPerEdge(0, 0, edgeTop_px, edgeBot_px, edgeSlantH_px[0], (cols-1));
      } else {
        drawTrapezoidsPerEdgeHollow(0, 0, edgeTop_px, edgeBot_px, cylinderH_px, (cols-1), true);
        drawTzFoldlinesPerEdge(0, 0, edgeTop_px, edgeBot_px, cylinderH_px, (cols-1));
      }
      popMatrix();
    }

    // Use actual strip height to prevent overlap
    float stripHeight = getStripHeight();
    // When split, lids need to be below both halves
    if (splitStrip && nEdges >= 4) {
      float splitSpacingLid = stripHeight + tabDepth_px * 2 + 10 * MM_current;
      stripHeight = splitSpacingLid + stripHeight;
    }
    float neckDepth_px2 = tabDepth_px * TAB_DEPTH_FRACTION;

    if (cuboidMode) {
      // --- CUBOID RECTANGULAR LIDS ---
      float botLidW = edgeBot_px[0];  // Length edges (index 0, 2)
      float botLidD = edgeBot_px[1];  // Width edges (index 1, 3)
      float topLidW = edgeTop_px[0];
      float topLidD = edgeTop_px[1];
      
      PVector botDimCub = getRectangularLidDimensions(botLidW, botLidD, tabDepth_px);
      PVector topDimCub = getRectangularLidDimensions(topLidW, topLidD, tabDepth_px);
      float extraLidSpace = max(0, topDimCub.y - botDimCub.y);
      float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * MM_current);

      // Bottom lid
      pushMatrix();
      translate((uiLidOffsetX + uiBotLidOffsetX) * MM_current, lidSpacing + (uiLidOffsetY + uiBotLidOffsetY) * MM_current);
      pushMatrix();
      translate(botDimCub.x/2, botDimCub.y/2);
      rotate(radians(uiBotLidRotation));
      translate(-botDimCub.x/2, -botDimCub.y/2);
      if (fillColorEnabled && !bExportingCutFile) {
        pushStyle();
        fill(shapeColor);
        noStroke();
        rect(tabDepth_px, tabDepth_px, botLidW, botLidD);
        popStyle();
      }
      drawRectangularLid(botLidW, botLidD, neckDepth_px2, tabInset_bot_px, arrowheadFlare_bot_px);
      popMatrix();
      popMatrix();

      // Top lid (offset to the right)
      pushMatrix();
      translate((uiLidOffsetX + uiTopLidOffsetX) * MM_current, lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * MM_current);
      translate(botDimCub.x, botDimCub.y - topDimCub.y);
      pushMatrix();
      translate(topDimCub.x/2, topDimCub.y/2);
      rotate(radians(uiTopLidRotation));
      translate(-topDimCub.x/2, -topDimCub.y/2);
      if (fillColorEnabled && !bExportingCutFile) {
        pushStyle();
        fill(shapeColor);
        noStroke();
        rect(tabDepth_px, tabDepth_px, topLidW, topLidD);
        popStyle();
      }
      drawRectangularLid(topLidW, topLidD, neckDepth_px2, tabInset_top_px, arrowheadFlare_top_px);
      popMatrix();
      
      // Marker on top lid
      if (markersEnabled && m != null && img) {
        float centerX = topDimCub.x / 2.0;
        float centerY = topDimCub.y / 2.0;
        float mkr_size = ((float)Marker_Size * MM);
        float mkr_actualsize = mkr_size * (9.0 / 7.0);
        translate(centerX, centerY);   // grid is centred on the lid
        drawMarkerGrid(mkr_size, mkr_actualsize, Start_Index, Marker_Pos);
      }
      popMatrix();
    } else {
      // --- VARIABLE POLYGON LIDS (non-cuboid per-edge mode) ---
      PVector botDim = getPolygonLidVarDimensions(edgeBot_px, tabDepth_px);
      PVector topDim = getPolygonLidVarDimensions(edgeTop_px, tabDepth_px);
      float extraLidSpace = max(0, topDim.y - botDim.y);
      float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * MM_current);

      // --- BOTTOM LID (always draw outline) ---
      pushMatrix();
      translate((uiLidOffsetX + uiBotLidOffsetX) * MM_current, lidSpacing + (uiLidOffsetY + uiBotLidOffsetY) * MM_current);
      PVector botOff = getPolygonLidVarOffset(edgeBot_px, tabDepth_px);
      
      pushMatrix();
      translate(botOff.x + botDim.x/2, botOff.y + botDim.y/2); // Move to center
      rotate(radians(uiBotLidRotation)); // Apply rotation
      translate(-(botDim.x/2), -(botDim.y/2)); // Move back
      if (fillColorEnabled && !bExportingCutFile) {
        drawSolidColorVarLid(edgeBot_px, shapeColor);
      }
      drawPolygonLidVarHollow(edgeBot_px, neckDepth_px2, tabInset_bot_px, arrowheadFlare_bot_px, false);
      popMatrix();
      popMatrix();

      // --- TOP LID (always draw outline) - match uniform mode: translate(width, height_diff) ---
      pushMatrix();
      translate((uiLidOffsetX + uiTopLidOffsetX) * MM_current, lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * MM_current);
      translate(botDim.x, botDim.y - topDim.y);
      
      pushMatrix();
      PVector topOff = getPolygonLidVarOffset(edgeTop_px, tabDepth_px);
      translate(topOff.x + topDim.x/2, topOff.y + topDim.y/2); // Move to center
      rotate(radians(uiTopLidRotation)); // Apply rotation
      translate(-(topDim.x/2), -(topDim.y/2)); // Move back
      if (fillColorEnabled && !bExportingCutFile) {
        drawSolidColorVarLid(edgeTop_px, shapeColor);
      }
      drawPolygonLidVarHollow(edgeTop_px, neckDepth_px2, tabInset_top_px, arrowheadFlare_top_px, true);
      popMatrix();
      popMatrix();
    }
  } else {
    // if not variable prism, use the uniform pattern:
    if (splitStrip && nSides >= 4) {
      // --- SPLIT STRIP MODE (uniform) ---
      int splitAt = (int)ceil(nSides / 2.0);  // ceil(n/2) panels in first half
      float stripHeight = getStripHeight();
      float splitSpacing = stripHeight + tabDepth_px * 2 + 10 * MM_current;

      // === HALF 1: panels [0..splitAt) ===
      pushMatrix();
      translate(uiSplitHalf1OffsetX * MM_current, uiSplitHalf1OffsetY * MM_current);
      rotate(radians(uiSplitHalf1Rotation));
      if (fillColorEnabled && !bExportingCutFile) {
        drawSolidColorPanels_Range(shapeColor, 0, splitAt);
      }
      if (sideTextureMode == TEX_STRIP_BENT && stripImg != null) {
        drawTriangleStripTexture_Uniform_Range(g, stripImg, 0, splitAt);
      } else if (sideTextureMode == TEX_PER_PANEL) {
        drawPerPanelTexturesUniform_Range(g, 0, splitAt);
      }
      drawTrapezoids_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), 0, splitAt, img);
      drawTzFoldlines_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), 0, splitAt);
      drawTzTopFolds_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), 0, splitAt, true, true);
      popMatrix();

      // === HALF 2: panels [splitAt..nSides) ===
      pushMatrix();
      translate(uiSplitHalf2OffsetX * MM_current, splitSpacing + uiSplitHalf2OffsetY * MM_current);
      rotate(radians(uiSplitHalf2Rotation));
      if (fillColorEnabled && !bExportingCutFile) {
        drawSolidColorPanels_Range(shapeColor, splitAt, nSides);
      }
      if (sideTextureMode == TEX_STRIP_BENT && stripImg != null) {
        drawTriangleStripTexture_Uniform_Range(g, stripImg, splitAt, nSides);
      } else if (sideTextureMode == TEX_PER_PANEL) {
        drawPerPanelTexturesUniform_Range(g, splitAt, nSides);
      }
      drawTrapezoids_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), splitAt, nSides, img);
      drawTzFoldlines_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), splitAt, nSides);
      drawTzTopFolds_Range(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), splitAt, nSides, true, true);
      popMatrix();
    } else {
      // --- NORMAL SINGLE STRIP ---
      pushMatrix();
      // Kresling: shear the WHOLE strip (panels, fold lines, tabs and flaps) into the
      // parallelogram unfolded state. The original strip drawing stays leading — we just
      // apply a shear transform around the strip origin so the top edge slides sideways
      // while the bottom edge (y=0) stays put, and the tabs shear along with it.
      if (kreslingMode && !hollowMode) {
        shearX(kreslingShearAngle());
      }
      // Draw solid colour fill FIRST (always, as background under any texture)
      if (fillColorEnabled && !bExportingCutFile) {
        drawSolidColorPanels(shapeColor);
      }
      // Draw textured side panels based on mode
      if (sideTextureMode == TEX_STRIP_BENT && stripImg != null) {
        drawTriangleStripTexture_Uniform(g, stripImg);
      } else if (sideTextureMode == TEX_PER_PANEL) {
        drawPerPanelTexturesUniform(g);
      }
      // Kresling internal fold lines FIRST — so they are emitted first in the SVG and get
      // cut/scored before the outline (keeps the sheet anchored while the outline is cut last).
      if (kreslingMode) drawKreslingFoldlines(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (rows-1), kreslingSegments);
      // Then draw outlines and fold lines OVER the texture (original strip stays leading)
      drawTrapezoidsHollow(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1), img);
      drawTzFoldlines(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1));
      drawTzTopFolds(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1));
      popMatrix();
    }
    // Use actual strip height to prevent overlap
    float stripHeight = getStripHeight();
    // When split, lids need to be below both halves
    if (splitStrip && nSides >= 4) {
      float splitSpacingLid = stripHeight + tabDepth_px * 2 + 10 * MM_current;
      stripHeight = splitSpacingLid + stripHeight;
    }
    PVector lidBaseSize = getPolygonLidDimensions(nSides, cellBaseL_px, tabDepth_px);
    PVector lidTopSize  = getPolygonLidDimensions(nSides, cellTopL_px, tabDepth_px);
    // When top lid is taller than base lid (inverted frustum), it shifts up by (lidTopSize.y - lidBaseSize.y)
    // so lidSpacing must absorb that extra height to prevent it overlapping the strip.
    float extraLidSpace = max(0, lidTopSize.y - lidBaseSize.y);
    // lidSpacing must clear the LID_SPACING_MARGIN ratio, the bottom tabs, and any extra lid height
    float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * MM_current);

    float neckDepth_px2 = tabDepth_px * TAB_DEPTH_FRACTION;
    
    // Always draw bottom lid outline
    pushMatrix();
    translate((uiLidOffsetX + uiBotLidOffsetX) * MM_current, lidSpacing + (uiLidOffsetY + uiBotLidOffsetY) * MM_current);
    translate(lidBaseSize.x/2, lidBaseSize.y/2); // Move to center
    rotate(radians(uiBotLidRotation)); // Apply rotation
    translate(-lidBaseSize.x/2, -lidBaseSize.y/2); // Move back
    if (fillColorEnabled && !bExportingCutFile) {
      drawSolidColorLid(nSides, cellBaseL_px, shapeColor);
    }
    drawPolygonLidHollow(nSides, cellBaseL_px, neckDepth_px2, tabInset_bot_px, arrowheadFlare_bot_px, false);
    popMatrix();
    
    // Always draw top lid outline
    pushMatrix();
    translate((uiLidOffsetX + uiTopLidOffsetX) * MM_current, lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * MM_current);
    translate(lidBaseSize.x, lidBaseSize.y - lidTopSize.y);
    translate(lidTopSize.x/2, lidTopSize.y/2); // Move to center
    rotate(radians(uiTopLidRotation)); // Apply rotation
    translate(-lidTopSize.x/2, -lidTopSize.y/2); // Move back
    if (fillColorEnabled && !bExportingCutFile) {
      drawSolidColorLid(nSides, cellTopL_px, shapeColor);
    }
    drawPolygonLidHollow(nSides, cellTopL_px, neckDepth_px2, tabInset_top_px, arrowheadFlare_top_px, true);
    popMatrix();

    // Capture the main-piece bboxes (once) for the distance overlay
    if (showDistances && !_piecesCapturedThisFrame) {
      float stripW = nSides * max(cellBaseL_px, cellTopL_px);
      float botX = (uiLidOffsetX + uiBotLidOffsetX) * MM_current;
      float botY = lidSpacing + (uiLidOffsetY + uiBotLidOffsetY) * MM_current;
      float topX = (uiLidOffsetX + uiTopLidOffsetX) * MM_current + lidBaseSize.x;
      float topY = lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * MM_current + (lidBaseSize.y - lidTopSize.y);
      captureMainPieceBBoxes(stripW, getStripHeight(),
                             botX, botY, lidBaseSize.x, lidBaseSize.y,
                             topX, topY, lidTopSize.x, lidTopSize.y);
    }

    // Base plate (optional): a plate with slits at the bottom-lid tab bases. Placed below
    // the lids by default, then nudged by the user offset (like the lids). Drawn ONCE per
    // frame (during the first shape), so it isn't duplicated across the multi-shape loop.
    if (baseEnabled && !_baseDrawnThisFrame) {
      pushMatrix();
      float baseAnchorY = lidSpacing + lidBaseSize.y + 20 * MM_current;
      translate(baseOffsetX * MM_current, baseAnchorY + baseOffsetY * MM_current);
      if (baseBoxMode) drawBaseBox(); else drawBasePlate();
      popMatrix();
      _baseDrawnThisFrame = true;
      // Capture the pattern-mm bbox so the base can be dragged in the preview
      _baseAnchorYmm = baseAnchorY / MM_current;
      _baseBBoxX = baseOffsetX;
      _baseBBoxY = _baseAnchorYmm + baseOffsetY;
      float _baseLtotal = baseTwoPlates ? 2 * baseLengthMM : baseLengthMM;
      _baseBBoxW = baseBoxMode ? (baseWidthMM + 2 * baseWallHeightMM) : baseWidthMM;
      _baseBBoxH = baseBoxMode ? (_baseLtotal + 2 * baseWallHeightMM) : _baseLtotal;
      _baseDrawnValid = true;
    }
    
    //--RH-- Draw Fiducial Marker (if enabled, only for PDF printed pages, not SVG cuts)
    if (markersEnabled && m != null && img) {
      pushMatrix();
      translate((uiLidOffsetX + uiTopLidOffsetX) * MM_current, lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * MM_current);
      translate(lidBaseSize.x, lidBaseSize.y - lidTopSize.y);
      
      // Calculate the actual center of the polygon (same as drawPolygonLidHollow)
      float radius = (cellTopL_px / 2.0) / sin(PI / nSides);
      float angleIncrement = TWO_PI / nSides;
      float rectWidth = (radius * cos(angleIncrement/2) + tabDepth_px) * 2;
      float centerX = rectWidth/2;
      float centerY = rectWidth/2;
      
      translate(centerX, centerY); // Move to center
      rotate(radians(uiTopLidRotation)); // Apply same rotation as lid
      translate(-centerX, -centerY); // Move back
      
      float mkr_size = ((float)Marker_Size*MM);
      float mkr_actualsize = mkr_size*(9./7.);
      translate(centerX, centerY);   // grid is centred on the lid
      drawMarkerGrid(mkr_size, mkr_actualsize, Start_Index, Marker_Pos);
      popMatrix();
    }
    //--RH--
  }
  
  popMatrix();     //
  popStyle();
}

void exportPlan() {
  timestamp = month()+"_"+day()+"_"+hour()+"_"+minute()+"_"+second();
  setParams(false);
  drawFrontPDF(); //pdf

  setParams(true);
  saveFrontFold(); //cut
  saveFrontCalib(); //calibs
}

// Returns the bounding box of one full template (strip + lids) in current pixel units.
// Used to position repeated copies on the page (see nRep).
// .x = total width  (from overallLeft to rightmost edge)
// .y = total height (from overallTop  to bottom of lids)
// .z = overallLeft: x offset from template origin to left edge (≤ 0)
// Also writes overallTop into the ShapeSpec via a companion cachedBBoxTop field —
// the caller must store the result into _s.cachedBBox and _s.cachedBBoxTop themselves.
// This function only sets globals; the draw loop assigns both fields after calling.
PVector getTemplateBBox() {
  float stripH = getStripHeight();
  float gap = 5 * MM_current;

  // When split mode is active, effective strip height is doubled + spacing
  if (splitStrip) {
    float splitSpacing = stripH + tabDepth_px * 2 + 10 * MM_current;
    stripH = splitSpacing + stripH;
  }

  // Simulate the actual strip geometry to get a tight AABB (includes flap corners).
  float[] aabb = computeStripAABB();
  float stripMinX = aabb[0];
  float stripMinY = aabb[1];  // may be < 0 when strip rotates upward (tapered)
  float stripMaxX = aabb[2];

  // Top of the bounding rect: the strip AABB already includes tab extents (added in the
  // AABB simulation), so stripMinY is the true topmost point of the strip + tabs.
  float overallTop = stripMinY;

  // Lids are drawn below lidSpacing from y=0.  Bottom of the whole template.
  // lidSpacing is computed per-branch so we can account for inverted frustum:
  // both lids are bottom-aligned at y = lidSpacing + baseDim.y, but the top lid
  // starts higher by (topDim.y - baseDim.y) when top > base, so lidSpacing must
  // absorb that extra height to prevent the top lid from overlapping the strip.
  float lidBottom;
  float overallLeft, lidRight, bboxW;
  if ((perEdgeMode || cuboidMode) && edgeBot_px != null && edgeTop_px != null) {
    PVector botDim, topDim;
    if (cuboidMode) {
      botDim = getRectangularLidDimensions(edgeBot_px[0], edgeBot_px[1], tabDepth_px);
      topDim = getRectangularLidDimensions(edgeTop_px[0], edgeTop_px[1], tabDepth_px);
    } else {
      botDim = getPolygonLidVarDimensions(edgeBot_px, tabDepth_px);
      topDim = getPolygonLidVarDimensions(edgeTop_px, tabDepth_px);
    }
    float extraLidSpace = max(0, topDim.y - botDim.y);
    float lidSpacing = max(stripH * LID_SPACING_MARGIN, stripH + tabDepth_px + extraLidSpace + 2 * MM_current);
    lidRight   = botDim.x + topDim.x;
    lidBottom  = lidSpacing + botDim.y;  // both lids end at lidSpacing + botDim.y
    overallLeft = min(stripMinX, 0);
    bboxW       = max(stripMaxX, lidRight) - overallLeft + gap;
  } else {
    PVector lidBaseDim = getPolygonLidDimensions(nSides, cellBaseL_px, tabDepth_px);
    PVector lidTopDim  = getPolygonLidDimensions(nSides, cellTopL_px, tabDepth_px);
    float extraLidSpace = max(0, lidTopDim.y - lidBaseDim.y);
    float lidSpacing = max(stripH * LID_SPACING_MARGIN, stripH + tabDepth_px + extraLidSpace + 2 * MM_current);
    lidRight   = lidBaseDim.x + lidTopDim.x;
    lidBottom  = lidSpacing + lidBaseDim.y;  // both lids end at lidSpacing + lidBaseDim.y
    overallLeft = min(stripMinX, 0);
    bboxW       = max(stripMaxX, lidRight) - overallLeft + gap;
  }

  float bboxH = lidBottom - overallTop + gap;

  // Pack overallTop into a temporary global so the draw loop can store it.
  _bboxTopTemp = overallTop;

  return new PVector(bboxW, bboxH, overallLeft);
}
// Temporary variable written by getTemplateBBox(), read immediately after by the draw loop.
float _bboxTopTemp = 0;

// Initialise free placement positions from the current auto-grid layout.
// Positions are stored in physical mm, relative to the patX/patY origin.
// Also syncs the result back into the selected ShapeSpec.
void initRepPositions() {
  PVector bbox = getTemplateBBox();
  repPositions = new PVector[nRep];
  for (int i = 0; i < nRep; i++) {
    repPositions[i] = new PVector(
      ((i % 2) * bbox.x) / MM_current,
      ((i / 2) * bbox.y) / MM_current
    );
  }
  // Sync to selected shape
  if (shapes != null && selectedShapeIdx >= 0 && selectedShapeIdx < shapes.size()) {
    shapes.get(selectedShapeIdx).repPositions = repPositions;
  }
}

// Convert a screen pixel coordinate to the pattern-space position in mm
// (relative to the patX/patY origin, accounting for patRotation).
PVector screenToPatternMM(float sx, float sy) {
  float canvasX = (sx - canvasOffsetX) / SCREEN_SCALE;
  float canvasY = (sy - canvasOffsetY) / SCREEN_SCALE;
  // Undo the translate(patX_px, patY_px)
  float rx = canvasX - patX_px;
  float ry = canvasY - patY_px;
  // Undo the rotate(patRotation)
  if (patRotation != 0) {
    float a = -radians(patRotation);
    float cosA = cos(a);
    float sinA = sin(a);
    float nx = rx * cosA - ry * sinA;
    float ny = rx * sinA + ry * cosA;
    rx = nx;
    ry = ny;
  }
  return new PVector(rx / MM_current, ry / MM_current);
}

void drawBottomExportButton() {
  // Skip drawing when cropper is active
  if (cropperActive) return;
  
  pushStyle();
  
  // Draw export bar background (same color as sidebar)
  fill(240, 240, 245);
  noStroke();
  rect(LEFT_SIDEBAR_WIDTH, height - BOTTOM_EXPORT_HEIGHT, width - LEFT_SIDEBAR_WIDTH, BOTTOM_EXPORT_HEIGHT);
  
  // Draw label for text field
  fill(80);
  textSize(10);
  float bottomControlX = LEFT_SIDEBAR_WIDTH + 20;
  float exportBarY = height - BOTTOM_EXPORT_HEIGHT + 10;
  float bottomControlY = exportBarY + 8;
  textAlign(LEFT, CENTER);
  textSize(15);  // Increased to match sidebar header text
  float exportBarX = width - 320;
  text("File name input field", exportBarX - 140, exportBarY + 23);

  // Export success notification: green fading text above the export button
  if (exportNotifyTimer > 0) {
    exportNotifyTimer--;
    float fadeAlpha = min(255, exportNotifyTimer * 3.5);
    fill(30, 160, 60, fadeAlpha);
    textAlign(RIGHT, BOTTOM);
    textSize(12);
    String notifyLabel = "Saved: " + exportNotifyPath;
    text(notifyLabel, exportBarX + 310, exportBarY + 4);
  }
  
  popStyle();
}

// ---------------------------------------------------------------------------
// Draw shape parameter info note at the bottom of the A4 page.
// Uses distinct colors per shape for differentiation.
// Called within the A4 canvas coordinate space (0,0 = top-left of page).
// ---------------------------------------------------------------------------
void drawShapeInfoNote() {
  if (shapes == null || shapes.size() == 0) return;
  
  pushStyle();
  textAlign(LEFT, BOTTOM);
  textSize(8 / SCREEN_SCALE);
  
  // Distinct colors for each shape (up to 8, then cycle)
  color[] shapeColors = {
    color(220, 60, 60),    // red
    color(40, 120, 200),   // blue
    color(30, 160, 70),    // green
    color(180, 100, 20),   // orange
    color(130, 50, 180),   // purple
    color(0, 160, 160),    // teal
    color(180, 50, 120),   // magenta
    color(100, 100, 100)   // grey
  };
  
  float margin = 5 * MM;
  float lineH = 10 / SCREEN_SCALE;  // line spacing in px
  float y = heightA4 - margin;
  
  // Draw from bottom up so last shape is lowest
  for (int i = shapes.size() - 1; i >= 0; i--) {
    ShapeSpec s = shapes.get(i);
    color c = shapeColors[i % shapeColors.length];
    fill(c);
    noStroke();
    
    // Build info string
    String name = (s.label != null && !s.label.isEmpty()) ? s.label : ("Shape " + (i + 1));
    float topW = s.cylinder.x / s.nSides;  // per-side top width
    float botW = s.cylinder.y / s.nSides;  // per-side bottom width
    float h = s.cylinder.z;
    float sideDiff = abs(botW - topW);
    float slantH = sqrt(h * h + sideDiff * sideDiff);
    String info = name + ":  " + s.nSides + " sides,  H=" + nf(h, 0, 1) + "mm,  Top=" + nf(topW, 0, 1) + "mm,  Bot=" + nf(botW, 0, 1) + "mm";
    info += ",  Hyp=" + nf(slantH, 0, 1) + "mm";
    if (s.nRep > 1) info += ",  x" + s.nRep;
    
    // Draw color indicator square
    float sq = 6 / SCREEN_SCALE;
    rect(margin, y - lineH + 2, sq, sq);
    // Draw text
    text(info, margin + 9 / SCREEN_SCALE, y);
    
    y -= lineH;
  }
  
  popStyle();
}

// Track bottom export button click to avoid multiple triggers
boolean bottomExportClicked = false;

// Returns the screen rect [x, y, w, h] of the two 3D view mode buttons.
// btn 0 = "Selected", btn 1 = "All"
float[] get3DViewBtnRect(int btnIdx) {
  float btnW = 90, btnH = 28, gap = 6;
  float bx = width - (3 * btnW + 2 * gap + 10);  // 3 buttons total (Selected, All, Wireframe)
  float by = TOOLBAR_HEIGHT + 10;
  return new float[]{ bx + btnIdx * (btnW + gap), by, btnW, btnH };
}

// Returns the screen rect [x, y, w, h] of the Wireframe toggle button.
float[] getWireframeBtnRect() {
  float[] allBtn = get3DViewBtnRect(1);  // "All" button
  float btnW = 90, btnH = 28, gap = 6;
  return new float[]{ allBtn[0] + allBtn[2] + gap, allBtn[1], btnW, btnH };
}

// Returns the screen rect [x, y, w, h] of the shape navigation arrow buttons.
// btn 0 = left arrow (◄), btn 1 = right arrow (►)
float[] get3DViewArrowRect(int btnIdx) {
  float arrowW = 32, arrowH = 28, gap = 4;
  // Position them to the left of the mode buttons, with room for the name label
  float[] modeBtn0 = get3DViewBtnRect(0);
  float labelW = 120;
  float bx = modeBtn0[0] - (labelW + 2 * arrowW + gap + 16);
  float by = TOOLBAR_HEIGHT + 10;
  return new float[]{ bx + btnIdx * (arrowW + gap), by, arrowW, arrowH };
}

void draw3DViewModeButtons() {
  if (shapes == null) return;
  pushStyle();
  textAlign(CENTER, CENTER);
  textSize(12);
  
  // --- Selected / All toggle buttons ---
  String[] labels = { "Selected", "All" };
  boolean[] active = { !view3DShowAll, view3DShowAll };
  
  for (int i = 0; i < 2; i++) {
    float[] r = get3DViewBtnRect(i);
    boolean hov = mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3];
    color bg = active[i] ? color(80, 130, 200) : (hov ? color(60, 70, 100) : color(40, 50, 80));
    fill(bg);
    noStroke();
    rect(r[0], r[1], r[2], r[3], 5);
    fill(255);
    text(labels[i], r[0] + r[2]/2, r[1] + r[3]/2);
  }
  
  // --- Wireframe toggle button ---
  {
    float[] r = getWireframeBtnRect();
    boolean hov = mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3];
    color bg = wireframeMode ? color(80, 130, 200) : (hov ? color(60, 70, 100) : color(40, 50, 80));
    fill(bg);
    noStroke();
    rect(r[0], r[1], r[2], r[3], 5);
    fill(255);
    text("Wireframe", r[0] + r[2]/2, r[1] + r[3]/2);
  }
  
  // --- Shape navigation arrows + name label (only when multiple shapes exist) ---
  if (shapes.size() > 1) {
    // Arrow buttons
    String[] arrows = { "\u25c4", "\u25ba" };
    boolean[] enabled = { selectedShapeIdx > 0, selectedShapeIdx < shapes.size() - 1 };
    for (int i = 0; i < 2; i++) {
      float[] r = get3DViewArrowRect(i);
      boolean hov = mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3];
      color bg = !enabled[i] ? color(30, 35, 55) : (hov ? color(60, 70, 100) : color(40, 50, 80));
      fill(bg);
      noStroke();
      rect(r[0], r[1], r[2], r[3], 5);
      fill(enabled[i] ? 255 : color(100));
      text(arrows[i], r[0] + r[2]/2, r[1] + r[3]/2);
    }
    // Name / number label to the right of the right arrow
    float[] rR = get3DViewArrowRect(1);
    float labelW = 120, labelH = 28, labelGap = 6;
    float lx = rR[0] + rR[2] + labelGap;
    float ly = rR[1];
    ShapeSpec cur = shapes.get(selectedShapeIdx);
    String shapeName = (cur.label != null && !cur.label.isEmpty())
      ? cur.label
      : "Shape " + (selectedShapeIdx + 1);
    fill(40, 50, 80);
    noStroke();
    rect(lx, ly, labelW, labelH, 5);
    fill(220);
    textAlign(CENTER, CENTER);
    textSize(11);
    // Clip text to fit — Processing has no built-in clip, so truncate manually
    String display = shapeName;
    while (textWidth(display) > labelW - 8 && display.length() > 1) {
      display = display.substring(0, display.length() - 1);
    }
    if (!display.equals(shapeName)) display = display.substring(0, display.length() - 1) + "\u2026";
    text(display, lx + labelW/2, ly + labelH/2);
  }
  popStyle();
}

void windowResized() {
  // Update 3D buffer size
  if (view3DBuffer != null) {
    view3DBuffer = createGraphics(width - LEFT_SIDEBAR_WIDTH, height - TOOLBAR_HEIGHT, P3D);
  }
  
  // Update mini 3D buffer (fixed size, no need to recreate)
  if (mini3DBuffer == null) {
    mini3DBuffer = createGraphics(MINI_3D_WIDTH, MINI_3D_HEIGHT, P3D);
  }
  
  // Update sidebar layout
  if (sidebar != null) {
    sidebar.setup();
  }
  
  // Update export control positions
  updateExportControlPositions();
}





/* Explaination for reference 
drawPlan(img)
 --> Prepares basic styles: pushStyle(); rectMode(CORNER); strokeWeight(1);.
 --> Opens a local positioning block: pushMatrix();.
 --> It has two paths depending on whether you’re in per-edge mode:
 
 A) If perEdgeMode is true and edgeTop_px/edgeBot_px are set:
 --> Draws the side panels and fold lines per edge:
 --> drawTrapezoidsPerEdge(0, 0, edgeTop_px, edgeBot_px, cylinderH_px, (cols-1), true);
 --> drawTzFoldlinesPerEdge(0, 0, edgeTop_px, edgeBot_px, cylinderH_px, (cols-1));
 Computes side size for spacing lids:
 --> PVector sideSize = getTrapezoidsDimensions(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1));
 --> Moves down to the lids area: translate(0, 1.2f * sideSize.y);
 --> Sets lid “neck” depth: float neckDepth_px2 = tabDepth_px * 0.2f;
 --> Bottom lid (based on bottom edges):
 --> botOff = getPolygonLidVarOffset(edgeBot_px, tabDepth_px);
 --> botDim = getPolygonLidVarDimensions(edgeBot_px, tabDepth_px);
 --> translate(botOff.x, botOff.y);
 --> drawPolygonLidVar_Legacy(edgeBot_px, neckDepth_px2, tabInset_bot_px, arrowheadFlare_bot_px);
 --> Move to top lid spot:
 --> topDim = getPolygonLidVarDimensions(edgeTop_px, tabDepth_px);
 --> translate(botDim.x, botDim.y - topDim.y);
 --> topOff = getPolygonLidVarOffset(edgeTop_px, tabDepth_px);
 --> translate(topOff.x, topOff.y);
 --> drawPolygonLidVar_Legacy(edgeTop_px, neckDepth_px2, tabInset_top_px, arrowheadFlare_top_px);
 
 B) Otherwise (uniform prism):
 --> Draws side panels and fold lines for a regular layout:
 --> drawTrapezoids(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1), img);
 The last flag img is the one you pass from the exporter:
 --> In PDF: drawPlan(true) → ask to include images
 --> In SVG: drawPlan(false) → dont include images
 --> drawTzFoldlines(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1));
 --> drawTzTopFolds(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1));
 Compute size to place lids:
 --> sideSize = getTrapezoidsDimensions(0, 0, cellTopL_px, cellBaseL_px, cylinderH_px, (cols-1), (rows-1));
 --> Move to lids area: translate(0, 1.2f * sideSize.y);
 --> Set neck depth: neckDepth_px2 = tabDepth_px * 0.2f;
 Compute lid sizes:
 --> lidBaseSize = getPolygonLidDimensions(nSides, cellBaseL_px, tabDepth_px);
 --> lidTopSize = getPolygonLidDimensions(nSides, cellTopL_px, tabDepth_px);
 --> Draw bottom and top lids:
 --> drawPolygonLid(nSides, cellBaseL_px, neckDepth_px2, tabInset_bot_px, arrowheadFlare_bot_px);
 --> Move to top lid: translate(lidBaseSize.x, lidBaseSize.y - lidTopSize.y);
 --> drawPolygonLid(nSides, cellTopL_px, neckDepth_px2, tabInset_top_px, arrowheadFlare_top_px);
 Close the local positioning and styles: popMatrix(); popStyle();.
 */


//20251030 - added UI V1
//20251103 - corrected the button range, added labels, added locking mechanism
//20251103 - added advanced functions + extra info for the designer
//20251104 - added additional functions to control the shape + remove folding lines for cylinders
//20251105 - horrible attempt at adding varability
//20251105 - first draft variability with gpt5 + gemini
//20251112 - fixed dashlines between panels
//20251112 - texture editting v1 --> current images do not skew
//20251121 - fixed texturing on the skewed edges
//20251124 - texturing can now be printed for non-variable mode /w copilot
//20251125 - texturing for per-edge mode ready /w code gemini
//20251126 - texturing along the strip with continous image /w gemini
//20251127 - added texturing to lids + texuring ui 
//20251128 - improved readabilyt of code with claude 4.5 + feedback from Bas van Rossem 
//20251129 - added 3D view mode + toolbar integration
//20251130 - fixed texture orientation in 3D view + minor toolbar fixes
//----------------------------------------------------------------------------------
