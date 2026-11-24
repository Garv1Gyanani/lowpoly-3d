import 'dart:math' as math;
import 'dart:ui';

import '../theme/desert_palette.dart';
import 'vec3.dart';

/// Render layers ensuring the single continuous 3D terrain always lies underneath
/// decals, shadows, and all 3D world geometry (including distant mesas & buildings).
enum RenderLayer {
  terrain, // 0: single continuous sculpted 3D low-poly desert terrain
  groundDecal, // 1: asphalt highway, parking apron, walkways, plot pads
  shadow, // 2: contact ambient occlusion & projected ground shadows
  world, // 3: ALL 3D objects — Monument Valley mesas, buildings, props, wires, cars, visitors
  skyCloud, // 4: luminous 3D desert clouds
}

/// A single flat-shaded 3D low-poly face.
class Poly3D {
  Poly3D({
    required this.vertices,
    required this.normal,
    required this.color,
    this.emissiveColor,
    this.emissiveStrength = 0.0,
    this.emissiveNightOnly = true,
    this.layer = RenderLayer.world,
    this.depthBias = 0.0,
    this.doubleSided = false,
    this.unlit = false,
    this.isCloud = false,
    this.distanceFade = 0.0,
    this.outlineColor,
    this.sortGroupAnchor,
    this.subOrder = 0,
  }) : centroid = _computeCentroid(vertices),
       radius = _computeRadius(vertices);

  final List<Vec3> vertices;
  final Vec3 normal;
  final Color color;
  final Color? emissiveColor;
  final double emissiveStrength;
  final bool emissiveNightOnly;
  final RenderLayer layer;
  final double depthBias;
  final bool doubleSided;
  final bool unlit;
  final bool isCloud;
  final double distanceFade;
  final Color? outlineColor;
  final Vec3 centroid;

  /// Bounding-sphere radius around [centroid] used for fast frustum culling.
  final double radius;
  final Vec3? sortGroupAnchor;
  final int subOrder;

  static double _computeRadius(List<Vec3> verts) {
    final c = _computeCentroid(verts);
    double maxSq = 0.0;
    for (final v in verts) {
      final dx = v.x - c.x;
      final dy = v.y - c.y;
      final dz = v.z - c.z;
      final d = dx * dx + dy * dy + dz * dz;
      if (d > maxSq) maxSq = d;
    }
    return math.sqrt(maxSq);
  }

  static Vec3 _computeCentroid(List<Vec3> verts) {
    double x = 0, y = 0, z = 0;
    for (final v in verts) {
      x += v.x;
      y += v.y;
      z += v.z;
    }
    final inv = 1.0 / verts.length;
    return Vec3(x * inv, y * inv, z * inv);
  }
}

/// A 3D line segment (fallback handrails / crisp accents).
class Line3D {
  const Line3D({
    required this.start,
    required this.end,
    required this.color,
    this.width = 1.2,
  });

  final Vec3 start;
  final Vec3 end;
  final Color color;
  final double width;
}

/// A 3D point that radiates soft light at night (lamps, neon signs, campfire, headlights).
class GlowLight3D {
  const GlowLight3D({
    required this.position,
    required this.color,
    this.radius = 28.0,
    this.intensity = 0.75,
    this.nightOnly = true,
  });

  final Vec3 position;
  final Color color;
  final double radius;
  final double intensity;
  final bool nightOnly;
}

/// A 3D signboard text anchored strictly to a 3D rectangular sign face.
class SignText3D {
  const SignText3D({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.text,
    required this.color,
    this.glowColor,
    this.nightGlow = true,
  });

  final Vec3 topLeft;
  final Vec3 topRight;
  final Vec3 bottomLeft;
  final String text;
  final Color color;
  final Color? glowColor;
  final bool nightGlow;
}

/// Accumulates low-poly 3D faces, contact shadows, 3D wires, glows, and 3D-aligned signs.
class MeshBuilder {
  final List<Poly3D> polys = <Poly3D>[];
  final List<Line3D> lines = <Line3D>[];
  final List<GlowLight3D> glows = <GlowLight3D>[];
  final List<SignText3D> signs = <SignText3D>[];

  Vec3 _origin = Vec3.zero;
  double _rotY = 0.0;
  double _scaleXZ = 1.0;
  double _scaleY = 1.0;
  Vec3? _sortGroupAnchor;
  int _subOrder = 0;

  void clear() {
    polys.clear();
    lines.clear();
    glows.clear();
    signs.clear();
  }

  /// Appends prebuilt static geometry without copying vertex arrays.
  void appendFrom(MeshBuilder other) {
    polys.addAll(other.polys);
    lines.addAll(other.lines);
    glows.addAll(other.glows);
    signs.addAll(other.signs);
  }

  void withTransform(Vec3 origin, double rotY, void Function() build) {
    final prevOrigin = _origin;
    final prevRot = _rotY;
    final scaledLocal = Vec3(origin.x * _scaleXZ, origin.y * _scaleY, origin.z * _scaleXZ);
    _origin = prevOrigin + scaledLocal.rotateY(prevRot);
    _rotY = prevRot + rotY;
    build();
    _origin = prevOrigin;
    _rotY = prevRot;
  }

  /// Applies grounded squash-and-stretch scaling around the current origin (`y = 0` stays planted!).
  void withScale(double scaleXZ, double scaleY, void Function() build) {
    final prevXZ = _scaleXZ;
    final prevY = _scaleY;
    _scaleXZ = prevXZ * scaleXZ;
    _scaleY = prevY * scaleY;
    build();
    _scaleXZ = prevXZ;
    _scaleY = prevY;
  }

  /// Groups all faces emitted inside [build] under a single world-space depth anchor
  /// so moving/rotating entities NEVER pop or z-fight internally.
  void withSortGroup(Vec3 worldAnchor, void Function() build) {
    final prevAnchor = _sortGroupAnchor;
    final prevSub = _subOrder;
    _sortGroupAnchor = worldAnchor;
    _subOrder = 0;
    build();
    _sortGroupAnchor = prevAnchor;
    _subOrder = prevSub;
  }

  /// Sets the internal draw layer priority inside an active [withSortGroup] block.
  void withSubOrder(int subOrder, void Function() build) {
    final prevSub = _subOrder;
    _subOrder = subOrder;
    build();
    _subOrder = prevSub;
  }

  Vec3 _tx(Vec3 local) {
    final scaled = Vec3(local.x * _scaleXZ, local.y * _scaleY, local.z * _scaleXZ);
    return _origin + scaled.rotateY(_rotY);
  }

  Vec3 _txNormal(Vec3 localN) => localN.rotateY(_rotY).normalized();

  /// Adds a quad face (vertices wound CCW when viewed from outside).
  void addQuad(
    Vec3 a,
    Vec3 b,
    Vec3 c,
    Vec3 d,
    Color color, {
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    RenderLayer layer = RenderLayer.world,
    double depthBias = 0.0,
    bool doubleSided = false,
    bool unlit = false,
    bool isCloud = false,
    double distanceFade = 0.0,
    Color? outlineColor,
    int? subOrder,
  }) {
    final wa = _tx(a);
    final wb = _tx(b);
    final wc = _tx(c);
    final wd = _tx(d);
    final n = (wb - wa).cross(wc - wa).normalized();
    polys.add(
      Poly3D(
        vertices: [wa, wb, wc, wd],
        normal: n,
        color: color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        layer: layer,
        depthBias: depthBias,
        doubleSided: doubleSided,
        unlit: unlit,
        isCloud: isCloud,
        distanceFade: distanceFade,
        outlineColor: outlineColor,
        sortGroupAnchor: layer == RenderLayer.world ? _sortGroupAnchor : null,
        subOrder: subOrder ?? _subOrder,
      ),
    );
  }

  /// Adds a triangle face (CCW outward).
  void addTri(
    Vec3 a,
    Vec3 b,
    Vec3 c,
    Color color, {
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    RenderLayer layer = RenderLayer.world,
    double depthBias = 0.0,
    bool doubleSided = false,
    bool unlit = false,
    bool isCloud = false,
    double distanceFade = 0.0,
    int? subOrder,
  }) {
    final wa = _tx(a);
    final wb = _tx(b);
    final wc = _tx(c);
    final n = (wb - wa).cross(wc - wa).normalized();
    polys.add(
      Poly3D(
        vertices: [wa, wb, wc],
        normal: n,
        color: color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        layer: layer,
        depthBias: depthBias,
        doubleSided: doubleSided,
        unlit: unlit,
        isCloud: isCloud,
        distanceFade: distanceFade,
        sortGroupAnchor: layer == RenderLayer.world ? _sortGroupAnchor : null,
        subOrder: subOrder ?? _subOrder,
      ),
    );
  }

  /// Adds a flat polygon on the ground (facing +Y).
  void addGroundPoly(
    List<Vec3> localVerts,
    Color color, {
    RenderLayer layer = RenderLayer.groundDecal,
    double depthBias = 0.0,
    bool unlit = false,
    double distanceFade = 0.0,
    Color? outlineColor,
  }) {
    final worldVerts = localVerts.map(_tx).toList(growable: false);
    polys.add(
      Poly3D(
        vertices: worldVerts,
        normal: Vec3.up,
        color: color,
        layer: layer,
        depthBias: depthBias,
        unlit: unlit,
        distanceFade: distanceFade,
        outlineColor: outlineColor,
      ),
    );
  }

  /// Adds a rectangular ground decal centered at (cx, y, cz).
  void addGroundRect(
    double cx,
    double y,
    double cz,
    double w,
    double d,
    Color color, {
    RenderLayer layer = RenderLayer.groundDecal,
    double depthBias = 0.0,
    bool unlit = false,
    Color? outlineColor,
  }) {
    final hw = w * 0.5;
    final hd = d * 0.5;
    addGroundPoly(
      [
        Vec3(cx - hw, y, cz - hd),
        Vec3(cx - hw, y, cz + hd),
        Vec3(cx + hw, y, cz + hd),
        Vec3(cx + hw, y, cz - hd),
      ],
      color,
      layer: layer,
      depthBias: depthBias,
      unlit: unlit,
      outlineColor: outlineColor,
    );
  }

  /// Adds a grounded two-stage shadow: a tight ambient-occlusion contact ring right under
  /// the base plus a directional cast shadow so buildings & props look firmly planted!
  void addBoxShadow(
    double cx,
    double cz,
    double w,
    double d,
    double height,
    Vec3 shadowDir,
    Color shadowColor, {
    double groundY = 0.02,
  }) {
    // 1. Tight base ambient-occlusion contact pad directly beneath footprint
    final chw = w * 0.53;
    final chd = d * 0.53;
    final contactAlpha = (shadowColor.a * 1.25).clamp(0.10, 0.42);
    final contactCol = Color.from(
      alpha: contactAlpha,
      red: DesertPalette.shadowContact.r,
      green: DesertPalette.shadowContact.g,
      blue: DesertPalette.shadowContact.b,
    );
    addGroundPoly(
      [
        Vec3(cx - chw, groundY, cz - chd),
        Vec3(cx - chw, groundY, cz + chd),
        Vec3(cx + chw, groundY, cz + chd),
        Vec3(cx + chw, groundY, cz - chd),
      ],
      contactCol,
      layer: RenderLayer.shadow,
      depthBias: -0.02,
      unlit: true,
    );

    // 2. Soft directional cast shadow
    final hw = w * 0.50;
    final hd = d * 0.50;
    final ox = shadowDir.x * height * 0.38;
    final oz = shadowDir.z * height * 0.38;
    addGroundPoly(
      [
        Vec3(cx - hw + ox, groundY, cz - hd + oz),
        Vec3(cx - hw + ox, groundY, cz + hd + oz),
        Vec3(cx + hw + ox, groundY, cz + hd + oz),
        Vec3(cx + hw + ox, groundY, cz - hd + oz),
      ],
      shadowColor,
      layer: RenderLayer.shadow,
      unlit: true,
    );
  }

  /// Adds a faceted octagonal ground contact + cast shadow under organic rocks, bushes, cacti & outcrops.
  void addDiscShadow(
    double cx,
    double groundY,
    double cz,
    double rx,
    double rz,
    double height,
    Vec3 shadowDir,
    Color shadowColor, {
    int sides = 6,
  }) {
    final y = groundY + 0.022;
    final ox = shadowDir.x * height * 0.32;
    final oz = shadowDir.z * height * 0.32;
    final contactVerts = <Vec3>[];
    final castVerts = <Vec3>[];
    for (int i = 0; i < sides; i++) {
      // Counter-clockwise on XZ ground plane so normal faces +Y
      final a = -(i / sides) * math.pi * 2.0;
      final ca = math.cos(a);
      final sa = math.sin(a);
      contactVerts.add(Vec3(cx + ca * rx * 1.04, y, cz + sa * rz * 1.04));
      castVerts.add(Vec3(cx + ox + ca * rx * 0.96, y, cz + oz + sa * rz * 0.96));
    }
    final contactCol = Color.from(
      alpha: (shadowColor.a * 1.28).clamp(0.12, 0.42),
      red: DesertPalette.shadowContact.r,
      green: DesertPalette.shadowContact.g,
      blue: DesertPalette.shadowContact.b,
    );
    addGroundPoly(castVerts, shadowColor, layer: RenderLayer.shadow, unlit: true);
    addGroundPoly(
      contactVerts,
      contactCol,
      layer: RenderLayer.shadow,
      depthBias: -0.02,
      unlit: true,
    );
  }

  /// Adds a 3D depth-sorted catenary wire ribbon (telephone wires, festoon string lights)
  /// that batches inside `Canvas.drawVertices` and naturally occludes behind taller objects.
  void addSaggingWire(
    Vec3 start,
    Vec3 end,
    Color color, {
    double sag = 0.28,
    double thickness = 0.036,
    int segments = 5,
    int bulbCount = 0,
    Color? bulbGlowColor,
  }) {
    for (int s = 0; s < segments; s++) {
      final t0 = s / segments;
      final t1 = (s + 1) / segments;
      final p0 = start.lerp(end, t0) - Vec3(0, math.sin(t0 * math.pi) * sag, 0);
      final p1 = start.lerp(end, t1) - Vec3(0, math.sin(t1 * math.pi) * sag, 0);
      addQuad(
        p0,
        p1,
        p1 - Vec3(0, thickness, 0),
        p0 - Vec3(0, thickness, 0),
        color,
        doubleSided: true,
        unlit: true,
      );
    }

    if (bulbCount > 0 && bulbGlowColor != null) {
      for (int b = 1; b <= bulbCount; b++) {
        final tb = b / (bulbCount + 1);
        final bp = start.lerp(end, tb) - Vec3(0, math.sin(tb * math.pi) * sag + 0.07, 0);
        addBox(
          bp.x,
          bp.y,
          bp.z,
          0.09,
          0.10,
          0.09,
          DesertPalette.cream,
          emissiveColor: bulbGlowColor,
          emissiveStrength: 1.0,
          depthBias: -0.15,
        );
      }
    }
  }

  /// Subdivides large world-layer quads (`> 0.90u`) into flat-shaded sub-quads so
  /// wide tabletops, walls & roofs sort cleanly against nearby props at every 360° angle.
  void _addBoxFace(
    Vec3 a,
    Vec3 b,
    Vec3 c,
    Vec3 d,
    Color color, {
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    RenderLayer layer = RenderLayer.world,
    double depthBias = 0.0,
    double distanceFade = 0.0,
    int? subOrder,
  }) {
    final allowSubdiv = layer == RenderLayer.world &&
        distanceFade == 0.0 &&
        _sortGroupAnchor == null;
    if (!allowSubdiv) {
      addQuad(
        a,
        b,
        c,
        d,
        color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        layer: layer,
        depthBias: depthBias,
        distanceFade: distanceFade,
        subOrder: subOrder,
      );
      return;
    }

    final lenU = (b - a).length;
    final lenV = (d - a).length;
    final nu = lenU > 0.95 ? (lenU / 0.90).ceil().clamp(1, 4) : 1;
    final nv = lenV > 0.95 ? (lenV / 0.90).ceil().clamp(1, 4) : 1;

    if (nu == 1 && nv == 1) {
      addQuad(
        a,
        b,
        c,
        d,
        color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        layer: layer,
        depthBias: depthBias,
        distanceFade: distanceFade,
        subOrder: subOrder,
      );
      return;
    }

    Vec3 sample(double u, double v) {
      final top = a.lerp(b, u);
      final bot = d.lerp(c, u);
      return top.lerp(bot, v);
    }

    for (int iu = 0; iu < nu; iu++) {
      final u0 = iu / nu;
      final u1 = (iu + 1) / nu;
      for (int iv = 0; iv < nv; iv++) {
        final v0 = iv / nv;
        final v1 = (iv + 1) / nv;
        addQuad(
          sample(u0, v0),
          sample(u1, v0),
          sample(u1, v1),
          sample(u0, v1),
          color,
          emissiveColor: emissiveColor,
          emissiveStrength: emissiveStrength,
          emissiveNightOnly: emissiveNightOnly,
          layer: layer,
          depthBias: depthBias,
          distanceFade: distanceFade,
          subOrder: subOrder,
        );
      }
    }
  }

  /// Adds a 3D box with bottom center at (cx, yBottom, cz) and size (w, h, d).
  void addBox(
    double cx,
    double yBottom,
    double cz,
    double w,
    double h,
    double d,
    Color color, {
    Color? topColor,
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    RenderLayer layer = RenderLayer.world,
    double depthBias = 0.0,
    double distanceFade = 0.0,
    bool skipBottom = true,
    bool skipTop = false,
    int? subOrder,
  }) {
    final x0 = cx - w * 0.5;
    final x1 = cx + w * 0.5;
    final y0 = yBottom;
    final y1 = yBottom + h;
    final z0 = cz - d * 0.5;
    final z1 = cz + d * 0.5;

    final p000 = Vec3(x0, y0, z0);
    final p100 = Vec3(x1, y0, z0);
    final p101 = Vec3(x1, y0, z1);
    final p001 = Vec3(x0, y0, z1);

    final p010 = Vec3(x0, y1, z0);
    final p110 = Vec3(x1, y1, z0);
    final p111 = Vec3(x1, y1, z1);
    final p011 = Vec3(x0, y1, z1);

    if (!skipTop) {
      _addBoxFace(
        p010,
        p011,
        p111,
        p110,
        topColor ?? color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        layer: layer,
        depthBias: depthBias,
        distanceFade: distanceFade,
        subOrder: subOrder,
      );
    }
    _addBoxFace(
      p001,
      p101,
      p111,
      p011,
      color,
      emissiveColor: emissiveColor,
      emissiveStrength: emissiveStrength,
      emissiveNightOnly: emissiveNightOnly,
      layer: layer,
      depthBias: depthBias,
      distanceFade: distanceFade,
      subOrder: subOrder,
    );
    _addBoxFace(
      p100,
      p000,
      p010,
      p110,
      color,
      emissiveColor: emissiveColor,
      emissiveStrength: emissiveStrength,
      emissiveNightOnly: emissiveNightOnly,
      layer: layer,
      depthBias: depthBias,
      distanceFade: distanceFade,
      subOrder: subOrder,
    );
    _addBoxFace(
      p101,
      p100,
      p110,
      p111,
      color,
      emissiveColor: emissiveColor,
      emissiveStrength: emissiveStrength,
      emissiveNightOnly: emissiveNightOnly,
      layer: layer,
      depthBias: depthBias,
      distanceFade: distanceFade,
      subOrder: subOrder,
    );
    _addBoxFace(
      p000,
      p001,
      p011,
      p010,
      color,
      emissiveColor: emissiveColor,
      emissiveStrength: emissiveStrength,
      emissiveNightOnly: emissiveNightOnly,
      layer: layer,
      depthBias: depthBias,
      distanceFade: distanceFade,
      subOrder: subOrder,
    );

    if (!skipBottom) {
      _addBoxFace(
        p001,
        p000,
        p100,
        p101,
        color,
        layer: layer,
        depthBias: depthBias,
        distanceFade: distanceFade,
        subOrder: subOrder,
      );
    }
  }

  /// Adds a tapered trapezoidal 3D prism (for sloped cabins, Googie roofs & RV cab-over noses).
  void addTaperedBox({
    required double cx,
    required double yBottom,
    required double cz,
    required double bottomLen,
    required double bottomWid,
    required double topLen,
    required double topWid,
    required double height,
    double topShiftX = 0.0,
    double topShiftZ = 0.0,
    required Color color,
    Color? topColor,
    int? subOrder,
  }) {
    final bx0 = cx - bottomLen * 0.5;
    final bx1 = cx + bottomLen * 0.5;
    final bz0 = cz - bottomWid * 0.5;
    final bz1 = cz + bottomWid * 0.5;

    final tx0 = cx + topShiftX - topLen * 0.5;
    final tx1 = cx + topShiftX + topLen * 0.5;
    final tz0 = cz + topShiftZ - topWid * 0.5;
    final tz1 = cz + topShiftZ + topWid * 0.5;
    final y0 = yBottom;
    final y1 = yBottom + height;

    final b00 = Vec3(bx0, y0, bz0);
    final b10 = Vec3(bx1, y0, bz0);
    final b11 = Vec3(bx1, y0, bz1);
    final b01 = Vec3(bx0, y0, bz1);

    final t00 = Vec3(tx0, y1, tz0);
    final t10 = Vec3(tx1, y1, tz0);
    final t11 = Vec3(tx1, y1, tz1);
    final t01 = Vec3(tx0, y1, tz1);

    addQuad(t00, t01, t11, t10, topColor ?? color, subOrder: subOrder);
    addQuad(b11, b10, t10, t11, color, subOrder: subOrder);
    addQuad(b00, b01, t01, t00, color, subOrder: subOrder);
    addQuad(b01, b11, t11, t01, color, subOrder: subOrder);
    addQuad(b10, b00, t00, t10, color, subOrder: subOrder);
  }

  /// Adds flush inset window quads onto all 4 sloped sides of a tapered vehicle cabin.
  void addCabinWindows({
    required double cx,
    required double yBottom,
    required double cz,
    required double bottomLen,
    required double bottomWid,
    required double topLen,
    required double topWid,
    required double height,
    double topShiftX = 0.0,
    required Color glassColor,
    Color? sheenColor,
    double insetBottom = 0.14,
    double insetTop = 0.14,
    double sideInset = 0.14,
    int? subOrder,
  }) {
    Vec3 lerpV(Vec3 a, Vec3 b, double t) => a.lerp(b, t);

    final bx0 = cx - bottomLen * 0.5;
    final bx1 = cx + bottomLen * 0.5;
    final bz0 = cz - bottomWid * 0.5;
    final bz1 = cz + bottomWid * 0.5;
    final tx0 = cx + topShiftX - topLen * 0.5;
    final tx1 = cx + topShiftX + topLen * 0.5;
    final tz0 = cz - topWid * 0.5;
    final tz1 = cz + topWid * 0.5;
    final y0 = yBottom;
    final y1 = yBottom + height;

    final b00 = Vec3(bx0, y0, bz0);
    final b10 = Vec3(bx1, y0, bz0);
    final b11 = Vec3(bx1, y0, bz1);
    final b01 = Vec3(bx0, y0, bz1);
    final t00 = Vec3(tx0, y1, tz0);
    final t10 = Vec3(tx1, y1, tz0);
    final t11 = Vec3(tx1, y1, tz1);
    final t01 = Vec3(tx0, y1, tz1);

    void addFaceWindow(Vec3 p0, Vec3 p1, Vec3 p2, Vec3 p3) {
      final n = (p1 - p0).cross(p2 - p0).normalized();
      final lift = n * 0.014;
      final q0 = lerpV(lerpV(p0, p1, sideInset), lerpV(p3, p2, sideInset), insetBottom) + lift;
      final q1 = lerpV(lerpV(p0, p1, 1.0 - sideInset), lerpV(p3, p2, 1.0 - sideInset), insetBottom) + lift;
      final q2 = lerpV(lerpV(p0, p1, 1.0 - sideInset), lerpV(p3, p2, 1.0 - sideInset), 1.0 - insetTop) + lift;
      final q3 = lerpV(lerpV(p0, p1, sideInset), lerpV(p3, p2, sideInset), 1.0 - insetTop) + lift;
      addQuad(q0, q1, q2, q3, glassColor, subOrder: subOrder);

      if (sheenColor != null) {
        final s0 = lerpV(q0, q1, 0.16) + n * 0.006;
        final s1 = lerpV(q0, q1, 0.34) + n * 0.006;
        final s2 = lerpV(q3, q2, 0.56) + n * 0.006;
        final s3 = lerpV(q3, q2, 0.38) + n * 0.006;
        addQuad(s0, s1, s2, s3, sheenColor, subOrder: (subOrder ?? _subOrder) + 1);
      }
    }

    addFaceWindow(b11, b10, t10, t11);
    addFaceWindow(b00, b01, t01, t00);
    addFaceWindow(b01, b11, t11, t01);
    addFaceWindow(b10, b00, t00, t10);
  }

  /// Adds a flush outward-facing quad on a box wall facing +X or -X.
  void addFlushRectOnX(
    double xWall,
    double cy,
    double cz,
    double widthZ,
    double heightY,
    Color color, {
    required bool positiveX,
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    int? subOrder,
  }) {
    final hz = widthZ * 0.5;
    final hy = heightY * 0.5;
    final x = xWall + (positiveX ? 0.015 : -0.015);
    if (positiveX) {
      addQuad(
        Vec3(x, cy - hy, cz + hz),
        Vec3(x, cy - hy, cz - hz),
        Vec3(x, cy + hy, cz - hz),
        Vec3(x, cy + hy, cz + hz),
        color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        subOrder: subOrder,
      );
    } else {
      addQuad(
        Vec3(x, cy - hy, cz - hz),
        Vec3(x, cy - hy, cz + hz),
        Vec3(x, cy + hy, cz + hz),
        Vec3(x, cy + hy, cz - hz),
        color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        subOrder: subOrder,
      );
    }
  }

  /// Adds a flush outward-facing quad on a wall facing +Z or -Z.
  void addFlushRectOnZ(
    double cx,
    double cy,
    double zWall,
    double widthX,
    double heightY,
    Color color, {
    required bool positiveZ,
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    int? subOrder,
  }) {
    final hx = widthX * 0.5;
    final hy = heightY * 0.5;
    final z = zWall + (positiveZ ? 0.015 : -0.015);
    if (positiveZ) {
      addQuad(
        Vec3(cx - hx, cy - hy, z),
        Vec3(cx + hx, cy - hy, z),
        Vec3(cx + hx, cy + hy, z),
        Vec3(cx - hx, cy + hy, z),
        color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        subOrder: subOrder,
      );
    } else {
      addQuad(
        Vec3(cx + hx, cy - hy, z),
        Vec3(cx - hx, cy - hy, z),
        Vec3(cx - hx, cy + hy, z),
        Vec3(cx + hx, cy + hy, z),
        color,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        subOrder: subOrder,
      );
    }
  }

  /// Adds a low-poly tapered frustum / prism.
  void addFrustum(
    double cx,
    double yBottom,
    double cz,
    double bottomRadiusX,
    double bottomRadiusZ,
    double topRadiusX,
    double topRadiusZ,
    double height,
    int sides,
    Color sideColor, {
    Color? topColor,
    RenderLayer layer = RenderLayer.world,
    double depthBias = 0.0,
    double distanceFade = 0.0,
    double phaseOffset = 0.0,
    double roughness = 0.0,
    int seed = 1,
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    bool isCloud = false,
    int? subOrder,
  }) {
    final bot = <Vec3>[];
    final top = <Vec3>[];
    for (int i = 0; i < sides; i++) {
      final a = phaseOffset + (i / sides) * math.pi * 2.0;
      final jitter = roughness == 0.0
          ? 1.0
          : 1.0 + math.sin(i * 3.17 + seed * 1.93) * roughness;
      final ca = math.cos(a) * jitter;
      final sa = math.sin(a) * jitter;
      bot.add(Vec3(cx + ca * bottomRadiusX, yBottom, cz + sa * bottomRadiusZ));
      top.add(Vec3(cx + ca * topRadiusX, yBottom + height, cz + sa * topRadiusZ));
    }

    for (int i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      addQuad(
        bot[next],
        bot[i],
        top[i],
        top[next],
        sideColor,
        layer: layer,
        depthBias: depthBias,
        distanceFade: distanceFade,
        emissiveColor: emissiveColor,
        emissiveStrength: emissiveStrength,
        emissiveNightOnly: emissiveNightOnly,
        isCloud: isCloud,
        subOrder: subOrder,
      );
    }

    if (topRadiusX > 0.01 && topRadiusZ > 0.01) {
      final worldTop = top.map(_tx).toList(growable: false);
      polys.add(
        Poly3D(
          vertices: worldTop,
          normal: _txNormal(Vec3.up),
          color: topColor ?? sideColor,
          layer: layer,
          depthBias: depthBias,
          distanceFade: distanceFade,
          emissiveColor: emissiveColor,
          emissiveStrength: emissiveStrength,
          emissiveNightOnly: emissiveNightOnly,
          isCloud: isCloud,
          sortGroupAnchor: layer == RenderLayer.world ? _sortGroupAnchor : null,
          subOrder: subOrder ?? _subOrder,
        ),
      );
    }
  }

  /// Adds a pitched triangular gable roof.
  void addGableRoof(
    double cx,
    double yBase,
    double cz,
    double w,
    double h,
    double d,
    Color roofColor,
    Color gableColor, {
    double depthBias = 0.0,
  }) {
    final x0 = cx - w * 0.5;
    final x1 = cx + w * 0.5;
    final z0 = cz - d * 0.5;
    final z1 = cz + d * 0.5;
    final yTop = yBase + h;

    final fl = Vec3(x0, yBase, z1);
    final fr = Vec3(x1, yBase, z1);
    final bl = Vec3(x0, yBase, z0);
    final br = Vec3(x1, yBase, z0);
    final rl = Vec3(x0, yTop, cz);
    final rr = Vec3(x1, yTop, cz);

    addQuad(fl, fr, rr, rl, roofColor, depthBias: depthBias);
    addQuad(br, bl, rl, rr, roofColor, depthBias: depthBias);
    addTri(fr, br, rr, gableColor, depthBias: depthBias);
    addTri(bl, fl, rl, gableColor, depthBias: depthBias);
  }

  /// Adds a sloped striped awning / porch canopy sloping down toward +Z.
  void addSlopedAwning(
    double cx,
    double yBack,
    double yFront,
    double cz,
    double w,
    double d,
    Color color, {
    Color? stripeColor,
    int stripes = 1,
    double depthBias = 0.0,
  }) {
    final x0 = cx - w * 0.5;
    final zBack = cz - d * 0.5;
    final zFront = cz + d * 0.5;
    final sw = w / stripes;

    for (int i = 0; i < stripes; i++) {
      final sx0 = x0 + sw * i;
      final sx1 = sx0 + sw;
      final c = (stripeColor != null && i.isOdd) ? stripeColor : color;
      addQuad(
        Vec3(sx0, yBack, zBack),
        Vec3(sx0, yFront, zFront),
        Vec3(sx1, yFront, zFront),
        Vec3(sx1, yBack, zBack),
        c,
        depthBias: depthBias,
        doubleSided: true,
      );
      addQuad(
        Vec3(sx0, yFront - 0.14, zFront),
        Vec3(sx1, yFront - 0.14, zFront),
        Vec3(sx1, yFront, zFront),
        Vec3(sx0, yFront, zFront),
        c,
        depthBias: depthBias,
        doubleSided: true,
      );
    }
  }

  void addFrontWindow(
    double cx,
    double cy,
    double zWall,
    double w,
    double h,
    Color dayColor,
    Color nightGlow, {
    double depthBias = 0.0,
  }) {
    final hw = w * 0.5;
    final hh = h * 0.5;
    final z = zWall + 0.03;
    addQuad(
      Vec3(cx - hw, cy - hh, z),
      Vec3(cx + hw, cy - hh, z),
      Vec3(cx + hw, cy + hh, z),
      Vec3(cx - hw, cy + hh, z),
      dayColor,
      emissiveColor: nightGlow,
      emissiveStrength: 0.92,
      emissiveNightOnly: true,
      depthBias: depthBias,
    );
  }

  void addRightWindow(
    double xWall,
    double cy,
    double cz,
    double d,
    double h,
    Color dayColor,
    Color nightGlow, {
    double depthBias = 0.0,
  }) {
    final hd = d * 0.5;
    final hh = h * 0.5;
    final x = xWall + 0.03;
    addQuad(
      Vec3(x, cy - hh, cz + hd),
      Vec3(x, cy - hh, cz - hd),
      Vec3(x, cy + hh, cz - hd),
      Vec3(x, cy + hh, cz + hd),
      dayColor,
      emissiveColor: nightGlow,
      emissiveStrength: emissiveStrengthForWindow,
      emissiveNightOnly: true,
      depthBias: depthBias,
    );
  }

  void addLeftWindow(
    double xWall,
    double cy,
    double cz,
    double d,
    double h,
    Color dayColor,
    Color nightGlow, {
    double depthBias = 0.0,
  }) {
    final hd = d * 0.5;
    final hh = h * 0.5;
    final x = xWall - 0.03;
    addQuad(
      Vec3(x, cy - hh, cz - hd),
      Vec3(x, cy - hh, cz + hd),
      Vec3(x, cy + hh, cz + hd),
      Vec3(x, cy + hh, cz - hd),
      dayColor,
      emissiveColor: nightGlow,
      emissiveStrength: emissiveStrengthForWindow,
      emissiveNightOnly: true,
      depthBias: depthBias,
    );
  }

  static const double emissiveStrengthForWindow = 0.92;

  void addLine(
    Vec3 a,
    Vec3 b,
    Color color, {
    double width = 1.2,
  }) {
    lines.add(Line3D(start: _tx(a), end: _tx(b), color: color, width: width));
  }

  void addGlow(
    Vec3 localPos,
    Color color, {
    double radius = 26.0,
    double intensity = 0.72,
    bool nightOnly = true,
  }) {
    glows.add(
      GlowLight3D(
        position: _tx(localPos),
        color: color,
        radius: radius,
        intensity: intensity,
        nightOnly: nightOnly,
      ),
    );
  }

  void addFrontSignText(
    double cx,
    double cy,
    double zFace,
    double width,
    double height,
    String text,
    Color color, {
    Color? glowColor,
    bool nightGlow = true,
  }) {
    final hw = width * 0.45;
    final hh = height * 0.40;
    final z = zFace + 0.05;
    signs.add(
      SignText3D(
        topLeft: _tx(Vec3(cx - hw, cy + hh, z)),
        topRight: _tx(Vec3(cx + hw, cy + hh, z)),
        bottomLeft: _tx(Vec3(cx - hw, cy - hh, z)),
        text: text,
        color: color,
        glowColor: glowColor,
        nightGlow: nightGlow,
      ),
    );
  }
}
