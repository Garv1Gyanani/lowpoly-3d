import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../theme/desert_palette.dart';
import 'vehicle_parts.dart';

/// Classic retro Winnebago-style desert Camper RV with cab-over bunk overhang,
/// flush dual stripes, side entry door, rolled camp awning, rear ladder, roof AC & solar panel.
class CamperRvModel {
  const CamperRvModel._();

  static const double length = 2.95;
  static const double width = 1.18;
  static const double bodyHeight = 1.24;

  static void buildLocal(
    MeshBuilder mesh, {
    required Color stripeColor,
    required bool headlightsOn,
    bool reversing = false,
  }) {
    const wy = VehicleParts.wheelY;
    VehicleParts.addWheelsAndBumpers(
      mesh,
      length: length,
      width: width,
      headlightsOn: headlightsOn,
      reversing: reversing,
      grillHeight: 0.22,
    );

    // SubOrder 1: Main RV cream coach box
    mesh.withSubOrder(1, () {
      mesh.addBox(0, wy, 0, length, 1.12, width, DesertPalette.cream);
    });

    // SubOrder 2: Flush outward dual desert stripes, panoramic windshield, side windows & entry door
    mesh.withSubOrder(2, () {
      final hx = length * 0.50;
      final hz = width * 0.50;

      // Dual retro stripes wrapping both sides & rear (zero nested-box z-fighting!)
      for (final posZ in [true, false]) {
        final zWall = posZ ? hz : -hz;
        mesh.addFlushRectOnZ(0, wy + 0.42, zWall, length * 0.98, 0.16, stripeColor, positiveZ: posZ);
        mesh.addFlushRectOnZ(0, wy + 0.56, zWall, length * 0.98, 0.07, DesertPalette.gold, positiveZ: posZ);

        // Side camper windows with glass sheen
        for (final wx in [-0.82, -0.05]) {
          mesh.addFlushRectOnZ(wx, wy + 0.80, zWall, 0.58, 0.30, VehicleParts.glassTint, positiveZ: posZ);
          mesh.addFlushRectOnZ(wx - 0.14, wy + 0.80, zWall + (posZ ? 0.008 : -0.008), 0.10, 0.24, VehicleParts.glassSheen, positiveZ: posZ);
        }
        // Cab side window
        mesh.addFlushRectOnZ(0.95, wy + 0.78, zWall, 0.46, 0.30, VehicleParts.glassTint, positiveZ: posZ);
      }

      // Entry door on right side (+Z)
      mesh.addFlushRectOnZ(0.45, wy + 0.52, hz + 0.004, 0.42, 0.86, DesertPalette.creamDark, positiveZ: true);
      mesh.addFlushRectOnZ(0.45, wy + 0.76, hz + 0.010, 0.26, 0.24, VehicleParts.glassTint, positiveZ: true);

      // Front panoramic windshield (+X) & rear stripe + window (-X)
      mesh.addFlushRectOnX(hx, wy + 0.78, 0, width * 0.84, 0.36, VehicleParts.glassTint, positiveX: true);
      mesh.addFlushRectOnX(hx + 0.008, wy + 0.78, -0.22, 0.14, 0.28, VehicleParts.glassSheen, positiveX: true);
      mesh.addFlushRectOnX(-hx, wy + 0.44, 0, width * 0.96, 0.16, stripeColor, positiveX: false);
      mesh.addFlushRectOnX(-hx, wy + 0.82, 0, width * 0.62, 0.28, VehicleParts.glassTint, positiveX: false);
    });

    // SubOrder 3: Rolled-up camp awning tube, rooftop AC unit, solar panel & rear roof ladder!
    mesh.withSubOrder(3, () {
      mesh.addBox(-0.22, wy + 1.04, width * 0.52, 1.88, 0.11, 0.11, DesertPalette.terracotta);
      mesh.addBox(-0.48, wy + 1.12, 0, 0.66, 0.20, 0.66, DesertPalette.creamDark);
      mesh.addBox(0.55, wy + 1.12, 0, 0.72, 0.06, 0.68, const Color(0xFF2D435C));
      // Rear ladder rungs
      mesh.addBox(-length * 0.52, wy + 0.60, 0.38, 0.06, 0.92, 0.05, DesertPalette.metal);
      mesh.addBox(-length * 0.52, wy + 0.60, 0.18, 0.06, 0.92, 0.05, DesertPalette.metal);
    });
  }
}
