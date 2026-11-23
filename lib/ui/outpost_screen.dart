import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/renderer_3d.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../systems/game_controller.dart';
import '../theme/desert_palette.dart';
import 'formatters.dart';
import 'game_hud_widgets.dart';
import 'overlays/game_action_tray.dart';
import 'overlays/game_menu_dialog.dart';

/// Pure game-first portrait screen for Desert Outpost:
/// - Tapping buildings/cart = instant cash + coin burst (never pops up an app card!)
/// - In-world floating 3D bubbles for parking expansion, open plots & affordable upgrades
/// - Minimal carved-wood HUD (top-left coin counter, top-right gear button, bottom tactile controls)
class OutpostScreen extends StatefulWidget {
  const OutpostScreen({super.key});

  @override
  State<OutpostScreen> createState() => _OutpostScreenState();
}

class _OutpostScreenState extends State<OutpostScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _controller;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _baseZoom = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  ActiveGameTray _activeTray = ActiveGameTray.none;

  @override
  void initState() {
    super.initState();
    _controller = GameController(initialPreset: OutpostPreset.stageOneCareer);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    _controller.tick(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleTray(ActiveGameTray tray) {
    setState(() {
      _activeTray = _activeTray == tray ? ActiveGameTray.none : tray;
    });
  }

  void _openGameMenu() {
    setState(() => _activeTray = ActiveGameTray.none);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => GameMenuDialog(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesertPalette.sky,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full-bleed interactive 3D Low-Poly Desert Outpost World
              Positioned.fill(
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      final factor = event.scrollDelta.dy > 0 ? 0.92 : 1.08;
                      _controller.zoomCamera(factor);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      if (_activeTray != ActiveGameTray.none) {
                        setState(() => _activeTray = ActiveGameTray.none);
                      }
                      _controller.handleWorldTap(
                        details.localPosition,
                        viewportSize,
                      );
                    },
                    onScaleStart: (details) {
                      _baseZoom = _controller.camera.zoom;
                      _lastFocalPoint = details.focalPoint;
                    },
                    onScaleUpdate: (details) {
                      if (details.pointerCount >= 2) {
                        _controller.camera.zoom = (_baseZoom * details.scale)
                            .clamp(0.75, 1.70);
                      }
                      final delta = details.focalPoint - _lastFocalPoint;
                      _lastFocalPoint = details.focalPoint;
                      _controller.panCamera(delta, viewportSize);
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: DesertOutpostPainter(controller: _controller),
                        size: viewportSize,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Diegetic In-World Floating 3D Action Bubbles (Parking, Open Plots, Affordable Upgrades)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Stack(
                      children: _buildInWorldBubbles(viewportSize),
                    );
                  },
                ),
              ),

              // 3. Minimalist Top Game HUD (Coin Counter + single Gear icon)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final claimable = _controller.claimableMilestoneCount;
                        return Row(
                          children: [
                            GameCoinHud(
                              cashText: formatCash(_controller.cash),
                              rateText: _controller.incomePerMinute > 0
                                  ? '+${formatCash(_controller.incomePerMinute)}/min'
                                  : 'Tap cart to earn',
                              hasPassiveIncome: _controller.incomePerMinute > 0,
                            ),
                            const Spacer(),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GameBevelButton(
                                  onTap: _openGameMenu,
                                  radius: 14,
                                  bevelDepth: 3.5,
                                  padding: const EdgeInsets.all(10),
                                  child: const Icon(
                                    Icons.settings_rounded,
                                    size: 20,
                                    color: Color(0xFFFFF2D4),
                                  ),
                                ),
                                if (claimable > 0)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GameHudColors.goldTop,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: GameHudColors.woodFrame,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        '$claimable',
                                        style: const TextStyle(
                                          color: GameHudColors.ink,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 4. Bottom Game Controls (Optional slim horizontal card tray + 3 chunky physical game buttons)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final nextPark = _controller.nextParkingTier;
                      final canBuildSomething =
                          (nextPark != null && _controller.cash >= nextPark.cost) ||
                          _controller.visiblePlots.any(
                            (p) =>
                                !p.isBuilt &&
                                _controller.cash >=
                                    kBusinessCatalog[p.businessType]!.purchaseCost,
                          );
                      final canUpgradeSomething =
                          _controller.cash >= _controller.tapUpgradeCost ||
                          _controller.plots.any((p) {
                            if (!p.isBuilt) return false;
                            final d = kBusinessCatalog[p.businessType]!;
                            return p.level < d.maxLevel &&
                                _controller.cash >= d.upgradeCostForLevel(p.level);
                          });

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GameActionTray(
                            controller: _controller,
                            mode: _activeTray,
                            onClose: () =>
                                setState(() => _activeTray = ActiveGameTray.none),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Bottom-Left: Build Deck Hammer Button
                                _CornerGameButton(
                                  icon: Icons.handyman_rounded,
                                  label: 'BUILD',
                                  active: _activeTray == ActiveGameTray.build,
                                  highlightDot: canBuildSomething,
                                  onTap: () => _toggleTray(ActiveGameTray.build),
                                ),

                                // Bottom-Center: Big Juicy Tactile Tap / Sell Game Button
                                GameBevelButton(
                                  onTap: () => _controller.performActiveTap(),
                                  topColor: GameHudColors.terraTop,
                                  baseColor: GameHudColors.terraBase,
                                  borderColor: GameHudColors.woodFrame,
                                  radius: 22,
                                  bevelDepth: 5.0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 13,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_drink_rounded,
                                        color: Color(0xFFFFF3D6),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _controller.parkingTier == 0
                                            ? 'SELL  +${formatCash(_controller.tapIncome)}'
                                            : 'SERVE  +${formatCash(_controller.tapIncome)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          letterSpacing: 0.6,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black38,
                                              offset: Offset(0, 1.5),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Bottom-Right: Upgrade Deck Up-Arrow Button
                                _CornerGameButton(
                                  icon: Icons.arrow_circle_up_rounded,
                                  label: 'UPGRADE',
                                  active: _activeTray == ActiveGameTray.upgrade,
                                  highlightDot: canUpgradeSomething,
                                  onTap: () => _toggleTray(ActiveGameTray.upgrade),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Projects floating diegetic 3D game bubbles right over actionable world spots.
  List<Widget> _buildInWorldBubbles(Size viewport) {
    final bubbles = <Widget>[];
    final bob = math.sin(_controller.animTime * 3.4) * 3.5;

    // 1. Floating Parking Upgrade Bubble right over the roadside shoulder!
    final nextPark = _controller.nextParkingTier;
    if (nextPark != null) {
      final canAfford = _controller.cash >= nextPark.cost;
      // Show always at Tier 0 so the player sees the goal right on the desert,
      // and show for Tier 2/3 once affordable so the world stays ultra-clean!
      if (_controller.parkingTier == 0 || canAfford) {
        final anchor = _controller.camera.project(const Vec3(0.2, 1.4, 9.6), viewport);
        if (anchor.inFront &&
            anchor.offset.dx > 36 &&
            anchor.offset.dx < viewport.width - 36 &&
            anchor.offset.dy > 95 &&
            anchor.offset.dy < viewport.height - 140) {
          bubbles.add(
            Positioned(
              left: anchor.offset.dx,
              top: anchor.offset.dy - 34 + (canAfford ? bob : 0),
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: WorldActionBubble(
                  icon: Icons.local_parking_rounded,
                  label: nextPark.tier == 1 ? 'DIRT LOT' : 'EXPAND LOT',
                  costText: formatCash(nextPark.cost),
                  canAfford: canAfford,
                  onTap: _controller.upgradeParking,
                ),
              ),
            ),
          );
        }
      }
    }

    // 2. Open Construction Plots & Affordable Building Upgrade Bubbles
    for (final plot in _controller.visiblePlots) {
      final data = kBusinessCatalog[plot.businessType]!;

      if (!plot.isBuilt) {
        final canAfford = _controller.cash >= data.purchaseCost;
        final anchor = _controller.camera.project(
          plot.position + const Vec3(0, 2.5, 0),
          viewport,
        );
        if (!anchor.inFront ||
            anchor.offset.dx < 30 ||
            anchor.offset.dx > viewport.width - 30 ||
            anchor.offset.dy < 90 ||
            anchor.offset.dy > viewport.height - 140) {
          continue;
        }
        final shortName = data.name.split(' ').last.toUpperCase();
        bubbles.add(
          Positioned(
            left: anchor.offset.dx,
            top: anchor.offset.dy - 32 + (canAfford ? bob : 0),
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: WorldActionBubble(
                icon: Icons.handyman_rounded,
                label: shortName,
                costText: formatCash(data.purchaseCost),
                canAfford: canAfford,
                onTap: () => _controller.buildOnPlot(plot),
              ),
            ),
          ),
        );
      } else if (plot.level < data.maxLevel) {
        // Only float a compact gold upgrade arrow over a built building when affordable!
        final cost = data.upgradeCostForLevel(plot.level);
        if (_controller.cash >= cost) {
          final anchor = _controller.camera.project(
            plot.position + const Vec3(0, 3.8, 0),
            viewport,
          );
          if (!anchor.inFront ||
              anchor.offset.dx < 30 ||
              anchor.offset.dx > viewport.width - 30 ||
              anchor.offset.dy < 90 ||
              anchor.offset.dy > viewport.height - 140) {
            continue;
          }
          bubbles.add(
            Positioned(
              left: anchor.offset.dx,
              top: anchor.offset.dy - 30 + bob,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: WorldActionBubble(
                  icon: Icons.arrow_upward_rounded,
                  label: 'LV${plot.level + 1}',
                  costText: formatCash(cost),
                  canAfford: true,
                  accentColor: GameHudColors.goldTop,
                  accentBase: GameHudColors.goldBase,
                  onTap: () => _controller.upgradePlot(plot),
                ),
              ),
            ),
          );
        }
      }
    }

    return bubbles;
  }
}

class _CornerGameButton extends StatelessWidget {
  const _CornerGameButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.highlightDot,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool highlightDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GameBevelButton(
          onTap: onTap,
          topColor: active ? GameHudColors.goldTop : GameHudColors.woodBody,
          baseColor: active ? GameHudColors.goldBase : GameHudColors.woodDeep,
          radius: 16,
          bevelDepth: 4.0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? GameHudColors.ink : const Color(0xFFFFF2D4),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: active ? GameHudColors.ink : const Color(0xFFFFE7B8),
                  fontWeight: FontWeight.w900,
                  fontSize: 9.5,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        if (highlightDot && !active)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: GameHudColors.greenTop,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFF4D2), width: 1.8),
              ),
            ),
          ),
      ],
    );
  }
}
