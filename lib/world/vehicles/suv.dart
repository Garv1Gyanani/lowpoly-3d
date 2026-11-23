import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../theme/desert_palette.dart';
import 'vehicle_parts.dart';

/// Rugged desert expedition SUV with sloped windshield, front bull-bar guard,
/// rear-mounted spare tire, and loaded roof rack (tent roll, duffel & jerrycan).
class SuvModel {
  const SuvModel._();

  static const double length = 2.28;
  static const double width = 1.08;
  static const double bodyHeight = 0.66;

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

    // SubOrder 1: Main SUV lower chassis + front bull-bar + rear spare tire
    mesh.withSubOrder(1, () {
      mesh.addBox(0, wy, 0, length, 0.46, width, bodyColor);
      // Front off-road bull-bar guard
      mesh.addBox(length * 0.54, wy + 0.14, 0, 0.07, 0.24, width * 0.56, DesertPalette.metalDark);
      // Rear-mounted spare wheel & cream center cap
      mesh.addBox(-length * 0.54, wy + 0.22, 0, 0.16, 0.42, 0.42, DesertPalette.asphalt);
    });

    // SubOrder 2: Flush trim + spare tire cover cap
    mesh.withSubOrder(2, () {
      mesh.addFlushRectOnX(
        -length * 0.62,
        wy + 0.43,
        0,
        0.22,
        0.22,
        DesertPalette.cream,
        positiveX: false,
      );
      for (final posZ in [true, false]) {
        mesh.addFlushRectOnZ(
          0,
          wy + 0.30,
          posZ ? width * 0.5 : -width * 0.5,
          length * 0.88,
          0.07,
          DesertPalette.asphalt,
          positiveZ: posZ,
        );
      }
    });

    // SubOrder 3: Sloped SUV cabin + roof expedition rack & strapped camping gear
    mesh.withSubOrder(3, () {
      mesh.addTaperedBox(
        cx: -0.18,
        yBottom: wy + 0.46,
        cz: 0,
        bottomLen: length * 0.70,
        bottomWid: width * 0.90,
        topLen: length * 0.56,
        topWid: width * 0.80,
        height: 0.48,
        topShiftX: -0.06,
        color: bodyColor,
        topColor: DesertPalette.cream,
      );
      for (final mz in [-width * 0.52, width * 0.52]) {
        mesh.addBox(0.46, wy + 0.52, mz, 0.08, 0.08, 0.11, DesertPalette.metalDark);
      }
      // Roof rack + terracotta duffel + rolled olive tent + amber fuel can
      mesh.addBox(-0.24, wy + 0.94, 0, 1.12, 0.07, width * 0.74, DesertPalette.metalDark);
      mesh.addBox(-0.46, wy + 1.01, -0.14, 0.50, 0.22, 0.34, DesertPalette.terracotta);
      mesh.addBox(0.06, wy + 1.01, 0.14, 0.46, 0.18, 0.24, DesertPalette.vegetation);
      mesh.addBox(-0.46, wy + 1.01, 0.22, 0.22, 0.20, 0.14, DesertPalette.gold);
    });

    // SubOrder 4 & 5: Sloped windows with reflection
    mesh.addCabinWindows(
      cx: -0.18,
      yBottom: wy + 0.46,
      cz: 0,
      bottomLen: length * 0.70,
      bottomWid: width * 0.90,
      topLen: length * 0.56,
      topWid: width * 0.80,
      height: 0.48,
      topShiftX: -0.06,
      glassColor: VehicleParts.glassTint,
      sheenColor: VehicleParts.glassSheen,
      subOrder: 4,
    );
  }
}
