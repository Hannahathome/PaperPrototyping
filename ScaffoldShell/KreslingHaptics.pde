//----------------------------------------------------------------------------------
// KRESLING HAPTIC-BEHAVIOR SELECTOR
// Pick a target haptic feel (Springy / Boundary / Bi-Stable); the generator searches for
// geometry (n = sides, a = cell width, h = fold height) that produces that feel at the
// current radius, then applies it to the shape.
//
// ALL classification/filter logic below comes strictly from the paper's RESULTS section.
// IMPORTANT CAVEATS (do not over-trust this model):
//  - ACTIVE classifier = the ANGLE-BASED force-gauge model (paper Table 2), chosen so feel
//    depends on the scale-invariant fold angle γ (any feel reachable at any diameter). The
//    paper flags Table 2 as likely OVERFIT (100% training accuracy, zero outliers) — accepted
//    deliberately here for scale-independence. Table 2's `b` term is undefined in the paper
//    and is ASSUMED = fold height h. The length-based human-perceived tree is preserved as
//    classifyHapticLength() for comparison.
//  - The buckling rule was trained on only 3 crumbled prototypes (weakest-validated rule).
//  - The acoustic "pop" rule has NO confirmed numeric threshold in the paper — heuristic only.
//  - The overall model is NOT validated on a hold-out test set — true accuracy is unknown.
//  - geometryFitsRadius() uses r = a / (2*sin(pi/n)) (regular-polygon circumradius). The
//    paper's Results text does not give this formula numerically — it is an assumption
//    filled in here.
//----------------------------------------------------------------------------------

// Hard constraints (reject anything outside these)
final int   KH_N_MIN = 5,   KH_N_MAX = 12;
final float KH_A_MIN = 20,  KH_A_MAX = 150;
final float KH_H_MIN = 30,  KH_H_MAX = 200;

// UI state
int kreslingTargetType = 0;             // 0=Springy, 1=Boundary, 2=Bi-Stable
KreslingResult kreslingLastResult = null;

String kreslingTypeName(int idx) {
  if (idx == 1) return "Boundary";
  if (idx == 2) return "Bi-Stable";
  return "Springy";
}

class KreslingResult {
  boolean valid;        // false => not possible (see reason)
  String reason = "";   // human-readable feedback when not possible
  int n;
  float a, h;
  String type;
  boolean acousticPop;
  boolean bucklingRisk; // always false for a successful result
}

// --- HAPTIC CLASSIFIER ---
// Active model = ANGLE-BASED (paper Table 2). We switched to it because feel then depends on
// the fold ANGLE γ (scale-invariant in a,h) rather than absolute cell width, so every feel is
// reachable at any diameter — the length-based model forced very large diameters for
// Boundary/Bi-Stable. TRADE-OFF: Table 2 is the paper's force-gauge model, which the paper
// itself flags as likely OVERFIT (100% training accuracy, zero outliers). The length-based
// human-perceived model is preserved below as classifyHapticLength() for comparison.
String classifyHaptic(float a, float h, int n) {
  return classifyHapticAngle(a, h, n);
}

// Fold angle γ (degrees) from the Kresling solver: γ = asin(s/a). Scale-invariant in (a,h),
// so it depends on the fold aspect ratio h/a and n, not the absolute size. Returns 0 if the
// fold is not solvable (disc < 0).
float kreslingGamma(float a, float h, int n) {
  int nn = max(3, n);
  float eta = PI / nn;
  float A = 1.0 / pow(sin(eta), 2);
  float B = -(pow(a, 2) + (2 * a * h) / tan(eta));
  float C = pow(a, 2) * pow(h, 2);
  float disc = pow(B, 2) - 4 * A * C;
  if (disc < 0) return 0;
  float sSquared = (-B - sqrt(disc)) / (2 * A);
  if (sSquared < 0 || Float.isNaN(sSquared)) return 0;
  float s = sqrt(sSquared);
  return degrees(asin(constrain(s / a, -1, 1)));
}

// Table 2 (measured haptic classes), keyed on γ (angle, deg), r (circumradius, mm), and b.
// NOTE: b is NOT defined numerically in the paper's Results — ASSUMED here to be the fold
// height h (mm). The γ>38.75 → Bi-Stable branch needs neither r nor b (purely angle-based),
// which is what makes Bi-Stable reachable at small diameters.
String classifyHapticAngle(float a, float h, int n) {
  float g = kreslingGamma(a, h, n);
  float r = a / (2.0 * sin(PI / max(3, n)));   // circumradius (mm)
  float b = h;                                  // ASSUMPTION: b undefined in paper; using foldHeight

  // Bi-Stable
  if (g > 38.75)                               return "Bi-Stable";
  if (g > 37.42 && g <= 38.75 && b > 121.93)   return "Bi-Stable";
  // Boundary
  if (g > 19.66 && g <= 37.42 && r > 102.25)   return "Boundary";
  if (g > 37.42 && g <= 38.75 && b <= 121.93)  return "Boundary";
  // Springy (all remaining cases: low γ, or mid-γ with small radius)
  return "Springy";
}

// Length-based human-perceived model (section-4 tree). Kept for reference/comparison; NOT the
// active classifier. Thresholds assume a, h in mm. Makes feel size-dependent (hence the large
// diameters needed for Boundary/Bi-Stable) — which is why we switched to the angle model.
String classifyHapticLength(float a, float h, int n) {
  float nh = n / h;
  float ah = a / h;
  float an = a / (float) n;

  if (nh <= 0.12 && h <= 82.0 && ah > 0.95)            return "Bi-Stable";
  else if (nh <= 0.12 && h > 119.0)                    return "Boundary";
  else if (nh > 0.12 && ah <= 0.92 && an > 5.62)       return "Boundary";
  else                                                 return "Springy";   // default
}

// Buckling filter — REJECT structures that will crumble. WEAKEST rule (3 prototypes).
boolean kreslingWillBuckle(float a, float h) {
  return (h / a) > 2.37;
}

// Acoustic "pop" — heuristic only, NO validated numeric threshold in the paper.
boolean kreslingAcousticPop(float a, float h, int n) {
  return (a / h) > 1.0 && n >= 8;   // approximate: width & sides large relative to height
}

// Geometric fit: does an n-gon of cell width a give circumradius r?  ASSUMPTION formula.
boolean geometryFitsRadius(float a, int n, float r) {
  float rr = a / (2.0 * sin(PI / n));
  return abs(rr - r) <= 0.5;   // 0.5 mm tolerance
}

// Does some fold height h produce targetType for this (n, a), passing buckling + solvability?
boolean kreslingTypeReachable(int n, float a, String targetType) {
  for (int h = (int) KH_H_MIN; h <= (int) KH_H_MAX; h++) {
    if (kreslingWillBuckle(a, h)) continue;
    if (kreslingFoldOffset(a, h, n) <= 0) continue;
    if (classifyHaptic(a, h, n).equals(targetType)) return true;
  }
  return false;
}

// Suggests the NEAREST (sides, diameter) that can produce targetType, so we can hint the
// user when their current shape can't. Prefers keeping the current side count (only the
// diameter changes); otherwise searches all n and picks the closest diameter. "" if none.
String kreslingSuggestion(String targetType) {
  float curDia = uiBotW;
  int curN = nSides;
  // Only suggest diameters the user can actually dial in on the diameter slider.
  float diaMax = (sTopSize != null) ? sTopSize.getMax() : 120;

  // Tier 1 — keep the current side count, find the nearest diameter that works
  if (curN >= KH_N_MIN && curN <= KH_N_MAX) {
    float bestDia = -1, bestDist = 1e9;
    for (int ai = (int) KH_A_MIN; ai <= (int) KH_A_MAX; ai++) {
      float dia = ai / sin(PI / curN);
      if (dia > diaMax) continue;
      if (!kreslingTypeReachable(curN, ai, targetType)) continue;
      float d = abs(dia - curDia);
      if (d < bestDist) { bestDist = d; bestDia = dia; }
    }
    if (bestDia > 0) return "n=" + curN + ", ⌀" + nf(bestDia, 0, 0) + "mm";
  }

  // Tier 2 — search all side counts, pick the closest diameter overall
  int bestN = -1; float bestDia = 0, bestDist = 1e9;
  for (int n = KH_N_MIN; n <= KH_N_MAX; n++) {
    for (int ai = (int) KH_A_MIN; ai <= (int) KH_A_MAX; ai++) {
      float dia = ai / sin(PI / n);
      if (dia > diaMax) continue;
      if (!kreslingTypeReachable(n, ai, targetType)) continue;
      float d = abs(dia - curDia);
      if (d < bestDist) { bestDist = d; bestN = n; bestDia = dia; }
    }
  }
  if (bestN < 0) return "";
  return "n=" + bestN + ", ⌀" + nf(bestDia, 0, 0) + "mm";
}

// " — try n=…, ⌀…mm" suffix for failure messages (empty if nothing works anywhere).
String kreslingHintSuffix(String targetType) {
  String s = kreslingSuggestion(targetType);
  return s.isEmpty() ? "" : " — try " + s;
}

// Generator. The user fixes the shape (sides, diameter, height) with the normal sliders;
// we hold n and the cell width a = diameter*sin(pi/n) FIXED and search only the fold height
// h that yields the target feel. Filters: buckling (h/a<=2.37), Kresling shear-solvability
// (kreslingFoldOffset>0, else it renders flat), and the human-perceived-feel classifier.
// If nothing fits, res.valid=false and res.reason explains why (clear feedback).
KreslingResult generateKresling(String targetType) {
  KreslingResult res = new KreslingResult();
  int n = nSides;
  // Cell width from the user's diameter + sides. Use the BOTTOM diameter because the app's
  // Kresling shear is computed from the bottom edge (cellBaseL); for a uniform cylinder
  // top == bottom anyway.
  float diameter = uiBotW;
  float a = diameter * sin(PI / max(3, n));

  // Validate the FIXED inputs against the paper's hard constraints first
  if (n < KH_N_MIN || n > KH_N_MAX) {
    res.valid = false;
    res.reason = "Sides must be " + KH_N_MIN + "–" + KH_N_MAX + " (now " + n + ")"
               + kreslingHintSuffix(targetType);
    return res;
  }
  if (a < KH_A_MIN || a > KH_A_MAX) {
    res.valid = false;
    res.reason = "Cell width a=" + nf(a, 0, 1) + "mm is outside " + (int)KH_A_MIN + "–"
               + (int)KH_A_MAX + kreslingHintSuffix(targetType);
    return res;
  }

  ArrayList<Integer> hCandidates = new ArrayList<Integer>();
  for (int h = (int) KH_H_MIN; h <= (int) KH_H_MAX; h++) {
    if (kreslingWillBuckle(a, h)) continue;             // buckling
    if (kreslingFoldOffset(a, h, n) <= 0) continue;     // must actually fold (solvable)
    if (!classifyHaptic(a, h, n).equals(targetType)) continue;  // haptic type
    hCandidates.add(h);
  }

  if (hCandidates.isEmpty()) {
    res.valid = false;
    res.reason = "No " + targetType + " fold at n=" + n + ", ⌀" + nf(diameter, 0, 0) + "mm"
               + kreslingHintSuffix(targetType);
    return res;
  }

  int h = hCandidates.get((int) random(hCandidates.size()));   // random re-roll per paper
  res.valid = true;
  res.n = n;
  res.a = a;
  res.h = h;
  res.type = classifyHaptic(a, h, n);
  res.acousticPop = kreslingAcousticPop(a, h, n);
  res.bucklingRisk = false;
  return res;
}

// Runs the generator for the currently selected feel and applies the result to the shape.
void kreslingGenerateAndApply() {
  kreslingLastResult = generateKresling(kreslingTypeName(kreslingTargetType));
  applyKreslingResult(kreslingLastResult);
}

// Classifies the CURRENT geometry (shape + current manual fold height) WITHOUT changing
// anything — tells the user what feel their settings produce, and flags a buckling risk.
void kreslingCheckCurrent() {
  KreslingResult res = new KreslingResult();
  int n = nSides;
  float a = uiBotW * sin(PI / max(3, n));
  float h = kreslingFoldHeight;
  res.n = n; res.a = a; res.h = h;

  if (n < KH_N_MIN || n > KH_N_MAX) {
    res.valid = false;
    res.reason = "Sides must be " + KH_N_MIN + "–" + KH_N_MAX + " (now " + n + ")";
  } else if (a < KH_A_MIN || a > KH_A_MAX) {
    res.valid = false;
    res.reason = "Cell width a=" + nf(a, 0, 1) + "mm is outside " + (int)KH_A_MIN + "–" + (int)KH_A_MAX;
  } else if (h < KH_H_MIN || h > KH_H_MAX) {
    res.valid = false;
    res.reason = "Fold height " + nf(h, 0, 1) + "mm is outside " + (int)KH_H_MIN + "–" + (int)KH_H_MAX;
  } else if (kreslingFoldOffset(a, h, n) <= 0) {
    res.valid = false;
    res.reason = "Not a solvable Kresling fold at this fold height";
  } else {
    res.valid = true;
    res.type = classifyHaptic(a, h, n);
    res.acousticPop = kreslingAcousticPop(a, h, n);
    res.bucklingRisk = kreslingWillBuckle(a, h);   // check reports buckling instead of filtering it
  }
  kreslingLastResult = res;
  redraw();
}

// Applies a generated result. The shape (sides, diameter, height) is the user's input and
// is left untouched — we only set the Kresling fold settings: the fold height, and the
// segment count so the fold tiers fit the form height (numTiers ~= tubeHeight / foldHeight).
void applyKreslingResult(KreslingResult res) {
  if (res == null || !res.valid) { redraw(); return; }

  kreslingFoldHeight = res.h;
  kreslingSegments = (int) constrain(round(uiHeight / res.h), 1, 8);

  boolean prevSync = _syncingUI;
  _syncingUI = true;
  if (sKreslingUnits    != null) sKreslingUnits.setValue(kreslingFoldHeight);
  if (sKreslingSegments != null) sKreslingSegments.setValue(kreslingSegments);
  _syncingUI = prevSync;

  redraw();
}

// Readout text under the buttons.
String kreslingReadoutText() {
  if (kreslingLastResult == null) return "Set sides / diameter / height, pick a feel, then Generate — or Check current.";
  if (!kreslingLastResult.valid) return "Not possible: " + kreslingLastResult.reason;
  KreslingResult r = kreslingLastResult;
  String s = r.type + " · fold h=" + nf(r.h, 0, 1) + "mm · pop:" + (r.acousticPop ? "yes" : "no");
  if (r.bucklingRisk) s += " · ⚠ may buckle";
  s += "  (n=" + r.n + ", a=" + nf(r.a, 0, 1) + "mm)";
  return s;
}

// Whether the last generate produced a valid result (used to colour the readout).
boolean kreslingLastResultOk() {
  return kreslingLastResult != null && kreslingLastResult.valid;
}

// ---- Live bistability feedback (reflects the CURRENT fold height, no button needed) ----

// Threshold above which the Kresling snaps (bi-stable), per Table 2's pure-angle branch.
final float KRESLING_BISTABLE_GAMMA = 38.75;

// Fold angle γ (deg) for the current shape + current manual fold height.
float kreslingCurrentGamma() {
  float a = uiBotW * sin(PI / max(3, nSides));
  return kreslingGamma(a, kreslingFoldHeight, nSides);
}

boolean kreslingCurrentIsBistable() {
  return kreslingCurrentGamma() > KRESLING_BISTABLE_GAMMA;
}

// One-line live indicator: current fold angle vs the bi-stable snap threshold.
String kreslingLiveText() {
  float g = kreslingCurrentGamma();
  if (g > KRESLING_BISTABLE_GAMMA) return "now: γ=" + nf(g, 0, 1) + "° ✓ Bi-Stable (snaps)";
  return "now: γ=" + nf(g, 0, 1) + "° — snaps at >" + nf(KRESLING_BISTABLE_GAMMA, 0, 1) + "° (raise fold height)";
}
