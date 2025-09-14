import processing.serial.*;

Serial myPort;
float roll, pitch, yaw;
float baseRoll, basePitch, baseYaw;
boolean calibrated = false;

void setup() {
  size(800, 600, P3D);
  myPort = new Serial(this, "/dev/ttyACM0", 115200); // sesuaikan port
}

void draw() {
  background(50);
  lights();

  translate(width/2, height/2, 0);
  rotateY(radians(yaw));
  rotateX(radians(pitch));
  rotateZ(radians(roll));

  // Drone body
  fill(100, 200, 255);
  box(150, 20, 150);

  // Drone arms
  fill(255, 0, 0);
  pushMatrix();
  translate(-75, 0, -75);
  sphere(20); // motor
  popMatrix();

  pushMatrix();
  translate(75, 0, -75);
  sphere(20);
  popMatrix();

  pushMatrix();
  translate(-75, 0, 75);
  sphere(20);
  popMatrix();

  pushMatrix();
  translate(75, 0, 75);
  sphere(20);
  popMatrix();
}

void serialEvent(Serial p) {
  String inData = p.readStringUntil('\n');
  if (inData != null) {
    inData = trim(inData);
    String[] values = split(inData, '\t'); // atau ',' sesuai Arduino
    if (values.length == 3) {
      float rawRoll  = float(values[0].split(": ")[1]);
      float rawPitch = float(values[1].split(": ")[1]);
      float rawYaw   = float(values[2].split(": ")[1]);

      if (!calibrated) {
        baseRoll = rawRoll;
        basePitch = rawPitch;
        baseYaw = rawYaw;
        calibrated = true;
      }

      roll = rawRoll - baseRoll;
      pitch = rawPitch - basePitch;
      yaw = rawYaw - baseYaw;
    }
  }
}
