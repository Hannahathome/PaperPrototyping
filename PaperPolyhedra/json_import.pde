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
    // Replace
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

  // Optional solid fill colour: "#RRGGBB"
  String hexColor = e.isNull("color") ? "" : e.getString("color", "");
  if (hexColor.length() > 0) {
    s.shapeColor      = parseHexColor(hexColor);
    s.fillColorEnabled = true;
  }

  return s;
}
