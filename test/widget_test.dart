import 'package:desert_outpost/main.dart';
import 'package:desert_outpost/models/game_models.dart';
import 'package:desert_outpost/systems/game_controller.dart';
import 'package:desert_outpost/ui/object_studio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Desert Outpost renders carved-wood game HUD, in-world bubbles, and slim trays', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DesertOutpostApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BUILD'), findsOneWidget);
    expect(find.text('UPGRADE'), findsOneWidget);
    expect(find.textContaining('SELL'), findsOneWidget);
    expect(find.textContaining('DIRT LOT'), findsOneWidget);

    // Tap 8 times ($5 * 8 = $40) -> Dirt Lot in-world bubble becomes affordable & builds on tap!
    for (int i = 0; i < 8; i++) {
      await tester.tap(find.textContaining('SELL'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.textContaining('DIRT LOT'));
    await tester.pump(const Duration(milliseconds: 100));

    // After Tier 1 Dirt Lot is built, primary action button switches to SERVE
    expect(find.textContaining('SERVE'), findsOneWidget);

    // Open slim horizontal Build tray
    await tester.tap(find.text('BUILD'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Gravel Lot & Lamps'), findsOneWidget);
  });

  testWidgets('3D Object Studio renders modular assets and switches objects', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ObjectStudioScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cart / Stall'), findsWidgets);
    expect(find.text('lib/world/buildings/vendor_cart.dart'), findsOneWidget);

    await tester.tap(find.text('Desert Diner'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('lib/world/buildings/desert_diner.dart'), findsOneWidget);
  });

  test('Stage 1 starts with 0 parking and 0 visitors until Dirt Pull-Off is built', () {
    final controller = GameController(initialPreset: OutpostPreset.stageOneCareer);
    expect(controller.parkingTier, 0);
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
    expect(controller.vehicles, isNotEmpty);
  });

  test('Full City preset constructs plots, upgrades buildings, and simulates traffic', () {
    final controller = GameController(initialPreset: OutpostPreset.fullCity);
    expect(controller.parkingTier, 3);
    expect(controller.builtCount, 7);
    expect(controller.plots.length, 8);
    expect(controller.incomePerMinute, greaterThan(0));

    final openPlot = controller.plots.firstWhere((p) => !p.isBuilt);
    expect(openPlot.businessType, BusinessType.oasisPlaza);
    expect(controller.buildOnPlot(openPlot), isTrue);
    expect(controller.builtCount, 8);

    for (int i = 0; i < 240; i++) {
      controller.tick(0.05);
    }
    for (final car in controller.vehicles) {
      expect(car.yaw.isFinite, isTrue);
    }
  });
}
