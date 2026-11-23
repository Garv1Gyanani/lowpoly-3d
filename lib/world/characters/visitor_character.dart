import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../models/game_models.dart';
import '../../theme/desert_palette.dart';

/// Stylized animated low-poly desert traveller wrapped in a deterministic sort group
/// so backpack, arms, legs, sunglasses & sun hat NEVER pop while walking or turning!
class VisitorCharacter {
  const VisitorCharacter._();

  static void build(
    MeshBuilder mesh,
    VisitorEntity visitor,
    DesertLighting lighting,
  ) {
    final walking = visitor.phase != VisitorPhase.shopping;
    final stride = walking ? math.sin(visitor.walkCycle * 10.0) : 0.0;
    final bob = walking ? stride.abs() * 0.06 : 0.0;

    // Ground shadow outside sort group so it always stays in RenderLayer.shadow
    mesh.addGroundRect(
      visitor.position.x,
      0.022,
      visitor.position.z,
      0.40,
      0.40,
      Color.from(alpha: lighting.shadowAlpha, red: 0.2, green: 0.12, blue: 0.08),
      layer: RenderLayer.shadow,
      unlit: true,
    );

    // Deterministic sort group anchored at visitor center -> zero body-part popping!
    mesh.withSortGroup(visitor.position + const Vec3(0, 0.55, 0), () {
      mesh.withTransform(visitor.position, visitor.yaw, () {
        const legCol = Color(0xFF475769);
        const skinCol = Color(0xFFEBC09B);

        // SubOrder 0: Animated swinging legs & desert boots
        mesh.withSubOrder(0, () {
          mesh.addBox(stride * 0.10, 0.0, -0.08, 0.13, 0.10, 0.12, DesertPalette.woodDark);
          mesh.addBox(-stride * 0.10, 0.0, 0.08, 0.13, 0.10, 0.12, DesertPalette.woodDark);
          mesh.addBox(stride * 0.10, 0.10, -0.08, 0.12, 0.25, 0.11, legCol);
          mesh.addBox(-stride * 0.10, 0.10, 0.08, 0.12, 0.25, 0.11, legCol);
        });

        // SubOrder 1: Torso, swinging arms & trail backpack (sorted strictly by localDepth!)
        mesh.withSubOrder(1, () {
          mesh.addBox(0, 0.34 + bob, 0, 0.24, 0.42, 0.32, visitor.shirtColor);
          mesh.addBox(-stride * 0.09, 0.38 + bob, -0.21, 0.10, 0.30, 0.09, skinCol);
          mesh.addBox(stride * 0.09, 0.38 + bob, 0.21, 0.10, 0.30, 0.09, skinCol);
          mesh.addBox(-0.18, 0.40 + bob, 0, 0.12, 0.32, 0.24, DesertPalette.woodLight);
          mesh.addBox(-0.18, 0.66 + bob, 0, 0.10, 0.09, 0.26, DesertPalette.terracotta); // sleeping roll
        });

        // SubOrder 2: Head + flush sunglasses on front face (+X) + desert sun hat
        mesh.withSubOrder(2, () {
          mesh.addBox(0, 0.76 + bob, 0, 0.24, 0.25, 0.24, skinCol);
          mesh.addFlushRectOnX(
            0.12,
            0.90 + bob,
            0,
            0.18,
            0.06,
            DesertPalette.asphalt,
            positiveX: true,
            subOrder: 3,
          );
          mesh.addBox(0, 1.01 + bob, 0, 0.42, 0.06, 0.42, visitor.hatColor, subOrder: 3);
          mesh.addBox(0, 1.07 + bob, 0, 0.24, 0.10, 0.24, visitor.hatColor, subOrder: 3);
        });
      });
    });
  }
}
