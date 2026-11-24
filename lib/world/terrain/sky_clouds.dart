import 'dart:math' as math;

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Luminous faceted 3D low-poly desert clouds floating high above the distant
/// Monument Valley skyline (kept beyond the buildable desert so they never block
/// the top-down build view).
class SkyClouds {
  const SkyClouds._();

  static void build(
    MeshBuilder mesh,
    DesertLighting lighting,
    double animTime,
  ) {
    final drift = math.sin(animTime * 0.05) * 6.0;

    final puffs = [
      (Vec3(30.0 + drift, 62.0, -250.0), 13.0, 4.0, 6.8, 7),
      (Vec3(46.0 + drift, 65.0, -252.0), 15.0, 6.0, 7.6, 7),
      (Vec3(64.0 + drift, 68.0, -255.0), 17.0, 8.4, 8.6, 7),
      (Vec3(82.0 + drift, 65.0, -254.0), 15.0, 6.6, 7.8, 7),
      (Vec3(-70.0 + drift * 0.6, 63.0, -262.0), 14.0, 4.2, 6.6, 6),
      (Vec3(-54.0 + drift * 0.6, 65.0, -264.0), 12.5, 5.0, 6.0, 6),
      (Vec3(-140.0 + drift * 0.4, 58.0, -230.0), 13.0, 4.4, 6.4, 6),
      (Vec3(150.0 + drift * 0.4, 60.0, -220.0), 12.0, 4.0, 6.0, 6),
    ];
    for (final (pos, rx, h, rz, sides) in puffs) {
      mesh.addFrustum(
        pos.x,
        pos.y,
        pos.z,
        rx,
        rz,
        rx * 0.66,
        rz * 0.66,
        h,
        sides,
        DesertPalette.cloudSunlit,
        topColor: DesertPalette.cloudSunlit,
        layer: RenderLayer.world,
        isCloud: true,
        distanceFade: 0.10,
      );
    }
  }
}
