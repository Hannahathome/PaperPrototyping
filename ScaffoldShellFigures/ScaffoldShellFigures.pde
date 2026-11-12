// SCAFFOLDSHELLFIGURES.PDE - Figures of a ScaffoldShell frustum and its scaffold, for papers
//
// Not a fabrication tool: nothing here is cut or printed. It draws one frustum shell and the
// strut scaffold that goes inside it, three ways side by side --
//
//   SHELL      the paper shell on its own
//   SCAFFOLD   the 3D-printed strut cage and its component rigs on their own
//   ASSEMBLY   the scaffold seen through a see-through shell
//
// -- all from the same camera, so the three panels always line up. Everything is set from
// the sliders; the tool reads no files. "Save PNG" (or S) renders the panels again off-screen
// at a multiple of screen resolution and writes them to output/.
//
// Look: the paper's folding figures -- white background, light-grey paper faces with flat
// shading, thin dark-grey edges, one blue accent, and a dark letter tag ("a", "b", "c") on a
// rule under each panel. Controls are neutral grey ControlP5. Every colour is a constant
// below, so the whole palette changes in one place.
//
// Files:
//   Geometry.pde  shell vertices + the scaffold geometry (ported from ScaffoldShell/Frame.pde)
//   Camera.pde    the shared orbit / pan / zoom
//   Render.pde    drawing the three panels
//   UI.pde        the ControlP5 sidebar
//   Export.pde    high-resolution PNG

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

final color CLR_SHELL      = color(240, 240, 240);   // paper faces
final color CLR_EDGE       = color(70, 70, 70);      // shell edges
final color CLR_CAGE       = color(150, 150, 150);   // ring, wall struts, floor spokes
final color CLR_RIG        = color(112, 112, 112);   // rig posts, spines, connectors
final color CLR_ACCENT     = color(30, 30, 200);     // the blue: component box outlines
final color CLR_BOX        = color(205, 210, 240);   // component box faces
final float BOX_ALPHA      = 70;
final color CLR_TAG        = color(85, 85, 85);      // panel letter tag and rule
final color CLR_TAG_TEXT   = color(255);

// Lighting: mostly ambient, with the key light coming from the viewer's side, so faces read
// as flat paper -- walls facing you near-white, the top lid and walls turned away a step
// darker -- rather than as glossy solids.
final float LIGHT_AMBIENT  = 185;                    // 0..255
final float LIGHT_KEY      = 85;                     // directional, from front left
final float LIGHT_FILL     = 15;                     // directional, from the right

// ---------------------------------------------------------------------------
// Shell (mm). Diameters are CIRCUMSCRIBED diameters: 2 x the distance to a corner.
// ---------------------------------------------------------------------------

int     sides          = 6;
float   topDiameter    = 50;
float   bottomDiameter = 80;
float   shellHeight    = 60;
boolean showTopLid     = true;
boolean showBottomLid  = true;

// ---------------------------------------------------------------------------
// Scaffold (mm)
// ---------------------------------------------------------------------------

float   strutRadius  = 1.0;
float   clearance    = 0.4;
boolean dualStruts   = false;
float   strutSpacing = 15;
float   wallFlapLength = 8;   // wedge flap at the top of each wall strut (ScaffoldShell's default)

ArrayList<Rig> rigs = new ArrayList<Rig>();
int selectedRig = 0;
final int MAX_RIGS = 4;

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

boolean orthoView    = false;
boolean showRigBoxes = true;
boolean showLabels   = true;
float   overlayAlpha = 90;    // assembly panel; the Shell panel is always opaque
float   edgeWeight   = 1.0;   // screen pixels; scaled up with the export

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

int     exportScale   = 3;
boolean transparentBg = false;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

boolean showUI          = true;
boolean uiReady         = false;   // ControlP5 fires events while it is being built
boolean exportRequested = false;   // export runs in draw(), where the GL context is current
String  statusLine      = "";

final int SIDEBAR_W = 300;
final int GAP       = 10;

final int PANEL_SHELL    = 0;
final int PANEL_SCAFFOLD = 1;
final int PANEL_ASSEMBLY = 2;
final String[] PANEL_LETTERS = { "a", "b", "c" };
final String[] PANEL_FILES  = { "shell", "scaffold", "assembly" };

PGraphics[] panelBufs = new PGraphics[3];
int panelX0, panelY0, panelW, panelH;

PFont fontTitle, fontHeader, fontBody, fontLabel;

void settings() {
  size(1500, 850, P3D);
  pixelDensity(1);
  smooth(8);
}

void setup() {
  surface.setTitle("ScaffoldShell Figures");
  surface.setResizable(true);

  fontTitle  = createFont("SansSerif.bold", 15, true);
  fontHeader = createFont("SansSerif.bold", 11, true);
  fontBody   = createFont("SansSerif", 11, true);
  fontLabel  = createFont("SansSerif.bold", 32, true);   // drawn smaller; large for sharp exports

  rigs.add(new Rig(24, 24, 10, 0, 0, 8, 0));

  setupUI();
  layoutPanels();
  resetView();
  uiReady = true;
}

void draw() {
  layoutPanels();
  ShellGeometry  sg = buildShellGeometry();
  FrameGeometry  fg = buildFrameGeometry();

  if (exportRequested) {
    exportRequested = false;
    exportFigure(sg, fg);
  }

  for (int i = 0; i < 3; i++) {
    PGraphics b = panelBuffer(i);
    renderPanel(b, i, sg, fg, 1, false);
  }

  background(CLR_BG);
  camera();
  noLights();
  hint(DISABLE_DEPTH_TEST);

  for (int i = 0; i < 3; i++) {
    image(panelBufs[i], panelX(i), panelY0);
    if (showLabels) drawPanelLabel(g, panelX(i), panelY0, panelW, panelH, i, 1);
  }
  drawPanelWarnings(fg);

  if (showUI) {
    drawSidebar(fg);
    cp5.draw();
  } else {
    fill(CLR_TEXT_MUTED);
    textFont(fontBody);
    textAlign(LEFT, BOTTOM);
    text("H  show controls", GAP + 6, height - GAP - 6);
  }

  hint(ENABLE_DEPTH_TEST);
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

void layoutPanels() {
  int left  = (showUI ? SIDEBAR_W : 0) + GAP;
  int avail = width - left - GAP;
  panelW  = max(60, (avail - 2 * GAP) / 3);
  panelH  = max(60, height - 2 * GAP);
  panelX0 = left;
  panelY0 = GAP;
}

int panelX(int i) {
  return panelX0 + i * (panelW + GAP);
}

// One P3D buffer per panel, rebuilt only when the panel changes size.
PGraphics panelBuffer(int i) {
  PGraphics b = panelBufs[i];
  if (b == null || b.width != panelW || b.height != panelH) {
    if (b != null) b.dispose();
    b = createGraphics(panelW, panelH, P3D);
    b.smooth(4);
    panelBufs[i] = b;
  }
  return b;
}

// Shown on screen only -- never baked into an exported figure.
void drawPanelWarnings(FrameGeometry fg) {
  textFont(fontBody);
  textAlign(LEFT, TOP);
  for (int i = PANEL_SCAFFOLD; i <= PANEL_ASSEMBLY; i++) {
    float x = panelX(i) + 14;
    float y = panelY0 + 12;
    if (!fg.valid) {
      fill(CLR_WARN);
      text("No scaffold: " + fg.problem, x, y);
    } else if (fg.highestRigTop > fg.zTop + 0.01) {
      fill(CLR_WARN);
      text("A rig sticks out of the top of the shell", x, y);
    }
  }
}

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

void keyPressed() {
  if (key == 'h' || key == 'H') {
    showUI = !showUI;
    if (showUI) cp5.show(); else cp5.hide();
  } else if (key == 'r' || key == 'R') {
    resetView();
  } else if (key == 's' || key == 'S') {
    exportRequested = true;
  } else if (key == 'o' || key == 'O') {
    cp5.getController("orthoView").setValue(orthoView ? 0 : 1);
  }
}
