import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 6B: Oasis Souvenir Plaza with shimmering plunge pool, wooden sun loungers
/// with terracotta towels, overhead pergola trellis slats, craft shop & desert palm.
class OasisPlazaBuilding {
  const OasisPlazaBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    mesh.addBoxShadow(
      origin.x,
      origin.z,
      4.0,
      3.1,
      2.4,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(origin, 0, () {
      // Courtyard sandstone deck
      mesh.addBox(0, 0, 0, 4.0, 0.16, 3.1, DesertPalette.creamDark);

      // Shimmering turquoise plunge pool + stone coping border
      final shimmer = 0.08 * math.sin(animTime * 2.5);
      final poolCol = Color.lerp(DesertPalette.water, DesertPalette.neonTurquoise, 0.15 + shimmer)!;
      mesh.addBox(0.32, 0.13, 0.32, 2.15, 0.09, 1.50, poolCol, emissiveColor: DesertPalette.neonTurquoise, emissiveStrength: 0.42);
      mesh.addBox(0.32, 0.16, -0.48, 2.32, 0.11, 0.15, DesertPalette.cream);
      mesh.addBox(0.32, 0.16, 1.12, 2.32, 0.11, 0.15, DesertPalette.cream);

      // Two poolside wooden sun loungers with terracotta beach towels
      for (final lx in [-0.20, 0.85]) {
        mesh.addBox(lx, 0.16, -0.84, 0.54, 0.18, 0.36, DesertPalette.woodLight);
        mesh.addBox(lx, 0.34, -0.84, 0.46, 0.05, 0.30, DesertPalette.terracotta);
      }

      // Souvenir craft stall on left
      mesh.addBox(-1.32, 0.16, -0.26, 1.16, 1.72, 1.92, DesertPalette.terracotta);
      mesh.addBox(-1.32, 1.88, -0.26, 1.34, 0.18, 2.10, DesertPalette.cream);
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: -1.32,
        cy: 1.06,
        zWall: 0.70,
        width: 0.72,
        height: 0.66,
      );

      // Timber pergola arch with overhead wooden trellis rafters & OASIS sign
      for (final x in [-0.42, 1.32]) {
        mesh.addBox(x, 0.16, -1.10, 0.15, 2.10, 0.15, DesertPalette.wood);
      }
      for (final rx in [-0.20, 0.22, 0.64, 1.06]) {
        mesh.addBox(rx, 2.24, -0.96, 0.10, 0.08, 0.64, DesertPalette.woodDark);
      }
      mesh.addBox(0.45, 2.20, -1.10, 2.05, 0.56, 0.22, DesertPalette.woodLight);
      mesh.addFrontSignText(
        0.45,
        2.48,
        -0.98,
        1.90,
        0.44,
        'OASIS',
        DesertPalette.cream,
        glowColor: DesertPalette.neonTurquoise,
      );

      // Poolside warm corner lantern
      mesh.addBox(1.70, 0.16, 1.18, 0.12, 1.15, 0.12, DesertPalette.woodDark);
      mesh.addBox(
        1.70,
        1.28,
        1.18,
        0.22,
        0.24,
        0.22,
        DesertPalette.cream,
        emissiveColor: DesertPalette.windowNight,
        emissiveStrength: 1.0,
      );

      // Level 2+: Stylized desert palm & cactus planters
      if (level >= 2) {
        mesh.addFrustum(1.60, 0.16, -0.86, 0.15, 0.15, 0.10, 0.10, 2.18, 5, DesertPalette.wood);
        for (int i = 0; i < 5; i++) {
          final a = (i / 5) * math.pi * 2.0;
          final fx = 1.60 + math.cos(a) * 0.50;
          final fz = -0.86 + math.sin(a) * 0.50;
          mesh.addBox(fx, 2.28, fz, 0.66, 0.13, 0.30, DesertPalette.vegetation);
        }
        MeshParts.addPottedCactus(mesh, cx: -1.60, yBottom: 0.16, cz: 1.08);
      }

      mesh.addGlow(const Vec3(0.32, 1.0, 0.32), DesertPalette.neonTurquoise, radius: 32, intensity: 0.65);
    });
  }
}
