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

/// Dispatches each construction plot to its dedicated modular low-poly building file.
class BuildingModels {
  const BuildingModels._();

  static void buildPlot(
    MeshBuilder mesh,
    PlotState plot,
    DesertLighting lighting,
    double animTime, {
    required bool isSelected,
  }) {
    final shadowCol = Color.from(
      alpha: lighting.shadowAlpha,
      red: 0.22,
      green: 0.13,
      blue: 0.10,
    );

    if (isSelected) {
      final pulse = 0.55 + 0.35 * math.sin(animTime * 5.0);
      mesh.addGroundRect(
        plot.position.x,
        0.04,
        plot.position.z,
        plot.footprintWidth + 0.6,
        plot.footprintDepth + 0.6,
        DesertPalette.gold.withValues(alpha: 0.28 * pulse),
        layer: RenderLayer.groundDecal,
        depthBias: -0.3,
        unlit: true,
        outlineColor: DesertPalette.gold.withValues(alpha: 0.85),
      );
    }

    if (!plot.isBuilt) {
      EmptyPlotBuilding.build(mesh, plot, animTime);
      return;
    }

    double liftY = 0.0;
    if (plot.bounceTimer > 0) {
      liftY += math.sin(plot.bounceTimer * math.pi * 4.0).abs() * 0.20;
    }
    if (plot.buildPopTimer > 0) {
      final t = 1.0 - plot.buildPopTimer.clamp(0.0, 1.0);
      liftY -= (1.0 - t) * 1.4;
    }

    final origin = Vec3(plot.position.x, liftY, plot.position.z);
    buildByType(
      mesh,
      plot.businessType,
      origin,
      plot.level,
      lighting,
      shadowCol,
      animTime,
    );
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
        OutpostMartBuilding.build(mesh, origin, level, lighting, shadowCol);
      case BusinessType.foodStand:
        FoodStandBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.desertDiner:
        DesertDinerBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.gasStation:
        GasStationBuilding.build(mesh, origin, level, lighting, shadowCol);
      case BusinessType.desertMotel:
        DesertMotelBuilding.build(mesh, origin, level, lighting, shadowCol);
      case BusinessType.lookoutCamp:
        LookoutCampBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
      case BusinessType.oasisPlaza:
        OasisPlazaBuilding.build(mesh, origin, level, lighting, shadowCol, animTime);
    }
  }
}
