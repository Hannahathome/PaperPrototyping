import controlP5.*;
import processing.pdf.*;
import processing.svg.*;
import processing.core.PFont;
ControlP5 cp5;
PFont myFont;

PGraphicsPDF pdf;
PGraphics svg;
boolean bSavePDF = false;

final float MM = 2.8346; //
final float PRINT_DPI = 72;
final float VINYL_DPI = 96;
final float VINYL_TO_PRINT_RATIO = VINYL_DPI/PRINT_DPI;
final float MM_V = MM*VINYL_TO_PRINT_RATIO;//333333334*1.02;
final float PRINT_W = 297;
final float PRINT_H = 210;
final float VINYL_W = 280;
final float VINYL_H = 200;
float widthA4 = PRINT_W*MM; // mm
float heightA4 = PRINT_H*MM; // mm
float widthA4_V = VINYL_W*MM_V; // mm
float heightA4_V = VINYL_H*MM_V; // mm
float widthA4_C = VINYL_W*MM; // mm
float heightA4_C = VINYL_H*MM; // mm

float offsetMM = 3*MM;
float thickMM = 0.5*MM;
//float voxelW = 30; //MM
//float voxelL = 30;
//float voxelH = 30;

//float voxelW = 60; //MM
//float voxelL = 30;
//float voxelH = 30;

//float voxelW = 60; //MM
//float voxelL = 60;
//float voxelH = 30;

//float voxelW = 30; //MM
//float voxelL = 20;
//float voxelH = 20;

float voxelW = 50; //MM
float voxelL = 50;
float voxelH = 20;

int unitW = 1;
int unitL = 1;
int unitH = 1;
int resW = unitW*unitH+3;
int resH = unitL+2;
float[] xpos = new float[resW+1];
float[] ypos = new float[resH+1];
float voxelLMM = voxelL*MM;
float voxelWMM = voxelW*MM;
float voxelHMM = voxelH*MM;
float paddingX = 15.;
float paddingY = 15.;
float patX = paddingX*MM;
float patY = paddingY*MM;
float patW = voxelWMM*8.*MM;
float patH = voxelWMM*8.*MM;

float patX_V = paddingX*MM_V;
float patY_V = paddingY*MM_V;

final int NORTH = 0;
final int SOUTH = 1;
final int WEST = 2;

Numberbox wNumbox;
Numberbox hNumbox;
Numberbox lNumbox;

String pdfFilename = "output/results.pdf";
String svgFilename = "output/results.svg";
float offsetW = 1.4*MM;
float offsetH = 0*MM;

float offW_V_F = 5*MM_V;
float offH_V_F = 5*MM_V;

boolean isCalib = false;
boolean isSVG = true;

float dash = 3;
float gap = 3;  //space between dashes
float dash_px = dash*MM;
float gap_px = gap*MM;

PImage img;             // Declare variable for the image
int[][] pixelArray;     // 2D integer array to store pixel values
Marker[] m = new Marker[1024];
color ck = color(0);
int Start_Index = 48; //change this
int Marker_Size = 16;
boolean Marker_Pos = false;
Numberbox idNumbox;
int Marker_OffY = 0;
int nRep = 1;

void setup() {
  size(1200, 800, P3D);
  Start_Index = 48; //change this
  Marker_Size = 16;
  initUI();
  initMarkers("aruco1024_px.png");
}

void draw() {
  background(255);
  String timestamp = month()+"_"+day()+"_"+hour()+"_"+minute()+"_"+second();
  float bboxW = xpos[xpos.length-1]-thickMM*2-xpos[0];
  float bbowH = ypos[ypos.length-1]-ypos[0];

  if (bSavePDF) {
    pdfFilename = "output/result_"+timestamp+".pdf";
    pdf = (PGraphicsPDF) createGraphics((int)widthA4, (int)heightA4, PDF, pdfFilename);
    beginRecord(pdf);
  } else {
    background(200);
    pushMatrix();
    fill(255);
    stroke(0);
    rect(0, 0, widthA4, heightA4);
    popMatrix();
  }

  pushMatrix();
  setDimension(voxelW, voxelL, voxelH, false);
  drawCalibCrosses();
  translate(patX, patY);
  for (int i=0; i < nRep; i++) {
    pushMatrix();
    translate((i%2)*bboxW, (i/2)*bbowH);
    stroke(0, 0, 255);
    drawPatternA_BackFold(false);
    stroke(255, 0, 0);
    drawPatternA_FrontFold(false);
    drawPatternA_FrontCut(false, i, Marker_Pos);
    popMatrix();
  }
  popMatrix();

  if (bSavePDF) {
    endRecord();
    println("File saved:", pdfFilename);
    if (isSVG) {
      setDimension(voxelW, voxelL, voxelH, true);
      pushMatrix();
      svgFilename = "output/calib_f_"+timestamp+".svg";
      svg = createGraphics((int)widthA4_V, (int)heightA4_V, SVG, svgFilename);
      beginRecord(svg);
      stroke(0);
      drawAnchors_V();
      translate(offW_V_F, offH_V_F);
      drawCalibCrosses_V();
      endRecord();
      popMatrix();

      pushMatrix();
      svgFilename = "output/res_f_"+timestamp+".svg";
      svg = createGraphics((int)widthA4_V, (int)heightA4_V, SVG, svgFilename);
      beginRecord(svg);
      drawAnchors_V();
      translate(offW_V_F+patX_V, offH_V_F+patY_V);
      stroke(0);
      for (int i=0; i < nRep; i++) {
        pushMatrix();
        translate((i%2)*bboxW, (i/2)*bbowH);
        drawPatternA_FrontFold(true);
        drawPatternA_BackFold(true);
        drawPatternA_FrontCut(true, i, Marker_Pos);
        popMatrix();
      }
      endRecord();
      popMatrix();
    }
    bSavePDF = false;
  }

  hint(DISABLE_DEPTH_TEST);
  cp5.draw();
  hint(ENABLE_DEPTH_TEST);
}


//--RH--//
void drawMarker(int marker_id, int marker_size) {
  float mkr_actualsize = (float)marker_size*(9./7.);
  float gridSize = mkr_actualsize/9.;
  pushMatrix();
  pushStyle();

  pushMatrix();
  rectMode(CORNER);
  fill(255);
  noStroke();
  for (int pi = 0; pi < 9; pi++) {
    for (int pj = 0; pj < 9; pj++) {
      if (pi > 0 && pi < 8 && pj > 0 && pj < 8) {
        if (pi > 1 && pi < 7 && pj > 1 && pj < 7) {
          if (m[marker_id].payload[pi - 2][pj - 2] > 0) {
            fill(255); // White
          } else {
            fill(ck); // Black
          }
        } else {
          fill(ck); // White for cells outside the 4x4 payload
        }
      } else fill(255);
      rect(round(pi * gridSize), round(pj * gridSize), ceil(gridSize), ceil(gridSize));
    }
  }
  popMatrix();
  noStroke();
  noFill();
  rect(0, 0, mkr_actualsize, mkr_actualsize);
  //PImage markerImg = pg2.get();


  //image(markerImg, 0, 0);
  if (marker_id>=0) {
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(ceil(gridSize*1.4));
    text((marker_id), mkr_actualsize/2, 0);//mkr_x+mkr_actualsize/2, mkr_y-(gridSize*MM/2));
  }
  popMatrix();
  popStyle();
  //popMatrix();
}

void initMarkers(String filename) {
  img = loadImage(filename);  // Load the image
  img.loadPixels();      // Load image pixels into the pixel array
  pixelArray = new int[img.width][img.height]; // Initialize 2D array with image dimensions

  m = new Marker[1024];
  for (int i = 0; i < m.length; i++) m[i] = new Marker();
  for (int x = 0; x < img.width; x++) {
    for (int y = 0; y < img.height; y++) {
      color c = img.get(x, y);  // Get color of pixel at (x, y)
      // Check if the pixel is white
      if (red(c) == 255 && green(c) == 255 && blue(c) == 255) {
        pixelArray[x][y] = 1;  // Set the array value to 1 for white pixel
      } else {
        pixelArray[x][y] = 0;  // Set the array value to 0 for non-white pixel
      }
    }
  }
  for (int i=0; i<img.width; i+=8) {
    for (int j=0; j<img.height; j+=8) {
      int index = (i/8)+(j/8)*(img.width/8);
      int[][] payload = new int[5][5];
      for (int x=1; x<6; x+=1) {
        for (int y=1; y<6; y+=1) {
          payload[x-1][y-1] = pixelArray[i+x][j+y];
        }
      }
      m[index].setPayload(payload);
    }
  }
}
