import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 2: Outpost Convenience Store ("MART") evolving visually through Level 5.
class OutpostMartBuilding {
  const OutpostMartBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol, [
    double animTime = 0.0,
  ]) {
    mesh.withTransform(origin, 0, () {
      mesh.addBoxShadow(0, 0, 4.8, 3.6, 3.3, lighting.shadowDirection, shadowCol);

      mesh.addBox(0, 0, 0.22, 4.9, 0.20, 3.8, DesertPalette.concrete);
      mesh.addBox(0, 0.20, -0.22, 4.45, 2.55, 2.75, DesertPalette.cream, skipTop: true);
      // Terracotta wainscot trim sitting cleanly in front of main wall (z = 1.155)
      mesh.addBox(0, 0.20, 1.185, 4.48, 0.48, 0.05, DesertPalette.terracotta);

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

      // Porch posts stop cleanly underneath the sloped awning (yTop = 2.02 < awning y = 2.066 at z = 1.95)
      for (final px in [-2.0, -0.72, 0.72, 2.0]) {
        mesh.addBox(px, 0.20, 1.88, 0.14, 1.82, 0.14, DesertPalette.wood, skipTop: true);
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

      if (level >= 2) {
        mesh.addBox(-1.60, 0.20, 1.48, 0.78, 0.60, 0.42, DesertPalette.creamDark);
        mesh.addFrustum(-2.12, 0.20, 1.46, 0.22, 0.22, 0.20, 0.20, 0.56, 7, DesertPalette.wood);
        mesh.addBox(1.70, 0.20, 1.44, 0.62, 1.24, 0.42, DesertPalette.awningRed);
        mesh.addFlushRectOnZ(
          1.70,
          1.00,
          1.65,
          0.46,
          0.56,
          DesertPalette.cream,
          positiveZ: true,
          emissiveColor: DesertPalette.neonWarm,
          emissiveStrength: 0.9,
        );
      }
      MeshParts.addPottedCactus(mesh, cx: 0.72, yBottom: 0.20, cz: 1.50);

      // Warm porch bulbs tucked cleanly underneath the awning lip
      for (final lx in [-1.35, 0.0, 1.35]) {
        mesh.addBox(
          lx,
          1.84,
          1.88,
          0.10,
          0.10,
          0.10,
          DesertPalette.cream,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 1.0,
        );
      }

      MeshParts.addMarqueeSign(
        mesh,
        cx: 0,
        yBottom: 3.07,
        cz: 1.06,
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

      if (level >= 3) {
        mesh.addBox(-2.72, 0.20, -0.30, 1.12, 1.90, 2.15, DesertPalette.creamDark, skipTop: true);
        mesh.addBox(-2.72, 2.10, -0.30, 1.24, 0.20, 2.30, DesertPalette.terracotta);
        mesh.addBox(1.25, 2.81, -0.65, 0.78, 0.56, 0.68, DesertPalette.metal);
        mesh.addBox(-1.45, 2.81, -0.90, 0.44, 0.78, 0.44, DesertPalette.sandstone);
      }

      // Level 4+: Covered firewood & water supply rack on right + geometric adobe mural band
      if (level >= 4) {
        mesh.addFlushRectOnZ(0, 2.52, 1.16, 4.25, 0.14, DesertPalette.gold, positiveZ: true);
        mesh.addBox(2.62, 0.20, 0.20, 0.72, 1.35, 1.45, DesertPalette.wood);
        mesh.addSlopedAwning(2.62, 1.65, 1.48, 0.20, 0.86, 1.55, DesertPalette.terracotta);
      }

      // Level 5: Rooftop solar panel array + spinning brass weathervane!
      if (level >= 5) {
        mesh.addTaperedBox(
          cx: -0.35,
          yBottom: 2.81,
          cz: -0.75,
          bottomLen: 1.55,
          bottomWid: 0.88,
          topLen: 1.55,
          topWid: 0.72,
          height: 0.24,
          topShiftZ: 0.08,
          color: DesertPalette.metalDark,
          topColor: const Color(0xFF2B4663),
        );
        mesh.addBox(1.85, 3.07, 1.06, 0.08, 0.72, 0.08, DesertPalette.metalDark);
        mesh.withTransform(const Vec3(1.85, 3.74, 1.06), animTime * 1.6, () {
          mesh.addBox(0, 0, 0, 0.56, 0.07, 0.08, DesertPalette.gold);
          mesh.addBox(0, 0, 0, 0.08, 0.07, 0.56, DesertPalette.gold);
        });
      }
    });
  }
}
