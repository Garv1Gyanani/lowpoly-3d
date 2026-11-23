import 'dart:ui';

import '../engine/lighting.dart';
import '../engine/mesh_builder.dart';
import '../engine/vec3.dart';
import 'props/desert_flora_and_rocks.dart';
import 'props/desert_windmill.dart';
import 'props/roadside_welcome_sign.dart';
import 'props/street_lamp.dart';
import 'props/telephone_poles.dart';
import 'terrain/desert_terrain.dart';
import 'terrain/highway_and_parking.dart';
import 'terrain/monument_mesas.dart';
import 'terrain/sky_clouds.dart';

/// Orchestrates the unified single-terrain Monument Valley desert world from modular asset files,
/// evolving its infrastructure progressively as parkingTier and builtCount grow.
class EnvironmentBuilder {
  const EnvironmentBuilder._();

  static const List<Vec3> parkingSlots = HighwayAndParking.parkingSlots;
  static const double highwayCenterZ = HighwayAndParking.highwayCenterZ;
  static const double highwayWestboundZ = HighwayAndParking.highwayWestboundZ;
  static const double highwayEastboundZ = HighwayAndParking.highwayEastboundZ;

  static List<int> activeParkingSlotIndices(int parkingTier) =>
      HighwayAndParking.activeSlotIndicesForTier(parkingTier);

  static double terrainHeight(double x, double z) => DesertTerrain.heightAt(x, z);

  static void build(
    MeshBuilder mesh,
    DesertLighting lighting,
    double animTime, {
    int parkingTier = 3,
    int builtCount = 7,
  }) {
    final shadowCol = Color.from(
      alpha: lighting.shadowAlpha,
      red: 0.22,
      green: 0.13,
      blue: 0.10,
    );

    // Always present natural Utah Monument Valley world & highway
    DesertTerrain.build(mesh);
    HighwayAndParking.build(mesh, parkingTier: parkingTier, builtCount: builtCount);
    MonumentMesas.buildAll(mesh);
    SkyClouds.build(mesh, lighting, animTime);
    TelephonePoles.buildHighwayLine(mesh, lighting, shadowCol);
    DesertFloraAndRocks.buildAll(mesh, lighting, shadowCol, animTime);

    // Progressive town infrastructure unlocked as the outpost grows!
    if (parkingTier == 2) {
      // First 3 warm timber lamps along the new front boardwalk promenade
      for (final p in const [
        Vec3(-5.6, 0, 6.9),
        Vec3(0.4, 0, 6.9),
        Vec3(6.2, 0, 6.9),
      ]) {
        StreetLampAndFence.buildLamp(mesh, p, lighting, shadowCol);
      }
    } else if (parkingTier >= 3) {
      // Full outpost infrastructure: welcome billboard, fences, all 6 lamps & windmill!
      RoadsideWelcomeSign.build(mesh, const Vec3(-10.8, 0, 10.2), lighting, shadowCol);
      StreetLampAndFence.buildOutpostFencesAndLamps(mesh, lighting, shadowCol);
      if (builtCount >= 4) {
        DesertWindmill.build(
          mesh,
          Vec3(11.4, DesertTerrain.heightAt(11.4, -5.2), -5.2),
          lighting,
          shadowCol,
          animTime,
        );
      }
    }
  }
}
