import '../engine/vec3.dart';

/// Shared spatial layout constants for Route 163, parking bays, driveways,
/// pedestrian sidewalks, and landmark plot orientations so 3D terrain decals
/// and AI pathfinding stay strictly synchronized.
class OutpostLayout {
  const OutpostLayout._();

  // Highway Z coordinates
  static const double highwayCenterZ = 13.4;
  static const double highwayWestboundZ = 12.5;
  static const double highwayEastboundZ = 14.3;

  // Parking lot & driveway geometry
  static const double parkingAisleZ = 10.95;
  static const double parkingRowZ = 9.2;

  static const List<Vec3> parkingSlots = [
    Vec3(-7.0, 0, parkingRowZ), // 0 (Tier 3)
    Vec3(-4.2, 0, parkingRowZ), // 1 (Tier 2)
    Vec3(-1.4, 0, parkingRowZ), // 2 (Tier 1)
    Vec3(1.4, 0, parkingRowZ), // 3 (Tier 1)
    Vec3(4.2, 0, parkingRowZ), // 4 (Tier 2)
    Vec3(7.0, 0, parkingRowZ), // 5 (Tier 3)
  ];

  static List<int> activeSlotIndicesForTier(int tier) {
    if (tier <= 0) return const [];
    if (tier == 1) return const [2, 3];
    if (tier == 2) return const [1, 2, 3, 4];
    return const [0, 1, 2, 3, 4, 5];
  }

  static double drivewayHalfSpanForTier(int tier) {
    if (tier <= 1) return 2.5;
    if (tier == 2) return 5.2;
    return 8.2;
  }

  // Pedestrian boardwalk & town walkways
  static const double frontPromenadeZ = 6.9;
  static const double midCrosswalkZ = 2.2;
  static const double upperTerraceZ = -5.0;
  static const double centralSpineX = 0.25;
}
