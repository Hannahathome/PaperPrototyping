// ---------------------------------------------------------------------------
// PlaceholderAssets.pde
//
// Generates the texture files the sketch expects in data/ if they are missing.
//
// Why this exists: the artwork used on polyhedra panels is personal media and
// ran to ~100 MB (single .tif files over 12 MB). Committing it would bloat the
// repository permanently, so data/ artwork is gitignored. Instead the sketch
// draws its own placeholders on first run, so a fresh clone is immediately
// runnable and every texture code path has something real to load.
//
// Nothing here overwrites an existing file. Drop your own top.jpg / bottom.jpg /
// strip.jpg / panels/edge_N.png into data/ and they win.
// ---------------------------------------------------------------------------

// Placeholders are deliberately informative rather than decorative: each one
// states what it is, which slot it fills, and carries a grid so tessellation
// seams and texture orientation are obvious at a glance.

final int PLACEHOLDER_LID_SIZE    = 512;   // px, square lid textures
final int PLACEHOLDER_PANEL_SIZE  = 512;   // px, square per-edge panel textures
final int PLACEHOLDER_STRIP_W     = 2048;  // px, wide strip that bends across panels
final int PLACEHOLDER_STRIP_H     = 256;   // px
final int PLACEHOLDER_WRAP_W      = 2048;  // px, whole-surface wrap (perimeter across)
final int PLACEHOLDER_WRAP_H      = 1200;  // px, bottom centre -> wall -> top centre
final int PLACEHOLDER_PANEL_COUNT = 12;    // matches the 3..12 sides the UI allows

// Call once from setup(), before setParams() tries to loadImage() any of these.
void ensurePlaceholderAssets() {
  boolean madeAny = false;

  File panelDir = new File(dataPath("panels"));
  if (!panelDir.exists()) panelDir.mkdirs();

  if (makeLidPlaceholder("top.jpg", "TOP LID", color(38, 132, 196))) madeAny = true;
  if (makeLidPlaceholder("bottom.jpg", "BOTTOM LID", color(196, 84, 38))) madeAny = true;
  if (makeStripPlaceholder("strip.jpg")) madeAny = true;
  if (makeWrapPlaceholder("wrap.jpg")) madeAny = true;

  for (int i = 0; i < PLACEHOLDER_PANEL_COUNT; i++) {
    if (makePanelPlaceholder(i)) madeAny = true;
  }

  if (madeAny) {
    println("[PlaceholderAssets] Generated placeholder textures in " + dataPath(""));
    println("[PlaceholderAssets] Replace them with your own artwork at any time.");
  }
}

// Returns true if the file was generated, false if it already existed.
boolean makeLidPlaceholder(String filename, String label, color accent) {
  if (assetExists(filename)) return false;

  PGraphics g = createGraphics(PLACEHOLDER_LID_SIZE, PLACEHOLDER_LID_SIZE);
  g.beginDraw();
  g.background(248);
  drawGrid(g, 8, color(220));

  // Corner brackets make rotation of the mapped texture immediately visible.
  g.noFill();
  g.stroke(accent);
  g.strokeWeight(6);
  float m = PLACEHOLDER_LID_SIZE * 0.08;
  float b = PLACEHOLDER_LID_SIZE * 0.16;
  g.line(m, m, m + b, m);
  g.line(m, m, m, m + b);
  g.line(PLACEHOLDER_LID_SIZE - m, m, PLACEHOLDER_LID_SIZE - m - b, m);

  // A single filled quadrant kills any doubt about mirroring.
  g.noStroke();
  g.fill(accent, 60);
  g.rect(m, m, PLACEHOLDER_LID_SIZE * 0.34, PLACEHOLDER_LID_SIZE * 0.34);

  g.fill(60);
  g.textAlign(CENTER, CENTER);
  g.textFont(createFont("Arial", 34));
  g.text(label, PLACEHOLDER_LID_SIZE / 2, PLACEHOLDER_LID_SIZE / 2);
  g.textFont(createFont("Arial", 18));
  g.fill(140);
  g.text("placeholder", PLACEHOLDER_LID_SIZE / 2, PLACEHOLDER_LID_SIZE / 2 + 34);
  g.endDraw();

  g.save(dataPath(filename));
  return true;
}

// The strip texture is mapped once across the whole perimeter, so the
// placeholder is a ruler: it shows continuity at panel seams and doubles as a
// rough print-scale check.
boolean makeStripPlaceholder(String filename) {
  if (assetExists(filename)) return false;

  PGraphics g = createGraphics(PLACEHOLDER_STRIP_W, PLACEHOLDER_STRIP_H);
  g.beginDraw();
  g.background(252);

  // Hue sweep left to right: any discontinuity in the bend shows up as a
  // colour jump rather than something you have to squint for.
  g.colorMode(HSB, 360, 100, 100);
  g.noStroke();
  for (int x = 0; x < PLACEHOLDER_STRIP_W; x += 4) {
    g.fill(map(x, 0, PLACEHOLDER_STRIP_W, 0, 340), 30, 100);
    g.rect(x, 0, 4, PLACEHOLDER_STRIP_H * 0.25);
  }
  g.colorMode(RGB, 255);

  // Ruler ticks every 1/100th of the strip, taller every 10th.
  g.stroke(70);
  g.textAlign(CENTER, TOP);
  g.textFont(createFont("Arial", 16));
  g.fill(70);
  for (int i = 0; i <= 100; i++) {
    float x = map(i, 0, 100, 0, PLACEHOLDER_STRIP_W);
    boolean major = (i % 10 == 0);
    g.strokeWeight(major ? 2 : 1);
    g.line(x, PLACEHOLDER_STRIP_H * 0.35, x, PLACEHOLDER_STRIP_H * (major ? 0.62 : 0.50));
    if (major && i < 100) g.text(i + "%", x, PLACEHOLDER_STRIP_H * 0.66);
  }

  g.noStroke();
  g.fill(120);
  g.textAlign(CENTER, CENTER);
  g.textFont(createFont("Arial", 20));
  g.text("STRIP PLACEHOLDER  -  replace with data/strip.jpg",
         PLACEHOLDER_STRIP_W / 2, PLACEHOLDER_STRIP_H * 0.90);
  g.endDraw();

  g.save(dataPath(filename));
  return true;
}

// The wrap texture covers the WHOLE surface, so its placeholder is a calibration sheet:
// horizontal rules say where a rim landed, vertical rules say where a fold landed, and the
// TOP / BOTTOM captions make the vertical orientation impossible to misread. Where the two
// rims fall depends on the shape's own proportions, so the rules are a plain percentage
// grid rather than marks baked at particular heights. See WrapFrame.pde.
boolean makeWrapPlaceholder(String filename) {
  if (assetExists(filename)) return false;

  PGraphics g = createGraphics(PLACEHOLDER_WRAP_W, PLACEHOLDER_WRAP_H);
  g.beginDraw();

  // Hue around the perimeter, value up the surface: a break at the seam shows as a colour
  // jump, a break at a rim shows as a step in brightness.
  g.colorMode(HSB, 360, 100, 100);
  g.noStroke();
  for (int x = 0; x < PLACEHOLDER_WRAP_W; x += 8) {
    float hue = map(x, 0, PLACEHOLDER_WRAP_W, 0, 340);
    for (int y = 0; y < PLACEHOLDER_WRAP_H; y += 8) {
      g.fill(hue, 26, map(y, 0, PLACEHOLDER_WRAP_H, 100, 74));
      g.rect(x, y, 8, 8);
    }
  }
  g.colorMode(RGB, 255);

  // Percentage grid. Horizontals every 10%, verticals every 1/12 - twelve being the most
  // sides the UI allows, so every panel count lands on a line or a clean fraction of one.
  g.textFont(createFont("Arial", 20));
  for (int i = 1; i < 10; i++) {
    float y = PLACEHOLDER_WRAP_H * i / 10.0;
    g.stroke(60, 90);
    g.strokeWeight(i == 5 ? 3 : 1);
    g.line(0, y, PLACEHOLDER_WRAP_W, y);
    g.noStroke();
    g.fill(40);
    g.textAlign(LEFT, CENTER);
    g.text((100 - i * 10) + "%", 12, y - 14);
  }
  for (int i = 1; i < 12; i++) {
    float x = PLACEHOLDER_WRAP_W * i / 12.0;
    g.stroke(60, 60);
    g.strokeWeight(1);
    g.line(x, 0, x, PLACEHOLDER_WRAP_H);
    g.noStroke();
    g.fill(40);
    g.textAlign(CENTER, TOP);
    g.text(i + "/12", x, PLACEHOLDER_WRAP_H * 0.5 + 6);
  }

  // The seam. s = 0 and s = 1 meet here, so these two edges must line up on the folded form.
  g.stroke(200, 40, 40);
  g.strokeWeight(8);
  g.line(4, 0, 4, PLACEHOLDER_WRAP_H);
  g.line(PLACEHOLDER_WRAP_W - 4, 0, PLACEHOLDER_WRAP_W - 4, PLACEHOLDER_WRAP_H);

  // Which way is up. The top row of the image collapses onto the top lid's centre.
  g.noStroke();
  g.textAlign(CENTER, TOP);
  g.textFont(createFont("Arial", 54));
  g.fill(30);
  g.text("TOP LID CENTRE", PLACEHOLDER_WRAP_W / 2, 18);
  g.textAlign(CENTER, BOTTOM);
  g.text("BOTTOM LID CENTRE", PLACEHOLDER_WRAP_W / 2, PLACEHOLDER_WRAP_H - 18);

  g.textAlign(CENTER, CENTER);
  g.textFont(createFont("Arial", 26));
  g.fill(70);
  g.text("WRAP PLACEHOLDER  -  replace with data/wrap.jpg",
         PLACEHOLDER_WRAP_W / 2, PLACEHOLDER_WRAP_H * 0.5 - 30);
  g.endDraw();

  g.save(dataPath(filename));
  return true;
}

boolean makePanelPlaceholder(int edgeIdx) {
  String rel = "panels/edge_" + edgeIdx + ".png";
  if (assetExists(rel)) return false;
  // Respect a .jpg the user may have supplied for the same slot.
  if (assetExists("panels/edge_" + edgeIdx + ".jpg")) return false;

  PGraphics g = createGraphics(PLACEHOLDER_PANEL_SIZE, PLACEHOLDER_PANEL_SIZE);
  g.beginDraw();

  // Distinct hue per edge so you can tell at a glance which panel went where
  // once the net is folded up.
  g.colorMode(HSB, 360, 100, 100);
  color base = g.color((edgeIdx * 360.0 / PLACEHOLDER_PANEL_COUNT) % 360, 22, 100);
  color ink  = g.color((edgeIdx * 360.0 / PLACEHOLDER_PANEL_COUNT) % 360, 70, 62);
  g.colorMode(RGB, 255);

  g.background(base);
  drawGrid(g, 8, color(255, 120));

  g.noFill();
  g.stroke(ink);
  g.strokeWeight(4);
  g.rect(8, 8, PLACEHOLDER_PANEL_SIZE - 16, PLACEHOLDER_PANEL_SIZE - 16);

  // Arrow pointing "up" relative to the texture, so a flipped or rotated
  // mapping is unmistakable.
  g.strokeWeight(6);
  float cx = PLACEHOLDER_PANEL_SIZE / 2;
  g.line(cx, PLACEHOLDER_PANEL_SIZE * 0.72, cx, PLACEHOLDER_PANEL_SIZE * 0.60);
  g.line(cx, PLACEHOLDER_PANEL_SIZE * 0.60, cx - 14, PLACEHOLDER_PANEL_SIZE * 0.66);
  g.line(cx, PLACEHOLDER_PANEL_SIZE * 0.60, cx + 14, PLACEHOLDER_PANEL_SIZE * 0.66);

  g.noStroke();
  g.fill(ink);
  g.textAlign(CENTER, CENTER);
  g.textFont(createFont("Arial", 120));
  g.text(str(edgeIdx), cx, PLACEHOLDER_PANEL_SIZE * 0.40);
  g.textFont(createFont("Arial", 20));
  g.text("edge " + edgeIdx, cx, PLACEHOLDER_PANEL_SIZE * 0.86);
  g.endDraw();

  g.save(dataPath(rel));
  return true;
}

// --- helpers ---------------------------------------------------------------

boolean assetExists(String relativePath) {
  return new File(dataPath(relativePath)).exists();
}

void drawGrid(PGraphics g, int divisions, color c) {
  g.stroke(c);
  g.strokeWeight(1);
  for (int i = 1; i < divisions; i++) {
    float t = i / float(divisions);
    g.line(t * g.width, 0, t * g.width, g.height);
    g.line(0, t * g.height, g.width, t * g.height);
  }
  g.noStroke();
}
