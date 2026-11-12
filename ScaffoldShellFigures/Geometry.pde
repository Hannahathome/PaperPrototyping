// GEOMETRY.PDE - The shell and its scaffold, in frame space
//
// Everything here is in ScaffoldShell's FRAME SPACE ("FS"): millimetres, Z-UP, origin at the
// centre of the shell's height. Bottom plane at z = -h/2, top at +h/2, vertex i of a ring at
// angle (i * 360/n + phase). Render.pde converts to Processing's y-down space when drawing.
//
// ---------------------------------------------------------------------------
// PORTED FROM ScaffoldShell/Frame.pde -- KEEP IN STEP
// ---------------------------------------------------------------------------
// buildFrameGeometry() and buildRigGeometry() are copies of the functions of the same name in
// ScaffoldShell/Frame.pde (and the clearance step of frameScadParamsFor()), so a figure shows
// the scaffold ScaffoldShell would export for the same numbers. The shell is given as
// circumscribed diameters directly, instead of being derived from a ShapeSpec's perimeters
// (R = perimeter / (2 n sin(PI/n)) there).
//
// Frame.pde only produces strut CENTRELINES; the solid shape of each strut is decided by the
// OpenSCAD modules (ScaffoldShell/data/template_frame.txt) and FrameSCAD.pde's assembly. The
// parts of that which show in a figure are ported too:
//   - every strut is a plain cylinder() -- flat ends, no rounding;
//   - spheres only at the bottom cage corners and at each rig post's base;
//   - WALL STRUTS: _local_draw_half_edge() extends each by one radius and shaves a wedge flap
//     over its top flap_length (buildWallStrutMesh());
//   - THE TOP TRIM: the whole assembly is differenced with a disc from zTop to zTop + 2r
//     (writeTopTrimSlice()), which cuts every wall strut -- and any rig post reaching that
//     high -- off along ONE HORIZONTAL PLANE. The flat, level tops are what the lid sits on.
// If the strut layout changes in Frame.pde, or the shapes in template_frame.txt or the trim
// in FrameSCAD.pde, change it here too.

// ---------------------------------------------------------------------------
// Rigs: a cuboid mount for a component, standing on posts off the shell floor
// ---------------------------------------------------------------------------

// Offsets are mm in FS: x/y from the axis, z up from the bottom plane. rot is yaw in degrees.
class Rig {
  float w, d, h, offX, offY, offZ, rot;
  String preset = "Custom";

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

final int RIG_NPARAM = 7;
final String[] RIG_PARAM_LABELS = { "Width", "Depth", "Height", "Offset X", "Offset Y", "Offset Z", "Rotation" };
final String[] RIG_PARAM_KEYS   = { "rig_w", "rig_d", "rig_h", "rig_offX", "rig_offY", "rig_offZ", "rig_rot" };
final float[][] RIG_PARAM_RANGE = {
  {5, 120}, {5, 120}, {2, 120}, {-100, 100}, {-100, 100}, {0, 150}, {-180, 180}
};

// Same presets as ScaffoldShell. RIG_PRESET_WDH[k] pairs with RIG_PRESET_NAMES[k + 1];
// "Custom" applies nothing.
final String[] RIG_PRESET_NAMES = {
  "Custom", "M5Atom", "M5Atom lying", "M5Core", "M5Core lying", "M5Core+Ext", "M5Core+Ext lying"
};
final float[][] RIG_PRESET_WDH = {
  {24, 24, 31.5},   // M5Atom standing
  {24, 31.5, 24},   // M5Atom lying
  {54, 17, 54},     // M5Core standing
  {54, 54, 17},     // M5Core lying
  {54, 21, 54},     // M5Core+Ext standing
  {54, 54, 21}      // M5Core+Ext lying
};

// ScaffoldShell's phase: puts edge 0's midpoint at -90 degrees, as its shell does, so the
// wall struts sit in the shell's corners.
float framePhaseDeg(int n) {
  return -90.0 - 180.0 / (float)max(3, n);
}

// ---------------------------------------------------------------------------
// The shell
// ---------------------------------------------------------------------------

class ShellGeometry {
  int n;
  PVector[] bot, top;
}

ShellGeometry buildShellGeometry() {
  ShellGeometry s = new ShellGeometry();
  s.n = max(3, sides);
  s.bot = polygonRing(s.n, bottomDiameter / 2, -shellHeight / 2);
  s.top = polygonRing(s.n, topDiameter / 2,     shellHeight / 2);
  return s;
}

PVector[] polygonRing(int n, float r, float z) {
  PVector[] ring = new PVector[n];
  float phase = framePhaseDeg(n);
  for (int i = 0; i < n; i++) {
    float a = radians(i * 360.0 / n + phase);
    ring[i] = new PVector(r * cos(a), r * sin(a), z);
  }
  return ring;
}

// ---------------------------------------------------------------------------
// The scaffold
// ---------------------------------------------------------------------------

// Every segment is a strut centreline {from, to}. Boxes are {cx, cy, cz, w, d, h, rotDeg}.
class FrameGeometry {
  ArrayList<PVector>   cageVertices        = new ArrayList<PVector>();
  ArrayList<PVector[]> cageRing            = new ArrayList<PVector[]>();  // bottom perimeter
  ArrayList<PVector[]> cageWallStruts      = new ArrayList<PVector[]>();  // bottom -> top
  ArrayList<PVector[]> floorSpokes         = new ArrayList<PVector[]>();  // rim -> axis
  ArrayList<PVector[]> rigPosts            = new ArrayList<PVector[]>();
  ArrayList<PVector[]> rigBottomConnectors = new ArrayList<PVector[]>();
  ArrayList<PVector[]> rigSpines           = new ArrayList<PVector[]>();
  ArrayList<PVector[]> rigBaseLinks        = new ArrayList<PVector[]>();
  ArrayList<float[]>   rigBoxes            = new ArrayList<float[]>();
  ArrayList<PVector>   rigPostBases        = new ArrayList<PVector>();    // sphere at each
  ArrayList<StrutMesh> wallStrutMeshes     = new ArrayList<StrutMesh>();  // solid, trimmed

  float strutRadius;
  float trimZ0, trimZ1, trimR;   // the top trimming slice: z in [trimZ0, trimZ1], radius trimR
  float zBottom, zTop;       // strut-centreline planes
  float highestRigTop;
  boolean valid;
  String problem = "";
}

FrameGeometry buildFrameGeometry() {
  FrameGeometry g = new FrameGeometry();
  int n = max(3, sides);

  // frameScadParamsFor(): the shell pulled in by the clearance.
  float pBotR = bottomDiameter / 2 - clearance;
  float pTopR = topDiameter / 2    - clearance;
  float pH    = shellHeight        - 2 * clearance;

  g.strutRadius = strutRadius;
  g.valid = true;
  if (pH - 2 * strutRadius <= 0) {
    g.valid = false;
    g.problem = "strut radius and clearance exceed the shell height";
  } else if (min(pBotR, pTopR) - strutRadius <= 0) {
    g.valid = false;
    g.problem = "strut radius and clearance exceed the shell radius";
  }
  if (!g.valid) return g;

  // buildFrameGeometry(): strut centrelines, inset by one radius so the strut surface touches
  // the clearance line.
  float eR   = strutRadius;
  float botR = pBotR - eR;
  float topR = pTopR - eR;
  float h    = pH - 2 * eR;

  g.zBottom = -h / 2;
  g.zTop    =  h / 2;

  float phase = framePhaseDeg(n);
  PVector[] bot = new PVector[n];
  PVector[] top = new PVector[n];
  for (int i = 0; i < n; i++) {
    float a = radians(i * 360.0 / n + phase);
    bot[i] = new PVector(botR * cos(a), botR * sin(a), g.zBottom);
    top[i] = new PVector(topR * cos(a), topR * sin(a), g.zTop);
    g.cageVertices.add(bot[i]);
  }
  for (int i = 0; i < n; i++) {
    g.cageRing.add(new PVector[]{ bot[i], bot[(i + 1) % n] });
    g.cageWallStruts.add(new PVector[]{ bot[i], top[i] });
  }

  // writeTopTrimSlice(): translate z = p.height/2 - eR (= zTop), height 2 eR, radius topR + eR.
  g.trimZ0 = g.zTop;
  g.trimZ1 = g.zTop + 2 * eR;
  g.trimR  = pTopR + eR;
  for (PVector[] e : g.cageWallStruts) {
    g.wallStrutMeshes.add(buildWallStrutMesh(e[0], e[1], eR, wallFlapLength, g.trimZ0));
  }

  g.highestRigTop = g.zTop;
  if (rigs.isEmpty()) return g;

  // Floor spokes exist only to carry rigs, so an empty frame does without them.
  PVector axis = new PVector(0, 0, g.zBottom);
  for (int i = 0; i < n; i++) {
    PVector mid = PVector.add(bot[i], bot[(i + 1) % n]).mult(0.5);
    g.floorSpokes.add(new PVector[]{ mid, axis.copy() });
  }

  for (Rig r : rigs) buildRigGeometry(g, r, eR, dualStruts, strutSpacing);

  // The trim slice cuts the rigs too: a post or spine reaching above zTop loses the part
  // inside the slice (and keeps any part above it, as OpenSCAD would).
  g.rigPosts  = trimVertical(g.rigPosts, g);
  g.rigSpines = trimVertical(g.rigSpines, g);
  return g;
}

// Vertical segments with the trim slice removed. Non-vertical ones pass through untouched;
// the only ones in a frame (ring, spokes, connectors, base links) lie on the floor anyway.
ArrayList<PVector[]> trimVertical(ArrayList<PVector[]> segs, FrameGeometry g) {
  ArrayList<PVector[]> out = new ArrayList<PVector[]>();
  for (PVector[] e : segs) {
    PVector lo = e[0].z <= e[1].z ? e[0] : e[1];
    PVector hi = e[0].z <= e[1].z ? e[1] : e[0];
    boolean vertical = abs(lo.x - hi.x) < 1e-4 && abs(lo.y - hi.y) < 1e-4;
    boolean inside   = dist(0, 0, lo.x, lo.y) <= g.trimR;
    if (!vertical || !inside || hi.z <= g.trimZ0 || lo.z >= g.trimZ1) {
      out.add(e);
      continue;
    }
    if (lo.z < g.trimZ0) out.add(new PVector[]{ lo.copy(), new PVector(lo.x, lo.y, g.trimZ0) });
    if (hi.z > g.trimZ1) out.add(new PVector[]{ new PVector(hi.x, hi.y, g.trimZ1), hi.copy() });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Wall struts as solids: _local_draw_half_edge() + the top trim
// ---------------------------------------------------------------------------
//
// OpenSCAD builds the strut along its own axis, rotated by rotate([0, b, a]) with
// b = acos(v.z / d), a = atan2(v.y, v.x). In that local frame:
//   - a cylinder of radius r from t = 0 to t = d + r (one radius past the top corner);
//   - a wedge cutter removes local y > yCut(t) over the top flap_length, where yCut runs
//     linearly from r (no cut) at t = d + r - flap to 0 (the centre line) at the tip;
//   - then the trim slice removes everything above the global plane z = zTop.
// So each cross-section is a circle clipped by the line y = yCut: an arc plus a chord. The
// mesh samples it at fixed counts, so slices join up into quads, and every surface line is
// cut where it crosses z = zTop. The cap left there is flat and horizontal.

final int FLAP_ARC_N   = 25;   // samples on the round part, both ends included
final int FLAP_CHORD_N = 6;    // samples on the flat cut, both ends included
final int FLAP_SLICES  = 24;   // slices over the tapered part

class StrutMesh {
  PVector[][] pts;     // [line][slice], frame space. Lines run along the strut.
  PVector[][] nrm;
  int arcLines;        // lines [0, arcLines) are the round surface, the rest the flat cut
  PVector bottomNormal;
}

StrutMesh buildWallStrutMesh(PVector p1, PVector p2, float r, float flap, float zTrim) {
  PVector v = PVector.sub(p2, p1);
  float d = v.mag();
  float b = acos(constrain(v.z / d, -1, 1));
  float a = (abs(v.x) < 1e-6 && abs(v.y) < 1e-6) ? 0 : atan2(v.y, v.x);   // atan2(0,0) = 0 in OpenSCAD

  PVector xl = new PVector(cos(b) * cos(a), cos(b) * sin(a), -sin(b));
  PVector yl = new PVector(-sin(a), cos(a), 0);
  PVector zl = PVector.div(v, d);

  float ext = d + r;
  float h80 = ext - flap;                    // where the taper begins

  // Slice positions along the axis: dense only where the cross-section changes.
  FloatList ts = new FloatList();
  ts.append(0);
  float tStart = flap > 0 ? max(0, h80) : ext;
  if (tStart > 0) ts.append(tStart);
  if (flap > 0) for (int i = 1; i <= FLAP_SLICES; i++) ts.append(lerp(tStart, ext, i / (float)FLAP_SLICES));

  int nS = ts.size();
  int nL = FLAP_ARC_N + FLAP_CHORD_N;
  StrutMesh m = new StrutMesh();
  m.pts = new PVector[nL][nS];
  m.nrm = new PVector[nL][nS];
  m.arcLines = FLAP_ARC_N;
  m.bottomNormal = PVector.mult(zl, -1);

  // The wedge's cut face, outward: local (0, 1, r/flap).
  PVector cutN = flap > 0 ? PVector.add(yl, PVector.mult(zl, r / flap)).normalize() : yl.copy();

  for (int s = 0; s < nS; s++) {
    float t = ts.get(s);
    float c = (flap > 0 && t > h80) ? r * (1 - (t - h80) / flap) : r;
    c = constrain(c, 0, r);
    float alpha = asin(c / r);
    PVector axisPt = PVector.add(p1, PVector.mult(zl, t));

    for (int j = 0; j < FLAP_ARC_N; j++) {
      float th = lerp(PI - alpha, TWO_PI + alpha, j / (float)(FLAP_ARC_N - 1));
      PVector radial = PVector.add(PVector.mult(xl, cos(th)), PVector.mult(yl, sin(th)));
      m.pts[j][s] = PVector.add(axisPt, PVector.mult(radial, r));
      m.nrm[j][s] = radial;
    }
    float half = r * cos(alpha);
    for (int k = 0; k < FLAP_CHORD_N; k++) {
      float x = lerp(half, -half, k / (float)(FLAP_CHORD_N - 1));   // arc end -> arc start
      m.pts[FLAP_ARC_N + k][s] = PVector.add(axisPt, PVector.add(PVector.mult(xl, x), PVector.mult(yl, c)));
      m.nrm[FLAP_ARC_N + k][s] = cutN;
    }
  }

  // The trim: cut every line where it crosses z = zTrim; the rest of it collapses onto that
  // point, so the strut ends in a flat horizontal cap made of each line's last point.
  for (int j = 0; j < nL; j++) {
    for (int s = 1; s < nS; s++) {
      PVector prev = m.pts[j][s - 1], cur = m.pts[j][s];
      if (cur.z <= zTrim) continue;
      PVector cut = prev.z >= zTrim ? prev.copy()
                  : PVector.lerp(prev, cur, (zTrim - prev.z) / (cur.z - prev.z));
      for (int q = s; q < nS; q++) m.pts[j][q] = cut;
      break;
    }
  }
  return m;
}

// One rig's posts, spine, connectors, base link and reference box.
void buildRigGeometry(FrameGeometry g, Rig r, float eR, boolean dual, float spacing) {
  float hx = r.w / 2;
  float hy = r.d / 2;
  float zCuboidBot = g.zBottom + r.offZ - eR * 2;
  float zCuboidTop = zCuboidBot + r.h;
  g.highestRigTop = max(g.highestRigTop, zCuboidTop);

  PVector centerStart = new PVector(r.offX, r.offY, g.zBottom);
  PVector centerEnd   = new PVector(r.offX, r.offY, zCuboidBot);
  g.rigSpines.add(new PVector[]{ centerStart, centerEnd });
  g.rigBaseLinks.add(new PVector[]{ new PVector(0, 0, g.zBottom), centerStart.copy() });

  // Post positions relative to the rig centre, before yaw. Dual mode puts two posts on each
  // face, spread along that face by the strut spacing.
  float halfSp = spacing / 2;
  float[][] locals = dual ? new float[][]{
    {-halfSp,      hy + eR}, { halfSp,      hy + eR},
    {-halfSp,   -(hy + eR)}, { halfSp,   -(hy + eR)},
    { hx + eR,     -halfSp}, { hx + eR,      halfSp},
    {-(hx + eR),   -halfSp}, {-(hx + eR),    halfSp}
  } : new float[][]{
    {0,  hy + eR},
    {0, -(hy + eR)},
    { hx + eR, 0},
    {-(hx + eR), 0}
  };

  float rad = radians(r.rot);
  float c = cos(rad), sn = sin(rad);
  for (float[] loc : locals) {
    float rx = loc[0] * c - loc[1] * sn;
    float ry = loc[0] * sn + loc[1] * c;
    PVector base = new PVector(r.offX + rx, r.offY + ry, g.zBottom);
    PVector tip  = new PVector(r.offX + rx, r.offY + ry, zCuboidTop);
    g.rigPosts.add(new PVector[]{ base, tip });
    g.rigPostBases.add(base.copy());
    g.rigBottomConnectors.add(new PVector[]{ centerStart.copy(), base.copy() });
  }

  g.rigBoxes.add(new float[]{ r.offX, r.offY, zCuboidBot + r.h / 2, r.w, r.d, r.h, r.rot });
}
