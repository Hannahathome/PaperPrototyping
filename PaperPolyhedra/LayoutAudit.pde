//----------------------------------------------------------------------
// LayoutAudit.pde - TEMPORARY measurement harness (branch: fullscreen-responsive-ui)
//
// Records the screen-space bounding box of every UI element that is drawn, so we can
// answer two questions with numbers instead of guesses:
//   1. how much space does each panel / widget actually occupy?
//   2. what overlaps, or falls outside the window, at a given window size?
//
// It works by overriding PApplet rect()/text()/image() inside the sketch class, so no
// existing draw code has to be touched. ControlP5 draws into its own graphics, so those
// widgets are enumerated separately through the cp5 API.
//
// Enable with AUDIT_MODE = true, then run the sketch: it sweeps a set of
// (window size x mode x sidebar tab) configurations, writes one CSV row per box, and exits.
//----------------------------------------------------------------------

final boolean AUDIT_MODE = false;   // flip to true to re-run the sweep
String AUDIT_OUT = "docs/layout_boxes.csv";  // relative to the sketch folder

boolean auditRecording = false;
PrintWriter auditWriter = null;
ArrayList<String> auditRows = new ArrayList<String>();

// ---- sweep plan -------------------------------------------------------
class AuditCfg {
  int w, h; String mode; int tab; boolean d3, asm, workshop;
  AuditCfg(int _w, int _h, String _mode, int _tab, boolean _d3, boolean _asm, boolean _ws) {
    w=_w; h=_h; mode=_mode; tab=_tab; d3=_d3; asm=_asm; workshop=_ws;
  }
  String id() { return w + "x" + h + "|" + mode + "|tab" + tab; }
}
ArrayList<AuditCfg> auditPlan = new ArrayList<AuditCfg>();
int auditCfgIdx = 0;
int auditSettle = 0;
final int AUDIT_SETTLE_FRAMES = 5;

// Wrapping handleDraw() rather than registerMethod(): Processing inner classes are not
// public, so reflection-based hooks cannot reach them.
public void handleDraw() {
  if (AUDIT_MODE) auditPre();
  super.handleDraw();
  if (AUDIT_MODE) auditPost();
}

void auditInit() {
  surface.setResizable(true);
  // The current fixed size, two common laptop sizes, and 1080p / 1440p full screen.
  int[][] sizes = { {1500,800}, {1280,720}, {1366,768}, {1920,1080}, {2560,1440} };
  for (int si = 0; si < sizes.length; si++) {
    int sw = sizes[si][0], sh = sizes[si][1];
    for (int t = 0; t < 3; t++) auditPlan.add(new AuditCfg(sw, sh, "2D", t, false, false, false));
    for (int t = 0; t < 3; t++) auditPlan.add(new AuditCfg(sw, sh, "3D", t, true,  false, false));
    auditPlan.add(new AuditCfg(sw, sh, "ASSEMBLY", 3, true,  true,  false));
    auditPlan.add(new AuditCfg(sw, sh, "WORKSHOP", 0, false, false, true));
  }
  auditWriter = createWriter(AUDIT_OUT);
  auditWriter.println("config,win_w,win_h,mode,tab,kind,source,label,x,y,w,h,visible");
  println("[AUDIT] " + auditPlan.size() + " configurations queued -> " + AUDIT_OUT);
}

void auditApplyCfg(AuditCfg c) {
  if (width != c.w || height != c.h) surface.setSize(c.w, c.h);
  view3DMode   = c.d3;
  workshopMode = c.workshop;
  assemblyMode = c.asm;
  assemblyShowTemplate = false;
  if (sidebar != null) {
    sidebar.activeMainTab = constrain(c.tab, 0, c.asm ? 3 : 2);
    sidebar.mainTabs.clear();
    sidebar.setupMainTabs();
  }
  if (toolbar != null) toolbar.setup();
  updateSidebarControlsVisibility();
  updateExportControlPositions();
}

void auditPre() {
  if (auditCfgIdx >= auditPlan.size()) return;
  AuditCfg c = auditPlan.get(auditCfgIdx);
  if (auditSettle == 0) auditApplyCfg(c);
  auditSettle++;
  auditRecording = (auditSettle > AUDIT_SETTLE_FRAMES);
  if (auditRecording) auditRows.clear();
}

void auditPost() {
  if (auditCfgIdx >= auditPlan.size()) return;
  if (!auditRecording) return;
  AuditCfg c = auditPlan.get(auditCfgIdx);
  auditRecordControlP5();
  auditRecordRegions();
  String prefix = c.id() + "," + c.w + "," + c.h + "," + c.mode + "," + c.tab + ",";
  for (int i = 0; i < auditRows.size(); i++) auditWriter.println(prefix + auditRows.get(i));
  auditWriter.flush();
  println("[AUDIT] " + c.id() + " -> " + auditRows.size() + " boxes");
  auditRecording = false;
  auditSettle = 0;
  auditCfgIdx++;
  if (auditCfgIdx >= auditPlan.size()) {
    auditWriter.flush();
    auditWriter.close();
    println("[AUDIT] done.");
    exit();
  }
}

// ---- recording --------------------------------------------------------
String auditEsc(String s) {
  if (s == null) return "\"\"";
  String t = s.replace('"', '\'').replace('\n', ' ').replace(',', ';');
  return "\"" + t + "\"";
}

void auditBox(String kind, String source, String label, float bx, float by, float bw, float bh, boolean vis) {
  // nf() honours the system locale and emits a decimal comma on this machine, which would
  // break the CSV — format explicitly in US locale instead.
  auditRows.add(kind + "," + auditEsc(source) + "," + auditEsc(label) + ","
    + auditNum(bx) + "," + auditNum(by) + "," + auditNum(bw) + "," + auditNum(bh) + "," + vis);
}

String auditNum(float v) {
  return String.format(java.util.Locale.US, "%.2f", v);
}

// Caller of the overridden primitive, so each box is attributed to the function that drew it.
String auditCaller() {
  StackTraceElement[] st = Thread.currentThread().getStackTrace();
  for (int i = 3; i < st.length; i++) {
    String m = st[i].getMethodName();
    if (m.equals("auditCaller") || m.equals("auditShape") || m.equals("rect")
     || m.equals("text") || m.equals("image")) continue;
    return st[i].getClassName().replace("PaperPolyhedra$", "") + "." + m;
  }
  return "?";
}

// Map a model-space rect through the current matrix into screen space.
void auditShape(String kind, float x1, float y1, float x2, float y2) {
  float sx1 = screenX(x1, y1), sy1 = screenY(x1, y1);
  float sx2 = screenX(x2, y2), sy2 = screenY(x2, y2);
  float bx = min(sx1, sx2), by = min(sy1, sy2);
  auditBox(kind, auditCaller(), "", bx, by, abs(sx2-sx1), abs(sy2-sy1), true);
}

float[] _auditCorners = new float[4];

void auditRectCorners(float a, float b, float c, float d) {
  int m = g.rectMode;
  if (m == CORNERS)     { _auditCorners[0]=a;     _auditCorners[1]=b;     _auditCorners[2]=c;     _auditCorners[3]=d; }
  else if (m == RADIUS) { _auditCorners[0]=a-c;   _auditCorners[1]=b-d;   _auditCorners[2]=a+c;   _auditCorners[3]=b+d; }
  else if (m == CENTER) { _auditCorners[0]=a-c/2; _auditCorners[1]=b-d/2; _auditCorners[2]=a+c/2; _auditCorners[3]=b+d/2; }
  else                  { _auditCorners[0]=a;     _auditCorners[1]=b;     _auditCorners[2]=a+c;   _auditCorners[3]=b+d; }
}

void rect(float a, float b, float c, float d) {
  if (auditRecording) { auditRectCorners(a,b,c,d);
    auditShape("rect", _auditCorners[0], _auditCorners[1], _auditCorners[2], _auditCorners[3]); }
  super.rect(a, b, c, d);
}

void rect(float a, float b, float c, float d, float r) {
  if (auditRecording) { auditRectCorners(a,b,c,d);
    auditShape("rect", _auditCorners[0], _auditCorners[1], _auditCorners[2], _auditCorners[3]); }
  super.rect(a, b, c, d, r);
}

void image(PImage img, float a, float b) {
  if (auditRecording && img != null) auditShape("image", a, b, a + img.width, b + img.height);
  super.image(img, a, b);
}

void image(PImage img, float a, float b, float c, float d) {
  if (auditRecording) { auditRectCorners(a,b,c,d);
    auditShape("image", _auditCorners[0], _auditCorners[1], _auditCorners[2], _auditCorners[3]); }
  super.image(img, a, b, c, d);
}

void text(String s, float x, float y) {
  if (auditRecording && s != null && s.length() > 0) {
    float tw = textWidth(s), asc = textAscent(), dsc = textDescent();
    float x1 = x, y1 = y - asc, x2 = x + tw, y2 = y + dsc;
    if (g.textAlign == CENTER)      { x1 = x - tw/2; x2 = x + tw/2; }
    else if (g.textAlign == RIGHT)  { x1 = x - tw;   x2 = x; }
    if (g.textAlignY == CENTER)     { y1 = y - (asc+dsc)/2; y2 = y + (asc+dsc)/2; }
    else if (g.textAlignY == TOP)   { y1 = y;               y2 = y + asc + dsc; }
    else if (g.textAlignY == BOTTOM){ y1 = y - asc - dsc;   y2 = y; }
    float sx1 = screenX(x1,y1), sy1 = screenY(x1,y1);
    float sx2 = screenX(x2,y2), sy2 = screenY(x2,y2);
    auditBox("text", auditCaller(), s, min(sx1,sx2), min(sy1,sy2), abs(sx2-sx1), abs(sy2-sy1), true);
  }
  super.text(s, x, y);
}

// ---- ControlP5 widgets -------------------------------------------------
void auditRecordControlP5() {
  if (cp5__prism == null) return;
  java.util.List<controlP5.ControllerInterface<?>> all = cp5__prism.getAll();
  for (int i = 0; i < all.size(); i++) {
    controlP5.ControllerInterface<?> ci = all.get(i);
    try {
      // getAbsolutePosition() reports accumulated nonsense for top-level controllers in this
      // ControlP5 build; getPosition() is what the sketch actually sets, so record both and
      // trust getPosition().
      float[] rp = ci.getPosition();
      float[] ap = ci.getAbsolutePosition();
      auditBox("cp5", ci.getClass().getSimpleName(), ci.getName(),
               rp[0], rp[1], ci.getWidth(), ci.getHeight(), ci.isVisible());
      auditBox("cp5abs", ci.getClass().getSimpleName(), ci.getName(),
               ap[0], ap[1], ci.getWidth(), ci.getHeight(), ci.isVisible());
    } catch (Exception e) { /* groups / labels without geometry */ }
  }
}

// ---- static regions ----------------------------------------------------
void auditRecordRegions() {
  auditBox("region", "window",    "window",        0, 0, width, height, true);
  auditBox("region", "toolbar",   "TOOLBAR",       0, 0, width, TOOLBAR_HEIGHT, true);
  auditBox("region", "sidebar",   "LEFT_SIDEBAR",  0, TOOLBAR_HEIGHT, LEFT_SIDEBAR_WIDTH, height - TOOLBAR_HEIGHT, true);
  auditBox("region", "exportbar", "BOTTOM_EXPORT", LEFT_SIDEBAR_WIDTH, height - BOTTOM_EXPORT_HEIGHT,
           width - LEFT_SIDEBAR_WIDTH, BOTTOM_EXPORT_HEIGHT, true);
  auditBox("region", "canvas",    "CANVAS_AREA",   LEFT_SIDEBAR_WIDTH, TOOLBAR_HEIGHT,
           width - LEFT_SIDEBAR_WIDTH, height - TOOLBAR_HEIGHT - BOTTOM_EXPORT_HEIGHT, true);
  auditBox("region", "page",      "PAGE_DISPLAY",  canvasOffsetX, canvasOffsetY, widthA4_display, heightA4_display, true);
  if (view3DBuffer != null)
    auditBox("region", "buf3d",   "VIEW3D_BUFFER", LEFT_SIDEBAR_WIDTH, TOOLBAR_HEIGHT, view3DBuffer.width, view3DBuffer.height, true);
  if (showMini3DView && mini3DBuffer != null)
    auditBox("region", "mini3d",  "MINI_3D",       width - MINI_3D_WIDTH - MINI_3D_MARGIN,
             height - BOTTOM_EXPORT_HEIGHT - MINI_3D_HEIGHT - MINI_3D_MARGIN, MINI_3D_WIDTH, MINI_3D_HEIGHT, true);
}
