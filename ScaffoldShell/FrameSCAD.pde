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

ArrayList<Integer> framedShapeIndices() {
  ArrayList<Integer> out = new ArrayList<Integer>();
  if (shapes == null) return out;
  for (int i = 0; i < shapes.size(); i++) {
    ShapeSpec s = shapes.get(i);
    if (s.frame != null && s.frame.enabled && frameAvailable(s)) out.add(i);
  }
  return out;
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

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

// Writes one .scad per frame-enabled shape. Returns the paths written, so the caller can
// report them. Called from exportPlan() alongside the PDF and SVGs.
ArrayList<String> exportFrameSCAD(String baseName, String stamp) {
  ArrayList<String> written = new ArrayList<String>();
  ArrayList<Integer> idxs = framedShapeIndices();
  if (idxs.isEmpty()) return written;

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

  for (int idx : idxs) {
    String path = "output/" + baseName + "_" + stamp + "_frame_" + frameShapeSlug(idx) + ".scad";
    if (writeFrameSCAD(shapes.get(idx), idx, path, mainLines, helperLines)) {
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

  FrameSpec f = s.frame;
  FrameDims d = frameDimsFor(s);
  boolean hasRigs = !f.rigs.isEmpty();

  PrintWriter out = createWriter(path);

  out.println("// Internal support scaffold, exported from ScaffoldShell.");
  out.println("// Render with F6, export STL, print. Dimensions are millimetres.");
  out.println("//");
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
  out.println();

  out.println("flap_length = " + scadNum(f.flapLength)
            + ";  // wedge flap length at the top of each wall strut");
  out.println();

  // The whole assembly sits inside a difference() so the top slice shears every wall strut
  // off flat at the cap plane, however far its flap overshoots.
  out.println("// --- ASSEMBLY: wall struts sheared flush at the top plane ---");
  out.println("difference() {");
  out.println("  union() {");
  out.println("    frustumCage("
            + scadInt(p.n) + ", "
            + scadNum(p.botR) + ", "
            + scadNum(p.topR) + ", "
            + scadNum(p.height) + ", "
            + scadNum(p.strutRadius) + ", "
            + scadNum(p.phaseDeg) + ", "
            + (hasRigs ? "true" : "false") + ");");

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

  for (String line : mainLines) out.println(line);
  out.println();
  for (String line : helperLines) out.println(line);

  out.flush();
  out.close();
  println("[Scaffold] wrote " + path);
  return true;
}

// Flat disc subtracted at the top cap plane, so the wall struts are cut off straight rather
// than ending in their wedge flaps. Spans z in [h/2 - eR, h/2 + eR]; the base sits exactly
// on the top-vertex plane. Rotationally symmetric, so the ring phase does not reach it.
void writeTopTrimSlice(PrintWriter out, FrameScadParams p) {
  out.println("  // Top trimming slice: cuts all wall struts off straight");
  out.println("  translate([0, 0, " + scadNum(p.height / 2 - p.strutRadius) + "])");
  out.println("    cylinder(h = " + scadNum(p.strutRadius * 2)
            + ", r = " + scadNum(p.topR + p.strutRadius) + ", $fn = 64);");
}
