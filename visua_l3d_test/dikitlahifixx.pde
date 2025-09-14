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

float altitude = 2.0; // meters
float windSpeed = 0.0; // km/h
String flightMode = "Manual";
String gpsStatus = "Ready";
boolean motorsRunning = false;
float batteryLevel = 99.5; // percentage
String simulatorStatus = "Simulator Ready";
boolean showLandingPad = true;

boolean isFullscreen = false;

void settings() {
  // Default: Custom size with P3D renderer
  size(1200, 800, P3D);
  
  // Uncomment salah satu opsi di bawah sesuai kebutuhan:
  
  // Opsi 1: Fullscreen
  // fullScreen(P3D);
  
  // Opsi 2: Ukuran custom lainnya
  // size(1600, 900, P3D);  // HD+
  // size(1920, 1080, P3D); // Full HD
}

void setup() {
  // Buat window bisa di-resize
  surface.setResizable(true);
  
  // Set posisi window di tengah layar
  surface.setLocation((displayWidth - width) / 2, (displayHeight - height) / 2);
  
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
  background(20, 30, 50); // Clear entire frame buffer first
  
  drawRealisticEnvironment(); // Enhanced environment
  
  setupLighting();
  
  drawGround();
  
  if (showLandingPad) {
    drawLandingPad(); // Added landing pad
  }
  
  // Pindah ke tengah layar
  translate(width/2, height/2 - 50, 0);
  
  rotateY(radians(smoothYaw));
  rotateX(radians(smoothPitch));
  rotateZ(radians(smoothRoll));
  
  propellerRotation += motorsRunning ? 15 : 2; // Conditional propeller speed
  
  // Gambar model drone
  drawRealisticDrone();
  
  drawSimulatorUI(); // Professional UI overlay
}

void drawRealisticEnvironment() {
  // Sky gradient (more realistic) - now draws over cleared background
  for (int i = 0; i <= height; i++) {
    float inter = map(i, 0, height, 0, 1);
    color c = lerpColor(color(135, 206, 250), color(34, 139, 34), inter); // Sky to grass
    stroke(c);
    line(0, i, width, i);
  }
  
  // Draw distant mountains
  drawMountains();
}

void drawMountains() {
  fill(80, 120, 80, 150);
  noStroke();
  
  // Mountain range
  beginShape();
  vertex(0, height * 0.4);
  vertex(width * 0.2, height * 0.3);
  vertex(width * 0.4, height * 0.35);
  vertex(width * 0.6, height * 0.25);
  vertex(width * 0.8, height * 0.4);
  vertex(width, height * 0.35);
  vertex(width, height);
  vertex(0, height);
  endShape(CLOSE);
}

void drawLandingPad() {
  pushMatrix();
  translate(width/2, height - 45, 0);
  rotateX(PI/2);
  
  // Yellow landing pad
  fill(255, 255, 0, 200);
  noStroke();
  ellipse(0, 0, 200, 200);
  
  // Landing pad markings
  stroke(0);
  strokeWeight(3);
  noFill();
  ellipse(0, 0, 180, 180);
  ellipse(0, 0, 160, 160);
  
  // Cross markings
  line(-80, 0, 80, 0);
  line(0, -80, 0, 80);
  
  // Corner markers
  fill(0);
  noStroke();
  for (int i = 0; i < 4; i++) {
    pushMatrix();
    rotate(i * PI/2);
    translate(70, 0);
    rect(-5, -15, 10, 30);
    popMatrix();
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

void drawSimulatorUI() {
  camera();
  hint(DISABLE_DEPTH_TEST);
  
  // Top status bar (like DJI interface)
  drawTopStatusBar();
  
  // Left side panel
  drawLeftPanel();
  
  // Right side controls
  drawRightControls();
  
  // Bottom flight data
  drawFlightData();
  
  drawAltitudeDisplay();
  
  hint(ENABLE_DEPTH_TEST);
}

void drawTopStatusBar() {
  fill(0, 0, 0, 180);
  noStroke();
  rect(0, 0, width, 60);
  
  fill(255);
  textAlign(LEFT);
  textSize(14);
  
  // Flight mode and GPS
  text("GPS: " + gpsStatus, 20, 25);
  text("Mode: " + flightMode, 20, 45);
  
  // Battery and time (center-right)
  textAlign(RIGHT);
  text("Battery: " + nf(batteryLevel, 1, 1) + "%", width - 20, 25);
  text("Flight Time: 00:00", width - 20, 45);
  
  // Center status
  textAlign(CENTER);
  textSize(16);
  fill(motorsRunning ? color(0, 255, 0) : color(255, 255, 0));
  text(simulatorStatus, width/2, 30);
}

void drawLeftPanel() {
  // Status messages panel
  fill(0, 0, 0, 150);
  noStroke();
  rect(20, 80, 300, 120);
  
  fill(0, 255, 0);
  textAlign(LEFT);
  textSize(12);
  
  // Status indicators
  ellipse(40, 110, 12, 12);
  fill(255);
  text("Tips", 60, 115);
  fill(200);
  text("Simulator Ready. Start Motors now", 60, 130);
  
  fill(0, 255, 0);
  ellipse(40, 150, 12, 12);
  fill(255);
  text("Tips", 60, 155);
  fill(200);
  text("Simulator Initializing", 60, 170);
  
  // Orientation data panel
  fill(0, 0, 0, 150);
  rect(20, 220, 250, 140);
  
  fill(255);
  textSize(14);
  text("Flight Data:", 30, 240);
  
  fill(100, 255, 100);
  textSize(12);
  text("Roll: " + nf(smoothRoll, 1, 1) + "°", 30, 260);
  text("Pitch: " + nf(smoothPitch, 1, 1) + "°", 30, 280);
  text("Yaw: " + nf(smoothYaw, 1, 1) + "°", 30, 300);
  
  fill(255, 255, 100);
  text("Altitude: " + nf(altitude, 1, 1) + " m", 30, 320);
  text("Wind: ↑ " + nf(windSpeed, 1, 1) + " km/h", 30, 340);
}

void drawRightControls() {
  // Control buttons panel
  fill(0, 0, 0, 150);
  noStroke();
  rect(width - 120, 100, 100, 200);
  
  // Gimbal controls
  fill(100, 100, 100);
  stroke(150);
  strokeWeight(1);
  ellipse(width - 70, 150, 40, 40);
  
  // Record button (red circle)
  fill(motorsRunning ? color(255, 0, 0) : color(100, 0, 0));
  noStroke();
  ellipse(width - 70, 220, 50, 50);
  
  // Additional control icons
  fill(255);
  textAlign(CENTER);
  textSize(10);
  text("REC", width - 70, 225);
}

void drawFlightData() {
  fill(0, 0, 0, 150);
  noStroke();
  rect(0, height - 80, width, 80);
  
  fill(255);
  textAlign(LEFT);
  textSize(12);
  
  // Distance scale
  text("0", 50, height - 20);
  text("50m", 150, height - 20);
  
  // Scale line
  stroke(255);
  strokeWeight(2);
  line(50, height - 30, 150, height - 30);
  
  // Wind indicator
  textAlign(CENTER);
  fill(255, 255, 0);
  text("Wind: ↑ " + nf(windSpeed, 1, 1) + " km/h", width/2 - 100, height - 40);
  
  // Restart button
  fill(100, 100, 100);
  stroke(150);
  strokeWeight(1);
  rect(width/2 + 50, height - 60, 80, 30);
  fill(255);
  noStroke();
  textAlign(CENTER);
  text("Restart", width/2 + 90, height - 42);
}

void drawAltitudeDisplay() {
  textAlign(CENTER);
  textSize(24);
  fill(255, 255, 255, 200);
  text(nf(altitude, 1, 1) + " m", width/2, height/2 + 150);
  
  // Altitude background
  fill(0, 0, 0, 100);
  noStroke();
  rect(width/2 - 40, height/2 + 130, 80, 30);
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
    simulatorStatus = "Recalibrating...";
    println("Kalibrasi direset - tekan untuk kalibrasi ulang");
  }
  if (key == 's' || key == 'S') {
    smoothingFactor = constrain(smoothingFactor + 0.05, 0.0, 0.95);
    println("Smoothing factor: " + smoothingFactor);
  }
  if (key == 'f' || key == 'F') {
    smoothingFactor = constrain(smoothingFactor - 0.05, 0.0, 0.95);
    println("Smoothing factor: " + smoothingFactor);
  }
  if (key == 'm' || key == 'M') {
    motorsRunning = !motorsRunning;
    simulatorStatus = motorsRunning ? "Motors Running" : "Motors Stopped";
    println("Motors: " + (motorsRunning ? "ON" : "OFF"));
  }
  if (key == 'p' || key == 'P') {
    showLandingPad = !showLandingPad;
    println("Landing pad: " + (showLandingPad ? "ON" : "OFF"));
  }
  if (key == 'F' && (keyPressed && (keyCode == SHIFT))) {
    if (!isFullscreen) {
      surface.setSize(displayWidth, displayHeight);
      surface.setLocation(0, 0);
      isFullscreen = true;
      println("Fullscreen ON");
    } else {
      surface.setSize(1200, 800);
      surface.setLocation((displayWidth - 1200) / 2, (displayHeight - 800) / 2);
      isFullscreen = false;
      println("Fullscreen OFF");
    }
  }
  if (key == 'r' || key == 'R') {
    surface.setSize(1200, 800);
    surface.setLocation((displayWidth - 1200) / 2, (displayHeight - 800) / 2);
    println("Window reset to default size");
  }
}

void setupLighting() {
  // Ambient light for overall illumination
  ambientLight(60, 60, 80);
  
  // Main directional light (sun)
  directionalLight(200, 200, 180, -0.5, 0.8, -0.3);
  
  // Secondary light from opposite direction (sky reflection)
  directionalLight(80, 100, 120, 0.3, -0.5, 0.2);
  
  // Point light for drone details
  pointLight(150, 150, 150, width/2, height/2 - 100, 100);
}

void drawGround() {
  pushMatrix();
  translate(width/2, height - 20, 0);
  rotateX(PI/2);
  
  // Ground plane with grass texture effect
  fill(34, 139, 34); // Forest green
  noStroke();
  rect(-width, -height, width*2, height*2);
  
  // Add some texture lines for grass effect
  stroke(28, 120, 28);
  strokeWeight(1);
  for (int i = -width; i < width; i += 20) {
    for (int j = -height; j < height; j += 15) {
      if (random(100) > 70) {
        line(i, j, i + random(-5, 5), j + random(-3, 3));
      }
    }
  }
  
  popMatrix();
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
