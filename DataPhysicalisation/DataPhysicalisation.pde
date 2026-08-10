// ── Required libraries (install via Sketch → Import Library → Manage Libraries)
// • ControlP5  by Andreas Schlegel
// • PeasyCam   by Jonathan Feinberg
// ─────────────────────────────────────────────────────────────────────────────
import controlP5.*;
import peasy.*;

// ── Libraries ────────────────────────────────────────────────────────────────
ControlP5 cp5;
PeasyCam  camera;

// ── Data ──────────────────────────────────────────────────────────────────────
Table    csvTable;
String[] columnNames = new String[0];

// ── Column → dimension mappings  (-1 = not assigned) ─────────────────────────
int mapLabel    = -1;
int mapHeight   = -1;
int mapDiameter = -1;   // poly mode + bar-linked mode
int mapWidth    = -1;   // bar-separate mode
int mapDepth    = -1;   // bar-separate mode
int mapSides    = -1;
int mapColor    = -1;

// ── Visual constants ──────────────────────────────────────────────────────────
float scaleH       = 100;   // max polyhedron height in world units  (adjustable)
float minHeightPct =  20;   // minimum bar height as % of scaleH   (0–100)
float scaleDiam =  20;   // max polyhedron diameter               (adjustable)
float minDiamPct   =  20;   // minimum diameter as % of scaleDiam  (0–100)
int   scaleSides =  30;  // max number of sides                   (adjustable)
final int   MIN_SIDES = 3;    // triangle prism minimum
final int   DEF_SIDES = 6;    // default sides when no column assigned
final float BAR_GAP   = 20;   // gap between shapes
final float SHAPE_SLOT = 120; // fixed grid slot per shape (spacing); shapes grow inside this
final float GND_Y    = 150;   // Y of the ground plane (Processing Y grows down)
final int   SIDE_W   = 260;   // sidebar pixel width

// ── Export feedback ───────────────────────────────────────────────────────────
String exportMsg   = "";
int    msgTimer    = 0;
final int MSG_DUR  = 150;   // frames to show feedback message
String exportName  = "export";   // filename (without .json) for JSON export
boolean suppressEvents = false;   // prevent recursive controlEvent loops

// ── Visible bar count ───────────────────────────────────────────────────────────
int    visibleBars    = 0;    // 0 = show all (before CSV loaded)
Slider barCountSlider;

// ── Orientation gizmo ────────────────────────────────────────────────────────
PGraphics gizmo;
final int GIZMO_SIZE = 84;

// ── Mode toggle ──────────────────────────────────────────────────────────────
boolean polyMode  = false;   // true = polyhedra prisms, false = boxes (bars)
boolean barLinked = true;    // bar mode: true = diameter, false = separate W+D
boolean view2D    = true;    // bar mode: true = flat 2D chart, false = 3D scene
boolean trueSize  = false;   // true = normalize from zero (preserve absolute ratios)

// ── 2D chart pan / zoom ───────────────────────────────────────────────────
float view2DZoom  = 1.5;
float view2DPanX  = 0;
float view2DPanY  = 100;   // world-space Y centre of the bar area (GND_Y - scaleH/2)
boolean pan2DActive = false;
float   pan2DLastX, pan2DLastY;
String  thresholdStr      = "";       // user-typed comma-separated threshold values
float[] parsedThresholds = new float[0]; // sorted actual data values

// ── Dropdown references ───────────────────────────────────────────────────────
// (replaced by prev/next button selectors — no ScrollableList references needed)

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
  size(1600, 980, P3D);
  surface.setTitle("3D Polyhedra Chart");

  camera = new PeasyCam(this, 0, 0, 0, 800);
  camera.setMinimumDistance(100);
  camera.setMaximumDistance(3000);
  camera.setSuppressRollRotationMode();  // prevent rolling/tilting sideways
  camera.setYawRotationMode();           // mouse drag only rotates horizontally — no pitching below the plane

  cp5 = new ControlP5(this);
  buildUI();
  cp5.setAutoDraw(false);   // draw manually inside beginHUD so UI stays locked to screen

  gizmo = createGraphics(GIZMO_SIZE, GIZMO_SIZE, P3D);
}

void buildUI() {
  int sx   = 10, sy = 10;
  int sw   = SIDE_W - 20;
  int aw   = 26;    // arrow button width
  int NB_W = 52;    // numberbox width for precise typing
  int slW  = sw - NB_W - 4;  // slider width (leaves room for numberbox)

  cp5.addButton("loadCSV")
     .setLabel("Load CSV")
     .setPosition(sx, sy)
     .setSize(sw, 32)
     .setColorBackground(color(30, 130, 70))
     .setColorActive(color(40, 170, 90));
  sy += 42;

  cp5.addButton("toggleMode")
     .setLabel(polyMode ? "MODE: POLYHEDRA" : "MODE: BARS")
     .setPosition(sx, sy)
     .setSize(sw, 32)
     .setColorBackground(polyMode ? color(90, 40, 160) : color(30, 80, 190))
     .setColorActive(polyMode ? color(120, 60, 200) : color(50, 110, 230));
  sy += 36;

  cp5.addButton("toggleView2D")
     .setLabel(view2D ? "VIEW: 2D" : "VIEW: 3D")
     .setPosition(sx, sy)
     .setSize(sw, 26)
     .setColorBackground(color(60, 60, 60))
     .setColorActive(color(90, 90, 90));
  sy += 30;

  cp5.addButton("toggleTrueSize")
     .setLabel(trueSize ? "SCALE: TRUE SIZE" : "SCALE: RELATIVE")
     .setPosition(sx, sy)
     .setSize(sw, 26)
     .setColorBackground(color(60, 60, 60))
     .setColorActive(color(90, 90, 90));
  sy += 34;

  int rowH = 26;   // button row height
  int gap  = 12;   // gap after each section

  // ─ LABEL ─────────────────────────────────────────────────────────────────
  cp5.addTextlabel("lbl0").setText("LABEL COLUMN").setPosition(sx, sy); sy += 16;
  cp5.addButton("prevLabel").setLabel("<").setPosition(sx,        sy).setSize(aw, rowH);
  cp5.addTextlabel("curLabel").setText("(load CSV)").setPosition(sx+aw+2, sy+6);
  cp5.addButton("nextLabel").setLabel(">").setPosition(sx+sw-aw,  sy).setSize(aw, rowH);
  sy += rowH + gap;

  // ─ HEIGHT ────────────────────────────────────────────────────────────────
  cp5.addTextlabel("lbl1").setText("HEIGHT COLUMN").setPosition(sx, sy); sy += 16;
  cp5.addTextlabel("lblScaleH").setText("Max output height (mm)").setPosition(sx, sy).setColorValue(0xFFAAAAAA); sy += 13;
  cp5.addSlider("scaleH").setLabel("").setPosition(sx, sy).setSize(slW, 18)
     .setRange(10, 200).setValue(scaleH).setDecimalPrecision(0);
  cp5.addNumberbox("nb_scaleH").setLabel("").setPosition(sx+slW+4, sy).setSize(NB_W, 18)
     .setRange(10, 200).setValue(scaleH).setDecimalPrecision(0).setScrollSensitivity(1);
  sy += 22;
  cp5.addTextlabel("lblMinH").setText("Min height — % of max (0 = no floor)").setPosition(sx, sy).setColorValue(0xFFAAAAAA); sy += 13;
  cp5.addSlider("minHeightPct").setLabel("").setPosition(sx, sy).setSize(slW, 18)
     .setRange(0, 80).setValue(minHeightPct).setDecimalPrecision(0);
  cp5.addNumberbox("nb_minHeightPct").setLabel("").setPosition(sx+slW+4, sy).setSize(NB_W, 18)
     .setRange(0, 80).setValue(minHeightPct).setDecimalPrecision(0).setScrollSensitivity(1);
  sy += 22;
  cp5.addButton("prevHeight").setLabel("<").setPosition(sx,        sy).setSize(aw, rowH);
  cp5.addTextlabel("curHeight").setText("(load CSV)").setPosition(sx+aw+2, sy+6);
  cp5.addButton("nextHeight").setLabel(">").setPosition(sx+sw-aw,  sy).setSize(aw, rowH);
  sy += rowH + gap;

  // ─ DIAMETER ──────────────────────────────────────────────────────────────
  cp5.addTextlabel("lbl2").setText("DIAMETER COLUMN").setPosition(sx, sy); sy += 16;
  cp5.addTextlabel("lblScaleDiam").setText("Max output width/diameter (mm)").setPosition(sx, sy).setColorValue(0xFFAAAAAA); sy += 13;
  cp5.addSlider("scaleDiam").setLabel("").setPosition(sx, sy).setSize(slW, 18)
     .setRange(1, 100).setValue(scaleDiam).setDecimalPrecision(0);
  cp5.addNumberbox("nb_scaleDiam").setLabel("").setPosition(sx+slW+4, sy).setSize(NB_W, 18)
     .setRange(1, 100).setValue(scaleDiam).setDecimalPrecision(0).setScrollSensitivity(1);
  sy += 22;
  cp5.addTextlabel("lblMinDiam").setText("Min diameter — % of max (0 = no floor)").setPosition(sx, sy).setColorValue(0xFFAAAAAA); sy += 13;
  cp5.addSlider("minDiamPct").setLabel("").setPosition(sx, sy).setSize(slW, 18)
     .setRange(0, 80).setValue(minDiamPct).setDecimalPrecision(0);
  cp5.addNumberbox("nb_minDiamPct").setLabel("").setPosition(sx+slW+4, sy).setSize(NB_W, 18)
     .setRange(0, 80).setValue(minDiamPct).setDecimalPrecision(0).setScrollSensitivity(1);
  sy += 22;
  cp5.addButton("prevDiameter").setLabel("<").setPosition(sx,        sy).setSize(aw, rowH);
  cp5.addTextlabel("curDiameter").setText("(load CSV)").setPosition(sx+aw+2, sy+6);
  cp5.addButton("nextDiameter").setLabel(">").setPosition(sx+sw-aw,  sy).setSize(aw, rowH);
  sy += rowH + gap;

  // ─ SIDES ─────────────────────────────────────────────────────────────────
  cp5.addTextlabel("lbl3").setText("SIDES COLUMN").setPosition(sx, sy); sy += 16;
  cp5.addSlider("scaleSides").setLabel("").setPosition(sx, sy).setSize(slW, 18)
     .setRange(3, 30).setValue(scaleSides).setDecimalPrecision(0);
  cp5.addNumberbox("nb_scaleSides").setLabel("").setPosition(sx+slW+4, sy).setSize(NB_W, 18)
     .setRange(3, 30).setValue(scaleSides).setDecimalPrecision(0).setScrollSensitivity(1);
  sy += 22;
  cp5.addButton("prevSides").setLabel("<").setPosition(sx,        sy).setSize(aw, rowH);
  cp5.addTextlabel("curSides").setText("(load CSV)").setPosition(sx+aw+2, sy+6);
  cp5.addButton("nextSides").setLabel(">").setPosition(sx+sw-aw,  sy).setSize(aw, rowH);
  sy += rowH + gap;

  // ─ COLOR ─────────────────────────────────────────────────────────────────
  cp5.addTextlabel("lbl4").setText("COLOR COLUMN").setPosition(sx, sy); sy += 16;
  cp5.addButton("prevColor").setLabel("<").setPosition(sx,        sy).setSize(aw, rowH);
  cp5.addTextlabel("curColor").setText("(load CSV)").setPosition(sx+aw+2, sy+6);
  cp5.addButton("nextColor").setLabel(">").setPosition(sx+sw-aw,  sy).setSize(aw, rowH);
  sy += rowH + 4;
  cp5.addTextlabel("lblThresh").setText("COLOR THRESHOLDS").setPosition(sx, sy); sy += 15;
  cp5.addTextlabel("lblThreshHint").setText("(enter values, comma-separated)").setPosition(sx, sy).setColorValue(0xFFAAAAAA); sy += 15;
  cp5.addTextfield("thresholds").setLabel("").setPosition(sx, sy).setSize(sw, 22)
     .setAutoClear(false).setText(""); sy += gap + 30;

  // ─ SHAPES TO SHOW ─────────────────────────────────────────────────────────
  cp5.addTextlabel("lblCount").setText("SHAPES TO SHOW").setPosition(sx, sy); sy += 16;
  barCountSlider = cp5.addSlider("barCount")
                      .setLabel("")
                      .setPosition(sx, sy)
                      .setSize(slW, 18)
                      .setRange(1, 10)
                      .setValue(10)
                      .setDecimalPrecision(0);
  cp5.addNumberbox("nb_barCount").setLabel("").setPosition(sx+slW+4, sy).setSize(NB_W, 18)
     .setRange(1, 10).setValue(10).setDecimalPrecision(0).setScrollSensitivity(1);
  sy += 48;

  // ─ Preset view buttons ────────────────────────────────────────────────────
  cp5.addTextlabel("lblViews").setText("PRESET VIEWS").setPosition(sx, sy); sy += 16;
  int bw = (sw - 4) / 2;
  cp5.addButton("snapFront").setLabel("Front")    .setPosition(sx,        sy).setSize(bw, 26);
  cp5.addButton("snapTop")  .setLabel("Top")      .setPosition(sx+bw+4,   sy).setSize(bw, 26); sy += 30;
  cp5.addButton("snapSide") .setLabel("Side")     .setPosition(sx,        sy).setSize(bw, 26);
  cp5.addButton("snapIso")  .setLabel("Isometric").setPosition(sx+bw+4,   sy).setSize(bw, 26); sy += 30;
  cp5.addButton("resetView").setLabel("Reset View").setPosition(sx,       sy).setSize(sw, 26);

  // ─ Bottom-left toggles ────────────────────────────────────────────────────
  cp5.addButton("toggleBarSize")
     .setLabel("BAR SIZE: DIAMETER")
     .setPosition(10, height - 112)
     .setSize(sw, 32);

  cp5.addTextfield("exportName")
     .setLabel("Export filename")
     .setPosition(10, height - 72)
     .setSize(sw, 22)
     .setText("export")
     .setAutoClear(false);

  cp5.addButton("exportJSON")
     .setLabel("Export JSON")
     .setPosition(10, height - 42)
     .setSize(sw, 32)
     .setColorBackground(color(30, 130, 70))
     .setColorActive(color(40, 170, 90));

  updateModeVisibility();
}

// ─────────────────────────────────────────────────────────────────────────────
void draw() {
  background(30);

  boolean use2D = view2D && !polyMode;
  camera.setActive(!use2D && !cp5.isMouseOver());

  if (use2D) {
    // Override to a fixed front-facing camera; pan/zoom controlled manually.
    // Shift look-at X so the world origin sits in the centre of the right panel
    // (the area to the right of the sidebar), not behind it.
    float zDist      = 800.0 / view2DZoom;
    float worldPerPx = (2.0 * zDist * tan(PI / 6.0)) / height;  // same scale X & Y
    float sidbarShift = (SIDE_W / 2.0) * worldPerPx;            // world-space offset
    float camX = view2DPanX - sidbarShift;
    camera(camX, view2DPanY, zDist,
           camX, view2DPanY, 0,
           0, 1, 0);
    lights();
    if (csvTable != null && mapHeight >= 0) {
      drawBarsLine();
      drawLabelsLine();
      drawAxesLine();
    }
  } else {
    // 3-D scene
    lights();
    drawGrid();
    if (csvTable != null && mapHeight >= 0) {
      if (polyMode) drawPolyhedra(); else drawBars();
      drawLabels();
      drawAxes();
    }
  }

  // Flat HUD overlay
  camera.beginHUD();
  drawSidebarBg();
  drawFeedback();
  drawRangeLegend();
  if (!use2D) drawGizmo();
  cp5.draw();
  camera.endHUD();
}

// ── Ground grid ───────────────────────────────────────────────────────────────
void drawGrid() {
  pushStyle();
  stroke(70);
  strokeWeight(1);
  noFill();
  int half = 500, step = 50;
  for (int i = -half; i <= half; i += step) {
    line(i, GND_Y, -half, i, GND_Y, half);
    line(-half, GND_Y, i, half, GND_Y, i);
  }
  popStyle();
}

// ── Height axis with tick marks ──────────────────────────────────────────────
void drawAxes() {
  if (csvTable == null || mapHeight < 0) return;

  int   n       = visibleCount();
  int   cols    = max(1, (int) ceil(sqrt(n)));
  float spacing = SHAPE_SLOT + BAR_GAP;
  float startX  = -(cols * spacing - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;
  float axX     = startX - SHAPE_SLOT / 2.0 - 50;

  float[] hVals = getColumnValues(mapHeight);
  float   hMin  = min(hVals), hMax = max(hVals);
  int     ticks = 5;

  pushStyle();
  hint(DISABLE_DEPTH_TEST);

  // Vertical axis line
  stroke(255, 100, 100);
  strokeWeight(1.5);
  line(axX, GND_Y, 0, axX, GND_Y - scaleH, 0);

  // Ticks and value labels
  for (int t = 0; t <= ticks; t++) {
    float frac = t / (float) ticks;
    float wy   = GND_Y - frac * scaleH;
    float val  = hMin + frac * (hMax - hMin);

    stroke(255, 100, 100);
    strokeWeight(1);
    line(axX - 8, wy, 0, axX, wy, 0);

    fill(220, 180, 180);
    noStroke();
    textSize(9);
    textAlign(RIGHT, CENTER);
    pushMatrix();
    translate(axX - 12, wy, 0);
    text(nf(val, 0, 1), 0, 0);
    popMatrix();
  }

  // Column name rotated along axis
  fill(255, 130, 130);
  textSize(10);
  textAlign(CENTER, BOTTOM);
  noStroke();
  pushMatrix();
  translate(axX - 36, GND_Y - scaleH / 2.0, 0);
  rotateZ(-HALF_PI);
  text(columnNames[mapHeight], 0, 0);
  popMatrix();

  hint(ENABLE_DEPTH_TEST);
  popStyle();
}

// ── Diameter / Sides range legend (drawn in HUD) ─────────────────────────────
void drawRangeLegend() {
  if (csvTable == null) return;
  int lx = SIDE_W + 10;
  int ly = height - 56;

  pushStyle();
  fill(170);
  textSize(11);
  textAlign(LEFT, TOP);

  if (mapDiameter >= 0 && isNumericCol(mapDiameter)) {
    float[] vals = getColumnValues(mapDiameter);
    text("Diameter  [" + columnNames[mapDiameter] + "]:  "
         + nf(min(vals), 0, 1) + " – " + nf(max(vals), 0, 1), lx, ly);
    ly += 18;
  }
  if (mapSides >= 0 && isNumericCol(mapSides)) {
    float[] vals = getColumnValues(mapSides);
    text("Sides  [" + columnNames[mapSides] + "]:  "
         + MIN_SIDES + " – " + scaleSides
         + "  (mapped from " + nf(min(vals), 0, 1) + " – " + nf(max(vals), 0, 1) + ")", lx, ly);
    ly += 18;
  }

  // Colour threshold legend (only shown when thresholds are entered)
  if (mapColor >= 0 && isNumericCol(mapColor) && parsedThresholds.length > 0) {
    int nBands = parsedThresholds.length + 1;
    float bandW = min(30, (width - SIDE_W - 30) / (float)nBands - 2);
    text("Color  [" + columnNames[mapColor] + "]:", lx, ly); ly += 14;
    for (int b = 0; b < nBands; b++) {
      color bc = bandColor(b, nBands);
      fill(bc);
      noStroke();
      rect(lx + b * (bandW + 2), ly, bandW, 14);
      fill(170);
      textSize(8);
      String lbl;
      if      (b == 0)           lbl = "< " + nf(parsedThresholds[0], 0, 2);
      else if (b == nBands - 1)  lbl = ">= " + nf(parsedThresholds[b-1], 0, 2);
      else                       lbl = nf(parsedThresholds[b-1], 0, 2) + "-" + nf(parsedThresholds[b], 0, 2);
      text(lbl, lx + b * (bandW + 2), ly + 16);
    }
  }
  popStyle();
}

// ── 2D line view: real 3D bars in a single row ────────────────────────────────
void drawBarsLine() {
  int n = visibleCount();
  float[] hN   = pickNorm(mapHeight);
  float[] dN   = (mapDiameter >= 0) ? pickNorm(mapDiameter) : null;
  float[] wN   = (mapWidth    >= 0) ? pickNorm(mapWidth)    : null;
  float[] dpN  = (mapDepth    >= 0) ? pickNorm(mapDepth)    : null;
  boolean numColor = (mapColor >= 0) && isNumericCol(mapColor);
  float[] cN   = numColor ? normalizeCol(mapColor) : null;
  float[] cRaw = numColor ? getColumnValues(mapColor) : null;
  java.util.HashMap<String, Integer> catMap =
      (!numColor && mapColor >= 0) ? buildCatMap(mapColor) : null;
  int catCount = (catMap != null) ? max(catMap.size(), 1) : 1;

  float spacing = SHAPE_SLOT + BAR_GAP;
  float startX  = -(n * spacing - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;

  for (int i = 0; i < n; i++) {
    float h  = scaledHeight(hN[i]);
    float bx = startX + i * spacing;
    float by = GND_Y - h / 2.0;

    float bw, bd;
    if (barLinked) {
      float diam = (dN != null) ? scaledDiam(dN[i]) : scaleDiam * 0.5;
      bw = diam; bd = diam;
    } else {
      bw = (wN  != null) ? scaledDiam(wN[i])  : scaleDiam * 0.5;
      bd = (dpN != null) ? scaledDiam(dpN[i]) : scaleDiam * 0.5;
    }

    pushStyle();
    stroke(200, 60); strokeWeight(0.5);
    fill(resolveColor(cN != null ? cN[i] : -1,
                      cRaw != null ? cRaw[i] : 0,
                      (catMap != null && mapColor >= 0) ? csvTable.getRow(i).getString(mapColor) : null,
                      catMap, catCount));
    pushMatrix();
    translate(bx, by, 0);
    box(bw, h, bd);
    popMatrix();
    popStyle();
  }
}

void drawLabelsLine() {
  int n = visibleCount();
  float[] hN   = pickNorm(mapHeight);
  float[] hRaw = getColumnValues(mapHeight);
  float[] dN   = (mapDiameter >= 0) ? pickNorm(mapDiameter) : null;
  float[] wN   = (mapWidth    >= 0) ? pickNorm(mapWidth)    : null;
  float[] dpN  = (mapDepth    >= 0) ? pickNorm(mapDepth)    : null;
  float[] dRaw = (mapDiameter >= 0) ? getColumnValues(mapDiameter) : null;
  float[] wRaw = (mapWidth    >= 0) ? getColumnValues(mapWidth)    : null;
  float[] dpRaw= (mapDepth    >= 0) ? getColumnValues(mapDepth)    : null;

  float spacing = SHAPE_SLOT + BAR_GAP;
  float startX  = -(n * spacing - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;

  hint(DISABLE_DEPTH_TEST);
  pushStyle();
  textAlign(CENTER, CENTER);

  for (int i = 0; i < n; i++) {
    float h  = scaledHeight(hN[i]);
    float bx = startX + i * spacing;
    float topY = GND_Y - h;

    float bw, bd;
    if (barLinked) {
      float diam = (dN != null) ? scaledDiam(dN[i]) : scaleDiam * 0.5;
      bw = diam; bd = diam;
    } else {
      bw = (wN  != null) ? scaledDiam(wN[i])  : scaleDiam * 0.5;
      bd = (dpN != null) ? scaledDiam(dpN[i]) : scaleDiam * 0.5;
    }

    // ── Label column drawn after measurements (see below) ──────────────

    // ── Height dimension line: full-height arrow to the right of bar ─────────
    if (mapHeight >= 0) {
      String hLabel = nf(hRaw[i], 0, 1) + " → " + nf(h, 0, 1) + "mm";
      float lineX = bx + bw / 2.0 + 14;  // just right of bar edge
      stroke(255, 220, 120, 180); strokeWeight(1); noFill();
      dimLine(lineX, GND_Y, lineX, GND_Y - h);  // full height, vertical
      // label at midpoint
      fill(255, 220, 120); noStroke(); textSize(9);
      pushMatrix();
      translate(lineX + 12, GND_Y - h / 2.0, 0);
      rotateZ(HALF_PI);
      text(hLabel, 0, 0);
      popMatrix();
    }

    // ── Width/Diameter dimension line: full-width arrow below bar ────────
    float[] useWN  = barLinked ? dN  : wN;
    float[] useRaw = barLinked ? dRaw : wRaw;
    String  wColName = barLinked
        ? (mapDiameter >= 0 ? columnNames[mapDiameter] : "")
        : (mapWidth    >= 0 ? columnNames[mapWidth]    : "");
    if (useWN != null && useRaw != null) {
      String wLabel = nf(useRaw[i], 0, 1) + " → " + nf(bw, 0, 1) + "mm";
      float lineY = GND_Y + 18;  // just below ground
      stroke(150, 220, 255, 180); strokeWeight(1); noFill();
      dimLine(bx - bw / 2.0, lineY, bx + bw / 2.0, lineY);  // full width, horizontal
      // label centred under bar
      fill(150, 220, 255); noStroke(); textSize(9);
      pushMatrix();
      translate(bx, lineY + 10, 0);
      text(wLabel, 0, 0);
      popMatrix();
      // ── Column label below measurement ──────────────────────────────
      if (mapLabel >= 0) {
        fill(200); noStroke(); textSize(10);
        pushMatrix();
        translate(bx, lineY + 22, 0);
        text(csvTable.getRow(i).getString(mapLabel), 0, 0);
        popMatrix();
      }
    } else {
      // No width column mapped — still show label below ground
      if (mapLabel >= 0) {
        fill(200); noStroke(); textSize(10);
        pushMatrix();
        translate(bx, GND_Y + 14, 0);
        text(csvTable.getRow(i).getString(mapLabel), 0, 0);
        popMatrix();
      }
    }

    // ── Depth (separate mode only) ──────────────────────────────────────
    if (!barLinked && dpN != null && dpRaw != null) {
      String dLabel = nf(dpRaw[i], 0, 1) + " → " + nf(bd, 0, 1) + "mm";
      fill(180, 255, 180); textSize(9);
      pushMatrix();
      translate(bx, GND_Y - h / 2.0, bd / 2.0 + 8);
      text(dLabel, 0, 0);
      popMatrix();
    }
  }

  popStyle();
  hint(ENABLE_DEPTH_TEST);
}

// Draw a line with an arrowhead pointing at (x2, y2) in the XY plane (z=0)
void arrowTo(float x1, float y1, float x2, float y2) {
  line(x1, y1, 0, x2, y2, 0);
  float ang  = atan2(y2 - y1, x2 - x1);
  float aLen = 4;
  line(x2, y2, 0, x2 - aLen * cos(ang - 0.45), y2 - aLen * sin(ang - 0.45), 0);
  line(x2, y2, 0, x2 - aLen * cos(ang + 0.45), y2 - aLen * sin(ang + 0.45), 0);
}

// Draw a double-headed dimension line from (x1,y1) to (x2,y2)
void dimLine(float x1, float y1, float x2, float y2) {
  line(x1, y1, 0, x2, y2, 0);
  float ang  = atan2(y2 - y1, x2 - x1);
  float aLen = 5;
  // arrowhead at end
  line(x2, y2, 0, x2 - aLen * cos(ang - 0.4), y2 - aLen * sin(ang - 0.4), 0);
  line(x2, y2, 0, x2 - aLen * cos(ang + 0.4), y2 - aLen * sin(ang + 0.4), 0);
  // arrowhead at start (reversed)
  float ang2 = ang + PI;
  line(x1, y1, 0, x1 - aLen * cos(ang2 - 0.4), y1 - aLen * sin(ang2 - 0.4), 0);
  line(x1, y1, 0, x1 - aLen * cos(ang2 + 0.4), y1 - aLen * sin(ang2 + 0.4), 0);
}

void drawAxesLine() {
  if (csvTable == null || mapHeight < 0) return;
  int   n       = visibleCount();
  float spacing = SHAPE_SLOT + BAR_GAP;
  float startX  = -(n * spacing - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;
  float axX     = startX - SHAPE_SLOT / 2.0 - 50;

  float[] hVals = getColumnValues(mapHeight);
  float   hMin  = trueSize ? 0 : min(hVals);
  float   hMax  = max(hVals);
  int     ticks = 5;

  pushStyle();
  hint(DISABLE_DEPTH_TEST);
  stroke(255, 100, 100); strokeWeight(1.5);
  line(axX, GND_Y, 0, axX, GND_Y - scaleH, 0);

  for (int t = 0; t <= ticks; t++) {
    float frac = t / (float) ticks;
    float wy   = GND_Y - frac * scaleH;
    float val  = hMin + frac * (hMax - hMin);
    stroke(255, 100, 100); strokeWeight(1);
    line(axX - 8, wy, 0, axX, wy, 0);
    fill(220, 180, 180); noStroke(); textSize(9); textAlign(RIGHT, CENTER);
    pushMatrix();
    translate(axX - 12, wy, 0);
    text(nf(val, 0, 1), 0, 0);
    popMatrix();
  }
  fill(255, 130, 130); textSize(10); textAlign(CENTER, BOTTOM); noStroke();
  pushMatrix();
  translate(axX - 36, GND_Y - scaleH / 2.0, 0);
  rotateZ(-HALF_PI);
  text(columnNames[mapHeight], 0, 0);
  popMatrix();
  hint(ENABLE_DEPTH_TEST);
  popStyle();
}

// ── Bars (boxes) ─────────────────────────────────────────────────────────────
void drawBars() {
  int n = visibleCount();

  float[] hN   = pickNorm(mapHeight);
  float[] dN   = (mapDiameter >= 0) ? pickNorm(mapDiameter) : null;
  float[] wN   = (mapWidth    >= 0) ? pickNorm(mapWidth)    : null;
  float[] dpN  = (mapDepth    >= 0) ? pickNorm(mapDepth)    : null;
  boolean numColor = (mapColor >= 0) && isNumericCol(mapColor);
  float[] cN   = numColor ? normalizeCol(mapColor) : null;
  float[] cRaw = numColor ? getColumnValues(mapColor) : null;
  java.util.HashMap<String, Integer> catMap =
      (!numColor && mapColor >= 0) ? buildCatMap(mapColor) : null;
  int catCount = (catMap != null) ? max(catMap.size(), 1) : 1;

  float spacing = SHAPE_SLOT + BAR_GAP;
  float startX  = -(n * spacing - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;

  for (int i = 0; i < n; i++) {
    float h    = scaledHeight(hN[i]);
    PVector gp = gridPos(i, n);
    float bx   = gp.x;
    float bz   = gp.y;
    float by   = GND_Y - h / 2.0;

    float bw, bd;
    if (barLinked) {
      float diam = (dN != null) ? scaledDiam(dN[i]) : scaleDiam * 0.5;
      bw = diam;
      bd = diam;
    } else {
      bw = (wN  != null) ? scaledDiam(wN[i])  : scaleDiam * 0.5;
      bd = (dpN != null) ? scaledDiam(dpN[i]) : scaleDiam * 0.5;
    }

    pushStyle();
    stroke(200, 60);
    strokeWeight(0.5);
    fill(resolveColor(cN != null ? cN[i] : -1,
                      cRaw != null ? cRaw[i] : 0,
                      (catMap != null && mapColor >= 0) ? csvTable.getRow(i).getString(mapColor) : null,
                      catMap, catCount));
    pushMatrix();
    translate(bx, by, bz);
    box(bw, h, bd);
    popMatrix();
    popStyle();
  }
}

// ── Polyhedra (prisms) ────────────────────────────────────────────────────────
void drawPolyhedra() {
  int n = visibleCount();

  float[] hN   = pickNorm(mapHeight);
  float[] dN   = (mapDiameter >= 0) ? pickNorm(mapDiameter) : null;
  float[] sN   = (mapSides    >= 0) ? pickNorm(mapSides)    : null;
  boolean numColor = (mapColor >= 0) && isNumericCol(mapColor);
  float[] cN   = numColor ? normalizeCol(mapColor) : null;
  float[] cRaw = numColor ? getColumnValues(mapColor) : null;
  java.util.HashMap<String, Integer> catMap =
      (!numColor && mapColor >= 0) ? buildCatMap(mapColor) : null;
  int catCount = (catMap != null) ? max(catMap.size(), 1) : 1;

  float spacing = SHAPE_SLOT + BAR_GAP;
  float startX  = -(n * spacing - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;

  for (int i = 0; i < n; i++) {
    float h    = scaledHeight(hN[i]);
    float diam = (dN != null) ? scaledDiam(dN[i]) : scaleDiam * 0.5;
    int   sides = (sN != null)
                    ? (int) map(sN[i], 0, 1, MIN_SIDES, scaleSides)
                    : DEF_SIDES;
    sides = constrain(sides, MIN_SIDES, scaleSides);

    PVector gp = gridPos(i, n);
    float bx = gp.x;
    float bz = gp.y;
    float by = GND_Y - h / 2.0;

    pushStyle();
    stroke(200, 60);
    strokeWeight(0.5);
    fill(resolveColor(cN != null ? cN[i] : -1,
                      cRaw != null ? cRaw[i] : 0,
                      (catMap != null && mapColor >= 0) ? csvTable.getRow(i).getString(mapColor) : null,
                      catMap, catCount));
    drawPrism(bx, by, bz, diam, h, sides);
    popStyle();
  }
}

// ── Shared colour resolver ──────────────────────────────────────────────────────────
// norm:   normalised 0-1 value (or -1 if not numeric)
// rawVal: actual data value (used for threshold comparison)
// catKey: string category key (or null)
color resolveColor(float norm, float rawVal, String catKey, java.util.HashMap<String, Integer> catMap, int catCount) {
  if (norm >= 0) {
    if (parsedThresholds.length > 0) {
      // Find which band rawVal falls into
      int band = parsedThresholds.length; // default: above all thresholds
      for (int t = 0; t < parsedThresholds.length; t++) {
        if (rawVal < parsedThresholds[t]) { band = t; break; }
      }
      return bandColor(band, parsedThresholds.length + 1);
    } else {
      // Continuous gradient: blue → red
      return lerpColor(color(50, 80, 255), color(255, 60, 50), norm);
    }
  } else if (catMap != null && catKey != null) {
    int ci = catMap.containsKey(catKey) ? catMap.get(catKey) : 0;
    colorMode(HSB, 360, 100, 100);
    color c = color(map(ci, 0, catCount, 0, 300), 80, 90);
    colorMode(RGB, 255);
    return c;
  }
  return color(150, 180, 220);  // default
}

// Return a distinct colour for band index b out of total bands
color bandColor(int b, int total) {
  colorMode(HSB, 360, 100, 100);
  color c = color(map(b, 0, total, 0, 300), 85, 90);
  colorMode(RGB, 255);
  return c;
}

// Parse the threshold textfield string into a sorted float array
void parseThresholds() {
  String[] parts = split(thresholdStr.trim(), ',');
  java.util.ArrayList<Float> vals = new java.util.ArrayList<Float>();
  for (String p : parts) {
    String t = p.trim();
    if (t.length() > 0) {
      try { vals.add(Float.parseFloat(t)); } catch (Exception ex) {}
    }
  }
  java.util.Collections.sort(vals);
  parsedThresholds = new float[vals.size()];
  for (int j = 0; j < vals.size(); j++) parsedThresholds[j] = vals.get(j);
}
void drawPrism(float cx, float cy, float cz, float diameter, float h, int sides) {
  float r     = diameter / 2.0;
  float halfH = h / 2.0;

  pushMatrix();
  translate(cx, cy, cz);

  // Top cap
  beginShape(TRIANGLE_FAN);
  vertex(0, -halfH, 0);
  for (int i = 0; i <= sides; i++) {
    float a = i * TWO_PI / sides;
    vertex(r * cos(a), -halfH, r * sin(a));
  }
  endShape();

  // Bottom cap (reversed winding)
  beginShape(TRIANGLE_FAN);
  vertex(0, halfH, 0);
  for (int i = sides; i >= 0; i--) {
    float a = i * TWO_PI / sides;
    vertex(r * cos(a), halfH, r * sin(a));
  }
  endShape();

  // Side faces
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a  = i * TWO_PI / sides;
    float vx = r * cos(a);
    float vz = r * sin(a);
    vertex(vx, -halfH, vz);
    vertex(vx,  halfH, vz);
  }
  endShape();

  popMatrix();
}

// ── Labels: below shape + vertically on front face ───────────────────────────
void drawLabels() {
  if (mapLabel < 0) return;
  int n = visibleCount();

  float[] hN = pickNorm(mapHeight);
  float[] dN = (mapDiameter >= 0) ? pickNorm(mapDiameter) : null;

  float spacing = SHAPE_SLOT + BAR_GAP;
  float startX  = -(n * spacing - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;

  hint(DISABLE_DEPTH_TEST);
  pushStyle();
  textAlign(CENTER, CENTER);

  for (int i = 0; i < n; i++) {
    String lbl  = csvTable.getRow(i).getString(mapLabel);
    float  h    = scaledHeight(hN[i]);
    float  diam = (dN != null) ? scaledDiam(dN[i]) : scaleDiam * 0.5;
    PVector gp  = gridPos(i, n);
    float  bx   = gp.x;
    float  bz   = gp.y;
    float  by   = GND_Y - h / 2.0;

    // Below shape
    fill(200);
    textSize(10);
    pushMatrix();
    translate(bx, GND_Y + 8, bz);
    text(lbl, 0, 0);
    popMatrix();
  }

  popStyle();
  hint(ENABLE_DEPTH_TEST);
}

// ── HUD elements ──────────────────────────────────────────────────────────────
void drawSidebarBg() {
  pushStyle();
  fill(20, 20, 20, 255);   // fully opaque — sidebar is a solid separate panel
  noStroke();
  rect(0, 0, SIDE_W, height);
  popStyle();
}

// ── Orientation gizmo (top-right corner, screen-locked) ─────────────────────
void drawGizmo() {
  float[] r = camera.getRotations();
  int gx = width - GIZMO_SIZE - 10;
  int gy = 10;

  gizmo.beginDraw();
  gizmo.background(25, 25, 25, 210);
  gizmo.pushMatrix();
  gizmo.translate(GIZMO_SIZE / 2.0, GIZMO_SIZE / 2.0, 0);
  gizmo.rotateX((float) r[0]);
  gizmo.rotateY((float) r[1]);
  gizmo.rotateZ((float) r[2]);

  int len = 28;
  gizmo.strokeWeight(2);
  gizmo.noFill();

  // X axis — red
  gizmo.stroke(255, 80, 80);   gizmo.line(0,0,0, len,0,0);
  // Y axis — green (up = negative Y in Processing)
  gizmo.stroke(80, 220, 80);   gizmo.line(0,0,0, 0,-len,0);
  // Z axis — blue
  gizmo.stroke(100, 140, 255); gizmo.line(0,0,0, 0,0,len);

  // Axis labels at tips
  gizmo.textSize(9);
  gizmo.noStroke();
  gizmo.fill(255, 100, 100); gizmo.text("X",  len+4,    2,  0);
  gizmo.fill(100, 240, 100); gizmo.text("Y",      2, -len-4,  0);
  gizmo.fill(130, 160, 255); gizmo.text("Z",      2,    2, len+4);

  gizmo.popMatrix();

  // Border circle
  gizmo.noFill();
  gizmo.stroke(80);
  gizmo.strokeWeight(1);
  gizmo.ellipse(GIZMO_SIZE / 2.0, GIZMO_SIZE / 2.0, GIZMO_SIZE - 4, GIZMO_SIZE - 4);
  gizmo.endDraw();

  image(gizmo, gx, gy);
}

void drawFeedback() {
  if (msgTimer <= 0) return;
  float alpha = map(msgTimer, 0, MSG_DUR, 0, 255);
  pushStyle();
  fill(80, 220, 110, alpha);
  textAlign(LEFT, TOP);
  textSize(13);
  text(exportMsg, SIDE_W + 10, 10);
  popStyle();
  msgTimer--;
}

// ── Button callbacks (ControlP5 naming convention) ────────────────────────────
// ── Camera preset snappers ────────────────────────────────────────────────────
void snapFront() { camera.setRotations(0, 0, 0);              camera.setDistance(800); }
void snapTop()   { camera.setRotations(-HALF_PI, 0, 0);       camera.setDistance(800); }
void snapSide()  { camera.setRotations(0, HALF_PI, 0);        camera.setDistance(800); }
void snapIso()   { camera.setRotations(-0.615, PI / 4.0, 0);  camera.setDistance(800); }
void resetView() { camera.reset(500); }

void toggleMode() {
  polyMode = !polyMode;
  updateModeVisibility();
}

void toggleBarSize() {
  barLinked = !barLinked;
  updateModeVisibility();
}

void toggleTrueSize() {
  trueSize = !trueSize;
  cp5.get(Button.class, "toggleTrueSize")
     .setLabel(trueSize ? "SCALE: TRUE SIZE" : "SCALE: RELATIVE");
}

void toggleView2D() {
  view2D = !view2D;
  if (view2D) {
    // Reset to a sensible front view centred on the bars
    view2DZoom = 1.5;
    view2DPanX = 0;
    view2DPanY = GND_Y - scaleH * 0.5;   // vertical centre of tallest bar
  }
  cp5.get(Button.class, "toggleView2D")
     .setLabel(view2D ? "VIEW: 2D" : "VIEW: 3D");
}

void updateModeVisibility() {
  boolean useSides = polyMode;

  cp5.get(Textlabel.class, "lbl2").setText("DIAMETER COLUMN");

  // Show/hide the entire sides row
  cp5.get(Textlabel.class,  "lbl3")          .setVisible(useSides);
  cp5.getController("scaleSides")             .setVisible(useSides);
  cp5.get(Numberbox.class,   "nb_scaleSides").setVisible(useSides);
  cp5.getController("prevSides")              .setVisible(useSides);
  cp5.get(Textlabel.class,  "curSides")   .setVisible(useSides);
  cp5.getController("nextSides")           .setVisible(useSides);

  cp5.getController("toggleBarSize")
     .setVisible(false);   // kept for future use
  cp5.get(Button.class, "toggleMode")
     .setLabel(polyMode ? "MODE: POLYHEDRA" : "MODE: BARS")
     .setColorBackground(polyMode ? color(90, 40, 160) : color(30, 80, 190))
     .setColorActive(polyMode ? color(120, 60, 200) : color(50, 110, 230));

  // 2D/3D view toggle only makes sense in bar mode
  cp5.getController("toggleView2D").setVisible(!polyMode);
}

void loadCSV() {
  selectInput("Select a CSV file:", "fileSelected");
}

void fileSelected(File selection) {
  if (selection == null) return;
  csvTable    = loadTable(selection.getAbsolutePath(), "header,csv");
  columnNames = csvTable.getColumnTitles();
  surface.setTitle("3D Polyhedra Chart  —  " + selection.getName());
  updateDropdowns();
}

void exportJSON() {
  if (csvTable == null || mapHeight < 0) {
    exportMsg = "Load a CSV file first.";
    msgTimer  = MSG_DUR;
    return;
  }

  int     n       = visibleCount();
  float[] hN      = pickNorm(mapHeight);
  float[] dN      = (mapDiameter >= 0) ? pickNorm(mapDiameter) : null;
  float[] wN      = (mapWidth    >= 0) ? pickNorm(mapWidth)    : null;
  float[] dpN     = (mapDepth    >= 0) ? pickNorm(mapDepth)    : null;
  float[] sN      = (mapSides    >= 0) ? pickNorm(mapSides)    : null;
  boolean numColor = (mapColor >= 0) && isNumericCol(mapColor);
  float[] cN      = numColor ? normalizeCol(mapColor) : null;
  float[] cRaw    = numColor ? getColumnValues(mapColor) : null;
  java.util.HashMap<String, Integer> catMap =
      (!numColor && mapColor >= 0) ? buildCatMap(mapColor) : null;
  int catCount = (catMap != null) ? max(catMap.size(), 1) : 1;

  float   spacing = SHAPE_SLOT + BAR_GAP;
  float   startX  = -(n * spacing - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;

  JSONArray arr = new JSONArray();
  for (int i = 0; i < n; i++) {
    float h   = scaledHeight(hN[i]);
    PVector gp = gridPos(i, n);
    float bx  = gp.x;
    float bz  = gp.y;
    String lbl = (mapLabel >= 0) ? csvTable.getRow(i).getString(mapLabel) : ("shape_" + i);

    // Resolve colour
    color c = resolveColor(cN != null ? cN[i] : -1,
                           cRaw != null ? cRaw[i] : 0,
                           (catMap != null && mapColor >= 0) ? csvTable.getRow(i).getString(mapColor) : null,
                           catMap, catCount);

    JSONObject obj = new JSONObject();
    obj.setString("label",      lbl);
    obj.setFloat ("height",     h);
    obj.setString("color",      colorToHex(c));

    if (polyMode) {
      float diam = (dN != null) ? scaledDiam(dN[i]) : scaleDiam * 0.5;
      int sides  = (sN != null)
                     ? constrain((int) map(sN[i], 0, 1, MIN_SIDES, scaleSides), MIN_SIDES, scaleSides)
                     : DEF_SIDES;
      obj.setFloat("diameter", diam);
      obj.setInt  ("sides",    sides);
    } else if (barLinked) {
      float diam = (dN != null) ? scaledDiam(dN[i]) : scaleDiam * 0.5;
      obj.setFloat("width",  diam);
      obj.setFloat("depth",  diam);
    } else {
      float bw = (wN  != null) ? scaledDiam(wN[i])  : scaleDiam * 0.5;
      float bd = (dpN != null) ? scaledDiam(dpN[i]) : scaleDiam * 0.5;
      obj.setFloat("width",  bw);
      obj.setFloat("depth",  bd);
    }
    arr.setJSONObject(i, obj);
  }

  String fname = cp5.get(Textfield.class, "exportName").getText().trim();
  if (fname.isEmpty()) fname = "export";
  String filename = fname + ".json";
  String outPath = sketchPath(filename);
  saveJSONArray(arr, outPath);
  exportMsg = "Saved: " + filename + "  (" + n + " shapes)";
  msgTimer  = MSG_DUR;
}

// ── Dropdown management (now prev/next button selectors) ─────────────────────
void updateDropdowns() {
  // Auto-detect sensible default mappings
  int firstStr = -1, n1 = -1, n2 = -1, n3 = -1, n4 = -1;
  for (int i = 0; i < columnNames.length; i++) {
    if (isNumericCol(i)) {
      if      (n1 < 0) n1 = i;
      else if (n2 < 0) n2 = i;
      else if (n3 < 0) n3 = i;
      else if (n4 < 0) n4 = i;
    } else {
      if (firstStr < 0) firstStr = i;
    }
  }

  mapLabel    = (firstStr >= 0) ? firstStr : 0;
  mapHeight   = (n1 >= 0) ? n1 : 0;
  mapDiameter = (n2 >= 0) ? n2 : mapHeight;
  mapWidth    = (n2 >= 0) ? n2 : mapHeight;
  mapDepth    = (n3 >= 0) ? n3 : mapHeight;
  mapSides    = (n4 >= 0) ? n4 : -1;
  mapColor    = mapHeight;

  int total = csvTable.getRowCount();
  barCountSlider.setRange(1, total);
  barCountSlider.setValue(total);
  visibleBars = total;
  Numberbox nb_bc = cp5.get(Numberbox.class, "nb_barCount");
  if (nb_bc != null) { suppressEvents = true; nb_bc.setRange(1, total); nb_bc.setValue(total); suppressEvents = false; }

  updateColLabels();
}

// Update all the current-column display labels
void updateColLabels() {
  cp5.get(Textlabel.class, "curLabel")   .setText(colName(mapLabel,    true));
  cp5.get(Textlabel.class, "curHeight")  .setText(colName(mapHeight,   false));
  cp5.get(Textlabel.class, "curDiameter").setText(colName(mapDiameter, true));
  cp5.get(Textlabel.class, "curSides")   .setText(colName(mapSides,    true));
  cp5.get(Textlabel.class, "curColor")   .setText(colName(mapColor,    true));
}

String colName(int idx, boolean allowNone) {
  if (idx < 0) return allowNone ? "(none)" : "(load CSV)";
  if (columnNames == null || idx >= columnNames.length) return "?";
  String name = columnNames[idx];
  return (name.length() > 14) ? name.substring(0, 13) + "…" : name;
}

// Cycle a column index, wrapping around; allowNone includes -1 as a valid choice
int cycleCol(int current, int dir, boolean allowNone) {
  if (csvTable == null) return current;
  int n = csvTable.getColumnCount();
  if (allowNone) {
    // valid range: -1 .. n-1  (total n+1 values)
    return ((current + 1 + dir + n + 1) % (n + 1)) - 1;
  } else {
    return (current + dir + n) % n;
  }
}

void controlEvent(ControlEvent e) {
  if (suppressEvents) return;

  // ── Sliders → sync to their numberbox ────────────────────────────────────
  if (e.isFrom("scaleH"))       { scaleH       = e.getValue(); suppressEvents = true; cp5.get(Numberbox.class, "nb_scaleH").setValue(scaleH);       suppressEvents = false; return; }
  if (e.isFrom("minHeightPct")) { minHeightPct = e.getValue(); suppressEvents = true; cp5.get(Numberbox.class, "nb_minHeightPct").setValue(minHeightPct); suppressEvents = false; return; }
  if (e.isFrom("scaleDiam"))    { scaleDiam    = e.getValue(); suppressEvents = true; cp5.get(Numberbox.class, "nb_scaleDiam").setValue(scaleDiam);   suppressEvents = false; return; }
  if (e.isFrom("minDiamPct"))   { minDiamPct   = e.getValue(); suppressEvents = true; cp5.get(Numberbox.class, "nb_minDiamPct").setValue(minDiamPct); suppressEvents = false; return; }
  if (e.isFrom("scaleSides"))   { scaleSides   = (int)e.getValue(); suppressEvents = true; cp5.get(Numberbox.class, "nb_scaleSides").setValue(scaleSides); suppressEvents = false; return; }
  if (e.isFrom("barCount"))     { visibleBars  = (int)e.getValue(); suppressEvents = true; cp5.get(Numberbox.class, "nb_barCount").setValue(visibleBars);  suppressEvents = false; return; }

  // ── Numberboxes → sync to their slider ───────────────────────────────────
  if (e.isFrom("nb_scaleH"))       { scaleH       = e.getValue(); suppressEvents = true; cp5.getController("scaleH").setValue(scaleH);             suppressEvents = false; return; }
  if (e.isFrom("nb_minHeightPct")) { minHeightPct = e.getValue(); suppressEvents = true; cp5.getController("minHeightPct").setValue(minHeightPct); suppressEvents = false; return; }
  if (e.isFrom("nb_scaleDiam"))    { scaleDiam    = e.getValue(); suppressEvents = true; cp5.getController("scaleDiam").setValue(scaleDiam);       suppressEvents = false; return; }
  if (e.isFrom("nb_minDiamPct"))   { minDiamPct   = e.getValue(); suppressEvents = true; cp5.getController("minDiamPct").setValue(minDiamPct);     suppressEvents = false; return; }
  if (e.isFrom("nb_scaleSides"))   { scaleSides   = (int)e.getValue(); suppressEvents = true; cp5.getController("scaleSides").setValue(scaleSides); suppressEvents = false; return; }
  if (e.isFrom("nb_barCount"))     { visibleBars  = (int)e.getValue(); suppressEvents = true; cp5.getController("barCount").setValue(visibleBars);  suppressEvents = false; return; }

  if (e.isFrom("thresholds")) { thresholdStr = ((controlP5.Textfield)e.getController()).getText(); parseThresholds(); return; }
}

// ── Column selector prev/next callbacks ───────────────────────────────
void prevLabel()    { mapLabel    = cycleCol(mapLabel,    -1, true);  updateColLabels(); }
void nextLabel()    { mapLabel    = cycleCol(mapLabel,    +1, true);  updateColLabels(); }
void prevHeight()   { mapHeight   = cycleCol(mapHeight,   -1, false); updateColLabels(); }
void nextHeight()   { mapHeight   = cycleCol(mapHeight,   +1, false); updateColLabels(); }
void prevDiameter() { mapDiameter = cycleCol(mapDiameter, -1, true);  updateColLabels(); }
void nextDiameter() { mapDiameter = cycleCol(mapDiameter, +1, true);  updateColLabels(); }
void prevSides()    { mapSides    = cycleCol(mapSides,    -1, true);  updateColLabels(); }
void nextSides()    { mapSides    = cycleCol(mapSides,    +1, true);  updateColLabels(); }
void prevColor()    { mapColor    = cycleCol(mapColor,    -1, true);  updateColLabels(); }
void nextColor()    { mapColor    = cycleCol(mapColor,    +1, true);  updateColLabels(); }

// ── Data helpers ──────────────────────────────────────────────────────────────
void mousePressed() {
  if (view2D && !polyMode && mouseX > SIDE_W && !cp5.isMouseOver()) {
    pan2DActive = true;
    pan2DLastX  = mouseX;
    pan2DLastY  = mouseY;
  }
}

void mouseReleased() {
  pan2DActive = false;
}

void mouseDragged() {
  if (pan2DActive) {
    // Convert screen-pixel delta to world units at the current zoom/distance
    float worldPerPx = (800.0 / view2DZoom) / (height * 0.5 / tan(PI / 6.0));
    view2DPanX -= (mouseX - pan2DLastX) * worldPerPx;
    view2DPanY -= (mouseY - pan2DLastY) * worldPerPx;
    pan2DLastX  = mouseX;
    pan2DLastY  = mouseY;
  }
}

void mouseWheel(MouseEvent e) {
  if (view2D && !polyMode && mouseX > SIDE_W) {
    float factor = (e.getCount() > 0) ? 0.9 : 1.1;
    view2DZoom  *= factor;
    view2DZoom   = constrain(view2DZoom, 0.05, 20);
  }
}

float scaledHeight(float norm) {
  if (trueSize) return norm * scaleH;   // from-zero: no minimum floor
  float minH = scaleH * (minHeightPct / 100.0);
  return map(norm, 0, 1, minH, scaleH);
}

float scaledDiam(float norm) {
  if (trueSize) return norm * scaleDiam;
  float minD = scaleDiam * (minDiamPct / 100.0);
  return map(norm, 0, 1, minD, scaleDiam);
}

// Normalize 0 → max (true-size: preserves absolute proportions from zero)
float[] normalizeColFromZero(int col) {
  int n = csvTable.getRowCount();
  float[] vals = new float[n];
  float mx = -1e30;
  for (int i = 0; i < n; i++) {
    try { vals[i] = float(csvTable.getRow(i).getString(col)); }
    catch (Exception ex) { vals[i] = 0; }
    if (vals[i] > mx) mx = vals[i];
  }
  if (mx < 1e-9) { for (int i = 0; i < n; i++) vals[i] = 1.0; return vals; }
  for (int i = 0; i < n; i++) vals[i] = vals[i] / mx;
  return vals;
}

// Pick normalization mode based on trueSize flag (leave color always min-max)
float[] pickNorm(int col) {
  return trueSize ? normalizeColFromZero(col) : normalizeCol(col);
}

float[] normalizeCol(int col) {
  int n = csvTable.getRowCount();
  float[] vals = new float[n];
  float mn =  1e30, mx = -1e30;
  for (int i = 0; i < n; i++) {
    try { vals[i] = float(csvTable.getRow(i).getString(col)); }
    catch (Exception ex) { vals[i] = 0; }
    if (vals[i] < mn) mn = vals[i];
    if (vals[i] > mx) mx = vals[i];
  }
  float range = mx - mn;
  if (range < 1e-9) {
    // All values identical → show all bars at full scale
    for (int i = 0; i < n; i++) vals[i] = 1.0;
    return vals;
  }
  for (int i = 0; i < n; i++) vals[i] = (vals[i] - mn) / range;
  return vals;
}

boolean isNumericCol(int col) {
  if (csvTable == null || col < 0 || col >= csvTable.getColumnCount()) return false;
  for (int i = 0; i < csvTable.getRowCount(); i++) {
    String v = csvTable.getRow(i).getString(col);
    if (v == null || v.trim().isEmpty()) continue;
    try { Float.parseFloat(v.trim()); }
    catch (NumberFormatException e) { return false; }
  }
  return true;
}

java.util.HashMap<String, Integer> buildCatMap(int col) {
  java.util.HashMap<String, Integer> map = new java.util.HashMap<String, Integer>();
  int idx = 0;
  for (int i = 0; i < csvTable.getRowCount(); i++) {
    String v = csvTable.getRow(i).getString(col);
    if (!map.containsKey(v)) map.put(v, idx++);
  }
  return map;
}

// ── View helpers ──────────────────────────────────────────────────────────────
int visibleCount() {
  if (csvTable == null) return 0;
  int total = csvTable.getRowCount();
  return (visibleBars > 0) ? min(visibleBars, total) : total;
}

float[] getColumnValues(int col) {
  int n = csvTable.getRowCount();
  float[] vals = new float[n];
  for (int i = 0; i < n; i++) {
    try { vals[i] = float(csvTable.getRow(i).getString(col)); }
    catch (Exception ex) { vals[i] = 0; }
  }
  return vals;
}

String colorToHex(color c) {
  return String.format("#%02X%02X%02X", (int) red(c), (int) green(c), (int) blue(c));
}

// Returns the (x, z) centre position of shape i in a square grid.
// PVector.x = world X,  PVector.y = world Z  (y is reused as Z)
PVector gridPos(int i, int n) {
  int   cols = max(1, (int) ceil(sqrt(n)));
  int   rows = max(1, (int) ceil((float) n / cols));
  float sp   = SHAPE_SLOT + BAR_GAP;
  float sx   = -(cols * sp - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;
  float sz   = -(rows * sp - BAR_GAP) / 2.0 + SHAPE_SLOT / 2.0;
  return new PVector(sx + (i % cols) * sp, sz + (i / cols) * sp);
}
