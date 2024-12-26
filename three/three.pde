import java.util.Collections;
String[] codeLines; ArrayList<Character> allChars; ArrayList<Integer> currentIndices, lineStarts; int currentSize = 1, leftStart, totalChars;
void settings() {
  codeLines = loadStrings(sketchPath() + "/three.pde");
  int maxLineLength = 0;
  for (String line : codeLines) maxLineLength = max(maxLineLength, line.length());
  size(20 + maxLineLength * 7, 40 + codeLines.length * 15);
}
void setup() {
  textSize(12);
  allChars = new ArrayList<Character>(); currentIndices = new ArrayList<Integer>(); lineStarts = new ArrayList<Integer>(); 
  int currentPosition = 0;
  for (String line : codeLines) {
    lineStarts.add(currentPosition);
    for (char c : line.toCharArray()) {
      allChars.add(c);
      currentIndices.add(currentPosition);
      currentPosition++;
    }
  }
  totalChars = currentPosition;
  Collections.shuffle(currentIndices);
}
void draw() {
  background(0);
  fill(0, 255, 0);
  for (int i = 0; i < codeLines.length; i++) {
    for (int j = 0; j < ((i < codeLines.length - 1) ? lineStarts.get(i + 1) : totalChars) - lineStarts.get(i); j++) {
      for (int k = 0; k < totalChars; k++) if (currentIndices.get(k) == lineStarts.get(i) + j) { text(allChars.get(k), 10 + j * 7, 20 + i * 15); break; }
    }
  }
  merge(currentIndices, leftStart, min((leftStart += 2 * currentSize) - 2 * currentSize + currentSize, totalChars), min(leftStart, totalChars));
  if (leftStart >= totalChars) { leftStart = 0; currentSize *= 2; }
  saveFrame("output/frame-####.png");
  if (currentSize > 2 * totalChars) exit();
}
void merge(ArrayList<Integer> arr, int left, int mid, int right) {
  Integer[] L = new Integer[mid - left], R = new Integer[right - mid];
  for (int i = 0; i < L.length; i++) L[i] = arr.get(left + i);
  for (int j = 0; j < R.length; j++) R[j] = arr.get(mid + j);
  for (int i = 0, j = 0, k = left; k < right; k++) arr.set(k, i < L.length && (j >= R.length || L[i] <= R[j]) ? L[i++] : R[j++]);
}