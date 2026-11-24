import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';
import '../characters/vendor_character.dart';

/// LEVEL 1 Starter Asset: Handcrafted tiny wooden desert drink cart with iron-rimmed
/// spoked wheels, striped sun umbrella wedges, glass lemonade dispenser jug, blue cooler,
/// woven desert mat, cash tin, hanging brass camp lantern, and animated vendor.
class VendorCartBuilding {
  const VendorCartBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    mesh.addBoxShadow(
      origin.x,
      origin.z,
      2.2,
      1.6,
      2.0,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(origin, 0, () {
      // Woven desert mat under the tiny cart
      mesh.addGroundRect(0, 0.028, 0.15, 2.25, 1.55, DesertPalette.terracotta, layer: RenderLayer.groundDecal, depthBias: -0.06);
      mesh.addGroundRect(0, 0.030, 0.15, 1.80, 1.15, DesertPalette.creamDark, layer: RenderLayer.groundDecal, depthBias: -0.08);

      // Two sturdy iron-rimmed spoked cart wheels + hubs (flush outside cart body at x = ±0.71)
      for (final wx in [-0.77, 0.77]) {
        mesh.addBox(wx, 0.0, 0.05, 0.12, 0.58, 0.58, DesertPalette.woodDark);
        final isRight = wx > 0;
        mesh.addFlushRectOnX(
          wx + (isRight ? 0.06 : -0.06),
          0.29,
          0.05,
          0.42,
          0.42,
          DesertPalette.woodLight,
          positiveX: isRight,
        );
        mesh.addFlushRectOnX(
          wx + (isRight ? 0.072 : -0.072),
          0.29,
          0.05,
          0.16,
          0.16,
          DesertPalette.metalDark,
          positiveX: isRight,
        );
      }
      // Front wooden kickstand pegs (stopping cleanly at cart body bottom y = 0.34)
      mesh.addBox(-0.56, 0.0, 0.44, 0.09, 0.34, 0.09, DesertPalette.woodDark, skipTop: true);
      mesh.addBox(0.56, 0.0, 0.44, 0.09, 0.34, 0.09, DesertPalette.woodDark, skipTop: true);

      // Compact timber push-cart body (y = 0.34..0.98, skipTop) & cream serving top (y = 0.98..1.07)
      mesh.addBox(0, 0.34, 0.08, 1.42, 0.64, 0.90, DesertPalette.wood, skipTop: true);
      mesh.addBox(0, 0.98, 0.08, 1.56, 0.09, 1.00, DesertPalette.cream);

      // Wooden hand-pull push handles sticking out on the right side (+X, starting cleanly at x = 0.71)
      mesh.addBox(0.99, 0.82, -0.18, 0.54, 0.08, 0.08, DesertPalette.woodLight);
      mesh.addBox(0.99, 0.82, 0.34, 0.54, 0.08, 0.08, DesertPalette.woodLight);
      mesh.addBox(1.26, 0.82, 0.08, 0.08, 0.08, 0.58, DesertPalette.woodDark);

      // Turquoise ice chest cooler + glass lemonade dispenser jug + stacked cups + cash tin!
      mesh.addBox(-0.36, 1.07, 0.04, 0.56, 0.42, 0.48, DesertPalette.turquoise, skipTop: true);
      mesh.addBox(-0.36, 1.49, 0.04, 0.60, 0.07, 0.52, DesertPalette.cream);
      // Golden lemonade jug with brass lid
      mesh.addFrustum(0.18, 1.07, 0.14, 0.16, 0.16, 0.14, 0.14, 0.34, 6, DesertPalette.gold, topColor: DesertPalette.cream);
      mesh.addBox(0.18, 1.41, 0.14, 0.18, 0.05, 0.18, DesertPalette.woodDark);
      // Cold soda bottles + metal cash box
      mesh.addBox(0.46, 1.07, 0.24, 0.10, 0.22, 0.10, DesertPalette.awningRed);
      mesh.addBox(0.58, 1.07, 0.24, 0.10, 0.24, 0.10, DesertPalette.water);
      mesh.addBox(0.46, 1.07, -0.14, 0.28, 0.16, 0.22, DesertPalette.metalDark);

      // Hand-painted wooden sign flush in front of cart front wall (z = 0.53)
      mesh.addFlushRectOnZ(0, 0.67, 0.535, 1.14, 0.44, DesertPalette.woodDark, positiveZ: true);
      mesh.addFlushRectOnZ(0, 0.67, 0.555, 1.04, 0.36, DesertPalette.cream, positiveZ: true);
      mesh.addFrontSignText(
        0,
        0.67,
        0.58,
        1.00,
        0.34,
        'DRINKS',
        DesertPalette.sandstoneDark,
        glowColor: DesertPalette.neonWarm,
        nightGlow: false,
      );

      // Supply crate + water jug on sand beside the cart
      mesh.addBox(-1.14, 0.0, 0.06, 0.46, 0.42, 0.44, DesertPalette.woodLight);
      mesh.addFrustum(-1.14, 0.42, 0.06, 0.14, 0.14, 0.10, 0.10, 0.28, 6, DesertPalette.water);

      // Striped hexagonal desert shade umbrella (pole starts on countertop y = 1.07 and stops under canopy y = 2.22)
      mesh.addBox(-0.48, 1.07, -0.26, 0.08, 1.15, 0.08, DesertPalette.woodDark, skipTop: true);
      const ux = -0.48;
      const uz = -0.26;
      const uBaseY = 2.22;
      const uTopY = 2.62;
      const uRadius = 1.12;
      const apex = Vec3(ux, uTopY, uz);
      for (int i = 0; i < 6; i++) {
        final a0 = (i / 6) * math.pi * 2.0;
        final a1 = ((i + 1) / 6) * math.pi * 2.0;
        final p0 = Vec3(ux + math.cos(a0) * uRadius, uBaseY, uz + math.sin(a0) * uRadius);
        final p1 = Vec3(ux + math.cos(a1) * uRadius, uBaseY, uz + math.sin(a1) * uRadius);
        mesh.addTri(
          p1,
          p0,
          apex,
          i.isEven ? DesertPalette.terracotta : DesertPalette.cream,
          doubleSided: true,
        );
      }
      mesh.addBox(ux, uTopY, uz, 0.12, 0.10, 0.12, DesertPalette.woodDark);

      // Hanging glowing brass camp lantern cleanly beneath the umbrella canopy
      mesh.addBox(-0.08, 2.16, -0.14, 0.04, 0.22, 0.04, DesertPalette.metalDark);
      mesh.addBox(
        -0.08,
        1.96,
        -0.14,
        0.15,
        0.20,
        0.15,
        DesertPalette.cream,
        emissiveColor: DesertPalette.windowNight,
        emissiveStrength: 1.0,
      );
      mesh.addGlow(
        const Vec3(-0.08, 2.02, -0.14),
        DesertPalette.windowNight,
        radius: 24,
        intensity: 0.74,
      );

      // Cheerful vendor character standing behind the tiny cart
      VendorCharacter.build(mesh, const Vec3(0.24, 0.0, -0.56), animTime);
    });
  }
}
