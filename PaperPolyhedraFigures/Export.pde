// EXPORT.PDE - High-resolution PNG of the current view
//
// Draws both panels again at exportScale x their on-screen size. The figure is plain 2D, so
// unlike ScaffoldShellFigures there is no off-screen 3D render: the same drawing code runs
// with k = exportScale, and every pixel length in it is multiplied by k. Writes:
//
//   output/template_<stamp>.png           both panels side by side (+ letters if shown)
//   output/template_<stamp>_template.png  panel a alone, without its letter,
//   output/template_<stamp>_details.png   panel b alone -- for laying the figure out yourself
//
// Runs from draw() (see exportRequested).

boolean drawingTransparent = false;   // set while a transparent export is drawn
boolean exporting = false;            // set while any export is drawn: on-screen-only marks stay off

void exportFigure(Template tp) {
  float k = max(1, exportScale);
  int wa = round(panelWs[0] * k), wb = round(panelWs[1] * k), h = round(panelH * k);
  String base = "output/template_" + timestamp();
  drawingTransparent = transparentBg;
  exporting = true;

  PGraphics a = panelCanvas(wa, h);
  a.beginDraw();
  renderTemplatePanel(a, tp, 0, 0, wa, h, k);
  a.endDraw();
  PGraphics b = panelCanvas(wb, h);
  b.beginDraw();
  renderDetailsPanel(b, tp, 0, 0, wb, h, k);
  b.endDraw();
  a.save(sketchPath(base + "_" + PANEL_FILES[0] + ".png"));
  b.save(sketchPath(base + "_" + PANEL_FILES[1] + ".png"));

  PGraphics c = createGraphics(wa + wb, h);
  c.beginDraw();
  if (transparentBg) c.clear(); else c.background(CLR_PANEL);
  c.image(a, 0, 0);
  c.image(b, wa, 0);
  if (showLabels) {
    drawPanelLabel(c, 0, 0, wa, h, 0, k);
    drawPanelLabel(c, wa, 0, wb, h, 1, k);
  }
  c.endDraw();
  c.save(sketchPath(base + ".png"));
  drawingTransparent = false;
  exporting = false;

  statusLine = "Saved " + base + ".png  (" + (wa + wb) + " x " + h + ")";
  println("[Export] " + statusLine);
}

PGraphics panelCanvas(int w, int h) {
  PGraphics p = createGraphics(w, h);
  p.smooth(8);
  return p;
}

String timestamp() {
  return nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_"
       + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
}
