
void initUI() {
  cp5 = new ControlP5(this);
  myFont = createFont("Arial", 144, true);
  textFont(myFont);

  wNumbox=cp5.addNumberbox("voxelW")
    .setPosition(width-150, 10)
    .setSize(40, 20)
    .setColorLabel(color(0))
    .setRange(1, 100)
    .setDecimalPrecision(0)
    .setValue(voxelW);

  lNumbox=cp5.addNumberbox("voxelL")
    .setPosition(width-100, 10)
    .setSize(40, 20)
    .setColorLabel(color(0))
    .setRange(1, 100)
    .setDecimalPrecision(0)
    .setValue(voxelL);

  hNumbox=cp5.addNumberbox("voxelH")
    .setPosition(width-50, 10)
    .setSize(40, 20)
    .setColorLabel(color(0))
    .setRange(1, 100)
    .setDecimalPrecision(0)
    .setValue(voxelH);

  idNumbox = cp5.addNumberbox("marker_id_start")
    .setPosition(width-150, 100)
    .setSize(40, 20)
    .setColorLabel(color(0))
    .setRange(1, 999)
    .setValue((int)48)
    .setDecimalPrecision(0)
    .setLabel("Marker ID");

  cp5.addNumberbox("marker_size")
    .setPosition(width-100, 100)
    .setSize(40, 20)
    .setColorLabel(color(0))
    .setRange(5, 50)
    .setValue(16)
    .setDecimalPrecision(0)
    .setLabel("M_Size");
    
  cp5.addNumberbox("repeat")
    .setPosition(width-50, 100)
    .setSize(40, 20)
    .setColorLabel(color(0))
    .setRange(1, 16)
    .setValue(1)
    .setDecimalPrecision(0)
    .setLabel("M_Repeat");
  
  cp5.addToggle("marker_pos")
    .setPosition(width-150, 150)
    .setSize(50, 20)
    .setLabel("M_Pos")
    .setColorLabel(color(0))
    .setValue(!Marker_Pos);

  cp5.addButton("Export").setPosition(920, 50).setSize(50, 20);

  resetValues();
}

public void resetValues() {
  //Start_Index = 48; //change this
  //Marker_Size = 16;
  cp5.get(Numberbox.class, "voxelW").setValue(voxelW);
  cp5.get(Numberbox.class, "voxelL").setValue(voxelL);
  cp5.get(Numberbox.class, "voxelH").setValue(voxelH);
  cp5.get(Numberbox.class, "marker_size").setValue(Marker_Size);
  cp5.get(Numberbox.class, "marker_id_start").setValue(Start_Index);
  cp5.get(Numberbox.class, "repeat").setValue(nRep);
  cp5.get(Toggle.class, "marker_pos").setValue(!Marker_Pos);
}

void Export() {
  if (!bSavePDF) bSavePDF = true;
}

public void controlEvent(ControlEvent e) {
  // Check if the event came from one of our number boxes
  if (e.isFrom("voxelW") || e.isFrom("voxelL") || e.isFrom("voxelH")) {
    // If so, update the pattern layout.
    // This is far more efficient than doing it in draw().
    set2DPlanParams(unitW, unitL, unitH, false);
  }
  if (e.isFrom("marker_size")){
    Marker_Size = int(e.getValue());
  }
  if (e.isFrom("marker_id_start")){
    Start_Index = int(e.getValue());
  }
  if (e.isFrom("repeat")){
    nRep = int(e.getValue());
  }
  if (e.isFrom("marker_pos")) {
    Marker_Pos = (Marker_Pos? false : true);
  }
}
