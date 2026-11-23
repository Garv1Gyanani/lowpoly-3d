import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/camera_3d.dart';
import '../engine/lighting.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../theme/desert_palette.dart';
import '../world/environment_builder.dart';

/// Preset layouts so the player can explore the full low-poly desert city right away
/// or play the idle-clicker progression from Stage 1 (Roadside Vendor Stall only).
enum OutpostPreset {
  fullCity,
  stageOneCareer,
}

/// Central simulation and state controller for Desert Outpost.
class GameController extends ChangeNotifier {
  GameController({OutpostPreset initialPreset = OutpostPreset.stageOneCareer}) {
    _initPlots(initialPreset);
    _initMilestones();
    _seedInitialTraffic();
  }

  final math.Random _rng = math.Random(42);
  final Camera3D camera = Camera3D();

  // Economy & progression state
  double cash = 0.0;
  double totalCashEarned = 0.0;
  int totalCustomersServed = 0;
  int totalTaps = 0;
  int tapUpgradeLevel = 1;
  int parkingTier = 0;
  OutpostPreset activePreset = OutpostPreset.stageOneCareer;

  // Time & lighting
  double animTime = 0.0;
  double timeOfDay = 0.37; // Warm Utah afternoon sunlight at start
  bool autoDayNight = true;
  static const double _dayCycleRate = 0.0085; // ~2 min full day/night cycle

  DesertLighting get lighting => DesertLighting.fromTime(timeOfDay);

  // World entities
  late List<PlotState> plots;
  final List<VehicleEntity> vehicles = [];
  final List<VisitorEntity> visitors = [];
  final List<FloatingCash> floatingCash = [];
  final List<Particle3D> particles = [];
  final List<PlacedDecoration> decorations = [];
  late List<MilestoneData> milestones;

  String? selectedPlotId;
  int _nextEntityId = 1;
  double _trafficSpawnCooldown = 0.8;
  double _passivePayoutAccum = 0.0;

  // Available decoration slots around the property perimeter
  static const List<Vec3> _decorationSpots = [
    Vec3(-7.0, 0, 6.2),
    Vec3(0.4, 0, 5.8),
    Vec3(8.4, 0, 5.6),
    Vec3(-11.4, 0, 1.5),
    Vec3(12.0, 0, -2.5),
    Vec3(-3.0, 0, -5.0),
    Vec3(1.8, 0, -5.2),
    Vec3(-11.2, 0, -4.5),
  ];

  void _initPlots(OutpostPreset preset) {
    activePreset = preset;
    final full = preset == OutpostPreset.fullCity;

    plots = [
      // Stage 1: Front-Left-Center Roadside Vendor Stall (always built!)
      PlotState(
        id: 'vendor',
        businessType: BusinessType.vendorStall,
        position: const Vec3(-2.6, 0, 4.9),
        footprintWidth: 3.7,
        footprintDepth: 2.9,
        visitorStopPoint: const Vec3(-2.6, 0, 6.7),
        isBuilt: true,
        level: full ? 3 : 1,
      ),
      // Stage 3A: Front-Right-Center Food & Coffee Stand
      PlotState(
        id: 'food_stand',
        businessType: BusinessType.foodStand,
        position: const Vec3(3.6, 0, 4.9),
        footprintWidth: 3.9,
        footprintDepth: 3.0,
        visitorStopPoint: const Vec3(3.6, 0, 6.7),
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      // Stage 6B: Front-Far-Left Expansion Plot (ready to build!)
      PlotState(
        id: 'oasis_plaza',
        businessType: BusinessType.oasisPlaza,
        position: const Vec3(-7.6, 0, 4.8),
        footprintWidth: 4.1,
        footprintDepth: 3.2,
        visitorStopPoint: const Vec3(-7.6, 0, 6.7),
        isBuilt: false,
        level: 1,
      ),
      // Stage 2: Mid-Left Outpost Convenience Store ("MART")
      PlotState(
        id: 'mart',
        businessType: BusinessType.convenienceStore,
        position: const Vec3(-6.8, 0, -0.7),
        footprintWidth: 5.0,
        footprintDepth: 4.0,
        visitorStopPoint: const Vec3(-6.8, 0, 2.0),
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      // Stage 3B: Centerpiece Route 163 Desert Diner
      PlotState(
        id: 'diner',
        businessType: BusinessType.desertDiner,
        position: const Vec3(0.0, 0, -1.5),
        footprintWidth: 6.1,
        footprintDepth: 4.5,
        visitorStopPoint: const Vec3(0.0, 0, 2.0),
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      // Stage 4: Mid-Right Canyon Gas Station & Repair Garage
      PlotState(
        id: 'gas_station',
        businessType: BusinessType.gasStation,
        position: const Vec3(7.0, 0, -0.7),
        footprintWidth: 5.6,
        footprintDepth: 4.6,
        visitorStopPoint: const Vec3(7.0, 0, 2.1),
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      // Stage 5: Upper-Left Red Rock Motel & Cabins
      PlotState(
        id: 'motel',
        businessType: BusinessType.desertMotel,
        position: const Vec3(-4.8, 0, -7.8),
        footprintWidth: 6.9,
        footprintDepth: 4.4,
        visitorStopPoint: const Vec3(-4.6, 0, -4.9),
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      // Stage 6A: Upper-Right Mesa Lookout Water Tower, Tour Centre & Camp
      PlotState(
        id: 'lookout',
        businessType: BusinessType.lookoutCamp,
        position: const Vec3(4.6, 0, -8.0),
        footprintWidth: 6.4,
        footprintDepth: 4.4,
        visitorStopPoint: const Vec3(4.2, 0, -4.9),
        isBuilt: full,
        level: full ? 2 : 1,
      ),
    ];

    if (full) {
      parkingTier = 3;
      cash = 650.0;
      totalCashEarned = 2850.0;
      totalCustomersServed = 42;
      tapUpgradeLevel = 2;
    } else {
      parkingTier = 0;
      cash = 0.0;
      totalCashEarned = 0.0;
      totalCustomersServed = 0;
      tapUpgradeLevel = 1;
    }
    selectedPlotId = null;
    decorations.clear();
  }

  void _initMilestones() {
    milestones = [
      MilestoneData(
        id: 'm_park1',
        title: 'First Pull-Off',
        description: 'Build the Dirt Pull-Off so travellers can stop',
        rewardCash: 35,
        checkCompleted: () => parkingTier >= 1,
      ),
      MilestoneData(
        id: 'm_3biz',
        title: 'Roadside Strip',
        description: 'Operate at least 3 desert businesses',
        rewardCash: 150,
        checkCompleted: () => builtCount >= 3,
      ),
      MilestoneData(
        id: 'm_oasis',
        title: 'Complete the Outpost',
        description: 'Build all 8 desert city landmarks',
        rewardCash: 1000,
        checkCompleted: () => builtCount == plots.length,
      ),
      MilestoneData(
        id: 'm_500min',
        title: 'Booming Highway Stop',
        description: 'Reach \$500/min passive income',
        rewardCash: 350,
        checkCompleted: () => incomePerMinute >= 500,
      ),
      MilestoneData(
        id: 'm_taps',
        title: 'Friendly Host',
        description: 'Serve 25 active taps at the outpost',
        rewardCash: 120,
        checkCompleted: () => totalTaps >= 25,
      ),
      MilestoneData(
        id: 'm_visitors',
        title: 'Desert Destination',
        description: 'Serve 60 highway visitors',
        rewardCash: 400,
        checkCompleted: () => totalCustomersServed >= 60,
      ),
    ];
  }

  void _seedInitialTraffic() {
    vehicles.clear();
    visitors.clear();

    // Cruising highway vehicles always give life to Route 163
    _spawnVehicle(initialX: -14.0, direction: 1, forcePark: false);
    _spawnVehicle(initialX: 9.0, direction: -1, forcePark: false);
    _spawnVehicle(initialX: -2.0, direction: 1, forcePark: false);

    // Only pre-park vehicles when parking spaces actually exist (e.g., Full City preset)
    if (parkingTier >= 2) {
      for (final slotIdx in [1, 4]) {
        final slot = EnvironmentBuilder.parkingSlots[slotIdx];
        final v = VehicleEntity(
          id: _nextEntityId++,
          kind: slotIdx == 1 ? VehicleKind.pickupTruck : VehicleKind.camperRv,
          bodyColor: _randomVehicleColor(),
          position: Vec3(slot.x, 0, slot.z),
          yaw: -math.pi * 0.5,
          speed: 0,
          direction: 1,
          phase: VehiclePhase.parked,
          parkingSlotIndex: slotIdx,
          parkTimer: 4.5 + slotIdx * 1.4,
          spawnedVisitor: true,
        );
        vehicles.add(v);
        _spawnVisitorFromVehicle(v);
      }
    }
  }

  // --- Computed metrics ---

  int get builtCount => plots.where((p) => p.isBuilt).length;

  /// Progressive plot visibility so raw desert stays clean at Level 1 and
  /// reveals the next expansion plots naturally as parking & buildings grow.
  bool isPlotUnlocked(PlotState plot) {
    if (plot.isBuilt) return true;
    switch (plot.businessType) {
      case BusinessType.vendorStall:
        return true;
      case BusinessType.convenienceStore:
        return parkingTier >= 1;
      case BusinessType.foodStand:
        return parkingTier >= 2 || builtCount >= 2;
      case BusinessType.desertDiner:
        return parkingTier >= 2 && builtCount >= 2;
      case BusinessType.gasStation:
        return builtCount >= 3;
      case BusinessType.desertMotel:
        return builtCount >= 4;
      case BusinessType.lookoutCamp:
        return builtCount >= 5;
      case BusinessType.oasisPlaza:
        return builtCount >= 5 || parkingTier >= 3;
    }
  }

  List<PlotState> get visiblePlots =>
      plots.where(isPlotUnlocked).toList(growable: false);

  bool get canUpgradeParking => parkingTier < kParkingTiers.length - 1;

  ParkingTierData? get nextParkingTier =>
      canUpgradeParking ? kParkingTiers[parkingTier + 1] : null;

  ParkingTierData get currentParkingTierData => kParkingTiers[parkingTier];

  double get incomePerMinute {
    // At Tier 0 (no parking yet), zero customers stop — active tapping only!
    if (parkingTier == 0) return 0.0;
    double sum = 0;
    for (final plot in plots) {
      if (plot.isBuilt) {
        sum += kBusinessCatalog[plot.businessType]!.incomeForLevel(plot.level);
      }
    }
    final lotMultiplier = 1.0 + (parkingTier - 1) * 0.15;
    return (sum * lotMultiplier).roundToDouble();
  }

  double get tapIncome {
    final base = 5.0 + (tapUpgradeLevel - 1) * 5.0;
    final bonus = (builtCount - 1) * 2.0;
    return (base + bonus).roundToDouble();
  }

  double get tapUpgradeCost => (35.0 * math.pow(1.65, tapUpgradeLevel - 1)).roundToDouble();

  int get reputation => (builtCount * 12 + totalCustomersServed + plots.fold<int>(0, (s, p) => s + (p.isBuilt ? p.level * 4 : 0)));

  PlotState? get selectedPlot {
    if (selectedPlotId == null) return null;
    for (final p in plots) {
      if (p.id == selectedPlotId) return p;
    }
    return null;
  }

  // --- Simulation step (called from Flutter Ticker) ---

  void tick(double dt) {
    final clampedDt = dt.clamp(0.0, 0.05);
    animTime += clampedDt;

    if (autoDayNight) {
      timeOfDay = (timeOfDay + clampedDt * _dayCycleRate) % 1.0;
    }

    // Passive income accrual
    final incomePerSec = incomePerMinute / 60.0;
    final earned = incomePerSec * clampedDt;
    cash += earned;
    totalCashEarned += earned;
    _passivePayoutAccum += earned;
    if (_passivePayoutAccum >= 12.0) {
      _passivePayoutAccum = 0.0;
    }

    // Update plot bounce / pop animations
    for (final plot in plots) {
      if (plot.bounceTimer > 0) {
        plot.bounceTimer = math.max(0.0, plot.bounceTimer - clampedDt * 2.4);
      }
      if (plot.buildPopTimer > 0) {
        plot.buildPopTimer = math.max(0.0, plot.buildPopTimer - clampedDt * 2.2);
      }
    }

    // Update traffic & visitors
    _updateVehicles(clampedDt);
    _updateVisitors(clampedDt);

    // Update particles & floating cash
    for (final pt in particles) {
      pt.age += clampedDt;
      pt.position = pt.position + pt.velocity * clampedDt;
      pt.velocity = Vec3(
        pt.velocity.x * 0.96,
        pt.velocity.y - (pt.isCoin ? 6.5 : 0.4) * clampedDt,
        pt.velocity.z * 0.96,
      );
      if (pt.position.y < 0.05) {
        pt.position = Vec3(pt.position.x, 0.05, pt.position.z);
      }
    }
    particles.removeWhere((p) => p.isDone);

    for (final fc in floatingCash) {
      fc.age += clampedDt;
    }
    floatingCash.removeWhere((f) => f.isDone);

    notifyListeners();
  }

  void _updateVehicles(double dt) {
    _trafficSpawnCooldown -= dt;
    final desiredMax = 5 + math.min(5, builtCount);
    if (_trafficSpawnCooldown <= 0 && vehicles.length < desiredMax) {
      final dir = _rng.nextBool() ? 1 : -1;
      final spawnX = dir == 1 ? -28.0 : 28.0;
      final laneZ = dir == 1
          ? EnvironmentBuilder.highwayEastboundZ
          : EnvironmentBuilder.highwayWestboundZ;
      // Only spawn when the entry lane has safe clearance
      final laneClear = !vehicles.any(
        (other) =>
            other.phase == VehiclePhase.highwayCruise &&
            (other.position.z - laneZ).abs() < 0.8 &&
            (other.position.x - spawnX).abs() < 6.0,
      );
      if (laneClear) {
        _spawnVehicle(initialX: spawnX, direction: dir, forcePark: false);
        _trafficSpawnCooldown = (2.6 - builtCount * 0.14).clamp(1.2, 2.8) + _rng.nextDouble() * 1.1;
      }
    }

    final toRemove = <VehicleEntity>[];
    const aisleZ = 10.95;

    for (final v in vehicles) {
      switch (v.phase) {
        case VehiclePhase.highwayCruise:
          // Smooth highway following distance so cars never clip through slower cars ahead
          double activeSpeed = v.speed;
          for (final other in vehicles) {
            if (other.id == v.id) continue;
            if ((other.position.z - v.position.z).abs() > 1.1) continue;
            final ahead = (other.position.x - v.position.x) * v.direction;
            if (ahead > 0.2 && ahead < 4.6) {
              activeSpeed = math.min(activeSpeed, other.phase == VehiclePhase.highwayCruise ? other.speed * 0.75 : 1.0);
              if (ahead < 3.1) activeSpeed = 0.0;
            }
          }

          v.position = Vec3(
            v.position.x + v.direction * activeSpeed * dt,
            0,
            v.position.z,
          );
          final targetYaw = v.direction == 1 ? 0.0 : math.pi;
          v.yaw = _lerpAngle(v.yaw, targetYaw, (dt * 7.0).clamp(0.0, 1.0));

          // Only pull in once parking spaces exist!
          if (parkingTier > 0 && v.parkingSlotIndex == -1) {
            final entryHalfSpan = parkingTier == 1 ? 2.5 : (parkingTier == 2 ? 5.2 : 8.2);
            final nearWestEntry = v.direction == 1 &&
                v.position.x > -entryHalfSpan - 1.2 &&
                v.position.x < -entryHalfSpan + 1.2;
            final nearEastEntry = v.direction == -1 &&
                v.position.x < entryHalfSpan + 1.2 &&
                v.position.x > entryHalfSpan - 1.2;
            final pullChance = parkingTier == 1 ? 0.14 : 0.085;
            if ((nearWestEntry || nearEastEntry) && _rng.nextDouble() < pullChance) {
              final freeSlot = _findFreeParkingSlot();
              if (freeSlot != -1) {
                v.parkingSlotIndex = freeSlot;
                final slot = EnvironmentBuilder.parkingSlots[freeSlot];
                final entryX = nearWestEntry ? -entryHalfSpan : entryHalfSpan;
                v.waypoints
                  ..clear()
                  ..add(Vec3(entryX, 0, aisleZ))
                  ..add(Vec3(slot.x, 0, aisleZ))
                  ..add(slot);
                v.phase = VehiclePhase.pullingIn;
              }
            }
          }

          if (v.position.x.abs() > 31.0) {
            toRemove.add(v);
          }

        case VehiclePhase.pullingIn:
          if (v.waypoints.isEmpty) {
            v.yaw = _lerpAngle(v.yaw, -math.pi * 0.5, (dt * 9.0).clamp(0.0, 1.0));
            v.phase = VehiclePhase.parked;
            v.parkTimer = 6.5 + _rng.nextDouble() * 3.5;
            v.spawnedVisitor = false;
            break;
          }
          final wp = v.waypoints.first;
          final toWp = wp - v.position;
          final dist = toWp.length;
          if (dist < 0.22) {
            v.position = wp;
            v.waypoints.removeAt(0);
            if (v.waypoints.isEmpty) {
              v.yaw = -math.pi * 0.5; // parked nose north (-Z)
              v.phase = VehiclePhase.parked;
              v.parkTimer = 6.5 + _rng.nextDouble() * 3.5;
              v.spawnedVisitor = false;
            }
          } else {
            final step = math.min(dist, 3.8 * dt);
            final dir = toWp / dist;
            v.position = v.position + dir * step;
            // rotateY(yaw) maps +X to (cos(yaw), 0, +sin(yaw)) -> atan2(dir.z, dir.x)!
            final desiredYaw = math.atan2(dir.z, dir.x);
            v.yaw = _lerpAngle(v.yaw, desiredYaw, (dt * 8.5).clamp(0.0, 1.0));
          }

        case VehiclePhase.parked:
          if (!v.spawnedVisitor) {
            v.spawnedVisitor = true;
            _spawnVisitorFromVehicle(v);
          }
          v.parkTimer -= dt;
          final hasActiveVisitor = visitors.any((vis) => vis.vehicleId == v.id);
          if (v.parkTimer <= 0 && !hasActiveVisitor) {
            // Step 1: back straight out of the parking stall into the aisle
            v.waypoints
              ..clear()
              ..add(Vec3(v.position.x, 0, aisleZ));
            v.phase = VehiclePhase.backingOut;
          }

        case VehiclePhase.backingOut:
          if (v.waypoints.isEmpty) {
            _beginPullOutToHighway(v, aisleZ);
            break;
          }
          final backTarget = v.waypoints.first;
          final toBack = backTarget - v.position;
          final dist = toBack.length;
          if (dist < 0.18) {
            v.position = backTarget;
            v.waypoints.clear();
            _beginPullOutToHighway(v, aisleZ);
          } else {
            // Reverse gently southward while keeping nose pointed north (turning slightly as backing out)
            final step = math.min(dist, 2.2 * dt);
            v.position = v.position + (toBack / dist) * step;
            final subtleTailSwing = v.direction == 1 ? -math.pi * 0.42 : -math.pi * 0.58;
            v.yaw = _lerpAngle(v.yaw, subtleTailSwing, (dt * 2.5).clamp(0.0, 1.0));
          }

        case VehiclePhase.pullingOut:
          if (v.waypoints.isEmpty) {
            v.parkingSlotIndex = -1;
            v.phase = VehiclePhase.highwayCruise;
            break;
          }
          final wp = v.waypoints.first;
          final toWp = wp - v.position;
          final dist = toWp.length;
          if (dist < 0.25) {
            v.position = wp;
            v.waypoints.removeAt(0);
            if (v.waypoints.isEmpty) {
              v.parkingSlotIndex = -1;
              v.phase = VehiclePhase.highwayCruise;
            }
          } else {
            final step = math.min(dist, 4.1 * dt);
            final dir = toWp / dist;
            v.position = v.position + dir * step;
            final desiredYaw = math.atan2(dir.z, dir.x);
            v.yaw = _lerpAngle(v.yaw, desiredYaw, (dt * 8.0).clamp(0.0, 1.0));
          }
      }
    }

    vehicles.removeWhere(toRemove.contains);
  }

  void _beginPullOutToHighway(VehicleEntity v, double aisleZ) {
    final exitHalfSpan = parkingTier <= 1 ? 2.4 : (parkingTier == 2 ? 5.0 : 8.0);
    final exitX = v.direction == 1 ? exitHalfSpan : -exitHalfSpan;
    final exitZ = v.direction == 1
        ? EnvironmentBuilder.highwayEastboundZ
        : EnvironmentBuilder.highwayWestboundZ;
    v.waypoints
      ..clear()
      ..add(Vec3(exitX, 0, aisleZ))
      ..add(Vec3(exitX + v.direction * 1.6, 0, exitZ));
    v.phase = VehiclePhase.pullingOut;
  }

  void _updateVisitors(double dt) {
    final toRemove = <VisitorEntity>[];

    for (final vis in visitors) {
      vis.walkCycle += dt;
      switch (vis.phase) {
        case VisitorPhase.walkingToBusiness:
          if (vis.outboundPath.isEmpty) {
            vis.phase = VisitorPhase.shopping;
            vis.waitTimer = 1.6 + _rng.nextDouble() * 1.4;
            break;
          }
          final wp = vis.outboundPath.first;
          final diff = wp - vis.position;
          final dist = diff.length;
          if (dist < 0.20) {
            vis.position = wp;
            vis.outboundPath.removeAt(0);
            if (vis.outboundPath.isEmpty) {
              vis.phase = VisitorPhase.shopping;
              vis.yaw = -math.pi * 0.5; // face toward the shop storefront (-Z)
              vis.waitTimer = 1.6 + _rng.nextDouble() * 1.4;
            }
          } else {
            final dir = diff / dist;
            vis.position = vis.position + dir * (2.0 * dt);
            final desiredYaw = math.atan2(dir.z, dir.x);
            vis.yaw = _lerpAngle(vis.yaw, desiredYaw, (dt * 10.0).clamp(0.0, 1.0));
          }

        case VisitorPhase.shopping:
          vis.waitTimer -= dt;
          if (vis.waitTimer <= 0) {
            final plot = plots.firstWhere(
              (p) => p.id == vis.targetPlotId,
              orElse: () => plots.first,
            );
            final biz = kBusinessCatalog[plot.businessType]!;
            final sale = math.max(3.0, (biz.incomeForLevel(plot.level) / 14.0).roundToDouble());
            cash += sale;
            totalCashEarned += sale;
            totalCustomersServed += 1;
            plot.bounceTimer = 0.22;
            floatingCash.add(
              FloatingCash(
                position: plot.position + const Vec3(0, 2.4, 0),
                text: '+\$${sale.toInt()}',
                color: const Color(0xFFFFE57F),
              ),
            );
            vis.phase = VisitorPhase.returningToCar;
          }

        case VisitorPhase.returningToCar:
          if (vis.returnPath.isEmpty) {
            toRemove.add(vis);
            break;
          }
          final wp = vis.returnPath.first;
          final diff = wp - vis.position;
          final dist = diff.length;
          if (dist < 0.22) {
            vis.position = wp;
            vis.returnPath.removeAt(0);
            if (vis.returnPath.isEmpty) {
              toRemove.add(vis);
            }
          } else {
            final dir = diff / dist;
            vis.position = vis.position + dir * (2.0 * dt);
            final desiredYaw = math.atan2(dir.z, dir.x);
            vis.yaw = _lerpAngle(vis.yaw, desiredYaw, (dt * 10.0).clamp(0.0, 1.0));
          }
      }
    }

    visitors.removeWhere(toRemove.contains);
  }

  /// Shortest-arc angular interpolation for silky smooth vehicle & visitor turns.
  double _lerpAngle(double current, double target, double t) {
    double diff = (target - current) % (math.pi * 2.0);
    if (diff > math.pi) diff -= math.pi * 2.0;
    if (diff < -math.pi) diff += math.pi * 2.0;
    return current + diff * t;
  }

  int _findFreeParkingSlot() {
    final allowed = EnvironmentBuilder.activeParkingSlotIndices(parkingTier);
    if (allowed.isEmpty) return -1;
    final used = vehicles
        .where((v) => v.parkingSlotIndex >= 0)
        .map((v) => v.parkingSlotIndex)
        .toSet();
    final free = <int>[];
    for (final idx in allowed) {
      if (!used.contains(idx)) free.add(idx);
    }
    if (free.isEmpty) return -1;
    return free[_rng.nextInt(free.length)];
  }

  void _spawnVehicle({
    required double initialX,
    required int direction,
    required bool forcePark,
  }) {
    final laneZ = direction == 1
        ? EnvironmentBuilder.highwayEastboundZ
        : EnvironmentBuilder.highwayWestboundZ;
    final kinds = VehicleKind.values;
    final kind = kinds[_rng.nextInt(kinds.length)];
    final speed = 4.6 + _rng.nextDouble() * 2.4;

    vehicles.add(
      VehicleEntity(
        id: _nextEntityId++,
        kind: kind,
        bodyColor: _randomVehicleColor(),
        position: Vec3(initialX, 0, laneZ),
        yaw: direction == 1 ? 0.0 : math.pi,
        speed: speed,
        direction: direction,
        phase: forcePark ? VehiclePhase.pullingIn : VehiclePhase.highwayCruise,
      ),
    );
  }

  void _spawnVisitorFromVehicle(VehicleEntity v) {
    final openPlots = plots.where((p) => p.isBuilt).toList();
    if (openPlots.isEmpty) return;
    final targetPlot = openPlots[_rng.nextInt(openPlots.length)];

    const shirts = [
      DesertPalette.awningRed,
      DesertPalette.turquoise,
      DesertPalette.gold,
      DesertPalette.terracotta,
      DesertPalette.cream,
      Color(0xFF5D7EA8),
    ];
    const hats = [
      DesertPalette.sand,
      DesertPalette.woodLight,
      DesertPalette.cream,
      DesertPalette.sandstone,
    ];

    final start = v.position + const Vec3(0.45, 0, -1.1);
    final dest = targetPlot.visitorStopPoint;
    final outbound = _buildSidewalkPath(start, dest);
    final inbound = [...outbound.reversed.skip(1), start];

    visitors.add(
      VisitorEntity(
        id: _nextEntityId++,
        shirtColor: shirts[_rng.nextInt(shirts.length)],
        hatColor: hats[_rng.nextInt(hats.length)],
        position: start,
        origin: start,
        destination: dest,
        targetPlotId: targetPlot.id,
        vehicleId: v.id,
        phase: VisitorPhase.walkingToBusiness,
        yaw: -math.pi * 0.5,
        outboundPath: outbound,
        returnPath: inbound,
      ),
    );
  }

  /// Routes visitors cleanly along paved pedestrian sidewalks so they NEVER cut through buildings.
  List<Vec3> _buildSidewalkPath(Vec3 start, Vec3 dest) {
    const promenadeZ = 6.9;
    const spineX = 0.25;
    final path = <Vec3>[Vec3(start.x, 0, promenadeZ)];

    if (dest.z > 5.5) {
      // Front-row stall (Vendor, Food Stand, Oasis): walk right along the promenade
      path.add(Vec3(dest.x, 0, promenadeZ));
      path.add(dest);
    } else if (dest.z > 0.0) {
      // Mid-row business (Mart, Diner, Gas Station): promenade -> central spine -> cross street
      const crossZ = 2.2;
      path.add(const Vec3(spineX, 0, promenadeZ));
      path.add(const Vec3(spineX, 0, crossZ));
      path.add(Vec3(dest.x, 0, crossZ));
      path.add(dest);
    } else {
      // Upper-row destination (Motel, Lookout Camp): promenade -> central spine -> upper terrace
      const upperZ = -5.0;
      path.add(const Vec3(spineX, 0, promenadeZ));
      path.add(const Vec3(spineX, 0, upperZ));
      path.add(Vec3(dest.x, 0, upperZ));
      path.add(dest);
    }
    return path;
  }

  Color _randomVehicleColor() {
    const palette = [
      Color(0xFFC85B43), // desert red
      Color(0xFF4F9A94), // turquoise
      Color(0xFFE0B45A), // ochre yellow
      Color(0xFFDFD5C3), // desert cream
      Color(0xFF5A778E), // slate blue
      Color(0xFF7B855E), // sage olive
      Color(0xFFB56E4B), // burnt sienna
    ];
    return palette[_rng.nextInt(palette.length)];
  }

  // --- Player Interactions ---

  /// Active tap on the vendor stall (or main Tap button).
  void performActiveTap({PlotState? target}) {
    final plot = target ?? plots.first;
    final gain = tapIncome;
    cash += gain;
    totalCashEarned += gain;
    totalTaps += 1;
    plot.bounceTimer = 0.35;

    final spawnOrigin = plot.position + const Vec3(0, 2.2, 0.3);
    floatingCash.add(
      FloatingCash(
        position: spawnOrigin + Vec3((_rng.nextDouble() - 0.5) * 0.7, 0.2, 0),
        text: '+\$${gain.toInt()}',
        color: const Color(0xFF7BFF9B),
      ),
    );

    // Coin burst particles
    for (int i = 0; i < 6; i++) {
      final a = _rng.nextDouble() * math.pi * 2.0;
      final spd = 1.4 + _rng.nextDouble() * 1.8;
      particles.add(
        Particle3D(
          position: spawnOrigin,
          velocity: Vec3(math.cos(a) * spd, 2.8 + _rng.nextDouble() * 1.5, math.sin(a) * spd),
          color: DesertPalette.gold,
          size: 3.6,
          duration: 0.65,
          isCoin: true,
        ),
      );
    }
    notifyListeners();
  }

  /// Handles tapping directly on the 3D desert diorama canvas.
  /// Returns the tapped plot if any was hit.
  PlotState? handleWorldTap(Offset screenPos, Size viewport) {
    final groundPoint = camera.screenToGround(screenPos, viewport, planeY: 0.0);
    // Also check slightly elevated plane so tapping tall building roofs hits cleanly
    final midPoint = camera.screenToGround(screenPos, viewport, planeY: 1.4);

    PlotState? best;
    double bestDist = double.infinity;

    for (final plot in visiblePlots) {
      final hitGround = plot.containsGroundPoint(groundPoint, margin: 0.9);
      final hitMid = plot.containsGroundPoint(midPoint, margin: 0.9);
      if (hitGround || hitMid) {
        final d = (plot.position - groundPoint).length;
        if (d < bestDist) {
          bestDist = d;
          best = plot;
        }
      }
    }

    if (best != null) {
      if (best.isBuilt) {
        // Pure game interaction: tapping a built building immediately taps for cash (no app popup!)
        performActiveTap(target: best);
      } else {
        // Tapping an open construction plot builds it directly if affordable!
        buildOnPlot(best);
      }
      return best;
    }

    selectedPlotId = null;
    notifyListeners();
    return null;
  }

  void selectPlot(String? plotId) {
    selectedPlotId = plotId;
    notifyListeners();
  }

  /// Upgrades the roadside parking lot & outpost infrastructure (Tier 0 -> Tier 3).
  bool upgradeParking() {
    final next = nextParkingTier;
    if (next == null || cash < next.cost) return false;

    cash -= next.cost;
    parkingTier = next.tier;
    _spawnConstructionDust(const Vec3(-2.5, 0, 9.4), count: 8);
    _spawnConstructionDust(const Vec3(2.5, 0, 9.4), count: 8);
    floatingCash.add(
      FloatingCash(
        position: const Vec3(0, 2.2, 9.2),
        text: '${next.name.toUpperCase()}!',
        color: DesertPalette.gold,
        duration: 1.5,
      ),
    );

    // Reward the player immediately with their first arriving customer car on Tier 1!
    if (parkingTier == 1) {
      final freeSlot = _findFreeParkingSlot();
      if (freeSlot != -1) {
        final slot = EnvironmentBuilder.parkingSlots[freeSlot];
        final v = VehicleEntity(
          id: _nextEntityId++,
          kind: VehicleKind.pickupTruck,
          bodyColor: _randomVehicleColor(),
          position: const Vec3(-9.5, 0, EnvironmentBuilder.highwayEastboundZ),
          yaw: 0.0,
          speed: 5.0,
          direction: 1,
          phase: VehiclePhase.pullingIn,
          parkingSlotIndex: freeSlot,
          waypoints: [
            const Vec3(-2.4, 0, 10.95),
            Vec3(slot.x, 0, 10.95),
            slot,
          ],
        );
        vehicles.add(v);
      }
    }

    notifyListeners();
    return true;
  }

  /// Builds a business on an empty construction plot.
  bool buildOnPlot(PlotState plot) {
    if (plot.isBuilt) return false;
    final data = kBusinessCatalog[plot.businessType]!;
    if (cash < data.purchaseCost) return false;

    cash -= data.purchaseCost;
    plot.isBuilt = true;
    plot.level = 1;
    plot.buildPopTimer = 1.0;
    plot.bounceTimer = 0.4;
    _spawnConstructionDust(plot.position, count: 14);
    floatingCash.add(
      FloatingCash(
        position: plot.position + const Vec3(0, 2.8, 0),
        text: 'BUILT!',
        color: DesertPalette.gold,
        duration: 1.4,
      ),
    );
    notifyListeners();
    return true;
  }

  /// Upgrades a built business, visually enhancing the 3D building at milestone levels.
  bool upgradePlot(PlotState plot) {
    if (!plot.isBuilt) return false;
    final data = kBusinessCatalog[plot.businessType]!;
    if (plot.level >= data.maxLevel) return false;
    final cost = data.upgradeCostForLevel(plot.level);
    if (cash < cost) return false;

    cash -= cost;
    plot.level += 1;
    plot.bounceTimer = 0.45;
    _spawnConstructionDust(plot.position, count: 10);
    floatingCash.add(
      FloatingCash(
        position: plot.position + const Vec3(0, 3.0, 0),
        text: 'LV ${plot.level}!',
        color: DesertPalette.neonTurquoise,
        duration: 1.35,
      ),
    );
    notifyListeners();
    return true;
  }

  bool upgradeTapPower() {
    final cost = tapUpgradeCost;
    if (cash < cost) return false;
    cash -= cost;
    tapUpgradeLevel += 1;
    performActiveTap(target: plots.first);
    return true;
  }

  /// Places a desert decoration at the next open decorative spot.
  bool placeDecoration(DecorationKind kind, String name, double cost) {
    if (cash < cost || decorations.length >= _decorationSpots.length) return false;
    cash -= cost;
    final spot = _decorationSpots[decorations.length];
    decorations.add(
      PlacedDecoration(
        id: 'deco_${_nextEntityId++}',
        kind: kind,
        position: spot,
        name: name,
        cost: cost,
      ),
    );
    _spawnConstructionDust(spot, count: 8);
    notifyListeners();
    return true;
  }

  bool get canAddMoreDecorations => decorations.length < _decorationSpots.length;

  bool claimMilestone(MilestoneData milestone) {
    if (milestone.claimed || !milestone.checkCompleted()) return false;
    milestone.claimed = true;
    cash += milestone.rewardCash;
    totalCashEarned += milestone.rewardCash;
    floatingCash.add(
      FloatingCash(
        position: const Vec3(0, 3.5, 0),
        text: '+\$${milestone.rewardCash.toInt()} BONUS',
        color: DesertPalette.gold,
        duration: 1.6,
      ),
    );
    notifyListeners();
    return true;
  }

  int get claimableMilestoneCount =>
      milestones.where((m) => !m.claimed && m.checkCompleted()).length;

  void _spawnConstructionDust(Vec3 center, {int count = 12}) {
    for (int i = 0; i < count; i++) {
      final a = (i / count) * math.pi * 2.0 + _rng.nextDouble() * 0.4;
      final spd = 1.6 + _rng.nextDouble() * 2.0;
      particles.add(
        Particle3D(
          position: center + Vec3(math.cos(a) * 0.6, 0.3, math.sin(a) * 0.6),
          velocity: Vec3(math.cos(a) * spd, 1.4 + _rng.nextDouble() * 1.4, math.sin(a) * spd),
          color: DesertPalette.sandLight,
          size: 7.5 + _rng.nextDouble() * 4.0,
          duration: 0.85,
          isCoin: false,
        ),
      );
    }
  }

  // --- Time of day & preset controls ---

  void setTimePreset(double normalizedTime, {bool pauseCycle = true}) {
    timeOfDay = normalizedTime % 1.0;
    autoDayNight = !pauseCycle;
    notifyListeners();
  }

  void toggleAutoDayNight() {
    autoDayNight = !autoDayNight;
    notifyListeners();
  }

  void switchPreset(OutpostPreset preset) {
    _initPlots(preset);
    _initMilestones();
    _seedInitialTraffic();
    camera.reset();
    notifyListeners();
  }

  /// Grants simulated offline earnings so the player can test Section 4.3 easily.
  double simulateOfflineEarnings({int minutesAway = 15}) {
    final earned = (incomePerMinute * minutesAway).roundToDouble();
    cash += earned;
    totalCashEarned += earned;
    floatingCash.add(
      FloatingCash(
        position: const Vec3(0, 3.2, 1.0),
        text: '+\$${earned.toInt()} OFFLINE',
        color: const Color(0xFF7BFF9B),
        duration: 1.6,
      ),
    );
    notifyListeners();
    return earned;
  }

  // --- Camera Controls ---

  void panCamera(Offset delta, Size viewport) {
    camera.panByScreenDelta(delta, viewport);
    notifyListeners();
  }

  void zoomCamera(double scaleDelta) {
    camera.zoomByFactor(scaleDelta);
    notifyListeners();
  }

  void resetCamera() {
    camera.reset();
    notifyListeners();
  }
}
