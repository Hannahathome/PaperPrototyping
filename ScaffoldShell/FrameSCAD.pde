// FRAMESCAD.PDE - OpenSCAD export for the internal support frame
//
// The frame is the one thing this sketch produces that is printed rather than cut, so it
// leaves as OpenSCAD source: open the .scad, render (F6), export STL, print.
//
// This file writes numbers. It derives NO geometry -- every dimension comes from
// frameScadParamsFor() in Frame.pde, which the 3D preview reads too, so what you see in
// the preview is what OpenSCAD builds. See Frame.pde's "one geometry, two projections".
//
// Exports land in output/ with the rest of the export set, rather than beside the sketch
// the way FrustumSupport did -- which its own README nominated as the follow-up.
//
// UNITS: millimetres throughout, and never anything else. Nothing here may touch a _px
// global. exportPlan() flips setParams(true) (MM_V, 96 DPI) partway through its run, so a
// pixel value read here would silently be at the wrong scale depending on when it was
// called. The .scad is written from ShapeSpec fields, which are already mm.

// Written near the top of every export so it can be tweaked in OpenSCAD without coming
// back here. Per-shape, because a short frame wants a shorter flap.
final String FRAME_TEMPLATE_MAIN   = "template_frame.txt";
final String FRAME_TEMPLATE_HELPER = "template_helper.txt";

// OpenSCAD is not locale-aware: it wants "19.1", and a machine set to a locale that writes
// decimals with a comma would otherwise emit "19,1" and produce a file that does not parse.
// Processing's nf() formats through NumberFormat.getInstance(), which follows the default
// locale, so it is not safe here. Locale.US is pinned deliberately.
String scadNum(float v) {
  return String.format(java.util.Locale.US, "%.4f", v);
}

String scadInt(int v) {
  return String.format(java.util.Locale.US, "%d", v);
}

// ---------------------------------------------------------------------------
// Which shapes get a frame
// ---------------------------------------------------------------------------

// What an export will do with one shape. The status is what the Scaffold tab shows.
class FrameExportEntry {
  int shapeIdx;
  boolean wanted = false;   // its scaffold is switched on
  boolean writes = false;   // it gets a file of its own
  int sameAs = -1;          // the earlier shape whose file already covers it
  String status;
}

// One entry per shape, in shape order. THE single decision: the Scaffold tab's list, the
// export and the notification all read this, so what the tab promises is what gets written.
// Shapes with identical scaffolds share one file - it is the same print either way.
ArrayList<FrameExportEntry> frameExportPlan() {
  ArrayList<FrameExportEntry> plan = new ArrayList<FrameExportEntry>();
  if (shapes == null) return plan;
  HashMap<String, Integer> firstWithKey = new HashMap<String, Integer>();

  for (int i = 0; i < shapes.size(); i++) {
    ShapeSpec s = shapes.get(i);
    FrameExportEntry e = new FrameExportEntry();
    e.shapeIdx = i;
    plan.add(e);

    if (s.frame == null || !s.frame.enabled) {
      e.status = "scaffold off";
      continue;
    }
    e.wanted = true;
    if (!frameAvailable(s)) {
      e.status = "skipped, " + frameUnavailableReason(s);
      continue;
    }
    FrameScadParams p = frameScadParamsFor(s);
    if (!p.valid) {
      e.status = "skipped, " + p.problem;
      continue;
    }
    String key = frameScadKey(s, p);
    Integer first = firstWithKey.get(key);
    if (first != null) {
      e.sameAs = first;
      e.status = "same as " + frameShapeName(first);
    } else {
      firstWithKey.put(key, i);
      e.writes = true;
      e.status = "will export";
    }
  }
  return plan;
}

int frameExportFileCount() {
  int count = 0;
  for (FrameExportEntry e : frameExportPlan()) if (e.writes) count++;
  return count;
}

// What the notification adds to a file count: ", 1 identical, 1 skipped", or "" when every
// scaffold that was asked for got a file.
String frameExportNote(int written) {
  int wanted = 0, identical = 0;
  for (FrameExportEntry e : frameExportPlan()) {
    if (e.wanted) wanted++;
    if (e.sameAs >= 0) identical++;
  }
  int skipped = wanted - identical - written;
  return (identical > 0 ? ", " + identical + " identical" : "")
       + (skipped > 0 ? ", " + skipped + " skipped" : "");
}

// What OpenSCAD builds for this shape, as text: the assembly with its comment lines removed,
// so two scaffolds differing only in a rig's name or the shell note still count as the same.
// Comes from the writer itself, so it cannot miss a parameter the file depends on.
String frameScadKey(ShapeSpec s, FrameScadParams p) {
  java.io.StringWriter text = new java.io.StringWriter();
  PrintWriter out = new PrintWriter(text);
  writeFrameAssembly(out, s, p);
  out.flush();

  StringBuilder key = new StringBuilder();
  for (String line : text.toString().split("\\R")) {
    if (!line.trim().startsWith("//")) key.append(line).append('\n');
  }
  return key.toString();
}

// A shape's name as the Scaffold tab shows it.
String frameShapeName(int idx) {
  ShapeSpec s = shapes.get(idx);
  return (s.label != null && !s.label.isEmpty()) ? s.label : ("Shape " + (idx + 1));
}

// A filename-safe name for one shape: its label if it has one, else its position.
String frameShapeSlug(int idx) {
  ShapeSpec s = shapes.get(idx);
  String name = (s.label != null) ? s.label.trim() : "";
  if (name.isEmpty()) return "shape" + (idx + 1);
  name = name.replaceAll("[^A-Za-z0-9_-]+", "_");
  name = name.replaceAll("^_+|_+$", "");
  return name.isEmpty() ? ("shape" + (idx + 1)) : name;
}

// frameShapeSlug(), kept apart from the names already taken in this export: two shapes can
// share a label, and the second file would silently replace the first. Compared without
// case, because the file systems this runs on mostly do.
String frameUniqueSlug(int idx, java.util.HashSet<String> taken) {
  String slug = frameShapeSlug(idx);
  while (!taken.add(slug.toLowerCase())) slug += "_" + (idx + 1);
  return slug;
}

// The name in the export field, or the default.
String frameExportBaseName() {
  return (uiExportFilename != null && !uiExportFilename.trim().isEmpty())
       ? uiExportFilename : "result";
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

// Writes one .scad per different scaffold (see frameExportPlan). Returns the paths written,
// so the caller can report them. Called from exportPlan() alongside the PDF and SVGs, and
// from the Scaffold tab's Export all button.
ArrayList<String> exportFrameSCAD(String baseName, String stamp) {
  ArrayList<String> written = new ArrayList<String>();
  if (frameExportFileCount() == 0) return written;

  // Load the OpenSCAD module libraries ONCE, before writing anything. These are real
  // source, not the generated placeholders PlaceholderAssets.pde makes -- if they are
  // missing, nothing can be salvaged. FrustumSupport wrote the file anyway on a null load,
  // producing a .scad that called modules it never defined and failed only in OpenSCAD.
  String[] mainLines   = loadStrings(FRAME_TEMPLATE_MAIN);
  String[] helperLines = loadStrings(FRAME_TEMPLATE_HELPER);
  if (mainLines == null || helperLines == null) {
    println("[Scaffold] ERROR: missing OpenSCAD module library in data/ ("
          + FRAME_TEMPLATE_MAIN + " / " + FRAME_TEMPLATE_HELPER + "). No .scad written.");
    return written;
  }

  java.util.HashSet<String> taken = new java.util.HashSet<String>();
  for (FrameExportEntry e : frameExportPlan()) {
    if (!e.writes) continue;
    String path = "output/" + baseName + "_" + stamp + "_frame_" + frameUniqueSlug(e.shapeIdx, taken) + ".scad";
    if (writeFrameSCAD(shapes.get(e.shapeIdx), e.shapeIdx, path, mainLines, helperLines)) {
      written.add(path);
    }
  }
  return written;
}

// Writes the frame for one shape. Returns false (having written nothing) if the frame is
// geometrically impossible.
boolean writeFrameSCAD(ShapeSpec s, int idx, String path, String[] mainLines, String[] helperLines) {
  FrameScadParams p = frameScadParamsFor(s);
  if (!p.valid) {
    println("[Scaffold] skipped " + frameShapeSlug(idx) + ": " + p.problem);
    return false;
  }

  PrintWriter out = createWriter(path);
  writeFrameAssembly(out, s, p);

  for (String line : mainLines) out.println(line);
  out.println();
  for (String line : helperLines) out.println(line);

  out.flush();
  out.close();
  println("[Scaffold] wrote " + path);
  return true;
}

// Everything in the file except the module libraries, which are the same in all of them.
void writeFrameAssembly(PrintWriter out, ShapeSpec s, FrameScadParams p) {
  FrameSpec f = s.frame;
  FrameDims d = frameDimsFor(s);
  boolean hasRigs = !f.rigs.isEmpty();

  out.println("// Internal support scaffold, exported from ScaffoldShell.");
  out.println("// Render with F6, export STL, print. Dimensions are millimetres.");
  out.println("//");
  if (d.box) {
    out.println("// Shell it goes inside: a cuboid, bottom " + scadNum(d.botL) + " x " + scadNum(d.botW)
              + " mm, top " + scadNum(d.topL) + " x " + scadNum(d.topW)
              + " mm (length x width), height " + scadNum(d.height) + " mm.");
    out.println("// Clearance of " + scadNum(f.clearanceMM)
              + " mm is already subtracted from each wall and from the height below.");
  } else {
    out.println("// Shell it goes inside: " + scadInt(d.n) + " sides"
              + ", bottom perimeter " + scadNum(s.cylinder.y) + " mm"
              + ", top perimeter " + scadNum(s.cylinder.x) + " mm"
              + ", height " + scadNum(s.cylinder.z) + " mm.");
    out.println("// Derived circumradii: bottom " + scadNum(d.botR)
              + ", top " + scadNum(d.topR) + ".");
    out.println("// Clearance of " + scadNum(f.clearanceMM)
              + " mm is already subtracted from the radii and the height below.");
    out.println("// Ring phase " + scadNum(d.phaseDeg)
              + " deg aligns the wall struts with the shell's folded corners.");
  }
  out.println();

  out.println("flap_length = " + scadNum(f.flapLength)
            + ";  // wedge flap length at the top of each wall strut");
  out.println();

  // The whole assembly sits inside a difference() so the top slice shears every wall strut
  // off flat at the cap plane, however far its flap overshoots.
  out.println("// --- ASSEMBLY: wall struts sheared flush at the top plane ---");
  out.println("difference() {");
  out.println("  union() {");
  if (p.box) {
    out.println("    boxCage("
              + scadNum(p.botL) + ", "
              + scadNum(p.botW) + ", "
              + scadNum(p.topL) + ", "
              + scadNum(p.topW) + ", "
              + scadNum(p.height) + ", "
              + scadNum(p.strutRadius) + ", "
              + (hasRigs ? "true" : "false") + ");");
  } else {
    out.println("    frustumCage("
              + scadInt(p.n) + ", "
              + scadNum(p.botR) + ", "
              + scadNum(p.topR) + ", "
              + scadNum(p.height) + ", "
              + scadNum(p.strutRadius) + ", "
              + scadNum(p.phaseDeg) + ", "
              + (hasRigs ? "true" : "false") + ");");
  }

  if (hasRigs) {
    out.println();
    out.println("    // --- INTERNAL RIGS (" + f.rigs.size() + ") ---");
    for (int i = 0; i < f.rigs.size(); i++) {
      Rig r = f.rigs.get(i);
      String tag = r.preset.equals("Custom") ? "" : "  (" + r.preset + ")";
      out.println("    // Rig " + (i + 1) + tag);
      out.println("    rigSupport("
                + scadNum(p.height) + ", " + scadNum(p.strutRadius) + ", "
                + scadNum(r.w) + ", " + scadNum(r.d) + ", " + scadNum(r.h) + ", "
                + scadNum(r.offX) + ", " + scadNum(r.offY) + ", " + scadNum(r.offZ) + ", "
                + scadNum(r.rot) + ", "
                + (f.dualStruts ? "2" : "1") + ", " + scadNum(f.strutSpacing) + ");");
    }
  }

  out.println("  }");
  writeTopTrimSlice(out, p);
  out.println("}");
  out.println();
}

// Flat disc subtracted at the top cap plane, so the wall struts are cut off straight rather
// than ending in their wedge flaps. Spans z in [h/2 - eR, h/2 + eR]; the base sits exactly
// on the top-vertex plane. Rotationally symmetric, so the ring phase does not reach it.
// A cuboid gets a flat slab the shape of its top, one strut radius wider on every side.
void writeTopTrimSlice(PrintWriter out, FrameScadParams p) {
  out.println("  // Top trimming slice: cuts all wall struts off straight");
  if (p.box) {
    float sl = p.topL + 2 * p.strutRadius, sw = p.topW + 2 * p.strutRadius;
    out.println("  translate([" + scadNum(-sl / 2) + ", " + scadNum(-sw / 2) + ", "
              + scadNum(p.height / 2 - p.strutRadius) + "])");
    out.println("    cube([" + scadNum(sl) + ", " + scadNum(sw) + ", "
              + scadNum(p.strutRadius * 2) + "]);");
    return;
  }
  out.println("  translate([0, 0, " + scadNum(p.height / 2 - p.strutRadius) + "])");
  out.println("    cylinder(h = " + scadNum(p.strutRadius * 2)
            + ", r = " + scadNum(p.topR + p.strutRadius) + ", $fn = 64);");
}
