import 'package:desert_outpost/engine/camera_3d.dart';
import 'package:desert_outpost/engine/mesh_builder.dart';
import 'package:desert_outpost/engine/mesh_parts.dart';
import 'package:desert_outpost/engine/renderer_3d.dart';
import 'package:desert_outpost/engine/vec3.dart';
import 'package:desert_outpost/main.dart';
import 'package:desert_outpost/models/game_models.dart';
import 'package:desert_outpost/systems/game_controller.dart';
import 'package:desert_outpost/systems/road_network.dart';
import 'package:desert_outpost/systems/world_grid.dart';
import 'package:desert_outpost/ui/object_studio_screen.dart';
import 'package:desert_outpost/ui/outpost_screen.dart';
import 'package:desert_outpost/world/outpost_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Stage 1 HUD, onboarding bubbles, road line tool and build tray render', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const DesertOutpostApp(home: OutpostScreen(enablePersistence: false)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BUILD'), findsOneWidget);
    expect(find.text('ROADS'), findsOneWidget);
    expect(find.text('UPGRADE'), findsOneWidget);
    expect(find.text('STG 1'), findsOneWidget);
    expect(find.textContaining('SELL'), findsOneWidget);
    expect(find.textContaining('DIRT LOT'), findsOneWidget);
    expect(find.textContaining('ACCESS ROAD'), findsOneWidget);
    expect(find.text('First Pull-Off'), findsOneWidget);

    // Road tool shows tier brushes, junction counter and BUILD / DONE controls
    await tester.tap(find.text('ROADS'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('DIRT'), findsOneWidget);
    expect(find.text('GRAVEL'), findsOneWidget);
    expect(find.text('PAVED'), findsOneWidget);
    expect(find.textContaining('JUNCTIONS'), findsOneWidget);
    await tester.tap(find.text('DONE'));
    await tester.pump(const Duration(milliseconds: 80));

    // Earn $40 by tapping, then place the Dirt Pull-Off from its in-world bubble
    for (int i = 0; i < 8; i++) {
      await tester.tap(find.textContaining('SELL'));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.tap(find.textContaining('DIRT LOT'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('SERVE'), findsOneWidget);
    expect(find.textContaining('CLAIM'), findsOneWidget);

    // ACCESS ROAD bubble opens the road tool with a pre-drawn Route 163 -> cart line
    await tester.tap(find.textContaining('ACCESS ROAD'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('BUILD ·'), findsOneWidget);
    await tester.tap(find.text('DONE'));
    await tester.pump(const Duration(milliseconds: 80));

    // Build tray lists roads, land and the next store
    await tester.tap(find.text('BUILD'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Build Roads'), findsOneWidget);
    expect(find.text('Buy Land'), findsOneWidget);
    expect(find.text('Outpost Mart'), findsOneWidget);
  });

  testWidgets('3D Object Studio renders modular assets across Lv1-Lv5 and switches objects', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DesertOutpostApp(home: ObjectStudioScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cart / Stall'), findsWidgets);
    expect(find.text('lib/world/buildings/vendor_cart.dart'), findsOneWidget);
    expect(find.text('Lv5'), findsOneWidget);

    await tester.tap(find.text('Lv5'));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.text('Desert Diner'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('lib/world/buildings/desert_diner.dart'), findsOneWidget);
  });

  test('Open-desert career: access road, parking, land, access scoring & monotonic stages', () {
    final c = GameController(initialPreset: OutpostPreset.stageOneCareer);
    final cart = c.cartPlot;

    // Cart starts in the middle of the desert, ~40 units north of Route 163
    expect(c.outpostStage, 1);
    expect(c.camera.distance, Camera3D.stageOneDistance);
    expect(OutpostLayout.highwayCenterZ - cart.position.z, greaterThan(38.0));
    expect(c.worldGrid.ownedParcels.length, 2);
    expect(c.incomePerMinute, 0);
    expect(c.isRoadTierUnlocked(RoadTier.gravel), isFalse);

    c.cash = 1000;
    expect(c.upgradeLockReason(cart), 'NO ROAD');

    // A lot without a road is placed but NOT connected
    expect(c.placeParkingLotAt(ParkingLotKind.dirtPullOff, -2, -12), isTrue);
    expect(c.parkingLots.single.isConnected, isFalse);
    expect(c.totalParkingSpaces, 0);

    // Cannot build on land we don't own
    expect(c.placeParkingLotAt(ParkingLotKind.dirtPullOff, 20, -12), isFalse);

    // Draw the access road from Route 163 to the cart entrance in ONE line (no gaps)
    final entrance = cart.entranceCell;
    expect(entrance, const GridCell(0, -12));
    expect(
      c.buildRoadLine(const GridCell(0, OutpostLayout.highwayEntryRowZ), entrance),
      isTrue,
    );
    expect(c.roadNetwork.roadCount, 18);
    expect(c.roadNetwork.highwayTurnOffCount, 1);
    final firstLot = c.parkingLots.single;
    expect(firstLot.isConnected, isTrue);
    // Lot placed west of a north-south road automatically faces east (+X road -> nose-in west)!
    expect(firstLot.effectiveEntrySide, LotEntrySide.east);
    expect(firstLot.orientedWorldDimensions, (4.0, 4.0));
    expect(cart.access.hasDirectRoad, isTrue);
    expect(cart.access.score, greaterThan(0.6));
    expect(c.outpostStage, 2);
    expect(c.incomePerMinute, greaterThan(0));

    // Stage 2 unlocks upgrading Dirt Pull-Off (2 bays) -> Gravel Lot (4 bays) in place!
    expect(c.parkingLotUpgradeLockReason(firstLot), isNull);
    expect(c.upgradeParkingLot(firstLot), isTrue);
    expect(firstLot.kind, ParkingLotKind.gravelLot);
    expect(c.totalParkingSpaces, 4);
    expect(c.parkingLotUpgradeLockReason(firstLot), 'STAGE 4');

    // A frontage road along the highway counts as ONE junction, not one per tile
    final frontage = c.computeRoadLinePreview(
      const GridCell(0, OutpostLayout.highwayEntryRowZ),
      const GridCell(4, OutpostLayout.highwayEntryRowZ),
    );
    expect(frontage.blockReason, isNull);

    // Mart placed far from roads & lots gets NO access
    expect(c.placeBuildingAt(BusinessType.convenienceStore, 4, -17), isTrue);
    final mart = c.plots.firstWhere((p) => p.businessType == BusinessType.convenienceStore);
    expect(mart.access.score, 0.0);

    // Stage 2 caps upgrades at Lv2
    expect(c.upgradePlot(cart), isTrue);
    expect(c.upgradeLockReason(cart), 'STAGE 3');

    // Gravel L-shaped line to the Mart entrance connects it and promotes to Stage 3
    c.enterRoadPaintMode(tier: RoadTier.gravel);
    expect(c.buildRoadLine(const GridCell(1, -12), mart.entranceCell, tier: RoadTier.gravel), isTrue);
    // Connected, but the only lot is 8 tiles away -> "far lot" parking penalty applies
    expect(mart.access.score, greaterThan(0.4));
    expect(mart.access.walkStepsFromParking, greaterThan(7));
    expect(c.outpostStage, 3);
    expect(c.upgradeLockReason(cart), isNull);

    // Bulldozing roads never drops the stage (monotonic progression)
    c.setRoadEraseMode(true);
    c.setRoadLine(const GridCell(1, -12), mart.entranceCell);
    expect(c.confirmRoadLine(), isTrue);
    expect(mart.access.score, 0.0);
    expect(c.outpostStage, 3);

    // Buy an adjacent land parcel and relocate the cart onto it with rotation
    c.cancelToolMode();
    expect(c.buyParcel(const LandParcel(3, 4)), isTrue);
    expect(c.worldGrid.ownedParcels.length, 3);
    expect(c.relocatePlotTo(cart, -6, -22, rotationQuarter: 1), isTrue);
    expect(cart.rotationQuarter, 1);
    // Rotating 90° turns the entrance to face west (-X), matching Vec3.rotateY
    expect(cart.entranceCell, const GridCell(-7, -21));

    for (int i = 0; i < 160; i++) {
      c.tick(0.05);
    }
    expect(c.vehicles, isNotEmpty);
  });

  test('Lane offset keeps two-way traffic on the right-hand side', () {
    final path = [const Vec3(0, 0, 10), const Vec3(0, 0, 0)];
    final offset = RoadNetwork.offsetPathRight(path, 0.5);
    // Driving north (-Z, away from the default camera): right-hand lane is +X (screen right)
    expect(offset.first.x, closeTo(0.5, 1e-6));
  });

  test('Full City preset: paved loop, Oasis placement, decorations and traffic', () {
    final c = GameController(initialPreset: OutpostPreset.fullCity);
    expect(c.outpostStage, 6);
    expect(c.parkingTier, 3);
    expect(c.builtCount, 7);
    expect(c.roadNetwork.pavedRoadCount, greaterThan(40));
    expect(c.roadNetwork.highwayTurnOffCount, 2);
    expect(c.averageAccessScore, greaterThan(0.9));
    expect(c.incomePerMinute, greaterThan(0));

    final oasis = c.plots.firstWhere((p) => !p.isBuilt);
    expect(oasis.businessType, BusinessType.oasisPlaza);
    expect(c.placeBuildingAt(BusinessType.oasisPlaza, 6, -5), isTrue);
    expect(c.builtCount, 8);
    expect(oasis.access.score, greaterThan(0.0));

    final beforeDeco = c.incomePerMinute;
    c.cash += 500;
    expect(c.placeDecoration(DecorationKind.campfireRing, 'Campfire', 95), isTrue);
    expect(c.incomePerMinute, greaterThan(beforeDeco));

    // Free 360° orbit (no yaw clamp) and tilt range
    final yaw0 = c.camera.yaw;
    c.orbitCamera(2.5);
    expect((c.camera.yaw - yaw0).abs(), greaterThan(2.0));
    c.tiltCamera(5.0);
    expect(c.camera.pitch, Camera3D.maxPitch);

    const viewport = Size(1280, 720);
    final projected = c.camera.project(const Vec3(0, 0, -10), viewport);
    final groundHit = c.camera.screenToGround(projected.offset, viewport);
    expect(groundHit.x.abs(), lessThan(0.05));
    expect((groundHit.z + 10.0).abs(), lessThan(0.05));

    for (int i = 0; i < 240; i++) {
      c.tick(0.05);
    }
    for (final car in c.vehicles) {
      expect(car.yaw.isFinite, isTrue);
    }
  });

  test('3D engine subdivides wide slabs and sorts props/windows strictly in front of host planes', () {
    // 1. Wide cart countertop subdivides automatically; small bottle box stays 5 faces
    final wideMesh = MeshBuilder()..addBox(0, 0.98, 0.08, 1.56, 0.09, 1.00, const Color(0xFFFFFFFF));
    final smallMesh = MeshBuilder()..addBox(0, 1.07, 0.24, 0.12, 0.24, 0.12, const Color(0xFFFFFFFF));
    expect(wideMesh.polys.length, greaterThan(5));
    expect(smallMesh.polys.length, 5);

    // 2. Cooler face sitting on top of countertop (y = 1.07) always sorts IN FRONT of countertop
    const countertopVerts = [
      Vec3(-0.78, 1.07, -0.42),
      Vec3(-0.78, 1.07, 0.58),
      Vec3(0.78, 1.07, 0.58),
      Vec3(0.78, 1.07, -0.42),
    ];
    const coolerSideVerts = [
      Vec3(-0.64, 1.07, 0.28),
      Vec3(-0.08, 1.07, 0.28),
      Vec3(-0.08, 1.49, 0.28),
      Vec3(-0.64, 1.49, 0.28),
    ];
    expect(
      SceneRenderer3D.isWorldPolyInFront(
        aVerts: coolerSideVerts,
        aNormal: const Vec3(0, 0, 1),
        aD: 0.28,
        bVerts: countertopVerts,
        bNormal: Vec3.up,
        bD: 1.07,
      ),
      isTrue,
    );
    expect(
      SceneRenderer3D.isWorldPolyInFront(
        aVerts: countertopVerts,
        aNormal: Vec3.up,
        aD: 1.07,
        bVerts: coolerSideVerts,
        bNormal: const Vec3(0, 0, 1),
        bD: 0.28,
      ),
      isFalse,
    );

    // 3. Off-center flush window (x = -1.72, z = 1.27) always sorts IN FRONT of wide wall (z = 1.24)
    const wallVerts = [
      Vec3(-2.57, 0.22, 1.24),
      Vec3(2.57, 0.22, 1.24),
      Vec3(2.57, 2.84, 1.24),
      Vec3(-2.57, 2.84, 1.24),
    ];
    const windowVerts = [
      Vec3(-2.43, 0.85, 1.27),
      Vec3(-1.01, 0.85, 1.27),
      Vec3(-1.01, 1.87, 1.27),
      Vec3(-2.43, 1.87, 1.27),
    ];
    expect(
      SceneRenderer3D.isWorldPolyInFront(
        aVerts: windowVerts,
        aNormal: const Vec3(0, 0, 1),
        aD: 1.27,
        bVerts: wallVerts,
        bNormal: const Vec3(0, 0, 1),
        bD: 1.24,
      ),
      isTrue,
    );

    // 4. Hollow adobe parapet roof keeps roof deck recessed strictly below parapet rims (zero Z-fighting)
    final roofMesh = MeshBuilder();
    MeshParts.addAdobeParapetRoof(
      roofMesh,
      cx: 0,
      yBase: 2.75,
      cz: 0,
      width: 4.48,
      depth: 2.78,
      parapetHeight: 0.32,
      parapetColor: const Color(0xFF9E5538),
      roofDeckColor: const Color(0xFFD6B484),
      addVigasBeams: false,
    );
    final upFaces = roofMesh.polys.where((p) => p.normal.y > 0.99).toList();
    final deckTops = upFaces.where((p) => p.color == const Color(0xFFD6B484)).toList();
    final rimTops = upFaces.where((p) => p.color == const Color(0xFF9E5538)).toList();
    expect(deckTops, isNotEmpty);
    expect(rimTops, isNotEmpty);
    for (final deck in deckTops) {
      for (final rim in rimTops) {
        expect(rim.centroid.y - deck.centroid.y, greaterThan(0.20));
      }
    }
  });
}
