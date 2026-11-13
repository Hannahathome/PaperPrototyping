// PAPERPOLYHEDRAFIGURES.PDE - Figures of a PaperPolyhedra flat template, for papers
//
// Not a fabrication tool: nothing here is cut. It draws the flat template PaperPolyhedra
// would cut for the same settings, as a clean line figure in two panels:
//
//   a  TEMPLATE    the whole template -- strip, flaps and both lids -- with full cuts and
//                  dashed folds in their own colours, numbered frames for the close-ups, and
//                  the panel's height and edge widths
//   b  DETAILS     four close-ups -- a wall tab, the glue flap, the hook flap and a lid tab
//                  -- with every size that shapes them dimensioned in millimetres. Each can
//                  be zoomed further: wheel over it, drag to pan, R to reset.
//
// The template geometry is copied from PaperPolyhedra (Template.pde says exactly what and
// from where). Everything is set from the sliders; the tool reads no files. "Save PNG" (or S)
// draws the panels again at a multiple of screen resolution and writes them to output/.
//
// Look: matches ScaffoldShellFigures -- white panels, a dark letter tag on a rule under each,
// neutral grey ControlP5. Every colour is a constant below.
//
// Files:
//   Template.pde    the template, copied from PaperPolyhedra and recorded as cuts and folds
//   Render.pde      drawing the template and the two panels
//   Dimensions.pde  dimension lines and the close-up layouts
//   UI.pde          the ControlP5 sidebar
//   Export.pde      high-resolution PNG

import controlP5.*;

ControlP5 cp5;

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

final color CLR_BG         = color(248, 249, 250);   // window, between the panels
final color CLR_PANEL      = color(255);             // panel / figure background
final color CLR_TEXT       = color(33, 37, 41);
final color CLR_TEXT_MUTED = color(140, 145, 150);
final color CLR_WARN       = color(200, 70, 70);

final color CLR_CUT        = color(205, 40, 45);     // full cuts: solid
final color CLR_FOLD       = color(30, 95, 205);     // folds: dashed
final color CLR_DIM        = color(60, 60, 60);      // dimension and extension lines
final color CLR_DIM_LABEL  = color(255, 255, 255, 230);
final color CLR_FRAME      = color(120, 125, 130);   // close-up frames on panel a
final color CLR_TAG        = color(85, 85, 85);      // panel letter tag and rule
final color CLR_TAG_TEXT   = color(255);

// ---------------------------------------------------------------------------
// Template (mm) -- PaperPolyhedra's sliders
// ---------------------------------------------------------------------------

int     sides          = 6;
float   topDiameter    = 40;    // PaperPolyhedra's "diameter": circumscribed, but the side length at 4 sides
float   bottomDiameter = 40;
float   shellHeight    = 60;
float   tabDepth       = 15;
float   flapDepth      = 5;
float   flapTaper      = 5;
float   tabNeckRatio   = 0.8;
final float hookOffset = -1;    // fixed in PaperPolyhedra (Param.pde)
boolean splitStrip     = false;

// ---------------------------------------------------------------------------
// View and export
// ---------------------------------------------------------------------------

boolean showDimensions = true;
boolean showNotes      = true;   // the rules under each close-up ("inset = 1/4 edge")
boolean showFrames     = true;   // the numbered close-up frames on panel a
boolean showLegend     = true;
boolean showLabels     = true;   // panel letters
float   lineWeight     = 1.0;    // screen pixels; scaled with the export

int     exportScale    = 3;
boolean transparentBg  = false;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

boolean showUI          = true;
boolean uiReady         = false;   // ControlP5 fires events while it is being built
boolean exportRequested = false;
String  statusLine      = "";

final int SIDEBAR_W = 300;
final int GAP       = 10;
final float PANEL_A_SHARE = 0.56;   // of the width left for the panels

final String[] PANEL_LETTERS = { "a", "b" };
final String[] PANEL_FILES   = { "template", "details" };

int panelY0, panelH;
int[] panelXs = new int[2], panelWs = new int[2];

PFont fontTitle, fontHeader, fontBody, fontLabel, fontDim;

void settings() {
  size(1500, 850);
  pixelDensity(1);
  smooth(8);
}

void setup() {
  surface.setTitle("PaperPolyhedra Figures");
  surface.setResizable(true);

  fontTitle  = createFont("SansSerif.bold", 15, true);
  fontHeader = createFont("SansSerif.bold", 11, true);
  fontBody   = createFont("SansSerif", 11, true);
  fontLabel  = createFont("SansSerif.bold", 32, true);   // drawn smaller; large for sharp exports
  fontDim    = createFont("SansSerif", 32, true);

  setupUI();
  layoutPanels();
  uiReady = true;
}

void draw() {
  layoutPanels();
  Template t = buildTemplate();

  if (exportRequested) {
    exportRequested = false;
    exportFigure(t);
  }

  background(CLR_BG);
  renderTemplatePanel(g, t, panelXs[0], panelY0, panelWs[0], panelH, 1);
  renderDetailsPanel(g, t, panelXs[1], panelY0, panelWs[1], panelH, 1);
  for (int i = 0; i < 2; i++) {
    if (showLabels) drawPanelLabel(g, panelXs[i], panelY0, panelWs[i], panelH, i, 1);
  }

  if (showUI) {
    drawSidebar(t);
    cp5.draw();
  } else {
    fill(CLR_TEXT_MUTED);
    textFont(fontBody);
    textAlign(LEFT, BOTTOM);
    text("H  show controls", GAP + 6, height - GAP - 6);
  }
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

void layoutPanels() {
  int left  = (showUI ? SIDEBAR_W : 0) + GAP;
  int avail = max(200, width - left - GAP);
  panelWs[0] = round((avail - GAP) * PANEL_A_SHARE);
  panelWs[1] = avail - GAP - panelWs[0];
  panelXs[0] = left;
  panelXs[1] = left + panelWs[0] + GAP;
  panelY0 = GAP;
  panelH  = max(60, height - 2 * GAP);
}

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

void keyPressed() {
  if (key == 'h' || key == 'H') {
    showUI = !showUI;
    if (showUI) cp5.show(); else cp5.hide();
  } else if (key == 's' || key == 'S') {
    exportRequested = true;
  } else if (key == 'd' || key == 'D') {
    cp5.getController("showDimensions").setValue(showDimensions ? 0 : 1);
  } else if (key == 'n' || key == 'N') {
    cp5.getController("showNotes").setValue(showNotes ? 0 : 1);
  } else if (key == 'r' || key == 'R') {
    resetCloseupZoom();
  }
}
