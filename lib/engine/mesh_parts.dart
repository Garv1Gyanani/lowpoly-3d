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
    // Outer chunky timber frame
    mesh.addBox(
      cx,
      yBottom,
      zWall + 0.03,
      width + 0.14,
      height + 0.08,
      0.10,
      frameColor,
      depthBias: -0.14,
    );
    // Inner door slab
    mesh.addBox(
      cx,
      yBottom,
      zWall + 0.05,
      width,
      height,
      0.08,
      doorColor,
      depthBias: -0.18,
    );
    if (hasGlassWindow) {
      mesh.addFrontWindow(
        cx,
        yBottom + height * 0.62,
        zWall + 0.08,
        width * 0.68,
        height * 0.44,
        DesertPalette.windowDay,
        DesertPalette.windowNight,
        depthBias: -0.26,
      );
    }
  }

  /// Adds a framed front window (+Z) with wooden/stucco sill and glowing night glass.
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
    // Frame backing
    mesh.addBox(
      cx,
      cy - height * 0.5 - 0.05,
      zWall + 0.02,
      width + 0.14,
      height + 0.12,
      0.08,
      frameColor,
      depthBias: -0.14,
    );
    // Window sill ledge
    mesh.addBox(
      cx,
      cy - height * 0.5 - 0.09,
      zWall + 0.07,
      width + 0.24,
      0.08,
      0.16,
      sillColor,
      depthBias: -0.20,
    );
    // Glowing pane
    mesh.addFrontWindow(
      cx,
      cy,
      zWall + 0.05,
      width,
      height,
      DesertPalette.windowDay,
      DesertPalette.windowNight,
      depthBias: -0.26,
    );
    // Crisp wooden cross-mullion bars for richer handcrafted low-poly window detail
    mesh.addFlushRectOnZ(
      cx,
      cy,
      zWall + 0.085,
      0.05,
      height,
      frameColor,
      positiveZ: true,
    );
    mesh.addFlushRectOnZ(
      cx,
      cy,
      zWall + 0.085,
      width,
      0.05,
      frameColor,
      positiveZ: true,
    );
  }

  /// Adds a southwestern adobe parapet roof with recessed flat roof & protruding wooden vigas beams.
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
    mesh.addBox(cx, yBase, cz, width + 0.22, parapetHeight, depth + 0.22, parapetColor);
    mesh.addBox(cx, yBase + parapetHeight * 0.55, cz, width - 0.18, 0.14, depth - 0.18, roofDeckColor);

    if (addVigasBeams) {
      final count = math.max(3, (width / 1.15).floor());
      for (int i = 0; i < count; i++) {
        final t = count == 1 ? 0.5 : i / (count - 1);
        final bx = cx - (width * 0.40) + t * (width * 0.80);
        mesh.addBox(
          bx,
          yBase - 0.12,
          cz + depth * 0.5 + 0.12,
          0.11,
          0.11,
          0.26,
          DesertPalette.woodDark,
          depthBias: -0.15,
        );
      }
    }
  }

  /// Adds a rooftop illuminated marquee signboard with perspective-aligned 3D text.
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
    mesh.addBox(cx, yBottom, cz, width, height, depth, frameColor);
    mesh.addBox(
      cx,
      yBottom + 0.08,
      cz + depth * 0.42,
      width - 0.22,
      height - 0.18,
      0.08,
      faceColor,
      emissiveColor: glowColor,
      emissiveStrength: 0.85,
      depthBias: -0.22,
    );
    mesh.addFrontSignText(
      cx,
      yBottom + height * 0.50,
      cz + depth * 0.42 + 0.05,
      width - 0.34,
      height - 0.26,
      text,
      textColor,
      glowColor: glowColor,
    );
    mesh.addGlow(
      Vec3(cx, yBottom + height * 0.5, cz + depth * 0.5 + 0.1),
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
    mesh.addBox(cx, yBottom, cz, 0.22 * s, 0.48 * s, 0.22 * s, DesertPalette.woodDark);
    mesh.addBox(cx, yBottom + 0.48 * s, cz, 0.80 * s, 0.09 * s, 0.80 * s, DesertPalette.woodLight);
    // Two cute wooden patio stools flanking the table
    for (final dx in [-0.54 * s, 0.54 * s]) {
      mesh.addBox(cx + dx, yBottom, cz, 0.24 * s, 0.34 * s, 0.24 * s, DesertPalette.wood);
    }
    // Pole & faceted umbrella canopy with peak finial
    mesh.addBox(cx, yBottom + 0.52 * s, cz, 0.08 * s, 1.25 * s, 0.08 * s, DesertPalette.woodDark);
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
    mesh.addBox(cx, yBottom + 1.84 * s, cz, 0.11 * s, 0.12 * s, 0.11 * s, DesertPalette.cream);
  }

  /// Adds a small terracotta pot with a mini cactus or desert agave (great near doorways!).
  static void addPottedCactus(
    MeshBuilder mesh, {
    required double cx,
    required double yBottom,
    required double cz,
  }) {
    mesh.addFrustum(cx, yBottom, cz, 0.18, 0.18, 0.24, 0.24, 0.30, 6, DesertPalette.terracotta);
    mesh.addFrustum(cx, yBottom + 0.28, cz, 0.12, 0.12, 0.10, 0.10, 0.52, 6, DesertPalette.cactus);
  }
}
