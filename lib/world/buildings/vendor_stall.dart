import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';
import '../characters/vendor_character.dart';
import 'vendor_cart.dart';

/// STAGE 1: Evolves visually across ALL 5 LEVELS:
/// Lv 1: Tiny wooden push-cart -> Lv 2: Timber stall & striped awning -> Lv 3: DRINKS marquee & patio
/// -> Lv 4: Navajo rug runner & overhead festoon string-light arch -> Lv 5: Twin patio + fluttering pennant mast!
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
    if (level <= 1) {
      VendorCartBuilding.build(mesh, origin, lighting, shadowCol, animTime);
      return;
    }

    mesh.withTransform(origin, 0, () {
      mesh.addBoxShadow(0, 0, 3.3, 2.5, 2.5, lighting.shadowDirection, shadowCol);

      // Woven southwestern doormat in front of counter
      mesh.addGroundRect(0, 0.032, 1.48, 1.85, 0.58, DesertPalette.terracotta, layer: RenderLayer.groundDecal, depthBias: -0.1);
      mesh.addGroundRect(0, 0.034, 1.48, 1.32, 0.36, DesertPalette.cream, layer: RenderLayer.groundDecal, depthBias: -0.14);

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
          cx: 2.10,
          yBottom: 0,
          cz: 0.50,
          umbrellaColor: DesertPalette.turquoise,
        );
        MeshParts.addPottedCactus(mesh, cx: -1.85, yBottom: 0, cz: -0.45);
      }

      // Level 4+: Woven Navajo counter banner & glowing side festoon string-light pole!
      if (level >= 4) {
        mesh.addFlushRectOnZ(0, 0.64, 0.97, 1.65, 0.46, DesertPalette.turquoise, positiveZ: true);
        mesh.addFlushRectOnZ(0, 0.64, 0.98, 1.15, 0.28, DesertPalette.gold, positiveZ: true);
        mesh.addBox(2.55, 0, 1.25, 0.12, 2.35, 0.12, DesertPalette.woodDark);
        mesh.addSaggingWire(
          const Vec3(1.38, 2.15, 0.80),
          const Vec3(2.55, 2.28, 1.25),
          DesertPalette.woodDark,
          sag: 0.18,
          bulbCount: 3,
          bulbGlowColor: DesertPalette.windowNight,
        );
      }

      // Level 5: Flagship left patio umbrella + tall fluttering crimson/gold desert pennant mast!
      if (level >= 5) {
        MeshParts.addPatioUmbrellaTable(
          mesh,
          cx: -2.15,
          yBottom: 0,
          cz: -0.10,
          umbrellaColor: DesertPalette.gold,
          scale: 0.88,
        );
        mesh.addBox(1.42, 2.33, -0.90, 0.08, 1.25, 0.08, DesertPalette.woodDark);
        final flutter = math.sin(animTime * 4.5) * 0.12;
        mesh.addTri(
          const Vec3(1.46, 3.52, -0.90),
          const Vec3(1.46, 3.16, -0.90),
          Vec3(2.18, 3.34, -0.90 + flutter),
          DesertPalette.gold,
          doubleSided: true,
        );
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
