import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Outpost timber streetlamps & rustic wooden split-rail fences.
class StreetLampAndFence {
  const StreetLampAndFence._();

  static void buildOutpostFencesAndLamps(
    MeshBuilder mesh,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    buildFenceRun(mesh, -10.8, 6.2, -10.8, -3.5, 4);
    buildFenceRun(mesh, 10.8, 6.2, 10.8, 1.5, 2);

    const lampPositions = [
      Vec3(-5.6, 0, 6.9),
      Vec3(0.4, 0, 6.9),
      Vec3(6.2, 0, 6.9),
      Vec3(-3.3, 0, 1.9),
      Vec3(3.8, 0, 1.9),
      Vec3(-0.8, 0, -4.8),
    ];

    for (final p in lampPositions) {
      buildLamp(mesh, p, lighting, shadowCol);
    }
  }

  static void buildLamp(
    MeshBuilder mesh,
    Vec3 position,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    mesh.addBoxShadow(
      position.x,
      position.z,
      0.24,
      0.24,
      2.35,
      lighting.shadowDirection,
      shadowCol,
    );
    mesh.withTransform(position, 0, () {
      mesh.addBox(0, 0, 0, 0.13, 2.35, 0.13, DesertPalette.woodDark);
      mesh.addBox(0, 2.25, 0.20, 0.11, 0.11, 0.46, DesertPalette.woodDark);
      mesh.addBox(
        0,
        1.96,
        0.36,
        0.22,
        0.28,
        0.22,
        DesertPalette.cream,
        emissiveColor: DesertPalette.windowNight,
        emissiveStrength: 1.0,
      );
      mesh.addFrustum(
        0,
        2.24,
        0.36,
        0.20,
        0.20,
        0.04,
        0.04,
        0.14,
        4,
        DesertPalette.metalDark,
        phaseOffset: math.pi / 4,
      );
      mesh.addGlow(
        const Vec3(0, 2.1, 0.36),
        DesertPalette.windowNight,
        radius: 28,
        intensity: 0.72,
      );
    });
  }

  static void buildFenceRun(
    MeshBuilder mesh,
    double x0,
    double z0,
    double x1,
    double z1,
    int segments,
  ) {
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final px = x0 + (x1 - x0) * t;
      final pz = z0 + (z1 - z0) * t;
      mesh.addBox(px, 0, pz, 0.15, 0.82, 0.15, DesertPalette.wood);
      if (i < segments) {
        final tNext = (i + 1) / segments;
        final nx = x0 + (x1 - x0) * tNext;
        final nz = z0 + (z1 - z0) * tNext;
        final mx = (px + nx) * 0.5;
        final mz = (pz + nz) * 0.5;
        final lenX = (nx - px).abs() + 0.12;
        final lenZ = (nz - pz).abs() + 0.12;
        mesh.addBox(mx, 0.56, mz, lenX, 0.08, lenZ, DesertPalette.woodLight);
        mesh.addBox(mx, 0.27, mz, lenX, 0.08, lenZ, DesertPalette.woodLight);
      }
    }
  }
}
