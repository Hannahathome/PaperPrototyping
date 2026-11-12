// UI.PDE - The ControlP5 sidebar
//
// Most controllers are named after the sketch field they drive (topDiameter, ...), so
// ControlP5 writes the value straight into that field. The exceptions go through
// controlEvent():
//   - integer sliders, named int_*, rounded into their int field;
//   - buttons, named btn*, so ControlP5 never auto-calls a method of the same name while the
//     UI is still being built;
//   - the rig sliders, named rig_*, which edit whichever rig is selected rather than a field.
//
// Section headers and the rig counter are not controllers: drawSidebar() paints them at the
// y positions setupUI() recorded.

final int UI_X       = 18;
final int UI_SLIDER_W = 150;
final int UI_ROW_H   = 14;
final int UI_ROW     = 20;

int uiY;                                    // layout cursor while building
ArrayList<String> headerText = new ArrayList<String>();
ArrayList<Integer> headerY   = new ArrayList<Integer>();
int rigRowY;
boolean syncingRig = false;                 // set while rig sliders are moved by code

void setupUI() {
  cp5 = new ControlP5(this);
  cp5.setAutoDraw(false);                   // drawn last in draw(), over the panels
  cp5.setFont(new ControlFont(createFont("SansSerif", 11, true), 11));
  cp5.setColorBackground(color(233, 236, 239));
  cp5.setColorForeground(color(173, 181, 189));
  cp5.setColorActive(color(73, 80, 87));
  cp5.setColorCaptionLabel(CLR_TEXT);
  cp5.setColorValueLabel(CLR_TEXT);

  uiY = 44;

  header("Shell");
  intSlider("sides", "Sides", 3, 12, sides);
  slider("topDiameter",    "Top diameter (mm)",    5, 200, 1, topDiameter);
  slider("bottomDiameter", "Bottom diameter (mm)", 5, 200, 1, bottomDiameter);
  slider("shellHeight",    "Height (mm)",          5, 200, 1, shellHeight);
  toggleRow("showTopLid", "Top lid", "showBottomLid", "Bottom lid");

  header("Scaffold");
  slider("strutRadius",  "Strut radius (mm)",  0.3, 4, 2, strutRadius);
  slider("clearance",    "Clearance (mm)",     0, 3, 2, clearance);
  slider("strutSpacing", "Strut spacing (mm)", 2, 60, 1, strutSpacing);
  slider("wallFlapLength", "Wall flap length (mm)", 0, 20, 1, wallFlapLength);
  toggleRow("dualStruts", "Two posts per rig face", null, null);

  header("Component rigs");
  rigRowY = uiY;
  button("btnAddRig",    "Add",    UI_X,       uiY, 54);
  button("btnRemoveRig", "Remove", UI_X + 60,  uiY, 64);
  button("btnPrevRig",   "<",      UI_X + 130, uiY, 24);
  button("btnNextRig",   ">",      UI_X + 158, uiY, 24);
  uiY += UI_ROW + 4;
  button("btnPreset", "Preset: Custom", UI_X, uiY, UI_SLIDER_W + 32);
  uiY += UI_ROW + 4;
  for (int j = 0; j < RIG_NPARAM; j++) {
    String unit = j == 6 ? " (deg)" : " (mm)";
    slider(RIG_PARAM_KEYS[j], RIG_PARAM_LABELS[j] + unit, RIG_PARAM_RANGE[j][0], RIG_PARAM_RANGE[j][1], 1, 0);
  }
  toggleRow("showRigBoxes", "Show component boxes", null, null);

  header("View");
  slider("overlayAlpha", "Overlay opacity", 0, 255, 0, overlayAlpha);
  slider("edgeWeight",   "Edge weight",     0.25, 4, 2, edgeWeight);
  toggleRow("orthoView", "Orthographic", "showLabels", "Panel letters");
  button("btnResetView", "Reset view (R)", UI_X, uiY, 110);
  uiY += UI_ROW + 4;

  header("Export");
  intSlider("exportScale", "PNG scale (x)", 1, 6, exportScale);
  toggleRow("transparentBg", "Transparent background", null, null);
  button("btnSavePng", "Save PNG (S)", UI_X, uiY, 110);
  uiY += UI_ROW + 4;

  syncRigControls();
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

void header(String label) {
  uiY += 10;
  headerText.add(label.toUpperCase());
  headerY.add(uiY);
  uiY += 14;
}

// value is the starting value. It has to be passed in: ControlP5 reads the linked field
// before setRange() runs, clamping it to its default 0..100 range.
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

// Integer settings. Named int_<field> so ControlP5 does not link them to the int field
// (it shows no value label when it does); controlEvent() rounds into the field instead.
Slider intSlider(String field, String label, int lo, int hi, int value) {
  return slider("int_" + field, label, lo, hi, 0, value);
}

// One or two toggles on a row, caption to the right of each box.
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

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

void controlEvent(ControlEvent e) {
  if (!uiReady || !e.isController()) return;
  String name = e.getName();

  if (name.equals("btnAddRig")) {
    if (rigs.size() < MAX_RIGS) {
      rigs.add(new Rig(24, 24, 10, 0, 0, 8, 0));
      selectedRig = rigs.size() - 1;
    }
    syncRigControls();
  } else if (name.equals("btnRemoveRig")) {
    if (!rigs.isEmpty()) rigs.remove(constrain(selectedRig, 0, rigs.size() - 1));
    syncRigControls();
  } else if (name.equals("btnPrevRig")) {
    selectedRig--;
    syncRigControls();
  } else if (name.equals("btnNextRig")) {
    selectedRig++;
    syncRigControls();
  } else if (name.equals("btnPreset")) {
    cyclePreset();
  } else if (name.equals("btnResetView")) {
    resetView();
  } else if (name.equals("btnSavePng")) {
    exportRequested = true;
  } else if (name.equals("int_sides")) {
    sides = round(e.getValue());
  } else if (name.equals("int_exportScale")) {
    exportScale = round(e.getValue());
  } else if (name.startsWith("rig_")) {
    applyRigSlider(name, e.getValue());
  }
}

void applyRigSlider(String name, float value) {
  if (syncingRig || rigs.isEmpty()) return;
  Rig r = rigs.get(selectedRig);
  for (int j = 0; j < RIG_NPARAM; j++) {
    if (!RIG_PARAM_KEYS[j].equals(name)) continue;
    if (j <= 2 && abs(r.get(j) - value) > 0.001) r.preset = "Custom";   // size edited by hand
    r.set(j, value);
  }
  updatePresetLabel();
}

// Steps the selected rig through the presets; "Custom" keeps the current size.
void cyclePreset() {
  if (rigs.isEmpty()) return;
  Rig r = rigs.get(selectedRig);
  int idx = 0;
  for (int i = 0; i < RIG_PRESET_NAMES.length; i++) if (RIG_PRESET_NAMES[i].equals(r.preset)) idx = i;
  idx = (idx + 1) % RIG_PRESET_NAMES.length;
  if (idx > 0) {
    float[] wdh = RIG_PRESET_WDH[idx - 1];
    r.w = wdh[0]; r.d = wdh[1]; r.h = wdh[2];
  }
  r.preset = RIG_PRESET_NAMES[idx];
  syncRigControls();
}

// Moves the rig sliders to the selected rig, and hides them when there is none.
void syncRigControls() {
  selectedRig = rigs.isEmpty() ? 0 : constrain(selectedRig, 0, rigs.size() - 1);
  boolean any = !rigs.isEmpty();
  syncingRig = true;
  for (int j = 0; j < RIG_NPARAM; j++) {
    Controller c = cp5.getController(RIG_PARAM_KEYS[j]);
    c.setVisible(any);
    if (any) c.setValue(rigs.get(selectedRig).get(j));
  }
  syncingRig = false;
  cp5.getController("btnPreset").setVisible(any);
  cp5.getController("btnRemoveRig").setVisible(any);
  cp5.getController("btnPrevRig").setVisible(rigs.size() > 1);
  cp5.getController("btnNextRig").setVisible(rigs.size() > 1);
  cp5.getController("btnAddRig").setVisible(rigs.size() < MAX_RIGS);
  updatePresetLabel();
}

void updatePresetLabel() {
  if (rigs.isEmpty()) return;
  cp5.getController("btnPreset").setCaptionLabel("Preset: " + rigs.get(selectedRig).preset + "  >");
}

// ---------------------------------------------------------------------------
// Sidebar painting (behind the controllers)
// ---------------------------------------------------------------------------

void drawSidebar(FrameGeometry fg) {
  pushStyle();
  noStroke();
  fill(CLR_PANEL);
  rect(0, 0, SIDEBAR_W, height);

  fill(CLR_TEXT);
  textFont(fontTitle);
  textAlign(LEFT, TOP);
  text("ScaffoldShell Figures", UI_X, 16);

  textFont(fontHeader);
  fill(CLR_TEXT_MUTED);
  for (int i = 0; i < headerText.size(); i++) text(headerText.get(i), UI_X, headerY.get(i));

  textFont(fontBody);
  textAlign(LEFT, CENTER);
  fill(CLR_TEXT);
  String rigLabel = rigs.isEmpty() ? "No rigs" : "Rig " + (selectedRig + 1) + " of " + rigs.size();
  text(rigLabel, UI_X + 192, rigRowY + (UI_ROW_H + 4) / 2);

  textAlign(LEFT, BOTTOM);
  fill(CLR_TEXT_MUTED);
  text("Drag: orbit   Right/Shift-drag: pan   Wheel: zoom\nR reset   O ortho   H hide UI   S save", UI_X, height - 30);
  if (statusLine.length() > 0) {
    fill(CLR_TEXT);
    text(statusLine, UI_X, height - 12);
  }
  popStyle();
}
