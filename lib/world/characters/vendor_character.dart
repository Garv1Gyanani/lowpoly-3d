import 'dart:math' as math;
import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Stylized low-poly roadside vendor character with cream apron, terracotta bandana,
/// gentle animated serving arms, and wide-brim desert straw hat with hatband.
class VendorCharacter {
  const VendorCharacter._();

  static void build(MeshBuilder mesh, Vec3 localPos, double animTime) {
    final bob = math.sin(animTime * 3.5).abs() * 0.04;
    final wave = math.sin(animTime * 3.5) * 0.06;

    mesh.withTransform(localPos + Vec3(0, bob, 0), 0, () {
      // Boots & legs
      mesh.addBox(-0.08, 0.0, 0, 0.12, 0.26, 0.14, const Color(0xFF475769));
      mesh.addBox(0.08, 0.0, 0, 0.12, 0.26, 0.14, const Color(0xFF475769));
      // Shirt torso + crisp flush cream apron on front (+Z)
      mesh.addBox(0, 0.24, 0, 0.40, 0.52, 0.30, DesertPalette.terracotta);
      mesh.addFlushRectOnZ(0, 0.44, 0.15, 0.28, 0.42, DesertPalette.cream, positiveZ: true);
      // Arms gently gesturing while serving
      const skin = Color(0xFFE7BA93);
      mesh.addBox(-0.25, 0.36 + wave, 0.04, 0.10, 0.28, 0.10, skin);
      mesh.addBox(0.25, 0.36 - wave, 0.04, 0.10, 0.28, 0.10, skin);
      // Head
      mesh.addBox(0, 0.76, 0, 0.30, 0.30, 0.30, skin);
      // Wide-brim straw desert hat + terracotta hatband
      mesh.addBox(0, 1.04, 0, 0.60, 0.07, 0.60, DesertPalette.sand);
      mesh.addBox(0, 1.11, 0, 0.34, 0.05, 0.34, DesertPalette.awningRed);
      mesh.addBox(0, 1.16, 0, 0.32, 0.13, 0.32, DesertPalette.sandDark);
    });
  }
}
