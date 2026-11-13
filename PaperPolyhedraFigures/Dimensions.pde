// DIMENSIONS.PDE - Dimension lines, and what each close-up shows
//
// Every dimension is measured from points Template.pde anchored while it recorded the
// template, so it stays right whichever way a panel is turned on the page (a frustum's strip
// fans out, so its panels are). A dimension is drawn parallel to what it measures, pushed
// out square to it, with extension lines back to the shape.
//
// Panel a: the panel height and its two edge widths, inside panel 2 of the strip.
// Panel b: the close-ups, in order --
//   1  Wall tab    tab depth, neck, flare, tab width, the gap beside it, the edge
//   2  Glue flap   flap depth, taper, the slot the hook goes through, its inset, panel height
//   3  Hook flap   its barbed end: flap depth, neck, hook offset, flare (the inset is in the notes)
//   4  Lid tab     as the wall tab, with the lid's shorter neck
// Sizes PaperPolyhedra derives rather than takes from a slider say so in their label or in
// the notes under the close-up ("inset = 1/4 edge").

final String[] CLOSEUPS = { "Wall tab", "Glue flap", "Hook flap", "Lid tab" };

// The area of the template a close-up shows (mm): {x0, y0, x1, y1}, or null if the template
// has no such part. tight: just the part, for its frame on panel a; otherwise with room
// around it for the dimensions.
float[] closeupBox(Template tp, int i, boolean tight) {
  String[] keys;
  float padRel, padMin;
  switch (i) {
    case 0:  keys = new String[]{ "walltab.e0", "walltab.e1", "walltab.t0", "walltab.t1" }; padRel = 0.45; padMin = 6; break;
    case 1:  keys = new String[]{ "glue.p1", "glue.p4", "glue.p1_flap", "glue.p4_flap" };   padRel = 0.12; padMin = 4; break;
    case 2:  keys = new String[]{ "hook.p2_inset", "hook.p2_neck", "hook.p2_hook", "hook.p2_rect", "hook.p2_flap" }; padRel = 0.9; padMin = 4; break;
    default: keys = new String[]{ "lidtab.e0", "lidtab.e1", "lidtab.t0", "lidtab.t1" };     padRel = 0.45; padMin = 6; break;
  }
  if (!tp.has(keys)) return null;
  float x0 = Float.MAX_VALUE, y0 = Float.MAX_VALUE, x1 = -Float.MAX_VALUE, y1 = -Float.MAX_VALUE;
  for (String key : keys) {
    PVector p = tp.a(key);
    x0 = min(x0, p.x); y0 = min(y0, p.y); x1 = max(x1, p.x); y1 = max(y1, p.y);
  }
  if (tight) return new float[]{ x0, y0, x1, y1 };
  // A flap is long and thin: give it room across, for the panel beside it and the dimensions.
  float size = max(x1 - x0, y1 - y0);
  float pad = max(padMin, padRel * size);
  float padAcross = (i == 1) ? max(pad, 0.4 * size) : pad;
  boolean tall = (y1 - y0) >= (x1 - x0);
  return new float[]{ x0 - (tall ? padAcross : pad), y0 - (tall ? pad : padAcross),
                      x1 + (tall ? padAcross : pad), y1 + (tall ? pad : padAcross) };
}

// ---------------------------------------------------------------------------
// Panel a
// ---------------------------------------------------------------------------

void drawPanelDimensions(PGraphics t, Template tp, View v, float k) {
  String p = "panel1.";
  if (!tp.has(p + "BL", p + "BR", p + "TL", p + "TR")) return;
  PVector BL = tp.a(p + "BL"), BR = tp.a(p + "BR"), TL = tp.a(p + "TL"), TR = tp.a(p + "TR");
  PVector midB = PVector.add(BL, BR).mult(0.5), midT = PVector.add(TL, TR).mult(0.5);
  PVector up = unit(PVector.sub(midT, midB));            // bottom edge -> top edge, on the page

  // The panel's height along its axis -- its slant height, on a frustum.
  String hLabel = "panel " + fmtMM(tp.panelH) + " mm";
  dimAligned(t, v, midB, midT, unit(PVector.sub(BR, BL)), 0, null, hLabel, true, k);

  // Its two edges, each dimensioned just inside the panel.
  dimAligned(t, v, BL, BR, up, 12 * k, null, fmtMM(tp.edgeBot) + " mm", false, k);
  dimAligned(t, v, TL, TR, PVector.mult(up, -1), 12 * k, null, fmtMM(tp.edgeTop) + " mm", false, k);
}

// ---------------------------------------------------------------------------
// Panel b
// ---------------------------------------------------------------------------

void drawCloseupDimensions(PGraphics t, Template tp, int i, View v, float k) {
  switch (i) {
    case 0:  tabDimensions(t, tp, "walltab.", tp.neckWall, "neck " + fmtMM(tp.neckWall) + " mm", v, k); break;
    case 1:  glueFlapDimensions(t, tp, v, k); break;
    case 2:  hookFlapDimensions(t, tp, v, k); break;
    default: tabDimensions(t, tp, "lidtab.", tp.neckLid, "neck " + fmtMM(tp.neckLid) + " mm", v, k); break;
  }
}

// An arrowhead tab, wall or lid: anchors e0 b0 n0 t0 t1 n1 b1 e1 along it (Template.pde).
void tabDimensions(PGraphics t, Template tp, String p, float neck, String neckLabel, View v, float k) {
  PVector e0 = tp.a(p + "e0"), e1 = tp.a(p + "e1"), b0 = tp.a(p + "b0"), b1 = tp.a(p + "b1");
  PVector n0 = tp.a(p + "n0"), n1 = tp.a(p + "n1"), t0 = tp.a(p + "t0");
  PVector u = unit(PVector.sub(e1, e0));
  PVector out = unit(PVector.sub(n0, b0));
  if (out.mag() < 0.5) out = new PVector(-u.y, u.x);
  PVector in = PVector.mult(out, -1);
  PVector mid = PVector.add(b0, b1).mult(0.5);
  PVector away0 = unit(PVector.sub(b0, mid)), away1 = unit(PVector.sub(b1, mid));

  float depth = PVector.sub(t0, b0).dot(out);
  PVector tip0 = PVector.add(b0, PVector.mult(out, depth));

  dimAligned(t, v, b0, tip0, away0, 16 * k, null, "tab " + fmtMM(depth) + " mm", true, k);
  dimAligned(t, v, b1, n1, away1, 16 * k, null, neckLabel, true, k);
  dimAligned(t, v, tip0, t0, out, 12 * k, null, "flare " + fmtMM(PVector.dist(tip0, t0)) + " mm", false, k);
  dimAligned(t, v, b0, b1, in, 14 * k, null, fmtMM(PVector.dist(b0, b1)) + " mm", false, k);
  // The stretch of edge with no tab: twice the inset.
  if (PVector.dist(e0, b0) > 0.05) {
    dimAligned(t, v, e0, b0, in, 14 * k, null, fmtMM(PVector.dist(e0, b0)) + " mm", false, k);
  } else if (PVector.dist(b1, e1) > 0.05) {
    dimAligned(t, v, b1, e1, in, 14 * k, null, fmtMM(PVector.dist(b1, e1)) + " mm", false, k);
  }
  dimAligned(t, v, e0, e1, in, 38 * k, null, "edge " + fmtMM(PVector.dist(e0, e1)) + " mm", false, k);
}

void glueFlapDimensions(PGraphics t, Template tp, View v, float k) {
  String p = "glue.";
  PVector p1 = tp.a(p + "p1"), p4 = tp.a(p + "p4");
  PVector i1 = tp.a(p + "p1_inset"), i4 = tp.a(p + "p4_inset");
  PVector r1 = tp.a(p + "p1_rect"), f1 = tp.a(p + "p1_flap");
  PVector along = unit(PVector.sub(p1, p4));
  PVector out = unit(PVector.sub(r1, p1));
  PVector in = PVector.mult(out, -1);

  PVector mid = PVector.add(p1, p4).mult(0.5);
  dimAligned(t, v, mid, PVector.add(mid, PVector.mult(out, tp.flapDepthUsed)), along, 0, out,
             "flap " + fmtMM(tp.flapDepthUsed) + " mm", false, k);
  dimAligned(t, v, r1, f1, out, 12 * k, null, "taper " + fmtMM(PVector.dist(r1, f1)) + " mm", false, k);
  dimAligned(t, v, i4, i1, in, 14 * k, null, "slot " + fmtMM(PVector.dist(i4, i1)) + " mm", true, k);
  dimAligned(t, v, i1, p1, in, 14 * k, null, fmtMM(PVector.dist(i1, p1)) + " mm", true, k);
  dimAligned(t, v, p4, p1, in, 42 * k, null, "panel " + fmtMM(PVector.dist(p4, p1)) + " mm", true, k);
}

void hookFlapDimensions(PGraphics t, Template tp, View v, float k) {
  String p = "hook.";
  PVector p2 = tp.a(p + "p2");
  PVector i2 = tp.a(p + "p2_inset");
  PVector n2 = tp.a(p + "p2_neck"), h2 = tp.a(p + "p2_hook");
  PVector r2 = tp.a(p + "p2_rect"), f2 = tp.a(p + "p2_flap");
  PVector toP2 = unit(PVector.sub(p2, i2));           // along the edge, toward the p2 end
  PVector out = unit(PVector.sub(r2, i2));

  // Flap depth, straight out from the edge to the flap's outer corner.
  PVector foot = PVector.add(i2, PVector.mult(toP2, -PVector.dist(r2, f2)));
  dimAligned(t, v, foot, f2, toP2, 0, PVector.mult(toP2, -1), "flap " + fmtMM(tp.flapDepthUsed) + " mm", false, k);
  dimAligned(t, v, i2, n2, toP2, 14 * k, null, "neck " + fmtMM(tp.neckHook) + " mm", false, k);
  dimAligned(t, v, r2, f2, out, 12 * k, null, "flare " + fmtMM(PVector.dist(r2, f2)) + " mm", false, k);
  dimAligned(t, v, n2, h2, out, 38 * k, null, "hook " + fmtMM(tp.hookOffsetUsed) + " mm", false, k);
}

// The rules behind the derived sizes, under each close-up.
void drawCloseupNotes(PGraphics t, Template tp, int i, float x, float y, float k) {
  String[] lines;
  switch (i) {
    case 0:
      lines = new String[]{ "inset = 1/4 edge = " + fmtMM(tp.insetTop) + " mm;  gap = 2 × inset",
                            "flare = inset / 3",
                            "neck = " + fmtRatio(tabNeckRatio) + " × tab depth" };
      break;
    case 1:
      lines = new String[]{ "inset = 1/4 panel height = " + fmtMM(tp.insetH) + " mm",
                            "the slot between the two folds is cut;",
                            "the hook goes through it" };
      break;
    case 2:
      lines = new String[]{ "inset = 1/4 panel height = " + fmtMM(tp.insetH) + " mm",
                            "flare = inset / 3;  neck = 0.2 × tab depth",
                            "hook offset fixed at " + fmtMM(tp.hookOffsetUsed) + " mm" };
      break;
    default:
      lines = new String[]{ "inset = 1/4 edge = " + fmtMM(tp.insetTop) + " mm;  gap = 2 × inset",
                            "flare = inset / 3",
                            "neck = 0.2 × tab depth (lids)" };
      break;
  }
  t.pushStyle();
  t.textFont(k > 1.5 ? fontDim : fontBody);
  t.textSize(10 * k);
  t.textAlign(LEFT, TOP);
  t.fill(CLR_TEXT_MUTED);
  for (int j = 0; j < lines.length; j++) t.text(lines[j], round(x), round(y + j * 13 * k));
  t.popStyle();
}

// ---------------------------------------------------------------------------
// One dimension
// ---------------------------------------------------------------------------

// Measures P-Q (mm) with a line pushed offPx along offDir (a unit vector, mm and pixels
// alike: the view only scales), extension lines back to P and Q, arrowheads, and the label
// on labelDir's side (offDir's if null). alongLine turns the label to run with the line.
void dimAligned(PGraphics t, View v, PVector P, PVector Q, PVector offDir, float offPx,
                PVector labelDir, String label, boolean alongLine, float k) {
  PVector p = v.map(P), q = v.map(Q);
  if (PVector.dist(p, q) < 0.5) return;
  PVector a = PVector.add(p, PVector.mult(offDir, offPx));
  PVector b = PVector.add(q, PVector.mult(offDir, offPx));

  t.pushStyle();
  t.stroke(CLR_DIM);
  t.strokeWeight(0.75 * k);
  t.noFill();
  if (offPx > 0.5) {
    PVector over = PVector.mult(offDir, 3 * k);
    t.line(p.x, p.y, a.x + over.x, a.y + over.y);
    t.line(q.x, q.y, b.x + over.x, b.y + over.y);
  }
  t.line(a.x, a.y, b.x, b.y);
  float arrow = 6 * k;
  if (PVector.dist(a, b) >= 2 * arrow + 4 * k) {
    arrowhead(t, b, a, k);
    arrowhead(t, a, b, k);
  } else {
    // Too short for arrows inside: point at it from outside.
    PVector d = unit(PVector.sub(b, a));
    PVector aOut = PVector.sub(a, PVector.mult(d, arrow + 6 * k));
    PVector bOut = PVector.add(b, PVector.mult(d, arrow + 6 * k));
    t.line(aOut.x, aOut.y, a.x, a.y);
    t.line(b.x, b.y, bOut.x, bOut.y);
    arrowhead(t, aOut, a, k);
    arrowhead(t, bOut, b, k);
  }

  PVector ld = labelDir != null ? labelDir : offDir;
  PVector mid = PVector.add(a, b).mult(0.5);
  DimLabel L = new DimLabel();
  L.text = label;
  L.slide = unit(PVector.sub(b, a));
  L.out = ld.copy();
  L.home = mid;
  if (alongLine) {
    L.ang = atan2(b.y - a.y, b.x - a.x);
    if (L.ang > HALF_PI || L.ang < -HALF_PI) L.ang += PI;   // keep the text upright
    L.at = PVector.add(mid, PVector.mult(ld, 8 * k));
    L.alignX = CENTER; L.alignY = CENTER;
  } else if (abs(ld.x) >= abs(ld.y)) {
    L.at = PVector.add(mid, PVector.mult(ld, 6 * k));
    L.alignX = ld.x > 0 ? LEFT : RIGHT; L.alignY = CENTER;
  } else {
    L.at = PVector.add(mid, PVector.mult(ld, 6 * k));
    L.alignX = CENTER; L.alignY = ld.y > 0 ? TOP : BOTTOM;
  }
  t.popStyle();
  if (pendingLabels != null) pendingLabels.add(L);
  else drawDimLabel(t, L, L.at, k);
}

// ---------------------------------------------------------------------------
// Labels that keep out of each other's way
// ---------------------------------------------------------------------------
//
// While pendingLabels is set, dimAligned() draws its lines but only collects its label;
// placeLabels() then puts each label down in turn, where it was meant to go if that is free,
// otherwise at the nearest free spot -- slid along its own dimension line, further out from
// it, or as a last resort across it -- with a thin leader back to its line once it has moved
// off it.

class DimLabel {
  String text;
  PVector at;              // where it would go
  PVector home;            // the middle of its dimension line
  PVector slide, out;      // the ways it may move: along its line, and away from it
  int alignX, alignY;
  float ang;               // 0, or turned to run along its line
}

ArrayList<DimLabel> pendingLabels = null;
int labelsStillOverlapping = 0;   // labels that found no free spot, counted for testing

void beginLabels() { pendingLabels = new ArrayList<DimLabel>(); }

// bounds {x, y, w, h}: a label is kept inside it if it can be.
void placeLabels(PGraphics t, float[] bounds, float k) {
  ArrayList<DimLabel> labels = pendingLabels;
  pendingLabels = null;
  if (labels == null) return;
  t.pushStyle();
  t.textFont(k > 1.5 ? fontDim : fontBody);
  t.textSize(11 * k);

  // Every candidate spot, nearest first: up to 24 steps each way along the line, 10 out,
  // and -- costing more, as it puts the label across its own line -- 6 back.
  float stepAlong = 5 * k, stepOut = 7 * k;
  ArrayList<float[]> moves = new ArrayList<float[]>();
  for (int o = -6; o <= 10; o++) {
    for (int s = -24; s <= 24; s++) {
      float cost = abs(s) * stepAlong + (o >= 0 ? 1.6 : 4) * abs(o) * stepOut;
      moves.add(new float[]{ s * stepAlong, o * stepOut, cost });
    }
  }
  java.util.Collections.sort(moves, new java.util.Comparator<float[]>() {
    public int compare(float[] p, float[] q) { return Float.compare(p[2], q[2]); }
  });

  ArrayList<float[]> taken = new ArrayList<float[]>();
  for (DimLabel L : labels) {
    PVector best = L.at;
    float[] bestBox = labelBox(t, L, L.at, k);
    for (int pass = 0; pass < 2; pass++) {   // first inside the bounds, then anywhere free
      boolean found = false;
      for (float[] m : moves) {
        PVector p = PVector.add(L.at, PVector.add(PVector.mult(L.slide, m[0]), PVector.mult(L.out, m[1])));
        float[] box = labelBox(t, L, p, k);
        if (pass == 0 && !inside(box, bounds)) continue;
        if (overlapsAny(box, taken)) continue;
        best = p; bestBox = box; found = true;
        break;
      }
      if (found) break;
    }
    if (overlapsAny(bestBox, taken)) labelsStillOverlapping++;
    taken.add(bestBox);
    if (PVector.dist(best, L.at) > 9 * k) {
      // Moved off its line: a leader from the line's middle to the nearest edge of the label.
      float cx = constrain(L.home.x, bestBox[0], bestBox[2]), cy = constrain(L.home.y, bestBox[1], bestBox[3]);
      t.stroke(CLR_TEXT_MUTED);
      t.strokeWeight(0.5 * k);
      t.line(L.home.x, L.home.y, cx, cy);
    }
    drawDimLabel(t, L, best, k);
  }
  t.popStyle();
}

void drawDimLabel(PGraphics t, DimLabel L, PVector p, float k) {
  t.pushStyle();
  t.textFont(k > 1.5 ? fontDim : fontBody);
  t.textSize(11 * k);
  if (L.ang != 0) {
    t.pushMatrix();
    t.translate(p.x, p.y);
    t.rotate(L.ang);
    labelAt(t, L.text, 0, 0, L.alignX, L.alignY, k);
    t.popMatrix();
  } else {
    labelAt(t, L.text, p.x, p.y, L.alignX, L.alignY, k);
  }
  t.popStyle();
}

// The label's footprint at p, with its white backing and a little air: {x0, y0, x1, y1}.
float[] labelBox(PGraphics t, DimLabel L, PVector p, float k) {
  float w = t.textWidth(L.text), h = 11 * k, pad = 2.5 * k + 1.5 * k;
  float left = L.alignX == LEFT ? 0 : L.alignX == RIGHT ? -w : -w / 2;
  float top  = L.alignY == TOP ? 0 : L.alignY == BOTTOM ? -h : -h / 2;
  float[][] c = { { left - pad, top - pad }, { left + w + pad, top - pad },
                  { left + w + pad, top + h + pad }, { left - pad, top + h + pad } };
  float cs = cos(L.ang), sn = sin(L.ang);
  float x0 = Float.MAX_VALUE, y0 = Float.MAX_VALUE, x1 = -Float.MAX_VALUE, y1 = -Float.MAX_VALUE;
  for (float[] q : c) {
    float x = p.x + q[0] * cs - q[1] * sn, y = p.y + q[0] * sn + q[1] * cs;
    x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x); y1 = max(y1, y);
  }
  return new float[]{ x0, y0, x1, y1 };
}

boolean overlapsAny(float[] b, ArrayList<float[]> others) {
  for (float[] o : others) {
    if (b[0] < o[2] && o[0] < b[2] && b[1] < o[3] && o[1] < b[3]) return true;
  }
  return false;
}

boolean inside(float[] b, float[] r) {
  return r == null || (b[0] >= r[0] && b[1] >= r[1] && b[2] <= r[0] + r[2] && b[3] <= r[1] + r[3]);
}

// A filled arrowhead at tip, pointing away from tail.
void arrowhead(PGraphics t, PVector tail, PVector tip, float k) {
  PVector dir = PVector.sub(tip, tail);
  if (dir.mag() < 1e-3) return;
  dir.normalize();
  PVector side = new PVector(-dir.y, dir.x);
  float len = 6 * k, half = 2.2 * k;
  t.pushStyle();
  t.noStroke();
  t.fill(CLR_DIM);
  t.triangle(tip.x, tip.y,
             tip.x - dir.x * len + side.x * half, tip.y - dir.y * len + side.y * half,
             tip.x - dir.x * len - side.x * half, tip.y - dir.y * len - side.y * half);
  t.popStyle();
}

// Text on a white backing, so it stays readable over the lines.
void labelAt(PGraphics t, String s, float x, float y, int alignX, int alignY, float k) {
  float w = t.textWidth(s), h = 11 * k;
  float pad = 2.5 * k;
  float left = alignX == LEFT ? x : alignX == RIGHT ? x - w : x - w / 2;
  float top  = alignY == TOP ? y : alignY == BOTTOM ? y - h : y - h / 2;
  t.noStroke();
  t.fill(CLR_DIM_LABEL);
  t.rect(left - pad, top - pad, w + 2 * pad, h + 2 * pad, 2 * k);
  t.fill(CLR_TEXT);
  t.textAlign(LEFT, TOP);
  t.text(s, round(left), round(top - 1.5 * k));   // whole pixels, or a full stop can vanish
}

PVector unit(PVector v) {
  float m = v.mag();
  return m < 1e-6 ? new PVector(0, 0) : PVector.div(v, m);
}

// Millimetres as a figure would print them: one decimal, dropped when it is zero, and always
// a decimal point -- nf() would follow the machine's locale and print a comma.
String fmtMM(float v) {
  float r = round(v * 10) / 10.0;
  if (abs(r - round(r)) < 0.001) return str(round(r));
  return String.format(java.util.Locale.US, "%.1f", r);
}

String fmtRatio(float v) {
  return String.format(java.util.Locale.US, "%.2f", v).replaceAll("0+$", "").replaceAll("\\.$", "");
}
