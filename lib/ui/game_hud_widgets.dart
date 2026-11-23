import 'package:flutter/material.dart';

import '../theme/desert_palette.dart';

/// Game-style UI color tokens (warm carved desert wood, parchment, brass, emerald, terracotta).
class GameHudColors {
  const GameHudColors._();

  static const Color woodFrame = Color(0xFF4B2E1E);
  static const Color woodRim = Color(0xFF7B4F34);
  static const Color woodBody = Color(0xFF5D3A26);
  static const Color woodDeep = Color(0xFF341E13);
  static const Color parchment = Color(0xFFF3E4C6);
  static const Color parchmentDark = Color(0xFFE3CEAA);
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

    return GestureDetector(
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
                color: Colors.black.withValues(alpha: 0.28),
                offset: Offset(0, widget.bevelDepth + 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Top-left carved-wood & gold coin HUD counter (no white Material card).
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
        color: GameHudColors.woodFrame.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GameHudColors.woodRim, width: 2.2),
        boxShadow: [
          const BoxShadow(
            color: GameHudColors.woodDeep,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            offset: const Offset(0, 6),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Embossed gold coin emblem
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE285), GameHudColors.goldTop, GameHudColors.goldBase],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF7D5310), width: 2.0),
            ),
            child: const Center(
              child: Text(
                '\$',
                style: TextStyle(
                  color: Color(0xFF5D3A08),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  height: 1.0,
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
                style: const TextStyle(
                  color: Color(0xFFFFF6E3),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  height: 1.05,
                  shadows: [
                    Shadow(color: Colors.black54, offset: Offset(0, 1.5), blurRadius: 2),
                  ],
                ),
              ),
              Text(
                rateText,
                style: TextStyle(
                  color: hasPassiveIncome
                      ? const Color(0xFF8CFF9B)
                      : DesertPalette.sand.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact wooden-framed parchment game panel (for floating game menus & trays).
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
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// In-world floating 3D diegetic action bubble anchored over a 3D world position.
class WorldActionBubble extends StatelessWidget {
  const WorldActionBubble({
    super.key,
    required this.icon,
    required this.label,
    required this.costText,
    required this.canAfford,
    required this.onTap,
    this.accentColor = GameHudColors.greenTop,
    this.accentBase = GameHudColors.greenBase,
  });

  final IconData icon;
  final String label;
  final String costText;
  final bool canAfford;
  final VoidCallback onTap;
  final Color accentColor;
  final Color accentBase;

  @override
  Widget build(BuildContext context) {
    final bgTop = canAfford ? accentColor : GameHudColors.woodFrame.withValues(alpha: 0.88);
    final bgBase = canAfford ? accentBase : GameHudColors.woodDeep;

    return GestureDetector(
      onTap: canAfford ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: bgTop,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canAfford ? const Color(0xFFFFF4D2) : GameHudColors.woodRim,
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: bgBase,
                  offset: const Offset(0, 2.5),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  offset: const Offset(0, 5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: canAfford ? Colors.white : DesertPalette.sand,
                ),
                const SizedBox(width: 4),
                Text(
                  '$label $costText',
                  style: TextStyle(
                    color: canAfford ? Colors.white : DesertPalette.cream,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Tiny downward pointer caret anchoring the bubble to the 3D object
          CustomPaint(
            size: const Size(10, 5),
            painter: _CaretPainter(bgBase),
          ),
        ],
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
