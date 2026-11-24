import 'dart:math' as math;
import 'dart:ui';

import '../theme/desert_palette.dart';
import 'mesh_builder.dart';
import 'vec3.dart';

/// Shared architectural & low-poly detail helpers so all individual building,
/// prop, and vehicle files share one cohesive Desert Outpost visual language.
class MeshParts {
  const MeshParts._();

  /// Adds a framed front door (+Z) with wooden surround, recessed door panel, and optional transom glass.
  /// All layers stack cleanly forward from [zWall] with zero wall penetration.
  static void addFramedDoor(
    MeshBuilder mesh, {
    required double cx,
    required double yBottom,
    required double zWall,
    required double width,
    required double height,
    Color frameColor = DesertPalette.woodDark,
    Color doorColor = DesertPalette.wood,
    bool hasGlassWindow = true,
  }) {
    // Outer chunky timber frame: [zWall, zWall + 0.06]
    mesh.addBox(
      cx,
      yBottom,
      zWall + 0.03,
      width + 0.14,
      height + 0.08,
      0.06,
      frameColor,
    );
    // Inner door slab: [zWall + 0.06, zWall + 0.09]
    mesh.addBox(
      cx,
      yBottom,
      zWall + 0.075,
      width,
      height,
      0.03,
      doorColor,
    );
    if (hasGlassWindow) {
      mesh.addFrontWindow(
        cx,
        yBottom + height * 0.62,
        zWall + 0.075,
        width * 0.68,
        height * 0.44,
        DesertPalette.windowDay,
        DesertPalette.windowNight,
      );
    }
  }

  /// Adds a framed front window (+Z) with wooden/stucco sill and glowing night glass.
  /// All layers stack strictly forward from [zWall] with zero box-in-box intersections.
  static void addFramedFrontWindow(
    MeshBuilder mesh, {
    required double cx,
    required double cy,
    required double zWall,
    required double width,
    required double height,
    Color frameColor = DesertPalette.wood,
    Color sillColor = DesertPalette.creamDark,
  }) {
    final frameBottom = cy - height * 0.5 - 0.05;
    // Frame backing: [zWall, zWall + 0.05]
    mesh.addBox(
      cx,
      frameBottom,
      zWall + 0.025,
      width + 0.14,
      height + 0.12,
      0.05,
      frameColor,
    );
    // Window sill ledge seated directly below frame: [zWall, zWall + 0.14]
    mesh.addBox(
      cx,
      frameBottom - 0.08,
      zWall + 0.07,
      width + 0.24,
      0.08,
      0.14,
      sillColor,
    );
    // Glowing pane at zWall + 0.07 (0.02 in front of frame backing)
    mesh.addFrontWindow(
      cx,
      cy,
      zWall + 0.04,
      width,
      height,
      DesertPalette.windowDay,
      DesertPalette.windowNight,
    );
    // Crisp wooden cross-mullion bars at zWall + 0.085 (in front of pane)
    mesh.addFlushRectOnZ(
      cx,
      cy,
      zWall + 0.07,
      0.05,
      height,
      frameColor,
      positiveZ: true,
    );
    mesh.addFlushRectOnZ(
      cx,
      cy,
      zWall + 0.07,
      width,
      0.05,
      frameColor,
      positiveZ: true,
    );
  }

  /// Adds a southwestern adobe parapet roof built from 4 non-overlapping perimeter parapet walls
  /// around a cleanly recessed flat roof deck, plus outward-projecting wooden vigas beams.
  static void addAdobeParapetRoof(
    MeshBuilder mesh, {
    required double cx,
    required double yBase,
    required double cz,
    required double width,
    required double depth,
    double parapetHeight = 0.30,
    Color parapetColor = DesertPalette.terracotta,
    Color roofDeckColor = DesertPalette.sandDark,
    bool addVigasBeams = true,
  }) {
    final outerW = width + 0.22;
    final outerD = depth + 0.22;
    final rim = math.min(0.24, math.min(outerW, outerD) * 0.18);
    final innerW = math.max(0.2, outerW - rim * 2.0);
    final innerD = math.max(0.2, outerD - rim * 2.0);

    // 1. Recessed flat roof deck cleanly seated inside the parapet well (zero overlap!)
    mesh.addBox(cx, yBase, cz, innerW, 0.06, innerD, roofDeckColor);

    // 2. Four non-overlapping perimeter parapet rim walls (North, South, West, East)
    mesh.addBox(
      cx,
      yBase,
      cz - outerD * 0.5 + rim * 0.5,
      outerW,
      parapetHeight,
      rim,
      parapetColor,
    );
    mesh.addBox(
      cx,
      yBase,
      cz + outerD * 0.5 - rim * 0.5,
      outerW,
      parapetHeight,
      rim,
      parapetColor,
    );
    mesh.addBox(
      cx - outerW * 0.5 + rim * 0.5,
      yBase,
      cz,
      rim,
      parapetHeight,
      innerD,
      parapetColor,
    );
    mesh.addBox(
      cx + outerW * 0.5 - rim * 0.5,
      yBase,
      cz,
      rim,
      parapetHeight,
      innerD,
      parapetColor,
    );

    if (addVigasBeams) {
      final count = math.max(3, (width / 1.15).floor());
      for (int i = 0; i < count; i++) {
        final t = count == 1 ? 0.5 : i / (count - 1);
        final bx = cx - (width * 0.40) + t * (width * 0.80);
        // Protrudes cleanly outward from front wall (+Z) without penetrating inside
        mesh.addBox(
          bx,
          yBase - 0.12,
          cz + depth * 0.5 + 0.12,
          0.11,
          0.11,
          0.22,
          DesertPalette.woodDark,
        );
      }
    }
  }

  /// Adds a rooftop illuminated marquee signboard with flush front face and perspective-aligned 3D text.
  static void addMarqueeSign(
    MeshBuilder mesh, {
    required double cx,
    required double yBottom,
    required double cz,
    required double width,
    required double height,
    required String text,
    required Color frameColor,
    required Color glowColor,
    Color faceColor = DesertPalette.cream,
    Color textColor = DesertPalette.uiInk,
    double depth = 0.22,
    double glowRadius = 36.0,
  }) {
    final frontZ = cz + depth * 0.5;
    mesh.addBox(cx, yBottom, cz, width, height, depth, frameColor);
    mesh.addFlushRectOnZ(
      cx,
      yBottom + height * 0.5,
      frontZ,
      width - 0.22,
      height - 0.18,
      faceColor,
      positiveZ: true,
      emissiveColor: glowColor,
      emissiveStrength: 0.85,
    );
    mesh.addFrontSignText(
      cx,
      yBottom + height * 0.50,
      frontZ + 0.025,
      width - 0.34,
      height - 0.26,
      text,
      textColor,
      glowColor: glowColor,
    );
    mesh.addGlow(
      Vec3(cx, yBottom + height * 0.5, frontZ + 0.1),
      glowColor,
      radius: glowRadius,
      intensity: 0.72,
    );
  }

  /// Adds a shaded patio table with an alternating striped octagonal low-poly umbrella & 2 wooden chairs.
  static void addPatioUmbrellaTable(
    MeshBuilder mesh, {
    required double cx,
    required double yBottom,
    required double cz,
    required Color umbrellaColor,
    Color topColor = DesertPalette.cream,
    double scale = 1.0,
  }) {
    final s = scale;
    // Wooden table pedestal & tabletop
    mesh.addBox(cx, yBottom, cz, 0.22 * s, 0.48 * s, 0.22 * s, DesertPalette.woodDark, skipTop: true);
    mesh.addBox(cx, yBottom + 0.48 * s, cz, 0.80 * s, 0.09 * s, 0.80 * s, DesertPalette.woodLight);
    // Two cute wooden patio stools flanking the table
    for (final dx in [-0.54 * s, 0.54 * s]) {
      mesh.addBox(cx + dx, yBottom, cz, 0.24 * s, 0.34 * s, 0.24 * s, DesertPalette.wood);
    }
    // Pole seated cleanly on top of tabletop and stopping under umbrella canopy
    mesh.addBox(cx, yBottom + 0.57 * s, cz, 0.08 * s, 0.97 * s, 0.08 * s, DesertPalette.woodDark);
    mesh.addFrustum(
      cx,
      yBottom + 1.54 * s,
      cz,
      0.86 * s,
      0.86 * s,
      0.07 * s,
      0.07 * s,
      0.32 * s,
      6,
      umbrellaColor,
      topColor: topColor,
    );
    mesh.addBox(cx, yBottom + 1.86 * s, cz, 0.11 * s, 0.12 * s, 0.11 * s, DesertPalette.cream);
  }

  /// Adds a small terracotta pot with a mini cactus or desert agave (great near doorways!).
  static void addPottedCactus(
    MeshBuilder mesh, {
    required double cx,
    required double yBottom,
    required double cz,
  }) {
    mesh.addFrustum(cx, yBottom, cz, 0.18, 0.18, 0.24, 0.24, 0.30, 6, DesertPalette.terracotta);
    mesh.addFrustum(cx, yBottom + 0.30, cz, 0.12, 0.12, 0.10, 0.10, 0.50, 6, DesertPalette.cactus);
  }
}
