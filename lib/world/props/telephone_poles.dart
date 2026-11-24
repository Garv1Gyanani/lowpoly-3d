import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';
import '../terrain/desert_terrain.dart';

/// Highway wooden telephone poles running along the SOUTH shoulder of Route 163,
/// outside the buildable desert so player roads & junctions never collide with them.
class TelephonePoles {
  const TelephonePoles._();

  static void buildHighwayLine(
    MeshBuilder mesh,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    const poleZ = 16.8;
    const poleH = 3.85;

    final wireColor = Color.lerp(
      const Color(0xFF564438),
      const Color(0xFF222A38),
      lighting.nightFactor,
    )!;

    final poles = <double>[for (double x = -108; x <= 108; x += 13.5) x];

    for (final x in poles) {
      final py = DesertTerrain.heightAt(x, poleZ);
      mesh.addBoxShadow(
        x,
        poleZ,
        0.34,
        0.34,
        poleH,
        lighting.shadowDirection,
        shadowCol,
        groundY: py + 0.02,
      );
      mesh.addBox(x, py, poleZ, 0.19, poleH, 0.19, DesertPalette.woodDark);
      mesh.addBox(x, py + poleH - 0.42, poleZ, 0.15, 0.14, 1.15, DesertPalette.wood);
      mesh.addBox(x, py + poleH - 0.28, poleZ - 0.44, 0.09, 0.12, 0.09, DesertPalette.cream);
      mesh.addBox(x, py + poleH - 0.28, poleZ + 0.44, 0.09, 0.12, 0.09, DesertPalette.cream);
    }

    for (int i = 0; i < poles.length - 1; i++) {
      final x0 = poles[i];
      final x1 = poles[i + 1];
      final y0 = DesertTerrain.heightAt(x0, poleZ) + poleH - 0.24;
      final y1 = DesertTerrain.heightAt(x1, poleZ) + poleH - 0.24;
      for (final zOff in [-0.44, 0.44]) {
        mesh.addSaggingWire(
          Vec3(x0, y0, poleZ + zOff),
          Vec3(x1, y1, poleZ + zOff),
          wireColor,
          sag: 0.34,
          thickness: 0.032,
          segments: 5,
        );
      }
    }
  }
}
