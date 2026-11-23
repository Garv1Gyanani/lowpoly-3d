import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 3A: Desert Food Stand & Coffee Kiosk ("CAFE") with festive fiesta bunting pennants,
/// bar stools with backrests, steaming rooftop coffee mug with cream foam, and chalkboard menu.
class FoodStandBuilding {
  const FoodStandBuilding._();

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
      3.5,
      2.6,
      2.6,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(origin, 0, () {
      mesh.addBox(0, 0, 0.1, 3.75, 0.16, 2.85, DesertPalette.concrete);
      mesh.addBox(0, 0.16, -0.18, 2.85, 2.20, 1.95, DesertPalette.terracotta);
      mesh.addBox(0, 2.18, -0.18, 3.0, 0.24, 2.10, DesertPalette.cream);

      // Serving counter window, chalkboard menu side panel & wooden bar shelf
      mesh.addFrontWindow(0, 1.38, 0.80, 1.88, 0.84, const Color(0xFF3E2D24), DesertPalette.windowNight);
      mesh.addFlushRectOnZ(-1.18, 1.38, 0.81, 0.36, 0.68, const Color(0xFF2F3638), positiveZ: true);
      mesh.addBox(0, 0.90, 0.95, 2.25, 0.11, 0.42, DesertPalette.woodLight);

      // Bar stools with cushions & low metal backrests
      for (final sx in [-0.70, 0.0, 0.70]) {
        mesh.addBox(sx, 0.16, 1.22, 0.11, 0.52, 0.11, DesertPalette.metalDark);
        mesh.addBox(sx, 0.68, 1.22, 0.32, 0.10, 0.32, DesertPalette.awningRed);
        mesh.addBox(sx, 0.78, 1.35, 0.26, 0.20, 0.05, DesertPalette.metalDark);
      }

      // Striped front canopy + colorful fiesta triangle pennant bunting + glowing bulbs
      mesh.addSlopedAwning(
        0,
        2.18,
        1.86,
        1.16,
        2.95,
        0.88,
        DesertPalette.wood,
        stripeColor: DesertPalette.cream,
        stripes: 6,
      );
      const pennantCols = [
        DesertPalette.awningRed,
        DesertPalette.gold,
        DesertPalette.turquoise,
        DesertPalette.cream,
        DesertPalette.terracotta,
        DesertPalette.gold,
      ];
      for (int i = 0; i < pennantCols.length; i++) {
        final px = -1.12 + i * 0.45;
        mesh.addTri(
          Vec3(px - 0.15, 1.74, 1.60),
          Vec3(px + 0.15, 1.74, 1.60),
          Vec3(px, 1.48, 1.60),
          pennantCols[i],
          doubleSided: true,
          depthBias: -0.22,
        );
      }
      for (final lx in [-0.85, 0.0, 0.85]) {
        mesh.addBox(
          lx,
          1.76,
          1.42,
          0.10,
          0.10,
          0.10,
          DesertPalette.cream,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 1.0,
          depthBias: -0.22,
        );
      }

      // Level 2+: Rooftop illuminated CAFE sign + steaming low-poly coffee cup with cream foam!
      if (level >= 2) {
        MeshParts.addMarqueeSign(
          mesh,
          cx: 0,
          yBottom: 2.42,
          cz: 0.52,
          width: 2.15,
          height: 0.60,
          text: 'CAFE',
          frameColor: DesertPalette.woodDark,
          glowColor: DesertPalette.neonCoral,
          textColor: DesertPalette.sandstoneDark,
          depth: 0.18,
          glowRadius: 28,
        );
        mesh.addFrustum(
          0,
          2.42,
          -0.38,
          0.38,
          0.38,
          0.48,
          0.48,
          0.78,
          8,
          DesertPalette.cream,
          topColor: DesertPalette.woodDark,
        );
        // Creamy espresso foam dome
        mesh.addFrustum(0, 3.18, -0.38, 0.36, 0.36, 0.14, 0.14, 0.14, 8, DesertPalette.cream);
        mesh.addBox(0.48, 2.66, -0.38, 0.22, 0.32, 0.11, DesertPalette.cream);

        for (int s = 0; s < 2; s++) {
          final phase = (animTime * 0.7 + s * 0.5) % 1.0;
          final sy = 3.36 + phase * 0.72;
          final sx = math.sin(animTime * 2.2 + s * 2.0) * 0.12;
          final sz = 0.16 * (1.0 - phase * 0.45);
          mesh.addBox(
            sx,
            sy,
            -0.38,
            sz,
            sz,
            sz,
            DesertPalette.cream.withValues(alpha: (1.0 - phase) * 0.75),
            emissiveColor: DesertPalette.cream,
            emissiveStrength: 0.6,
            emissiveNightOnly: false,
          );
        }
      }

      // Level 3+: Patio table with red sun umbrella & cactus planter
      if (level >= 3) {
        MeshParts.addPatioUmbrellaTable(
          mesh,
          cx: -2.0,
          yBottom: 0.16,
          cz: 0.45,
          umbrellaColor: DesertPalette.awningRed,
          scale: 0.94,
        );
        MeshParts.addPottedCactus(mesh, cx: 1.56, yBottom: 0.16, cz: 0.88);
      }

      mesh.addGlow(
        const Vec3(0, 1.55, 0.98),
        DesertPalette.windowNight,
        radius: 28,
        intensity: 0.76,
      );
    });
  }
}
