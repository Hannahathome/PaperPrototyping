////----------------------------------------------------------------------
//// all the tools needed for the printing and cutting of the outputted files
////------------------------------------------------------------------------------------

void drawCalibCrosses() {
  line(10*MM, 8*MM, 10*MM, 12*MM);
  line(8*MM, 10*MM, 12*MM, 10*MM);
  line(widthA4_C-10*MM, 8*MM, widthA4_C-10*MM, 12*MM);
  line(widthA4_C-8*MM, 10*MM, widthA4_C-12*MM, 10*MM);
  line(10*MM, heightA4_C-8*MM, 10*MM, heightA4_C-12*MM);
  line(8*MM, heightA4_C-10*MM, 12*MM, heightA4_C-10*MM);
  line(widthA4_C-10*MM, heightA4_C-8*MM, widthA4_C-10*MM, heightA4_C-12*MM);
  line(widthA4_C-8*MM, heightA4_C-10*MM, widthA4_C-12*MM, heightA4_C-10*MM);
}

void drawCalibCrosses_V() {
  line(10*MM_V, 0*MM_V, 10*MM_V, 20*MM_V);
  line(0*MM_V, 10*MM_V, 20*MM_V, 10*MM_V);
  line(widthA4_V-10*MM_V, 0*MM_V, widthA4_V-10*MM_V, 20*MM_V);
  line(widthA4_V-0*MM_V, 10*MM_V, widthA4_V-20*MM_V, 10*MM_V);
  line(10*MM_V, heightA4_V-0*MM_V, 10*MM_V, heightA4_V-20*MM_V);
  line(0*MM_V, heightA4_V-10*MM_V, 20*MM_V, heightA4_V-10*MM_V);
  line(widthA4_V-10*MM_V, heightA4_V-0*MM_V, widthA4_V-10*MM_V, heightA4_V-20*MM_V);
  line(widthA4_V-0*MM_V, heightA4_V-10*MM_V, widthA4_V-20*MM_V, heightA4_V-10*MM_V);
}

void drawAnchors_V() {
  point(0, 0);
  point(widthA4_V, 0);
  point(0, heightA4_V);
  point(widthA4_V, heightA4_V);
}


void drawFrontPDF() {
  String baseName = (uiExportFilename != null && !uiExportFilename.trim().isEmpty()) ? uiExportFilename : "result";
  pdfFilename = "output/" + baseName + "_" + timestamp + ".pdf";

  // CRITICAL: Call setParams BEFORE beginRecord to load images outside PDF context
  setParams(false);

  // --- ASSEMBLY MODE: simple vector-only PDF export ---
  if (assemblyMode && activeAssembly != null) {
    pdf = (PGraphicsPDF) createGraphics((int)widthA4, (int)heightA4, PDF, pdfFilename);
    beginRecord(pdf);
    pushStyle();
    stroke(0);
    strokeWeight(0.5);
    pushMatrix();
    drawCalibCrosses();
    translate(patX_px, patY_px);
    rotate(radians(patRotation));
    drawAssemblyPlan(activeAssembly);
    popMatrix();
    popStyle();
    endRecord();
    println("Assembly PDF saved:", pdfFilename);
    return;
  }

  // PDF canvas at 72 DPI (standard A4: 842x595 px = 297x210 mm)
  pdf = (PGraphicsPDF) createGraphics((int)widthA4, (int)heightA4, PDF, pdfFilename);
  beginRecord(pdf);
  pushStyle();
  stroke(0);

  // One buffer for every page: at A1 it is too large to allocate once per sheet.
  PGraphics art = createGraphics((int)widthA4_render, (int)heightA4_render, P2D);
  int[] pages = usedPages();
  for (int pi = 0; pi < pages.length; pi++) {
    // nextPage() resets the recorder's matrix, so nothing may be pushed across this call.
    if (pi > 0) pdf.nextPage();
    strokeWeight(1);
    renderPageTextures(art, pages[pi]);

    // Composite high-res texture into PDF, scaled down to 72 DPI coordinate space
    image(art, 0, 0, widthA4, heightA4);

    // VECTOR LAYER (72 DPI - native PDF resolution)
    pushMatrix();
    drawCalibCrosses();
    strokeWeight(0.5);  // Thinner lines for fold/cut outlines
    drawPageTemplates(pages[pi], false);
    popMatrix();
  }
  lastExportPageCount = pages.length;

  popStyle();
  endRecord();
  println("Print File saved:", pdfFilename);
}

// HIGH-RESOLUTION TEXTURE LAYER (300 DPI): redraws art with one page's textures.
void renderPageTextures(PGraphics art, int page) {
  // Save original values
  float oldMM = MM;
  float oldWidthA4 = widthA4;
  float oldHeightA4 = heightA4;

  // Temporarily switch to 300 DPI for texture rendering
  MM = TEXTURE_DPI / 25.4;  // 11.811 px/mm at 300 DPI
  widthA4 = PRINT_W * MM;
  heightA4 = PRINT_H * MM;

  // Recalculate all pixel coordinates for 300 DPI
  // Images are already loaded, so this won't corrupt PDF
  // We just need to recalculate the *_px dependent variables
  setParams(false);
  
  // Render textures at 3508x2480 px
  art.beginDraw();
  art.smooth(8); // Enable high-quality anti-aliasing
  art.background(0, 0); // transparent background
  int _texRunIdx = 0;
  for (int _tsi = 0; _tsi < shapes.size(); _tsi++) {
    ShapeSpec _ts = shapes.get(_tsi);
    loadGlobalsFrom(_ts);
    setParams(false);
    PVector bboxTex = getTemplateBBox();
    for (int rep = 0; rep < _ts.nRep; rep++) {
      if (repPage(_ts, rep) != page) continue;
      art.pushMatrix();
      PVector repOff = repOffset(_ts, rep, bboxTex);
      art.translate(repOff.x, repOff.y);
      drawTexturesForPrinting(art);  // Draws at 300 DPI coordinates
      art.popMatrix();
      _texRunIdx++;
    }
  }
  // Restore 72 DPI globals
  art.endDraw();
  loadGlobalsFrom(shapes.get(selectedShapeIdx));
  
  // Restore 72 DPI for vector elements
  MM = oldMM;
  widthA4 = oldWidthA4;
  heightA4 = oldHeightA4;
  setParams(false);  // Recalculate back to 72 DPI
}

// Draws one page's templates at the current scale: drawPlan(true) artwork for the print
// layer, drawPlan(false) outlines when cut is set. Shared so the PDF and SVG pages cannot
// drift apart. Caller owns the matrix.
void drawPageTemplates(int page, boolean cut) {
  translate(patX_px, patY_px);
  rotate(radians(patRotation));
  _baseDrawnThisFrame = !basePlateOnPage(page);   // base plate draws once, on its own page
  int autoIdx = (shapes.size() > 0) ? shapes.get(0).markerStartIndex : Start_Index;
  for (int si = 0; si < shapes.size(); si++) {
    ShapeSpec s = shapes.get(si);
    loadGlobalsFrom(s);
    setParams(cut);
    _drawingShapeIdx = si;   // tells drawConnectionSlits() whose lid it is drawing
    PVector bbox = getTemplateBBox();
    for (int rep = 0; rep < s.nRep; rep++) {
      if (autoMarkerIDs) { Start_Index = autoIdx; autoIdx += max(1, markerGrid*markerGrid); }
      else Start_Index = s.markerStartIndex + rep;
      if (repPage(s, rep) != page) continue;  // after the ID, see Pages.pde
      pushMatrix();
      PVector repOff = repOffset(s, rep, bbox);
      translate(repOff.x, repOff.y);
      drawPlan(!cut);
      popMatrix();
    }
  }
  _drawingShapeIdx = -1;
  // Restore selected shape globals
  loadGlobalsFrom(shapes.get(selectedShapeIdx));
  setParams(cut);
}

void saveFrontFold() {
  bExportingCutFile = true;  // suppress solid color fill in SVG output
  String baseName = (uiExportFilename != null && !uiExportFilename.trim().isEmpty()) ? uiExportFilename : "result";
  svgFilename = "output/" + baseName + "_fold_" + timestamp + ".svg";

  // --- ASSEMBLY MODE: vector-only SVG cut export ---
  if (assemblyMode && activeAssembly != null) {
    setParams(true);
    svg = createGraphics((int)widthA4_V, (int)heightA4_V, SVG, svgFilename);
    beginRecord(svg);
    pushStyle();
    stroke(0);
    strokeWeight(0.5);
    pushMatrix();
    translate(offW_V_F, offH_V_F);
    translate(patX_px, patY_px);
    rotate(radians(patRotation));
    drawAssemblyPlan(activeAssembly);
    popMatrix();
    popStyle();
    endRecord();
    fixSVGPhysicalDimensions(svgFilename, VINYL_W, VINYL_H, widthA4_V, heightA4_V);
    println("Assembly cut file saved:", svgFilename);
    bExportingCutFile = false;
    return;
  }

  // SVG has no pages, so each sheet gets its own file. The numbers follow the PDF: fold_p2
  // cuts PDF page 2, whatever page it was in the sketch.
  int[] pages = usedPages();
  for (int pi = 0; pi < pages.length; pi++) {
    if (pages.length > 1) {
      svgFilename = "output/" + baseName + "_fold_p" + (pi + 1) + "_" + timestamp + ".svg";
    }
    // SVG canvas at vinyl DPI — physical dimensions declared via fixSVGPhysicalDimensions
    svg = createGraphics((int)widthA4_V, (int)heightA4_V, SVG, svgFilename);
    beginRecord(svg);
    pushStyle();
    stroke(0);
    strokeWeight(0.5);  // Thinner lines for vinyl cutting

    setParams(true);  // Ensure patX_px/patY_px use vinyl DPI before translate
    pushMatrix();
    translate(offW_V_F, offH_V_F); //optional
    drawPageTemplates(pages[pi], true);
    popMatrix();

    popStyle();
    endRecord();
    fixSVGPhysicalDimensions(svgFilename, VINYL_W, VINYL_H, widthA4_V, heightA4_V);
    println("Print File saved:", svgFilename);
  }
  bExportingCutFile = false;  // restore color fill for screen
}

// One calibration file however many pages: the crosses are the same on every sheet.
void saveFrontCalib() {
  String baseName = (uiExportFilename != null && !uiExportFilename.trim().isEmpty()) ? uiExportFilename : "result";
  svgFilename = "output/" + baseName + "_calib_" + timestamp + ".svg";
  // SVG canvas at vinyl DPI — physical dimensions declared via fixSVGPhysicalDimensions
  svg = createGraphics((int)widthA4_V, (int)heightA4_V, SVG, svgFilename);
  beginRecord(svg);
  pushStyle();
  stroke(0);
  strokeWeight(1);

  pushMatrix();
  translate(offW_V_F, offH_V_F);//optional
  drawCalibCrosses_V();
  popMatrix();

  popStyle();
  endRecord();
  fixSVGPhysicalDimensions(svgFilename, VINYL_W, VINYL_H, widthA4_V, heightA4_V);
  println("Print File saved:", svgFilename);
}

// Post-processes an exported SVG to replace unitless pixel dimensions with
// explicit physical mm dimensions and a viewBox. Without this, vinyl cutter
// software guesses the DPI and gets the wrong physical size.
void fixSVGPhysicalDimensions(String filename, float physW_mm, float physH_mm, float canvasW_px, float canvasH_px) {
  String[] lines = loadStrings(filename);
  if (lines == null || lines.length == 0) {
    println("[SVG Fix] Could not read: " + filename);
    return;
  }
  String viewBox = "viewBox=\"0 0 " + (int)canvasW_px + " " + (int)canvasH_px + "\"";
  String wAttr = "width=\"" + (int)physW_mm + "mm\"";
  String hAttr = "height=\"" + (int)physH_mm + "mm\"";
  boolean fixed = false;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains("width=\"") && lines[i].contains("height=\"")) {
      lines[i] = lines[i].replaceAll("width=\"[0-9.]+\"", wAttr);
      lines[i] = lines[i].replaceAll("height=\"[0-9.]+\"", hAttr);
      if (!lines[i].contains("viewBox")) {
        lines[i] = lines[i].replace("<svg ", "<svg " + viewBox + " ");
      }
      fixed = true;
      break;
    }
  }
  if (fixed) {
    saveStrings(filename, lines);
    println("[SVG Fix] " + (int)physW_mm + "mm x " + (int)physH_mm + "mm, viewBox 0 0 " + (int)canvasW_px + " " + (int)canvasH_px);
  }
}

//--------------------------explaining the code ---------------------
//adding an example to make it easier to understand what is going on for new users and for me when i do not work on this at the moment
/*
drawFrontPDF()
 --> Sets the file name: pdfFilename = "output/result_"+timestamp+".pdf".
 --> Creates the PDF page at A4 size (595x842 points): createGraphics(pdfWidth, pdfHeight, PDF, pdfFilename)
 --> Starts recording to that PDF: beginRecord(pdf)
 --> Scales content from high-DPI rendering (300 DPI) to PDF page size: scale(...)
 --> Sets line style: pushStyle(); stroke(0); strokeWeight(1);
 --> Positions drawing stack: pushMatrix();
 --> Draws small cross marks on the page: drawCalibCrosses()
 --> Moves the whole plan by your pattern offset: translate(patX_px, patY_px)
 --> Draws the plan (and asks to include images): drawPlan(true)
 --> Closes that positioning: popMatrix();
 --> Restores style: popStyle();
 --> Finishes and saves the PDF: endRecord(); println("Print File saved:", pdfFilename);

 With more than one page, everything from the crosses to the plan repeats per page in usedPages(),
 with pdf.nextPage() between them. saveFrontFold() writes one SVG per page the same way.
 */
