import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../engine/camera_3d.dart';
import '../engine/renderer_3d.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../systems/game_controller.dart';
import '../theme/desert_palette.dart';
import 'formatters.dart';
import 'game_hud_widgets.dart';
import 'game_icons.dart';
import 'overlays/game_action_tray.dart';
import 'overlays/game_menu_dialog.dart';

/// Main Desert Outpost screen:
/// - Responsive widescreen & portrait camera + centered HUD framing
/// - Decoupled 60–120 Hz `renderListenable` vs discrete HUD state rebuilds
/// - Right-drag / Shift-drag / `Q` & `E` horizontal diorama orbit
/// - Visible top Goal/Milestone pill & offline welcome-back banner
class OutpostScreen extends StatefulWidget {
  const OutpostScreen({super.key});

  @override
  State<OutpostScreen> createState() => _OutpostScreenState();
}

class _OutpostScreenState extends State<OutpostScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _controller;
  late final Ticker _ticker;
  final FocusNode _focusNode = FocusNode();
  Duration _lastTick = Duration.zero;
  double _baseZoom = 1.0;
  double _baseYaw = 0.0;
  Offset _lastFocalPoint = Offset.zero;
  int _activePointerButtons = 0;
  ActiveGameTray _activeTray = ActiveGameTray.none;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      initialPreset: OutpostPreset.stageOneCareer,
      enablePersistence: true,
    );
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
    _focusNode.dispose();
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
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Menu',
      barrierColor: const Color(0xFF000000).withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, _) => GameMenuDialog(controller: _controller),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyQ ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _controller.orbitCamera(-0.045);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyE ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _controller.orbitCamera(0.045);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ColoredBox(
        color: DesertPalette.sky,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-bleed interactive 3D Low-Poly Desert Outpost World
                Positioned.fill(
                  child: Listener(
                    onPointerDown: (e) => _activePointerButtons = e.buttons,
                    onPointerMove: (e) {
                      // Right-click or middle-click drag orbits the diorama horizontally!
                      if ((e.buttons & kSecondaryMouseButton) != 0 ||
                          (e.buttons & kMiddleMouseButton) != 0) {
                        _controller.orbitCamera(-e.delta.dx * 0.0045);
                      }
                    },
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
                        _baseYaw = _controller.camera.yaw;
                        _lastFocalPoint = details.focalPoint;
                      },
                      onScaleUpdate: (details) {
                        if ((_activePointerButtons & kSecondaryMouseButton) != 0) {
                          return;
                        }
                        final shiftHeld = HardwareKeyboard.instance.isShiftPressed;
                        if (details.pointerCount >= 2) {
                          _controller.camera.zoom = (_baseZoom * details.scale)
                              .clamp(0.70, 1.85);
                          if (details.rotation.abs() > 0.02) {
                            _controller.camera.yaw = (_baseYaw - details.rotation * 0.45)
                                .clamp(Camera3D.minYaw, Camera3D.maxYaw);
                          }
                        }
                        final delta = details.focalPoint - _lastFocalPoint;
                        _lastFocalPoint = details.focalPoint;
                        if (shiftHeld) {
                          _controller.orbitCamera(-delta.dx * 0.0045);
                        } else {
                          _controller.panCamera(delta, viewportSize);
                        }
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

                // 2. Diegetic In-World Floating 3D Action Bubbles
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_controller, _controller.renderListenable]),
                    builder: (context, _) {
                      return Stack(
                        children: _buildInWorldBubbles(viewportSize),
                      );
                    },
                  ),
                ),

                // 3. Responsive Top Game HUD (Centered max-width on widescreen monitors!)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final claimable = _controller.claimableMilestoneCount;
                              final milestone = _controller.nextActiveMilestone;
                              final milestoneReady =
                                  milestone != null && !milestone.claimed && milestone.checkCompleted();

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      GameCoinHud(
                                        cashText: formatCash(_controller.cash),
                                        rateText: _controller.incomePerMinute > 0
                                            ? '+${formatCash(_controller.incomePerMinute)}/min'
                                            : 'Tap cart to earn',
                                        hasPassiveIncome: _controller.incomePerMinute > 0,
                                      ),
                                      const SizedBox(width: 8),
                                      if (milestone != null)
                                        Flexible(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: _MilestoneHudPill(
                                              milestone: milestone,
                                              isReady: milestoneReady,
                                              onTap: () {
                                                if (milestoneReady) {
                                                  _controller.claimMilestone(milestone);
                                                } else {
                                                  _openGameMenu();
                                                }
                                              },
                                            ),
                                          ),
                                        )
                                      else
                                        const Spacer(),
                                      if (milestone == null) const SizedBox.shrink() else const SizedBox(width: 8),
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          GameBevelButton(
                                            onTap: _openGameMenu,
                                            radius: 14,
                                            bevelDepth: 3.5,
                                            padding: const EdgeInsets.all(10),
                                            child: const GameIcon(
                                              GameIconKind.settings,
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
                                                  style: DesertTypography.display(
                                                    size: 9.5,
                                                    color: GameHudColors.ink,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (_controller.pendingOfflineWelcomeCash > 0) ...[
                                    const SizedBox(height: 8),
                                    GameBevelButton(
                                      onTap: _controller.dismissOfflineWelcome,
                                      topColor: GameHudColors.goldTop,
                                      baseColor: GameHudColors.goldBase,
                                      radius: 14,
                                      bevelDepth: 3.0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const GameIcon(
                                            GameIconKind.sparkle,
                                            size: 15,
                                            color: GameHudColors.ink,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'WELCOME BACK! +${formatCash(_controller.pendingOfflineWelcomeCash)} EARNED (${_controller.pendingOfflineMinutes}M)',
                                            style: DesertTypography.display(
                                              size: 10.5,
                                              color: GameHudColors.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Responsive Bottom Game Controls (Centered max-width on widescreen monitors!)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
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
                                      _CornerGameButton(
                                        icon: GameIconKind.hammer,
                                        label: 'BUILD',
                                        active: _activeTray == ActiveGameTray.build,
                                        highlightDot: canBuildSomething,
                                        onTap: () => _toggleTray(ActiveGameTray.build),
                                      ),
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
                                            const GameIcon(
                                              GameIconKind.drinkCup,
                                              color: Color(0xFFFFF3D6),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _controller.parkingTier == 0
                                                  ? 'SELL  +${formatCash(_controller.tapIncome)}'
                                                  : 'SERVE  +${formatCash(_controller.tapIncome)}',
                                              style: DesertTypography.display(
                                                size: 13.5,
                                                color: const Color(0xFFFFFFFF),
                                                letterSpacing: 0.7,
                                                shadows: const [
                                                  Shadow(
                                                    color: Color(0x66000000),
                                                    offset: Offset(0, 1.5),
                                                    blurRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _CornerGameButton(
                                        icon: GameIconKind.upgradeArrow,
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
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildInWorldBubbles(Size viewport) {
    final bubbles = <Widget>[];
    final bob = math.sin(_controller.animTime * 3.4) * 3.5;
    final frame = _controller.camera.createFrame(viewport);

    // 1. Floating Parking Upgrade Bubble
    final nextPark = _controller.nextParkingTier;
    if (nextPark != null) {
      final canAfford = _controller.cash >= nextPark.cost;
      if (_controller.parkingTier == 0 || canAfford) {
        const worldPos = Vec3(0.4, 1.45, 9.6);
        final anchor = frame.project(worldPos);
        if (anchor.inFront &&
            anchor.offset.dx > 36 &&
            anchor.offset.dx < viewport.width - 36 &&
            anchor.offset.dy > 95 &&
            anchor.offset.dy < viewport.height - 135) {
          bubbles.add(
            Positioned(
              left: anchor.offset.dx,
              top: anchor.offset.dy - 36 + (canAfford ? bob : 0),
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: WorldActionBubble(
                  icon: GameIconKind.parking,
                  label: nextPark.tier == 1 ? 'DIRT LOT' : 'EXPAND LOT',
                  costText: formatCash(nextPark.cost),
                  canAfford: canAfford,
                  progress: nextPark.cost > 0 ? (_controller.cash / nextPark.cost) : 1.0,
                  onTap: _controller.upgradeParking,
                  onUnaffordableTap: () =>
                      _controller.notifyShortfall(worldPos, nextPark.cost - _controller.cash),
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
        final worldPos = plot.position + const Vec3(0, 2.2, 0);
        final anchor = frame.project(worldPos);
        if (!anchor.inFront ||
            anchor.offset.dx < 30 ||
            anchor.offset.dx > viewport.width - 30 ||
            anchor.offset.dy < 90 ||
            anchor.offset.dy > viewport.height - 135) {
          continue;
        }
        final shortName = data.name.split(' ').last.toUpperCase();
        bubbles.add(
          Positioned(
            left: anchor.offset.dx,
            top: anchor.offset.dy - 34 + (canAfford ? bob : 0),
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: WorldActionBubble(
                icon: GameIconKind.hammer,
                label: shortName,
                costText: formatCash(data.purchaseCost),
                canAfford: canAfford,
                progress: data.purchaseCost > 0 ? (_controller.cash / data.purchaseCost) : 1.0,
                onTap: () => _controller.buildOnPlot(plot),
                onUnaffordableTap: () => _controller.notifyShortfall(
                  worldPos,
                  data.purchaseCost - _controller.cash,
                ),
              ),
            ),
          ),
        );
      } else if (plot.level < data.maxLevel) {
        final cost = data.upgradeCostForLevel(plot.level);
        if (_controller.cash >= cost) {
          final anchor = frame.project(plot.position + const Vec3(0, 3.8, 0));
          if (!anchor.inFront ||
              anchor.offset.dx < 30 ||
              anchor.offset.dx > viewport.width - 30 ||
              anchor.offset.dy < 90 ||
              anchor.offset.dy > viewport.height - 135) {
            continue;
          }
          bubbles.add(
            Positioned(
              left: anchor.offset.dx,
              top: anchor.offset.dy - 30 + bob,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: WorldActionBubble(
                  icon: GameIconKind.upgradeArrow,
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

class _MilestoneHudPill extends StatelessWidget {
  const _MilestoneHudPill({
    required this.milestone,
    required this.isReady,
    required this.onTap,
  });

  final MilestoneData milestone;
  final bool isReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isReady) {
      return GameBevelButton(
        onTap: onTap,
        topColor: GameHudColors.goldTop,
        baseColor: GameHudColors.goldBase,
        radius: 16,
        bevelDepth: 3.0,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameIcon(GameIconKind.trophy, size: 15, color: GameHudColors.ink),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'CLAIM +${formatCash(milestone.rewardCash)}',
                style: DesertTypography.display(
                  size: 10.5,
                  color: GameHudColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: GameHudColors.woodFrame.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GameHudColors.woodRim.withValues(alpha: 0.8), width: 1.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameIcon(GameIconKind.trophy, size: 13, color: GameHudColors.goldTop),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  milestone.title,
                  style: DesertTypography.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    color: const Color(0xFFFFF2D4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  final GameIconKind icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(
                icon,
                size: 20,
                color: active ? GameHudColors.ink : const Color(0xFFFFF2D4),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: DesertTypography.display(
                  size: 9.2,
                  color: active ? GameHudColors.ink : const Color(0xFFFFE7B8),
                  letterSpacing: 0.5,
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
