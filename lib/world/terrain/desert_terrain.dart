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
  /// Flat (`y = 0`) across the whole 128 x 128 buildable desert + highway corridor,
  /// smoothly rising into faceted low-poly dunes & canyon foothills around the perimeter.
  static double heightAt(double x, double z) {
    final flatDistX = math.max(0.0, x.abs() - 72.0);
    final flatDistZ = z < -124.0
        ? (-124.0 - z)
        : (z > 24.0 ? (z - 24.0) : 0.0);
    final radialOut = math.sqrt(flatDistX * flatDistX + flatDistZ * flatDistZ);
    if (radialOut <= 0.001) return 0.0;

    final blend = (radialOut / 40.0).clamp(0.0, 1.0);
    final smooth = blend * blend * (3.0 - 2.0 * blend);

    final wave1 = math.sin(x * 0.045 + z * 0.035) * 2.3;
    final wave2 = math.cos(x * 0.08 - z * 0.055) * 1.3;
    final farRise = z < -160.0 ? ((-160.0 - z) * 0.06).clamp(0.0, 6.0) : 0.0;
    final sideRise = x.abs() > 110.0 ? ((x.abs() - 110.0) * 0.05).clamp(0.0, 6.0) : 0.0;

    return math.max(0.0, (wave1 + wave2 + 1.9 + farRise + sideRise) * smooth);
  }

  static void build(MeshBuilder mesh, {int parkingTier = 0}) {
    const xs = <double>[
      -340, -260, -200, -150, -110, -90, -72, -48, -24, 0, 24, 48, 72, 90, 110, 150, 200, 260, 340,
    ];
    const zs = <double>[
      -380, -300, -240, -190, -160, -140, -124, -96, -64, -40, -16, 4, 16, 24, 40, 70, 110,
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
        final distFade = avgZ < -130.0
            ? ((-130.0 - avgZ) / 200.0).clamp(0.0, 0.58)
            : 0.0;

        final earthMix = (avgY / 6.0).clamp(0.0, 1.0);
        final farEarthMix = avgZ < -124.0 ? ((-124.0 - avgZ) / 160.0).clamp(0.0, 0.55) : 0.0;
        // Subtle organic variation across valley floor so flat sand never looks plain
        final valleyRipple = 0.045 * (0.5 + 0.5 * math.sin(avgX * 0.11 + avgZ * 0.13));
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

    // Winding dry desert washes / arroyo ribbons meandering across the open desert floor
    final washPatches = <List<Vec3>>[
      const [
        Vec3(-48.0, 0.012, -70.0),
        Vec3(-40.0, 0.012, -64.0),
        Vec3(-22.0, 0.012, -68.0),
        Vec3(-28.0, 0.012, -74.0),
      ],
      const [
        Vec3(-28.0, 0.012, -74.0),
        Vec3(-22.0, 0.012, -68.0),
        Vec3(2.0, 0.012, -72.0),
        Vec3(-2.0, 0.012, -78.0),
      ],
      const [
        Vec3(24.0, 0.012, -6.0),
        Vec3(34.0, 0.012, -2.0),
        Vec3(48.0, 0.012, -10.0),
        Vec3(40.0, 0.012, -14.0),
      ],
      const [
        Vec3(30.0, 0.012, -96.0),
        Vec3(44.0, 0.012, -90.0),
        Vec3(58.0, 0.012, -98.0),
        Vec3(46.0, 0.012, -104.0),
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
  }
}
