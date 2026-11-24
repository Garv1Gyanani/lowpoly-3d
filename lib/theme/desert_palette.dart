import 'package:flutter/painting.dart';

/// Official Desert Outpost color palette & typography tokens.
class DesertPalette {
  const DesertPalette._();

  // Core desert & sandstone palette
  static const Color sand = Color(0xFFDDBA87);
  static const Color sandLight = Color(0xFFE8CDA0);
  static const Color sandDark = Color(0xFFC8A16D);
  static const Color arroyoSand = Color(0xFFD2A673);
  static const Color arroyoDark = Color(0xFFBC8E5C);
  static const Color sandstone = Color(0xFFA9573D);
  static const Color sandstoneDark = Color(0xFF833D29);
  static const Color sandstoneLight = Color(0xFFC47152);
  static const Color terracotta = Color(0xFFC8794B);
  static const Color wood = Color(0xFF79543B);
  static const Color woodLight = Color(0xFF9A6F4F);
  static const Color woodDark = Color(0xFF563A27);
  static const Color vegetation = Color(0xFF79805A);
  static const Color vegetationDark = Color(0xFF5A6142);
  static const Color cactus = Color(0xFF637D4F);
  static const Color sky = Color(0xFF8CB5C4);
  static const Color skyHorizon = Color(0xFFE9CFAF);
  static const Color cream = Color(0xFFF2E5CC);
  static const Color creamDark = Color(0xFFDCC9A8);

  // Monument Valley shadow & atmospheric accents
  static const Color shadowPlum = Color(0xFF432634);
  static const Color shadowContact = Color(0xFF2B1620);
  static const Color cloudSunlit = Color(0xFFFFF8EE);
  static const Color cloudWarmBounce = Color(0xFFF3D5BE);

  // Supporting desert outpost accents
  static const Color asphalt = Color(0xFF494544);
  static const Color asphaltShoulder = Color(0xFF8F7A61);
  static const Color roadYellow = Color(0xFFEDBE58);
  static const Color roadWhite = Color(0xFFEBE4D4);
  static const Color concrete = Color(0xFFCBBFA9);
  static const Color awningRed = Color(0xFFC9533E);
  static const Color turquoise = Color(0xFF4B9B95);
  static const Color windowDay = Color(0xFF4C6A7A);
  static const Color windowNight = Color(0xFFFFD57E);
  static const Color neonWarm = Color(0xFFFFB657);
  static const Color neonCoral = Color(0xFFFF7A5A);
  static const Color neonTurquoise = Color(0xFF64E2D5);
  static const Color metal = Color(0xFF80878B);
  static const Color metalDark = Color(0xFF4D5358);
  static const Color gold = Color(0xFFF4BF48);
  static const Color goldPopup = Color(0xFFFFE082);
  static const Color emeraldPopup = Color(0xFF8EF5A8);
  static const Color water = Color(0xFF57AEBD);

  // UI tones
  static const Color uiSurface = Color(0xFFF7EFE0);
  static const Color uiSurfaceDark = Color(0xFF2B221D);
  static const Color uiInk = Color(0xFF35261D);
  static const Color uiSubtle = Color(0xFF7B6554);
  static const Color uiAccent = Color(0xFFC8683C);
  static const Color uiCashGreen = Color(0xFF3E8C54);
}

/// Shared custom game typography (bundled Bungee marquee display + Fredoka tactile UI).
class DesertTypography {
  const DesertTypography._();

  static const String displayFamily = 'Bungee';
  static const String uiFamily = 'Fredoka';

  static TextStyle display({
    required double size,
    Color color = const Color(0xFFFFF6E3),
    double letterSpacing = 0.6,
    double height = 1.05,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle ui({
    required double size,
    Color color = DesertPalette.uiInk,
    FontWeight weight = FontWeight.w700,
    double letterSpacing = 0.2,
    double height = 1.15,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }
}
