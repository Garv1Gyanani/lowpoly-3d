import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';
import '../characters/vendor_character.dart';
import 'vendor_cart.dart';

/// STAGE 1: Evolves from a tiny wooden push-cart (Lv 1) -> full timber roadside
/// vendor stall with striped awning & string bulbs (Lv 2) -> rooftop sign & patio umbrella (Lv 3+).
class VendorStallBuilding {
  const VendorStallBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    // Level 1: Humble tiny wooden desert cart!
    if (level <= 1) {
      VendorCartBuilding.build(mesh, origin, lighting, shadowCol, animTime);
      return;
    }

    mesh.addBoxShadow(
      origin.x,
      origin.z,
      3.3,
      2.5,
      2.5,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(origin, 0, () {
      // Woven southwestern doormat in front of counter
      mesh.addGroundRect(0, 0.032, 1.48, 1.8, 0.56, DesertPalette.terracotta, layer: RenderLayer.groundDecal, depthBias: -0.1);
      mesh.addGroundRect(0, 0.034, 1.48, 1.3, 0.34, DesertPalette.cream, layer: RenderLayer.groundDecal, depthBias: -0.14);

      // Wooden deck platform & back slat wall
      mesh.addBox(0, 0, 0, 3.4, 0.18, 2.5, DesertPalette.woodLight);
      mesh.addBox(0, 0.18, -0.90, 2.95, 2.05, 0.18, DesertPalette.wood);
      mesh.addBox(0, 1.32, -0.74, 2.2, 0.08, 0.22, DesertPalette.woodLight);
      for (final bx in [-0.75, -0.45, -0.15, 0.45, 0.72]) {
        mesh.addBox(
          bx,
          1.40,
          -0.74,
          0.11,
          0.26,
          0.11,
          bx < 0 ? DesertPalette.turquoise : DesertPalette.awningRed,
        );
      }

      for (final x in [-1.38, 1.38]) {
        for (final z in [-0.90, 0.80]) {
          mesh.addBox(x, 0.18, z, 0.15, 2.15, 0.15, DesertPalette.woodDark);
        }
      }

      // Serving counter & countertop bottles + snack jar
      mesh.addBox(0, 0.18, 0.68, 2.70, 0.88, 0.58, DesertPalette.wood);
      mesh.addBox(0, 1.06, 0.68, 2.86, 0.10, 0.72, DesertPalette.cream);
      mesh.addBox(-0.88, 1.16, 0.68, 0.12, 0.26, 0.12, DesertPalette.water);
      mesh.addBox(-0.70, 1.16, 0.68, 0.12, 0.24, 0.12, DesertPalette.awningRed);
      mesh.addBox(-0.52, 1.16, 0.68, 0.12, 0.26, 0.12, DesertPalette.gold);
      mesh.addBox(0.88, 1.16, 0.66, 0.28, 0.30, 0.28, DesertPalette.terracotta);

      // Drinks cooler & supply crates
      mesh.addBox(-1.08, 0.18, 0.14, 0.68, 0.64, 0.52, DesertPalette.turquoise);
      mesh.addBox(-1.08, 0.82, 0.14, 0.72, 0.10, 0.56, DesertPalette.cream);
      mesh.addBox(1.10, 0.18, -0.14, 0.52, 0.48, 0.48, DesertPalette.woodLight);
      mesh.addBox(1.06, 0.66, -0.16, 0.40, 0.34, 0.38, DesertPalette.terracotta);

      VendorCharacter.build(mesh, const Vec3(0.10, 0.24, -0.08), animTime);

      mesh.addSlopedAwning(
        0,
        2.44,
        2.06,
        0.02,
        3.35,
        2.32,
        DesertPalette.awningRed,
        stripeColor: DesertPalette.cream,
        stripes: 6,
      );

      for (final lx in [-1.15, -0.58, 0.0, 0.58, 1.15]) {
        mesh.addBox(
          lx,
          1.84,
          1.12,
          0.11,
          0.11,
          0.11,
          DesertPalette.cream,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 1.0,
          depthBias: -0.22,
        );
      }

      mesh.addBox(-2.0, 0, 0.92, 0.62, 0.84, 0.12, DesertPalette.woodDark);
      mesh.addBox(-2.0, 0.14, 0.96, 0.50, 0.60, 0.08, const Color(0xFF333B3D), depthBias: -0.18);

      // Level 3+: Illuminated rooftop "DRINKS" marquee + patio umbrella seating & cactus planter
      if (level >= 3) {
        MeshParts.addMarqueeSign(
          mesh,
          cx: 0,
          yBottom: 2.45,
          cz: -0.50,
          width: 2.35,
          height: 0.62,
          text: 'DRINKS',
          frameColor: DesertPalette.woodDark,
          glowColor: DesertPalette.neonWarm,
          textColor: DesertPalette.sandstoneDark,
          depth: 0.18,
          glowRadius: 28,
        );
        MeshParts.addPatioUmbrellaTable(
          mesh,
          cx: 2.05,
          yBottom: 0,
          cz: 0.50,
          umbrellaColor: DesertPalette.turquoise,
        );
        MeshParts.addPottedCactus(mesh, cx: -1.85, yBottom: 0, cz: -0.45);
      }

      mesh.addGlow(
        const Vec3(0, 1.9, 0.65),
        DesertPalette.windowNight,
        radius: 30,
        intensity: 0.80,
      );
    });
  }
}
