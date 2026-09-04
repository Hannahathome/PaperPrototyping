import java.io.PrintWriter;
import java.util.Arrays;
import controlP5.*;

// --- GLOBAL FRUSTUM PARAMETERS (shown in both modes) ---
// [nside, bottom_radius, top_radius, height, edge_radius]
float[] globalParams = {8, 20, 25, 40, 1};
String[] globalLabels = {
  "frustum_nside", "frustum_bottom_radius", "frustum_top_radius",
  "frustum_height", "edge_radius"
};
final int NGLOBAL = 5;

// --- PER-RIG PARAMETERS ---
String[] rigLabels = {
  "cuboid_width", "cuboid_depth", "cuboid_height",
  "cuboid_offset_x", "cuboid_offset_y", "cuboid_offset_z", "cuboid_rotation"
};
final int NRIG = 7;
final int NBOX = NGLOBAL + NRIG;   // 12 numberboxes total

// --- EMBEDDED ELECTRONICS TEMPLATES ---
// Preset cuboid footprints (W, D, H in mm). templateWDH[k] pairs with
// templateItems[k + 1]; item 0 ("Custom") applies nothing.
String[] templateItems = { "Custom", "M5Atom","M5Atom_lying","M5Core","M5Core_lying","M5Core+Ext","M5Core+Ext_lying"};
float[][] templateWDH  = {
  {24, 24, 31.5},   // M5Atom standing
  {24, 31.5, 24},   // M5Atom lying
  {54, 17, 54},     // M5Core standing
  {54, 54, 17},     // M5Core lying 
  {54, 21, 54},      // M5Core+Ext standing
  {54, 54, 21}      // M5Core+Ext lying
};

// --- INTERNAL RIG MODEL ---
class Rig {
  float w, d, h, offX, offY, offZ, rot;   // rot = yaw degrees about Z, around (offX, offY)
  String template = "Custom";
  Rig(float w, float d, float h, float ox, float oy, float oz, float rot) {
    this.w = w; this.d = d; this.h = h;
    this.offX = ox; this.offY = oy; this.offZ = oz; this.rot = rot;
  }
  float get(int j) {
    switch (j) {
      case 0: return w;    case 1: return d;    case 2: return h;
      case 3: return offX; case 4: return offY; case 5: return offZ;
      default: return rot;
    }
  }
  void set(int j, float v) {
    switch (j) {
      case 0: w = v; break;    case 1: d = v; break;    case 2: h = v; break;
      case 3: offX = v; break; case 4: offY = v; break; case 5: offZ = v; break;
      default: rot = v; break;
    }
  }
}
ArrayList<Rig> rigs = new ArrayList<Rig>();
int selectedRig = 0;

// State trackers (change detection)
float[] oldGlobal = new float[NGLOBAL];
float[] oldRig = new float[NRIG];

// Geometry Containers
PVector[] vertices;
ArrayList<int[]> edges = new ArrayList<int[]>();
ArrayList<PVector[]> bottom_cross_spokes = new ArrayList<PVector[]>();
ArrayList<PVector[]> rig_supports = new ArrayList<PVector[]>();          // all posts, all rigs
ArrayList<PVector[]> rig_bottom_connectors = new ArrayList<PVector[]>(); // spine-base -> post-base
ArrayList<PVector[]> rig_spines = new ArrayList<PVector[]>();            // spine start -> box under-side
ArrayList<PVector[]> rig_base_links = new ArrayList<PVector[]>();        // frustum centre -> spine start
ArrayList<float[]> rig_boxes = new ArrayList<float[]>();                 // [cx, cy, cz, w, d, h, rotDeg]

float z_bottom;
float height, bottom_radius, top_radius;

// --- DYNAMIC CAMERA ANCHORS ---
float targetX, targetY, targetZ;
float camRadius = 90;

// Configured base values to make the 3D model look oriented upward initially
float defaultRotX = -PI/3;
float defaultRotY = 0;
float rotX = defaultRotX;
float rotY = defaultRotY;

// GUI Elements
ControlP5 cp5;
Toggle cuboidToggle;
ScrollableList templateList;
Textlabel templateHeader;
ScrollableList rigList;
Textlabel rigHeader;
Textfield filenameTf;
Button saveBtn, resetBtn;
Toggle dualStrutToggle;
Numberbox strutSpacingBox;
String exportFilename = "model.scad";
boolean cuboidEnabled = true;

// Extra pair of support struts around each rig (offset by strutSpacing).
boolean dualStruts = false;   // false = single post per face, true = two posts per face
float strutSpacing = 15;      // gap (mm) between the two posts on each face

// Wedge flap length (mm) baked into every exported .scad; editable in OpenSCAD.
final float FLAP_LENGTH = 8;

// Layout anchors used when repositioning the bottom controls per mode
final int gUIX = 20;
int gSimpleBottomY, gFullBottomY;

void setup() {
  size(1050, 760, P3D);
  smooth(8);

  // Start with a single default rig (matching the previous single cuboid)
  rigs.add(new Rig(24, 24, 31.5, 0, 0, 8.5, 0));
  selectedRig = 0;

  arrayCopy(globalParams, oldGlobal);
  for (int j = 0; j < NRIG; j++) oldRig[j] = rigs.get(0).get(j);

  calculateGeometry();

  // --- CONTROLP5 UI INITIALIZATION ---
  cp5 = new ControlP5(this);
  cp5.setAutoInitialization(false);

  int uiX = gUIX;
  int uiY = 30;
  int spacing = 38;
  PFont labelFont = createFont("sans-serif", 10);

  int toggleY      = uiY + NGLOBAL * spacing + 8;
  int rigRowY      = toggleY + 44;
  int templateY    = rigRowY + 44;
  int rigParamsTop = templateY + 40;
  int strutRowY    = rigParamsTop + NRIG * spacing + 8;   // dual-strut toggle + spacing
  gFullBottomY     = strutRowY + 40;
  gSimpleBottomY   = toggleY + 40;

  // 1. Generate parameter fields (5 global + 7 rig = 12), each with a typing box
  for (int i = 0; i < NBOX; i++) {
    int y = (i < NGLOBAL) ? (uiY + i * spacing)
                          : (rigParamsTop + (i - NGLOBAL) * spacing);

    Numberbox nb = cp5.addNumberbox("param_" + i)
       .setPosition(uiX, y)
       .setSize(130, 20)
       .setValue(currentValue(i));

    nb.getCaptionLabel().getStyle().setMarginLeft(-1);
    nb.getCaptionLabel().getStyle().setMarginTop(-31);
    nb.getCaptionLabel().setFont(labelFont);
    nb.getCaptionLabel().setColor(color(180, 185, 195));

    // Typeable input box next to each numberbox (press ENTER to apply)
    Textfield tf = cp5.addTextfield("input_" + i)
       .setPosition(uiX + 138, y)
       .setSize(60, 20)
       .setText(formatParam(i, currentValue(i)))
       .setAutoClear(false)
       .setLabel("");
    tf.getValueLabel().setFont(labelFont);
  }

  // 2. Simple <-> full mode toggle
  cuboidToggle = cp5.addToggle("cuboid_enabled")
     .setPosition(uiX, toggleY)
     .setSize(50, 20)
     .setValue(true)
     .setMode(Toggle.SWITCH)
     .setLabel("ENABLE CUBOID RIG")
     .setColorLabel(color(180, 185, 195));
  cuboidToggle.getCaptionLabel().getStyle().setMarginLeft(58).setMarginTop(-17);
  cuboidToggle.getCaptionLabel().setFont(labelFont);

  // 2a. Internal-rig selector + add / remove
  rigHeader = cp5.addTextlabel("rigHeader", "INTERNAL RIG", uiX, rigRowY - 14);
  rigList = cp5.addScrollableList("rigSelector")
     .setPosition(uiX, rigRowY)
     .setSize(90, 120)
     .setBarHeight(20)
     .setItemHeight(20)
     .setType(ScrollableList.DROPDOWN)
     .setOpen(false);
  rigList.getCaptionLabel().setFont(labelFont);
  rigList.getValueLabel().setFont(labelFont);
  cp5.addButton("addRigButton").setPosition(uiX + 96, rigRowY).setSize(28, 20).setLabel("+")
     .getCaptionLabel().setFont(labelFont);
  cp5.addButton("removeRigButton").setPosition(uiX + 128, rigRowY).setSize(28, 20).setLabel("-")
     .getCaptionLabel().setFont(labelFont);

  // 2b. Electronics template dropdown (applies to the selected rig)
  templateHeader = cp5.addTextlabel("templateHeader", "ELECTRONICS TEMPLATE", uiX, templateY - 14);
  templateList = cp5.addScrollableList("templateSelector")
     .setPosition(uiX, templateY)
     .setSize(130, 100)
     .setBarHeight(20)
     .setItemHeight(20)
     .setType(ScrollableList.DROPDOWN)
     .addItems(Arrays.asList(templateItems))
     .setOpen(false)
     .setLabel("Custom");
  templateList.getCaptionLabel().setFont(labelFont);
  templateList.getValueLabel().setFont(labelFont);

  // 2c. Extra support struts around each rig (two posts per face)
  dualStrutToggle = cp5.addToggle("dual_struts")
     .setPosition(uiX, strutRowY)
     .setSize(50, 20)
     .setValue(dualStruts)
     .setMode(Toggle.SWITCH)
     .setLabel("DUAL STRUTS")
     .setColorLabel(color(180, 185, 195));
  dualStrutToggle.getCaptionLabel().getStyle().setMarginLeft(58).setMarginTop(-17);
  dualStrutToggle.getCaptionLabel().setFont(labelFont);

  strutSpacingBox = cp5.addNumberbox("strut_spacing_box")
     .setPosition(uiX + 138, strutRowY)
     .setSize(60, 20)
     .setValue(strutSpacing)
     .setMultiplier(0.5)
     .setDecimalPrecision(1)
     .setMin(0)
     .setLabel("STRUT SPACING (mm)");
  strutSpacingBox.getCaptionLabel().getStyle().setMarginLeft(-1).setMarginTop(-31);
  strutSpacingBox.getCaptionLabel().setFont(labelFont);
  strutSpacingBox.getCaptionLabel().setColor(color(180, 185, 195));

  // 3. Export filename field
  filenameTf = cp5.addTextfield("filenameField")
     .setPosition(uiX, gFullBottomY)
     .setSize(130, 20)
     .setText(exportFilename)
     .setLabel("EXPORT FILENAME")
     .setAutoClear(false);
  filenameTf.getCaptionLabel().getStyle().setMarginTop(-31).setMarginLeft(-1);
  filenameTf.getCaptionLabel().setFont(labelFont);

  // 4. Export button
  saveBtn = cp5.addButton("saveBlueprintButton")
     .setPosition(uiX, gFullBottomY + 42)
     .setSize(130, 28)
     .setLabel("SAVE OPENSCAD FILE");
  saveBtn.getCaptionLabel().setFont(labelFont);

  // 5. Reset camera
  resetBtn = cp5.addButton("resetCameraButton")
     .setPosition(uiX, gFullBottomY + 76)
     .setSize(130, 24)
     .setLabel("RESET 3D VIEW")
     .setColorBackground(color(72, 84, 96))
     .setColorActive(color(100, 114, 128));
  resetBtn.getCaptionLabel().setFont(labelFont);

  // Ensure expanded dropdown lists render above the controls beneath them
  rigList.bringToFront();
  templateList.bringToFront();

  updateControllerVisibility();
}

void draw() {
  background(40, 44, 52);
  readControllers();

  // ==========================================
  // PASS 1: RENDER THE 3D SCENE
  // ==========================================
  float camX = targetX + camRadius * cos(rotX) * sin(rotY);
  float camY = targetY + camRadius * sin(rotX);
  float camZ = targetZ + camRadius * cos(rotX) * cos(rotY);
  camera(camX, camY, camZ, targetX, targetY, targetZ, 0, -1, 0);

  ambientLight(140, 140, 140);
  directionalLight(180, 180, 180, 0.5, 1, -0.5);
  lightSpecular(255, 255, 255);
  noStroke();

  float edgeR = globalParams[4];

  fill(230, 90, 90);
  int nSide = (int)globalParams[0];
  for (int i = 0; i < nSide; i++) {
    if (i < vertices.length) drawSphere(vertices[i], edgeR);
  }

  fill(220, 220, 220);
  for (int[] e : edges) {
    drawCylinderEdge(vertices[e[0]], vertices[e[1]], edgeR);
  }

  if (cuboidEnabled) {
    fill(130, 170, 255);
    for (PVector[] spoke : bottom_cross_spokes) drawCylinderEdge(spoke[0], spoke[1], edgeR);

    fill(240, 190, 110);
    for (PVector[] s : rig_spines) drawCylinderEdge(s[0], s[1], edgeR);

    fill(195, 232, 141);
    for (PVector[] line : rig_supports) {
      drawCylinderEdge(line[0], line[1], edgeR);
      drawSphere(line[0], edgeR);
    }
    for (PVector[] conn : rig_bottom_connectors) drawCylinderEdge(conn[0], conn[1], edgeR);

    fill(244, 120, 190);
    for (PVector[] link : rig_base_links) drawCylinderEdge(link[0], link[1], edgeR);

    // Translucent reference boxes (rotated); highlight the selected rig
    hint(DISABLE_DEPTH_TEST);
    for (int i = 0; i < rig_boxes.size(); i++) {
      float[] b = rig_boxes.get(i);
      if (i == selectedRig) {
        fill(255, 210, 130, 80);
        stroke(255, 210, 130, 220);
      } else {
        fill(138, 190, 183, 70);
        stroke(138, 190, 183, 180);
      }
      strokeWeight(0.5f);
      pushMatrix();
      translate(b[0], b[1], b[2]);
      rotateZ(radians(b[6]));
      box(b[3], b[4], b[5]);
      popMatrix();
    }
    hint(ENABLE_DEPTH_TEST);
  }

  // ==========================================
  // PASS 2: RENDER THE 2D GUI OVERLAY LAYER
  // ==========================================
  hint(DISABLE_DEPTH_TEST);
  camera();
  noLights();
  cp5.draw();
  hint(ENABLE_DEPTH_TEST);
}

// --- CONTROLLER IO MONITOR ---
void readControllers() {
  boolean cur = cp5.get(Toggle.class, "cuboid_enabled").getBooleanValue();
  if (cur != cuboidEnabled) {
    cuboidEnabled = cur;
    updateControllerVisibility();
    calculateGeometry();
    return;
  }

  boolean changed = false;

  // Global frustum params
  for (int i = 0; i < NGLOBAL; i++) {
    float v = cp5.get(Numberbox.class, "param_" + i).getValue();
    if (i == 0) v = (int)v;
    globalParams[i] = v;
    if (v != oldGlobal[i]) { oldGlobal[i] = v; changed = true; }
    syncBox(i, v);
  }

  // Selected rig params
  if (cuboidEnabled && !rigs.isEmpty()) {
    Rig r = rigs.get(selectedRig);
    for (int j = 0; j < NRIG; j++) {
      int idx = NGLOBAL + j;
      float v = cp5.get(Numberbox.class, "param_" + idx).getValue();
      r.set(j, v);
      if (v != oldRig[j]) { oldRig[j] = v; changed = true; }
      syncBox(idx, v);
    }
  }

  // Dual-strut controls (apply to every rig)
  boolean ds = cp5.get(Toggle.class, "dual_struts").getBooleanValue();
  if (ds != dualStruts) { dualStruts = ds; changed = true; }
  float sp = cp5.get(Numberbox.class, "strut_spacing_box").getValue();
  if (sp != strutSpacing) { strutSpacing = sp; changed = true; }

  exportFilename = cp5.get(Textfield.class, "filenameField").getText();

  if (changed) calculateGeometry();
  updateTemplateLabel();
}

// Keep a typing box in sync with its numberbox, unless the user is typing in it.
void syncBox(int idx, float v) {
  Textfield tf = cp5.get(Textfield.class, "input_" + idx);
  if (tf != null && !tf.isFocus()) {
    String desired = formatParam(idx, v);
    if (!tf.getText().equals(desired)) tf.setText(desired);
  }
}

void updateControllerVisibility() {
  for (int i = 0; i < NBOX; i++) {
    Numberbox nb = cp5.get(Numberbox.class, "param_" + i);
    Textfield tf = cp5.get(Textfield.class, "input_" + i);
    boolean vis = (i < NGLOBAL) || cuboidEnabled;
    if (vis) {
      nb.show();
      nb.setLabel((i < NGLOBAL) ? globalLabels[i] : rigLabels[i - NGLOBAL]);
      nb.setDecimalPrecision(i == 0 ? 0 : 1);
      nb.setMultiplier(i == 0 ? 1 : 0.5);
      nb.setMin(minForIndex(i));
      float val = currentValue(i);
      nb.setValue(val);
      if (tf != null) { tf.show(); tf.setText(formatParam(i, val)); }
    } else {
      nb.hide();
      if (tf != null) tf.hide();
    }
  }

  // Rig + template controls only make sense with the cuboid rig
  if (cuboidEnabled) {
    rigList.show();      rigHeader.show();
    templateList.show(); templateHeader.show();
    if (dualStrutToggle != null) dualStrutToggle.show();
    if (strutSpacingBox != null) strutSpacingBox.show();
    rebuildRigList();
    updateTemplateLabel();
  } else {
    rigList.setOpen(false);      rigList.hide();      rigHeader.hide();
    templateList.setOpen(false); templateList.hide(); templateHeader.hide();
    if (dualStrutToggle != null) dualStrutToggle.hide();
    if (strutSpacingBox != null) strutSpacingBox.hide();
  }

  // Reposition the bottom controls so simple mode isn't a big empty gap
  int by = cuboidEnabled ? gFullBottomY : gSimpleBottomY;
  if (filenameTf != null) filenameTf.setPosition(gUIX, by);
  if (saveBtn != null)    saveBtn.setPosition(gUIX, by + 42);
  if (resetBtn != null)   resetBtn.setPosition(gUIX, by + 76);
}

public void controlEvent(ControlEvent normalEvent) {
  if (!normalEvent.isController()) return;
  String name = normalEvent.getController().getName();

  if (name.equals("saveBlueprintButton")) {
    saveOpenSCADFile(exportFilename);
  } else if (name.equals("resetCameraButton")) {
    rotX = defaultRotX;
    rotY = defaultRotY;
    camRadius = 90;
    println("Camera perspective restored.");
  } else if (name.startsWith("input_")) {
    applyTextInput(int(name.substring(6)));
  } else if (name.equals("templateSelector")) {
    applyTemplate((int)normalEvent.getValue());
  } else if (name.equals("rigSelector")) {
    selectRig((int)normalEvent.getValue());
  } else if (name.equals("addRigButton")) {
    addRig();
  } else if (name.equals("removeRigButton")) {
    removeRig();
  }
}

// --- RIG MANAGEMENT ---
void selectRig(int i) {
  selectedRig = constrain(i, 0, rigs.size() - 1);
  syncRigControls();
}

void addRig() {
  Rig base = rigs.get(selectedRig);
  rigs.add(new Rig(base.w, base.d, base.h, base.offX, base.offY, base.offZ, base.rot));
  rigs.get(rigs.size() - 1).template = base.template;
  selectedRig = rigs.size() - 1;
  rebuildRigList();
  syncRigControls();
  calculateGeometry();
}

void removeRig() {
  if (rigs.size() <= 1) return;   // always keep at least one rig
  rigs.remove(selectedRig);
  selectedRig = constrain(selectedRig, 0, rigs.size() - 1);
  rebuildRigList();
  syncRigControls();
  calculateGeometry();
}

void rebuildRigList() {
  if (rigList == null) return;
  rigList.clear();
  ArrayList<String> items = new ArrayList<String>();
  for (int i = 0; i < rigs.size(); i++) items.add("Rig " + (i + 1));
  rigList.addItems(items);
  rigList.getCaptionLabel().setText("Rig " + (selectedRig + 1) + " of " + rigs.size());
}

// Load the selected rig's values into the rig numberboxes / text boxes.
void syncRigControls() {
  Rig r = rigs.get(selectedRig);
  for (int j = 0; j < NRIG; j++) {
    int idx = NGLOBAL + j;
    cp5.get(Numberbox.class, "param_" + idx).setValue(r.get(j));
    oldRig[j] = r.get(j);
    Textfield tf = cp5.get(Textfield.class, "input_" + idx);
    if (tf != null && !tf.isFocus()) tf.setText(formatParam(idx, r.get(j)));
  }
  if (rigList != null) rigList.getCaptionLabel().setText("Rig " + (selectedRig + 1) + " of " + rigs.size());
  updateTemplateLabel();
}

// Apply a selected electronics template's W/D/H to the selected rig.
void applyTemplate(int itemIndex) {
  if (!cuboidEnabled || rigs.isEmpty()) return;
  Rig r = rigs.get(selectedRig);
  if (itemIndex <= 0 || itemIndex > templateWDH.length) {
    r.template = "Custom";
    return;
  }
  float[] wdh = templateWDH[itemIndex - 1];
  r.w = wdh[0]; r.d = wdh[1]; r.h = wdh[2];
  r.template = templateItems[itemIndex];
  cp5.get(Numberbox.class, "param_" + (NGLOBAL + 0)).setValue(wdh[0]);
  cp5.get(Numberbox.class, "param_" + (NGLOBAL + 1)).setValue(wdh[1]);
  cp5.get(Numberbox.class, "param_" + (NGLOBAL + 2)).setValue(wdh[2]);
  oldRig[0] = wdh[0]; oldRig[1] = wdh[1]; oldRig[2] = wdh[2];
  calculateGeometry();
  updateTemplateLabel();
}

// Reflect the selected rig's dimensions in the dropdown bar (template vs "Custom").
void updateTemplateLabel() {
  if (templateList == null || !cuboidEnabled || rigs.isEmpty() || templateList.isOpen()) return;
  Rig r = rigs.get(selectedRig);
  String name = "Custom";
  for (int t = 0; t < templateWDH.length; t++) {
    if (r.w == templateWDH[t][0] && r.d == templateWDH[t][1] && r.h == templateWDH[t][2]) {
      name = templateItems[t + 1];
      break;
    }
  }
  templateList.getCaptionLabel().setText(name);
}

// Apply a typed value (on ENTER) to its numberbox.
void applyTextInput(int idx) {
  Textfield tf = cp5.get(Textfield.class, "input_" + idx);
  if (tf == null) return;
  try {
    float v = Float.parseFloat(trim(tf.getText()));
    v = max(v, minForIndex(idx));
    if (idx == 0) v = (int)v;
    cp5.get(Numberbox.class, "param_" + idx).setValue(v);  // readControllers picks this up
    tf.setText(formatParam(idx, v));
  } catch (Exception e) {
    tf.setText(formatParam(idx, currentValue(idx)));
  }
}

// Current model value behind numberbox index i.
float currentValue(int i) {
  if (i < NGLOBAL) return globalParams[i];
  if (rigs.isEmpty()) return 0;
  return rigs.get(selectedRig).get(i - NGLOBAL);
}

// Minimum allowed value per index (offsets X/Y and rotation may go negative).
float minForIndex(int idx) {
  if (idx == 0) return 3;               // frustum_nside
  if (idx == 8 || idx == 9 || idx == 11) return -9999;  // offset_x, offset_y, rotation
  return 0;
}

// Format a value the way its numberbox displays it.
String formatParam(int i, float v) {
  return (i == 0) ? str((int)v) : nf(v, 0, 1);
}

// --- GEOMETRY ---
void calculateGeometry() {
  edges.clear();
  bottom_cross_spokes.clear();
  rig_supports.clear();
  rig_bottom_connectors.clear();
  rig_spines.clear();
  rig_base_links.clear();
  rig_boxes.clear();

  int frustum_nside = (int)globalParams[0];
  float edgeR = globalParams[4];

  bottom_radius = globalParams[1] - edgeR;
  top_radius    = globalParams[2] - edgeR;
  height        = globalParams[3] - (2 * edgeR);

  vertices = new PVector[frustum_nside * 2];
  for (int i = 0; i < frustum_nside; i++) {
    float angle = radians(i * 360.0f / frustum_nside);
    vertices[i] = new PVector(bottom_radius * cos(angle), bottom_radius * sin(angle), -height/2);
  }
  for (int i = 0; i < frustum_nside; i++) {
    float angle = radians(i * 360.0f / frustum_nside);
    vertices[i + frustum_nside] = new PVector(top_radius * cos(angle), top_radius * sin(angle), height/2);
  }
  for (int i = 0; i < frustum_nside; i++) {
    edges.add(new int[]{i, (i + 1) % frustum_nside});
    edges.add(new int[]{i, i + frustum_nside});
  }

  z_bottom = -height/2;

  if (cuboidEnabled) {
    for (int i = 0; i < frustum_nside; i++) {
      PVector p1 = vertices[i];
      PVector p2 = vertices[(i + 1) % frustum_nside];
      PVector midpoint = PVector.add(p1, p2).mult(0.5f);
      bottom_cross_spokes.add(new PVector[]{midpoint, new PVector(0, 0, z_bottom)});
    }

    float maxTop = height/2;
    for (Rig r : rigs) {
      buildRigGeometry(r, edgeR);
      float zCuboidTop = z_bottom + r.offZ - edgeR * 2 + r.h;
      maxTop = max(maxTop, zCuboidTop);
    }

    targetX = 0;
    targetY = 0;
    targetZ = (z_bottom + maxTop) / 2.0f;
  } else {
    targetX = 0;
    targetY = 0;
    targetZ = 0;
  }
}

// Build one rig's posts (rotated), spine, connectors, base link and box.
void buildRigGeometry(Rig r, float edgeR) {
  float hx = r.w / 2;
  float hy = r.d / 2;
  float zSupportStart = z_bottom;
  float zCuboidBot    = z_bottom + r.offZ - edgeR * 2;
  float zCuboidTop    = zCuboidBot + r.h;

  PVector centerStart = new PVector(r.offX, r.offY, zSupportStart);
  PVector centerEnd   = new PVector(r.offX, r.offY, zCuboidBot);
  rig_spines.add(new PVector[]{centerStart, centerEnd});
  rig_base_links.add(new PVector[]{new PVector(0, 0, z_bottom), centerStart});

  // Post offsets relative to the rig centre, before yaw rotation.
  // Dual mode: two posts per face, spread by strutSpacing along the face.
  float halfSp = strutSpacing / 2;
  float[][] locals = dualStruts ? new float[][]{
    {-halfSp,  hy + edgeR}, { halfSp,  hy + edgeR},     // +Y face (spread along X)
    {-halfSp, -(hy + edgeR)}, { halfSp, -(hy + edgeR)}, // -Y face (spread along X)
    { hx + edgeR, -halfSp}, { hx + edgeR,  halfSp},     // +X face (spread along Y)
    {-(hx + edgeR), -halfSp}, {-(hx + edgeR),  halfSp}  // -X face (spread along Y)
  } : new float[][]{
    {0,  hy + edgeR},
    {0, -(hy + edgeR)},
    { hx + edgeR, 0},
    {-(hx + edgeR), 0}
  };
  float rad = radians(r.rot);
  float c = cos(rad), s = sin(rad);
  for (float[] loc : locals) {
    float rx = loc[0] * c - loc[1] * s;
    float ry = loc[0] * s + loc[1] * c;
    PVector base = new PVector(r.offX + rx, r.offY + ry, zSupportStart);
    PVector top  = new PVector(r.offX + rx, r.offY + ry, zCuboidTop);
    rig_supports.add(new PVector[]{base, top});
    rig_bottom_connectors.add(new PVector[]{centerStart, base});
  }

  rig_boxes.add(new float[]{r.offX, r.offY, zCuboidBot + r.h/2, r.w, r.d, r.h, r.rot});
}

// --- GEOMETRIC DRAWING HELPERS ---
void drawSphere(PVector pos, float r) {
  pushMatrix();
  translate(pos.x, pos.y, pos.z);
  sphere(r);
  popMatrix();
}

void drawCylinderEdge(PVector p1, PVector p2, float r) {
  PVector v = PVector.sub(p2, p1);
  float d = v.mag();
  if (d < 0.0001) return;
  float phi = atan2(v.y, v.x);
  float theta = acos(v.z / d);

  pushMatrix();
  translate(p1.x, p1.y, p1.z);
  rotateZ(phi);
  rotateY(theta);

  int detail = 16;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= detail; i++) {
    float angle = TWO_PI * i / detail;
    vertex(r * cos(angle), r * sin(angle), 0);
    vertex(r * cos(angle), r * sin(angle), d);
  }
  endShape();
  popMatrix();
}

void mouseDragged() {
  if (mouseX > 220) {
    float sensitivity = 0.007f;
    rotY += (mouseX - pmouseX) * sensitivity;
    rotX += (mouseY - pmouseY) * sensitivity;
    rotX = constrain(rotX, -radians(89), radians(89));
  }
}
void mouseWheel(MouseEvent event) {
  if (mouseX > 220) {
    camRadius = constrain(camRadius + event.getCount() * 5, 15, 400);
  }
}

// --- OPENSCAD EXPORT ---
void saveOpenSCADFile(String filename) {
  if (!filename.toLowerCase().endsWith(".scad")) filename += ".scad";
  PrintWriter output = createWriter(filename);

  output.println("// Exported programmatically from Processing Canvas Workspace");
  output.println();

  int nside = (int)globalParams[0];
  float bR = globalParams[1], tR = globalParams[2], fh = globalParams[3], eR = globalParams[4];

  // Length of the wedge flap at the top of each wall strut. Tweak in OpenSCAD.
  output.println("flap_length = " + FLAP_LENGTH + ";  // wedge flap length at the top of each wall strut");
  output.println();

  if (cuboidEnabled) {
    // Whole assembly is wrapped in a difference() so the top slice shears
    // every wall strut off straight at the top cap plane.
    output.println("// --- ASSEMBLY: wall struts sheared flush at the top plane ---");
    output.println("difference() {");
    output.println("  union() {");
    output.println("    // --- FRUSTUM CAGE (drawn once) ---");
    output.println("    frustumCage(" + nside + ", " + bR + ", " + tR + ", " + fh + ", " + eR + ");");
    output.println();
    output.println("    // --- INTERNAL RIGS (" + rigs.size() + ") ---");
    for (int i = 0; i < rigs.size(); i++) {
      Rig r = rigs.get(i);
      String tag = r.template.equals("Custom") ? "" : " (" + r.template + ")";
      output.println("    // Rig " + (i + 1) + tag);
      output.println("    rigSupport(" + fh + ", " + eR + ", "
        + r.w + ", " + r.d + ", " + r.h + ", "
        + r.offX + ", " + r.offY + ", " + r.offZ + ", " + r.rot + ", "
        + (dualStruts ? 2 : 1) + ", " + strutSpacing + ");");
    }
    output.println("  }");
    printTopTrimSlice(output, tR, fh, eR);
    output.println("}");
    output.println();

    String[] lines = loadStrings("template_full.txt");
    if (lines != null) for (String line : lines) output.println(line);
  } else {
    output.println("// --- ASSEMBLY: wall struts sheared flush at the top plane ---");
    output.println("difference() {");
    output.println("  frustum(" + nside + ", " + bR + ", " + tR + ", " + fh + ", " + eR + ");");
    printTopTrimSlice(output, tR, fh, eR);
    output.println("}");
    output.println();

    String[] lines = loadStrings("template_simple.txt");
    if (lines != null) for (String line : lines) output.println(line);
  }

  output.println();
  String[] helperLines = loadStrings("template_helper.txt");
  if (helperLines != null) for (String line : helperLines) output.println(line);

  output.flush();
  output.close();
  println("Saved OpenSCAD blueprint to: " + filename);
}

// Flat disc subtracted at the top cap plane so wall struts are cut off straight.
// Spans z in [fh/2 - eR, fh/2 + eR]; base sits exactly on the top-vertex plane.
void printTopTrimSlice(PrintWriter output, float tR, float fh, float eR) {
  output.println("  // Top trimming slice: cuts all wall struts off straight");
  output.println("  translate([0, 0, " + fh + "/2 - " + eR + "])");
  output.println("    scale([" + tR + " + " + eR + ", " + tR + " + " + eR + ", 1])");
  output.println("    cylinder(h = " + eR + " * 2, r = 1, $fn = 64);");
}
