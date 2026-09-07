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

final boolean AUDIT_MODE = false;  // flip to true to re-run the sweep
String AUDIT_OUT = "docs/layout_boxes.csv";  // relative to the sketch folder
// Also save a PNG of each configuration, for eyeballing what the numbers describe.
final boolean AUDIT_SHOTS = false;
String AUDIT_SHOT_DIR = "docs/shots/";

// '|' is not a legal filename character on Windows.
String auditSafeName(String id) { return id.replace('|', '_'); }

boolean auditRecording = false;
PrintWriter auditWriter = null;
ArrayList<String> auditRows = new ArrayList<String>();

// ---- sweep plan -------------------------------------------------------
class AuditCfg {
  int w, h; String mode; int tab; boolean d3, asm, workshop;
  // Optional scenario overrides: -1 / false means "leave alone".
  int sides = -1, texTab = -1; boolean advOpen = false; String tag = "";
  AuditCfg(int _w, int _h, String _mode, int _tab, boolean _d3, boolean _asm, boolean _ws) {
    w=_w; h=_h; mode=_mode; tab=_tab; d3=_d3; asm=_asm; workshop=_ws;
  }
  AuditCfg sides(int n)      { sides = n;  return this; }
  AuditCfg texTab(int t)     { texTab = t; return this; }
  AuditCfg adv(boolean o)    { advOpen = o; return this; }
  AuditCfg tag(String t)     { tag = t;    return this; }
  String id() { return w + "x" + h + "|" + mode + "|tab" + tab + (tag.length() > 0 ? "|" + tag : ""); }
}
ArrayList<AuditCfg> auditPlan = new ArrayList<AuditCfg>();
int auditCfgIdx = 0;
int auditSettle = 0;
final int AUDIT_SETTLE_FRAMES = 12;  // a resize can take several frames to land

// Wrapping handleDraw() rather than registerMethod(): Processing inner classes are not
// public, so reflection-based hooks cannot reach them.
public void handleDraw() {
  if (AUDIT_MODE) auditPre();
  super.handleDraw();
  if (AUDIT_MODE) auditPost();
  if (AUDIT_CLICK_TEST && frameCount > 0) clickTestTick();
}

// --- Click-routing test ------------------------------------------------------------
// The bounding-box sweep proves where things are DRAWN. It cannot prove a click reaches
// them: mousePressed() runs canvas-space picks before the UI checks, and one of those
// swallowing the click looks identical in the geometry data. That is exactly how the
// "buttons stop working after a resize" bug hid from the sweep. This drives the real
// dispatcher at the centre of known targets and checks the expected thing happened.
final boolean AUDIT_CLICK_TEST = false;  // flip to true to run it
int clickTestSize = 0, clickTestFrame = 0, clickFails = 0, clickChecks = 0;
int[][] CLICK_SIZES = { {1500,800}, {1180,980}, {1000,700}, {1920,1080}, {2560,1440} };

void clickAt(float mx, float my) {
  mouseX = int(mx);
  mouseY = int(my);
  mousePressed();          // the sketch's own dispatcher, not the boolean field
}

void clickExpect(String what, boolean ok) {
  clickChecks++;
  if (!ok) { clickFails++; println("      FAIL  " + what); }
}

// Controls in the bottom bar belong to ControlP5, which handles its own mouse events, so
// calling the sketch's mousePressed() proves nothing about them. Post real events instead and
// let Processing deliver them the way it delivers a user's click. ControlP5 decides what is
// hovered while it draws, so the move, press and release each need their own frame.
void cp5PostMouse(int action, float mx, float my) {
  mouseX = int(mx);
  mouseY = int(my);
  postEvent(new processing.event.MouseEvent(null, millis(), action, 0, int(mx), int(my), LEFT, 1));
}

boolean cp5Before = false;

void clickTestTick() {
  if (clickTestSize >= CLICK_SIZES.length) return;
  clickTestFrame++;
  if (clickTestFrame == 5) {
    surface.setSize(CLICK_SIZES[clickTestSize][0], CLICK_SIZES[clickTestSize][1]);
    return;
  }

  // The bottom bar is the case that broke when the window was maximised: ControlP5 clamps its
  // hit-testing to the size it was built at, so controls below that height stopped responding.
  if (tShowDistances != null) {
    float[] p = tShowDistances.getPosition();
    float cx = p[0] + tShowDistances.getWidth() / 2;
    float cy = p[1] + tShowDistances.getHeight() / 2;
    if (clickTestFrame == 30) { cp5Before = tShowDistances.getState();
                                cp5PostMouse(processing.event.MouseEvent.MOVE, cx, cy);    return; }
    if (clickTestFrame == 33) { cp5PostMouse(processing.event.MouseEvent.PRESS, cx, cy);   return; }
    if (clickTestFrame == 36) { cp5PostMouse(processing.event.MouseEvent.RELEASE, cx, cy); return; }
    if (clickTestFrame == 39) {
      clickExpect("bottom bar DISTANCES toggle (ControlP5)", tShowDistances.getState() != cp5Before);
      tShowDistances.setValue(cp5Before ? 1 : 0);
      return;
    }
  }

  if (clickTestFrame < 45) return;

  println("[CLICK] " + width + "x" + height);

  int restoreTab = sidebar.activeMainTab;

  // Sidebar main tabs: click each one and check the selection followed.
  for (int i = 0; i < sidebar.mainTabs.size(); i++) {
    SidebarButton t = sidebar.mainTabs.get(i);
    clickAt(t.x + t.w / 2, t.y + t.h / 2);
    clickExpect("main tab " + i + " at (" + mouseX + "," + mouseY + ")", sidebar.activeMainTab == i);
  }

  // Toolbar: the Info button toggles its dropdown.
  if (toolbar != null && toolbar.dimensionsBtn != null) {
    boolean before = toolbar.dropdownOpen;
    ToolbarButton d = toolbar.dimensionsBtn;
    clickAt(d.x + d.w / 2, d.y + d.h / 2);
    clickExpect("toolbar Info button", toolbar.dropdownOpen != before);
    toolbar.dropdownOpen = before;
  }

  // Shape tab: the Advanced options disclosure and the Reset action.
  sidebar.activeMainTab = 0;
  updateSidebarControlsVisibility();

  boolean advBefore = advancedOpen;
  float[] ar = sidebar.advancedHeaderRect();
  clickAt(ar[0] + ar[2] / 2, ar[1] + ar[3] / 2);
  clickExpect("advanced options disclosure", advancedOpen != advBefore);
  advancedOpen = advBefore;
  updateSidebarControlsVisibility();

  uiTopW = 55;
  float[] rr = sidebar.shapeActionBtnRect(0);
  clickAt(rr[0] + rr[2] / 2, rr[1] + rr[3] / 2);
  clickExpect("Reset to default button", abs(uiTopW - 30) < 0.01);

  sidebar.activeMainTab = restoreTab;
  updateSidebarControlsVisibility();

  clickTestSize++;
  clickTestFrame = 0;
  if (clickTestSize >= CLICK_SIZES.length) {
    println("[CLICK] " + (clickChecks - clickFails) + "/" + clickChecks + " checks passed"
      + (clickFails == 0 ? "" : "  <-- " + clickFails + " FAILED"));
    exit();
  }
}

void auditInit() {
  surface.setResizable(true);
  // The current fixed size, two common laptop sizes, and 1080p / 1440p full screen.
  int[][] sizes = { {1000,700}, {1100,720}, {1280,720}, {1366,768}, {1500,800}, {1920,1080}, {2560,1440} };
  for (int si = 0; si < sizes.length; si++) {
    int sw = sizes[si][0], sh = sizes[si][1];
    for (int t = 0; t < 3; t++) auditPlan.add(new AuditCfg(sw, sh, "2D", t, false, false, false));
    for (int t = 0; t < 3; t++) auditPlan.add(new AuditCfg(sw, sh, "3D", t, true,  false, false));
    auditPlan.add(new AuditCfg(sw, sh, "ASSEMBLY", 3, true,  true,  false));
    auditPlan.add(new AuditCfg(sw, sh, "WORKSHOP", 0, false, false, true));
    // Scenarios the plain size sweep does not reach.
    auditPlan.add(new AuditCfg(sw, sh, "2D", 0, false, false, false).adv(true).tag("advopen"));
    auditPlan.add(new AuditCfg(sw, sh, "2D", 1, false, false, false).sides(14).texTab(0).tag("panels14"));
    auditPlan.add(new AuditCfg(sw, sh, "2D", 1, false, false, false).texTab(2).tag("tracking"));
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
  if (c.sides > 0 && sNSides != null) sNSides.setValue(c.sides);
  // Go through the click handler, not the field: the selection is per-shape state that has to
  // be written back to the ShapeSpec or loadGlobalsFrom() undoes it.
  if (c.texTab >= 0 && sidebar != null) sidebar.handleTextureTabClick("texture_tab_" + c.texTab);
  advancedOpen = c.advOpen;
  relayout();   // the sketch's own single layout entry point
}

void auditPre() {
  if (auditCfgIdx >= auditPlan.size()) return;
  AuditCfg c = auditPlan.get(auditCfgIdx);
  if (auditSettle == 0) auditApplyCfg(c);
  auditSettle++;
  auditRecording = (auditSettle > AUDIT_SETTLE_FRAMES);
  if (auditRecording) {
    auditRows.clear();
    auditFrameW = width;    // remember what the frame is being DRAWN at
    auditFrameH = height;
  }
}

// The size the recorded frame was drawn at. A resize can land between pre and post, which
// would pair boxes drawn at the old size with regions measured at the new one and report
// full-bleed backgrounds as hanging off the window.
int auditFrameW = 0, auditFrameH = 0;

void auditPost() {
  if (auditCfgIdx >= auditPlan.size()) return;
  if (!auditRecording) return;
  if (width != auditFrameW || height != auditFrameH) {
    // The window changed size mid-frame; this capture would be internally inconsistent.
    auditRecording = false;
    auditSettle = AUDIT_SETTLE_FRAMES;   // re-record on the next frame
    return;
  }
  AuditCfg c = auditPlan.get(auditCfgIdx);
  auditRecordControlP5();
  auditRecordRegions();
  // Record the size the window ACTUALLY ended up at, not the size that was asked for --
  // the OS does not always grant the request exactly, and comparing boxes against the
  // request makes correctly-drawn full-bleed panels look like they hang off the window.
  String prefix = c.id() + "," + auditFrameW + "," + auditFrameH + "," + c.mode + "," + c.tab + ",";
  for (int i = 0; i < auditRows.size(); i++) auditWriter.println(prefix + auditRows.get(i));
  auditWriter.flush();
  println("[AUDIT] " + c.id() + " -> " + auditRows.size() + " boxes");
  if (AUDIT_SHOTS) save(AUDIT_SHOT_DIR + auditSafeName(c.id()) + ".png");
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
