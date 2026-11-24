import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/camera_3d.dart';
import '../engine/lighting.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../theme/desert_palette.dart';
import '../world/outpost_layout.dart';
import 'outpost_storage.dart';

enum OutpostPreset {
  fullCity,
  stageOneCareer,
}

/// Central simulation and state controller for Desert Outpost.
///
/// Performance architecture:
/// - [renderListenable] ticks at 60–120 Hz solely to repaint the 3D `CustomPaint` canvas
///   and smoothly bob in-world bubbles.
/// - `GameController` itself (`ChangeNotifier`) notifies HUD widgets ONLY when discrete
///   economy/UI values (`cash.floor()`, `parkingTier`, `builtCount`, upgrades, milestones)
///   actually change—eliminating 60 Hz widget-tree rebuild churn!
class GameController extends ChangeNotifier {
  GameController({
    OutpostPreset initialPreset = OutpostPreset.stageOneCareer,
    this.enablePersistence = false,
  }) {
    _initPlots(initialPreset);
    _initMilestones();
    if (enablePersistence) {
      _loadSavedState();
    }
    camera.reset(parkingTier: parkingTier, builtCount: builtCount);
    _seedInitialTraffic();
    _lastHudCashFloor = cash.floor();
  }

  final bool enablePersistence;
  final math.Random _rng = math.Random(42);
  final Camera3D camera = Camera3D();

  /// High-frequency repaint signal exclusively for 3D canvas & projected world bubbles.
  final ChangeNotifier renderListenable = ChangeNotifier();

  // Economy & progression state
  double cash = 0.0;
  double totalCashEarned = 0.0;
  int totalCustomersServed = 0;
  int totalTaps = 0;
  int tapUpgradeLevel = 1;
  int parkingTier = 0;
  OutpostPreset activePreset = OutpostPreset.stageOneCareer;
  bool soundEnabled = true;

  /// Offline welcome-back reward banner (`> 0` when returning after time away).
  double pendingOfflineWelcomeCash = 0.0;
  int pendingOfflineMinutes = 0;

  // Time & lighting
  double animTime = 0.0;
  double timeOfDay = 0.37;
  bool autoDayNight = true;
  static const double _dayCycleRate = 0.0085;

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
  double _autosaveAccum = 0.0;
  int _lastHudCashFloor = 0;
  int _lastClaimableCount = 0;

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

  @override
  void dispose() {
    if (enablePersistence) {
      saveState();
    }
    renderListenable.dispose();
    super.dispose();
  }

  void _notifyRender() {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    renderListenable.notifyListeners();
  }

  void _notifyBoth() {
    _lastHudCashFloor = cash.floor();
    _lastClaimableCount = claimableMilestoneCount;
    notifyListeners();
    _notifyRender();
  }

  void _playTapFeedback({bool heavy = false}) {
    if (!soundEnabled) return;
    if (heavy) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    SystemSound.play(SystemSoundType.click);
  }

  void toggleSound() {
    soundEnabled = !soundEnabled;
    _playTapFeedback();
    saveState();
    notifyListeners();
  }

  void dismissOfflineWelcome() {
    if (pendingOfflineWelcomeCash <= 0) return;
    pendingOfflineWelcomeCash = 0.0;
    pendingOfflineMinutes = 0;
    notifyListeners();
  }

  void _initPlots(OutpostPreset preset) {
    activePreset = preset;
    final full = preset == OutpostPreset.fullCity;

    // Subtle organic inward angles on outer landmarks break up the rigid 0° grid!
    plots = [
      PlotState(
        id: 'vendor',
        businessType: BusinessType.vendorStall,
        position: const Vec3(-2.4, 0, 4.9),
        footprintWidth: 3.7,
        footprintDepth: 2.9,
        visitorStopPoint: const Vec3(-2.4, 0, 6.7),
        yaw: 0.03,
        isBuilt: true,
        level: full ? 4 : 1,
      ),
      PlotState(
        id: 'food_stand',
        businessType: BusinessType.foodStand,
        position: const Vec3(3.6, 0, 4.9),
        footprintWidth: 3.9,
        footprintDepth: 3.0,
        visitorStopPoint: const Vec3(3.6, 0, 6.7),
        yaw: -0.06,
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      PlotState(
        id: 'oasis_plaza',
        businessType: BusinessType.oasisPlaza,
        position: const Vec3(-7.7, 0, 4.8),
        footprintWidth: 4.1,
        footprintDepth: 3.2,
        visitorStopPoint: const Vec3(-7.5, 0, 6.7),
        yaw: 0.13,
        isBuilt: false,
        level: 1,
      ),
      PlotState(
        id: 'mart',
        businessType: BusinessType.convenienceStore,
        position: const Vec3(-6.8, 0, -0.7),
        footprintWidth: 5.0,
        footprintDepth: 4.0,
        visitorStopPoint: const Vec3(-6.7, 0, 2.0),
        yaw: 0.08,
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      PlotState(
        id: 'diner',
        businessType: BusinessType.desertDiner,
        position: const Vec3(0.0, 0, -1.5),
        footprintWidth: 6.1,
        footprintDepth: 4.5,
        visitorStopPoint: const Vec3(0.0, 0, 2.0),
        yaw: 0.0,
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      PlotState(
        id: 'gas_station',
        businessType: BusinessType.gasStation,
        position: const Vec3(7.0, 0, -0.7),
        footprintWidth: 5.6,
        footprintDepth: 4.6,
        visitorStopPoint: const Vec3(6.9, 0, 2.1),
        yaw: -0.09,
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      PlotState(
        id: 'motel',
        businessType: BusinessType.desertMotel,
        position: const Vec3(-4.8, 0, -7.8),
        footprintWidth: 6.9,
        footprintDepth: 4.4,
        visitorStopPoint: const Vec3(-4.6, 0, -4.9),
        yaw: 0.08,
        isBuilt: full,
        level: full ? 3 : 1,
      ),
      PlotState(
        id: 'lookout',
        businessType: BusinessType.lookoutCamp,
        position: const Vec3(4.6, 0, -8.0),
        footprintWidth: 6.4,
        footprintDepth: 4.4,
        visitorStopPoint: const Vec3(4.2, 0, -4.9),
        yaw: -0.09,
        isBuilt: full,
        level: full ? 3 : 1,
      ),
    ];

    if (full) {
      parkingTier = 3;
      cash = 1450.0;
      totalCashEarned = 3650.0;
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

    _spawnVehicle(initialX: -14.0, direction: 1, forcePark: false);
    _spawnVehicle(initialX: 9.0, direction: -1, forcePark: false);
    _spawnVehicle(initialX: -2.0, direction: 1, forcePark: false);

    if (parkingTier >= 2) {
      for (final slotIdx in [1, 4]) {
        final slot = OutpostLayout.parkingSlots[slotIdx];
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
        _spawnVisitorsFromVehicle(v);
      }
    }
  }

  // --- Computed metrics ---

  int get builtCount => plots.where((p) => p.isBuilt).length;

  /// Hash signature of built static buildings & their levels for instant `CustomPainter` cache invalidation.
  int get staticBuildingsSignature {
    int h = 17;
    for (final p in plots) {
      h = h * 31 + (p.isBuilt ? p.level : 0);
      h = h * 31 + (p.bounceTimer > 0 || p.buildPopTimer > 0 ? 1 : 0);
    }
    return h ^ (selectedPlotId?.hashCode ?? 0);
  }

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
      case BusinessType.oasisPlaza:
        return builtCount >= 4 && parkingTier >= 2;
      case BusinessType.desertMotel:
        return builtCount >= 5;
      case BusinessType.lookoutCamp:
        return builtCount >= 6;
    }
  }

  List<PlotState> get visiblePlots =>
      plots.where(isPlotUnlocked).toList(growable: false);

  bool get canUpgradeParking => parkingTier < kParkingTiers.length - 1;

  ParkingTierData? get nextParkingTier =>
      canUpgradeParking ? kParkingTiers[parkingTier + 1] : null;

  ParkingTierData get currentParkingTierData => kParkingTiers[parkingTier];

  /// Systemic scenic tip bonus from placed desert decorations (+4% per prop!).
  double get decorationBonusMultiplier => 1.0 + decorations.length * 0.04;

  double get incomePerMinute {
    if (parkingTier == 0) return 0.0;
    double sum = 0;
    for (final plot in plots) {
      if (plot.isBuilt) {
        sum += kBusinessCatalog[plot.businessType]!.incomeForLevel(plot.level);
      }
    }
    final lotMultiplier = 1.0 + (parkingTier - 1) * 0.15;
    return (sum * lotMultiplier * decorationBonusMultiplier).roundToDouble();
  }

  double get tapIncome {
    final base = 5.0 + (tapUpgradeLevel - 1) * 5.0;
    final bonus = (builtCount - 1) * 2.0;
    return ((base + bonus) * decorationBonusMultiplier).roundToDouble();
  }

  double get tapUpgradeCost => (35.0 * math.pow(1.65, tapUpgradeLevel - 1)).roundToDouble();

  int get reputation =>
      builtCount * 12 +
      totalCustomersServed +
      decorations.length * 6 +
      plots.fold<int>(0, (s, p) => s + (p.isBuilt ? p.level * 4 : 0));

  MilestoneData? get nextActiveMilestone {
    for (final m in milestones) {
      if (!m.claimed && m.checkCompleted()) return m;
    }
    for (final m in milestones) {
      if (!m.claimed) return m;
    }
    return null;
  }

  PlotState? get selectedPlot {
    if (selectedPlotId == null) return null;
    for (final p in plots) {
      if (p.id == selectedPlotId) return p;
    }
    return null;
  }

  // --- Persistence (Local Save / Load + Real Offline Earnings) ---

  void saveState() {
    if (!enablePersistence) return;
    final map = <String, Object?>{
      'preset': activePreset.name,
      'cash': cash,
      'totalCashEarned': totalCashEarned,
      'totalCustomersServed': totalCustomersServed,
      'totalTaps': totalTaps,
      'tapUpgradeLevel': tapUpgradeLevel,
      'parkingTier': parkingTier,
      'timeOfDay': timeOfDay,
      'autoDayNight': autoDayNight,
      'soundEnabled': soundEnabled,
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
      'plots': [
        for (final p in plots)
          {'id': p.id, 'isBuilt': p.isBuilt, 'level': p.level},
      ],
      'decorations': [
        for (final d in decorations)
          {'kind': d.kind.name, 'name': d.name, 'cost': d.cost},
      ],
      'claimedMilestones': [
        for (final m in milestones)
          if (m.claimed) m.id,
      ],
    };
    OutpostStorage.writeSave(jsonEncode(map));
  }

  void _loadSavedState() {
    final raw = OutpostStorage.readSave();
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final presetName = map['preset'] as String?;
      if (presetName == OutpostPreset.fullCity.name) {
        activePreset = OutpostPreset.fullCity;
      } else {
        activePreset = OutpostPreset.stageOneCareer;
      }

      cash = (map['cash'] as num?)?.toDouble() ?? cash;
      totalCashEarned = (map['totalCashEarned'] as num?)?.toDouble() ?? totalCashEarned;
      totalCustomersServed = (map['totalCustomersServed'] as num?)?.toInt() ?? 0;
      totalTaps = (map['totalTaps'] as num?)?.toInt() ?? 0;
      tapUpgradeLevel = (map['tapUpgradeLevel'] as num?)?.toInt() ?? 1;
      parkingTier = ((map['parkingTier'] as num?)?.toInt() ?? 0).clamp(0, kParkingTiers.length - 1);
      timeOfDay = (map['timeOfDay'] as num?)?.toDouble() ?? 0.37;
      autoDayNight = (map['autoDayNight'] as bool?) ?? true;
      soundEnabled = (map['soundEnabled'] as bool?) ?? true;

      final savedPlots = map['plots'] as List<dynamic>?;
      if (savedPlots != null) {
        for (final entry in savedPlots) {
          if (entry is Map<String, dynamic>) {
            final id = entry['id'] as String?;
            for (final p in plots) {
              if (p.id == id) {
                p.isBuilt = (entry['isBuilt'] as bool?) ?? p.isBuilt;
                p.level = ((entry['level'] as num?)?.toInt() ?? p.level).clamp(1, 5);
              }
            }
          }
        }
      }

      decorations.clear();
      final savedDecos = map['decorations'] as List<dynamic>?;
      if (savedDecos != null) {
        for (final entry in savedDecos) {
          if (entry is Map<String, dynamic> && decorations.length < _decorationSpots.length) {
            final kindStr = entry['kind'] as String?;
            final kind = DecorationKind.values.firstWhere(
              (k) => k.name == kindStr,
              orElse: () => DecorationKind.saguaroCluster,
            );
            decorations.add(
              PlacedDecoration(
                id: 'deco_${_nextEntityId++}',
                kind: kind,
                position: _decorationSpots[decorations.length],
                name: (entry['name'] as String?) ?? 'Prop',
                cost: (entry['cost'] as num?)?.toDouble() ?? 35.0,
              ),
            );
          }
        }
      }

      final claimedIds = (map['claimedMilestones'] as List<dynamic>?)
              ?.whereType<String>()
              .toSet() ??
          const <String>{};
      for (final m in milestones) {
        m.claimed = claimedIds.contains(m.id);
      }

      final savedAtMs = (map['savedAtMs'] as num?)?.toInt();
      if (savedAtMs != null && incomePerMinute > 0) {
        final elapsedMin = ((DateTime.now().millisecondsSinceEpoch - savedAtMs) / 60000.0)
            .floor()
            .clamp(0, 480); // Cap offline accrual at 8 hours
        if (elapsedMin >= 2) {
          final offlineEarned = (incomePerMinute * elapsedMin * 0.65).roundToDouble();
          if (offlineEarned >= 5) {
            cash += offlineEarned;
            totalCashEarned += offlineEarned;
            pendingOfflineWelcomeCash = offlineEarned;
            pendingOfflineMinutes = elapsedMin;
          }
        }
      }
    } catch (_) {
      // Ignore corrupt save data cleanly.
    }
  }

  // --- Simulation step (called from Flutter Ticker) ---

  void tick(double dt) {
    final clampedDt = dt.clamp(0.0, 0.05);
    animTime += clampedDt;
    camera.updateSmoothing(clampedDt);

    if (autoDayNight) {
      timeOfDay = (timeOfDay + clampedDt * _dayCycleRate) % 1.0;
    }

    // Smooth baseline passive income (65% steady stream + ~35% live customer checkout bursts!)
    final steadyPerSec = (incomePerMinute * 0.68) / 60.0;
    final earned = steadyPerSec * clampedDt;
    cash += earned;
    totalCashEarned += earned;

    if (enablePersistence) {
      _autosaveAccum += clampedDt;
      if (_autosaveAccum >= 6.0) {
        _autosaveAccum = 0.0;
        saveState();
      }
    }

    for (final plot in plots) {
      if (plot.bounceTimer > 0) {
        plot.bounceTimer = math.max(0.0, plot.bounceTimer - clampedDt);
      }
      if (plot.buildPopTimer > 0) {
        plot.buildPopTimer = math.max(0.0, plot.buildPopTimer - clampedDt * 1.9);
      }
    }

    _updateVehicles(clampedDt);
    _updateVisitors(clampedDt);

    for (final pt in particles) {
      pt.age += clampedDt;
      pt.position = pt.position + pt.velocity * clampedDt;
      pt.velocity = Vec3(
        pt.velocity.x * 0.96,
        pt.velocity.y - (pt.isCoin ? 6.8 : 0.45) * clampedDt,
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

    // Always repaint 3D canvas; only rebuild HUD widgets when visible integers/badges change!
    _notifyRender();
    final cashFloor = cash.floor();
    final claimableNow = claimableMilestoneCount;
    if (cashFloor != _lastHudCashFloor || claimableNow != _lastClaimableCount) {
      _lastHudCashFloor = cashFloor;
      _lastClaimableCount = claimableNow;
      notifyListeners();
    }
  }

  void _updateVehicles(double dt) {
    _trafficSpawnCooldown -= dt;
    final desiredMax = 5 + math.min(5, builtCount);
    if (_trafficSpawnCooldown <= 0 && vehicles.length < desiredMax) {
      final dir = _rng.nextBool() ? 1 : -1;
      final spawnX = dir == 1 ? -28.0 : 28.0;
      final laneZ = dir == 1
          ? OutpostLayout.highwayEastboundZ
          : OutpostLayout.highwayWestboundZ;
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
    const aisleZ = OutpostLayout.parkingAisleZ;

    for (final v in vehicles) {
      switch (v.phase) {
        case VehiclePhase.highwayCruise:
          double activeSpeed = v.speed;
          for (final other in vehicles) {
            if (other.id == v.id) continue;
            if ((other.position.z - v.position.z).abs() > 1.1) continue;
            final ahead = (other.position.x - v.position.x) * v.direction;
            if (ahead > 0.2 && ahead < 4.6) {
              activeSpeed = math.min(
                activeSpeed,
                other.phase == VehiclePhase.highwayCruise ? other.speed * 0.75 : 1.0,
              );
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

          if (parkingTier > 0 && v.parkingSlotIndex == -1) {
            final entryHalfSpan = OutpostLayout.drivewayHalfSpanForTier(parkingTier);
            final nearWestEntry = v.direction == 1 &&
                v.position.x > -entryHalfSpan - 1.2 &&
                v.position.x < -entryHalfSpan + 1.2;
            final nearEastEntry = v.direction == -1 &&
                v.position.x < entryHalfSpan + 1.2 &&
                v.position.x > entryHalfSpan - 1.2;
            final pullChance = parkingTier == 1 ? 0.16 : 0.10;
            if ((nearWestEntry || nearEastEntry) && _rng.nextDouble() < pullChance) {
              final freeSlot = _findFreeParkingSlot();
              if (freeSlot != -1) {
                v.parkingSlotIndex = freeSlot;
                final slot = OutpostLayout.parkingSlots[freeSlot];
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
          // Subtle tire sand dust puffs on unpaved dirt/gravel lots
          if (parkingTier <= 2 && _rng.nextDouble() < dt * 7.5) {
            particles.add(
              Particle3D(
                position: v.position + const Vec3(0, 0.14, 0),
                velocity: Vec3((_rng.nextDouble() - 0.5) * 0.6, 0.45, (_rng.nextDouble() - 0.5) * 0.6),
                color: DesertPalette.sandLight,
                size: 4.5,
                duration: 0.55,
              ),
            );
          }

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
              v.yaw = -math.pi * 0.5;
              v.phase = VehiclePhase.parked;
              v.parkTimer = 6.5 + _rng.nextDouble() * 3.5;
              v.spawnedVisitor = false;
            }
          } else {
            final step = math.min(dist, 3.8 * dt);
            final dir = toWp / dist;
            v.position = v.position + dir * step;
            final desiredYaw = math.atan2(dir.z, dir.x);
            v.yaw = _lerpAngle(v.yaw, desiredYaw, (dt * 8.5).clamp(0.0, 1.0));
          }

        case VehiclePhase.parked:
          if (!v.spawnedVisitor) {
            v.spawnedVisitor = true;
            _spawnVisitorsFromVehicle(v);
          }
          v.parkTimer -= dt;
          final hasActiveVisitor = visitors.any((vis) => vis.vehicleId == v.id);
          if (v.parkTimer <= 0 && !hasActiveVisitor) {
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
    final exitHalfSpan = OutpostLayout.drivewayHalfSpanForTier(parkingTier) - 0.15;
    final exitX = v.direction == 1 ? exitHalfSpan : -exitHalfSpan;
    final exitZ = v.direction == 1
        ? OutpostLayout.highwayEastboundZ
        : OutpostLayout.highwayWestboundZ;
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
              vis.yaw = -math.pi * 0.5;
              vis.waitTimer = 1.6 + _rng.nextDouble() * 1.4;
            }
          } else {
            final dir = diff / dist;
            vis.position = vis.position + dir * (2.05 * dt);
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
            final sale = math.max(
              3.0,
              ((biz.incomeForLevel(plot.level) * decorationBonusMultiplier) / 15.0)
                  .roundToDouble(),
            );
            cash += sale;
            totalCashEarned += sale;
            totalCustomersServed += 1;
            plot.bounceTimer = 0.28;
            floatingCash.add(
              FloatingCash(
                position: plot.position + const Vec3(0, 2.5, 0),
                text: '+\$${sale.toInt()}',
                color: DesertPalette.goldPopup,
                driftX: (_rng.nextDouble() - 0.5) * 0.65,
              ),
            );
            vis.phase = VisitorPhase.returningToCar;
            notifyListeners();
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
            vis.position = vis.position + dir * (2.05 * dt);
            final desiredYaw = math.atan2(dir.z, dir.x);
            vis.yaw = _lerpAngle(vis.yaw, desiredYaw, (dt * 10.0).clamp(0.0, 1.0));
          }
      }
    }

    visitors.removeWhere(toRemove.contains);
  }

  double _lerpAngle(double current, double target, double t) {
    double diff = (target - current) % (math.pi * 2.0);
    if (diff > math.pi) diff -= math.pi * 2.0;
    if (diff < -math.pi) diff += math.pi * 2.0;
    return current + diff * t;
  }

  int _findFreeParkingSlot() {
    final allowed = OutpostLayout.activeSlotIndicesForTier(parkingTier);
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
        ? OutpostLayout.highwayEastboundZ
        : OutpostLayout.highwayWestboundZ;
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

  /// Tourist Vans & Camper RVs unload 2–3 passengers who visit different shops!
  void _spawnVisitorsFromVehicle(VehicleEntity v) {
    final openPlots = plots.where((p) => p.isBuilt).toList();
    if (openPlots.isEmpty) return;

    final int passengerCount = switch (v.kind) {
      VehicleKind.touristVan => 3,
      VehicleKind.camperRv => 2,
      VehicleKind.suv => _rng.nextBool() ? 2 : 1,
      _ => 1,
    };

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

    for (int i = 0; i < passengerCount; i++) {
      final targetPlot = openPlots[(i + _rng.nextInt(openPlots.length)) % openPlots.length];
      final offset = Vec3(0.42 + (i - 0.5) * 0.34, 0, -1.05 - i * 0.22);
      final start = v.position + offset;
      final dest = targetPlot.visitorStopPoint + Vec3((i - 0.5) * 0.36, 0, 0);
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
          walkCycle: i * 0.8,
          outboundPath: outbound,
          returnPath: inbound,
        ),
      );
    }
  }

  List<Vec3> _buildSidewalkPath(Vec3 start, Vec3 dest) {
    const promenadeZ = OutpostLayout.frontPromenadeZ;
    const spineX = OutpostLayout.centralSpineX;
    final path = <Vec3>[Vec3(start.x, 0, promenadeZ)];

    if (dest.z > 5.5) {
      path.add(Vec3(dest.x, 0, promenadeZ));
      path.add(dest);
    } else if (dest.z > 0.0) {
      const crossZ = OutpostLayout.midCrosswalkZ;
      path.add(const Vec3(spineX, 0, promenadeZ));
      path.add(const Vec3(spineX, 0, crossZ));
      path.add(Vec3(dest.x, 0, crossZ));
      path.add(dest);
    } else {
      const upperZ = OutpostLayout.upperTerraceZ;
      path.add(const Vec3(spineX, 0, promenadeZ));
      path.add(const Vec3(spineX, 0, upperZ));
      path.add(Vec3(dest.x, 0, upperZ));
      path.add(dest);
    }
    return path;
  }

  Color _randomVehicleColor() {
    const palette = [
      Color(0xFFC85B43),
      Color(0xFF4F9A94),
      Color(0xFFE0B45A),
      Color(0xFFDFD5C3),
      Color(0xFF5A778E),
      Color(0xFF7B855E),
      Color(0xFFB56E4B),
    ];
    return palette[_rng.nextInt(palette.length)];
  }

  // --- Player Interactions ---

  void performActiveTap({PlotState? target}) {
    final plot = target ?? plots.first;
    final gain = tapIncome;
    cash += gain;
    totalCashEarned += gain;
    totalTaps += 1;
    plot.bounceTimer = 0.36;
    _playTapFeedback();

    final spawnOrigin = plot.position + const Vec3(0, 2.35, 0.35);
    // Alternating golden/warm arc drift prevents text stacking into a green smudge!
    final sideSign = (totalTaps.isEven ? 1.0 : -1.0);
    floatingCash.add(
      FloatingCash(
        position: spawnOrigin + Vec3(sideSign * 0.22, 0.15, 0),
        text: '+\$${gain.toInt()}',
        color: DesertPalette.goldPopup,
        driftX: sideSign * (0.45 + _rng.nextDouble() * 0.55),
      ),
    );

    for (int i = 0; i < 6; i++) {
      final a = _rng.nextDouble() * math.pi * 2.0;
      final spd = 1.6 + _rng.nextDouble() * 2.0;
      particles.add(
        Particle3D(
          position: spawnOrigin,
          velocity: Vec3(math.cos(a) * spd, 3.0 + _rng.nextDouble() * 1.6, math.sin(a) * spd),
          color: DesertPalette.gold,
          size: 3.8,
          duration: 0.68,
          isCoin: true,
        ),
      );
    }
    _notifyBoth();
  }

  /// Spawns a friendly in-world hint when tapping an unaffordable bubble.
  void notifyShortfall(Vec3 worldPos, double neededAmount) {
    _playTapFeedback();
    floatingCash.add(
      FloatingCash(
        position: worldPos + const Vec3(0, 0.6, 0),
        text: 'NEED \$${neededAmount.ceil()}',
        color: const Color(0xFFFFB899),
        driftX: (_rng.nextDouble() - 0.5) * 0.3,
        duration: 0.95,
      ),
    );
    _notifyRender();
  }

  PlotState? handleWorldTap(Offset screenPos, Size viewport) {
    final groundPoint = camera.screenToGround(screenPos, viewport, planeY: 0.0);
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
        performActiveTap(target: best);
      } else {
        if (!buildOnPlot(best)) {
          final cost = kBusinessCatalog[best.businessType]!.purchaseCost;
          notifyShortfall(best.position + const Vec3(0, 2.2, 0), cost - cash);
        }
      }
      return best;
    }

    if (selectedPlotId != null) {
      selectedPlotId = null;
      _notifyBoth();
    }
    return null;
  }

  void selectPlot(String? plotId) {
    selectedPlotId = plotId;
    _notifyBoth();
  }

  bool upgradeParking() {
    final next = nextParkingTier;
    if (next == null || cash < next.cost) return false;

    cash -= next.cost;
    parkingTier = next.tier;
    _playTapFeedback(heavy: true);
    camera.setStageFraming(parkingTier: parkingTier, builtCount: builtCount);
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

    if (parkingTier == 1) {
      final freeSlot = _findFreeParkingSlot();
      if (freeSlot != -1) {
        final slot = OutpostLayout.parkingSlots[freeSlot];
        final v = VehicleEntity(
          id: _nextEntityId++,
          kind: VehicleKind.pickupTruck,
          bodyColor: _randomVehicleColor(),
          position: const Vec3(-9.5, 0, OutpostLayout.highwayEastboundZ),
          yaw: 0.0,
          speed: 5.0,
          direction: 1,
          phase: VehiclePhase.pullingIn,
          parkingSlotIndex: freeSlot,
          waypoints: [
            const Vec3(-2.4, 0, OutpostLayout.parkingAisleZ),
            Vec3(slot.x, 0, OutpostLayout.parkingAisleZ),
            slot,
          ],
        );
        vehicles.add(v);
      }
    }

    saveState();
    _notifyBoth();
    return true;
  }

  bool buildOnPlot(PlotState plot) {
    if (plot.isBuilt) return false;
    final data = kBusinessCatalog[plot.businessType]!;
    if (cash < data.purchaseCost) return false;

    cash -= data.purchaseCost;
    plot.isBuilt = true;
    plot.level = 1;
    plot.buildPopTimer = 1.0;
    plot.bounceTimer = 0.38;
    _playTapFeedback(heavy: true);
    camera.setStageFraming(parkingTier: parkingTier, builtCount: builtCount);
    _spawnConstructionDust(plot.position, count: 14);
    floatingCash.add(
      FloatingCash(
        position: plot.position + const Vec3(0, 2.8, 0),
        text: 'BUILT!',
        color: DesertPalette.gold,
        duration: 1.4,
      ),
    );
    saveState();
    _notifyBoth();
    return true;
  }

  bool upgradePlot(PlotState plot) {
    if (!plot.isBuilt) return false;
    final data = kBusinessCatalog[plot.businessType]!;
    if (plot.level >= data.maxLevel) return false;
    final cost = data.upgradeCostForLevel(plot.level);
    if (cash < cost) return false;

    cash -= cost;
    plot.level += 1;
    plot.bounceTimer = 0.40;
    _playTapFeedback(heavy: true);
    _spawnConstructionDust(plot.position, count: 10);
    floatingCash.add(
      FloatingCash(
        position: plot.position + const Vec3(0, 3.0, 0),
        text: 'LV ${plot.level}!',
        color: DesertPalette.neonTurquoise,
        duration: 1.35,
      ),
    );
    saveState();
    _notifyBoth();
    return true;
  }

  bool upgradeTapPower() {
    final cost = tapUpgradeCost;
    if (cash < cost) return false;
    cash -= cost;
    tapUpgradeLevel += 1;
    _playTapFeedback(heavy: true);
    performActiveTap(target: plots.first);
    saveState();
    return true;
  }

  bool placeDecoration(DecorationKind kind, String name, double cost) {
    if (cash < cost || decorations.length >= _decorationSpots.length) return false;
    cash -= cost;
    _playTapFeedback(heavy: true);
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
    floatingCash.add(
      FloatingCash(
        position: spot + const Vec3(0, 2.0, 0),
        text: '+4% TIPS!',
        color: DesertPalette.goldPopup,
        duration: 1.3,
      ),
    );
    saveState();
    _notifyBoth();
    return true;
  }

  bool get canAddMoreDecorations => decorations.length < _decorationSpots.length;

  bool claimMilestone(MilestoneData milestone) {
    if (milestone.claimed || !milestone.checkCompleted()) return false;
    milestone.claimed = true;
    cash += milestone.rewardCash;
    totalCashEarned += milestone.rewardCash;
    _playTapFeedback(heavy: true);
    floatingCash.add(
      FloatingCash(
        position: const Vec3(0, 3.5, 2.0),
        text: '+\$${milestone.rewardCash.toInt()} BONUS!',
        color: DesertPalette.gold,
        duration: 1.6,
      ),
    );
    saveState();
    _notifyBoth();
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
    saveState();
    _notifyBoth();
  }

  void toggleAutoDayNight() {
    autoDayNight = !autoDayNight;
    saveState();
    _notifyBoth();
  }

  void switchPreset(OutpostPreset preset) {
    _initPlots(preset);
    _initMilestones();
    camera.reset(parkingTier: parkingTier, builtCount: builtCount);
    _seedInitialTraffic();
    saveState();
    _notifyBoth();
  }

  double simulateOfflineEarnings({int minutesAway = 15}) {
    final earned = (incomePerMinute * minutesAway).roundToDouble();
    cash += earned;
    totalCashEarned += earned;
    floatingCash.add(
      FloatingCash(
        position: const Vec3(0, 3.2, 1.0),
        text: '+\$${earned.toInt()} OFFLINE',
        color: DesertPalette.goldPopup,
        duration: 1.6,
      ),
    );
    saveState();
    _notifyBoth();
    return earned;
  }

  // --- Camera Controls ---

  void panCamera(Offset delta, Size viewport) {
    camera.panByScreenDelta(delta, viewport);
    _notifyRender();
  }

  void orbitCamera(double deltaRadians) {
    camera.orbitByDelta(deltaRadians);
    _notifyRender();
  }

  void zoomCamera(double scaleDelta) {
    camera.zoomByFactor(scaleDelta);
    _notifyRender();
  }

  void resetCamera() {
    camera.reset(parkingTier: parkingTier, builtCount: builtCount);
    _notifyRender();
  }
}
