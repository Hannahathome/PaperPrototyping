// RIGCUTOUT.PDE - Cutouts in the paper shell, placed by the scaffold's rigs
//
// A rig holds a component inside the shell; a cutout lets its screen, button or LED show
// through the paper. Each rig names ONE of its faces (Rig.cutoutFace). If that face reaches
// the shell, a square hole of a preset size is cut into the piece of paper it meets:
//   Top          -> the top lid
//   a side face  -> the wall panel that face looks at
// A face that stops short of the shell cuts nothing, and the Scaffold tab says how far off
// it is -- a hole in the paper with the component 20 mm behind it is not what anyone wants.
//
// ---------------------------------------------------------------------------
// WHY THIS NEEDS NO NEW COORDINATE FRAME
// ---------------------------------------------------------------------------
// Rigs live in frame space (FS, Frame.pde). The paper has two canonical frames already:
//
//   TOP LID (LidFrame.pde). LF (u, v) -> 3D (u, -halfH, v), and FS (x, y, z) -> 3D
//   (x, -z, y). So LF u = FS x and LF v = FS y: a rig's (offX, offY) IS its position on the
//   top lid, with no conversion. Yaw carries across unchanged too -- FS rotates
//   (x c - y s, x s + y c), which is exactly what rotate() does on the page.
//
//   WALL PANEL (SidePanelFrame.pde). FS vertex i is the shell's 3D vertex i (FrameSelfTest
//   checks this at seven vertex counts), so panel i in FS is panel i on the page. The panel
//   basis is rebuilt here in FS millimetres from the ShapeSpec, by the same construction
//   sidePanelBasis3D() uses, so the plan can be made without any shape's globals loaded --
//   the Scaffold tab needs it for a status line, outside drawPlan().
//
// The frustum flat-height caveat in SidePanelFrame.pde's header applies: SF v is flat-pattern
// millimetres, and the 3D slant is mapped onto it as a fraction, the same way it maps back.
//
// Scope: whatever frameAvailable() allows (uniform regular frustums). Wall cutouts are also
// refused on kresling walls, as sidePanelFrameAvailable() refuses wall connections, because
// drawPlan() shears the whole strip.

final int RIG_CUT_NONE  = 0;
final int RIG_CUT_TOP   = 1;
final int RIG_CUT_POS_Y = 2;
final int RIG_CUT_NEG_Y = 3;
final int RIG_CUT_POS_X = 4;
final int RIG_CUT_NEG_X = 5;
String[] RIG_CUT_FACE_NAMES = {
  "None", "Top", "Front (+Y)", "Back (−Y)", "Right (+X)", "Left (−X)"
};

// Rig.cutoutSize: 0 picks the largest preset that fits the face, else a fixed preset.
String[] RIG_CUT_SIZE_NAMES = { "Auto", "16 mm", "50 mm" };

// How close a face has to come to the paper to count as touching it: one strut radius plus
// this much.
final float RIG_CUT_REACH_SLACK_MM = 1;

float rigCutoutReachMM(FrameSpec f) {
  return f.strutRadius + RIG_CUT_REACH_SLACK_MM;
}

// Kept clear of every fold line. On a wall all four boundaries are folds; on a lid the
// perimeter is where the tabs fold.
final float RIG_CUT_FOLD_MARGIN_MM = 2;

// A side face has to look at a wall roughly square-on to cut it. 35 degrees admits a face
// between two panels of a hexagon (30 degrees off each) and rejects a rig turned corner-on.
final float RIG_CUT_MIN_ALIGN = 0.819;   // cos(35 deg)

class RigCutoutPlan {
  int     rigIdx;
  int     face;
  boolean onLid;          // top lid, else wall panel `panel`
  int     panel = -1;
  PVector localMM;        // LF on the top lid, SF on the wall panel
  float   rotDeg;         // square's rotation in that frame
  float   sizeMM;
  boolean reaches;        // close enough to the paper to cut
  boolean fits;           // clear of the face's fold lines
  float   gapMM;          // face to paper
  String  status = "";
}

// The shape's cutoutable rigs, planned. Empty when the scaffold is off or cannot be built.
ArrayList<RigCutoutPlan> planRigCutouts(ShapeSpec s) {
  ArrayList<RigCutoutPlan> out = new ArrayList<RigCutoutPlan>();
  if (s == null || s.frame == null || !s.frame.enabled || !frameAvailable(s)) return out;
  FrameGeometry g = buildFrameGeometry(s);
  if (!g.valid) return out;
  for (int i = 0; i < s.frame.rigs.size() && i < g.rigBoxes.size(); i++) {
    RigCutoutPlan p = planRigCutout(s, g, i);
    if (p != null) out.add(p);
  }
  return out;
}

// One rig's cutout, or null when it asks for none.
RigCutoutPlan planRigCutout(ShapeSpec s, FrameGeometry g, int i) {
  if (g == null || !g.valid || i < 0 || i >= s.frame.rigs.size() || i >= g.rigBoxes.size()) return null;
  Rig r = s.frame.rigs.get(i);
  if (r.cutoutFace == RIG_CUT_NONE) return null;

  // {cx, cy, cz, w, d, h, rotDeg}, FS mm -- the same box the preview and the .scad draw.
  float[] box = g.rigBoxes.get(i);
  float cx = box[0], cy = box[1], cz = box[2];
  float w  = box[3], dp = box[4], h = box[5];

  FrameDims d = frameDimsFor(s);
  float tol = rigCutoutReachMM(s.frame);

  RigCutoutPlan p = new RigCutoutPlan();
  p.rigIdx = i;
  p.face   = r.cutoutFace;

  if (r.cutoutFace == RIG_CUT_TOP) {
    p.onLid   = true;
    p.localMM = new PVector(cx, cy);
    p.rotDeg  = r.rot;
    p.sizeMM  = rigCutoutSize(r, w, dp);
    p.gapMM   = d.height / 2 - (cz + h / 2);
    p.reaches = p.gapMM <= tol;
    PVector[] lid = regularPolygonMM(d.n, s.cylinder.x / d.n, 0);
    p.fits = squareInPoly(lid, p.localMM, p.rotDeg, p.sizeMM + 2 * RIG_CUT_FOLD_MARGIN_MM);

    p.status = rigCutoutDistanceText("the top lid", p.gapMM, tol);
    if (!p.reaches) {
      p.status += " No cut. Raise Offset Z or Height.";
    } else {
      p.status += " Cuts a " + nf(p.sizeMM, 0, 0) + " mm square into the top lid."
               + (p.fits ? "" : " It runs over the lid's edge. Move the rig toward the centre.");
    }
    return p;
  }

  if (!sidePanelFrameAvailable(s)) {
    p.status = "No cut: kresling walls cannot take a cutout.";
    return p;
  }

  // The face's outward normal and its extent, in the rig's own axes before yaw.
  float nx = 0, ny = 0, halfN, faceW;
  switch (r.cutoutFace) {
    case RIG_CUT_POS_Y: ny =  1; halfN = dp / 2; faceW = w;  break;
    case RIG_CUT_NEG_Y: ny = -1; halfN = dp / 2; faceW = w;  break;
    case RIG_CUT_POS_X: nx =  1; halfN = w / 2;  faceW = dp; break;
    default:            nx = -1; halfN = w / 2;  faceW = dp; break;
  }
  float rad = radians(r.rot), c = cos(rad), sn = sin(rad);
  PVector nF = new PVector(nx * c - ny * sn, nx * sn + ny * c, 0);
  PVector tF = new PVector(-nF.y, nF.x, 0);
  PVector P  = new PVector(cx + nF.x * halfN, cy + nF.y * halfN, cz);

  PVector[] corners = new PVector[4];
  int k = 0;
  for (int su = -1; su <= 1; su += 2) {
    for (int sz = -1; sz <= 1; sz += 2) {
      corners[k++] = new PVector(P.x + tF.x * su * faceW / 2,
                                 P.y + tF.y * su * faceW / 2,
                                 P.z + sz * h / 2);
    }
  }

  // The panel this face looks at: of those it faces squarely, the nearest. Measured at the
  // face's nearest corner, since a rig turned slightly touches a wall corner-first.
  RigPanelFS best = null;
  float bestGap = Float.MAX_VALUE;
  for (int j = 0; j < d.n; j++) {
    RigPanelFS pan = rigPanelFS(d, j);
    if (nF.dot(pan.n) < RIG_CUT_MIN_ALIGN) continue;
    float gap = Float.MAX_VALUE;
    for (PVector q : corners) gap = min(gap, PVector.sub(pan.c, q).dot(pan.n));
    if (gap < bestGap) { bestGap = gap; best = pan; }
  }
  p.sizeMM = rigCutoutSize(r, faceW, h);
  if (best == null) {
    p.status = "No cut: this face does not look squarely at a wall. Rotate the rig.";
    return p;
  }

  p.panel   = best.index;
  p.gapMM   = bestGap;
  p.reaches = bestGap <= tol;

  // The face centre, dropped onto the panel plane, in SF.
  PVector Q  = PVector.add(P, PVector.mult(best.n, PVector.sub(best.c, P).dot(best.n)));
  PVector dd = PVector.sub(Q, best.c);
  float flatH = rigPanelFlatHeightMM(s, d.n);
  p.localMM = new PVector(dd.dot(best.u), dd.dot(best.v) * flatH / best.slant);
  p.rotDeg  = 0;   // the rig stands upright and faces the panel, so the square sits square

  float b = s.cylinder.y / d.n / 2 - RIG_CUT_FOLD_MARGIN_MM;
  float t = s.cylinder.x / d.n / 2 - RIG_CUT_FOLD_MARGIN_MM;
  float hh = flatH / 2 - RIG_CUT_FOLD_MARGIN_MM;
  PVector[] panelPoly = {
    new PVector(-b, -hh), new PVector(b, -hh), new PVector(t, hh), new PVector(-t, hh)
  };
  p.fits = squareInPoly(panelPoly, p.localMM, 0, p.sizeMM);

  String where = "wall panel " + (p.panel + 1);
  p.status = rigCutoutDistanceText(where, p.gapMM, tol);
  if (!p.reaches) {
    p.status += " No cut. Move the rig toward it.";
  } else {
    p.status += " Cuts a " + nf(p.sizeMM, 0, 0) + " mm square into " + where + "."
             + (p.fits ? "" : " It crosses a fold line. Move the rig along the wall, or pick a smaller size.");
  }
  return p;
}

// Always leads the status line, so the distance is on show whether or not it cuts.
// A negative gap means the rig pokes through the paper.
String rigCutoutDistanceText(String where, float gapMM, float tol) {
  return "Distance to " + where + ": " + nf(gapMM, 0, 1) + " mm (cuts within "
       + nf(tol, 0, 1) + " mm).";
}

// Rig.cutoutSize 0 = Auto: the largest preset that fits within the face, or the small one
// when neither does.
float rigCutoutSize(Rig r, float faceA, float faceB) {
  if (r.cutoutSize == 1) return CUTOUT_SIZE_SMALL;
  if (r.cutoutSize == 2) return CUTOUT_SIZE_LARGE;
  return min(faceA, faceB) >= CUTOUT_SIZE_LARGE ? CUTOUT_SIZE_LARGE : CUTOUT_SIZE_SMALL;
}

// A square of `side` at `centre`, turned `rotDeg`, lies wholly inside `poly`.
boolean squareInPoly(PVector[] poly, PVector centre, float rotDeg, float side) {
  float rad = radians(rotDeg), c = cos(rad), sn = sin(rad), hs = side / 2;
  for (int sx = -1; sx <= 1; sx += 2) {
    for (int sy = -1; sy <= 1; sy += 2) {
      float lx = sx * hs, ly = sy * hs;
      if (!pointInPoly(poly, centre.x + lx * c - ly * sn, centre.y + lx * sn + ly * c)) return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------------------
// Wall panels in FS millimetres
// ---------------------------------------------------------------------------

class RigPanelFS {
  int index;
  PVector c;        // median midpoint -- SF (0,0)
  PVector u, v, n;  // along the median, up the panel, outward
  float slant;      // true slant height (mm)
}

// Panel k of the shell itself (no clearance), built like sidePanelBasis3D().
RigPanelFS rigPanelFS(FrameDims d, int k) {
  int n = d.n, j = (k + 1) % n;
  float a0 = radians(k * 360.0 / n + d.phaseDeg);
  float a1 = radians(j * 360.0 / n + d.phaseDeg);
  float zb = -d.height / 2, zt = d.height / 2;
  PVector B0 = new PVector(d.botR * cos(a0), d.botR * sin(a0), zb);
  PVector B1 = new PVector(d.botR * cos(a1), d.botR * sin(a1), zb);
  PVector T0 = new PVector(d.topR * cos(a0), d.topR * sin(a0), zt);
  PVector T1 = new PVector(d.topR * cos(a1), d.topR * sin(a1), zt);

  RigPanelFS p = new RigPanelFS();
  p.index = k;
  p.c = PVector.add(PVector.add(B0, B1), PVector.add(T0, T1)).mult(0.25);
  PVector mL = PVector.add(B0, T0).mult(0.5), mR = PVector.add(B1, T1).mult(0.5);
  PVector mB = PVector.add(B0, B1).mult(0.5), mT = PVector.add(T0, T1).mult(0.5);
  p.u = PVector.sub(mR, mL).normalize();
  p.v = PVector.sub(mT, mB);
  p.slant = p.v.mag();
  p.v.normalize();
  p.n = p.u.cross(p.v).normalize();
  if (p.n.x * p.c.x + p.n.y * p.c.y < 0) p.n.mult(-1);   // outward, whatever the winding
  return p;
}

// The panel's height as DRAWN FLAT, mirroring Param.pde's cylinderH_px (see the frustum note
// in SidePanelFrame.pde's header). mm.
float rigPanelFlatHeightMM(ShapeSpec s, int n) {
  float edgeDiff = abs(s.cylinder.y - s.cylinder.x) / n;
  return sqrt(sq(s.cylinder.z) + sq(edgeDiff));
}

// ---------------------------------------------------------------------------
// Drawing -- inside drawPlan(), with the drawn shape's globals loaded
// ---------------------------------------------------------------------------

ArrayList<RigCutoutPlan> rigCutoutsForDrawnShape() {
  if (shapes == null || _drawingShapeIdx < 0 || _drawingShapeIdx >= shapes.size()) {
    return new ArrayList<RigCutoutPlan>();
  }
  return planRigCutouts(shapes.get(_drawingShapeIdx));
}

// Preview and export styling, matching styleConnectionSlits(): blue on screen, red when it
// crosses a fold, thicker for the rig selected on the Scaffold tab; a plain cut line on export.
void styleRigCutout(RigCutoutPlan p) {
  noFill();
  if (bSavePDF) {
    stroke(uiLightGrayCutLines ? 180 : 0);
    strokeWeight(0.5);
    return;
  }
  boolean sel = sidebar != null && sidebar.activeMainTab == MAIN_TAB_FRAME
             && _drawingShapeIdx == selectedShapeIdx
             && p.rigIdx == shapes.get(_drawingShapeIdx).frame.selectedRigIdx;
  stroke(p.fits ? color(0, 120, 255) : color(230, 60, 60));
  strokeWeight((sel ? 2.0 : 1.5) / SCREEN_SCALE);
}

// Draws one square at the current origin, plus its rig number on screen.
void drawRigCutoutSquare(RigCutoutPlan p) {
  float ps = p.sizeMM * MM_current;
  pushStyle();
  styleRigCutout(p);
  rectMode(CENTER);
  rect(0, 0, ps, ps, cutoutCornerRadius * MM_current);
  if (!bSavePDF) {
    fill(p.fits ? color(0, 120, 255) : color(230, 60, 60));
    noStroke();
    textAlign(CENTER, CENTER);
    pageText(9 / SCREEN_SCALE);
    text("Rig " + (p.rigIdx + 1), 0, 0);
  }
  popStyle();
}

// Call inside the TOP lid's matrix in drawPlan(), before the lid outline, like
// drawConnectionSlits(): inner cuts go first so the sheet stays anchored.
void drawRigCutoutsOnTopLid() {
  if (!lidFrameAvailable()) return;
  for (RigCutoutPlan p : rigCutoutsForDrawnShape()) {
    if (!p.onLid || !p.reaches) continue;
    PVector at = lidLocalToPiecePx(p.localMM, true);
    pushMatrix();
    translate(at.x, at.y);
    rotate(radians(p.rotDeg));
    drawRigCutoutSquare(p);
    popMatrix();
  }
}

// Call at the strip origin, where drawConnectionSlitsOnPanels() is called.
void drawRigCutoutsOnPanels() {
  if (!sidePanelFrameAvailable()) return;
  SidePanelPose[] poses = null;
  for (RigCutoutPlan p : rigCutoutsForDrawnShape()) {
    if (p.onLid || !p.reaches || p.panel < 0) continue;
    if (poses == null) poses = sidePanelPosesPx();
    if (poses == null || p.panel >= poses.length || poses[p.panel] == null) continue;
    SidePanelPose pose = poses[p.panel];
    pushMatrix();
    translate(pose.originPx.x, pose.originPx.y);
    rotate(pose.rotRad);
    translate(p.localMM.x * MM_current, p.localMM.y * MM_current);
    drawRigCutoutSquare(p);
    popMatrix();
  }
}
