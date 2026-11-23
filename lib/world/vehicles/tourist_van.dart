import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../theme/desert_palette.dart';
import 'vehicle_parts.dart';

/// Vintage two-tone VW-style desert tourist bus with flush wraparound windows,
/// front nose spare wheel, wooden roof rack, striped surfboard & red cooler.
class TouristVanModel {
  const TouristVanModel._();

  static const double length = 2.55;
  static const double width = 1.12;
  static const double bodyHeight = 0.98;

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

    // SubOrder 1: Two-tone lower body + upper cream cabin body (non-overlapping stacked boxes!)
    mesh.withSubOrder(1, () {
      mesh.addBox(0, wy, 0, length, 0.44, width, bodyColor);
      // Front nose spare tire emblem
      mesh.addBox(length * 0.52, wy + 0.20, 0, 0.11, 0.34, 0.34, DesertPalette.asphalt);
    });

    // SubOrder 3: Sloped upper cream camper roof + wraparound windows + roof cargo!
    mesh.withSubOrder(3, () {
      mesh.addTaperedBox(
        cx: -0.02,
        yBottom: wy + 0.44,
        cz: 0,
        bottomLen: length * 0.98,
        bottomWid: width * 0.98,
        topLen: length * 0.88,
        topWid: width * 0.88,
        height: 0.48,
        color: DesertPalette.cream,
        topColor: DesertPalette.cream,
      );
      for (final mz in [-width * 0.53, width * 0.53]) {
        mesh.addBox(length * 0.34, wy + 0.50, mz, 0.08, 0.08, 0.10, DesertPalette.metalDark);
      }

      // Wooden roof rack + striped road-trip surfboard + red picnic cooler
      mesh.addBox(-0.20, wy + 0.92, 0, 1.40, 0.07, width * 0.78, DesertPalette.wood);
      mesh.addBox(-0.12, wy + 0.99, 0.16, 1.68, 0.07, 0.32, DesertPalette.gold);
      mesh.addBox(-0.12, wy + 1.06, 0.16, 1.38, 0.03, 0.10, DesertPalette.awningRed);
      mesh.addBox(-0.36, wy + 0.99, -0.22, 0.44, 0.22, 0.28, DesertPalette.awningRed);
    });

    // SubOrder 4 & 5: Flush wraparound camper windows with sheen
    mesh.addCabinWindows(
      cx: -0.02,
      yBottom: wy + 0.44,
      cz: 0,
      bottomLen: length * 0.98,
      bottomWid: width * 0.98,
      topLen: length * 0.88,
      topWid: width * 0.88,
      height: 0.48,
      glassColor: VehicleParts.glassTint,
      sheenColor: VehicleParts.glassSheen,
      insetBottom: 0.16,
      insetTop: 0.16,
      sideInset: 0.08,
      subOrder: 4,
    );
  }
}
