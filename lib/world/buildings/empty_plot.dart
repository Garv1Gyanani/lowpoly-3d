import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../models/game_models.dart';
import '../../theme/desert_palette.dart';

/// Clean staked construction plot with perimeter survey rope and stacked timber/bricks.
/// Leaves price/action labeling strictly to the single floating `WorldActionBubble` (no duplicate text!).
class EmptyPlotBuilding {
  const EmptyPlotBuilding._();

  static void build(MeshBuilder mesh, PlotState plot, DesertLighting lighting) {
    final w = plot.footprintWidth;
    final d = plot.footprintDepth;

    mesh.withTransform(plot.position, plot.yaw, () {
      mesh.addGroundRect(
        0,
        0.032,
        0,
        w,
        d,
        const Color(0xFFD1B78F),
        layer: RenderLayer.groundDecal,
        depthBias: -0.05,
        outlineColor: DesertPalette.wood.withValues(alpha: 0.65),
      );

      final hw = w * 0.45;
      final hd = d * 0.45;
      final corners = [
        Vec3(-hw, 0, -hd),
        Vec3(hw, 0, -hd),
        Vec3(hw, 0, hd),
        Vec3(-hw, 0, hd),
      ];

      for (final c in corners) {
        mesh.addBox(c.x, 0, c.z, 0.13, 0.62, 0.13, DesertPalette.woodDark);
        mesh.addBox(c.x, 0.50, c.z, 0.17, 0.11, 0.17, DesertPalette.awningRed);
      }

      // Perimeter cord linking the 4 stakes
      for (int i = 0; i < 4; i++) {
        final a = corners[i] + const Vec3(0, 0.46, 0);
        final b = corners[(i + 1) % 4] + const Vec3(0, 0.46, 0);
        mesh.addSaggingWire(a, b, DesertPalette.woodLight, sag: 0.08, thickness: 0.025, segments: 3);
      }

      // Neat stack of waiting timber planks & adobe bricks inside the plot
      mesh.addBoxShadow(-0.45, -0.15, 1.3, 0.7, 0.45, lighting.shadowDirection, lighting.shadowColor);
      mesh.addBox(-0.45, 0.03, -0.22, 1.25, 0.12, 0.48, DesertPalette.woodLight);
      mesh.addBox(-0.42, 0.15, -0.18, 1.18, 0.12, 0.44, DesertPalette.wood);
      mesh.addBox(0.55, 0.03, 0.22, 0.56, 0.28, 0.46, DesertPalette.terracotta);
      mesh.addBox(0.55, 0.31, 0.22, 0.42, 0.18, 0.36, DesertPalette.sandstone);
    });
  }
}
