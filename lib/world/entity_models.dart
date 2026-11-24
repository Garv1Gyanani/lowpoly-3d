import 'dart:math' as math;

import '../engine/lighting.dart';
import '../engine/mesh_builder.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import 'characters/visitor_character.dart';
import 'props/placed_decoration_models.dart';
import 'vehicles/camper_rv.dart';
import 'vehicles/compact_car.dart';
import 'vehicles/pickup_truck.dart';
import 'vehicles/suv.dart';
import 'vehicles/tourist_van.dart';

/// Dispatches vehicles, walking visitors, and placed decorations to their modular files,
/// wrapping moving entities in deterministic 3D sort groups so parts NEVER pop while moving.
class EntityModels {
  const EntityModels._();

  static bool isAnimatedDecoration(PlacedDecoration deco) =>
      PlacedDecorationModels.isAnimated(deco);

  static void buildVehicle(
    MeshBuilder mesh,
    VehicleEntity v,
    DesertLighting lighting,
  ) {
    final shadowCol = lighting.shadowColor;
    final contactCol = lighting.contactShadowColor;

    final (len, wid, bodyH) = switch (v.kind) {
      VehicleKind.compactCar => (
          CompactCarModel.length,
          CompactCarModel.width,
          CompactCarModel.bodyHeight,
        ),
      VehicleKind.pickupTruck => (
          PickupTruckModel.length,
          PickupTruckModel.width,
          PickupTruckModel.bodyHeight,
        ),
      VehicleKind.suv => (
          SuvModel.length,
          SuvModel.width,
          SuvModel.bodyHeight,
        ),
      VehicleKind.camperRv => (
          CamperRvModel.length,
          CamperRvModel.width,
          CamperRvModel.bodyHeight,
        ),
      VehicleKind.touristVan => (
          TouristVanModel.length,
          TouristVanModel.width,
          TouristVanModel.bodyHeight,
        ),
    };

    // Oriented two-stage ground shadow (tight wheel contact AO + directional sun cast shadow)
    final hl = len * 0.50;
    final hw = wid * 0.52;
    final sOff = lighting.shadowDirection * ((bodyH + 0.4) * 0.34);
    final c = math.cos(v.yaw);
    final s = math.sin(v.yaw);

    Vec3 rotCast(double lx, double lz) => Vec3(
          v.position.x + lx * c - lz * s + sOff.x,
          0.038,
          v.position.z + lx * s + lz * c + sOff.z,
        );
    Vec3 rotContact(double lx, double lz) => Vec3(
          v.position.x + lx * c - lz * s,
          0.039,
          v.position.z + lx * s + lz * c,
        );

    mesh.addGroundPoly(
      [rotCast(-hl, -hw), rotCast(-hl, hw), rotCast(hl, hw), rotCast(hl, -hw)],
      shadowCol,
      layer: RenderLayer.shadow,
      unlit: true,
    );
    mesh.addGroundPoly(
      [
        rotContact(-hl * 0.96, -hw * 0.96),
        rotContact(-hl * 0.96, hw * 0.96),
        rotContact(hl * 0.96, hw * 0.96),
        rotContact(hl * 0.96, -hw * 0.96),
      ],
      contactCol,
      layer: RenderLayer.shadow,
      depthBias: -0.02,
      unlit: true,
    );

    final headlightsOn = v.phase != VehiclePhase.parked;
    final reversing = v.phase == VehiclePhase.backingOut;

    mesh.withSortGroup(v.position + const Vec3(0, 0.55, 0), () {
      mesh.withTransform(v.position, v.yaw, () {
        switch (v.kind) {
          case VehicleKind.compactCar:
            CompactCarModel.buildLocal(
              mesh,
              bodyColor: v.bodyColor,
              headlightsOn: headlightsOn,
              reversing: reversing,
            );
          case VehicleKind.pickupTruck:
            PickupTruckModel.buildLocal(
              mesh,
              bodyColor: v.bodyColor,
              headlightsOn: headlightsOn,
              reversing: reversing,
            );
          case VehicleKind.suv:
            SuvModel.buildLocal(
              mesh,
              bodyColor: v.bodyColor,
              headlightsOn: headlightsOn,
              reversing: reversing,
            );
          case VehicleKind.camperRv:
            CamperRvModel.buildLocal(
              mesh,
              stripeColor: v.bodyColor,
              headlightsOn: headlightsOn,
              reversing: reversing,
            );
          case VehicleKind.touristVan:
            TouristVanModel.buildLocal(
              mesh,
              bodyColor: v.bodyColor,
              headlightsOn: headlightsOn,
              reversing: reversing,
            );
        }
      });
    });
  }

  static void buildVisitor(
    MeshBuilder mesh,
    VisitorEntity visitor,
    DesertLighting lighting,
  ) {
    VisitorCharacter.build(mesh, visitor, lighting);
  }

  static void buildDecoration(
    MeshBuilder mesh,
    PlacedDecoration deco,
    DesertLighting lighting,
    double animTime,
  ) {
    PlacedDecorationModels.build(mesh, deco, lighting, animTime);
  }
}
