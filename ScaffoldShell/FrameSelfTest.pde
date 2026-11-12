//----------------------------------------------------------------------
// FrameSelfTest.pde - Regression check for the frame geometry bridge
//
// The frame's dimensions are derived, not typed, so a mistake in the derivation produces a
// frame that is confidently wrong rather than obviously broken -- it renders, it exports,
// it prints, and it does not fit. This harness pins the derivation down with numbers.
//
// It checks:
//   1. PERIMETER -> CIRCUMRADIUS round-trips exactly.
//   2. The frame's vertex ring lands on the SAME points as the shell's own 3D polygon
//      (getPolygonVertices in tools.pde). This is the phase correction, and it is the one
//      that hurts: at phase 0 the struts miss the corners by tens of millimetres.
//   3. Reproducing FrustumSupport's defaults (n=8, R 20/25, H 40, strut 1, one M5Atom at
//      z 8.5, no clearance) emits the same numbers FrustumSupport's exporter did, so the
//      absorption did not quietly change anyone's existing frames.
//   4. The written .scad: modules called are modules defined, braces balance, and no
//      number carries a locale decimal comma.
//   5. The Frame tab's clicks land on the controls it drew.
//   6. An export writes one file per different scaffold, counted on disk, and says so when
//      a scaffold shares a file or is left out.
//   7. The dimensions file, loaded back, rebuilds the same shapes and the same scaffolds.
//   8. Cuboids: the cage sits in the shell's corners, the .scad builds the same box, the
//      cutouts land on the rig's face, and the Cuboid toggle swaps the sides and diameters
//      for X and Y and back.
//
// Enable with FRAME_SELFTEST = true and run the sketch: it prints a pass/fail table and
// exits. Same shape as AUDIT_MODE in LayoutAudit.pde.
//----------------------------------------------------------------------

final boolean FRAME_SELFTEST = false;   // flip to true to run the checks

int _ftChecks = 0, _ftFails = 0;

void frameSelfTestRun() {
  println("[FRAME SELFTEST]");
  frameTestRadiusRoundTrip();
  frameTestPhaseAlignment();
  frameTestFrustumSupportParity();
  frameTestScadOutput();
  frameTestRigCutouts();
  frameTestTabInteraction();
  frameTestExportSet();
  frameTestDimensionRecord();
  frameTestCuboids();
  println("[FRAME SELFTEST] " + (_ftChecks - _ftFails) + "/" + _ftChecks + " passed"
        + (_ftFails == 0 ? "" : "   <-- " + _ftFails + " FAILED"));
  exit();
}

void ftCheck(String what, boolean ok, String detail) {
  _ftChecks++;
  if (!ok) _ftFails++;
  println("  [" + (ok ? "PASS" : "FAIL") + "] " + what + (detail.isEmpty() ? "" : "   " + detail));
}

void ftNear(String what, float got, float want, float tol) {
  ftCheck(what, abs(got - want) <= tol,
          "got " + nf(got, 0, 4) + ", want " + nf(want, 0, 4));
}

// 1. The conversion docs/shared-concepts.md warns about.
void frameTestRadiusRoundTrip() {
  println(" perimeter <-> circumradius");
  for (int n : new int[]{3, 4, 5, 6, 8, 12}) {
    for (float R : new float[]{5, 20, 25, 97.3}) {
      float perim = 2 * n * R * sin(PI / n);
      ftNear("n=" + n + " R=" + nf(R, 0, 1), circumradiusFromPerimeterMM(perim, n), R, 1e-3);
    }
  }
}

// 2. The frame ring against the shell's own polygon. Both are built for the same shape, so
//    every vertex must coincide -- that is what "the struts sit in the corners" means.
void frameTestPhaseAlignment() {
  println(" strut ring vs shell corners");
  ShapeSpec s = new ShapeSpec();
  s.frame.enabled     = true;
  s.frame.strutRadius = 0;     // no inset, so the ring sits exactly on the shell
  s.frame.clearanceMM = 0;
  s.cylinder = new PVector(160, 160, 50);   // prism: top perimeter == base perimeter

  for (int n : new int[]{3, 4, 5, 6, 7, 8, 12}) {
    s.nSides = n;

    // The shell's own 3D polygon, via the globals the rest of the sketch draws from.
    loadGlobalsFrom(s);
    setParams(false);
    PVector[] shell = getPolygonVertices(false);   // bottom ring, sketch 3D space (px)

    // The frame's ring, through the projection the preview uses.
    FrameGeometry g = buildFrameGeometry(s);
    float worst = 0;
    for (int i = 0; i < n; i++) {
      PVector f = frameToLocalPx(g.cageVertices.get(i));
      worst = max(worst, dist(f.x, f.z, shell[i].x, shell[i].z));
    }
    ftCheck("n=" + n + " ring coincides with shell corners", worst < 0.01,
            "worst vertex gap " + nf(worst, 0, 5) + " px");
  }
}

// 3. Parity with the tool this absorbed. FrustumSupport wrote these literals:
//      frustum(8, 20.0, 25.0, 40.0, 1.0)
//      rigSupport(40.0, 1.0, 24.0, 24.0, 31.5, 0.0, 0.0, 8.5, 0.0, 1, 15.0)
//      trim slice at z = 40/2 - 1 = 19, h = 2, r = 25 + 1 = 26
//    Anything here that has moved would silently change frames people already printed.
void frameTestFrustumSupportParity() {
  println(" parity with FrustumSupport defaults");
  int n = 8;
  float wantBotR = 20, wantTopR = 25, wantH = 40;

  ShapeSpec s = new ShapeSpec();
  s.nSides   = n;
  s.cylinder = new PVector(2 * n * wantTopR * sin(PI / n),   // x = top perimeter
                           2 * n * wantBotR * sin(PI / n),   // y = base perimeter
                           wantH);
  s.frame.enabled     = true;
  s.frame.strutRadius = 1.0;
  s.frame.clearanceMM = 0;      // FrustumSupport had no clearance concept
  s.frame.rigs.add(new Rig(24, 24, 31.5, 0, 0, 8.5, 0));

  FrameScadParams p = frameScadParamsFor(s);
  ftCheck("params valid", p.valid, p.problem);
  ftCheck("nside", p.n == n, "got " + p.n);
  ftNear("frustum_bottom_radius", p.botR, wantBotR, 1e-3);
  ftNear("frustum_top_radius",    p.topR, wantTopR, 1e-3);
  ftNear("frustum_height",        p.height, wantH, 1e-3);
  ftNear("edge_radius",           p.strutRadius, 1.0, 1e-6);

  // The trim slice, recomputed the way writeTopTrimSlice() does.
  ftNear("trim slice z",      p.height / 2 - p.strutRadius, 19.0, 1e-3);
  ftNear("trim slice height", p.strutRadius * 2,             2.0, 1e-3);
  ftNear("trim slice radius", p.topR + p.strutRadius,       26.0, 1e-3);

  // Phase is the one deliberate departure: FrustumSupport used 0 and put its struts in the
  // middle of the facets. -112.5 for n=8.
  ftNear("ring phase", p.phaseDeg, -112.5, 1e-4);

  // Rig geometry: the post ring and the spine, against FrustumSupport's own arithmetic.
  FrameGeometry g = buildFrameGeometry(s);
  float eR = 1.0;
  float hEff    = (wantH - 2 * eR);
  float zBottom = -hEff / 2;
  ftNear("z_bottom",     g.zBottom, zBottom, 1e-3);
  ftNear("rig box top",  g.highestRigTop, zBottom + 8.5 - 2 * eR + 31.5, 1e-3);
  ftCheck("4 posts in single-strut mode", g.rigPosts.size() == 4, "got " + g.rigPosts.size());
  ftCheck("floor spokes present with a rig", g.floorSpokes.size() == n,
          "got " + g.floorSpokes.size());

  s.frame.dualStruts = true;
  ftCheck("8 posts in dual-strut mode", buildFrameGeometry(s).rigPosts.size() == 8, "");

  // An empty frame is FrustumSupport's "simple" mode: cage only, no floor bracing.
  s.frame.rigs.clear();
  FrameGeometry bare = buildFrameGeometry(s);
  ftCheck("empty frame drops the floor spokes", bare.floorSpokes.size() == 0,
          "got " + bare.floorSpokes.size());
  ftCheck("empty frame keeps the cage", bare.cageWallStruts.size() == n, "");
}

// 4. The written file itself.
//
// The decimal-separator check is not paranoia: this is a Processing sketch, and
// Processing's nf() formats through NumberFormat.getInstance(), which follows the machine's
// locale. On a machine set to a comma-decimal locale -- Dutch, German, French -- nf(19.1)
// returns "19,1", and OpenSCAD reads that as two arguments. The file would look fine in a
// text editor and fail to parse. scadNum() pins Locale.US to prevent it; this asserts it.
void frameTestScadOutput() {
  println(" written .scad");

  String[] mainLines   = loadStrings(FRAME_TEMPLATE_MAIN);
  String[] helperLines = loadStrings(FRAME_TEMPLATE_HELPER);
  ftCheck("OpenSCAD module libraries present in data/",
          mainLines != null && helperLines != null, "");
  if (mainLines == null || helperLines == null) return;

  int n = 8;
  ShapeSpec s = new ShapeSpec();
  s.label    = "selftest";
  s.nSides   = n;
  s.cylinder = new PVector(2 * n * 25.0 * sin(PI / n), 2 * n * 20.0 * sin(PI / n), 40);
  s.frame.enabled = true;
  s.frame.rigs.add(new Rig(24, 24, 31.5, 3.5, -2.25, 8.5, 30));

  if (shapes == null) shapes = new ArrayList<ShapeSpec>();
  shapes.add(s);
  int idx = shapes.size() - 1;

  String path = "output/selftest_frame.scad";
  ftCheck("writeFrameSCAD returned true",
          writeFrameSCAD(s, idx, path, mainLines, helperLines), "");

  String[] out = loadStrings(path);
  ftCheck("file readable back", out != null, "");
  if (out == null) return;

  boolean callsCage = false, callsRig = false, definesCage = false, definesRig = false;
  boolean definesHelper = false, badDecimal = false;
  String firstBad = "";
  for (String line : out) {
    String code = line.contains("//") ? line.substring(0, line.indexOf("//")) : line;
    if (code.contains("frustumCage(") && !code.contains("module")) callsCage = true;
    if (code.contains("rigSupport(")  && !code.contains("module")) callsRig  = true;
    if (code.contains("module frustumCage")) definesCage = true;
    if (code.contains("module rigSupport")) definesRig = true;
    if (code.contains("module _local_draw_edge")) definesHelper = true;
    // A digit, a comma, a digit -- the signature of a locale-formatted decimal.
    if (code.matches(".*[0-9],[0-9].*")) {
      badDecimal = true;
      if (firstBad.isEmpty()) firstBad = trim(code);
    }
  }
  ftCheck("no locale decimal commas in the numbers", !badDecimal, firstBad);
  ftCheck("calls frustumCage()", callsCage, "");
  ftCheck("calls rigSupport()", callsRig, "");
  ftCheck("defines frustumCage()", definesCage, "");
  ftCheck("defines rigSupport()", definesRig, "");
  ftCheck("defines the _local_draw_* helpers", definesHelper, "");

  // Every module the file calls must also be defined in it -- FrustumSupport would emit a
  // file calling modules it never wrote when a data/ template failed to load.
  ftCheck("balanced braces", frameCountChar(out, '{') == frameCountChar(out, '}'),
          frameCountChar(out, '{') + " open, " + frameCountChar(out, '}') + " close");

  shapes.remove(idx);
}

// 5. Rig cutouts (RigCutout.pde) land where the rig is. The plan is made in FS millimetres
//    without any globals; here it is projected through the paper's OWN frames -- LidFrame
//    and SidePanelFrame, the ones the 3D preview uses -- and must meet the rig's face.
void frameTestRigCutouts() {
  println(" rig cutouts");
  ShapeSpec s = new ShapeSpec();
  s.nSides   = 4;
  s.cylinder = new PVector(160, 160, 50);   // 40 mm square prism, 50 tall
  s.frame.enabled     = true;
  s.frame.strutRadius = 1.0;
  s.frame.clearanceMM = 0.4;
  loadGlobalsFrom(s);
  setParams(false);

  // Top: a rig whose top sits 1 mm under the lid, off-centre and turned.
  Rig r = new Rig(24, 24, 31.5, 3, -4, 0, 20);
  s.frame.rigs.add(r);
  FrameGeometry g = buildFrameGeometry(s);
  r.offZ = (s.cylinder.z / 2 - 1) - (g.zBottom - 2 * s.frame.strutRadius + r.h);
  r.cutoutFace = RIG_CUT_TOP;
  RigCutoutPlan p = planRigCutout(s, buildFrameGeometry(s), 0);
  ftCheck("top: reaches the lid", p != null && p.onLid && p.reaches, p == null ? "null" : p.status);
  if (p != null) {
    ftNear("top: gap", p.gapMM, 1, 1e-3);
    ftNear("top: auto size for a 24 mm face", p.sizeMM, CUTOUT_SIZE_SMALL, 1e-6);
    ftCheck("top: fits the lid", p.fits, p.status);
    PVector want = frameToLocalPx(new PVector(r.offX, r.offY, s.cylinder.z / 2));
    PVector got  = lidLocalTo3D(p.localMM, true);
    ftNear("top: lands over the rig", PVector.dist(got, want), 0, 0.01);
  }

  r.offZ = 0;
  p = planRigCutout(s, buildFrameGeometry(s), 0);
  ftCheck("top: a low rig cuts nothing", p != null && !p.reaches, p == null ? "null" : p.status);

  // Side: every face of an unturned rig, pushed toward the wall it names. The apothem is
  // 20 mm; the face is put 1.5 mm inside it, under the 2 mm reach (strut radius + 1).
  r.rot = 0;
  r.offZ = 5;
  int[]     faces = { RIG_CUT_POS_X, RIG_CUT_NEG_X, RIG_CUT_POS_Y, RIG_CUT_NEG_Y };
  float[][] dirs  = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} };
  for (int k = 0; k < faces.length; k++) {
    r.cutoutFace = faces[k];
    r.offX = dirs[k][0] * (18.5 - r.w / 2);
    r.offY = dirs[k][1] * (18.5 - r.d / 2);
    g = buildFrameGeometry(s);
    p = planRigCutout(s, g, 0);
    String name = RIG_CUT_FACE_NAMES[faces[k]];
    ftCheck(name + ": touches a wall", p != null && !p.onLid && p.reaches && p.panel >= 0,
            p == null ? "null" : p.status);
    if (p == null || p.panel < 0) continue;
    ftNear(name + ": gap", p.gapMM, 1.5, 1e-3);

    // The face centre, pushed out onto the wall, in the sketch's 3D.
    float[] box = g.rigBoxes.get(0);
    PVector want = frameToLocalPx(new PVector(dirs[k][0] * 20 + (dirs[k][0] == 0 ? box[0] : 0),
                                              dirs[k][1] * 20 + (dirs[k][1] == 0 ? box[1] : 0),
                                              box[2]));
    PVector got = sidePanelLocalTo3D(sidePanelBasis3D(p.panel), p.localMM);
    ftNear(name + ": lands on the face, panel " + (p.panel + 1), PVector.dist(got, want), 0, 0.01);
  }

  // 3 mm from the wall is past the reach.
  r.cutoutFace = RIG_CUT_POS_X;
  r.offX = 17 - r.w / 2; r.offY = 0;
  p = planRigCutout(s, buildFrameGeometry(s), 0);
  ftCheck("3 mm off the wall cuts nothing", p != null && p.panel >= 0 && !p.reaches,
          p == null ? "null" : p.status);

  // A face pointing at a corner looks at no wall squarely.
  r.cutoutFace = RIG_CUT_POS_X;
  r.offX = 0; r.offY = 0; r.rot = 45;
  p = planRigCutout(s, buildFrameGeometry(s), 0);
  ftCheck("corner-on face cuts nothing", p != null && p.panel < 0, p == null ? "null" : p.status);
}

int frameCountChar(String[] lines, char c) {
  int n = 0;
  for (String line : lines) {
    String code = line.contains("//") ? line.substring(0, line.indexOf("//")) : line;
    for (int i = 0; i < code.length(); i++) if (code.charAt(i) == c) n++;
  }
  return n;
}

// 5. The Frame tab responds to clicks where it draws its controls.
//
// The tab lays itself out and hit-tests against the SAME row list, so this is really a
// check that the two walks stay in step -- including after scrolling, which moves every
// row. Clicks go through the sketch's own dispatcher, the way LayoutAudit's do.
void frameTestTabInteraction() {
  println(" Frame tab interaction");
  if (sidebar == null || shapes == null || shapes.isEmpty()) {
    ftCheck("sidebar ready", false, "");
    return;
  }
  sidebar.activeMainTab = MAIN_TAB_FRAME;
  frameScrollY = 0;
  FrameSpec f = shapes.get(selectedShapeIdx).frame;
  f.enabled = false;

  ftCheck("enable toggle turns a frame on", ftClickRow("frame_enabled", 0) && f.enabled, "");

  float before = f.strutRadius;
  ftCheck("strut radius [+] increases it", ftClickRow("strut_radius", +1)
          && f.strutRadius > before, "now " + nf(f.strutRadius, 0, 2));
  ftCheck("strut radius [-] decreases it", ftClickRow("strut_radius", -1)
          && abs(f.strutRadius - before) < 1e-4, "back to " + nf(f.strutRadius, 0, 2));

  int nBefore = f.rigs.size();
  ftCheck("Add rig adds one", ftClickRow("rig_add", 0) && f.rigs.size() == nBefore + 1, "");
  ftCheck("Remove rig removes one", ftClickRow("rig_remove", 0) && f.rigs.size() == nBefore, "");

  // --- scrolling -----------------------------------------------------------
  // Whether the tab actually overflows depends on the window, so the checks below are
  // about the machinery, not about this particular size.
  f.rigs.add(new Rig(24, 24, 31.5, 0, 0, 8.5, 0));
  frameRows();                       // one layout pass, so the content height is known
  float contentH = _frameContentH;
  ftCheck("content height is measured", contentH > 0, nf(contentH, 0, 0) + "px");

  // The tab has a scrollbar because it does not fit at the window size the layout is
  // documented to support. If this ever stops being true the scrolling can go.
  float minViewport = MIN_WIN_H - SIDEBAR_PADDING - (sidebar.contentY + SIDEBAR_PADDING);
  ftCheck("overflows at the minimum window height", contentH > minViewport,
          nf(contentH, 0, 0) + "px of content vs " + nf(minViewport, 0, 0) + "px at "
          + MIN_WIN_W + "x" + MIN_WIN_H);

  // Asking to scroll past the end lands exactly at the end, never beyond it.
  frameScrollY = 99999;
  frameRows();
  ftNear("scroll clamps to the content", frameScrollY, frameScrollMax(), 0.01);

  // And the hit-test follows the rows wherever the scroll put them. At a window tall
  // enough to fit the tab that offset is zero, which is still worth asserting.
  float rotBefore = f.selectedRig().rot;
  ftCheck("a row still hits its own control at scroll " + nf(frameScrollY, 0, 0),
          ftClickRow("rig_6", +1) && f.selectedRig().rot > rotBefore,
          "rotation " + nf(f.selectedRig().rot, 0, 1));
  frameScrollY = 0;
}

// Clicks a row by id: dir 0 hits the row itself (toggle / button), +1 / -1 the step buttons.
// Returns false if the row is not on the tab at all, which is itself a failure.
boolean ftClickRow(String id, int dir) {
  for (FrameRow row : frameRows()) {
    if (!row.id.equals(id)) continue;
    float[] r = (dir == 0) ? new float[]{ row.x, row.y, row.w, row.h }
                           : frameStepBtnRect(row, dir > 0);
    clickAt(r[0] + r[2] / 2, r[1] + r[3] / 2);
    return true;
  }
  return false;
}

// 6. What leaves the sketch. The counts come off the disk, not from what the export reports,
//    because the failure this guards against reported two files and left one.
ShapeSpec ftFramedShape(float perim, float h) {
  ShapeSpec s = new ShapeSpec();
  s.nSides   = 6;
  s.cylinder = new PVector(perim, perim, h);
  s.frame.enabled = true;
  return s;
}

void ftSetShapes(ShapeSpec... list) {
  shapes = new ArrayList<ShapeSpec>(java.util.Arrays.asList(list));
}

// .scad files in output/ starting with tag. Removes them, so a run leaves nothing behind.
int ftTakeFiles(String tag) {
  int count = 0;
  java.io.File[] files = new java.io.File(sketchPath("output")).listFiles();
  if (files == null) return 0;
  for (java.io.File file : files) {
    if (file.getName().startsWith(tag) && file.getName().endsWith(".scad")) {
      count++;
      file.delete();
    }
  }
  return count;
}

int ftTakeRecords(String tag) {
  int count = 0;
  java.io.File[] files = new java.io.File(sketchPath("output")).listFiles();
  if (files == null) return 0;
  for (java.io.File file : files) {
    if (file.getName().startsWith(tag) && file.getName().endsWith("_dimensions.json")) {
      count++;
      file.delete();
    }
  }
  return count;
}

int ftExportFiles() {
  exportFrameSCAD("selftest_set", "T");
  return ftTakeFiles("selftest_set");
}

void frameTestExportSet() {
  println(" export set");
  ArrayList<ShapeSpec> realShapes = shapes;

  ftSetShapes(ftFramedShape(180, 60), ftFramedShape(180, 30));
  ftCheck("two different scaffolds, two files", ftExportFiles() == 2, "");

  ShapeSpec off = ftFramedShape(180, 30);
  off.frame.enabled = false;
  ftSetShapes(ftFramedShape(180, 60), off);
  ftCheck("a shape with its scaffold off is left out", ftExportFiles() == 1, "");
  ftCheck("and the plan says so", frameExportPlan().get(1).status.equals("scaffold off"),
          frameExportPlan().get(1).status);
  ftCheck("and it is not a shortfall", frameExportNote(1).isEmpty(), frameExportNote(1));

  ShapeSpec twice = ftFramedShape(180, 60);
  twice.nRep = 2;
  ftSetShapes(twice);
  ftCheck("two copies of one shape, one file", ftExportFiles() == 1, "");

  // --- identical scaffolds ---
  ftSetShapes(ftFramedShape(180, 60), ftFramedShape(180, 60));
  ftCheck("identical scaffolds, one file", ftExportFiles() == 1, "");
  ftCheck("the second points at the first", frameExportPlan().get(1).sameAs == 0, "");
  ftCheck("and the note counts it", frameExportNote(1).equals(", 1 identical"), frameExportNote(1));

  ftSetShapes(ftFramedShape(180, 60), ftFramedShape(180, 30), ftFramedShape(180, 60));
  ftCheck("a matching pair and a different one, two files", ftExportFiles() == 2, "");

  // The rig's name only reaches a comment, so these print the same.
  ShapeSpec named = ftFramedShape(180, 60), plain = ftFramedShape(180, 60);
  named.frame.rigs.add(new Rig(24, 24, 31.5, 0, 0, 8.5, 0));
  plain.frame.rigs.add(new Rig(24, 24, 31.5, 0, 0, 8.5, 0));
  named.frame.rigs.get(0).preset = "M5Atom lying";
  ftSetShapes(named, plain);
  ftCheck("a name in a comment is not a difference", ftExportFiles() == 1, "");

  plain.frame.rigs.get(0).offX += 1;
  ftCheck("a rig moved 1 mm is", ftExportFiles() == 2, "");
  plain.frame.rigs.get(0).offX -= 1;
  plain.frame.dualStruts = !plain.frame.dualStruts;
  ftCheck("and so is a strut setting", ftExportFiles() == 2, "");

  // --- filenames ---
  ShapeSpec a = ftFramedShape(180, 60), b = ftFramedShape(180, 30), c = ftFramedShape(180, 45);
  a.label = "Cup";
  b.label = "Cup";
  ftSetShapes(a, b);
  ftCheck("the same label does not overwrite", ftExportFiles() == 2, "");
  b.label = "cup";
  ftCheck("nor does the same label in another case", ftExportFiles() == 2, "");
  c.label = "Cup_2";
  ftSetShapes(a, b, c);
  ftCheck("nor does a label that looks like the fix", ftExportFiles() == 3, "");

  // --- left out, and saying so ---
  ShapeSpec hollow = ftFramedShape(180, 30);
  hollow.hollowMode = true;
  ftSetShapes(ftFramedShape(180, 60), hollow);
  ftCheck("a hollow shape is left out", ftExportFiles() == 1, "");
  ftCheck("and counted as skipped", frameExportNote(1).equals(", 1 skipped"), frameExportNote(1));

  ftSetShapes(ftFramedShape(180, 60), ftFramedShape(6, 3));
  ftCheck("a scaffold that cannot fit is left out", ftExportFiles() == 1, "");
  ftCheck("and counted as skipped", frameExportNote(1).equals(", 1 skipped"), frameExportNote(1));

  // --- the tab, on the real shape list ---
  shapes = realShapes;
  sidebar.activeMainTab = MAIN_TAB_FRAME;
  shapes.get(selectedShapeIdx).frame.enabled = true;
  addShape();
  ShapeSpec added = shapes.get(shapes.size() - 1);
  ftCheck("a new shape starts without a scaffold", !added.frame.enabled, "");

  added.frame.enabled = true;
  added.cylinder = new PVector(added.cylinder.x, added.cylinder.y, added.cylinder.z / 2);
  String keptName = uiExportFilename;
  uiExportFilename = "selftest_all";
  frameRows();
  frameScrollY = frameScrollMax();
  ftCheck("Export all is clickable and writes both", ftClickRow("frame_export_all", 0)
          && ftTakeFiles("selftest_all") == 2, "");
  ftCheck("and the notification counts them", exportNotifyPath.startsWith("2 scaffolds"), exportNotifyPath);
  ftCheck("and the dimensions file", ftTakeRecords("selftest_all") == 1, "");
  frameScrollY = 0;
  uiExportFilename = keptName;
}

boolean ftLabelSurvives(String label) {
  ShapeSpec s = ftFramedShape(180, 30);
  s.label = label;
  ftSetShapes(s);
  String path = exportShapeRecord("selftest_label", "T");
  JSONArray arr = loadJSONArray(path);
  new java.io.File(sketchPath(path)).delete();
  return arr != null && label.equals(arr.getJSONObject(0).getString("label", ""));
}

// 7. The record is only worth keeping if it brings the piece back, so this goes through the
//    file: write it, read it from disk, rebuild, and compare what OpenSCAD would build.
//    The awkward perimeter is deliberate - a value that rounds would pass with clean numbers.
void frameTestDimensionRecord() {
  println(" dimensions file");
  ArrayList<ShapeSpec> realShapes = shapes;
  int realSelected = selectedShapeIdx;
  selectedShapeIdx = 0;

  ShapeSpec frustum = ftFramedShape(187.33334, 61.7);
  frustum.cylinder.y = 241.07;
  frustum.label = "Lamp base";
  frustum.tabDepth = 12.5;
  frustum.fillColorEnabled = true;
  frustum.shapeColor = color(200, 40, 90);
  frustum.frame.strutRadius = 1.3;
  frustum.frame.clearanceMM = 0.55;
  frustum.frame.dualStruts = true;
  frustum.frame.strutSpacing = 11.25;
  frustum.frame.flapLength = 6.5;
  Rig rig = new Rig(24, 31.5, 8.25, 3.5, -2.25, 8.5, 30);
  rig.preset = "M5Atom lying";
  rig.cutoutFace = RIG_CUT_TOP;
  rig.cutoutSize = 2;
  frustum.frame.rigs.add(rig);

  ShapeSpec plain = ftFramedShape(180, 30);
  plain.frame.enabled = false;

  ShapeSpec hollow = ftFramedShape(180, 30);
  hollow.hollowMode = true;
  hollow.wallThickness = 3.5;
  hollow.frame.enabled = false;

  ShapeSpec box = ftFramedShape(160, 40);
  box.nSides = 4;
  box.cuboidMode = true;

  ftSetShapes(frustum, plain, hollow, box);
  String path = exportShapeRecord("selftest_record", "T");
  JSONArray arr = loadJSONArray(path);
  ftCheck("one entry per shape, scaffold or not", arr != null && arr.size() == 4, "");
  if (arr == null || arr.size() != 4) return;

  ArrayList<ShapeSpec> back = new ArrayList<ShapeSpec>();
  for (int i = 0; i < arr.size(); i++) back.add(buildShapeFromJSON(arr.getJSONObject(i)));
  ShapeSpec f2 = back.get(0);

  ftCheck("sides come back", f2.nSides == frustum.nSides, "");
  ftCheck("the label comes back", "Lamp base".equals(f2.label), f2.label);
  ftCheck("the height comes back exactly", f2.cylinder.z == frustum.cylinder.z, "");
  ftCheck("the top perimeter comes back exactly", f2.cylinder.x == frustum.cylinder.x, "");
  ftCheck("a frustum stays a frustum", f2.cylinder.y == frustum.cylinder.y, "");
  ftCheck("tab depth comes back", f2.tabDepth == frustum.tabDepth, "");
  ftCheck("colour comes back", f2.fillColorEnabled && f2.shapeColor == frustum.shapeColor, "");
  ftCheck("the sidebar's diameters match the perimeters",
          abs(f2.uiBotW - shapeDiameterFromPerimeter(241.07, 6)) < 1e-3 && !f2.uiLock, "");

  ftCheck("the scaffold comes back switched on", f2.frame.enabled, "");
  ftCheck("the rig comes back with its cutout", f2.frame.rigs.size() == 1
          && f2.frame.rigs.get(0).preset.equals("M5Atom lying")
          && f2.frame.rigs.get(0).cutoutFace == RIG_CUT_TOP
          && f2.frame.rigs.get(0).cutoutSize == 2, "");
  ftCheck("OpenSCAD would build the same scaffold",
          frameScadKey(f2, frameScadParamsFor(f2)).equals(frameScadKey(frustum, frameScadParamsFor(frustum))), "");

  ftCheck("no scaffold stays no scaffold", !back.get(1).frame.enabled, "");
  ftCheck("hollow comes back", back.get(2).hollowMode && back.get(2).wallThickness == 3.5, "");
  ftCheck("cuboid is recorded", arr.getJSONObject(3).hasKey("cuboid_mm"), "");
  ftCheck("and flagged as not rebuilt", jsonApproximatedCount(arr) == 1, "");

  // A shape selected when the file loads must not leak its modes into what is loaded.
  hollowMode = true;
  ftCheck("the selected shape's modes do not leak in",
          !buildShapeFromJSON(arr.getJSONObject(1)).hollowMode, "");
  hollowMode = false;

  JSONObject old = JSONObject.parse("{ \"sides\": 6, \"diameter\": 100, \"height\": 20 }");
  ftNear("a plain diameter file still loads", buildShapeFromJSON(old).cylinder.x, 300, 0.01);

  String raw = join(loadStrings(path), " ");
  ftCheck("no locale decimal commas", !raw.matches(".*[0-9],[0-9].*"), "");
  ftCheck("no float noise in the numbers", !raw.matches(".*\\.[0-9]{8,}.*"), "");
  ftCheck("a shape reads from its name down", raw.indexOf("\"name\"") < raw.indexOf("\"sides\"")
          && raw.indexOf("\"sides\"") < raw.indexOf("\"height\"")
          && raw.indexOf("\"height\"") < raw.indexOf("\"scaffold\""), "");
  ftCheck("a label that needs escaping survives", ftLabelSurvives("Lamp \"A\" \\ base"), "");
  new java.io.File(sketchPath(path)).delete();

  shapes = realShapes;
  selectedShapeIdx = realSelected;
  loadGlobalsFrom(shapes.get(selectedShapeIdx));
  setParams(false);
}

// 8. Cuboids. Everything a regular shell is checked for above, for a shell whose top and
//    bottom are rectangles -- including ones that taper in one direction only, where a
//    length and a width wall lean differently.
ShapeSpec ftCuboid(float topL, float topW, float botL, float botW, float h) {
  ShapeSpec s = new ShapeSpec();
  s.nSides     = 4;
  s.uiSides    = 4;
  s.cuboidMode = true;
  s.uiCubTopLen = topL; s.uiCubTopWid = topW;
  s.uiCubBotLen = botL; s.uiCubBotWid = botW;
  s.cylinder = new PVector(2 * (topL + topW), 2 * (botL + botW), h);
  s.frame.enabled = true;
  return s;
}

// The cuboid's globals, with its edge arrays filled from its X and Y as applyToModel() does.
void ftLoadCuboid(ShapeSpec s) {
  loadGlobalsFrom(s);
  syncEdgesFromPerimeters();
  setParams(false);
}

void frameTestCuboids() {
  println(" cuboids");
  ArrayList<ShapeSpec> realShapes = shapes;
  int realSelected = selectedShapeIdx;
  int realTab = sidebar.activeMainTab;

  // --- the cage against the shell's own corners ---
  float[][] sizes = { {40, 40, 40, 40}, {60, 40, 60, 40}, {50, 40, 70, 40}, {40, 50, 60, 30} };
  for (float[] sz : sizes) {
    ShapeSpec s = ftCuboid(sz[0], sz[1], sz[2], sz[3], 50);
    s.frame.strutRadius = 0;    // no inset, so the cage sits exactly on the shell
    s.frame.clearanceMM = 0;
    ftLoadCuboid(s);
    PVector[] bot = getPolygonVertices(false), top = getPolygonVertices(true);
    FrameGeometry g = buildFrameGeometry(s);
    float worst = 0;
    for (int i = 0; i < 4; i++) {
      PVector fb = frameToLocalPx(g.cageWallStruts.get(i)[0]);
      PVector ft = frameToLocalPx(g.cageWallStruts.get(i)[1]);
      worst = max(worst, max(dist(fb.x, fb.z, bot[i].x, bot[i].z), dist(ft.x, ft.z, top[i].x, top[i].z)));
    }
    ftCheck("top " + nf(sz[0], 0, 0) + "x" + nf(sz[1], 0, 0) + ", bottom " + nf(sz[2], 0, 0) + "x"
          + nf(sz[3], 0, 0) + ": cage corners on the shell's", worst < 0.01,
            "worst gap " + nf(worst, 0, 5) + " px");
  }

  // --- clearance and strut radius, square off each wall ---
  ShapeSpec s = ftCuboid(50, 40, 70, 40, 50);   // tapers along X only; strut 1, clearance 0.4
  FrameGeometry g = buildFrameGeometry(s);
  ftNear("inset: bottom corner 0 x", g.cageVertices.get(0).x, -(35 - 1.4), 1e-3);
  ftNear("inset: bottom corner 0 y", g.cageVertices.get(0).y, -(20 - 1.4), 1e-3);
  ftNear("inset: top corner 2 x", g.cageWallStruts.get(2)[1].x, 25 - 1.4, 1e-3);
  ftNear("inset: top corner 2 y", g.cageWallStruts.get(2)[1].y, 20 - 1.4, 1e-3);

  // --- the written file builds the same box ---
  String[] mainLines   = loadStrings(FRAME_TEMPLATE_MAIN);
  String[] helperLines = loadStrings(FRAME_TEMPLATE_HELPER);
  s.frame.rigs.add(new Rig(24, 24, 31.5, 0, 0, 5, 0));
  ftSetShapes(s);
  String path = "output/selftest_cuboid.scad";
  ftCheck("cuboid: writeFrameSCAD returned true", writeFrameSCAD(s, 0, path, mainLines, helperLines), "");
  String[] out = loadStrings(path);
  new java.io.File(sketchPath(path)).delete();
  FrameScadParams p = frameScadParamsFor(s);
  ftNear("cuboid: frame length is the shell's less two clearances", p.botL, 70 - 0.8, 1e-4);
  String wantCall = "boxCage(" + scadNum(p.botL) + ", " + scadNum(p.botW) + ", " + scadNum(p.topL) + ", "
                  + scadNum(p.topW) + ", " + scadNum(p.height) + ", " + scadNum(p.strutRadius) + ", true);";
  String wantSlab = "cube([" + scadNum(p.topL + 2 * p.strutRadius) + ", " + scadNum(p.topW + 2 * p.strutRadius);
  boolean callsBox = false, callsFrustum = false, definesBox = false, slab = false;
  if (out != null) {
    for (String line : out) {
      String code = line.contains("//") ? line.substring(0, line.indexOf("//")) : line;
      if (code.contains(wantCall)) callsBox = true;
      if (trim(code).startsWith("frustumCage(")) callsFrustum = true;
      if (code.contains("module boxCage")) definesBox = true;
      if (code.contains(wantSlab)) slab = true;
    }
  }
  ftCheck("cuboid: calls boxCage() with the preview's numbers", callsBox, wantCall);
  ftCheck("cuboid: does not call frustumCage()", !callsFrustum, "");
  ftCheck("cuboid: defines boxCage()", definesBox, "");
  ftCheck("cuboid: trims the top with a slab its own shape", slab, wantSlab);
  ftCheck("cuboid: balanced braces", out != null && frameCountChar(out, '{') == frameCountChar(out, '}'), "");
  // What boxCage() computes for corner 0, against the preview's corner 0.
  ftNear("cuboid: .scad corner 0 x is the preview's", -(p.botL / 2 - p.strutRadius), g.cageVertices.get(0).x, 1e-4);

  // --- what it refuses ---
  FrameScadParams tiny = frameScadParamsFor(ftCuboid(2, 2, 30, 30, 50));
  ftCheck("cuboid: a 2 mm side is refused", !tiny.valid && tiny.problem.contains("width"), tiny.problem);
  ShapeSpec five = ftCuboid(50, 40, 70, 40, 50);
  five.nSides = 5;
  ftCheck("cuboid mode at 5 sides gets no scaffold", !frameAvailable(five), frameUnavailableReason(five));

  // --- one file per different scaffold ---
  ftSetShapes(ftCuboid(50, 40, 70, 40, 50), ftCuboid(50, 40, 70, 40, 50));
  ftCheck("cuboid: identical cuboids, one file", ftExportFiles() == 1, "");
  ftSetShapes(ftCuboid(50, 40, 70, 40, 50), ftCuboid(40, 50, 40, 70, 50));
  ftCheck("cuboid: the same cuboid turned 90 degrees, two files", ftExportFiles() == 2, "");

  // --- the dimensions record ---
  ftSetShapes(ftCuboid(50, 40, 70, 40, 50));
  JSONObject rec = shapeRecord(frameExportPlan().get(0)).getJSONObject("scaffold");
  ftCheck("cuboid record: frame lengths, not radii",
          rec.hasKey("frame_bottom_length_mm") && !rec.hasKey("frame_top_radius_mm"), "");
  ftNear("cuboid record: frame bottom length", rec.getFloat("frame_bottom_length_mm"), 69.2, 1e-4);

  // --- cutouts: top lid ---
  s = ftCuboid(50, 40, 70, 40, 50);
  ftSetShapes(s);
  ftLoadCuboid(s);
  Rig r = new Rig(24, 24, 31.5, 5, -3, 0, 0);
  s.frame.rigs.add(r);
  g = buildFrameGeometry(s);
  r.offZ = (s.cylinder.z / 2 - 1) - (g.zBottom - 2 * s.frame.strutRadius + r.h);
  r.cutoutFace = RIG_CUT_TOP;
  RigCutoutPlan cp = planRigCutout(s, buildFrameGeometry(s), 0);
  ftCheck("cuboid top: reaches the lid and fits", cp != null && cp.onLid && cp.reaches && cp.fits,
          cp == null ? "null" : cp.status);
  if (cp != null) {
    PVector want = frameToLocalPx(new PVector(r.offX, r.offY, s.cylinder.z / 2));
    ftNear("cuboid top: lands over the rig", PVector.dist(lidLocalTo3D(cp.localMM, true), want), 0, 0.01);
  }
  r.offX = 20;   // 20 + 8 + 2 mm of fold margin is past the top's 25 mm half length
  cp = planRigCutout(s, buildFrameGeometry(s), 0);
  ftCheck("cuboid top: past the lid's edge does not fit", cp != null && cp.reaches && !cp.fits,
          cp == null ? "null" : cp.status);

  // --- cutouts: every wall. The X walls lean (the length shrinks upward), the Y walls stand
  //     straight. Each rig is pushed to 1.5 mm off its wall at the nearer end of its face. ---
  r.offX = 0; r.offY = 0; r.offZ = 5; r.rot = 0;
  g = buildFrameGeometry(s);
  float zLo = g.rigBoxes.get(0)[2] - r.h / 2, zHi = zLo + r.h;
  float H = s.cylinder.z;
  int[]     faces  = { RIG_CUT_POS_X, RIG_CUT_NEG_X, RIG_CUT_POS_Y, RIG_CUT_NEG_Y };
  int[]     panels = { 1, 3, 2, 0 };
  float[][] dirs   = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} };
  for (int k = 0; k < faces.length; k++) {
    boolean alongX = dirs[k][0] != 0;
    float topHalf = (alongX ? s.uiCubTopLen : s.uiCubTopWid) / 2;
    float botHalf = (alongX ? s.uiCubBotLen : s.uiCubBotWid) / 2;
    float slope = (botHalf - topHalf) / H;                 // how far the wall comes in per mm up
    float cosT  = 1 / sqrt(1 + slope * slope);
    float wallAt = min((topHalf + botHalf) / 2 - zLo * slope, (topHalf + botHalf) / 2 - zHi * slope);
    float off = wallAt - (alongX ? r.w : r.d) / 2 - 1.5 / cosT;
    r.offX = dirs[k][0] * off;
    r.offY = dirs[k][1] * off;
    r.cutoutFace = faces[k];
    g = buildFrameGeometry(s);
    cp = planRigCutout(s, g, 0);
    String name = "cuboid " + RIG_CUT_FACE_NAMES[faces[k]];
    ftCheck(name + ": touches wall panel " + (panels[k] + 1),
            cp != null && !cp.onLid && cp.reaches && cp.panel == panels[k], cp == null ? "null" : cp.status);
    if (cp == null || cp.panel < 0) continue;
    ftNear(name + ": gap", cp.gapMM, 1.5, 1e-3);

    // The square, put on the sketch's own 3D wall, must sit on that wall straight out from
    // the face's centre. The flat panel is edgeSlantH_px tall, so v is scaled to the 3D slant.
    SidePanelBasis b = sidePanelBasis3D(cp.panel);
    float vScale = b.slantPx / edgeSlantH_px[cp.panel];
    PVector got = new PVector(b.c.x, b.c.y, b.c.z);
    got.add(PVector.mult(b.u, cp.localMM.x * MM_current));
    got.add(PVector.mult(b.v, cp.localMM.y * MM_current * vScale));
    float[] box = g.rigBoxes.get(0);
    PVector face = frameToLocalPx(new PVector(box[0] + dirs[k][0] * r.w / 2, box[1] + dirs[k][1] * r.d / 2, box[2]));
    float offPlane = abs(PVector.sub(got, b.c).dot(b.n));
    float sideways = PVector.sub(got, face).cross(b.n).mag();
    ftCheck(name + ": lands on the wall over the face", offPlane < 0.01 && sideways < 0.01,
            "off the wall " + nf(offPlane, 0, 4) + " px, off the face " + nf(sideways, 0, 4) + " px");
  }

  // The 3D view's hole for the last of those (-Y), straight out from the same face.
  ArrayList<CutoutHole3D> holes = cutoutHoles3D(0, getPolygonVertices(false), getPolygonVertices(true));
  ftCheck("cuboid 3D: one hole, in wall panel 1", holes.size() == 1 && holes.get(0).face == 0,
          holes.size() + " holes");
  if (holes.size() == 1) {
    PVector mid = new PVector();
    for (PVector v : holes.get(0).quad) mid.add(v);
    mid.div(4);
    SidePanelBasis b0 = sidePanelBasis3D(0);
    float[] box0 = g.rigBoxes.get(0);
    PVector face0 = frameToLocalPx(new PVector(box0[0], box0[1] - r.d / 2, box0[2]));
    ftNear("cuboid 3D: the hole is straight out from the face",
           PVector.sub(mid, face0).cross(b0.n).mag(), 0, 0.01);
  }

  // A long, narrow cuboid: its 18 mm end wall is far narrower than perimeter / 4 (49 mm), so a
  // 16 mm window plus its fold margins fits the long wall but not the end wall.
  ShapeSpec slim = ftCuboid(80, 18, 80, 18, 50);
  Rig sr = new Rig(10, 10, 20, 0, 0, 5, 0);
  sr.cutoutSize = 1;
  slim.frame.rigs.add(sr);
  ftSetShapes(slim);
  ftLoadCuboid(slim);
  sr.cutoutFace = RIG_CUT_POS_X;
  sr.offX = 40 - 5 - 1.5;
  cp = planRigCutout(slim, buildFrameGeometry(slim), 0);
  ftCheck("cuboid: a 16 mm window does not fit the 18 mm end wall",
          cp != null && cp.panel == 1 && cp.reaches && !cp.fits, cp == null ? "null" : cp.status);
  sr.cutoutFace = RIG_CUT_POS_Y;
  sr.offX = 0;
  sr.offY = 9 - 5 - 1.5;
  cp = planRigCutout(slim, buildFrameGeometry(slim), 0);
  ftCheck("cuboid: but does fit the 80 mm long wall",
          cp != null && cp.panel == 2 && cp.reaches && cp.fits, cp == null ? "null" : cp.status);

  // --- the Cuboid toggle on the Shape tab ---
  sidebar.activeMainTab = MAIN_TAB_SHAPE;
  ShapeSpec hex = new ShapeSpec();
  hex.nSides = 6; hex.uiSides = 6;
  hex.uiTopW = 45; hex.uiBotW = 45;
  ftSetShapes(hex);
  selectedShapeIdx = 0;
  syncUIToSelectedShape();
  applyToModel();
  float hexPerim = shapes.get(0).cylinder.x;

  tCuboidMode.setValue(1);
  ftCheck("toggle on: a cuboid with 4 sides", cuboidMode && uiSides == 4 && shapes.get(0).cuboidMode
          && shapes.get(0).nSides == 4, "sides " + uiSides);
  ftCheck("toggle on: X and Y replace the sides and diameters",
          sCubTopLen.isVisible() && sCubBotWid.isVisible() && tCubRatioLock.isVisible()
          && !sNSides.isVisible() && !sTopSize.isVisible() && tCuboidMode.isVisible(), "");

  tCubRatioLock.setValue(1);
  ftCheck("same as top: the bottom takes the top's size",
          uiCubBotLen == uiCubTopLen && uiCubBotWid == uiCubTopWid, "");
  sCubTopLen.setValue(55);
  ftCheck("same as top: and follows it", uiCubBotLen == 55 && shapes.get(0).uiCubBotLen == 55,
          "bottom X " + uiCubBotLen);
  tCubRatioLock.setValue(0);
  sCubTopLen.setValue(60);
  ftCheck("same as top off: the bottom stays", uiCubBotLen == 55, "bottom X " + uiCubBotLen);

  tCuboidMode.setValue(0);
  ftCheck("toggle off: back to 6 sides", !cuboidMode && uiSides == 6 && shapes.get(0).nSides == 6,
          "sides " + uiSides);
  ftNear("toggle off: back to the diameter it had", shapes.get(0).cylinder.x, hexPerim, 1e-3);
  ftCheck("toggle off: the sides and diameters are back",
          sNSides.isVisible() && sTopSize.isVisible() && !sCubTopLen.isVisible() && !tCubRatioLock.isVisible(), "");

  sidebar.activeMainTab = realTab;
  shapes = realShapes;
  selectedShapeIdx = realSelected;
  syncUIToSelectedShape();
}
