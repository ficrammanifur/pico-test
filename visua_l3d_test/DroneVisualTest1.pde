import processing.serial.*;

Serial myPort;
float roll, pitch, yaw;
float baseRoll, basePitch, baseYaw;
boolean calibrated = false;
float propellerRotation = 0; // Added propeller rotation animation

float smoothRoll, smoothPitch, smoothYaw;
float smoothingFactor = 0.85; // Higher = more smoothing (0.0-1.0)
float[] rollHistory = new float[5];
float[] pitchHistory = new float[5];
float[] yawHistory = new float[5];
int historyIndex = 0;

float previousYaw = 0;
float yawOffset = 0;

void setup() {
  size(800, 600, P3D);
  
  // Tampilkan daftar port serial yang tersedia
  println("Port tersedia: ");
  println(Serial.list());
  
  // Gunakan port /dev/ttyACM0
  try {
    myPort = new Serial(this, "/dev/ttyACM0", 115200);
    myPort.bufferUntil('\n');
    println("Berhasil terhubung ke /dev/ttyACM0");
  } catch (Exception e) {
    println("Gagal membuka port /dev/ttyACM0: " + e.getMessage());
    exit();
  }
  
  for (int i = 0; i < 5; i++) {
    rollHistory[i] = 0;
    pitchHistory[i] = 0;
    yawHistory[i] = 0;
  }
  
  background(20, 30, 50); // Dark blue sky background for realism
}

void draw() {
  drawSkyGradient();
  
  setupLighting();
  
  drawGround();
  
  // Pindah ke tengah layar
  translate(width/2, height/2 - 50, 0);
  
  rotateY(radians(smoothYaw));
  rotateX(radians(smoothPitch));
  rotateZ(radians(smoothRoll));
  
  propellerRotation += 15; // Fast rotation
  
  // Gambar model drone
  drawRealisticDrone();
  
  drawOrientationInfo();
}

void drawSkyGradient() {
  for (int i = 0; i <= height; i++) {
    float inter = map(i, 0, height, 0, 1);
    color c = lerpColor(color(135, 206, 250), color(25, 25, 112), inter); // Sky blue to midnight blue
    stroke(c);
    line(0, i, width, i);
  }
}

void setupLighting() {
  // Main directional light (sun)
  directionalLight(255, 255, 240, -0.5, 0.8, -0.3);
  
  // Ambient light for overall illumination
  ambientLight(80, 90, 120);
  
  // Point light for drone details
  pointLight(255, 255, 255, width/2, height/2 - 200, 200);
}

void drawGround() {
  pushMatrix();
  translate(width/2, height - 50, 0);
  rotateX(PI/2);
  fill(34, 139, 34, 150); // Semi-transparent green
  noStroke();
  rect(-400, -400, 800, 800);
  
  // Grid lines on ground
  stroke(255, 255, 255, 50);
  for (int i = -400; i <= 400; i += 50) {
    line(i, -400, i, 400);
    line(-400, i, 400, i);
  }
  popMatrix();
}

void serialEvent(Serial p) {
  String inData = p.readStringUntil('\n');
  if (inData != null) {
    inData = trim(inData);
    String[] values = split(inData, '\t'); // Split berdasarkan tab
    if (values.length == 3) {
      try {
        float rawRoll = float(values[0].split(": ")[1]);
        float rawPitch = float(values[1].split(": ")[1]);
        float rawYaw = float(values[2].split(": ")[1]);
        
        // Simpan data pertama sebagai baseline (referensi nol)
        if (!calibrated) {
          baseRoll = rawRoll;
          basePitch = rawPitch;
          baseYaw = rawYaw;
          calibrated = true;
          println("Baseline disimpan: Roll=" + baseRoll + ", Pitch=" + basePitch + ", Yaw=" + baseYaw);
        }
        
        // Kurangi baseline untuk posisi netral
        float correctedRoll = rawRoll - baseRoll;
        float correctedPitch = rawPitch - basePitch;
        float correctedYaw = rawYaw - baseYaw;
        
        correctedYaw = normalizeAngle(correctedYaw);
        
        rollHistory[historyIndex] = correctedRoll;
        pitchHistory[historyIndex] = correctedPitch;
        yawHistory[historyIndex] = correctedYaw;
        historyIndex = (historyIndex + 1) % 5;
        
        float avgRoll = average(rollHistory);
        float avgPitch = average(pitchHistory);
        float avgYaw = average(yawHistory);
        
        smoothRoll = lerp(smoothRoll, avgRoll, 1.0 - smoothingFactor);
        smoothPitch = lerp(smoothPitch, avgPitch, 1.0 - smoothingFactor);
        smoothYaw = lerp(smoothYaw, avgYaw, 1.0 - smoothingFactor);
        
        // Update raw values for display
        roll = correctedRoll;
        pitch = correctedPitch;
        yaw = correctedYaw;
        
        println("Data terkoreksi - Roll: " + roll + ", Pitch: " + pitch + ", Yaw: " + yaw);
      } catch (Exception e) {
        println("Error parsing serial data: " + e.getMessage());
      }
    }
  }
}

void drawRealisticDrone() {
  // Main body (sleek, modern design)
  fill(45, 45, 45); // Dark gray metallic
  stroke(80, 80, 80);
  strokeWeight(1);
  
  pushMatrix();
  // Central body - more aerodynamic shape
  translate(0, 0, 0);
  scale(1.2, 0.3, 0.8);
  box(100, 25, 80);
  popMatrix();
  
  // Battery compartment (bottom)
  fill(30, 30, 30);
  pushMatrix();
  translate(0, 8, 0);
  scale(0.8, 0.4, 0.6);
  box(80, 15, 60);
  popMatrix();
  
  // Camera gimbal (realistic 3-axis gimbal)
  drawCameraGimbal();
  
  // Arms (carbon fiber look)
  fill(20, 20, 20);
  stroke(40, 40, 40);
  strokeWeight(2);
  
  // Front right arm
  pushMatrix();
  translate(60, 0, -60);
  rotateY(PI/4);
  scale(1.5, 0.15, 0.15);
  box(80, 8, 8);
  popMatrix();
  
  // Front left arm
  pushMatrix();
  translate(-60, 0, -60);
  rotateY(-PI/4);
  scale(1.5, 0.15, 0.15);
  box(80, 8, 8);
  popMatrix();
  
  // Back right arm
  pushMatrix();
  translate(60, 0, 60);
  rotateY(-PI/4);
  scale(1.5, 0.15, 0.15);
  box(80, 8, 8);
  popMatrix();
  
  // Back left arm
  pushMatrix();
  translate(-60, 0, 60);
  rotateY(PI/4);
  scale(1.5, 0.15, 0.15);
  box(80, 8, 8);
  popMatrix();
  
  // Motors (detailed brushless motors)
  drawMotors();
  
  // Propellers (with rotation animation)
  drawPropellers();
  
  // LED lights (navigation lights)
  drawLEDLights();
  
  // Antennas
  drawAntennas();
}

void drawCameraGimbal() {
  pushMatrix();
  translate(0, 20, 0);
  
  // Gimbal frame
  fill(60, 60, 60);
  stroke(100, 100, 100);
  strokeWeight(1);
  
  // Outer gimbal ring
  pushMatrix();
  rotateX(PI/2);
  noFill();
  strokeWeight(3);
  ellipse(0, 0, 40, 40);
  popMatrix();
  
  // Camera body
  fill(25, 25, 25);
  pushMatrix();
  translate(0, 0, 0);
  box(20, 15, 25);
  popMatrix();
  
  // Camera lens
  fill(10, 10, 10);
  pushMatrix();
  translate(0, 0, -15);
  cylinder(8, 10);
  popMatrix();
  
  popMatrix();
}

void drawMotors() {
  fill(80, 80, 80); // Aluminum color
  stroke(120, 120, 120);
  strokeWeight(1);
  
  float[] motorX = {85, -85, -85, 85};
  float[] motorZ = {-85, -85, 85, 85};
  
  for (int i = 0; i < 4; i++) {
    pushMatrix();
    translate(motorX[i], -8, motorZ[i]);
    
    // Motor housing
    cylinder(12, 20);
    
    // Motor top cap
    fill(100, 100, 100);
    pushMatrix();
    translate(0, -12, 0);
    cylinder(10, 3);
    popMatrix();
    
    // Motor mount
    fill(50, 50, 50);
    pushMatrix();
    translate(0, 5, 0);
    cylinder(15, 8);
    popMatrix();
    
    popMatrix();
  }
}

void drawPropellers() {
  float[] motorX = {85, -85, -85, 85};
  float[] motorZ = {-85, -85, 85, 85};
  boolean[] clockwise = {true, false, true, false}; // Alternating rotation
  
  for (int i = 0; i < 4; i++) {
    pushMatrix();
    translate(motorX[i], -20, motorZ[i]);
    
    // Rotate propellers
    float rotation = clockwise[i] ? propellerRotation : -propellerRotation;
    rotateY(radians(rotation));
    
    // Propeller blades (2-blade design)
    fill(220, 220, 220, 180); // Semi-transparent white
    stroke(200, 200, 200);
    strokeWeight(1);
    
    // Blade 1
    pushMatrix();
    rotateZ(PI/12); // Slight pitch angle
    scale(1, 0.05, 0.15);
    box(60, 2, 8);
    popMatrix();
    
    // Blade 2 (opposite)
    pushMatrix();
    rotateY(PI);
    rotateZ(PI/12);
    scale(1, 0.05, 0.15);
    box(60, 2, 8);
    popMatrix();
    
    // Propeller hub
    fill(100, 100, 100);
    noStroke();
    cylinder(4, 6);
    
    popMatrix();
  }
}

void drawLEDLights() {
  // Front LEDs (white)
  fill(255, 255, 255, 200);
  noStroke();
  pushMatrix();
  translate(0, -5, -45);
  sphere(3);
  popMatrix();
  
  // Rear LED (red)
  fill(255, 50, 50, 200);
  pushMatrix();
  translate(0, -5, 45);
  sphere(3);
  popMatrix();
  
  // Side LEDs (green - right, red - left)
  fill(50, 255, 50, 200); // Green - right
  pushMatrix();
  translate(45, -5, 0);
  sphere(2);
  popMatrix();
  
  fill(255, 50, 50, 200); // Red - left
  pushMatrix();
  translate(-45, -5, 0);
  sphere(2);
  popMatrix();
}

void drawAntennas() {
  stroke(150, 150, 150);
  strokeWeight(2);
  
  // GPS antenna
  pushMatrix();
  translate(0, -15, 20);
  line(0, 0, 0, 0, -25, 0);
  // GPS antenna tip
  fill(255, 200, 0);
  noStroke();
  translate(0, -25, 0);
  sphere(2);
  popMatrix();
  
  // RC receiver antenna
  stroke(100, 100, 100);
  strokeWeight(1);
  pushMatrix();
  translate(-20, -10, -30);
  line(0, 0, 0, 0, -20, 0);
  popMatrix();
}

void drawOrientationInfo() {
  // Reset transformations for UI
  camera();
  hint(DISABLE_DEPTH_TEST);
  
  fill(0, 0, 0, 150);
  noStroke();
  rect(10, 10, 250, 120); // Made info panel larger
  
  fill(255);
  textSize(14);
  textAlign(LEFT);
  
  text("Raw - Roll: " + nf(roll, 1, 1) + "°", 20, 30);
  text("Raw - Pitch: " + nf(pitch, 1, 1) + "°", 20, 50);
  text("Raw - Yaw: " + nf(yaw, 1, 1) + "°", 20, 70);
  
  fill(100, 255, 100);
  text("Smooth - Roll: " + nf(smoothRoll, 1, 1) + "°", 20, 95);
  text("Smooth - Pitch: " + nf(smoothPitch, 1, 1) + "°", 20, 115);
  
  if (calibrated) {
    fill(0, 255, 0);
    text("CALIBRATED", 180, 30);
  } else {
    fill(255, 255, 0);
    text("CALIBRATING...", 180, 30);
  }
  
  fill(200, 200, 255);
  textSize(10);
  text("C: Recalibrate | S/F: Adjust smoothing", 20, 140);
  text("Smoothing: " + nf(smoothingFactor, 1, 2), 20, 155);
  
  hint(ENABLE_DEPTH_TEST);
}

void cylinder(float radius, float height) {
  int sides = 12;
  float angle = TWO_PI / sides;
  
  // Draw cylinder
  beginShape(TRIANGLES);
  for (int i = 0; i < sides; i++) {
    float x1 = cos(i * angle) * radius;
    float z1 = sin(i * angle) * radius;
    float x2 = cos((i + 1) * angle) * radius;
    float z2 = sin((i + 1) * angle) * radius;
    
    // Side faces
    vertex(x1, -height/2, z1);
    vertex(x2, -height/2, z2);
    vertex(x1, height/2, z1);
    
    vertex(x2, -height/2, z2);
    vertex(x2, height/2, z2);
    vertex(x1, height/2, z1);
  }
  endShape();
}

void stop() {
  if (myPort != null) {
    myPort.stop();
    println("Port serial ditutup");
  }
}

float average(float[] array) {
  float sum = 0;
  for (float value : array) {
    sum += value;
  }
  return sum / array.length;
}

float normalizeAngle(float angle) {
  // Keep angle between -180 and 180 degrees
  while (angle > 180) angle -= 360;
  while (angle < -180) angle += 360;
  return angle;
}

void keyPressed() {
  if (key == 'c' || key == 'C') {
    calibrated = false;
    smoothRoll = smoothPitch = smoothYaw = 0;
    println("Kalibrasi direset - tekan untuk kalibrasi ulang");
  }
  if (key == 's' || key == 'S') {
    // Adjust smoothing factor
    smoothingFactor = constrain(smoothingFactor + 0.05, 0.0, 0.95);
    println("Smoothing factor: " + smoothingFactor);
  }
  if (key == 'f' || key == 'F') {
    // Decrease smoothing (faster response)
    smoothingFactor = constrain(smoothingFactor - 0.05, 0.0, 0.95);
    println("Smoothing factor: " + smoothingFactor);
  }
}
