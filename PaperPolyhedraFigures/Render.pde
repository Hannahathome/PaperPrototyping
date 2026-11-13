// RENDER.PDE - Drawing the template and the two panels
//
// Everything is drawn into a target PGraphics t at a panel's rectangle, with k the export
// scale: k = 1 on screen, exportScale in a saved PNG, where every length in pixels -- line
// weights, dashes, text, gaps -- is multiplied by k, so the export is the screen figure,
// sharper. The template itself is in millimetres; a View maps it into a rectangle.
//
// Folds are dashed here, at a figure's dash length, not at the cutter's: Template.pde
// records each fold as one whole line.

final float FOLD_DASH_PX = 5;
final float FOLD_GAP_PX  = 3.5;

// Template millimetres -> target pixels: uniform scale, then offset.
class View {
  float s, ox, oy;
  PVector map(PVector p) { return new PVector(ox + p.x * s, oy + p.y * s); }
}

// The view that fits the box (mm) into the rectangle (px), centred, leaving `pad` px clear.
View fitView(float x0, float y0, float x1, float y1, float rx, float ry, float rw, float rh, float pad) {
  View v = new View();
  float w = max(1e-3, x1 - x0), h = max(1e-3, y1 - y0);
  v.s = min((rw - 2 * pad) / w, (rh - 2 * pad) / h);
  v.ox = rx + rw / 2 - (x0 + w / 2) * v.s;
  v.oy = ry + rh / 2 - (y0 + h / 2) * v.s;
  return v;
}

void drawTemplate(PGraphics t, Template tp, View v, float k) {
  t.pushStyle();
  t.noFill();
  t.strokeJoin(ROUND);
  t.strokeCap(ROUND);
  t.strokeWeight(lineWeight * k);
  for (TStroke s : tp.strokes) {
    if (s.kind == K_CUT) {
      t.stroke(CLR_CUT);
      t.beginShape();
      for (PVector p : s.pts) { PVector q = v.map(p); t.vertex(q.x, q.y); }
      t.endShape();
    } else {
      t.stroke(CLR_FOLD);
      for (int i = 0; i + 1 < s.pts.length; i++) {
        dashedLine(t, v.map(s.pts[i]), v.map(s.pts[i + 1]), FOLD_DASH_PX * k, FOLD_GAP_PX * k);
      }
    }
  }
  t.popStyle();
}

// Dashes centred on the line, so both ends look the same.
void dashedLine(PGraphics t, PVector a, PVector b, float dash, float gap) {
  float len = PVector.dist(a, b);
  if (len < 1e-3) return;
  PVector d = PVector.sub(b, a).div(len);
  int n = max(1, floor((len + gap) / (dash + gap)));
  float used = n * dash + (n - 1) * gap;
  float pos = (len - used) / 2;
  for (int i = 0; i < n; i++) {
    float e = min(len, pos + dash);
    t.line(a.x + d.x * pos, a.y + d.y * pos, a.x + d.x * e, a.y + d.y * e);
    pos += dash + gap;
  }
}

// ---------------------------------------------------------------------------
// Panel a: the whole template
// ---------------------------------------------------------------------------

void renderTemplatePanel(PGraphics t, Template tp, float x, float y, float w, float h, float k) {
  t.pushStyle();
  t.noStroke();
  t.fill(CLR_PANEL);
  if (!drawingTransparent) t.rect(x, y, w, h);

  // Room under the template for the legend and the letter tag, and around it for dimensions.
  float bottomRoom = (showLegend ? 62 : 0) * k + (showLabels ? 34 : 14) * k;
  View v = fitView(tp.minX, tp.minY, tp.maxX, tp.maxY, x, y, w, h - bottomRoom + 20 * k, 36 * k);

  drawTemplate(t, tp, v, k);
  if (showFrames) drawCloseupFrames(t, tp, v, k);
  if (showDimensions) {
    beginLabels();
    drawPanelDimensions(t, tp, v, k);
    placeLabels(t, new float[]{ x, y, w, h - bottomRoom }, k);
  }
  if (showLegend) drawTemplateLegend(t, tp, x + 14 * k, y + h - bottomRoom + 12 * k, k);
  t.popStyle();
}

// Numbered frames on the template, where each close-up of panel b comes from. A close-up
// zoomed or panned by hand is framed by the area it was asked to show instead.
void drawCloseupFrames(PGraphics t, Template tp, View v, float k) {
  for (int i = 0; i < CLOSEUPS.length; i++) {
    float[] box = closeupBox(tp, i, true);
    if (box == null) continue;
    if (closeupZoom[i] > 1.001 || closeupPanX[i] != 0 || closeupPanY[i] != 0) {
      float[] full = closeupBox(tp, i, false);
      float cx = (full[0] + full[2]) / 2 + closeupPanX[i], cy = (full[1] + full[3]) / 2 + closeupPanY[i];
      float hw = (full[2] - full[0]) / 2 / closeupZoom[i], hh = (full[3] - full[1]) / 2 / closeupZoom[i];
      box = new float[]{ cx - hw, cy - hh, cx + hw, cy + hh };
    }
    PVector a = v.map(new PVector(box[0], box[1])), b = v.map(new PVector(box[2], box[3]));
    float m = 4 * k;
    t.noFill();
    t.stroke(CLR_FRAME);
    t.strokeWeight(0.75 * k);
    t.rect(a.x - m, a.y - m, b.x - a.x + 2 * m, b.y - a.y + 2 * m, 3 * k);
    numberTag(t, i + 1, a.x - m - 14 * k, a.y - m, k);
  }
}

// A small dark square with a number, its top-left corner at (x, y).
void numberTag(PGraphics t, int n, float x, float y, float k) {
  float s = 14 * k;
  t.noStroke();
  t.fill(CLR_TAG);
  t.rect(x, y, s, s);
  t.fill(CLR_TAG_TEXT);
  t.textFont(k > 1.5 ? fontLabel : fontHeader);
  t.textSize(10 * k);
  t.textAlign(CENTER, CENTER);
  t.text(str(n), round(x + s / 2), round(y + s / 2 - 1 * k));
}

// Line kinds, the shape, and any size PaperPolyhedra has limited.
void drawTemplateLegend(PGraphics t, Template tp, float x, float y, float k) {
  t.pushStyle();
  t.textFont(k > 1.5 ? fontDim : fontBody);
  t.textSize(11 * k);
  t.textAlign(LEFT, CENTER);
  float lineLen = 26 * k, rowH = 16 * k;

  t.strokeWeight(lineWeight * k);
  t.stroke(CLR_CUT);
  t.line(x, y, x + lineLen, y);
  t.noStroke();
  t.fill(CLR_TEXT);
  t.text("Cut", round(x + lineLen + 6 * k), round(y));

  float x2 = x + lineLen + 50 * k;
  t.stroke(CLR_FOLD);
  dashedLine(t, new PVector(x2, y), new PVector(x2 + lineLen, y), FOLD_DASH_PX * k, FOLD_GAP_PX * k);
  t.noStroke();
  t.text("Fold", round(x2 + lineLen + 6 * k), round(y));

  String shape = tp.edgeTop == tp.edgeBot ? "prism" : "frustum";
  String info = sides + "-sided " + shape + ",  height " + fmtMM(shellHeight) + " mm"
              + (splitStrip && sides >= 4 ? ",  strip split in two" : "");
  t.text(info, round(x), round(y + rowH));

  ArrayList<String> limits = new ArrayList<String>();
  if (tp.tabClamped)   limits.add("tab depth limited to " + fmtMM(tp.tabDepthUsed) + " mm");
  if (tp.flapClamped)  limits.add("flap depth limited to " + fmtMM(tp.flapDepthUsed) + " mm");
  if (tp.taperClamped) limits.add("flap taper limited to " + fmtMM(tp.flapTaperUsed) + " mm");
  if (!limits.isEmpty()) {
    t.fill(CLR_TEXT_MUTED);
    t.text(join(limits.toArray(new String[0]), ",  ") + " by PaperPolyhedra", round(x), round(y + 2 * rowH));
  }
  t.popStyle();
}

// ---------------------------------------------------------------------------
// Panel b: the four close-ups, two by two
// ---------------------------------------------------------------------------

void renderDetailsPanel(PGraphics t, Template tp, float x, float y, float w, float h, float k) {
  t.pushStyle();
  t.noStroke();
  t.fill(CLR_PANEL);
  if (!drawingTransparent) t.rect(x, y, w, h);

  float bottomRoom = (showLabels ? 34 : 10) * k;
  float m = 10 * k;
  float cw = (w - 3 * m) / 2, ch = (h - bottomRoom - 3 * m) / 2;
  for (int i = 0; i < CLOSEUPS.length; i++) {
    float cx = x + m + (i % 2) * (cw + m);
    float cy = y + m + (i / 2) * (ch + m);
    renderCloseup(t, tp, i, cx, cy, cw, ch, k);
  }
  t.popStyle();
}

void renderCloseup(PGraphics t, Template tp, int i, float x, float y, float w, float h, float k) {
  // Cell: a hairline frame, the title band at the top, the notes band at the bottom, and the
  // close-up clipped to the space between, so no line runs into either.
  t.noFill();
  t.stroke(230);
  t.strokeWeight(1 * k);
  t.rect(x, y, w, h);
  numberTag(t, i + 1, x + 8 * k, y + 8 * k, k);
  t.fill(CLR_TEXT);
  t.textFont(k > 1.5 ? fontLabel : fontHeader);
  t.textSize(11 * k);
  t.textAlign(LEFT, CENTER);
  t.text(CLOSEUPS[i], round(x + 28 * k), round(y + 15 * k));

  float[] box = closeupBox(tp, i, false);
  if (box == null) {
    t.fill(CLR_TEXT_MUTED);
    t.textFont(k > 1.5 ? fontDim : fontBody);
    t.textSize(11 * k);
    t.text("Not in this template", round(x + 10 * k), round(y + h / 2));
    return;
  }

  float top = 30 * k, notesRoom = (showNotes ? 50 : 4) * k;
  float vy = y + top, vh = h - top - notesRoom;
  // The cell's own zoom and pan (Camera-free, in template mm, so an export frames the same).
  float cx = (box[0] + box[2]) / 2 + closeupPanX[i], cy = (box[1] + box[3]) / 2 + closeupPanY[i];
  float hw = (box[2] - box[0]) / 2 / closeupZoom[i], hh = (box[3] - box[1]) / 2 / closeupZoom[i];
  View v = fitView(cx - hw, cy - hh, cx + hw, cy + hh, x, vy, w, vh, 8 * k);
  if (!exporting) {
    closeupViews[i] = v;
    closeupRects[i] = new float[]{ x, vy, w, vh };
  }
  t.clip(x + 1, vy, w - 2, vh);
  drawTemplate(t, tp, v, k);
  if (showDimensions) {
    beginLabels();
    drawCloseupDimensions(t, tp, i, v, k);
    placeLabels(t, new float[]{ x + 1, vy, w - 2, vh }, k);
  }
  t.noClip();
  if (closeupZoom[i] > 1.001 || closeupPanX[i] != 0 || closeupPanY[i] != 0) {
    // On screen only: how far in, and how to get back.
    if (!exporting) {
      t.fill(CLR_TEXT_MUTED);
      t.textFont(fontBody);
      t.textSize(10);
      t.textAlign(RIGHT, CENTER);
      t.text(nf(closeupZoom[i], 0, 1).replace(',', '.') + "×   R resets", round(x + w - 8), round(y + 15));
    }
  }
  if (showNotes) drawCloseupNotes(t, tp, i, x + 10 * k, y + h - notesRoom + 6 * k, k);
}

// ---------------------------------------------------------------------------
// Zooming into a close-up: wheel to zoom about the cursor, drag to pan, R to reset
// ---------------------------------------------------------------------------

float[] closeupZoom = { 1, 1, 1, 1 };
float[] closeupPanX = { 0, 0, 0, 0 }, closeupPanY = { 0, 0, 0, 0 };   // mm
View[]  closeupViews = new View[4];          // as last drawn on screen
float[][] closeupRects = new float[4][];
int draggingCloseup = -1;

int closeupAt(float mx, float my) {
  for (int i = 0; i < 4; i++) {
    float[] r = closeupRects[i];
    if (r != null && closeupViews[i] != null
        && mx >= r[0] && mx < r[0] + r[2] && my >= r[1] && my < r[1] + r[3]) return i;
  }
  return -1;
}

void resetCloseupZoom() {
  for (int i = 0; i < 4; i++) { closeupZoom[i] = 1; closeupPanX[i] = 0; closeupPanY[i] = 0; }
}

void mouseWheel(MouseEvent e) {
  if (showUI && cp5.isMouseOver()) return;
  int i = closeupAt(mouseX, mouseY);
  if (i < 0) return;
  View v = closeupViews[i];
  float z0 = closeupZoom[i];
  float z1 = constrain(z0 * pow(0.85, e.getCount()), 1, 40);
  // Keep the point under the cursor where it is: the view centre moves toward it.
  float px = (mouseX - v.ox) / v.s, py = (mouseY - v.oy) / v.s;
  float[] r = closeupRects[i];
  float cx = (r[0] + r[2] / 2 - v.ox) / v.s, cy = (r[1] + r[3] / 2 - v.oy) / v.s;
  closeupPanX[i] += (px - cx) * (1 - z0 / z1);
  closeupPanY[i] += (py - cy) * (1 - z0 / z1);
  closeupZoom[i] = z1;
}

void mousePressed() {
  draggingCloseup = (showUI && cp5.isMouseOver()) ? -1 : closeupAt(mouseX, mouseY);
}

void mouseReleased() {
  draggingCloseup = -1;
}

void mouseDragged() {
  if (draggingCloseup < 0 || closeupViews[draggingCloseup] == null) return;
  float s = closeupViews[draggingCloseup].s;
  closeupPanX[draggingCloseup] -= (mouseX - pmouseX) / s;
  closeupPanY[draggingCloseup] -= (mouseY - pmouseY) / s;
}

// ---------------------------------------------------------------------------
// Panel letters and the sidebar
// ---------------------------------------------------------------------------

// As in ScaffoldShellFigures: a dark square tag with a white letter at the bottom left, on a
// thin rule along the bottom of the panel.
void drawPanelLabel(PGraphics t, float x, float y, float w, float h, int i, float k) {
  float m    = 14 * k;
  float tag  = 20 * k;
  float base = y + h - m;
  t.pushStyle();
  t.stroke(CLR_TAG);
  t.strokeWeight(1 * k);
  t.line(x + m, base, x + w - m, base);
  t.noStroke();
  t.fill(CLR_TAG);
  t.rect(x + m, base - tag, tag, tag);
  t.fill(CLR_TAG_TEXT);
  t.textFont(fontLabel);
  t.textSize(14 * k);
  t.textAlign(CENTER, CENTER);
  t.text(PANEL_LETTERS[i], x + m + tag / 2, base - tag / 2 - 2 * k);
  t.popStyle();
}
