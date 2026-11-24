import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Crisp custom vector game icons so Desert Outpost needs zero `material.dart` imports
/// and zero 1.6 MB MaterialIcons font overhead on Web.
enum GameIconKind {
  settings,
  hammer,
  upgradeArrow,
  drinkCup,
  parking,
  chevronDown,
  close,
  sun,
  sunset,
  moon,
  cube3d,
  centerFocus,
  trophy,
  verified,
  tapHand,
  arrowBack,
  play,
  pause,
  volumeOn,
  volumeOff,
  cactus,
  sparkle,
  road,
  rotate,
  move,
  trash,
  check,
  warning,
}

class GameIcon extends StatelessWidget {
  const GameIcon(
    this.kind, {
    super.key,
    this.size = 18.0,
    this.color = const Color(0xFFFFFFFF),
  });

  final GameIconKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GameIconPainter(kind: kind, color: color),
    );
  }
}

class _GameIconPainter extends CustomPainter {
  const _GameIconPainter({required this.kind, required this.color});

  final GameIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.5, h * 0.5);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, w * 0.115)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case GameIconKind.settings:
        canvas.drawCircle(c, w * 0.21, stroke);
        for (int i = 0; i < 8; i++) {
          final a = (i / 8) * math.pi * 2.0;
          final p0 = Offset(c.dx + math.cos(a) * w * 0.28, c.dy + math.sin(a) * h * 0.28);
          final p1 = Offset(c.dx + math.cos(a) * w * 0.42, c.dy + math.sin(a) * h * 0.42);
          canvas.drawLine(p0, p1, stroke);
        }

      case GameIconKind.hammer:
        canvas.drawLine(Offset(w * 0.22, h * 0.78), Offset(w * 0.62, h * 0.38), stroke);
        final head = Path()
          ..moveTo(w * 0.46, h * 0.24)
          ..lineTo(w * 0.78, h * 0.24)
          ..lineTo(w * 0.78, h * 0.44)
          ..lineTo(w * 0.52, h * 0.44)
          ..close();
        canvas.drawPath(head, fill);

      case GameIconKind.upgradeArrow:
        canvas.drawCircle(c, w * 0.42, stroke);
        final arrow = Path()
          ..moveTo(w * 0.50, h * 0.26)
          ..lineTo(w * 0.70, h * 0.48)
          ..lineTo(w * 0.30, h * 0.48)
          ..close();
        canvas.drawPath(arrow, fill);
        canvas.drawLine(Offset(w * 0.50, h * 0.46), Offset(w * 0.50, h * 0.72), stroke);

      case GameIconKind.drinkCup:
        final cup = Path()
          ..moveTo(w * 0.26, h * 0.32)
          ..lineTo(w * 0.74, h * 0.32)
          ..lineTo(w * 0.66, h * 0.84)
          ..lineTo(w * 0.34, h * 0.84)
          ..close();
        canvas.drawPath(cup, stroke);
        canvas.drawLine(Offset(w * 0.22, h * 0.32), Offset(w * 0.78, h * 0.32), stroke);
        canvas.drawLine(Offset(w * 0.54, h * 0.32), Offset(w * 0.66, h * 0.14), stroke);

      case GameIconKind.parking:
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.14, h * 0.14, w * 0.72, h * 0.72),
          Radius.circular(w * 0.18),
        );
        canvas.drawRRect(rrect, stroke);
        canvas.drawLine(Offset(w * 0.38, h * 0.70), Offset(w * 0.38, h * 0.30), stroke);
        final loop = Path()
          ..moveTo(w * 0.38, h * 0.30)
          ..lineTo(w * 0.56, h * 0.30)
          ..arcToPoint(Offset(w * 0.56, h * 0.52), radius: Radius.circular(w * 0.11))
          ..lineTo(w * 0.38, h * 0.52);
        canvas.drawPath(loop, stroke);

      case GameIconKind.chevronDown:
        final p = Path()
          ..moveTo(w * 0.24, h * 0.38)
          ..lineTo(w * 0.50, h * 0.64)
          ..lineTo(w * 0.76, h * 0.38);
        canvas.drawPath(p, stroke);

      case GameIconKind.close:
        canvas.drawLine(Offset(w * 0.25, h * 0.25), Offset(w * 0.75, h * 0.75), stroke);
        canvas.drawLine(Offset(w * 0.75, h * 0.25), Offset(w * 0.25, h * 0.75), stroke);

      case GameIconKind.sun:
        canvas.drawCircle(c, w * 0.22, fill);
        for (int i = 0; i < 8; i++) {
          final a = (i / 8) * math.pi * 2.0;
          canvas.drawLine(
            Offset(c.dx + math.cos(a) * w * 0.32, c.dy + math.sin(a) * h * 0.32),
            Offset(c.dx + math.cos(a) * w * 0.44, c.dy + math.sin(a) * h * 0.44),
            stroke,
          );
        }

      case GameIconKind.sunset:
        canvas.drawLine(Offset(w * 0.14, h * 0.70), Offset(w * 0.86, h * 0.70), stroke);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.5, h * 0.70), width: w * 0.48, height: h * 0.48),
          math.pi,
          math.pi,
          true,
          fill,
        );

      case GameIconKind.moon:
        final moon = Path()
          ..addOval(Rect.fromCircle(center: c, radius: w * 0.36));
        final cutout = Path()
          ..addOval(Rect.fromCircle(center: Offset(w * 0.64, h * 0.36), radius: w * 0.30));
        canvas.drawPath(Path.combine(PathOperation.difference, moon, cutout), fill);

      case GameIconKind.cube3d:
        final top = Path()
          ..moveTo(w * 0.50, h * 0.16)
          ..lineTo(w * 0.82, h * 0.34)
          ..lineTo(w * 0.50, h * 0.52)
          ..lineTo(w * 0.18, h * 0.34)
          ..close();
        canvas.drawPath(top, stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.34), Offset(w * 0.18, h * 0.68), stroke);
        canvas.drawLine(Offset(w * 0.82, h * 0.34), Offset(w * 0.82, h * 0.68), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.52), Offset(w * 0.50, h * 0.86), stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.68), Offset(w * 0.50, h * 0.86), stroke);
        canvas.drawLine(Offset(w * 0.82, h * 0.68), Offset(w * 0.50, h * 0.86), stroke);

      case GameIconKind.centerFocus:
        canvas.drawCircle(c, w * 0.15, fill);
        canvas.drawCircle(c, w * 0.34, stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.08), Offset(w * 0.5, h * 0.22), stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.78), Offset(w * 0.5, h * 0.92), stroke);
        canvas.drawLine(Offset(w * 0.08, h * 0.5), Offset(w * 0.22, h * 0.5), stroke);
        canvas.drawLine(Offset(w * 0.78, h * 0.5), Offset(w * 0.92, h * 0.5), stroke);

      case GameIconKind.trophy:
        final cup = Path()
          ..moveTo(w * 0.26, h * 0.20)
          ..lineTo(w * 0.74, h * 0.20)
          ..lineTo(w * 0.64, h * 0.54)
          ..lineTo(w * 0.36, h * 0.54)
          ..close();
        canvas.drawPath(cup, fill);
        canvas.drawLine(Offset(w * 0.50, h * 0.54), Offset(w * 0.50, h * 0.78), stroke);
        canvas.drawLine(Offset(w * 0.32, h * 0.80), Offset(w * 0.68, h * 0.80), stroke);

      case GameIconKind.verified:
        canvas.drawCircle(c, w * 0.40, stroke);
        final check = Path()
          ..moveTo(w * 0.30, h * 0.52)
          ..lineTo(w * 0.45, h * 0.66)
          ..lineTo(w * 0.72, h * 0.36);
        canvas.drawPath(check, stroke);

      case GameIconKind.tapHand:
        canvas.drawCircle(Offset(w * 0.50, h * 0.28), w * 0.18, stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.34), Offset(w * 0.50, h * 0.78), stroke);
        canvas.drawLine(Offset(w * 0.34, h * 0.58), Offset(w * 0.66, h * 0.58), stroke);

      case GameIconKind.arrowBack:
        canvas.drawLine(Offset(w * 0.78, h * 0.50), Offset(w * 0.24, h * 0.50), stroke);
        final head = Path()
          ..moveTo(w * 0.46, h * 0.26)
          ..lineTo(w * 0.22, h * 0.50)
          ..lineTo(w * 0.46, h * 0.74);
        canvas.drawPath(head, stroke);

      case GameIconKind.play:
        final p = Path()
          ..moveTo(w * 0.30, h * 0.22)
          ..lineTo(w * 0.78, h * 0.50)
          ..lineTo(w * 0.30, h * 0.78)
          ..close();
        canvas.drawPath(p, fill);

      case GameIconKind.pause:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.26, h * 0.22, w * 0.16, h * 0.56), const Radius.circular(2)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.22, w * 0.16, h * 0.56), const Radius.circular(2)),
          fill,
        );

      case GameIconKind.volumeOn:
        final spk = Path()
          ..moveTo(w * 0.18, h * 0.40)
          ..lineTo(w * 0.36, h * 0.40)
          ..lineTo(w * 0.56, h * 0.22)
          ..lineTo(w * 0.56, h * 0.78)
          ..lineTo(w * 0.36, h * 0.60)
          ..lineTo(w * 0.18, h * 0.60)
          ..close();
        canvas.drawPath(spk, fill);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.56, h * 0.50), width: w * 0.42, height: h * 0.48),
          -0.8,
          1.6,
          false,
          stroke,
        );

      case GameIconKind.volumeOff:
        final spk = Path()
          ..moveTo(w * 0.18, h * 0.40)
          ..lineTo(w * 0.36, h * 0.40)
          ..lineTo(w * 0.56, h * 0.22)
          ..lineTo(w * 0.56, h * 0.78)
          ..lineTo(w * 0.36, h * 0.60)
          ..lineTo(w * 0.18, h * 0.60)
          ..close();
        canvas.drawPath(spk, fill);
        canvas.drawLine(Offset(w * 0.66, h * 0.36), Offset(w * 0.86, h * 0.64), stroke);
        canvas.drawLine(Offset(w * 0.86, h * 0.36), Offset(w * 0.66, h * 0.64), stroke);

      case GameIconKind.cactus:
        canvas.drawLine(Offset(w * 0.50, h * 0.84), Offset(w * 0.50, h * 0.20), stroke);
        final arms = Path()
          ..moveTo(w * 0.26, h * 0.36)
          ..lineTo(w * 0.26, h * 0.54)
          ..lineTo(w * 0.50, h * 0.54)
          ..moveTo(w * 0.74, h * 0.30)
          ..lineTo(w * 0.74, h * 0.48)
          ..lineTo(w * 0.50, h * 0.48);
        canvas.drawPath(arms, stroke);

      case GameIconKind.sparkle:
        final star = Path()
          ..moveTo(w * 0.50, h * 0.14)
          ..lineTo(w * 0.60, h * 0.40)
          ..lineTo(w * 0.86, h * 0.50)
          ..lineTo(w * 0.60, h * 0.60)
          ..lineTo(w * 0.50, h * 0.86)
          ..lineTo(w * 0.40, h * 0.60)
          ..lineTo(w * 0.14, h * 0.50)
          ..lineTo(w * 0.40, h * 0.40)
          ..close();
        canvas.drawPath(star, fill);

      case GameIconKind.road:
        canvas.drawLine(Offset(w * 0.28, h * 0.16), Offset(w * 0.14, h * 0.84), stroke);
        canvas.drawLine(Offset(w * 0.72, h * 0.16), Offset(w * 0.86, h * 0.84), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.22), Offset(w * 0.50, h * 0.40), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.56), Offset(w * 0.50, h * 0.78), stroke);

      case GameIconKind.rotate:
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: w * 0.32),
          -math.pi * 0.7,
          math.pi * 1.45,
          false,
          stroke,
        );
        final head = Path()
          ..moveTo(w * 0.68, h * 0.16)
          ..lineTo(w * 0.84, h * 0.34)
          ..lineTo(w * 0.60, h * 0.38)
          ..close();
        canvas.drawPath(head, fill);

      case GameIconKind.move:
        canvas.drawLine(Offset(w * 0.50, h * 0.16), Offset(w * 0.50, h * 0.84), stroke);
        canvas.drawLine(Offset(w * 0.16, h * 0.50), Offset(w * 0.84, h * 0.50), stroke);
        canvas.drawCircle(c, w * 0.10, fill);

      case GameIconKind.trash:
        canvas.drawLine(Offset(w * 0.20, h * 0.28), Offset(w * 0.80, h * 0.28), stroke);
        canvas.drawLine(Offset(w * 0.38, h * 0.18), Offset(w * 0.62, h * 0.18), stroke);
        final bin = Path()
          ..moveTo(w * 0.28, h * 0.28)
          ..lineTo(w * 0.34, h * 0.82)
          ..lineTo(w * 0.66, h * 0.82)
          ..lineTo(w * 0.72, h * 0.28);
        canvas.drawPath(bin, stroke);

      case GameIconKind.check:
        final p = Path()
          ..moveTo(w * 0.20, h * 0.52)
          ..lineTo(w * 0.42, h * 0.74)
          ..lineTo(w * 0.82, h * 0.28);
        canvas.drawPath(p, stroke);

      case GameIconKind.warning:
        final tri = Path()
          ..moveTo(w * 0.50, h * 0.16)
          ..lineTo(w * 0.86, h * 0.82)
          ..lineTo(w * 0.14, h * 0.82)
          ..close();
        canvas.drawPath(tri, stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.42), Offset(w * 0.50, h * 0.58), stroke);
        canvas.drawCircle(Offset(w * 0.50, h * 0.71), w * 0.05, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _GameIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
