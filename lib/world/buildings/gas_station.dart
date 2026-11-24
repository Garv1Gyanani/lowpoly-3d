import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 4: Canyon Gas Station & Garage evolving visually through Level 5.
class GasStationBuilding {
  const GasStationBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol, [
    double animTime = 0.0,
  ]) {
    mesh.withTransform(origin, 0, () {
      mesh.addBoxShadow(0, 0, 5.4, 4.1, 3.3, lighting.shadowDirection, shadowCol);

      mesh.addBox(0, 0, 0.2, 5.5, 0.18, 4.4, DesertPalette.concrete);
      mesh.addBox(0.25, 0.18, -1.12, 4.75, 2.48, 1.82, DesertPalette.cream, skipTop: true);
      MeshParts.addAdobeParapetRoof(
        mesh,
        cx: 0.25,
        yBase: 2.66,
        cz: -1.12,
        width: 4.78,
        depth: 1.85,
        parapetHeight: 0.26,
        parapetColor: DesertPalette.terracotta,
        addVigasBeams: false,
      );

      // Garage door seated strictly in front of wall (z = -0.21) with flush horizontal slats
      mesh.addBox(-0.78, 0.18, -0.18, 1.88, 1.75, 0.06, DesertPalette.metal);
      for (final sy in [0.55, 0.92, 1.29, 1.66]) {
        mesh.addFlushRectOnZ(-0.78, sy, -0.15, 1.84, 0.05, DesertPalette.metalDark, positiveZ: true);
      }

      MeshParts.addFramedFrontWindow(
        mesh,
        cx: 1.42,
        cy: 1.30,
        zWall: -0.21,
        width: 1.28,
        height: 0.90,
      );

      const canopyY = 2.75;
      mesh.addBox(-1.55, 0.18, 1.05, 0.30, canopyY - 0.18, 0.30, DesertPalette.creamDark, skipTop: true);
      mesh.addBox(1.55, 0.18, 1.05, 0.30, canopyY - 0.18, 0.30, DesertPalette.creamDark, skipTop: true);
      mesh.addBox(0, canopyY, 1.05, 4.75, 0.38, 2.12, DesertPalette.cream);
      mesh.addBox(0, canopyY + 0.08, 1.05, 4.86, 0.22, 2.22, DesertPalette.awningRed, skipTop: true);
      for (final lx in [-0.95, 0.95]) {
        mesh.addBox(
          lx,
          canopyY - 0.06,
          1.05,
          1.15,
          0.06,
          0.55,
          DesertPalette.cream,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 1.0,
          skipTop: true,
        );
        mesh.addGlow(Vec3(lx, canopyY - 0.18, 1.05), DesertPalette.windowNight, radius: 34, intensity: 0.85);
      }

      mesh.addBox(0, 0.18, 1.05, 2.85, 0.15, 0.72, DesertPalette.concrete);
      for (final bx in [-1.32, 1.32]) {
        mesh.addFrustum(bx, 0.33, 1.05, 0.09, 0.09, 0.08, 0.08, 0.62, 6, DesertPalette.gold);
      }
      for (final px in [-0.66, 0.66]) {
        mesh.addBox(px, 0.33, 1.05, 0.52, 1.12, 0.40, DesertPalette.awningRed, skipTop: true);
        mesh.addBox(px, 1.45, 1.05, 0.44, 0.14, 0.34, DesertPalette.cream);
        mesh.addBox(px + 0.30, 0.66, 1.05, 0.07, 0.54, 0.07, DesertPalette.asphalt);
        mesh.addBox(px + 0.30, 1.12, 1.05, 0.10, 0.14, 0.12, DesertPalette.metal);
        mesh.addFlushRectOnZ(
          px,
          1.08,
          1.25,
          0.35,
          0.32,
          DesertPalette.cream,
          positiveZ: true,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 0.85,
        );
      }

      if (level >= 2) {
        mesh.addBox(2.58, 0.18, 1.98, 0.22, 4.35, 0.22, DesertPalette.metalDark);
        MeshParts.addMarqueeSign(
          mesh,
          cx: 2.58,
          yBottom: 3.40,
          cz: 1.98,
          width: 1.56,
          height: 1.22,
          text: 'GAS\n3.49',
          frameColor: DesertPalette.awningRed,
          glowColor: DesertPalette.neonWarm,
          textColor: DesertPalette.sandstoneDark,
          depth: 0.26,
          glowRadius: 34,
        );
      }

      if (level >= 3) {
        mesh.addFrustum(-2.35, 0.18, -0.45, 0.32, 0.32, 0.32, 0.32, 0.48, 8, DesertPalette.asphalt);
        mesh.addFrustum(-2.35, 0.18, 0.36, 0.26, 0.26, 0.26, 0.26, 0.78, 8, DesertPalette.turquoise);
        mesh.addBox(-1.95, 0.18, 0.02, 0.48, 0.64, 0.36, DesertPalette.awningRed);
      }

      // Level 4+: Garage rooftop solar panels + red air/water tower stand
      if (level >= 4) {
        mesh.addTaperedBox(
          cx: 0.25,
          yBottom: 2.92,
          cz: -1.15,
          bottomLen: 2.6,
          bottomWid: 0.95,
          topLen: 2.6,
          topWid: 0.78,
          height: 0.18,
          topShiftZ: 0.10,
          color: DesertPalette.metalDark,
          topColor: const Color(0xFF2B4663),
        );
        mesh.addBox(-2.38, 0.18, 1.75, 0.34, 1.15, 0.30, DesertPalette.turquoise);
      }

      // Level 5: Spinning golden highway star-shield beacon atop the totem!
      if (level >= 5) {
        mesh.addBox(2.58, 4.62, 1.98, 0.12, 0.42, 0.12, DesertPalette.metal);
        mesh.withTransform(const Vec3(2.58, 5.05, 1.98), animTime * 1.1, () {
          mesh.addFrustum(
            0,
            0,
            0,
            0.42,
            0.16,
            0.32,
            0.14,
            0.48,
            6,
            DesertPalette.gold,
            emissiveColor: DesertPalette.gold,
            emissiveStrength: 0.95,
          );
        });
      }
    });
  }
}
