import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../models/game_models.dart';
import '../../theme/desert_palette.dart';
import '../props/desert_flora_and_rocks.dart';

/// Player-placeable desert outpost decorations (cacti, signposts, picnic sets, lamps, campfires).
class PlacedDecorationModels {
  const PlacedDecorationModels._();

  static void build(
    MeshBuilder mesh,
    PlacedDecoration deco,
    DesertLighting lighting,
    double animTime,
  ) {
    final shadowCol = Color.from(
      alpha: lighting.shadowAlpha,
      red: 0.22,
      green: 0.13,
      blue: 0.10,
    );

    switch (deco.kind) {
      case DecorationKind.saguaroCluster:
        DesertFloraAndRocks.addSaguaro(mesh, deco.position, 1.05, 0.5, lighting, shadowCol);
        DesertFloraAndRocks.addDesertBush(mesh, deco.position + const Vec3(0.6, 0, 0.3), 0.45);
      case DecorationKind.woodenSignpost:
        mesh.withTransform(deco.position, 0.15, () {
          mesh.addBox(0, 0, 0, 0.15, 2.0, 0.15, DesertPalette.woodDark);
          mesh.addBox(0.38, 1.55, 0, 0.95, 0.26, 0.09, DesertPalette.cream);
          mesh.addBox(-0.34, 1.18, 0, 0.85, 0.24, 0.09, DesertPalette.terracotta);
        });
      case DecorationKind.picnicSet:
        mesh.withTransform(deco.position, 0, () {
          mesh.addBox(0, 0, 0, 1.15, 0.58, 0.72, DesertPalette.woodLight);
          mesh.addBox(0, 0, -0.58, 1.05, 0.34, 0.28, DesertPalette.wood);
          mesh.addBox(0, 0, 0.58, 1.05, 0.34, 0.28, DesertPalette.wood);
        });
      case DecorationKind.desertLamp:
        mesh.withTransform(deco.position, 0, () {
          mesh.addBox(0, 0, 0, 0.14, 2.4, 0.14, DesertPalette.woodDark);
          mesh.addBox(
            0,
            2.4,
            0,
            0.32,
            0.34,
            0.32,
            DesertPalette.cream,
            emissiveColor: DesertPalette.windowNight,
            emissiveStrength: 1.0,
          );
          mesh.addGlow(const Vec3(0, 2.55, 0), DesertPalette.windowNight, radius: 34, intensity: 0.82);
        });
      case DecorationKind.campfireRing:
        mesh.withTransform(deco.position, 0, () {
          mesh.addFrustum(0, 0, 0, 0.56, 0.56, 0.48, 0.48, 0.20, 7, DesertPalette.metal);
          final flick = 0.75 + math.sin(animTime * 9.0) * 0.2;
          mesh.addFrustum(
            0,
            0.16,
            0,
            0.28,
            0.28,
            0.05,
            0.05,
            0.58 * flick,
            5,
            const Color(0xFFFF8C32),
            emissiveColor: const Color(0xFFFFC14D),
            emissiveStrength: 1.0,
            emissiveNightOnly: false,
          );
          mesh.addGlow(
            const Vec3(0, 0.5, 0),
            const Color(0xFFFF9838),
            radius: 36,
            intensity: 0.82,
            nightOnly: false,
          );
        });
    }
  }
}
