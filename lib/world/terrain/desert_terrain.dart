import 'dart:math' as math;
import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Single continuous sculpted low-poly 3D desert terrain spanning from the
/// foreground highway seamlessly out to the far Monument Valley horizon.
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

  static void build(MeshBuilder mesh) {
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

        final avgZ = (v00.z + v11.z) * 0.5;
        final avgY = (v00.y + v10.y + v11.y + v01.y) * 0.25;
        final distFade = avgZ < -32.0
            ? ((-32.0 - avgZ) / 62.0).clamp(0.0, 0.58)
            : 0.0;

        final earthMix = (avgY / 3.8).clamp(0.0, 1.0);
        final farEarthMix = avgZ < -18.0 ? ((-18.0 - avgZ) / 50.0).clamp(0.0, 0.55) : 0.0;
        final facetTint = ((r + c).isEven) ? 0.0 : 0.06;

        Color baseCol = Color.lerp(
          DesertPalette.sand,
          const Color(0xFFD58C5A),
          (earthMix * 0.65 + farEarthMix * 0.55).clamp(0.0, 0.85),
        )!;
        if (facetTint > 0) {
          baseCol = Color.lerp(baseCol, DesertPalette.sandDark, facetTint)!;
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
  }
}
