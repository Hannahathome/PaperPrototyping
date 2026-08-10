//----------------------------------------------------------------------------------
// KRESLING PATTERN  (fold-line OVERLAY on the original strip)
// The original side-panel strip stays leading — its outline, panel folds, tabs and
// flaps are drawn as usual. Kresling is layered on top: each side panel is split
// (along its height) into up to 4 segments, and every segment gets an angled valley
// diagonal plus a mountain fold at the segment boundary. Diagonals alternate direction
// per segment (chevron), matching the Kresling crease structure.
//
// This draws in the same per-panel local frame as drawTzFoldlines(), so it lines up
// with each panel and works for frustums (top != bottom) as well as cylinders.
//----------------------------------------------------------------------------------

boolean kreslingMode = false;   // Shear the strip into the Kresling parallelogram + diagonals
int kreslingSegments = 1;       // Vertical split per panel (tiers), 1..8
float kreslingFoldHeight = 90;  // Stijn's foldHeight parameter (mm) — sets the base/shear angle

// Kresling shear offset (px) — how far the top edge shifts sideways over the panel height,
// solved from panel width a, height h and side count n. Ported from ProjectStijn/Kresling.pde.
// Returns 0 if the configuration is not geometrically possible.
float kreslingFoldOffset(float a, float h, int n) {
  float eta = PI / n;
  float A = 1.0 / pow(sin(eta), 2);
  float B = -(pow(a, 2) + (2 * a * h) / tan(eta));
  float C = pow(a, 2) * pow(h, 2);

  float disc = pow(B, 2) - 4 * A * C;
  if (disc < 0) return 0;

  float sSquared = (-B - sqrt(disc)) / (2 * A);
  if (sSquared < 0 || Float.isNaN(sSquared)) return 0;

  float s = sqrt(sSquared);
  float gamma = asin(constrain(s / a, -1, 1));
  float beta = PI - gamma - eta;
  return abs(h / tan(beta));
}

// Largest fold height (mm) for which the Kresling shear is geometrically valid, given the
// current base edge width and side count. Above this the solver has no real solution
// (disc < 0) and the strip goes flat. Derivation: disc >= 0  <=>  h <= (a/2)*cot(pi/2n).
float kreslingFoldHeightMax() {
  int n = max(3, nSides);
  float panelWidthMM = cylinder.y / (float) n;   // base edge length (mm) = basePerimeter / n
  float halfEta = PI / (2.0 * n);
  float t = tan(halfEta);
  if (t <= 0) return 30;
  return (panelWidthMM / 2.0) / t;               // (a/2) * cot(pi/2n)
}

// Base/shear angle for the strip, computed exactly like Stijn's example: from the panel
// width (a), the foldHeight PARAMETER (h), and the side count (n). The same angle is then
// applied across the whole panel height via shearX(), so the panels lean at Stijn's base
// angle regardless of the actual tube height. Returns 0 if the fold height makes the
// Kresling geometrically impossible (mirrors Stijn's "Not Possible").
float kreslingShearAngle() {
  float a = cellBaseL_px;
  float h = kreslingFoldHeight * MM_current;   // Stijn's foldHeight, in px
  if (h <= 0) return 0;
  float off = kreslingFoldOffset(a, h, max(3, nSides));
  if (off <= 0) return 0;
  return atan(off / h);                         // the Kresling base angle (from vertical)
}

// Kresling internal folds now use the same small dash as everywhere else (dash_px is already
// scaled down globally by FOLD_DASH_SCALE), so no extra Kresling-specific scaling.
float KRESLING_DASH_SCALE = 1.0;

// Local dashed-line helper that respects the CURRENT stroke colour (the app's own
// drawDashedLine overrides the stroke, which would kill the mountain/valley colouring).
void kreslingDash(float x1, float y1, float x2, float y2) {
  float d = dist(x1, y1, x2, y2);
  float dashLen = dash_px * KRESLING_DASH_SCALE, spaceLen = gap_px * KRESLING_DASH_SCALE;
  if (d <= dashLen) { line(x1, y1, x2, y2); return; }
  int segments = max(1, round((d - dashLen) / (dashLen + spaceLen)));
  float step = (d - dashLen) / segments;
  for (int i = 0; i <= segments; i++) {
    float startP = (i * step) / d;
    float endP = min((i * step + dashLen) / d, 1.0);
    line(lerp(x1, x2, startP), lerp(y1, y2, startP), lerp(x1, x2, endP), lerp(y1, y2, endP));
  }
}

// Overlays the Kresling segment folds on the strip. Mirrors drawTzFoldlines()'s
// panel-to-panel transform so the folds sit exactly on each panel.
//   topLen / bottomLen = panel top/bottom edge lengths (px), h = panel height (px),
//   n = number of panels (nSides), nSeg = vertical segments per panel (clamped to 4).
void drawKreslingFoldlines(float startX, float startY,
                           float topLen, float bottomLen,
                           float h, int n, int nSeg) {
  nSeg = constrain(nSeg, 1, 8);
  if (uiHidePanelFolds) return;

  pushMatrix();
  pushStyle();
  translate(startX, startY);
  strokeWeight(1);

  color mountainCol = uiLightGrayCutLines ? color(180) : color(0, 0, 255);  // segment boundary
  color valleyCol   = uiLightGrayCutLines ? color(180) : color(255, 0, 0);  // diagonal

  float offset = (bottomLen - topLen) / 2.0;   // horizontal inset of the top edge (frustum)
  float segH   = h / (float) nSeg;

  for (int count = 0; count < n; count++) {
    for (int s = 0; s < nSeg; s++) {
      float yB = s * segH, yT = (s + 1) * segH;

      // Panel left/right edges at these two heights (interpolated for frustums)
      float leftB  = lerp(0, offset, yB / h);
      float rightB = lerp(bottomLen, offset + topLen, yB / h);
      float leftT  = lerp(0, offset, yT / h);
      float rightT = lerp(bottomLen, offset + topLen, yT / h);

      // Mountain fold at the interior segment boundary (skip the panel's own bottom edge)
      if (s > 0) {
        stroke(mountainCol);
        kreslingDash(leftB, yB, rightB, yB);
      }

      // Valley diagonal — all parallel, same direction (Kresling twist), like Stijn's reference
      stroke(valleyCol);
      kreslingDash(leftB, yB, rightT, yT);   // bottom-left -> top-right, every segment
    }

    // Step to the next panel (identical transform to drawTzFoldlines)
    if (count < n - 1) {
      PVector A_right = new PVector((topLen - bottomLen) / 2.0, h);
      float offsetNext = (bottomLen - topLen) / 2.0;
      PVector B_left   = new PVector(offsetNext, h);
      float angleA         = atan2(A_right.y, A_right.x);
      float angleB         = atan2(B_left.y, B_left.x);
      float rotationNeeded = angleA - angleB;
      translate(bottomLen, 0);
      rotate(rotationNeeded);
    }
  }

  popStyle();
  popMatrix();
}
