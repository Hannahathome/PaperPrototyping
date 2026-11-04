//----------------------------------------------------------------------
// PagesSelfTest.pde - Regression checks for page assignment
//
// Enable with PAGES_SELFTEST = true and run the sketch: it prints a pass/fail table and
// exits. Same shape as AUDIT_MODE, FRAME_SELFTEST and TEXTURE_SELFTEST.
//----------------------------------------------------------------------

final boolean PAGES_SELFTEST = false;   // flip to true to run the checks

int _pgChecks = 0, _pgFails = 0;

void pagesSelfTestRun() {
  println("[PAGES SELFTEST]");
  pagesTestAssignment();
  pagesTestRemoval();
  pagesTestCutArea();
  pagesTestOverview();
  pagesTestOverviewDrag();
  println("[PAGES SELFTEST] " + (_pgChecks - _pgFails) + "/" + _pgChecks + " passed"
        + (_pgFails == 0 ? "" : "   <-- " + _pgFails + " FAILED"));
  exit();
}

void pgCheck(String what, boolean ok, String detail) {
  _pgChecks++;
  if (!ok) _pgFails++;
  println("  [" + (ok ? "PASS" : "FAIL") + "] " + what + (detail.isEmpty() ? "" : "   " + detail));
}

// Three shapes, the second with two copies: {0}, {0, 1}, {3}, with pages 2 and 4 empty.
void pgReset() {
  while (shapes.size() < 3) shapes.add(shapeFromCurrentGlobals());
  while (shapes.size() > 3) shapes.remove(shapes.size() - 1);
  shapes.get(0).nRep = 1; shapes.get(0).repPages = new int[]{ 0 };
  shapes.get(1).nRep = 2; shapes.get(1).repPages = new int[]{ 0, 1 };
  shapes.get(2).nRep = 1; shapes.get(2).repPages = new int[]{ 3 };
  pageCount = 5;
  currentPage = 0;
  selectedShapeIdx = 0;
  selectedRepIdx = 0;
}

void pagesTestAssignment() {
  println(" assignment");
  pgReset();

  ShapeSpec s = new ShapeSpec();
  pgCheck("a new shape starts on page 1", repPage(s, 0) == 0, "");
  s.repPages = null;
  pgCheck("no page list reads as page 1", repPage(s, 0) == 0, "");
  pgCheck("a copy past the list reads as page 1", repPage(shapes.get(0), 5) == 0, "");

  int[] pages = usedPages();
  pgCheck("empty pages are skipped",
          pages.length == 3 && pages[0] == 0 && pages[1] == 1 && pages[2] == 3, str(pages.length));

  currentPage = 2;
  int[] grown = resizedRepPages(new int[]{ 4, 1 }, 3);
  pgCheck("existing copies keep their page when the count grows",
          grown[0] == 4 && grown[1] == 1, "");
  pgCheck("a new copy lands on the page in view", grown[2] == 2, str(grown[2]));
  pgCheck("shrinking keeps the remaining copies", resizedRepPages(new int[]{ 4, 1 }, 1)[0] == 4, "");

  pgReset();
  pgCheck("the base follows the first copy of the first shape",
          basePlateOnPage(0) && !basePlateOnPage(1), "");

  selectedShapeIdx = 1;
  selectedRepIdx = 1;
  currentPage = 1;
  moveSelectedCopy(1);
  pgCheck("Move sends the clicked copy on", shapes.get(1).repPages[1] == 2, "");
  pgCheck("Move leaves the other copy", shapes.get(1).repPages[0] == 0, "");
  pgCheck("the view follows the moved copy", currentPage == 2, str(currentPage));

  currentPage = 4;
  pgCheck("no move target when the shape is not on this page", moveTargetRep() == -1, "");
  moveSelectedCopy(1);
  pgCheck("Move with no target does nothing", pageCount == 5 && currentPage == 4, "");

  // Off the sheet at the old position, so it should land at the corner of the new page.
  pgReset();
  ShapeSpec far = shapes.get(0);
  far.cachedBBox = new PVector(105 * MM_current, 55 * MM_current, 0);
  far.cachedBBoxTop = 0;
  far.repPositions = new PVector[]{ new PVector(0, VINYL_H) };
  moveSelectedCopy(1);
  pgCheck("Move brings an off-sheet copy to the corner", far.repPositions[0].y == 0, str(far.repPositions[0].y));
  far.repPositions[0].set(20, 30);
  moveSelectedCopy(1);
  pgCheck("Move keeps a position that fits", far.repPositions[0].x == 20 && far.repPositions[0].y == 30, "");

  pgReset();
  selectedShapeIdx = 1;
  selectedRepIdx = 1;
  currentPage = 4;
  shapes.get(2).repPages[0] = 4;
  selectedShapeIdx = 2;
  moveSelectedCopy(1);
  pgCheck("Move past the last page creates one", pageCount == 6 && currentPage == 5, str(pageCount));

  pgReset();
  selectedShapeIdx = 2;
  followSelectionToPage();
  pgCheck("selecting from 3D brings its page into view", currentPage == 3, str(currentPage));
}

void pagesTestRemoval() {
  println(" removing a page");
  pgReset();
  currentPage = 1;
  removeCurrentPage();
  pgCheck("a removed page's copies go to the page before",
          shapes.get(1).repPages[1] == 0, str(shapes.get(1).repPages[1]));
  pgCheck("later pages shift down", shapes.get(2).repPages[0] == 2, str(shapes.get(2).repPages[0]));
  pgCheck("the page count drops", pageCount == 4, str(pageCount));

  pgReset();
  currentPage = 0;
  removeCurrentPage();
  pgCheck("removing page 1 keeps its copies on page 1",
          shapes.get(0).repPages[0] == 0 && shapes.get(1).repPages[0] == 0, "");
  pgCheck("removing page 1 shifts the rest down", shapes.get(2).repPages[0] == 2, "");

  pageCount = 1;
  currentPage = 0;
  removeCurrentPage();
  pgCheck("the last page cannot be removed", pageCount == 1, str(pageCount));
}

void pagesTestCutArea() {
  println(" cut area");
  float oldX = patX_px, oldY = patY_px, oldRot = patRotation;
  patX_px = 10 * MM_current;
  patY_px = 20 * MM_current;
  patRotation = 0;
  float mm = MM_current;
  PVector bbox = new PVector(105 * mm, 55 * mm, 0);  // a 100 x 50 mm template plus its gap

  pgCheck("a template inside the area passes",
          !copyOutsideCutArea(new PVector(0, 0), bbox, 0), "");
  pgCheck("the padding gap does not count",
          !copyOutsideCutArea(new PVector((VINYL_W - 111) * mm, 0), bbox, 0), "");
  pgCheck("past the right edge is caught",
          copyOutsideCutArea(new PVector((VINYL_W - 105) * mm, 0), bbox, 0), "");
  pgCheck("past the bottom edge is caught",
          copyOutsideCutArea(new PVector(0, (VINYL_H - 65) * mm), bbox, 0), "");
  pgCheck("a tab above the page is caught",
          copyOutsideCutArea(new PVector(0, 0), bbox, -25 * mm), "");
  patRotation = 90;
  pgCheck("rotation is accounted for",
          copyOutsideCutArea(new PVector(0, 0), bbox, 0), "");

  patX_px = oldX;
  patY_px = oldY;
  patRotation = oldRot;
}

void pagesTestOverview() {
  println(" overview");
  float w = width - LEFT_SIDEBAR_WIDTH;
  float h = height - TOOLBAR_HEIGHT - PAGE_BAR_H - BOTTOM_EXPORT_HEIGHT;
  boolean fits = true, apart = true;
  for (int n = 1; n <= 12; n++) {
    float[] grid = overviewGrid(n, w, h);
    float[][] rects = new float[n][];
    for (int p = 0; p < n; p++) {
      float[] r = overviewPageRect(p, grid);
      rects[p] = r;
      if (r[0] < LEFT_SIDEBAR_WIDTH || r[0] + r[2] > width ||
          r[1] < TOOLBAR_HEIGHT + PAGE_BAR_H ||
          r[1] + r[3] > height - BOTTOM_EXPORT_HEIGHT) fits = false;
      for (int q = 0; q < p; q++) {
        float[] o = rects[q];
        if (r[0] < o[0] + o[2] && o[0] < r[0] + r[2] &&
            r[1] < o[1] + o[3] && o[1] < r[1] + r[3]) apart = false;
      }
    }
  }
  pgCheck("every sheet stays on the canvas, 1 to 12 pages", fits, "");
  pgCheck("no two sheets overlap, 1 to 12 pages", apart, "");
  pgCheck("one page is not enlarged", overviewGrid(1, w, h)[2] <= SCREEN_SCALE, "");
  pgCheck("two pages sit side by side", overviewGrid(2, w, h)[0] == 2, str(overviewGrid(2, w, h)[0]));

  pgReset();
  float[] r = overviewPageRect(3, overviewGridNow());
  pgCheck("a click finds the sheet under it", overviewPageAt(r[0] + 5, r[1] + 5) == 3, "");
  pgCheck("a click between sheets finds nothing", overviewPageAt(r[0] - 5, r[1] - 5) == -1, "");
  pgCheck("a page with templates is not empty", !pageIsEmpty(1), "");
  pgCheck("a page without templates is empty", pageIsEmpty(2), "");

  pageOverview = true;
  openPage(3);
  pgCheck("opening a sheet leaves the overview", !pageOverview && currentPage == 3, "");
}

void pagesTestOverviewDrag() {
  println(" dragging in the overview");
  pgReset();
  for (ShapeSpec s : shapes) {
    s.cachedBBox = new PVector(105 * MM_current, 55 * MM_current, 0);
    s.cachedBBoxTop = 0;
    s.repPositions = new PVector[s.nRep];
    for (int i = 0; i < s.nRep; i++) s.repPositions[i] = new PVector(0, 0);
  }

  float[] grid = overviewGridNow();
  PVector wanted = new PVector(40, 30);
  float[] on = pgScreenOn(3, 20, 10, grid);
  PVector back = screenToPatternMM(on[0], on[1], overviewPageRect(3, grid)[0],
                                   overviewPageRect(3, grid)[1], grid[2]);
  pgCheck("screen to sheet mm round-trips", abs(back.x - 20) < 0.01 && abs(back.y - 10) < 0.01,
          back.x + ", " + back.y);

  int[] hit = pickShapeAt(new PVector(20, 10), 3);
  pgCheck("a pick finds the template on that sheet", hit[0] == 2 && hit[1] == 0, hit[0] + "/" + hit[1]);
  pgCheck("a pick ignores the other sheets", pickShapeAt(new PVector(20, 10), 2)[0] == -1, "");
  pgCheck("a pick misses bare paper", pickShapeAt(new PVector(200, 150), 3)[0] == -1, "");

  // Press 20, 10 mm into the template on page 4, drop it with that point at 60, 40 on page 3.
  pageOverview = true;
  _pageBarDrawn = true;
  pgPointer(on);
  pgCheck("a press on a template is handled", handleOverviewClick() && ovDragging, "");
  pgCheck("the press selects the template", selectedShapeIdx == 2 && selectedRepIdx == 0, "");

  pgPointer(new float[]{ on[0] + 2, on[1] });
  dragCopyInOverview();
  pgCheck("a tiny movement is not a drag yet", !ovDragMoved, "");

  float[] gap = overviewPageRect(2, grid);
  pgPointer(new float[]{ gap[0] - OV_GAP / 2, gap[1] + 5 });
  dragCopyInOverview();
  pgCheck("the gap between sheets leaves the page alone", repPage(shapes.get(2), 0) == 3, "");

  pgPointer(pgScreenOn(2, 60, 40, grid));
  dragCopyInOverview();
  endOverviewDrag();
  mouseReleased();
  ShapeSpec moved = shapes.get(2);
  pgCheck("the drop moves the template to that sheet", repPage(moved, 0) == 2, str(repPage(moved, 0)));
  pgCheck("it lands where it was dropped", moved.repPositions[0].dist(wanted) < 0.5,
          moved.repPositions[0].toString());
  pgCheck("a drop keeps the overview open", pageOverview, "");
  pgCheck("the page in view follows the drop", currentPage == 2, str(currentPage));
  pgCheck("the drag state is cleared", !ovDragging && draggedShapeIdx == -1, "");

  pgPointer(pgScreenOn(1, 20, 10, overviewGridNow()));
  handleOverviewClick();
  mouseReleased();
  pgCheck("a click on a template opens its sheet", !pageOverview && currentPage == 1, str(currentPage));
  pgCheck("a click does not move the template", shapes.get(1).repPositions[1].mag() == 0, "");

  pageOverview = true;
  pgPointer(pgScreenOn(4, 200, 150, overviewGridNow()));
  handleOverviewClick();
  pgCheck("a click on bare paper opens the sheet", !pageOverview && currentPage == 4, str(currentPage));
  pgCheck("bare paper starts no drag", !ovDragging, "");
}

// Screen position of a point given in pattern mm on a sheet.
float[] pgScreenOn(int page, float xMM, float yMM, float[] grid) {
  float[] r = overviewPageRect(page, grid);
  return new float[]{ r[0] + (patX_px + xMM * MM_current) * grid[2],
                      r[1] + (patY_px + yMM * MM_current) * grid[2] };
}

void pgPointer(float[] p) {
  mouseX = round(p[0]);
  mouseY = round(p[1]);
}
