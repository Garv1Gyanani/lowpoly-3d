import 'package:flutter/widgets.dart';

import '../../models/game_models.dart';
import '../../systems/game_controller.dart';
import '../../theme/desert_palette.dart';
import '../formatters.dart';
import '../game_hud_widgets.dart';
import '../game_icons.dart';

enum ActiveGameTray { none, build, upgrade }

/// Slim horizontal wooden game card deck featuring live miniature 3D isometric previews
/// of each landmark & prop so the player sees exactly what they are constructing!
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
    (DecorationKind.saguaroCluster, 'Cactus', 35.0),
    (DecorationKind.picnicSet, 'Picnic', 55.0),
    (DecorationKind.woodenSignpost, 'Signpost', 45.0),
    (DecorationKind.desertLamp, 'Lantern', 75.0),
    (DecorationKind.campfireRing, 'Campfire', 95.0),
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
                GameIcon(
                  mode == ActiveGameTray.build
                      ? GameIconKind.hammer
                      : GameIconKind.upgradeArrow,
                  size: 16,
                  color: GameHudColors.woodFrame,
                ),
                const SizedBox(width: 6),
                Text(
                  mode == ActiveGameTray.build ? 'BUILD' : 'UPGRADE',
                  style: DesertTypography.display(
                    size: 12,
                    color: GameHudColors.ink,
                    letterSpacing: 0.9,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: GameHudColors.woodFrame.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const GameIcon(
                      GameIconKind.chevronDown,
                      size: 16,
                      color: GameHudColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 118,
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

    final nextPark = controller.nextParkingTier;
    if (nextPark != null) {
      items.add(
        _GameDeckCard(
          preview: Container(
            width: 44,
            height: 32,
            decoration: BoxDecoration(
              color: GameHudColors.greenTop.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: GameIcon(GameIconKind.parking, size: 22, color: GameHudColors.greenBase),
            ),
          ),
          title: nextPark.name,
          subtitle: '${nextPark.spaces} spaces',
          costText: formatCash(nextPark.cost),
          canAfford: controller.cash >= nextPark.cost,
          onTap: controller.upgradeParking,
        ),
      );
    }

    for (final plot in controller.visiblePlots.where((p) => !p.isBuilt)) {
      final data = kBusinessCatalog[plot.businessType]!;
      items.add(
        _GameDeckCard(
          preview: Mini3DAssetPreview(businessType: plot.businessType, level: 2),
          title: _shortTitle(data.name),
          subtitle: '+${formatCash(data.baseIncomePerMin)}/m',
          costText: formatCash(data.purchaseCost),
          canAfford: controller.cash >= data.purchaseCost,
          onTap: () => controller.buildOnPlot(plot),
        ),
      );
    }

    if (controller.canAddMoreDecorations) {
      for (final (kind, name, cost) in _decoCatalog) {
        items.add(
          _GameDeckCard(
            preview: Mini3DAssetPreview(decorationKind: kind),
            title: name,
            subtitle: '+4% Tips',
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

    final tapCost = controller.tapUpgradeCost;
    items.add(
      _GameDeckCard(
        preview: Container(
          width: 44,
          height: 32,
          decoration: BoxDecoration(
            color: GameHudColors.goldTop.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: GameIcon(GameIconKind.tapHand, size: 22, color: GameHudColors.woodFrame),
          ),
        ),
        title: 'Tap Power',
        subtitle: 'Lv ${controller.tapUpgradeLevel} → +\$5',
        costText: formatCash(tapCost),
        canAfford: controller.cash >= tapCost,
        isUpgrade: true,
        onTap: controller.upgradeTapPower,
      ),
    );

    for (final plot in controller.plots.where((p) => p.isBuilt)) {
      final data = kBusinessCatalog[plot.businessType]!;
      final isMax = plot.level >= data.maxLevel;
      final cost = data.upgradeCostForLevel(plot.level);
      final previewLv = isMax ? plot.level : (plot.level + 1);
      items.add(
        _GameDeckCard(
          preview: Mini3DAssetPreview(businessType: plot.businessType, level: previewLv),
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
    required this.preview,
    required this.title,
    required this.subtitle,
    required this.costText,
    required this.canAfford,
    required this.onTap,
    this.isUpgrade = false,
  });

  final Widget preview;
  final String title;
  final String subtitle;
  final String costText;
  final bool canAfford;
  final VoidCallback? onTap;
  final bool isUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
      decoration: BoxDecoration(
        color: GameHudColors.parchmentDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canAfford
              ? GameHudColors.woodFrame
              : GameHudColors.woodRim.withValues(alpha: 0.45),
          width: 1.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          preview,
          Text(
            title,
            style: DesertTypography.ui(
              size: 11.2,
              weight: FontWeight.w700,
              color: GameHudColors.ink,
              height: 1.05,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: DesertTypography.ui(
              size: 10.0,
              weight: FontWeight.w600,
              color: GameHudColors.inkMuted,
              height: 1.05,
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
              padding: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 6),
              child: Center(
                child: Text(
                  costText,
                  style: DesertTypography.display(
                    size: 10.8,
                    color: const Color(0xFFFFFFFF),
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
