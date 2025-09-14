#include "Wire.h"
#include "I2Cdev.h"
#include "MPU6050.h"

//=====================
// MPU6050 Object
//=====================
MPU6050 mpu(0x68);

//=====================
// Offsets hasil kalibrasi
//=====================
int16_t ax_offset = -7477;
int16_t ay_offset = -5665;
int16_t az_offset = 8937;
int16_t gx_offset = -28;
int16_t gy_offset = -21;
int16_t gz_offset = -71;

//=====================
// Variabel sensor
//=====================
int16_t ax, ay, az;
int16_t gx, gy, gz;

float roll, pitch, yaw;
float dt = 0.01; // timestep (s)
float alpha = 0.98; // komplementer filter

unsigned long timer;

void setup() {
  Wire.begin();
  Serial.begin(115200);

  mpu.initialize();
  Serial.println("MPU6050 initialized (skipping testConnection).");

  // Apply offsets
  mpu.setXAccelOffset(ax_offset);
  mpu.setYAccelOffset(ay_offset);
  mpu.setZAccelOffset(az_offset);
  mpu.setXGyroOffset(gx_offset);
  mpu.setYGyroOffset(gy_offset);
  mpu.setZGyroOffset(gz_offset);

  timer = micros();
}

void loop() {
  // Ambil data sensor
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

  // Convert gyro dari raw ke dps (±250°/s)
  float gyroXrate = gx / 131.0;
  float gyroYrate = gy / 131.0;
  float gyroZrate = gz / 131.0;

  // Convert accel ke g
  float accX = ax / 16384.0;
  float accY = ay / 16384.0;
  float accZ = az / 16384.0;

  // Hitung roll & pitch dari accelerometer
  float rollAcc  = atan2(accY, accZ) * 57.2958;
  float pitchAcc = atan(-accX / sqrt(accY*accY + accZ*accZ)) * 57.2958;

  // Hitung dt
  unsigned long now = micros();
  dt = (now - timer) / 1000000.0;
  timer = now;

  // Komplementer filter untuk roll & pitch
  roll  = alpha * (roll + gyroXrate * dt)  + (1 - alpha) * rollAcc;
  pitch = alpha * (pitch + gyroYrate * dt) + (1 - alpha) * pitchAcc;

  // Integrasi gyro untuk yaw (tanpa magnetometer)
  yaw += gyroZrate * dt;

  // Output ke Serial
  Serial.print("Roll: ");  Serial.print(roll, 2);
  Serial.print("\tPitch: "); Serial.print(pitch, 2);
  Serial.print("\tYaw: ");   Serial.println(yaw, 2);

  delay(10);
}
