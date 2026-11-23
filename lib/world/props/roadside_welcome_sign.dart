import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Classic weathered wooden roadside welcome billboard ("OLJATO OUTPOST").
class RoadsideWelcomeSign {
  const RoadsideWelcomeSign._();

  static void build(
    MeshBuilder mesh,
    Vec3 position,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    mesh.addBoxShadow(
      position.x,
      position.z,
      2.1,
      0.6,
      2.9,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(position, 0, () {
      mesh.addBox(-0.80, 0, 0, 0.17, 2.85, 0.17, DesertPalette.woodDark);
      mesh.addBox(0.80, 0, 0, 0.17, 2.85, 0.17, DesertPalette.woodDark);
      mesh.addBox(0, 1.4, 0, 2.25, 1.25, 0.16, DesertPalette.wood);
      mesh.addBox(
        0,
        1.5,
        0.05,
        2.04,
        1.04,
        0.08,
        DesertPalette.cream,
        emissiveColor: const Color(0xFFFFE5B4),
        emissiveStrength: 0.55,
        depthBias: -0.15,
      );
      mesh.addBox(0, 2.65, 0, 2.45, 0.16, 0.26, DesertPalette.terracotta);
      mesh.addBox(
        0,
        2.71,
        0.32,
        0.34,
        0.11,
        0.20,
        DesertPalette.metalDark,
        emissiveColor: DesertPalette.windowNight,
        emissiveStrength: 0.9,
      );
      mesh.addGlow(
        const Vec3(0, 2.4, 0.32),
        DesertPalette.windowNight,
        radius: 24,
        intensity: 0.65,
      );
      mesh.addFrontSignText(
        0,
        2.02,
        0.09,
        1.95,
        0.95,
        'OLJATO\nOUTPOST',
        DesertPalette.sandstoneDark,
        glowColor: DesertPalette.neonWarm,
      );
    });
  }
}
