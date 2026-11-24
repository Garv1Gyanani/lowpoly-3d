import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';
import '../outpost_layout.dart';

/// Route 163 two-lane desert highway plus progressive parking, flared driveways & outpost walkways.
class HighwayAndParking {
  const HighwayAndParking._();

  static const List<Vec3> parkingSlots = OutpostLayout.parkingSlots;
  static const double highwayCenterZ = OutpostLayout.highwayCenterZ;
  static const double highwayWestboundZ = OutpostLayout.highwayWestboundZ;
  static const double highwayEastboundZ = OutpostLayout.highwayEastboundZ;

  static List<int> activeSlotIndicesForTier(int tier) =>
      OutpostLayout.activeSlotIndicesForTier(tier);

  static void _addFlaredDriveway(
    MeshBuilder mesh, {
    required double cx,
    required double y,
    required double topZ,
    required double bottomZ,
    required double topWidth,
    required double bottomWidth,
    required Color color,
    double depthBias = 0.04,
  }) {
    final htw = topWidth * 0.5;
    final hbw = bottomWidth * 0.5;
    mesh.addGroundPoly(
      [
        Vec3(cx - htw, y, topZ),
        Vec3(cx - hbw, y, bottomZ),
        Vec3(cx + hbw, y, bottomZ),
        Vec3(cx + htw, y, topZ),
      ],
      color,
      layer: RenderLayer.groundDecal,
      depthBias: depthBias,
    );
  }

  static void build(
    MeshBuilder mesh, {
    DesertLighting? lighting,
    required int parkingTier,
    required int builtCount,
  }) {
    // 1. Always render Route 163 two-lane desert highway & warm gravel shoulders
    for (double x = -72; x < 72; x += 12) {
      final cx = x + 6;
      mesh.addGroundRect(
        cx,
        0.02,
        highwayCenterZ,
        12.1,
        4.9,
        DesertPalette.asphaltShoulder,
        layer: RenderLayer.groundDecal,
        depthBias: 0.2,
      );
      mesh.addGroundRect(
        cx,
        0.03,
        highwayCenterZ,
        12.1,
        3.85,
        DesertPalette.asphalt,
        layer: RenderLayer.groundDecal,
        depthBias: 0.0,
      );
      mesh.addGroundRect(
        cx,
        0.035,
        highwayCenterZ - 1.70,
        12.1,
        0.11,
        DesertPalette.roadWhite,
        layer: RenderLayer.groundDecal,
        depthBias: -0.1,
      );
      mesh.addGroundRect(
        cx,
        0.035,
        highwayCenterZ + 1.70,
        12.1,
        0.11,
        DesertPalette.roadWhite,
        layer: RenderLayer.groundDecal,
        depthBias: -0.1,
      );
    }

    for (double x = -40; x <= 40; x += 3.2) {
      mesh.addGroundRect(
        x,
        0.036,
        highwayCenterZ,
        1.5,
        0.13,
        DesertPalette.roadYellow,
        layer: RenderLayer.groundDecal,
        depthBias: -0.15,
      );
    }

    // Tier 0: Raw desert shoulder with subtle worn sandy pull-over hint
    if (parkingTier <= 0) {
      _addFlaredDriveway(
        mesh,
        cx: -2.0,
        y: 0.021,
        topZ: 9.8,
        bottomZ: 11.4,
        topWidth: 4.2,
        bottomWidth: 6.4,
        color: DesertPalette.arroyoSand,
        depthBias: 0.18,
      );
      return;
    }

    // Tier 1: Rustic dusty dirt pull-off (2 spaces) + flared apron + timber stops + angled sign
    if (parkingTier == 1) {
      _addFlaredDriveway(
        mesh,
        cx: 0,
        y: 0.022,
        topZ: 7.7,
        bottomZ: 11.6,
        topWidth: 7.8,
        bottomWidth: 11.2,
        color: const Color(0xFFB89668),
        depthBias: 0.08,
      );
      _addFlaredDriveway(
        mesh,
        cx: 0,
        y: 0.024,
        topZ: 10.6,
        bottomZ: 11.7,
        topWidth: 6.8,
        bottomWidth: 9.4,
        color: const Color(0xFFA5855E),
        depthBias: 0.05,
      );
      for (final idx in activeSlotIndicesForTier(1)) {
        final slot = parkingSlots[idx];
        mesh.addBox(slot.x, 0.03, slot.z - 1.25, 1.55, 0.14, 0.20, DesertPalette.wood);
      }
      // Slightly angled hand-painted roadside wooden sign announcing parking & cold drinks!
      if (lighting != null) {
        mesh.addBoxShadow(-4.6, 10.6, 1.4, 0.4, 1.85, lighting.shadowDirection, lighting.shadowColor);
      }
      mesh.withTransform(const Vec3(-4.6, 0, 10.6), 0.18, () {
        mesh.addBox(0, 0, 0, 0.14, 1.85, 0.14, DesertPalette.woodDark);
        mesh.addBox(0, 1.22, 0, 1.50, 0.64, 0.13, DesertPalette.cream);
        mesh.addBox(0, 1.84, 0, 1.62, 0.10, 0.20, DesertPalette.terracotta);
        mesh.addFrontSignText(
          0,
          1.53,
          0.07,
          1.38,
          0.52,
          'PARKING',
          DesertPalette.sandstoneDark,
          nightGlow: false,
        );
      });
      return;
    }

    // Tier 2: Graded gravel lot (4 spaces) + flared twin driveways + sandstone boardwalk promenade
    if (parkingTier == 2) {
      mesh.addGroundRect(
        0,
        0.015,
        1.8,
        16.8,
        11.6,
        const Color(0xFFD5B07C),
        layer: RenderLayer.groundDecal,
        depthBias: 0.4,
      );
      mesh.addGroundRect(
        0,
        0.024,
        9.5,
        14.0,
        4.2,
        const Color(0xFF8C7E70),
        layer: RenderLayer.groundDecal,
        depthBias: 0.06,
      );
      for (final dx in [-5.0, 5.0]) {
        _addFlaredDriveway(
          mesh,
          cx: dx,
          y: 0.025,
          topZ: 10.6,
          bottomZ: 11.9,
          topWidth: 3.0,
          bottomWidth: 4.8,
          color: const Color(0xFF7D7165),
          depthBias: 0.04,
        );
      }
      for (final idx in activeSlotIndicesForTier(2)) {
        final slot = parkingSlots[idx];
        mesh.addBox(slot.x, 0.03, slot.z - 1.25, 1.55, 0.14, 0.20, DesertPalette.concrete);
      }
      mesh.addGroundRect(
        0,
        0.028,
        OutpostLayout.frontPromenadeZ,
        14.8,
        1.20,
        DesertPalette.concrete,
        layer: RenderLayer.groundDecal,
        depthBias: 0.02,
      );
      if (builtCount >= 2) {
        mesh.addGroundRect(
          0,
          0.028,
          OutpostLayout.midCrosswalkZ,
          14.8,
          1.28,
          const Color(0xFFCFBE9F),
          layer: RenderLayer.groundDecal,
          depthBias: 0.06,
        );
        mesh.addGroundRect(
          OutpostLayout.centralSpineX,
          0.028,
          4.55,
          2.15,
          5.2,
          const Color(0xFFCFBE9F),
          layer: RenderLayer.groundDecal,
          depthBias: 0.06,
        );
      }
      return;
    }

    // Tier 3: Full paved asphalt parking plaza (6 stalls) + flared curb aprons + town walkways
    mesh.addGroundRect(
      0,
      0.015,
      -0.8,
      22.4,
      18.8,
      const Color(0xFFD5B07C),
      layer: RenderLayer.groundDecal,
      depthBias: 0.4,
    );
    mesh.addGroundRect(
      0,
      0.025,
      9.4,
      19.4,
      4.4,
      const Color(0xFF675E57),
      layer: RenderLayer.groundDecal,
      depthBias: 0.05,
    );
    for (final dx in [-8.0, 8.0]) {
      _addFlaredDriveway(
        mesh,
        cx: dx,
        y: 0.026,
        topZ: 10.6,
        bottomZ: 11.95,
        topWidth: 3.2,
        bottomWidth: 5.4,
        color: const Color(0xFF5A534D),
        depthBias: 0.02,
      );
    }

    for (int i = 0; i <= parkingSlots.length; i++) {
      final lx = -8.4 + i * 2.8;
      mesh.addGroundRect(
        lx,
        0.033,
        9.1,
        0.11,
        2.5,
        const Color(0xFFDCD3C2),
        layer: RenderLayer.groundDecal,
        depthBias: -0.15,
      );
    }
    for (final slot in parkingSlots) {
      mesh.addBox(slot.x, 0.03, slot.z - 1.25, 1.55, 0.14, 0.20, DesertPalette.concrete);
    }

    mesh.addGroundRect(
      0,
      0.028,
      OutpostLayout.frontPromenadeZ,
      20.4,
      1.25,
      DesertPalette.concrete,
      layer: RenderLayer.groundDecal,
      depthBias: 0.02,
    );
    mesh.addGroundRect(
      OutpostLayout.centralSpineX,
      0.028,
      -0.2,
      2.35,
      13.6,
      const Color(0xFFCFBE9F),
      layer: RenderLayer.groundDecal,
      depthBias: 0.06,
    );
    mesh.addGroundRect(
      0,
      0.028,
      OutpostLayout.midCrosswalkZ,
      18.8,
      1.4,
      const Color(0xFFCFBE9F),
      layer: RenderLayer.groundDecal,
      depthBias: 0.06,
    );
    mesh.addGroundRect(
      0,
      0.028,
      OutpostLayout.upperTerraceZ,
      16.4,
      1.25,
      const Color(0xFFCBB897),
      layer: RenderLayer.groundDecal,
      depthBias: 0.06,
    );
  }
}
