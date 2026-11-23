import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 3B: Centerpiece Route 163 Desert Diner with retro checkered patio tiles,
/// Art-Deco chrome pilasters & entry canopy, crimson roofline neon, and spinning golden roof star!
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
    mesh.addBoxShadow(
      origin.x,
      origin.z,
      5.8,
      4.1,
      3.5,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(origin, 0, () {
      // Elevated diner plaza slab + retro red/cream checkered walkway tiles in front of entry
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

      // Main retro cream hall + red & turquoise horizontal diner bands
      mesh.addBox(0, 0.22, -0.28, 5.45, 2.65, 3.05, DesertPalette.cream);
      mesh.addBox(0, 2.40, -0.28, 5.58, 0.32, 3.18, DesertPalette.awningRed);
      mesh.addBox(0, 2.18, -0.28, 5.54, 0.18, 3.14, DesertPalette.turquoise);
      // Glowing retro crimson neon trim tube wrapping the roofline at night
      mesh.addBox(
        0,
        2.74,
        -0.28,
        5.66,
        0.09,
        3.26,
        DesertPalette.awningRed,
        emissiveColor: DesertPalette.neonCoral,
        emissiveStrength: 0.95,
        depthBias: -0.16,
      );
      mesh.addBox(0, 2.87, -0.28, 5.68, 0.30, 3.28, DesertPalette.creamDark);

      // Entry vestibule with Art-Deco chrome pilasters, canopy overhang & framed glass door
      mesh.addBox(0, 0.22, 1.38, 1.62, 2.20, 0.70, DesertPalette.cream);
      mesh.addBox(-0.78, 0.22, 1.72, 0.14, 2.00, 0.14, DesertPalette.metal);
      mesh.addBox(0.78, 0.22, 1.72, 0.14, 2.00, 0.14, DesertPalette.metal);
      mesh.addBox(0, 2.16, 1.66, 1.92, 0.14, 0.74, DesertPalette.metal);
      mesh.addBox(
        0,
        2.12,
        2.02,
        1.94,
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

      // Panoramic diner booth windows with mullions
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: -1.78,
        cy: 1.36,
        zWall: 1.25,
        width: 1.46,
        height: 1.02,
        frameColor: DesertPalette.metalDark,
      );
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: 1.78,
        cy: 1.36,
        zWall: 1.25,
        width: 1.46,
        height: 1.02,
        frameColor: DesertPalette.metalDark,
      );
      mesh.addRightWindow(2.73, 1.36, -0.28, 1.50, 1.02, DesertPalette.windowDay, DesertPalette.windowNight);
      mesh.addLeftWindow(-2.73, 1.36, -0.28, 1.50, 1.02, DesertPalette.windowDay, DesertPalette.windowNight);

      // Kitchen exhaust chimney, vent ductwork & AC pod
      mesh.addBox(-1.90, 3.17, -1.0, 0.66, 0.78, 0.66, DesertPalette.metal);
      mesh.addBox(-1.90, 3.95, -1.0, 0.78, 0.12, 0.78, DesertPalette.metalDark);
      mesh.addBox(1.75, 3.17, -0.82, 0.92, 0.42, 0.78, DesertPalette.metalDark);

      // Iconic retro "DINER" neon marquee
      MeshParts.addMarqueeSign(
        mesh,
        cx: 0,
        yBottom: 3.17,
        cz: 1.02,
        width: 3.20,
        height: 1.06,
        text: 'DINER',
        frameColor: DesertPalette.awningRed,
        glowColor: DesertPalette.neonCoral,
        textColor: DesertPalette.sandstoneDark,
        depth: 0.24,
        glowRadius: 42,
      );

      mesh.addGlow(const Vec3(-1.65, 1.4, 1.45), DesertPalette.windowNight, radius: 32, intensity: 0.68);
      mesh.addGlow(const Vec3(1.65, 1.4, 1.45), DesertPalette.windowNight, radius: 32, intensity: 0.68);

      // Level 2+: Outdoor patio dining umbrellas with chairs
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

      // Level 3+: Slowly rotating retro golden rooftop star beacon!
      if (level >= 3) {
        mesh.addBox(0, 4.23, 1.02, 0.15, 0.56, 0.15, DesertPalette.metal);
        mesh.withTransform(const Vec3(0, 4.79, 1.02), animTime * 0.9, () {
          mesh.addBox(
            0,
            0,
            0,
            0.48,
            0.48,
            0.22,
            DesertPalette.gold,
            emissiveColor: DesertPalette.gold,
            emissiveStrength: 0.95,
          );
        });
      }
    });
  }
}
