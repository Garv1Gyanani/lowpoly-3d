import 'package:desert_outpost/engine/camera_3d.dart';
import 'package:desert_outpost/engine/vec3.dart';
import 'package:desert_outpost/main.dart';
import 'package:desert_outpost/models/game_models.dart';
import 'package:desert_outpost/systems/game_controller.dart';
import 'package:desert_outpost/ui/object_studio_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Desert Outpost renders carved-wood game HUD, goal pill, bubbles, and 3D trays', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DesertOutpostApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BUILD'), findsOneWidget);
    expect(find.text('UPGRADE'), findsOneWidget);
    expect(find.textContaining('SELL'), findsOneWidget);
    expect(find.textContaining('DIRT LOT'), findsOneWidget);
    expect(find.text('First Pull-Off'), findsOneWidget);

    // Tapping an unaffordable bubble triggers shortfall feedback cleanly
    await tester.tap(find.textContaining('DIRT LOT'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('SELL'), findsOneWidget);

    // Tap 8 times ($5 * 8 = $40) -> Dirt Lot in-world bubble becomes affordable & builds on tap!
    for (int i = 0; i < 8; i++) {
      await tester.tap(find.textContaining('SELL'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.textContaining('DIRT LOT'));
    await tester.pump(const Duration(milliseconds: 100));

    // After Tier 1 Dirt Lot is built, primary action button switches to SERVE & milestone is claimable!
    expect(find.textContaining('SERVE'), findsOneWidget);
    expect(find.textContaining('CLAIM'), findsOneWidget);

    // Open slim horizontal Build tray with 3D miniature previews
    await tester.tap(find.text('BUILD'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Gravel Lot & Lamps'), findsOneWidget);
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

  test('Stage 1 starts zoomed on cart with 0 parking and expands framing on upgrade', () {
    final controller = GameController(initialPreset: OutpostPreset.stageOneCareer);
    expect(controller.parkingTier, 0);
    expect(controller.camera.distance, Camera3D.stageOneDistance);
    expect(controller.builtCount, 1);
    expect(controller.visiblePlots.length, 1);
    expect(controller.incomePerMinute, 0);
    expect(controller.visitors, isEmpty);

    for (int i = 0; i < 8; i++) {
      controller.performActiveTap();
    }
    expect(controller.upgradeParking(), isTrue);
    expect(controller.parkingTier, 1);
    expect(controller.incomePerMinute, greaterThan(0));
    expect(controller.visiblePlots.length, 2);

    for (int i = 0; i < 200; i++) {
      controller.tick(0.05);
    }
    expect(controller.camera.distance, greaterThan(Camera3D.stageOneDistance));
    expect(controller.vehicles, isNotEmpty);
  });

  test('Full City preset constructs Oasis Plaza, boosts tips via decorations, and simulates RVs', () {
    final controller = GameController(initialPreset: OutpostPreset.fullCity);
    expect(controller.parkingTier, 3);
    expect(controller.builtCount, 7);
    expect(controller.plots.length, 8);
    final baseIncome = controller.incomePerMinute;
    expect(baseIncome, greaterThan(0));

    final openPlot = controller.plots.firstWhere((p) => !p.isBuilt);
    expect(openPlot.businessType, BusinessType.oasisPlaza);
    expect(controller.buildOnPlot(openPlot), isTrue);
    expect(controller.builtCount, 8);

    // Placing a decoration increases passive tip multiplier
    final beforeDeco = controller.incomePerMinute;
    controller.cash += 500;
    expect(controller.placeDecoration(DecorationKind.campfireRing, 'Campfire', 95), isTrue);
    expect(controller.incomePerMinute, greaterThan(beforeDeco));

    // Camera ground raycast round-trips target cleanly
    const viewport = Size(1280, 720);
    final projected = controller.camera.project(const Vec3(0, 0, 4), viewport);
    final groundHit = controller.camera.screenToGround(projected.offset, viewport);
    expect((groundHit.x).abs(), lessThan(0.05));
    expect((groundHit.z - 4.0).abs(), lessThan(0.05));

    for (int i = 0; i < 240; i++) {
      controller.tick(0.05);
    }
    for (final car in controller.vehicles) {
      expect(car.yaw.isFinite, isTrue);
    }
  });
}
