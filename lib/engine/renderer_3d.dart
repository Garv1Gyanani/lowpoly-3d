import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../systems/game_controller.dart';
import '../world/building_models.dart';
import '../world/entity_models.dart';
import '../world/environment_builder.dart';
import 'camera_3d.dart';
import 'lighting.dart';
import 'mesh_builder.dart';
import 'vec3.dart';

/// Projected drawable face ready for back-to-front painter sorting.
class _RenderPoly {
  _RenderPoly({
    required this.points,
    required this.layerIndex,
    required this.groupDepth,
    required this.subOrder,
    required this.localDepth,
    required this.fillColor,
    this.outlineColor,
  });

  final List<Offset> points;
  final int layerIndex;
  final double groupDepth;
  final int subOrder;
  final double localDepth;
  final Color fillColor;
  final Color? outlineColor;
}

/// Shared pure-Dart 3D rendering pipeline used by both the main Desert Outpost
/// diorama and the standalone 3D Object Studio inspector.
class SceneRenderer3D {
  const SceneRenderer3D._();

  static void paintSkyDome(
    Canvas canvas,
    Size size,
    Camera3D camera,
    DesertLighting lighting,
    double animTime,
  ) {
    final hY = camera.horizonScreenY(size).clamp(size.height * 0.05, size.height * 0.55);

    const dayTop = Color(0xFF6F97CE);
    const dayMid = Color(0xFFAAC2DF);
    const dayHorizon = Color(0xFFF6C8A2);

    const sunsetTop = Color(0xFF4F4670);
    const sunsetMid = Color(0xFFC56B69);
    const sunsetHorizon = Color(0xFFFFAE68);

    const nightTop = Color(0xFF0A1426);
    const nightMid = Color(0xFF162946);
    const nightHorizon = Color(0xFF284060);

    Color top = Color.lerp(dayTop, sunsetTop, lighting.sunsetFactor * 0.85)!;
    top = Color.lerp(top, nightTop, lighting.nightFactor)!;

    Color mid = Color.lerp(dayMid, sunsetMid, lighting.sunsetFactor * 0.85)!;
    mid = Color.lerp(mid, nightMid, lighting.nightFactor)!;

    Color bot = Color.lerp(dayHorizon, sunsetHorizon, lighting.sunsetFactor * 0.85)!;
    bot = Color.lerp(bot, nightHorizon, lighting.nightFactor)!;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, hY + 60),
          [top, mid, bot],
          const [0.0, 0.55, 1.0],
        ),
    );

    if (lighting.nightFactor > 0.14) {
      final starAlpha = ((lighting.nightFactor - 0.14) / 0.86).clamp(0.0, 1.0);
      final starPaint = Paint()..style = PaintingStyle.fill;
      for (int i = 0; i < 58; i++) {
        final fx = ((i * 73.13 + 17.0) % 100.0) / 100.0;
        final fy = ((i * 39.71 + 7.0) % 100.0) / 100.0;
        final twinkle = 0.5 + 0.5 * math.sin(animTime * 2.2 + i * 1.9);
        starPaint.color = Colors.white.withValues(alpha: starAlpha * twinkle * 0.88);
        canvas.drawCircle(
          Offset(fx * size.width, fy * hY * 0.92),
          (i % 5 == 0) ? 1.65 : 1.05,
          starPaint,
        );
      }
    }

    final sunAngle = (lighting.timeOfDay - 0.25) * math.pi * 2.0;
    final sunElev = math.sin(sunAngle);
    final sunX = size.width * (0.52 - math.cos(sunAngle) * 0.34);
    final sunY = (hY * (0.76 - sunElev * 0.44)).clamp(38.0, hY + 10.0);

    if (lighting.nightFactor < 0.78) {
      final vis = (1.0 - lighting.nightFactor).clamp(0.0, 1.0);
      final sunCol = Color.lerp(
        const Color(0xFFFFF4D2),
        const Color(0xFFFF9650),
        lighting.sunsetFactor,
      )!;
      canvas.drawCircle(
        Offset(sunX, sunY),
        70,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(sunX, sunY),
            70,
            [sunCol.withValues(alpha: 0.36 * vis), sunCol.withValues(alpha: 0.0)],
          ),
      );
      canvas.drawCircle(
        Offset(sunX, sunY),
        14,
        Paint()..color = sunCol.withValues(alpha: 0.92 * vis),
      );
    }

    if (lighting.nightFactor > 0.25) {
      final moonVis = ((lighting.nightFactor - 0.25) / 0.75).clamp(0.0, 1.0);
      final moonPos = Offset(size.width * 0.68, math.max(58.0, hY * 0.36));
      canvas.drawCircle(
        moonPos,
        42,
        Paint()
          ..shader = ui.Gradient.radial(
            moonPos,
            42,
            [
              const Color(0xFFCDE2FF).withValues(alpha: 0.32 * moonVis),
              const Color(0xFFCDE2FF).withValues(alpha: 0.0),
            ],
          ),
      );
      canvas.drawCircle(
        moonPos,
        12,
        Paint()..color = const Color(0xFFEAF3FF).withValues(alpha: 0.92 * moonVis),
      );
    }
  }

  static void paintMesh(
    Canvas canvas,
    Size size,
    Camera3D camera,
    DesertLighting lighting,
    MeshBuilder mesh,
  ) {
    final eye = camera.eye;
    final renderList = <_RenderPoly>[];

    for (final poly in mesh.polys) {
      if (!poly.doubleSided && poly.layer == RenderLayer.world) {
        final toEye = eye - poly.centroid;
        if (poly.normal.dot(toEye) <= 0.0) {
          continue;
        }
      }

      final pts = <Offset>[];
      double sumDepth = 0.0;
      double minX = double.infinity;
      double maxX = double.negativeInfinity;
      double minY = double.infinity;
      double maxY = double.negativeInfinity;
      bool valid = true;

      for (final v in poly.vertices) {
        final p = camera.project(v, size);
        if (!p.inFront) {
          valid = false;
          break;
        }
        pts.add(p.offset);
        sumDepth += p.depth;
        if (p.offset.dx < minX) minX = p.offset.dx;
        if (p.offset.dx > maxX) maxX = p.offset.dx;
        if (p.offset.dy < minY) minY = p.offset.dy;
        if (p.offset.dy > maxY) maxY = p.offset.dy;
      }

      if (!valid) continue;
      if (maxX < -60 || minX > size.width + 60 || maxY < -60 || minY > size.height + 60) {
        continue;
      }

      final localDepth = (sumDepth / pts.length) + poly.depthBias;
      final groupDepth = poly.sortGroupAnchor != null
          ? camera.project(poly.sortGroupAnchor!, size).depth
          : localDepth;

      final Color shaded = poly.unlit
          ? poly.color
          : lighting.shadeFace(
              baseColor: poly.color,
              normal: poly.normal,
              emissiveColor: poly.emissiveColor,
              emissiveStrength: poly.emissiveStrength,
              emissiveNightOnly: poly.emissiveNightOnly,
              distanceFade: poly.distanceFade,
            );

      renderList.add(
        _RenderPoly(
          points: pts,
          layerIndex: poly.layer.index,
          groupDepth: groupDepth,
          subOrder: poly.subOrder,
          localDepth: localDepth,
          fillColor: shaded,
          outlineColor: poly.outlineColor,
        ),
      );
    }

    // Sort: layer ASC -> groupDepth DESC (furthest object first) -> subOrder ASC -> localDepth DESC!
    renderList.sort((a, b) {
      final layerCmp = a.layerIndex.compareTo(b.layerIndex);
      if (layerCmp != 0) return layerCmp;
      final groupCmp = b.groupDepth.compareTo(a.groupDepth);
      if (groupCmp != 0) return groupCmp;
      final subCmp = a.subOrder.compareTo(b.subOrder);
      if (subCmp != 0) return subCmp;
      return b.localDepth.compareTo(a.localDepth);
    });

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final seamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    for (final rp in renderList) {
      final path = Path()..addPolygon(rp.points, true);
      fillPaint.color = rp.fillColor;
      canvas.drawPath(path, fillPaint);

      if (rp.layerIndex != RenderLayer.shadow.index && rp.fillColor.a > 0.95) {
        seamPaint.color = rp.fillColor;
        canvas.drawPath(path, seamPaint);
      }

      if (rp.outlineColor != null) {
        outlinePaint.color = rp.outlineColor!;
        canvas.drawPath(path, outlinePaint);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final line in mesh.lines) {
      final a = camera.project(line.start, size);
      final b = camera.project(line.end, size);
      if (!a.inFront || !b.inFront) continue;
      linePaint
        ..color = line.color
        ..strokeWidth = line.width;
      canvas.drawLine(a.offset, b.offset, linePaint);
    }

    _paintPerspectiveSigns(canvas, size, camera, lighting, mesh.signs);
    _paintGlowLights(canvas, size, camera, lighting, mesh.glows);
  }

  static void _paintPerspectiveSigns(
    Canvas canvas,
    Size size,
    Camera3D camera,
    DesertLighting lighting,
    List<SignText3D> signs,
  ) {
    final nightStrength = (lighting.nightFactor * 0.95 + lighting.sunsetFactor * 0.4).clamp(0.0, 1.0);

    for (final sign in signs) {
      final tl = camera.project(sign.topLeft, size);
      final tr = camera.project(sign.topRight, size);
      final bl = camera.project(sign.bottomLeft, size);
      if (!tl.inFront || !tr.inFront || !bl.inFront) continue;

      final u = tr.offset - tl.offset;
      final v = bl.offset - tl.offset;
      // Backface-cull sign text when orbiting behind a signboard in the 3D Studio!
      final cross2D = u.dx * v.dy - u.dy * v.dx;
      if (cross2D <= 0) continue;

      final signW = u.distance;
      final signH = v.distance;
      if (signW < 12 || signH < 5) continue;

      final textCol = (sign.nightGlow && sign.glowColor != null)
          ? Color.lerp(sign.color, sign.glowColor!, nightStrength * 0.88)!
          : sign.color;

      final tp = TextPainter(
        text: TextSpan(
          text: sign.text,
          style: TextStyle(
            color: textCol,
            fontSize: 28.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            height: 1.0,
            shadows: sign.nightGlow && nightStrength > 0.25 && sign.glowColor != null
                ? [
                    Shadow(
                      color: sign.glowColor!.withValues(alpha: 0.85 * nightStrength),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      if (tp.width < 1 || tp.height < 1) continue;

      final scaleX = signW / tp.width;
      final scaleY = signH / tp.height;
      final fit = math.min(scaleX, scaleY);

      final usedW = tp.width * fit;
      final usedH = tp.height * fit;
      final padU = (1.0 - usedW / signW) * 0.5;
      final padV = (1.0 - usedH / signH) * 0.5;

      final ux = (u.dx / signW) * fit;
      final uy = (u.dy / signW) * fit;
      final vx = (v.dx / signH) * fit;
      final vy = (v.dy / signH) * fit;

      final originX = tl.offset.dx + u.dx * padU + v.dx * padV;
      final originY = tl.offset.dy + u.dy * padU + v.dy * padV;

      final matrix = Float64List.fromList([
        ux, uy, 0, 0,
        vx, vy, 0, 0,
        0, 0, 1, 0,
        originX, originY, 0, 1,
      ]);

      canvas.save();
      canvas.transform(matrix);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  static void _paintGlowLights(
    Canvas canvas,
    Size size,
    Camera3D camera,
    DesertLighting lighting,
    List<GlowLight3D> glows,
  ) {
    final nightStrength = (lighting.nightFactor * 0.95 + lighting.sunsetFactor * 0.35).clamp(0.0, 1.0);
    for (final g in glows) {
      final factor = g.nightOnly ? nightStrength : 1.0;
      if (factor <= 0.04) continue;

      final p = camera.project(g.position, size);
      if (!p.inFront) continue;
      final r = (g.radius * (Camera3D.defaultDistance / p.depth)).clamp(10.0, 80.0);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          p.offset,
          r,
          [
            g.color.withValues(alpha: (0.44 * g.intensity * factor).clamp(0.0, 0.75)),
            g.color.withValues(alpha: 0.0),
          ],
        );
      canvas.drawCircle(p.offset, r, paint);
    }
  }
}

/// Main Desert Outpost CustomPainter assembling the full unified 3D world.
class DesertOutpostPainter extends CustomPainter {
  DesertOutpostPainter({
    required this.controller,
  }) : super(repaint: controller);

  final GameController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final camera = controller.camera;
    final lighting = controller.lighting;
    final animTime = controller.animTime;

    SceneRenderer3D.paintSkyDome(canvas, size, camera, lighting, animTime);

    final mesh = MeshBuilder();
    EnvironmentBuilder.build(
      mesh,
      lighting,
      animTime,
      parkingTier: controller.parkingTier,
      builtCount: controller.builtCount,
    );

    for (final deco in controller.decorations) {
      EntityModels.buildDecoration(mesh, deco, lighting, animTime);
    }
    for (final plot in controller.visiblePlots) {
      BuildingModels.buildPlot(
        mesh,
        plot,
        lighting,
        animTime,
        isSelected: controller.selectedPlotId == plot.id,
      );
    }
    for (final vehicle in controller.vehicles) {
      EntityModels.buildVehicle(mesh, vehicle, lighting);
    }
    for (final visitor in controller.visitors) {
      EntityModels.buildVisitor(mesh, visitor, lighting);
    }

    SceneRenderer3D.paintMesh(canvas, size, camera, lighting, mesh);
    _paintParticles(canvas, size, camera, controller.particles);
    _paintFloatingCash(canvas, size, camera, controller.floatingCash);
  }

  void _paintParticles(
    Canvas canvas,
    Size size,
    Camera3D camera,
    List<Particle3D> particles,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final pt in particles) {
      final p = camera.project(pt.position, size);
      if (!p.inFront) continue;
      final fade = (1.0 - pt.progress).clamp(0.0, 1.0);
      paint.color = pt.color.withValues(alpha: fade * 0.92);
      final distScale = (Camera3D.defaultDistance / p.depth).clamp(0.5, 1.8);
      final r = pt.size * distScale * (pt.isCoin ? 1.0 : (0.65 + pt.progress * 0.85));
      if (pt.isCoin) {
        canvas.drawCircle(p.offset, r, paint);
        paint.color = const Color(0xFFFFF4C2).withValues(alpha: fade);
        canvas.drawCircle(p.offset, r * 0.45, paint);
      } else {
        final path = Path()
          ..moveTo(p.offset.dx, p.offset.dy - r)
          ..lineTo(p.offset.dx + r, p.offset.dy)
          ..lineTo(p.offset.dx, p.offset.dy + r)
          ..lineTo(p.offset.dx - r, p.offset.dy)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _paintFloatingCash(
    Canvas canvas,
    Size size,
    Camera3D camera,
    List<FloatingCash> popups,
  ) {
    for (final fc in popups) {
      final riseY = fc.position.y + fc.progress * 2.2;
      final p = camera.project(Vec3(fc.position.x, riseY, fc.position.z), size);
      if (!p.inFront) continue;
      final alpha = (1.0 - math.pow(fc.progress, 2)).clamp(0.0, 1.0);

      final tp = TextPainter(
        text: TextSpan(
          text: fc.text,
          style: TextStyle(
            color: fc.color.withValues(alpha: alpha),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.45 * alpha),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(p.offset.dx - tp.width * 0.5, p.offset.dy - tp.height * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant DesertOutpostPainter oldDelegate) => true;
}
