import 'dart:math' as math;
import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Single continuous sculpted low-poly 3D desert terrain with subtle dry arroyo
/// sand washes, sun-baked ochre facets, and rustic sandstone stepping stones.
class DesertTerrain {
  const DesertTerrain._();

  /// Continuous ground height function.
  /// Flat (`y = 0`) across the entire outpost valley & highway corridor,
  /// smoothly rising into faceted low-poly dunes & canyon foothills around the perimeter.
  static double heightAt(double x, double z) {
    final flatDistX = math.max(0.0, x.abs() - 14.5);
    final flatDistZ = z < -11.5
        ? (-11.5 - z)
        : (z > 17.5 ? (z - 17.5) : 0.0);
    final radialOut = math.sqrt(flatDistX * flatDistX + flatDistZ * flatDistZ);
    if (radialOut <= 0.001) return 0.0;

    final blend = (radialOut / 14.0).clamp(0.0, 1.0);
    final smooth = blend * blend * (3.0 - 2.0 * blend);

    final wave1 = math.sin(x * 0.09 + z * 0.07) * 1.15;
    final wave2 = math.cos(x * 0.16 - z * 0.11) * 0.65;
    final farRise = z < -28.0 ? ((-28.0 - z) * 0.045).clamp(0.0, 2.2) : 0.0;
    final sideRise = x.abs() > 26.0 ? ((x.abs() - 26.0) * 0.035).clamp(0.0, 2.4) : 0.0;

    return math.max(0.0, (wave1 + wave2 + 0.95 + farRise + sideRise) * smooth);
  }

  static void build(MeshBuilder mesh, {int parkingTier = 0}) {
    const xs = <double>[
      -128, -94, -68, -48, -34, -24, -16, -10, -4, 0, 4, 10, 16, 24, 34, 48, 68, 94, 128,
    ];
    const zs = <double>[
      -120, -96, -76, -60, -46, -34, -24, -14, -8, -2, 4, 10, 16, 22, 32,
    ];

    final rows = zs.length;
    final cols = xs.length;

    final grid = List<List<Vec3>>.generate(rows, (r) {
      final z = zs[r];
      return List<Vec3>.generate(cols, (c) {
        final x = xs[c];
        return Vec3(x, heightAt(x, z), z);
      });
    });

    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < cols - 1; c++) {
        final v00 = grid[r][c];
        final v10 = grid[r][c + 1];
        final v11 = grid[r + 1][c + 1];
        final v01 = grid[r + 1][c];

        final avgX = (v00.x + v10.x) * 0.5;
        final avgZ = (v00.z + v11.z) * 0.5;
        final avgY = (v00.y + v10.y + v11.y + v01.y) * 0.25;
        final distFade = avgZ < -32.0
            ? ((-32.0 - avgZ) / 62.0).clamp(0.0, 0.58)
            : 0.0;

        final earthMix = (avgY / 3.8).clamp(0.0, 1.0);
        final farEarthMix = avgZ < -18.0 ? ((-18.0 - avgZ) / 50.0).clamp(0.0, 0.55) : 0.0;
        // Subtle organic variation across valley floor so flat sand never looks plain
        final valleyRipple = 0.045 * (0.5 + 0.5 * math.sin(avgX * 0.28 + avgZ * 0.34));
        final facetTint = (((r + c).isEven) ? 0.0 : 0.055) + valleyRipple;

        Color baseCol = Color.lerp(
          DesertPalette.sand,
          const Color(0xFFD68D5B),
          (earthMix * 0.65 + farEarthMix * 0.55).clamp(0.0, 0.85),
        )!;
        if (facetTint > 0) {
          baseCol = Color.lerp(baseCol, DesertPalette.sandDark, facetTint.clamp(0.0, 0.16))!;
        }

        if ((r + c).isEven) {
          mesh.addTri(v00, v01, v11, baseCol, layer: RenderLayer.terrain, distanceFade: distFade);
          mesh.addTri(v00, v11, v10, baseCol, layer: RenderLayer.terrain, distanceFade: distFade);
        } else {
          mesh.addTri(v00, v01, v10, baseCol, layer: RenderLayer.terrain, distanceFade: distFade);
          mesh.addTri(v10, v01, v11, baseCol, layer: RenderLayer.terrain, distanceFade: distFade);
        }
      }
    }

    // Winding dry desert wash / arroyo ribbon meandering behind the town toward Monument Valley
    final washPatches = <List<Vec3>>[
      const [
        Vec3(-18.5, 0.012, -11.2),
        Vec3(-15.5, 0.012, -9.4),
        Vec3(-8.2, 0.012, -10.8),
        Vec3(-10.5, 0.012, -12.6),
      ],
      const [
        Vec3(-10.5, 0.012, -12.6),
        Vec3(-8.2, 0.012, -10.8),
        Vec3(1.5, 0.012, -11.6),
        Vec3(-0.5, 0.012, -13.5),
      ],
      const [
        Vec3(6.8, 0.012, 3.2),
        Vec3(9.8, 0.012, 4.4),
        Vec3(13.6, 0.012, 1.8),
        Vec3(11.2, 0.012, 0.6),
      ],
    ];
    for (final poly in washPatches) {
      mesh.addGroundPoly(
        poly,
        DesertPalette.arroyoSand,
        layer: RenderLayer.groundDecal,
        depthBias: 0.45,
      );
    }

    // Early-stage rustic sandstone stepping stones & worn footpath leading to the tiny cart!
    if (parkingTier <= 1) {
      mesh.addGroundPoly(
        const [
          Vec3(-3.8, 0.014, 5.4),
          Vec3(-3.5, 0.014, 10.8),
          Vec3(-1.3, 0.014, 10.8),
          Vec3(-1.5, 0.014, 5.4),
        ],
        DesertPalette.arroyoSand,
        layer: RenderLayer.groundDecal,
        depthBias: 0.35,
      );
      for (final (sx, sz, w, d) in const [
        (-2.8, 6.5, 0.56, 0.36),
        (-2.3, 7.3, 0.48, 0.34),
        (-2.7, 8.1, 0.54, 0.38),
        (-2.4, 9.0, 0.50, 0.34),
      ]) {
        mesh.addGroundRect(
          sx,
          0.019,
          sz,
          w,
          d,
          DesertPalette.sandstoneLight,
          layer: RenderLayer.groundDecal,
          depthBias: 0.12,
        );
      }
    }
  }
}
