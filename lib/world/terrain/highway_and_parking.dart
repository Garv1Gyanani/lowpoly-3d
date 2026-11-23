import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Route 163 two-lane desert highway plus progressive parking & outpost walkways:
/// - Tier 0: Raw desert sand (highway only, 0 parking spaces, no customers stopping)
/// - Tier 1: Dirt roadside pull-off (2 center spaces + rustic wooden tire-stop logs & signpost)
/// - Tier 2: Graded gravel lot (4 spaces + concrete stops + front boardwalk promenade)
/// - Tier 3: Full paved asphalt parking lot (6 painted spaces + driveways + full town walkways)
class HighwayAndParking {
  const HighwayAndParking._();

  static const List<Vec3> parkingSlots = [
    Vec3(-7.0, 0, 9.2), // 0 (Tier 3)
    Vec3(-4.2, 0, 9.2), // 1 (Tier 2)
    Vec3(-1.4, 0, 9.2), // 2 (Tier 1)
    Vec3(1.4, 0, 9.2), // 3 (Tier 1)
    Vec3(4.2, 0, 9.2), // 4 (Tier 2)
    Vec3(7.0, 0, 9.2), // 5 (Tier 3)
  ];

  /// Active parking slot indices available for each parking tier.
  static List<int> activeSlotIndicesForTier(int tier) {
    if (tier <= 0) return const [];
    if (tier == 1) return const [2, 3];
    if (tier == 2) return const [1, 2, 3, 4];
    return const [0, 1, 2, 3, 4, 5];
  }

  static const double highwayCenterZ = 13.4;
  static const double highwayWestboundZ = 12.5;
  static const double highwayEastboundZ = 14.3;

  static void build(MeshBuilder mesh, {required int parkingTier, required int builtCount}) {
    // 1. Always render Route 163 two-lane desert highway & shoulders
    for (double x = -72; x < 72; x += 12) {
      final cx = x + 6;
      mesh.addGroundRect(
        cx,
        0.02,
        highwayCenterZ,
        12.1,
        4.8,
        DesertPalette.asphaltShoulder,
        layer: RenderLayer.groundDecal,
        depthBias: 0.2,
      );
      mesh.addGroundRect(
        cx,
        0.03,
        highwayCenterZ,
        12.1,
        3.8,
        DesertPalette.asphalt,
        layer: RenderLayer.groundDecal,
        depthBias: 0.0,
      );
      mesh.addGroundRect(
        cx,
        0.035,
        highwayCenterZ - 1.68,
        12.1,
        0.11,
        DesertPalette.roadWhite,
        layer: RenderLayer.groundDecal,
        depthBias: -0.1,
      );
      mesh.addGroundRect(
        cx,
        0.035,
        highwayCenterZ + 1.68,
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

    // Tier 0: Raw desert sand — just the highway and your tiny cart!
    if (parkingTier <= 0) return;

    // Tier 1: Rustic dusty dirt pull-off (2 spaces) + wooden log stops + small highway sign!
    if (parkingTier == 1) {
      mesh.addGroundRect(
        0,
        0.022,
        9.7,
        8.6,
        3.9,
        const Color(0xFFB89668),
        layer: RenderLayer.groundDecal,
        depthBias: 0.08,
      );
      // Tire-tracked dirt apron into highway
      mesh.addGroundRect(
        0,
        0.023,
        11.5,
        6.4,
        1.4,
        const Color(0xFFA78862),
        layer: RenderLayer.groundDecal,
        depthBias: 0.06,
      );
      for (final idx in activeSlotIndicesForTier(1)) {
        final slot = parkingSlots[idx];
        mesh.addBox(slot.x, 0.03, slot.z - 1.25, 1.55, 0.14, 0.20, DesertPalette.wood);
      }
      // Small hand-painted roadside wooden sign announcing cold drinks!
      mesh.addBox(-4.6, 0, 10.6, 0.14, 1.85, 0.14, DesertPalette.woodDark);
      mesh.addBox(-4.6, 1.22, 10.6, 1.45, 0.62, 0.12, DesertPalette.cream);
      mesh.addFrontSignText(
        -4.6,
        1.53,
        10.67,
        1.35,
        0.52,
        'PARKING',
        DesertPalette.sandstoneDark,
        nightGlow: false,
      );
      return;
    }

    // Tier 2: Graded gravel lot (4 spaces) + front sandstone promenade + courtyard pad
    if (parkingTier == 2) {
      mesh.addGroundRect(
        0,
        0.015,
        1.8,
        16.5,
        11.5,
        const Color(0xFFD5B07C),
        layer: RenderLayer.groundDecal,
        depthBias: 0.4,
      );
      mesh.addGroundRect(
        0,
        0.024,
        9.5,
        13.8,
        4.2,
        const Color(0xFF8C7E70),
        layer: RenderLayer.groundDecal,
        depthBias: 0.06,
      );
      mesh.addGroundRect(
        -5.0,
        0.025,
        11.4,
        3.2,
        1.6,
        const Color(0xFF7D7165),
        layer: RenderLayer.groundDecal,
        depthBias: 0.04,
      );
      mesh.addGroundRect(
        5.0,
        0.025,
        11.4,
        3.2,
        1.6,
        const Color(0xFF7D7165),
        layer: RenderLayer.groundDecal,
        depthBias: 0.04,
      );
      for (final idx in activeSlotIndicesForTier(2)) {
        final slot = parkingSlots[idx];
        mesh.addBox(slot.x, 0.03, slot.z - 1.25, 1.55, 0.14, 0.20, DesertPalette.concrete);
      }
      // Front sandstone walkway promenade
      mesh.addGroundRect(
        0,
        0.028,
        6.9,
        14.6,
        1.15,
        DesertPalette.concrete,
        layer: RenderLayer.groundDecal,
        depthBias: 0.02,
      );
      if (builtCount >= 2) {
        mesh.addGroundRect(
          0,
          0.028,
          2.2,
          14.6,
          1.25,
          const Color(0xFFCFBE9F),
          layer: RenderLayer.groundDecal,
          depthBias: 0.06,
        );
        mesh.addGroundRect(
          0,
          0.028,
          4.5,
          2.1,
          5.2,
          const Color(0xFFCFBE9F),
          layer: RenderLayer.groundDecal,
          depthBias: 0.06,
        );
      }
      return;
    }

    // Tier 3: Full paved asphalt parking lot (6 painted stalls) + driveways + full town walkways!
    mesh.addGroundRect(
      0,
      0.015,
      -0.8,
      22.2,
      18.6,
      const Color(0xFFD5B07C),
      layer: RenderLayer.groundDecal,
      depthBias: 0.4,
    );
    mesh.addGroundRect(
      0,
      0.025,
      9.4,
      19.2,
      4.4,
      const Color(0xFF696059),
      layer: RenderLayer.groundDecal,
      depthBias: 0.05,
    );
    mesh.addGroundRect(
      -8.0,
      0.026,
      11.4,
      3.4,
      1.6,
      const Color(0xFF5D5650),
      layer: RenderLayer.groundDecal,
      depthBias: 0.02,
    );
    mesh.addGroundRect(
      8.0,
      0.026,
      11.4,
      3.4,
      1.6,
      const Color(0xFF5D5650),
      layer: RenderLayer.groundDecal,
      depthBias: 0.02,
    );

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
      6.9,
      20.2,
      1.2,
      DesertPalette.concrete,
      layer: RenderLayer.groundDecal,
      depthBias: 0.02,
    );
    mesh.addGroundRect(
      0,
      0.028,
      -0.2,
      2.3,
      13.6,
      const Color(0xFFCFBE9F),
      layer: RenderLayer.groundDecal,
      depthBias: 0.06,
    );
    mesh.addGroundRect(
      0,
      0.028,
      2.2,
      18.6,
      1.4,
      const Color(0xFFCFBE9F),
      layer: RenderLayer.groundDecal,
      depthBias: 0.06,
    );
    mesh.addGroundRect(
      0,
      0.028,
      -5.1,
      16.2,
      1.2,
      const Color(0xFFCBB897),
      layer: RenderLayer.groundDecal,
      depthBias: 0.06,
    );
  }
}
