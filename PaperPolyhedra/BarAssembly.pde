// BarAssembly.pde  v2 — per-cell shape assignment, variable heights
//
// Usage:
//   1. Load shapes via JSON (shapes[] ArrayList)
//   2. Open Assem tab → click a shape in the palette to set the paint brush
//   3. Click cells in the sidebar grid to paint / erase bars
//   4. Assembly mode (toolbar) shows the 3D result; sidebar "Template" switches to flat template
//
// Design decisions:
//   - All cells share the same grid spacing (cellSizeMM), taken from the first placed shape
//   - Each cell can hold a different shape (different height, same cross-section size)
//   - Shared face between adjacent bars = open channel; no strip panel is generated for it
//   - Strip: variable-height rectangular panels, staircase outline, tabs at bottom per panel
//   - Lid: 2D footprint of the assembly (single bottom lid)

// ---------------------------------------------------------------------------
// Data Model
// ---------------------------------------------------------------------------

class BarAssembly {
  int[][] shapeGrid;   // [row][col] = shapeIdx into shapes[] or -1 (empty)
  int gridW, gridH;
  float cellSizeMM;    // square side length in mm — uniform for all cells
  int paintShapeIdx;   // "paint brush" shape index; -1 = erase mode

  // Per-piece drag offsets (pattern-space px, delta from each piece's natural position).
  PVector stripOffset     = new PVector(0, 0);
  PVector bottomLidOffset = new PVector(0, 0);
  PVector topLidOffset    = new PVector(0, 0);
  // Effective translate applied per piece last draw — used for hit-testing.
  // [0]=strip, [1]=bottomLid, [2]=topLid
  float[] _pieceTX = new float[3];
  float[] _pieceTY = new float[3];
  // Bounding rect per piece (pattern-space px, includes offset): [x, y, w, h]
  float[][] _pieceRect = new float[3][4];
  boolean[] _pieceRectValid = new boolean[3];

  BarAssembly(int _gridW, int _gridH) {
    gridW = _gridW;
    gridH = _gridH;
    shapeGrid = new int[_gridH][_gridW];
    clearAll();
    cellSizeMM  = 30.0;
    paintShapeIdx = -1;
  }

  void setCell(int row, int col, int sIdx) {
    if (row >= 0 && row < gridH && col >= 0 && col < gridW)
      shapeGrid[row][col] = sIdx;
  }

  int getCell(int row, int col) {
    if (row < 0 || row >= gridH || col < 0 || col >= gridW) return -1;
    return shapeGrid[row][col];
  }

  boolean isFilled(int row, int col) {
    return getCell(row, col) >= 0;
  }

  boolean hasAnyCell() {
    for (int r = 0; r < gridH; r++)
      for (int c = 0; c < gridW; c++)
        if (shapeGrid[r][c] >= 0) return true;
    return false;
  }

  void resizeGrid(int newW, int newH) {
    int[][] ng = new int[newH][newW];
    for (int r = 0; r < newH; r++)
      for (int c = 0; c < newW; c++)
        ng[r][c] = -1;
    int cW = min(gridW, newW);
    int cH = min(gridH, newH);
    for (int r = 0; r < cH; r++)
      for (int c = 0; c < cW; c++)
        ng[r][c] = shapeGrid[r][c];
    shapeGrid = ng;
    gridW = newW;
    gridH = newH;
  }

  void clearAll() {
    for (int r = 0; r < gridH; r++)
      for (int c = 0; c < gridW; c++)
        shapeGrid[r][c] = -1;
  }

  void fillAll() {
    int si = (paintShapeIdx >= 0) ? paintShapeIdx : 0;
    for (int r = 0; r < gridH; r++)
      for (int c = 0; c < gridW; c++)
        shapeGrid[r][c] = si;
  }
}

// ---------------------------------------------------------------------------
// Color palette for shape visualisation
// ---------------------------------------------------------------------------

color getAsmShapeColor(int idx) {
  if (idx < 0) return color(160, 160, 160);
  color[] palette = {
    color(230, 100,  60),   // 0 orange
    color( 60, 140, 220),   // 1 blue
    color( 80, 200,  80),   // 2 green
    color(200,  60, 180),   // 3 purple
    color(240, 200,  40),   // 4 yellow
    color( 60, 200, 200),   // 5 cyan
    color(200, 100, 100),   // 6 rose
    color(120, 180,  60)    // 7 lime
  };
  return palette[idx % palette.length];
}

// ---------------------------------------------------------------------------
// Perimeter Extraction
// ---------------------------------------------------------------------------

// Hash key for a point — uses 1/10 px precision to avoid float issues.
String asmPtKey(float x, float y) {
  return Math.round(x * 10) + "|" + Math.round(y * 10);
}

// Compute ordered CW corner list of the assembly perimeter.
// Boundary half-edges are collected per cell, then stitched and collinear
// Compute ordered CW corner list of the assembly perimeter.
// Uses BarAssembly.isFilled() so it works with the new int shapeGrid.
ArrayList<PVector> computePerimeterCorners(BarAssembly a, float cellSizePx) {
  float W = cellSizePx;

  // Build boundary half-edge map: startKey → {endX, endY}
  // CW in screen coords (y-down):
  //   Top    (→): filled cell, empty above  → (cx,cy)    → (cx+W,cy)
  //   Right  (↓): filled cell, empty right  → (cx+W,cy)  → (cx+W,cy+W)
  //   Bottom (←): filled cell, empty below  → (cx+W,cy+W)→ (cx,cy+W)
  //   Left   (↑): filled cell, empty left   → (cx,cy+W)  → (cx,cy)
  java.util.HashMap<String, float[]> edgeMap =
      new java.util.HashMap<String, float[]>();

  for (int r = 0; r < a.gridH; r++) {
    for (int c = 0; c < a.gridW; c++) {
      if (!a.isFilled(r, c)) continue;
      float cx = c * W, cy = r * W;
      if (!a.isFilled(r - 1, c))
        edgeMap.put(asmPtKey(cx,     cy    ), new float[]{ cx + W, cy     });
      if (!a.isFilled(r, c + 1))
        edgeMap.put(asmPtKey(cx + W, cy    ), new float[]{ cx + W, cy + W });
      if (!a.isFilled(r + 1, c))
        edgeMap.put(asmPtKey(cx + W, cy + W), new float[]{ cx,     cy + W });
      if (!a.isFilled(r, c - 1))
        edgeMap.put(asmPtKey(cx,     cy + W), new float[]{ cx,     cy     });
    }
  }
  if (edgeMap.isEmpty()) return new ArrayList<PVector>();

  // Start at top-left corner of topmost-leftmost filled cell
  int startR = a.gridH, startC = a.gridW;
  for (int r = 0; r < a.gridH; r++)
    for (int c = 0; c < a.gridW; c++)
      if (a.isFilled(r, c) && (r < startR || (r == startR && c < startC))) {
        startR = r; startC = c;
      }
  float startX = startC * W, startY = startR * W;

  ArrayList<PVector> raw = new ArrayList<PVector>();
  float cx = startX, cy = startY;
  int maxIter = edgeMap.size() + 4;
  for (int iter = 0; iter < maxIter; iter++) {
    raw.add(new PVector(cx, cy));
    float[] next = edgeMap.get(asmPtKey(cx, cy));
    if (next == null) { println("[Assembly] Chain broken at (" + cx + "," + cy + ")"); break; }
    float nx = next[0], ny = next[1];
    if (iter > 0 && abs(nx - startX) < 0.5 && abs(ny - startY) < 0.5) break;
    cx = nx; cy = ny;
  }
  if (raw.size() < 3) return raw;

  // Merge collinear consecutive points, but always keep corners where
  // adjacent segments belong to cells of different heights — those are
  // the fold/cut lines between bars of different heights.
  int n = raw.size();
  ArrayList<PVector> merged = new ArrayList<PVector>();
  for (int i = 0; i < n; i++) {
    PVector prev = raw.get((i - 1 + n) % n);
    PVector curr = raw.get(i);
    PVector nextPt = raw.get((i + 1) % n);
    boolean collinear =
        (abs(prev.x - curr.x) < 0.1 && abs(curr.x - nextPt.x) < 0.1) ||
        (abs(prev.y - curr.y) < 0.1 && abs(curr.y - nextPt.y) < 0.1);
    if (collinear) {
      // Keep the corner if the two adjacent segments own cells of different heights
      float hIn  = asmSegmentOwnerHeight(a, prev, curr,   W);
      float hOut = asmSegmentOwnerHeight(a, curr, nextPt, W);
      if (hIn >= 0 && hOut >= 0 && abs(hIn - hOut) > 0.5f) collinear = false;
    }
    if (!collinear) merged.add(curr);
  }
  return merged;
}

// Returns the height in px for the cell that owns boundary segment p0→p1.
// Uses the inward-normal (left of CW direction in y-down coords) to identify
// the interior cell.  Returns -1 if no valid filled cell is found.
float asmSegmentOwnerHeight(BarAssembly a, PVector p0, PVector p1, float W) {
  float dx = p1.x - p0.x, dy = p1.y - p0.y;
  float len = sqrt(dx*dx + dy*dy);
  if (len < 0.01f) return -1;
  float midX = (p0.x + p1.x) * 0.5f;
  float midY = (p0.y + p1.y) * 0.5f;
  // Left of CW direction (y-down) = interior: (-dy/len, dx/len)
  float inX = midX + (-dy / len) * W * 0.4f;
  float inY = midY + ( dx / len) * W * 0.4f;
  int row = (int)(inY / W);
  int col = (int)(inX / W);
  if (row >= 0 && row < a.gridH && col >= 0 && col < a.gridW && a.isFilled(row, col))
    return getAsmCellHeightPx(a, row, col);
  return -1;
}

// Convert corner list to per-segment lengths.
float[] cornersToSegmentLengths(ArrayList<PVector> corners) {
  if (corners == null || corners.size() < 3) return null;
  int n = corners.size();
  float[] lengths = new float[n];
  for (int i = 0; i < n; i++) {
    PVector a = corners.get(i);
    PVector b = corners.get((i + 1) % n);
    lengths[i] = PVector.dist(a, b);
  }
  return lengths;
}

// For each perimeter segment find the owning (interior) cell.
// Returns int[][2] with {row, col} per segment; {-1,-1} if not found.
int[][] computePerimeterCellIndices(BarAssembly a, ArrayList<PVector> corners, float cellSizePx) {
  int n = corners.size();
  int[][] result = new int[n][2];
  float W = cellSizePx;
  for (int i = 0; i < n; i++) {
    PVector p0 = corners.get(i);
    PVector p1 = corners.get((i + 1) % n);
    float midX = (p0.x + p1.x) * 0.5f;
    float midY = (p0.y + p1.y) * 0.5f;
    float dx = p1.x - p0.x, dy = p1.y - p0.y;
    float len = sqrt(dx * dx + dy * dy);
    if (len < 0.01f) { result[i][0] = -1; result[i][1] = -1; continue; }
    // Left of CW direction (y-down) = interior: (-dy/len, dx/len)
    float inX = midX + (-dy / len) * W * 0.4f;
    float inY = midY + ( dx / len) * W * 0.4f;
    int row = (int)(inY / W);
    int col = (int)(inX / W);
    if (row >= 0 && row < a.gridH && col >= 0 && col < a.gridW && a.isFilled(row, col)) {
      result[i][0] = row;
      result[i][1] = col;
    } else {
      result[i][0] = -1;
      result[i][1] = -1;
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Cell height helpers
// ---------------------------------------------------------------------------

// Returns the height in px for the shape assigned to cell (row, col).
float getAsmCellHeightPx(BarAssembly a, int row, int col) {
  int si = a.getCell(row, col);
  if (si >= 0 && shapes != null && si < shapes.size())
    return shapes.get(si).uiHeight * MM_current;
  return a.cellSizeMM * MM_current;
}

// Returns the cell size in px, derived from the first found shape's uiTopW.
float getAsmCellSizePx(BarAssembly a) {
  for (int r = 0; r < a.gridH; r++)
    for (int c = 0; c < a.gridW; c++) {
      int si = a.getCell(r, c);
      if (si >= 0 && shapes != null && si < shapes.size()) {
        float tw = shapes.get(si).uiTopW;
        if (tw > 0) return tw * MM_current;
      }
    }
  return a.cellSizeMM * MM_current;
}

// ---------------------------------------------------------------------------
// Template Drawing — Variable-height strip
// ---------------------------------------------------------------------------
//
// Strip layout on the page (y increases downward = screen coords):
//   y = 0           ← TOP of all panels (shared cut line; connects to optional top lid)
//   y = heights[i]  ← BOTTOM of panel i (variable; tab pointing downward for lid)
//
// Left closing flap on first panel; right closing slot on last panel.
// At each junction between panel i and i+1 at x=xOff:
//   - Dashed fold line from y=0 to y=min(h_i, h_{i+1})
//   - Solid step cut from y=min to y=max (when heights differ)

void drawAssemblyVariableStrip(BarAssembly a) {
  if (!a.hasAnyCell()) return;

  float cellPx = getAsmCellSizePx(a);
  ArrayList<PVector> corners = computePerimeterCorners(a, cellPx);
  float[] segs = cornersToSegmentLengths(corners);
  if (segs == null || segs.length < 3) return;
  int n = segs.length;

  int[][] cellIdx = computePerimeterCellIndices(a, corners, cellPx);

  float[] heights = new float[n];
  for (int i = 0; i < n; i++) {
    int row = cellIdx[i][0], col = cellIdx[i][1];
    heights[i] = (row >= 0) ? getAsmCellHeightPx(a, row, col) : (a.cellSizeMM * MM_current);
  }

  // All bars bottom-aligned: shared bottom at y = maxH.
  float maxH = 0;
  float minH = Float.MAX_VALUE;
  for (float hh : heights) { maxH = max(maxH, hh); minH = min(minH, hh); }
  float dH = maxH - minH;

  // Rotate the perimeter so tall panels are grouped at the start.
  // Find the first index where height goes from non-max to max (short→tall transition).
  int startIdx = 0;
  if (dH > 0.5f) {
    for (int i = 0; i < n; i++) {
      float prevH = heights[(i - 1 + n) % n];
      float currH = heights[i];
      if (currH >= maxH - 0.5f && prevH < maxH - 0.5f) {
        startIdx = i;
        break;
      }
    }
    if (startIdx != 0) {
      float[] rSegs = new float[n];
      float[] rHeights = new float[n];
      for (int i = 0; i < n; i++) {
        rSegs[i]    = segs[(startIdx + i) % n];
        rHeights[i] = heights[(startIdx + i) % n];
      }
      segs    = rSegs;
      heights = rHeights;
    }
  }

  // Smallest segment width governs tab/flap size for uniformity.
  float minSegW = Float.MAX_VALUE;
  for (float s : segs) if (s > 0.1f) minSegW = min(minSegW, s);
  float uniformInset = minSegW / 4.0f;
  float uniformFlare = uniformInset / 3.0f;
  float uniformNeck  = tabDepth_px * TAB_DEPTH_FRACTION;

  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);

  // Flap/slot geometry is governed by the SHORTER of the two end panels.
  // Both are drawn over an edge of flapEdgeH (bottom-aligned) so they match exactly.
  float flapEdgeH   = min(heights[0], heights[n - 1]);
  float sharedInset = flapEdgeH / 4.0f;
  float sharedFlare = sharedInset / 3.0f;
  float sharedNeck  = min(neckDepth_hook_px, flapEdgeH / 3.0f);
  float sharedHook  = min(hookOffset_px,     sharedInset / 2.0f);

  // Left closing flap — active zone = flapEdgeH (bottom-aligned).
  // If heights[0] > flapEdgeH, draw a plain line for the extra height above.
  // (Split into tab-zone + non-tab-zone after the left tab is computed.)
  float xOff = 0;
  drawLeftSlantFlap(new PVector(xOff, maxH - flapEdgeH), new PVector(xOff, maxH),
                    flapDepth_px, sharedFlare, sharedInset);
  // Left riser lock tab — TOP half of step area.
  // Junction tabs sit in BOTTOM half, so they interlock with riser panel tabs.
  float leftStepH = maxH - heights[0];
  if (leftStepH < tabDepth_px) {
    for (int j = 1; j < n; j++) {
      if (heights[0] - heights[j] > tabDepth_px) {
        leftStepH = heights[0] - heights[j];
        break;
      }
    }
  }
  if (leftStepH > tabDepth_px) {
    float leftTabH  = leftStepH * 0.5f;          // half the step height
    float leftTabY  = maxH - heights[0];          // TOP of step area
    float leftInset = leftTabH / 4.0f;
    float leftFlare = leftInset / 3.0f;
    drawLeftTabContour(new PVector(0, leftTabY), new PVector(0, leftTabH),
                       tabDepth_px, leftInset, leftFlare, uniformNeck);
    // Solid line only BELOW the tab, from tab bottom to flap top.
    if (heights[0] > flapEdgeH + 0.5f)
      line(xOff, leftTabY + leftTabH, xOff, maxH - flapEdgeH);
  } else {
    // No tab — full solid line from panel top to flap top.
    if (heights[0] > flapEdgeH + 0.5f)
      line(xOff, maxH - heights[0], xOff, maxH - flapEdgeH);
  }
  for (int i = 0; i < n; i++) {
    float w    = segs[i];
    float h    = heights[i];
    float topY = maxH - h;

    // Top tab (upward) and bottom tab (downward), both arrowhead style.
    // Inset scales with this segment's width so tab is always half the edge length.
    // Shorter panels get a reduced top tab so it doesn't clash with riser lock tabs.
    float segInset = w / 4.0f;
    float segFlare = segInset / 3.0f;
    float topTabD  = (h < maxH - 0.5f) ? tabDepth_px * h / maxH : tabDepth_px;
    drawBottomTabContour(
      new PVector(xOff, topY), new PVector(w, 0),
      topTabD, segInset, segFlare, min(uniformNeck, topTabD * 0.6f)
    );
    drawTopTabContour(
      new PVector(xOff, maxH), new PVector(w, 0),
      tabDepth_px, segInset, segFlare, uniformNeck
    );

    // Junction to next panel.
    // Only geometric corners (90° turns in 3D) get fold lines.
    // Height changes get a solid cut line for the step only — no fold line.
    // Straight same-height junctions: nothing.
    if (i < n - 1) {
      float topYNext  = maxH - heights[i + 1];
      float sharedTop = max(topY, topYNext);
      float stepTop   = min(topY, topYNext);
      PVector c0 = corners.get((startIdx + i    ) % n);
      PVector c1 = corners.get((startIdx + i + 1) % n);
      PVector c2 = corners.get((startIdx + i + 2) % n);
      boolean seg_i_horiz    = abs(c1.y - c0.y) < 0.5f;
      boolean seg_next_horiz = abs(c2.y - c1.y) < 0.5f;
      boolean isGeomCorner   = (seg_i_horiz != seg_next_horiz);
      boolean isHeightChange = abs(h - heights[i + 1]) > 0.5f;
      if (isGeomCorner) {
        drawDashedLine(xOff + w, topY, xOff + w, maxH, dash_px, gap_px);
      } else if (isHeightChange) {
        // Don't draw a full solid cut line here — the tab portion needs a
        // dashed fold line instead. Solid line only for the non-tab half.
      }
      // Riser lock tab at height-change junctions — positioned at TOP of step
      // area (like the left-edge tab). Depth clamped to avoid overlap when two
      // tabs face each other across a short panel.
      // Skip if it's also a geometric corner (fold line already occupies this edge).
      if (isHeightChange && !isGeomCorner) {
        float stepH    = sharedTop - stepTop;
        float tabH     = stepH * 0.5f;             // half the step height
        float jInset   = tabH / 4.0f;
        float jFlare   = jInset / 3.0f;
        if (h > heights[i + 1]) {
          // Panel i is taller → tab extends RIGHT, BOTTOM half of step area.
          float tabTopY = sharedTop - tabH;
          // Solid cut line for the TOP half (no tab there).
          line(xOff + w, stepTop, xOff + w, tabTopY);
          // Dashed fold line for the BOTTOM half (tab folds here).
          float clampedDepth = min(tabDepth_px, segs[i + 1] * 0.35f);
          drawDashedLine(xOff + w, tabTopY + jInset, xOff + w, sharedTop - jInset, dash_px, gap_px);
          drawRightTabContour(new PVector(0, tabTopY), new PVector(xOff + w, tabH),
                              clampedDepth, jInset, jFlare, min(uniformNeck, clampedDepth * 0.6f));
        } else {
          // Panel i+1 is taller → tab extends LEFT, TOP half of step area.
          float tabTopY = stepTop;
          // Dashed fold line for the TOP half (tab folds here).
          float clampedDepth = min(tabDepth_px, w * 0.35f);
          drawLeftTabContour(new PVector(xOff + w, tabTopY), new PVector(0, tabH),
                             clampedDepth, jInset, jFlare, min(uniformNeck, clampedDepth * 0.6f));
          // Solid cut line for the BOTTOM half (no tab there).
          line(xOff + w, tabTopY + tabH, xOff + w, sharedTop);
        }
      }
      // straight same-height → nothing
    }

    xOff += w;
  }

  // Right closing slot — active zone = flapEdgeH (bottom-aligned), same as left flap.
  // If heights[n-1] > flapEdgeH, draw a plain line for the extra height above.
  if (heights[n - 1] > flapEdgeH + 0.5f)
    line(xOff, maxH - heights[n - 1], xOff, maxH - flapEdgeH);
  drawRightSlantFlap(
    new PVector(xOff, maxH - flapEdgeH), new PVector(xOff, maxH),
    flapDepth_px, sharedInset, sharedFlare, sharedNeck, sharedHook
  );
}

// ---------------------------------------------------------------------------
// Stepped Top Lid helpers
// ---------------------------------------------------------------------------

// Returns all unique height values (px) present in the assembly, sorted descending.
// Returns height groups in spatial left-to-right order (column 0 → last column).
// The first new height encountered scanning left→right is group 0, etc.
// This ensures bridge widths match the actual adjacent pairs in the assembly.
float[] getAssemblyUniqueHeights(BarAssembly a) {
  ArrayList<Float> ordered = new ArrayList<Float>();
  for (int c = 0; c < a.gridW; c++) {
    for (int r = 0; r < a.gridH; r++) {
      if (!a.isFilled(r, c)) continue;
      float h = getAsmCellHeightPx(a, r, c);
      boolean found = false;
      for (int k = 0; k < ordered.size(); k++) if (abs(ordered.get(k) - h) < 0.5f) { found = true; break; }
      if (!found) ordered.add(h);
      break; // one representative row per column is enough
    }
  }
  float[] arr = new float[ordered.size()];
  for (int i = 0; i < arr.length; i++) arr[i] = ordered.get(i);
  return arr;
}

// Total shared edge length (px) between cells at height h1 and cells at height h2.
float computeSharedBoundaryLength(BarAssembly a, float h1, float h2, float cellPx) {
  float total = 0;
  for (int r = 0; r < a.gridH; r++)
    for (int c = 0; c < a.gridW; c++) {
      if (!a.isFilled(r, c)) continue;
      if (abs(getAsmCellHeightPx(a, r, c) - h1) > 0.5f) continue;
      if (c + 1 < a.gridW && a.isFilled(r, c+1) && abs(getAsmCellHeightPx(a, r, c+1) - h2) < 0.5f) total += cellPx;
      if (r + 1 < a.gridH && a.isFilled(r+1, c) && abs(getAsmCellHeightPx(a, r+1, c) - h2) < 0.5f) total += cellPx;
    }
  return total;
}

// Compute perimeter corners for a boolean mask (same algorithm as computePerimeterCorners
// but operates on a standalone mask array instead of BarAssembly.isFilled).
ArrayList<PVector> computePerimeterCornersFromMask(boolean[][] mask, int gridH, int gridW, float W) {
  java.util.HashMap<String, float[]> edgeMap = new java.util.HashMap<String, float[]>();
  for (int r = 0; r < gridH; r++) {
    for (int c = 0; c < gridW; c++) {
      if (!mask[r][c]) continue;
      float cx = c * W, cy = r * W;
      boolean aboveEmpty = (r == 0 || !mask[r-1][c]);
      boolean rightEmpty = (c == gridW-1 || !mask[r][c+1]);
      boolean belowEmpty = (r == gridH-1 || !mask[r+1][c]);
      boolean leftEmpty  = (c == 0 || !mask[r][c-1]);
      if (aboveEmpty) edgeMap.put(asmPtKey(cx,     cy    ), new float[]{ cx+W, cy   });
      if (rightEmpty) edgeMap.put(asmPtKey(cx+W,   cy    ), new float[]{ cx+W, cy+W });
      if (belowEmpty) edgeMap.put(asmPtKey(cx+W,   cy+W  ), new float[]{ cx,   cy+W });
      if (leftEmpty)  edgeMap.put(asmPtKey(cx,     cy+W  ), new float[]{ cx,   cy   });
    }
  }
  if (edgeMap.isEmpty()) return new ArrayList<PVector>();
  int startR = gridH, startC = gridW;
  for (int r = 0; r < gridH; r++)
    for (int c = 0; c < gridW; c++)
      if (mask[r][c] && (r < startR || (r == startR && c < startC))) { startR = r; startC = c; }
  float startX = startC * W, startY = startR * W;
  ArrayList<PVector> raw = new ArrayList<PVector>();
  float cx = startX, cy = startY;
  for (int iter = 0; iter < edgeMap.size() + 4; iter++) {
    raw.add(new PVector(cx, cy));
    float[] next = edgeMap.get(asmPtKey(cx, cy));
    if (next == null) break;
    float nx = next[0], ny = next[1];
    if (iter > 0 && abs(nx - startX) < 0.5f && abs(ny - startY) < 0.5f) break;
    cx = nx; cy = ny;
  }
  if (raw.size() < 3) return raw;
  int n = raw.size();
  ArrayList<PVector> merged = new ArrayList<PVector>();
  for (int i = 0; i < n; i++) {
    PVector prev = raw.get((i-1+n)%n), curr = raw.get(i), nextPt = raw.get((i+1)%n);
    boolean collinear =
      (abs(prev.x-curr.x) < 0.1f && abs(curr.x-nextPt.x) < 0.1f) ||
      (abs(prev.y-curr.y) < 0.1f && abs(curr.y-nextPt.y) < 0.1f);
    if (!collinear) merged.add(curr);
  }
  return merged;
}

// Draw the perimeter lid for only the cells at targetHeight.
// connectLeft / connectRight: if true, the left/right boundary of the bounding box
// is a fold line (connects to a riser) instead of a tab.
// First lid in sequence → connectLeft=false, connectRight=true (or false if only 1 group)
// Middle lids           → connectLeft=true,  connectRight=true
// Last lid              → connectLeft=true,  connectRight=false
// Returns PVector(footprintW, footprintH) — actual footprint, no tab overhang.
PVector drawHeightGroupLid(BarAssembly a, float targetH, float cellPx,
                           float offsetX, float offsetY,
                           boolean connectLeft, boolean connectRight) {
  boolean[][] mask = new boolean[a.gridH][a.gridW];
  for (int r = 0; r < a.gridH; r++)
    for (int c = 0; c < a.gridW; c++)
      mask[r][c] = a.isFilled(r, c) && abs(getAsmCellHeightPx(a, r, c) - targetH) < 0.5f;

  ArrayList<PVector> corners = computePerimeterCornersFromMask(mask, a.gridH, a.gridW, cellPx);
  if (corners == null || corners.size() < 3) return new PVector(0, 0);

  // Bounding box in original (un-normalised) corner space.
  float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE;
  float maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
  for (PVector p : corners) {
    minX = min(minX, p.x); maxX = max(maxX, p.x);
    minY = min(minY, p.y); maxY = max(maxY, p.y);
  }

  float localNeck = tabDepth_px * TAB_DEPTH_FRACTION;
  pushMatrix();
  translate(offsetX - minX, offsetY - minY);
  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);

  int nc = corners.size();
  for (int i = 0; i < nc; i++) {
    PVector p0 = corners.get(i);
    PVector p1 = corners.get((i + 1) % nc);
    float edgeLen = PVector.dist(p0, p1);
    if (edgeLen < 0.1f) continue;

    // A vertical edge sitting on the left bbox boundary → left connector
    boolean isLeftEdge  = (abs(p0.x - minX) < 0.5f && abs(p1.x - minX) < 0.5f);
    // A vertical edge sitting on the right bbox boundary → right connector
    boolean isRightEdge = (abs(p0.x - maxX) < 0.5f && abs(p1.x - maxX) < 0.5f);
    boolean isFoldEdge  = (isLeftEdge && connectLeft) || (isRightEdge && connectRight);

    float angle = atan2(p1.y - p0.y, p1.x - p0.x);
    pushMatrix();
    translate(p0.x, p0.y);
    rotate(angle);
    if (isFoldEdge) {
      drawDashedLine(0, 0, edgeLen, 0, dash_px, gap_px);
    } else {
      float localInset = edgeLen / 4.0f;
      float localFlare = localInset / 3.0f;
      drawBottomTabContour(new PVector(0, 0), new PVector(edgeLen, 0),
                           tabDepth_px, localInset, localFlare, localNeck);
    }
    popMatrix();
  }

  popMatrix();
  return new PVector(maxX - minX, maxY - minY);
}

// Draw the full stepped top lid: one footprint per height group, connected by riser strips.
// First/last lids get 3 outer tabs; middle lids get only top+bottom tabs.
void drawSteppedTopLid(BarAssembly a, float cellPx) {
  float[] uHeights = getAssemblyUniqueHeights(a);  // descending (tallest first)
  if (uHeights.length == 0) return;
  int last = uHeights.length - 1;
  float xOff = 0;
  for (int k = 0; k <= last; k++) {
    boolean cL = (k > 0);       // left edge connects to previous riser
    boolean cR = (k < last);    // right edge connects to next riser
    PVector bbox = drawHeightGroupLid(a, uHeights[k], cellPx, xOff, 0, cL, cR);
    xOff += bbox.x;
    if (k < last) {
      float riserW = abs(uHeights[k] - uHeights[k + 1]);                                    // width = height step (spatial order, may go up or down)
      float riserH = computeSharedBoundaryLength(a, uHeights[k], uHeights[k + 1], cellPx); // height = shared boundary
      if (riserW > 0.1f) {
        float rInset = riserW / 4.0f;
        float rFlare = rInset / 3.0f;
        float rNeck  = tabDepth_px * TAB_DEPTH_FRACTION;
        pushStyle();
        noFill(); stroke(uiLightGrayCutLines ? 180 : 0);
        // Fold lines on both sides already drawn by adjacent lid boundary edges.
        // Top edge: tab pointing upward (away from riser rectangle).
        drawBottomTabContour(new PVector(xOff, 0), new PVector(riserW, 0),
                             tabDepth_px, rInset, rFlare, rNeck);
        // Bottom edge: tab pointing downward.
        drawTopTabContour(new PVector(xOff, riserH), new PVector(riserW, 0),
                          tabDepth_px, rInset, rFlare, rNeck);
        popStyle();
        xOff += riserW;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Lid Drawing (2D footprint of the assembly)
// ---------------------------------------------------------------------------

void drawAssemblyLid(BarAssembly a, float cellSizePx) {
  if (!a.hasAnyCell()) return;
  ArrayList<PVector> corners = computePerimeterCorners(a, cellSizePx);
  if (corners == null || corners.size() < 3) return;
  int n = corners.size();
  float localNeck = tabDepth_px * TAB_DEPTH_FRACTION;
  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);
  for (int i = 0; i < n; i++) {
    PVector p0 = corners.get(i);
    PVector p1 = corners.get((i + 1) % n);
    float edgeLen = PVector.dist(p0, p1);
    if (edgeLen < 0.1) continue;
    float localInset = edgeLen / 4.0;           // tab = half edge length
    float localFlare  = localInset / 3.0;       // proportional arrowhead flare
    float angle = atan2(p1.y - p0.y, p1.x - p0.x);
    pushMatrix();
    translate(p0.x, p0.y);
    rotate(angle);
    drawBottomTabContour(new PVector(0, 0), new PVector(edgeLen, 0),
                         tabDepth_px, localInset, localFlare, localNeck);
    popMatrix();
  }
}

// AABB of the lid polygon expanded by tabDepth on each side.
PVector getAssemblyLidBBox(BarAssembly a, float cellSizePx) {
  ArrayList<PVector> corners = computePerimeterCorners(a, cellSizePx);
  if (corners == null || corners.isEmpty())
    return new PVector(cellSizePx + 2 * tabDepth_px, cellSizePx + 2 * tabDepth_px);
  float minX = Float.MAX_VALUE, maxX = -Float.MAX_VALUE;
  float minY = Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
  for (PVector p : corners) {
    minX = min(minX, p.x); maxX = max(maxX, p.x);
    minY = min(minY, p.y); maxY = max(maxY, p.y);
  }
  return new PVector(maxX - minX + 2 * tabDepth_px, maxY - minY + 2 * tabDepth_px);
}

// ---------------------------------------------------------------------------
// Color fill helpers for assembly template (behind outlines).
// Skipped during SVG cut export (bExportingCutFile == true).
// ---------------------------------------------------------------------------

// Strip: one filled rectangle per perimeter panel, coloured by its owning shape.
void drawAssemblyStripColorFill(BarAssembly a) {
  if (!a.hasAnyCell() || bExportingCutFile) return;

  float cellPx = getAsmCellSizePx(a);
  ArrayList<PVector> corners = computePerimeterCorners(a, cellPx);
  float[] segs = cornersToSegmentLengths(corners);
  if (segs == null || segs.length < 3) return;
  int n = segs.length;
  int[][] cellIdx = computePerimeterCellIndices(a, corners, cellPx);

  float[] heights = new float[n];
  int[] siArr = new int[n];
  for (int i = 0; i < n; i++) {
    int row = cellIdx[i][0], col = cellIdx[i][1];
    heights[i] = (row >= 0) ? getAsmCellHeightPx(a, row, col) : (a.cellSizeMM * MM_current);
    siArr[i]   = (row >= 0) ? a.getCell(row, col) : -1;
  }

  float maxH = 0, minH = Float.MAX_VALUE;
  for (float hh : heights) { maxH = max(maxH, hh); minH = min(minH, hh); }

  // Same rotation as drawAssemblyVariableStrip
  if (maxH - minH > 0.5f) {
    int startIdx = 0;
    for (int i = 0; i < n; i++) {
      if (heights[i] >= maxH - 0.5f && heights[(i - 1 + n) % n] < maxH - 0.5f) { startIdx = i; break; }
    }
    if (startIdx != 0) {
      float[] rS = new float[n]; float[] rH = new float[n]; int[] rI = new int[n];
      for (int i = 0; i < n; i++) {
        rS[i] = segs[(startIdx + i) % n];
        rH[i] = heights[(startIdx + i) % n];
        rI[i] = siArr[(startIdx + i) % n];
      }
      segs = rS; heights = rH; siArr = rI;
    }
  }

  pushStyle();
  noStroke();
  float xOff = 0;
  for (int i = 0; i < n; i++) {
    int si = siArr[i];
    color c;
    if (si >= 0 && shapes != null && si < shapes.size() && shapes.get(si).fillColorEnabled) {
      c = shapes.get(si).shapeColor;
    } else {
      c = getAsmShapeColor(si);
    }
    fill(c);
    rect(xOff, maxH - heights[i], segs[i], heights[i]);
    xOff += segs[i];
  }
  popStyle();
}

// Bottom lid: per-cell coloured rectangles matching the grid footprint.
void drawAssemblyLidColorFill(BarAssembly a, float cellSizePx) {
  if (!a.hasAnyCell() || bExportingCutFile) return;

  pushStyle();
  noStroke();
  for (int r = 0; r < a.gridH; r++) {
    for (int c = 0; c < a.gridW; c++) {
      if (!a.isFilled(r, c)) continue;
      int si = a.getCell(r, c);
      color clr;
      if (si >= 0 && shapes != null && si < shapes.size() && shapes.get(si).fillColorEnabled) {
        clr = shapes.get(si).shapeColor;
      } else {
        clr = getAsmShapeColor(si);
      }
      fill(clr);
      rect(c * cellSizePx, r * cellSizePx, cellSizePx, cellSizePx);
    }
  }
  popStyle();
}

// Stepped top lid: per-cell fills following the height-group layout.
void drawSteppedTopLidColorFill(BarAssembly a, float cellPx) {
  if (!a.hasAnyCell() || bExportingCutFile) return;

  float[] uHeights = getAssemblyUniqueHeights(a);
  if (uHeights.length == 0) return;

  pushStyle();
  noStroke();
  int last = uHeights.length - 1;
  float xOff = 0;

  for (int k = 0; k <= last; k++) {
    float targetH = uHeights[k];
    boolean[][] mask = new boolean[a.gridH][a.gridW];
    for (int r = 0; r < a.gridH; r++)
      for (int c = 0; c < a.gridW; c++)
        mask[r][c] = a.isFilled(r, c) && abs(getAsmCellHeightPx(a, r, c) - targetH) < 0.5f;

    ArrayList<PVector> gc = computePerimeterCornersFromMask(mask, a.gridH, a.gridW, cellPx);
    if (gc == null || gc.size() < 3) continue;

    float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE;
    float maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
    for (PVector p : gc) {
      minX = min(minX, p.x); maxX = max(maxX, p.x);
      minY = min(minY, p.y); maxY = max(maxY, p.y);
    }

    for (int r = 0; r < a.gridH; r++) {
      for (int c = 0; c < a.gridW; c++) {
        if (!mask[r][c]) continue;
        int si = a.getCell(r, c);
        color clr;
        if (si >= 0 && shapes != null && si < shapes.size() && shapes.get(si).fillColorEnabled) {
          clr = shapes.get(si).shapeColor;
        } else {
          clr = getAsmShapeColor(si);
        }
        fill(clr);
        rect(xOff - minX + c * cellPx, -minY + r * cellPx, cellPx, cellPx);
      }
    }

    xOff += maxX - minX;
    if (k < last) {
      float riserW = abs(uHeights[k] - uHeights[k + 1]);
      if (riserW > 0.1f) {
        // Fill the riser with the colour of the taller of the two adjacent bars
        float riserH = computeSharedBoundaryLength(a, uHeights[k], uHeights[k + 1], cellPx);
        float tallerH = max(uHeights[k], uHeights[k + 1]);
        // Find a representative cell at the taller height
        int riserSi = -1;
        for (int r = 0; r < a.gridH && riserSi < 0; r++)
          for (int c = 0; c < a.gridW && riserSi < 0; c++)
            if (a.isFilled(r, c) && abs(getAsmCellHeightPx(a, r, c) - tallerH) < 0.5f)
              riserSi = a.getCell(r, c);
        color rClr;
        if (riserSi >= 0 && shapes != null && riserSi < shapes.size() && shapes.get(riserSi).fillColorEnabled) {
          rClr = shapes.get(riserSi).shapeColor;
        } else {
          rClr = getAsmShapeColor(riserSi);
        }
        fill(rClr);
        rect(xOff, 0, riserW, riserH);
        xOff += riserW;
      }
    }
  }
  popStyle();
}

// ---------------------------------------------------------------------------
// Full flat template: strip above, two lids below
// ---------------------------------------------------------------------------

void drawAssemblyPlan(BarAssembly a) {
  if (a == null || !a.hasAnyCell()) {
    pushStyle();
    fill(120); noStroke();
    textAlign(CENTER, CENTER);
    textSize(13 / SCREEN_SCALE);
    text("No bars placed.\nOpen the Assem tab, pick a shape, and click grid cells.",
         widthA4 * 0.35, heightA4 * 0.3);
    popStyle();
    return;
  }

  // Load tab params from the first found shape
  boolean loaded = false;
  for (int r = 0; r < a.gridH && !loaded; r++)
    for (int c = 0; c < a.gridW && !loaded; c++) {
      int si = a.getCell(r, c);
      if (si >= 0 && shapes != null && si < shapes.size()) {
        loadGlobalsFrom(shapes.get(si));
        setParams(bExportingCutFile);
        loaded = true;
      }
    }

  float cellPx = getAsmCellSizePx(a);

  pushStyle();
  rectMode(CORNER);
  if (!bSavePDF) strokeWeight(1.0 / SCREEN_SCALE);
  noFill();
  stroke(uiLightGrayCutLines ? 180 : 0);

  // Find maximum strip height for layout calculations (needed before drawing).
  ArrayList<PVector> corners = computePerimeterCorners(a, cellPx);
  int[][] cellIdx = computePerimeterCellIndices(a, corners, cellPx);
  float maxH = 0;
  if (cellIdx != null)
    for (int i = 0; i < cellIdx.length; i++)
      if (cellIdx[i][0] >= 0)
        maxH = max(maxH, getAsmCellHeightPx(a, cellIdx[i][0], cellIdx[i][1]));
  if (maxH < 1) maxH = a.cellSizeMM * MM_current;

  float stripH     = maxH + 2 * tabDepth_px;
  float lidSpacing = max(stripH * LID_SPACING_MARGIN, stripH + tabDepth_px + 2 * MM_current);
  PVector lidBBox  = getAssemblyLidBBox(a, cellPx);
  float lidGap     = tabDepth_px * 2 + 4 * MM_current;
  float topLidBaseY = lidSpacing + lidBBox.y + lidGap;

  // --- Estimate piece widths for bounding-rect cache ---
  float[] segs = cornersToSegmentLengths(corners);
  float stripTotalW = flapDepth_px * 2;
  if (segs != null) for (float s : segs) stripTotalW += s;
  float topLidTotalW = computeTopLidTotalWidth(a, cellPx);

  // Offsets are stored in mm; multiply by MM_current for current coordinate space.
  // --- Strip ---
  float tx0 = a.stripOffset.x * MM_current, ty0 = a.stripOffset.y * MM_current;
  a._pieceTX[0] = tx0; a._pieceTY[0] = ty0;
  a._pieceRect[0] = new float[]{ tx0 - flapDepth_px, ty0 - tabDepth_px,
                                  stripTotalW, stripH };
  a._pieceRectValid[0] = true;
  pushMatrix();
  translate(tx0, ty0);
  drawAssemblyStripColorFill(a);
  drawAssemblyVariableStrip(a);
  popMatrix();

  // --- Bottom lid ---
  float tx1 = a.bottomLidOffset.x * MM_current, ty1 = a.bottomLidOffset.y * MM_current + lidSpacing;
  a._pieceTX[1] = tx1; a._pieceTY[1] = ty1;
  a._pieceRect[1] = new float[]{ tx1 - tabDepth_px, ty1 - tabDepth_px,
                                  lidBBox.x, lidBBox.y };
  a._pieceRectValid[1] = true;
  pushMatrix();
  translate(tx1, ty1);
  drawAssemblyLidColorFill(a, cellPx);
  drawAssemblyLid(a, cellPx);
  popMatrix();

  // --- Stepped top lid — placed to the RIGHT of the bottom lid, same row ---
  float topLidBaseX = lidBBox.x + lidGap;
  float tx2 = a.topLidOffset.x * MM_current + topLidBaseX, ty2 = a.topLidOffset.y * MM_current + lidSpacing;
  a._pieceTX[2] = tx2; a._pieceTY[2] = ty2;
  a._pieceRect[2] = new float[]{ tx2 - tabDepth_px, ty2 - tabDepth_px,
                                  topLidTotalW + 2 * tabDepth_px, maxH + 2 * tabDepth_px };
  a._pieceRectValid[2] = true;
  pushMatrix();
  translate(tx2, ty2);
  drawSteppedTopLidColorFill(a, cellPx);
  drawSteppedTopLid(a, cellPx);
  popMatrix();

  popStyle();
}

// Estimate total width of the stepped top lid (sum of footprints + riser widths).
float computeTopLidTotalWidth(BarAssembly a, float cellPx) {
  float[] uH = getAssemblyUniqueHeights(a);
  float total = 0;
  for (int k = 0; k < uH.length; k++) {
    boolean[][] mask = new boolean[a.gridH][a.gridW];
    for (int r = 0; r < a.gridH; r++)
      for (int c = 0; c < a.gridW; c++)
        mask[r][c] = a.isFilled(r, c) && abs(getAsmCellHeightPx(a, r, c) - uH[k]) < 0.5f;
    ArrayList<PVector> cs = computePerimeterCornersFromMask(mask, a.gridH, a.gridW, cellPx);
    if (cs != null && cs.size() >= 2) {
      float mn = Float.MAX_VALUE, mx = -Float.MAX_VALUE;
      for (PVector p : cs) { mn = min(mn, p.x); mx = max(mx, p.x); }
      total += mx - mn;
    }
    if (k < uH.length - 1) total += abs(uH[k] - uH[k + 1]);
  }
  return total;
}

// Returns which assembly piece (0=strip, 1=bottomLid, 2=topLid) contains the
// given point in pattern-space px, or -1 if none.
int pickAsmPiece(BarAssembly a, float px, float py) {
  if (a == null) return -1;
  for (int i = 0; i < 3; i++) {
    if (!a._pieceRectValid[i]) continue;
    float[] r = a._pieceRect[i];
    if (px >= r[0] && px <= r[0] + r[2] && py >= r[1] && py <= r[1] + r[3]) return i;
  }
  return -1;
}

// ---------------------------------------------------------------------------
// 3D Assembly Rendering
// ---------------------------------------------------------------------------

// Draw all bars in the BarAssembly as colored prisms at their grid positions.
// Call this from inside a view3DBuffer.beginDraw() / endDraw() block,
// after setting up translation/rotation/scale.
void draw3DAssembly(BarAssembly a, PGraphics pg) {
  if (a == null || !a.hasAnyCell()) {
    pg.fill(80); pg.noStroke();
    pg.textAlign(CENTER, CENTER);
    pg.textSize(16);
    pg.text("No bars placed.\nOpen the Assem tab,\npick a shape and click grid cells.", 0, 0, 0);
    return;
  }

  // Scene units = px (consistent with drawPrismWireframe)
  float W = a.cellSizeMM * MM_current;

  // First pass: find the maximum half-height so we can bottom-align all bars
  float maxHalfH = 0;
  for (int r = 0; r < a.gridH; r++) {
    for (int c = 0; c < a.gridW; c++) {
      int si = a.getCell(r, c);
      if (si < 0) continue;
      if (shapes != null && si < shapes.size()) {
        loadGlobalsFrom(shapes.get(si));
        setParams(false);
        maxHalfH = max(maxHalfH, cylinderVertH_px / 2.0); // <-- height fix
      }
    }
  }

  // Second pass: draw each bar bottom-aligned (bottom at +maxHalfH in P3D y-down space)
  for (int r = 0; r < a.gridH; r++) {
    for (int c = 0; c < a.gridW; c++) {
      int si = a.getCell(r, c);
      if (si < 0) continue;

      if (shapes != null && si < shapes.size()) {
        loadGlobalsFrom(shapes.get(si));
        setParams(false);
      }

      float halfH = cylinderVertH_px / 2.0; // <-- height fix
      // Bottom-align: shift bar up so its bottom face sits at +maxHalfH
      float posY = maxHalfH - halfH;

      // Center each bar in its grid cell; grid is centered at origin
      float posX = (c + 0.5f) * W - (a.gridW * 0.5f * W);
      float posZ = (r + 0.5f) * W - (a.gridH * 0.5f * W);

      color savedColor = shapeColor;
      boolean savedFill = fillColorEnabled;
      if (!assemblyTrueColor) {
        // Palette mode: override with a distinct colour per shape index
        shapeColor = getAsmShapeColor(si);
        fillColorEnabled = true;
      }
      // True-colour mode: loadGlobalsFrom() already set shapeColor/fillColorEnabled/sideTextureMode

      pg.pushMatrix();
      pg.translate(posX, posY, posZ);
      drawPrismWireframe(pg);
      pg.popMatrix();

      shapeColor = savedColor;
      fillColorEnabled = savedFill;
    }
  }

  // Restore selected shape globals
  if (shapes != null && shapes.size() > 0)
    loadGlobalsFrom(shapes.get(max(0, min(selectedShapeIdx, shapes.size() - 1))));
  setParams(false);
}
