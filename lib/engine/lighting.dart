import 'dart:math' as math;
import 'dart:ui';

import '../theme/desert_palette.dart';
import 'vec3.dart';

/// Computes sky colors, directional sun/moon lighting, and night emissive factors
/// for the Desert Outpost day/night cycle.
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
    required this.shadowAlpha,
    required this.shadowDirection,
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
  final double shadowAlpha;

  /// Ground-plane XZ vector along which shadows stretch.
  final Vec3 shadowDirection;
  final Color fogTint;

  factory DesertLighting.fromTime(double t) {
    final normT = t % 1.0;
    // Sun elevation: -1 at midnight (0.0), +1 at noon (0.5).
    final sunAngle = (normT - 0.25) * math.pi * 2.0;
    final elevation = math.sin(sunAngle); // -1..1
    final azimuth = math.cos(sunAngle);

    // Smooth night factor: 0 when elevation > 0.18, 1 when elevation < -0.15
    final night = _smoothstep(0.20, -0.16, elevation);
    // Warm sunset/sunrise glow near elevation = 0.02
    final sunset = math.exp(-math.pow((elevation - 0.04) / 0.22, 2)).clamp(0.0, 1.0);

    // Light vector: during night, switch smoothly to high cool moonlight
    final rawSun = Vec3(
      azimuth * 0.72 + 0.25,
      math.max(0.24, elevation.abs() * 0.85 + 0.28),
      0.42,
    ).normalized();

    final moonDir = const Vec3(-0.35, 0.78, 0.52).normalized();
    final activeDir = rawSun.lerp(moonDir, night).normalized();

    // Sky palette blending: Day -> Sunset -> Night
    const dayTop = Color(0xFF7CA9BC);
    const dayBottom = Color(0xFFEED3B3);
    const sunsetTop = Color(0xFF6B5A78);
    const sunsetBottom = Color(0xFFEB8E5C);
    const nightTop = Color(0xFF0E1B2E);
    const nightBottom = Color(0xFF203854);

    Color skyTop = Color.lerp(dayTop, sunsetTop, sunset * 0.75)!;
    skyTop = Color.lerp(skyTop, nightTop, night)!;

    Color skyBottom = Color.lerp(dayBottom, sunsetBottom, sunset * 0.85)!;
    skyBottom = Color.lerp(skyBottom, nightBottom, night)!;

    // Light & bounce colors
    Color sunCol = Color.lerp(
      const Color(0xFFFFF4DC),
      const Color(0xFFFFA563),
      sunset * 0.9,
    )!;
    sunCol = Color.lerp(sunCol, const Color(0xFF7FA3D1), night)!;

    Color ambSky = Color.lerp(
      const Color(0xFFB5CBD6),
      const Color(0xFFD68D6A),
      sunset * 0.7,
    )!;
    ambSky = Color.lerp(ambSky, const Color(0xFF2B4363), night)!;

    Color ambGround = Color.lerp(
      DesertPalette.sand,
      const Color(0xFFB86C49),
      sunset * 0.65,
    )!;
    ambGround = Color.lerp(ambGround, const Color(0xFF2A2635), night)!;

    final shadowAlpha = (0.24 * (1.0 - night * 0.62)).clamp(0.06, 0.28);
    final shadowLen = (0.85 + (1.0 - elevation.abs()) * 0.55).clamp(0.65, 1.45);
    final shadowDir = Vec3(
      -activeDir.x * shadowLen,
      0.0,
      -activeDir.z * shadowLen,
    );

    final fogTint = Color.lerp(skyBottom, DesertPalette.sand, 0.25)!;

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
      shadowAlpha: shadowAlpha,
      shadowDirection: shadowDir,
      fogTint: fogTint,
    );
  }

  /// Shades a low-poly flat face using directional + hemisphere ambient lighting
  /// plus optional night emissive illumination (windows, signs, lanterns).
  Color shadeFace({
    required Color baseColor,
    required Vec3 normal,
    Color? emissiveColor,
    double emissiveStrength = 0.0,
    bool emissiveNightOnly = true,
    double distanceFade = 0.0,
  }) {
    final ndl = math.max(0.0, normal.dot(sunDirection));
    // Hemisphere bounce (top faces catch sky, undersides catch warm desert sand)
    final hemiT = (normal.y * 0.5 + 0.5).clamp(0.0, 1.0);
    final ambR = _lerp(ambientGround.r, ambientSky.r, hemiT);
    final ambG = _lerp(ambientGround.g, ambientSky.g, hemiT);
    final ambB = _lerp(ambientGround.b, ambientSky.b, hemiT);

    // Night dims ambient and directional intensity while preserving readable silhouettes
    final ambWeight = _lerp(0.54, 0.34, nightFactor);
    final sunWeight = _lerp(0.58, 0.26, nightFactor);

    double r = baseColor.r * (ambR * ambWeight + sunColor.r * ndl * sunWeight);
    double g = baseColor.g * (ambG * ambWeight + sunColor.g * ndl * sunWeight);
    double b = baseColor.b * (ambB * ambWeight + sunColor.b * ndl * sunWeight);

    // Gentle low-poly contrast lift during daytime so colors feel crisp and cheerful
    final lift = _lerp(1.12, 1.02, nightFactor);
    r *= lift;
    g *= lift;
    b *= lift;

    // Apply emissive lighting (windows, lamps, neon signs, campfire, headlights)
    if (emissiveColor != null && emissiveStrength > 0.0) {
      final glow = emissiveNightOnly
          ? emissiveStrength * (nightFactor * 0.92 + sunsetFactor * 0.35).clamp(0.0, 1.0)
          : emissiveStrength;
      r = _lerp(r, emissiveColor.r, glow);
      g = _lerp(g, emissiveColor.g, glow);
      b = _lerp(b, emissiveColor.b, glow);
    }

    // Subtle atmospheric haze for distant Monument Valley mesas
    if (distanceFade > 0.0) {
      final f = distanceFade.clamp(0.0, 0.65);
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
