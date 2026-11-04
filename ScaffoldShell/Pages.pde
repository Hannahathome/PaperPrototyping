//----------------------------------------------------------------------
// PAGES.PDE - Spreading templates over several sheets
//
// Every copy of a shape sits on one page, and the whole copy (strip + lids) moves together.
// The page belongs to the COPY rather than the shape, so two repeats of a shape can sit on
// different sheets. ShapeSpec.repPages runs parallel to repPositions.
//
// The 2D view shows currentPage. Export walks usedPages() instead of pageCount, so a page
// left empty produces no sheet. Pages are stored 0-based and shown 1-based.
//
// The overview shows every page side by side, including empty ones. Dragging a template
// there moves it to the sheet under the pointer; clicking opens the sheet. Finer work on a
// template (cutouts, markers, connections) still needs the single page in view.
//
// Marker IDs are handed out in draw order. Every loop that skips a copy for being on another
// page must do so AFTER advancing the ID counter, or a template's markers renumber
// depending on which page is being drawn.
//----------------------------------------------------------------------

int currentPage = 0;     // page shown in the 2D view
int pageCount = 1;       // pages that exist, including empty ones
int selectedRepIdx = 0;  // last copy clicked; the one "Move" acts on
boolean pageOverview = false;  // show all pages side by side instead of currentPage

final int PAGE_BAR_H = 34;  // strip reserved above the page, see fitPageToCanvas()
final float CUT_GAP_MM = 5; // the padding getTemplateBBox() adds around a template

boolean _pageBarDrawn = false;     // set only by frames that actually show the bar
boolean _pageHasOverflow = false;  // a copy on this page leaves the cut area

// ---------------------------------------------------------------------------
// Where a copy sits
// ---------------------------------------------------------------------------

int repPage(ShapeSpec s, int rep) {
  if (s.repPages == null || rep >= s.repPages.length) return 0;
  return s.repPages[rep];
}

// A copy's offset from the pattern origin, in current px.
PVector repOffset(ShapeSpec s, int rep, PVector bbox) {
  if (freePlacementMode && s.repPositions != null && rep < s.repPositions.length) {
    return new PVector(s.repPositions[rep].x * MM_current, s.repPositions[rep].y * MM_current);
  }
  return new PVector((rep % 2) * bbox.x, (rep / 2) * bbox.y);
}

// Resizes a page list when the copy count changes. Existing copies stay put; new ones land
// on the page being looked at.
int[] resizedRepPages(int[] old, int n) {
  int[] out = new int[n];
  for (int i = 0; i < n; i++) out[i] = (old != null && i < old.length) ? old[i] : currentPage;
  return out;
}

// The pages that hold at least one copy, ascending.
int[] usedPages() {
  boolean[] used = new boolean[pageCount];
  int n = 0;
  for (ShapeSpec s : shapes) {
    for (int rep = 0; rep < s.nRep; rep++) {
      int p = constrain(repPage(s, rep), 0, pageCount - 1);
      if (!used[p]) { used[p] = true; n++; }
    }
  }
  int[] pages = new int[n];
  int w = 0;
  for (int p = 0; p < pageCount; p++) if (used[p]) pages[w++] = p;
  return pages;
}

// The base plate draws during the first drawPlan() call, which is always the first copy of
// the first shape. It lives on that copy's page, not on every page.
boolean basePlateOnPage(int page) {
  return shapes != null && shapes.size() > 0 && repPage(shapes.get(0), 0) == page;
}

// True when a copy's outline runs past the area the cutter can reach. off comes from
// repOffset(); bbox and top come from getTemplateBBox(). Measured on the page, so it accounts
// for patX/patY and patRotation.
boolean copyOutsideCutArea(PVector off, PVector bbox, float top) {
  float left = off.x + bbox.z;
  float upper = off.y + top;
  float right = left + bbox.x - CUT_GAP_MM * MM_current;
  float lower = upper + bbox.y - CUT_GAP_MM * MM_current;
  float[] xs = { left, right, right, left };
  float[] ys = { upper, upper, lower, lower };
  float a = radians(patRotation);
  for (int i = 0; i < 4; i++) {
    float px = patX_px + xs[i] * cos(a) - ys[i] * sin(a);
    float py = patY_px + xs[i] * sin(a) + ys[i] * cos(a);
    if (px < 0 || py < 0 || px > VINYL_W * MM_current || py > VINYL_H * MM_current) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Page actions
// ---------------------------------------------------------------------------

// The copy of the selected shape that Move acts on: the one last clicked if it is on this
// page, otherwise the first copy that is. -1 when the shape has nothing on this page.
int moveTargetRep() {
  ShapeSpec s = shapes.get(selectedShapeIdx);
  if (selectedRepIdx < s.nRep && repPage(s, selectedRepIdx) == currentPage) return selectedRepIdx;
  for (int rep = 0; rep < s.nRep; rep++) if (repPage(s, rep) == currentPage) return rep;
  return -1;
}

// Selecting from the 3D view can land on a shape that is not on the page in view. Without
// this the sidebar would edit a shape nothing on screen shows.
void followSelectionToPage() {
  ShapeSpec s = shapes.get(selectedShapeIdx);
  for (int rep = 0; rep < s.nRep; rep++) if (repPage(s, rep) == currentPage) return;
  currentPage = constrain(repPage(s, 0), 0, pageCount - 1);
}

// Moving past the last page creates the next one. The view follows the copy. A copy usually
// moves because it did not fit, so if its position is off the sheet it starts at the corner.
void moveSelectedCopy(int dir) {
  int rep = moveTargetRep();
  if (rep < 0) return;
  ShapeSpec s = shapes.get(selectedShapeIdx);
  int target = currentPage + dir;
  if (target < 0) return;
  s.repPages = resizedRepPages(s.repPages, s.nRep);
  s.repPages[rep] = target;
  if (s.cachedBBox != null && s.repPositions != null && rep < s.repPositions.length &&
      copyOutsideCutArea(repOffset(s, rep, s.cachedBBox), s.cachedBBox, s.cachedBBoxTop)) {
    s.repPositions[rep].set(0, 0);
  }
  selectedRepIdx = rep;
  pageCount = max(pageCount, target + 1);
  currentPage = target;
}

void addPage() {
  pageCount++;
  currentPage = pageCount - 1;
}

// Templates on the removed page move to the page before it, so nothing is lost. Page 1 has
// no page before it, so its templates stay on what becomes the new page 1.
void removeCurrentPage() {
  if (pageCount <= 1) return;
  for (ShapeSpec s : shapes) {
    if (s.repPages == null) continue;
    for (int i = 0; i < s.repPages.length; i++) {
      if (s.repPages[i] >= currentPage && s.repPages[i] > 0) s.repPages[i]--;
    }
  }
  pageCount--;
  currentPage = max(0, currentPage - 1);
}

// ---------------------------------------------------------------------------
// Page bar
// ---------------------------------------------------------------------------

final int PB_PREV = 0, PB_NEXT = 1, PB_ADD = 2, PB_REMOVE = 3, PB_MOVE_PREV = 4, PB_MOVE_NEXT = 5;
final int PB_OVERVIEW = 6, PB_COUNT = 7;
final float PB_BTN = 26, PB_LABEL_W = 92, PB_GAP = 6, PB_MOVE_LABEL_W = 46, PB_OVERVIEW_W = 76;

float pageBarWidth() {
  return 6 * PB_BTN + PB_LABEL_W + PB_MOVE_LABEL_W + PB_OVERVIEW_W + 8 * PB_GAP;
}

// Screen rect [x, y, w, h] of a page-bar button. The bar is centred on the canvas.
float[] pageBarBtnRect(int btn) {
  float x = LEFT_SIDEBAR_WIDTH + (width - LEFT_SIDEBAR_WIDTH - pageBarWidth()) / 2;
  float y = TOOLBAR_HEIGHT + (PAGE_BAR_H - PB_BTN) / 2;
  float step = PB_BTN + PB_GAP;
  float[] xs = {
    x,                                              // prev page
    x + step + PB_LABEL_W + PB_GAP,                 // next page
    x + 2 * step + PB_LABEL_W + PB_GAP,             // add
    x + 3 * step + PB_LABEL_W + PB_GAP,             // remove
    x + 4 * step + PB_LABEL_W + PB_MOVE_LABEL_W + 2 * PB_GAP,  // move back
    x + 5 * step + PB_LABEL_W + PB_MOVE_LABEL_W + 2 * PB_GAP,  // move on
    x + 6 * step + PB_LABEL_W + PB_MOVE_LABEL_W + 3 * PB_GAP   // overview
  };
  return new float[]{ xs[btn], y, btn == PB_OVERVIEW ? PB_OVERVIEW_W : PB_BTN, PB_BTN };
}

boolean pageBtnEnabled(int btn) {
  if (btn == PB_PREV)      return currentPage > 0;
  if (btn == PB_NEXT)      return currentPage < pageCount - 1;
  if (btn == PB_REMOVE)    return pageCount > 1;
  if (btn == PB_MOVE_PREV) return currentPage > 0 && moveTargetRep() >= 0;
  if (btn == PB_MOVE_NEXT) return moveTargetRep() >= 0;
  return true;
}

void drawPageBar() {
  _pageBarDrawn = true;
  String[] labels = { "<", ">", "+", "-", "<", ">", "Overview" };
  float[] prev = pageBarBtnRect(PB_PREV);
  float[] moveFirst = pageBarBtnRect(PB_MOVE_PREV);

  pushStyle();
  rectMode(CORNER);
  textAlign(CENTER, CENTER);
  uiText(13);
  for (int i = 0; i < labels.length; i++) {
    float[] r = pageBarBtnRect(i);
    boolean on = pageBtnEnabled(i);
    boolean hov = mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3];
    boolean active = (i == PB_OVERVIEW && pageOverview);
    fill(active ? color(50, 150, 255)
                : !on ? color(170, 170, 178) : (hov ? color(120, 120, 130) : color(100, 100, 110)));
    noStroke();
    rect(r[0], r[1], r[2], r[3], 4);
    fill(255);
    text(labels[i], r[0] + r[2]/2, r[1] + r[3]/2 - 1);
  }
  fill(40);
  text("Page " + (currentPage + 1) + " / " + pageCount,
       prev[0] + PB_BTN + PB_GAP + PB_LABEL_W/2, prev[1] + PB_BTN/2);
  uiText(12);
  fill(70);
  textAlign(RIGHT, CENTER);
  text("Move", moveFirst[0] - PB_GAP, moveFirst[1] + PB_BTN/2);
  if (_pageHasOverflow) {
    float[] last = pageBarBtnRect(PB_OVERVIEW);
    fill(200, 40, 40);
    textAlign(LEFT, CENTER);
    text("Outside cut area", last[0] + last[2] + 12, last[1] + PB_BTN/2);
  }
  popStyle();
}

boolean handlePageBarClick() {
  if (!_pageBarDrawn) return false;
  for (int i = 0; i < PB_COUNT; i++) {
    float[] r = pageBarBtnRect(i);
    if (mouseX < r[0] || mouseX > r[0]+r[2] || mouseY < r[1] || mouseY > r[1]+r[3]) continue;
    if (pageBtnEnabled(i)) {
      if (i == PB_PREV)      currentPage--;
      if (i == PB_NEXT)      currentPage++;
      if (i == PB_ADD)       addPage();
      if (i == PB_REMOVE)    removeCurrentPage();
      if (i == PB_MOVE_PREV) moveSelectedCopy(-1);
      if (i == PB_MOVE_NEXT) moveSelectedCopy(1);
      if (i == PB_OVERVIEW)  pageOverview = !pageOverview;
      redraw();
    }
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

final float OV_GAP = 16, OV_LABEL_H = 18;
final float OV_DRAG_SLOP = 4;  // px of travel before a press counts as a drag, not a click

boolean ovDragging = false;    // a press landed on a template in the overview
boolean ovDragMoved = false;   // and has travelled far enough to be a drag
float ovPressX, ovPressY;

// Fits n pages into w x h as the grid with the largest pages. Returns { cols, rows, scale }.
// Never larger than the single-page view, so one page does not jump in size.
float[] overviewGrid(int n, float w, float h) {
  float[] best = { 1, n, 0 };
  for (int cols = 1; cols <= n; cols++) {
    int rows = ceil(n / (float) cols);
    float s = min((w - (cols + 1) * OV_GAP) / (cols * widthA4),
                  (h - (rows + 1) * OV_GAP - rows * OV_LABEL_H) / (rows * heightA4));
    if (s > best[2]) best = new float[]{ cols, rows, s };
  }
  best[2] = min(best[2], SCREEN_SCALE);
  return best;
}

// Screen rect [x, y, w, h] of one sheet, for p in 0..pageCount-1. The grid is centred on the
// canvas, and each sheet has its label above it.
float[] overviewPageRect(int p, float[] grid) {
  float cols = grid[0], rows = grid[1];
  float pw = widthA4 * grid[2], ph = heightA4 * grid[2];
  float availW = width - LEFT_SIDEBAR_WIDTH;
  float availH = height - TOOLBAR_HEIGHT - PAGE_BAR_H - BOTTOM_EXPORT_HEIGHT;
  float gridW = cols * pw + (cols - 1) * OV_GAP;
  float gridH = rows * (ph + OV_LABEL_H) + (rows - 1) * OV_GAP;
  float x0 = LEFT_SIDEBAR_WIDTH + (availW - gridW) / 2;
  float y0 = TOOLBAR_HEIGHT + PAGE_BAR_H + (availH - gridH) / 2;
  int col = p % (int) cols, row = p / (int) cols;
  return new float[]{ x0 + col * (pw + OV_GAP),
                      y0 + row * (ph + OV_LABEL_H + OV_GAP) + OV_LABEL_H, pw, ph };
}

float[] overviewGridNow() {
  return overviewGrid(pageCount, width - LEFT_SIDEBAR_WIDTH,
                      height - TOOLBAR_HEIGHT - PAGE_BAR_H - BOTTOM_EXPORT_HEIGHT);
}

boolean pageIsEmpty(int page) {
  for (int p : usedPages()) if (p == page) return false;
  return true;
}

// The sheet under the pointer, or -1.
int overviewPageAt(float mx, float my) {
  float[] grid = overviewGridNow();
  for (int p = 0; p < pageCount; p++) {
    float[] r = overviewPageRect(p, grid);
    if (mx >= r[0] && mx <= r[0]+r[2] && my >= r[1] && my <= r[1]+r[3]) return p;
  }
  return -1;
}

void drawPageOverview() {
  background(200);
  float[] grid = overviewGridNow();
  int hovered = mouseInCanvasArea() ? overviewPageAt(mouseX, mouseY) : -1;

  // Everything drawPlan() sizes for the screen divides by SCREEN_SCALE, so it has to match the
  // thumbnails while they draw. Mouse handling never runs mid-frame, so it never sees this.
  float fullScale = SCREEN_SCALE;
  SCREEN_SCALE = grid[2];
  for (int p = 0; p < pageCount; p++) {
    float[] r = overviewPageRect(p, grid);
    // Clipped, or a template hanging off one sheet would draw across its neighbour.
    clip(r[0], r[1], r[2], r[3]);
    pushMatrix();
    translate(r[0], r[1]);
    scale(SCREEN_SCALE);
    drawPaperSheet();
    drawPageView(p);
    popMatrix();
    noClip();

    pushStyle();
    rectMode(CORNER);
    noFill();
    if (p == currentPage || p == hovered) {
      stroke(p == currentPage ? color(50, 150, 255) : color(120, 120, 130));
      strokeWeight(2);
      rect(r[0], r[1], r[2], r[3]);
    }
    fill(p == currentPage ? color(30, 100, 200) : color(60));
    noStroke();
    textAlign(LEFT, BOTTOM);
    uiText(12);
    text("Page " + (p + 1) + (pageIsEmpty(p) ? "  (empty)" : ""), r[0], r[1] - 3);
    popStyle();
  }
  if (ovDragging && ovDragMoved) drawOverviewDragOutline();
  SCREEN_SCALE = fullScale;
}

// The dragged template is clipped to its sheet like any other, so it vanishes crossing the
// gap between two sheets. This outline stays with the pointer the whole way. It is the same
// transform as drawPageView(), anchored at the pointer rather than the sheet.
void drawOverviewDragOutline() {
  ShapeSpec s = shapes.get(draggedShapeIdx);
  if (s.cachedBBox == null) return;
  pushMatrix();
  pushStyle();
  translate(mouseX, mouseY);
  scale(SCREEN_SCALE);
  rotate(radians(patRotation));
  translate(-dragOffset.x * MM_current, -dragOffset.y * MM_current);
  rectMode(CORNER);
  noFill();
  stroke(50, 150, 255);
  strokeWeight(1.5 / SCREEN_SCALE);
  rect(s.cachedBBox.z, s.cachedBBoxTop, s.cachedBBox.x, s.cachedBBox.y);
  popStyle();
  popMatrix();
}

void openPage(int page) {
  currentPage = page;
  pageOverview = false;
  redraw();
}

// Pattern mm of the pointer on a sheet, as if that sheet were the one in view.
PVector overviewPointerMM(int page) {
  float[] grid = overviewGridNow();
  float[] r = overviewPageRect(page, grid);
  return screenToPatternMM(mouseX, mouseY, r[0], r[1], grid[2]);
}

// A press on a template selects it and starts a drag; a press on bare paper opens the sheet.
// Swallows every other click on the canvas too: the overview has no single page position, so
// nothing below may treat the pointer as one.
boolean handleOverviewClick() {
  if (!_pageBarDrawn || !pageOverview) return false;
  int p = overviewPageAt(mouseX, mouseY);
  if (p < 0) return true;
  PVector mMM = overviewPointerMM(p);
  int[] hit = pickShapeAt(mMM, p);
  if (hit[0] < 0) {
    openPage(p);
    return true;
  }
  if (hit[0] != selectedShapeIdx) {
    saveGlobalsTo(shapes.get(selectedShapeIdx));
    selectedShapeIdx = hit[0];
    loadGlobalsFrom(shapes.get(selectedShapeIdx));
    setParams(false);
    syncUIToSelectedShape();
  }
  selectedRepIdx = hit[1];
  currentPage = p;
  draggedShapeIdx = hit[0];
  draggedRepIdx = hit[1];
  PVector rp = shapes.get(hit[0]).repPositions[hit[1]];
  dragOffset.set(mMM.x - rp.x, mMM.y - rp.y);
  ovDragging = true;
  ovDragMoved = false;
  ovPressX = mouseX;
  ovPressY = mouseY;
  redraw();
  return true;
}

// Moves the copy to the sheet under the pointer, at the spot under the pointer. Between
// sheets it stays where it last was, so a drop in a gap cannot lose it.
void dragCopyInOverview() {
  if (!ovDragMoved && dist(mouseX, mouseY, ovPressX, ovPressY) < OV_DRAG_SLOP) return;
  ovDragMoved = true;
  int p = overviewPageAt(mouseX, mouseY);
  if (p < 0) {
    redraw();
    return;
  }
  ShapeSpec s = shapes.get(draggedShapeIdx);
  PVector mMM = overviewPointerMM(p);
  s.repPositions[draggedRepIdx].set(mMM.x - dragOffset.x, mMM.y - dragOffset.y);
  s.repPages = resizedRepPages(s.repPages, s.nRep);
  s.repPages[draggedRepIdx] = p;
  currentPage = p;
  // Keep global repPositions in sync for the selected shape
  if (draggedShapeIdx == selectedShapeIdx) repPositions = s.repPositions;
  redraw();
}

// A press that never became a drag was a click, which opens the sheet.
void endOverviewDrag() {
  if (!ovDragging) return;
  ovDragging = false;
  if (!ovDragMoved) openPage(currentPage);
}

// Scrolling is zooming: down leaves the single page, up opens the sheet under the pointer.
boolean handlePageWheel(float count) {
  if (!_pageBarDrawn || !mouseInCanvasArea()) return false;
  if (count > 0 && !pageOverview) {
    pageOverview = true;
    redraw();
  } else if (count < 0 && pageOverview) {
    int p = overviewPageAt(mouseX, mouseY);
    if (p >= 0) openPage(p);
  }
  return true;
}
