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
import 'road_network.dart';
import 'world_grid.dart';

part 'game_controller_building.dart';
part 'game_controller_persistence.dart';
part 'game_controller_traffic.dart';

enum OutpostPreset {
  fullCity,
  stageOneCareer,
}

class _RenderNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Central simulation & state hub for Desert Outpost.
///
/// Split across library parts for maintainability:
/// - `game_controller.dart` – state, presets, progression, economy, tick, camera
/// - `game_controller_building.dart` – land parcels, road line tool, freeform placement
/// - `game_controller_traffic.dart` – highway traffic, parking & visitor AI
/// - `game_controller_persistence.dart` – save schema v3 + legacy migration
class GameController extends ChangeNotifier {
  GameController({
    OutpostPreset initialPreset = OutpostPreset.stageOneCareer,
    this.enablePersistence = false,
  }) {
    _suppressStageFx = true;
    _initWorld(initialPreset);
    _initMilestones();
    if (enablePersistence) {
      _loadSavedState();
    }
    _recomputeNetwork();
    _resetCameraToTown();
    _seedInitialTraffic();
    _suppressStageFx = false;
    _lastHudCashFloor = cash.floor();
    _lastClaimableCount = claimableMilestoneCount;
  }

  final bool enablePersistence;
  final math.Random _rng = math.Random(42);
  final Camera3D camera = Camera3D();
  final RoadNetwork roadNetwork = RoadNetwork();
  final WorldGrid worldGrid = WorldGrid();

  final _RenderNotifier _renderNotifier = _RenderNotifier();
  Listenable get renderListenable => _renderNotifier;

  // Economy & progression state
  double cash = 0.0;
  double totalCashEarned = 0.0;
  int totalCustomersServed = 0;
  int totalTaps = 0;
  int tapUpgradeLevel = 1;
  OutpostPreset activePreset = OutpostPreset.stageOneCareer;
  bool soundEnabled = true;

  double pendingOfflineWelcomeCash = 0.0;
  int pendingOfflineMinutes = 0;

  // Time & lighting (memoized to avoid per-frame DesertLighting allocations)
  double animTime = 0.0;
  double timeOfDay = 0.37;
  bool autoDayNight = true;
  static const double _dayCycleRate = 0.0085;
  double _cachedLightingTime = -1.0;
  DesertLighting? _cachedLighting;

  DesertLighting get lighting {
    if (_cachedLighting == null || _cachedLightingTime != timeOfDay) {
      _cachedLightingTime = timeOfDay;
      _cachedLighting = DesertLighting.fromTime(timeOfDay);
    }
    return _cachedLighting!;
  }

  // World entities
  late List<PlotState> plots;
  final List<ParkingLotEntity> parkingLots = [];
  final List<VehicleEntity> vehicles = [];
  final List<VisitorEntity> visitors = [];
  final List<FloatingCash> floatingCash = [];
  final List<Particle3D> particles = [];
  final List<PlacedDecoration> decorations = [];
  late List<MilestoneData> milestones;

  static const int maxDecorations = 16;

  // Interactive build tool state
  WorldToolMode toolMode = WorldToolMode.play;
  RoadTier activeRoadTier = RoadTier.dirt;
  bool roadEraseMode = false;
  GridCell? roadLineStart;
  GridCell? roadLineEnd;
  BusinessType? pendingBuildingType;
  PlotState? relocatingPlot;
  ParkingLotKind? pendingParkingKind;
  ParkingLotEntity? relocatingParkingLot;
  bool relocatingParkingIsUpgrade = false;
  (DecorationKind, String, double)? pendingDecoration;
  int ghostGridX = 0;
  int ghostGridZ = -12;
  int ghostRotation = 0;

  String? selectedPlotId;
  int _nextEntityId = 1;
  double _trafficSpawnCooldown = 0.8;
  double _autosaveAccum = 0.0;
  int _lastHudCashFloor = 0;
  int _lastClaimableCount = 0;

  // Cached progression metrics (refreshed only when the world changes, never per frame)
  int _highestStage = 1;
  int _connectedBuiltCount = 0;
  int _totalParkingSpaces = 0;
  int _parkingTier = 0;
  double _averageAccess = 0.0;
  bool _suppressStageFx = false;

  /// Default Full-City landmark layout `(gridX, gridZ)` around a paved desert loop.
  static const Map<String, (int, int)> _cityLayout = {
    'vendor': (-8, -8),
    'food_stand': (-4, -8),
    'oasis_plaza': (6, -5),
    'mart': (-8, -16),
    'diner': (-2, -16),
    'gas_station': (4, -9),
    'motel': (-8, -23),
    'lookout': (2, -23),
  };

  /// Career start: the tiny cart sits in the middle of the desert, ~40 units from Route 163.
  static const (int, int) _careerCartCell = (-1, -14);

  @override
  void dispose() {
    if (enablePersistence) {
      saveState();
    }
    _renderNotifier.dispose();
    super.dispose();
  }

  void _notifyRender() => _renderNotifier.ping();

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

  // --- World / Preset Initialization ---

  List<PlotState> _buildPlots({required bool full}) {
    PlotState make(
      String id,
      BusinessType type,
      double fw,
      double fd, {
      required bool built,
      required int level,
    }) {
      final (gx, gz) = (!full && id == 'vendor') ? _careerCartCell : _cityLayout[id]!;
      return PlotState(
        id: id,
        businessType: type,
        gridX: gx,
        gridZ: gz,
        footprintWidth: fw,
        footprintDepth: fd,
        isBuilt: built,
        level: level,
      );
    }

    return [
      make('vendor', BusinessType.vendorStall, 3.7, 2.9, built: true, level: full ? 4 : 1),
      make('food_stand', BusinessType.foodStand, 3.9, 3.0, built: full, level: full ? 3 : 1),
      make('oasis_plaza', BusinessType.oasisPlaza, 4.1, 3.2, built: false, level: 1),
      make('mart', BusinessType.convenienceStore, 5.0, 4.0, built: full, level: full ? 3 : 1),
      make('diner', BusinessType.desertDiner, 6.1, 4.5, built: full, level: full ? 3 : 1),
      make('gas_station', BusinessType.gasStation, 5.6, 4.6, built: full, level: full ? 3 : 1),
      make('motel', BusinessType.desertMotel, 6.9, 4.4, built: full, level: full ? 3 : 1),
      make('lookout', BusinessType.lookoutCamp, 6.4, 4.4, built: full, level: full ? 3 : 1),
    ];
  }

  void _initWorld(OutpostPreset preset) {
    activePreset = preset;
    final full = preset == OutpostPreset.fullCity;
    roadNetwork.clear();
    parkingLots.clear();
    decorations.clear();
    vehicles.clear();
    visitors.clear();
    cancelToolMode(notify: false);
    plots = _buildPlots(full: full);
    _highestStage = 1;

    if (full) {
      worldGrid.resetOwnership([
        for (int px = 2; px <= 5; px++)
          for (int pz = 4; pz <= 6; pz++) LandParcel(px, pz),
      ]);

      // Paved Monument Valley loop: twin highway junctions + three town avenues
      for (int gz = -20; gz <= OutpostLayout.highwayEntryRowZ; gz++) {
        roadNetwork.setTile(GridCell(-10, gz), RoadTier.paved);
        roadNetwork.setTile(GridCell(10, gz), RoadTier.paved);
      }
      for (int gx = -10; gx <= 10; gx++) {
        for (final row in const [-6, -13, -20]) {
          roadNetwork.setTile(GridCell(gx, row), RoadTier.paved);
        }
      }

      parkingLots.addAll([
        ParkingLotEntity(
          id: 'lot_${_nextEntityId++}',
          kind: ParkingLotKind.pavedLot,
          gridX: 3,
          gridZ: -12,
        ),
        ParkingLotEntity(
          id: 'lot_${_nextEntityId++}',
          kind: ParkingLotKind.gravelLot,
          gridX: -4,
          gridZ: -12,
        ),
        ParkingLotEntity(
          id: 'lot_${_nextEntityId++}',
          kind: ParkingLotKind.dirtPullOff,
          gridX: -3,
          gridZ: -19,
        ),
      ]);

      cash = 1450.0;
      totalCashEarned = 3650.0;
      totalCustomersServed = 42;
      tapUpgradeLevel = 2;
    } else {
      worldGrid.resetOwnership([
        for (final (px, pz) in OutpostLayout.starterParcels) LandParcel(px, pz),
      ]);
      cash = 0.0;
      totalCashEarned = 0.0;
      totalCustomersServed = 0;
      tapUpgradeLevel = 1;
    }
    totalTaps = 0;
    selectedPlotId = null;
  }

  void _initMilestones() {
    milestones = [
      MilestoneData(
        id: 'm_park1',
        title: 'First Pull-Off',
        description: 'Place a Dirt Pull-Off beside your cart',
        rewardCash: 40,
        checkCompleted: () => parkingLots.isNotEmpty,
      ),
      MilestoneData(
        id: 'm_road1',
        title: 'Desert Access Road',
        description: 'Connect Route 163 to your cart with a road',
        rewardCash: 60,
        checkCompleted: () => plots.any((p) => p.isBuilt && p.access.hasDirectRoad),
      ),
      MilestoneData(
        id: 'm_land',
        title: 'Land Rush',
        description: 'Buy your first extra desert land parcel',
        rewardCash: 100,
        checkCompleted: () =>
            worldGrid.ownedParcels.length > OutpostLayout.starterParcels.length,
      ),
      MilestoneData(
        id: 'm_3biz',
        title: 'Desert Strip',
        description: 'Operate at least 3 road-connected businesses',
        rewardCash: 160,
        checkCompleted: () => connectedBuiltCount >= 3,
      ),
      MilestoneData(
        id: 'm_paved_loop',
        title: 'Highway Loop',
        description: 'Build 4+ Paved tiles & 2 Route 163 junctions',
        rewardCash: 420,
        checkCompleted: () =>
            roadNetwork.pavedRoadCount >= 4 && roadNetwork.highwayTurnOffCount >= 2,
      ),
      MilestoneData(
        id: 'm_oasis',
        title: 'Complete the Outpost',
        description: 'Build all 8 desert city landmarks',
        rewardCash: 1000,
        checkCompleted: () => builtCount == plots.length,
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

  /// Recomputes road connectivity, store access, tile occupancy & cached progression.
  void _recomputeNetwork() {
    roadNetwork.recompute(
      plots: plots,
      parkingLots: parkingLots,
      decorations: decorations,
    );
    worldGrid.rebuildOccupancy(
      plots: plots,
      parkingLots: parkingLots,
      decorations: decorations,
    );
    _refreshProgression();
  }

  void _refreshProgression() {
    _connectedBuiltCount = plots.where((p) => p.isBuilt && p.access.score > 0.0).length;
    final activeLots = parkingLots.where((l) => l.isConnected).toList(growable: false);
    _totalParkingSpaces = activeLots.fold<int>(0, (s, l) => s + l.spec.spaces);

    if (activeLots.isEmpty) {
      _parkingTier = 0;
    } else if (activeLots.any((l) => l.kind == ParkingLotKind.pavedLot) ||
        _totalParkingSpaces >= 6) {
      _parkingTier = 3;
    } else if (activeLots.any((l) => l.kind == ParkingLotKind.gravelLot) ||
        _totalParkingSpaces >= 4) {
      _parkingTier = 2;
    } else {
      _parkingTier = 1;
    }

    final built = plots.where((p) => p.isBuilt).toList(growable: false);
    _averageAccess = built.isEmpty
        ? 0.0
        : built.fold<double>(0.0, (s, p) => s + p.access.score) / built.length;

    // Stage is MONOTONIC: bulldozing never drops progression or re-locks content.
    final computed = _computeStage();
    if (computed > _highestStage) {
      _highestStage = computed;
      if (!_suppressStageFx) {
        floatingCash.add(
          FloatingCash(
            position: townFocus + const Vec3(0, 4.2, 0),
            text: 'STAGE $computed · ${stageInfo.title.toUpperCase()}!',
            color: DesertPalette.gold,
            duration: 2.2,
          ),
        );
        _playTapFeedback(heavy: true);
      }
    }
  }

  int _computeStage() {
    final hasHighway = roadNetwork.highwayTurnOffCount > 0;
    int stage = 1;
    if (_totalParkingSpaces >= 2 && hasHighway) stage = 2;
    if (stage >= 2 &&
        _connectedBuiltCount >= 2 &&
        (totalCustomersServed >= 4 || roadNetwork.gravelOrBetterCount >= 3)) {
      stage = 3;
    }
    if (stage >= 3 && _connectedBuiltCount >= 4 && _totalParkingSpaces >= 4) stage = 4;
    if (stage >= 4 &&
        _connectedBuiltCount >= 5 &&
        (roadNetwork.pavedRoadCount >= 4 || _totalParkingSpaces >= 6)) {
      stage = 5;
    }
    if (stage >= 5 && _connectedBuiltCount >= 7 && _totalParkingSpaces >= 6) stage = 6;
    return stage;
  }

  // --- Computed Metrics & Progression Gates ---

  int get builtCount => plots.where((p) => p.isBuilt).length;
  int get connectedBuiltCount => _connectedBuiltCount;
  int get totalParkingSpaces => _totalParkingSpaces;
  int get parkingTier => _parkingTier;
  double get averageAccessScore => _averageAccess;
  int get outpostStage => _highestStage;

  OutpostStageInfo get stageInfo =>
      kOutpostStages[(outpostStage - 1).clamp(0, kOutpostStages.length - 1)];

  PlotState get cartPlot => plots.first;

  /// World-space focus point of the town (the cart, or the starter land center).
  Vec3 get townFocus {
    final cart = cartPlot;
    if (cart.isBuilt) return cart.position;
    final (px, pz) = OutpostLayout.starterParcels.first;
    return OutpostLayout.parcelCenter(px, pz);
  }

  int get staticBuildingsSignature {
    int h = 17;
    for (final p in plots) {
      h = h * 31 + (p.isBuilt ? p.level : 0);
      h = h * 31 + p.gridX * 7 + p.gridZ * 13 + p.rotationQuarter * 3;
      h = h * 31 + (p.bounceTimer > 0 || p.buildPopTimer > 0 ? 1 : 0);
    }
    for (final l in parkingLots) {
      h = h * 31 + l.kind.index * 19 + l.gridX * 7 + l.gridZ * 13 + l.rotationQuarter * 3;
      h = h * 31 + (l.connectedSide?.index ?? 7);
    }
    h = h * 31 + roadNetwork.version;
    h = h * 31 + worldGrid.version;
    h = h * 31 + _highestStage * 97;
    h = h * 31 + toolMode.index;
    return h ^ (selectedPlotId?.hashCode ?? 0);
  }

  bool isRoadTierUnlocked(RoadTier tier) =>
      outpostStage >= kRoadTierCatalog[tier]!.unlockStage;

  bool isParkingKindUnlocked(ParkingLotKind kind) =>
      outpostStage >= kParkingLotCatalog[kind]!.unlockStage;

  bool isDecorationUnlocked(DecorationKind kind) =>
      outpostStage >= decorationUnlockStage(kind);

  int decorationUnlockStage(DecorationKind kind) {
    return switch (kind) {
      DecorationKind.saguaroCluster || DecorationKind.woodenSignpost => 1,
      DecorationKind.picnicSet => 2,
      DecorationKind.desertLamp || DecorationKind.campfireRing => 4,
    };
  }

  bool isPlotUnlocked(PlotState plot) {
    if (plot.isBuilt) return true;
    return outpostStage >= plot.data.stage;
  }

  /// `null` if [plot] may upgrade now, otherwise a short lock label.
  String? upgradeLockReason(PlotState plot) {
    if (!plot.isBuilt) return 'UNBUILT';
    final data = plot.data;
    if (plot.level >= data.maxLevel) return 'MAX';
    if (!plot.access.hasParkingAccess || plot.access.score <= 0.0) {
      return 'NO ROAD';
    }
    final nextLv = plot.level + 1;
    if (nextLv == 3 && outpostStage < 3) return 'STAGE 3';
    if (nextLv == 4) {
      if (outpostStage < 4) return 'STAGE 4';
      if (plot.access.roadTier == null ||
          plot.access.roadTier!.index < RoadTier.gravel.index) {
        return 'NEED GRAVEL';
      }
    }
    if (nextLv == 5) {
      if (outpostStage < 6) return 'STAGE 6';
      if (plot.access.roadTier != RoadTier.paved) return 'NEED PAVED';
    }
    return null;
  }

  bool canUpgradePlotByProgression(PlotState plot) => upgradeLockReason(plot) == null;

  List<PlotState> get visiblePlots => plots.where((p) => p.isBuilt).toList(growable: false);

  List<PlotState> get availableUnbuiltPlots =>
      plots.where((p) => !p.isBuilt).toList(growable: false);

  double get decorationBonusMultiplier => 1.0 + decorations.length * 0.04;

  /// Passive income scales directly with each store's live Road Access quality.
  double get incomePerMinute {
    if (_totalParkingSpaces <= 0) return 0.0;
    double sum = 0.0;
    for (final plot in plots) {
      if (!plot.isBuilt || plot.access.score <= 0.0) continue;
      sum += plot.data.incomeForLevel(plot.level) * plot.access.score;
    }
    return (sum * decorationBonusMultiplier).roundToDouble();
  }

  double get tapIncome {
    final base = 5.0 + (tapUpgradeLevel - 1) * 5.0;
    final bonus = (builtCount - 1) * 2.0;
    return ((base + bonus) * decorationBonusMultiplier).roundToDouble();
  }

  double get tapUpgradeCost =>
      (35.0 * math.pow(1.65, tapUpgradeLevel - 1)).roundToDouble();

  int get reputation =>
      builtCount * 12 +
      totalCustomersServed +
      decorations.length * 6 +
      roadNetwork.roadCount * 2 +
      _totalParkingSpaces * 5 +
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

  int get claimableMilestoneCount =>
      milestones.where((m) => !m.claimed && m.checkCompleted()).length;

  /// O(1) occupancy probe used to auto-clear flora under roads, lots & buildings.
  bool isWorldPointOccupied(double x, double z) {
    for (final ox in const [-0.7, 0.7]) {
      for (final oz in const [-0.7, 0.7]) {
        final (gx, gz) = OutpostLayout.worldToCell(Vec3(x + ox, 0, z + oz));
        final cell = GridCell(gx, gz);
        if (roadNetwork.hasRoadAt(cell) || worldGrid.isOccupied(cell)) return true;
      }
    }
    return false;
  }

  // --- Simulation Step ---

  void tick(double dt) {
    final clampedDt = dt.clamp(0.0, 0.05);
    animTime += clampedDt;
    camera.updateSmoothing(clampedDt);

    if (autoDayNight) {
      timeOfDay = (timeOfDay + clampedDt * _dayCycleRate) % 1.0;
    }

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
        plot.buildPopTimer = math.max(0.0, plot.buildPopTimer - clampedDt * 1.45);
      }
    }

    for (final fc in floatingCash) {
      fc.age += clampedDt;
    }
    floatingCash.removeWhere((f) => f.isDone);

    for (final p in particles) {
      p.age += clampedDt;
      p.position = p.position + p.velocity * clampedDt;
      p.velocity = Vec3(
        p.velocity.x * 0.96,
        p.velocity.y - (p.isCoin ? 9.5 : 2.8) * clampedDt,
        p.velocity.z * 0.96,
      );
      if (p.position.y < 0.05) {
        p.position = Vec3(p.position.x, 0.05, p.position.z);
        p.velocity = Vec3(p.velocity.x * 0.6, 0, p.velocity.z * 0.6);
      }
    }
    particles.removeWhere((p) => p.isDone);

    _updateVehicles(clampedDt);
    _updateVisitors(clampedDt);

    _notifyRender();

    final cashFloor = cash.floor();
    final claimables = claimableMilestoneCount;
    if (cashFloor != _lastHudCashFloor || claimables != _lastClaimableCount) {
      _lastHudCashFloor = cashFloor;
      _lastClaimableCount = claimables;
      notifyListeners();
    }
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

  void _floatNotice(Vec3 worldPos, String text, {Color color = const Color(0xFFFFB899)}) {
    floatingCash.add(
      FloatingCash(position: worldPos, text: text, color: color, duration: 1.3),
    );
    _notifyRender();
  }

  PlotState? handleWorldTap(Offset screenPos, Size viewport) {
    final groundPoint = camera.screenToGround(screenPos, viewport, planeY: 0.0);

    switch (toolMode) {
      case WorldToolMode.paintRoad:
        final (gx, gz) = OutpostLayout.worldToCell(groundPoint);
        roadLineTap(GridCell(gx, gz));
        return null;
      case WorldToolMode.placeBuilding:
      case WorldToolMode.placeParking:
      case WorldToolMode.placeDecoration:
        moveGhostToWorld(groundPoint);
        return null;
      case WorldToolMode.buyLand:
        final parcel = parcelAtWorld(groundPoint);
        if (parcel != null) buyParcel(parcel);
        return null;
      case WorldToolMode.play:
        break;
    }

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
      performActiveTap(target: best);
      return best;
    }
    return null;
  }

  /// Long-press drag inside a build tool (draws road lines / drags the placement ghost).
  void beginToolDrag(Vec3 groundPoint) {
    if (toolMode == WorldToolMode.paintRoad) {
      final (gx, gz) = OutpostLayout.worldToCell(groundPoint);
      roadLineStart = GridCell(gx, gz);
      roadLineEnd = roadLineStart;
      _playTapFeedback();
      _notifyBoth();
    } else if (toolMode == WorldToolMode.placeBuilding ||
        toolMode == WorldToolMode.placeParking ||
        toolMode == WorldToolMode.placeDecoration) {
      moveGhostToWorld(groundPoint);
    }
  }

  void updateToolDrag(Vec3 groundPoint) {
    if (toolMode == WorldToolMode.paintRoad && roadLineStart != null) {
      final (gx, gz) = OutpostLayout.worldToCell(groundPoint);
      final cell = GridCell(gx, gz);
      if (cell != roadLineEnd) {
        roadLineEnd = cell;
        _notifyBoth();
      }
    } else if (toolMode == WorldToolMode.placeBuilding ||
        toolMode == WorldToolMode.placeParking ||
        toolMode == WorldToolMode.placeDecoration) {
      moveGhostToWorld(groundPoint);
    }
  }

  bool upgradePlot(PlotState plot) {
    if (!plot.isBuilt) return false;
    final lock = upgradeLockReason(plot);
    if (lock != null) {
      _floatNotice(plot.position + const Vec3(0, 2.8, 0), lock);
      return false;
    }
    final cost = plot.data.upgradeCostForLevel(plot.level);
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
    floatingCash.add(
      FloatingCash(
        position: plots.first.position + const Vec3(0, 2.7, 0),
        text: 'TAP +\$${tapIncome.toInt()}!',
        color: DesertPalette.gold,
        duration: 1.25,
      ),
    );
    saveState();
    _notifyBoth();
    return true;
  }

  bool claimMilestone(MilestoneData milestone) {
    if (milestone.claimed || !milestone.checkCompleted()) return false;
    milestone.claimed = true;
    cash += milestone.rewardCash;
    totalCashEarned += milestone.rewardCash;
    _playTapFeedback(heavy: true);
    floatingCash.add(
      FloatingCash(
        position: townFocus + const Vec3(0, 3.5, 0),
        text: '+\$${milestone.rewardCash.toInt()} BONUS!',
        color: DesertPalette.gold,
        duration: 1.6,
      ),
    );
    saveState();
    _notifyBoth();
    return true;
  }

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

  // --- Time of Day & Preset Controls ---

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
    _suppressStageFx = true;
    _initWorld(preset);
    _initMilestones();
    _recomputeNetwork();
    _resetCameraToTown();
    _seedInitialTraffic();
    _suppressStageFx = false;
    saveState();
    _notifyBoth();
  }

  // --- Camera Controls ---

  void _resetCameraToTown() {
    if (activePreset == OutpostPreset.fullCity) {
      camera.reset(target: const Vec3(0, 1.8, -12.0), distance: 58.0);
    } else {
      camera.reset(
        target: townFocus + const Vec3(0, 1.6, 0),
        distance: Camera3D.stageOneDistance,
      );
    }
  }

  void panCamera(Offset delta, Size viewport) {
    camera.panByScreenDelta(delta, viewport);
    _notifyRender();
  }

  void panCameraRelative(double rightUnits, double forwardUnits) {
    camera.panRelative(rightUnits, forwardUnits);
    _notifyRender();
  }

  void orbitCamera(double deltaRadians) {
    camera.orbitByDelta(deltaRadians);
    _notifyRender();
  }

  void tiltCamera(double deltaRadians) {
    camera.tiltByDelta(deltaRadians);
    _notifyRender();
  }

  void zoomCamera(double scaleDelta) {
    camera.zoomByFactor(scaleDelta);
    _notifyRender();
  }

  void rotateCameraQuarter(int direction) {
    camera.rotateQuarter(direction);
    _notifyRender();
  }

  void cycleCameraTilt() {
    camera.cyclePitchPreset();
    _notifyRender();
  }

  void resetCamera() {
    camera.focusOn(
      townFocus + const Vec3(0, 1.6, 0),
      distance: activePreset == OutpostPreset.fullCity ? 58.0 : 34.0,
      pitch: Camera3D.defaultPitch,
      yaw: Camera3D.defaultYaw,
    );
    _notifyRender();
  }
}
