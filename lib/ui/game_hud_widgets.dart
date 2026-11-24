import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../engine/camera_3d.dart';
import '../engine/lighting.dart';
import '../engine/mesh_builder.dart';
import '../engine/renderer_3d.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../theme/desert_palette.dart';
import '../world/building_models.dart';
import '../world/entity_models.dart';
import 'game_icons.dart';

/// Game-style UI color tokens (warm carved desert wood, parchment, brass, emerald, terracotta).
class GameHudColors {
  const GameHudColors._();

  static const Color woodFrame = Color(0xFF4B2E1E);
  static const Color woodRim = Color(0xFF7B4F34);
  static const Color woodBody = Color(0xFF5D3A26);
  static const Color woodDeep = Color(0xFF341E13);
  static const Color parchment = Color(0xFFF4E6CA);
  static const Color parchmentDark = Color(0xFFE5D0AC);
  static const Color ink = Color(0xFF331E14);
  static const Color inkMuted = Color(0xFF6F503C);

  static const Color greenTop = Color(0xFF4CA85E);
  static const Color greenBase = Color(0xFF2F763E);
  static const Color terraTop = Color(0xFFD96E43);
  static const Color terraBase = Color(0xFF9C4223);
  static const Color goldTop = Color(0xFFF5C44E);
  static const Color goldBase = Color(0xFFB88320);
  static const Color stoneTop = Color(0xFF9F917F);
  static const Color stoneBase = Color(0xFF6D6153);
}

/// Tactile 3D-beveled game button that physically depresses downward on press.
class GameBevelButton extends StatefulWidget {
  const GameBevelButton({
    super.key,
    required this.child,
    required this.onTap,
    this.topColor = GameHudColors.woodBody,
    this.baseColor = GameHudColors.woodDeep,
    this.borderColor = GameHudColors.woodFrame,
    this.radius = 14.0,
    this.bevelDepth = 4.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color topColor;
  final Color baseColor;
  final Color borderColor;
  final double radius;
  final double bevelDepth;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  @override
  State<GameBevelButton> createState() => _GameBevelButtonState();
}

class _GameBevelButtonState extends State<GameBevelButton> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final topCol = _active ? widget.topColor : GameHudColors.stoneTop;
    final baseCol = _active ? widget.baseColor : GameHudColors.stoneBase;
    final drop = (_pressed && _active) ? widget.bevelDepth : 0.0;

    return MouseRegion(
      cursor: _active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _active ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _active
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: Padding(
          padding: EdgeInsets.only(top: drop, bottom: widget.bevelDepth - drop),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: topCol,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(color: widget.borderColor, width: 2.0),
              boxShadow: [
                if (!_pressed || !_active)
                  BoxShadow(
                    color: baseCol,
                    offset: Offset(0, widget.bevelDepth),
                    blurRadius: 0,
                  ),
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.28),
                  offset: Offset(0, widget.bevelDepth + 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Top-left carved-wood & gold coin HUD counter with custom `Bungee` display numbers.
class GameCoinHud extends StatelessWidget {
  const GameCoinHud({
    super.key,
    required this.cashText,
    required this.rateText,
    required this.hasPassiveIncome,
  });

  final String cashText;
  final String rateText;
  final bool hasPassiveIncome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
      decoration: BoxDecoration(
        color: GameHudColors.woodFrame.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GameHudColors.woodRim, width: 2.2),
        boxShadow: [
          const BoxShadow(
            color: GameHudColors.woodDeep,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.28),
            offset: const Offset(0, 6),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE58F), GameHudColors.goldTop, GameHudColors.goldBase],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF7D5310), width: 2.0),
            ),
            child: Center(
              child: Text(
                '\$',
                style: DesertTypography.display(
                  size: 15,
                  color: const Color(0xFF5D3A08),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cashText,
                style: DesertTypography.display(
                  size: 16,
                  color: const Color(0xFFFFF6E3),
                  shadows: const [
                    Shadow(color: Color(0x8A000000), offset: Offset(0, 1.5), blurRadius: 2),
                  ],
                ),
              ),
              Text(
                rateText,
                style: DesertTypography.ui(
                  size: 11,
                  weight: FontWeight.w700,
                  color: hasPassiveIncome
                      ? const Color(0xFF8CFF9B)
                      : DesertPalette.sand.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact wooden-framed parchment game panel.
class GameWoodPanel extends StatelessWidget {
  const GameWoodPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: GameHudColors.parchment,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: GameHudColors.woodFrame, width: 3.0),
        boxShadow: [
          const BoxShadow(
            color: GameHudColors.woodDeep,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.35),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// In-world floating 3D diegetic action bubble with affordability fill bar
/// and snappy horizontal shake feedback when tapped before affordable!
class WorldActionBubble extends StatefulWidget {
  const WorldActionBubble({
    super.key,
    required this.icon,
    required this.label,
    required this.costText,
    required this.canAfford,
    required this.onTap,
    this.progress = 0.0,
    this.onUnaffordableTap,
    this.accentColor = GameHudColors.greenTop,
    this.accentBase = GameHudColors.greenBase,
  });

  final GameIconKind icon;
  final String label;
  final String costText;
  final bool canAfford;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback? onUnaffordableTap;
  final Color accentColor;
  final Color accentBase;

  @override
  State<WorldActionBubble> createState() => _WorldActionBubbleState();
}

class _WorldActionBubbleState extends State<WorldActionBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _handlePress() {
    if (widget.canAfford) {
      widget.onTap();
    } else {
      _shakeCtrl.forward(from: 0.0);
      widget.onUnaffordableTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgTop = widget.canAfford
        ? widget.accentColor
        : GameHudColors.woodFrame.withValues(alpha: 0.90);
    final bgBase = widget.canAfford ? widget.accentBase : GameHudColors.woodDeep;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _handlePress,
        child: AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final shakeX = _shakeCtrl.isAnimating
                ? math.sin(_shakeCtrl.value * math.pi * 4.0) * (1.0 - _shakeCtrl.value) * 6.0
                : 0.0;
            return Transform.translate(
              offset: Offset(shakeX, 0),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
                decoration: BoxDecoration(
                  color: bgTop,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.canAfford ? const Color(0xFFFFF4D2) : GameHudColors.woodRim,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: bgBase,
                      offset: const Offset(0, 2.5),
                      blurRadius: 0,
                    ),
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.28),
                      offset: const Offset(0, 5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GameIcon(
                          widget.icon,
                          size: 13,
                          color: widget.canAfford ? const Color(0xFFFFFFFF) : DesertPalette.sand,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.label} ${widget.costText}',
                          style: DesertTypography.display(
                            size: 10.5,
                            color: widget.canAfford ? const Color(0xFFFFFFFF) : DesertPalette.cream,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    if (!widget.canAfford && widget.progress > 0.02) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 78,
                        height: 3.5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(color: GameHudColors.woodDeep),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: widget.progress.clamp(0.0, 1.0),
                                child: Container(color: GameHudColors.goldTop),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(10, 5),
                painter: _CaretPainter(bgBase),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) => oldDelegate.color != color;
}

/// Cached miniature 3D isometric preview rendered directly on Build & Upgrade deck cards!
class Mini3DAssetPreview extends StatelessWidget {
  const Mini3DAssetPreview({
    super.key,
    this.businessType,
    this.decorationKind,
    this.level = 1,
    this.size = const Size(44, 34),
  });

  final BusinessType? businessType;
  final DecorationKind? decorationKind;
  final int level;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _Mini3DAssetPainter(
          businessType: businessType,
          decorationKind: decorationKind,
          level: level,
        ),
      ),
    );
  }
}

class _Mini3DAssetPainter extends CustomPainter {
  const _Mini3DAssetPainter({
    this.businessType,
    this.decorationKind,
    required this.level,
  });

  final BusinessType? businessType;
  final DecorationKind? decorationKind;
  final int level;

  static final DesertLighting _studioLight = DesertLighting.fromTime(0.39);

  @override
  void paint(Canvas canvas, Size size) {
    final mesh = MeshBuilder();
    double dist = 12.0;
    double targetY = 1.4;

    if (businessType != null) {
      (dist, targetY) = switch (businessType!) {
        BusinessType.vendorStall => (9.0, 1.15),
        BusinessType.convenienceStore => (12.8, 1.55),
        BusinessType.foodStand => (10.5, 1.35),
        BusinessType.desertDiner => (14.2, 1.75),
        BusinessType.gasStation => (14.8, 1.70),
        BusinessType.oasisPlaza => (11.5, 1.15),
        BusinessType.desertMotel => (15.8, 2.05),
        BusinessType.lookoutCamp => (16.5, 2.45),
      };
      BuildingModels.buildByType(
        mesh,
        businessType!,
        Vec3.zero,
        level,
        _studioLight,
        const Color(0x00000000),
        0.5,
      );
    } else if (decorationKind != null) {
      dist = 6.2;
      targetY = 0.85;
      EntityModels.buildDecoration(
        mesh,
        PlacedDecoration(
          id: 'preview',
          kind: decorationKind!,
          position: Vec3.zero,
          name: '',
          cost: 0,
        ),
        _studioLight,
        0.5,
      );
    }

    mesh.signs.clear();
    mesh.glows.clear();

    final cam = Camera3D(
      yaw: -0.46,
      pitch: 0.34,
      distance: dist,
      fovY: 0.56,
      target: Vec3(0, targetY, 0),
    );
    SceneRenderer3D.paintMesh(canvas, size, cam, _studioLight, mesh);
  }

  @override
  bool shouldRepaint(covariant _Mini3DAssetPainter oldDelegate) =>
      oldDelegate.businessType != businessType ||
      oldDelegate.decorationKind != decorationKind ||
      oldDelegate.level != level;
}
