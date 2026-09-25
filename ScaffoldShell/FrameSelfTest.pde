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
