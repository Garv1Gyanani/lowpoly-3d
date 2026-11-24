import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../theme/desert_palette.dart';
import 'desert_terrain.dart';

/// True 3D sculpted Monument Valley mesas, Mitten Buttes, and grounded red-rock outcrops.
class MonumentMesas {
  const MonumentMesas._();

  static void buildAll(MeshBuilder mesh, {DesertLighting? lighting}) {
    // Monument Valley skyline pushed far beyond the 128 x 128 buildable desert so the
    // outpost truly sits in the middle of open sand, framed by distant red-rock giants.

    // 1. Hero Left West Mitten Butte (with twin flanking spires!)
    buildMittenButte(
      mesh,
      cx: -62.0,
      cz: -205.0,
      scale: 2.7,
      distanceFade: 0.22,
      hasLeftButtress: true,
      hasRightThumb: true,
      seed: 1,
      lighting: lighting,
    );

    // 2. Far-Left Distant Mesa Shoulder
    buildFlatPlateau(
      mesh,
      cx: -165.0,
      cz: -235.0,
      rx: 38.0,
      rz: 22.0,
      height: 34.0,
      distanceFade: 0.38,
      seed: 2,
    );

    // 3. Distant Center Flat-Topped Plateau
    buildFlatPlateau(
      mesh,
      cx: 10.0,
      cz: -275.0,
      rx: 40.0,
      rz: 20.0,
      height: 30.0,
      distanceFade: 0.44,
      seed: 3,
    );

    // 4. Mid-Right East Mitten Butte (with slender left thumb spire)
    buildMittenButte(
      mesh,
      cx: 60.0,
      cz: -228.0,
      scale: 2.0,
      distanceFade: 0.32,
      hasLeftThumb: true,
      seed: 4,
      lighting: lighting,
    );

    // 5. Hero Right Merrick Cathedral Butte
    buildMittenButte(
      mesh,
      cx: 118.0,
      cz: -192.0,
      scale: 2.45,
      distanceFade: 0.24,
      seed: 5,
      lighting: lighting,
    );

    // 6. Low red-rock outcrops just outside the buildable desert edges
    buildLowOutcrop(mesh, -96.0, -70.0, 9.0, 6.5, 6.0, 0.10, 6, lighting);
    buildLowOutcrop(mesh, 94.0, -52.0, 9.5, 6.8, 6.6, 0.10, 7, lighting);
    buildLowOutcrop(mesh, -100.0, -5.0, 7.6, 5.8, 5.0, 0.08, 8, lighting);
    buildLowOutcrop(mesh, 98.0, 2.0, 8.0, 6.0, 5.4, 0.08, 9, lighting);
    buildLowOutcrop(mesh, -30.0, -150.0, 8.4, 6.0, 5.6, 0.14, 10, lighting);
    buildLowOutcrop(mesh, 36.0, -146.0, 7.8, 5.6, 5.2, 0.14, 11, lighting);
  }

  /// Sculpted multi-tiered 3D red sandstone Mitten / Cathedral Butte.
  static void buildMittenButte(
    MeshBuilder mesh, {
    required double cx,
    required double cz,
    required double scale,
    double distanceFade = 0.0,
    int seed = 1,
    bool hasLeftButtress = false,
    bool hasRightThumb = false,
    bool hasLeftThumb = false,
    double? overrideBaseY,
    DesertLighting? lighting,
  }) {
    final groundY = overrideBaseY ?? DesertTerrain.heightAt(cx, cz);
    final baseY = groundY - 0.6;
    final s = scale;

    if (lighting != null && overrideBaseY == null) {
      mesh.addDiscShadow(
        cx,
        groundY,
        cz,
        10.6 * s,
        8.0 * s,
        12.0 * s,
        lighting.shadowDirection,
        lighting.shadowColor,
        sides: 8,
      );
    }

    const talusCol = Color(0xFFB85B3C);
    const cliffMain = Color(0xFFBC5838);
    const cliffRib = Color(0xFFA24531);
    const capCol = Color(0xFFD67346);

    mesh.addFrustum(
      cx,
      baseY,
      cz,
      11.2 * s,
      8.5 * s,
      6.4 * s,
      4.9 * s,
      4.8 * s,
      10,
      talusCol,
      topColor: cliffMain,
      distanceFade: distanceFade,
      roughness: 0.14,
      seed: seed,
    );

    mesh.addFrustum(
      cx,
      baseY + 4.5 * s,
      cz,
      6.3 * s,
      4.9 * s,
      5.2 * s,
      4.0 * s,
      2.0 * s,
      9,
      cliffRib,
      topColor: cliffMain,
      distanceFade: distanceFade,
      roughness: 0.12,
      seed: seed + 10,
    );

    mesh.addFrustum(
      cx,
      baseY + 6.2 * s,
      cz,
      5.0 * s,
      3.8 * s,
      4.7 * s,
      3.6 * s,
      4.5 * s,
      9,
      cliffMain,
      topColor: capCol,
      distanceFade: distanceFade,
      roughness: 0.15,
      seed: seed + 20,
    );
    mesh.addFrustum(
      cx,
      baseY + 10.6 * s,
      cz,
      4.8 * s,
      3.7 * s,
      4.6 * s,
      3.5 * s,
      1.2 * s,
      9,
      capCol,
      topColor: capCol,
      distanceFade: distanceFade,
      roughness: 0.14,
      seed: seed + 22,
    );
    mesh.addFrustum(
      cx,
      baseY + 11.7 * s,
      cz,
      4.6 * s,
      3.5 * s,
      4.3 * s,
      3.3 * s,
      3.8 * s,
      9,
      cliffMain,
      topColor: capCol,
      distanceFade: distanceFade,
      roughness: 0.15,
      seed: seed + 24,
    );

    mesh.addFrustum(
      cx - 2.3 * s,
      baseY + 5.8 * s,
      cz + 1.9 * s,
      2.1 * s,
      1.7 * s,
      1.7 * s,
      1.4 * s,
      8.6 * s,
      6,
      cliffRib,
      topColor: capCol,
      distanceFade: distanceFade,
      roughness: 0.10,
      seed: seed + 30,
    );
    mesh.addFrustum(
      cx + 2.1 * s,
      baseY + 5.8 * s,
      cz + 2.0 * s,
      2.2 * s,
      1.8 * s,
      1.8 * s,
      1.5 * s,
      8.9 * s,
      6,
      capCol,
      topColor: DesertPalette.terracotta,
      distanceFade: distanceFade,
      roughness: 0.10,
      seed: seed + 40,
    );

    mesh.addFrustum(
      cx,
      baseY + 15.3 * s,
      cz,
      4.2 * s,
      3.2 * s,
      3.5 * s,
      2.7 * s,
      1.6 * s,
      8,
      capCol,
      topColor: DesertPalette.terracotta,
      distanceFade: distanceFade,
      roughness: 0.08,
      seed: seed + 50,
    );

    if (hasLeftButtress) {
      mesh.addFrustum(
        cx - 6.0 * s,
        baseY + 3.4 * s,
        cz + 0.5 * s,
        1.55 * s,
        1.45 * s,
        1.05 * s,
        1.0 * s,
        9.4 * s,
        6,
        cliffRib,
        topColor: capCol,
        distanceFade: distanceFade,
        roughness: 0.09,
        seed: seed + 60,
      );
    }

    if (hasRightThumb) {
      mesh.addFrustum(
        cx + 6.4 * s,
        baseY + 3.2 * s,
        cz + 1.0 * s,
        1.45 * s,
        1.35 * s,
        0.72 * s,
        0.70 * s,
        9.6 * s,
        6,
        capCol,
        topColor: DesertPalette.terracotta,
        distanceFade: distanceFade,
        roughness: 0.08,
        seed: seed + 70,
      );
    }

    if (hasLeftThumb) {
      mesh.addFrustum(
        cx - 6.0 * s,
        baseY + 3.0 * s,
        cz + 0.8 * s,
        1.35 * s,
        1.25 * s,
        0.65 * s,
        0.65 * s,
        8.6 * s,
        6,
        cliffMain,
        topColor: capCol,
        distanceFade: distanceFade,
        roughness: 0.08,
        seed: seed + 80,
      );
    }
  }

  static void buildFlatPlateau(
    MeshBuilder mesh, {
    required double cx,
    required double cz,
    required double rx,
    required double rz,
    required double height,
    double distanceFade = 0.0,
    int seed = 1,
    double? overrideBaseY,
  }) {
    final baseY = overrideBaseY ?? (DesertTerrain.heightAt(cx, cz) - 0.6);
    final skirtH = height * 0.42;
    final cliffH = height * 0.58;

    mesh.addFrustum(
      cx,
      baseY,
      cz,
      rx,
      rz,
      rx * 0.72,
      rz * 0.72,
      skirtH,
      8,
      const Color(0xFFB56652),
      topColor: DesertPalette.sandstone,
      distanceFade: distanceFade,
      roughness: 0.12,
      seed: seed,
    );
    mesh.addFrustum(
      cx,
      baseY + skirtH - 0.2,
      cz,
      rx * 0.70,
      rz * 0.70,
      rx * 0.62,
      rz * 0.62,
      cliffH,
      8,
      DesertPalette.sandstone,
      topColor: DesertPalette.terracotta,
      distanceFade: distanceFade,
      roughness: 0.10,
      seed: seed + 15,
    );
  }

  static void buildLowOutcrop(
    MeshBuilder mesh,
    double cx,
    double cz,
    double rx,
    double rz,
    double h,
    double fade,
    int seed,
    DesertLighting? lighting,
  ) {
    final groundY = DesertTerrain.heightAt(cx, cz);
    if (lighting != null) {
      mesh.addDiscShadow(
        cx,
        groundY,
        cz,
        rx * 0.94,
        rz * 0.94,
        h,
        lighting.shadowDirection,
        lighting.shadowColor,
        sides: 6,
      );
    }
    mesh.addFrustum(
      cx,
      groundY - 0.35,
      cz,
      rx,
      rz,
      rx * 0.62,
      rz * 0.62,
      h,
      6,
      DesertPalette.sandstone,
      topColor: DesertPalette.terracotta,
      distanceFade: fade,
      roughness: 0.16,
      seed: seed,
    );
  }
}
