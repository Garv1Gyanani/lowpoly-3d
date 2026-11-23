import 'dart:math' as math;
import 'dart:ui';

import 'vec3.dart';

/// Projected 2D point + camera-space depth (larger depth = further from camera).
class ProjectedPoint {
  const ProjectedPoint(this.offset, this.depth, {this.inFront = true});

  final Offset offset;
  final double depth;
  final bool inFront;
}

/// True 3D perspective camera with zero roll (always keeps the desert horizon level)
/// tailored for a portrait 9:16 Monument Valley diorama.
class Camera3D {
  Camera3D({
    this.yaw = defaultYaw,
    this.pitch = defaultPitch,
    this.distance = defaultDistance,
    this.fovY = defaultFovY,
    this.target = defaultTarget,
  });

  /// Subtle horizontal azimuth so buildings show crisp 3D side faces while keeping horizon level.
  double yaw;

  /// Elevation angle above ground plane (radians).
  double pitch;

  /// Distance from target (controls zoom smoothly).
  double distance;

  /// Vertical field of view in radians (~34° telephoto diorama look).
  double fovY;

  /// World-space focus point.
  Vec3 target;

  static const double defaultYaw = -0.09;
  static const double defaultPitch = 0.27;
  static const double defaultDistance = 39.5;
  static const double defaultFovY = 0.62; // horizontal FOV (~35.5 deg) on portrait screens
  static const Vec3 defaultTarget = Vec3(0.0, 4.4, 0.5);

  static const double minDistance = 24.0;
  static const double maxDistance = 54.0;

  /// Normalized zoom factor (1.0 at defaultDistance, >1 zoomed in, <1 zoomed out).
  double get zoom => defaultDistance / distance;
  set zoom(double z) {
    distance = (defaultDistance / z).clamp(minDistance, maxDistance);
  }

  Vec3 get eye {
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    return target + Vec3(sy * cp * distance, sp * distance, cy * cp * distance);
  }

  /// Unit vector from camera eye toward target (into the screen).
  Vec3 get forward => (target - eye).normalized();

  /// Camera right vector (always strictly horizontal -> guaranteed level horizon!).
  Vec3 get right => forward.cross(Vec3.up).normalized();

  /// Camera up vector.
  Vec3 get up => right.cross(forward).normalized();

  double focalLength(Size viewport) {
    // Compute focal length from horizontal width on portrait screens so the entire
    // 26-unit desert town fits edge-to-edge while preserving tall sky + Monument Valley vista!
    final baseDim = math.min(viewport.width, viewport.height * 0.52);
    return baseDim / (2.0 * math.tan(fovY * 0.5));
  }

  /// Projects a 3D world point to 2D canvas coordinates + distance along camera forward axis.
  ProjectedPoint project(Vec3 world, Size viewport) {
    final e = eye;
    final fwd = forward;
    final rgt = right;
    final u = up;

    final rel = world - e;
    final cz = rel.dot(fwd);
    if (cz <= 0.35) {
      return ProjectedPoint(
        Offset(viewport.width * 0.5, viewport.height * 2.0),
        cz,
        inFront: false,
      );
    }

    final cx = rel.dot(rgt);
    final cy = rel.dot(u);
    final f = focalLength(viewport);

    final sx = viewport.width * 0.5 + (cx / cz) * f;
    final sy = viewport.height * 0.5 - (cy / cz) * f;
    return ProjectedPoint(Offset(sx, sy), cz, inFront: true);
  }

  /// Exact Y screen coordinate of the mathematical 3D horizon line.
  double horizonScreenY(Size viewport) {
    final fwd = forward;
    final horizDir = Vec3(fwd.x, 0.0, fwd.z).normalized();
    return project(eye + horizDir * 500.0, viewport).offset.dy;
  }

  /// Intersects a screen tap ray with the horizontal ground plane y = planeY.
  Vec3 screenToGround(Offset screen, Size viewport, {double planeY = 0.0}) {
    final f = focalLength(viewport);
    final ndcX = (screen.dx - viewport.width * 0.5) / f;
    final ndcY = (viewport.height * 0.5 - screen.dy) / f;
    final rayDir = (forward + right * ndcX + up * ndcY).normalized();

    if (rayDir.y.abs() < 1e-5) return target;
    final e = eye;
    final t = (planeY - e.y) / rayDir.y;
    if (t <= 0) return target;
    return e + rayDir * t;
  }

  /// Pans the camera target across the desert valley floor within safe bounds.
  void panByScreenDelta(Offset delta, Size viewport) {
    final f = focalLength(viewport);
    final scale = distance / f;
    final rgt = right;
    final flatFwd = Vec3(forward.x, 0, forward.z).normalized();

    final moveRight = -delta.dx * scale * 0.85;
    final moveFwd = delta.dy * scale * 1.15;

    final next = target + rgt * moveRight + flatFwd * moveFwd;
    target = Vec3(
      next.x.clamp(-9.5, 9.5),
      defaultTarget.y,
      next.z.clamp(-6.5, 8.5),
    );
  }

  void zoomByFactor(double factor) {
    distance = (distance / factor).clamp(minDistance, maxDistance);
  }

  void reset() {
    yaw = defaultYaw;
    pitch = defaultPitch;
    distance = defaultDistance;
    fovY = defaultFovY;
    target = defaultTarget;
  }
}
