import 'dart:math' as math;

import '../engine/vec3.dart';

/// Shared spatial layout for the open-desert outpost world:
/// a 64 x 64 tile buildable map (2 world units per tile) north of Route 163,
/// divided into 8 x 8 land parcels that the player buys to expand.
class OutpostLayout {
  const OutpostLayout._();

  // Route 163 runs east-west along the south edge of the map.
  static const double highwayCenterZ = 13.4;
  static const double highwayWestboundZ = 12.5;
  static const double highwayEastboundZ = 14.3;
  static const double highwayNorthEdgeZ = 11.1;

  /// Legacy fallback aisle used only for lots that border the highway directly.
  static const double parkingAisleZ = 10.95;

  // Tile grid
  static const double gridCellSize = 2.0;
  static const int minGridX = -32;
  static const int maxGridX = 31;
  static const int minGridZ = -58;
  static const int maxGridZ = 5;

  /// Row immediately bordering Route 163 where roads become highway junctions.
  static const int highwayEntryRowZ = 5;

  // Land parcels
  static const int parcelSize = 8;
  static const int parcelCountX = 8;
  static const int parcelCountZ = 8;

  /// Two starter parcels in the middle of the desert (~40 units north of Route 163).
  static const List<(int, int)> starterParcels = [(3, 5), (4, 5)];

  /// Stores whose rows are at or north of this line sit in the Scenic Mesa zone.
  static const int scenicRowMax = -35;

  /// Stores reaching this row or further south count as highway-edge businesses.
  static const int highwayBonusRowMin = -1;

  static const double worldMinX = (minGridX - 0.5) * gridCellSize;
  static const double worldMaxX = (maxGridX + 0.5) * gridCellSize;
  static const double worldMinZ = (minGridZ - 0.5) * gridCellSize;
  static const double worldMaxZ = (maxGridZ + 0.5) * gridCellSize;

  static Vec3 cellCenter(int gx, int gz) =>
      Vec3(gx * gridCellSize, 0.0, gz * gridCellSize);

  static (int gx, int gz) worldToCell(Vec3 worldPos) => (
        (worldPos.x / gridCellSize).round(),
        (worldPos.z / gridCellSize).round(),
      );

  static bool isCellInMap(int gx, int gz) =>
      gx >= minGridX && gx <= maxGridX && gz >= minGridZ && gz <= maxGridZ;

  static (int px, int pz) parcelOf(int gx, int gz) => (
        ((gx - minGridX) / parcelSize).floor(),
        ((gz - minGridZ) / parcelSize).floor(),
      );

  static bool isParcelInMap(int px, int pz) =>
      px >= 0 && px < parcelCountX && pz >= 0 && pz < parcelCountZ;

  /// Inclusive tile bounds `(minGx, maxGx, minGz, maxGz)` of a parcel.
  static (int, int, int, int) parcelCellBounds(int px, int pz) {
    final minGx = minGridX + px * parcelSize;
    final minGz = minGridZ + pz * parcelSize;
    return (minGx, minGx + parcelSize - 1, minGz, minGz + parcelSize - 1);
  }

  static Vec3 parcelCenter(int px, int pz) {
    final (minGx, maxGx, minGz, maxGz) = parcelCellBounds(px, pz);
    return Vec3(
      (minGx + maxGx) * 0.5 * gridCellSize,
      0.0,
      (minGz + maxGz) * 0.5 * gridCellSize,
    );
  }

  static Vec3 footprintCenter(int gx, int gz, int widthCells, int depthCells) {
    final cx = (gx + (widthCells - 1) * 0.5) * gridCellSize;
    final cz = (gz + (depthCells - 1) * 0.5) * gridCellSize;
    return Vec3(cx, 0.0, cz);
  }

  static (int w, int d) rotatedSize(int baseW, int baseD, int rotationQuarter) {
    final r = rotationQuarter & 3;
    return (r == 1 || r == 3) ? (baseD, baseW) : (baseW, baseD);
  }

  /// Yaw for quarter turns `0..3` (`0` = front facing +Z toward Route 163).
  static double yawForQuarterTurn(int rotationQuarter) =>
      (rotationQuarter & 3) * (math.pi * 0.5);

  /// Forward unit grid step for a quarter turn, matching `Vec3.rotateY`
  /// (`+Z` rotated by +90° points toward `-X`).
  static (int dx, int dz) forwardStepForQuarterTurn(int rotationQuarter) {
    return switch (rotationQuarter & 3) {
      0 => (0, 1),
      1 => (-1, 0),
      2 => (0, -1),
      _ => (1, 0),
    };
  }
}
