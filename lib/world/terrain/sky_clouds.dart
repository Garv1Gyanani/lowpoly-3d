import 'dart:math' as math;

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Luminous faceted 3D low-poly desert clouds floating high above Monument Valley.
/// Uses `isCloud: true` subsurface bounce shading so undersides stay warm and airy in front of the sun!
class SkyClouds {
  const SkyClouds._();

  static void build(
    MeshBuilder mesh,
    DesertLighting lighting,
    double animTime,
  ) {
    final drift = math.sin(animTime * 0.08) * 2.4;

    final rightPuffs = [
      (Vec3(8.5 + drift, 26.8, -62.0), 5.6, 1.7, 2.9),
      (Vec3(15.2 + drift, 28.2, -63.0), 6.6, 2.7, 3.4),
      (Vec3(23.0 + drift, 30.0, -64.0), 7.6, 3.8, 3.9),
      (Vec3(31.2 + drift, 28.8, -63.5), 6.8, 3.0, 3.5),
    ];
    for (final (pos, rx, h, rz) in rightPuffs) {
      mesh.addFrustum(
        pos.x,
        pos.y,
        pos.z,
        rx,
        rz,
        rx * 0.68,
        rz * 0.68,
        h,
        7,
        DesertPalette.cloudSunlit,
        topColor: DesertPalette.cloudSunlit,
        layer: RenderLayer.world,
        isCloud: true,
        distanceFade: 0.06,
      );
    }

    final leftPuffs = [
      (Vec3(-25.5 + drift * 0.6, 27.6, -65.0), 6.0, 1.8, 2.8),
      (Vec3(-18.2 + drift * 0.6, 28.5, -65.5), 5.4, 2.2, 2.6),
    ];
    for (final (pos, rx, h, rz) in leftPuffs) {
      mesh.addFrustum(
        pos.x,
        pos.y,
        pos.z,
        rx,
        rz,
        rx * 0.65,
        rz * 0.65,
        h,
        6,
        DesertPalette.cloudSunlit,
        topColor: DesertPalette.cloudSunlit,
        layer: RenderLayer.world,
        isCloud: true,
        distanceFade: 0.08,
      );
    }
  }
}
