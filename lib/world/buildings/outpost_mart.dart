import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 2: Outpost Convenience Store ("MART") with glowing soda vending machine,
/// oak barrel, southwestern parapet vigas, framed display windows, and side annex.
class OutpostMartBuilding {
  const OutpostMartBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    mesh.addBoxShadow(
      origin.x,
      origin.z,
      4.8,
      3.6,
      3.3,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(origin, 0, () {
      mesh.addBox(0, 0, 0.22, 4.9, 0.20, 3.8, DesertPalette.concrete);
      mesh.addBox(0, 0.20, -0.22, 4.45, 2.55, 2.75, DesertPalette.cream);
      mesh.addBox(0, 0.20, 1.18, 4.50, 0.48, 0.08, DesertPalette.terracotta, depthBias: -0.12);

      MeshParts.addAdobeParapetRoof(
        mesh,
        cx: 0,
        yBase: 2.75,
        cz: -0.22,
        width: 4.48,
        depth: 2.78,
        parapetHeight: 0.32,
        parapetColor: DesertPalette.sandstone,
      );

      MeshParts.addFramedDoor(
        mesh,
        cx: 0,
        yBottom: 0.20,
        zWall: 1.16,
        width: 0.92,
        height: 1.58,
      );
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: -1.42,
        cy: 1.30,
        zWall: 1.16,
        width: 1.16,
        height: 0.96,
      );
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: 1.42,
        cy: 1.30,
        zWall: 1.16,
        width: 1.16,
        height: 0.96,
      );
      mesh.addRightWindow(2.23, 1.35, -0.22, 1.10, 0.90, DesertPalette.windowDay, DesertPalette.windowNight);

      // Timber porch pillars & turquoise striped awning
      for (final px in [-2.0, -0.72, 0.72, 2.0]) {
        mesh.addBox(px, 0.20, 1.88, 0.14, 1.92, 0.14, DesertPalette.wood);
      }
      mesh.addSlopedAwning(
        0,
        2.38,
        2.02,
        1.56,
        4.65,
        1.05,
        DesertPalette.turquoise,
        stripeColor: DesertPalette.cream,
        stripes: 8,
      );

      // Ice chest on left + glowing retro soda vending machine on right + oak barrel
      mesh.addBox(-1.60, 0.20, 1.48, 0.78, 0.60, 0.42, DesertPalette.creamDark);
      mesh.addFrustum(-2.12, 0.20, 1.46, 0.22, 0.22, 0.20, 0.20, 0.56, 7, DesertPalette.wood);
      // Glowing desert soda vending machine
      mesh.addBox(1.70, 0.20, 1.44, 0.62, 1.24, 0.42, DesertPalette.awningRed);
      mesh.addBox(
        1.70,
        0.72,
        1.65,
        0.46,
        0.56,
        0.05,
        DesertPalette.cream,
        emissiveColor: DesertPalette.neonWarm,
        emissiveStrength: 0.9,
        depthBias: -0.20,
      );
      MeshParts.addPottedCactus(mesh, cx: 0.72, yBottom: 0.20, cz: 1.50);

      // Warm hanging porch bulbs
      for (final lx in [-1.35, 0.0, 1.35]) {
        mesh.addBox(
          lx,
          1.92,
          1.96,
          0.11,
          0.11,
          0.11,
          DesertPalette.cream,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 1.0,
          depthBias: -0.22,
        );
      }

      // Rooftop illuminated "MART" marquee
      MeshParts.addMarqueeSign(
        mesh,
        cx: 0,
        yBottom: 3.07,
        cz: 0.86,
        width: 3.05,
        height: 0.86,
        text: 'MART',
        frameColor: DesertPalette.turquoise,
        glowColor: DesertPalette.neonTurquoise,
      );

      mesh.addGlow(
        const Vec3(0, 1.8, 1.6),
        DesertPalette.windowNight,
        radius: 34,
        intensity: 0.75,
      );

      // Level 3+: Side supply annex & rooftop AC unit + chimney stack
      if (level >= 3) {
        mesh.addBox(-2.72, 0.20, -0.30, 1.12, 1.90, 2.15, DesertPalette.creamDark);
        mesh.addBox(-2.72, 2.10, -0.30, 1.24, 0.20, 2.30, DesertPalette.terracotta);
        mesh.addBox(1.25, 3.04, -0.65, 0.78, 0.46, 0.68, DesertPalette.metal);
        mesh.addBox(-1.45, 3.04, -0.90, 0.44, 0.65, 0.44, DesertPalette.sandstone);
      }
    });
  }
}
