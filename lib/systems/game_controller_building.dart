part of 'game_controller.dart';

/// Land parcels, the road line tool, and freeform placement of stores,
/// parking lots and decorations on the 64 x 64 desert grid.
extension GameControllerBuilding on GameController {
  // --- Validation ---

  String? _cellBlockReason(GridCell cell, {String? ignoreId, bool allowRoad = false}) {
    if (!OutpostLayout.isCellInMap(cell.gx, cell.gz)) return 'Outside the desert map';
    if (!worldGrid.isCellOwned(cell)) return 'Buy this land first';
    if (!allowRoad && roadNetwork.hasRoadAt(cell)) return 'Overlaps a road';
    if (worldGrid.isOccupiedExcept(cell, ignoreId)) return 'Overlaps another structure';
    return null;
  }

  (bool valid, String? reason) validateBuildingPlacement({
    required BusinessType type,
    required int gridX,
    required int gridZ,
    required int rotationQuarter,
    PlotState? ignorePlot,
  }) {
    final data = kBusinessCatalog[type]!;
    final (w, d) = OutpostLayout.rotatedSize(data.gridW, data.gridD, rotationQuarter);
    final ignoreId = ignorePlot != null ? 'plot:${ignorePlot.id}' : null;
    for (int dx = 0; dx < w; dx++) {
      for (int dz = 0; dz < d; dz++) {
        final reason = _cellBlockReason(GridCell(gridX + dx, gridZ + dz), ignoreId: ignoreId);
        if (reason != null) return (false, reason);
      }
    }
    return (true, null);
  }

  (bool valid, String? reason) validateParkingPlacement({
    required ParkingLotKind kind,
    required int gridX,
    required int gridZ,
    required int rotationQuarter,
    ParkingLotEntity? ignoreLot,
  }) {
    final spec = kParkingLotCatalog[kind]!;
    final (w, d) = OutpostLayout.rotatedSize(spec.gridW, spec.gridD, rotationQuarter);
    final ignoreId = ignoreLot != null ? 'lot:${ignoreLot.id}' : null;
    for (int dx = 0; dx < w; dx++) {
      for (int dz = 0; dz < d; dz++) {
        final reason = _cellBlockReason(GridCell(gridX + dx, gridZ + dz), ignoreId: ignoreId);
        if (reason != null) return (false, reason);
      }
    }
    return (true, null);
  }

  (bool valid, String? reason) validateDecorationPlacement(int gridX, int gridZ) {
    final reason = _cellBlockReason(GridCell(gridX, gridZ));
    return (reason == null, reason);
  }

  (bool, String?) _ghostValidation() {
    switch (toolMode) {
      case WorldToolMode.placeBuilding:
        final type = pendingBuildingType;
        if (type == null) return (false, null);
        return validateBuildingPlacement(
          type: type,
          gridX: ghostGridX,
          gridZ: ghostGridZ,
          rotationQuarter: ghostRotation,
          ignorePlot: relocatingPlot,
        );
      case WorldToolMode.placeParking:
        final kind = pendingParkingKind;
        if (kind == null) return (false, null);
        return validateParkingPlacement(
          kind: kind,
          gridX: ghostGridX,
          gridZ: ghostGridZ,
          rotationQuarter: ghostRotation,
          ignoreLot: relocatingParkingLot,
        );
      case WorldToolMode.placeDecoration:
        return validateDecorationPlacement(ghostGridX, ghostGridZ);
      default:
        return (false, null);
    }
  }

  bool get isGhostPlacementValid => _ghostValidation().$1;
  String? get ghostInvalidReason => _ghostValidation().$2;

  double get _signBonus => math.min(
        0.16,
        decorations.where((d) => d.kind == DecorationKind.woodenSignpost).length * 0.08,
      );

  RoadAccessReport get ghostAccessPreview {
    final type = pendingBuildingType;
    if (toolMode != WorldToolMode.placeBuilding || type == null) {
      return RoadAccessReport.disconnected;
    }
    return roadNetwork.evaluateBuildingAccess(
      businessType: type,
      gridX: ghostGridX,
      gridZ: ghostGridZ,
      rotationQuarter: ghostRotation,
      parkingLots: parkingLots,
      signBonus: _signBonus,
    );
  }

  // --- Tool Mode Transitions ---

  void _clearPending() {
    pendingBuildingType = null;
    relocatingPlot = null;
    pendingParkingKind = null;
    relocatingParkingLot = null;
    relocatingParkingIsUpgrade = false;
    pendingDecoration = null;
    roadLineStart = null;
    roadLineEnd = null;
  }

  void cancelToolMode({bool notify = true}) {
    toolMode = WorldToolMode.play;
    roadEraseMode = false;
    _clearPending();
    if (notify) _notifyBoth();
  }

  void enterRoadPaintMode({RoadTier? tier, bool erase = false}) {
    _clearPending();
    toolMode = WorldToolMode.paintRoad;
    roadEraseMode = erase;
    if (tier != null && isRoadTierUnlocked(tier)) {
      activeRoadTier = tier;
    } else if (!isRoadTierUnlocked(activeRoadTier)) {
      activeRoadTier = RoadTier.dirt;
    }
    camera.ensureMinPitch(0.78);
    _notifyBoth();
  }

  void setRoadBrush(RoadTier tier) {
    if (!isRoadTierUnlocked(tier)) return;
    activeRoadTier = tier;
    roadEraseMode = false;
    _notifyBoth();
  }

  void setRoadEraseMode(bool erase) {
    roadEraseMode = erase;
    _notifyBoth();
  }

  void enterLandMode() {
    _clearPending();
    toolMode = WorldToolMode.buyLand;
    camera.focusOn(
      townFocus + const Vec3(0, 1.0, 0),
      distance: math.max(camera.distance, 72.0),
      pitch: math.max(camera.pitch, 0.95),
    );
    _notifyBoth();
  }

  void _focusGhost() {
    final (w, d) = _ghostSize();
    final center = OutpostLayout.footprintCenter(ghostGridX, ghostGridZ, w, d);
    camera.focusOn(
      center + const Vec3(0, 1.2, 0),
      distance: camera.distance.clamp(22.0, 46.0),
    );
    camera.ensureMinPitch(0.72);
  }

  void startPlacingBuilding(BusinessType type) {
    final plot = plots.firstWhere((p) => p.businessType == type);
    if (plot.isBuilt || !isPlotUnlocked(plot)) return;
    _clearPending();
    toolMode = WorldToolMode.placeBuilding;
    pendingBuildingType = type;
    ghostRotation = 0;
    final smart = _findSmartBuildingSpot(type);
    ghostGridX = smart.gx;
    ghostGridZ = smart.gz;
    _focusGhost();
    _notifyBoth();
  }

  void startRelocatingPlot(PlotState plot) {
    if (!plot.isBuilt) return;
    _clearPending();
    toolMode = WorldToolMode.placeBuilding;
    pendingBuildingType = plot.businessType;
    relocatingPlot = plot;
    ghostGridX = plot.gridX;
    ghostGridZ = plot.gridZ;
    ghostRotation = plot.rotationQuarter;
    _focusGhost();
    _notifyBoth();
  }

  void startPlacingParking(ParkingLotKind kind) {
    if (!isParkingKindUnlocked(kind)) return;
    _clearPending();
    toolMode = WorldToolMode.placeParking;
    pendingParkingKind = kind;
    final (spot, rot) = _findSmartParkingSpotWithRot(kind);
    ghostGridX = spot.gx;
    ghostGridZ = spot.gz;
    ghostRotation = rot;
    _focusGhost();
    _notifyBoth();
  }

  void startRelocatingParkingLot(
    ParkingLotEntity lot, {
    ParkingLotKind? upgradeTo,
  }) {
    _clearPending();
    toolMode = WorldToolMode.placeParking;
    pendingParkingKind = upgradeTo ?? lot.kind;
    relocatingParkingLot = lot;
    relocatingParkingIsUpgrade = upgradeTo != null && upgradeTo != lot.kind;
    ghostGridX = lot.gridX;
    ghostGridZ = lot.gridZ;
    ghostRotation = _rotationForEntrySide(lot.effectiveEntrySide);
    _focusGhost();
    _notifyBoth();
  }

  void startPlacingDecoration(DecorationKind kind, String name, double cost) {
    if (!isDecorationUnlocked(kind) || decorations.length >= GameController.maxDecorations) {
      return;
    }
    _clearPending();
    toolMode = WorldToolMode.placeDecoration;
    pendingDecoration = (kind, name, cost);
    ghostRotation = 0;
    final smart = _findSmartDecorationSpot();
    ghostGridX = smart.gx;
    ghostGridZ = smart.gz;
    _focusGhost();
    _notifyBoth();
  }

  (int, int) _ghostSize() {
    if (toolMode == WorldToolMode.placeBuilding && pendingBuildingType != null) {
      final data = kBusinessCatalog[pendingBuildingType!]!;
      return OutpostLayout.rotatedSize(data.gridW, data.gridD, ghostRotation);
    }
    if (toolMode == WorldToolMode.placeParking && pendingParkingKind != null) {
      final spec = kParkingLotCatalog[pendingParkingKind!]!;
      return OutpostLayout.rotatedSize(spec.gridW, spec.gridD, ghostRotation);
    }
    return (1, 1);
  }

  void rotateGhost() {
    if (toolMode != WorldToolMode.placeBuilding && toolMode != WorldToolMode.placeParking) {
      return;
    }
    ghostRotation = (ghostRotation + 1) & 3;
    _playTapFeedback();
    _notifyBoth();
  }

  void moveGhostToWorld(Vec3 worldPos) {
    final (cx, cz) = OutpostLayout.worldToCell(worldPos);
    final (w, d) = _ghostSize();
    final nextX = (cx - (w ~/ 2))
        .clamp(OutpostLayout.minGridX, OutpostLayout.maxGridX - w + 1)
        .toInt();
    final nextZ = (cz - (d ~/ 2))
        .clamp(OutpostLayout.minGridZ, OutpostLayout.maxGridZ - d + 1)
        .toInt();
    if (nextX != ghostGridX || nextZ != ghostGridZ) {
      ghostGridX = nextX;
      ghostGridZ = nextZ;
      _notifyBoth();
    }
  }

  bool confirmPlacement() {
    bool ok = false;
    switch (toolMode) {
      case WorldToolMode.placeBuilding:
        final type = pendingBuildingType;
        if (type == null) return false;
        ok = relocatingPlot != null
            ? relocatePlotTo(relocatingPlot!, ghostGridX, ghostGridZ,
                rotationQuarter: ghostRotation)
            : placeBuildingAt(type, ghostGridX, ghostGridZ, rotationQuarter: ghostRotation);
      case WorldToolMode.placeParking:
        final kind = pendingParkingKind;
        if (kind == null) return false;
        ok = relocatingParkingLot != null
            ? relocateParkingLotTo(
                relocatingParkingLot!,
                ghostGridX,
                ghostGridZ,
                rotationQuarter: ghostRotation,
                upgradeTo: relocatingParkingIsUpgrade ? kind : null,
              )
            : placeParkingLotAt(kind, ghostGridX, ghostGridZ, rotationQuarter: ghostRotation);
      case WorldToolMode.placeDecoration:
        final deco = pendingDecoration;
        if (deco == null) return false;
        ok = placeDecorationAt(deco.$1, deco.$2, deco.$3, ghostGridX, ghostGridZ);
      default:
        return false;
    }
    if (ok) cancelToolMode();
    return ok;
  }

  // --- Smart default spots ---

  Iterable<GridCell> _ownedCells() sync* {
    for (final p in worldGrid.ownedParcels) {
      final (minGx, maxGx, minGz, maxGz) = OutpostLayout.parcelCellBounds(p.px, p.pz);
      for (int gz = minGz; gz <= maxGz; gz++) {
        for (int gx = minGx; gx <= maxGx; gx++) {
          yield GridCell(gx, gz);
        }
      }
    }
  }

  GridCell _focusCell() {
    final (gx, gz) = OutpostLayout.worldToCell(townFocus);
    return GridCell(gx, gz);
  }

  GridCell _findSmartBuildingSpot(BusinessType type) {
    final focus = _focusCell();
    GridCell? best;
    double bestScore = double.negativeInfinity;
    for (final c in _ownedCells()) {
      final (valid, _) = validateBuildingPlacement(
        type: type,
        gridX: c.gx,
        gridZ: c.gz,
        rotationQuarter: 0,
      );
      if (!valid) continue;
      final report = roadNetwork.evaluateBuildingAccess(
        businessType: type,
        gridX: c.gx,
        gridZ: c.gz,
        rotationQuarter: 0,
        parkingLots: parkingLots,
      );
      final score = report.score * 10.0 - c.manhattanTo(focus) * 0.05;
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best ?? GridCell(focus.gx + 3, focus.gz);
  }

  int _rotationForEntrySide(LotEntrySide side) => switch (side) {
        LotEntrySide.south => 0,
        LotEntrySide.west => 1,
        LotEntrySide.north => 2,
        LotEntrySide.east => 3,
      };

  (GridCell, int) _findSmartParkingSpotWithRot(ParkingLotKind kind) {
    final spec = kParkingLotCatalog[kind]!;
    final cart = cartPlot;
    final entrance = cart.isBuilt ? cart.entranceCell : _focusCell();
    GridCell? best;
    int bestRot = 0;
    double bestScore = double.negativeInfinity;

    for (final c in _ownedCells()) {
      for (final rot in const [0, 3, 1, 2]) {
        final (w, d) = OutpostLayout.rotatedSize(spec.gridW, spec.gridD, rot);
        final (valid, _) = validateParkingPlacement(
          kind: kind,
          gridX: c.gx,
          gridZ: c.gz,
          rotationQuarter: rot,
        );
        if (!valid) continue;

        bool blocksAccessCorridor = false;
        int minDist = 1 << 20;
        for (int dx = 0; dx < w; dx++) {
          for (int dz = 0; dz < d; dz++) {
            final cell = GridCell(c.gx + dx, c.gz + dz);
            if (cell.gx == entrance.gx && cell.gz >= entrance.gz) {
              blocksAccessCorridor = true;
            }
            minDist = math.min(minDist, cell.manhattanTo(entrance));
          }
        }
        if (blocksAccessCorridor) continue;

        // Count connected road tiles along the front entry edge for this rotation
        final entryBorder = switch (rot & 3) {
          0 => [for (int dx = 0; dx < w; dx++) GridCell(c.gx + dx, c.gz + d)],
          1 => [for (int dz = 0; dz < d; dz++) GridCell(c.gx - 1, c.gz + dz)],
          2 => [for (int dx = 0; dx < w; dx++) GridCell(c.gx + dx, c.gz - 1)],
          _ => [for (int dz = 0; dz < d; dz++) GridCell(c.gx + w, c.gz + dz)],
        };
        int roadContacts = 0;
        int corridorContacts = 0;
        for (final rc in entryBorder) {
          if (roadNetwork.isRoadConnectedToHighway(rc)) roadContacts++;
          if (rc.gx == entrance.gx && rc.gz >= entrance.gz) corridorContacts++;
        }

        final score = roadContacts * 60.0 + corridorContacts * 12.0 - minDist;
        if (score > bestScore) {
          bestScore = score;
          best = c;
          bestRot = rot;
        }
      }
    }
    return (best ?? GridCell(entrance.gx - 2, entrance.gz), bestRot);
  }

  GridCell _findSmartDecorationSpot() {
    final focus = _focusCell();
    GridCell? best;
    int bestDist = 1 << 20;
    for (final c in _ownedCells()) {
      if (!validateDecorationPlacement(c.gx, c.gz).$1) continue;
      final dist = c.manhattanTo(focus);
      if (dist >= 2 && dist < bestDist) {
        bestDist = dist;
        best = c;
      }
    }
    return best ?? focus;
  }

  // --- Land Parcels ---

  int get ownedParcelCount => worldGrid.ownedParcels.length;
  double get nextParcelPrice => worldGrid.nextParcelPrice();
  bool get canBuyMoreLand => ownedParcelCount < stageInfo.maxParcels;

  LandParcel? parcelAtWorld(Vec3 worldPos) {
    final (gx, gz) = OutpostLayout.worldToCell(worldPos);
    if (!OutpostLayout.isCellInMap(gx, gz)) return null;
    final (px, pz) = OutpostLayout.parcelOf(gx, gz);
    return LandParcel(px, pz);
  }

  bool buyParcel(LandParcel parcel) {
    if (worldGrid.ownedParcels.contains(parcel)) return false;
    if (!worldGrid.isParcelPurchasable(parcel)) {
      _floatNotice(parcel.center + const Vec3(0, 2.0, 0), 'MUST BORDER YOUR LAND');
      return false;
    }
    if (!canBuyMoreLand) {
      _floatNotice(
        parcel.center + const Vec3(0, 2.0, 0),
        'STAGE ${outpostStage + 1} FOR MORE LAND',
      );
      return false;
    }
    final price = nextParcelPrice;
    if (cash < price) {
      notifyShortfall(parcel.center + const Vec3(0, 1.6, 0), price - cash);
      return false;
    }
    cash -= price;
    worldGrid.buyParcel(parcel);
    _playTapFeedback(heavy: true);
    _spawnConstructionDust(parcel.center, count: 14);
    _floatNotice(parcel.center + const Vec3(0, 2.4, 0), 'LAND +1!', color: DesertPalette.gold);
    saveState();
    _notifyBoth();
    return true;
  }

  // --- Road Line Tool ---

  /// Tap 1 sets the start tile, later taps move the end tile (preview updates live).
  void roadLineTap(GridCell cell) {
    if (roadLineStart == null) {
      roadLineStart = cell;
      roadLineEnd = cell;
    } else {
      roadLineEnd = cell;
    }
    _playTapFeedback();
    _notifyBoth();
  }

  void setRoadLine(GridCell start, GridCell end) {
    roadLineStart = start;
    roadLineEnd = end;
    _notifyBoth();
  }

  void clearRoadLine() {
    roadLineStart = null;
    roadLineEnd = null;
    _notifyBoth();
  }

  RoadLinePreview get roadLinePreview {
    final a = roadLineStart;
    final b = roadLineEnd;
    if (toolMode != WorldToolMode.paintRoad || a == null || b == null) {
      return RoadLinePreview.empty;
    }
    return computeRoadLinePreview(a, b);
  }

  RoadLinePreview computeRoadLinePreview(GridCell a, GridCell b) {
    final cells = RoadNetwork.linePath(a, b);
    final build = <GridCell>[];
    final skip = <GridCell>[];
    final blocked = <GridCell>[];
    double cost = 0.0;
    String? reason;

    if (roadEraseMode) {
      for (final c in cells) {
        final tile = roadNetwork.tileAt(c);
        if (tile == null) {
          skip.add(c);
        } else {
          build.add(c);
          cost -= (kRoadTierCatalog[tile.tier]!.costPerTile * 0.5).roundToDouble();
        }
      }
      return RoadLinePreview(
        cells: cells,
        buildCells: build,
        skipCells: skip,
        blockedCells: blocked,
        cost: cost,
        blockReason: build.isEmpty ? 'No road tiles on this line' : null,
      );
    }

    final targetCost = kRoadTierCatalog[activeRoadTier]!.costPerTile;
    for (final c in cells) {
      if (!OutpostLayout.isCellInMap(c.gx, c.gz)) {
        blocked.add(c);
        reason ??= 'Outside the desert map';
        continue;
      }
      if (worldGrid.isOccupied(c)) {
        blocked.add(c);
        reason ??= 'Blocked by a building, lot or prop';
        continue;
      }
      final existing = roadNetwork.tileAt(c);
      if (existing != null && existing.tier.index >= activeRoadTier.index) {
        skip.add(c);
        continue;
      }
      final prevCost = existing != null ? kRoadTierCatalog[existing.tier]!.costPerTile : 0.0;
      build.add(c);
      cost += math.max(2.0, targetCost - prevCost);
    }

    final currentJunctions = roadNetwork.highwayTurnOffCount;
    final nextJunctions = roadNetwork.highwayTurnOffCountWith(build);
    if (nextJunctions > currentJunctions && nextJunctions > stageInfo.maxHighwayTurnOffs) {
      reason ??= 'Stage $outpostStage allows ${stageInfo.maxHighwayTurnOffs} highway junction(s)';
    }
    if (build.isEmpty) reason ??= 'Already built at this tier';

    return RoadLinePreview(
      cells: cells,
      buildCells: build,
      skipCells: skip,
      blockedCells: blocked,
      cost: cost,
      blockReason: reason,
    );
  }

  bool confirmRoadLine() {
    final preview = roadLinePreview;
    if (!preview.isValid) {
      if (preview.blockReason != null && preview.cells.isNotEmpty) {
        _floatNotice(preview.cells.last.worldCenter + const Vec3(0, 1.4, 0), 'BLOCKED');
      }
      return false;
    }

    final parkingBefore = totalParkingSpaces;
    if (roadEraseMode) {
      for (final c in preview.buildCells) {
        roadNetwork.removeTile(c);
      }
      cash += -preview.cost;
    } else {
      if (cash < preview.cost) {
        notifyShortfall(
          preview.buildCells.last.worldCenter + const Vec3(0, 1.0, 0),
          preview.cost - cash,
        );
        return false;
      }
      cash -= preview.cost;
      for (final c in preview.buildCells) {
        roadNetwork.setTile(c, activeRoadTier);
      }
    }

    _recomputeNetwork();
    _playTapFeedback(heavy: true);
    for (int i = 0; i < preview.buildCells.length; i += 3) {
      _spawnConstructionDust(preview.buildCells[i].worldCenter, count: 3);
    }
    _floatNotice(
      preview.buildCells.last.worldCenter + const Vec3(0, 1.8, 0),
      roadEraseMode
          ? '+\$${(-preview.cost).toInt()} REFUND'
          : '${preview.buildCells.length} TILES BUILT',
      color: DesertPalette.gold,
    );
    if (parkingBefore == 0 && totalParkingSpaces > 0) {
      _dispatchImmediateCustomerToLot(parkingLots.firstWhere((l) => l.isConnected));
    }
    roadLineStart = null;
    roadLineEnd = null;
    saveState();
    _notifyBoth();
    return true;
  }

  /// Convenience used by tests & onboarding: preview + build a road line in one call.
  bool buildRoadLine(GridCell start, GridCell end, {RoadTier? tier}) {
    if (toolMode != WorldToolMode.paintRoad) enterRoadPaintMode(tier: tier);
    if (tier != null) setRoadBrush(tier);
    roadEraseMode = false;
    setRoadLine(start, end);
    return confirmRoadLine();
  }

  /// One-tap onboarding: previews a straight Dirt access road from Route 163 to the cart.
  void suggestAccessRoad() {
    final cart = cartPlot;
    final entrance = cart.entranceCell;
    enterRoadPaintMode(tier: RoadTier.dirt);
    roadLineStart = GridCell(entrance.gx, OutpostLayout.highwayEntryRowZ);
    roadLineEnd = entrance;
    final a = roadLineStart!.worldCenter;
    final b = entrance.worldCenter;
    final mid = a.lerp(b, 0.5);
    camera.focusOn(
      mid + const Vec3(0, 1.0, 0),
      distance: math.max(34.0, (a - b).length * 1.25),
      pitch: math.max(camera.pitch, 0.9),
    );
    _notifyBoth();
  }

  bool get needsAccessRoad =>
      roadNetwork.highwayTurnOffCount == 0 ||
      !plots.any((p) => p.isBuilt && p.access.hasDirectRoad);

  // --- Placing Stores, Parking Lots & Decorations ---

  bool placeBuildingAt(
    BusinessType type,
    int gridX,
    int gridZ, {
    int rotationQuarter = 0,
  }) {
    final plot = plots.firstWhere((p) => p.businessType == type);
    if (plot.isBuilt || !isPlotUnlocked(plot)) return false;
    final (valid, _) = validateBuildingPlacement(
      type: type,
      gridX: gridX,
      gridZ: gridZ,
      rotationQuarter: rotationQuarter,
    );
    if (!valid) return false;
    final data = plot.data;
    if (cash < data.purchaseCost) return false;

    cash -= data.purchaseCost;
    plot.gridX = gridX;
    plot.gridZ = gridZ;
    plot.rotationQuarter = rotationQuarter & 3;
    plot.isBuilt = true;
    plot.level = 1;
    plot.buildPopTimer = 1.0;
    plot.bounceTimer = 0.38;
    _recomputeNetwork();
    _playTapFeedback(heavy: true);
    _spawnConstructionDust(plot.position, count: 14);
    floatingCash.add(
      FloatingCash(
        position: plot.position + const Vec3(0, 2.8, 0),
        text: plot.access.score > 0 ? 'BUILT! ${plot.access.percent}%' : 'BUILT! ADD ROAD',
        color: plot.access.score > 0 ? DesertPalette.gold : const Color(0xFFFFB899),
        duration: 1.5,
      ),
    );
    saveState();
    _notifyBoth();
    return true;
  }

  bool relocatePlotTo(
    PlotState plot,
    int gridX,
    int gridZ, {
    int rotationQuarter = 0,
  }) {
    if (!plot.isBuilt) return false;
    final (valid, _) = validateBuildingPlacement(
      type: plot.businessType,
      gridX: gridX,
      gridZ: gridZ,
      rotationQuarter: rotationQuarter,
      ignorePlot: plot,
    );
    if (!valid) return false;

    plot.gridX = gridX;
    plot.gridZ = gridZ;
    plot.rotationQuarter = rotationQuarter & 3;
    plot.bounceTimer = 0.36;
    _recomputeNetwork();
    _playTapFeedback(heavy: true);
    _spawnConstructionDust(plot.position, count: 10);
    _floatNotice(
      plot.position + const Vec3(0, 2.6, 0),
      'MOVED · ${plot.access.percent}%',
      color: DesertPalette.neonTurquoise,
    );
    saveState();
    _notifyBoth();
    return true;
  }

  bool placeParkingLotAt(
    ParkingLotKind kind,
    int gridX,
    int gridZ, {
    int rotationQuarter = 0,
  }) {
    if (!isParkingKindUnlocked(kind)) return false;
    final (valid, _) = validateParkingPlacement(
      kind: kind,
      gridX: gridX,
      gridZ: gridZ,
      rotationQuarter: rotationQuarter,
    );
    if (!valid) return false;
    final spec = kParkingLotCatalog[kind]!;
    if (cash < spec.cost) return false;

    final parkingBefore = totalParkingSpaces;
    cash -= spec.cost;
    final lot = ParkingLotEntity(
      id: 'lot_${_nextEntityId++}',
      kind: kind,
      gridX: gridX,
      gridZ: gridZ,
      rotationQuarter: rotationQuarter & 3,
    );
    parkingLots.add(lot);
    _recomputeNetwork();
    _playTapFeedback(heavy: true);
    _spawnConstructionDust(lot.position, count: 12);
    floatingCash.add(
      FloatingCash(
        position: lot.position + const Vec3(0, 2.2, 0),
        text: lot.isConnected ? '${spec.name.toUpperCase()}!' : 'CONNECT A ROAD!',
        color: lot.isConnected ? DesertPalette.gold : const Color(0xFFFFB899),
        duration: 1.5,
      ),
    );
    if (parkingBefore == 0 && lot.isConnected) {
      _dispatchImmediateCustomerToLot(lot);
    }
    saveState();
    _notifyBoth();
    return true;
  }

  bool placeDecorationAt(
    DecorationKind kind,
    String name,
    double cost,
    int gridX,
    int gridZ,
  ) {
    if (!isDecorationUnlocked(kind)) return false;
    if (decorations.length >= GameController.maxDecorations) return false;
    if (!validateDecorationPlacement(gridX, gridZ).$1) return false;
    if (cash < cost) return false;

    cash -= cost;
    final spot = OutpostLayout.cellCenter(gridX, gridZ);
    decorations.add(
      PlacedDecoration(
        id: 'deco_${_nextEntityId++}',
        kind: kind,
        position: spot,
        name: name,
        cost: cost,
        gridX: gridX,
        gridZ: gridZ,
      ),
    );
    _recomputeNetwork();
    _playTapFeedback(heavy: true);
    _spawnConstructionDust(spot, count: 8);
    _floatNotice(
      spot + const Vec3(0, 2.0, 0),
      kind == DecorationKind.woodenSignpost ? '+8% TRAFFIC!' : '+4% TIPS!',
      color: DesertPalette.goldPopup,
    );
    saveState();
    _notifyBoth();
    return true;
  }

  /// Places a decoration at the nearest free owned tile to the town (no ghost).
  bool placeDecoration(DecorationKind kind, String name, double cost) {
    final spot = _findSmartDecorationSpot();
    return placeDecorationAt(kind, name, cost, spot.gx, spot.gz);
  }

  bool get canAddMoreDecorations => decorations.length < GameController.maxDecorations;

  /// Net upgrade cost for upgrading [lot] to its next tier (`Dirt -> Gravel -> Paved`).
  double parkingLotUpgradeCost(ParkingLotEntity lot) {
    final next = lot.nextUpgradeKind;
    if (next == null) return 0.0;
    return math.max(20.0, kParkingLotCatalog[next]!.cost - lot.spec.cost);
  }

  /// `null` if [lot] is progression-eligible to upgrade now, otherwise a short lock label.
  String? parkingLotUpgradeLockReason(ParkingLotEntity lot) {
    final next = lot.nextUpgradeKind;
    if (next == null) return 'MAX';
    final nextSpec = kParkingLotCatalog[next]!;
    if (!isParkingKindUnlocked(next)) return 'STAGE ${nextSpec.unlockStage}';
    return null;
  }

  bool canUpgradeParkingLotByProgression(ParkingLotEntity lot) =>
      parkingLotUpgradeLockReason(lot) == null;

  /// Upgrades an existing [lot] in place (`Dirt -> Gravel -> Paved`), automatically
  /// expanding by 1 tile along the road axis (or opening move-to-upgrade if boxed in).
  bool upgradeParkingLot(ParkingLotEntity lot) {
    final lock = parkingLotUpgradeLockReason(lot);
    if (lock != null) {
      _floatNotice(lot.position + const Vec3(0, 2.2, 0), lock);
      return false;
    }
    final nextKind = lot.nextUpgradeKind!;
    final cost = parkingLotUpgradeCost(lot);
    if (cash < cost) {
      notifyShortfall(lot.position + const Vec3(0, 1.8, 0), cost - cash);
      return false;
    }

    final wasConnected = lot.isConnected;
    const shifts = <(int, int)>[
      (0, 0),
      (-1, 0),
      (0, -1),
      (1, 0),
      (0, 1),
      (-1, -1),
      (1, -1),
      (-2, 0),
      (0, -2),
    ];

    (int gx, int gz, int rot)? bestChoice;
    double bestScore = double.negativeInfinity;

    for (final rot in const [0, 1, 2, 3]) {
      final (w, d) = OutpostLayout.rotatedSize(
        kParkingLotCatalog[nextKind]!.gridW,
        kParkingLotCatalog[nextKind]!.gridD,
        rot,
      );
      for (final (sx, sz) in shifts) {
        final gx = lot.gridX + sx;
        final gz = lot.gridZ + sz;
        final (valid, _) = validateParkingPlacement(
          kind: nextKind,
          gridX: gx,
          gridZ: gz,
          rotationQuarter: rot,
          ignoreLot: lot,
        );
        if (!valid) continue;

        // Count connected road contacts on each side, especially the primary wide side
        int totalRoadContacts = 0;
        int primaryContacts = 0;
        final borders = <(int, List<GridCell>)>[
          (0, [for (int dx = 0; dx < w; dx++) GridCell(gx + dx, gz + d)]),
          (1, [for (int dz = 0; dz < d; dz++) GridCell(gx - 1, gz + dz)]),
          (2, [for (int dx = 0; dx < w; dx++) GridCell(gx + dx, gz - 1)]),
          (3, [for (int dz = 0; dz < d; dz++) GridCell(gx + w, gz + dz)]),
        ];
        for (final (rSide, cells) in borders) {
          for (final rc in cells) {
            if (roadNetwork.isRoadConnectedToHighway(rc)) {
              totalRoadContacts++;
              if (rSide == rot) primaryContacts++;
            }
          }
        }
        if (wasConnected && totalRoadContacts == 0) continue;

        final score = primaryContacts * 50.0 +
            totalRoadContacts * 20.0 -
            (sx.abs() + sz.abs()) * 4.0;
        if (score > bestScore) {
          bestScore = score;
          bestChoice = (gx, gz, rot);
        }
      }
    }

    if (bestChoice != null) {
      return relocateParkingLotTo(
        lot,
        bestChoice.$1,
        bestChoice.$2,
        rotationQuarter: bestChoice.$3,
        upgradeTo: nextKind,
      );
    }

    // Tightly boxed in on both sides: let the player pick where to place the expanded lot!
    startRelocatingParkingLot(lot, upgradeTo: nextKind);
    _floatNotice(lot.position + const Vec3(0, 2.4, 0), 'MOVE TO FIT BIGGER LOT');
    return false;
  }

  bool relocateParkingLotTo(
    ParkingLotEntity lot,
    int gridX,
    int gridZ, {
    int rotationQuarter = 0,
    ParkingLotKind? upgradeTo,
  }) {
    final targetKind = upgradeTo ?? lot.kind;
    final isUpgrade = upgradeTo != null && upgradeTo != lot.kind;
    if (isUpgrade && !isParkingKindUnlocked(targetKind)) return false;

    final (valid, _) = validateParkingPlacement(
      kind: targetKind,
      gridX: gridX,
      gridZ: gridZ,
      rotationQuarter: rotationQuarter,
      ignoreLot: lot,
    );
    if (!valid) return false;

    final cost = isUpgrade
        ? math.max(20.0, kParkingLotCatalog[targetKind]!.cost - lot.spec.cost)
        : 0.0;
    if (cash < cost) {
      notifyShortfall(lot.position + const Vec3(0, 1.8, 0), cost - cash);
      return false;
    }

    cash -= cost;
    lot.kind = targetKind;
    lot.gridX = gridX;
    lot.gridZ = gridZ;
    lot.rotationQuarter = rotationQuarter & 3;
    _evictParkedVehiclesOnLot(lot.id);
    _recomputeNetwork();
    _playTapFeedback(heavy: true);
    _spawnConstructionDust(lot.position, count: 14);
    _floatNotice(
      lot.position + const Vec3(0, 2.4, 0),
      isUpgrade ? '${lot.spec.name.toUpperCase()}!' : 'LOT MOVED!',
      color: isUpgrade ? DesertPalette.gold : DesertPalette.neonTurquoise,
    );
    saveState();
    _notifyBoth();
    return true;
  }

  bool removeParkingLot(ParkingLotEntity lot) {
    if (!parkingLots.contains(lot)) return false;
    final refund = (lot.spec.cost * 0.5).roundToDouble();
    final pos = lot.position;
    parkingLots.remove(lot);
    _evictParkedVehiclesOnLot(lot.id);
    cash += refund;
    _recomputeNetwork();
    _playTapFeedback();
    _floatNotice(
      pos + const Vec3(0, 1.8, 0),
      '+\$${refund.toInt()} REFUND',
      color: DesertPalette.sandLight,
    );
    saveState();
    _notifyBoth();
    return true;
  }

  void _evictParkedVehiclesOnLot(String lotId) {
    final evictedIds = <int>{};
    vehicles.removeWhere((v) {
      final match = v.parkingLotId == lotId;
      if (match) evictedIds.add(v.id);
      return match;
    });
    if (evictedIds.isNotEmpty) {
      visitors.removeWhere((vis) => evictedIds.contains(vis.vehicleId));
    }
  }

  /// Onboarding & quick helper: upgrades an existing lot if possible, otherwise places a new one.
  bool upgradeParking() {
    for (final lot in parkingLots) {
      if (canUpgradeParkingLotByProgression(lot) &&
          cash >= parkingLotUpgradeCost(lot)) {
        if (upgradeParkingLot(lot)) return true;
      }
    }
    final kind = isParkingKindUnlocked(ParkingLotKind.pavedLot) && parkingTier >= 2
        ? ParkingLotKind.pavedLot
        : (isParkingKindUnlocked(ParkingLotKind.gravelLot) && parkingTier >= 1
            ? ParkingLotKind.gravelLot
            : ParkingLotKind.dirtPullOff);
    final (spot, rot) = _findSmartParkingSpotWithRot(kind);
    return placeParkingLotAt(kind, spot.gx, spot.gz, rotationQuarter: rot);
  }

  /// Builds an unlocked plot at its default layout spot (or the best free spot).
  bool buildOnPlot(PlotState plot) {
    if (plot.isBuilt) return false;
    final (valid, _) = validateBuildingPlacement(
      type: plot.businessType,
      gridX: plot.gridX,
      gridZ: plot.gridZ,
      rotationQuarter: plot.rotationQuarter,
    );
    if (valid) {
      return placeBuildingAt(
        plot.businessType,
        plot.gridX,
        plot.gridZ,
        rotationQuarter: plot.rotationQuarter,
      );
    }
    final smart = _findSmartBuildingSpot(plot.businessType);
    return placeBuildingAt(plot.businessType, smart.gx, smart.gz);
  }
}
