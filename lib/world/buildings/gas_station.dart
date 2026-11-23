import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 4: Canyon Gas Station Canopy, Fuel Pumps with Hoses & Safety Bollards,
/// Corrugated Repair Garage Bay, Tool Chest, and Highway Price Totem.
class GasStationBuilding {
  const GasStationBuilding._();

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
  ) {
    mesh.addBoxShadow(
      origin.x,
      origin.z,
      5.4,
      4.1,
      3.3,
      lighting.shadowDirection,
      shadowCol,
    );

    mesh.withTransform(origin, 0, () {
      // Concrete forecourt slab
      mesh.addBox(0, 0, 0.2, 5.5, 0.18, 4.4, DesertPalette.concrete);

      // Attached adobe repair garage & service office
      mesh.addBox(0.25, 0.18, -1.12, 4.75, 2.48, 1.82, DesertPalette.cream);
      MeshParts.addAdobeParapetRoof(
        mesh,
        cx: 0.25,
        yBase: 2.66,
        cz: -1.12,
        width: 4.78,
        depth: 1.85,
        parapetHeight: 0.26,
        parapetColor: DesertPalette.terracotta,
        addVigasBeams: false,
      );

      // Corrugated roll-up repair bay door with horizontal slats
      mesh.addBox(-0.78, 0.18, -0.20, 1.88, 1.75, 0.10, DesertPalette.metal, depthBias: -0.16);
      for (final sy in [0.55, 0.92, 1.29, 1.66]) {
        mesh.addBox(-0.78, sy, -0.14, 1.84, 0.05, 0.04, DesertPalette.metalDark, depthBias: -0.22);
      }

      MeshParts.addFramedFrontWindow(
        mesh,
        cx: 1.42,
        cy: 1.30,
        zWall: -0.20,
        width: 1.28,
        height: 0.90,
      );

      // Overhead fuel canopy with recessed glowing fluorescent ceiling panels
      const canopyY = 2.75;
      mesh.addBox(-1.55, 0.18, 1.05, 0.30, canopyY - 0.18, 0.30, DesertPalette.creamDark);
      mesh.addBox(1.55, 0.18, 1.05, 0.30, canopyY - 0.18, 0.30, DesertPalette.creamDark);
      mesh.addBox(0, canopyY, 1.05, 4.75, 0.38, 2.12, DesertPalette.cream);
      mesh.addBox(0, canopyY + 0.08, 1.05, 4.86, 0.22, 2.22, DesertPalette.awningRed);
      for (final lx in [-0.95, 0.95]) {
        mesh.addBox(
          lx,
          canopyY - 0.05,
          1.05,
          1.15,
          0.06,
          0.55,
          DesertPalette.cream,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 1.0,
          depthBias: -0.12,
        );
        mesh.addGlow(Vec3(lx, canopyY - 0.18, 1.05), DesertPalette.windowNight, radius: 34, intensity: 0.85);
      }

      // Fuel island + safety yellow bollards + 2 vintage low-poly red gas pumps with side hoses
      mesh.addBox(0, 0.18, 1.05, 2.85, 0.15, 0.72, DesertPalette.concrete);
      for (final bx in [-1.32, 1.32]) {
        mesh.addFrustum(bx, 0.33, 1.05, 0.09, 0.09, 0.08, 0.08, 0.62, 6, DesertPalette.gold);
      }
      for (final px in [-0.66, 0.66]) {
        mesh.addBox(px, 0.33, 1.05, 0.52, 1.12, 0.40, DesertPalette.awningRed);
        mesh.addBox(px, 1.45, 1.05, 0.44, 0.14, 0.34, DesertPalette.cream);
        // Pump side hose loop & chrome nozzle
        mesh.addBox(px + 0.30, 0.66, 1.05, 0.07, 0.54, 0.07, DesertPalette.asphalt);
        mesh.addBox(px + 0.30, 1.12, 1.05, 0.10, 0.14, 0.12, DesertPalette.metal);
        mesh.addBox(
          px,
          0.92,
          1.26,
          0.35,
          0.32,
          0.06,
          DesertPalette.cream,
          emissiveColor: DesertPalette.windowNight,
          emissiveStrength: 0.85,
          depthBias: -0.20,
        );
      }

      // Tall highway price totem sign
      mesh.addBox(2.58, 0.18, 1.98, 0.22, 4.35, 0.22, DesertPalette.metalDark);
      MeshParts.addMarqueeSign(
        mesh,
        cx: 2.58,
        yBottom: 3.40,
        cz: 1.98,
        width: 1.48,
        height: 1.20,
        text: 'GAS\n\$3.49',
        frameColor: DesertPalette.awningRed,
        glowColor: DesertPalette.neonWarm,
        textColor: DesertPalette.sandstoneDark,
        depth: 0.26,
        glowRadius: 34,
      );

      // Level 3+: Stacked spare tires, red mechanic tool chest & turquoise oil drum
      if (level >= 3) {
        mesh.addFrustum(-2.35, 0.18, -0.45, 0.32, 0.32, 0.32, 0.32, 0.48, 8, DesertPalette.asphalt);
        mesh.addFrustum(-2.35, 0.18, 0.36, 0.26, 0.26, 0.26, 0.26, 0.78, 8, DesertPalette.turquoise);
        mesh.addBox(-1.95, 0.18, 0.02, 0.48, 0.64, 0.36, DesertPalette.awningRed);
      }
    });
  }
}
