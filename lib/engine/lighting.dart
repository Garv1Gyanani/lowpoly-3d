import 'dart:math' as math;
import 'dart:ui';

import '../theme/desert_palette.dart';
import 'vec3.dart';

/// Computes sky colors, Monument Valley warm-vs-cool facet shading, luminous cloud bounce,
/// plum-tinted ground shadows, and night emissive factors.
class DesertLighting {
  DesertLighting._({
    required this.timeOfDay,
    required this.nightFactor,
    required this.sunsetFactor,
    required this.sunDirection,
    required this.sunColor,
    required this.skyTop,
    required this.skyBottom,
    required this.ambientSky,
    required this.ambientGround,
    required this.coolShadowTint,
    required this.shadowAlpha,
    required this.shadowDirection,
    required this.shadowColor,
    required this.contactShadowColor,
    required this.fogTint,
  });

  /// Normalized cycle in [0.0, 1.0):
  /// 0.00 = midnight, 0.25 = sunrise, 0.50 = midday, 0.75 = sunset.
  final double timeOfDay;

  /// 0.0 during full day, 1.0 during deep night.
  final double nightFactor;

  /// 0.0 away from horizon, 1.0 peak golden/terracotta dusk & dawn.
  final double sunsetFactor;

  /// Normalized vector pointing TOWARD the active light source (sun or moon).
  final Vec3 sunDirection;
  final Color sunColor;
  final Color skyTop;
  final Color skyBottom;
  final Color ambientSky;
  final Color ambientGround;
  final Color coolShadowTint;
  final double shadowAlpha;

  /// Ground-plane XZ vector along which cast shadows stretch.
  final Vec3 shadowDirection;
  final Color shadowColor;
  final Color contactShadowColor;
  final Color fogTint;

  factory DesertLighting.fromTime(double t) {
    final normT = t % 1.0;
    final sunAngle = (normT - 0.25) * math.pi * 2.0;
    final elevation = math.sin(sunAngle); // -1..1
    final azimuth = math.cos(sunAngle);

    final night = _smoothstep(0.20, -0.16, elevation);
    final sunset = math.exp(-math.pow((elevation - 0.04) / 0.22, 2)).clamp(0.0, 1.0);

    final rawSun = Vec3(
      azimuth * 0.74 + 0.24,
      math.max(0.24, elevation.abs() * 0.85 + 0.28),
      0.40,
    ).normalized();

    final moonDir = const Vec3(-0.35, 0.78, 0.52).normalized();
    final activeDir = rawSun.lerp(moonDir, night).normalized();

    // Sky palette blending: Day -> Sunset -> Night
    const dayTop = Color(0xFF72A3BA);
    const dayBottom = Color(0xFFF1D4B3);
    const sunsetTop = Color(0xFF634F76);
    const sunsetBottom = Color(0xFFF08C58);
    const nightTop = Color(0xFF0C182B);
    const nightBottom = Color(0xFF1F3652);

    Color skyTop = Color.lerp(dayTop, sunsetTop, sunset * 0.78)!;
    skyTop = Color.lerp(skyTop, nightTop, night)!;

    Color skyBottom = Color.lerp(dayBottom, sunsetBottom, sunset * 0.88)!;
    skyBottom = Color.lerp(skyBottom, nightBottom, night)!;

    Color sunCol = Color.lerp(
      const Color(0xFFFFF5DD),
      const Color(0xFFFFA15C),
      sunset * 0.92,
    )!;
    sunCol = Color.lerp(sunCol, const Color(0xFF82A8D8), night)!;

    Color ambSky = Color.lerp(
      const Color(0xFFBACFD9),
      const Color(0xFFD98B6C),
      sunset * 0.72,
    )!;
    ambSky = Color.lerp(ambSky, const Color(0xFF2B4363), night)!;

    Color ambGround = Color.lerp(
      DesertPalette.sand,
      const Color(0xFFBC6D4A),
      sunset * 0.65,
    )!;
    ambGround = Color.lerp(ambGround, const Color(0xFF2A2635), night)!;

    // Monument Valley cool dusty-rose/plum shadow tint for faces turned away from the sun
    Color coolTint = Color.lerp(
      const Color(0xFF8E6D82),
      const Color(0xFF7A4B6C),
      sunset * 0.8,
    )!;
    coolTint = Color.lerp(coolTint, const Color(0xFF273452), night)!;

    final shadowAlpha = (0.26 + sunset * 0.06) * (1.0 - night * 0.58);
    final clampedShadowAlpha = shadowAlpha.clamp(0.08, 0.32);
    final shadowLen = (0.85 + (1.0 - elevation.abs()) * 0.68).clamp(0.65, 1.60);
    final shadowDir = Vec3(
      -activeDir.x * shadowLen,
      0.0,
      -activeDir.z * shadowLen,
    );

    final shadowCol = Color.from(
      alpha: clampedShadowAlpha,
      red: _lerp(0.28, 0.10, night),
      green: _lerp(0.14, 0.08, night),
      blue: _lerp(0.20, 0.16, night),
    );
    final contactCol = Color.from(
      alpha: (clampedShadowAlpha * 1.38).clamp(0.14, 0.44),
      red: 0.19,
      green: 0.09,
      blue: 0.13,
    );

    final fogTint = Color.lerp(skyBottom, DesertPalette.sand, 0.22)!;

    return DesertLighting._(
      timeOfDay: normT,
      nightFactor: night,
      sunsetFactor: sunset,
      sunDirection: activeDir,
      sunColor: sunCol,
      skyTop: skyTop,
      skyBottom: skyBottom,
      ambientSky: ambSky,
      ambientGround: ambGround,
      coolShadowTint: coolTint,
      shadowAlpha: clampedShadowAlpha,
      shadowDirection: shadowDir,
      shadowColor: shadowCol,
      contactShadowColor: contactCol,
      fogTint: fogTint,
    );
  }

  /// Shades a low-poly flat face with warm sunlit key light + Monument Valley
  /// cool dusty-lavender shadow separation so adjacent faces pop crisply.
  Color shadeFace({
    required Color baseColor,
    required Vec3 normal,
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    double distanceFade = 0.0,
  }) {
    final rawDot = normal.dot(sunDirection);
    final ndl = math.max(0.0, rawDot);
    final shadowFacing = math.max(0.0, -rawDot);

    final hemiT = (normal.y * 0.5 + 0.5).clamp(0.0, 1.0);
    double ambR = _lerp(ambientGround.r, ambientSky.r, hemiT);
    double ambG = _lerp(ambientGround.g, ambientSky.g, hemiT);
    double ambB = _lerp(ambientGround.b, ambientSky.b, hemiT);

    // Subtle cool plum/rose shift on shadow-facing vertical walls for crisp facet contrast
    final coolMix = (shadowFacing * (1.0 - normal.y.abs()) * 0.34).clamp(0.0, 0.32);
    if (coolMix > 0.0) {
      ambR = _lerp(ambR, coolShadowTint.r, coolMix);
      ambG = _lerp(ambG, coolShadowTint.g, coolMix);
      ambB = _lerp(ambB, coolShadowTint.b, coolMix);
    }

    final ambWeight = _lerp(0.53, 0.35, nightFactor);
    final sunWeight = _lerp(0.61, 0.27, nightFactor);

    double r = baseColor.r * (ambR * ambWeight + sunColor.r * ndl * sunWeight);
    double g = baseColor.g * (ambG * ambWeight + sunColor.g * ndl * sunWeight);
    double b = baseColor.b * (ambB * ambWeight + sunColor.b * ndl * sunWeight);

    final lift = _lerp(1.13, 1.03, nightFactor);
    r *= lift;
    g *= lift;
    b *= lift;

    if (emissiveColor != null && emissiveStrength > 0.0) {
      final glow = emissiveNightOnly
          ? emissiveStrength * (nightFactor * 0.92 + sunsetFactor * 0.36).clamp(0.0, 1.0)
          : emissiveStrength;
      r = _lerp(r, emissiveColor.r, glow);
      g = _lerp(g, emissiveColor.g, glow);
      b = _lerp(b, emissiveColor.b, glow);
    }

    if (distanceFade > 0.0) {
      final f = distanceFade.clamp(0.0, 0.68);
      r = _lerp(r, fogTint.r, f);
      g = _lerp(g, fogTint.g, f);
      b = _lerp(b, fogTint.b, f);
    }

    return Color.from(
      alpha: baseColor.a,
      red: r.clamp(0.0, 1.0),
      green: g.clamp(0.0, 1.0),
      blue: b.clamp(0.0, 1.0),
    );
  }

  /// Luminous subsurface cloud shading so clouds drifting in front of the sun
  /// stay airy and warm instead of turning dark grey underneath.
  Color shadeCloudFace(Vec3 normal) {
    final topMix = (normal.y * 0.5 + 0.5).clamp(0.0, 1.0);
    final sunRim = (normal.dot(sunDirection) * 0.5 + 0.5).clamp(0.0, 1.0);

    final dayLit = DesertPalette.cloudSunlit;
    final dayUnder = DesertPalette.cloudWarmBounce;
    Color lit = Color.lerp(dayLit, const Color(0xFFFFD8B0), sunsetFactor * 0.85)!;
    lit = Color.lerp(lit, const Color(0xFF425D82), nightFactor * 0.92)!;

    Color under = Color.lerp(dayUnder, const Color(0xFFE59574), sunsetFactor * 0.85)!;
    under = Color.lerp(under, const Color(0xFF283D5C), nightFactor * 0.92)!;

    final t = (topMix * 0.62 + sunRim * 0.38).clamp(0.0, 1.0);
    return Color.lerp(under, lit, t)!;
  }

  String get periodLabel {
    if (nightFactor > 0.65) return 'Night';
    if (sunsetFactor > 0.55) {
      return timeOfDay < 0.5 ? 'Sunrise' : 'Sunset';
    }
    return 'Day';
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
