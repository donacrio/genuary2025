import java.io.File;
import java.util.HashMap;

// Canvas and brush size configuration
static int MAX_DIMENSION = 2400;
// Configuration constants for brush strokes
static int GRID_SIZE = MAX_DIMENSION / 120;
// Brush sizes for different detail levels
static float LARGE_BRUSH_LENGTH = 8 * GRID_SIZE;    // Base size for background elements
static float MEDIUM_BRUSH_LENGTH = 4 * GRID_SIZE;   // For medium details
static float SMALL_BRUSH_LENGTH = 2 * GRID_SIZE;    // For fine details
static float LARGE_BRUSH_WIDTH = 2 * GRID_SIZE;     // Width for broad strokes
static float MEDIUM_BRUSH_WIDTH = 1 * GRID_SIZE;        // Width for medium details
static float SMALL_BRUSH_WIDTH = 0.5 * GRID_SIZE;   // Width for fine details
// Color and edge detection parameters
static float COLOR_SIMILARITY_THRESHOLD = 5;        // Lower = more color segments
static float EDGE_THRESHOLD = 0.00001;                 // Very sensitive to detect subtle gradients
static float BASE_COVERAGE = 0.4;                    // Minimum coverage for areas with no edges

// Core resources
PImage paperTexture;          // Background paper texture
PImage originalImage;         // Input image to be processed
PImage edgeDetectionMap;      // Stores edge detection results
Watercolor watercolorShape;
ArrayList<Watercolor> brushStrokes;  // Collection of all brush strokes
String timestamp;
HashMap<Integer, ArrayList<PVector>> colorRegions;  // Maps colors to their positions

int canvasWidth, canvasHeight;    // Store dimensions for use in settings() and setup()

void settings() {
  // Load image first to get its dimensions
  originalImage = loadImage("images/input_3.png");
  
  // Calculate new dimensions maintaining aspect ratio
  float ratio = (float) originalImage.width / originalImage.height;
  
  if (ratio > 1) {  // Landscape
    canvasWidth = MAX_DIMENSION;
    canvasHeight = int(MAX_DIMENSION / ratio);
  } else {          // Portrait
    canvasHeight = MAX_DIMENSION;
    canvasWidth = int(MAX_DIMENSION * ratio);
  }
  
  // Set canvas size
  size(canvasWidth, canvasHeight);
}

void setup() {
  paperTexture = loadImage("images/paper.jpg");
  originalImage.resize(width, height);
  
  // Enhance edges before detection
  originalImage.loadPixels();
  for (int i = 0; i < originalImage.pixels.length; i++) {
    color c = originalImage.pixels[i];
    float b = brightness(c);
    originalImage.pixels[i] = color(
      red(c) * (1 + b / 255),
      green(c) * (1 + b / 255),
      blue(c) * (1 + b / 255)
     );
  }
  originalImage.updatePixels();
  
  edgeDetectionMap = createEdgeImage();
  colorRegions = createSegmentImage();
  brushStrokes = createWatercolorShapes();
  timestamp = getTimestamp();
  
  noLoop();
}

void draw() {
  background(255);
  tint(255, 150);
  image(paperTexture, 0, 0, width, height);
  
  for (Watercolor shape : brushStrokes) {
    waterColourEffect(shape, shape.shapeColor);
  }
  
  // Create output directory if it doesn't exist
  File outputDir = new File(sketchPath("output"));
  if (!outputDir.exists()) {
    outputDir.mkdir();
  }
  
  // Save the result
  save("output/watercolor_" + timestamp + ".png");
}

/**
* Groups similar colors into regions for painting
*/
HashMap<Integer, ArrayList<PVector>> createSegmentImage() {
  HashMap<Integer, ArrayList<PVector>> segments = new HashMap<>();
  
  // Sample colors at grid points
  for (int x = GRID_SIZE / 2; x < width; x += GRID_SIZE) {
    for (int y = GRID_SIZE / 2; y < height; y += GRID_SIZE) {
      color sampledColor = sampleAreaColor(x, y, GRID_SIZE);
      
      // Find or create a segment for this color
      Integer segmentKey = findSimilarColorKey(segments, sampledColor);
      if (segmentKey == null) {
        segmentKey = sampledColor;
        segments.put(segmentKey, new ArrayList<PVector>());
      }
      
      segments.get(segmentKey).add(new PVector(x, y));
    }
  }
  
  return segments;
}

/**
* Find a color key in the existing segments that's similar to the given color
*/
Integer findSimilarColorKey(HashMap<Integer, ArrayList<PVector>> segments, color c) {
  for (Integer key : segments.keySet()) {
    if (colorDistance(key, c) < COLOR_SIMILARITY_THRESHOLD) {
      return key;
    }
  }
  return null;
}

/**
* Calculate Euclidean distance between two colors in RGB space
*/
float colorDistance(color c1, color c2) {
  float r1 = red(c1), g1 = green(c1), b1 = blue(c1);
  float r2 = red(c2), g2 = green(c2), b2 = blue(c2);
  return sqrt(sq(r1 - r2) + sq(g1 - g2) + sq(b1 - b2));
}

/**
* Creates brush strokes in three layers: background, mid-level, and detail
*/
ArrayList<Watercolor> createWatercolorShapes() {
  ArrayList<Watercolor> shapes = new ArrayList<Watercolor>();
  
  // Paint in layers: large strokes first, then medium, then small
  paintLayer(shapes, LARGE_BRUSH_LENGTH, LARGE_BRUSH_WIDTH, 8);
  paintLayer(shapes, MEDIUM_BRUSH_LENGTH, MEDIUM_BRUSH_WIDTH, 4);
  paintLayer(shapes, SMALL_BRUSH_LENGTH, SMALL_BRUSH_WIDTH, 2);
  
  return shapes;
}

/**
* Creates a layer of brush strokes with specified characteristics
* @param strokeLength Base length of strokes
* @param strokeWidth Base width of strokes
* @param spacing Controls density (higher = fewer strokes)
*/
void paintLayer(ArrayList<Watercolor> shapes, float strokeLength, float strokeWidth, int spacing) {
  for (Integer colorKey : colorRegions.keySet()) {
    ArrayList<PVector> points = colorRegions.get(colorKey);
    
    // Ensure minimum coverage even in areas with no edges
    int numStrokes = max(
      int(points.size() * BASE_COVERAGE),  // Minimum number of strokes
      points.size() / (100 / spacing)      
     );
    
    // Randomly sample points for more natural distribution
    for (int i = 0; i < numStrokes; i++) {
      PVector point = points.get(int(random(points.size())));
      int x = int(point.x);
      int y = int(point.y);
      
      // Get edge information
      color edgeInfo = edgeDetectionMap.get(x, y);
      float edgeStrength = red(edgeInfo) / 255.0;
      float edgeAngle = green(edgeInfo) - PI;
      
      // Calculate gradient strength
      float gradientStrength = min(1.0, edgeStrength / EDGE_THRESHOLD);
      
      // For very weak edges, use extra large strokes with more random angles
      float adjustedLength = strokeLength;
      float adjustedWidth = strokeWidth;
      float baseAngle;
      float angleVariation;
      
      if (gradientStrength < 0.1) {  // Very weak edges
        adjustedLength *= 2.0;        // Double the length
        adjustedWidth *= 1.5;         // 50% wider
        // Use mostly horizontal strokes with slight variations
        baseAngle = 0;                // Horizontal base angle (0 = right, PI/2 = down)
        angleVariation = PI / 6;      // Allow some variation but keep mostly horizontal
        
        // Occasionally flip the angle by 180 degrees for variety
        if (random(1) < 0.5) {
          baseAngle = PI;
        }
      } else {
        // Normal edge-guided behavior
        adjustedLength *= (0.8 + gradientStrength * 0.4);
        adjustedWidth *= (1.2 - gradientStrength * 0.4);
        baseAngle = gradientStrength * edgeAngle + (1 - gradientStrength) * random(TWO_PI);
        angleVariation = PI / 8 * (1 - gradientStrength * 0.7);
      }
      
      // Create brush stroke
      shapes.add(createBrushStroke(
        point.x, point.y,
        adjustedLength,
        adjustedWidth,
        baseAngle + random( -angleVariation, angleVariation),
        colorKey
       ));
    }
  }
}

/**
* Samples and averages colors from a square area of the image
*/
color sampleAreaColor(int x, int y, int size) {
  float r = 0, g = 0, b = 0;
  int count = 0;
  
  int halfSize = size / 2;
  for (int i = -halfSize; i < halfSize; i++) {
    for (int j = -halfSize; j < halfSize; j++) {
      if (x + i >= 0 && x + i < width && y + j >= 0 && y + j < height) {
        color c = originalImage.get(x + i, y + j);
        r += red(c);
        g += green(c);
        b += blue(c);
        count++;
      }
    }
  }
  return color(r / count, g / count, b / count);
}

/**
* Creates a single brush stroke with specified parameters
*/
Watercolor createBrushStroke(float x, float y, float length, float width, float angle, color shapeColor) {
  ArrayList<PVector> vertices = new ArrayList<PVector>();
  
  PVector direction = new PVector(cos(angle), sin(angle));
  PVector perpendicular = new PVector( -direction.y, direction.x);
  
  vertices.add(PVector.add(new PVector(x, y), PVector.mult(direction, length / 2)));
  
  vertices.add(PVector.add(
    PVector.add(new PVector(x, y), PVector.mult(direction, length / 3)),
    PVector.mult(perpendicular, width / 2)
   ));
  vertices.add(PVector.add(
    PVector.add(new PVector(x, y), PVector.mult(direction, -length / 3)),
    PVector.mult(perpendicular, width / 2)
   ));
  
  vertices.add(PVector.add(new PVector(x, y), PVector.mult(direction, -length / 2)));
  
  vertices.add(PVector.add(
    PVector.add(new PVector(x, y), PVector.mult(direction, -length / 3)),
    PVector.mult(perpendicular, -width / 2)
   ));
  vertices.add(PVector.add(
    PVector.add(new PVector(x, y), PVector.mult(direction, length / 3)),
    PVector.mult(perpendicular, -width / 2)
   ));
  
  Watercolor shape = new Watercolor(vertices);
  shape.shapeColor = shapeColor;
  return shape;
}

/**
* Represents a watercolor brush stroke with organic distortion capabilities
*/
class Watercolor {
  ArrayList<PVector> vertices;      
  float[] distortionFactors;       
  color shapeColor;                
  
  /**
  * Creates a brush stroke that can grow and distort organically
  */
  Watercolor(ArrayList<PVector> vertices) {
    this(vertices, null);
  }
  
  /**
  * Creates a new brush stroke with specified distortion
  * @param vertices Points defining the stroke shape
  * @param distortionFactors Controls vertex movement (null for default)
  */
  Watercolor(ArrayList<PVector> vertices, float[] distortionFactors) {
    this.vertices = vertices;
    if (distortionFactors == null) {
      this.distortionFactors = new float[vertices.size()];
      for (int i = 0; i < vertices.size(); i ++) {
        this.distortionFactors[i] = random(0.1, 0.8);
      }
    } else {
      this.distortionFactors = distortionFactors;
    }
  }
  
  /**
  * Creates a larger version of the stroke with natural variations
  */
  Watercolor grow() {
    ArrayList<PVector> expandedVertices = new ArrayList<PVector>();
    float[] newDistortions = new float[vertices.size() * 2];
    
    for (int i = 0; i < vertices.size(); i ++) {
      int nextIndex = (i + 1) % vertices.size();
      PVector currentPoint = vertices.get(i);
      PVector nextPoint = vertices.get(nextIndex);
      
      float distortion = distortionFactors[i];
      
      expandedVertices.add(currentPoint.copy());
      newDistortions[i * 2] = updateDistortion(distortion);
      
      PVector edgeVector = PVector.sub(nextPoint, currentPoint);
      float edgeLength = edgeVector.mag();
      edgeVector.mult(customRandom());
      
      PVector midPoint = PVector.add(edgeVector, currentPoint);
      
      edgeVector.rotate( -PI / 2 + (customRandom() - 0.5) * PI / 4);
      edgeVector.setMag(customRandom() * edgeLength / 2 * distortion);
      midPoint.add(edgeVector);
      
      expandedVertices.add(midPoint);
      newDistortions[i * 2 + 1] = updateDistortion(distortion);
    }
    return new Watercolor(expandedVertices, newDistortions);
  }
  
  /**
  * Updates a distortion factor with random variation
  * @param currentDistortion Current distortion value
  * @return New distortion value
  */
  float updateDistortion(float currentDistortion) {
    return currentDistortion + (customRandom() - 0.5) * 0.1;
  }
  
  /**
  * Creates an exact copy of this brush stroke
  * @return New Watercolor object with same properties
  */
  Watercolor duplicate() {
    ArrayList<PVector> newVerts = new ArrayList<PVector>();
    for (PVector v : vertices) {
      newVerts.add(v.copy());
    }
    float[] newMods = distortionFactors.clone();
    return new Watercolor(newVerts, newMods);
  }
  
  /**
  * Renders the brush stroke to the canvas
  */
  void draw() {
    beginShape();
    for (PVector point : vertices) {
      vertex(point.x, point.y);
    }
    endShape(CLOSE);
  }
}

/**
* Applies watercolor effect to a brush stroke
* @param shape Brush stroke to render
* @param paintColor Color to use for the stroke
*/
void waterColourEffect(Watercolor shape, color paintColor) {
  int numLayers = 12;  // Slightly fewer layers for more defined strokes
  fill(red(paintColor), green(paintColor), blue(paintColor), 255 / (2 * numLayers));
  noStroke();
  
  shape = shape.grow().grow();
  
  for (int i = 0; i < numLayers; i ++) {
    if (i == int(numLayers / 3) || i == int(2 * numLayers / 3)) {
      shape = shape.grow().grow();
    }
    
    shape.grow().draw();
  }  
}

/**
* Creates a custom random distribution for more natural-looking strokes
* @return Value between 0 and 1 with cubic distribution
*/
float customRandom() {
  return distribute(random(1));
}

/**
* Applies cubic distribution to create more natural randomness
* @param value Input value between 0 and 1
* @return Transformed value with emphasis on extremes
*/
float distribute(float value) {
  return pow((value - 0.5) * 1.58740105, 3) + 0.5;
}

/**
* Generates timestamp string for unique filenames
* @return Formatted string: YYYYMMDD_HHMMSS
*/
String getTimestamp() {
  return String.format("%d%02d%02d_%02d%02d%02d",
    year(), month(), day(),
    hour(), minute(), second()
   );
}

/**
* Applies Sobel edge detection to find edges and their directions
*/
PImage createEdgeImage() {
  PImage edges = createImage(width, height, RGB);
  originalImage.loadPixels();
  edges.loadPixels();
  
  for (int x = 1; x < width - 1; x++) {
    for (int y = 1; y < height - 1; y++) {
      // Sobel edge detection
      float gx = 0, gy = 0;
      
      for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
          int idx = (y + j) * width + (x + i);
          float val = brightness(originalImage.pixels[idx]);
          gx += val * sobelX(i, j);
          gy += val * sobelY(i, j);
        }
      }
      
      float mag = sqrt(gx * gx + gy * gy);
      float angle = atan2(gy, gx);
      
      edges.pixels[y * width + x] = color(mag, angle + PI, 255);
    }
  }
  edges.updatePixels();
  return edges;
}

/**
* Sobel operator for horizontal edges
*/
float sobelX(int x, int y) {
  int[][] kernel = {{ - 1,0,1} , { - 2,0,2} , { - 1,0,1} };
  return kernel[y + 1][x + 1];
}

/**
* Sobel operator for vertical edges
*/
float sobelY(int x, int y) {
  int[][] kernel = {{ - 1, -2, -1} , {0,0,0} , {1,2,1} };
  return kernel[y + 1][x + 1];
}




