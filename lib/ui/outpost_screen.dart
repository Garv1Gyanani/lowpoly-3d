import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

/// Main Desert Outpost screen.
///
/// Camera: one finger always pans, two fingers pinch-zoom / twist-rotate / vertical-drag tilt,
/// right-drag orbits & tilts, WASD/arrows pan, Q/E rotate, T/G tilt, scroll zooms.
/// Build tools: tap to place (or long-press & drag); roads use tap-start / tap-end lines.
class OutpostScreen extends StatefulWidget {
  const OutpostScreen({
    super.key,
    this.enablePersistence = true,
  });

  final bool enablePersistence;

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
  double _lastRotation = 0.0;
  int _activePointerButtons = 0;
  ActiveGameTray _activeTray = ActiveGameTray.none;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      initialPreset: OutpostPreset.stageOneCareer,
      enablePersistence: widget.enablePersistence,
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

  bool get _isPlacing =>
      _controller.toolMode == WorldToolMode.placeBuilding ||
      _controller.toolMode == WorldToolMode.placeParking ||
      _controller.toolMode == WorldToolMode.placeDecoration;

  void _toggleTray(ActiveGameTray tray) {
    if (_controller.toolMode != WorldToolMode.play) {
      _controller.cancelToolMode();
    }
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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final panStep = _controller.camera.distance * 0.06;

    if (key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.arrowUp) {
      _controller.panCameraRelative(0, panStep);
    } else if (key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.arrowDown) {
      _controller.panCameraRelative(0, -panStep);
    } else if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.arrowLeft) {
      _controller.panCameraRelative(-panStep, 0);
    } else if (key == LogicalKeyboardKey.keyD || key == LogicalKeyboardKey.arrowRight) {
      _controller.panCameraRelative(panStep, 0);
    } else if (key == LogicalKeyboardKey.keyQ) {
      _controller.orbitCamera(-0.06);
    } else if (key == LogicalKeyboardKey.keyE) {
      _controller.orbitCamera(0.06);
    } else if (key == LogicalKeyboardKey.keyT || key == LogicalKeyboardKey.pageUp) {
      _controller.tiltCamera(0.04);
    } else if (key == LogicalKeyboardKey.keyG || key == LogicalKeyboardKey.pageDown) {
      _controller.tiltCamera(-0.04);
    } else if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd) {
      _controller.zoomCamera(1.08);
    } else if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      _controller.zoomCamera(0.92);
    } else if (event is KeyDownEvent && key == LogicalKeyboardKey.keyR) {
      _controller.rotateGhost();
    } else if (event is KeyDownEvent && key == LogicalKeyboardKey.escape) {
      if (_controller.toolMode == WorldToolMode.play) return KeyEventResult.ignored;
      _controller.cancelToolMode();
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter)) {
      if (_controller.toolMode == WorldToolMode.paintRoad) {
        _controller.confirmRoadLine();
      } else if (_isPlacing) {
        _controller.confirmPlacement();
      } else {
        return KeyEventResult.ignored;
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
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
                // 1. Full-bleed interactive 3D desert world
                Positioned.fill(child: _buildWorldGestureLayer(viewportSize)),

                // 2. Diegetic in-world bubbles (store actions, land prices)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_controller, _controller.renderListenable]),
                    builder: (context, _) => Stack(children: _buildInWorldBubbles(viewportSize)),
                  ),
                ),

                // 3. Top HUD
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
                            builder: (context, _) => _buildTopHud(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Camera controls (rotate / tilt / home) on the right edge
                Positioned(
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 74, 12, 0),
                      child: _CameraControls(controller: _controller),
                    ),
                  ),
                ),

                // 5. Bottom controls (play / road line / placement / land)
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
                            switch (_controller.toolMode) {
                              case WorldToolMode.paintRoad:
                                return _buildRoadBar();
                              case WorldToolMode.buyLand:
                                return _buildLandBar();
                              case WorldToolMode.placeBuilding:
                              case WorldToolMode.placeParking:
                              case WorldToolMode.placeDecoration:
                                return _buildPlacementBar();
                              case WorldToolMode.play:
                                return _buildPlayBottomBar();
                            }
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

  Widget _buildWorldGestureLayer(Size viewportSize) {
    return Listener(
      onPointerDown: (e) => _activePointerButtons = e.buttons,
      onPointerUp: (_) => _activePointerButtons = 0,
      onPointerMove: (e) {
        // Right / middle drag: horizontal orbit + vertical tilt.
        if ((e.buttons & kSecondaryMouseButton) != 0 || (e.buttons & kMiddleMouseButton) != 0) {
          _controller.orbitCamera(-e.delta.dx * 0.006);
          _controller.tiltCamera(e.delta.dy * 0.004);
        }
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _controller.zoomCamera(event.scrollDelta.dy > 0 ? 0.92 : 1.08);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (_activeTray != ActiveGameTray.none) {
            setState(() => _activeTray = ActiveGameTray.none);
          }
          _controller.handleWorldTap(details.localPosition, viewportSize);
        },
        onLongPressStart: (details) {
          if (_controller.toolMode == WorldToolMode.play) return;
          _controller.beginToolDrag(
            _controller.camera.screenToGround(details.localPosition, viewportSize),
          );
        },
        onLongPressMoveUpdate: (details) {
          if (_controller.toolMode == WorldToolMode.play) return;
          _controller.updateToolDrag(
            _controller.camera.screenToGround(details.localPosition, viewportSize),
          );
        },
        onScaleStart: (details) {
          _baseZoom = _controller.camera.zoom;
          _lastRotation = 0.0;
        },
        onScaleUpdate: (details) {
          if ((_activePointerButtons & (kSecondaryMouseButton | kMiddleMouseButton)) != 0) {
            return;
          }
          if (details.pointerCount >= 2) {
            // Two fingers: pinch zoom, twist rotate, vertical drag tilt.
            _controller.camera.zoom = (_baseZoom * details.scale).clamp(0.33, 3.0);
            final rotDelta = details.rotation - _lastRotation;
            _lastRotation = details.rotation;
            if (rotDelta.abs() > 0.0005) _controller.orbitCamera(-rotDelta);
            if ((details.scale - 1.0).abs() < 0.06) {
              _controller.tiltCamera(details.focalPointDelta.dy * 0.005);
            }
            return;
          }
          if (HardwareKeyboard.instance.isShiftPressed) {
            _controller.orbitCamera(-details.focalPointDelta.dx * 0.006);
            _controller.tiltCamera(details.focalPointDelta.dy * 0.004);
            return;
          }
          // One finger ALWAYS pans, in every mode.
          _controller.panCamera(details.focalPointDelta, viewportSize);
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: DesertOutpostPainter(controller: _controller),
            size: viewportSize,
          ),
        ),
      ),
    );
  }

  Widget _buildTopHud() {
    final claimable = _controller.claimableMilestoneCount;
    final milestone = _controller.nextActiveMilestone;
    final milestoneReady = milestone != null && !milestone.claimed && milestone.checkCompleted();

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
            _StageBadgePill(stage: _controller.outpostStage, onTap: _openGameMenu),
            const SizedBox(width: 6),
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
            if (milestone != null) const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                GameBevelButton(
                  onTap: _openGameMenu,
                  radius: 14,
                  bevelDepth: 3.5,
                  padding: const EdgeInsets.all(10),
                  child: const GameIcon(GameIconKind.settings, size: 20, color: Color(0xFFFFF2D4)),
                ),
                if (claimable > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: GameHudColors.goldTop,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GameHudColors.woodFrame, width: 1.5),
                      ),
                      child: Text(
                        '$claimable',
                        style: DesertTypography.display(size: 9.5, color: GameHudColors.ink),
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
                const GameIcon(GameIconKind.sparkle, size: 15, color: GameHudColors.ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'WELCOME BACK! +${formatCash(_controller.pendingOfflineWelcomeCash)} EARNED (${_controller.pendingOfflineMinutes}M)',
                    style: DesertTypography.display(size: 10.5, color: GameHudColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayBottomBar() {
    final canBuildSomething = (_controller.parkingLots.isEmpty && _controller.cash >= 40) ||
        _controller.availableUnbuiltPlots.any(
          (p) => _controller.isPlotUnlocked(p) && _controller.cash >= p.data.purchaseCost,
        );
    final canUpgradeSomething = _controller.cash >= _controller.tapUpgradeCost ||
        _controller.parkingLots.any(
          (l) =>
              _controller.canUpgradeParkingLotByProgression(l) &&
              _controller.cash >= _controller.parkingLotUpgradeCost(l),
        ) ||
        _controller.plots.any((p) {
          if (!p.isBuilt || !_controller.canUpgradePlotByProgression(p)) return false;
          return _controller.cash >= p.data.upgradeCostForLevel(p.level);
        });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameActionTray(
          controller: _controller,
          mode: _activeTray,
          onClose: () => setState(() => _activeTray = ActiveGameTray.none),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CornerGameButton(
                    icon: GameIconKind.hammer,
                    label: 'BUILD',
                    active: _activeTray == ActiveGameTray.build,
                    highlightDot: canBuildSomething,
                    onTap: () => _toggleTray(ActiveGameTray.build),
                  ),
                  const SizedBox(width: 8),
                  _CornerGameButton(
                    icon: GameIconKind.road,
                    label: 'ROADS',
                    active: false,
                    highlightDot: _controller.needsAccessRoad && _controller.cash >= 20,
                    onTap: () {
                      setState(() => _activeTray = ActiveGameTray.none);
                      _controller.enterRoadPaintMode();
                    },
                  ),
                ],
              ),
              Flexible(
                child: GameBevelButton(
                  onTap: () => _controller.performActiveTap(),
                  topColor: GameHudColors.terraTop,
                  baseColor: GameHudColors.terraBase,
                  borderColor: GameHudColors.woodFrame,
                  radius: 22,
                  bevelDepth: 5.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon(GameIconKind.drinkCup, color: Color(0xFFFFF3D6), size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _controller.parkingLots.isEmpty
                              ? 'SELL  +${formatCash(_controller.tapIncome)}'
                              : 'SERVE  +${formatCash(_controller.tapIncome)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DesertTypography.display(
                            size: 12.5,
                            color: const Color(0xFFFFFFFF),
                            letterSpacing: 0.6,
                            shadows: const [
                              Shadow(color: Color(0x66000000), offset: Offset(0, 1.5), blurRadius: 2),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
  }

  Widget _buildRoadBar() {
    final preview = _controller.roadLinePreview;
    final hasStart = _controller.roadLineStart != null;
    final erase = _controller.roadEraseMode;
    final tiles = preview.buildCells.length;
    final cost = preview.cost;
    final affordable = erase || _controller.cash >= cost;
    final canConfirm = preview.isValid && affordable;

    final String hint;
    if (!hasStart) {
      hint = erase
          ? 'TAP FIRST TILE OF THE ROAD TO REMOVE'
          : 'TAP START TILE · OR LONG-PRESS & DRAG';
    } else if (preview.cells.length <= 1 && tiles <= 1 && preview.blockReason == null) {
      hint = 'NOW TAP THE END TILE (STRAIGHT OR L-SHAPE)';
    } else if (preview.blockReason != null) {
      hint = preview.blockReason!.toUpperCase();
    } else if (!affordable) {
      hint = 'NEED ${formatCash(cost - _controller.cash)} MORE';
    } else {
      hint = erase ? 'REMOVE $tiles TILES' : '$tiles NEW TILES READY';
    }

    final String confirmLabel = erase
        ? (tiles > 0 ? 'REMOVE · +${formatCash(-cost)}' : 'REMOVE')
        : (tiles > 0 ? 'BUILD · ${formatCash(cost)}' : 'BUILD');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GameWoodPanel(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        radius: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const GameIcon(GameIconKind.road, size: 16, color: GameHudColors.woodFrame),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint,
                    style: DesertTypography.ui(
                      size: 11.0,
                      weight: FontWeight.w700,
                      color: preview.blockReason != null && hasStart
                          ? GameHudColors.terraBase
                          : GameHudColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'JUNCTIONS ${_controller.roadNetwork.highwayTurnOffCount}/${_controller.stageInfo.maxHighwayTurnOffs}',
                  style: DesertTypography.display(size: 9.0, color: GameHudColors.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final tier in RoadTier.values) ...[
                  Expanded(child: _roadTierChip(tier)),
                  const SizedBox(width: 6),
                ],
                GameBevelButton(
                  onTap: () => _controller.setRoadEraseMode(!erase),
                  topColor: erase ? GameHudColors.terraTop : GameHudColors.woodBody,
                  baseColor: erase ? GameHudColors.terraBase : GameHudColors.woodDeep,
                  radius: 12,
                  bevelDepth: 3.0,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  child: const GameIcon(GameIconKind.trash, size: 16, color: Color(0xFFFFFFFF)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GameBevelButton(
                  enabled: hasStart,
                  onTap: hasStart ? _controller.clearRoadLine : null,
                  radius: 12,
                  bevelDepth: 3.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'CLEAR',
                    style: DesertTypography.display(size: 10.5, color: const Color(0xFFFFF2D4)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GameBevelButton(
                    enabled: canConfirm,
                    onTap: canConfirm ? _controller.confirmRoadLine : null,
                    topColor: erase ? GameHudColors.terraTop : GameHudColors.greenTop,
                    baseColor: erase ? GameHudColors.terraBase : GameHudColors.greenBase,
                    radius: 12,
                    bevelDepth: 3.0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Center(
                      child: Text(
                        confirmLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DesertTypography.display(size: 11.0, color: const Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GameBevelButton(
                  onTap: _controller.cancelToolMode,
                  topColor: GameHudColors.woodBody,
                  baseColor: GameHudColors.woodDeep,
                  radius: 12,
                  bevelDepth: 3.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'DONE',
                    style: DesertTypography.display(size: 10.5, color: const Color(0xFFFFFFFF)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roadTierChip(RoadTier tier) {
    final spec = kRoadTierCatalog[tier]!;
    final unlocked = _controller.isRoadTierUnlocked(tier);
    final selected = !_controller.roadEraseMode && _controller.activeRoadTier == tier;
    return GameBevelButton(
      enabled: unlocked,
      onTap: unlocked ? () => _controller.setRoadBrush(tier) : null,
      topColor: selected ? GameHudColors.goldTop : GameHudColors.woodBody,
      baseColor: selected ? GameHudColors.goldBase : GameHudColors.woodDeep,
      radius: 12,
      bevelDepth: 3.0,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            spec.shortName,
            style: DesertTypography.display(
              size: 10.0,
              color: selected ? GameHudColors.ink : const Color(0xFFFFFFFF),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            unlocked ? '${formatCash(spec.costPerTile)}/tile' : 'STG ${spec.unlockStage}',
            style: DesertTypography.ui(
              size: 9.0,
              weight: FontWeight.w700,
              color: selected ? GameHudColors.ink : const Color(0xFFFFE7B8),
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildLandBar() {
    final canBuy = _controller.canBuyMoreLand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GameWoodPanel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        radius: 18,
        child: Row(
          children: [
            const GameIcon(GameIconKind.centerFocus, size: 18, color: GameHudColors.woodFrame),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BUY LAND · ${_controller.ownedParcelCount}/${_controller.stageInfo.maxParcels} PARCELS',
                    style: DesertTypography.display(size: 10.5, color: GameHudColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    canBuy
                        ? 'Tap a green parcel bordering your land · next ${formatCash(_controller.nextParcelPrice)}'
                        : 'Reach Stage ${_controller.outpostStage + 1} to buy more land',
                    style: DesertTypography.ui(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: GameHudColors.inkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GameBevelButton(
              onTap: _controller.cancelToolMode,
              topColor: GameHudColors.greenTop,
              baseColor: GameHudColors.greenBase,
              radius: 12,
              bevelDepth: 3.0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                'DONE',
                style: DesertTypography.display(size: 11.0, color: const Color(0xFFFFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacementBar() {
    final mode = _controller.toolMode;
    final isBuilding = mode == WorldToolMode.placeBuilding;
    final isRelocatingBuilding = _controller.relocatingPlot != null;
    final relocatingLot = _controller.relocatingParkingLot;
    final isRelocatingFreeLot =
        relocatingLot != null && !_controller.relocatingParkingIsUpgrade;
    final isRelocating = isRelocatingBuilding || isRelocatingFreeLot;
    final valid = _controller.isGhostPlacementValid;
    final invalidReason = _controller.ghostInvalidReason;

    String title = 'PLACE';
    double cost = 0.0;
    if (isBuilding && _controller.pendingBuildingType != null) {
      final data = kBusinessCatalog[_controller.pendingBuildingType!]!;
      title = isRelocatingBuilding
          ? 'MOVE ${data.name.toUpperCase()}'
          : 'PLACE ${data.name.toUpperCase()}';
      cost = isRelocatingBuilding ? 0.0 : data.purchaseCost;
    } else if (mode == WorldToolMode.placeParking && _controller.pendingParkingKind != null) {
      final spec = kParkingLotCatalog[_controller.pendingParkingKind!]!;
      if (relocatingLot != null && _controller.relocatingParkingIsUpgrade) {
        title = 'UPGRADE TO ${spec.name.toUpperCase()}';
        cost = math.max(20.0, spec.cost - relocatingLot.spec.cost);
      } else if (relocatingLot != null) {
        title = 'MOVE ${spec.name.toUpperCase()}';
        cost = 0.0;
      } else {
        title = 'PLACE ${spec.name.toUpperCase()}';
        cost = spec.cost;
      }
    } else if (mode == WorldToolMode.placeDecoration && _controller.pendingDecoration != null) {
      final (_, name, decoCost) = _controller.pendingDecoration!;
      title = 'PLACE ${name.toUpperCase()}';
      cost = decoCost;
    }

    final canAfford = _controller.cash >= cost;
    final canConfirm = valid && canAfford;
    final access = isBuilding ? _controller.ghostAccessPreview : null;

    final Color statusBg;
    final String statusText;
    final String hintText;
    if (!valid) {
      statusBg = GameHudColors.terraBase;
      statusText = 'BLOCKED';
      hintText = invalidReason ?? 'Tap open sand on your land';
    } else if (access != null) {
      statusBg = access.score <= 0
          ? GameHudColors.terraTop
          : (access.isGreat ? GameHudColors.greenBase : GameHudColors.goldBase);
      statusText = access.statusLabel;
      hintText = access.hint;
    } else {
      statusBg = GameHudColors.greenBase;
      statusText = 'READY';
      hintText = mode == WorldToolMode.placeParking
          ? 'Place beside a road connected to Route 163'
          : 'Tap to move · drag one finger to look around';
    }

    final rotatable = mode != WorldToolMode.placeDecoration;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GameWoodPanel(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        radius: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: DesertTypography.display(size: 9.5, color: const Color(0xFFFFFFFF)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: DesertTypography.display(size: 10.5, color: GameHudColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        hintText,
                        style: DesertTypography.ui(
                          size: 10.5,
                          weight: FontWeight.w700,
                          color: GameHudColors.inkMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (rotatable) ...[
                  GameBevelButton(
                    onTap: _controller.rotateGhost,
                    radius: 12,
                    bevelDepth: 3.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GameIcon(GameIconKind.rotate, size: 15, color: Color(0xFFFFF2D4)),
                        const SizedBox(width: 5),
                        Text(
                          'ROTATE',
                          style: DesertTypography.display(
                            size: 10.5,
                            color: const Color(0xFFFFF2D4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: GameBevelButton(
                    enabled: canConfirm,
                    onTap: canConfirm ? _controller.confirmPlacement : null,
                    topColor: GameHudColors.greenTop,
                    baseColor: GameHudColors.greenBase,
                    radius: 12,
                    bevelDepth: 3.0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GameIcon(GameIconKind.check, size: 16, color: Color(0xFFFFFFFF)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isRelocating
                                ? 'MOVE HERE'
                                : (cost > 0 ? 'PLACE · ${formatCash(cost)}' : 'PLACE'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesertTypography.display(
                              size: 11.5,
                              color: const Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GameBevelButton(
                  onTap: _controller.cancelToolMode,
                  topColor: GameHudColors.terraTop,
                  baseColor: GameHudColors.terraBase,
                  radius: 12,
                  bevelDepth: 3.0,
                  padding: const EdgeInsets.all(9),
                  child: const GameIcon(GameIconKind.close, size: 16, color: Color(0xFFFFFFFF)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _onScreen(Offset p, Size viewport) =>
      p.dx > 30 && p.dx < viewport.width - 30 && p.dy > 90 && p.dy < viewport.height - 135;

  Widget _bubbleAt(Offset anchor, double lift, Widget child) {
    return Positioned(
      left: anchor.dx,
      top: anchor.dy - lift,
      child: FractionalTranslation(translation: const Offset(-0.5, 0), child: child),
    );
  }

  List<Widget> _buildInWorldBubbles(Size viewport) {
    final mode = _controller.toolMode;
    final bubbles = <Widget>[];
    final bob = math.sin(_controller.animTime * 3.4) * 3.5;
    final frame = _controller.camera.createFrame(viewport);

    // Land mode: price tags over every purchasable parcel bordering owned land.
    if (mode == WorldToolMode.buyLand) {
      final price = _controller.nextParcelPrice;
      final canBuyMore = _controller.canBuyMoreLand;
      for (final parcel in _controller.worldGrid.purchasableParcels()) {
        final p = frame.project(parcel.center + const Vec3(0, 1.2, 0));
        if (!p.inFront || !_onScreen(p.offset, viewport)) continue;
        bubbles.add(
          _bubbleAt(
            p.offset,
            30,
            WorldActionBubble(
              icon: GameIconKind.centerFocus,
              label: canBuyMore ? 'LAND' : 'LOCKED',
              costText: canBuyMore ? formatCash(price) : '',
              canAfford: canBuyMore && _controller.cash >= price,
              progress: price > 0 ? _controller.cash / price : 1.0,
              onTap: () => _controller.buyParcel(parcel),
              onUnaffordableTap: () => _controller.buyParcel(parcel),
            ),
          ),
        );
      }
      return bubbles;
    }

    if (mode != WorldToolMode.play) return bubbles;

    final cart = _controller.cartPlot;

    // Onboarding 1: Dirt Pull-Off beside the cart.
    if (_controller.parkingLots.isEmpty && cart.isBuilt) {
      final spec = kParkingLotCatalog[ParkingLotKind.dirtPullOff]!;
      final canAfford = _controller.cash >= spec.cost;
      final worldPos = cart.position + const Vec3(2.6, 1.8, 2.4);
      final anchor = frame.project(worldPos);
      if (anchor.inFront && _onScreen(anchor.offset, viewport)) {
        bubbles.add(
          _bubbleAt(
            anchor.offset,
            36 - (canAfford ? bob : 0),
            WorldActionBubble(
              icon: GameIconKind.parking,
              label: 'DIRT LOT',
              costText: formatCash(spec.cost),
              canAfford: canAfford,
              progress: _controller.cash / spec.cost,
              onTap: _controller.upgradeParking,
              onUnaffordableTap: () =>
                  _controller.notifyShortfall(worldPos, spec.cost - _controller.cash),
            ),
          ),
        );
      }
    }

    // Onboarding 2: one-tap access road preview from Route 163.
    if (_controller.needsAccessRoad && cart.isBuilt) {
      final worldPos = cart.position + const Vec3(-2.6, 1.8, 2.4);
      final anchor = frame.project(worldPos);
      if (anchor.inFront && _onScreen(anchor.offset, viewport)) {
        bubbles.add(
          _bubbleAt(
            anchor.offset,
            36 - bob * 0.6,
            WorldActionBubble(
              icon: GameIconKind.road,
              label: 'ACCESS ROAD',
              costText: '',
              canAfford: true,
              accentColor: GameHudColors.goldTop,
              accentBase: GameHudColors.goldBase,
              onTap: _controller.suggestAccessRoad,
            ),
          ),
        );
      }
    }

    // Parking lot road-connection warnings & in-world upgrade bubbles!
    for (final lot in _controller.parkingLots) {
      if (!lot.isConnected) {
        final anchor = frame.project(lot.position + const Vec3(0, 2.0, 0));
        if (anchor.inFront && _onScreen(anchor.offset, viewport)) {
          bubbles.add(
            _bubbleAt(
              anchor.offset,
              28 - bob * 0.6,
              WorldActionBubble(
                icon: GameIconKind.road,
                label: 'CONNECT ROAD',
                costText: '',
                canAfford: true,
                accentColor: GameHudColors.terraTop,
                accentBase: GameHudColors.terraBase,
                onTap: () => _controller.enterRoadPaintMode(),
              ),
            ),
          );
        }
        continue;
      }

      if (_controller.canUpgradeParkingLotByProgression(lot)) {
        final cost = _controller.parkingLotUpgradeCost(lot);
        if (_controller.cash >= cost && lot.nextUpgradeKind != null) {
          final nextSpec = kParkingLotCatalog[lot.nextUpgradeKind!]!;
          final anchor = frame.project(lot.position + const Vec3(0, 2.2, 0));
          if (anchor.inFront && _onScreen(anchor.offset, viewport)) {
            bubbles.add(
              _bubbleAt(
                anchor.offset,
                28 - bob,
                WorldActionBubble(
                  icon: GameIconKind.upgradeArrow,
                  label: nextSpec.shortName,
                  costText: formatCash(cost),
                  canAfford: true,
                  accentColor: GameHudColors.goldTop,
                  accentBase: GameHudColors.goldBase,
                  onTap: () => _controller.upgradeParkingLot(lot),
                ),
              ),
            );
          }
        }
      }
    }

    // Store warnings & progression-unlocked affordable upgrades.
    for (final plot in _controller.visiblePlots) {
      final data = plot.data;
      if (_controller.parkingLots.isNotEmpty && plot.access.score <= 0.0) {
        final anchor = frame.project(plot.position + const Vec3(0, 3.6, 0));
        if (anchor.inFront && _onScreen(anchor.offset, viewport)) {
          bubbles.add(
            _bubbleAt(
              anchor.offset,
              30 - bob * 0.6,
              WorldActionBubble(
                icon: GameIconKind.warning,
                label: plot.access.statusLabel,
                costText: '',
                canAfford: true,
                accentColor: GameHudColors.terraTop,
                accentBase: GameHudColors.terraBase,
                onTap: () => _controller.enterRoadPaintMode(),
              ),
            ),
          );
          continue;
        }
      }

      if (plot.level < data.maxLevel && _controller.canUpgradePlotByProgression(plot)) {
        final cost = data.upgradeCostForLevel(plot.level);
        if (_controller.cash >= cost) {
          final anchor = frame.project(plot.position + const Vec3(0, 3.8, 0));
          if (!anchor.inFront || !_onScreen(anchor.offset, viewport)) continue;
          bubbles.add(
            _bubbleAt(
              anchor.offset,
              30 - bob,
              WorldActionBubble(
                icon: GameIconKind.upgradeArrow,
                label: 'LV${plot.level + 1}',
                costText: formatCash(cost),
                canAfford: true,
                accentColor: GameHudColors.goldTop,
                accentBase: GameHudColors.goldBase,
                onTap: () => _controller.upgradePlot(plot),
              ),
            ),
          );
        }
      }
    }

    return bubbles;
  }
}

/// Compact right-edge camera cluster: rotate ±90°, cycle tilt, return home.
class _CameraControls extends StatelessWidget {
  const _CameraControls({required this.controller});

  final GameController controller;

  Widget _btn(Widget icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GameBevelButton(
        onTap: onTap,
        radius: 12,
        bevelDepth: 3.0,
        padding: const EdgeInsets.all(8),
        child: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const iconCol = Color(0xFFFFF2D4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          Transform.flip(
            flipX: true,
            child: const GameIcon(GameIconKind.rotate, size: 17, color: iconCol),
          ),
          () => controller.rotateCameraQuarter(-1),
        ),
        _btn(
          const GameIcon(GameIconKind.rotate, size: 17, color: iconCol),
          () => controller.rotateCameraQuarter(1),
        ),
        _btn(
          const GameIcon(GameIconKind.cube3d, size: 17, color: iconCol),
          controller.cycleCameraTilt,
        ),
        _btn(
          const GameIcon(GameIconKind.centerFocus, size: 17, color: iconCol),
          controller.resetCamera,
        ),
      ],
    );
  }
}

class _StageBadgePill extends StatelessWidget {
  const _StageBadgePill({required this.stage, required this.onTap});

  final int stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: GameHudColors.woodFrame.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GameHudColors.goldTop, width: 1.6),
          ),
          child: Text(
            'STG $stage',
            style: DesertTypography.display(
              size: 10.0,
              color: GameHudColors.goldTop,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
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
                style: DesertTypography.display(size: 10.5, color: GameHudColors.ink),
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 19, color: active ? GameHudColors.ink : const Color(0xFFFFF2D4)),
              const SizedBox(height: 3),
              Text(
                label,
                style: DesertTypography.display(
                  size: 8.8,
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
