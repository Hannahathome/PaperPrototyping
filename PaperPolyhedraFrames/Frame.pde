// FRAME.PDE - Internal 3D-printed support frame
//
// A tall frustum folded from paper cannot hold its own profile or carry electronics. The
// frame is the rigid wireframe that goes INSIDE it: a strut cage following the shell's own
// edges, plus cuboid mounting rigs for components. It is 3D printed, not cut -- it leaves
// this sketch as OpenSCAD source (FrameSCAD.pde), never as PDF or SVG.
//
// This is FrustumSupport, absorbed. What changed in the absorption is the thing that made
// it worth doing: the frustum is no longer typed in. It is DERIVED from the ShapeSpec of
// the shell it goes inside, so the two cannot drift apart. FrustumSupport's README warned
// "these must match the shell, or the frame will not seat"; now they cannot fail to.
//
// ---------------------------------------------------------------------------
// ONE GEOMETRY, TWO PROJECTIONS
// ---------------------------------------------------------------------------
// Same discipline as LidFrame.pde, for the same reason. The 3D preview and the exported
// .scad must never be able to disagree about where a strut is, so neither of them computes
// geometry. Both read buildFrameGeometry(), which works in one canonical space:
//
//   FRAME SPACE ("FS"): millimetres, Z-UP, origin at the centre of the frustum's height.
//     bottom plane at z = -h/2, top plane at z = +h/2
//     +x / +y horizontal, vertex i of a ring at angle (i*360/n + phase)
//
// FS is chosen to BE OpenSCAD's space, so the exporter writes its numbers out verbatim.
// The preview projects into the sketch's 3D space instead -- see frameToLocalPx().
//
// ---------------------------------------------------------------------------
// THE TWO CONVERSIONS THAT MAKE IT SEAT
// ---------------------------------------------------------------------------
// 1. PERIMETER -> CIRCUMRADIUS. docs/shared-concepts.md flags this as the classic way to
//    get a frame that "matches" on paper and does not fit: PaperPolyhedra is driven by
//    perimeters because that is what you cut, OpenSCAD builds from circumradii.
//        R = perimeter / (2*n*sin(PI/n))
//    Note the shell's VERTICAL height (cylinder.z) is what the frame wants. The slant
//    height Param.pde derives for the flat panels plays no part here.
//
// 2. ROTATIONAL PHASE. The sketch's 3D polygon (getPolygonVertices() in tools.pde) walks
//    vertex-to-vertex from the origin along +x and re-centres, which puts EDGE 0's
//    MIDPOINT at -90 degrees. OpenSCAD's cage puts VERTEX 0 at 0 degrees. Those are
//    different conventions, and without a correction every vertical strut lands in the
//    middle of a facet instead of in the shell's corner -- invisible at n=4, obvious at
//    n=3 and n=5. framePhaseDeg() is the correction, and it is applied in FS space (so
//    both projections inherit it) rather than at draw time.
//
// ---------------------------------------------------------------------------
// WHERE A FRAME LIVES
// ---------------------------------------------------------------------------
// ShapeSpec holds a FrameSpec REFERENCE, and saveGlobalsTo()/loadGlobalsFrom() deliberately
// do not touch it. Those two copy scalars and share object references -- which is exactly
// why EdgeProfile needs deepCopyEdgeProfile(). A mutable ArrayList<Rig> pushed through the
// global-swap pattern would let two shapes silently share one rig list, and edits to one
// would show up in the other. Connection.pde's header makes the same call for the same
// reason. The frame is reached as shapes.get(i).frame, never through a global mirror.
//
// Scope (v1): uniform regular polygons -- the same scope LidFrame.pde and BasePlate.pde
// take. Per-edge, cuboid and hollow shells are refused by frameAvailable() rather than
// given a frame that cannot seat.

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

// A cuboid mount for a component, standing on posts off the frustum floor.
// Offsets are millimetres in FS space: x/y from the axis, z up from the bottom plane.
// rot is yaw in degrees about the rig's own (offX, offY).
class Rig {
  float w, d, h, offX, offY, offZ, rot;
  String preset = "Custom";

  Rig(float w, float d, float h, float ox, float oy, float oz, float rot) {
    this.w = w; this.d = d; this.h = h;
    this.offX = ox; this.offY = oy; this.offZ = oz; this.rot = rot;
  }

  Rig copy() {
    Rig r = new Rig(w, d, h, offX, offY, offZ, rot);
    r.preset = preset;
    return r;
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
String[] RIG_PARAM_LABELS = {
  "Width", "Depth", "Height", "Offset X", "Offset Y", "Offset Z", "Rotation"
};

// Preset component footprints (W, D, H in mm). RIG_PRESET_WDH[k] pairs with
// RIG_PRESET_NAMES[k + 1]; entry 0 ("Custom") applies nothing.
//
// Named "preset" rather than FrustumSupport's "template": in this sketch a template is the
// flat cut pattern (getTemplateBBox(), platonic_templates_production.txt), and reusing the
// word for electronics footprints would be genuinely confusing.
String[] RIG_PRESET_NAMES = {
  "Custom", "M5Atom", "M5Atom lying", "M5Core", "M5Core lying", "M5Core+Ext", "M5Core+Ext lying"
};
float[][] RIG_PRESET_WDH = {
  {24, 24, 31.5},   // M5Atom standing
  {24, 31.5, 24},   // M5Atom lying
  {54, 17, 54},     // M5Core standing
  {54, 54, 17},     // M5Core lying
  {54, 21, 54},     // M5Core+Ext standing
  {54, 54, 21}      // M5Core+Ext lying
};

// Per-shape frame settings. Held by reference on ShapeSpec -- see the header.
class FrameSpec {
  boolean enabled;
  float   strutRadius;    // printed wireframe edge radius (mm)
  float   clearanceMM;    // gap between shell and frame, for paper thickness and fold slop
  boolean dualStruts;     // two posts per rig face instead of one
  float   strutSpacing;   // gap between the paired posts (mm)
  float   flapLength;     // wedge flap at the top of each wall strut (mm)
  ArrayList<Rig> rigs;
  int     selectedRigIdx;

  FrameSpec() {
    enabled        = false;
    strutRadius    = 1.0;
    clearanceMM    = FRAME_CLEARANCE_DEFAULT;
    dualStruts     = false;
    strutSpacing   = 15;
    flapLength     = 8;
    rigs           = new ArrayList<Rig>();
    selectedRigIdx = 0;
  }

  Rig selectedRig() {
    if (rigs.isEmpty()) return null;
    selectedRigIdx = constrain(selectedRigIdx, 0, rigs.size() - 1);
    return rigs.get(selectedRigIdx);
  }
}

// Paper has thickness (PAPER_THICKNESS_MM) and a folded shell does not land exactly on
// nominal. FrustumSupport had no clearance parameter because its radii were typed by hand,
// so this slop was absorbed by typing a smaller number. Derived radii leave nowhere to do
// that, which makes an explicit clearance necessary rather than a nicety.
final float FRAME_CLEARANCE_DEFAULT = 0.4;

// ---------------------------------------------------------------------------
// Availability
// ---------------------------------------------------------------------------

// The frame addresses a shell as a uniform regular frustum. Anything else is refused
// rather than given a frame that will not seat.
boolean frameAvailable(ShapeSpec s) {
  if (s == null) return false;
  return !s.perEdgeMode && !s.cuboidMode && !s.hollowMode && s.nSides >= 3;
}

// Why not, for the sidebar to show. Empty string when the shape is fine.
String frameUnavailableReason(ShapeSpec s) {
  if (s == null)        return "no shape selected";
  if (s.perEdgeMode)    return "per-edge shapes are not supported yet";
  if (s.cuboidMode)     return "cuboid shapes are not supported yet";
  if (s.hollowMode)     return "hollow (double-wall) shapes are not supported yet";
  if (s.nSides < 3)     return "needs at least 3 sides";
  return "";
}

// ---------------------------------------------------------------------------
// The bridge: ShapeSpec (perimeters, mm) -> frustum (circumradii, mm)
// ---------------------------------------------------------------------------

// R = perimeter / (2*n*sin(PI/n)). See docs/shared-concepts.md.
float circumradiusFromPerimeterMM(float perimeterMM, int n) {
  n = max(3, n);
  return perimeterMM / (2.0 * n * sin(PI / (float)n));
}

// Rotation (degrees) that carries OpenSCAD's "vertex 0 at 0 degrees" onto this sketch's
// "edge 0 midpoint at -90 degrees". Derivation: OpenSCAD's edge 0 midpoint sits at
// 180/n, and it has to land at -90, so phase = -90 - 180/n.
float framePhaseDeg(int n) {
  return -90.0 - 180.0 / (float)max(3, n);
}

// The shell, as the frustum the frame has to fit inside. Millimetres, no clearance applied.
class FrameDims {
  int   n;
  float botR, topR, height;   // shell circumradii and vertical height (mm)
  float phaseDeg;
}

FrameDims frameDimsFor(ShapeSpec s) {
  FrameDims d = new FrameDims();
  d.n        = max(3, s.nSides);
  d.topR     = circumradiusFromPerimeterMM(s.cylinder.x, d.n);   // cylinder.x = top perimeter
  d.botR     = circumradiusFromPerimeterMM(s.cylinder.y, d.n);   // cylinder.y = base perimeter
  d.height   = s.cylinder.z;                                     // vertical, not slant
  d.phaseDeg = framePhaseDeg(d.n);
  return d;
}

// What actually gets passed to OpenSCAD: the shell pulled in by the clearance. The module
// then insets a further strut radius of its own, so the strut's outer surface ends up one
// clearance short of the paper.
class FrameScadParams {
  int   n;
  float botR, topR, height;   // clearance applied, strut radius NOT yet
  float strutRadius, phaseDeg;
  boolean valid;
  String problem;
}

FrameScadParams frameScadParamsFor(ShapeSpec s) {
  FrameDims d = frameDimsFor(s);
  FrameSpec f = s.frame;

  FrameScadParams p = new FrameScadParams();
  p.n           = d.n;
  p.phaseDeg    = d.phaseDeg;
  p.strutRadius = f.strutRadius;
  p.botR        = d.botR    - f.clearanceMM;
  p.topR        = d.topR    - f.clearanceMM;
  p.height      = d.height  - 2 * f.clearanceMM;
  p.valid       = true;
  p.problem     = "";

  // The module subtracts a strut radius from each radius and two from the height. If that
  // takes anything to zero the frame is inside-out, and OpenSCAD would render it as an
  // unhelpful tangle rather than an error.
  if (p.height - 2 * f.strutRadius <= 0) {
    p.valid = false;
    p.problem = "strut radius and clearance exceed the shell height";
  } else if (min(p.botR, p.topR) - f.strutRadius <= 0) {
    p.valid = false;
    p.problem = "strut radius and clearance exceed the shell radius";
  }
  return p;
}

// ---------------------------------------------------------------------------
// Geometry, in FS space (mm, z-up)
// ---------------------------------------------------------------------------

// Every segment is a strut centreline: {from, to}. Boxes are {cx, cy, cz, w, d, h, rotDeg}.
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

  float strutRadius;
  float zBottom, zTop;       // strut-centreline planes
  float highestRigTop;       // for the "rig pokes out of the shell" warning
  boolean valid;
  String problem;
}

// Builds the whole frame for one shape. Read by BOTH the 3D preview and the .scad writer;
// neither derives geometry of its own.
//
// The effective numbers here mirror what the OpenSCAD modules compute internally from the
// same parameters, so the preview shows what will print.
FrameGeometry buildFrameGeometry(ShapeSpec s) {
  FrameGeometry g = new FrameGeometry();
  FrameScadParams p = frameScadParamsFor(s);
  FrameSpec f = s.frame;

  g.strutRadius = f.strutRadius;
  g.valid       = p.valid;
  g.problem     = p.problem;
  if (!p.valid) return g;

  // Strut centrelines, inset by one radius so the strut surface touches the clearance line.
  float eR   = f.strutRadius;
  float botR = p.botR - eR;
  float topR = p.topR - eR;
  float h    = p.height - 2 * eR;

  g.zBottom = -h / 2;
  g.zTop    =  h / 2;

  int n = p.n;
  PVector[] bot = new PVector[n];
  PVector[] top = new PVector[n];
  for (int i = 0; i < n; i++) {
    float a = radians(i * 360.0 / n + p.phaseDeg);
    bot[i] = new PVector(botR * cos(a), botR * sin(a), g.zBottom);
    top[i] = new PVector(topR * cos(a), topR * sin(a), g.zTop);
    g.cageVertices.add(bot[i]);
  }
  for (int i = 0; i < n; i++) {
    g.cageRing.add(new PVector[]{ bot[i], bot[(i + 1) % n] });
    g.cageWallStruts.add(new PVector[]{ bot[i], top[i] });
  }

  g.highestRigTop = g.zTop;
  if (f.rigs.isEmpty()) return g;

  // Floor spokes brace the base ring against the axis. They exist only to carry rigs, so
  // an empty frame does without them -- which is what FrustumSupport's "simple" mode was.
  PVector axis = new PVector(0, 0, g.zBottom);
  for (int i = 0; i < n; i++) {
    PVector mid = PVector.add(bot[i], bot[(i + 1) % n]).mult(0.5);
    g.floorSpokes.add(new PVector[]{ mid, axis.copy() });
  }

  for (Rig r : f.rigs) {
    buildRigGeometry(g, r, eR, f.dualStruts, f.strutSpacing);
  }
  return g;
}

// One rig's posts, spine, connectors, base link and reference box. Ported from
// FrustumSupport's buildRigGeometry(), with the dims passed in rather than read off globals.
void buildRigGeometry(FrameGeometry g, Rig r, float eR, boolean dualStruts, float strutSpacing) {
  float hx = r.w / 2;
  float hy = r.d / 2;
  float zCuboidBot = g.zBottom + r.offZ - eR * 2;
  float zCuboidTop = zCuboidBot + r.h;
  g.highestRigTop = max(g.highestRigTop, zCuboidTop);

  PVector centerStart = new PVector(r.offX, r.offY, g.zBottom);
  PVector centerEnd   = new PVector(r.offX, r.offY, zCuboidBot);
  g.rigSpines.add(new PVector[]{ centerStart, centerEnd });
  g.rigBaseLinks.add(new PVector[]{ new PVector(0, 0, g.zBottom), centerStart.copy() });

  // Post positions relative to the rig centre, before yaw. Dual mode puts two posts on
  // each face, spread along that face by strutSpacing.
  float halfSp = strutSpacing / 2;
  float[][] locals = dualStruts ? new float[][]{
    {-halfSp,      hy + eR}, { halfSp,      hy + eR},   // +Y face, spread along X
    {-halfSp,   -(hy + eR)}, { halfSp,   -(hy + eR)},   // -Y face, spread along X
    { hx + eR,     -halfSp}, { hx + eR,      halfSp},   // +X face, spread along Y
    {-(hx + eR),   -halfSp}, {-(hx + eR),    halfSp}    // -X face, spread along Y
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
    g.rigBottomConnectors.add(new PVector[]{ centerStart.copy(), base.copy() });
  }

  g.rigBoxes.add(new float[]{ r.offX, r.offY, zCuboidBot + r.h / 2, r.w, r.d, r.h, r.rot });
}

// ---------------------------------------------------------------------------
// Projection: FS space -> the sketch's own 3D space
// ---------------------------------------------------------------------------

// FS is millimetres and Z-UP. The sketch's 3D is pixels and Y-DOWN, with the top face at
// -halfH (see LidFrame.lidLocalTo3D and getPolygonVertices). So the vertical axis flips
// and the two horizontal axes shift along: (x, y, z)_FS -> (x, -z, y)_3D.
//
// Getting this wrong renders the frame lying on its side, which is the giveaway.
PVector frameToLocalPx(PVector fs) {
  return new PVector(fs.x * MM_current, -fs.z * MM_current, fs.y * MM_current);
}

// ---------------------------------------------------------------------------
// Rig management (operates on a shape's own FrameSpec, never on globals)
// ---------------------------------------------------------------------------

FrameSpec selectedFrame() {
  if (shapes == null || shapes.isEmpty()) return null;
  int i = constrain(selectedShapeIdx, 0, shapes.size() - 1);
  return shapes.get(i).frame;
}

void frameAddRig(FrameSpec f) {
  if (f == null) return;
  // A new rig copies the selected one, so adding a second identical mount is one click.
  Rig base = f.selectedRig();
  f.rigs.add(base != null ? base.copy() : new Rig(24, 24, 31.5, 0, 0, 8.5, 0));
  f.selectedRigIdx = f.rigs.size() - 1;
}

void frameRemoveRig(FrameSpec f) {
  if (f == null || f.rigs.isEmpty()) return;
  f.rigs.remove(constrain(f.selectedRigIdx, 0, f.rigs.size() - 1));
  f.selectedRigIdx = constrain(f.selectedRigIdx, 0, max(0, f.rigs.size() - 1));
}

// Applies a preset's W/D/H to the selected rig. Index 0 ("Custom") leaves the values alone.
void frameApplyRigPreset(FrameSpec f, int presetIdx) {
  if (f == null) return;
  Rig r = f.selectedRig();
  if (r == null) return;
  if (presetIdx <= 0 || presetIdx > RIG_PRESET_WDH.length) {
    r.preset = "Custom";
    return;
  }
  float[] wdh = RIG_PRESET_WDH[presetIdx - 1];
  r.w = wdh[0]; r.d = wdh[1]; r.h = wdh[2];
  r.preset = RIG_PRESET_NAMES[presetIdx];
}

// Which preset the selected rig's dimensions currently match, for the dropdown caption.
int frameRigPresetIndex(Rig r) {
  if (r == null) return 0;
  for (int t = 0; t < RIG_PRESET_WDH.length; t++) {
    if (r.w == RIG_PRESET_WDH[t][0] && r.d == RIG_PRESET_WDH[t][1] && r.h == RIG_PRESET_WDH[t][2]) {
      return t + 1;
    }
  }
  return 0;
}
