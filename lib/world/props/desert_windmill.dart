import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Classic spinning western wooden desert windmill with open 4-leg timber lattice tower,
/// cross-braces, service ladder, metallic rotor ring, 8 blades & painted red tail vane.
class DesertWindmill {
  const DesertWindmill._();

  static void build(
    MeshBuilder mesh,
    Vec3 position,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    if (position.y < 0.05) {
      mesh.addBoxShadow(
        position.x,
        position.z,
        1.7,
        1.7,
        5.8,
        lighting.shadowDirection,
        shadowCol,
      );
    }

    mesh.withTransform(position, 0, () {
      // Concrete footing pads + 4 angled open-frame wooden tower legs (segmented upward)
      const tiers = 4;
      const totalH = 5.1;
      const baseSpread = 0.72;
      const topSpread = 0.24;

      for (final sx in [-1.0, 1.0]) {
        for (final sz in [-1.0, 1.0]) {
          // Footing block
          mesh.addBox(sx * baseSpread, 0, sz * baseSpread, 0.24, 0.16, 0.24, DesertPalette.concrete);
          for (int t = 0; t < tiers; t++) {
            final f0 = t / tiers;
            final f1 = (t + 1) / tiers;
            final fm = (f0 + f1) * 0.5;
            final sp = baseSpread + (topSpread - baseSpread) * fm;
            final y0 = f0 * totalH;
            final segH = totalH / tiers + 0.08;
            mesh.addBox(sx * sp, y0, sz * sp, 0.13, segH, 0.13, DesertPalette.wood);
          }
        }
      }

      // Horizontal timber cross-beams at 3 levels for authentic lattice silhouette
      for (final frac in [0.28, 0.56, 0.82]) {
        final y = frac * totalH;
        final sp = baseSpread + (topSpread - baseSpread) * frac;
        final span = sp * 2.0 + 0.12;
        mesh.addBox(0, y, sp, span, 0.10, 0.10, DesertPalette.woodDark);
        mesh.addBox(0, y, -sp, span, 0.10, 0.10, DesertPalette.woodDark);
        mesh.addBox(sp, y, 0, 0.10, 0.10, span, DesertPalette.woodDark);
        mesh.addBox(-sp, y, 0, 0.10, 0.10, span, DesertPalette.woodDark);
      }

      // Vertical wooden service ladder rungs on front face
      for (int r = 1; r <= 9; r++) {
        final frac = r / 10.5;
        final y = frac * totalH;
        final z = baseSpread + (topSpread - baseSpread) * frac + 0.06;
        mesh.addBox(0, y, z, 0.36, 0.06, 0.06, DesertPalette.woodLight);
      }

      // Top service platform, gear housing & red metal tail vane
      mesh.addBox(0, 5.02, 0, 0.82, 0.14, 0.82, DesertPalette.woodDark);
      mesh.addBox(0, 5.16, 0, 0.38, 0.38, 0.72, DesertPalette.metalDark);
      mesh.addBox(0, 5.26, -0.52, 0.08, 0.10, 0.65, DesertPalette.metal);
      mesh.addBox(0, 5.14, -0.92, 0.08, 0.70, 0.78, DesertPalette.awningRed);
      mesh.addBox(0, 5.36, -0.92, 0.10, 0.14, 0.56, DesertPalette.cream, depthBias: -0.06);

      // Spinning 8-blade steel desert rotor facing +Z
      final angle = animTime * 1.05;
      const bladeCount = 8;
      const rIn = 0.22;
      const rOut = 1.46;
      const hubY = 5.35;
      const hubZ = 0.44;

      // Center spinner cone
      mesh.addBox(0, hubY - 0.14, hubZ + 0.04, 0.28, 0.28, 0.22, DesertPalette.awningRed, depthBias: -0.28);

      for (int i = 0; i < bladeCount; i++) {
        final a = angle + (i / bladeCount) * math.pi * 2.0;
        final a2 = a + 0.26;
        final p0 = Vec3(math.cos(a) * rIn, hubY + math.sin(a) * rIn, hubZ);
        final p1 = Vec3(math.cos(a) * rOut, hubY + math.sin(a) * rOut, hubZ);
        final p2 = Vec3(math.cos(a2) * rOut, hubY + math.sin(a2) * rOut, hubZ + 0.06);
        final p3 = Vec3(math.cos(a2) * rIn, hubY + math.sin(a2) * rIn, hubZ + 0.06);
        mesh.addQuad(
          p0,
          p1,
          p2,
          p3,
          i.isEven ? DesertPalette.cream : DesertPalette.metal,
          doubleSided: true,
          depthBias: -0.24,
        );
      }
    });
  }
}
