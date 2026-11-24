import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 3B: Centerpiece Route 163 Desert Diner with streamlined chrome corner drums,
/// mid-century Googie angled roof fin, checkered patio, and Lv1–Lv5 visual progression!
class DesertDinerBuilding {
  const DesertDinerBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    mesh.withTransform(origin, 0, () {
      mesh.addBoxShadow(0, 0, 5.9, 4.2, 3.6, lighting.shadowDirection, shadowCol);

      mesh.addBox(0, 0, 0.22, 6.0, 0.22, 4.35, DesertPalette.concrete);
      for (int i = 0; i < 6; i++) {
        mesh.addGroundRect(
          -2.5 + i * 1.0,
          0.225,
          2.16,
          0.98,
          0.38,
          i.isEven ? DesertPalette.awningRed : DesertPalette.cream,
          layer: RenderLayer.world,
          depthBias: -0.06,
        );
      }

      // Main retro diner hall + streamlined faceted chrome corner drums for distinct Googie silhouette!
      mesh.addBox(0, 0.22, -0.28, 5.15, 2.62, 3.02, DesertPalette.cream);
      for (final cx in [-2.52, 2.52]) {
        mesh.addFrustum(
          cx,
          0.22,
          -0.28,
          0.46,
          1.48,
          0.46,
          1.48,
          2.62,
          6,
          DesertPalette.metal,
          topColor: DesertPalette.creamDark,
        );
      }

      mesh.addBox(0, 2.38, -0.28, 5.75, 0.30, 3.16, DesertPalette.awningRed);
      mesh.addBox(0, 2.16, -0.28, 5.72, 0.18, 3.12, DesertPalette.turquoise);
      mesh.addBox(
        0,
        2.72,
        -0.28,
        5.82,
        0.09,
        3.24,
        DesertPalette.awningRed,
        emissiveColor: DesertPalette.neonCoral,
        emissiveStrength: 0.95,
        depthBias: -0.16,
      );
      mesh.addBox(0, 2.84, -0.28, 5.84, 0.26, 3.26, DesertPalette.creamDark);

      // Iconic Mid-Century Googie swept boomerang roof wing!
      mesh.addTaperedBox(
        cx: 0,
        yBottom: 3.10,
        cz: 0.35,
        bottomLen: 4.20,
        bottomWid: 1.45,
        topLen: 5.10,
        topWid: 1.85,
        height: 0.24,
        topShiftZ: 0.28,
        color: DesertPalette.turquoise,
        topColor: DesertPalette.cream,
      );

      // Entry vestibule with Art-Deco chrome pilasters & canopy overhang
      mesh.addBox(0, 0.22, 1.38, 1.62, 2.20, 0.70, DesertPalette.cream);
      mesh.addBox(-0.78, 0.22, 1.72, 0.14, 2.00, 0.14, DesertPalette.metal);
      mesh.addBox(0.78, 0.22, 1.72, 0.14, 2.00, 0.14, DesertPalette.metal);
      mesh.addBox(0, 2.16, 1.66, 2.10, 0.14, 0.82, DesertPalette.metal);
      mesh.addBox(
        0,
        2.12,
        2.06,
        2.12,
        0.06,
        0.06,
        DesertPalette.turquoise,
        emissiveColor: DesertPalette.neonTurquoise,
        emissiveStrength: 0.95,
        depthBias: -0.20,
      );
      MeshParts.addFramedDoor(
        mesh,
        cx: 0,
        yBottom: 0.22,
        zWall: 1.73,
        width: 0.90,
        height: 1.68,
      );
      MeshParts.addPottedCactus(mesh, cx: -1.06, yBottom: 0.22, cz: 1.78);
      MeshParts.addPottedCactus(mesh, cx: 1.06, yBottom: 0.22, cz: 1.78);

      MeshParts.addFramedFrontWindow(
        mesh,
        cx: -1.72,
        cy: 1.36,
        zWall: 1.24,
        width: 1.42,
        height: 1.02,
        frameColor: DesertPalette.metalDark,
      );
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: 1.72,
        cy: 1.36,
        zWall: 1.24,
        width: 1.42,
        height: 1.02,
        frameColor: DesertPalette.metalDark,
      );
      mesh.addRightWindow(2.88, 1.36, -0.28, 1.30, 0.96, DesertPalette.windowDay, DesertPalette.windowNight);
      mesh.addLeftWindow(-2.88, 1.36, -0.28, 1.30, 0.96, DesertPalette.windowDay, DesertPalette.windowNight);

      mesh.addBox(-1.90, 3.10, -1.05, 0.66, 0.78, 0.66, DesertPalette.metal);
      mesh.addBox(-1.90, 3.88, -1.05, 0.78, 0.12, 0.78, DesertPalette.metalDark);
      mesh.addBox(1.75, 3.10, -0.95, 0.92, 0.42, 0.78, DesertPalette.metalDark);

      MeshParts.addMarqueeSign(
        mesh,
        cx: 0,
        yBottom: 3.34,
        cz: 0.92,
        width: 3.20,
        height: 1.04,
        text: 'DINER',
        frameColor: DesertPalette.awningRed,
        glowColor: DesertPalette.neonCoral,
        textColor: DesertPalette.sandstoneDark,
        depth: 0.24,
        glowRadius: 42,
      );

      mesh.addGlow(const Vec3(-1.65, 1.4, 1.45), DesertPalette.windowNight, radius: 32, intensity: 0.68);
      mesh.addGlow(const Vec3(1.65, 1.4, 1.45), DesertPalette.windowNight, radius: 32, intensity: 0.68);

      if (level >= 2) {
        for (final tx in [-2.05, 2.05]) {
          MeshParts.addPatioUmbrellaTable(
            mesh,
            cx: tx,
            yBottom: 0.22,
            cz: 1.90,
            umbrellaColor: DesertPalette.turquoise,
            scale: 0.90,
          );
        }
      }

      if (level >= 3) {
        mesh.addBox(0, 4.38, 0.92, 0.14, 0.54, 0.14, DesertPalette.metal);
        mesh.withTransform(const Vec3(0, 4.92, 0.92), animTime * 0.9, () {
          mesh.addBox(
            0,
            0,
            0,
            0.50,
            0.50,
            0.20,
            DesertPalette.gold,
            emissiveColor: DesertPalette.gold,
            emissiveStrength: 0.95,
          );
        });
      }

      // Level 4+: Glowing turquoise Googie side fins & retro jukebox alcove glow
      if (level >= 4) {
        for (final fx in [-2.35, 2.35]) {
          mesh.addTaperedBox(
            cx: fx,
            yBottom: 3.34,
            cz: 0.50,
            bottomLen: 0.16,
            bottomWid: 1.20,
            topLen: 0.12,
            topWid: 0.65,
            height: 0.72,
            topShiftZ: 0.25,
            color: DesertPalette.awningRed,
            topColor: DesertPalette.gold,
          );
        }
      }

      // Level 5: Twin flanking spinning Googie starbursts & neon highway menu pedestal!
      if (level >= 5) {
        for (final sx in [-1.85, 1.85]) {
          mesh.addBox(sx, 3.34, 0.92, 0.10, 0.42, 0.10, DesertPalette.metal);
          mesh.withTransform(Vec3(sx, 3.76, 0.92), -animTime * 1.2, () {
            mesh.addBox(
              0,
              0,
              0,
              0.32,
              0.32,
              0.14,
              DesertPalette.turquoise,
              emissiveColor: DesertPalette.neonTurquoise,
              emissiveStrength: 0.95,
            );
          });
        }
      }
    });
  }
}
