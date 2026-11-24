import 'dart:math' as math;

import '../engine/lighting.dart';
import '../engine/mesh_builder.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../systems/road_network.dart';
import '../systems/world_grid.dart';
import '../theme/desert_palette.dart';
import 'props/desert_flora_and_rocks.dart';
import 'props/roadside_welcome_sign.dart';
import 'props/telephone_poles.dart';
import 'terrain/desert_terrain.dart';
import 'terrain/highway_and_parking.dart';
import 'terrain/monument_mesas.dart';
import 'terrain/sky_clouds.dart';

/// Orchestrates the open-desert Monument Valley world, cleanly separated into
/// `buildStatic` (cached) and `buildDynamic` (animated per-frame).
class EnvironmentBuilder {
  const EnvironmentBuilder._();

  static double terrainHeight(double x, double z) => DesertTerrain.heightAt(x, z);

  /// Immutable world backdrop (terrain, Route 163 highway, distant mesas & telephone line).
  /// Cached separately so painting roads or placing buildings NEVER rebuilds terrain/mesas!
  static void buildBackdrop(
    MeshBuilder mesh,
    DesertLighting lighting,
  ) {
    final shadowCol = lighting.shadowColor;
    DesertTerrain.build(mesh);
    HighwayAndParking.buildHighwayOnly(mesh);
    MonumentMesas.buildAll(mesh, lighting: lighting);
    TelephonePoles.buildHighwayLine(mesh, lighting, shadowCol);
  }

  /// Player-affected static layer (roads, parking lots, cleared flora, build grid, Stage 5 sign).
  static void buildOutpostStatic(
    MeshBuilder mesh,
    DesertLighting lighting, {
    RoadNetwork? roadNetwork,
    List<ParkingLotEntity>? parkingLots,
    WorldGrid? worldGrid,
    WorldToolMode toolMode = WorldToolMode.play,
    int outpostStage = 1,
    int maxParcels = 2,
    bool Function(double x, double z)? isOccupied,
  }) {
    final shadowCol = lighting.shadowColor;
    HighwayAndParking.buildNetworkOnly(
      mesh,
      lighting: lighting,
      roadNetwork: roadNetwork,
      parkingLots: parkingLots,
      worldGrid: worldGrid,
      toolMode: toolMode,
      maxParcels: maxParcels,
    );
    DesertFloraAndRocks.buildStatic(
      mesh,
      lighting,
      shadowCol,
      isOccupied: isOccupied,
    );
    if (outpostStage >= 5) {
      mesh.withTransform(const Vec3(-18.0, 0, 19.2), math.pi - 0.2, () {
        RoadsideWelcomeSign.build(mesh, Vec3.zero, lighting, shadowCol);
      });
    }
  }

  static void buildStatic(
    MeshBuilder mesh,
    DesertLighting lighting, {
    RoadNetwork? roadNetwork,
    List<ParkingLotEntity>? parkingLots,
    WorldGrid? worldGrid,
    WorldToolMode toolMode = WorldToolMode.play,
    int outpostStage = 1,
    int maxParcels = 2,
    bool Function(double x, double z)? isOccupied,
  }) {
    buildBackdrop(mesh, lighting);
    buildOutpostStatic(
      mesh,
      lighting,
      roadNetwork: roadNetwork,
      parkingLots: parkingLots,
      worldGrid: worldGrid,
      toolMode: toolMode,
      outpostStage: outpostStage,
      maxParcels: maxParcels,
      isOccupied: isOccupied,
    );
  }

  static void buildDynamic(
    MeshBuilder mesh,
    DesertLighting lighting,
    double animTime, {
    bool Function(double x, double z)? isOccupied,
  }) {
    final shadowCol = lighting.shadowColor;

    SkyClouds.build(mesh, lighting, animTime);
    DesertFloraAndRocks.buildDynamic(
      mesh,
      lighting,
      shadowCol,
      animTime,
      isOccupied: isOccupied,
    );

    // Two rolling desert tumbleweeds drifting across the open sand
    for (final (speed, laneZ, phase) in const [(0.020, 22.5, 0.0), (0.014, -60.0, 0.45)]) {
      final twCycle = (animTime * speed + phase) % 1.0;
      final twX = -90.0 + twCycle * 180.0;
      final twZ = laneZ + math.sin(animTime * 0.3 + phase * 10) * 2.0;
      final twHop = math.sin(animTime * 4.2 + phase * 7).abs() * 0.22;
      final twGround = DesertTerrain.heightAt(twX, twZ);
      if (isOccupied != null && isOccupied(twX, twZ)) continue;
      mesh.addDiscShadow(
        twX,
        twGround,
        twZ,
        0.24,
        0.22,
        0.35,
        lighting.shadowDirection,
        shadowCol,
        sides: 5,
      );
      mesh.withTransform(Vec3(twX, twGround + twHop, twZ), animTime * 2.4, () {
        mesh.addFrustum(
          0,
          0.04,
          0,
          0.22,
          0.20,
          0.16,
          0.15,
          0.30,
          5,
          DesertPalette.arroyoDark,
          topColor: DesertPalette.woodLight,
        );
      });
    }
  }
}
