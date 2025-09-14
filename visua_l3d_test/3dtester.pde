import processing.serial.*;

Serial myPort;
float roll = 0, pitch = 0, yaw = 0;

void setup() {
  size(800, 600, P3D);
  println(Serial.list()); 
  
  // Ganti index sesuai hasil Serial.list(), biasanya [0] = "/dev/ttyACM0"
  myPort = new Serial(this, Serial.list()[0], 115200);  
  myPort.bufferUntil('\n');
}

void draw() {
  background(30);
  lights();
  
  translate(width/2, height/2, 0);
  
  // Rotasi drone sesuai data dari Arduino
  rotateX(radians(pitch));
  rotateY(radians(yaw));
  rotateZ(radians(roll));
  
  // Badan drone (kotak)
  fill(100, 150, 255);
  box(60, 10, 200);
  
  // Lengan drone (X-axis)
  pushMatrix();
  rotateZ(HALF_PI);
  fill(255, 100, 100);
  box(200, 10, 60);
  popMatrix();
  
  // Motor (lingkaran kecil di ujung-ujung)
  drawMotor(100, 0, 0);
  drawMotor(-100, 0, 0);
  drawMotor(0, 0, 100);
  drawMotor(0, 0, -100);
}

void drawMotor(float x, float y, float z) {
  pushMatrix();
  translate(x, y, z);
  fill(0, 200, 0);
  sphere(20);
  popMatrix();
}

void serialEvent(Serial myPort) {
  String data = trim(myPort.readStringUntil('\n'));
  if (data != null) {
    String[] values = split(data, ',');
    if (values.length == 3) {
      roll = float(values[0]);
      pitch = float(values[1]);
      yaw = float(values[2]);
    }
  }
}
