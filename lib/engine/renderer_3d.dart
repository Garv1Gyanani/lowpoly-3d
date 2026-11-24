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
import '../world/outpost_layout.dart';
import '../world/terrain/highway_and_parking.dart';
import 'camera_3d.dart';
import 'lighting.dart';
import 'mesh_builder.dart';
import 'vec3.dart';

/// Projected drawable face ready for Newell plane-refined back-to-front sorting and GPU batching.
class _RenderPoly {
  _RenderPoly({
    required this.id,
    required this.points,
    required this.worldVerts,
    required this.planeNormal,
    required this.planeD,
    required this.layerIndex,
    required this.groupDepth,
    required this.subOrder,
    required this.localDepth,
    required this.minZ,
    required this.maxZ,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.hasSortGroup,
    required this.fillColor,
    this.outlineColor,
  });

  final int id;
  final List<Offset> points;
  final List<Vec3> worldVerts;
  final Vec3 planeNormal;
  final double planeD;
  final int layerIndex;
  final double groupDepth;
  final int subOrder;
  final double localDepth;
  final double minZ;
  final double maxZ;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final bool hasSortGroup;
  final Color fillColor;
  final Color? outlineColor;
  int pulls = 0;
  int lastPulledBefore = -1;
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
    double animTime, {
    CameraFrame? frame,
  }) {
    final activeFrame = frame ?? camera.createFrame(size);
    final horizDir = Vec3(activeFrame.forward.x, 0.0, activeFrame.forward.z).normalized();
    final rawHorizonY = activeFrame.project(activeFrame.eye + horizDir * 500.0).offset.dy;
    final hY = rawHorizonY.clamp(size.height * 0.05, size.height * 0.58);

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
    MeshBuilder mesh, {
    CameraFrame? frame,
  }) {
    final activeFrame = frame ?? camera.createFrame(size);
    final eye = activeFrame.eye;
    final renderList = <_RenderPoly>[];

    for (final poly in mesh.polys) {
      // Bounding-sphere frustum culling skips off-screen geometry before projection & sorting.
      if (activeFrame.isSphereCulled(poly.centroid, poly.radius)) continue;

      final v0 = poly.vertices.first;
      final toEyeX = eye.x - poly.centroid.x;
      final toEyeY = eye.y - poly.centroid.y;
      final toEyeZ = eye.z - poly.centroid.z;
      final viewDot = poly.normal.x * toEyeX + poly.normal.y * toEyeY + poly.normal.z * toEyeZ;

      if (!poly.doubleSided && poly.layer == RenderLayer.world && viewDot <= 0.0) {
        continue;
      }

      final pts = _projectAndClipPoly(poly.vertices, activeFrame);
      if (pts == null || pts.$1.length < 3) continue;

      final screenPts = pts.$1;
      final avgDepth = pts.$2;
      final minZ = pts.$3;
      final maxZ = pts.$4;

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
      // Sub-pixel LOD culling: skip microscopic world faces when zoomed far out.
      if (poly.layer == RenderLayer.world &&
          (maxX - minX) < 1.15 &&
          (maxY - minY) < 1.15) {
        continue;
      }

      final isWorld = poly.layer == RenderLayer.world;
      // Only apply legacy depthBias to coplanar 2D ground/shadow/terrain layers;
      // 3D world geometry uses exact 3D depth + Newell plane-side ordering so recessed
      // bulbs, windows, and beams never bleed through roofs or awnings.
      final localDepth = isWorld ? avgDepth : avgDepth + poly.depthBias;
      final groupDepth = poly.sortGroupAnchor != null
          ? activeFrame.project(poly.sortGroupAnchor!).depth
          : (isWorld ? maxZ : localDepth);

      // Orient the face plane normal toward the camera for exact Newell plane-side tests.
      final planeNormal = viewDot < 0.0 ? -poly.normal : poly.normal;
      final planeD = planeNormal.x * v0.x + planeNormal.y * v0.y + planeNormal.z * v0.z;

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
          id: renderList.length,
          points: screenPts,
          worldVerts: poly.vertices,
          planeNormal: planeNormal,
          planeD: planeD,
          layerIndex: poly.layer.index,
          groupDepth: groupDepth,
          subOrder: poly.subOrder,
          localDepth: localDepth,
          minZ: minZ,
          maxZ: maxZ,
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          hasSortGroup: poly.sortGroupAnchor != null,
          fillColor: shaded,
          outlineColor: poly.outlineColor,
        ),
      );
    }

    // 1. Fast initial back-to-front sort: layer ASC -> groupDepth DESC -> subOrder ASC -> localDepth DESC
    renderList.sort((a, b) {
      final layerCmp = a.layerIndex.compareTo(b.layerIndex);
      if (layerCmp != 0) return layerCmp;
      final groupCmp = b.groupDepth.compareTo(a.groupDepth);
      if (groupCmp != 0) return groupCmp;
      final subCmp = a.subOrder.compareTo(b.subOrder);
      if (subCmp != 0) return subCmp;
      return b.localDepth.compareTo(a.localDepth);
    });

    // 2. Newell plane-side refinement on RenderLayer.world so countertops, walls, flush windows,
    //    signs & props NEVER flip or pop when orbiting 360° or tilting top-down!
    _refineWorldDepthOrder(renderList);

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
        final a = activeFrame.project(line.start);
        final b = activeFrame.project(line.end);
        if (!a.inFront || !b.inFront) continue;
        linePaint
          ..color = line.color
          ..strokeWidth = line.width;
        canvas.drawLine(a.offset, b.offset, linePaint);
      }
    }

    _paintPerspectiveSigns(canvas, activeFrame, lighting, mesh.signs, renderList);
    _paintGlowLights(canvas, activeFrame, lighting, mesh.glows);
  }

  /// Canonical Newell's Algorithm depth resolver on `RenderLayer.world`:
  /// Starting from `maxZ`-descending order, pulls any occluded polygon `Q` ahead of `P`
  /// whenever their 2D screen projections truly overlap (SAT) and 3D half-space tests
  /// prove `P` lies in front of `Q`. Uses a watermark-guarded `maxZ <= minZ` early break
  /// so nearby buildings at the same depth never miss overlaps regardless of polygon count.
  static void _refineWorldDepthOrder(List<_RenderPoly> list) {
    final worldLayer = RenderLayer.world.index;
    int start = -1;
    int end = list.length;
    for (int i = 0; i < list.length; i++) {
      final li = list[i].layerIndex;
      if (li == worldLayer && start == -1) {
        start = i;
      } else if (li > worldLayer) {
        end = i;
        break;
      }
    }
    if (start == -1 || end - start < 2) return;

    const int maxScan = 512;
    const int maxPulls = 8;
    int watermark = start;

    for (int i = start; i < end - 1; i++) {
      final p = list[i];
      if (p.hasSortGroup) continue;

      final limit = math.min(end, i + maxScan);
      int pullIdx = -1;
      for (int j = i + 1; j < limit; j++) {
        final q = list[j];
        if (q.hasSortGroup) continue;

        // Every element at index > watermark remains strictly sorted by maxZ DESC,
        // so once q.maxZ <= p.minZ no remaining polygon can overlap p in depth.
        if (q.maxZ <= p.minZ) {
          if (j > watermark) break;
          continue;
        }
        // Fast 2D screen AABB reject (>98% of pairs skip in 4 float compares)
        if (p.maxX <= q.minX || p.minX >= q.maxX || p.maxY <= q.minY || p.minY >= q.maxY) {
          continue;
        }
        if (q.pulls >= maxPulls || q.lastPulledBefore == p.id) continue;

        // Exact 2D convex polygon Separating Axis Test (ignores edge-only neighbors)
        if (!_polysOverlap2D(p.points, q.points)) continue;

        final pInFrontOfQ = q.minZ >= p.maxZ ||
            isWorldPolyInFront(
              aVerts: p.worldVerts,
              aNormal: p.planeNormal,
              aD: p.planeD,
              bVerts: q.worldVerts,
              bNormal: q.planeNormal,
              bD: q.planeD,
            );
        if (pInFrontOfQ) {
          pullIdx = j;
          break;
        }
      }

      if (pullIdx != -1) {
        final q = list[pullIdx];
        q.pulls++;
        q.lastPulledBefore = p.id;
        if (pullIdx > watermark) watermark = pullIdx;
        for (int k = pullIdx; k > i; k--) {
          list[k] = list[k - 1];
        }
        list[i] = q;
        i--; // Re-evaluate the newly pulled polygon at index i
      }
    }
  }

  /// Zero-allocation 2D convex polygon Separating Axis Test (SAT).
  /// Returns `false` for disjoint polygons AND polygons that only touch along a shared edge.
  static bool _polysOverlap2D(List<Offset> a, List<Offset> b) {
    if (_hasSeparatingAxis2D(a, b)) return false;
    if (_hasSeparatingAxis2D(b, a)) return false;
    return true;
  }

  static bool _hasSeparatingAxis2D(List<Offset> poly, List<Offset> other) {
    final n = poly.length;
    for (int i = 0; i < n; i++) {
      final p0 = poly[i];
      final p1 = poly[(i + 1) % n];
      final nx = -(p1.dy - p0.dy);
      final ny = p1.dx - p0.dx;
      final lenSq = nx * nx + ny * ny;
      if (lenSq < 1e-6) continue;

      double minA = double.infinity;
      double maxA = double.negativeInfinity;
      for (final p in poly) {
        final d = p.dx * nx + p.dy * ny;
        if (d < minA) minA = d;
        if (d > maxA) maxA = d;
      }

      double minB = double.infinity;
      double maxB = double.negativeInfinity;
      for (final p in other) {
        final d = p.dx * nx + p.dy * ny;
        if (d < minB) minB = d;
        if (d > maxB) maxB = d;
      }

      // Tiny 0.05px tolerance prevents shared-edge adjacent box/wall faces from triggering swaps.
      final edgeEps = 0.05 * math.sqrt(lenSq);
      if (maxA <= minB + edgeEps || maxB <= minA + edgeEps) {
        return true;
      }
    }
    return false;
  }

  /// Exact 3D Newell plane-side test: returns true when polygon [aVerts] lies strictly on the
  /// camera side of [bVerts]'s plane OR [bVerts] lies strictly behind [aVerts]'s plane.
  /// Both [aNormal] and [bNormal] must be oriented toward the camera eye.
  static bool isWorldPolyInFront({
    required List<Vec3> aVerts,
    required Vec3 aNormal,
    required double aD,
    required List<Vec3> bVerts,
    required Vec3 bNormal,
    required double bD,
  }) {
    const eps = 0.002;

    // 1. Test A's vertices against B's plane (positive = camera side = in front of B)
    double minA = double.infinity;
    double maxA = double.negativeInfinity;
    for (final v in aVerts) {
      final s = bNormal.x * v.x + bNormal.y * v.y + bNormal.z * v.z - bD;
      if (s < minA) minA = s;
      if (s > maxA) maxA = s;
    }
    if (minA >= -eps && maxA > eps) return true;
    if (maxA <= eps && minA < -eps) return false;

    // 2. Test B's vertices against A's plane (negative = behind A => A is in front of B)
    double minB = double.infinity;
    double maxB = double.negativeInfinity;
    for (final v in bVerts) {
      final s = aNormal.x * v.x + aNormal.y * v.y + aNormal.z * v.z - aD;
      if (s < minB) minB = s;
      if (s > maxB) maxB = s;
    }
    if (maxB <= eps && minB < -eps) return true;
    if (minB >= -eps && maxB > eps) return false;

    return false;
  }

  /// Fast projection with near-plane Sutherland-Hodgman polygon clipping so large
  /// foreground road & terrain quads never vanish abruptly when zooming in.
  static (List<Offset>, double, double, double)? _projectAndClipPoly(
    List<Vec3> worldVerts,
    CameraFrame frame,
  ) {
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
      double minZ = double.infinity;
      double maxZ = double.negativeInfinity;
      for (final v in worldVerts) {
        final p = frame.project(v);
        pts.add(p.offset);
        sumDepth += p.depth;
        if (p.depth < minZ) minZ = p.depth;
        if (p.depth > maxZ) maxZ = p.depth;
      }
      return (pts, sumDepth / pts.length, minZ, maxZ);
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
    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;
    for (final c in clipped) {
      final invZ = frame.focalLength / c.z;
      pts.add(Offset(frame.halfWidth + c.x * invZ, frame.halfHeight - c.y * invZ));
      sumDepth += c.z;
      if (c.z < minZ) minZ = c.z;
      if (c.z > maxZ) maxZ = c.z;
    }
    return (pts, sumDepth / pts.length, minZ, maxZ);
  }

  static bool _pointInPoly2D(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final pi = poly[i];
      final pj = poly[j];
      final intersect = ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
          (p.dx < (pj.dx - pi.dx) * (p.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static void _paintPerspectiveSigns(
    Canvas canvas,
    CameraFrame frame,
    DesertLighting lighting,
    List<SignText3D> signs,
    List<_RenderPoly> renderList,
  ) {
    final nightStrength = (lighting.nightFactor * 0.95 + lighting.sunsetFactor * 0.4).clamp(0.0, 1.0);
    final nightBucket = (nightStrength * 12).round();
    final worldLayer = RenderLayer.world.index;

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
      if (signW < 10 || signH < 4 || signW > 900 || signH > 450) continue;

      // Occlusion check: hide sign text cleanly when a closer 3D wall/roof/umbrella blocks it.
      final centerWorld = (sign.topRight + sign.bottomLeft) * 0.5;
      final centerProj = frame.project(centerWorld);
      if (!centerProj.inFront) continue;
      bool occluded = false;
      final sp = centerProj.offset;
      final occludeZ = centerProj.depth - 0.14;
      for (int i = renderList.length - 1; i >= 0; i--) {
        final rp = renderList[i];
        if (rp.layerIndex != worldLayer) continue;
        if (rp.maxZ >= occludeZ) continue;
        if (sp.dx < rp.minX || sp.dx > rp.maxX || sp.dy < rp.minY || sp.dy > rp.maxY) {
          continue;
        }
        if (_pointInPoly2D(sp, rp.points)) {
          occluded = true;
          break;
        }
      }
      if (occluded) continue;

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

/// Main Desert Outpost CustomPainter with two-tier static geometry caching:
/// - `_backdropCache`: terrain, Route 163 highway, distant mesas & telephone line (rebuilds only on shadow bucket)
/// - `_outpostStaticCache`: roads, parking lots, cleared flora & static buildings (rebuilds on player edits)
class DesertOutpostPainter extends CustomPainter {
  DesertOutpostPainter({
    required this.controller,
  }) : super(repaint: controller.renderListenable);

  final GameController controller;

  final MeshBuilder _backdropCache = MeshBuilder();
  int _cachedBackdropBucket = -1;

  final MeshBuilder _outpostStaticCache = MeshBuilder();
  int _cachedOutpostSignature = -1;

  final MeshBuilder _frameMesh = MeshBuilder();

  @override
  void paint(Canvas canvas, Size size) {
    final camera = controller.camera;
    final lighting = controller.lighting;
    final animTime = controller.animTime;

    // Single CameraFrame shared across sky dome, 3D mesh, routes, particles & cash popups!
    final frame = camera.createFrame(size);

    SceneRenderer3D.paintSkyDome(canvas, size, camera, lighting, animTime, frame: frame);

    final shadowBucket = (lighting.timeOfDay * 48).floor();
    if (shadowBucket != _cachedBackdropBucket) {
      _cachedBackdropBucket = shadowBucket;
      _backdropCache.clear();
      EnvironmentBuilder.buildBackdrop(_backdropCache, lighting);
    }

    final outpostSig = Object.hash(
      controller.decorations.length,
      controller.staticBuildingsSignature,
      shadowBucket,
    );

    if (outpostSig != _cachedOutpostSignature) {
      _cachedOutpostSignature = outpostSig;
      _outpostStaticCache.clear();
      EnvironmentBuilder.buildOutpostStatic(
        _outpostStaticCache,
        lighting,
        roadNetwork: controller.roadNetwork,
        parkingLots: controller.parkingLots,
        worldGrid: controller.worldGrid,
        toolMode: controller.toolMode,
        outpostStage: controller.outpostStage,
        maxParcels: controller.stageInfo.maxParcels,
        isOccupied: controller.isWorldPointOccupied,
      );
      for (final deco in controller.decorations) {
        if (!EntityModels.isAnimatedDecoration(deco)) {
          EntityModels.buildDecoration(_outpostStaticCache, deco, lighting, 0.0);
        }
      }
      for (final plot in controller.visiblePlots) {
        if (BuildingModels.isStaticPlot(plot, isSelected: controller.selectedPlotId == plot.id)) {
          BuildingModels.buildPlot(
            _outpostStaticCache,
            plot,
            lighting,
            0.0,
            isSelected: false,
          );
        }
      }
    }

    _frameMesh.clear();
    _frameMesh.appendFrom(_backdropCache);
    _frameMesh.appendFrom(_outpostStaticCache);

    // Dynamic ambient environment (clouds, swaying sagebrush, tumbleweeds)
    EnvironmentBuilder.buildDynamic(
      _frameMesh,
      lighting,
      animTime,
      isOccupied: controller.isWorldPointOccupied,
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

    // Live 3D placement ghost & road line preview while a build tool is active
    _appendPlacementGhost(_frameMesh, lighting, animTime);
    _appendRoadLinePreview(_frameMesh, animTime);

    for (final vehicle in controller.vehicles) {
      EntityModels.buildVehicle(_frameMesh, vehicle, lighting);
    }
    for (final visitor in controller.visitors) {
      EntityModels.buildVisitor(_frameMesh, visitor, lighting);
    }

    SceneRenderer3D.paintMesh(canvas, size, camera, lighting, _frameMesh, frame: frame);

    _paintRoutePreview(canvas, frame);
    _paintParticles(canvas, frame, controller.particles);
    _paintFloatingCash(canvas, frame, controller.floatingCash);
  }

  void _appendPlacementGhost(
    MeshBuilder mesh,
    DesertLighting lighting,
    double animTime,
  ) {
    final valid = controller.isGhostPlacementValid;
    final padFill = valid
        ? const Color(0x664CA85E)
        : const Color(0x77D94B38);
    final padOutline = valid
        ? const Color(0xFF9BFF9F)
        : const Color(0xFFFF8F80);

    if (controller.toolMode == WorldToolMode.placeBuilding &&
        controller.pendingBuildingType != null) {
      final type = controller.pendingBuildingType!;
      final data = kBusinessCatalog[type]!;
      final rot = controller.ghostRotation;
      final (w, d) = OutpostLayout.rotatedSize(data.gridW, data.gridD, rot);
      final center = OutpostLayout.footprintCenter(
        controller.ghostGridX,
        controller.ghostGridZ,
        w,
        d,
      );
      final yaw = OutpostLayout.yawForQuarterTurn(rot);
      final hoverY = 0.08 + math.sin(animTime * 4.5).abs() * 0.10;

      // Ground validity pad
      mesh.addGroundRect(
        center.x,
        0.045,
        center.z,
        w * OutpostLayout.gridCellSize - 0.08,
        d * OutpostLayout.gridCellSize - 0.08,
        padFill,
        layer: RenderLayer.groundDecal,
        depthBias: -0.25,
        unlit: true,
        outlineColor: padOutline,
      );

      // Front entrance directional chevron arrow showing which way the store faces
      final (fdx, fdz) = OutpostLayout.forwardStepForQuarterTurn(rot);
      final frontDist = (fdx != 0 ? w : d) * OutpostLayout.gridCellSize * 0.5 + 0.55;
      final arrowCenter = Vec3(
        center.x + fdx * frontDist,
        0.06,
        center.z + fdz * frontDist,
      );
      mesh.withTransform(arrowCenter, yaw, () {
        mesh.addTri(
          const Vec3(-0.48, 0.0, -0.24),
          const Vec3(0.0, 0.0, 0.44),
          const Vec3(0.48, 0.0, -0.24),
          valid ? DesertPalette.gold : const Color(0xFFFF7A66),
          layer: RenderLayer.groundDecal,
          depthBias: -0.30,
          unlit: true,
        );
      });

      final lv = controller.relocatingPlot?.level ?? 1;
      mesh.withTransform(center + Vec3(0, hoverY, 0), yaw, () {
        BuildingModels.buildByType(
          mesh,
          type,
          Vec3.zero,
          lv,
          lighting,
          const Color(0x00000000),
          animTime,
        );
      });
    } else if (controller.toolMode == WorldToolMode.placeDecoration &&
        controller.pendingDecoration != null) {
      final center = OutpostLayout.cellCenter(controller.ghostGridX, controller.ghostGridZ);
      mesh.addGroundRect(
        center.x,
        0.05,
        center.z,
        OutpostLayout.gridCellSize - 0.08,
        OutpostLayout.gridCellSize - 0.08,
        padFill,
        layer: RenderLayer.groundDecal,
        depthBias: -0.26,
        unlit: true,
        outlineColor: padOutline,
      );
      EntityModels.buildDecoration(
        mesh,
        PlacedDecoration(
          id: 'ghost_deco',
          kind: controller.pendingDecoration!.$1,
          position: center,
          name: '',
          cost: 0,
        ),
        lighting,
        animTime,
      );
    } else if (controller.toolMode == WorldToolMode.placeParking &&
        controller.pendingParkingKind != null) {
      final kind = controller.pendingParkingKind!;
      final lot = ParkingLotEntity(
        id: 'ghost_lot',
        kind: kind,
        gridX: controller.ghostGridX,
        gridZ: controller.ghostGridZ,
        rotationQuarter: controller.ghostRotation,
      );
      HighwayAndParking.buildParkingLot(
        mesh,
        lot,
        lighting: lighting,
        tintOverride: valid ? null : const Color(0xBBD94B38),
      );
      final (w, d) = lot.sizeCells;
      mesh.addGroundRect(
        lot.position.x,
        0.05,
        lot.position.z,
        w * OutpostLayout.gridCellSize,
        d * OutpostLayout.gridCellSize,
        padFill,
        layer: RenderLayer.groundDecal,
        depthBias: -0.26,
        unlit: true,
        outlineColor: padOutline,
      );

      // Entry-side chevron arrow showing which edge faces the road
      final (_, depth) = lot.orientedWorldDimensions;
      final entryArrowPos = lot.position - lot.pullInDir * (depth * 0.5 + 0.50);
      final entryYaw = math.atan2(lot.pullInDir.x, lot.pullInDir.z);
      mesh.withTransform(Vec3(entryArrowPos.x, 0.06, entryArrowPos.z), entryYaw, () {
        mesh.addTri(
          const Vec3(-0.48, 0.0, -0.24),
          const Vec3(0.0, 0.0, 0.44),
          const Vec3(0.48, 0.0, -0.24),
          valid ? DesertPalette.gold : const Color(0xFFFF7A66),
          layer: RenderLayer.groundDecal,
          depthBias: -0.30,
          unlit: true,
        );
      });
    }
  }

  void _appendRoadLinePreview(MeshBuilder mesh, double animTime) {
    if (controller.toolMode != WorldToolMode.paintRoad) return;
    const cs = OutpostLayout.gridCellSize;
    final start = controller.roadLineStart;
    if (start == null) return;
    final preview = controller.roadLinePreview;
    final pulse = 0.75 + 0.25 * math.sin(animTime * 6.0);
    final erase = controller.roadEraseMode;

    void cell(GridCell c, Color fill, Color outline) {
      final w = c.worldCenter;
      mesh.addGroundRect(
        w.x,
        0.06,
        w.z,
        cs - 0.16,
        cs - 0.16,
        fill,
        layer: RenderLayer.groundDecal,
        depthBias: -0.35,
        unlit: true,
        outlineColor: outline,
      );
    }

    if (preview.cells.isEmpty) {
      cell(start, Color.fromRGBO(242, 193, 78, 0.45 * pulse), const Color(0xFFF2C14E));
      return;
    }
    final ok = preview.isValid;
    for (final c in preview.buildCells) {
      cell(
        c,
        erase
            ? Color.fromRGBO(217, 75, 56, 0.45 * pulse)
            : (ok
                ? Color.fromRGBO(76, 168, 94, 0.48 * pulse)
                : Color.fromRGBO(242, 160, 60, 0.42 * pulse)),
        erase ? const Color(0xFFFF8F80) : (ok ? const Color(0xFF9BFF9F) : const Color(0xFFFFC27A)),
      );
    }
    for (final c in preview.skipCells) {
      cell(c, const Color(0x22FFFFFF), const Color(0x66FFFFFF));
    }
    for (final c in preview.blockedCells) {
      cell(c, Color.fromRGBO(217, 75, 56, 0.55 * pulse), const Color(0xFFFF6B5A));
    }
  }

  void _paintRoutePreview(Canvas canvas, CameraFrame frame) {
    if (controller.toolMode != WorldToolMode.placeBuilding) return;
    final access = controller.ghostAccessPreview;
    if (access.routePreview.length < 2) return;

    final path = Path();
    bool started = false;
    for (final pt in access.routePreview) {
      final proj = frame.project(pt + const Vec3(0, 0.16, 0));
      if (!proj.inFront) continue;
      if (!started) {
        path.moveTo(proj.offset.dx, proj.offset.dy);
        started = true;
      } else {
        path.lineTo(proj.offset.dx, proj.offset.dy);
      }
    }
    if (!started) return;

    final routeCol = access.isGreat
        ? const Color(0xFF6EF594)
        : (access.isPoor ? const Color(0xFFFFB24A) : const Color(0xFF68E8DE));
    final glowPaint = Paint()
      ..color = routeCol.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePaint = Paint()
      ..color = routeCol
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
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
