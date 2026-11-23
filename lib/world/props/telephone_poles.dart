import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';
import '../terrain/desert_terrain.dart';

/// Highway wooden telephone poles with ceramic insulators and sagging power lines.
class TelephonePoles {
  const TelephonePoles._();

  static void buildHighwayLine(
    MeshBuilder mesh,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    final poleXs = [-21.0, -12.5, -4.0, 4.5, 13.0, 21.5];
    const poleZ = 16.0;
    const poleH = 3.9;

    for (final x in poleXs) {
      final py = DesertTerrain.heightAt(x, poleZ);
      mesh.addBoxShadow(x, poleZ, 0.35, 0.35, poleH, lighting.shadowDirection, shadowCol);
      mesh.addBox(x, py, poleZ, 0.20, poleH, 0.20, DesertPalette.woodDark);
      mesh.addBox(x, py + poleH - 0.42, poleZ, 0.16, 0.15, 1.2, DesertPalette.wood);
      mesh.addBox(x, py + poleH - 0.27, poleZ - 0.46, 0.10, 0.12, 0.10, DesertPalette.cream);
      mesh.addBox(x, py + poleH - 0.27, poleZ + 0.46, 0.10, 0.12, 0.10, DesertPalette.cream);
    }

    final wireColor = Color.lerp(
      const Color(0xFF3E342D),
      const Color(0xFF1A222E),
      lighting.nightFactor,
    )!;
    for (int i = 0; i < poleXs.length - 1; i++) {
      final x0 = poleXs[i];
      final x1 = poleXs[i + 1];
      final y0 = DesertTerrain.heightAt(x0, poleZ) + poleH - 0.24;
      final y1 = DesertTerrain.heightAt(x1, poleZ) + poleH - 0.24;
      for (final zOff in [-0.46, 0.46]) {
        const segs = 4;
        for (int s = 0; s < segs; s++) {
          final t0 = s / segs;
          final t1 = (s + 1) / segs;
          final sag0 = math.sin(t0 * math.pi) * 0.38;
          final sag1 = math.sin(t1 * math.pi) * 0.38;
          mesh.addLine(
            Vec3(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0 - sag0, poleZ + zOff),
            Vec3(x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1 - sag1, poleZ + zOff),
            wireColor,
            width: 1.0,
          );
        }
      }
    }
  }
}
