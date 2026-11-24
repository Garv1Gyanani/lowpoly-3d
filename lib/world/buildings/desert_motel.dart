import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 5: Red Rock Desert Motel evolving visually through Level 5.
class DesertMotelBuilding {
  const DesertMotelBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    mesh.withTransform(origin, 0, () {
      mesh.addBoxShadow(0, 0, 6.4, 4.0, 4.4, lighting.shadowDirection, shadowCol);

      mesh.addBox(0, 0, 0.18, 6.8, 0.20, 4.2, DesertPalette.concrete);
      final stories = level >= 2 ? 2 : 1;
      final wallH = stories == 2 ? 4.05 : 2.20;
      mesh.addBox(0.2, 0.20, -0.68, 5.8, wallH, 2.2, DesertPalette.cream, skipTop: true);

      MeshParts.addAdobeParapetRoof(
        mesh,
        cx: 0.2,
        yBase: 0.20 + wallH,
        cz: -0.68,
        width: 5.82,
        depth: 2.24,
        parapetHeight: 0.30,
        parapetColor: DesertPalette.terracotta,
      );

      for (final rx in [-1.62, 0.20, 2.02]) {
        MeshParts.addFramedDoor(
          mesh,
          cx: rx - 0.32,
          yBottom: 0.20,
          zWall: 0.42,
          width: 0.54,
          height: 1.42,
          doorColor: DesertPalette.turquoise,
          hasGlassWindow: false,
        );
        mesh.addBox(
          rx - 0.01,
          1.34,
          0.47,
          0.11,
          0.16,
          0.08,
          DesertPalette.cream,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 1.0,
        );
        MeshParts.addFramedFrontWindow(
          mesh,
          cx: rx + 0.38,
          cy: 1.08,
          zWall: 0.42,
          width: 0.70,
          height: 0.68,
        );
        mesh.addBox(rx + 0.38, 0.38, 0.53, 0.44, 0.24, 0.20, DesertPalette.metal);
      }

      if (stories == 2) {
        mesh.addBox(0.2, 2.16, 0.78, 5.85, 0.15, 0.76, DesertPalette.wood);
        mesh.addBox(0.2, 2.82, 1.12, 5.85, 0.10, 0.10, DesertPalette.woodLight);
        // Split lower & upper balcony posts cleanly at balcony deck (y = 2.16..2.31)
        for (final px in [-2.60, -0.90, 0.82, 2.60]) {
          mesh.addBox(px, 0.20, 1.12, 0.13, 1.96, 0.13, DesertPalette.woodDark, skipTop: true);
          mesh.addBox(px, 2.31, 1.12, 0.13, 0.51, 0.13, DesertPalette.woodDark, skipTop: true);
        }

        const steps = 6;
        for (int s = 0; s < steps; s++) {
          final frac = (s + 1) / steps;
          final sy = 0.20 + frac * 1.94;
          final sz = 2.02 - frac * 1.18;
          mesh.addBox(3.42, 0.20, sz, 0.64, sy - 0.28, 0.24, DesertPalette.wood, skipTop: true);
          mesh.addBox(3.42, sy - 0.08, sz + 0.02, 0.68, 0.08, 0.26, DesertPalette.woodLight);
        }
        mesh.addBox(3.72, 0.20, 0.96, 0.12, 2.72, 0.12, DesertPalette.woodDark);
        mesh.addBox(3.72, 0.20, 2.04, 0.12, 0.96, 0.12, DesertPalette.woodDark);
        mesh.addSaggingWire(
          const Vec3(3.72, 1.14, 2.04),
          const Vec3(3.72, 2.86, 0.96),
          DesertPalette.woodLight,
          sag: 0.0,
          thickness: 0.06,
          segments: 2,
        );

        for (final rx in [-1.62, 0.20, 2.02]) {
          MeshParts.addFramedDoor(
            mesh,
            cx: rx - 0.32,
            yBottom: 2.31,
            zWall: 0.42,
            width: 0.54,
            height: 1.38,
            doorColor: DesertPalette.terracotta,
            hasGlassWindow: false,
          );
          mesh.addBox(
            rx - 0.01,
            3.42,
            0.47,
            0.11,
            0.16,
            0.08,
            DesertPalette.cream,
            emissiveColor: DesertPalette.windowNight,
            emissiveStrength: 1.0,
          );
          MeshParts.addFramedFrontWindow(
            mesh,
            cx: rx + 0.38,
            cy: 3.12,
            zWall: 0.42,
            width: 0.70,
            height: 0.66,
          );
        }
        mesh.addGlow(const Vec3(-1.4, 3.1, 0.85), DesertPalette.windowNight, radius: 30, intensity: 0.65);
        mesh.addGlow(const Vec3(2.0, 3.1, 0.85), DesertPalette.windowNight, radius: 30, intensity: 0.65);
      }

      final signBaseY = 0.50 + wallH;
      MeshParts.addMarqueeSign(
        mesh,
        cx: 0.2,
        yBottom: signBaseY,
        cz: 0.32,
        width: 2.85,
        height: 0.98,
        text: 'MOTEL',
        frameColor: DesertPalette.sandstoneDark,
        glowColor: DesertPalette.neonTurquoise,
        depth: 0.24,
        glowRadius: 42,
      );

      if (level >= 3) {
        mesh.addBox(-3.0, 0.20, 1.0, 1.62, 1.35, 1.72, DesertPalette.woodLight);
        mesh.addGableRoof(-3.0, 1.55, 1.0, 1.84, 0.72, 1.94, DesertPalette.sandstone, DesertPalette.wood);
        mesh.addBox(-3.55, 1.60, 0.65, 0.34, 1.05, 0.34, DesertPalette.sandstoneDark);
        MeshParts.addFramedFrontWindow(
          mesh,
          cx: -3.0,
          cy: 0.92,
          zWall: 1.86,
          width: 0.56,
          height: 0.52,
        );
      }

      // Level 4+: Courtyard guest patio lounge table & potted desert cacti
      if (level >= 4) {
        MeshParts.addPatioUmbrellaTable(
          mesh,
          cx: 0.25,
          yBottom: 0.20,
          cz: 1.72,
          umbrellaColor: DesertPalette.terracotta,
          scale: 0.85,
        );
        MeshParts.addPottedCactus(mesh, cx: -1.75, yBottom: 0.20, cz: 1.55);
      }

      // Level 5: Rooftop redwood water cistern & starlight resort neon trim!
      if (level >= 5) {
        mesh.addFrustum(-1.95, 0.50 + wallH, -0.85, 0.56, 0.56, 0.52, 0.52, 0.95, 8, DesertPalette.wood);
        mesh.addFrustum(-1.95, 1.45 + wallH, -0.85, 0.64, 0.64, 0.08, 0.08, 0.38, 8, DesertPalette.terracotta);
        mesh.addSaggingWire(
          const Vec3(-2.60, 2.75, 1.12),
          const Vec3(2.60, 2.75, 1.12),
          DesertPalette.woodDark,
          sag: 0.18,
          bulbCount: 5,
          bulbGlowColor: DesertPalette.windowNight,
        );
      }
    });
  }
}
