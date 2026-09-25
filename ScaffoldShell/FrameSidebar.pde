// FRAMESIDEBAR.PDE - The Frame tab
//
// Controls for the selected shape's internal support frame. This is what replaced
// FrustumSupport's window: the frustum itself is NOT here, because it is derived from the
// shell (Frame.pde). What is left to choose is how the frame is built -- strut thickness,
// clearance, and the component rigs inside it.
//
// The tab is laid out ONCE per interaction into a list of rows, and both the drawing and
// the hit-testing walk that same list. The Shape tab takes the same approach with its
// shapeActionBtnRect()/shapeCounterBtnRect() helpers, for the same reason: a hand-drawn
// panel whose click targets are computed separately from its pixels will drift, and the
// drift is invisible until someone clicks the wrong thing.

final int FROW_HEADER   = 0;   // section heading
final int FROW_NOTE     = 1;   // explanatory / warning text, no interaction
final int FROW_NUM      = 2;   // label + [-] value [+]
final int FROW_TOGGLE   = 3;   // label + on/off pill
final int FROW_BUTTON   = 4;   // full-width button
final int FROW_SELECT   = 5;   // label + [<] text [>]

final float FROW_H      = 26;
final float FROW_GAP    = 5;
final float FROW_STEP_H = 22;   // the small +/- buttons

class FrameRow {
  int kind;
  String id, label, text, unit;
  float value, step, minV, maxV;
  boolean on;
  color tint = color(60);
  float x, y, w, h;

  FrameRow(int kind, String id, String label) {
    this.kind = kind; this.id = id; this.label = label;
    this.text = ""; this.unit = ""; this.step = 0.5;
    this.minV = -9999; this.maxV = 9999;
  }
  FrameRow num(float v, float st, float lo, float hi, String u) {
    value = v; step = st; minV = lo; maxV = hi; unit = u; return this;
  }
  FrameRow toggled(boolean b) { on = b; return this; }
  FrameRow txt(String t) { text = t; return this; }
  FrameRow colored(color c) { tint = c; return this; }
}

// ---------------------------------------------------------------------------
// Layout -- the single source of truth for this tab
// ---------------------------------------------------------------------------

ArrayList<FrameRow> frameRows() {
  ArrayList<FrameRow> rows = new ArrayList<FrameRow>();
  if (sidebar == null || shapes == null || shapes.isEmpty()) return rows;

  ShapeSpec s = shapes.get(constrain(selectedShapeIdx, 0, shapes.size() - 1));
  FrameSpec f = s.frame;

  String shapeName = (s.label != null && !s.label.trim().isEmpty())
                   ? s.label.trim() : ("Shape " + (selectedShapeIdx + 1));

  // The shell it will sit in, as the frame sees it. Shown because the whole point of
  // deriving these is that the user can no longer type them -- so they have to be able to
  // read them, and see them move when they change the shape.
  if (!frameAvailable(s)) {
    rows.add(new FrameRow(FROW_HEADER, "", "SCAFFOLD  —  " + shapeName));
    rows.add(new FrameRow(FROW_NOTE, "", "")
      .txt("No scaffold for this shape: " + frameUnavailableReason(s) + ".")
      .colored(color(180, 90, 40)));
    rows.add(new FrameRow(FROW_NOTE, "", "")
      .txt("A scaffold is built as a uniform regular frustum, matching the scope of "
         + "base plates and lid connections."));
    layoutFrameRows(rows);
    return rows;
  }

  FrameDims d = frameDimsFor(s);
  rows.add(new FrameRow(FROW_HEADER, "", "SCAFFOLD  —  " + shapeName));
  rows.add(new FrameRow(FROW_NOTE, "", "")
    .txt(d.n + " sides   ·   R bottom " + nf(d.botR, 0, 1) + "   ·   R top " + nf(d.topR, 0, 1)
       + "   ·   H " + nf(d.height, 0, 1) + " mm")
    .colored(color(90, 110, 140)));
  rows.add(new FrameRow(FROW_NOTE, "", "")
    .txt("Derived from the shape's perimeters — edit them on the Shape tab.")
    .colored(color(140)));

  rows.add(new FrameRow(FROW_TOGGLE, "frame_enabled", "Build a scaffold for this shape")
    .toggled(f.enabled));

  if (!f.enabled) {
    layoutFrameRows(rows);
    return rows;
  }

  rows.add(new FrameRow(FROW_HEADER, "", "STRUCTURE"));
  rows.add(new FrameRow(FROW_NUM, "strut_radius", "Strut radius")
    .num(f.strutRadius, 0.1, 0.2, 10, "mm"));
  rows.add(new FrameRow(FROW_NUM, "clearance", "Clearance")
    .num(f.clearanceMM, 0.1, 0, 5, "mm"));
  rows.add(new FrameRow(FROW_NUM, "flap_length", "Wall flap length")
    .num(f.flapLength, 0.5, 0, 30, "mm"));

  FrameScadParams p = frameScadParamsFor(s);
  if (!p.valid) {
    rows.add(new FrameRow(FROW_NOTE, "", "")
      .txt("Will not build: " + p.problem + ".")
      .colored(color(200, 60, 60)));
  }

  rows.add(new FrameRow(FROW_HEADER, "", "COMPONENT RIGS"));
  int nRigs = f.rigs.size();
  rows.add(new FrameRow(FROW_SELECT, "rig_select", "Rig")
    .txt(nRigs == 0 ? "none" : ((f.selectedRigIdx + 1) + " of " + nRigs)));
  rows.add(new FrameRow(FROW_BUTTON, "rig_add", nRigs == 0 ? "Add a rig" : "Add rig (copy of this one)"));
  if (nRigs > 0) rows.add(new FrameRow(FROW_BUTTON, "rig_remove", "Remove this rig"));

  Rig r = f.selectedRig();
  if (r != null) {
    rows.add(new FrameRow(FROW_SELECT, "rig_preset", "Component")
      .txt(RIG_PRESET_NAMES[frameRigPresetIndex(r)]));
    for (int j = 0; j < RIG_NPARAM; j++) {
      boolean isRot = (j == 6);
      rows.add(new FrameRow(FROW_NUM, "rig_" + j, RIG_PARAM_LABELS[j])
        .num(r.get(j), isRot ? 5 : 0.5,
             (j >= 3 && j <= 4) || isRot ? -9999 : 0,
             isRot ? 9999 : 9999,
             isRot ? "deg" : "mm"));
    }

    // Which face of this rig cuts a window in the paper, and whether it gets there.
    rows.add(new FrameRow(FROW_SELECT, "rig_cut_face", "Paper cutout")
      .txt(RIG_CUT_FACE_NAMES[r.cutoutFace]));
    if (r.cutoutFace != RIG_CUT_NONE) {
      RigCutoutPlan cp = planRigCutout(s, buildFrameGeometry(s), f.selectedRigIdx);
      String sizeTxt = RIG_CUT_SIZE_NAMES[r.cutoutSize];
      if (r.cutoutSize == 0 && cp != null && cp.sizeMM > 0) sizeTxt += " (" + nf(cp.sizeMM, 0, 0) + " mm)";
      rows.add(new FrameRow(FROW_SELECT, "rig_cut_size", "Cutout size").txt(sizeTxt));
      if (cp != null && !cp.status.isEmpty()) {
        boolean ok = cp.reaches && cp.fits;
        rows.add(new FrameRow(FROW_NOTE, "", "")
          .txt(cp.status)
          .colored(ok ? color(60, 130, 80) : color(200, 120, 30)));
      }
    }

    rows.add(new FrameRow(FROW_TOGGLE, "dual_struts", "Two posts per face")
      .toggled(f.dualStruts));
    if (f.dualStruts) {
      rows.add(new FrameRow(FROW_NUM, "strut_spacing", "Post spacing")
        .num(f.strutSpacing, 0.5, 0, 200, "mm"));
    }

    // A rig taller than the shell is legal geometry and a useless print, so it is a
    // warning rather than a clamp -- the user may be mid-edit.
    FrameGeometry g = buildFrameGeometry(s);
    if (g.valid && g.highestRigTop > g.zTop + 0.01) {
      rows.add(new FrameRow(FROW_NOTE, "", "")
        .txt("A rig reaches " + nf(g.highestRigTop - g.zTop, 0, 1)
           + " mm above the shell's top — lower it, or the scaffold will not fit inside.")
        .colored(color(200, 120, 30)));
    }
  }

  rows.add(new FrameRow(FROW_HEADER, "", "EXPORT"));
  rows.add(new FrameRow(FROW_TOGGLE, "show_frame", "Show scaffolds in the 3D view")
    .toggled(scaffoldVisible3D()));
  rows.add(new FrameRow(FROW_BUTTON, "frame_export", "Export this scaffold (.scad)"));
  rows.add(new FrameRow(FROW_NOTE, "", "")
    .txt("Scaffolds are also written by the main Export, one file per scaffold-enabled shape. "
       + "Open the .scad in OpenSCAD, render with F6, export STL.")
    .colored(color(140)));

  layoutFrameRows(rows);
  return rows;
}

// How far the tab is scrolled, in pixels. The rig parameters alone are seven rows, so on a
// window near the documented 700px minimum the tab is taller than the space it has. It
// scrolls rather than being compressed, because every row on it is a number someone has to
// be able to read and hit.
float frameScrollY = 0;
float _frameContentH = 0;   // total laid-out height, measured by the last layout pass

// Assigns every row its rectangle. Called at the end of frameRows(), so no caller can
// forget to and get a list of rows with zero-sized hit targets. Scroll is applied HERE,
// which is what keeps the drawing and the hit-testing agreeing about where a row is.
void layoutFrameRows(ArrayList<FrameRow> rows) {
  float rx = sidebar.x + SIDEBAR_PADDING;
  float rw = sidebar.w - 2 * SIDEBAR_PADDING;
  float top = sidebar.contentY + SIDEBAR_PADDING;
  float cy = top;

  for (FrameRow row : rows) {
    row.x = rx;
    row.w = rw;
    if (row.kind == FROW_HEADER) {
      cy += 8;
      row.h = 18;
    } else if (row.kind == FROW_NOTE) {
      row.h = frameNoteHeight(row.text, rw);
    } else {
      row.h = FROW_H;
    }
    row.y = cy;
    cy += row.h + FROW_GAP;
  }

  _frameContentH = cy - top;
  frameScrollY = constrain(frameScrollY, 0, frameScrollMax());
  if (frameScrollY > 0) {
    for (FrameRow row : rows) row.y -= frameScrollY;
  }
}

float frameViewportH() {
  return height - SIDEBAR_PADDING - (sidebar.contentY + SIDEBAR_PADDING);
}

float frameScrollMax() {
  return max(0, _frameContentH - frameViewportH());
}

boolean handleFrameTabWheel(float count) {
  if (mouseX < sidebar.x || mouseX > sidebar.x + sidebar.w) return false;
  if (frameScrollMax() <= 0) return false;
  frameScrollY = constrain(frameScrollY + count * FROW_H * 0.8, 0, frameScrollMax());
  redraw();
  return true;
}

// Notes wrap, so their height is not fixed. Measured with the same font the drawing uses.
float frameNoteHeight(String s, float w) {
  if (s == null || s.isEmpty()) return 0;
  pushStyle();
  uiText(11);
  int lines = frameWrapLines(s, w).size();
  popStyle();
  return max(14, lines * 14);
}

ArrayList<String> frameWrapLines(String s, float w) {
  ArrayList<String> out = new ArrayList<String>();
  String[] words = split(s, ' ');
  String cur = "";
  for (String word : words) {
    String trial = cur.isEmpty() ? word : cur + " " + word;
    if (textWidth(trial) > w && !cur.isEmpty()) {
      out.add(cur);
      cur = word;
    } else {
      cur = trial;
    }
  }
  if (!cur.isEmpty()) out.add(cur);
  return out;
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

void drawFrameContent() {
  ArrayList<FrameRow> rows = frameRows();
  float vy = sidebar.contentY + 1;
  float vh = height - vy;

  pushStyle();
  // Clipped, so a scrolled row cannot paint over the tab bar above it.
  clip(sidebar.x, vy, sidebar.w, vh);
  for (FrameRow row : rows) {
    if (row.y + row.h < vy || row.y > vy + vh) continue;   // off-screen, skip the work
    drawFrameRow(row);
  }
  noClip();

  drawFrameScrollbar(vy, vh);
  popStyle();
}

// A thin track on the sidebar's right edge, shown only when there is something to scroll.
void drawFrameScrollbar(float vy, float vh) {
  float maxScroll = frameScrollMax();
  if (maxScroll <= 0) return;

  float trackX = sidebar.x + sidebar.w - 5;
  float frac   = frameViewportH() / _frameContentH;
  float thumbH = max(30, vh * frac);
  float thumbY = vy + (vh - thumbH) * (frameScrollY / maxScroll);

  noStroke();
  fill(0, 25);
  rect(trackX, vy, 3, vh, 1.5);
  fill(120, 130, 145);
  rect(trackX, thumbY, 3, thumbH, 1.5);
}

void drawFrameRow(FrameRow row) {
  switch (row.kind) {
    case FROW_HEADER:
      fill(70, 80, 95);
      textAlign(LEFT, CENTER);
      uiText(11);
      text(row.label, row.x, row.y + row.h / 2);
      stroke(210);
      strokeWeight(1);
      line(row.x, row.y + row.h, row.x + row.w, row.y + row.h);
      noStroke();
      break;

    case FROW_NOTE: {
      fill(row.tint);
      textAlign(LEFT, TOP);
      uiText(11);
      ArrayList<String> lines = frameWrapLines(row.text, row.w);
      for (int i = 0; i < lines.size(); i++) {
        text(lines.get(i), row.x, row.y + i * 14);
      }
      break;
    }

    case FROW_NUM: {
      fill(60);
      textAlign(LEFT, CENTER);
      uiText(12);
      text(row.label, row.x, row.y + row.h / 2);

      float[] mr = frameStepBtnRect(row, false);
      float[] pr = frameStepBtnRect(row, true);
      drawFrameMiniBtn(mr, "–");
      drawFrameMiniBtn(pr, "+");

      float[] vr = frameValueRect(row);
      fill(255);
      stroke(200);
      strokeWeight(1);
      rect(vr[0], vr[1], vr[2], vr[3], 3);
      noStroke();
      fill(40);
      textAlign(CENTER, CENTER);
      uiText(12);
      text(nf(row.value, 0, 1) + " " + row.unit, vr[0] + vr[2] / 2, vr[1] + vr[3] / 2);
      break;
    }

    case FROW_TOGGLE: {
      fill(60);
      textAlign(LEFT, CENTER);
      uiText(12);
      text(row.label, row.x, row.y + row.h / 2);

      float[] tr = frameToggleRect(row);
      fill(row.on ? color(80, 165, 110) : color(185));
      noStroke();
      rect(tr[0], tr[1], tr[2], tr[3], tr[3] / 2);
      fill(255);
      ellipse(row.on ? tr[0] + tr[2] - tr[3] / 2 : tr[0] + tr[3] / 2,
              tr[1] + tr[3] / 2, tr[3] - 6, tr[3] - 6);
      break;
    }

    case FROW_BUTTON: {
      fill(hoveringFrameRow(row) ? color(95, 130, 175) : color(80, 110, 150));
      noStroke();
      rect(row.x, row.y, row.w, row.h, 4);
      fill(255);
      textAlign(CENTER, CENTER);
      uiText(12);
      text(row.label, row.x + row.w / 2, row.y + row.h / 2);
      break;
    }

    case FROW_SELECT: {
      fill(60);
      textAlign(LEFT, CENTER);
      uiText(12);
      text(row.label, row.x, row.y + row.h / 2);

      float[] lr = frameStepBtnRect(row, false);
      float[] rr = frameStepBtnRect(row, true);
      drawFrameMiniBtn(lr, "◄");
      drawFrameMiniBtn(rr, "►");

      float[] vr = frameValueRect(row);
      fill(255);
      stroke(200);
      strokeWeight(1);
      rect(vr[0], vr[1], vr[2], vr[3], 3);
      noStroke();
      fill(40);
      textAlign(CENTER, CENTER);
      uiText(11);
      text(row.text, vr[0] + vr[2] / 2, vr[1] + vr[3] / 2);
      break;
    }
  }
}

void drawFrameMiniBtn(float[] r, String glyph) {
  boolean hot = mouseX >= r[0] && mouseX <= r[0] + r[2] && mouseY >= r[1] && mouseY <= r[1] + r[3];
  fill(hot ? color(150, 160, 175) : color(120, 130, 145));
  noStroke();
  rect(r[0], r[1], r[2], r[3], 3);
  fill(255);
  textAlign(CENTER, CENTER);
  uiText(12);
  text(glyph, r[0] + r[2] / 2, r[1] + r[3] / 2 - 1);
}

boolean hoveringFrameRow(FrameRow row) {
  return mouseX >= row.x && mouseX <= row.x + row.w
      && mouseY >= row.y && mouseY <= row.y + row.h;
}

// --- Control geometry, shared by drawing and hit-testing -------------------
// The right-hand cluster of every NUM / SELECT row: [-] [ value ] [+]

float[] frameStepBtnRect(FrameRow row, boolean plus) {
  float bw = 24, vw = 86;
  float right = row.x + row.w;
  float by = row.y + (row.h - FROW_STEP_H) / 2;
  float minusX = right - (bw + vw + bw + 8);
  return plus ? new float[]{ right - bw, by, bw, FROW_STEP_H }
              : new float[]{ minusX, by, bw, FROW_STEP_H };
}

float[] frameValueRect(FrameRow row) {
  float bw = 24, vw = 86;
  float right = row.x + row.w;
  float by = row.y + (row.h - FROW_STEP_H) / 2;
  return new float[]{ right - bw - 4 - vw, by, vw, FROW_STEP_H };
}

float[] frameToggleRect(FrameRow row) {
  float tw = 44, th = 20;
  return new float[]{ row.x + row.w - tw, row.y + (row.h - th) / 2, tw, th };
}

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------

boolean hitRect(float[] r) {
  return mouseX >= r[0] && mouseX <= r[0] + r[2] && mouseY >= r[1] && mouseY <= r[1] + r[3];
}

// Returns true when the click was consumed. Called from SidebarPanel.mousePressed().
boolean handleFrameTabClick() {
  if (shapes == null || shapes.isEmpty()) return false;
  ShapeSpec s = shapes.get(constrain(selectedShapeIdx, 0, shapes.size() - 1));
  FrameSpec f = s.frame;

  // Shift coarsens every numeric step, matching the per-edge keyboard controls. Read off
  // mouseEvent, not keyEvent -- keyEvent holds the last KEY press, which during a click is
  // whatever was typed earlier, or null.
  float mult = (mouseEvent != null && mouseEvent.isShiftDown()) ? 10 : 1;

  float vy = sidebar.contentY + 1;
  for (FrameRow row : frameRows()) {
    // A row scrolled up behind the tab bar is drawn nowhere, so it must not be clickable
    // either -- otherwise the tab buttons would sit on top of invisible live controls.
    if (row.y + row.h < vy || row.y > height) continue;
    switch (row.kind) {
      case FROW_NUM: {
        if (hitRect(frameStepBtnRect(row, false))) {
          applyFrameValue(f, row, constrain(row.value - row.step * mult, row.minV, row.maxV));
          return true;
        }
        if (hitRect(frameStepBtnRect(row, true))) {
          applyFrameValue(f, row, constrain(row.value + row.step * mult, row.minV, row.maxV));
          return true;
        }
        break;
      }
      case FROW_TOGGLE: {
        if (hitRect(frameToggleRect(row)) || hoveringFrameRow(row)) {
          applyFrameToggle(f, row);
          return true;
        }
        break;
      }
      case FROW_BUTTON: {
        if (hoveringFrameRow(row)) {
          applyFrameButton(s, f, row);
          return true;
        }
        break;
      }
      case FROW_SELECT: {
        if (hitRect(frameStepBtnRect(row, false))) { applyFrameSelect(f, row, -1); return true; }
        if (hitRect(frameStepBtnRect(row, true)))  { applyFrameSelect(f, row, +1); return true; }
        break;
      }
    }
  }
  // Clicks anywhere else on the tab are swallowed, so they do not fall through to the
  // canvas behind the sidebar.
  return mouseX >= sidebar.x && mouseX <= sidebar.x + sidebar.w && mouseY >= sidebar.contentY;
}

void applyFrameValue(FrameSpec f, FrameRow row, float v) {
  if (row.id.equals("strut_radius"))       f.strutRadius  = v;
  else if (row.id.equals("clearance"))     f.clearanceMM  = v;
  else if (row.id.equals("flap_length"))   f.flapLength   = v;
  else if (row.id.equals("strut_spacing")) f.strutSpacing = v;
  else if (row.id.startsWith("rig_")) {
    Rig r = f.selectedRig();
    if (r != null) {
      r.set(int(row.id.substring(4)), v);
      // Typing dimensions by hand means it is no longer the preset it started as.
      r.preset = RIG_PRESET_NAMES[frameRigPresetIndex(r)];
    }
  }
  redraw();
}

void applyFrameToggle(FrameSpec f, FrameRow row) {
  if (row.id.equals("frame_enabled")) {
    f.enabled = !f.enabled;
    // A frame with nothing in it is just a cage, which is a legitimate thing to want, so
    // enabling does not force a rig. The rig list starts empty and stays that way.
    // Turning one on switches the 3D view to show it; the user can switch straight back.
    if (f.enabled) setView3DStyle(VIEW3D_SCAFFOLD);
  } else if (row.id.equals("dual_struts")) {
    f.dualStruts = !f.dualStruts;
  } else if (row.id.equals("show_frame")) {
    // Same switch as the 3D view's bottom-right buttons: Scaffold, or back to Textured.
    setView3DStyle(scaffoldVisible3D() ? VIEW3D_TEXTURED : VIEW3D_SCAFFOLD);
  }
  redraw();
}

void applyFrameButton(ShapeSpec s, FrameSpec f, FrameRow row) {
  if (row.id.equals("rig_add")) {
    frameAddRig(f);
  } else if (row.id.equals("rig_remove")) {
    frameRemoveRig(f);
  } else if (row.id.equals("frame_export")) {
    exportSingleFrame(s);
  }
  redraw();
}

void applyFrameSelect(FrameSpec f, FrameRow row, int dir) {
  if (row.id.equals("rig_select")) {
    if (f.rigs.isEmpty()) return;
    f.selectedRigIdx = (f.selectedRigIdx + dir + f.rigs.size()) % f.rigs.size();
  } else if (row.id.equals("rig_preset")) {
    Rig r = f.selectedRig();
    if (r == null) return;
    int n = RIG_PRESET_NAMES.length;
    frameApplyRigPreset(f, (frameRigPresetIndex(r) + dir + n) % n);
  } else if (row.id.equals("rig_cut_face")) {
    Rig r = f.selectedRig();
    if (r == null) return;
    int n = RIG_CUT_FACE_NAMES.length;
    r.cutoutFace = (r.cutoutFace + dir + n) % n;
  } else if (row.id.equals("rig_cut_size")) {
    Rig r = f.selectedRig();
    if (r == null) return;
    int n = RIG_CUT_SIZE_NAMES.length;
    r.cutoutSize = (r.cutoutSize + dir + n) % n;
  }
  redraw();
}

// The Frame tab's own export button: writes just this shape's .scad, so a frame can be
// iterated on without regenerating the whole print-and-cut set.
void exportSingleFrame(ShapeSpec s) {
  if (s.frame == null || !s.frame.enabled || !frameAvailable(s)) {
    println("[Scaffold] nothing to export for this shape.");
    return;
  }
  String[] mainLines   = loadStrings(FRAME_TEMPLATE_MAIN);
  String[] helperLines = loadStrings(FRAME_TEMPLATE_HELPER);
  if (mainLines == null || helperLines == null) {
    println("[Scaffold] ERROR: missing OpenSCAD module library in data/. Nothing written.");
    return;
  }
  String baseName = (uiExportFilename != null && !uiExportFilename.trim().isEmpty())
                  ? uiExportFilename : "result";
  String stamp = month()+"_"+day()+"_"+hour()+"_"+minute()+"_"+second();
  int idx = shapes.indexOf(s);
  String path = "output/" + baseName + "_" + stamp + "_frame_" + frameShapeSlug(idx) + ".scad";
  if (writeFrameSCAD(s, idx, path, mainLines, helperLines)) {
    exportNotifyTimer = 240;
    exportNotifyPath  = path;
  }
}
