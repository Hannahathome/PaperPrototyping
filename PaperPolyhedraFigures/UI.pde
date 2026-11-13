// UI.PDE - The ControlP5 sidebar
//
// As in ScaffoldShellFigures: most controllers are named after the sketch field they drive,
// so ControlP5 writes the value straight into it. Integer sliders are named int_* and
// rounded into their field by controlEvent(); buttons are named btn*.
//
// Section headers are not controllers: drawSidebar() paints them where setupUI() put them.

final int UI_X        = 18;
final int UI_SLIDER_W = 150;
final int UI_ROW_H    = 14;
final int UI_ROW      = 20;

int uiY;
ArrayList<String> headerText = new ArrayList<String>();
ArrayList<Integer> headerY   = new ArrayList<Integer>();

void setupUI() {
  cp5 = new ControlP5(this);
  cp5.setAutoDraw(false);
  cp5.setFont(new ControlFont(createFont("SansSerif", 11, true), 11));
  cp5.setColorBackground(color(233, 236, 239));
  cp5.setColorForeground(color(173, 181, 189));
  cp5.setColorActive(color(73, 80, 87));
  cp5.setColorCaptionLabel(CLR_TEXT);
  cp5.setColorValueLabel(CLR_TEXT);

  uiY = 44;

  header("Shape");
  intSlider("sides", "Sides", 3, 20, sides);
  slider("topDiameter",    "Top diameter (mm)",    5, 200, 1, topDiameter);
  slider("bottomDiameter", "Bottom diameter (mm)", 5, 200, 1, bottomDiameter);
  slider("shellHeight",    "Height (mm)",          5, 200, 1, shellHeight);
  toggleRow("splitStrip", "Split strip in half", null, null);

  header("Tabs and flaps");
  slider("tabDepth",     "Tab depth (mm)",  0, 50, 1, tabDepth);
  slider("tabNeckRatio", "Tab neck ratio",  0.2, 1.5, 2, tabNeckRatio);
  slider("flapDepth",    "Flap depth (mm)", 0, 50, 1, flapDepth);
  slider("flapTaper",    "Flap taper (mm)", 0, 50, 1, flapTaper);

  header("View");
  toggleRow("showDimensions", "Dimensions (D)", "showFrames", "Close-up frames");
  toggleRow("showNotes", "Notes (N)", "showLegend", "Legend");
  toggleRow("showLabels", "Panel letters", null, null);
  slider("lineWeight", "Line weight", 0.25, 4, 2, lineWeight);

  header("Export");
  intSlider("exportScale", "PNG scale (x)", 1, 6, exportScale);
  toggleRow("transparentBg", "Transparent background", null, null);
  button("btnSavePng", "Save PNG (S)", UI_X, uiY, 110);
  uiY += UI_ROW + 4;
}

void header(String label) {
  uiY += 10;
  headerText.add(label.toUpperCase());
  headerY.add(uiY);
  uiY += 14;
}

// value is the starting value: ControlP5 reads the linked field before setRange() runs,
// clamping it to its default 0..100 range.
Slider slider(String name, String label, float lo, float hi, int decimals, float value) {
  Slider s = cp5.addSlider(name)
    .setPosition(UI_X, uiY)
    .setSize(UI_SLIDER_W, UI_ROW_H)
    .setRange(lo, hi)
    .setDecimalPrecision(decimals)
    .setValue(value)
    .setCaptionLabel(label);
  s.getCaptionLabel().toUpperCase(false).setPaddingX(6);
  uiY += UI_ROW;
  return s;
}

Slider intSlider(String field, String label, int lo, int hi, int value) {
  return slider("int_" + field, label, lo, hi, 0, value);
}

void toggleRow(String a, String aLabel, String b, String bLabel) {
  toggle(a, aLabel, UI_X);
  if (b != null) toggle(b, bLabel, UI_X + 130);
  uiY += UI_ROW + 2;
}

void toggle(String name, String label, int x) {
  Toggle t = cp5.addToggle(name)
    .setPosition(x, uiY)
    .setSize(UI_ROW_H, UI_ROW_H)
    .setCaptionLabel(label);
  t.getCaptionLabel().toUpperCase(false).align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(6);
}

void button(String name, String label, int x, int y, int w) {
  cp5.addButton(name)
    .setPosition(x, y)
    .setSize(w, UI_ROW_H + 4)
    .setCaptionLabel(label)
    .getCaptionLabel().toUpperCase(false);
}

void controlEvent(ControlEvent e) {
  if (!uiReady || !e.isController()) return;
  String name = e.getName();
  if (name.equals("btnSavePng")) {
    exportRequested = true;
  } else if (name.equals("int_sides")) {
    sides = round(e.getValue());
  } else if (name.equals("int_exportScale")) {
    exportScale = round(e.getValue());
  }
}

void drawSidebar(Template tp) {
  pushStyle();
  noStroke();
  fill(CLR_PANEL);
  rect(0, 0, SIDEBAR_W, height);

  fill(CLR_TEXT);
  textFont(fontTitle);
  textAlign(LEFT, TOP);
  text("PaperPolyhedra Figures", UI_X, 16);

  textFont(fontHeader);
  fill(CLR_TEXT_MUTED);
  for (int i = 0; i < headerText.size(); i++) text(headerText.get(i), UI_X, headerY.get(i));

  textFont(fontBody);
  textAlign(LEFT, BOTTOM);
  fill(CLR_TEXT_MUTED);
  text("Wheel over a close-up: zoom   Drag: pan\nR reset zoom  D dims  N notes  H hide UI  S save", UI_X, height - 30);
  if (statusLine.length() > 0) {
    fill(CLR_TEXT);
    text(statusLine, UI_X, height - 12);
  }
  popStyle();
}
