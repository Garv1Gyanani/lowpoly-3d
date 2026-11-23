import 'package:flutter/material.dart';

import '../../models/game_models.dart';
import '../../systems/game_controller.dart';
import '../../theme/desert_palette.dart';
import '../formatters.dart';
import '../game_hud_widgets.dart';

enum ActiveGameTray { none, build, upgrade }

/// Slim horizontal wooden game card deck that docks unobtrusively at the bottom
/// so the 3D desert stays completely visible while building or upgrading.
class GameActionTray extends StatelessWidget {
  const GameActionTray({
    super.key,
    required this.controller,
    required this.mode,
    required this.onClose,
  });

  final GameController controller;
  final ActiveGameTray mode;
  final VoidCallback onClose;

  static const _decoCatalog = [
    (DecorationKind.saguaroCluster, 'Cactus', 35.0, Icons.park_rounded),
    (DecorationKind.picnicSet, 'Picnic', 55.0, Icons.deck_rounded),
    (DecorationKind.woodenSignpost, 'Signpost', 45.0, Icons.signpost_rounded),
    (DecorationKind.desertLamp, 'Lantern', 75.0, Icons.light_mode_rounded),
    (DecorationKind.campfireRing, 'Campfire', 95.0, Icons.local_fire_department_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    if (mode == ActiveGameTray.none) return const SizedBox.shrink();

    final cards = mode == ActiveGameTray.build
        ? _buildDeckCards()
        : _upgradeDeckCards();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GameWoodPanel(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        radius: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  mode == ActiveGameTray.build
                      ? Icons.handyman_rounded
                      : Icons.arrow_circle_up_rounded,
                  size: 16,
                  color: GameHudColors.woodFrame,
                ),
                const SizedBox(width: 6),
                Text(
                  mode == ActiveGameTray.build ? 'BUILD' : 'UPGRADE',
                  style: const TextStyle(
                    color: GameHudColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: GameHudColors.woodFrame.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: GameHudColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => cards[i],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDeckCards() {
    final items = <Widget>[];

    // 1. Next Parking Tier card (always first if not maxed!)
    final nextPark = controller.nextParkingTier;
    if (nextPark != null) {
      items.add(
        _GameDeckCard(
          icon: Icons.local_parking_rounded,
          accent: GameHudColors.greenTop,
          title: nextPark.name,
          subtitle: '${nextPark.spaces} spaces',
          costText: formatCash(nextPark.cost),
          canAfford: controller.cash >= nextPark.cost,
          onTap: controller.upgradeParking,
        ),
      );
    }

    // 2. Unlocked open construction plots
    for (final plot in controller.visiblePlots.where((p) => !p.isBuilt)) {
      final data = kBusinessCatalog[plot.businessType]!;
      items.add(
        _GameDeckCard(
          icon: data.icon,
          accent: data.accentColor,
          title: _shortTitle(data.name),
          subtitle: '+${formatCash(data.baseIncomePerMin)}/m',
          costText: formatCash(data.purchaseCost),
          canAfford: controller.cash >= data.purchaseCost,
          onTap: () => controller.buildOnPlot(plot),
        ),
      );
    }

    // 3. Desert decorations
    if (controller.canAddMoreDecorations) {
      for (final (kind, name, cost, icon) in _decoCatalog) {
        items.add(
          _GameDeckCard(
            icon: icon,
            accent: DesertPalette.wood,
            title: name,
            subtitle: 'Prop',
            costText: formatCash(cost),
            canAfford: controller.cash >= cost,
            onTap: () => controller.placeDecoration(kind, name, cost),
          ),
        );
      }
    }

    return items;
  }

  List<Widget> _upgradeDeckCards() {
    final items = <Widget>[];

    // 1. Tap / Counter power upgrade
    final tapCost = controller.tapUpgradeCost;
    items.add(
      _GameDeckCard(
        icon: Icons.touch_app_rounded,
        accent: GameHudColors.goldBase,
        title: 'Tap Power',
        subtitle: 'Lv ${controller.tapUpgradeLevel} → +\$5',
        costText: formatCash(tapCost),
        canAfford: controller.cash >= tapCost,
        isUpgrade: true,
        onTap: controller.upgradeTapPower,
      ),
    );

    // 2. Every built business upgrade
    for (final plot in controller.plots.where((p) => p.isBuilt)) {
      final data = kBusinessCatalog[plot.businessType]!;
      final isMax = plot.level >= data.maxLevel;
      final cost = data.upgradeCostForLevel(plot.level);
      items.add(
        _GameDeckCard(
          icon: data.icon,
          accent: data.accentColor,
          title: _shortTitle(data.name),
          subtitle: isMax ? 'MAX LV' : 'Lv ${plot.level} → ${plot.level + 1}',
          costText: isMax ? 'MAX' : formatCash(cost),
          canAfford: !isMax && controller.cash >= cost,
          isUpgrade: true,
          onTap: isMax ? null : () => controller.upgradePlot(plot),
        ),
      );
    }

    return items;
  }

  String _shortTitle(String full) {
    if (full.length <= 13) return full;
    return full.split(' ').take(2).join(' ');
  }
}

class _GameDeckCard extends StatelessWidget {
  const _GameDeckCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.costText,
    required this.canAfford,
    required this.onTap,
    this.isUpgrade = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String costText;
  final bool canAfford;
  final VoidCallback? onTap;
  final bool isUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
      decoration: BoxDecoration(
        color: GameHudColors.parchmentDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canAfford ? GameHudColors.woodFrame : GameHudColors.woodRim.withValues(alpha: 0.45),
          width: 1.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: GameHudColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: GameHudColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 10.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(
            width: double.infinity,
            child: GameBevelButton(
              enabled: canAfford && onTap != null,
              onTap: onTap,
              topColor: isUpgrade ? GameHudColors.terraTop : GameHudColors.greenTop,
              baseColor: isUpgrade ? GameHudColors.terraBase : GameHudColors.greenBase,
              radius: 10,
              bevelDepth: 2.5,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
              child: Center(
                child: Text(
                  costText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
