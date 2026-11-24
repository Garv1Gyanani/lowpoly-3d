import 'package:flutter/widgets.dart';

import '../../models/game_models.dart';
import '../../systems/game_controller.dart';
import '../../theme/desert_palette.dart';
import '../formatters.dart';
import '../game_hud_widgets.dart';
import '../game_icons.dart';

enum ActiveGameTray { none, build, upgrade }

/// Slim horizontal wooden game card deck featuring live miniature 3D isometric previews,
/// road painting entry, freeform parking & store placement, and progression-gated upgrades!
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
    (DecorationKind.saguaroCluster, 'Cactus', 35.0, '+4% Tips'),
    (DecorationKind.woodenSignpost, 'Signpost', 45.0, '+8% Traffic'),
    (DecorationKind.picnicSet, 'Picnic', 55.0, '+4% Tips'),
    (DecorationKind.desertLamp, 'Lantern', 75.0, '+4% Tips'),
    (DecorationKind.campfireRing, 'Campfire', 95.0, '+4% Tips'),
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
                  mode == ActiveGameTray.build
                      ? 'BUILD · STAGE ${controller.outpostStage}'
                      : 'UPGRADE & MOVE',
                  style: DesertTypography.display(
                    size: 11.5,
                    color: GameHudColors.ink,
                    letterSpacing: 0.8,
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
              height: 126,
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

    // 1. Roads Paint Mode Card
    items.add(
      _GameDeckCard(
        preview: Container(
          width: 44,
          height: 32,
          decoration: BoxDecoration(
            color: GameHudColors.woodFrame.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: GameIcon(GameIconKind.road, size: 22, color: GameHudColors.woodFrame),
          ),
        ),
        title: 'Build Roads',
        subtitle: '${controller.roadNetwork.roadCount} tiles laid',
        costText: 'DRAW',
        canAfford: true,
        onTap: () {
          onClose();
          controller.enterRoadPaintMode();
        },
      ),
    );

    // 1b. Buy Land parcels (progression-capped)
    items.add(
      _GameDeckCard(
        preview: Container(
          width: 44,
          height: 32,
          decoration: BoxDecoration(
            color: GameHudColors.goldTop.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: GameIcon(GameIconKind.centerFocus, size: 22, color: GameHudColors.woodFrame),
          ),
        ),
        title: 'Buy Land',
        subtitle:
            '${controller.ownedParcelCount}/${controller.stageInfo.maxParcels} parcels',
        costText: controller.canBuyMoreLand
            ? formatCash(controller.nextParcelPrice)
            : 'STAGE ${controller.outpostStage + 1}',
        canAfford: controller.canBuyMoreLand,
        onTap: () {
          onClose();
          controller.enterLandMode();
        },
      ),
    );

    // 2. Freely Placeable Parking Lots (unlocked first, then progression-locked)
    final parkingKinds = [...ParkingLotKind.values]..sort((a, b) {
        final ua = controller.isParkingKindUnlocked(a) ? 0 : 1;
        final ub = controller.isParkingKindUnlocked(b) ? 0 : 1;
        return ua != ub ? ua.compareTo(ub) : a.index.compareTo(b.index);
      });
    for (final kind in parkingKinds) {
      final spec = kParkingLotCatalog[kind]!;
      final unlocked = controller.isParkingKindUnlocked(kind);
      if (!unlocked) continue;
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
              child: GameIcon(
                GameIconKind.parking,
                size: 22,
                color: GameHudColors.greenBase,
              ),
            ),
          ),
          title: spec.name,
          subtitle: '${spec.spaces} bays · Place',
          costText: formatCash(spec.cost),
          canAfford: controller.cash >= spec.cost,
          onTap: () {
            onClose();
            controller.startPlacingParking(kind);
          },
        ),
      );
    }

    // 3. Unbuilt Stores sorted by unlock status & Stage — unlocked stores appear first!
    final unbuiltSorted = [...controller.availableUnbuiltPlots]..sort((a, b) {
        final ua = controller.isPlotUnlocked(a) ? 0 : 1;
        final ub = controller.isPlotUnlocked(b) ? 0 : 1;
        return ua != ub ? ua.compareTo(ub) : a.data.stage.compareTo(b.data.stage);
      });
    for (final plot in unbuiltSorted) {
      final data = plot.data;
      final unlocked = controller.isPlotUnlocked(plot);
      items.add(
        _GameDeckCard(
          preview: Mini3DAssetPreview(businessType: plot.businessType, level: 2),
          title: _shortTitle(data.name),
          subtitle: unlocked
              ? '+${formatCash(data.baseIncomePerMin)}/m'
              : 'Stage ${data.stage} unlock',
          costText: unlocked ? formatCash(data.purchaseCost) : 'STAGE ${data.stage}',
          canAfford: unlocked && controller.cash >= data.purchaseCost,
          onTap: unlocked
              ? () {
                  onClose();
                  controller.startPlacingBuilding(plot.businessType);
                }
              : null,
        ),
      );
    }

    // Locked future parking lots shown right after stores as clear progression goals
    for (final kind in parkingKinds) {
      if (controller.isParkingKindUnlocked(kind)) continue;
      final spec = kParkingLotCatalog[kind]!;
      items.add(
        _GameDeckCard(
          preview: Container(
            width: 44,
            height: 32,
            decoration: BoxDecoration(
              color: GameHudColors.stoneTop.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: GameIcon(
                GameIconKind.parking,
                size: 22,
                color: GameHudColors.inkMuted,
              ),
            ),
          ),
          title: spec.name,
          subtitle: '${spec.spaces} bays · Stage ${spec.unlockStage}',
          costText: 'STAGE ${spec.unlockStage}',
          canAfford: false,
          onTap: null,
        ),
      );
    }

    // 4. Decorations (progression-gated)
    if (controller.canAddMoreDecorations) {
      for (final (kind, name, cost, bonusText) in _decoCatalog) {
        final unlocked = controller.isDecorationUnlocked(kind);
        final reqStage = controller.decorationUnlockStage(kind);
        items.add(
          _GameDeckCard(
            preview: Mini3DAssetPreview(decorationKind: kind),
            title: name,
            subtitle: bonusText,
            costText: unlocked ? formatCash(cost) : 'STAGE $reqStage',
            canAfford: unlocked && controller.cash >= cost,
            onTap: unlocked
                ? () {
                    onClose();
                    controller.startPlacingDecoration(kind, name, cost);
                  }
                : null,
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

    // Placed Parking Lots: Upgrade in-place (Dirt -> Gravel -> Paved), Move, or Remove!
    for (int i = 0; i < controller.parkingLots.length; i++) {
      final lot = controller.parkingLots[i];
      final nextKind = lot.nextUpgradeKind;
      final isMax = nextKind == null;
      final lockReason = controller.parkingLotUpgradeLockReason(lot);
      final cost = controller.parkingLotUpgradeCost(lot);
      final nextSpaces = nextKind != null ? kParkingLotCatalog[nextKind]!.spaces : lot.spec.spaces;

      final String btnLabel;
      final bool canPress;
      if (isMax) {
        btnLabel = 'MAX';
        canPress = false;
      } else if (lockReason != null) {
        btnLabel = lockReason;
        canPress = false;
      } else {
        btnLabel = formatCash(cost);
        canPress = controller.cash >= cost;
      }

      final String sub = !lot.isConnected
          ? 'NO ROAD · ${lot.spec.spaces}b'
          : (isMax
              ? '${lot.spec.spaces} bays · MAX'
              : '${lot.spec.spaces} → $nextSpaces bays');

      items.add(
        _GameDeckCard(
          preview: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 32,
                decoration: BoxDecoration(
                  color: lot.isConnected
                      ? GameHudColors.greenTop.withValues(alpha: 0.20)
                      : GameHudColors.terraTop.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: GameIcon(
                    GameIconKind.parking,
                    size: 22,
                    color: lot.isConnected ? GameHudColors.greenBase : GameHudColors.terraBase,
                  ),
                ),
              ),
              Positioned(
                left: -28,
                top: -2,
                child: GestureDetector(
                  onTap: () => controller.removeParkingLot(lot),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: GameHudColors.terraBase,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: GameHudColors.woodFrame, width: 1.2),
                    ),
                    child: const GameIcon(
                      GameIconKind.trash,
                      size: 11,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -28,
                top: -2,
                child: GestureDetector(
                  onTap: () {
                    onClose();
                    controller.startRelocatingParkingLot(lot);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: GameHudColors.woodBody,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: GameHudColors.woodFrame, width: 1.2),
                    ),
                    child: const GameIcon(
                      GameIconKind.move,
                      size: 11,
                      color: Color(0xFFFFF2D4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          title: lot.spec.name,
          subtitle: sub,
          subtitleColor: !lot.isConnected ? GameHudColors.terraBase : GameHudColors.greenBase,
          costText: btnLabel,
          canAfford: canPress,
          isUpgrade: true,
          onTap: canPress ? () => controller.upgradeParkingLot(lot) : null,
        ),
      );
    }

    for (final plot in controller.plots.where((p) => p.isBuilt)) {
      final data = plot.data;
      final isMax = plot.level >= data.maxLevel;
      final lockReason = controller.upgradeLockReason(plot);
      final cost = data.upgradeCostForLevel(plot.level);
      final previewLv = isMax ? plot.level : (plot.level + 1);
      final accessPct = plot.access.percent;

      final String btnLabel;
      final bool canPress;
      if (isMax) {
        btnLabel = 'MAX';
        canPress = false;
      } else if (lockReason != null) {
        btnLabel = lockReason;
        canPress = false;
      } else {
        btnLabel = formatCash(cost);
        canPress = controller.cash >= cost;
      }

      items.add(
        _GameDeckCard(
          preview: Stack(
            clipBehavior: Clip.none,
            children: [
              Mini3DAssetPreview(businessType: plot.businessType, level: previewLv),
              Positioned(
                right: -28,
                top: -2,
                child: GestureDetector(
                  onTap: () {
                    onClose();
                    controller.startRelocatingPlot(plot);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: GameHudColors.woodBody,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: GameHudColors.woodFrame, width: 1.2),
                    ),
                    child: const GameIcon(
                      GameIconKind.move,
                      size: 11,
                      color: Color(0xFFFFF2D4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          title: _shortTitle(data.name),
          subtitle: 'Lv${plot.level} · Road $accessPct%',
          subtitleColor: accessPct == 0
              ? GameHudColors.terraBase
              : (accessPct >= 88 ? GameHudColors.greenBase : GameHudColors.inkMuted),
          costText: btnLabel,
          canAfford: canPress,
          isUpgrade: true,
          onTap: canPress ? () => controller.upgradePlot(plot) : null,
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
    this.subtitleColor,
  });

  final Widget preview;
  final String title;
  final String subtitle;
  final String costText;
  final bool canAfford;
  final VoidCallback? onTap;
  final bool isUpgrade;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
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
              color: subtitleColor ?? GameHudColors.inkMuted,
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
                    size: 10.0,
                    color: const Color(0xFFFFFFFF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
