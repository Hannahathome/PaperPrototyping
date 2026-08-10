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
  strokeWeight(1);

  // HIGH-RESOLUTION TEXTURE LAYER (300 DPI)
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
  PGraphics art = createGraphics((int)widthA4_render, (int)heightA4_render, P2D);
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
      art.pushMatrix();
      if (freePlacementMode && _ts.repPositions != null && rep < _ts.repPositions.length) {
        art.translate(_ts.repPositions[rep].x * MM_current, _ts.repPositions[rep].y * MM_current);
      } else {
        art.translate((rep % 2) * bboxTex.x, (rep / 2) * bboxTex.y);
      }
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
  
  // Composite high-res texture into PDF, scaled down to 72 DPI coordinate space
  image(art, 0, 0, widthA4, heightA4);

  // VECTOR LAYER (72 DPI - native PDF resolution)
  pushMatrix();
  drawCalibCrosses();
  strokeWeight(0.5);  // Thinner lines for fold/cut outlines
  translate(patX_px, patY_px);
  rotate(radians(patRotation));
  _baseDrawnThisFrame = false;   // base plate draws once, during the first shape
  int _pdfAutoIdx = (shapes.size() > 0) ? shapes.get(0).markerStartIndex : Start_Index;
  for (int _psi = 0; _psi < shapes.size(); _psi++) {
    ShapeSpec _ps = shapes.get(_psi);
    loadGlobalsFrom(_ps);
    setParams(false);
    PVector bboxPDF = getTemplateBBox();
    for (int rep = 0; rep < _ps.nRep; rep++) {
      if (autoMarkerIDs) { Start_Index = _pdfAutoIdx; _pdfAutoIdx += max(1, markerGrid*markerGrid); }
      else Start_Index = _ps.markerStartIndex + rep;
      pushMatrix();
      if (freePlacementMode && _ps.repPositions != null && rep < _ps.repPositions.length) {
        translate(_ps.repPositions[rep].x * MM_current, _ps.repPositions[rep].y * MM_current);
      } else {
        translate((rep % 2) * bboxPDF.x, (rep / 2) * bboxPDF.y);
      }
      drawPlan(true);
      popMatrix();
    }
  }
  // Restore selected shape globals
  loadGlobalsFrom(shapes.get(selectedShapeIdx));
  setParams(false);
  popMatrix();

  popStyle();
  endRecord();
  println("Print File saved:", pdfFilename);
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

  // SVG canvas at vinyl DPI — physical dimensions declared via fixSVGPhysicalDimensions
  svg = createGraphics((int)widthA4_V, (int)heightA4_V, SVG, svgFilename);
  beginRecord(svg);
  pushStyle();
  stroke(0);
  strokeWeight(0.5);  // Thinner lines for vinyl cutting

  setParams(true);  // Ensure patX_px/patY_px use vinyl DPI before translate
  pushMatrix();
  translate(offW_V_F, offH_V_F); //optional
  translate(patX_px, patY_px);
  rotate(radians(patRotation));
  _baseDrawnThisFrame = false;   // base plate draws once, during the first shape
  int _svgAutoIdx = (shapes.size() > 0) ? shapes.get(0).markerStartIndex : Start_Index;
  for (int _fsi = 0; _fsi < shapes.size(); _fsi++) {
    ShapeSpec _fs = shapes.get(_fsi);
    loadGlobalsFrom(_fs);
    setParams(true);
    PVector bboxSVG = getTemplateBBox();
    for (int rep = 0; rep < _fs.nRep; rep++) {
      if (autoMarkerIDs) { Start_Index = _svgAutoIdx; _svgAutoIdx += max(1, markerGrid*markerGrid); }
      else Start_Index = _fs.markerStartIndex + rep;
      pushMatrix();
      if (freePlacementMode && _fs.repPositions != null && rep < _fs.repPositions.length) {
        translate(_fs.repPositions[rep].x * MM_current, _fs.repPositions[rep].y * MM_current);
      } else {
        translate((rep % 2) * bboxSVG.x, (rep / 2) * bboxSVG.y);
      }
      drawPlan(false);
      popMatrix();
    }
  }
  // Restore selected shape globals
  loadGlobalsFrom(shapes.get(selectedShapeIdx));
  setParams(true);
  popMatrix();

  popStyle();
  endRecord();
  fixSVGPhysicalDimensions(svgFilename, VINYL_W, VINYL_H, widthA4_V, heightA4_V);
  println("Print File saved:", svgFilename);
  bExportingCutFile = false;  // restore color fill for screen
}

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
 */
