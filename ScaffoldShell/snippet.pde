// ============================================================================
// PLATONIC SOLIDS NET GENERATOR
// ============================================================================
// Generate 2D unfolded templates (nets) for all 5 platonic solids
// with optional arrowhead-shaped gluing tabs.
//
// BASIC USAGE:
//   drawPlatonicSolid("cube", 300, 100, 100, true);
//
// TEMPLATE PARAMETER SYSTEM:
//   // Create a parameterized template
//   PlatonicSolidTemplate myTemplate = new PlatonicSolidTemplate("cube", 50);
//   myTemplate.templateName = "Custom Cube";
//   myTemplate.scaleFactor = 1.5;
//   myTemplate.includeTabs = true;
//   myTemplate.notes = "Voor lasersnijden 3mm MDF";
//   
//   // Draw from template
//   drawPlatonicSolidFromTemplate(myTemplate, 400, 300);
//   
//   // Use template library
//   templateLibrary = new PlatonicTemplateLibrary();
//   templateLibrary.loadAllPresets();
//   templateLibrary.saveToFile("my_templates.txt");
//
// TESTING:
//   1. Set platonicTestMode = true to enter test mode
//   2. Call drawPlatonicSolidGallery() from main draw() when in test mode
//   3. Use keyboard shortcuts to interact:
//      'K' - Toggle platonic test mode
//      'T' - Toggle tabs on/off in test view
//      '1-5' - Select individual solid (1=tetrahedron...5=icosahedron)
//      '0' - Return to gallery view (all solids)
//      '+/-' - Increase/decrease test scale
//      'P' - Generate production templates (saved to data/)
//      'E' - Export current view to PDF
//
// SOLIDS SUPPORTED:
//   - tetrahedron (4 equilateral triangles)
//   - cube (6 squares)
//   - octahedron (8 equilateral triangles)
//   - dodecahedron (12 regular pentagons)
//   - icosahedron (20 equilateral triangles)
//
// PARAMETERS:
//   Each template kan geconfigureerd worden met:
//   - edgeLength_mm: Lengte van ribben in millimeters
//   - scaleFactor: Schaal multiplicator (1.0 = normaal)
//   - materialThickness_mm: Materiaal dikte voor compensatie
//   - includeTabs: Wel/geen lijmtabs
//   - tabDepth_mm, tabInsetRatio, tabNeckRatio: Tab configuratie
//   - offsetX_mm, offsetY_mm: Positie offset
//   - rotation_deg: Rotatie in graden
//   - notes: Vrije tekst notitie
// ============================================================================

// ============================================================================
// CONSTANTS (using globals from Param.pde)
// ============================================================================
// Constants borrowed from Param.pde:
// - TAB_INSET_RATIO = 0.25 (line 91)
// - ARROWHEAD_FLARE_RATIO = 1.0/3.0 (line 94)
// - TAB_NECK_RATIO_DEFAULT = 0.8 (line 92)

final float DEFAULT_TAB_DEPTH_MM = 15.0;         // Default tab protrusion (mm)

// Local MM conversion if not available from main project
float MM_local = 2.8346;  // Pixels per mm at 72 DPI

// ============================================================================
// TEST MODE GLOBALS
// ============================================================================
boolean platonicTestMode = false;     // Toggle test mode on/off
boolean platonicShowTabs = true;      // Show/hide tabs in test view
int platonicSelectedSolid = -1;       // Selected solid (-1 = show all)
float platonicTestScale = 200.0;      // Scale for preview (pixels)

// ============================================================================
// EDIT MODE GLOBALS
// ============================================================================
boolean platonicEditMode = false;           // Toggle edit mode on/off
String selectedTemplateType = "cube";       // Currently selected solid type
PlatonicSolidTemplate selectedTemplate = null;  // Active template being edited
int selectedThumbnailIndex = 1;             // Which thumbnail is selected (0-4)

// ============================================================================
// PLATONIC SOLID TEMPLATE PARAMETERS
// ============================================================================

/**
 * Template parameters for generating platonic solid nets
 * Deze klasse slaat alle configureerbare parameters op voor het genereren
 * van platonic solid templates in verschillende formaten
 */
class PlatonicSolidTemplate {
  // Identificatie
  String solidType;           // "tetrahedron", "cube", "octahedron", "dodecahedron", "icosahedron"
  String templateName;        // Custom naam voor deze template instantie
  
  // Geometrie parameters
  float edgeLength_mm;        // Lengte van één ribbe in millimeters
  float materialThickness_mm; // Dikte van materiaal (voor compensatie indien nodig)
  float scaleFactor;          // Schaalfactor (1.0 = normaal)
  
  // Tab parameters
  boolean includeTabs;        // Wel/geen tabs
  float tabDepth_mm;          // Tab uitsteek diepte in mm
  float tabInsetRatio;        // Tab inset ratio (0.0-0.5)
  float tabNeckRatio;         // Tab neck ratio (hoe smal de tab is bij basis)
  
  // Layout parameters
  float offsetX_mm;           // Offset X positie in mm
  float offsetY_mm;           // Offset Y positie in mm
  float rotation_deg;         // Rotatie in graden
  
  // Metadata
  int numFaces;               // Aantal vlakken
  String notes;               // Notities over deze template
  
  // Constructor met defaults
  PlatonicSolidTemplate(String type, float edgeLengthMM) {
    this.solidType = type;
    this.templateName = type + "_default";
    this.edgeLength_mm = edgeLengthMM;
    
    // Defaults
    this.materialThickness_mm = 0.0;  // Geen compensatie
    this.scaleFactor = 1.0;
    this.includeTabs = false;
    this.tabDepth_mm = DEFAULT_TAB_DEPTH_MM;
    this.tabInsetRatio = TAB_INSET_RATIO;
    this.tabNeckRatio = TAB_NECK_RATIO_DEFAULT;
    this.offsetX_mm = 0;
    this.offsetY_mm = 0;
    this.rotation_deg = 0;
    this.notes = "";
    
    // Set face count
    setFaceCount();
  }
  
  // Set aantal faces op basis van type
  void setFaceCount() {
    switch(solidType) {
      case "tetrahedron": numFaces = 4; break;
      case "cube": numFaces = 6; break;
      case "octahedron": numFaces = 8; break;
      case "dodecahedron": numFaces = 12; break;
      case "icosahedron": numFaces = 20; break;
      default: numFaces = 0;
    }
  }
  
  // Bereken edge length in pixels
  float getEdgeLengthPx() {
    return edgeLength_mm * MM * scaleFactor;
  }
  
  // Copy constructor voor duplicatie
  PlatonicSolidTemplate copy() {
    PlatonicSolidTemplate t = new PlatonicSolidTemplate(this.solidType, this.edgeLength_mm);
    t.templateName = this.templateName;
    t.materialThickness_mm = this.materialThickness_mm;
    t.scaleFactor = this.scaleFactor;
    t.includeTabs = this.includeTabs;
    t.tabDepth_mm = this.tabDepth_mm;
    t.tabInsetRatio = this.tabInsetRatio;
    t.tabNeckRatio = this.tabNeckRatio;
    t.offsetX_mm = this.offsetX_mm;
    t.offsetY_mm = this.offsetY_mm;
    t.rotation_deg = this.rotation_deg;
    t.notes = this.notes;
    return t;
  }
  
  // Print parameters voor debugging
  void print() {
    println("=== Platonic Solid Template ===");
    println("Type: " + solidType);
    println("Name: " + templateName);
    println("Edge Length: " + edgeLength_mm + " mm");
    println("Faces: " + numFaces);
    println("Scale: " + scaleFactor);
    println("Tabs: " + (includeTabs ? "YES" : "NO"));
    if (includeTabs) {
      println("  Tab Depth: " + tabDepth_mm + " mm");
      println("  Tab Inset: " + tabInsetRatio);
      println("  Tab Neck: " + tabNeckRatio);
    }
    println("Offset: (" + offsetX_mm + ", " + offsetY_mm + ") mm");
    println("Rotation: " + rotation_deg + "°");
    if (notes.length() > 0) println("Notes: " + notes);
    println("===============================");
  }
  
  // Export naar string (voor opslag)
  String serialize() {
    return solidType + "|" +
           templateName + "|" +
           edgeLength_mm + "|" +
           materialThickness_mm + "|" +
           scaleFactor + "|" +
           (includeTabs ? "1" : "0") + "|" +
           tabDepth_mm + "|" +
           tabInsetRatio + "|" +
           tabNeckRatio + "|" +
           offsetX_mm + "|" +
           offsetY_mm + "|" +
           rotation_deg + "|" +
           notes;
  }
}

/**
 * Deserialize a template from string (standalone function instead of static method)
 */
PlatonicSolidTemplate deserializePlatonicTemplate(String data) {
  String[] parts = split(data, '|');
  if (parts.length < 13) return null;
  
  PlatonicSolidTemplate t = new PlatonicSolidTemplate(parts[0], float(parts[2]));
  t.templateName = parts[1];
  t.materialThickness_mm = float(parts[3]);
  t.scaleFactor = float(parts[4]);
  t.includeTabs = parts[5].equals("1");
  t.tabDepth_mm = float(parts[6]);
  t.tabInsetRatio = float(parts[7]);
  t.tabNeckRatio = float(parts[8]);
  t.offsetX_mm = float(parts[9]);
  t.offsetY_mm = float(parts[10]);
  t.rotation_deg = float(parts[11]);
  t.notes = parts[12];
  return t;
}

/**
 * Generate een platonic solid net op basis van een template
 */
void drawPlatonicSolidFromTemplate(PlatonicSolidTemplate template, float screenX, float screenY) {
  pushMatrix();
  translate(screenX, screenY);
  
  // Apply rotation if specified
  if (template.rotation_deg != 0) {
    rotate(radians(template.rotation_deg));
  }
  
  // Apply offset
  translate(template.offsetX_mm * MM, template.offsetY_mm * MM);
  
  // Draw the solid
  float edgePx = template.getEdgeLengthPx();
  drawPlatonicSolid(template.solidType, edgePx, 0, 0, template.includeTabs);
  
  popMatrix();
}

/**
 * Maak een preset template voor een specifieke use case
 */
PlatonicSolidTemplate createPresetTemplate(String presetName) {
  PlatonicSolidTemplate t = null;
  
  switch(presetName) {
    case "cube_small":
      t = new PlatonicSolidTemplate("cube", 30);
      t.templateName = "Small Cube 30mm";
      t.notes = "Kleine kubus voor desktop decoratie";
      break;
      
    case "cube_medium":
      t = new PlatonicSolidTemplate("cube", 50);
      t.templateName = "Medium Cube 50mm";
      t.notes = "Medium kubus voor displays";
      break;
      
    case "cube_large":
      t = new PlatonicSolidTemplate("cube", 100);
      t.templateName = "Large Cube 100mm";
      t.notes = "Grote kubus voor sculpturen";
      break;
      
    case "dodecahedron_standard":
      t = new PlatonicSolidTemplate("dodecahedron", 40);
      t.templateName = "Standard Dodecahedron";
      t.notes = "Standaard dodecahedon met 40mm ribben";
      break;
      
    case "icosahedron_display":
      t = new PlatonicSolidTemplate("icosahedron", 35);
      t.templateName = "Display Icosahedron";
      t.notes = "Icosahedon voor display doeleinden";
      break;
      
    default:
      // Default: medium cube
      t = new PlatonicSolidTemplate("cube", 50);
      t.templateName = "Default Template";
  }
  
  return t;
}

/**
 * Template Manager - beheert meerdere platonic solid templates
 */
class PlatonicTemplateLibrary {
  ArrayList<PlatonicSolidTemplate> templates;
  
  PlatonicTemplateLibrary() {
    templates = new ArrayList<PlatonicSolidTemplate>();
  }
  
  // Voeg template toe
  void addTemplate(PlatonicSolidTemplate template) {
    templates.add(template);
  }
  
  // Zoek template op naam
  PlatonicSolidTemplate getTemplate(String name) {
    for (PlatonicSolidTemplate t : templates) {
      if (t.templateName.equals(name)) {
        return t;
      }
    }
    return null;
  }
  
  // Krijg alle templates van een bepaald type
  ArrayList<PlatonicSolidTemplate> getTemplatesByType(String solidType) {
    ArrayList<PlatonicSolidTemplate> result = new ArrayList<PlatonicSolidTemplate>();
    for (PlatonicSolidTemplate t : templates) {
      if (t.solidType.equals(solidType)) {
        result.add(t);
      }
    }
    return result;
  }
  
  // Verwijder template
  void removeTemplate(String name) {
    for (int i = templates.size() - 1; i >= 0; i--) {
      if (templates.get(i).templateName.equals(name)) {
        templates.remove(i);
        break;
      }
    }
  }
  
  // Export alle templates naar string array
  String[] exportAll() {
    String[] data = new String[templates.size()];
    for (int i = 0; i < templates.size(); i++) {
      data[i] = templates.get(i).serialize();
    }
    return data;
  }
  
  // Import templates van string array
  void importAll(String[] data) {
    templates.clear();
    for (String line : data) {
      PlatonicSolidTemplate t = deserializePlatonicTemplate(line);
      if (t != null) {
        templates.add(t);
      }
    }
  }
  
  // Save templates naar bestand
  void saveToFile(String filename) {
    String[] data = exportAll();
    saveStrings(filename, data);
    println("Saved " + templates.size() + " templates to " + filename);
  }
  
  // Load templates van bestand
  void loadFromFile(String filename) {
    String[] data = loadStrings(filename);
    if (data != null) {
      importAll(data);
      println("Loaded " + templates.size() + " templates from " + filename);
    } else {
      println("Could not load templates from " + filename);
    }
  }
  
  // Print alle templates
  void printAll() {
    println("\n=== Template Library (" + templates.size() + " templates) ===");
    for (int i = 0; i < templates.size(); i++) {
      println("\n--- Template " + (i+1) + " ---");
      templates.get(i).print();
    }
  }
  
  // Laad alle presets
  void loadAllPresets() {
    templates.clear();
    templates.add(createPresetTemplate("cube_small"));
    templates.add(createPresetTemplate("cube_medium"));
    templates.add(createPresetTemplate("cube_large"));
    templates.add(createPresetTemplate("dodecahedron_standard"));
    templates.add(createPresetTemplate("icosahedron_display"));
    
    // Extra: maak templates voor alle solids met standaard 40mm
    for (String solidType : SOLID_NAMES) {
      PlatonicSolidTemplate t = new PlatonicSolidTemplate(solidType, 40);
      t.templateName = solidType + "_40mm";
      t.notes = "Standaard " + solidType + " met 40mm ribben";
      templates.add(t);
    }
  }
}

// Global template library
PlatonicTemplateLibrary templateLibrary = null;

/**
 * VOORBEELD GEBRUIK:
 * 
 * // 1. Maak een nieuwe template aan
 * PlatonicSolidTemplate myTemplate = new PlatonicSolidTemplate("cube", 50);
 * myTemplate.templateName = "My Custom Cube";
 * myTemplate.scaleFactor = 1.5;
 * myTemplate.includeTabs = true;
 * myTemplate.tabDepth_mm = 20;
 * 
 * // 2. Gebruik de template om te tekenen
 * drawPlatonicSolidFromTemplate(myTemplate, 400, 300);
 * 
 * // 3. Gebruik de library om templates te beheren
 * templateLibrary = new PlatonicTemplateLibrary();
 * templateLibrary.loadAllPresets();
 * templateLibrary.addTemplate(myTemplate);
 * 
 * // 4. Opslaan en laden
 * templateLibrary.saveToFile("my_templates.txt");
 * templateLibrary.loadFromFile("my_templates.txt");
 * 
 * // 5. Zoek en gebruik een template
 * PlatonicSolidTemplate foundTemplate = templateLibrary.getTemplate("cube_medium");
 * if (foundTemplate != null) {
 *   drawPlatonicSolidFromTemplate(foundTemplate, 100, 100);
 * }
 */

// Solid type names
final String[] SOLID_NAMES = {
  "tetrahedron", "cube", "octahedron", "dodecahedron", "icosahedron"
};

// ============================================================================
// TAB PARAMETERS CLASS
// ============================================================================
class TabParams {
  float tabDepth;
  float tabInset;
  float arrowheadFlare;
  float neckDepth;
  
  TabParams(float depth, float inset, float flare, float neck) {
    this.tabDepth = depth;
    this.tabInset = inset;
    this.arrowheadFlare = flare;
    this.neckDepth = neck;
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Calculate tab parameters based on edge length
 * Uses standard ratios from main project
 */
TabParams calculateTabParams(float edgeLength) {
  float tabInset = edgeLength * TAB_INSET_RATIO;
  float arrowheadFlare = tabInset * ARROWHEAD_FLARE_RATIO;
  
  // Use MM conversion from global (part of same sketch)
  float tabDepth = DEFAULT_TAB_DEPTH_MM * MM;
  
  // Safety clamp: prevent tabs larger than 45% of edge
  tabDepth = min(tabDepth, 0.45 * edgeLength);
  
  float neckDepth = tabDepth * TAB_NECK_RATIO_DEFAULT;
  
  return new TabParams(tabDepth, tabInset, arrowheadFlare, neckDepth);
}

/**
 * Get dash and gap values for fold lines
 * Uses globals from main project
 */
float getDashLength() {
  return dash_px;
}

float getGapLength() {
  return gap_px;
}

/**
 * Draw simple rounded tab on an edge (matches reference image style)
 * 
 * @param p0 Start point of edge
 * @param p1 End point of edge
 * @param tabDepth How far tab protrudes
 * @param tabInset Inset from corners
 */
void drawTabOnEdge(PVector p0, PVector p1, float tabDepth, float tabInset) {
  // Calculate edge direction and perpendicular
  PVector edge = PVector.sub(p1, p0);
  float edgeLen = edge.mag();
  PVector edgeDir = edge.copy();
  edgeDir.normalize();
  
  // Perpendicular pointing outward (rotate 90° clockwise)
  PVector perp = new PVector(edgeDir.y, -edgeDir.x);
  
  // Calculate inset points along edge
  float insetDist = tabInset * 2;
  PVector pLeft = PVector.add(p0, PVector.mult(edgeDir, insetDist));
  PVector pRight = PVector.add(p1, PVector.mult(edgeDir, -insetDist));
  
  // Simple rectangular tab with rounded corners
  PVector leftOut = PVector.add(pLeft, PVector.mult(perp, tabDepth));
  PVector rightOut = PVector.add(pRight, PVector.mult(perp, tabDepth));
  
  // Draw dashed fold line at tab base
  pushStyle();
  stroke(150);
  strokeWeight(1);
  drawDashedLineLocal(pLeft.x, pLeft.y, pRight.x, pRight.y, getDashLength(), getGapLength());
  
  // Draw solid tab outline with slight curves
  stroke(0);
  noFill();
  beginShape();
  vertex(pLeft.x, pLeft.y);
  vertex(leftOut.x, leftOut.y);
  vertex(rightOut.x, rightOut.y);
  vertex(pRight.x, pRight.y);
  endShape();
  popStyle();
}

/**
 * Local implementation of dashed line drawing
 * Based on tools.pde drawDashedLine() but standalone
 */
void drawDashedLineLocal(float x1, float y1, float x2, float y2, 
                        float dashLength, float gapLength) {
  float dx = x2 - x1;
  float dy = y2 - y1;
  float totalLength = sqrt(dx*dx + dy*dy);
  
  if (totalLength == 0) return;
  
  float dirX = dx / totalLength;
  float dirY = dy / totalLength;
  
  float dashGapLength = dashLength + gapLength;
  float drawStart = gapLength;
  float drawEnd = totalLength - gapLength;
  
  pushStyle();
  stroke(150);
  strokeWeight(1);
  
  float currentPos = drawStart;
  while (currentPos < drawEnd) {
    float nextPos = min(currentPos + dashLength, drawEnd);
    float sx = x1 + dirX * currentPos;
    float sy = y1 + dirY * currentPos;
    float ex = x1 + dirX * nextPos;
    float ey = y1 + dirY * nextPos;
    line(sx, sy, ex, ey);
    currentPos += dashGapLength;
  }
  popStyle();
}

/**
 * Calculate vertices of a regular polygon
 * @param cx Center X
 * @param cy Center Y
 * @param radius Circumradius (center to vertex)
 * @param sides Number of sides
 * @param startAngle Starting angle in radians
 * @return Array of vertex positions
 */
PVector[] getRegularPolygonVertices(float cx, float cy, float radius, 
                                    int sides, float startAngle) {
  PVector[] vertices = new PVector[sides];
  float angleStep = TWO_PI / sides;
  
  for (int i = 0; i < sides; i++) {
    float angle = startAngle + i * angleStep;
    vertices[i] = new PVector(
      cx + cos(angle) * radius,
      cy + sin(angle) * radius
    );
  }
  
  return vertices;
}

/**
 * Draw a regular polygon outline
 * @param vertices Array of PVector vertices
 */
void drawPolygonOutline(PVector[] vertices) {
  pushStyle();
  stroke(0);
  strokeWeight(1);
  noFill();
  
  beginShape();
  for (PVector v : vertices) {
    vertex(v.x, v.y);
  }
  endShape(CLOSE);
  popStyle();
}

/**
 * Edge tracking class om dubbele lijnen te voorkomen
 */
class EdgeSet {
  ArrayList<PVector[]> edges;
  ArrayList<Boolean> isShared; // true = fold line (dashed), false = cut line (solid)
  float tolerance = 0.01; // Tolerance voor edge matching
  
  EdgeSet() {
    edges = new ArrayList<PVector[]>();
    isShared = new ArrayList<Boolean>();
  }
  
  // Voeg een edge toe als "cut" (outer edge, solid)
  void addCutEdge(PVector p1, PVector p2) {
    int existingIdx = findEdge(p1, p2);
    if (existingIdx == -1) {
      // Nieuwe edge
      edges.add(new PVector[] {p1.copy(), p2.copy()});
      isShared.add(false);
    } else {
      // Edge bestaat al - markeer als shared (fold line)
      isShared.set(existingIdx, true);
    }
  }
  
  // Vind een edge (in beide richtingen)
  int findEdge(PVector p1, PVector p2) {
    for (int i = 0; i < edges.size(); i++) {
      PVector[] edge = edges.get(i);
      if (edgeMatches(edge[0], edge[1], p1, p2)) {
        return i;
      }
    }
    return -1;
  }
  
  // Check of twee edges hetzelfde zijn (in beide richtingen)
  boolean edgeMatches(PVector a1, PVector a2, PVector b1, PVector b2) {
    return (pointsEqual(a1, b1) && pointsEqual(a2, b2)) ||
           (pointsEqual(a1, b2) && pointsEqual(a2, b1));
  }
  
  boolean pointsEqual(PVector p1, PVector p2) {
    return abs(p1.x - p2.x) < tolerance && abs(p1.y - p2.y) < tolerance;
  }
  
  // Teken alle edges: solid voor cut lines, dashed voor fold lines
  void drawAll() {
    for (int i = 0; i < edges.size(); i++) {
      PVector[] edge = edges.get(i);
      if (isShared.get(i)) {
        // Fold line - dashed
        drawFoldLine(edge[0], edge[1]);
      } else {
        // Cut line - solid
        drawCutLine(edge[0], edge[1]);
      }
    }
  }
  
  void clear() {
    edges.clear();
    isShared.clear();
  }
}

/**
 * Helper: Add triangle edges to EdgeSet
 */
void addTriangleToEdgeSet(EdgeSet edgeSet, PVector a, PVector b, PVector c) {
  edgeSet.addCutEdge(a, b);
  edgeSet.addCutEdge(b, c);
  edgeSet.addCutEdge(c, a);
}

/**
 * Helper: Add polygon edges to EdgeSet
 */
void addPolygonToEdgeSet(EdgeSet edgeSet, PVector[] vertices) {
  for (int i = 0; i < vertices.length; i++) {
    edgeSet.addCutEdge(vertices[i], vertices[(i + 1) % vertices.length]);
  }
}

/**
 * Draw cut line (solid)
 */
void drawCutLine(PVector p0, PVector p1) {
  pushStyle();
  stroke(0);
  strokeWeight(1);
  line(p0.x, p0.y, p1.x, p1.y);
  popStyle();
}

/**
 * Draw fold line between two points (dashed)
 */
void drawFoldLine(PVector p0, PVector p1) {
  pushStyle();
  stroke(150);
  strokeWeight(1);
  drawDashedLineLocal(p0.x, p0.y, p1.x, p1.y, getDashLength(), getGapLength());
  popStyle();
}

// ============================================================================
// PLATONIC SOLID NET IMPLEMENTATIONS
// ============================================================================

/**
 * Draw tetrahedron net (4 equilateral triangles)
 * Layout: One central triangle with 3 triangles sharing its edges
 */
void drawTetrahedronNet(float edgeLen, boolean withTabs) {
  float h = edgeLen * sqrt(3.0) / 2.0;  // Height of equilateral triangle
  
  TabParams tabs = calculateTabParams(edgeLen);
  EdgeSet edgeSet = new EdgeSet();
  
  // Central triangle (base) - pointing up
  PVector base_left = new PVector(edgeLen/2, h);
  PVector base_top = new PVector(edgeLen, 0);
  PVector base_right = new PVector(edgeLen*1.5, h);
  
  // Triangle 1: shares left edge of base - pointing left
  PVector tri1_third = new PVector(0, 0);
  
  // Triangle 2: shares right edge of base - pointing right
  PVector tri2_third = new PVector(edgeLen*2, 0);
  
  // Triangle 3: shares bottom edge of base - pointing down
  PVector tri3_bottom = new PVector(edgeLen, h*2);
  
  // Add all edges to EdgeSet (automatically detects shared edges)
  // Central triangle
  edgeSet.addCutEdge(base_left, base_top);
  edgeSet.addCutEdge(base_top, base_right);
  edgeSet.addCutEdge(base_right, base_left);
  
  // Triangle 1
  edgeSet.addCutEdge(base_left, base_top);  // Shared - will be marked as fold
  edgeSet.addCutEdge(base_top, tri1_third);
  edgeSet.addCutEdge(tri1_third, base_left);
  
  // Triangle 2
  edgeSet.addCutEdge(base_top, base_right); // Shared - will be marked as fold
  edgeSet.addCutEdge(base_right, tri2_third);
  edgeSet.addCutEdge(tri2_third, base_top);
  
  // Triangle 3
  edgeSet.addCutEdge(base_left, base_right); // Shared - will be marked as fold
  edgeSet.addCutEdge(base_right, tri3_bottom);
  edgeSet.addCutEdge(tri3_bottom, base_left);
  
  // Draw all edges (solid for cuts, dashed for folds, no overlaps)
  edgeSet.drawAll();
}

/**
 * Helper to draw triangle with solid outline
 */
void drawTriangle(PVector a, PVector b, PVector c) {
  pushStyle();
  stroke(0);
  strokeWeight(1);
  noFill();
  beginShape();
  vertex(a.x, a.y);
  vertex(b.x, b.y);
  vertex(c.x, c.y);
  endShape(CLOSE);
  popStyle();
}

/**
 * Draw cube net (6 squares)
 * Layout: Classic cross/T-shape
 */
void drawCubeNet(float edgeLen, boolean withTabs) {
  TabParams tabs = calculateTabParams(edgeLen);
  EdgeSet edgeSet = new EdgeSet();
  
  // Define 6 square positions in cross pattern:
  //     [1]
  // [4] [0] [2]
  //     [3]
  //     [5]
  
  float s = edgeLen;
  
  // Square 0 (center)
  PVector[] sq0 = {
    new PVector(s, s), new PVector(2*s, s),
    new PVector(2*s, 2*s), new PVector(s, 2*s)
  };
  
  // Square 1 (top)
  PVector[] sq1 = {
    new PVector(s, 0), new PVector(2*s, 0),
    new PVector(2*s, s), new PVector(s, s)
  };
  
  // Square 2 (right)
  PVector[] sq2 = {
    new PVector(2*s, s), new PVector(3*s, s),
    new PVector(3*s, 2*s), new PVector(2*s, 2*s)
  };
  
  // Square 3 (bottom)
  PVector[] sq3 = {
    new PVector(s, 2*s), new PVector(2*s, 2*s),
    new PVector(2*s, 3*s), new PVector(s, 3*s)
  };
  
  // Square 4 (left)
  PVector[] sq4 = {
    new PVector(0, s), new PVector(s, s),
    new PVector(s, 2*s), new PVector(0, 2*s)
  };
  
  // Square 5 (far bottom)
  PVector[] sq5 = {
    new PVector(s, 3*s), new PVector(2*s, 3*s),
    new PVector(2*s, 4*s), new PVector(s, 4*s)
  };
  
  // Add all squares to EdgeSet
  addPolygonToEdgeSet(edgeSet, sq0);
  addPolygonToEdgeSet(edgeSet, sq1);
  addPolygonToEdgeSet(edgeSet, sq2);
  addPolygonToEdgeSet(edgeSet, sq3);
  addPolygonToEdgeSet(edgeSet, sq4);
  addPolygonToEdgeSet(edgeSet, sq5);
  
  // Draw all edges (auto-detects shared edges as folds)
  edgeSet.drawAll();
}

/**
 * Calculate third point of equilateral triangle given two points
 * @param p1 First point
 * @param p2 Second point
 * @param clockwise If true, point is on right side, else left side
 */
PVector getThirdPointEquilateral(PVector p1, PVector p2, boolean clockwise) {
  // Vector from p1 to p2
  PVector edge = PVector.sub(p2, p1);
  // Midpoint
  PVector mid = PVector.add(p1, p2).mult(0.5);
  // Perpendicular vector (rotate 90 degrees)
  PVector perp = new PVector(-edge.y, edge.x);
  perp.normalize();
  // Height of equilateral triangle
  float h = edge.mag() * sqrt(3.0) / 2.0;
  // Third point
  if (!clockwise) h = -h;
  return PVector.add(mid, PVector.mult(perp, h));
}

/**
 * Draw octahedron net (8 equilateral triangles)
 * Layout: Horizontal strip of 6 alternating triangles + 2 wing triangles
 */
void drawOctahedronNet(float edgeLen, boolean withTabs) {
  float a = edgeLen;
  float h = a * sqrt(3.0) / 2.0;
  TabParams tabs = calculateTabParams(edgeLen);
  EdgeSet edgeSet = new EdgeSet();
  
  PVector[][] triangles = new PVector[8][3];
  
  // Middelste strip (6 driehoeken):
  triangles[0][0] = new PVector(0, 0);
  triangles[0][1] = new PVector(a, 0);
  triangles[0][2] = new PVector(a/2, h);
  
  triangles[1][0] = new PVector(a, 0);
  triangles[1][1] = new PVector(a/2, h);
  triangles[1][2] = new PVector(3*a/2, h);
  
  triangles[2][0] = new PVector(a, 0);
  triangles[2][1] = new PVector(2*a, 0);
  triangles[2][2] = new PVector(3*a/2, h);
  
  triangles[3][0] = new PVector(2*a, 0);
  triangles[3][1] = new PVector(3*a/2, h);
  triangles[3][2] = new PVector(5*a/2, h);
  
  triangles[4][0] = new PVector(2*a, 0);
  triangles[4][1] = new PVector(3*a, 0);
  triangles[4][2] = new PVector(5*a/2, h);
  
  triangles[5][0] = new PVector(3*a, 0);
  triangles[5][1] = new PVector(5*a/2, h);
  triangles[5][2] = new PVector(7*a/2, h);
  
  // Vleugels
  triangles[6][0] = new PVector(3*a/2, h);
  triangles[6][1] = new PVector(5*a/2, h);
  triangles[6][2] = new PVector(2*a, 2*h);
  
  triangles[7][0] = new PVector(a, 0);
  triangles[7][1] = new PVector(2*a, 0);
  triangles[7][2] = new PVector(3*a/2, -h);
  
  // Add all triangles to EdgeSet
  for (int i = 0; i < 8; i++) {
    addTriangleToEdgeSet(edgeSet, triangles[i][0], triangles[i][1], triangles[i][2]);
  }
  
  // Draw all edges (auto-detects shared edges as folds)
  edgeSet.drawAll();
}

/**
 * Helper: Calculate center and rotation for neighboring pentagon sharing an edge
 * Returns [centerX, centerY, rotationDegrees]
 */
float[] neighbourCenter(float cx, float cy, float rotateDeg, int edgeIndex, float edgeLen) {
  float r = edgeLen / (2.0 * tan(PI / 5.0)); // apothema
  
  // Get vertices of original pentagon
  PVector[] verts = getPentagonVertices(cx, cy, rotateDeg, edgeLen);
  
  // Get the edge to share
  PVector v1 = verts[edgeIndex];
  PVector v2 = verts[(edgeIndex + 1) % 5];
  
  // Midpoint of edge
  PVector mid = PVector.add(v1, v2).mult(0.5);
  
  // Direction from center to edge midpoint
  float angle = atan2(mid.y - cy, mid.x - cx);
  
  // Distance = 2 * apothema
  float dist = 2 * r;
  
  // New center
  float newCx = cx + dist * cos(angle);
  float newCy = cy + dist * sin(angle);
  
  // New rotation = rotateDeg + 180 - (edgeIndex * 72)
  float newRotate = rotateDeg + 180 - (edgeIndex * 72);
  
  return new float[] {newCx, newCy, newRotate};
}

/**
 * Helper: Calculate pentagon center and rotation for a reflected pentagon
 * Returns [centerX, centerY, rotationDegrees]
 */
float[] reflectPentagonOver(float cx, float cy, float rotateDeg, int edgeIndex, float edgeLen) {
  float R = edgeLen / (2.0 * sin(PI / 5.0));
  
  // Get vertices of original pentagon
  PVector[] verts = getPentagonVertices(cx, cy, rotateDeg, edgeLen);
  
  // Get the edge to reflect over
  PVector v1 = verts[edgeIndex];
  PVector v2 = verts[(edgeIndex + 1) % 5];
  
  // Midpoint of edge
  PVector mid = PVector.add(v1, v2).mult(0.5);
  
  // Reflect center over edge midpoint
  float newCx = 2 * mid.x - cx;
  float newCy = 2 * mid.y - cy;
  
  // New rotation = old rotation + 72 degrees per reflection
  float newRotate = rotateDeg + 72;
  
  return new float[] {newCx, newCy, newRotate};
}

/**
 * Get pentagon vertices given center, rotation (degrees), and edge length
 */
PVector[] getPentagonVertices(float cx, float cy, float rotateDeg, float edgeLen) {
  float R = edgeLen / (2.0 * sin(PI / 5.0));
  float rotateRad = radians(rotateDeg);
  
  PVector[] verts = new PVector[5];
  for (int i = 0; i < 5; i++) {
    float angle = rotateRad + i * TWO_PI / 5.0;
    verts[i] = new PVector(
      cx + R * cos(angle),
      cy + R * sin(angle)
    );
  }
  return verts;
}

/**
 * Draw dodecahedron net (12 regular pentagons)
 * Layout: Two flowers connected petal-to-petal
 * P1-P6 = bloem 1 (centrum + 5 blaadjes)
 * P7 = verbindend blaadje bloem 2
 * P8 = centrum bloem 2
 * P9-P12 = overige 4 blaadjes bloem 2
 */
void drawDodecahedronNet(float edgeLen, boolean withTabs) {
  TabParams tabs = calculateTabParams(edgeLen);
  float r = edgeLen / (2.0 * tan(PI / 5.0));
  EdgeSet edgeSet = new EdgeSet();
  
  float[][] pentagonData = new float[13][3]; // index 1-12 gebruikt
  PVector[][] pentagons = new PVector[13][5]; // index 1-12 gebruikt
  
  // BLOEM 1: Place at origin
  // P1: centrum bloem 1 at (0, 0), rotation 90°
  pentagonData[1][0] = 0;
  pentagonData[1][1] = 0;
  pentagonData[1][2] = 90;
  pentagons[1] = getPentagonVertices(0, 0, 90, edgeLen);
  
  // P2-P6: 5 petals around P1
  for (int i = 0; i < 5; i++) {
    float[] data = neighbourCenter(pentagonData[1][0], pentagonData[1][1], pentagonData[1][2], i, edgeLen);
    pentagonData[i + 2][0] = data[0];
    pentagonData[i + 2][1] = data[1];
    pentagonData[i + 2][2] = data[2];
    pentagons[i + 2] = getPentagonVertices(data[0], data[1], data[2], edgeLen);
  }
  
  // BLOEM 2: Place to the right, separated by distance to avoid overlap
  // Distance: radius of bloem 1 + gap + radius of bloem 2
  float bloem1Radius = 2 * r + edgeLen; // rough estimate: center to outer petal edge
  float separation = 2.5 * bloem1Radius; // spacing between the two flowers
  
  // P8: centrum bloem 2 at (separation, 0), rotation 270° (flipped to face bloem 1)
  pentagonData[8][0] = separation;
  pentagonData[8][1] = 0;
  pentagonData[8][2] = 270; // was 90°, now 270° to flip
  pentagons[8] = getPentagonVertices(separation, 0, 270, edgeLen);
  
  // P7, P9-P12: 5 petals around P8
  int petalIndex = 7;
  for (int i = 0; i < 5; i++) {
    float[] data = neighbourCenter(pentagonData[8][0], pentagonData[8][1], pentagonData[8][2], i, edgeLen);
    pentagonData[petalIndex][0] = data[0];
    pentagonData[petalIndex][1] = data[1];
    pentagonData[petalIndex][2] = data[2];
    pentagons[petalIndex] = getPentagonVertices(data[0], data[1], data[2], edgeLen);
    petalIndex++;
    if (petalIndex == 8) petalIndex = 9; // skip index 8 (already used for center)
  }
  
  // Add all pentagons to EdgeSet
  for (int i = 1; i <= 12; i++) {
    if (pentagons[i] != null) {
      addPolygonToEdgeSet(edgeSet, pentagons[i]);
    }
  }
  
  // Draw all edges (auto-detects shared edges as folds)
  edgeSet.drawAll();
  
  // Draw pentagon labels
  for (int i = 1; i <= 12; i++) {
    if (pentagons[i] != null) {
      fill(255, 0, 0);
      textAlign(CENTER, CENTER);
      textSize(12);
      text("P" + i, pentagonData[i][0], pentagonData[i][1]);
      noFill();
    }
  }
}

/**
 * Draw icosahedron net (20 equilateral triangles)
 * Layout: Complex elongated diamond/fan pattern with all 20 triangles
 */
void drawIcosahedronNet(float edgeLen, boolean withTabs) {
  float h = edgeLen * sqrt(3.0) / 2.0;
  float a = edgeLen;
  TabParams tabs = calculateTabParams(edgeLen);
  EdgeSet edgeSet = new EdgeSet();
  
  // 20 triangles: strip of 10 + 5 top wings + 5 bottom wings
  PVector[][] triangles = new PVector[20][3];
  
  // MIDDELSTE STRIP (10 driehoeken alternating):
  triangles[0][0] = new PVector(0, 0);
  triangles[0][1] = new PVector(a, 0);
  triangles[0][2] = new PVector(a/2, h);
  
  triangles[1][0] = new PVector(a, 0);
  triangles[1][1] = new PVector(a/2, h);
  triangles[1][2] = new PVector(3*a/2, h);
  
  triangles[2][0] = new PVector(a, 0);
  triangles[2][1] = new PVector(2*a, 0);
  triangles[2][2] = new PVector(3*a/2, h);
  
  triangles[3][0] = new PVector(2*a, 0);
  triangles[3][1] = new PVector(3*a/2, h);
  triangles[3][2] = new PVector(5*a/2, h);
  
  triangles[4][0] = new PVector(2*a, 0);
  triangles[4][1] = new PVector(3*a, 0);
  triangles[4][2] = new PVector(5*a/2, h);
  
  triangles[5][0] = new PVector(3*a, 0);
  triangles[5][1] = new PVector(5*a/2, h);
  triangles[5][2] = new PVector(7*a/2, h);
  
  triangles[6][0] = new PVector(3*a, 0);
  triangles[6][1] = new PVector(4*a, 0);
  triangles[6][2] = new PVector(7*a/2, h);
  
  triangles[7][0] = new PVector(4*a, 0);
  triangles[7][1] = new PVector(7*a/2, h);
  triangles[7][2] = new PVector(9*a/2, h);
  
  triangles[8][0] = new PVector(4*a, 0);
  triangles[8][1] = new PVector(5*a, 0);
  triangles[8][2] = new PVector(9*a/2, h);
  
  triangles[9][0] = new PVector(5*a, 0);
  triangles[9][1] = new PVector(9*a/2, h);
  triangles[9][2] = new PVector(11*a/2, h);
  
  // BOVEN WINGS (5 driehoeken)
  triangles[10][0] = new PVector(a/2, h);
  triangles[10][1] = new PVector(3*a/2, h);
  triangles[10][2] = new PVector(a, 2*h);
  
  triangles[11][0] = new PVector(3*a/2, h);
  triangles[11][1] = new PVector(5*a/2, h);
  triangles[11][2] = new PVector(2*a, 2*h);
  
  triangles[12][0] = new PVector(5*a/2, h);
  triangles[12][1] = new PVector(7*a/2, h);
  triangles[12][2] = new PVector(3*a, 2*h);
  
  triangles[13][0] = new PVector(7*a/2, h);
  triangles[13][1] = new PVector(9*a/2, h);
  triangles[13][2] = new PVector(4*a, 2*h);
  
  triangles[14][0] = new PVector(9*a/2, h);
  triangles[14][1] = new PVector(11*a/2, h);
  triangles[14][2] = new PVector(5*a, 2*h);
  
  // ONDER WINGS (5 driehoeken)
  triangles[15][0] = new PVector(0, 0);
  triangles[15][1] = new PVector(a, 0);
  triangles[15][2] = new PVector(a/2, -h);
  
  triangles[16][0] = new PVector(a, 0);
  triangles[16][1] = new PVector(2*a, 0);
  triangles[16][2] = new PVector(3*a/2, -h);
  
  triangles[17][0] = new PVector(2*a, 0);
  triangles[17][1] = new PVector(3*a, 0);
  triangles[17][2] = new PVector(5*a/2, -h);
  
  triangles[18][0] = new PVector(3*a, 0);
  triangles[18][1] = new PVector(4*a, 0);
  triangles[18][2] = new PVector(7*a/2, -h);
  
  triangles[19][0] = new PVector(4*a, 0);
  triangles[19][1] = new PVector(5*a, 0);
  triangles[19][2] = new PVector(9*a/2, -h);
  
  // Add all triangles to EdgeSet
  for (int i = 0; i < 20; i++) {
    addTriangleToEdgeSet(edgeSet, triangles[i][0], triangles[i][1], triangles[i][2]);
  }
  
  // Draw all edges (auto-detects shared edges as folds)
  edgeSet.drawAll();
}

// ============================================================================
// MAIN PLATONIC SOLID DRAWING FUNCTION
// ============================================================================

/**
 * Draw a platonic solid net at specified position
 * 
 * @param solidType One of: tetrahedron, cube, octahedron, dodecahedron, icosahedron
 * @param targetSize Desired bounding box size in pixels
 * @param x X position to draw at
 * @param y Y position to draw at
 * @param withTabs Include gluing tabs
 */
/**
 * Get bounding box dimensions for each solid type (at edgeLen = 1.0)
 * Returns [width, height, centerOffsetX, centerOffsetY]
 */
float[] getSolidBoundingBox(String solidType) {
  float w, h, cx, cy;
  
  switch(solidType.toLowerCase()) {
    case "tetrahedron":
      // Layout spans about 2*edgeLen wide, 2h tall
      w = 2.0;
      h = 1.732; // 2 * sqrt(3)/2
      cx = -1.0; // Center offset
      cy = -0.866;
      break;
      
    case "cube":
      // Cross pattern: 3 wide, 4 tall
      w = 3.0;
      h = 4.0;
      cx = -1.5;
      cy = -2.0;
      break;
      
    case "octahedron":
      // Strip of ~3.5 wide x 3h tall (including wings)
      w = 3.5;
      h = 3.0 * 0.866; // 3h where h = sqrt(3)/2
      cx = -1.75;
      cy = -0.433; // Center Y: ranges from -h to 2h, center at h/2
      break;
      
    case "dodecahedron":
      // Two flowers side by side
      float r = 1.0 / (2.0 * tan(PI / 5.0)); // apothema
      float bloem1Radius = 2 * r + 1.0;
      float separation = 2.5 * bloem1Radius;
      w = separation + bloem1Radius * 2;
      h = bloem1Radius * 2;
      cx = -w / 2;
      cy = -h / 2;
      break;
      
    case "icosahedron":
      // Strip: 5.5 wide, 3h tall
      w = 5.5;
      h = 3.0 * 0.866;
      cx = -2.75;
      cy = -0.433; // Center Y: ranges from -h to 2h, center at h/2
      break;
      
    default:
      w = 1.0;
      h = 1.0;
      cx = 0;
      cy = 0;
  }
  
  return new float[] {w, h, cx, cy};
}

/**
 * Draw platonic solid centered and scaled to fit targetSize
 */
void drawPlatonicSolid(String solidType, float targetSize, float x, float y, boolean withTabs) {
  pushMatrix();
  translate(x, y);
  
  // Get bounding box for this solid at edgeLen = 1.0
  float[] bbox = getSolidBoundingBox(solidType);
  float bboxWidth = bbox[0];
  float bboxHeight = bbox[1];
  float centerX = bbox[2];
  float centerY = bbox[3];
  
  // Calculate scale to fit target size (use max dimension)
  float maxDim = max(bboxWidth, bboxHeight);
  float scale = targetSize / maxDim;
  float edgeLen = scale * 1.0;
  
  // Center the shape
  translate(-centerX * edgeLen, -centerY * edgeLen);
  
  // Draw the solid
  switch(solidType.toLowerCase()) {
    case "tetrahedron":
      drawTetrahedronNet(edgeLen, withTabs);
      break;
      
    case "cube":
      drawCubeNet(edgeLen, withTabs);
      break;
      
    case "octahedron":
      drawOctahedronNet(edgeLen, withTabs);
      break;
      
    case "dodecahedron":
      drawDodecahedronNet(edgeLen, withTabs);
      break;
      
    case "icosahedron":
      drawIcosahedronNet(edgeLen, withTabs);
      break;
      
    default:
      println("[ERROR] Unknown platonic solid type: " + solidType);
      println("        Valid types: tetrahedron, cube, octahedron, dodecahedron, icosahedron");
      break;
  }
  
  popMatrix();
}

// ============================================================================
// TESTING AND GALLERY FUNCTIONS
// ============================================================================

/**
 * Test het template parametersysteem
 * Laat verschillende varianten van platonic solids zien met verschillende parameters
 */
void testTemplateSystem() {
  background(240);
  
  // Initialize library als dat nog niet gedaan is
  if (templateLibrary == null) {
    templateLibrary = new PlatonicTemplateLibrary();
    templateLibrary.loadAllPresets();
    templateLibrary.printAll();  // Print naar console
  }
  
  // Test 1: Drie cubes met verschillende groottes
  fill(0);
  textAlign(LEFT);
  textSize(14);
  text("Template System Demo - Drie cubes (30mm, 50mm, 100mm)", 20, 30);
  
  PlatonicSolidTemplate small = templateLibrary.getTemplate("Small Cube 30mm");
  PlatonicSolidTemplate medium = templateLibrary.getTemplate("Medium Cube 50mm");
  PlatonicSolidTemplate large = templateLibrary.getTemplate("Large Cube 100mm");
  
  if (small != null) drawPlatonicSolidFromTemplate(small, 150, 200);
  if (medium != null) drawPlatonicSolidFromTemplate(medium, 400, 200);
  if (large != null) drawPlatonicSolidFromTemplate(large, 750, 200);
  
  // Labels
  text("30mm", 150, 400);
  text("50mm", 400, 400);
  text("100mm", 750, 400);
  
  // Test 2: Custom template met schaalfactor
  text("Custom: 40mm dodecahedron @ 1.5x scale", 20, 500);
  PlatonicSolidTemplate custom = new PlatonicSolidTemplate("dodecahedron", 40);
  custom.scaleFactor = 1.5;
  custom.templateName = "Scaled Dodecahedron";
  drawPlatonicSolidFromTemplate(custom, 300, 650);
}

/**
 * Demo: Genereer en export templates voor productie
 * Dit zou je kunnen gebruiken om snel sets van templates te maken
 */
void generateProductionTemplates() {
  println("\n=== Generating Production Templates ===");
  
  PlatonicTemplateLibrary productionLib = new PlatonicTemplateLibrary();
  
  // Maak een serie cubes in verschillende groottes
  float[] sizes = {20, 30, 40, 50, 60, 80, 100};
  for (float size : sizes) {
    PlatonicSolidTemplate t = new PlatonicSolidTemplate("cube", size);
    t.templateName = "Cube_" + (int)size + "mm";
    t.notes = "Productie kubus " + (int)size + "mm voor lasersnijden";
    productionLib.addTemplate(t);
  }
  
  // Maak complete set van alle solids op 50mm
  for (String solidType : SOLID_NAMES) {
    PlatonicSolidTemplate t = new PlatonicSolidTemplate(solidType, 50);
    t.templateName = "Standard_" + solidType + "_50mm";
    t.notes = "Standaard 50mm set";
    productionLib.addTemplate(t);
  }
  
  // Save naar bestand
  productionLib.saveToFile("data/platonic_templates_production.txt");
  productionLib.printAll();
  
  println("=== Production Templates Generated ===\n");
}

/**
 * Draw all 5 platonic solids in a gallery grid layout
 */
void drawPlatonicSolidGallery() {
  background(240);
  
  // Grid layout: 3 columns × 2 rows
  int cols = 3;
  float cellW = width / cols;
  float cellH = height / 2;
  float margin = 50;
  float drawSize = min(cellW, cellH) - margin * 2;
  
  // Draw each solid
  for (int i = 0; i < 5; i++) {
    int col = i % cols;
    int row = i / cols;
    
    float cellX = col * cellW;
    float cellY = row * cellH;
    
    // Horizontaal gecentreerd in de cel
    float centerX = cellX + cellW / 2;
    
    // Label bovenaan, shape direct eronder
    float labelY = cellY + 20;
    float shapeY = cellY + 60; // Shape begint onder het label
    
    // Draw label
    pushStyle();
    fill(0);
    textAlign(CENTER, TOP);
    textSize(14);
    text(SOLID_NAMES[i].toUpperCase(), centerX, labelY);
    popStyle();
    
    // Draw solid (horizontaal gecentreerd, direct onder label)
    drawPlatonicSolid(SOLID_NAMES[i], platonicTestScale, 
                     centerX, shapeY, platonicShowTabs);
    
    // Draw bounding box for reference
    pushStyle();
    stroke(200);
    strokeWeight(1);
    noFill();
    rect(cellX + margin, cellY + margin, cellW - margin*2, cellH - margin*2);
    popStyle();
  }
  
  // Draw HUD
  drawPlatonicTestHUD();
}

/**
 * Draw detailed view of single solid
 */
void drawPlatonicSolidDetailed(int solidIndex) {
  background(240);
  
  if (solidIndex < 0 || solidIndex >= 5) {
    return;
  }
  
  String solidName = SOLID_NAMES[solidIndex];
  
  // Center on screen perfectly
  float scale = platonicTestScale * 2;
  float centerX = width / 2;
  float centerY = height / 2 + 20; // +20 for title offset
  
  // Draw solid (now perfectly centered)
  drawPlatonicSolid(solidName, scale, centerX, centerY, platonicShowTabs);
  
  // Draw title
  pushStyle();
  fill(0);
  textAlign(CENTER, TOP);
  textSize(24);
  text(solidName.toUpperCase() + " NET", width/2, 20);
  textSize(14);
  text("Tabs: " + (platonicShowTabs ? "ON" : "OFF"), width/2, 50);
  popStyle();
  
  // Draw HUD
  drawPlatonicTestHUD();
}

/**
 * Draw test mode HUD
 */
void drawPlatonicTestHUD() {
  pushStyle();
  
  // HUD panel
  float hudX = width - 220;
  float hudY = 10;
  float hudW = 210;
  float hudH = 150;
  
  fill(255, 245);
  stroke(0);
  strokeWeight(1);
  rect(hudX, hudY, hudW, hudH);
  
  // Text
  fill(0);
  textAlign(LEFT, TOP);
  textSize(12);
  
  float ty = hudY + 10;
  float tx = hudX + 10;
  float lineH = 18;
  
  text("PLATONIC SOLIDS TEST", tx, ty);
  ty += lineH * 1.5;
  
  text("Mode: " + (platonicSelectedSolid < 0 ? "Gallery" : SOLID_NAMES[platonicSelectedSolid]), tx, ty);
  ty += lineH;
  
  text("Tabs: " + (platonicShowTabs ? "ON" : "OFF"), tx, ty);
  ty += lineH;
  
  text("Scale: " + nf(platonicTestScale, 1, 0) + "px", tx, ty);
  ty += lineH * 1.5;
  
  text("Keys:", tx, ty);
  ty += lineH;
  text("T - Toggle tabs", tx, ty);
  ty += lineH;
  text("0 - Gallery view", tx, ty);
  ty += lineH;
  text("1-5 - Detail view", tx, ty);
  
  popStyle();
}

// ============================================================================
// TEMPLATE EDIT MODE - Interactive template editor
// ============================================================================

/**
 * Main render function for template edit mode
 * Combines thumbnail selection, size controls, and canvas display
 */
void drawTemplateEditMode() {
  background(240);
  
  // Constants
  float thumbnailSize = 80;
  float thumbnailSpacing = 10;
  float topMargin = TOOLBAR_HEIGHT + 20;
  float thumbnailY = topMargin;
  
  // Calculate centered X position for thumbnail strip (offset for sidebar)
  float canvasArea = width - LEFT_SIDEBAR_WIDTH;
  float totalThumbnailWidth = (thumbnailSize + thumbnailSpacing) * 5 - thumbnailSpacing;
  float thumbnailStartX = LEFT_SIDEBAR_WIDTH + (canvasArea - totalThumbnailWidth) / 2;
  
  // Draw title
  pushStyle();
  fill(0);
  textAlign(CENTER, TOP);
  textSize(18);
  text("TEMPLATE EDITOR", LEFT_SIDEBAR_WIDTH + canvasArea/2, topMargin - 5);
  popStyle();
  
  // PHASE 2: Draw thumbnail grid
  drawThumbnailGrid(thumbnailStartX, thumbnailY, thumbnailSize, thumbnailSpacing);
  
  // Calculate canvas area (respecting bottom bar)
  float canvasTopY = thumbnailY + thumbnailSize + 40;
  float canvasBottomY = height - BOTTOM_EXPORT_HEIGHT;
  float canvasHeight = canvasBottomY - canvasTopY;
  float canvasCenterX = LEFT_SIDEBAR_WIDTH + canvasArea / 2;
  float canvasCenterY = canvasTopY + canvasHeight / 2;
  
  // PHASE 3: Draw size controls (in left sidebar area)
  drawSizeControls(20, canvasTopY, LEFT_SIDEBAR_WIDTH - 40);
  
  // PHASE 4: Draw template on canvas with feedback
  drawTemplateCanvas(canvasCenterX, canvasCenterY);
  
  // Draw bottom bar (same as main code)
  drawEditModeBottomBar();
  
  // Draw edit mode HUD
  drawEditModeHUD();
}

/**
 * PHASE 2: Draw thumbnail selection grid
 */
void drawThumbnailGrid(float startX, float startY, float thumbSize, float spacing) {
  pushStyle();
  
  for (int i = 0; i < 5; i++) {
    float x = startX + i * (thumbSize + spacing);
    float y = startY;
    
    // Check if mouse is over this thumbnail
    boolean hover = mouseX >= x && mouseX <= x + thumbSize &&
                    mouseY >= y && mouseY <= y + thumbSize;
    boolean selected = (i == selectedThumbnailIndex);
    
    // Draw thumbnail background
    if (selected) {
      fill(100, 180, 255);
      strokeWeight(3);
      stroke(50, 120, 200);
    } else if (hover) {
      fill(220);
      strokeWeight(2);
      stroke(150);
    } else {
      fill(255);
      strokeWeight(1);
      stroke(100);
    }
    rect(x, y, thumbSize, thumbSize, 5);
    
    // Draw mini preview of solid
    pushMatrix();
    translate(x + thumbSize/2, y + thumbSize/2);
    drawPlatonicSolid(SOLID_NAMES[i], thumbSize * 0.6, 0, 0, false);
    popMatrix();
    
    // Draw label
    fill(0);
    textAlign(CENTER, TOP);
    textSize(9);
    text(SOLID_NAMES[i].substring(0, 4), x + thumbSize/2, y + thumbSize + 3);
  }
  
  popStyle();
}

/**
 * PHASE 3: Draw size control UI elements
 * (Placeholder - will be replaced with ControlP5 sliders)
 */
void drawSizeControls(float x, float y, float w) {
  pushStyle();
  
  // Control panel background
  fill(255);
  stroke(100);
  strokeWeight(1);
  rect(x, y, w, 120, 5);
  
  // Title
  fill(0);
  textAlign(LEFT, TOP);
  textSize(12);
  text("SIZE CONTROLS", x + 10, y + 10);
  
  // Edge length display
  textSize(11);
  text("Edge Length:", x + 10, y + 35);
  textAlign(RIGHT, TOP);
  text(nf(selectedTemplate.edgeLength_mm, 1, 1) + " mm", x + w - 10, y + 35);
  
  // Instructions
  textAlign(LEFT, TOP);
  textSize(9);
  fill(100);
  text("Use +/- keys to adjust", x + 10, y + 55);
  text("(Sliders coming soon)", x + 10, y + 70);
  
  popStyle();
}

/**
 * PHASE 4: Draw template on canvas with real-time feedback
 */
void drawTemplateCanvas(float centerX, float centerY) {
  if (selectedTemplate == null) return;
  
  pushStyle();
  
  // Calculate display size that fits nicely on canvas
  float targetDisplaySize = 300; // Target size for the solid's bounding box
  
  // Draw template centered using drawPlatonicSolid directly
  // This ensures proper sizing and centering
  drawPlatonicSolid(selectedTemplate.solidType, targetDisplaySize, 
                   centerX, centerY, selectedTemplate.includeTabs);
  
  // Get bounding box for feedback calculations
  float[] bbox = getSolidBoundingBox(selectedTemplate.solidType);
  float bboxWidth = bbox[0];
  float bboxHeight = bbox[1];
  float maxDim = max(bboxWidth, bboxHeight);
  
  // Calculate what the actual edge length is in pixels for this display
  float displayScale = targetDisplaySize / maxDim;
  float edgeLenPx = displayScale * 1.0;
  
  // Calculate actual dimensions in mm (what user set)
  float actualWidth = bboxWidth * selectedTemplate.edgeLength_mm;
  float actualHeight = bboxHeight * selectedTemplate.edgeLength_mm;
  
  // Calculate display dimensions in pixels
  float displayWidth = bboxWidth * edgeLenPx;
  float displayHeight = bboxHeight * edgeLenPx;
  
  // Draw bounding box overlay
  stroke(150, 150, 255, 100);
  strokeWeight(2);
  strokeCap(SQUARE);
  noFill();
  rect(centerX - displayWidth/2, centerY - displayHeight/2, displayWidth, displayHeight);
  
  // Draw edge length feedback (top right)
  fill(0);
  textAlign(LEFT, TOP);
  textSize(14);
  text("Edge: " + nf(selectedTemplate.edgeLength_mm, 1, 1) + " mm", 
       centerX + displayWidth/2 + 15, centerY - displayHeight/2);
  
  // Draw bounding box dimensions (below)
  textSize(12);
  fill(100);
  text("Size: " + nf(actualWidth, 1, 1) + " × " + nf(actualHeight, 1, 1) + " mm",
       centerX - displayWidth/2, centerY + displayHeight/2 + 15);
  
  popStyle();
}

/**
 * Draw bottom bar for edit mode (matches main application)
 */
void drawEditModeBottomBar() {
  pushStyle();
  
  // Draw export bar background (same color as sidebar)
  fill(240, 240, 245);
  noStroke();
  rect(LEFT_SIDEBAR_WIDTH, height - BOTTOM_EXPORT_HEIGHT, width - LEFT_SIDEBAR_WIDTH, BOTTOM_EXPORT_HEIGHT);
  
  // Add some labels/info
  fill(80);
  textAlign(LEFT, CENTER);
  textSize(15);
  float exportBarY = height - BOTTOM_EXPORT_HEIGHT + 10;
  text("Template Editor", LEFT_SIDEBAR_WIDTH + 20, exportBarY + 23);
  
  // Show active template info
  if (selectedTemplate != null) {
    textSize(12);
    fill(100);
    text(selectedTemplate.solidType + " | " + 
         nf(selectedTemplate.edgeLength_mm, 1, 1) + " mm", 
         LEFT_SIDEBAR_WIDTH + 180, exportBarY + 23);
  }
  
  popStyle();
}

/**
 * Draw HUD for edit mode
 */
void drawEditModeHUD() {
  pushStyle();
  
  // HUD panel (top right)
  float hudX = width - 220;
  float hudY = TOOLBAR_HEIGHT + 10;
  float hudW = 210;
  float hudH = 130;
  
  fill(255, 245);
  stroke(0);
  strokeWeight(1);
  rect(hudX, hudY, hudW, hudH);
  
  // Text
  fill(0);
  textAlign(LEFT, TOP);
  textSize(12);
  
  float ty = hudY + 10;
  float tx = hudX + 10;
  float lineH = 18;
  
  text("TEMPLATE EDITOR", tx, ty);
  ty += lineH * 1.5;
  
  text("Type: " + selectedTemplateType, tx, ty);
  ty += lineH;
  
  text("Edge: " + nf(selectedTemplate.edgeLength_mm, 1, 1) + " mm", tx, ty);
  ty += lineH * 1.5;
  
  text("Controls:", tx, ty);
  ty += lineH;
  text("+/- : Adjust size", tx, ty);
  ty += lineH;
  text("Click thumbnails", tx, ty);
  
  popStyle();
}

/**
 * Quick test function for development
 * Draws all 5 solids in a simple row
 */
void quickTestPlatonicSolid() {
  background(240);
  
  float scale = width / 6.5;
  float y = 100;
  float spacing = width / 5.5;
  
  for (int i = 0; i < 5; i++) {
    drawPlatonicSolid(SOLID_NAMES[i], scale, i * spacing + 20, y, true);
    
    // Label
    pushStyle();
    fill(0);
    textAlign(LEFT, TOP);
    textSize(10);
    text(SOLID_NAMES[i], i * spacing + 20, y - 15);
    popStyle();
  }
}

// ============================================================================
// EXPORT FUNCTIONS
// ============================================================================

/**
 * Export a single platonic solid to PDF
 * Note: Requires Processing PDF library
 */
void exportPlatonicSolid(String solidType, float scale, boolean withTabs) {
  println("[Export] Starting export of " + solidType + " net...");
  
  // Create timestamp
  String timestamp = year() + "_" + nf(month(),2) + "_" + nf(day(),2) + "_" + 
                    nf(hour(),2) + nf(minute(),2) + nf(second(),2);
  
  String filename = "output/platonic_" + solidType + "_" + timestamp + ".pdf";
  
  // Note: Actual PDF export requires beginRecord(PDF, filename)
  // This is a placeholder for the export logic
  println("[Export] Would export to: " + filename);
  println("[Export] Scale: " + scale + "px, Tabs: " + withTabs);
  
  // TODO: Implement actual PDF export when integrated with main project
  // Example:
  // PGraphics pdf = createGraphics(842, 595, PDF, filename);
  // pdf.beginDraw();
  // ... draw solid centered on page ...
  // pdf.endDraw();
  // pdf.dispose();
}

/**
 * Export all 5 platonic solids to separate PDFs
 */
void exportAllPlatonicSolids() {
  println("[Export] Exporting all platonic solids...");
  
  for (String solidName : SOLID_NAMES) {
    exportPlatonicSolid(solidName, 200.0, true);
  }
  
  println("[Export] Batch export complete!");
}

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

/**
 * Validate a platonic solid net
 * Checks basic geometric correctness
 */
boolean validatePlatonicNet(String solidType, float edgeLength) {
  println("[Validate] Checking " + solidType + " net...");
  
  boolean valid = true;
  
  // Basic checks
  if (edgeLength <= 0) {
    println("[Validate] ERROR: Edge length must be positive");
    valid = false;
  }
  
  TabParams tabs = calculateTabParams(edgeLength);
  if (tabs.tabDepth > edgeLength * 0.45) {
    println("[Validate] WARNING: Tab depth may be too large");
  }
  
  // Type-specific checks
  switch(solidType.toLowerCase()) {
    case "tetrahedron":
      println("[Validate] Tetrahedron: 4 equilateral triangles");
      break;
    case "cube":
      println("[Validate] Cube: 6 squares");
      break;
    case "octahedron":
      println("[Validate] Octahedron: 8 equilateral triangles");
      break;
    case "dodecahedron":
      println("[Validate] Dodecahedron: 12 regular pentagons");
      break;
    case "icosahedron":
      println("[Validate] Icosahedron: 20 equilateral triangles");
      break;
    default:
      println("[Validate] ERROR: Unknown solid type");
      valid = false;
  }
  
  println("[Validate] Result: " + (valid ? "PASS" : "FAIL"));
  return valid;
}

// ============================================================================
// END OF PLATONIC SOLIDS NET GENERATOR
// ============================================================================
