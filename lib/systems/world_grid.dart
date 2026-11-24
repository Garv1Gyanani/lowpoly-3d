import 'dart:math' as math;

import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../world/outpost_layout.dart';

/// A purchasable 8 x 8 tile land parcel.
class LandParcel {
  const LandParcel(this.px, this.pz);

  final int px;
  final int pz;

  Vec3 get center => OutpostLayout.parcelCenter(px, pz);

  List<LandParcel> get neighbors4 => [
        LandParcel(px + 1, pz),
        LandParcel(px - 1, pz),
        LandParcel(px, pz + 1),
        LandParcel(px, pz - 1),
      ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LandParcel && other.px == px && other.pz == pz;

  @override
  int get hashCode => Object.hash(px, pz);
}

/// Layered tile world: land ownership, structure occupancy index, and reserved
/// utility layers (water pipes – Phase 3, power poles & wires – Phase 4).
///
/// Roads live in [RoadNetwork]; everything that physically occupies a tile
/// (buildings, parking lots, decorations) is indexed here for O(1) validation.
class WorldGrid {
  final Set<LandParcel> ownedParcels = <LandParcel>{};

  /// Occupancy index: tile -> structure id (`plot:<id>`, `lot:<id>`, `deco:<id>`).
  final Map<GridCell, String> structures = <GridCell, String>{};

  /// Reserved Phase 3 layer: water pipe tiles (value = network id).
  final Map<GridCell, int> waterPipes = <GridCell, int>{};

  /// Reserved Phase 4 layer: power pole tiles (value = network id).
  final Map<GridCell, int> powerPoles = <GridCell, int>{};

  int _version = 0;
  int get version => _version;

  void resetOwnership(Iterable<LandParcel> parcels) {
    ownedParcels
      ..clear()
      ..addAll(parcels);
    _version++;
  }

  bool isParcelOwned(int px, int pz) => ownedParcels.contains(LandParcel(px, pz));

  bool isCellOwned(GridCell cell) {
    if (!OutpostLayout.isCellInMap(cell.gx, cell.gz)) return false;
    final (px, pz) = OutpostLayout.parcelOf(cell.gx, cell.gz);
    return ownedParcels.contains(LandParcel(px, pz));
  }

  bool isParcelPurchasable(LandParcel p) {
    if (!OutpostLayout.isParcelInMap(p.px, p.pz)) return false;
    if (ownedParcels.contains(p)) return false;
    return p.neighbors4.any(ownedParcels.contains);
  }

  List<LandParcel> purchasableParcels() {
    final result = <LandParcel>[];
    for (int px = 0; px < OutpostLayout.parcelCountX; px++) {
      for (int pz = 0; pz < OutpostLayout.parcelCountZ; pz++) {
        final p = LandParcel(px, pz);
        if (isParcelPurchasable(p)) result.add(p);
      }
    }
    return result;
  }

  /// Escalating land price: each extra parcel costs ~40% more than the last.
  double nextParcelPrice() {
    final extra = math.max(0, ownedParcels.length - OutpostLayout.starterParcels.length);
    final raw = 120.0 * math.pow(1.4, extra);
    return (raw / 5.0).roundToDouble() * 5.0;
  }

  bool buyParcel(LandParcel p) {
    if (!isParcelPurchasable(p)) return false;
    ownedParcels.add(p);
    _version++;
    return true;
  }

  void rebuildOccupancy({
    required List<PlotState> plots,
    required List<ParkingLotEntity> parkingLots,
    required List<PlacedDecoration> decorations,
  }) {
    structures.clear();
    for (final p in plots) {
      if (!p.isBuilt) continue;
      for (final c in p.occupiedCells) {
        structures[c] = 'plot:${p.id}';
      }
    }
    for (final l in parkingLots) {
      for (final c in l.occupiedCells) {
        structures[c] = 'lot:${l.id}';
      }
    }
    for (final d in decorations) {
      structures[d.cell] = 'deco:${d.id}';
    }
    _version++;
  }

  bool isOccupied(GridCell cell) => structures.containsKey(cell);

  /// Occupied cells, optionally ignoring every tile owned by [ignoreId].
  bool isOccupiedExcept(GridCell cell, String? ignoreId) {
    final occ = structures[cell];
    if (occ == null) return false;
    return ignoreId == null || occ != ignoreId;
  }
}
