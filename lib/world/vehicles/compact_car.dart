import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../theme/desert_palette.dart';
import 'vehicle_parts.dart';

/// Sleek low-poly retro desert sedan with true sloped windshields, glass sheen,
/// chrome belt trim, side mirrors, and zero-pop sort layers.
class CompactCarModel {
  const CompactCarModel._();

  static const double length = 1.92;
  static const double width = 0.98;
  static const double bodyHeight = 0.52;

  static void buildLocal(
    MeshBuilder mesh, {
    required Color bodyColor,
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
    );

    // SubOrder 1: Lower sedan body
    mesh.withSubOrder(1, () {
      mesh.addBox(0, wy, 0, length, 0.40, width, bodyColor);
    });

    // SubOrder 2: Flush chrome side trim strips above the wheels
    mesh.withSubOrder(2, () {
      for (final posZ in [true, false]) {
        mesh.addFlushRectOnZ(
          0,
          wy + 0.28,
          posZ ? width * 0.5 : -width * 0.5,
          length * 0.88,
          0.06,
          DesertPalette.creamDark,
          positiveZ: posZ,
        );
      }
    });

    // SubOrder 3: Sleek sloped trapezoidal cabin + cream roof cap + side mirrors
    mesh.withSubOrder(3, () {
      mesh.addTaperedBox(
        cx: -0.06,
        yBottom: wy + 0.40,
        cz: 0,
        bottomLen: length * 0.58,
        bottomWid: width * 0.88,
        topLen: length * 0.36,
        topWid: width * 0.74,
        height: 0.42,
        topShiftX: -0.04,
        color: bodyColor,
        topColor: DesertPalette.cream,
      );
      for (final mz in [-width * 0.50, width * 0.50]) {
        mesh.addBox(0.24, wy + 0.44, mz, 0.08, 0.07, 0.10, DesertPalette.metalDark);
      }
    });

    // SubOrder 4 & 5: Flush sloped windshield & side windows with diagonal glass reflection!
    mesh.addCabinWindows(
      cx: -0.06,
      yBottom: wy + 0.40,
      cz: 0,
      bottomLen: length * 0.58,
      bottomWid: width * 0.88,
      topLen: length * 0.36,
      topWid: width * 0.74,
      height: 0.42,
      topShiftX: -0.04,
      glassColor: VehicleParts.glassTint,
      sheenColor: VehicleParts.glassSheen,
      subOrder: 4,
    );
  }
}
