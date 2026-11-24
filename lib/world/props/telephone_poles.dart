import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';
import '../terrain/desert_terrain.dart';

/// Highway wooden telephone poles positioned cleanly along the north roadside flanks
/// (`z = 11.25`, outside the central outpost plaza) using true 3D depth-sorted sagging wires
/// so utility wires NEVER cut across foreground vehicles or draw through RVs!
class TelephonePoles {
  const TelephonePoles._();

  static void buildHighwayLine(
    MeshBuilder mesh,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    const poleZ = 11.20;
    const poleH = 3.85;

    final wireColor = Color.lerp(
      const Color(0xFF564438),
      const Color(0xFF222A38),
      lighting.nightFactor,
    )!;

    // West & East roadside pole runs flanking the outpost driveway cleanly
    const poleGroups = <List<double>>[
      [-28.5, -20.2, -11.8],
      [11.8, 20.2, 28.5],
    ];

    for (final group in poleGroups) {
      for (final x in group) {
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
        // Crossarm & ceramic insulators
        mesh.addBox(x, py + poleH - 0.42, poleZ, 0.15, 0.14, 1.15, DesertPalette.wood);
        mesh.addBox(x, py + poleH - 0.28, poleZ - 0.44, 0.09, 0.12, 0.09, DesertPalette.cream);
        mesh.addBox(x, py + poleH - 0.28, poleZ + 0.44, 0.09, 0.12, 0.09, DesertPalette.cream);
      }

      for (int i = 0; i < group.length - 1; i++) {
        final x0 = group[i];
        final x1 = group[i + 1];
        final y0 = DesertTerrain.heightAt(x0, poleZ) + poleH - 0.24;
        final y1 = DesertTerrain.heightAt(x1, poleZ) + poleH - 0.24;
        for (final zOff in [-0.44, 0.44]) {
          mesh.addSaggingWire(
            Vec3(x0, y0, poleZ + zOff),
            Vec3(x1, y1, poleZ + zOff),
            wireColor,
            sag: 0.30,
            thickness: 0.032,
            segments: 5,
          );
        }
      }
    }
  }
}
