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
final int PLACEHOLDER_PANEL_COUNT = 12;    // matches the 3..12 sides the UI allows

// Call once from setup(), before setParams() tries to loadImage() any of these.
void ensurePlaceholderAssets() {
  boolean madeAny = false;

  File panelDir = new File(dataPath("panels"));
  if (!panelDir.exists()) panelDir.mkdirs();

  if (makeLidPlaceholder("top.jpg", "TOP LID", color(38, 132, 196))) madeAny = true;
  if (makeLidPlaceholder("bottom.jpg", "BOTTOM LID", color(196, 84, 38))) madeAny = true;
  if (makeStripPlaceholder("strip.jpg")) madeAny = true;

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
