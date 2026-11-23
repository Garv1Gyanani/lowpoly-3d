import 'package:flutter/material.dart';

import '../engine/vec3.dart';

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

/// Data-driven business definition (GDD Section 16).
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
    required this.icon,
    required this.accentColor,
    required this.upgradeNotes,
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
  final IconData icon;
  final Color accentColor;
  final List<String> upgradeNotes;

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

/// A fixed construction plot in the portrait desert outpost diorama.
class PlotState {
  PlotState({
    required this.id,
    required this.businessType,
    required this.position,
    required this.footprintWidth,
    required this.footprintDepth,
    required this.visitorStopPoint,
    this.isBuilt = false,
    this.level = 1,
    this.bounceTimer = 0.0,
    this.buildPopTimer = 0.0,
  });

  final String id;
  final BusinessType businessType;
  final Vec3 position;
  final double footprintWidth;
  final double footprintDepth;
  final Vec3 visitorStopPoint;

  bool isBuilt;
  int level;

  /// Short squash-and-stretch animation when tapped or upgraded.
  double bounceTimer;

  /// Pop-in rise animation when newly constructed.
  double buildPopTimer;

  bool containsGroundPoint(Vec3 point, {double margin = 0.75}) {
    final hw = footprintWidth * 0.5 + margin;
    final hd = footprintDepth * 0.5 + margin;
    return (point.x - position.x).abs() <= hw &&
        (point.z - position.z).abs() <= hd;
  }
}

/// Low-poly vehicle archetypes from GDD Section 8.
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
    this.parkingSlotIndex = -1,
    this.parkTimer = 0.0,
    this.spawnedVisitor = false,
    List<Vec3>? waypoints,
  }) : waypoints = waypoints ?? <Vec3>[];

  final int id;
  final VehicleKind kind;
  final Color bodyColor;
  Vec3 position;
  double yaw;
  double speed;

  /// +1 moving East (+X), -1 moving West (-X).
  final int direction;
  VehiclePhase phase;
  int parkingSlotIndex;
  double parkTimer;
  bool spawnedVisitor;
  final List<Vec3> waypoints;

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

/// Floating `$` popup indicator when tapping or when visitors complete a purchase.
class FloatingCash {
  FloatingCash({
    required this.position,
    required this.text,
    required this.color,
    this.age = 0.0,
    this.duration = 1.15,
  });

  final Vec3 position;
  final String text;
  final Color color;
  double age;
  final double duration;

  double get progress => (age / duration).clamp(0.0, 1.0);
  bool get isDone => age >= duration;
}

/// Short dust puff or coin sparkle particle in 3D space.
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

/// Optional decorative low-poly props the player can add around the outpost.
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
  });

  final String id;
  final DecorationKind kind;
  final Vec3 position;
  final String name;
  final double cost;
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

/// Progressive roadside parking & infrastructure tiers (Tier 0 -> Tier 3).
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
    cost: 180,
    spaces: 4,
  ),
  ParkingTierData(
    tier: 3,
    name: 'Paved Outpost Lot',
    subtitle: '6 asphalt bays + driveways + Welcome Billboard & fences',
    cost: 550,
    spaces: 6,
  ),
];

/// Catalog of all 8 Desert Outpost businesses following GDD Stages 1–6.
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
    icon: Icons.storefront_rounded,
    accentColor: Color(0xFFC8794B),
    upgradeNotes: [
      'Build wooden stall, striped awning & string lights',
      'Add rooftop DRINKS sign & shaded patio umbrella',
      'Deluxe counter bottles & cooler capacity',
      'Flagship desert refreshment stand',
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
    icon: Icons.local_convenience_store_rounded,
    accentColor: Color(0xFF4F9A94),
    upgradeNotes: [
      'Shaded porch & ice chest',
      'Rooftop billboard & night lights',
      'Expanded adobe annex & racks',
      'Flagship highway trading post',
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
    icon: Icons.local_cafe_rounded,
    accentColor: Color(0xFFC9533E),
    upgradeNotes: [
      'Shaded umbrellas & bar stools',
      'Rooftop coffee cup marquee',
      'Patio string lights & double grill',
      'Signature desert espresso bar',
    ],
  ),
  BusinessType.desertDiner: BusinessData(
    type: BusinessType.desertDiner,
    stage: 3,
    name: 'Route 163 Diner',
    subtitle: 'Stage 3 · Classic Utah roadside diner',
    purchaseCost: 520,
    baseIncomePerMin: 140,
    upgradeCostBase: 320,
    upgradeMultiplier: 1.82,
    maxLevel: 5,
    icon: Icons.restaurant_rounded,
    accentColor: Color(0xFFD96448),
    upgradeNotes: [
      'Outdoor patio tables & awning',
      'Glowing neon marquee & vents',
      'Expanded booth wing & jukebox',
      'Famous Monument Valley diner',
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
    icon: Icons.local_gas_station_rounded,
    accentColor: Color(0xFFDF9D42),
    upgradeNotes: [
      'Extra pump island & glowing canopy',
      'Tall highway price totem & tools',
      'Express tire & repair bay upgrade',
      'Full-service desert travel plaza',
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
    icon: Icons.hotel_rounded,
    accentColor: Color(0xFFA9573D),
    upgradeNotes: [
      'Upper balcony & illuminated rooms',
      'Vintage glowing MOTEL rooftop sign',
      'Cozy timber guest cabin annex',
      'Starlight desert resort suites',
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
    icon: Icons.terrain_rounded,
    accentColor: Color(0xFF79805A),
    upgradeNotes: [
      'Canvas desert tents & campfire',
      'Elevated wooden lookout deck',
      'Tour pavilion & evening lanterns',
      'Grand canyon adventure basecamp',
    ],
  ),
  BusinessType.oasisPlaza: BusinessData(
    type: BusinessType.oasisPlaza,
    stage: 6,
    name: 'Oasis Souvenir Plaza',
    subtitle: 'Stage 6 · Desert pool, palms & craft market',
    purchaseCost: 450,
    baseIncomePerMin: 165,
    upgradeCostBase: 360,
    upgradeMultiplier: 1.82,
    maxLevel: 5,
    icon: Icons.wb_sunny_rounded,
    accentColor: Color(0xFF5DA9B8),
    upgradeNotes: [
      'Shaded pergolas & craft stalls',
      'Turquoise plunge pool & loungers',
      'Evening oasis lanterns & arch',
      'Premier Utah desert oasis',
    ],
  ),
};
