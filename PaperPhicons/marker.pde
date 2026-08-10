class Marker {
  int[][] payload;

  Marker() {
    payload = new int[5][5]; // Initializes a 4x4 array of integers
  }

  // Method to set values in the payload
  void setPayload(int[][] newPayload) {
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        payload[i][j] = newPayload[i][j];
      }
    }
  }

  // Method to print the payload for debugging
  void displayPayload() {
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        print(payload[i][j] + " ");
      }
      println(); // Moves to the next line after each row
    }
  }
}
