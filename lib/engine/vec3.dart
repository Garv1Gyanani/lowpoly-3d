import 'dart:math' as math;

/// Lightweight immutable 3D vector for low-poly geometry & camera math.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const Vec3 zero = Vec3(0, 0, 0);
  static const Vec3 up = Vec3(0, 1, 0);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator /(double s) => Vec3(x / s, y / s, z / s);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get lengthSq => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSq);

  Vec3 normalized() {
    final len = length;
    if (len < 1e-7) return Vec3.up;
    return Vec3(x / len, y / len, z / len);
  }

  Vec3 rotateY(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec3(x * c - z * s, y, x * s + z * c);
  }

  Vec3 lerp(Vec3 other, double t) => Vec3(
        x + (other.x - x) * t,
        y + (other.y - y) * t,
        z + (other.z - z) * t,
      );
}
