part of 'game_controller.dart';

/// Save schema v3 (land parcels, road grid, placed lots, store coordinates, monotonic stage)
/// with automatic migration of older small-map saves into the new open-desert world.
extension GameControllerPersistence on GameController {
  static const int _saveVersion = 3;
  static const Map<String, double> _legacyRoadCost = {
    'dirt': 10,
    'gravel': 24,
    'paved': 48,
  };

  void saveState() {
    if (!enablePersistence) return;
    final map = <String, Object?>{
      'version': _saveVersion,
      'preset': activePreset.name,
      'cash': cash,
      'totalCashEarned': totalCashEarned,
      'totalCustomersServed': totalCustomersServed,
      'totalTaps': totalTaps,
      'tapUpgradeLevel': tapUpgradeLevel,
      'timeOfDay': timeOfDay,
      'autoDayNight': autoDayNight,
      'soundEnabled': soundEnabled,
      'highestStage': _highestStage,
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
      'parcels': [
        for (final p in worldGrid.ownedParcels) [p.px, p.pz],
      ],
      'plots': [
        for (final p in plots)
          {
            'id': p.id,
            'isBuilt': p.isBuilt,
            'level': p.level,
            'gridX': p.gridX,
            'gridZ': p.gridZ,
            'rot': p.rotationQuarter,
          },
      ],
      'roads': [
        for (final tile in roadNetwork.tiles.values)
          {'gx': tile.cell.gx, 'gz': tile.cell.gz, 'tier': tile.tier.name},
      ],
      'parkingLots': [
        for (final lot in parkingLots)
          {'kind': lot.kind.name, 'gx': lot.gridX, 'gz': lot.gridZ, 'rot': lot.rotationQuarter},
      ],
      'decorations': [
        for (final d in decorations)
          {'kind': d.kind.name, 'name': d.name, 'cost': d.cost, 'gx': d.gridX, 'gz': d.gridZ},
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
      final version = (map['version'] as num?)?.toInt() ?? 1;
      final legacy = version < _saveVersion;

      final loadedPreset = (map['preset'] as String?) == OutpostPreset.fullCity.name
          ? OutpostPreset.fullCity
          : OutpostPreset.stageOneCareer;
      if (loadedPreset != activePreset) _initWorld(loadedPreset);

      cash = (map['cash'] as num?)?.toDouble() ?? cash;
      totalCashEarned = (map['totalCashEarned'] as num?)?.toDouble() ?? totalCashEarned;
      totalCustomersServed = (map['totalCustomersServed'] as num?)?.toInt() ?? 0;
      totalTaps = (map['totalTaps'] as num?)?.toInt() ?? 0;
      tapUpgradeLevel = (map['tapUpgradeLevel'] as num?)?.toInt() ?? 1;
      timeOfDay = (map['timeOfDay'] as num?)?.toDouble() ?? 0.37;
      autoDayNight = (map['autoDayNight'] as bool?) ?? true;
      soundEnabled = (map['soundEnabled'] as bool?) ?? true;

      // Built status & levels always carry over.
      final savedPlots = (map['plots'] as List<dynamic>?) ?? const [];
      for (final entry in savedPlots.whereType<Map<String, dynamic>>()) {
        final id = entry['id'] as String?;
        for (final p in plots) {
          if (p.id != id) continue;
          p.isBuilt = (entry['isBuilt'] as bool?) ?? p.isBuilt;
          p.level = ((entry['level'] as num?)?.toInt() ?? p.level).clamp(1, 5);
          if (!legacy) {
            if (entry['gridX'] is num) p.gridX = (entry['gridX'] as num).toInt();
            if (entry['gridZ'] is num) p.gridZ = (entry['gridZ'] as num).toInt();
            if (entry['rot'] is num) p.rotationQuarter = (entry['rot'] as num).toInt() & 3;
          }
        }
      }

      if (legacy) {
        _migrateLegacyLayout(map, loadedPreset);
      } else {
        _loadV3Layout(map);
      }

      _recomputeNetwork();

      final claimedIds =
          (map['claimedMilestones'] as List<dynamic>?)?.whereType<String>().toSet() ??
              const <String>{};
      for (final m in milestones) {
        m.claimed = claimedIds.contains(m.id);
      }

      final savedAtMs = (map['savedAtMs'] as num?)?.toInt();
      if (savedAtMs != null && incomePerMinute > 0) {
        final elapsedMin = ((DateTime.now().millisecondsSinceEpoch - savedAtMs) / 60000.0)
            .floor()
            .clamp(0, 480);
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

  void _loadV3Layout(Map<String, dynamic> map) {
    final parcels = (map['parcels'] as List<dynamic>?) ?? const [];
    final owned = <LandParcel>[
      for (final e in parcels.whereType<List<dynamic>>())
        if (e.length == 2 && e[0] is num && e[1] is num)
          LandParcel((e[0] as num).toInt(), (e[1] as num).toInt()),
    ];
    worldGrid.resetOwnership(
      owned.isNotEmpty
          ? owned
          : [for (final (px, pz) in OutpostLayout.starterParcels) LandParcel(px, pz)],
    );

    roadNetwork.clear();
    for (final e in ((map['roads'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()) {
      final gx = (e['gx'] as num?)?.toInt();
      final gz = (e['gz'] as num?)?.toInt();
      if (gx == null || gz == null || !OutpostLayout.isCellInMap(gx, gz)) continue;
      final tier = RoadTier.values.firstWhere(
        (t) => t.name == e['tier'],
        orElse: () => RoadTier.dirt,
      );
      roadNetwork.setTile(GridCell(gx, gz), tier);
    }

    parkingLots.clear();
    for (final e in ((map['parkingLots'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()) {
      final gx = (e['gx'] as num?)?.toInt();
      final gz = (e['gz'] as num?)?.toInt();
      if (gx == null || gz == null) continue;
      final kind = ParkingLotKind.values.firstWhere(
        (k) => k.name == e['kind'],
        orElse: () => ParkingLotKind.dirtPullOff,
      );
      final lot = ParkingLotEntity(
        id: 'lot_${_nextEntityId++}',
        kind: kind,
        gridX: gx,
        gridZ: gz,
        rotationQuarter: ((e['rot'] as num?)?.toInt() ?? 0) & 3,
      );
      // If an older 1-tile-deep lot now overlaps a road or store after expanding to 2 tiles deep,
      // nudge it by 1 tile onto free sand so existing saves stay overlap-free!
      final plotCells = <GridCell>{
        for (final p in plots)
          if (p.isBuilt) ...p.occupiedCells,
      };
      bool overlaps(ParkingLotEntity candidate) => candidate.occupiedCells.any(
            (c) => roadNetwork.hasRoadAt(c) || plotCells.contains(c),
          );
      if (overlaps(lot)) {
        for (final (dx, dz) in const [
          (0, -1),
          (-1, 0),
          (0, 1),
          (1, 0),
          (-1, -1),
        ]) {
          lot.gridX = gx + dx;
          lot.gridZ = gz + dz;
          if (!overlaps(lot)) break;
        }
      }
      parkingLots.add(lot);
    }

    decorations.clear();
    for (final e in ((map['decorations'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()) {
      if (decorations.length >= GameController.maxDecorations) break;
      final gx = (e['gx'] as num?)?.toInt();
      final gz = (e['gz'] as num?)?.toInt();
      if (gx == null || gz == null) continue;
      final kind = DecorationKind.values.firstWhere(
        (k) => k.name == e['kind'],
        orElse: () => DecorationKind.saguaroCluster,
      );
      decorations.add(
        PlacedDecoration(
          id: 'deco_${_nextEntityId++}',
          kind: kind,
          position: OutpostLayout.cellCenter(gx, gz),
          name: (e['name'] as String?) ?? 'Prop',
          cost: (e['cost'] as num?)?.toDouble() ?? 35.0,
          gridX: gx,
          gridZ: gz,
        ),
      );
    }

    _highestStage = ((map['highestStage'] as num?)?.toInt() ?? 1).clamp(1, 6);
  }

  /// v1/v2 saves used a tiny highway-side grid. Keep all progress (cash, levels, milestones),
  /// move built stores onto the new desert layout, grant the land they need, and refund
  /// old roads, lots & props so the player can rebuild them in the open desert.
  void _migrateLegacyLayout(Map<String, dynamic> map, OutpostPreset preset) {
    if (preset == OutpostPreset.fullCity) return; // Full City already ships the new layout.

    double refund = 0.0;
    for (final e in ((map['roads'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()) {
      refund += GameControllerPersistence._legacyRoadCost[e['tier']] ?? 10.0;
    }
    for (final e in ((map['parkingLots'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()) {
      final kind = ParkingLotKind.values.firstWhere(
        (k) => k.name == e['kind'],
        orElse: () => ParkingLotKind.dirtPullOff,
      );
      refund += kParkingLotCatalog[kind]!.cost;
    }
    for (final e in ((map['decorations'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()) {
      refund += (e['cost'] as num?)?.toDouble() ?? 35.0;
    }
    // Legacy v1 saves stored a single parking tier instead of placed lots.
    final legacyTier = (map['parkingTier'] as num?)?.toInt() ?? 0;
    if (map['parkingLots'] == null && legacyTier > 0) {
      refund += const [0.0, 40.0, 180.0, 550.0][legacyTier.clamp(0, 3)];
    }

    final owned = <LandParcel>{
      for (final (px, pz) in OutpostLayout.starterParcels) LandParcel(px, pz),
    };
    final useCityLayout = plots.where((p) => p.isBuilt).length > 1;
    for (final p in plots) {
      if (!p.isBuilt) continue;
      final (gx, gz) = (p.id == 'vendor' && !useCityLayout)
          ? GameController._careerCartCell
          : GameController._cityLayout[p.id]!;
      p.gridX = gx;
      p.gridZ = gz;
      p.rotationQuarter = 0;
      for (final c in p.occupiedCells) {
        final (px, pz) = OutpostLayout.parcelOf(c.gx, c.gz);
        owned.add(LandParcel(px, pz));
      }
    }
    worldGrid.resetOwnership(owned);
    roadNetwork.clear();
    parkingLots.clear();
    decorations.clear();
    _highestStage = 1;

    if (refund > 0) {
      cash += refund;
      floatingCash.add(
        FloatingCash(
          position: cartPlot.position + const Vec3(0, 4.0, 0),
          text: 'NEW DESERT MAP! +\$${refund.toInt()} REFUND',
          color: DesertPalette.gold,
          duration: 3.0,
        ),
      );
    }
  }
}
