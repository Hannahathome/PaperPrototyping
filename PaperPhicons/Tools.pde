void drawDashedLine(float x1, float y1, float x2, float y2, float dashLength, float gapLength) {
  float totalLength = dist(x1, y1, x2, y2);

  // If the total line is too short to fit even the two end gaps, do nothing
  if (totalLength <= 2 * gapLength) {
    return;
  }

  // Calculate the direction of the line
  float dx = (x2 - x1) / totalLength;
  float dy = (y2 - y1) / totalLength;

  //pushStyle();
  //stroke(0);

  //sstart the drawing position after the first gap.
  float currentPos = gapLength;

  // The loop should stop before the drawing position enters the final gap area
  while (currentPos < totalLength - gapLength) {
    float startX = x1 + dx * currentPos;
    float startY = y1 + dy * currentPos;

    // determine the end of the current dash, ensuring it doesn't go past the final gap
    float endPos = min(currentPos + dashLength, totalLength - gapLength);
    float endX = x1 + dx * endPos;
    float endY = y1 + dy * endPos;

    line(startX, startY, endX, endY);

    // Move the current position forward by the length of a dash and a gap
    currentPos += dashLength + gapLength;
  }
  //popStyle();
}

void drawCalibCrosses() {
  line(10*MM, 5*MM, 10*MM, 15*MM);
  line(5*MM, 10*MM, 15*MM, 10*MM);
  line(widthA4_C-10*MM, 5*MM, widthA4_C-10*MM, 15*MM);
  line(widthA4_C-5*MM, 10*MM, widthA4_C-15*MM, 10*MM);
  line(10*MM, heightA4_C-5*MM, 10*MM, heightA4_C-15*MM);
  line(5*MM, heightA4_C-10*MM, 15*MM, heightA4_C-10*MM);
  line(widthA4_C-10*MM, heightA4_C-5*MM, widthA4_C-10*MM, heightA4_C-15*MM);
  line(widthA4_C-5*MM, heightA4_C-10*MM, widthA4_C-15*MM, heightA4_C-10*MM);
}

void drawCalibCrosses_V() {
  line(10*MM_V, 5*MM_V, 10*MM_V, 15*MM_V);
  line(5*MM_V, 10*MM_V, 15*MM_V, 10*MM_V);
  line(widthA4_V-10*MM_V, 5*MM_V, widthA4_V-10*MM_V, 15*MM_V);
  line(widthA4_V-5*MM_V, 10*MM_V, widthA4_V-15*MM_V, 10*MM_V);
  line(10*MM_V, heightA4_V-5*MM_V, 10*MM_V, heightA4_V-15*MM_V);
  line(5*MM_V, heightA4_V-10*MM_V, 15*MM_V, heightA4_V-10*MM_V);
  line(widthA4_V-10*MM_V, heightA4_V-5*MM_V, widthA4_V-10*MM_V, heightA4_V-15*MM_V);
  line(widthA4_V-5*MM_V, heightA4_V-10*MM_V, widthA4_V-15*MM_V, heightA4_V-10*MM_V);
}

void drawAnchors_V() {
  point(0, 0);
  point(widthA4_V, 0);
  point(0, heightA4_V);
  point(widthA4_V, heightA4_V);
}

void setDimension(float w, float l, float h, boolean cut) {
  voxelW = w;
  voxelL = l;
  voxelH = h;
  //resetValues();
  set2DPlanParams(cut);
}


void set2DPlanParams(boolean cut) {
  set2DPlanParams(1, 1, 1, cut);
}

void set2DPlanParams(int unitW, int unitL, int unitH, boolean cut) {
  
  float MM_I = (cut? MM_V: MM);
  resW = (unitW*2)+(unitH*3);
  resH = unitL+unitH*2;
  xpos = new float[resW+1];
  ypos = new float[resH+1];

  voxelWMM = voxelW*MM_I;
  voxelLMM = voxelL*MM_I;
  voxelHMM = voxelH*MM_I;

  patW = (unitW*2)*voxelWMM + (unitH*3)*voxelHMM;
  patH = unitL*voxelLMM + (unitH*2)*voxelHMM;

  xpos[0] = 0;
  ypos[0] = 0;

  for (int r = 1; r < 1+unitH; r++) xpos[r] = xpos[r-1] + voxelHMM;
  for (int r = 1+1*unitH+0*unitW; r < 1+1*unitH+1*unitW; r++) xpos[r] = xpos[r-1] + voxelWMM;
  for (int r = 1+1*unitH+1*unitW; r < 1+2*unitH+1*unitW; r++) xpos[r] = xpos[r-1] + voxelHMM;
  for (int r = 1+2*unitH+1*unitW; r < 1+2*unitH+2*unitW; r++) xpos[r] += xpos[r-1] + voxelWMM;
  for (int r = 1+2*unitH+2*unitW; r < 1+3*unitH+2*unitW; r++) xpos[r] += xpos[r-1] + voxelHMM;

  for (int c = 1; c < 1+unitH; c++) ypos[c] = ypos[c-1] + voxelHMM;
  for (int c = 1+unitH; c < 1+unitH+unitL; c++) ypos[c] = ypos[c-1] + voxelLMM;
  for (int c = 1+unitH+unitL; c < 1+unitL+2*unitH; c++) ypos[c] = ypos[c-1] + voxelHMM;
}
