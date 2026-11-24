import 'dart:math' as math;
import 'dart:ui';

import '../engine/lighting.dart';
import '../engine/mesh_builder.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../theme/desert_palette.dart';
import 'buildings/desert_diner.dart';
import 'buildings/desert_motel.dart';
import 'buildings/empty_plot.dart';
import 'buildings/food_stand.dart';
import 'buildings/gas_station.dart';
import 'buildings/lookout_camp.dart';
import 'buildings/oasis_plaza.dart';
import 'buildings/outpost_mart.dart';
import 'buildings/vendor_stall.dart';

/// Dispatches each construction plot to its dedicated modular low-poly building file,
/// applying grounded squash-and-stretch animations (`y = 0` stays planted!) and subtle organic angles.
class BuildingModels {
  const BuildingModels._();

  /// Returns true when a plot has no per-frame mesh animation and can be baked into
  /// the static world cache for maximum FPS.
  static bool isStaticPlot(PlotState plot, {required bool isSelected}) {
    if (!plot.isBuilt || isSelected) return false;
    if (plot.bounceTimer > 0 || plot.buildPopTimer > 0) return false;
    return switch (plot.businessType) {
      BusinessType.convenienceStore => plot.level < 5,
      BusinessType.gasStation => plot.level < 5,
      BusinessType.desertMotel => true,
      BusinessType.desertDiner => plot.level < 3,
      BusinessType.foodStand => plot.level < 2,
      _ => false,
    };
  }

  static void buildPlot(
    MeshBuilder mesh,
    PlotState plot,
    DesertLighting lighting,
    double animTime, {
    required bool isSelected,
  }) {
    final shadowCol = lighting.shadowColor;

    if (isSelected) {
      final pulse = 0.55 + 0.35 * math.sin(animTime * 5.0);
      mesh.withTransform(plot.position, plot.yaw, () {
        mesh.addGroundRect(
          0,
          0.04,
          0,
          plot.footprintWidth + 0.6,
          plot.footprintDepth + 0.6,
          DesertPalette.gold.withValues(alpha: 0.28 * pulse),
          layer: RenderLayer.groundDecal,
          depthBias: -0.3,
          unlit: true,
          outlineColor: DesertPalette.gold.withValues(alpha: 0.85),
        );
      });
    }

    if (!plot.isBuilt) {
      EmptyPlotBuilding.build(mesh, plot, lighting);
      return;
    }

    // Grounded elastic squash-and-stretch (`y = 0` stays firmly planted on sand!)
    double scaleY = 1.0;
    double scaleXZ = 1.0;

    if (plot.bounceTimer > 0) {
      final t = plot.bounceTimer / 0.38;
      final wave = math.sin(t * math.pi * 2.5) * t.clamp(0.0, 1.0);
      scaleY = 1.0 + wave * 0.14;
      scaleXZ = 1.0 - wave * 0.065;
    }
    if (plot.buildPopTimer > 0) {
      final progress = (1.0 - plot.buildPopTimer).clamp(0.0, 1.0);
      // Overshoot spring curve: 0.3 -> 1.08 -> 1.0
      final ease = 1.0 - math.pow(1.0 - progress, 3);
      final spring = ease + math.sin(progress * math.pi) * 0.10;
      scaleY *= (0.28 + 0.72 * spring);
      scaleXZ *= (0.55 + 0.45 * spring);
    }

    mesh.withTransform(plot.position, plot.yaw, () {
      mesh.withScale(scaleXZ, scaleY, () {
        buildByType(
          mesh,
          plot.businessType,
          Vec3.zero,
          plot.level,
          lighting,
          shadowCol,
          animTime,
        );
      });
    });
  }

  /// Renders any building archetype directly at [origin] (used by both the city and the 3D Object Studio).
  static void buildByType(
    MeshBuilder mesh,
    BusinessType type,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    switch (type) {
      case BusinessType.vendorStall:
        VendorStallBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.convenienceStore:
        OutpostMartBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.foodStand:
        FoodStandBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.desertDiner:
        DesertDinerBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.gasStation:
        GasStationBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.desertMotel:
        DesertMotelBuilding.build(mesh, origin, level, lighting, shadowCol);
      case BusinessType.lookoutCamp:
        LookoutCampBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.oasisPlaza:
        OasisPlazaBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
    }
  }
}
