import 'dart:ui';

import '../../engine/mesh_builder.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// Shared zero-popping low-poly vehicle wheels, flush hubcaps, chrome bumpers,
/// front radiator grill, license plates, headlights, permanent red taillights,
/// and dedicated white reverse lenses.
class VehicleParts {
  const VehicleParts._();

  static const double wheelY = 0.18;
  static const Color glassTint = Color(0xFF435F70);
  static const Color glassSheen = Color(0xFF7FA3B5);

  static void addWheelsAndBumpers(
    MeshBuilder mesh, {
    required double length,
    required double width,
    required bool headlightsOn,
    bool reversing = false,
    double grillHeight = 0.16,
  }) {
    // SubOrder 1: Tires & chrome bumpers (sorted cleanly by localDepth with chassis)
    mesh.withSubOrder(1, () {
      for (final wx in [-length * 0.31, length * 0.31]) {
        for (final wz in [-width * 0.48, width * 0.48]) {
          mesh.addBox(wx, 0.0, wz, 0.40, 0.36, 0.16, DesertPalette.asphalt);
          // Flush outer hubcap quad (subOrder 2 -> always cleanly on outside of tire!)
          final isPosZ = wz > 0;
          mesh.addFlushRectOnZ(
            wx,
            0.18,
            wz + (isPosZ ? 0.08 : -0.08),
            0.20,
            0.20,
            DesertPalette.creamDark,
            positiveZ: isPosZ,
            subOrder: 2,
          );
          mesh.addFlushRectOnZ(
            wx,
            0.18,
            wz + (isPosZ ? 0.092 : -0.092),
            0.08,
            0.08,
            DesertPalette.metalDark,
            positiveZ: isPosZ,
            subOrder: 2,
          );
        }
      }

      // Front & rear chrome bumpers
      mesh.addBox(length * 0.515, wheelY + 0.02, 0, 0.09, 0.12, width * 0.96, DesertPalette.metal);
      mesh.addBox(-length * 0.515, wheelY + 0.02, 0, 0.09, 0.12, width * 0.96, DesertPalette.metal);
      // Small chrome exhaust pipe at rear right
      mesh.addBox(-length * 0.54, wheelY - 0.02, width * 0.28, 0.14, 0.07, 0.07, DesertPalette.metalDark);
    });

    // SubOrder 2: Flush outward surface decals on +X front & -X rear (ZERO z-fighting!)
    mesh.withSubOrder(2, () {
      final frontX = length * 0.50;
      final rearX = -length * 0.50;

      // Radiator grill + center chrome slat
      mesh.addFlushRectOnX(
        frontX,
        wheelY + 0.25,
        0,
        width * 0.42,
        grillHeight,
        DesertPalette.metalDark,
        positiveX: true,
      );
      mesh.addFlushRectOnX(
        frontX + 0.008,
        wheelY + 0.25,
        0,
        width * 0.36,
        0.04,
        DesertPalette.creamDark,
        positiveX: true,
      );

      // Rear Utah-style cream license plate
      mesh.addFlushRectOnX(
        rearX,
        wheelY + 0.22,
        0,
        width * 0.26,
        0.13,
        DesertPalette.cream,
        positiveX: false,
      );

      // Headlights (+X) & Permanent red taillights + separate white reverse lenses (-X)
      const headCol = Color(0xFFFFF2C2);
      const tailCol = Color(0xFFFF4D42);
      const revCol = Color(0xFFFFFFFF);
      for (final wz in [-width * 0.34, width * 0.34]) {
        mesh.addFlushRectOnX(
          frontX,
          wheelY + 0.27,
          wz,
          0.18,
          0.13,
          headCol,
          positiveX: true,
          emissiveColor: headCol,
          emissiveStrength: headlightsOn ? 1.0 : 0.25,
        );
        mesh.addFlushRectOnX(
          rearX,
          wheelY + 0.27,
          wz,
          0.16,
          0.12,
          tailCol,
          positiveX: false,
          emissiveColor: tailCol,
          emissiveStrength: 0.95,
        );
        // Dedicated inner reverse lens (glows crisp white only while backing out!)
        final innerZ = wz * 0.62;
        mesh.addFlushRectOnX(
          rearX,
          wheelY + 0.27,
          innerZ,
          0.08,
          0.09,
          reversing ? revCol : DesertPalette.creamDark,
          positiveX: false,
          emissiveColor: reversing ? revCol : null,
          emissiveStrength: reversing ? 1.0 : 0.0,
          emissiveNightOnly: false,
        );
      }
    });

    if (headlightsOn) {
      mesh.addGlow(
        Vec3(length * 0.68, wheelY + 0.25, 0),
        const Color(0xFFFFF0B8),
        radius: 28,
        intensity: 0.78,
      );
    }
  }
}
