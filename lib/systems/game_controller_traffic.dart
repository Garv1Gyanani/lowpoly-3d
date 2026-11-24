part of 'game_controller.dart';

/// Highway traffic, junction turn-in decisions, right-hand lane driving on player roads,
/// parking, and visitor walking AI.
extension _GameControllerTraffic on GameController {
  static const double _laneOffset = 0.42;
  static const double _highwaySpawnX = 96.0;

  void _seedInitialTraffic() {
    vehicles.clear();
    visitors.clear();

    _spawnVehicle(initialX: -40.0, direction: 1);
    _spawnVehicle(initialX: 30.0, direction: -1);
    _spawnVehicle(initialX: -6.0, direction: 1);

    final activeLots = parkingLots.where((l) => l.isConnected).toList();
    if (activeLots.isEmpty || connectedBuiltCount < 2) return;

    int seeded = 0;
    for (final lot in activeLots) {
      final slots = lot.slotPositions;
      if (slots.isEmpty || lot.driveInPath.isEmpty) continue;
      final slot = slots.first;
      final aisle = lot.aislePointForSlot(0);
      final v = VehicleEntity(
        id: _nextEntityId++,
        kind: seeded.isEven ? VehicleKind.pickupTruck : VehicleKind.camperRv,
        bodyColor: _randomVehicleColor(),
        position: Vec3(slot.x, 0, slot.z),
        yaw: lot.parkedYaw,
        speed: 0,
        direction: 1,
        phase: VehiclePhase.parked,
        parkingLotId: lot.id,
        parkingSlotIndex: 0,
        parkTimer: 4.5 + seeded * 1.4,
        spawnedVisitor: true,
        exitWaypoints: [
          aisle,
          ...RoadNetwork.offsetPathRight(
            lot.driveInPath.reversed.toList(),
            _laneOffset,
          ),
        ],
      );
      vehicles.add(v);
      _spawnVisitorsFromVehicle(v);
      seeded++;
      if (seeded >= 2) break;
    }
  }

  /// Junction X positions (highway edge entry points) that lead to connected lots.
  List<double> _junctionEntryXs() {
    final xs = <double>[];
    for (final lot in parkingLots) {
      if (!lot.isConnected || lot.driveInPath.isEmpty) continue;
      final x = lot.driveInPath.first.x;
      if (!xs.any((e) => (e - x).abs() < 0.01)) xs.add(x);
    }
    return xs;
  }

  ParkingLotEntity? _lotById(String? id) {
    if (id == null) return null;
    for (final l in parkingLots) {
      if (l.id == id) return l;
    }
    return null;
  }

  void _assignBay(VehicleEntity v, ParkingLotEntity lot, int slotIdx, Vec3 slotPos) {
    final aisle = lot.aislePointForSlot(slotIdx);
    v.parkingLotId = lot.id;
    v.parkingSlotIndex = slotIdx;
    v.phase = VehiclePhase.pullingIn;
    v.waypoints
      ..clear()
      ..addAll(RoadNetwork.offsetPathRight(lot.driveInPath, _laneOffset))
      ..add(aisle)
      ..add(slotPos);
    v.exitWaypoints
      ..clear()
      ..add(aisle)
      ..addAll(RoadNetwork.offsetPathRight(lot.driveInPath.reversed.toList(), _laneOffset));
  }

  void _updateVehicles(double dt) {
    final maxVehicles = 4 + math.min(8, totalParkingSpaces);
    _trafficSpawnCooldown -= dt;
    if (_trafficSpawnCooldown <= 0 && vehicles.length < maxVehicles) {
      final dir = _rng.nextBool() ? 1 : -1;
      _spawnVehicle(initialX: dir == 1 ? -_highwaySpawnX : _highwaySpawnX, direction: dir);
      _trafficSpawnCooldown = (4.2 - totalParkingSpaces * 0.22).clamp(1.4, 4.2);
    }

    final entryXs = (totalParkingSpaces > 0 && connectedBuiltCount > 0)
        ? _junctionEntryXs()
        : const <double>[];
    final toRemove = <VehicleEntity>[];

    for (final v in vehicles) {
      switch (v.phase) {
        case VehiclePhase.highwayCruise:
          final nextX = v.position.x + v.direction * v.speed * dt;
          v.position = Vec3(nextX, 0, v.position.z);
          v.yaw = v.direction == 1 ? 0.0 : math.pi;

          if (v.parkingSlotIndex == -1) {
            for (final entryX in entryXs) {
              if ((v.position.x - entryX).abs() < 2.4 && v.consideredEntryX != entryX) {
                // Decide ONCE per junction (no per-frame re-rolls).
                v.consideredEntryX = entryX;
                final turnInChance = (0.24 + averageAccessScore * 0.52).clamp(0.18, 0.88);
                if (_rng.nextDouble() < turnInChance) {
                  final bay = _findFreeParkingBay(entryX);
                  if (bay != null) _assignBay(v, bay.$1, bay.$2, bay.$3);
                }
                break;
              }
            }
          }

          if (v.position.x > _highwaySpawnX + 4 || v.position.x < -_highwaySpawnX - 4) {
            toRemove.add(v);
          }

        case VehiclePhase.pullingIn:
          if (_rng.nextDouble() < dt * 6.0 && particles.length < 72) {
            final tireBehind = Vec3(
              v.position.x - math.cos(v.yaw) * 0.75,
              0.08,
              v.position.z - math.sin(v.yaw) * 0.75,
            );
            particles.add(
              Particle3D(
                position: tireBehind,
                velocity: Vec3(
                  (_rng.nextDouble() - 0.5) * 0.5,
                  0.6 + _rng.nextDouble() * 0.45,
                  (_rng.nextDouble() - 0.5) * 0.5,
                ),
                color: DesertPalette.sandLight,
                size: 4.5 + _rng.nextDouble() * 2.5,
                duration: 0.55,
              ),
            );
          }

          if (v.waypoints.isEmpty) {
            final lot = _lotById(v.parkingLotId);
            if (lot != null) v.yaw = lot.parkedYaw;
            v.phase = VehiclePhase.parked;
            v.parkTimer = 6.0 + _rng.nextDouble() * 3.5;
            v.spawnedVisitor = false;
            break;
          }
          final wp = v.waypoints.first;
          final toWp = wp - v.position;
          final dist = toWp.length;
          if (dist < 0.25) {
            v.position = wp;
            v.waypoints.removeAt(0);
            if (v.waypoints.isEmpty) {
              final lot = _lotById(v.parkingLotId);
              if (lot != null) v.yaw = lot.parkedYaw;
              v.phase = VehiclePhase.parked;
              v.parkTimer = 6.0 + _rng.nextDouble() * 3.5;
              v.spawnedVisitor = false;
            }
          } else {
            final roadSpd = roadNetwork.vehicleSpeedAt(v.position);
            final step = math.min(dist, roadSpd * dt);
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
            final backTarget = v.exitWaypoints.isNotEmpty
                ? v.exitWaypoints.first
                : Vec3(v.position.x, 0, OutpostLayout.parkingAisleZ);
            v.waypoints
              ..clear()
              ..add(backTarget);
            v.phase = VehiclePhase.backingOut;
          }

        case VehiclePhase.backingOut:
          if (v.waypoints.isEmpty) {
            _beginPullOutToHighway(v);
            break;
          }
          final backTarget = v.waypoints.first;
          final toBack = backTarget - v.position;
          final dist = toBack.length;
          if (dist < 0.22) {
            v.position = backTarget;
            v.waypoints.clear();
            _beginPullOutToHighway(v);
          } else {
            final step = math.min(dist, 2.3 * dt);
            final dir = toBack / dist;
            v.position = v.position + dir * step;
            // Reversing: the nose points away from the travel direction.
            final reverseYaw = math.atan2(-dir.z, -dir.x);
            v.yaw = _lerpAngle(v.yaw, reverseYaw, (dt * 3.0).clamp(0.0, 1.0));
          }

        case VehiclePhase.pullingOut:
          if (v.waypoints.isEmpty) {
            v.parkingLotId = null;
            v.parkingSlotIndex = -1;
            v.phase = VehiclePhase.highwayCruise;
            break;
          }
          final wp = v.waypoints.first;
          final toWp = wp - v.position;
          final dist = toWp.length;
          if (dist < 0.26) {
            v.position = wp;
            v.waypoints.removeAt(0);
            if (v.waypoints.isEmpty) {
              v.parkingLotId = null;
              v.parkingSlotIndex = -1;
              v.phase = VehiclePhase.highwayCruise;
            }
          } else {
            final roadSpd = roadNetwork.vehicleSpeedAt(v.position);
            final step = math.min(dist, roadSpd * dt);
            final dir = toWp / dist;
            v.position = v.position + dir * step;
            final desiredYaw = math.atan2(dir.z, dir.x);
            v.yaw = _lerpAngle(v.yaw, desiredYaw, (dt * 8.0).clamp(0.0, 1.0));
          }
      }
    }

    vehicles.removeWhere(toRemove.contains);
  }

  void _beginPullOutToHighway(VehicleEntity v) {
    final exitZ = v.direction == 1
        ? OutpostLayout.highwayEastboundZ
        : OutpostLayout.highwayWestboundZ;
    v.waypoints.clear();
    if (v.exitWaypoints.length > 1) {
      v.waypoints.addAll(v.exitWaypoints.skip(1));
    }
    final lastX = v.waypoints.isNotEmpty ? v.waypoints.last.x : v.position.x;
    v.waypoints.add(Vec3(lastX + v.direction * 1.8, 0, exitZ));
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
          if (dist < 0.22) {
            vis.position = wp;
            vis.outboundPath.removeAt(0);
            if (vis.outboundPath.isEmpty) {
              vis.phase = VisitorPhase.shopping;
              vis.yaw = -math.pi * 0.5;
              vis.waitTimer = 1.6 + _rng.nextDouble() * 1.4;
            }
          } else {
            final dir = diff / dist;
            vis.position = vis.position + dir * (2.15 * dt);
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
            final accessFactor = math.max(0.25, plot.access.score);
            final sale = math.max(
              3.0,
              ((plot.data.incomeForLevel(plot.level) *
                          accessFactor *
                          decorationBonusMultiplier) /
                      15.0)
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
            _refreshProgression();
            _notifyBoth();
          }

        case VisitorPhase.returningToCar:
          if (vis.returnPath.isEmpty) {
            toRemove.add(vis);
            break;
          }
          final wp = vis.returnPath.first;
          final diff = wp - vis.position;
          final dist = diff.length;
          if (dist < 0.24) {
            vis.position = wp;
            vis.returnPath.removeAt(0);
            if (vis.returnPath.isEmpty) toRemove.add(vis);
          } else {
            final dir = diff / dist;
            vis.position = vis.position + dir * (2.15 * dt);
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

  /// Free bay among connected lots reached through the junction at [entryX].
  (ParkingLotEntity, int, Vec3)? _findFreeParkingBay(double entryX) {
    final freeBays = <(ParkingLotEntity, int, Vec3)>[];
    for (final lot in parkingLots) {
      if (!lot.isConnected || lot.driveInPath.isEmpty) continue;
      if ((lot.driveInPath.first.x - entryX).abs() > 0.01) continue;
      final slots = lot.slotPositions;
      for (int i = 0; i < slots.length; i++) {
        final occupied = vehicles.any(
          (v) => v.parkingLotId == lot.id && v.parkingSlotIndex == i,
        );
        if (!occupied) freeBays.add((lot, i, slots[i]));
      }
    }
    if (freeBays.isEmpty) return null;
    return freeBays[_rng.nextInt(freeBays.length)];
  }

  void _dispatchImmediateCustomerToLot(ParkingLotEntity lot) {
    final slots = lot.slotPositions;
    if (slots.isEmpty || lot.driveInPath.isEmpty) return;
    final entryX = lot.driveInPath.first.x;
    final v = VehicleEntity(
      id: _nextEntityId++,
      kind: VehicleKind.pickupTruck,
      bodyColor: _randomVehicleColor(),
      position: Vec3(entryX - 9.0, 0, OutpostLayout.highwayEastboundZ),
      yaw: 0.0,
      speed: 5.2,
      direction: 1,
      phase: VehiclePhase.highwayCruise,
    );
    v.consideredEntryX = entryX;
    _assignBay(v, lot, 0, slots.first);
    vehicles.add(v);
  }

  void _spawnVehicle({
    required double initialX,
    required int direction,
  }) {
    final laneZ = direction == 1
        ? OutpostLayout.highwayEastboundZ
        : OutpostLayout.highwayWestboundZ;
    final kinds = VehicleKind.values;
    final kind = kinds[_rng.nextInt(kinds.length)];
    final speed = 5.2 + _rng.nextDouble() * 2.6;

    vehicles.add(
      VehicleEntity(
        id: _nextEntityId++,
        kind: kind,
        bodyColor: _randomVehicleColor(),
        position: Vec3(initialX, 0, laneZ),
        yaw: direction == 1 ? 0.0 : math.pi,
        speed: speed,
        direction: direction,
        phase: VehiclePhase.highwayCruise,
      ),
    );
  }

  /// Picks stores weighted by `plot.access.score` so bad road access gets few/no visitors.
  void _spawnVisitorsFromVehicle(VehicleEntity v) {
    final reachablePlots = plots.where((p) => p.isBuilt && p.access.score > 0.0).toList();
    if (reachablePlots.isEmpty) return;

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

    final blockedBuildings = <GridCell>{};
    for (final p in plots) {
      if (p.isBuilt) blockedBuildings.addAll(p.occupiedCells);
    }

    final totalWeight = reachablePlots.fold<double>(0.0, (s, p) => s + p.access.score);

    for (int i = 0; i < passengerCount; i++) {
      double roll = _rng.nextDouble() * totalWeight;
      PlotState targetPlot = reachablePlots.last;
      for (final p in reachablePlots) {
        roll -= p.access.score;
        if (roll <= 0) {
          targetPlot = p;
          break;
        }
      }

      final lot = _lotById(v.parkingLotId);
      final start = (lot != null && v.parkingSlotIndex >= 0)
          ? lot.visitorSpawnForSlot(v.parkingSlotIndex, i)
          : v.position + Vec3(0.42 + (i - 0.5) * 0.34, 0, -0.95 - i * 0.18);
      final dest = targetPlot.visitorStopPoint + Vec3((i - 0.5) * 0.32, 0, 0);
      final outbound = roadNetwork.buildVisitorWalkPath(
        startWorld: start,
        destWorld: dest,
        blockedCells: blockedBuildings,
      );
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
}
