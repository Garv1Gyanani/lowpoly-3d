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
class CameraFrame {
  CameraFrame({
    required this.eye,
    required this.forward,
    required this.right,
    required this.up,
    required this.focalLength,
    required this.halfWidth,
    required this.halfHeight,
    required this.viewport,
  })  : tanX = (halfWidth / focalLength) * 1.08,
        tanY = (halfHeight / focalLength) * 1.08 {
    invNormX = 1.0 / math.sqrt(1.0 + tanX * tanX);
    invNormY = 1.0 / math.sqrt(1.0 + tanY * tanY);
  }

  final Vec3 eye;
  final Vec3 forward;
  final Vec3 right;
  final Vec3 up;
  final double focalLength;
  final double halfWidth;
  final double halfHeight;
  final Size viewport;

  /// Frustum half-slopes (with a small safety margin) for sphere culling.
  final double tanX;
  final double tanY;
  late final double invNormX;
  late final double invNormY;

  static const double nearClipZ = 0.35;

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

  /// Returns true when a bounding sphere is completely outside the view frustum.
  @pragma('vm:prefer-inline')
  bool isSphereCulled(Vec3 center, double radius) {
    final rx = center.x - eye.x;
    final ry = center.y - eye.y;
    final rz = center.z - eye.z;
    final cz = rx * forward.x + ry * forward.y + rz * forward.z;
    if (cz + radius <= nearClipZ) return true;
    final cx = rx * right.x + ry * right.y + rz * right.z;
    if ((cx - cz * tanX) * invNormX > radius) return true;
    if ((-cx - cz * tanX) * invNormX > radius) return true;
    final cy = rx * up.x + ry * up.y + rz * up.z;
    if ((cy - cz * tanY) * invNormY > radius) return true;
    if ((-cy - cz * tanY) * invNormY > radius) return true;
    return false;
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

/// Free-roaming 3D orbit camera (full 360° yaw, adjustable tilt, wide zoom) with
/// smooth goal-based transitions for focus, rotate-by-90° and tilt presets.
class Camera3D {
  Camera3D({
    this.yaw = defaultYaw,
    this.pitch = defaultPitch,
    this.distance = stageOneDistance,
    this.fovY = defaultFovY,
    this.target = stageOneTarget,
  });

  double yaw;
  double pitch;
  double distance;
  double fovY;
  Vec3 target;

  double? _goalYaw;
  double? _goalPitch;
  double? _goalDistance;
  Vec3? _goalTarget;

  static const double defaultYaw = -0.11;
  static const double defaultPitch = 0.42;
  static const double defaultDistance = 36.5;
  static const double stageOneDistance = 26.0;
  static const double defaultFovY = 0.60;
  static const Vec3 defaultTarget = Vec3(0.0, 1.8, -16.0);
  static const Vec3 stageOneTarget = Vec3(-1.0, 1.6, -27.0);

  static const double minDistance = 12.0;
  static const double maxDistance = 110.0;
  static const double minPitch = 0.30;
  static const double maxPitch = 1.30;

  /// Tilt presets cycled by the VIEW button: cinematic -> isometric -> top-down build.
  static const List<double> pitchPresets = [0.42, 0.80, 1.20];

  /// Pan bounds (x = world X, y = world Z) covering the whole buildable desert + highway.
  Rect panBounds = const Rect.fromLTRB(-70, -124, 70, 24);

  bool get isAnimating =>
      _goalYaw != null || _goalPitch != null || _goalDistance != null || _goalTarget != null;

  double get zoom => defaultDistance / distance;
  set zoom(double z) {
    _goalDistance = null;
    distance = (defaultDistance / z).clamp(minDistance, maxDistance);
  }

  Vec3 get eye {
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    return target + Vec3(sy * cp * distance, sp * distance, cy * cp * distance);
  }

  Vec3 get forward => (target - eye).normalized();
  Vec3 get right => forward.cross(Vec3.up).normalized();
  Vec3 get up => right.cross(forward).normalized();

  double focalLength(Size viewport) {
    final w = viewport.width;
    final h = viewport.height;
    final double baseDim;
    if (w > h) {
      baseDim = math.max(h * 0.88, math.min(w * 0.58, h * 1.18));
    } else {
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

  ProjectedPoint project(Vec3 world, Size viewport) => createFrame(viewport).project(world);

  double horizonScreenY(Size viewport) {
    final frame = createFrame(viewport);
    final horizDir = Vec3(frame.forward.x, 0.0, frame.forward.z).normalized();
    return frame.project(frame.eye + horizDir * 500.0).offset.dy;
  }

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

  Vec3 _clampTarget(Vec3 t) => Vec3(
        t.x.clamp(panBounds.left, panBounds.right),
        t.y,
        t.z.clamp(panBounds.top, panBounds.bottom),
      );

  void panByScreenDelta(Offset delta, Size viewport) {
    _goalTarget = null;
    final f = focalLength(viewport);
    final scale = distance / f;
    final rgt = right;
    final flatFwd = Vec3(forward.x, 0, forward.z).normalized();
    // Steeper tilt -> screen-vertical drags map more directly to ground movement.
    final fwdGain = 1.0 / math.max(0.35, math.sin(pitch));
    final moveRight = -delta.dx * scale;
    final moveFwd = delta.dy * scale * fwdGain;
    target = _clampTarget(target + rgt * moveRight + flatFwd * moveFwd);
  }

  /// Pans relative to the current view heading (keyboard WASD / arrow keys).
  void panRelative(double rightUnits, double forwardUnits) {
    _goalTarget = null;
    final flatFwd = Vec3(forward.x, 0, forward.z).normalized();
    target = _clampTarget(target + right * rightUnits + flatFwd * forwardUnits);
  }

  void orbitByDelta(double deltaRadians) {
    _goalYaw = null;
    yaw = _wrapAngle(yaw + deltaRadians);
  }

  void tiltByDelta(double deltaRadians) {
    _goalPitch = null;
    pitch = (pitch + deltaRadians).clamp(minPitch, maxPitch);
  }

  void zoomByFactor(double factor) {
    _goalDistance = null;
    distance = (distance / factor).clamp(minDistance, maxDistance);
  }

  /// Smoothly rotates the view by ±90° around the current focus point.
  void rotateQuarter(int direction) {
    final base = _goalYaw ?? yaw;
    _goalYaw = base + direction * math.pi * 0.5;
  }

  /// Cycles cinematic -> isometric -> top-down tilt presets.
  void cyclePitchPreset() {
    final current = _goalPitch ?? pitch;
    double next = pitchPresets.first;
    for (final p in pitchPresets) {
      if (p > current + 0.05) {
        next = p;
        break;
      }
    }
    _goalPitch = next;
  }

  /// Ensures the view is at least [minimum] tilt (used by build tools for readable grids).
  void ensureMinPitch(double minimum) {
    if ((_goalPitch ?? pitch) < minimum) _goalPitch = minimum;
  }

  void focusOn(
    Vec3 newTarget, {
    double? distance,
    double? pitch,
    double? yaw,
    bool immediate = false,
  }) {
    final t = _clampTarget(newTarget);
    if (immediate) {
      target = t;
      if (distance != null) this.distance = distance.clamp(minDistance, maxDistance);
      if (pitch != null) this.pitch = pitch.clamp(minPitch, maxPitch);
      if (yaw != null) this.yaw = yaw;
      _goalTarget = null;
      _goalDistance = null;
      _goalPitch = null;
      _goalYaw = null;
      return;
    }
    _goalTarget = t;
    if (distance != null) _goalDistance = distance.clamp(minDistance, maxDistance);
    if (pitch != null) _goalPitch = pitch.clamp(minPitch, maxPitch);
    if (yaw != null) _goalYaw = yaw;
  }

  void updateSmoothing(double dt) {
    if (!isAnimating) return;
    final t = (dt * 4.2).clamp(0.0, 1.0);

    final gy = _goalYaw;
    if (gy != null) {
      final diff = gy - yaw;
      if (diff.abs() < 0.002) {
        yaw = _wrapAngle(gy);
        _goalYaw = null;
      } else {
        yaw += diff * t;
      }
    }
    final gp = _goalPitch;
    if (gp != null) {
      if ((gp - pitch).abs() < 0.002) {
        pitch = gp;
        _goalPitch = null;
      } else {
        pitch += (gp - pitch) * t;
      }
    }
    final gd = _goalDistance;
    if (gd != null) {
      if ((gd - distance).abs() < 0.05) {
        distance = gd;
        _goalDistance = null;
      } else {
        distance += (gd - distance) * t;
      }
    }
    final gt = _goalTarget;
    if (gt != null) {
      if ((gt - target).lengthSq < 0.003) {
        target = gt;
        _goalTarget = null;
      } else {
        target = target.lerp(gt, t);
      }
    }
  }

  void reset({Vec3 target = stageOneTarget, double distance = stageOneDistance}) {
    fovY = defaultFovY;
    focusOn(
      target,
      distance: distance,
      pitch: defaultPitch,
      yaw: defaultYaw,
      immediate: true,
    );
  }

  static double _wrapAngle(double a) {
    const twoPi = math.pi * 2.0;
    double r = a % twoPi;
    if (r > math.pi) r -= twoPi;
    if (r < -math.pi) r += twoPi;
    return r;
  }
}
