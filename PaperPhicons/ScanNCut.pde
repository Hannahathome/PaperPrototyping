
void drawPatternA_FrontFold(boolean cut) {
  float MM_I = (cut? MM_V: MM);
  dash_px = dash*MM_I;
  gap_px = gap*MM_I;

  drawDashedLine(xpos[unitH], ypos[0], xpos[unitH], ypos[ypos.length-1],dash_px, gap_px);
  drawDashedLine(xpos[unitH+unitW], ypos[0], xpos[unitH+unitW], ypos[ypos.length-1],dash_px, gap_px);
  drawDashedLine(xpos[unitH+unitW+unitH], ypos[unitH], xpos[unitH+unitW+unitH], ypos[ypos.length-1-unitH],dash_px, gap_px);
  drawDashedLine(xpos[unitH+unitW+unitH+unitW]-thickMM, ypos[unitH]+thickMM, xpos[unitH+unitW+unitH+unitW]-thickMM, ypos[ypos.length-1-unitH]-thickMM,dash_px, gap_px);
  drawDashedLine(xpos[0], ypos[unitH], xpos[unitH+unitW+unitH], ypos[unitH],dash_px, gap_px);
  drawDashedLine(xpos[unitH+unitW+unitH], ypos[unitH]+thickMM, xpos[xpos.length-1-unitH]-thickMM, ypos[unitH]+thickMM,dash_px, gap_px);
  drawDashedLine(xpos[0], ypos[ypos.length-1-unitH], xpos[unitH+unitW+unitH], ypos[ypos.length-1-unitH],dash_px, gap_px);
  drawDashedLine(xpos[unitH+unitW+unitH], ypos[ypos.length-1-unitH]-thickMM, xpos[xpos.length-1-unitH]-thickMM, ypos[ypos.length-1-unitH]-thickMM,dash_px, gap_px);
  
  //line(xpos[unitH], ypos[0], xpos[unitH], ypos[ypos.length-1]);// |
  //line(xpos[unitH+unitW], ypos[0], xpos[unitH+unitW], ypos[ypos.length-1]); // |
  //line(xpos[unitH+unitW+unitH], ypos[unitH], xpos[unitH+unitW+unitH], ypos[ypos.length-1-unitH]); // short |
  //line(xpos[unitH+unitW+unitH+unitW]-thickMM, ypos[unitH]+thickMM, xpos[unitH+unitW+unitH+unitW]-thickMM, ypos[ypos.length-1-unitH]-thickMM); // short |
  //line(xpos[0], ypos[unitH], xpos[unitH+unitW+unitH], ypos[unitH]); //--
  //line(xpos[unitH+unitW+unitH], ypos[unitH]+thickMM, xpos[xpos.length-1-unitH]-thickMM, ypos[unitH]+thickMM); //--
  //line(xpos[0], ypos[ypos.length-1-unitH], xpos[unitH+unitW+unitH], ypos[ypos.length-1-unitH]); //--
  //line(xpos[unitH+unitW+unitH], ypos[ypos.length-1-unitH]-thickMM, xpos[xpos.length-1-unitH]-thickMM, ypos[ypos.length-1-unitH]-thickMM); //--
}

void drawPatternA_BackFold(boolean cut) { 
  float MM_I = (cut? MM_V: MM);
  dash_px = dash*MM_I;
  gap_px = gap*MM_I;
  
  drawDashedLine(xpos[0], ypos[0], xpos[unitH], ypos[unitH],dash_px, gap_px);
  drawDashedLine(xpos[2*unitH+unitW], ypos[0], xpos[1*unitH+unitW], ypos[unitH],dash_px, gap_px);
  drawDashedLine(xpos[0], ypos[ypos.length-1], xpos[unitH], ypos[ypos.length-1-unitH],dash_px, gap_px);
  drawDashedLine(xpos[2*unitH+unitW], ypos[ypos.length-1], xpos[1*unitH+unitW], ypos[ypos.length-1-unitH],dash_px, gap_px);
  
  //line(xpos[0], ypos[0], xpos[unitH], ypos[unitH]);
  //line(xpos[2*unitH+unitW], ypos[0], xpos[1*unitH+unitW], ypos[unitH]);
  //line(xpos[0], ypos[ypos.length-1], xpos[unitH], ypos[ypos.length-1-unitH]);
  //line(xpos[2*unitH+unitW], ypos[ypos.length-1], xpos[1*unitH+unitW], ypos[ypos.length-1-unitH]);
}

void drawPatternA_FrontCut(boolean cut, int i, boolean m_pos) {
  float MM_I = (cut? MM_V: MM);
  offsetMM = 3*MM_I;
  thickMM = 0.5*MM_I;

  line(xpos[0], ypos[0], xpos[0], ypos[ypos.length-1]);
  line(xpos[xpos.length-1]-thickMM*2, ypos[unitH]+offsetMM+thickMM, xpos[xpos.length-1]-thickMM*2, ypos[unitH+unitL]-offsetMM-thickMM);

  line(xpos[0], ypos[0], xpos[unitH+unitW+unitH], ypos[0]);
  line(xpos[unitH+unitW+unitH]+offsetMM, ypos[0]+thickMM, xpos[unitH+unitW+unitH+unitW]-offsetMM-thickMM, ypos[0]+thickMM);

  line(xpos[0], ypos[ypos.length-1], xpos[unitH+unitW+unitH], ypos[ypos.length-1]);
  line(xpos[unitH+unitW+unitH]+offsetMM, ypos[ypos.length-1]-thickMM, xpos[unitH+unitW+unitH+unitW]-offsetMM-thickMM, ypos[ypos.length-1]-thickMM);

  line(xpos[xpos.length-1-unitH-unitW], ypos[0], xpos[xpos.length-1-unitH-unitW], ypos[unitH]+thickMM);
  line(xpos[xpos.length-1-unitH-unitW], ypos[ypos.length-1-unitH]-thickMM, xpos[xpos.length-1-unitH-unitW], ypos[ypos.length-1]);

  line(xpos[xpos.length-1-unitH]-offsetMM-thickMM, ypos[0]+thickMM, xpos[xpos.length-1-unitH]-thickMM, ypos[unitH]+thickMM);
  line(xpos[xpos.length-1-unitH]-offsetMM-thickMM, ypos[ypos.length-1]-thickMM, xpos[xpos.length-1-unitH]-thickMM, ypos[ypos.length-1-unitH]-thickMM);

  line(xpos[xpos.length-1-unitH]-thickMM, ypos[unitH]+thickMM, xpos[xpos.length-1]-thickMM*2, ypos[unitH]+offsetMM+thickMM);
  line(xpos[xpos.length-1-unitH]-thickMM, ypos[ypos.length-1-unitH]-thickMM, xpos[xpos.length-1]-thickMM*2, ypos[ypos.length-1-unitH]-offsetMM-thickMM);

  line(xpos[2*unitH+unitW]+offsetMM, ypos[0]+thickMM, xpos[2*unitH+unitW], ypos[unitH]+thickMM);
  line(xpos[2*unitH+unitW]+offsetMM, ypos[ypos.length-1]-thickMM, xpos[2*unitH+unitW], ypos[ypos.length-1-unitH]-thickMM);
  
  if(!cut){
    pushMatrix();
    float centerX = (xpos[unitH]+xpos[unitH+unitW])/2.;
    if(m_pos==true) centerX = (xpos[unitH+unitW+unitH]+xpos[unitH+unitW])/2.;
    float centerY = (ypos[unitH]+ypos[ypos.length-1-unitH])/2.;
    float mkr_size = ((float)Marker_Size*MM);
    float mkr_actualsize = mkr_size*(9./7.);
    PVector markerLoc = new PVector(centerX-mkr_actualsize/2, centerY-mkr_actualsize/2);
    translate(markerLoc.x, markerLoc.y+Marker_OffY*MM_I);
    drawMarker(Start_Index+i, (int)mkr_size);
    popMatrix();
  }
}
