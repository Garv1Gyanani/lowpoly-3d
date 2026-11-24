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

/// Precomputed per-frame camera basis & viewport projection constants.
/// Eliminates thousands of redundant trig/cross-product calls per frame.
class CameraFrame {
  const CameraFrame({
    required this.eye,
    required this.forward,
    required this.right,
    required this.up,
    required this.focalLength,
    required this.halfWidth,
    required this.halfHeight,
    required this.viewport,
  });

  final Vec3 eye;
  final Vec3 forward;
  final Vec3 right;
  final Vec3 up;
  final double focalLength;
  final double halfWidth;
  final double halfHeight;
  final Size viewport;

  static const double nearClipZ = 0.35;

  /// Transforms a world vertex into camera space `(cx, cy, cz)` where `cz` is depth forward.
  @pragma('vm:prefer-inline')
  Vec3 toCameraSpace(Vec3 world) {
    final rx = world.x - eye.x;
    final ry = world.y - eye.y;
    final rz = world.z - eye.z;
    return Vec3(
      rx * right.x + ry * right.y + rz * right.z,
      rx * up.x + ry * up.y + rz * up.z,
      rx * forward.x + ry * forward.y + rz * forward.z,
    );
  }

  @pragma('vm:prefer-inline')
  ProjectedPoint project(Vec3 world) {
    final rx = world.x - eye.x;
    final ry = world.y - eye.y;
    final rz = world.z - eye.z;
    final cz = rx * forward.x + ry * forward.y + rz * forward.z;
    if (cz <= nearClipZ) {
      return ProjectedPoint(Offset(halfWidth, halfHeight * 4.0), cz, inFront: false);
    }
    final cx = rx * right.x + ry * right.y + rz * right.z;
    final cy = rx * up.x + ry * up.y + rz * up.z;
    final invZ = focalLength / cz;
    return ProjectedPoint(
      Offset(halfWidth + cx * invZ, halfHeight - cy * invZ),
      cz,
      inFront: true,
    );
  }
}

/// True 3D perspective camera with zero roll (always keeps the desert horizon level),
/// responsive across both 9:16 portrait phones and 16:9 widescreen browsers,
/// with progressive stage framing as the outpost expands.
class Camera3D {
  Camera3D({
    this.yaw = defaultYaw,
    this.pitch = defaultPitch,
    this.distance = stageOneDistance,
    this.fovY = defaultFovY,
    this.target = stageOneTarget,
  });

  /// Horizontal azimuth (radians). Subtle tilt reveals 3D side faces cleanly.
  double yaw;

  /// Elevation angle above ground plane (radians).
  double pitch;

  /// Distance from target (controls zoom smoothly).
  double distance;

  /// Base vertical/reference field of view in radians (~34° telephoto diorama look).
  double fovY;

  /// World-space focus point.
  Vec3 target;

  /// Goal framing that eases smoothly as the player unlocks parking & landmarks,
  /// unless overridden by manual pan/zoom.
  double _goalDistance = stageOneDistance;
  Vec3 _goalTarget = stageOneTarget;
  bool _hasSmoothingGoal = false;

  static const double defaultYaw = -0.11;
  static const double defaultPitch = 0.275;
  static const double defaultDistance = 36.5;
  static const double stageOneDistance = 28.5;
  static const double defaultFovY = 0.60;
  static const Vec3 defaultTarget = Vec3(0.0, 3.9, 1.2);
  static const Vec3 stageOneTarget = Vec3(-1.1, 2.7, 5.4);

  static const double minDistance = 18.5;
  static const double maxDistance = 54.0;
  static const double minYaw = -0.48;
  static const double maxYaw = 0.34;

  /// Normalized zoom factor (1.0 at defaultDistance, >1 zoomed in, <1 zoomed out).
  double get zoom => defaultDistance / distance;
  set zoom(double z) {
    _hasSmoothingGoal = false;
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

  /// Responsive focal length that keeps the starter cart & outpost hero-sized on
  /// 16:9 widescreen browsers while fitting the town cleanly on 9:16 mobile portrait.
  double focalLength(Size viewport) {
    final w = viewport.width;
    final h = viewport.height;
    final double baseDim;
    if (w > h) {
      // Landscape / widescreen web: prevent ultra-wide FOV stretching so buildings stay chunky
      baseDim = math.max(h * 0.88, math.min(w * 0.58, h * 1.18));
    } else {
      // Portrait mobile: frame valley width while preserving Monument Valley sky
      baseDim = math.min(w, h * 0.58);
    }
    return baseDim / (2.0 * math.tan(fovY * 0.5));
  }

  CameraFrame createFrame(Size viewport) {
    final e = eye;
    final fwd = (target - e).normalized();
    final rgt = fwd.cross(Vec3.up).normalized();
    final u = rgt.cross(fwd).normalized();
    return CameraFrame(
      eye: e,
      forward: fwd,
      right: rgt,
      up: u,
      focalLength: focalLength(viewport),
      halfWidth: viewport.width * 0.5,
      halfHeight: viewport.height * 0.5,
      viewport: viewport,
    );
  }

  /// Projects a 3D world point to 2D canvas coordinates + distance along camera forward axis.
  ProjectedPoint project(Vec3 world, Size viewport) {
    return createFrame(viewport).project(world);
  }

  /// Exact Y screen coordinate of the mathematical 3D horizon line.
  double horizonScreenY(Size viewport) {
    final frame = createFrame(viewport);
    final horizDir = Vec3(frame.forward.x, 0.0, frame.forward.z).normalized();
    return frame.project(frame.eye + horizDir * 500.0).offset.dy;
  }

  /// Intersects a screen tap ray with the horizontal ground plane y = planeY.
  Vec3 screenToGround(Offset screen, Size viewport, {double planeY = 0.0}) {
    final frame = createFrame(viewport);
    final ndcX = (screen.dx - frame.halfWidth) / frame.focalLength;
    final ndcY = (frame.halfHeight - screen.dy) / frame.focalLength;
    final rayDir = (frame.forward + frame.right * ndcX + frame.up * ndcY).normalized();

    if (rayDir.y.abs() < 1e-5) return target;
    final t = (planeY - frame.eye.y) / rayDir.y;
    if (t <= 0) return target;
    return frame.eye + rayDir * t;
  }

  /// Pans the camera target across the desert valley floor within safe bounds.
  void panByScreenDelta(Offset delta, Size viewport) {
    _hasSmoothingGoal = false;
    final f = focalLength(viewport);
    final scale = distance / f;
    final rgt = right;
    final flatFwd = Vec3(forward.x, 0, forward.z).normalized();

    final moveRight = -delta.dx * scale * 0.85;
    final moveFwd = delta.dy * scale * 1.15;

    final next = target + rgt * moveRight + flatFwd * moveFwd;
    target = Vec3(
      next.x.clamp(-10.5, 10.5),
      target.y,
      next.z.clamp(-7.0, 9.0),
    );
  }

  /// Gently orbits horizontal camera azimuth within diorama-safe bounds.
  void orbitByDelta(double deltaRadians) {
    yaw = (yaw + deltaRadians).clamp(minYaw, maxYaw);
  }

  void zoomByFactor(double factor) {
    _hasSmoothingGoal = false;
    distance = (distance / factor).clamp(minDistance, maxDistance);
  }

  /// Sets cinematic stage framing goals as the outpost expands from a tiny cart to a full town.
  void setStageFraming({
    required int parkingTier,
    required int builtCount,
    bool immediate = false,
  }) {
    final (dist, tgt) = _computeStageFraming(parkingTier, builtCount);
    _goalDistance = dist;
    _goalTarget = tgt;
    if (immediate) {
      distance = dist;
      target = tgt;
      yaw = defaultYaw;
      pitch = defaultPitch;
      _hasSmoothingGoal = false;
    } else {
      _hasSmoothingGoal = true;
    }
  }

  void updateSmoothing(double dt) {
    if (!_hasSmoothingGoal) return;
    final t = (dt * 2.8).clamp(0.0, 1.0);
    distance = distance + (_goalDistance - distance) * t;
    target = target.lerp(_goalTarget, t);
    if ((distance - _goalDistance).abs() < 0.06 &&
        (target - _goalTarget).lengthSq < 0.004) {
      distance = _goalDistance;
      target = _goalTarget;
      _hasSmoothingGoal = false;
    }
  }

  static (double, Vec3) _computeStageFraming(int parkingTier, int builtCount) {
    if (parkingTier <= 0 && builtCount <= 1) {
      return (stageOneDistance, stageOneTarget);
    }
    if (parkingTier == 1 && builtCount <= 2) {
      return (32.5, const Vec3(-0.6, 3.2, 4.1));
    }
    if (builtCount <= 4 && parkingTier <= 2) {
      return (36.0, const Vec3(0.0, 3.7, 2.3));
    }
    return (39.2, defaultTarget);
  }

  void reset({int parkingTier = 3, int builtCount = 7}) {
    yaw = defaultYaw;
    pitch = defaultPitch;
    fovY = defaultFovY;
    setStageFraming(
      parkingTier: parkingTier,
      builtCount: builtCount,
      immediate: true,
    );
  }
}
