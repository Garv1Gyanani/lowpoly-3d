import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../theme/desert_palette.dart';
import 'vehicle_parts.dart';

/// Classic retro Winnebago-style desert Camper RV with a true sculpted cab-over
/// sleeping bunk overhang, sloped cab windshield, dual retro stripes, rolled awning,
/// rooftop AC, solar panel, and rear ladder!
class CamperRvModel {
  const CamperRvModel._();

  static const double length = 3.05;
  static const double width = 1.18;
  static const double bodyHeight = 1.28;

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
      grillHeight: 0.20,
    );

    // SubOrder 1: Stepped lower front hood/chassis + rear camper coach body + cab-over bunk!
    mesh.withSubOrder(1, () {
      // Full-length lower skirt & engine hood (+X nose)
      mesh.addBox(0, wy, 0, length, 0.44, width, DesertPalette.cream);
      // Main rear living coach (leaves front +X cab cutout)
      mesh.addBox(-0.34, wy + 0.44, 0, 2.36, 0.72, width, DesertPalette.cream);
      // Sloped driver cab under the bunk overhang
      mesh.addTaperedBox(
        cx: 1.06,
        yBottom: wy + 0.44,
        cz: 0,
        bottomLen: 0.56,
        bottomWid: width * 0.94,
        topLen: 0.40,
        topWid: width * 0.88,
        height: 0.38,
        topShiftX: -0.06,
        color: DesertPalette.cream,
      );
      // Iconic protruding cab-over sleeping bunk nose overhang!
      mesh.addTaperedBox(
        cx: 1.04,
        yBottom: wy + 0.82,
        cz: 0,
        bottomLen: 0.68,
        bottomWid: width * 0.96,
        topLen: 0.56,
        topWid: width * 0.92,
        height: 0.34,
        topShiftX: -0.04,
        color: DesertPalette.cream,
        topColor: DesertPalette.cream,
      );
    });

    // SubOrder 2: Flush retro stripes, cab windshield, bunk front window, side windows & door
    mesh.withSubOrder(2, () {
      final rearX = -length * 0.50;
      final hz = width * 0.50;

      for (final posZ in [true, false]) {
        final zWall = posZ ? hz : -hz;
        mesh.addFlushRectOnZ(0, wy + 0.34, zWall, length * 0.96, 0.14, stripeColor, positiveZ: posZ);
        mesh.addFlushRectOnZ(-0.34, wy + 0.48, zWall, 2.32, 0.07, DesertPalette.gold, positiveZ: posZ);

        for (final wx in [-0.96, -0.18]) {
          mesh.addFlushRectOnZ(wx, wy + 0.82, zWall, 0.56, 0.28, VehicleParts.glassTint, positiveZ: posZ);
          mesh.addFlushRectOnZ(
            wx - 0.14,
            wy + 0.82,
            zWall + (posZ ? 0.008 : -0.008),
            0.10,
            0.22,
            VehicleParts.glassSheen,
            positiveZ: posZ,
          );
        }
      }

      // Entry door on right side (+Z)
      mesh.addFlushRectOnZ(0.46, wy + 0.54, hz + 0.004, 0.40, 0.84, DesertPalette.creamDark, positiveZ: true);
      mesh.addFlushRectOnZ(0.46, wy + 0.78, hz + 0.010, 0.24, 0.22, VehicleParts.glassTint, positiveZ: true);

      // Front bunk peek window & rear stripe + window
      mesh.addFlushRectOnX(1.34, wy + 0.98, 0, width * 0.68, 0.14, VehicleParts.glassTint, positiveX: true);
      mesh.addFlushRectOnX(rearX, wy + 0.36, 0, width * 0.96, 0.15, stripeColor, positiveX: false);
      mesh.addFlushRectOnX(rearX, wy + 0.82, 0, width * 0.62, 0.28, VehicleParts.glassTint, positiveX: false);
    });

    // SubOrder 3: Cab wraparound windows + rooftop awning, AC unit, solar panel & ladder
    mesh.addCabinWindows(
      cx: 1.06,
      yBottom: wy + 0.44,
      cz: 0,
      bottomLen: 0.56,
      bottomWid: width * 0.94,
      topLen: 0.40,
      topWid: width * 0.88,
      height: 0.38,
      topShiftX: -0.06,
      glassColor: VehicleParts.glassTint,
      sheenColor: VehicleParts.glassSheen,
      subOrder: 3,
    );

    mesh.withSubOrder(4, () {
      mesh.addBox(-0.34, wy + 1.06, width * 0.52, 1.88, 0.11, 0.11, DesertPalette.terracotta);
      mesh.addBox(-0.62, wy + 1.16, 0, 0.64, 0.20, 0.64, DesertPalette.creamDark);
      mesh.addBox(0.24, wy + 1.16, 0, 0.74, 0.06, 0.68, const Color(0xFF2D435C));
      // Amber clearance lights on cab-over bunk brow
      for (final lz in [-0.36, 0.0, 0.36]) {
        mesh.addBox(1.30, wy + 1.13, lz, 0.06, 0.05, 0.08, DesertPalette.gold);
      }
      mesh.addBox(-length * 0.52, wy + 0.62, 0.38, 0.06, 0.92, 0.05, DesertPalette.metal);
      mesh.addBox(-length * 0.52, wy + 0.62, 0.18, 0.06, 0.92, 0.05, DesertPalette.metal);
    });
  }
}
