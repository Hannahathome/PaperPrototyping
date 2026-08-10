// TESSELLATION METHOD (Nov 2024):
// ------------------------------------
// Replaces simple 2-triangle quads with NxN subdivided grids to eliminate seams
// and improve texture detail. User-controllable density: 4x4, 8x8, or 16x16.
//
// --------------------------------------
// 1. SIDE PANEL TESSELLATION (Trapezoids)
// 
//
// MESH STRUCTURE:
// Trapezoid divided into density×density rectangular grid
// Example (4×4): 16 cells = 32 triangles
// Each cell = 2 triangles sharing diagonal
// :
// ----------
// 1. For each cell at grid position (col, row):
//    - Calculate normalized UV: u = col/density, v = row/density
//    - Four corners: (u0,v0), (u1,v0), (u1,v1), (u0,v1)
//
// 2. World position via BILINEAR INTERPOLATION:
//    - x = bilerp(xBL, xBR, xTL, xTR, u, v)
//    - y = bilerp(yBL, yBR, yTL, yTR, u, v)
//    - bilerp = lerp(lerp(bottom), lerp(top), v)
//
// 3. UV texture coordinates (linear mapping):
//    - uvX = u * img.width
//    - uvY = v * img.height
//
// 4. Generate triangles:
//    - Triangle 1: (u0,v0)→(u1,v0)→(u0,v1)
//    - Triangle 2: (u1,v0)→(u1,v1)→(u0,v1)
//
// CODE: tools.pde → drawTessellatedTrapezoid()
//-------------------------------------------------------------------
// 2. LID TESSELLATION (Circular/Polygonal)
//
// MESH STRUCTURE:
//   Radial subdivision from center outward, triangle fan pattern
//  Each polygon side divided into density rings (radial)and density arcs (angular) = density² quads per sector
//  Center  shared by all triangles
//
// ALGORITHM (Regular Polygons):
// -----------------------------
// 1. Divide into numSides angular sectors
//    - angleIncrement = 2π / numSides
//
// 2. For each sector, subdivide radially:
//    - Rings: r = 0.0 to 1.0 (normalized radius)
//    - Arcs: θ = angle1 to angle2 (sector span)
//
// 3. For each cell (ring, arc):
//    - World position: x = cos(θ) * r * radius, y = sin(θ) * r * radius
//    - UV (radial): u = imgCenterX + cos(θ) * r * uvRadius
//                   v = imgCenterY + sin(θ) * r * uvRadius
//
// 4. Generate triangles per quad:
//    - Triangle 1: (r0,θ0)→(r0,θ1)→(r1,θ0)
//    - Triangle 2: (r0,θ1)→(r1,θ1)→(r1,θ0)
//
// ALGORITHM (Irregular Polygons - Per-Edge Mode):
// -----------------------------------------------
// 1. Calculate circumradius R for variable edge lengths
//    - Each edge is a chord: sᵢ = 2*R*sin(θᵢ/2)
//    - Solve iteratively ensuring Σθᵢ = 2π
//
// 2. Compute accumulated angles for each edge vertex
//
// 3. Align first edge horizontally:
//    - rotate(-angle0) where angle0 = atan2(firstEdgeVector)
//
// 4. Apply same radial tessellation as regular polygons
//    - Sectors span variable angles but use same subdivision density
//
// CODE: 
// - Regular: api.pde → drawTessellatedPolygonLid()
// - Irregular: variableprismtools.pde → drawTessellatedPolygonLidVar()
//



import processing.opengl.*;

// Texture selection for sides
static final int TEX_NONE       = 0;     // no texture (gray fill)
static final int TEX_PER_PANEL  = 1;     // old per-edge/per-panel images
static final int TEX_STRIP_BENT = 2;     // new single bent strip
int sideTextureMode = TEX_NONE;          // default: no texture


boolean canTexture() {
  return (g instanceof PGraphicsOpenGL);
}

boolean canTexture(PGraphics tgt) {
  return (tgt instanceof PGraphicsOpenGL);
}

// Single authoritative array for per-panel textures
PImage[] panelTextures;

PImage getEdgeImage(int edgeIdx, int totalEdges) {
  // Don't load per-panel images when not in per-panel mode
  if (sideTextureMode != TEX_PER_PANEL) {
    return null;
  }
  
  // Check if this specific panel's toggle is enabled
  if (sidebar != null && sidebar.perPanelEnabled != null) {
    if (edgeIdx >= sidebar.perPanelEnabled.length || !sidebar.perPanelEnabled[edgeIdx]) {
      return null; // This panel's texture is disabled
    }
  }
  
  // Initialize array if needed
  if (panelTextures == null || panelTextures.length != totalEdges) {
    PImage[] newArray = new PImage[totalEdges];
    // Preserve existing textures when resizing
    if (panelTextures != null) {
      for (int i = 0; i < min(panelTextures.length, totalEdges); i++) {
        newArray[i] = panelTextures[i];
      }
    }
    panelTextures = newArray;
  }
  
  // Return texture if already loaded (user-uploaded or cached)
  if (panelTextures[edgeIdx] != null) {
    return panelTextures[edgeIdx];
  }
  
  // Try to load from data folder as fallback
  String[] tries = {
    "panels/edge_" + edgeIdx + ".png",
    "panels/edge_" + edgeIdx + ".jpg"
  };
  for (String p : tries) {
    PImage img = loadImage(p);
    if (img != null && img.width > 0 && img.height > 0) {
      panelTextures[edgeIdx] = img;
      break;
    }
  }
  
  return panelTextures[edgeIdx];
}




// Draw per-panel textures for per-edge mode (variable prisms)
void drawPerPanelTexturesPerEdge(PGraphics pg) {
  final int   n  = min(edgeTop_px.length, edgeBot_px.length);
  final int   m  = max(1, (cols - 1));
  final float h  = cylinderH_px;
  final float mh = h / (float)m;

  pg.pushMatrix();
  for (int e = 0; e < n; e++) {
    float topLen    = max(0.001f, edgeTop_px[e]);
    float bottomLen = max(0.001f, edgeBot_px[e]);
    float bleed = textureBleed ? textureBleedMM * MM : 0;

    for (int i = 0; i < m; i++) {
      float segTop = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float segBot = ((topLen - bottomLen) *  i   / (float)m) + bottomLen;
      float off    = (segBot - segTop) / 2.0f;

      float xBL = off*i - bleed, yBL = mh*i - (i == 0 ? bleed : 0);
      float xBR = off*i + segBot + bleed, yBR = mh*i - (i == 0 ? bleed : 0);
      float xTR = off*i + off + segTop + bleed, yTR = mh*i + mh + (i == m-1 ? bleed : 0);
      float xTL = off*i + off - bleed, yTL = mh*i + mh + (i == m-1 ? bleed : 0);

      PImage img = getEdgeImage(e, n);
      if (img != null) {
        pg.textureMode(IMAGE);
        pg.textureWrap(CLAMP);
        pg.hint(ENABLE_TEXTURE_MIPMAPS);
        pg.noStroke();

        pg.beginShape(TRIANGLES);
        pg.texture(img);
        pg.vertex(xTL, yTL, 0, img.height);
        pg.vertex(xTR, yTR, img.width, img.height);
        pg.vertex(xBL, yBL, 0, 0);
        pg.vertex(xTR, yTR, img.width, img.height);
        pg.vertex(xBR, yBR, img.width, 0);
        pg.vertex(xBL, yBL, 0, 0);
        pg.endShape();
      }
    }

    if (e < n - 1) {
      int   eNext = e + 1;
      float wTopN = edgeTop_px[eNext];
      float wBotN = edgeBot_px[eNext];
      PVector A_r = new PVector((topLen - bottomLen) / 2.0f, h);
      PVector B_l = new PVector((wBotN  - wTopN)    / 2.0f, h);
      float rot   = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      pg.translate(bottomLen, 0);
      pg.rotate(rot);
    }
  }
  pg.popMatrix();
}

// Draw per-panel textures for uniform mode (regular prisms)
void drawPerPanelTexturesUniform(PGraphics pg) {
  final float topLen    = cellTopL_px;
  final float bottomLen = cellBaseL_px;
  final float h         = cylinderH_px;
  final int   m         = max(1, (cols - 1));
  final int   n         = max(3, (rows - 1));
  final float mh        = h / (float)m;

  pg.pushMatrix();
  for (int e = 0; e < n; e++) {
    float bleed = textureBleed ? textureBleedMM * MM : 0;
    for (int i = 0; i < m; i++) {
      float segTop = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float segBot = ((topLen - bottomLen) *  i   / (float)m) + bottomLen;
      float off    = (segBot - segTop) / 2.0f;

      float xBL = off*i - bleed, yBL = mh*i - (i == 0 ? bleed : 0);
      float xBR = off*i + segBot + bleed, yBR = mh*i - (i == 0 ? bleed : 0);
      float xTR = off*i + off + segTop + bleed, yTR = mh*i + mh + (i == m-1 ? bleed : 0);
      float xTL = off*i + off - bleed, yTL = mh*i + mh + (i == m-1 ? bleed : 0);

      PImage img = getEdgeImage(e, n);
      if (img != null) {
        pg.textureMode(IMAGE);
        pg.textureWrap(CLAMP);
        pg.hint(ENABLE_TEXTURE_MIPMAPS);
        pg.noStroke();

        pg.beginShape(TRIANGLES);
        pg.texture(img);
        pg.vertex(xTL, yTL, 0, img.height);
        pg.vertex(xTR, yTR, img.width, img.height);
        pg.vertex(xBL, yBL, 0, 0);
        pg.vertex(xTR, yTR, img.width, img.height);
        pg.vertex(xBR, yBR, img.width, 0);
        pg.vertex(xBL, yBL, 0, 0);
        pg.endShape();
      }
    }

    if (e < n - 1) {
      PVector A_r  = new PVector((topLen - bottomLen) / 2.0f, h);
      float   offN = (bottomLen - topLen) / 2.0f;
      PVector B_l  = new PVector(offN, h);
      float rot    = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      pg.translate(bottomLen, 0);
      pg.rotate(rot);
    }
  }
  pg.popMatrix();
}

// Range version of drawPerPanelTexturesPerEdge: panels [panelStart..panelEnd)
void drawPerPanelTexturesPerEdge_Range(PGraphics pg, int panelStart, int panelEnd) {
  if (edgeTop_px == null || edgeBot_px == null) return;
  final int   n  = min(edgeTop_px.length, edgeBot_px.length);
  final int   m  = max(1, (cols - 1));
  final float h  = cylinderH_px;
  final float mh = h / (float)m;
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;

  pg.pushMatrix();
  // No skip — draw starts at local origin (matching drawTrapezoidsPerEdge_Range)
  // Draw panels [panelStart..panelEnd)
  for (int e = panelStart; e < panelEnd && e < n; e++) {
    float topLen    = max(0.001f, edgeTop_px[e]);
    float bottomLen = max(0.001f, edgeBot_px[e]);
    float bleed = textureBleed ? textureBleedMM * MM : 0;
    for (int i = 0; i < m; i++) {
      float segTop = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float segBot = ((topLen - bottomLen) *  i   / (float)m) + bottomLen;
      float off    = (segBot - segTop) / 2.0f;
      float xBL = off*i - bleed, yBL = mh*i - (i == 0 ? bleed : 0);
      float xBR = off*i + segBot + bleed, yBR = mh*i - (i == 0 ? bleed : 0);
      float xTR = off*i + off + segTop + bleed, yTR = mh*i + mh + (i == m-1 ? bleed : 0);
      float xTL = off*i + off - bleed, yTL = mh*i + mh + (i == m-1 ? bleed : 0);
      PImage img = getEdgeImage(e, n);
      if (img != null) {
        pg.textureMode(IMAGE); pg.textureWrap(CLAMP);
        pg.hint(ENABLE_TEXTURE_MIPMAPS); pg.noStroke();
        pg.beginShape(TRIANGLES); pg.texture(img);
        pg.vertex(xTL, yTL, 0, img.height);
        pg.vertex(xTR, yTR, img.width, img.height);
        pg.vertex(xBL, yBL, 0, 0);
        pg.vertex(xTR, yTR, img.width, img.height);
        pg.vertex(xBR, yBR, img.width, 0);
        pg.vertex(xBL, yBL, 0, 0);
        pg.endShape();
      }
    }
    if (e < n - 1) {
      int eNext = e + 1;
      float wTopN = edgeTop_px[eNext];
      float wBotN = edgeBot_px[eNext];
      PVector A_r = new PVector((topLen - bottomLen) / 2.0f, h);
      PVector B_l = new PVector((wBotN - wTopN) / 2.0f, h);
      float rot = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      pg.translate(bottomLen, 0);
      pg.rotate(rot);
    }
  }
  pg.popMatrix();
}

// Range version of drawPerPanelTexturesUniform: panels [panelStart..panelEnd)
void drawPerPanelTexturesUniform_Range(PGraphics pg, int panelStart, int panelEnd) {
  final float topLen    = cellTopL_px;
  final float bottomLen = cellBaseL_px;
  final float h         = cylinderH_px;
  final int   m         = max(1, (cols - 1));
  final int   n         = max(3, (rows - 1));
  final float mh        = h / (float)m;
  int nPanels = panelEnd - panelStart;
  if (nPanels <= 0) return;

  pg.pushMatrix();
  // No skip — draw starts at local origin (matching drawTrapezoids_Range)
  // Draw panels [panelStart..panelEnd)
  for (int e = panelStart; e < panelEnd && e < n; e++) {
    float bleed = textureBleed ? textureBleedMM * MM : 0;
    for (int i = 0; i < m; i++) {
      float segTop = ((topLen - bottomLen) * (i+1) / (float)m) + bottomLen;
      float segBot = ((topLen - bottomLen) *  i   / (float)m) + bottomLen;
      float off    = (segBot - segTop) / 2.0f;
      float xBL = off*i - bleed, yBL = mh*i - (i == 0 ? bleed : 0);
      float xBR = off*i + segBot + bleed, yBR = mh*i - (i == 0 ? bleed : 0);
      float xTR = off*i + off + segTop + bleed, yTR = mh*i + mh + (i == m-1 ? bleed : 0);
      float xTL = off*i + off - bleed, yTL = mh*i + mh + (i == m-1 ? bleed : 0);
      PImage img = getEdgeImage(e, n);
      if (img != null) {
        pg.textureMode(IMAGE); pg.textureWrap(CLAMP);
        pg.hint(ENABLE_TEXTURE_MIPMAPS); pg.noStroke();
        pg.beginShape(TRIANGLES); pg.texture(img);
        pg.vertex(xTL, yTL, 0, img.height);
        pg.vertex(xTR, yTR, img.width, img.height);
        pg.vertex(xBL, yBL, 0, 0);
        pg.vertex(xTR, yTR, img.width, img.height);
        pg.vertex(xBR, yBR, img.width, 0);
        pg.vertex(xBL, yBL, 0, 0);
        pg.endShape();
      }
    }
    if (e < n - 1) {
      PVector A_r  = new PVector((topLen - bottomLen) / 2.0f, h);
      float   offN = (bottomLen - topLen) / 2.0f;
      PVector B_l  = new PVector(offN, h);
      float rot    = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
      pg.translate(bottomLen, 0);
      pg.rotate(rot);
    }
  }
  pg.popMatrix();
}

void drawTexturesForPrinting(PGraphics pg) {
  pg.pushMatrix();
  // Match the same translation as drawPlan() in the PDF export
  pg.translate(patX_px, patY_px);
  pg.rotate(radians(patRotation));
  pg.hint(DISABLE_DEPTH_TEST);

  boolean isPerEdge = (perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null;

  if (sideTextureMode == TEX_STRIP_BENT && stripImg != null) {
    // ---------- STRIP BENT ----------
    if (isPerEdge) {
      int nEdges = min(edgeTop_px.length, edgeBot_px.length);
      if (splitStrip && nEdges >= 4) {
        int splitAt = (int)ceil(nEdges / 2.0);
        float stripHeight = getStripHeight();
        float splitSpacing = stripHeight + tabDepth_px * 2 + 10 * MM_current;
        // Half 1
        pg.pushMatrix();
        pg.translate(uiSplitHalf1OffsetX * MM_current, uiSplitHalf1OffsetY * MM_current);
        pg.rotate(radians(uiSplitHalf1Rotation));
        drawTriangleStripTexture_PerEdge_Range(pg, stripImg, 0, splitAt);
        pg.popMatrix();
        // Half 2
        pg.pushMatrix();
        pg.translate(uiSplitHalf2OffsetX * MM_current, splitSpacing + uiSplitHalf2OffsetY * MM_current);
        pg.rotate(radians(uiSplitHalf2Rotation));
        drawTriangleStripTexture_PerEdge_Range(pg, stripImg, splitAt, nEdges);
        pg.popMatrix();
      } else {
        drawTriangleStripTexture_PerEdge(pg, stripImg);
      }
    } else {
      int nSidesLocal = max(3, (rows - 1));
      if (splitStrip && nSidesLocal >= 4) {
        int splitAt = (int)ceil(nSidesLocal / 2.0);
        float stripHeight = getStripHeight();
        float splitSpacing = stripHeight + tabDepth_px * 2 + 10 * MM_current;
        // Half 1
        pg.pushMatrix();
        pg.translate(uiSplitHalf1OffsetX * MM_current, uiSplitHalf1OffsetY * MM_current);
        pg.rotate(radians(uiSplitHalf1Rotation));
        drawTriangleStripTexture_Uniform_Range(pg, stripImg, 0, splitAt);
        pg.popMatrix();
        // Half 2
        pg.pushMatrix();
        pg.translate(uiSplitHalf2OffsetX * MM_current, splitSpacing + uiSplitHalf2OffsetY * MM_current);
        pg.rotate(radians(uiSplitHalf2Rotation));
        drawTriangleStripTexture_Uniform_Range(pg, stripImg, splitAt, nSidesLocal);
        pg.popMatrix();
      } else {
        drawTriangleStripTexture_Uniform(pg, stripImg);
      }
    }
    // Lids
    if (sidebar != null && (sidebar.topLidEnabled || sidebar.bottomLidEnabled)) {
      if (isPerEdge) {
        texturedLidsForPrint_PerEdge(pg);
      } else {
        texturedLidsForPrint_Uniform(pg);
      }
    }
  } else if (sideTextureMode == TEX_PER_PANEL) {
    // ---------- PER-PANEL ----------
    if (isPerEdge) {
      int nEdges = min(edgeTop_px.length, edgeBot_px.length);
      if (splitStrip && nEdges >= 4) {
        int splitAt = (int)ceil(nEdges / 2.0);
        float stripHeight = getStripHeight();
        float splitSpacing = stripHeight + tabDepth_px * 2 + 10 * MM_current;
        pg.pushMatrix();
        pg.translate(uiSplitHalf1OffsetX * MM_current, uiSplitHalf1OffsetY * MM_current);
        pg.rotate(radians(uiSplitHalf1Rotation));
        drawPerPanelTexturesPerEdge_Range(pg, 0, splitAt);
        pg.popMatrix();
        pg.pushMatrix();
        pg.translate(uiSplitHalf2OffsetX * MM_current, splitSpacing + uiSplitHalf2OffsetY * MM_current);
        pg.rotate(radians(uiSplitHalf2Rotation));
        drawPerPanelTexturesPerEdge_Range(pg, splitAt, nEdges);
        pg.popMatrix();
      } else {
        drawPerPanelTexturesPerEdge(pg);
      }
      if (sidebar != null && (sidebar.topLidEnabled || sidebar.bottomLidEnabled)) {
        texturedLidsForPrint_PerEdge(pg);
      }
    } else {
      int nSidesLocal = max(3, (rows - 1));
      if (splitStrip && nSidesLocal >= 4) {
        int splitAt = (int)ceil(nSidesLocal / 2.0);
        float stripHeight = getStripHeight();
        float splitSpacing = stripHeight + tabDepth_px * 2 + 10 * MM_current;
        pg.pushMatrix();
        pg.translate(uiSplitHalf1OffsetX * MM_current, uiSplitHalf1OffsetY * MM_current);
        pg.rotate(radians(uiSplitHalf1Rotation));
        drawPerPanelTexturesUniform_Range(pg, 0, splitAt);
        pg.popMatrix();
        pg.pushMatrix();
        pg.translate(uiSplitHalf2OffsetX * MM_current, splitSpacing + uiSplitHalf2OffsetY * MM_current);
        pg.rotate(radians(uiSplitHalf2Rotation));
        drawPerPanelTexturesUniform_Range(pg, splitAt, nSidesLocal);
        pg.popMatrix();
      } else {
        drawPerPanelTexturesUniform(pg);
      }
      if (sidebar != null && (sidebar.topLidEnabled || sidebar.bottomLidEnabled)) {
        texturedLidsForPrint_Uniform(pg);
      }
    }
  }

  pg.popMatrix();
}


//--------------LIDS (not functional yet)-----------------------
//draw image in a box, optional aspect preserve
void drawImageInBox(PGraphics pg, PImage img,
  float x, float y, float w, float h,
  boolean keepAspect) {
  if (img == null || w <= 0 || h <= 0) return;
  if (!keepAspect) {
    pg.image(img, x, y, w, h);
    return;
  }
  float sx = w / img.width, sy = h / img.height, s = min(sx, sy);
  float rw = img.width * s, rh = img.height * s;
  float ox = x + (w - rw) * 0.5f, oy = y + (h - rh) * 0.5f;
  pg.image(img, ox, oy, rw, rh);
}

// Uniform lids (regular mode): mirrors drawPlan(uniform) lid placement
void texturedLidsUniform(PGraphics pg, PImage topImg, PImage botImg, boolean keepAspect) {
  // Use actual strip height to prevent overlap
  float stripHeight = getStripHeight();
  // When split, lids are placed below both halves
  if (splitStrip && nSides >= 4) {
    float splitSpacingLid = stripHeight + tabDepth_px * 2 + 10 * MM_current;
    stripHeight = splitSpacingLid + stripHeight;
  }
  PVector lidBaseDim = getPolygonLidDimensions(nSides, cellBaseL_px, tabDepth_px);
  PVector lidTopDim  = getPolygonLidDimensions(nSides, cellTopL_px, tabDepth_px);
  float extraLidSpace = max(0, lidTopDim.y - lidBaseDim.y);
  float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * MM_current);

  // Bottom lid - draw exactly where the outline is drawn (only if enabled)
  if (botImg != null && canTexture(pg) && sidebar != null && sidebar.bottomLidEnabled) {
    pg.pushMatrix();
    pg.translate((uiLidOffsetX + uiBotLidOffsetX) * (pg == g ? MM : MM), lidSpacing + (uiLidOffsetY + uiBotLidOffsetY) * (pg == g ? MM : MM));
    pg.translate(lidBaseDim.x/2, lidBaseDim.y/2); // Move to center
    pg.rotate(radians(uiBotLidRotation)); // Apply rotation
    pg.translate(-lidBaseDim.x/2, -lidBaseDim.y/2); // Move back
    drawTessellatedPolygonLidToPG(pg, nSides, cellBaseL_px, botImg, tessellationDensity, keepAspect);
    pg.popMatrix();
  }

  // Top lid - draw exactly where the outline is drawn (only if enabled)
  if (topImg != null && canTexture(pg) && sidebar != null && sidebar.topLidEnabled) {
    pg.pushMatrix();
    pg.translate((uiLidOffsetX + uiTopLidOffsetX) * (pg == g ? MM : MM), lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * (pg == g ? MM : MM));
    pg.translate(lidBaseDim.x, lidBaseDim.y - lidTopDim.y);
    pg.translate(lidTopDim.x/2, lidTopDim.y/2); // Move to center
    pg.rotate(radians(uiTopLidRotation)); // Apply rotation
    pg.translate(-lidTopDim.x/2, -lidTopDim.y/2); // Move back
    drawTessellatedPolygonLidToPG(pg, nSides, cellTopL_px, topImg, tessellationDensity, keepAspect);
    pg.popMatrix();
  }
}

// Per-edge lids (variable prism): mirrors drawPlan(per-edge) offsets/dimensions
void texturedLidsPerEdge(PGraphics pg, PImage topImg, PImage botImg, boolean keepAspect) {
  if (cuboidMode) {
    texturedLidsCuboid(pg, topImg, botImg, keepAspect);
    return;
  }
  // Use actual strip height to prevent overlap
  float stripHeight = getStripHeight();
  // When split, lids are placed below both halves
  if (splitStrip && edgeTop_px != null && edgeBot_px != null && min(edgeTop_px.length, edgeBot_px.length) >= 4) {
    float splitSpacingLid = stripHeight + tabDepth_px * 2 + 10 * MM_current;
    stripHeight = splitSpacingLid + stripHeight;
  }
  PVector botOff = getPolygonLidVarOffset(edgeBot_px, tabDepth_px);
  PVector botDim = getPolygonLidVarDimensions(edgeBot_px, tabDepth_px);
  PVector topDim = getPolygonLidVarDimensions(edgeTop_px, tabDepth_px);
  PVector topOff = getPolygonLidVarOffset(edgeTop_px, tabDepth_px);
  float extraLidSpace = max(0, topDim.y - botDim.y);
  float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * MM_current);

  // Bottom lid (only if enabled)
  if (botImg != null && canTexture(pg) && sidebar != null && sidebar.bottomLidEnabled) {
    pg.pushMatrix();
    pg.translate((uiLidOffsetX + uiBotLidOffsetX) * (pg == g ? MM : MM), lidSpacing + (uiLidOffsetY + uiBotLidOffsetY) * (pg == g ? MM : MM));
    pg.translate(botOff.x + botDim.x/2, botOff.y + botDim.y/2); // Move to center
    pg.rotate(radians(uiBotLidRotation)); // Apply rotation
    pg.translate(-(botDim.x/2), -(botDim.y/2)); // Move back
    drawTessellatedPolygonLidVarToPG(pg, edgeBot_px, botImg, tessellationDensity, keepAspect);
    pg.popMatrix();
  }

  // Top lid - match uniform mode positioning: translate(width, height_diff)
  if (topImg != null && canTexture(pg) && sidebar != null && sidebar.topLidEnabled) {
    pg.pushMatrix();
    pg.translate((uiLidOffsetX + uiTopLidOffsetX) * (pg == g ? MM : MM), lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * (pg == g ? MM : MM));
    pg.translate(botDim.x, botDim.y - topDim.y);
    pg.translate(topOff.x + topDim.x/2, topOff.y + topDim.y/2); // Move to center
    pg.rotate(radians(uiTopLidRotation)); // Apply rotation
    pg.translate(-(topDim.x/2), -(topDim.y/2)); // Move back
    drawTessellatedPolygonLidVarToPG(pg, edgeTop_px, topImg, tessellationDensity, keepAspect);
    pg.popMatrix();
  }
}

// Cuboid rectangular lids: uses rectangular texture mapping matching drawPlan cuboid positioning
void texturedLidsCuboid(PGraphics pg, PImage topImg, PImage botImg, boolean keepAspect) {
  float stripHeight = getStripHeight();
  // When split, lids are placed below both halves
  if (splitStrip && edgeTop_px != null && min(edgeTop_px.length, edgeBot_px.length) >= 4) {
    float splitSpacingLid = stripHeight + tabDepth_px * 2 + 10 * MM_current;
    stripHeight = splitSpacingLid + stripHeight;
  }
  float botLidW = edgeBot_px[0];  // Length
  float botLidD = edgeBot_px[1];  // Width
  float topLidW = edgeTop_px[0];
  float topLidD = edgeTop_px[1];
  
  PVector botDimCub = getRectangularLidDimensions(botLidW, botLidD, tabDepth_px);
  PVector topDimCub = getRectangularLidDimensions(topLidW, topLidD, tabDepth_px);
  float extraLidSpace = max(0, topDimCub.y - botDimCub.y);
  float lidSpacing = max(stripHeight * LID_SPACING_MARGIN, stripHeight + tabDepth_px + extraLidSpace + 2 * MM_current);

  // Bottom lid
  if (botImg != null && canTexture(pg) && sidebar != null && sidebar.bottomLidEnabled) {
    pg.pushMatrix();
    pg.translate((uiLidOffsetX + uiBotLidOffsetX) * (pg == g ? MM : MM), lidSpacing + (uiLidOffsetY + uiBotLidOffsetY) * (pg == g ? MM : MM));
    pg.translate(botDimCub.x/2, botDimCub.y/2);
    pg.rotate(radians(uiBotLidRotation));
    pg.translate(-botDimCub.x/2, -botDimCub.y/2);
    drawTessellatedRectangularLidToPG(pg, botLidW, botLidD, botImg, tessellationDensity, keepAspect);
    pg.popMatrix();
  }

  // Top lid (offset to the right, matching drawPlan)
  if (topImg != null && canTexture(pg) && sidebar != null && sidebar.topLidEnabled) {
    pg.pushMatrix();
    pg.translate((uiLidOffsetX + uiTopLidOffsetX) * (pg == g ? MM : MM), lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * (pg == g ? MM : MM));
    pg.translate(botDimCub.x, botDimCub.y - topDimCub.y);
    pg.translate(topDimCub.x/2, topDimCub.y/2);
    pg.rotate(radians(uiTopLidRotation));
    pg.translate(-topDimCub.x/2, -topDimCub.y/2);
    drawTessellatedRectangularLidToPG(pg, topLidW, topLidD, topImg, tessellationDensity, keepAspect);
    pg.popMatrix();
  }
}

void texturedLidsForPrint_Uniform(PGraphics pg) {
  texturedLidsUniform(pg, lidImgTop, lidImgBot, lidKeepAspect);
}
void texturedLidsForPrint_PerEdge(PGraphics pg) {
  texturedLidsPerEdge(pg, lidImgTop, lidImgBot, lidKeepAspect);
}

// PGraphics wrappers for tessellated lid drawing
void drawTessellatedPolygonLidToPG(PGraphics pg, int numSides, float sideLength, PImage img, int density, boolean keepAspect) {
  if (img == null || numSides < 3 || density < 1) return;
  
  float radius = (sideLength / 2.0) / sin(PI / (float)numSides);
  float angleIncrement = TWO_PI / (float)numSides;
  float rectWidth = (radius * cos(angleIncrement/2) + tabDepth_px) * 2;
  
  // Match the exact positioning from drawPolygonLid
  pg.pushMatrix();
  pg.translate(rectWidth/2., rectWidth/2.);
  
  // Calculate the actual radius of the polygon body (without tabs)
  // The polygon vertices are at distance 'radius' from center
  float polygonRadius = radius;
  
  float imgCX = img.width * 0.5f;
  float imgCY = img.height * 0.5f;
  float uvRadius = min(img.width, img.height) * 0.5f;
  
  pg.noStroke();
  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);
  
  pg.beginShape(TRIANGLES);
  pg.texture(img);
  
  for (int side = 0; side < numSides; side++) {
    float angle1 = side * angleIncrement;
    float angle2 = (side + 1) * angleIncrement;
    
    for (int ring = 0; ring < density; ring++) {
      float r0 = (float)ring / density;
      float r1 = (float)(ring + 1) / density;
      
      for (int arc = 0; arc < density; arc++) {
        float a0 = lerp(angle1, angle2, (float)arc / density);
        float a1 = lerp(angle1, angle2, (float)(arc + 1) / density);
        
        // World positions using polygon radius
        float x00 = cos(a0) * r0 * polygonRadius;
        float y00 = sin(a0) * r0 * polygonRadius;
        float x10 = cos(a1) * r0 * polygonRadius;
        float y10 = sin(a1) * r0 * polygonRadius;
        float x01 = cos(a0) * r1 * polygonRadius;
        float y01 = sin(a0) * r1 * polygonRadius;
        float x11 = cos(a1) * r1 * polygonRadius;
        float y11 = sin(a1) * r1 * polygonRadius;
        
        // UV coordinates - map to image space maintaining aspect ratio
        float u00 = imgCX + cos(a0) * r0 * uvRadius;
        float v00 = imgCY + sin(a0) * r0 * uvRadius;
        float u10 = imgCX + cos(a1) * r0 * uvRadius;
        float v10 = imgCY + sin(a1) * r0 * uvRadius;
        float u01 = imgCX + cos(a0) * r1 * uvRadius;
        float v01 = imgCY + sin(a0) * r1 * uvRadius;
        float u11 = imgCX + cos(a1) * r1 * uvRadius;
        float v11 = imgCY + sin(a1) * r1 * uvRadius;
        
        pg.vertex(x00, y00, u00, v00);
        pg.vertex(x10, y10, u10, v10);
        pg.vertex(x01, y01, u01, v01);
        
        pg.vertex(x10, y10, u10, v10);
        pg.vertex(x11, y11, u11, v11);
        pg.vertex(x01, y01, u01, v01);
      }
    }
  }
  
  pg.endShape();
  pg.popMatrix();
}

// Rectangular lid texture: maps the full image onto a rectangle using a simple grid tessellation
void drawTessellatedRectangularLidToPG(PGraphics pg, float lidW, float lidH, PImage img, int density, boolean keepAspect) {
  if (img == null || density < 1) return;
  
  pg.pushMatrix();
  // Translate so the rectangle is drawn at (tabDepth, tabDepth) to match drawRectangularLid
  pg.translate(tabDepth_px, tabDepth_px);
  
  pg.noStroke();
  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);
  
  pg.beginShape(TRIANGLES);
  pg.texture(img);
  
  float imgW = img.width;
  float imgH = img.height;
  
  // If keepAspect, fit the image preserving aspect ratio (centered)
  float uOff = 0, vOff = 0, uScale = imgW, vScale = imgH;
  if (keepAspect) {
    float imgAspect = imgW / imgH;
    float lidAspect = lidW / lidH;
    if (imgAspect > lidAspect) {
      // Image wider than lid: crop sides
      float usedW = imgH * lidAspect;
      uOff = (imgW - usedW) / 2.0;
      uScale = usedW;
      vScale = imgH;
    } else {
      // Image taller than lid: crop top/bottom
      float usedH = imgW / lidAspect;
      vOff = (imgH - usedH) / 2.0;
      uScale = imgW;
      vScale = usedH;
    }
  }
  
  for (int row = 0; row < density; row++) {
    float y0 = lidH * row / density;
    float y1 = lidH * (row + 1) / density;
    float v0 = vOff + vScale * row / density;
    float v1 = vOff + vScale * (row + 1) / density;
    for (int col = 0; col < density; col++) {
      float x0 = lidW * col / density;
      float x1 = lidW * (col + 1) / density;
      float u0 = uOff + uScale * col / density;
      float u1 = uOff + uScale * (col + 1) / density;
      
      pg.vertex(x0, y0, u0, v0);
      pg.vertex(x1, y0, u1, v0);
      pg.vertex(x0, y1, u0, v1);
      
      pg.vertex(x1, y0, u1, v0);
      pg.vertex(x1, y1, u1, v1);
      pg.vertex(x0, y1, u0, v1);
    }
  }
  
  pg.endShape();
  pg.popMatrix();
}

void drawTessellatedPolygonLidVarToPG(PGraphics pg, float[] sidePx, PImage img, int density, boolean keepAspect) {
  int n = (sidePx == null) ? 0 : sidePx.length;
  if (n < 3 || img == null || density < 1) return;

  float R = solveRadiusForChordSet(sidePx);
  float ang0 = -HALF_PI;

  float s0 = sidePx[0];
  float th0 = 2.0f * (float)Math.asin(_clampf(s0/(2.0f*R), 1e-6f, 0.999999f));
  PVector p0a = new PVector(R * cos(ang0), R * sin(ang0));
  PVector p0b = new PVector(R * cos(ang0 + th0), R * sin(ang0 + th0));
  float angle0 = atan2(p0b.y - p0a.y, p0b.x - p0a.x);

  pg.pushMatrix();
  pg.rotate(-angle0);

  float imgCX = img.width * 0.5f;
  float imgCY = img.height * 0.5f;
  float uvRadius = min(img.width, img.height) * 0.5f;

  pg.noStroke();
  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);

  pg.beginShape(TRIANGLES);
  pg.texture(img);

  float ang = ang0;
  for (int side = 0; side < n; side++) {
    float s = sidePx[side];
    float theta = 2.0f * (float)Math.asin(_clampf(s/(2.0f*R), 1e-6f, 0.999999f));

    float angle1 = ang;
    float angle2 = ang + theta;

    for (int ring = 0; ring < density; ring++) {
      float r0 = (float)ring / density;
      float r1 = (float)(ring + 1) / density;

      for (int arc = 0; arc < density; arc++) {
        float a0 = lerp(angle1, angle2, (float)arc / density);
        float a1 = lerp(angle1, angle2, (float)(arc + 1) / density);

        float x00 = cos(a0) * r0 * R;
        float y00 = sin(a0) * r0 * R;
        float x10 = cos(a1) * r0 * R;
        float y10 = sin(a1) * r0 * R;
        float x01 = cos(a0) * r1 * R;
        float y01 = sin(a0) * r1 * R;
        float x11 = cos(a1) * r1 * R;
        float y11 = sin(a1) * r1 * R;

        float u00 = imgCX + cos(a0) * r0 * uvRadius;
        float v00 = imgCY + sin(a0) * r0 * uvRadius;
        float u10 = imgCX + cos(a1) * r0 * uvRadius;
        float v10 = imgCY + sin(a1) * r0 * uvRadius;
        float u01 = imgCX + cos(a0) * r1 * uvRadius;
        float v01 = imgCY + sin(a0) * r1 * uvRadius;
        float u11 = imgCX + cos(a1) * r1 * uvRadius;
        float v11 = imgCY + sin(a1) * r1 * uvRadius;

        pg.vertex(x00, y00, u00, v00);
        pg.vertex(x10, y10, u10, v10);
        pg.vertex(x01, y01, u01, v01);

        pg.vertex(x10, y10, u10, v10);
        pg.vertex(x11, y11, u11, v11);
        pg.vertex(x01, y01, u01, v01);
      }
    }

    ang += theta;
  }

  pg.endShape();
  pg.popMatrix();
}



// Compute rotNeeded
float rotNeededFor(float topLen, float bottomLen, float nextTopLen, float nextBottomLen, float h) {
  PVector A_r = new PVector((topLen - bottomLen)/2.0f, h);
  PVector B_l = new PVector((nextBottomLen - nextTopLen)/2.0f, h);
  return atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
}

// Calculate the actual maximum Y extent of the bent strip
// Returns the height of the strip's bounding box
float computeStripHeight_PerEdge() {
  if (edgeTop_px == null || edgeBot_px == null) return cylinderH_px;
  final int n = min(edgeTop_px.length, edgeBot_px.length);
  final float h = cylinderH_px;
  Affine T = new Affine();
  
  float maxY = h;  // Start with straight height
  float minY = 0;
  
  float t = max(0.001f, edgeTop_px[0]);
  float b = max(0.001f, edgeBot_px[0]);
  
  // Check all four corners of first column
  maxY = max(maxY, T.apply(0, 0).y);
  maxY = max(maxY, T.apply(b, 0).y);
  maxY = max(maxY, T.apply((b-t)/2.0f, h).y);
  maxY = max(maxY, T.apply((b-t)/2.0f + t, h).y);
  
  for (int e = 0; e < n - 1; e++) {
    float tNext = max(0.001f, edgeTop_px[e+1]);
    float bNext = max(0.001f, edgeBot_px[e+1]);
    
    T.translate(b, 0);
    float rot = rotNeededFor(t, b, tNext, bNext, h);
    T.rotate(rot);
    
    t = tNext;
    b = bNext;
    
    // Check all corners of this column
    maxY = max(maxY, T.apply(0, 0).y);
    maxY = max(maxY, T.apply(b, 0).y);
    maxY = max(maxY, T.apply((b-t)/2.0f, h).y);
    maxY = max(maxY, T.apply((b-t)/2.0f + t, h).y);
  }
  
  return maxY - minY;
}

float computeStripHeight_Uniform() {
  final int n = max(3, (rows - 1));
  final float h = cylinderH_px;
  final float t = cellTopL_px;
  final float b = cellBaseL_px;
  Affine T = new Affine();
  
  float maxY = h;
  
  // Check first column
  maxY = max(maxY, T.apply(0, 0).y);
  maxY = max(maxY, T.apply(b, 0).y);
  maxY = max(maxY, T.apply((b-t)/2.0f, h).y);
  maxY = max(maxY, T.apply((b-t)/2.0f + t, h).y);
  
  for (int e = 0; e < n - 1; e++) {
    T.translate(b, 0);
    PVector A_r = new PVector((t - b)/2.0f, h);
    float offN = (b - t)/2.0f;
    PVector B_l = new PVector(offN, h);
    float rot = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
    T.rotate(rot);
    
    maxY = max(maxY, T.apply(0, 0).y);
    maxY = max(maxY, T.apply(b, 0).y);
    maxY = max(maxY, T.apply((b-t)/2.0f, h).y);
    maxY = max(maxY, T.apply((b-t)/2.0f + t, h).y);
  }
  
  return maxY;
}

// Get the actual strip height for current mode
// Always calculate bent strip height regardless of texture mode to prevent overlap
float getStripHeight() {
  if ((perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null) {
    return computeStripHeight_PerEdge();
  } else {
    return computeStripHeight_Uniform();
  }
}

// Compute the four global corners of the  strip in PER-EDGE mode.
// Returns TL, TR, BR, BL in that order.
PVector[] computeStripCorners_PerEdge() {
  final int n = min(edgeTop_px.length, edgeBot_px.length);
  final float h = cylinderH_px;
  Affine T = new Affine();

  // First column sizes
  float t0 = max(0.001f, edgeTop_px[0]);
  float b0 = max(0.001f, edgeBot_px[0]);
  // Local envelope corners for first column
  PVector TL0 = T.apply((b0 - t0)/2.0f, h);
  PVector BL0 = T.apply(0, 0);

  // Walk to last column, track last TR/BR
  float t = t0, b = b0;
  PVector TR_last = T.apply((b - t)/2.0f + t, h);
  PVector BR_last = T.apply(b, 0);

  for (int e = 0; e < n - 1; e++) {
    float tNext = max(0.001f, edgeTop_px[e+1]);
    float bNext = max(0.001f, edgeBot_px[e+1]);

    // advance to next column
    T.translate(b, 0);
    float rot = rotNeededFor(t, b, tNext, bNext, h);
    T.rotate(rot);

    // update "last" using the new column sizes
    t = tNext;
    b = bNext;
    TR_last = T.apply((b - t)/2.0f + t, h);
    BR_last = T.apply(b, 0);
  }

  return new PVector[] { TL0, TR_last, BR_last, BL0 };
}

// Compute the four global corners of the *whole* strip in UNIFORM mode.
PVector[] computeStripCorners_Uniform() {
  final int n = max(3, (rows - 1)); // == nSides
  final float h = cylinderH_px;
  final float t = cellTopL_px;
  final float b = cellBaseL_px;

  Affine T = new Affine();

  // First column corners
  PVector TL0 = T.apply((b - t)/2.0f, h);
  PVector BL0 = T.apply(0, 0);

  // Walk through uniform columns
  PVector TR_last = T.apply((b - t)/2.0f + t, h);
  PVector BR_last = T.apply(b, 0);

  for (int e = 0; e < n - 1; e++) {
    // uniform advance
    T.translate(b, 0);
    PVector A_r = new PVector((t - b)/2.0f, h);
    float offN = (b - t)/2.0f;
    PVector B_l = new PVector(offN, h);
    float rot = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);
    T.rotate(rot);

    TR_last = T.apply((b - t)/2.0f + t, h);
    BR_last = T.apply(b, 0);
  }

  return new PVector[] { TL0, TR_last, BR_last, BL0 };
}

// Draw one textured quad over the 4 corners (triangles). IMAGE UVs = full image.
void drawStripTexture(PGraphics pg, PImage img, PVector TL, PVector TR, PVector BR, PVector BL) {
  if (img == null) return;
  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);
  pg.noStroke();

  pg.beginShape(TRIANGLES);
  pg.texture(img);
  // TL, TR, BL
  pg.vertex(TL.x, TL.y, 0, 0);
  pg.vertex(TR.x, TR.y, img.width, 0);
  pg.vertex(BL.x, BL.y, 0, img.height);
  // TR, BR, BL
  pg.vertex(TR.x, TR.y, img.width, 0);
  pg.vertex(BR.x, BR.y, img.width, img.height);
  pg.vertex(BL.x, BL.y, 0, img.height);
  pg.endShape();
}

// Public: draw strip texture for current mode
void drawStripTextureForCurrentMode(PGraphics pg, PImage img) {
  if (img == null) return;
  PVector[] C = ((perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null)
    ? computeStripCorners_PerEdge()
    : computeStripCorners_Uniform();
  drawStripTexture(pg, img, C[0], C[1], C[2], C[3]);
}

// ===============================================================
// Bent strip texture: map ONE image across all columns (per-edge or uniform)
// Draws one quad per column with continuous u-mapping, following the bends
// ===============================================================

import processing.opengl.*;

// --- 0) Image to use for the strip (set once, e.g. in setup() or setParams(false))
PImage stripImg = null;   // e.g., stripImg = loadImage("strip.png");

// --- 1) Core: draw bent-strip texture for PER-EDGE mode
void drawBentStripTexture_PerEdge(PGraphics pg, PImage img) {
  if (img == null || edgeTop_px == null || edgeBot_px == null) return;

  final int   n  = min(edgeTop_px.length, edgeBot_px.length);
  final float h  = cylinderH_px;

  // 1a) collect average widths (for u spans)
  float[] top = new float[n], bot = new float[n], wAvg = new float[n];
  float sumAvg = 0;
  for (int e = 0; e < n; e++) {
    top[e] = max(0.001f, edgeTop_px[e]);
    bot[e] = max(0.001f, edgeBot_px[e]);
    wAvg[e] = 0.5f * (top[e] + bot[e]);
    sumAvg += wAvg[e];
  }
  if (sumAvg <= 0) return;

  // 1b) u-scaling from strip units to image pixels
  final float uScale = img.width / sumAvg;

  // 1c) draw each column in its local transform
  pg.pushMatrix(); // contain all per-edge transforms (start at print origin)
  float uAcc = 0;  // cumulative u (in strip units)

  for (int e = 0; e < n; e++) {
    float t = top[e], b = bot[e];
    float u0px = (uAcc       ) * uScale;
    float u1px = (uAcc+wAvg[e]) * uScale;
    uAcc += wAvg[e];

    // Envelope quad for the whole column (covers all panels in that column)
    float xBL = 0, yBL = 0;
    float xBR = b, yBR = 0;
    float xTL = (b - t) * 0.5f, yTL = h;
    float xTR = xTL + t, yTR = h;

    // Textured quad (two triangles), continuous u range
    pg.textureMode(IMAGE);
    pg.textureWrap(CLAMP);
    pg.hint(ENABLE_TEXTURE_MIPMAPS);
    pg.noStroke();

    pg.beginShape(TRIANGLES);
    pg.texture(img);
    // TL, TR, BL
    pg.vertex(xTL, yTL, u0px, 0);
    pg.vertex(xTR, yTR, u1px, 0);
    pg.vertex(xBL, yBL, u0px, img.height);
    // TR, BR, BL
    pg.vertex(xTR, yTR, u1px, 0);
    pg.vertex(xBR, yBR, u1px, img.height);
    pg.vertex(xBL, yBL, u0px, img.height);
    pg.endShape();

    // Advance transform to the next column (match panel math EXACTLY)
    if (e < n - 1) {
      float tNext = top[e+1], bNext = bot[e+1];
      // rotation vs NEXT edge (fixes drift)
      PVector A_r = new PVector((t - b) / 2.0f, h);
      PVector B_l = new PVector((bNext - tNext) / 2.0f, h);
      float rot   = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);

      pg.translate(b, 0);
      pg.rotate(rot);
    }
  }
  pg.popMatrix();
}

// --- 2) Core: draw bent-strip texture for UNIFORM mode
void drawBentStripTexture_Uniform(PGraphics pg, PImage img) {
  if (img == null) return;

  final int   n  = max(3, (rows - 1));   // == nSides
  final float h  = cylinderH_px;
  final float t  = cellTopL_px;
  final float b  = cellBaseL_px;
  final float wAvg = 0.5f * (t + b);
  final float sumAvg = wAvg * n;
  if (sumAvg <= 0) return;

  final float uScale = img.width / sumAvg;

  pg.pushMatrix();  // contain transforms
  float uAcc = 0;

  for (int e = 0; e < n; e++) {
    float u0px = (uAcc     ) * uScale;
    float u1px = (uAcc+wAvg) * uScale;
    uAcc += wAvg;

    float xBL = 0, yBL = 0;
    float xBR = b, yBR = 0;
    float xTL = (b - t) * 0.5f, yTL = h;
    float xTR = xTL + t, yTR = h;

    pg.textureMode(IMAGE);
    pg.textureWrap(CLAMP);
    pg.hint(ENABLE_TEXTURE_MIPMAPS);
    pg.noStroke();

    pg.beginShape(TRIANGLES);
    pg.texture(img);
    pg.vertex(xTL, yTL, u0px, 0);
    pg.vertex(xTR, yTR, u1px, 0);
    pg.vertex(xBL, yBL, u0px, img.height);
    pg.vertex(xTR, yTR, u1px, 0);
    pg.vertex(xBR, yBR, u1px, img.height);
    pg.vertex(xBL, yBL, u0px, img.height);
    pg.endShape();

    if (e < n - 1) {
      // uniform advance (same as your panel math)
      PVector A_r = new PVector((t - b) / 2.0f, h);
      float   offN = (b - t) / 2.0f;
      PVector B_l = new PVector(offN, h);
      float rot = atan2(A_r.y, A_r.x) - atan2(B_l.y, B_l.x);

      pg.translate(b, 0);
      pg.rotate(rot);
    }
  }

  pg.popMatrix();
}

// --- 3) Public wrapper for current mode
void drawBentStripTextureForCurrentMode(PGraphics pg, PImage img) {
  if (img == null) return;
  if ((perEdgeMode || cuboidMode) && edgeTop_px != null && edgeBot_px != null) {
    drawBentStripTexture_PerEdge(pg, img);
  } else {
    drawBentStripTexture_Uniform(pg, img);
  }
}




// translation tracker
//class Affine {
//  float c, s;  // rotation cos,sin
//  float tx, ty; // translation
//  Affine() {
//    c = 1;
//    s = 0;
//    tx = 0;
//    ty = 0;
//  }
//  // apply to point (x,y)
//  PVector apply(float x, float y) {
//    return new PVector(c*x - s*y + tx, s*x + c*y + ty);
//  }
//  // translate by (dx,dy) in current local frame
//  void translate(float dx, float dy) {
//    tx += c*dx - s*dy;
//    ty += s*dx + c*dy;
//  }
//  // rotate by angle (radians)
//  void rotate(float ang) {
//    float cc = cos(ang), ss = sin(ang);
//    float c2 = c*cc - s*ss;
//    float s2 = s*cc + c*ss;
//    c = c2;
//    s = s2;
//  }
//}
