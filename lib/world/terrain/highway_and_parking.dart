import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../models/game_models.dart';
import '../../systems/road_network.dart';
import '../../systems/world_grid.dart';
import '../../theme/desert_palette.dart';
import '../outpost_layout.dart';
import '../props/street_lamp.dart';

/// Route 163 two-lane desert highway plus player-built auto-tiled roads,
/// freely placeable parking lots, land-parcel overlays and the build grid.
class HighwayAndParking {
  const HighwayAndParking._();

  static const double highwayCenterZ = OutpostLayout.highwayCenterZ;

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

  static void buildHighwayOnly(MeshBuilder mesh) {
    // 1. Route 163 two-lane desert highway & warm gravel shoulders (runs to the horizon)
    for (double x = -240; x < 240; x += 16) {
      final cx = x + 8;
      mesh.addGroundRect(cx, 0.02, highwayCenterZ, 16.1, 4.9, DesertPalette.asphaltShoulder,
          layer: RenderLayer.groundDecal, depthBias: 0.2);
      mesh.addGroundRect(cx, 0.03, highwayCenterZ, 16.1, 3.85, DesertPalette.asphalt,
          layer: RenderLayer.groundDecal, depthBias: 0.0);
      mesh.addGroundRect(cx, 0.035, highwayCenterZ - 1.70, 16.1, 0.11, DesertPalette.roadWhite,
          layer: RenderLayer.groundDecal, depthBias: -0.1);
      mesh.addGroundRect(cx, 0.035, highwayCenterZ + 1.70, 16.1, 0.11, DesertPalette.roadWhite,
          layer: RenderLayer.groundDecal, depthBias: -0.1);
    }
    for (double x = -150; x <= 150; x += 3.2) {
      mesh.addGroundRect(x, 0.036, highwayCenterZ, 1.5, 0.13, DesertPalette.roadYellow,
          layer: RenderLayer.groundDecal, depthBias: -0.15);
    }
  }

  static void buildNetworkOnly(
    MeshBuilder mesh, {
    DesertLighting? lighting,
    RoadNetwork? roadNetwork,
    List<ParkingLotEntity>? parkingLots,
    WorldGrid? worldGrid,
    WorldToolMode toolMode = WorldToolMode.play,
    int maxParcels = 2,
  }) {
    // 2. Land parcels & build grid overlay while any build tool is active
    if (worldGrid != null && toolMode != WorldToolMode.play) {
      _buildLandAndGridOverlay(mesh, worldGrid, toolMode, maxParcels);
    }

    if (roadNetwork == null || parkingLots == null) return;

    // 3. Auto-tiled Player Road Network (Dirt Track -> Gravel Road -> Paved Asphalt)
    _buildRoadTiles(mesh, roadNetwork, lighting);

    // 4. Player-Placed Parking Lots
    for (final lot in parkingLots) {
      buildParkingLot(mesh, lot, lighting: lighting);
    }
  }

  static void build(
    MeshBuilder mesh, {
    DesertLighting? lighting,
    RoadNetwork? roadNetwork,
    List<ParkingLotEntity>? parkingLots,
    WorldGrid? worldGrid,
    WorldToolMode toolMode = WorldToolMode.play,
    int maxParcels = 2,
  }) {
    buildHighwayOnly(mesh);
    buildNetworkOnly(
      mesh,
      lighting: lighting,
      roadNetwork: roadNetwork,
      parkingLots: parkingLots,
      worldGrid: worldGrid,
      toolMode: toolMode,
      maxParcels: maxParcels,
    );
  }

  static void _buildLandAndGridOverlay(
    MeshBuilder mesh,
    WorldGrid grid,
    WorldToolMode toolMode,
    int maxParcels,
  ) {
    const cs = OutpostLayout.gridCellSize;
    const minX = OutpostLayout.worldMinX;
    const maxX = OutpostLayout.worldMaxX;
    const minZ = OutpostLayout.worldMinZ;
    const maxZ = OutpostLayout.worldMaxZ;
    const lineCol = Color(0x30FFF6E0);

    // Full-map tile grid as long thin ground strips (cheap: ~130 quads total)
    if (toolMode != WorldToolMode.buyLand) {
      for (int gx = OutpostLayout.minGridX; gx <= OutpostLayout.maxGridX + 1; gx++) {
        final x = (gx - 0.5) * cs;
        mesh.addGroundRect(x, 0.016, (minZ + maxZ) * 0.5, 0.06, maxZ - minZ, lineCol,
            layer: RenderLayer.groundDecal, depthBias: 0.32, unlit: true);
      }
      for (int gz = OutpostLayout.minGridZ; gz <= OutpostLayout.maxGridZ + 1; gz++) {
        final z = (gz - 0.5) * cs;
        mesh.addGroundRect((minX + maxX) * 0.5, 0.016, z, maxX - minX, 0.06, lineCol,
            layer: RenderLayer.groundDecal, depthBias: 0.32, unlit: true);
      }
    }

    const parcelW = OutpostLayout.parcelSize * cs;
    // Owned parcels: warm tint + gold border
    for (final p in grid.ownedParcels) {
      final c = p.center;
      mesh.addGroundRect(c.x, 0.015, c.z, parcelW - 0.2, parcelW - 0.2, const Color(0x1EF2C14E),
          layer: RenderLayer.groundDecal, depthBias: 0.34, unlit: true,
          outlineColor: const Color(0xAAF2C14E));
    }

    // Purchasable parcels while the Land tool is open
    if (toolMode == WorldToolMode.buyLand) {
      final canBuyMore = grid.ownedParcels.length < maxParcels;
      for (final p in grid.purchasableParcels()) {
        final c = p.center;
        mesh.addGroundRect(c.x, 0.015, c.z, parcelW - 0.4, parcelW - 0.4,
            canBuyMore ? const Color(0x2A4CA85E) : const Color(0x22000000),
            layer: RenderLayer.groundDecal, depthBias: 0.34, unlit: true,
            outlineColor: canBuyMore ? const Color(0xCC9BFF9F) : const Color(0x66FFFFFF));
      }
    }
  }

  static void _buildRoadTiles(
    MeshBuilder mesh,
    RoadNetwork roadNetwork,
    DesertLighting? lighting,
  ) {
    const cs = OutpostLayout.gridCellSize;
    final shadowCol = lighting?.shadowColor ?? const Color(0x33000000);

    for (final tile in roadNetwork.tiles.values) {
      final cell = tile.cell;
      final c = cell.worldCenter;
      final connected = roadNetwork.isRoadConnectedToHighway(cell);

      final hasN = roadNetwork.hasRoadAt(GridCell(cell.gx, cell.gz - 1));
      final hasS = roadNetwork.hasRoadAt(GridCell(cell.gx, cell.gz + 1)) ||
          cell.gz == OutpostLayout.highwayEntryRowZ;
      final hasW = roadNetwork.hasRoadAt(GridCell(cell.gx - 1, cell.gz));
      final hasE = roadNetwork.hasRoadAt(GridCell(cell.gx + 1, cell.gz));

      final (shoulderCol, surfaceCol, stripeCol) = switch (tile.tier) {
        RoadTier.dirt => (
            const Color(0xFFC5A172),
            connected ? const Color(0xFFA88356) : const Color(0xFF9C8468),
            null,
          ),
        RoadTier.gravel => (
            const Color(0xFFA99B89),
            connected ? const Color(0xFF83786C) : const Color(0xFF7B736A),
            const Color(0xFFB8AEA0),
          ),
        RoadTier.paved => (
            DesertPalette.asphaltShoulder,
            connected ? const Color(0xFF5D5650) : const Color(0xFF6B655F),
            DesertPalette.roadYellow,
          ),
      };

      // Subtle shoulder pad + full tile surface so adjacent tiles merge seamlessly
      final roadW = tile.tier == RoadTier.dirt ? 1.56 : 1.72;
      mesh.addGroundRect(
        c.x,
        0.022,
        c.z,
        cs + 0.04,
        cs + 0.04,
        shoulderCol,
        layer: RenderLayer.groundDecal,
        depthBias: 0.14,
      );
      mesh.addGroundRect(
        c.x,
        0.028,
        c.z,
        roadW,
        roadW,
        surfaceCol,
        layer: RenderLayer.groundDecal,
        depthBias: 0.05,
      );

      // Directional connector arms to neighbors (auto-tiling!)
      if (hasN) {
        mesh.addGroundRect(
          c.x,
          0.028,
          c.z - cs * 0.25,
          roadW,
          cs * 0.54,
          surfaceCol,
          layer: RenderLayer.groundDecal,
          depthBias: 0.05,
        );
      }
      if (hasS) {
        mesh.addGroundRect(
          c.x,
          0.028,
          c.z + cs * 0.25,
          roadW,
          cs * 0.54,
          surfaceCol,
          layer: RenderLayer.groundDecal,
          depthBias: 0.05,
        );
      }
      if (hasW) {
        mesh.addGroundRect(
          c.x - cs * 0.25,
          0.028,
          c.z,
          cs * 0.54,
          roadW,
          surfaceCol,
          layer: RenderLayer.groundDecal,
          depthBias: 0.05,
        );
      }
      if (hasE) {
        mesh.addGroundRect(
          c.x + cs * 0.25,
          0.028,
          c.z,
          cs * 0.54,
          roadW,
          surfaceCol,
          layer: RenderLayer.groundDecal,
          depthBias: 0.05,
        );
      }

      // Flared highway turn-off apron where road meets Route 163!
      if (cell.gz == OutpostLayout.highwayEntryRowZ) {
        _addFlaredDriveway(
          mesh,
          cx: c.x,
          y: 0.029,
          topZ: c.z + 0.4,
          bottomZ: 11.75,
          topWidth: roadW,
          bottomWidth: roadW + 1.45,
          color: surfaceCol,
          depthBias: 0.03,
        );
      }

      // Painted road markings on Paved & Gravel roads
      if (stripeCol != null) {
        if ((hasW || hasE) && !(hasN && hasS)) {
          mesh.addGroundRect(
            c.x,
            0.034,
            c.z,
            0.78,
            0.10,
            stripeCol,
            layer: RenderLayer.groundDecal,
            depthBias: -0.10,
          );
        }
        if ((hasN || hasS) && !(hasW && hasE)) {
          mesh.addGroundRect(
            c.x,
            0.034,
            c.z,
            0.10,
            0.78,
            stripeCol,
            layer: RenderLayer.groundDecal,
            depthBias: -0.10,
          );
        }
      }

      // Automatic street lamps spaced cleanly along Paved roads
      if (tile.tier == RoadTier.paved &&
          lighting != null &&
          ((cell.gx + cell.gz) % 3 == 0) &&
          !hasN &&
          (hasW || hasE)) {
        StreetLampAndFence.buildLamp(
          mesh,
          Vec3(c.x, 0, c.z - 0.96),
          lighting,
          shadowCol,
        );
      }
    }
  }

  /// Renders a placed parking lot (Dirt Pull-Off, Gravel Lot, or Paved Plaza Lot)
  /// with road-oriented bay stripes, wheel stops, driveway apron, and clear corner signage.
  static void buildParkingLot(
    MeshBuilder mesh,
    ParkingLotEntity lot, {
    DesertLighting? lighting,
    Color? tintOverride,
  }) {
    final (wCells, dCells) = lot.sizeCells;
    final worldW = wCells * OutpostLayout.gridCellSize - 0.14;
    final worldD = dCells * OutpostLayout.gridCellSize - 0.14;
    final c = lot.position;

    final baseCol = tintOverride ??
        switch (lot.kind) {
          ParkingLotKind.dirtPullOff => const Color(0xFFB89668),
          ParkingLotKind.gravelLot => const Color(0xFF8C7E70),
          ParkingLotKind.pavedLot => const Color(0xFF5D5650),
        };

    final borderCol = tintOverride ??
        switch (lot.kind) {
          ParkingLotKind.dirtPullOff => const Color(0xFF9E7C52),
          ParkingLotKind.gravelLot => const Color(0xFF756A5E),
          ParkingLotKind.pavedLot => DesertPalette.concrete,
        };

    // 1. Outer curb/border & main parking pad
    mesh.addGroundRect(
      c.x,
      0.023,
      c.z,
      worldW + 0.18,
      worldD + 0.18,
      borderCol,
      layer: RenderLayer.groundDecal,
      depthBias: 0.10,
    );
    mesh.addGroundRect(
      c.x,
      0.027,
      c.z,
      worldW,
      worldD,
      baseCol,
      layer: RenderLayer.groundDecal,
      depthBias: 0.04,
    );

    final (span, depth) = lot.orientedWorldDimensions;
    final u = lot.bayRowAxis;
    final f = lot.pullInDir;
    final count = lot.spec.spaces;
    final usableSpan = span - 0.36;
    final bayPitch = usableSpan / count;

    // 2. Seamless driveway apron bridging the lot entry edge into the adjacent road!
    if (lot.isConnected) {
      final apronCenter = c - f * (depth * 0.5 + 0.08);
      final isNorthSouthEntry =
          lot.effectiveEntrySide == LotEntrySide.south ||
          lot.effectiveEntrySide == LotEntrySide.north;
      mesh.addGroundRect(
        apronCenter.x,
        0.0285,
        apronCenter.z,
        isNorthSouthEntry ? span * 0.88 : 0.42,
        isNorthSouthEntry ? 0.42 : span * 0.88,
        baseCol,
        layer: RenderLayer.groundDecal,
        depthBias: 0.02,
      );
    }

    // Flared apron directly onto Route 163 when bordering the highway edge
    final touchesHighway =
        lot.occupiedCells.any((cell) => cell.gz == OutpostLayout.highwayEntryRowZ);
    if (touchesHighway) {
      _addFlaredDriveway(
        mesh,
        cx: c.x,
        y: 0.026,
        topZ: c.z + worldD * 0.42,
        bottomZ: 11.75,
        topWidth: worldW * 0.78,
        bottomWidth: worldW * 0.98,
        color: baseCol,
        depthBias: 0.03,
      );
    }

    // 3. Oriented wheel stops & bay divider stripes (aligned with pullInDir & bayRowAxis!)
    final stopCol = lot.kind == ParkingLotKind.dirtPullOff
        ? DesertPalette.wood
        : DesertPalette.concrete;
    final stripeCol = switch (lot.kind) {
      ParkingLotKind.dirtPullOff => const Color(0x889A784E),
      ParkingLotKind.gravelLot => const Color(0xBBC9BEB0),
      ParkingLotKind.pavedLot => const Color(0xFFE5DEC9),
    };

    // Note: when yaw = parkedYaw, local +X points along pullInDir (into bay) and local +Z along bayRowAxis!
    final bayYaw = lot.parkedYaw;
    final stopWidth = (bayPitch * 0.64).clamp(0.70, 1.15);
    for (int i = 0; i < count; i++) {
      final uOff = ((i + 0.5) / count - 0.5) * usableSpan;
      final stopPos = c + u * uOff + f * (depth * 0.5 - 0.42);
      mesh.withTransform(stopPos, bayYaw, () {
        mesh.addBox(0, 0.03, 0, 0.16, 0.12, stopWidth, stopCol);
      });
    }

    if (tintOverride == null) {
      final stripeLen = depth * 0.72;
      final isNS =
          lot.effectiveEntrySide == LotEntrySide.south ||
          lot.effectiveEntrySide == LotEntrySide.north;
      for (int i = 0; i <= count; i++) {
        final uOff = (i / count - 0.5) * usableSpan;
        final lineCenter = c + u * uOff + f * (depth * 0.06);
        mesh.addGroundRect(
          lineCenter.x,
          0.032,
          lineCenter.z,
          isNS ? 0.08 : stripeLen,
          isNS ? stripeLen : 0.08,
          stripeCol,
          layer: RenderLayer.groundDecal,
          depthBias: -0.10,
        );
      }

      // Back curb / timber rail along the rear edge so cars never visually overrun the pad
      final backRailPos = c + f * (depth * 0.5 - 0.10);
      if (lot.kind == ParkingLotKind.pavedLot) {
        mesh.withTransform(backRailPos, bayYaw, () {
          mesh.addBox(0, 0.03, 0, 0.18, 0.14, span - 0.24, DesertPalette.concrete);
        });
      }
    }

    // 4. Corner PARKING sign (Dirt) or Lamp (Gravel/Paved) placed OUTSIDE the bay envelope!
    if (tintOverride == null && lighting != null) {
      final cornerPos = c - u * (span * 0.5 + 0.06) + f * (depth * 0.5 - 0.12);
      // Face the sign outward toward oncoming road drivers
      final signYaw = bayYaw - math.pi * 0.5;
      if (lot.kind == ParkingLotKind.dirtPullOff) {
        mesh.addBoxShadow(
          cornerPos.x,
          cornerPos.z,
          0.9,
          0.3,
          1.6,
          lighting.shadowDirection,
          lighting.shadowColor,
        );
        mesh.withTransform(cornerPos, signYaw, () {
          mesh.addBox(0, 0, 0, 0.12, 1.65, 0.12, DesertPalette.woodDark);
          mesh.addBox(0, 1.08, 0, 1.18, 0.48, 0.12, DesertPalette.cream);
          mesh.addBox(0, 1.56, 0, 1.28, 0.08, 0.18, DesertPalette.terracotta);
          mesh.addFrontSignText(
            0,
            1.32,
            0.07,
            1.06,
            0.38,
            'PARKING',
            DesertPalette.sandstoneDark,
            nightGlow: false,
          );
        });
      } else {
        StreetLampAndFence.buildLamp(
          mesh,
          cornerPos,
          lighting,
          lighting.shadowColor,
        );
        if (lot.kind == ParkingLotKind.pavedLot) {
          final otherCorner = c + u * (span * 0.5 + 0.06) + f * (depth * 0.5 - 0.12);
          StreetLampAndFence.buildLamp(
            mesh,
            otherCorner,
            lighting,
            lighting.shadowColor,
          );
        }
      }
    }
  }
}
