import 'dart:math' as math;

import '../engine/lighting.dart';
import '../engine/mesh_builder.dart';
import '../engine/vec3.dart';
import '../theme/desert_palette.dart';
import 'outpost_layout.dart';
import 'props/desert_flora_and_rocks.dart';
import 'props/desert_windmill.dart';
import 'props/roadside_welcome_sign.dart';
import 'props/street_lamp.dart';
import 'props/telephone_poles.dart';
import 'terrain/desert_terrain.dart';
import 'terrain/highway_and_parking.dart';
import 'terrain/monument_mesas.dart';
import 'terrain/sky_clouds.dart';

/// Orchestrates the unified single-terrain Monument Valley desert world,
/// cleanly separated into `buildStatic` (cached) and `buildDynamic` (animated per-frame).
class EnvironmentBuilder {
  const EnvironmentBuilder._();

  static const List<Vec3> parkingSlots = OutpostLayout.parkingSlots;
  static const double highwayCenterZ = OutpostLayout.highwayCenterZ;
  static const double highwayWestboundZ = OutpostLayout.highwayWestboundZ;
  static const double highwayEastboundZ = OutpostLayout.highwayEastboundZ;

  static List<int> activeParkingSlotIndices(int parkingTier) =>
      OutpostLayout.activeSlotIndicesForTier(parkingTier);

  static double terrainHeight(double x, double z) => DesertTerrain.heightAt(x, z);

  static void build(
    MeshBuilder mesh,
    DesertLighting lighting,
    double animTime, {
    int parkingTier = 3,
    int builtCount = 7,
  }) {
    buildStatic(
      mesh,
      lighting,
      parkingTier: parkingTier,
      builtCount: builtCount,
    );
    buildDynamic(
      mesh,
      lighting,
      animTime,
      parkingTier: parkingTier,
      builtCount: builtCount,
    );
  }

  static void buildStatic(
    MeshBuilder mesh,
    DesertLighting lighting, {
    int parkingTier = 3,
    int builtCount = 7,
  }) {
    final shadowCol = lighting.shadowColor;

    DesertTerrain.build(mesh, parkingTier: parkingTier);
    HighwayAndParking.build(
      mesh,
      lighting: lighting,
      parkingTier: parkingTier,
      builtCount: builtCount,
    );
    MonumentMesas.buildAll(mesh, lighting: lighting);
    TelephonePoles.buildHighwayLine(mesh, lighting, shadowCol);
    DesertFloraAndRocks.buildStatic(mesh, lighting, shadowCol);

    if (parkingTier == 2) {
      for (final p in const [
        Vec3(-5.6, 0, OutpostLayout.frontPromenadeZ),
        Vec3(0.4, 0, OutpostLayout.frontPromenadeZ),
        Vec3(6.2, 0, OutpostLayout.frontPromenadeZ),
      ]) {
        StreetLampAndFence.buildLamp(mesh, p, lighting, shadowCol);
      }
    } else if (parkingTier >= 3) {
      // Slightly angled inward (+12°) toward passing highway drivers!
      mesh.withTransform(const Vec3(-10.8, 0, 10.2), 0.22, () {
        RoadsideWelcomeSign.build(mesh, Vec3.zero, lighting, shadowCol);
      });
      StreetLampAndFence.buildOutpostFencesAndLamps(mesh, lighting, shadowCol);
      // Warm overhead festoon string lights linking the front boardwalk lamps!
      final wireCol = DesertPalette.woodDark;
      mesh.addSaggingWire(
        const Vec3(-5.6, 2.22, OutpostLayout.frontPromenadeZ),
        const Vec3(0.4, 2.22, OutpostLayout.frontPromenadeZ),
        wireCol,
        sag: 0.22,
        bulbCount: 4,
        bulbGlowColor: DesertPalette.windowNight,
      );
      mesh.addSaggingWire(
        const Vec3(0.4, 2.22, OutpostLayout.frontPromenadeZ),
        const Vec3(6.2, 2.22, OutpostLayout.frontPromenadeZ),
        wireCol,
        sag: 0.22,
        bulbCount: 4,
        bulbGlowColor: DesertPalette.windowNight,
      );
    }
  }

  static void buildDynamic(
    MeshBuilder mesh,
    DesertLighting lighting,
    double animTime, {
    int parkingTier = 3,
    int builtCount = 7,
  }) {
    final shadowCol = lighting.shadowColor;

    SkyClouds.build(mesh, lighting, animTime);
    DesertFloraAndRocks.buildDynamic(mesh, lighting, shadowCol, animTime);

    // Gentle rolling desert tumbleweed drifting across the south roadside scrub
    final twCycle = (animTime * 0.055) % 1.0;
    final twX = -24.0 + twCycle * 48.0;
    const twZ = 16.8;
    final twHop = math.sin(animTime * 4.2).abs() * 0.22;
    final twGround = DesertTerrain.heightAt(twX, twZ);
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

    if (parkingTier >= 3 && builtCount >= 4) {
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
