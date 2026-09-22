// TEXTURES_WRAP.PDE - Drawing the whole-surface wrap
//
// All the maths lives in WrapFrame.pde; this file only turns it into triangles. Three
// consumers, one frame:
//
//   flat pattern + PDF   drawWrapWall() / drawWrapLidsOnPlan()
//   3D preview           drawWrapPrismFaces3D() / drawWrapCap3D()
//
// The wall reuses the existing strip renderers with the rim band selected, so there is one
// implementation of the trapezoid walk rather than two that can drift.

// ---------------------------------------------------------------------------
// Wall
// ---------------------------------------------------------------------------

// The strip renderer counts its rows from the model's BOTTOM edge, so the band is handed
// over descending: row 0 samples the bottom rim, row 1 the top rim.
void drawWrapWall(PGraphics pg) {
  if (!wrapActive()) return;
  drawTriangleStripTexture_Uniform(pg, wrapImg,
                                   wrapImgVFrac(wrapTBottomRim()),
                                   wrapImgVFrac(wrapTTopRim()));
}

void drawWrapWall_Range(PGraphics pg, int panelStart, int panelEnd) {
  if (!wrapActive()) return;
  drawTriangleStripTexture_Uniform_Range(pg, wrapImg, panelStart, panelEnd,
                                         wrapImgVFrac(wrapTBottomRim()),
                                         wrapImgVFrac(wrapTTopRim()));
}

// ---------------------------------------------------------------------------
// Caps, flat pattern
// ---------------------------------------------------------------------------

// One cap's mesh, drawn about the ORIGIN in the lid's own plane. The caller has already
// translated to the lid's centroid and applied the piece's rotation.
//
// printedMirror is the bottom lid. A bottom lid is flipped over when it is folded onto the
// form, so walking its printed rim clockwise walks the assembled model anticlockwise, and s
// has to run backwards to match - a flip is not something a rotation can undo. Which
// printed edge ends up against which wall panel is NOT fixed, and does not need to be: a
// regular n-gon mates in n rotational positions and they are all physically identical, so
// the builder simply turns the lid until the picture lines up. Reversing s per edge, and
// leaving the edge index alone, is therefore both correct and the least arbitrary choice.
void drawWrapCapToPG(PGraphics pg, boolean isTop, boolean printedMirror) {
  if (wrapImg == null || !wrapFrameAvailable()) return;

  final int n = max(3, nSides);
  final int density = max(2, tessellationDensity);   // full density: the radial squeeze bands at low counts
  final float[] sSpan = wrapPanelSpansS();
  final PVector[] V = wrapCapVertsPx(isTop);
  final float tRim  = isTop ? wrapTTopRim() : wrapTBottomRim();
  final float tPole = isTop ? 1.0 : 0.0;

  pg.pushStyle();
  pg.noStroke();
  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);

  pg.beginShape(TRIANGLES);
  pg.texture(wrapImg);

  for (int i = 0; i < n; i++) {
    PVector A = V[i], B = V[(i + 1) % n];
    float sA = printedMirror ? sSpan[i + 1] : sSpan[i];
    float sB = printedMirror ? sSpan[i]     : sSpan[i + 1];

    for (int ring = 0; ring < density; ring++) {
      float r0 = (float) ring / density;          // 0 = centre, 1 = rim
      float r1 = (float) (ring + 1) / density;
      float t0 = lerp(tPole, tRim, r0);
      float t1 = lerp(tPole, tRim, r1);

      for (int arc = 0; arc < density; arc++) {
        float a0 = (float) arc / density;         // along edge i, vertex i -> vertex i+1
        float a1 = (float) (arc + 1) / density;

        // Rim point at each arc fraction, then pulled in to the ring's radius.
        float ex0 = lerp(A.x, B.x, a0), ey0 = lerp(A.y, B.y, a0);
        float ex1 = lerp(A.x, B.x, a1), ey1 = lerp(A.y, B.y, a1);

        float x00 = ex0 * r0, y00 = ey0 * r0;
        float x10 = ex1 * r0, y10 = ey1 * r0;
        float x01 = ex0 * r1, y01 = ey0 * r1;
        float x11 = ex1 * r1, y11 = ey1 * r1;

        float s0 = lerp(sA, sB, a0);
        float s1 = lerp(sA, sB, a1);

        PVector uv00 = wrapUV(s0, t0, wrapImg);
        PVector uv10 = wrapUV(s1, t0, wrapImg);
        PVector uv01 = wrapUV(s0, t1, wrapImg);
        PVector uv11 = wrapUV(s1, t1, wrapImg);

        pg.vertex(x00, y00, uv00.x, uv00.y);
        pg.vertex(x10, y10, uv10.x, uv10.y);
        pg.vertex(x01, y01, uv01.x, uv01.y);

        pg.vertex(x10, y10, uv10.x, uv10.y);
        pg.vertex(x11, y11, uv11.x, uv11.y);
        pg.vertex(x01, y01, uv01.x, uv01.y);
      }
    }
  }

  pg.endShape();
  pg.popStyle();
}

// Places both lid pieces exactly where drawPlan() puts their outlines, then draws the cap
// mesh inside each. Mirrors texturedLidsUniform() - if that placement ever changes, this
// has to change with it.
void drawWrapLidsOnPlan(PGraphics pg) {
  if (!wrapActive() || sidebar == null) return;

  float stripHeight = getStripHeight();
  if (splitStrip && nSides >= 4) {
    float splitSpacingLid = stripHeight + tabDepth_px * 2 + 10 * MM_current;
    stripHeight = splitSpacingLid + stripHeight;
  }
  PVector lidBaseDim = getPolygonLidDimensions(nSides, cellBaseL_px, tabDepth_px);
  PVector lidTopDim  = getPolygonLidDimensions(nSides, cellTopL_px, tabDepth_px);
  float extraLidSpace = max(0, lidTopDim.y - lidBaseDim.y);
  float lidSpacing = max(stripHeight * LID_SPACING_MARGIN,
                         stripHeight + tabDepth_px + extraLidSpace + 2 * MM_current);

  // Bottom lid
  if (sidebar.bottomLidEnabled && canTexture(pg)) {
    PVector c = lidCentroidInPiecePx(false);
    pg.pushMatrix();
    pg.translate((uiLidOffsetX + uiBotLidOffsetX) * MM_current,
                 lidSpacing + (uiLidOffsetY + uiBotLidOffsetY) * MM_current);
    pg.translate(lidBaseDim.x / 2, lidBaseDim.y / 2);
    pg.rotate(radians(uiBotLidRotation));
    pg.translate(-lidBaseDim.x / 2, -lidBaseDim.y / 2);
    pg.translate(c.x, c.y);
    drawWrapCapToPG(pg, false, true);
    pg.popMatrix();
  }

  // Top lid
  if (sidebar.topLidEnabled && canTexture(pg)) {
    PVector c = lidCentroidInPiecePx(true);
    pg.pushMatrix();
    pg.translate((uiLidOffsetX + uiTopLidOffsetX) * MM_current,
                 lidSpacing + (uiLidOffsetY + uiTopLidOffsetY) * MM_current);
    pg.translate(lidBaseDim.x, lidBaseDim.y - lidTopDim.y);
    pg.translate(lidTopDim.x / 2, lidTopDim.y / 2);
    pg.rotate(radians(uiTopLidRotation));
    pg.translate(-lidTopDim.x / 2, -lidTopDim.y / 2);
    pg.translate(c.x, c.y);
    drawWrapCapToPG(pg, true, false);
    pg.popMatrix();
  }
}

// ---------------------------------------------------------------------------
// 3D preview
// ---------------------------------------------------------------------------

// Wall panels. Subdivided rather than emitted as one quad per panel: Processing splits a
// quad into two triangles, and on a frustum's trapezoid that diagonal shows as a crease in
// the artwork.
void drawWrapPrismFaces3D(PGraphics pg, PVector[] topVerts, PVector[] botVerts) {
  if (!wrapActive() || topVerts == null || botVerts == null) return;

  final int n = min(topVerts.length, botVerts.length);
  final int density = max(2, tessellationDensity / 2);
  final float[] sSpan = wrapPanelSpansS();
  final float tBot = wrapTBottomRim(), tTop = wrapTTopRim();

  pg.pushStyle();
  pg.noStroke();
  pg.noTint();
  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);

  pg.beginShape(TRIANGLES);
  pg.texture(wrapImg);

  for (int i = 0; i < n; i++) {
    int next = (i + 1) % n;
    PVector BL = botVerts[i], BR = botVerts[next];
    PVector TL = topVerts[i], TR = topVerts[next];

    for (int row = 0; row < density; row++) {
      float f0 = (float) row / density;           // 0 = bottom rim
      float f1 = (float) (row + 1) / density;
      float t0 = lerp(tBot, tTop, f0);
      float t1 = lerp(tBot, tTop, f1);

      for (int col = 0; col < density; col++) {
        float a0 = (float) col / density;
        float a1 = (float) (col + 1) / density;

        PVector p00 = wrapQuadPoint(BL, BR, TL, TR, a0, f0);
        PVector p10 = wrapQuadPoint(BL, BR, TL, TR, a1, f0);
        PVector p01 = wrapQuadPoint(BL, BR, TL, TR, a0, f1);
        PVector p11 = wrapQuadPoint(BL, BR, TL, TR, a1, f1);

        float s0 = lerp(sSpan[i], sSpan[i + 1], a0);
        float s1 = lerp(sSpan[i], sSpan[i + 1], a1);

        PVector uv00 = wrapUV(s0, t0, wrapImg);
        PVector uv10 = wrapUV(s1, t0, wrapImg);
        PVector uv01 = wrapUV(s0, t1, wrapImg);
        PVector uv11 = wrapUV(s1, t1, wrapImg);

        pg.vertex(p00.x, p00.y, p00.z, uv00.x, uv00.y);
        pg.vertex(p10.x, p10.y, p10.z, uv10.x, uv10.y);
        pg.vertex(p01.x, p01.y, p01.z, uv01.x, uv01.y);

        pg.vertex(p10.x, p10.y, p10.z, uv10.x, uv10.y);
        pg.vertex(p11.x, p11.y, p11.z, uv11.x, uv11.y);
        pg.vertex(p01.x, p01.y, p01.z, uv01.x, uv01.y);
      }
    }
  }

  pg.endShape();
  pg.popStyle();
}

// Bilinear point on a wall panel. a runs left to right, f runs bottom rim to top rim.
PVector wrapQuadPoint(PVector BL, PVector BR, PVector TL, PVector TR, float a, float f) {
  PVector b = PVector.lerp(BL, BR, a);
  PVector t = PVector.lerp(TL, TR, a);
  return PVector.lerp(b, t, f);
}

// One cap in 3D. No mirror here: verts already ARE the assembled polygon, so edge i is wall
// panel i and s runs forwards. The mirror belongs to the printed piece alone.
void drawWrapCap3D(PGraphics pg, PVector[] verts, boolean isTop) {
  if (!wrapActive() || verts == null || verts.length < 3) return;

  final int n = verts.length;
  final int density = max(2, tessellationDensity / 2);
  final float[] sSpan = wrapPanelSpansS();
  final float tRim  = isTop ? wrapTTopRim() : wrapTBottomRim();
  final float tPole = isTop ? 1.0 : 0.0;
  final float y = verts[0].y;

  pg.pushStyle();
  pg.noStroke();
  pg.noTint();
  pg.textureMode(IMAGE);
  pg.textureWrap(CLAMP);
  pg.hint(ENABLE_TEXTURE_MIPMAPS);

  pg.beginShape(TRIANGLES);
  pg.texture(wrapImg);

  for (int i = 0; i < n; i++) {
    PVector A = verts[i], B = verts[(i + 1) % n];

    for (int ring = 0; ring < density; ring++) {
      float r0 = (float) ring / density;
      float r1 = (float) (ring + 1) / density;
      float t0 = lerp(tPole, tRim, r0);
      float t1 = lerp(tPole, tRim, r1);

      for (int arc = 0; arc < density; arc++) {
        float a0 = (float) arc / density;
        float a1 = (float) (arc + 1) / density;

        float ex0 = lerp(A.x, B.x, a0), ez0 = lerp(A.z, B.z, a0);
        float ex1 = lerp(A.x, B.x, a1), ez1 = lerp(A.z, B.z, a1);

        float s0 = lerp(sSpan[i], sSpan[i + 1], a0);
        float s1 = lerp(sSpan[i], sSpan[i + 1], a1);

        PVector uv00 = wrapUV(s0, t0, wrapImg);
        PVector uv10 = wrapUV(s1, t0, wrapImg);
        PVector uv01 = wrapUV(s0, t1, wrapImg);
        PVector uv11 = wrapUV(s1, t1, wrapImg);

        pg.vertex(ex0 * r0, y, ez0 * r0, uv00.x, uv00.y);
        pg.vertex(ex1 * r0, y, ez1 * r0, uv10.x, uv10.y);
        pg.vertex(ex0 * r1, y, ez0 * r1, uv01.x, uv01.y);

        pg.vertex(ex1 * r0, y, ez1 * r0, uv10.x, uv10.y);
        pg.vertex(ex1 * r1, y, ez1 * r1, uv11.x, uv11.y);
        pg.vertex(ex0 * r1, y, ez0 * r1, uv01.x, uv01.y);
      }
    }
  }

  pg.endShape();
  pg.popStyle();
}
