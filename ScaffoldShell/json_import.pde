// JSON_IMPORT.PDE
// Handles batch import of shape definitions from a JSON file.
//
// JSON format (array of shape objects):
//   [
//     { "sides": 3, "diameter": 100, "height": 14.84, "label": "Dragonfly", "marker_id": 48 },
//     { "sides": 4, "diameter": 50,  "height": 30,    "label": "Box" }
//   ]
//
// Fields:
//   sides      (int)    — polygon side count, >= 3. Default: 4
//   diameter   (float)  — circumscribed diameter in mm (= side length for squares). Default: 30
//   height     (float)  — shape height in mm. Default: 30
//   label      (string) — optional display name. Default: ""
//   marker_id  (int)    — aruco start index for rep 0. Default: 48
//
// A dimensions file from an export (json_export.pde) is this array with more fields. When it
// gives top_perimeter_mm, those perimeters are used instead of diameter, and its scaffold and
// hollow settings are restored. Cuboid and per-edge shapes come back as regular ones.
//
// Called from SidebarPanel click handler when "Load JSON" is pressed.

import javax.swing.JOptionPane;

// ---------------------------------------------------------------------------
// Entry point — open OS file picker, callback to jsonFileSelected()
// ---------------------------------------------------------------------------
void loadJSONShapes() {
  selectInput("Select shapes JSON file", "jsonFileSelected");
}

// ---------------------------------------------------------------------------
// selectInput() callback — must be a top-level function
// ---------------------------------------------------------------------------
void jsonFileSelected(File selection) {
  if (selection == null) {
    println("[JSON Import] File selection cancelled.");
    return;
  }

  // --- Parse JSON ---
  JSONArray arr = null;
  try {
    arr = loadJSONArray(selection.getAbsolutePath());
  } catch (Exception e) {
    println("[JSON Import] ERROR: Could not parse JSON file: " + e.getMessage());
    JOptionPane.showMessageDialog(null,
      "Could not read the JSON file.\nMake sure it is a valid JSON array.\n\n" + e.getMessage(),
      "JSON Import Error", JOptionPane.ERROR_MESSAGE);
    return;
  }

  if (arr == null || arr.size() == 0) {
    println("[JSON Import] ERROR: JSON file is empty or not an array.");
    JOptionPane.showMessageDialog(null,
      "The JSON file is empty or not a JSON array.",
      "JSON Import Error", JOptionPane.ERROR_MESSAGE);
    return;
  }

  // --- Build ShapeSpec list ---
  ArrayList<ShapeSpec> newShapes = new ArrayList<ShapeSpec>();
  for (int i = 0; i < arr.size(); i++) {
    try {
      ShapeSpec s = buildShapeFromJSON(arr.getJSONObject(i));
      newShapes.add(s);
    } catch (Exception e) {
      println("[JSON Import] WARNING: Skipping entry " + i + " — " + e.getMessage());
    }
  }

  // Restore globals to selected shape (buildShapeFromJSON modified them temporarily)
  if (shapes != null && shapes.size() > 0) {
    loadGlobalsFrom(shapes.get(selectedShapeIdx));
    setParams(false);
  }

  if (newShapes.size() == 0) {
    println("[JSON Import] ERROR: No valid shapes found in JSON.");
    JOptionPane.showMessageDialog(null,
      "No valid shape entries were found in the JSON file.",
      "JSON Import Error", JOptionPane.ERROR_MESSAGE);
    return;
  }

  // --- Ask Replace / Append / Cancel ---
  String msg = "Found " + newShapes.size() + " shape" + (newShapes.size() == 1 ? "" : "s") +
               " in the JSON file.\nReplace all existing shapes, or append them?";
  int approximated = jsonApproximatedCount(arr);
  if (approximated > 0) {
    msg += "\n\n" + approximated + " cuboid or per-edge shape" + (approximated == 1 ? "" : "s")
         + " will load as a regular shape with the same perimeters.";
  }
  String[] options = { "Replace", "Append", "Cancel" };
  int choice = JOptionPane.showOptionDialog(
    null, msg, "Load JSON Shapes",
    JOptionPane.DEFAULT_OPTION, JOptionPane.QUESTION_MESSAGE,
    null, options, options[0]
  );

  if (choice == 2 || choice == JOptionPane.CLOSED_OPTION) {
    println("[JSON Import] Cancelled by user.");
    return;
  }

  // --- Apply to shapes list ---
  if (choice == 0) {
    // Replace — every existing shape index is about to become meaningless, so drop the
    // connections that reference them rather than leaving them pointing at new shapes.
    if (connections != null && !connections.isEmpty()) {
      println("[JSON Import] Cleared " + connections.size() + " connection(s) — shapes replaced.");
      connections.clear();
      selectedConnectionIdx = -1;
    }
    shapes.clear();
    shapes.addAll(newShapes);
    selectedShapeIdx = 0;
    println("[JSON Import] Replaced all shapes with " + newShapes.size() + " JSON shapes.");
  } else {
    // Append
    int firstNew = shapes.size();
    shapes.addAll(newShapes);
    selectedShapeIdx = firstNew;
    println("[JSON Import] Appended " + newShapes.size() + " JSON shapes.");
  }

  // --- Enable free placement if more than one shape exists ---
  if (shapes.size() > 1 && !freePlacementMode) {
    freePlacementMode = true;
    if (tFreePlacement != null) tFreePlacement.setValue(1);
    if (btnResetPlacement != null) btnResetPlacement.setVisible(true);
  }

  // Initialise placement positions for any shape that doesn't have them yet
  if (freePlacementMode) {
    for (int si = 0; si < shapes.size(); si++) {
      ShapeSpec s = shapes.get(si);
      if (s.repPositions == null) {
        loadGlobalsFrom(s);
        setParams(false);
        initRepPositionsForShape(s);
      }
    }
    // Restore globals again after the loop
    loadGlobalsFrom(shapes.get(selectedShapeIdx));
    setParams(false);
  }

  // Sync UI to the (now selected) shape and redraw
  syncUIToSelectedShape();
  redraw();
}

// Entries whose geometry buildShapeFromJSON() cannot rebuild.
int jsonApproximatedCount(JSONArray arr) {
  int count = 0;
  for (int i = 0; i < arr.size(); i++) {
    String type = arr.getJSONObject(i).getString("type", "");
    if (type.equals("cuboid") || type.equals("per-edge")) count++;
  }
  return count;
}

// ---------------------------------------------------------------------------
// Build a single ShapeSpec from a JSON object entry.
// Temporarily clobbers the draw-time globals; caller must restore them.
// ---------------------------------------------------------------------------
ShapeSpec buildShapeFromJSON(JSONObject e) {
  // Read fields with safe defaults
  int    sides    = max(3, e.getInt("sides", 4));
  float  diameter = max(1, e.getFloat("diameter", 30));
  float  ht       = max(1, e.getFloat("height", 30));
  String lbl      = e.isNull("label")     ? ""  : e.getString("label", "");
  int    markerId = e.getInt("marker_id", 48);

  // Set UI globals — mirror of what applyToModel() reads
  uiSides  = sides;
  uiTopW   = diameter;
  uiBotW   = diameter;
  uiHeight = ht;
  uiLock   = true;
  nSides   = sides;
  // An imported shape can have fewer walls than the one it replaces, which would strand any
  // connection addressed to a panel that no longer exists.
  clampConnectionsToPanelCount(selectedShapeIdx, nSides);
  // An import redefines what the shape indices mean, so stored snapshots stop describing
  // the assembly they were taken from.
  invalidateConnectionUndo("shape imported");

  // Compute perimeter using the same formula as applyToModel()
  float topPerim, botPerim;
  if (sides == 4) {
    // Square: diameter = side length, perimeter = 4 * side
    topPerim = 4.0 * diameter;
    botPerim = topPerim;
  } else {
    // Regular polygon: circumscribed diameter → side = D * sin(π/n)
    topPerim = sides * diameter * sin(PI / sides);
    botPerim = topPerim;
  }

  // A dimensions file gives both perimeters, which is the only way to keep a frustum one.
  boolean exact = e.hasKey("top_perimeter_mm") && e.hasKey("bottom_perimeter_mm");
  if (exact) {
    topPerim = e.getFloat("top_perimeter_mm");
    botPerim = e.getFloat("bottom_perimeter_mm");
    uiTopW = shapeDiameterFromPerimeter(topPerim, sides);
    uiBotW = shapeDiameterFromPerimeter(botPerim, sides);
    uiLock = topPerim == botPerim;
  }

  // Write into model
  cylinder.x = topPerim;
  cylinder.y = botPerim;
  cylinder.z = ht;

  // Recalculate all _px derived values
  setParams(false);

  // Capture into a new ShapeSpec
  ShapeSpec s = new ShapeSpec();
  saveGlobalsTo(s);

  // Set fields that have no global equivalent
  s.label            = lbl;
  s.markerStartIndex = markerId;
  s.nRep             = 1;
  s.repPositions     = null;
  s.repPages         = new int[] { currentPage };

  // Optional solid fill colour: "#RRGGBB"
  String hexColor = e.isNull("color") ? "" : e.getString("color", "");
  if (hexColor.length() > 0) {
    s.shapeColor      = parseHexColor(hexColor);
    s.fillColorEnabled = true;
  }

  // saveGlobalsTo() carried over whatever shape happened to be selected.
  if (exact) {
    s.perEdgeMode   = false;
    s.cuboidMode    = false;
    s.hollowMode    = e.getString("type", "").equals("hollow");
    s.wallThickness = e.getFloat("wall_thickness_mm", s.wallThickness);
    s.tabDepth      = e.getFloat("tab_depth_mm", s.tabDepth);
    s.flapDepth     = e.getFloat("flap_depth_mm", s.flapDepth);
  }
  if (e.hasKey("scaffold")) applyScaffoldJSON(s.frame, e.getJSONObject("scaffold"));

  return s;
}

void applyScaffoldJSON(FrameSpec f, JSONObject j) {
  f.enabled      = true;
  f.strutRadius  = j.getFloat("strut_radius_mm", f.strutRadius);
  f.clearanceMM  = j.getFloat("clearance_mm", f.clearanceMM);
  f.flapLength   = j.getFloat("wall_flap_length_mm", f.flapLength);
  f.dualStruts   = j.getBoolean("dual_struts", f.dualStruts);
  f.strutSpacing = j.getFloat("strut_spacing_mm", f.strutSpacing);

  JSONArray rigs = j.getJSONArray("rigs");
  for (int i = 0; rigs != null && i < rigs.size(); i++) {
    JSONObject o = rigs.getJSONObject(i);
    Rig r = new Rig(o.getFloat("w"), o.getFloat("d"), o.getFloat("h"),
                    o.getFloat("off_x"), o.getFloat("off_y"), o.getFloat("off_z"),
                    o.getFloat("rotation"));
    r.preset     = o.getString("preset", r.preset);
    r.cutoutFace = max(0, java.util.Arrays.asList(RIG_CUT_FACE_NAMES).indexOf(o.getString("cutout_face", "")));
    r.cutoutSize = max(0, java.util.Arrays.asList(RIG_CUT_SIZE_NAMES).indexOf(o.getString("cutout_size", "")));
    f.rigs.add(r);
  }
}
