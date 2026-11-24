import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../models/game_models.dart';
import '../systems/game_controller.dart';
import '../theme/desert_palette.dart';
import '../world/building_models.dart';
import '../world/entity_models.dart';
import '../world/environment_builder.dart';
import 'camera_3d.dart';
import 'lighting.dart';
import 'mesh_builder.dart';
import 'vec3.dart';

/// Projected drawable face ready for back-to-front painter sorting and GPU triangle batching.
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

/// High-throughput pure-Dart 3D rendering pipeline:
/// - Precomputes `CameraFrame` once per frame
/// - Clips foreground polygons cleanly against the near plane
/// - Submits all sorted low-poly faces in a SINGLE `Canvas.drawVertices` hardware batch
/// - Caches static world geometry and `TextPainter` layouts to eliminate GC spikes
class SceneRenderer3D {
  const SceneRenderer3D._();

  static Float32List _posBuffer = Float32List(16384);
  static Int32List _colBuffer = Int32List(8192);
  static final Paint _batchPaint = Paint()..isAntiAlias = true;
  static final Map<int, TextPainter> _signLayoutCache = <int, TextPainter>{};
  static final Map<int, TextPainter> _popupLayoutCache = <int, TextPainter>{};

  static void _ensureVertexCapacity(int vertexCount) {
    final neededFloats = vertexCount * 2;
    if (_posBuffer.length < neededFloats) {
      int nextLen = _posBuffer.length;
      while (nextLen < neededFloats) {
        nextLen *= 2;
      }
      _posBuffer = Float32List(nextLen);
      _colBuffer = Int32List(nextLen ~/ 2);
    }
  }

  static void paintSkyDome(
    Canvas canvas,
    Size size,
    Camera3D camera,
    DesertLighting lighting,
    double animTime,
  ) {
    final hY = camera.horizonScreenY(size).clamp(size.height * 0.05, size.height * 0.58);

    const dayTop = Color(0xFF6693C9);
    const dayMid = Color(0xFFA8C4DF);
    const dayHorizon = Color(0xFFF7CCA6);

    const sunsetTop = Color(0xFF4B426E);
    const sunsetMid = Color(0xFFC86A6A);
    const sunsetHorizon = Color(0xFFFFAF68);

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
          Offset(0, hY + 68),
          [top, mid, bot],
          const [0.0, 0.54, 1.0],
        ),
    );

    if (lighting.nightFactor > 0.14) {
      final starAlpha = ((lighting.nightFactor - 0.14) / 0.86).clamp(0.0, 1.0);
      final starPaint = Paint()..style = PaintingStyle.fill;
      for (int i = 0; i < 64; i++) {
        final fx = ((i * 73.13 + 17.0) % 100.0) / 100.0;
        final fy = ((i * 39.71 + 7.0) % 100.0) / 100.0;
        final twinkle = 0.5 + 0.5 * math.sin(animTime * 2.2 + i * 1.9);
        starPaint.color = const Color(0xFFFFFFFF).withValues(alpha: starAlpha * twinkle * 0.88);
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
        const Color(0xFFFFF5D6),
        const Color(0xFFFF9650),
        lighting.sunsetFactor,
      )!;
      canvas.drawCircle(
        Offset(sunX, sunY),
        84,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(sunX, sunY),
            84,
            [sunCol.withValues(alpha: 0.38 * vis), sunCol.withValues(alpha: 0.0)],
          ),
      );
      canvas.drawCircle(
        Offset(sunX, sunY),
        15,
        Paint()..color = sunCol.withValues(alpha: 0.94 * vis),
      );
    }

    if (lighting.nightFactor > 0.25) {
      final moonVis = ((lighting.nightFactor - 0.25) / 0.75).clamp(0.0, 1.0);
      final moonPos = Offset(size.width * 0.68, math.max(58.0, hY * 0.36));
      canvas.drawCircle(
        moonPos,
        44,
        Paint()
          ..shader = ui.Gradient.radial(
            moonPos,
            44,
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

    // Subtle soaring red-tailed desert hawk silhouette circling near Monument Valley
    if (lighting.nightFactor < 0.65) {
      final hawkAlpha = (1.0 - lighting.nightFactor * 1.4).clamp(0.0, 0.55);
      final hx = size.width * (0.34 + math.sin(animTime * 0.16) * 0.14);
      final hy = hY * (0.42 + math.cos(animTime * 0.23) * 0.06);
      final flap = math.sin(animTime * 2.6) * 2.2;
      final wingPaint = Paint()
        ..color = const Color(0xFF4A312C).withValues(alpha: hawkAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      final wingPath = Path()
        ..moveTo(hx - 7.5, hy - 1.5 - flap)
        ..quadraticBezierTo(hx - 3.2, hy - 3.6, hx, hy)
        ..quadraticBezierTo(hx + 3.2, hy - 3.6, hx + 7.5, hy - 1.5 - flap);
      canvas.drawPath(wingPath, wingPaint);
    }
  }

  static void paintMesh(
    Canvas canvas,
    Size size,
    Camera3D camera,
    DesertLighting lighting,
    MeshBuilder mesh,
  ) {
    final frame = camera.createFrame(size);
    final eye = frame.eye;
    final renderList = <_RenderPoly>[];

    for (final poly in mesh.polys) {
      if (!poly.doubleSided && poly.layer == RenderLayer.world) {
        final dx = eye.x - poly.centroid.x;
        final dy = eye.y - poly.centroid.y;
        final dz = eye.z - poly.centroid.z;
        if (poly.normal.x * dx + poly.normal.y * dy + poly.normal.z * dz <= 0.0) {
          continue;
        }
      }

      final pts = _projectAndClipPoly(poly.vertices, frame);
      if (pts == null || pts.$1.length < 3) continue;

      final screenPts = pts.$1;
      final avgDepth = pts.$2;

      double minX = double.infinity;
      double maxX = double.negativeInfinity;
      double minY = double.infinity;
      double maxY = double.negativeInfinity;
      for (final p in screenPts) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      if (maxX < -80 || minX > size.width + 80 || maxY < -80 || minY > size.height + 80) {
        continue;
      }

      final localDepth = avgDepth + poly.depthBias;
      final groupDepth = poly.sortGroupAnchor != null
          ? frame.project(poly.sortGroupAnchor!).depth
          : localDepth;

      final Color shaded;
      if (poly.unlit) {
        shaded = poly.color;
      } else if (poly.isCloud) {
        shaded = lighting.shadeCloudFace(poly.normal);
      } else {
        shaded = lighting.shadeFace(
          baseColor: poly.color,
          normal: poly.normal,
          emissiveColor: poly.emissiveColor,
          emissiveStrength: poly.emissiveStrength,
          emissiveNightOnly: poly.emissiveNightOnly,
          distanceFade: poly.distanceFade,
        );
      }

      renderList.add(
        _RenderPoly(
          points: screenPts,
          layerIndex: poly.layer.index,
          groupDepth: groupDepth,
          subOrder: poly.subOrder,
          localDepth: localDepth,
          fillColor: shaded,
          outlineColor: poly.outlineColor,
        ),
      );
    }

    // Sort: layer ASC -> groupDepth DESC -> subOrder ASC -> localDepth DESC
    renderList.sort((a, b) {
      final layerCmp = a.layerIndex.compareTo(b.layerIndex);
      if (layerCmp != 0) return layerCmp;
      final groupCmp = b.groupDepth.compareTo(a.groupDepth);
      if (groupCmp != 0) return groupCmp;
      final subCmp = a.subOrder.compareTo(b.subOrder);
      if (subCmp != 0) return subCmp;
      return b.localDepth.compareTo(a.localDepth);
    });

    // Count total triangle vertices for single-pass GPU Vertices batch
    int totalTriVerts = 0;
    for (final rp in renderList) {
      totalTriVerts += (rp.points.length - 2) * 3;
    }

    if (totalTriVerts >= 3) {
      _ensureVertexCapacity(totalTriVerts);
      int pIdx = 0;
      int cIdx = 0;
      final outlined = <_RenderPoly>[];

      for (final rp in renderList) {
        final pts = rp.points;
        final argb = rp.fillColor.toARGB32();
        final p0 = pts[0];
        for (int i = 1; i < pts.length - 1; i++) {
          final p1 = pts[i];
          final p2 = pts[i + 1];

          _posBuffer[pIdx++] = p0.dx;
          _posBuffer[pIdx++] = p0.dy;
          _posBuffer[pIdx++] = p1.dx;
          _posBuffer[pIdx++] = p1.dy;
          _posBuffer[pIdx++] = p2.dx;
          _posBuffer[pIdx++] = p2.dy;

          _colBuffer[cIdx++] = argb;
          _colBuffer[cIdx++] = argb;
          _colBuffer[cIdx++] = argb;
        }
        if (rp.outlineColor != null) {
          outlined.add(rp);
        }
      }

      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.sublistView(_posBuffer, 0, pIdx),
        colors: Int32List.sublistView(_colBuffer, 0, cIdx),
      );
      canvas.drawVertices(vertices, BlendMode.dst, _batchPaint);
      vertices.dispose();

      if (outlined.isNotEmpty) {
        final outlinePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round;
        for (final rp in outlined) {
          outlinePaint.color = rp.outlineColor!;
          canvas.drawPath(Path()..addPolygon(rp.points, true), outlinePaint);
        }
      }
    }

    if (mesh.lines.isNotEmpty) {
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (final line in mesh.lines) {
        final a = frame.project(line.start);
        final b = frame.project(line.end);
        if (!a.inFront || !b.inFront) continue;
        linePaint
          ..color = line.color
          ..strokeWidth = line.width;
        canvas.drawLine(a.offset, b.offset, linePaint);
      }
    }

    _paintPerspectiveSigns(canvas, frame, lighting, mesh.signs);
    _paintGlowLights(canvas, frame, lighting, mesh.glows);
  }

  /// Fast projection with near-plane Sutherland-Hodgman polygon clipping so large
  /// foreground road & terrain quads never vanish abruptly when zooming in.
  static (List<Offset>, double)? _projectAndClipPoly(List<Vec3> worldVerts, CameraFrame frame) {
    bool allInFront = true;
    bool anyInFront = false;

    for (final v in worldVerts) {
      final cz = (v.x - frame.eye.x) * frame.forward.x +
          (v.y - frame.eye.y) * frame.forward.y +
          (v.z - frame.eye.z) * frame.forward.z;
      if (cz <= CameraFrame.nearClipZ) {
        allInFront = false;
      } else {
        anyInFront = true;
      }
    }

    if (!anyInFront) return null;

    if (allInFront) {
      final pts = <Offset>[];
      double sumDepth = 0.0;
      for (final v in worldVerts) {
        final p = frame.project(v);
        pts.add(p.offset);
        sumDepth += p.depth;
      }
      return (pts, sumDepth / pts.length);
    }

    // Clip in camera space against z = nearClipZ
    final camVerts = worldVerts.map(frame.toCameraSpace).toList(growable: false);
    final clipped = <Vec3>[];
    const nearZ = CameraFrame.nearClipZ;

    for (int i = 0; i < camVerts.length; i++) {
      final curr = camVerts[i];
      final prev = camVerts[(i + camVerts.length - 1) % camVerts.length];
      final currIn = curr.z >= nearZ;
      final prevIn = prev.z >= nearZ;

      if (currIn != prevIn) {
        final t = (nearZ - prev.z) / (curr.z - prev.z);
        clipped.add(prev.lerp(curr, t));
      }
      if (currIn) {
        clipped.add(curr);
      }
    }

    if (clipped.length < 3) return null;
    final pts = <Offset>[];
    double sumDepth = 0.0;
    for (final c in clipped) {
      final invZ = frame.focalLength / c.z;
      pts.add(Offset(frame.halfWidth + c.x * invZ, frame.halfHeight - c.y * invZ));
      sumDepth += c.z;
    }
    return (pts, sumDepth / pts.length);
  }

  static void _paintPerspectiveSigns(
    Canvas canvas,
    CameraFrame frame,
    DesertLighting lighting,
    List<SignText3D> signs,
  ) {
    final nightStrength = (lighting.nightFactor * 0.95 + lighting.sunsetFactor * 0.4).clamp(0.0, 1.0);
    final nightBucket = (nightStrength * 12).round();

    for (final sign in signs) {
      final tl = frame.project(sign.topLeft);
      final tr = frame.project(sign.topRight);
      final bl = frame.project(sign.bottomLeft);
      if (!tl.inFront || !tr.inFront || !bl.inFront) continue;

      final u = tr.offset - tl.offset;
      final v = bl.offset - tl.offset;
      final cross2D = u.dx * v.dy - u.dy * v.dx;
      if (cross2D <= 0) continue;

      final signW = u.distance;
      final signH = v.distance;
      if (signW < 10 || signH < 4) continue;

      final effectiveStrength = nightBucket / 12.0;
      final textCol = (sign.nightGlow && sign.glowColor != null)
          ? Color.lerp(sign.color, sign.glowColor!, effectiveStrength * 0.88)!
          : sign.color;

      final cacheKey = Object.hash(
        sign.text,
        textCol.toARGB32(),
        sign.nightGlow ? nightBucket : 0,
        sign.glowColor?.toARGB32() ?? 0,
      );

      final tp = _signLayoutCache.putIfAbsent(cacheKey, () {
        if (_signLayoutCache.length > 240) _signLayoutCache.clear();
        return TextPainter(
          text: TextSpan(
            text: sign.text,
            style: DesertTypography.display(
              size: 26.0,
              color: textCol,
              letterSpacing: 0.9,
              height: 1.02,
              shadows: sign.nightGlow && effectiveStrength > 0.25 && sign.glowColor != null
                  ? [
                      Shadow(
                        color: sign.glowColor!.withValues(alpha: 0.85 * effectiveStrength),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
      });

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
    CameraFrame frame,
    DesertLighting lighting,
    List<GlowLight3D> glows,
  ) {
    final nightStrength = (lighting.nightFactor * 0.95 + lighting.sunsetFactor * 0.35).clamp(0.0, 1.0);
    for (final g in glows) {
      final factor = g.nightOnly ? nightStrength : 1.0;
      if (factor <= 0.04) continue;

      final p = frame.project(g.position);
      if (!p.inFront) continue;
      final r = (g.radius * (Camera3D.defaultDistance / p.depth)).clamp(10.0, 82.0);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          p.offset,
          r,
          [
            g.color.withValues(alpha: (0.44 * g.intensity * factor).clamp(0.0, 0.76)),
            g.color.withValues(alpha: 0.0),
          ],
        );
      canvas.drawCircle(p.offset, r, paint);
    }
  }

  static TextPainter layoutPopupText(String text, Color baseColor, int alphaBucket) {
    final alpha = (alphaBucket / 20.0).clamp(0.0, 1.0);
    final key = Object.hash(text, baseColor.toARGB32(), alphaBucket);
    return _popupLayoutCache.putIfAbsent(key, () {
      if (_popupLayoutCache.length > 320) _popupLayoutCache.clear();
      return TextPainter(
        text: TextSpan(
          text: text,
          style: DesertTypography.display(
            size: 14.5,
            color: baseColor.withValues(alpha: alpha),
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: const Color(0xFF23120B).withValues(alpha: 0.72 * alpha),
                blurRadius: 4,
                offset: const Offset(0, 1.8),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}

/// Main Desert Outpost CustomPainter with multi-tier static geometry caching.
class DesertOutpostPainter extends CustomPainter {
  DesertOutpostPainter({
    required this.controller,
  }) : super(repaint: controller.renderListenable);

  final GameController controller;

  final MeshBuilder _staticWorldCache = MeshBuilder();
  int _cachedWorldSignature = -1;

  final MeshBuilder _frameMesh = MeshBuilder();

  @override
  void paint(Canvas canvas, Size size) {
    final camera = controller.camera;
    final lighting = controller.lighting;
    final animTime = controller.animTime;

    SceneRenderer3D.paintSkyDome(canvas, size, camera, lighting, animTime);

    // Quantize shadow movement so static world shadows refresh smoothly ~once/sec
    // while terrain, mesas, highway, rocks & un-animated buildings stay cached!
    final shadowBucket = (lighting.timeOfDay * 96).floor();
    final staticSig = Object.hash(
      controller.parkingTier,
      controller.builtCount,
      controller.decorations.length,
      controller.staticBuildingsSignature,
      shadowBucket,
    );

    if (staticSig != _cachedWorldSignature) {
      _cachedWorldSignature = staticSig;
      _staticWorldCache.clear();
      EnvironmentBuilder.buildStatic(
        _staticWorldCache,
        lighting,
        parkingTier: controller.parkingTier,
        builtCount: controller.builtCount,
      );
      for (final deco in controller.decorations) {
        if (!EntityModels.isAnimatedDecoration(deco)) {
          EntityModels.buildDecoration(_staticWorldCache, deco, lighting, 0.0);
        }
      }
      for (final plot in controller.visiblePlots) {
        if (BuildingModels.isStaticPlot(plot, isSelected: controller.selectedPlotId == plot.id)) {
          BuildingModels.buildPlot(
            _staticWorldCache,
            plot,
            lighting,
            0.0,
            isSelected: false,
          );
        }
      }
    }

    _frameMesh.clear();
    _frameMesh.appendFrom(_staticWorldCache);

    // Dynamic ambient environment (clouds, swaying sagebrush, spinning windmill, tumbleweed)
    EnvironmentBuilder.buildDynamic(
      _frameMesh,
      lighting,
      animTime,
      parkingTier: controller.parkingTier,
      builtCount: controller.builtCount,
    );

    for (final deco in controller.decorations) {
      if (EntityModels.isAnimatedDecoration(deco)) {
        EntityModels.buildDecoration(_frameMesh, deco, lighting, animTime);
      }
    }

    for (final plot in controller.visiblePlots) {
      final selected = controller.selectedPlotId == plot.id;
      if (!BuildingModels.isStaticPlot(plot, isSelected: selected)) {
        BuildingModels.buildPlot(
          _frameMesh,
          plot,
          lighting,
          animTime,
          isSelected: selected,
        );
      }
    }

    for (final vehicle in controller.vehicles) {
      EntityModels.buildVehicle(_frameMesh, vehicle, lighting);
    }
    for (final visitor in controller.visitors) {
      EntityModels.buildVisitor(_frameMesh, visitor, lighting);
    }

    SceneRenderer3D.paintMesh(canvas, size, camera, lighting, _frameMesh);

    final frame = camera.createFrame(size);
    _paintParticles(canvas, frame, controller.particles);
    _paintFloatingCash(canvas, frame, controller.floatingCash);
  }

  void _paintParticles(
    Canvas canvas,
    CameraFrame frame,
    List<Particle3D> particles,
  ) {
    if (particles.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final pt in particles) {
      final p = frame.project(pt.position);
      if (!p.inFront) continue;
      final fade = (1.0 - pt.progress).clamp(0.0, 1.0);
      paint.color = pt.color.withValues(alpha: fade * 0.94);
      final distScale = (Camera3D.defaultDistance / p.depth).clamp(0.55, 2.0);
      final r = pt.size * distScale * (pt.isCoin ? 1.0 : (0.65 + pt.progress * 0.85));
      if (pt.isCoin) {
        canvas.drawCircle(p.offset, r, paint);
        paint.color = const Color(0xFFFFF7D6).withValues(alpha: fade);
        canvas.drawCircle(p.offset, r * 0.46, paint);
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
    CameraFrame frame,
    List<FloatingCash> popups,
  ) {
    if (popups.isEmpty) return;
    for (final fc in popups) {
      final riseY = fc.position.y + fc.progress * 2.35;
      final driftX = fc.position.x + fc.driftX * fc.progress;
      final p = frame.project(Vec3(driftX, riseY, fc.position.z));
      if (!p.inFront) continue;
      final alpha = (1.0 - math.pow(fc.progress, 2)).clamp(0.0, 1.0);
      final alphaBucket = (alpha * 20).round();
      if (alphaBucket <= 0) continue;

      final tp = SceneRenderer3D.layoutPopupText(fc.text, fc.color, alphaBucket);
      tp.paint(canvas, Offset(p.offset.dx - tp.width * 0.5, p.offset.dy - tp.height * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant DesertOutpostPainter oldDelegate) => true;
}
