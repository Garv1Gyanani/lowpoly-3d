import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';
import '../terrain/desert_terrain.dart';

/// Low-poly desert saguaro cacti with blooming crown flowers, swaying sagebrush,
/// grounded sandstone boulder clusters, and scattered desert pebble/driftwood accents.
class DesertFloraAndRocks {
  const DesertFloraAndRocks._();

  static const _cacti = [
    (-12.6, 5.2, 1.05, 0.2),
    (-12.4, -2.5, 1.20, 1.1),
    (-11.8, -11.5, 1.0, 2.2),
    (-1.2, -13.5, 1.15, 0.8),
    (11.6, 5.4, 1.10, 2.7),
    (12.5, -10.8, 1.25, 0.4),
    (10.8, 17.5, 1.05, 1.7),
    (-9.2, 17.8, 0.90, 0.6),
    (2.4, 18.0, 0.95, 2.1),
    (-6.8, -19.5, 1.20, 1.4),
    (7.4, -21.0, 1.15, 0.3),
  ];

  static const _bushes = [
    (-11.4, 7.2, 0.56),
    (-5.8, 4.7, 0.42),
    (0.3, 4.7, 0.40),
    (7.4, 5.6, 0.50),
    (10.8, -1.2, 0.58),
    (-10.4, -6.2, 0.54),
    (0.8, -9.2, 0.48),
    (10.4, -12.0, 0.65),
    (-5.4, 17.2, 0.60),
    (6.8, 17.2, 0.55),
    (-10.0, -17.5, 0.72),
    (4.2, -18.5, 0.68),
    (14.0, -22.0, 0.80),
  ];

  static const _rocks = [
    (-13.2, 1.5, 1.0, 0.65),
    (-12.2, -8.8, 0.82, 0.52),
    (12.2, 2.2, 1.10, 0.72),
    (13.5, -1.8, 0.88, 0.58),
    (-3.2, -14.2, 1.25, 0.80),
    (9.4, -14.4, 1.10, 0.70),
    (-13.2, 18.0, 1.10, 0.65),
    (12.6, 17.8, 0.95, 0.60),
    (-14.5, -22.5, 1.65, 1.05),
    (11.0, -24.5, 1.55, 0.95),
  ];

  static void buildAll(
    MeshBuilder mesh,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    buildStatic(mesh, lighting, shadowCol);
    buildDynamic(mesh, lighting, shadowCol, animTime);
  }

  /// Deterministic scatter of cacti, boulders & sagebrush across the whole open desert
  /// (kind: 0 = saguaro, 1 = sandstone rock, 2 = static bush).
  static final List<(double, double, int, double, double)> _scatter = _generateScatter();

  static List<(double, double, int, double, double)> _generateScatter() {
    int seed = 1640531527;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final out = <(double, double, int, double, double)>[];
    int guard = 0;
    while (out.length < 150 && guard++ < 1000) {
      final x = -112.0 + next() * 224.0;
      final z = -150.0 + next() * 192.0;
      if (z > 6.5 && z < 20.5) continue; // keep Route 163 corridor clear
      final roll = next();
      final kind = roll < 0.34 ? 0 : (roll < 0.62 ? 1 : 2);
      final scale = 0.75 + next() * 0.65;
      final rot = next() * math.pi * 2.0;
      out.add((x, z, kind, scale, rot));
    }
    return out;
  }

  static void buildStatic(
    MeshBuilder mesh,
    DesertLighting lighting,
    Color shadowCol, {
    bool Function(double x, double z)? isOccupied,
  }) {
    for (int i = 0; i < _scatter.length; i++) {
      final (x, z, kind, scale, rot) = _scatter[i];
      if (isOccupied != null && isOccupied(x, z)) continue;
      final gy = DesertTerrain.heightAt(x, z);
      switch (kind) {
        case 0:
          addSaguaro(mesh, Vec3(x, gy, z), scale, rot, lighting, shadowCol);
        case 1:
          addSandstoneRock(
            mesh,
            Vec3(x, gy - 0.08, z),
            0.7 + scale * 0.6,
            0.45 + scale * 0.35,
            rot,
            lighting: lighting,
            shadowCol: shadowCol,
            groundY: gy,
          );
        default:
          addDesertBush(
            mesh,
            Vec3(x, gy, z),
            0.38 + scale * 0.22,
            fixedPhase: rot,
            lighting: lighting,
            shadowCol: shadowCol,
          );
      }
    }

    for (final (x, z, scale, rot) in _cacti) {
      if (isOccupied != null && isOccupied(x, z)) continue;
      addSaguaro(mesh, Vec3(x, DesertTerrain.heightAt(x, z), z), scale, rot, lighting, shadowCol);
    }

    for (int i = 0; i < _rocks.length; i++) {
      final (x, z, rx, h) = _rocks[i];
      if (isOccupied != null && isOccupied(x, z)) continue;
      final gy = DesertTerrain.heightAt(x, z);
      addSandstoneRock(
        mesh,
        Vec3(x, gy - 0.08, z),
        rx,
        h,
        i * 0.7,
        lighting: lighting,
        shadowCol: shadowCol,
        groundY: gy,
      );
    }

    // Small valley floor pebble clusters & weathered desert driftwood logs for rich surface texture
    const pebbles = [
      (-6.4, 7.9, 0.24),
      (5.2, 8.2, 0.22),
      (-8.8, 2.8, 0.28),
      (8.9, 3.4, 0.25),
      (-4.2, -2.6, 0.22),
      (4.8, -3.4, 0.26),
    ];
    for (int i = 0; i < pebbles.length; i++) {
      final (px, pz, r) = pebbles[i];
      if (isOccupied != null && isOccupied(px, pz)) continue;
      final gy = DesertTerrain.heightAt(px, pz);
      mesh.addFrustum(
        px,
        gy,
        pz,
        r,
        r * 0.8,
        r * 0.5,
        r * 0.4,
        r * 0.55,
        5,
        DesertPalette.sandstoneLight,
        topColor: DesertPalette.terracotta,
        phaseOffset: i * 1.1,
      );
      mesh.addFrustum(
        px + r * 0.9,
        gy,
        pz + r * 0.4,
        r * 0.6,
        r * 0.5,
        r * 0.3,
        r * 0.3,
        r * 0.38,
        5,
        DesertPalette.arroyoDark,
        phaseOffset: i * 1.7,
      );
    }

    // Static contact shadows under bushes so swaying foliage stays grounded
    for (int i = 0; i < _bushes.length; i++) {
      final (x, z, radius) = _bushes[i];
      if (isOccupied != null && isOccupied(x, z)) continue;
      final gy = DesertTerrain.heightAt(x, z);
      mesh.addDiscShadow(
        x,
        gy,
        z,
        radius * 0.92,
        radius * 0.85,
        radius * 0.65,
        lighting.shadowDirection,
        shadowCol,
        sides: 6,
      );
    }
  }

  static void buildDynamic(
    MeshBuilder mesh,
    DesertLighting lighting,
    Color shadowCol,
    double animTime, {
    bool Function(double x, double z)? isOccupied,
  }) {
    for (int i = 0; i < _bushes.length; i++) {
      final (x, z, radius) = _bushes[i];
      if (isOccupied != null && isOccupied(x, z)) continue;
      final sway = math.sin(animTime * 1.4 + i * 1.3) * 0.025;
      addDesertBush(
        mesh,
        Vec3(x + sway, DesertTerrain.heightAt(x, z), z),
        radius,
        fixedPhase: x * 0.5 + i * 0.9,
      );
    }
  }

  static void addSaguaro(
    MeshBuilder mesh,
    Vec3 pos,
    double scale,
    double rotY,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    mesh.addDiscShadow(
      pos.x,
      pos.y,
      pos.z,
      0.38 * scale,
      0.38 * scale,
      2.0 * scale,
      lighting.shadowDirection,
      shadowCol,
      sides: 6,
    );
    mesh.withTransform(pos, rotY, () {
      final s = scale;
      mesh.addFrustum(
        0,
        0,
        0,
        0.22 * s,
        0.22 * s,
        0.18 * s,
        0.18 * s,
        2.08 * s,
        6,
        DesertPalette.cactus,
        topColor: DesertPalette.vegetation,
      );
      mesh.addBox(0, 2.08 * s, 0, 0.14 * s, 0.10 * s, 0.14 * s, DesertPalette.gold);
      mesh.addBox(0.30 * s, 0.90 * s, 0, 0.34 * s, 0.21 * s, 0.21 * s, DesertPalette.cactus);
      mesh.addBox(0.40 * s, 1.06 * s, 0, 0.21 * s, 0.64 * s, 0.21 * s, DesertPalette.cactus);
      mesh.addBox(0.40 * s, 1.70 * s, 0, 0.11 * s, 0.08 * s, 0.11 * s, DesertPalette.cream);
      mesh.addBox(-0.28 * s, 0.64 * s, 0, 0.30 * s, 0.19 * s, 0.19 * s, DesertPalette.vegetation);
      mesh.addBox(-0.36 * s, 0.80 * s, 0, 0.19 * s, 0.52 * s, 0.19 * s, DesertPalette.vegetation);
    });
  }

  static void addDesertBush(
    MeshBuilder mesh,
    Vec3 pos,
    double radius, {
    double? fixedPhase,
    DesertLighting? lighting,
    Color? shadowCol,
  }) {
    if (lighting != null && shadowCol != null) {
      mesh.addDiscShadow(
        pos.x,
        pos.y,
        pos.z,
        radius * 0.90,
        radius * 0.84,
        radius * 0.65,
        lighting.shadowDirection,
        shadowCol,
        sides: 6,
      );
    }
    final phase = fixedPhase ?? (pos.z * 0.7);
    mesh.addFrustum(
      pos.x,
      pos.y,
      pos.z,
      radius * 0.90,
      radius * 0.84,
      radius * 0.54,
      radius * 0.48,
      radius * 0.70,
      6,
      DesertPalette.vegetation,
      topColor: const Color(0xFF8C946A),
      phaseOffset: phase,
    );
    mesh.addFrustum(
      pos.x + radius * 0.36,
      pos.y,
      pos.z + radius * 0.18,
      radius * 0.50,
      radius * 0.46,
      radius * 0.24,
      radius * 0.24,
      radius * 0.46,
      5,
      DesertPalette.vegetationDark,
      topColor: DesertPalette.vegetation,
      phaseOffset: phase + 0.6,
    );
  }

  static void addSandstoneRock(
    MeshBuilder mesh,
    Vec3 pos,
    double radius,
    double height,
    double phase, {
    DesertLighting? lighting,
    Color? shadowCol,
    double? groundY,
  }) {
    if (lighting != null && shadowCol != null) {
      mesh.addDiscShadow(
        pos.x + radius * 0.18,
        groundY ?? (pos.y + 0.08),
        pos.z + radius * 0.08,
        radius * 1.05,
        radius * 0.85,
        height,
        lighting.shadowDirection,
        shadowCol,
        sides: 6,
      );
    }
    mesh.addFrustum(
      pos.x,
      pos.y,
      pos.z,
      radius,
      radius * 0.78,
      radius * 0.56,
      radius * 0.44,
      height,
      6,
      DesertPalette.terracotta,
      topColor: DesertPalette.sandstoneLight,
      phaseOffset: phase,
    );
    mesh.addFrustum(
      pos.x + radius * 0.68,
      pos.y,
      pos.z + radius * 0.32,
      radius * 0.46,
      radius * 0.40,
      radius * 0.24,
      radius * 0.22,
      height * 0.48,
      5,
      DesertPalette.sandstone,
      topColor: DesertPalette.terracotta,
      phaseOffset: phase + 1.1,
    );
  }
}
