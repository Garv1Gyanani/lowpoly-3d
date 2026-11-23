import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';

/// Faceted 3D low-poly desert clouds floating high above Monument Valley.
class SkyClouds {
  const SkyClouds._();

  static void build(
    MeshBuilder mesh,
    DesertLighting lighting,
    double animTime,
  ) {
    final drift = math.sin(animTime * 0.08) * 2.2;
    Color cloudCol = Color.lerp(
      const Color(0xFFFFF4E7),
      const Color(0xFFFFC194),
      lighting.sunsetFactor * 0.85,
    )!;
    cloudCol = Color.lerp(cloudCol, const Color(0xFF334B6E), lighting.nightFactor * 0.9)!;

    final rightPuffs = [
      (Vec3(7.0 + drift, 26.5, -62.0), 5.8, 1.8, 3.0),
      (Vec3(14.0 + drift, 28.0, -63.0), 6.8, 2.8, 3.5),
      (Vec3(22.0 + drift, 30.0, -64.0), 7.8, 4.0, 4.0),
      (Vec3(30.5 + drift, 28.8, -63.5), 7.0, 3.2, 3.6),
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
        cloudCol,
        topColor: cloudCol,
        layer: RenderLayer.world,
        distanceFade: 0.08,
      );
    }

    final leftPuffs = [
      (Vec3(-22.0 + drift * 0.6, 27.5, -65.0), 6.2, 1.8, 2.8),
      (Vec3(-14.5 + drift * 0.6, 28.4, -65.5), 5.6, 2.2, 2.6),
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
        cloudCol,
        topColor: cloudCol,
        layer: RenderLayer.world,
        distanceFade: 0.10,
      );
    }
  }
}
