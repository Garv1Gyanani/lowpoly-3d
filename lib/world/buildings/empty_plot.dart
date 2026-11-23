import 'dart:math' as math;
import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../models/game_models.dart';
import '../../theme/desert_palette.dart';

/// Empty construction plot with corner timber stakes, red flags, and floating build sign.
class EmptyPlotBuilding {
  const EmptyPlotBuilding._();

  static void build(MeshBuilder mesh, PlotState plot, double animTime) {
    final p = plot.position;
    final w = plot.footprintWidth;
    final d = plot.footprintDepth;

    mesh.addGroundRect(
      p.x,
      0.032,
      p.z,
      w,
      d,
      const Color(0xFFCBB189),
      layer: RenderLayer.groundDecal,
      depthBias: -0.05,
      outlineColor: DesertPalette.wood.withValues(alpha: 0.7),
    );

    final hw = w * 0.45;
    final hd = d * 0.45;
    for (final sx in [-hw, hw]) {
      for (final sz in [-hd, hd]) {
        mesh.addBox(p.x + sx, 0, p.z + sz, 0.14, 0.56, 0.14, DesertPalette.wood);
        mesh.addBox(p.x + sx, 0.44, p.z + sz, 0.18, 0.12, 0.18, DesertPalette.awningRed);
      }
    }

    mesh.addBox(p.x, 0, p.z, 0.14, 0.92, 0.14, DesertPalette.woodDark);
    final bob = math.sin(animTime * 3.0) * 0.08;
    mesh.addBox(
      p.x,
      0.90 + bob,
      p.z,
      1.65,
      0.72,
      0.16,
      DesertPalette.cream,
      emissiveColor: DesertPalette.gold,
      emissiveStrength: 0.45,
      emissiveNightOnly: false,
    );
    final biz = kBusinessCatalog[plot.businessType]!;
    mesh.addFrontSignText(
      p.x,
      1.26 + bob,
      p.z + 0.09,
      1.55,
      0.64,
      '+ BUILD\n\$${biz.purchaseCost.toInt()}',
      DesertPalette.uiInk,
      glowColor: DesertPalette.gold,
      nightGlow: false,
    );
  }
}
