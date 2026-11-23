import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 6A: Mesa Lookout Water Tower (with iron barrel hoops, climb ladder & cross-braces),
/// Adobe Tour Lodge, Trail Map Board, Canvas Tents, Log Benches & Animated Campfire Sparks.
class LookoutCampBuilding {
  const LookoutCampBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    mesh.addBoxShadow(
      origin.x,
      origin.z,
      5.8,
      4.0,
      6.0,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(origin, 0, () {
      mesh.addGroundRect(0, 0.03, 0, 6.2, 4.4, const Color(0xFFCDA876), layer: RenderLayer.groundDecal, depthBias: 0.04);

      // Tall Timber Water / Lookout Tower
      const tx = 1.50;
      const tz = -0.80;
      for (final lx in [-0.68, 0.68]) {
        for (final lz in [-0.68, 0.68]) {
          mesh.addBox(tx + lx, 0, tz + lz, 0.17, 3.85, 0.17, DesertPalette.woodDark);
        }
      }
      // Horizontal mid-braces & service ladder rungs
      mesh.addBox(tx, 1.25, tz + 0.68, 1.48, 0.10, 0.10, DesertPalette.wood);
      mesh.addBox(tx, 2.55, tz + 0.68, 1.48, 0.10, 0.10, DesertPalette.wood);
      mesh.addBox(tx, 1.78, tz, 1.52, 0.13, 1.52, DesertPalette.wood);
      for (int r = 1; r <= 7; r++) {
        mesh.addBox(tx - 0.18, r * 0.48, tz + 0.76, 0.34, 0.06, 0.06, DesertPalette.woodLight);
      }

      // Observation deck platform & railings
      mesh.addBox(tx, 3.80, tz, 2.10, 0.18, 2.10, DesertPalette.woodLight);
      mesh.addBox(tx, 4.36, tz + 0.98, 2.10, 0.09, 0.09, DesertPalette.wood);
      mesh.addBox(tx, 4.36, tz - 0.98, 2.10, 0.09, 0.09, DesertPalette.wood);

      // Cylindrical wooden water barrel with iron tension hoops
      mesh.addFrustum(
        tx,
        3.98,
        tz,
        0.86,
        0.86,
        0.82,
        0.82,
        1.65,
        8,
        DesertPalette.wood,
        topColor: DesertPalette.woodDark,
      );
      for (final hy in [4.38, 4.86, 5.32]) {
        mesh.addFrustum(
          tx,
          hy,
          tz,
          0.88,
          0.88,
          0.88,
          0.88,
          0.07,
          8,
          DesertPalette.metalDark,
          depthBias: -0.06,
        );
      }
      // Conical terracotta roof cap
      mesh.addFrustum(
        tx,
        5.63,
        tz,
        1.02,
        1.02,
        0.08,
        0.08,
        0.72,
        8,
        DesertPalette.terracotta,
        topColor: DesertPalette.sandstoneDark,
      );
      mesh.addGlow(const Vec3(tx, 6.15, tz), DesertPalette.neonWarm, radius: 32, intensity: 0.78);

      // Adobe Visitor Tour Lodge
      mesh.addBox(-1.50, 0, -0.70, 2.70, 2.02, 2.18, DesertPalette.cream);
      MeshParts.addAdobeParapetRoof(
        mesh,
        cx: -1.50,
        yBase: 2.02,
        cz: -0.70,
        width: 2.72,
        depth: 2.20,
        parapetHeight: 0.24,
        parapetColor: DesertPalette.sandstone,
      );
      MeshParts.addFramedDoor(
        mesh,
        cx: -1.50,
        yBottom: 0,
        zWall: 0.39,
        width: 0.68,
        height: 1.32,
        hasGlassWindow: false,
      );
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: -2.24,
        cy: 1.08,
        zWall: 0.39,
        width: 0.56,
        height: 0.56,
      );
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: -0.76,
        cy: 1.08,
        zWall: 0.39,
        width: 0.56,
        height: 0.56,
      );

      // Wooden trail map board outside the lodge
      mesh.addBox(-0.22, 0, 0.42, 0.08, 0.92, 0.08, DesertPalette.woodDark);
      mesh.addBox(-0.22, 0.62, 0.44, 0.56, 0.42, 0.07, DesertPalette.cream);

      MeshParts.addMarqueeSign(
        mesh,
        cx: -1.50,
        yBottom: 2.26,
        cz: 0.30,
        width: 1.95,
        height: 0.56,
        text: 'TOURS',
        frameColor: DesertPalette.sandstoneDark,
        glowColor: DesertPalette.neonWarm,
        depth: 0.16,
        glowRadius: 26,
      );

      // Level 2+: Canvas desert A-frame camping tents
      if (level >= 2) {
        _addCampTent(mesh, const Vec3(-1.95, 0, 1.45), DesertPalette.cream, DesertPalette.terracotta);
        _addCampTent(mesh, const Vec3(2.05, 0, 1.45), DesertPalette.turquoise, DesertPalette.cream);
      }

      // Campfire ring with wooden log benches & animated rising glowing sparks!
      const fx = 0.05;
      const fz = 1.35;
      mesh.addFrustum(fx, 0, fz, 0.54, 0.54, 0.48, 0.48, 0.18, 7, DesertPalette.metal);
      // Two cozy wooden log benches flanking the fire
      mesh.addBox(fx - 0.85, 0, fz + 0.15, 0.24, 0.24, 0.78, DesertPalette.wood);
      mesh.addBox(fx + 0.85, 0, fz + 0.15, 0.24, 0.24, 0.78, DesertPalette.wood);

      final flick = 0.72 + math.sin(animTime * 9.5) * 0.18;
      mesh.addFrustum(
        fx,
        0.15,
        fz,
        0.28,
        0.28,
        0.04,
        0.04,
        0.58 * flick,
        5,
        const Color(0xFFFF8C32),
        emissiveColor: const Color(0xFFFFC14D),
        emissiveStrength: 1.0,
        emissiveNightOnly: false,
      );
      // Rising glowing ember sparks
      for (int i = 0; i < 3; i++) {
        final t = (animTime * 1.15 + i * 0.33) % 1.0;
        final ex = fx + math.sin(animTime * 3.0 + i * 2.1) * 0.22;
        final ey = 0.55 + t * 0.95;
        mesh.addBox(
          ex,
          ey,
          fz,
          0.08,
          0.08,
          0.08,
          const Color(0xFFFFD666),
          emissiveColor: const Color(0xFFFFD666),
          emissiveStrength: 1.0,
          emissiveNightOnly: false,
        );
      }
      mesh.addGlow(
        const Vec3(fx, 0.52, fz),
        const Color(0xFFFF9838),
        radius: 38,
        intensity: 0.84,
        nightOnly: false,
      );
    });
  }

  static void _addCampTent(MeshBuilder mesh, Vec3 pos, Color wall, Color trim) {
    mesh.withTransform(pos, 0.15, () {
      mesh.addGableRoof(0, 0, 0, 1.18, 0.96, 1.36, wall, trim);
      mesh.addBox(0, 0, 0.68, 0.42, 0.58, 0.06, DesertPalette.woodDark, depthBias: -0.14);
    });
  }
}
