////----------------------------------------------------------------------
//// EdgeProfile class for per-edge mode (variable prisms)
//// Manages individual edge lengths for non-uniform polygonal prisms
////--------------------------------------------------------------

boolean perEdgeMode = false;         // set true to activate per-edge mode
EdgeProfile edgesTop;
EdgeProfile edgesBottom;

class EdgeProfile {
  final int minSides = MIN_SIDES;  // defined in Param.pde
  int n;
  float[] mm;      // per-edge lengths (mm)
  float mmToPx = 1.0;

  EdgeProfile(int nSides, float defaultMm, float mmToPxScale) {
    n = max(minSides, nSides);
    mmToPx = mmToPxScale;
    mm = new float[n];
    setAll(defaultMm);
  }

  void resize(int newNSides, float fillMm) {
    newNSides = max(minSides, newNSides);
    if (newNSides == n) return;
    float[] next = new float[newNSides];
    int copy = min(n, newNSides);
    arrayCopy(mm, next, copy);
    for (int i = copy; i < newNSides; i++) next[i] = max(0.001f, fillMm);
    mm = next;
    n = newNSides;
  }

  void setAll(float vMm) {
    vMm = max(0.001f, vMm);
    for (int i = 0; i < n; i++) mm[i] = vMm;
  }

  void set(int i, float vMm) {
    if (n == 0) return;
    i = ((i % n) + n) % n;
    mm[i] = max(0.001f, vMm);
  }

  float getMm(int i) {
    if (n == 0) return 0;
    i = ((i % n) + n) % n;
    return mm[i];
  }

  float getPx(int i) {
    return getMm(i) * mmToPx;
  }

  float perimeterMm() {
    float s = 0;
    for (int i = 0; i < n; i++) s += mm[i];
    return s;
  }

  void normalizeToPerimeter(float targetPerimMm) {
    targetPerimMm = max(0.001f, targetPerimMm);
    float cur = perimeterMm();
    if (cur <= 0) return;
    float k = targetPerimMm / cur;
    for (int i = 0; i < n; i++) mm[i] = max(0.001f, mm[i] * k); // preserve proportions
  }
}

//  Init
void initEdgeProfilesIfNeeded() {
  // === DIAMETER NAAR ZIJDE-LENGTE CONVERSIE ===
  // uiTopW/uiBotW zijn circumscribed DIAMETER van de UI sliders
  // EdgeProfile arrays werken met individuele ZIJDE-LENGTES
  // Conversie: zijde = diameter × sin(π/n)
  float topSideLen = max(1, uiTopW * sin(PI / max(3, nSides)));
  float botSideLen = max(1, uiBotW * sin(PI / max(3, nSides)));
  if (edgesTop == null) edgesTop = new EdgeProfile(max(3, nSides), topSideLen, MM);
  if (edgesBottom == null) edgesBottom = new EdgeProfile(max(3, nSides), botSideLen, MM);
  edgesTop.mmToPx = MM;
  edgesBottom.mmToPx = MM;
  edgesTop.resize(max(3, nSides), topSideLen);
  edgesBottom.resize(max(3, nSides), botSideLen);
}

// Keep arrays consistent with current perimeters (source = cylinder.x/y in mm)
void syncEdgesFromPerimeters() {
  initEdgeProfilesIfNeeded();
  float uniTop = max(1, cylinder.x / max(MIN_SIDES, nSides));
  float uniBot = max(1, cylinder.y / max(MIN_SIDES, nSides));
  if (cuboidMode && nSides == 4) {
    // Cuboid mode: set edges to alternating Length/Width
    edgesTop.set(0, uiCubTopLen);
    edgesTop.set(1, uiCubTopWid);
    edgesTop.set(2, uiCubTopLen);
    edgesTop.set(3, uiCubTopWid);
    edgesBottom.set(0, uiCubBotLen);
    edgesBottom.set(1, uiCubBotWid);
    edgesBottom.set(2, uiCubBotLen);
    edgesBottom.set(3, uiCubBotWid);
  } else if (!perEdgeMode) {           // uniform mode -> make arrays equal
    edgesTop.setAll(uniTop);
    edgesBottom.setAll(uniBot);
  } else {
    // per-edge: don't force; normalize if perimeter-lock is active
    if (uiPerimLock) {
      edgesTop.normalizeToPerimeter(max(1, uiPerim));
      if (uiLock) {
        for (int i = 0; i < nSides; i++) edgesBottom.set(i, edgesTop.getMm(i));
      }
    }
  }
}

//(mm/px) tools
float edgeTopMm(int i) {
  initEdgeProfilesIfNeeded();
  return edgesTop.getMm(i);
}
float edgeBottomMm(int i) {
  initEdgeProfilesIfNeeded();
  return edgesBottom.getMm(i);
}
float edgeTopPx(int i) {
  initEdgeProfilesIfNeeded();
  return edgesTop.getPx(i);
}
float edgeBottomPx(int i) {
  initEdgeProfilesIfNeeded();
  return edgesBottom.getPx(i);
}
float topPerimeterMm() {
  initEdgeProfilesIfNeeded();
  return edgesTop.perimeterMm();
}
float bottomPerimeterMm() {
  initEdgeProfilesIfNeeded();
  return edgesBottom.perimeterMm();
}

void setEdgeTopAtIndex(int i, float vMm) {
  initEdgeProfilesIfNeeded();
  edgesTop.set(i, vMm);
  cylinder.x = edgesTop.perimeterMm();
}
void setEdgeBottomAtIndex(int i, float vMm) {
  initEdgeProfilesIfNeeded();
  edgesBottom.set(i, vMm);
  cylinder.y = edgesBottom.perimeterMm();
}
void setAllTop(float vMm) {
  initEdgeProfilesIfNeeded();
  edgesTop.setAll(vMm);
  cylinder.x = edgesTop.perimeterMm();
}
void setAllBottom(float vMm) {
  initEdgeProfilesIfNeeded();
  edgesBottom.setAll(vMm);
  cylinder.y = edgesBottom.perimeterMm();
}
