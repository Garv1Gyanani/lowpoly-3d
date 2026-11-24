import 'dart:math' as math;
import 'dart:ui';

import '../engine/vec3.dart';
import '../world/outpost_layout.dart';

/// Identifiers for every business building in Desert Outpost.
enum BusinessType {
  vendorStall,
  convenienceStore,
  foodStand,
  desertDiner,
  gasStation,
  desertMotel,
  lookoutCamp,
  oasisPlaza,
}

/// Player-buildable road surface tiers unlocked by Outpost progression.
enum RoadTier {
  dirt,
  gravel,
  paved,
}

class RoadTierData {
  const RoadTierData({
    required this.tier,
    required this.name,
    required this.shortName,
    required this.unlockStage,
    required this.costPerTile,
    required this.vehicleSpeed,
    required this.accessFactor,
  });

  final RoadTier tier;
  final String name;
  final String shortName;
  final int unlockStage;
  final double costPerTile;
  final double vehicleSpeed;
  final double accessFactor;
}

const Map<RoadTier, RoadTierData> kRoadTierCatalog = {
  RoadTier.dirt: RoadTierData(
    tier: RoadTier.dirt,
    name: 'Dirt Track',
    shortName: 'DIRT',
    unlockStage: 1,
    costPerTile: 5,
    vehicleSpeed: 4.2,
    accessFactor: 0.72,
  ),
  RoadTier.gravel: RoadTierData(
    tier: RoadTier.gravel,
    name: 'Gravel Road',
    shortName: 'GRAVEL',
    unlockStage: 2,
    costPerTile: 14,
    vehicleSpeed: 5.6,
    accessFactor: 0.92,
  ),
  RoadTier.paved: RoadTierData(
    tier: RoadTier.paved,
    name: 'Paved Asphalt',
    shortName: 'PAVED',
    unlockStage: 4,
    costPerTile: 30,
    vehicleSpeed: 7.2,
    accessFactor: 1.08,
  ),
};

/// Freely placeable parking lot archetypes unlocked by Outpost progression.
enum ParkingLotKind {
  dirtPullOff,
  gravelLot,
  pavedLot,
}

class ParkingLotSpec {
  const ParkingLotSpec({
    required this.kind,
    required this.tier,
    required this.name,
    required this.shortName,
    required this.subtitle,
    required this.unlockStage,
    required this.cost,
    required this.spaces,
    required this.gridW,
    required this.gridD,
  });

  final ParkingLotKind kind;
  final int tier;
  final String name;
  final String shortName;
  final String subtitle;
  final int unlockStage;
  final double cost;
  final int spaces;
  final int gridW;
  final int gridD;
}

/// Which perimeter edge of a parking lot connects to the road / highway.
enum LotEntrySide {
  south, // Road on +Z side -> cars pull in heading -Z (north)
  west, // Road on -X side -> cars pull in heading +X (east)
  north, // Road on -Z side -> cars pull in heading +Z (south)
  east, // Road on +X side -> cars pull in heading -X (west)
}

const Map<ParkingLotKind, ParkingLotSpec> kParkingLotCatalog = {
  ParkingLotKind.dirtPullOff: ParkingLotSpec(
    kind: ParkingLotKind.dirtPullOff,
    tier: 1,
    name: 'Dirt Pull-Off',
    shortName: 'DIRT LOT',
    subtitle: '2 roomy bays (4×4m) · Fits trucks & RVs cleanly',
    unlockStage: 1,
    cost: 40,
    spaces: 2,
    gridW: 2,
    gridD: 2,
  ),
  ParkingLotKind.gravelLot: ParkingLotSpec(
    kind: ParkingLotKind.gravelLot,
    tier: 2,
    name: 'Gravel Lot',
    shortName: 'GRAVEL LOT',
    subtitle: '4 gravel bays + lamp · Upgrade from Dirt Pull-Off',
    unlockStage: 2,
    cost: 140,
    spaces: 4,
    gridW: 3,
    gridD: 2,
  ),
  ParkingLotKind.pavedLot: ParkingLotSpec(
    kind: ParkingLotKind.pavedLot,
    tier: 3,
    name: 'Paved Plaza Lot',
    shortName: 'PAVED LOT',
    subtitle: '6 striped asphalt bays + lamps · Maximum visitor flow',
    unlockStage: 4,
    cost: 320,
    spaces: 6,
    gridW: 4,
    gridD: 2,
  ),
};

/// Integer grid coordinate for roads, buildings, and parking lots.
class GridCell {
  const GridCell(this.gx, this.gz);

  final int gx;
  final int gz;

  Vec3 get worldCenter => OutpostLayout.cellCenter(gx, gz);

  List<GridCell> get neighbors4 => [
        GridCell(gx + 1, gz),
        GridCell(gx - 1, gz),
        GridCell(gx, gz + 1),
        GridCell(gx, gz - 1),
      ];

  int manhattanTo(GridCell other) => (gx - other.gx).abs() + (gz - other.gz).abs();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridCell && other.gx == gx && other.gz == gz;

  @override
  int get hashCode => Object.hash(gx, gz);

  @override
  String toString() => 'GridCell($gx, $gz)';
}

/// A single road tile painted by the player.
class RoadTile {
  const RoadTile({
    required this.cell,
    required this.tier,
  });

  final GridCell cell;
  final RoadTier tier;

  RoadTile copyWith({RoadTier? tier}) => RoadTile(
        cell: cell,
        tier: tier ?? this.tier,
      );
}

/// A player-placed parking lot connected to Route 163 or the road network.
/// Supports in-place tier upgrades, relocation, and automatic road-facing bay alignment.
class ParkingLotEntity {
  ParkingLotEntity({
    required this.id,
    required this.kind,
    required this.gridX,
    required this.gridZ,
    this.rotationQuarter = 0,
    this.connectedSide,
    this.isConnected = false,
    List<Vec3>? driveInPath,
  }) : driveInPath = driveInPath ?? <Vec3>[];

  final String id;
  ParkingLotKind kind;
  int gridX;
  int gridZ;
  int rotationQuarter;
  LotEntrySide? connectedSide;
  bool isConnected;
  List<Vec3> driveInPath;

  ParkingLotSpec get spec => kParkingLotCatalog[kind]!;

  ParkingLotKind? get nextUpgradeKind => switch (kind) {
        ParkingLotKind.dirtPullOff => ParkingLotKind.gravelLot,
        ParkingLotKind.gravelLot => ParkingLotKind.pavedLot,
        ParkingLotKind.pavedLot => null,
      };

  (int w, int d) get sizeCells =>
      OutpostLayout.rotatedSize(spec.gridW, spec.gridD, rotationQuarter);

  Vec3 get position {
    final (w, d) = sizeCells;
    return OutpostLayout.footprintCenter(gridX, gridZ, w, d);
  }

  double get yaw => OutpostLayout.yawForQuarterTurn(rotationQuarter);

  /// Active road-facing side: uses the detected adjacent road side when connected,
  /// otherwise falls back to [rotationQuarter].
  LotEntrySide get effectiveEntrySide {
    if (connectedSide != null) return connectedSide!;
    return switch (rotationQuarter & 3) {
      0 => LotEntrySide.south,
      1 => LotEntrySide.west,
      2 => LotEntrySide.north,
      _ => LotEntrySide.east,
    };
  }

  /// Unit vector pointing INTO the parking bay from the road (the nose-in heading).
  Vec3 get pullInDir => switch (effectiveEntrySide) {
        LotEntrySide.south => const Vec3(0, 0, -1),
        LotEntrySide.north => const Vec3(0, 0, 1),
        LotEntrySide.east => const Vec3(-1, 0, 0),
        LotEntrySide.west => const Vec3(1, 0, 0),
      };

  /// Unit vector pointing ACROSS the row of bays (perpendicular to [pullInDir]).
  Vec3 get bayRowAxis => switch (effectiveEntrySide) {
        LotEntrySide.south => const Vec3(1, 0, 0),
        LotEntrySide.north => const Vec3(-1, 0, 0),
        LotEntrySide.east => const Vec3(0, 0, -1),
        LotEntrySide.west => const Vec3(0, 0, 1),
      };

  /// Exact world yaw for a vehicle parked nose-in inside this lot.
  double get parkedYaw => switch (effectiveEntrySide) {
        LotEntrySide.south => -math.pi * 0.5,
        LotEntrySide.north => math.pi * 0.5,
        LotEntrySide.east => math.pi,
        LotEntrySide.west => 0.0,
      };

  /// `(spanAcrossBays, depthAlongBay)` in world units for the active [effectiveEntrySide].
  (double span, double depth) get orientedWorldDimensions {
    final (w, d) = sizeCells;
    final worldW = w * OutpostLayout.gridCellSize;
    final worldD = d * OutpostLayout.gridCellSize;
    return switch (effectiveEntrySide) {
      LotEntrySide.south || LotEntrySide.north => (worldW, worldD),
      LotEntrySide.east || LotEntrySide.west => (worldD, worldW),
    };
  }

  List<GridCell> get occupiedCells {
    final (w, d) = sizeCells;
    final cells = <GridCell>[];
    for (int dx = 0; dx < w; dx++) {
      for (int dz = 0; dz < d; dz++) {
        cells.add(GridCell(gridX + dx, gridZ + dz));
      }
    }
    return cells;
  }

  /// World positions for each nose-in parking bay inside this lot.
  List<Vec3> get slotPositions {
    final center = position;
    final count = spec.spaces;
    final (span, _) = orientedWorldDimensions;
    final u = bayRowAxis;
    final f = pullInDir;
    final usableSpan = span - 0.36;
    final slots = <Vec3>[];
    for (int i = 0; i < count; i++) {
      final offset = ((i + 0.5) / count - 0.5) * usableSpan;
      // Slight setback toward entry so 3.05m RVs sit squarely behind the wheel stop.
      slots.add(center + u * offset - f * 0.14);
    }
    return slots;
  }

  /// Point on the adjacent road aisle directly in front of bay [slotIndex] so vehicles
  /// turn cleanly at 90 degrees straight into their bay instead of cutting diagonally.
  Vec3 aislePointForSlot(int slotIndex) {
    final slots = slotPositions;
    final slot = slots[slotIndex.clamp(0, slots.length - 1)];
    final (_, depth) = orientedWorldDimensions;
    return slot - pullInDir * (depth * 0.5 + 0.85);
  }

  /// Safe pedestrian exit spot beside bay [slotIndex] (never on wheel stops or under bumpers).
  Vec3 visitorSpawnForSlot(int slotIndex, int passengerIndex) {
    final slots = slotPositions;
    final slot = slots[slotIndex.clamp(0, slots.length - 1)];
    final (span, depth) = orientedWorldDimensions;
    final bayPitch = (span - 0.36) / spec.spaces;
    return slot +
        bayRowAxis * (bayPitch * 0.42) +
        pullInDir * (depth * 0.32 - passengerIndex * 0.36);
  }

  bool containsPoint(Vec3 point, {double margin = 0.25}) {
    final (w, d) = sizeCells;
    final center = position;
    final hw = w * OutpostLayout.gridCellSize * 0.5 + margin;
    final hd = d * OutpostLayout.gridCellSize * 0.5 + margin;
    return (point.x - center.x).abs() <= hw && (point.z - center.z).abs() <= hd;
  }
}

/// Evaluated road-access & location quality report for a single store.
class RoadAccessReport {
  const RoadAccessReport({
    required this.score,
    required this.hasHighwayConnection,
    required this.hasDirectRoad,
    required this.frontageAligned,
    required this.hasParkingAccess,
    required this.roadTier,
    required this.roadStepsFromHighway,
    required this.walkStepsFromParking,
    required this.scenicBonus,
    required this.highwayBonus,
    required this.statusLabel,
    required this.hint,
    required this.routePreview,
  });

  static const RoadAccessReport disconnected = RoadAccessReport(
    score: 0.0,
    hasHighwayConnection: false,
    hasDirectRoad: false,
    frontageAligned: false,
    hasParkingAccess: false,
    roadTier: null,
    roadStepsFromHighway: 999,
    walkStepsFromParking: 999,
    scenicBonus: false,
    highwayBonus: false,
    statusLabel: 'NO ROAD',
    hint: 'Connect road & parking from Route 163',
    routePreview: <Vec3>[],
  );

  /// `0.0` (isolated) up to `1.35` (paved loop + parking + location bonus).
  final double score;
  final bool hasHighwayConnection;
  final bool hasDirectRoad;
  final bool frontageAligned;
  final bool hasParkingAccess;
  final RoadTier? roadTier;
  final int roadStepsFromHighway;
  final int walkStepsFromParking;
  final bool scenicBonus;
  final bool highwayBonus;
  final String statusLabel;
  final String hint;
  final List<Vec3> routePreview;

  int get percent => (score * 100).round();
  bool get isPoor => score < 0.55;
  bool get isGreat => score >= 0.88;
}

/// Interactive tool mode on the main 3D canvas.
enum WorldToolMode {
  play,
  paintRoad,
  placeBuilding,
  placeParking,
  placeDecoration,
  buyLand,
}

/// Live preview of a straight / L-shaped road line drawn with the road tool.
class RoadLinePreview {
  const RoadLinePreview({
    required this.cells,
    required this.buildCells,
    required this.skipCells,
    required this.blockedCells,
    required this.cost,
    required this.blockReason,
  });

  static const RoadLinePreview empty = RoadLinePreview(
    cells: <GridCell>[],
    buildCells: <GridCell>[],
    skipCells: <GridCell>[],
    blockedCells: <GridCell>[],
    cost: 0,
    blockReason: null,
  );

  final List<GridCell> cells;
  final List<GridCell> buildCells;
  final List<GridCell> skipCells;
  final List<GridCell> blockedCells;
  final double cost;
  final String? blockReason;

  bool get isValid => blockReason == null && buildCells.isNotEmpty;
}

/// Data-driven business definition with grid footprint & progression stage.
class BusinessData {
  const BusinessData({
    required this.type,
    required this.stage,
    required this.name,
    required this.subtitle,
    required this.purchaseCost,
    required this.baseIncomePerMin,
    required this.upgradeCostBase,
    required this.upgradeMultiplier,
    required this.maxLevel,
    required this.accentColor,
    required this.upgradeNotes,
    required this.gridW,
    required this.gridD,
    this.prefersScenic = false,
    this.prefersHighway = false,
  });

  final BusinessType type;
  final int stage;
  final String name;
  final String subtitle;
  final double purchaseCost;
  final double baseIncomePerMin;
  final double upgradeCostBase;
  final double upgradeMultiplier;
  final int maxLevel;
  final Color accentColor;
  final List<String> upgradeNotes;
  final int gridW;
  final int gridD;
  final bool prefersScenic;
  final bool prefersHighway;

  double incomeForLevel(int level) {
    if (level <= 0) return 0;
    return baseIncomePerMin * (1.0 + (level - 1) * 0.72);
  }

  double upgradeCostForLevel(int currentLevel) {
    double cost = upgradeCostBase;
    for (int i = 1; i < currentLevel; i++) {
      cost *= upgradeMultiplier;
    }
    return cost.roundToDouble();
  }

  String nextUpgradeLabel(int currentLevel) {
    final idx = (currentLevel - 1).clamp(0, upgradeNotes.length - 1);
    return upgradeNotes[idx];
  }
}

/// A construction plot / placed store in the desert outpost diorama.
/// Supports freeform grid placement, 90-degree rotation, and live road-access scoring.
class PlotState {
  PlotState({
    required this.id,
    required this.businessType,
    required this.gridX,
    required this.gridZ,
    required this.footprintWidth,
    required this.footprintDepth,
    this.rotationQuarter = 0,
    this.decorativeYawOffset = 0.0,
    this.isBuilt = false,
    this.level = 1,
    this.bounceTimer = 0.0,
    this.buildPopTimer = 0.0,
    this.access = RoadAccessReport.disconnected,
  });

  final String id;
  final BusinessType businessType;
  int gridX;
  int gridZ;
  final double footprintWidth;
  final double footprintDepth;
  int rotationQuarter;
  double decorativeYawOffset;

  bool isBuilt;
  int level;
  double bounceTimer;
  double buildPopTimer;
  RoadAccessReport access;

  BusinessData get data => kBusinessCatalog[businessType]!;

  (int w, int d) get sizeCells =>
      OutpostLayout.rotatedSize(data.gridW, data.gridD, rotationQuarter);

  Vec3 get position {
    final (w, d) = sizeCells;
    return OutpostLayout.footprintCenter(gridX, gridZ, w, d);
  }

  double get yaw => OutpostLayout.yawForQuarterTurn(rotationQuarter) + decorativeYawOffset;

  List<GridCell> get occupiedCells {
    final (w, d) = sizeCells;
    final cells = <GridCell>[];
    for (int dx = 0; dx < w; dx++) {
      for (int dz = 0; dz < d; dz++) {
        cells.add(GridCell(gridX + dx, gridZ + dz));
      }
    }
    return cells;
  }

  /// Grid cell immediately in front of the store's rotated entrance.
  GridCell get entranceCell {
    final (w, d) = sizeCells;
    return switch (rotationQuarter & 3) {
      0 => GridCell(gridX + (w ~/ 2), gridZ + d), // Facing +Z (south / highway)
      1 => GridCell(gridX - 1, gridZ + (d ~/ 2)), // Facing -X (west)
      2 => GridCell(gridX + (w ~/ 2), gridZ - 1), // Facing -Z (north / mesas)
      _ => GridCell(gridX + w, gridZ + (d ~/ 2)), // Facing +X (east)
    };
  }

  /// World-space stopping point where visitors browse/shop at this store.
  Vec3 get visitorStopPoint {
    final (dx, dz) = OutpostLayout.forwardStepForQuarterTurn(rotationQuarter);
    final (w, d) = sizeCells;
    final frontDist = (dx != 0 ? w : d) * OutpostLayout.gridCellSize * 0.5 + 0.55;
    final c = position;
    return Vec3(c.x + dx * frontDist, 0.0, c.z + dz * frontDist);
  }

  bool containsGroundPoint(Vec3 point, {double margin = 0.75}) {
    final (w, d) = sizeCells;
    final hw = (w * OutpostLayout.gridCellSize * 0.5).clamp(footprintWidth * 0.5, 6.0) + margin;
    final hd = (d * OutpostLayout.gridCellSize * 0.5).clamp(footprintDepth * 0.5, 6.0) + margin;
    final pos = position;
    return (point.x - pos.x).abs() <= hw && (point.z - pos.z).abs() <= hd;
  }
}

enum VehicleKind {
  compactCar,
  pickupTruck,
  suv,
  camperRv,
  touristVan,
}

enum VehiclePhase {
  highwayCruise,
  pullingIn,
  parked,
  backingOut,
  pullingOut,
}

class VehicleEntity {
  VehicleEntity({
    required this.id,
    required this.kind,
    required this.bodyColor,
    required this.position,
    required this.yaw,
    required this.speed,
    required this.direction,
    required this.phase,
    this.parkingLotId,
    this.parkingSlotIndex = -1,
    this.parkTimer = 0.0,
    this.spawnedVisitor = false,
    List<Vec3>? waypoints,
    List<Vec3>? exitWaypoints,
  })  : waypoints = waypoints ?? <Vec3>[],
        exitWaypoints = exitWaypoints ?? <Vec3>[];

  final int id;
  final VehicleKind kind;
  final Color bodyColor;
  Vec3 position;
  double yaw;
  double speed;
  final int direction;
  VehiclePhase phase;
  String? parkingLotId;
  int parkingSlotIndex;
  double parkTimer;
  bool spawnedVisitor;
  final List<Vec3> waypoints;
  final List<Vec3> exitWaypoints;

  /// X of the last highway junction this car already decided about (no re-rolls per frame).
  double consideredEntryX = double.nan;

  bool get isBrakingOrReversing =>
      phase == VehiclePhase.backingOut || phase == VehiclePhase.parked;
}

enum VisitorPhase {
  walkingToBusiness,
  shopping,
  returningToCar,
}

class VisitorEntity {
  VisitorEntity({
    required this.id,
    required this.shirtColor,
    required this.hatColor,
    required this.position,
    required this.origin,
    required this.destination,
    required this.targetPlotId,
    required this.vehicleId,
    required this.phase,
    this.yaw = -1.57,
    this.walkCycle = 0.0,
    this.waitTimer = 0.0,
    List<Vec3>? outboundPath,
    List<Vec3>? returnPath,
  })  : outboundPath = outboundPath ?? <Vec3>[destination],
        returnPath = returnPath ?? <Vec3>[origin];

  final int id;
  final Color shirtColor;
  final Color hatColor;
  Vec3 position;
  final Vec3 origin;
  final Vec3 destination;
  final String targetPlotId;
  final int vehicleId;
  VisitorPhase phase;
  double yaw;
  double walkCycle;
  double waitTimer;
  final List<Vec3> outboundPath;
  final List<Vec3> returnPath;
}

/// Floating `$` popup indicator with lateral arc drift so rapid taps never smudge together.
class FloatingCash {
  FloatingCash({
    required this.position,
    required this.text,
    required this.color,
    this.driftX = 0.0,
    this.age = 0.0,
    this.duration = 1.15,
  });

  final Vec3 position;
  final String text;
  final Color color;
  final double driftX;
  double age;
  final double duration;

  double get progress => (age / duration).clamp(0.0, 1.0);
  bool get isDone => age >= duration;
}

/// Short dust puff or golden coin sparkle particle in 3D space.
class Particle3D {
  Particle3D({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    this.age = 0.0,
    this.duration = 0.7,
    this.isCoin = false,
  });

  Vec3 position;
  Vec3 velocity;
  final Color color;
  final double size;
  double age;
  final double duration;
  final bool isCoin;

  double get progress => (age / duration).clamp(0.0, 1.0);
  bool get isDone => age >= duration;
}

enum DecorationKind {
  saguaroCluster,
  woodenSignpost,
  picnicSet,
  desertLamp,
  campfireRing,
}

class PlacedDecoration {
  const PlacedDecoration({
    required this.id,
    required this.kind,
    required this.position,
    required this.name,
    required this.cost,
    this.gridX = 0,
    this.gridZ = 0,
  });

  final String id;
  final DecorationKind kind;
  final Vec3 position;
  final String name;
  final double cost;
  final int gridX;
  final int gridZ;

  GridCell get cell => GridCell(gridX, gridZ);
}

class MilestoneData {
  MilestoneData({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardCash,
    required this.checkCompleted,
    this.claimed = false,
  });

  final String id;
  final String title;
  final String description;
  final double rewardCash;
  final bool Function() checkCompleted;
  bool claimed;
}

class ParkingTierData {
  const ParkingTierData({
    required this.tier,
    required this.name,
    required this.subtitle,
    required this.cost,
    required this.spaces,
  });

  final int tier;
  final String name;
  final String subtitle;
  final double cost;
  final int spaces;
}

const List<ParkingTierData> kParkingTiers = [
  ParkingTierData(
    tier: 0,
    name: 'Raw Desert Shoulder',
    subtitle: 'No parking yet — highway traffic cruises past',
    cost: 0,
    spaces: 0,
  ),
  ParkingTierData(
    tier: 1,
    name: 'Dirt Pull-Off',
    subtitle: '2 sandy spaces + roadside sign · First customers stop!',
    cost: 40,
    spaces: 2,
  ),
  ParkingTierData(
    tier: 2,
    name: 'Gravel Lot & Lamps',
    subtitle: '4 gravel spaces + boardwalk promenade + timber lamps',
    cost: 160,
    spaces: 4,
  ),
  ParkingTierData(
    tier: 3,
    name: 'Paved Outpost Lot',
    subtitle: '6 asphalt bays + driveways + Welcome Billboard & string lights',
    cost: 380,
    spaces: 6,
  ),
];

/// Stage progression metadata so players clearly see what unlocks next.
class OutpostStageInfo {
  const OutpostStageInfo({
    required this.stage,
    required this.title,
    required this.maxBuildingLevel,
    required this.maxHighwayTurnOffs,
    required this.maxParcels,
    required this.nextRequirement,
  });

  final int stage;
  final String title;
  final int maxBuildingLevel;

  /// Maximum number of separate highway junctions (contiguous road runs on Route 163).
  final int maxHighwayTurnOffs;

  /// Maximum number of owned land parcels at this stage.
  final int maxParcels;
  final String nextRequirement;
}

const List<OutpostStageInfo> kOutpostStages = [
  OutpostStageInfo(
    stage: 1,
    title: 'Desert Cart',
    maxBuildingLevel: 2,
    maxHighwayTurnOffs: 1,
    maxParcels: 2,
    nextRequirement: 'Build an access road from Route 163 & a parking lot',
  ),
  OutpostStageInfo(
    stage: 2,
    title: 'Trail Stop',
    maxBuildingLevel: 2,
    maxHighwayTurnOffs: 1,
    maxParcels: 3,
    nextRequirement: 'Run 2 connected stores & serve 4 visitors (or 3 gravel tiles)',
  ),
  OutpostStageInfo(
    stage: 3,
    title: 'Desert Strip',
    maxBuildingLevel: 3,
    maxHighwayTurnOffs: 2,
    maxParcels: 5,
    nextRequirement: 'Run 4 connected stores & 4+ parking bays',
  ),
  OutpostStageInfo(
    stage: 4,
    title: 'Oasis Hub',
    maxBuildingLevel: 4,
    maxHighwayTurnOffs: 2,
    maxParcels: 8,
    nextRequirement: 'Run 5 connected stores & 4+ Paved tiles (or 6 bays)',
  ),
  OutpostStageInfo(
    stage: 5,
    title: 'Desert Resort',
    maxBuildingLevel: 4,
    maxHighwayTurnOffs: 3,
    maxParcels: 12,
    nextRequirement: 'Run 7 connected stores & 6+ parking bays',
  ),
  OutpostStageInfo(
    stage: 6,
    title: 'Monument Outpost',
    maxBuildingLevel: 5,
    maxHighwayTurnOffs: 4,
    maxParcels: 20,
    nextRequirement: 'Flagship Monument Valley Outpost!',
  ),
];

/// Balanced catalog of all 8 Desert Outpost businesses across Stages 1–6.
const Map<BusinessType, BusinessData> kBusinessCatalog = {
  BusinessType.vendorStall: BusinessData(
    type: BusinessType.vendorStall,
    stage: 1,
    name: 'Roadside Cart & Stall',
    subtitle: 'Stage 1 · Cold drinks, snacks & postcards',
    purchaseCost: 0,
    baseIncomePerMin: 18,
    upgradeCostBase: 65,
    upgradeMultiplier: 1.75,
    maxLevel: 5,
    accentColor: Color(0xFFC8794B),
    gridW: 2,
    gridD: 2,
    prefersHighway: true,
    upgradeNotes: [
      'Build wooden stall, striped awning & string lights',
      'Add rooftop DRINKS sign & shaded patio umbrella',
      'Woven Navajo banner & festoon string-light pole',
      'Flagship twin-umbrella stand & desert pennant mast',
    ],
  ),
  BusinessType.convenienceStore: BusinessData(
    type: BusinessType.convenienceStore,
    stage: 2,
    name: 'Outpost Mart',
    subtitle: 'Stage 2 · Convenience store & road supplies',
    purchaseCost: 140,
    baseIncomePerMin: 48,
    upgradeCostBase: 110,
    upgradeMultiplier: 1.78,
    maxLevel: 5,
    accentColor: Color(0xFF4F9A94),
    gridW: 3,
    gridD: 3,
    upgradeNotes: [
      'Shaded porch, ice chest & glowing soda vendor',
      'Expanded adobe annex & rooftop AC stack',
      'Covered firewood trading rack & adobe frieze',
      'Rooftop solar array & spinning brass weathervane',
    ],
  ),
  BusinessType.foodStand: BusinessData(
    type: BusinessType.foodStand,
    stage: 3,
    name: 'Taco & Coffee Stand',
    subtitle: 'Stage 3 · Fresh street food & iced brews',
    purchaseCost: 260,
    baseIncomePerMin: 75,
    upgradeCostBase: 180,
    upgradeMultiplier: 1.8,
    maxLevel: 5,
    accentColor: Color(0xFFC9533E),
    gridW: 2,
    gridD: 2,
    upgradeNotes: [
      'Steaming rooftop espresso mug & CAFE marquee',
      'Shaded red patio umbrella & cactus planter',
      'Twin turquoise patio umbrella & golden neon trim',
      'Signature festoon string-light espresso pergola',
    ],
  ),
  BusinessType.desertDiner: BusinessData(
    type: BusinessType.desertDiner,
    stage: 3,
    name: 'Route 163 Diner',
    subtitle: 'Stage 3 · Streamlined Googie roadside diner',
    purchaseCost: 520,
    baseIncomePerMin: 140,
    upgradeCostBase: 320,
    upgradeMultiplier: 1.82,
    maxLevel: 5,
    accentColor: Color(0xFFD96448),
    gridW: 4,
    gridD: 3,
    upgradeNotes: [
      'Outdoor turquoise patio tables & umbrellas',
      'Spinning golden rooftop starburst beacon',
      'Swept Googie side roof fins & jukebox glow',
      'Twin neon Googie starbursts & flagship plaza',
    ],
  ),
  BusinessType.gasStation: BusinessData(
    type: BusinessType.gasStation,
    stage: 4,
    name: 'Canyon Fuel & Garage',
    subtitle: 'Stage 4 · Fuel pumps & highway repair bay',
    purchaseCost: 900,
    baseIncomePerMin: 220,
    upgradeCostBase: 520,
    upgradeMultiplier: 1.84,
    maxLevel: 5,
    accentColor: Color(0xFFDF9D42),
    gridW: 3,
    gridD: 3,
    prefersHighway: true,
    upgradeNotes: [
      'Tall illuminated highway GAS price totem',
      'Mechanic tool chest, oil drum & spare tire stack',
      'Garage solar panels & turquoise air/water stand',
      'Rotating golden highway star-shield beacon',
    ],
  ),
  BusinessType.oasisPlaza: BusinessData(
    type: BusinessType.oasisPlaza,
    stage: 5,
    name: 'Oasis Souvenir Plaza',
    subtitle: 'Stage 5 · Plunge pool, palms & craft market',
    purchaseCost: 1250,
    baseIncomePerMin: 285,
    upgradeCostBase: 680,
    upgradeMultiplier: 1.84,
    maxLevel: 5,
    accentColor: Color(0xFF5DA9B8),
    gridW: 3,
    gridD: 2,
    prefersScenic: true,
    upgradeNotes: [
      'Sculpted desert palm tree & potted agave',
      'Turquoise poolside umbrella & craft lounge',
      'Twin desert palms & red-rock pool waterfall',
      'Evening oasis lantern wires & golden sun crest',
    ],
  ),
  BusinessType.desertMotel: BusinessData(
    type: BusinessType.desertMotel,
    stage: 5,
    name: 'Red Rock Motel',
    subtitle: 'Stage 5 · Adobe rooms & cozy desert cabins',
    purchaseCost: 1650,
    baseIncomePerMin: 360,
    upgradeCostBase: 850,
    upgradeMultiplier: 1.86,
    maxLevel: 5,
    accentColor: Color(0xFFA9573D),
    gridW: 4,
    gridD: 3,
    prefersScenic: true,
    upgradeNotes: [
      'Second-story timber balcony & exterior stairs',
      'Cozy pitched-roof guest cabin & stone chimney',
      'Courtyard guest umbrella lounge & planters',
      'Rooftop redwood water cistern & balcony lights',
    ],
  ),
  BusinessType.lookoutCamp: BusinessData(
    type: BusinessType.lookoutCamp,
    stage: 6,
    name: 'Mesa Lookout & Camp',
    subtitle: 'Stage 6 · Water tower, tour desk & camp',
    purchaseCost: 2800,
    baseIncomePerMin: 520,
    upgradeCostBase: 1300,
    upgradeMultiplier: 1.88,
    maxLevel: 5,
    accentColor: Color(0xFF79805A),
    gridW: 4,
    gridD: 3,
    prefersScenic: true,
    upgradeNotes: [
      'Canvas desert A-frame tents & campfire',
      'Shaded trailhead tour patio & map deck',
      'High-altitude festoon lights up to Lookout Tower',
      'Fluttering canyon summit flag & grand basecamp',
    ],
  ),
};
