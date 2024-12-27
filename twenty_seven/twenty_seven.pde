static int MAX_DIMENSION = 2400;
static int RADIUS = 5;
static int INTENSITY_LEVEL = 20;

PImage originalImg;
int canvasWidth, canvasHeight;

void settings() {
  originalImg = loadImage("images/input_3.png");
  float ratio = (float) originalImg.width / originalImg.height;
  
  if (ratio > 1) {
    canvasWidth = MAX_DIMENSION;
    canvasHeight = int(MAX_DIMENSION / ratio);
  } else {
    canvasHeight = MAX_DIMENSION;
    canvasWidth = int(MAX_DIMENSION * ratio);
  }
  size(canvasWidth, canvasHeight);
}

void setup() {
  originalImg.resize(canvasWidth, canvasHeight);
  originalImg.loadPixels();
  
  PImage img = createImage(canvasWidth, canvasHeight, RGB);
  img.loadPixels();
  
  for (int i = 0; i < canvasWidth; i++) {
    for (int j = 0; j < canvasHeight; j++) {
      int index = j * canvasWidth + i;
      img.pixels[index] = findPixelColor(originalImg.pixels, index, RADIUS);
    }
  }
  img.updatePixels();
  image(img, 0, 0);
  
  String timestamp = String.format("%d%02d%02d_%02d%02d%02d",
    year(), month(), day(),
    hour(), minute(), second()
   );
  save("output/oil_" + timestamp + ".png");
  noLoop();
}

color findPixelColor(color[] pixels, int index, int radius) {
  int[] intensityCount = new int[256];
  int[] averageR = new int[256];
  int[] averageG = new int[256];
  int[] averageB = new int[256];
  
  for (int k = -radius; k < radius; k++) {
    for (int l = -radius; l < radius; l++) {
      int curIndex = index + k + l * canvasWidth;
      if (curIndex > 0 && curIndex < pixels.length) {
        color c = pixels[curIndex];
        int curIntensity = (int)((double)((red(c) + green(c) + blue(c)) / 3) * INTENSITY_LEVEL) / 255;
        intensityCount[curIntensity]++;
        averageR[curIntensity] += red(c);
        averageG[curIntensity] += green(c);
        averageB[curIntensity] += blue(c);
      }
    }
  }
  int maxValue = Integer.MIN_VALUE;
  int maxIndex = 0;
  for (int k = 0; k < intensityCount.length; k++) {
    if (intensityCount[k] > maxValue) {
      maxValue = intensityCount[k];
      maxIndex = k;
    }
  }
  
  int finalR = averageR[maxIndex] / maxValue;
  int finalG = averageG[maxIndex] / maxValue;
  int finalB = averageB[maxIndex] / maxValue;
  return color(finalR, finalG, finalB);
}