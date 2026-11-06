// JSON_EXPORT.PDE
// Writes a record of every shape's dimensions and scaffold alongside each export, so a piece
// can be rebuilt later: read the numbers, or load the file back with Load JSON.
//
// The file is the array json_import.pde reads, with its fields (sides, diameter, height,
// label, marker_id, color) plus these:
//
//   name                  how the sidebar names the shape
//   type                  prism, frustum, hollow, cuboid or per-edge
//   copies                how many of it are on the sheets
//   top_perimeter_mm      top and bottom perimeters: what the shape is actually built from.
//   bottom_perimeter_mm   diameter is the top alone, which cannot describe a frustum.
//   top_side_mm           one wall's width at the top and bottom, for reading
//   bottom_side_mm
//   tab_depth_mm          glue tab and flap depths
//   flap_depth_mm
//   wall_thickness_mm     hollow only
//   cuboid_mm             cuboid only: {top_length, top_width, bottom_length, bottom_width}
//   edges_mm              per-edge only: {top: [...], bottom: [...]}
//   scaffold              absent when the shape has no scaffold, otherwise:
//     export                    "exported", or why this shape has no file of its own
//     strut_radius_mm, clearance_mm, wall_flap_length_mm, dual_struts, strut_spacing_mm
//     frame_top_radius_mm, frame_bottom_radius_mm, frame_height_mm   as the .scad builds it
//     rigs                      w, d, h, off_x, off_y, off_z, rotation, preset, cutout_face,
//                               cutout_size
//
// Everything is millimetres, read from ShapeSpec fields, so like FrameSCAD.pde this never
// depends on the export's pixel scale. Load JSON restores the shape and its scaffold, except
// cuboid and per-edge geometry, copies and connections; those are a record only.

// What can be set by hand is written as Float.toString() gives it, the shortest text that
// reads back as the same float, so a loaded shape gets the same scaffold to the last digit.
void jsonPutExact(JSONObject o, String key, float v) {
  o.setDouble(key, Double.parseDouble(Float.toString(v)));
}

// Derived values are for reading, and nothing loads them back. Rounded through text, because
// the preprocessor makes a literal like 10000.0 a float, and float arithmetic here would
// leave 29.600000381469727 in the file.
void jsonPutRounded(JSONObject o, String key, float v) {
  o.setDouble(key, Double.parseDouble(scadNum(v)));
}

JSONArray jsonFloats(float[] values) {
  JSONArray out = new JSONArray();
  for (float v : values) out.append(Double.parseDouble(Float.toString(v)));
  return out;
}

String shapeTypeName(ShapeSpec s) {
  if (s.perEdgeMode) return "per-edge";
  if (s.cuboidMode)  return "cuboid";
  if (s.hollowMode)  return "hollow";
  return s.cylinder.x == s.cylinder.y ? "prism" : "frustum";
}

// The sidebar's diameter for a perimeter: applyToModel()'s conversion, backwards.
float shapeDiameterFromPerimeter(float perim, int sides) {
  return sides == 4 ? perim / 4.0 : perim / (sides * sin(PI / sides));
}

JSONObject shapeRecord(FrameExportEntry e) {
  ShapeSpec s = shapes.get(e.shapeIdx);
  JSONObject o = new JSONObject();

  o.setString("name", frameShapeName(e.shapeIdx));
  if (s.label != null && !s.label.isEmpty()) o.setString("label", s.label);
  o.setString("type", shapeTypeName(s));
  o.setInt("sides", s.nSides);
  o.setInt("copies", s.nRep);
  o.setInt("marker_id", s.markerStartIndex);
  if (s.fillColorEnabled) o.setString("color", "#" + hex(s.shapeColor, 6));

  jsonPutExact(o, "height", s.cylinder.z);
  jsonPutRounded(o, "diameter", shapeDiameterFromPerimeter(s.cylinder.x, s.nSides));
  jsonPutExact(o, "top_perimeter_mm", s.cylinder.x);
  jsonPutExact(o, "bottom_perimeter_mm", s.cylinder.y);
  jsonPutRounded(o, "top_side_mm", s.cylinder.x / s.nSides);
  jsonPutRounded(o, "bottom_side_mm", s.cylinder.y / s.nSides);
  jsonPutExact(o, "tab_depth_mm", s.tabDepth);
  jsonPutExact(o, "flap_depth_mm", s.flapDepth);

  if (s.hollowMode) jsonPutExact(o, "wall_thickness_mm", s.wallThickness);
  if (s.cuboidMode) {
    JSONObject c = new JSONObject();
    jsonPutExact(c, "top_length", s.uiCubTopLen);
    jsonPutExact(c, "top_width", s.uiCubTopWid);
    jsonPutExact(c, "bottom_length", s.uiCubBotLen);
    jsonPutExact(c, "bottom_width", s.uiCubBotWid);
    o.setJSONObject("cuboid_mm", c);
  }
  if (s.perEdgeMode && s.edgesTop != null && s.edgesBottom != null) {
    JSONObject edges = new JSONObject();
    edges.setJSONArray("top", jsonFloats(s.edgesTop.mm));
    edges.setJSONArray("bottom", jsonFloats(s.edgesBottom.mm));
    o.setJSONObject("edges_mm", edges);
  }

  if (e.wanted) o.setJSONObject("scaffold", scaffoldRecord(s, e));
  return o;
}

JSONObject scaffoldRecord(ShapeSpec s, FrameExportEntry e) {
  FrameSpec f = s.frame;
  JSONObject o = new JSONObject();

  o.setString("export", e.writes ? "exported" : e.status);
  jsonPutExact(o, "strut_radius_mm", f.strutRadius);
  jsonPutExact(o, "clearance_mm", f.clearanceMM);
  jsonPutExact(o, "wall_flap_length_mm", f.flapLength);
  o.setBoolean("dual_struts", f.dualStruts);
  jsonPutExact(o, "strut_spacing_mm", f.strutSpacing);

  if (frameAvailable(s)) {
    FrameScadParams p = frameScadParamsFor(s);
    jsonPutRounded(o, "frame_top_radius_mm", p.topR);
    jsonPutRounded(o, "frame_bottom_radius_mm", p.botR);
    jsonPutRounded(o, "frame_height_mm", p.height);
  }

  JSONArray rigs = new JSONArray();
  for (Rig r : f.rigs) {
    JSONObject j = new JSONObject();
    j.setString("preset", r.preset);
    jsonPutExact(j, "w", r.w);
    jsonPutExact(j, "d", r.d);
    jsonPutExact(j, "h", r.h);
    jsonPutExact(j, "off_x", r.offX);
    jsonPutExact(j, "off_y", r.offY);
    jsonPutExact(j, "off_z", r.offZ);
    jsonPutExact(j, "rotation", r.rot);
    j.setString("cutout_face", RIG_CUT_FACE_NAMES[r.cutoutFace]);
    j.setString("cutout_size", RIG_CUT_SIZE_NAMES[r.cutoutSize]);
    rigs.append(j);
  }
  o.setJSONArray("rigs", rigs);
  return o;
}

// The order fields appear in. JSONObject keeps them in hash order, which puts a shape's name
// somewhere in the middle of it, and this file is meant to be read as well as loaded.
final String[] RECORD_KEY_ORDER = {
  "name", "label", "type", "sides", "copies",
  "height", "diameter", "top_perimeter_mm", "bottom_perimeter_mm", "top_side_mm", "bottom_side_mm",
  "wall_thickness_mm", "cuboid_mm", "top_length", "top_width", "bottom_length", "bottom_width",
  "edges_mm", "top", "bottom", "tab_depth_mm", "flap_depth_mm", "marker_id", "color",
  "scaffold", "export", "strut_radius_mm", "clearance_mm", "wall_flap_length_mm", "dual_struts",
  "strut_spacing_mm", "frame_top_radius_mm", "frame_bottom_radius_mm", "frame_height_mm",
  "rigs", "preset", "w", "d", "h", "off_x", "off_y", "off_z", "rotation",
  "cutout_face", "cutout_size"
};

// A value as JSON text, with object fields in RECORD_KEY_ORDER. A field missing from the list
// still gets written, after the others.
String recordText(Object v, String pad) {
  String in = pad + "  ";
  ArrayList<String> parts = new ArrayList<String>();

  if (v instanceof JSONObject) {
    JSONObject o = (JSONObject) v;
    ArrayList<String> keys = new ArrayList<String>();
    for (String key : RECORD_KEY_ORDER) if (o.hasKey(key)) keys.add(key);
    for (Object key : o.keys()) if (!keys.contains(key)) keys.add((String) key);
    for (String key : keys) parts.add(in + "\"" + key + "\": " + recordText(o.get(key), in));
    return "{\n" + join(parts.toArray(new String[0]), ",\n") + "\n" + pad + "}";
  }
  if (v instanceof JSONArray) {
    JSONArray a = (JSONArray) v;
    if (a.size() == 0) return "[]";
    for (int i = 0; i < a.size(); i++) parts.add(in + recordText(a.get(i), in));
    return "[\n" + join(parts.toArray(new String[0]), ",\n") + "\n" + pad + "]";
  }
  if (v instanceof String) {
    String quoted = new JSONArray().append((String) v).format(-1);  // handles the escaping
    return quoted.substring(1, quoted.length() - 1);
  }
  return String.valueOf(v);
}

// Writes the record for every shape, scaffold or not. Called from exportPlan() and the
// Scaffold tab's Export all button. Returns the path written.
String exportShapeRecord(String baseName, String stamp) {
  JSONArray all = new JSONArray();
  for (FrameExportEntry e : frameExportPlan()) all.append(shapeRecord(e));
  String path = "output/" + baseName + "_" + stamp + "_dimensions.json";
  saveStrings(path, new String[] { recordText(all, "") });
  println("[Export] wrote " + path);
  return path;
}
