import 'dart:collection';
import 'dart:math' as math;

import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../world/outpost_layout.dart';

/// Manages the player-built desert road grid, highway turn-offs, parking
/// connectivity, BFS/A* car & visitor pathfinding, and per-store Road Access scoring.
class RoadNetwork {
  final Map<GridCell, RoadTile> tiles = <GridCell, RoadTile>{};

  // Cached BFS results from Route 163 entry cells (recomputed on any layout change)
  final Map<GridCell, int> _roadDistFromHighway = <GridCell, int>{};
  final Map<GridCell, GridCell?> _roadParent = <GridCell, GridCell?>{};
  final Map<GridCell, RoadTier> _pathMinTier = <GridCell, RoadTier>{};

  int _version = 0;
  int get version => _version;

  void clear() {
    tiles.clear();
    _roadDistFromHighway.clear();
    _roadParent.clear();
    _pathMinTier.clear();
    _version++;
  }

  RoadTile? tileAt(GridCell cell) => tiles[cell];
  bool hasRoadAt(GridCell cell) => tiles.containsKey(cell);

  int get roadCount => tiles.length;
  int get pavedRoadCount => tiles.values.where((t) => t.tier == RoadTier.paved).length;
  int get gravelOrBetterCount => tiles.values.where((t) => t.tier != RoadTier.dirt).length;

  /// Number of separate highway junctions: contiguous runs of road tiles bordering Route 163.
  /// (A frontage road running along the highway counts as ONE junction, not one per tile.)
  int get highwayTurnOffCount {
    final xs = tiles.keys
        .where((c) => c.gz == OutpostLayout.highwayEntryRowZ)
        .map((c) => c.gx)
        .toList()
      ..sort();
    int runs = 0;
    int? prev;
    for (final x in xs) {
      if (prev == null || x != prev + 1) runs++;
      prev = x;
    }
    return runs;
  }

  /// Junction count if [extra] tiles were added (used to validate road previews).
  int highwayTurnOffCountWith(Iterable<GridCell> extra) {
    final set = <int>{
      for (final c in tiles.keys)
        if (c.gz == OutpostLayout.highwayEntryRowZ) c.gx,
      for (final c in extra)
        if (c.gz == OutpostLayout.highwayEntryRowZ) c.gx,
    };
    final xs = set.toList()..sort();
    int runs = 0;
    int? prev;
    for (final x in xs) {
      if (prev == null || x != prev + 1) runs++;
      prev = x;
    }
    return runs;
  }

  /// Straight or L-shaped tile path between two cells (longer axis first).
  static List<GridCell> linePath(GridCell a, GridCell b) {
    final cells = <GridCell>[];
    final dx = b.gx - a.gx;
    final dz = b.gz - a.gz;
    final sx = dx.sign;
    final sz = dz.sign;
    if (dx.abs() >= dz.abs()) {
      for (int i = 0; i <= dx.abs(); i++) {
        cells.add(GridCell(a.gx + i * sx, a.gz));
      }
      for (int j = 1; j <= dz.abs(); j++) {
        cells.add(GridCell(b.gx, a.gz + j * sz));
      }
    } else {
      for (int j = 0; j <= dz.abs(); j++) {
        cells.add(GridCell(a.gx, a.gz + j * sz));
      }
      for (int i = 1; i <= dx.abs(); i++) {
        cells.add(GridCell(a.gx + i * sx, b.gz));
      }
    }
    return cells;
  }

  /// Offsets a driving polyline to the right-hand lane (drive-on-right).
  static List<Vec3> offsetPathRight(List<Vec3> pts, double offset) {
    if (pts.length < 2) return List<Vec3>.of(pts);
    final out = <Vec3>[];
    for (int i = 0; i < pts.length; i++) {
      final prev = i > 0 ? pts[i - 1] : pts[i];
      final next = i < pts.length - 1 ? pts[i + 1] : pts[i];
      double dx = next.x - prev.x;
      double dz = next.z - prev.z;
      final len = math.sqrt(dx * dx + dz * dz);
      if (len < 1e-6) {
        out.add(pts[i]);
        continue;
      }
      dx /= len;
      dz /= len;
      // Right of forward (dx, dz) on the XZ plane is (-dz, dx).
      out.add(Vec3(pts[i].x - dz * offset, pts[i].y, pts[i].z + dx * offset));
    }
    return out;
  }

  RoadTier? get highestRoadTier {
    if (tiles.isEmpty) return null;
    if (tiles.values.any((t) => t.tier == RoadTier.paved)) return RoadTier.paved;
    if (tiles.values.any((t) => t.tier == RoadTier.gravel)) return RoadTier.gravel;
    return RoadTier.dirt;
  }

  void setTile(GridCell cell, RoadTier tier) {
    tiles[cell] = RoadTile(cell: cell, tier: tier);
    _version++;
  }

  RoadTile? removeTile(GridCell cell) {
    final removed = tiles.remove(cell);
    if (removed != null) _version++;
    return removed;
  }

  bool isRoadConnectedToHighway(GridCell cell) => _roadDistFromHighway.containsKey(cell);

  /// Recomputes road graph connectivity from Route 163, updates every parking lot's
  /// `isConnected` & `driveInPath`, and evaluates every built store's `RoadAccessReport`.
  void recompute({
    required List<PlotState> plots,
    required List<ParkingLotEntity> parkingLots,
    required List<PlacedDecoration> decorations,
  }) {
    _roadDistFromHighway.clear();
    _roadParent.clear();
    _pathMinTier.clear();

    // 1. Multi-source BFS from every road tile touching Route 163 (gz == highwayEntryRowZ)
    final queue = Queue<GridCell>();
    for (final entry in tiles.entries) {
      if (entry.key.gz == OutpostLayout.highwayEntryRowZ) {
        _roadDistFromHighway[entry.key] = 0;
        _roadParent[entry.key] = null;
        _pathMinTier[entry.key] = entry.value.tier;
        queue.add(entry.key);
      }
    }

    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      final curDist = _roadDistFromHighway[cur]!;
      final curTier = _pathMinTier[cur]!;

      for (final next in cur.neighbors4) {
        final nextTile = tiles[next];
        if (nextTile == null) continue;
        final nextTier = _minTier(curTier, nextTile.tier);
        final nextDist = curDist + 1;

        final prevDist = _roadDistFromHighway[next];
        final prevTier = _pathMinTier[next];
        final better = prevDist == null ||
            nextDist < prevDist ||
            (nextDist == prevDist && nextTier.index > (prevTier?.index ?? -1));

        if (better) {
          _roadDistFromHighway[next] = nextDist;
          _roadParent[next] = cur;
          _pathMinTier[next] = nextTier;
          queue.add(next);
        }
      }
    }

    // 2. Evaluate connectivity, road-facing entry side & driving paths for every placed lot
    for (final lot in parkingLots) {
      final (wCells, dCells) = lot.sizeCells;
      final cells = lot.occupiedCells;
      final directlyOnHighway =
          cells.any((c) => c.gz == OutpostLayout.highwayEntryRowZ);

      // Count how many connected road tiles touch each of the 4 sides of the lot,
      // preferring the long bay-opening edge so bays always face the road cleanly!
      LotEntrySide? bestSide;
      GridCell? bestAdjRoad;
      int bestSideContacts = 0;
      int bestDist = 999;
      RoadTier bestTier = RoadTier.dirt;

      final sideChecks = <(LotEntrySide, List<GridCell>)>[
        (
          LotEntrySide.south,
          [for (int dx = 0; dx < wCells; dx++) GridCell(lot.gridX + dx, lot.gridZ + dCells)],
        ),
        (
          LotEntrySide.north,
          [for (int dx = 0; dx < wCells; dx++) GridCell(lot.gridX + dx, lot.gridZ - 1)],
        ),
        (
          LotEntrySide.east,
          [for (int dz = 0; dz < dCells; dz++) GridCell(lot.gridX + wCells, lot.gridZ + dz)],
        ),
        (
          LotEntrySide.west,
          [for (int dz = 0; dz < dCells; dz++) GridCell(lot.gridX - 1, lot.gridZ + dz)],
        ),
      ];

      for (final (side, borderCells) in sideChecks) {
        int contacts = 0;
        GridCell? sideBestCell;
        int sideMinDist = 999;
        RoadTier sideBestTier = RoadTier.dirt;

        for (final rc in borderCells) {
          final dist = _roadDistFromHighway[rc];
          if (dist == null) continue;
          contacts++;
          final t = _pathMinTier[rc] ?? RoadTier.dirt;
          if (dist < sideMinDist || (dist == sideMinDist && t.index > sideBestTier.index)) {
            sideMinDist = dist;
            sideBestCell = rc;
            sideBestTier = t;
          }
        }
        if (contacts == 0 || sideBestCell == null) continue;

        final better = contacts > bestSideContacts ||
            (contacts == bestSideContacts && sideMinDist < bestDist) ||
            (contacts == bestSideContacts &&
                sideMinDist == bestDist &&
                sideBestTier.index > bestTier.index);
        if (better) {
          bestSideContacts = contacts;
          bestSide = side;
          bestAdjRoad = sideBestCell;
          bestDist = sideMinDist;
          bestTier = sideBestTier;
        }
      }

      if (bestAdjRoad != null && bestSide != null) {
        lot.isConnected = true;
        lot.connectedSide = bestSide;
        lot.driveInPath = _reconstructRoadWorldPath(bestAdjRoad);
      } else if (directlyOnHighway) {
        lot.isConnected = true;
        lot.connectedSide = LotEntrySide.south;
        lot.driveInPath = <Vec3>[
          Vec3(lot.position.x, 0.0, OutpostLayout.parkingAisleZ),
        ];
      } else {
        lot.isConnected = false;
        lot.connectedSide = null;
        lot.driveInPath = <Vec3>[];
      }
    }

    // 3. Evaluate RoadAccessReport for every built store
    final signBonus = _computeSignBonus(decorations);
    for (final plot in plots) {
      if (!plot.isBuilt) {
        plot.access = RoadAccessReport.disconnected;
        continue;
      }
      plot.access = evaluateBuildingAccess(
        businessType: plot.businessType,
        gridX: plot.gridX,
        gridZ: plot.gridZ,
        rotationQuarter: plot.rotationQuarter,
        parkingLots: parkingLots,
        signBonus: signBonus,
      );
    }
  }

  /// Evaluates road access for any actual OR candidate/ghost building placement.
  RoadAccessReport evaluateBuildingAccess({
    required BusinessType businessType,
    required int gridX,
    required int gridZ,
    required int rotationQuarter,
    required List<ParkingLotEntity> parkingLots,
    double signBonus = 0.0,
  }) {
    final data = kBusinessCatalog[businessType]!;
    final (w, d) = OutpostLayout.rotatedSize(data.gridW, data.gridD, rotationQuarter);
    final footprint = <GridCell>{};
    for (int dx = 0; dx < w; dx++) {
      for (int dz = 0; dz < d; dz++) {
        footprint.add(GridCell(gridX + dx, gridZ + dz));
      }
    }

    // Front entrance cell directly outside the rotated front door (matches Vec3.rotateY)
    final entrance = switch (rotationQuarter & 3) {
      0 => GridCell(gridX + (w ~/ 2), gridZ + d),
      1 => GridCell(gridX - 1, gridZ + (d ~/ 2)),
      2 => GridCell(gridX + (w ~/ 2), gridZ - 1),
      _ => GridCell(gridX + w, gridZ + (d ~/ 2)),
    };

    // Perimeter cells surrounding the store
    final perimeter = <GridCell>{};
    for (final c in footprint) {
      for (final n in c.neighbors4) {
        if (!footprint.contains(n)) perimeter.add(n);
      }
    }

    // Check connected road touching front entrance vs side/back
    GridCell? bestRoadCell;
    bool frontageAligned = false;
    int bestRoadDist = 999;
    RoadTier? bestRoadTier;

    if (_roadDistFromHighway.containsKey(entrance)) {
      bestRoadCell = entrance;
      frontageAligned = true;
      bestRoadDist = _roadDistFromHighway[entrance]!;
      bestRoadTier = _pathMinTier[entrance];
    } else {
      // Check any front-row cell first, then any perimeter cell
      for (final p in perimeter) {
        final dist = _roadDistFromHighway[p];
        if (dist == null) continue;
        final t = _pathMinTier[p] ?? RoadTier.dirt;
        final isFrontEdge = switch (rotationQuarter & 3) {
          0 => p.gz == gridZ + d,
          1 => p.gx == gridX - 1,
          2 => p.gz == gridZ - 1,
          _ => p.gx == gridX + w,
        };
        final scoreBetter = bestRoadCell == null ||
            (isFrontEdge && !frontageAligned) ||
            (isFrontEdge == frontageAligned && dist < bestRoadDist);
        if (scoreBetter) {
          bestRoadCell = p;
          frontageAligned = isFrontEdge;
          bestRoadDist = dist;
          bestRoadTier = t;
        }
      }
    }

    // Check active parking lots & walking distance from nearest connected lot
    final activeLots = parkingLots.where((l) => l.isConnected).toList(growable: false);
    if (activeLots.isEmpty) {
      return RoadAccessReport(
        score: 0.0,
        hasHighwayConnection: bestRoadCell != null,
        hasDirectRoad: bestRoadCell != null,
        frontageAligned: frontageAligned,
        hasParkingAccess: false,
        roadTier: bestRoadTier,
        roadStepsFromHighway: bestRoadDist,
        walkStepsFromParking: 999,
        scenicBonus: false,
        highwayBonus: false,
        statusLabel: bestRoadCell == null ? 'NO ROAD' : 'NEED LOT',
        hint: bestRoadCell == null
            ? 'Connect road & parking lot from Route 163'
            : 'Place a Parking Lot along your road',
        routePreview: bestRoadCell != null ? _reconstructRoadWorldPath(bestRoadCell) : const [],
      );
    }

    ParkingLotEntity? nearestLot;
    int bestWalkSteps = 999;
    final storeCenter = OutpostLayout.footprintCenter(gridX, gridZ, w, d);
    for (final lot in activeLots) {
      int minCellDist = 999;
      for (final lc in lot.occupiedCells) {
        final dist = lc.manhattanTo(entrance);
        if (dist < minCellDist) minCellDist = dist;
      }
      if (minCellDist < bestWalkSteps) {
        bestWalkSteps = minCellDist;
        nearestLot = lot;
      }
    }

    // Can visitors reach this store?
    // Either: (A) Direct highway-connected road touching the store, OR
    //         (B) Active parking lot within 3 sand-walk tiles of the store entrance.
    final hasDirectRoad = bestRoadCell != null;
    final closeSandWalk = nearestLot != null && bestWalkSteps <= 3;

    if (!hasDirectRoad && !closeSandWalk) {
      return RoadAccessReport(
        score: 0.0,
        hasHighwayConnection: false,
        hasDirectRoad: false,
        frontageAligned: false,
        hasParkingAccess: false,
        roadTier: null,
        roadStepsFromHighway: 999,
        walkStepsFromParking: bestWalkSteps,
        scenicBonus: false,
        highwayBonus: false,
        statusLabel: 'NO ROAD',
        hint: 'Paint a road from Route 163 to this store',
        routePreview: const [],
      );
    }

    // Compute access quality score (0.0 -> 1.35)
    final double frontageFactor = hasDirectRoad
        ? (frontageAligned ? 1.00 : 0.80)
        : 0.48; // Sand footpath from nearby roadside pull-off

    final RoadTier effectiveTier = bestRoadTier ??
        (nearestLot!.kind == ParkingLotKind.pavedLot
            ? RoadTier.paved
            : (nearestLot.kind == ParkingLotKind.gravelLot
                ? RoadTier.gravel
                : RoadTier.dirt));

    final double surfaceFactor = hasDirectRoad
        ? kRoadTierCatalog[effectiveTier]!.accessFactor
        : 0.72;

    // Distance penalty only beyond a generous 24-tile commute (the outpost sits in the
    // middle of the desert, so every town has a long access road by design).
    final int roadSteps = hasDirectRoad ? bestRoadDist : 1;
    final double decayPerStep = switch (effectiveTier) {
      RoadTier.paved => 0.006,
      RoadTier.gravel => 0.012,
      RoadTier.dirt => 0.02,
    };
    final double distanceFactor = roadSteps <= 24
        ? 1.0
        : (1.0 - (roadSteps - 24) * decayPerStep).clamp(0.6, 1.0);

    // Parking proximity factor
    final double parkingFactor = bestWalkSteps <= 4
        ? 1.0
        : (bestWalkSteps <= 7 ? 0.82 : 0.62);

    // Location & network bonuses
    final bool scenicBonus =
        data.prefersScenic && gridZ <= OutpostLayout.scenicRowMax;
    final bool highwayBonus =
        data.prefersHighway && (gridZ + d - 1) >= OutpostLayout.highwayBonusRowMin;
    final double loopBonus = highwayTurnOffCount >= 2 ? 0.08 : 0.0;

    final rawScore = frontageFactor * surfaceFactor * distanceFactor * parkingFactor +
        (scenicBonus ? 0.15 : 0.0) +
        (highwayBonus ? 0.10 : 0.0) +
        loopBonus +
        signBonus;
    final finalScore = rawScore.clamp(0.15, 1.35);

    // Friendly status label + actionable hint
    final String statusLabel;
    final String hint;
    if (!hasDirectRoad) {
      statusLabel = 'SAND PATH ${(finalScore * 100).round()}%';
      hint = 'Paint a road to the entrance for more customers';
    } else if (!frontageAligned) {
      statusLabel = 'SIDE ACCESS ${(finalScore * 100).round()}%';
      hint = 'Rotate entrance toward road for +20% flow';
    } else if (bestWalkSteps > 5) {
      statusLabel = 'FAR LOT ${(finalScore * 100).round()}%';
      hint = 'Add a closer parking lot to boost traffic';
    } else if (finalScore < 0.75) {
      statusLabel = 'DIRT ROAD ${(finalScore * 100).round()}%';
      hint = 'Upgrade road to Gravel/Paved for faster traffic';
    } else if (finalScore >= 0.98) {
      statusLabel = 'GREAT ${(finalScore * 100).round()}%';
      hint = scenicBonus
          ? 'Scenic Mesa Bonus +15%!'
          : (highwayBonus ? 'Highway Edge Bonus +10%!' : 'Peak highway access!');
    } else {
      statusLabel = 'GOOD ${(finalScore * 100).round()}%';
      hint = 'Strong road & parking access';
    }

    // Build visual route preview from Route 163 -> Road -> Store
    final routePreview = <Vec3>[];
    if (bestRoadCell != null) {
      routePreview.addAll(_reconstructRoadWorldPath(bestRoadCell));
      routePreview.add(storeCenter);
    } else if (nearestLot != null) {
      routePreview.addAll(nearestLot.driveInPath);
      routePreview.add(nearestLot.position);
      routePreview.add(storeCenter);
    }

    return RoadAccessReport(
      score: finalScore,
      hasHighwayConnection: true,
      hasDirectRoad: hasDirectRoad,
      frontageAligned: frontageAligned,
      hasParkingAccess: true,
      roadTier: hasDirectRoad ? effectiveTier : null,
      roadStepsFromHighway: roadSteps,
      walkStepsFromParking: bestWalkSteps,
      scenicBonus: scenicBonus,
      highwayBonus: highwayBonus,
      statusLabel: statusLabel,
      hint: hint,
      routePreview: routePreview,
    );
  }

  /// Finds a walkable path from [startWorld] (parked car) to [destWorld] (store stop point),
  /// preferring player-built road tiles and avoiding stepping through buildings.
  /// A* with a binary heap, bounded to the start/goal box (+8 tiles) for speed on the 64x64 map.
  List<Vec3> buildVisitorWalkPath({
    required Vec3 startWorld,
    required Vec3 destWorld,
    required Set<GridCell> blockedCells,
  }) {
    final (sx, sz) = OutpostLayout.worldToCell(startWorld);
    final (dx, dz) = OutpostLayout.worldToCell(destWorld);
    final start = GridCell(
      sx.clamp(OutpostLayout.minGridX, OutpostLayout.maxGridX),
      sz.clamp(OutpostLayout.minGridZ, OutpostLayout.maxGridZ),
    );
    final goal = GridCell(
      dx.clamp(OutpostLayout.minGridX, OutpostLayout.maxGridX),
      dz.clamp(OutpostLayout.minGridZ, OutpostLayout.maxGridZ),
    );

    if (start == goal) return <Vec3>[destWorld];

    const margin = 8;
    final minX = math.max(OutpostLayout.minGridX, math.min(start.gx, goal.gx) - margin);
    final maxX = math.min(OutpostLayout.maxGridX, math.max(start.gx, goal.gx) + margin);
    final minZ = math.max(OutpostLayout.minGridZ, math.min(start.gz, goal.gz) - margin);
    final maxZ = math.min(OutpostLayout.maxGridZ, math.max(start.gz, goal.gz) + margin);

    final gScore = <GridCell, int>{start: 0};
    final parent = <GridCell, GridCell?>{start: null};
    final heap = _MinHeap();
    heap.push(start, start.manhattanTo(goal));

    while (heap.isNotEmpty) {
      final (cur, _) = heap.pop();
      if (cur == goal) break;
      final curCost = gScore[cur]!;

      for (final next in cur.neighbors4) {
        if (next.gx < minX || next.gx > maxX || next.gz < minZ || next.gz > maxZ) {
          continue;
        }
        if (next != goal && blockedCells.contains(next)) continue;
        final stepCost = tiles.containsKey(next) ? 1 : 3;
        final nextCost = curCost + stepCost;
        if (nextCost < (gScore[next] ?? 1 << 30)) {
          gScore[next] = nextCost;
          parent[next] = cur;
          heap.push(next, nextCost + next.manhattanTo(goal));
        }
      }
    }

    if (!parent.containsKey(goal)) {
      return <Vec3>[destWorld];
    }

    final cells = <GridCell>[];
    GridCell? cur = goal;
    while (cur != null) {
      cells.add(cur);
      cur = parent[cur];
    }
    final reversed = cells.reversed.toList(growable: false);
    final waypoints = <Vec3>[];
    for (int i = 1; i < reversed.length - 1; i++) {
      waypoints.add(reversed[i].worldCenter);
    }
    waypoints.add(destWorld);
    return waypoints;
  }

  /// Speed factor for a vehicle currently driving at [worldPos].
  double vehicleSpeedAt(Vec3 worldPos) {
    final (gx, gz) = OutpostLayout.worldToCell(worldPos);
    final tile = tiles[GridCell(gx, gz)];
    if (tile == null) return 3.8;
    return kRoadTierCatalog[tile.tier]!.vehicleSpeed;
  }

  List<Vec3> _reconstructRoadWorldPath(GridCell endCell) {
    final cells = <GridCell>[];
    GridCell? cur = endCell;
    int guard = 0;
    while (cur != null && guard++ < 256) {
      cells.add(cur);
      cur = _roadParent[cur];
    }
    final ordered = cells.reversed.toList(growable: false);
    if (ordered.isEmpty) return const [];
    final entry = ordered.first;
    final pts = <Vec3>[
      Vec3(entry.worldCenter.x, 0.0, OutpostLayout.highwayNorthEdgeZ),
    ];
    for (final c in ordered) {
      pts.add(c.worldCenter);
    }
    return pts;
  }

  double _computeSignBonus(List<PlacedDecoration> decorations) {
    final signs = decorations
        .where((d) => d.kind == DecorationKind.woodenSignpost)
        .length;
    return math.min(0.16, signs * 0.08);
  }

  RoadTier _minTier(RoadTier a, RoadTier b) => a.index <= b.index ? a : b;
}

/// Minimal binary min-heap keyed by integer priority for A* pathfinding.
class _MinHeap {
  final List<(GridCell, int)> _items = <(GridCell, int)>[];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(GridCell cell, int priority) {
    _items.add((cell, priority));
    int i = _items.length - 1;
    while (i > 0) {
      final parentIdx = (i - 1) >> 1;
      if (_items[parentIdx].$2 <= _items[i].$2) break;
      final tmp = _items[parentIdx];
      _items[parentIdx] = _items[i];
      _items[i] = tmp;
      i = parentIdx;
    }
  }

  (GridCell, int) pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      int i = 0;
      while (true) {
        final l = i * 2 + 1;
        final r = l + 1;
        int smallest = i;
        if (l < _items.length && _items[l].$2 < _items[smallest].$2) smallest = l;
        if (r < _items.length && _items[r].$2 < _items[smallest].$2) smallest = r;
        if (smallest == i) break;
        final tmp = _items[smallest];
        _items[smallest] = _items[i];
        _items[i] = tmp;
        i = smallest;
      }
    }
    return top;
  }
}
