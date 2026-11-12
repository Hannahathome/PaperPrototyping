// CAMERA.PDE - One orbit / pan / zoom camera shared by all three panels
//
// Left-drag orbits (turntable: yaw about the vertical axis, tilt clamped), right-drag or
// shift-drag pans, the wheel zooms. Every panel reads the same numbers, so the shell, the
// scaffold and the assembly always face the same way.
//
// zoom is screen pixels per millimetre. Pan is in screen pixels. An export at scale k
// multiplies both by k, so the saved figure frames exactly what is on screen.

float rotX, rotY;          // radians
float panX, panY;          // screen px
float zoom = 4;            // px per mm

boolean dragging = false;

void resetView() {
  rotX = -0.45;            // looking down a little, so the top lid shows
  rotY = -PI / 7;
  panX = 0;
  panY = 0;
  float extent = max(max(topDiameter, bottomDiameter), shellHeight);
  zoom = 0.6 * min(panelW, panelH) / max(extent, 1);
}

// The view comes in two steps, because Processing fixes a light's direction using the
// transform in effect when the light is set: lights set between the two stay put relative
// to the viewer while the model turns under them.

// Step 1: projection and the default camera.
void applyProjection(PGraphics pg) {
  float w = pg.width, h = pg.height;
  pg.camera();
  if (orthoView) {
    float depth = max(w, h) * 20;
    pg.ortho(-w / 2, w / 2, -h / 2, h / 2, -depth, depth);
  } else {
    pg.perspective();
  }
}

// Step 2: the shared orbit / pan / zoom. k is the export scale.
void applyModelView(PGraphics pg, float k) {
  float w = pg.width, h = pg.height;
  pg.translate(w / 2 + panX * k, h / 2 + panY * k, 0);
  pg.scale(zoom * k);
  pg.rotateX(rotX);
  pg.rotateY(rotY);
}

boolean overPanels() {
  return mouseX >= panelX0 && mouseX < panelX(2) + panelW
      && mouseY >= panelY0 && mouseY < panelY0 + panelH;
}

void mousePressed() {
  dragging = overPanels() && !(showUI && cp5.isMouseOver());
}

void mouseReleased() {
  dragging = false;
}

void mouseDragged() {
  if (!dragging) return;
  float dx = mouseX - pmouseX;
  float dy = mouseY - pmouseY;
  boolean pan = mouseButton == RIGHT || mouseButton == CENTER || (keyPressed && keyCode == SHIFT);
  if (pan) {
    panX += dx;
    panY += dy;
  } else {
    rotY += dx * 0.01;
    rotX  = constrain(rotX - dy * 0.01, -HALF_PI, HALF_PI);
  }
}

void mouseWheel(MouseEvent e) {
  if (!overPanels() || (showUI && cp5.isMouseOver())) return;
  zoom = constrain(zoom * pow(0.9, e.getCount()), 0.05, 200);
}
