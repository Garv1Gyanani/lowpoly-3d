import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../theme/desert_palette.dart';
import 'vehicle_parts.dart';

/// Vintage Utah ranch pickup truck with sloped windshield, chrome trim, wooden stake-bed rails,
/// tied-down supply crate, red fuel jerrycan & zero-popping sort layers.
class PickupTruckModel {
  const PickupTruckModel._();

  static const double length = 2.40;
  static const double width = 1.08;
  static const double bodyHeight = 0.62;

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

    // SubOrder 1: Lower truck chassis
    mesh.withSubOrder(1, () {
      mesh.addBox(0, wy, 0, length, 0.44, width, bodyColor);
    });

    // SubOrder 2: Flush chrome body side molding above wheel height
    mesh.withSubOrder(2, () {
      for (final posZ in [true, false]) {
        mesh.addFlushRectOnZ(
          0,
          wy + 0.30,
          posZ ? width * 0.5 : -width * 0.5,
          length * 0.90,
          0.06,
          DesertPalette.creamDark,
          positiveZ: posZ,
        );
      }
    });

    // SubOrder 3: Sloped pickup cab + wooden truck bed floor, stake rails & cargo!
    mesh.withSubOrder(3, () {
      // Dark wood bed liner + slatted timber side rails
      mesh.addBox(-0.62, wy + 0.44, 0, 1.04, 0.05, width * 0.86, DesertPalette.woodDark);
      for (final rz in [-width * 0.45, width * 0.45]) {
        mesh.addBox(-0.62, wy + 0.46, rz, 1.06, 0.12, 0.07, DesertPalette.woodLight);
        for (final px in [-1.06, -0.62, -0.18]) {
          mesh.addBox(px, wy + 0.44, rz, 0.07, 0.22, 0.07, DesertPalette.woodDark);
        }
      }
      // Wooden supply crate & red fuel jerrycan in the bed
      mesh.addBox(-0.56, wy + 0.49, -0.16, 0.48, 0.34, 0.42, DesertPalette.wood);
      mesh.addBox(-0.56, wy + 0.83, -0.16, 0.50, 0.05, 0.44, DesertPalette.woodLight);
      mesh.addBox(-0.90, wy + 0.49, 0.20, 0.24, 0.32, 0.16, DesertPalette.awningRed);
      mesh.addBox(-0.90, wy + 0.81, 0.20, 0.09, 0.06, 0.09, DesertPalette.gold);

      // Sloped ranch pickup cab + cream roof + amber cab marker lights
      mesh.addTaperedBox(
        cx: 0.32,
        yBottom: wy + 0.44,
        cz: 0,
        bottomLen: 0.94,
        bottomWid: width * 0.90,
        topLen: 0.72,
        topWid: width * 0.80,
        height: 0.54,
        topShiftX: -0.06,
        color: bodyColor,
        topColor: DesertPalette.cream,
      );
      for (final mz in [-width * 0.52, width * 0.52]) {
        mesh.addBox(0.56, wy + 0.52, mz, 0.08, 0.08, 0.11, DesertPalette.metalDark);
      }
    });

    // SubOrder 4 & 5: Sloped cab windows with sunlit reflection streak
    mesh.addCabinWindows(
      cx: 0.32,
      yBottom: wy + 0.44,
      cz: 0,
      bottomLen: 0.94,
      bottomWid: width * 0.90,
      topLen: 0.72,
      topWid: width * 0.80,
      height: 0.54,
      topShiftX: -0.06,
      glassColor: VehicleParts.glassTint,
      sheenColor: VehicleParts.glassSheen,
      subOrder: 4,
    );
  }
}
