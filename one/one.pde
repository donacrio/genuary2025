float[] startPositions;  
float[] positions;      
float[] weights;
float[] shades;
boolean[] isVertical;
float[] periods;
float[] phases;
float[] amplitudes;
int numLines = 200;

float animationDuration = 1000;
float time;

void setup() {
  size(800, 800);
  strokeCap(SQUARE);
  
  startPositions = new float[numLines];
  positions = new float[numLines];
  weights = new float[numLines];
  shades = new float[numLines];
  isVertical = new boolean[numLines];
  periods = new float[numLines];
  phases = new float[numLines];
  amplitudes = new float[numLines];
  
  for (int i = 0; i < numLines; i++) {
    weights[i] = random(1, 8);
    shades[i] = random(50, 200);
    isVertical[i] = random(1) > 0.5;
    startPositions[i] = random(isVertical[i] ? width : height);
    periods[i] = random(1, 10);
    phases[i] = random(TWO_PI);
    amplitudes[i] = random(10, 25);
  }
}

void draw() {
  background(245, 242, 235);
  time = (frameCount % animationDuration) / animationDuration;
  
  for (int i = 0; i < numLines; i++) {
    strokeWeight(weights[i]);
    stroke(shades[i]);
    
    float offset = sin(phases[i] + time * TWO_PI * periods[i]) * amplitudes[i];
    positions[i] = startPositions[i] + offset;
    
    if (isVertical[i]) {
      line(positions[i], 0, positions[i], height);
    } else {
      line(0, positions[i], width, positions[i]);
    }
  }
}

void mousePressed() {
  String timestamp = year() + month() + day() + "_" + hour() + minute() + second();
  save("output/sketch_" + timestamp + ".png");
}
