import 'dart:math' as math;
import 'dart:ui';

import '../../engine/lighting.dart';
import '../../engine/mesh_builder.dart';
import '../../engine/mesh_parts.dart';
import '../../engine/vec3.dart';
import '../../theme/desert_palette.dart';

/// STAGE 6B: Oasis Souvenir Plaza with shimmering plunge pool, sculpted arched low-poly
/// desert palm fronds, terracotta sun loungers, pergola trellis, and Lv1–Lv5 upgrades!
class OasisPlazaBuilding {
  const OasisPlazaBuilding._();

  static void _addSculptedPalmTree(
    MeshBuilder mesh, {
    required double x,
    required double yBottom,
    required double z,
    required double scale,
    required double animTime,
    double leanX = 0.22,
  }) {
    final s = scale;
    // Gently curved 4-segment ringed palm trunk
    const segs = 4;
    const totalH = 2.25;
    double curX = x;
    double curY = yBottom;
    for (int i = 0; i < segs; i++) {
      final f0 = i / segs;
      final f1 = (i + 1) / segs;
      final r0 = (0.17 - f0 * 0.06) * s;
      final r1 = (0.17 - f1 * 0.06) * s;
      final segH = (totalH / segs) * s;
      mesh.addFrustum(
        curX,
        curY,
        z,
        r0,
        r0,
        r1,
        r1,
        segH + 0.04,
        6,
        i.isEven ? DesertPalette.wood : DesertPalette.woodLight,
      );
      curX += (leanX / segs) * s * (i + 0.5);
      curY += segH;
    }

    // Coconut cluster under crown
    for (final (cx, cz) in [(-0.08, 0.06), (0.08, 0.05), (0.0, -0.08)]) {
      mesh.addBox(curX + cx * s, curY - 0.08 * s, z + cz * s, 0.11 * s, 0.11 * s, 0.11 * s, DesertPalette.woodDark);
    }

    // 6 gracefully arched, drooping low-poly wedge fronds!
    final breeze = math.sin(animTime * 1.8 + x) * 0.04;
    const frondCount = 6;
    for (int i = 0; i < frondCount; i++) {
      final a = (i / frondCount) * math.pi * 2.0 + 0.3;
      final dx = math.cos(a);
      final dz = math.sin(a);
      final perpX = -dz * 0.18 * s;
      final perpZ = dx * 0.18 * s;

      final root = Vec3(curX, curY + 0.04 * s, z);
      final mid = Vec3(
        curX + dx * 0.58 * s,
        curY + (0.20 + breeze) * s,
        z + dz * 0.58 * s,
      );
      final tip = Vec3(
        curX + dx * 1.08 * s,
        curY - (0.18 - breeze) * s,
        z + dz * 1.08 * s,
      );

      final col = i.isEven ? DesertPalette.cactus : DesertPalette.vegetation;
      // Inner frond blade
      mesh.addQuad(
        root - Vec3(perpX * 0.4, 0, perpZ * 0.4),
        root + Vec3(perpX * 0.4, 0, perpZ * 0.4),
        mid + Vec3(perpX, 0, perpZ),
        mid - Vec3(perpX, 0, perpZ),
        col,
        doubleSided: true,
      );
      // Drooping outer frond tip triangle
      mesh.addTri(
        mid - Vec3(perpX, 0, perpZ),
        mid + Vec3(perpX, 0, perpZ),
        tip,
        DesertPalette.vegetation,
        doubleSided: true,
      );
    }
  }

  static void build(
    MeshBuilder mesh,
    Vec3 origin,
    int level,
    DesertLighting lighting,
    Color shadowCol,
    double animTime,
  ) {
    mesh.withTransform(origin, 0, () {
      mesh.addBoxShadow(0, 0, 4.0, 3.1, 2.4, lighting.shadowDirection, shadowCol);

      mesh.addBox(0, 0, 0, 4.0, 0.16, 3.1, DesertPalette.creamDark);

      final shimmer = 0.08 * math.sin(animTime * 2.5);
      final poolCol = Color.lerp(DesertPalette.water, DesertPalette.neonTurquoise, 0.18 + shimmer)!;
      mesh.addBox(
        0.32,
        0.16,
        0.32,
        2.15,
        0.06,
        1.50,
        poolCol,
        emissiveColor: DesertPalette.neonTurquoise,
        emissiveStrength: 0.45,
      );
      mesh.addBox(0.32, 0.16, -0.48, 2.32, 0.11, 0.15, DesertPalette.cream);
      mesh.addBox(0.32, 0.16, 1.12, 2.32, 0.11, 0.15, DesertPalette.cream);

      for (final lx in [-0.20, 0.85]) {
        mesh.addBox(lx, 0.16, -0.84, 0.54, 0.18, 0.36, DesertPalette.woodLight);
        mesh.addBox(lx, 0.34, -0.84, 0.46, 0.05, 0.30, DesertPalette.terracotta);
      }

      mesh.addBox(-1.32, 0.16, -0.26, 1.16, 1.72, 1.92, DesertPalette.terracotta, skipTop: true);
      mesh.addBox(-1.32, 1.88, -0.26, 1.34, 0.18, 2.10, DesertPalette.cream);
      MeshParts.addFramedFrontWindow(
        mesh,
        cx: -1.32,
        cy: 1.06,
        zWall: 0.70,
        width: 0.72,
        height: 0.66,
      );

      for (final x in [-0.42, 1.32]) {
        mesh.addBox(x, 0.16, -1.10, 0.15, 2.04, 0.15, DesertPalette.wood, skipTop: true);
      }
      for (final rx in [-0.20, 0.22, 0.64, 1.06]) {
        mesh.addBox(rx, 2.20, -0.96, 0.10, 0.08, 0.64, DesertPalette.woodDark);
      }
      mesh.addBox(0.45, 2.28, -1.10, 2.05, 0.56, 0.22, DesertPalette.woodLight);
      mesh.addFrontSignText(
        0.45,
        2.56,
        -0.98,
        1.90,
        0.44,
        'OASIS',
        DesertPalette.cream,
        glowColor: DesertPalette.neonTurquoise,
      );

      mesh.addBox(1.70, 0.16, 1.18, 0.12, 1.12, 0.12, DesertPalette.woodDark, skipTop: true);
      mesh.addBox(
        1.70,
        1.28,
        1.18,
        0.22,
        0.24,
        0.22,
        DesertPalette.cream,
        emissiveColor: DesertPalette.windowNight,
        emissiveStrength: 1.0,
      );

      if (level >= 2) {
        _addSculptedPalmTree(
          mesh,
          x: 1.56,
          yBottom: 0.16,
          z: -0.84,
          scale: 1.0,
          animTime: animTime,
          leanX: 0.18,
        );
        MeshParts.addPottedCactus(mesh, cx: -1.60, yBottom: 0.16, cz: 1.08);
      }

      if (level >= 3) {
        MeshParts.addPatioUmbrellaTable(
          mesh,
          cx: -1.35,
          yBottom: 0.16,
          cz: 1.25,
          umbrellaColor: DesertPalette.turquoise,
          scale: 0.80,
        );
      }

      // Level 4+: Second companion palm tree + red sandstone pool waterfall rock!
      if (level >= 4) {
        _addSculptedPalmTree(
          mesh,
          x: -1.85,
          yBottom: 0.16,
          z: -1.15,
          scale: 0.84,
          animTime: animTime + 1.2,
          leanX: -0.16,
        );
        mesh.addFrustum(1.42, 0.16, 0.28, 0.34, 0.30, 0.18, 0.16, 0.55, 6, DesertPalette.sandstone);
      }

      // Level 5: Overhead evening oasis lantern festoon wire & golden sun crest!
      if (level >= 5) {
        mesh.addSaggingWire(
          const Vec3(-1.32, 2.04, 0.65),
          const Vec3(1.70, 1.42, 1.18),
          DesertPalette.woodDark,
          sag: 0.18,
          bulbCount: 4,
          bulbGlowColor: DesertPalette.neonTurquoise,
        );
        mesh.addFrustum(
          0.45,
          2.76,
          -1.10,
          0.32,
          0.12,
          0.08,
          0.08,
          0.36,
          6,
          DesertPalette.gold,
          emissiveColor: DesertPalette.gold,
          emissiveStrength: 0.9,
        );
      }

      mesh.addGlow(const Vec3(0.32, 1.0, 0.32), DesertPalette.neonTurquoise, radius: 32, intensity: 0.65);
    });
  }
}
