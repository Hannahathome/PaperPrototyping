// EXPORT.PDE - High-resolution PNG of the current view
//
// Renders the three panels again off-screen at exportScale x the on-screen panel size, with
// the same camera, so the figure frames exactly what is on screen -- just sharper. Writes:
//
//   output/figure_<stamp>.png            the three panels side by side (+ letters if shown)
//   output/figure_<stamp>_shell.png      each panel on its own, without a letter,
//   output/figure_<stamp>_scaffold.png   for laying the figure out in LaTeX / Illustrator
//   output/figure_<stamp>_assembly.png
//
// On-screen warnings are never included. Runs from draw() (see exportRequested), because
// creating P3D buffers needs the GL context that only the animation thread holds.

void exportFigure(ShellGeometry sg, FrameGeometry fg) {
  float k = max(1, exportScale);
  int w = round(panelW * k);
  int h = round(panelH * k);
  String base = "output/figure_" + timestamp();

  PImage[] imgs = new PImage[3];
  for (int i = 0; i < 3; i++) {
    PGraphics b = createGraphics(w, h, P3D);
    b.smooth(8);
    renderPanel(b, i, sg, fg, k, transparentBg);
    imgs[i] = b.get();
    b.dispose();
    imgs[i].save(sketchPath(base + "_" + PANEL_FILES[i] + ".png"));
  }

  PGraphics c = createGraphics(3 * w, h, JAVA2D);
  c.beginDraw();
  if (transparentBg) c.clear(); else c.background(CLR_PANEL);
  for (int i = 0; i < 3; i++) {
    c.image(imgs[i], i * w, 0);
    if (showLabels) drawPanelLabel(c, i * w, 0, w, h, i, k);
  }
  c.endDraw();
  c.save(sketchPath(base + ".png"));

  statusLine = "Saved " + base + ".png  (" + (3 * w) + " x " + h + ")";
  println("[Export] " + statusLine);
}

String timestamp() {
  return nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_"
       + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
}
