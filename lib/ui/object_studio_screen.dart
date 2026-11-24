import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../engine/camera_3d.dart';
import '../engine/lighting.dart';
import '../engine/mesh_builder.dart';
import '../engine/renderer_3d.dart';
import '../engine/vec3.dart';
import '../models/game_models.dart';
import '../theme/desert_palette.dart';
import '../world/building_models.dart';
import '../world/entity_models.dart';
import '../world/props/desert_flora_and_rocks.dart';
import '../world/props/desert_windmill.dart';
import '../world/props/roadside_welcome_sign.dart';
import '../world/terrain/monument_mesas.dart';
import 'game_hud_widgets.dart';
import 'game_icons.dart';

enum _StudioAssetKind {
  vendorStall,
  outpostMart,
  foodStand,
  desertDiner,
  gasStation,
  desertMotel,
  lookoutCamp,
  oasisPlaza,
  westMittenButte,
  desertWindmill,
  welcomeSign,
  pickupTruck,
  camperRv,
  touristVan,
  compactCar,
  suv,
  saguaroCluster,
}

class _StudioAssetEntry {
  const _StudioAssetEntry({
    required this.kind,
    required this.label,
    required this.filePath,
    required this.cameraDistance,
    required this.targetY,
    this.hasLevels = false,
  });

  final _StudioAssetKind kind;
  final String label;
  final String filePath;
  final double cameraDistance;
  final double targetY;
  final bool hasLevels;
}

const List<_StudioAssetEntry> _studioCatalog = [
  _StudioAssetEntry(
    kind: _StudioAssetKind.vendorStall,
    label: 'Cart / Stall',
    filePath: 'buildings/vendor_cart.dart',
    cameraDistance: 11.5,
    targetY: 1.4,
    hasLevels: true,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.outpostMart,
    label: 'Outpost Mart',
    filePath: 'buildings/outpost_mart.dart',
    cameraDistance: 15.0,
    targetY: 2.0,
    hasLevels: true,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.foodStand,
    label: 'Taco & Cafe',
    filePath: 'buildings/food_stand.dart',
    cameraDistance: 13.0,
    targetY: 1.7,
    hasLevels: true,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.desertDiner,
    label: 'Desert Diner',
    filePath: 'buildings/desert_diner.dart',
    cameraDistance: 17.5,
    targetY: 2.3,
    hasLevels: true,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.gasStation,
    label: 'Gas Station',
    filePath: 'buildings/gas_station.dart',
    cameraDistance: 18.0,
    targetY: 2.2,
    hasLevels: true,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.desertMotel,
    label: 'Red Rock Motel',
    filePath: 'buildings/desert_motel.dart',
    cameraDistance: 20.0,
    targetY: 2.8,
    hasLevels: true,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.lookoutCamp,
    label: 'Lookout & Camp',
    filePath: 'buildings/lookout_camp.dart',
    cameraDistance: 20.5,
    targetY: 3.1,
    hasLevels: true,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.oasisPlaza,
    label: 'Oasis Plaza',
    filePath: 'buildings/oasis_plaza.dart',
    cameraDistance: 14.5,
    targetY: 1.5,
    hasLevels: true,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.westMittenButte,
    label: 'West Mitten Butte',
    filePath: 'terrain/monument_mesas.dart',
    cameraDistance: 36.0,
    targetY: 6.5,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.desertWindmill,
    label: 'Windmill',
    filePath: 'props/desert_windmill.dart',
    cameraDistance: 16.5,
    targetY: 3.0,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.welcomeSign,
    label: 'Welcome Sign',
    filePath: 'props/roadside_welcome_sign.dart',
    cameraDistance: 10.5,
    targetY: 1.5,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.pickupTruck,
    label: 'Pickup Truck',
    filePath: 'vehicles/pickup_truck.dart',
    cameraDistance: 7.5,
    targetY: 0.7,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.camperRv,
    label: 'Camper RV',
    filePath: 'vehicles/camper_rv.dart',
    cameraDistance: 8.5,
    targetY: 0.9,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.touristVan,
    label: 'Tourist Van',
    filePath: 'vehicles/tourist_van.dart',
    cameraDistance: 8.0,
    targetY: 0.8,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.compactCar,
    label: 'Compact Car',
    filePath: 'vehicles/compact_car.dart',
    cameraDistance: 7.0,
    targetY: 0.6,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.suv,
    label: 'Desert SUV',
    filePath: 'vehicles/suv.dart',
    cameraDistance: 7.5,
    targetY: 0.7,
  ),
  _StudioAssetEntry(
    kind: _StudioAssetKind.saguaroCluster,
    label: 'Cactus & Rocks',
    filePath: 'props/desert_flora_and_rocks.dart',
    cameraDistance: 8.0,
    targetY: 1.0,
  ),
];

/// Interactive 360-degree turntable inspector supporting all 5 building upgrade levels (Lv1–Lv5),
/// built cleanly on pure `flutter/widgets.dart` with carved-wood game styling.
class ObjectStudioScreen extends StatefulWidget {
  const ObjectStudioScreen({super.key});

  @override
  State<ObjectStudioScreen> createState() => _ObjectStudioScreenState();
}

class _StudioRepaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _ObjectStudioScreenState extends State<ObjectStudioScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _StudioRepaint _repaint = _StudioRepaint();
  Duration _lastTick = Duration.zero;
  double _animTime = 0.0;

  int _selectedIndex = 0;
  int _level = 1;
  double _timeOfDay = 0.40;
  bool _autoRotate = true;
  late final Camera3D _camera;

  _StudioAssetEntry get _asset => _studioCatalog[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _camera = Camera3D(
      yaw: -0.45,
      pitch: 0.32,
      distance: _asset.cameraDistance,
      target: Vec3(0, _asset.targetY, 0),
    );
    _ticker = createTicker((elapsed) {
      if (_lastTick == Duration.zero) {
        _lastTick = elapsed;
        return;
      }
      final dt = ((elapsed - _lastTick).inMicroseconds / 1000000.0).clamp(0.0, 0.05);
      _lastTick = elapsed;
      _animTime += dt;
      if (_autoRotate) {
        _camera.yaw += dt * 0.45;
      }
      // Repaints only the 3D canvas (zero 60 Hz widget tree rebuilds!)
      _repaint.ping();
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _selectAsset(int index) {
    setState(() {
      _selectedIndex = index;
      _camera.distance = _asset.cameraDistance;
      _camera.target = Vec3(0, _asset.targetY, 0);
      _camera.pitch = 0.30;
    });
    _repaint.ping();
  }

  @override
  Widget build(BuildContext context) {
    final lighting = DesertLighting.fromTime(_timeOfDay);

    return ColoredBox(
      color: DesertPalette.sky,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final factor = event.scrollDelta.dy > 0 ? 1.08 : 0.92;
                _camera.distance = (_camera.distance * factor).clamp(4.5, 48.0);
                _repaint.ping();
              }
            },
            child: GestureDetector(
              onPanStart: (_) {
                if (_autoRotate) setState(() => _autoRotate = false);
              },
              onPanUpdate: (details) {
                _camera.yaw -= details.delta.dx * 0.012;
                _camera.pitch = (_camera.pitch + details.delta.dy * 0.008).clamp(0.08, 1.20);
                _repaint.ping();
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _StudioPainter(
                    repaint: _repaint,
                    asset: _asset,
                    level: _level,
                    camera: _camera,
                    lighting: lighting,
                    getAnimTime: () => _animTime,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(
                      children: [
                        GameBevelButton(
                          onTap: () => Navigator.of(context).maybePop(),
                          radius: 14,
                          bevelDepth: 3.0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const GameIcon(GameIconKind.arrowBack, size: 16, color: Color(0xFFFFF2D4)),
                              const SizedBox(width: 6),
                              Text(
                                'Back',
                                style: DesertTypography.display(size: 11.5, color: const Color(0xFFFFF2D4)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: GameHudColors.parchment.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: GameHudColors.woodFrame, width: 2.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _asset.label,
                                  style: DesertTypography.display(
                                    size: 13,
                                    color: GameHudColors.ink,
                                  ),
                                ),
                                Text(
                                  'lib/world/${_asset.filePath}',
                                  style: DesertTypography.ui(
                                    size: 10.5,
                                    weight: FontWeight.w600,
                                    color: GameHudColors.inkMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GameBevelButton(
                          onTap: () => setState(() => _autoRotate = !_autoRotate),
                          radius: 14,
                          bevelDepth: 3.0,
                          padding: const EdgeInsets.all(10),
                          child: GameIcon(
                            _autoRotate ? GameIconKind.pause : GameIconKind.play,
                            color: const Color(0xFFFFF2D4),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom controls: Time-of-Day, Lv1-Lv5 toggle, and Asset selector strip
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: GameWoodPanel(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      radius: 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _chipButton('Day', _timeOfDay == 0.40, () => setState(() => _timeOfDay = 0.40)),
                                const SizedBox(width: 6),
                                _chipButton('Sunset', _timeOfDay == 0.74, () => setState(() => _timeOfDay = 0.74)),
                                const SizedBox(width: 6),
                                _chipButton('Night', _timeOfDay == 0.96, () => setState(() => _timeOfDay = 0.96)),
                                if (_asset.hasLevels) ...[
                                  const SizedBox(width: 14),
                                  for (int lv = 1; lv <= 5; lv++) ...[
                                    if (lv > 1) const SizedBox(width: 5),
                                    _chipButton('Lv$lv', _level == lv, () => setState(() => _level = lv)),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _studioCatalog.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final item = _studioCatalog[index];
                                final active = index == _selectedIndex;
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _selectAsset(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? GameHudColors.terraTop
                                            : GameHudColors.parchmentDark,
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: active
                                              ? GameHudColors.woodFrame
                                              : GameHudColors.woodRim.withValues(alpha: 0.5),
                                          width: 1.6,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          item.label,
                                          style: DesertTypography.ui(
                                            size: 12,
                                            weight: FontWeight.w700,
                                            color: active ? const Color(0xFFFFFFFF) : GameHudColors.ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipButton(String label, bool active, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? GameHudColors.woodFrame : GameHudColors.parchmentDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? GameHudColors.woodDeep : GameHudColors.woodRim.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: DesertTypography.display(
              size: 10.5,
              color: active ? const Color(0xFFFFF2D4) : GameHudColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioPainter extends CustomPainter {
  const _StudioPainter({
    required Listenable repaint,
    required this.asset,
    required this.level,
    required this.camera,
    required this.lighting,
    required this.getAnimTime,
  }) : super(repaint: repaint);

  final _StudioAssetEntry asset;
  final int level;
  final Camera3D camera;
  final DesertLighting lighting;
  final double Function() getAnimTime;

  @override
  void paint(Canvas canvas, Size size) {
    final animTime = getAnimTime();
    final frame = camera.createFrame(size);
    SceneRenderer3D.paintSkyDome(canvas, size, camera, lighting, animTime, frame: frame);

    final mesh = MeshBuilder();
    final shadowCol = lighting.shadowColor;

    final padR = asset.kind == _StudioAssetKind.westMittenButte ? 14.0 : 5.4;
    mesh.addFrustum(
      0,
      -0.45,
      0,
      padR + 0.5,
      padR + 0.5,
      padR,
      padR,
      0.45,
      8,
      DesertPalette.sandDark,
      topColor: DesertPalette.sand,
      layer: RenderLayer.terrain,
    );

    switch (asset.kind) {
      case _StudioAssetKind.vendorStall:
        BuildingModels.buildByType(mesh, BusinessType.vendorStall, Vec3.zero, level, lighting, shadowCol, animTime);
      case _StudioAssetKind.outpostMart:
        BuildingModels.buildByType(mesh, BusinessType.convenienceStore, Vec3.zero, level, lighting, shadowCol, animTime);
      case _StudioAssetKind.foodStand:
        BuildingModels.buildByType(mesh, BusinessType.foodStand, Vec3.zero, level, lighting, shadowCol, animTime);
      case _StudioAssetKind.desertDiner:
        BuildingModels.buildByType(mesh, BusinessType.desertDiner, Vec3.zero, level, lighting, shadowCol, animTime);
      case _StudioAssetKind.gasStation:
        BuildingModels.buildByType(mesh, BusinessType.gasStation, Vec3.zero, level, lighting, shadowCol, animTime);
      case _StudioAssetKind.desertMotel:
        BuildingModels.buildByType(mesh, BusinessType.desertMotel, Vec3.zero, level, lighting, shadowCol, animTime);
      case _StudioAssetKind.lookoutCamp:
        BuildingModels.buildByType(mesh, BusinessType.lookoutCamp, Vec3.zero, level, lighting, shadowCol, animTime);
      case _StudioAssetKind.oasisPlaza:
        BuildingModels.buildByType(mesh, BusinessType.oasisPlaza, Vec3.zero, level, lighting, shadowCol, animTime);
      case _StudioAssetKind.westMittenButte:
        MonumentMesas.buildMittenButte(
          mesh,
          cx: 0,
          cz: 0,
          scale: 0.9,
          hasLeftButtress: true,
          hasRightThumb: true,
          overrideBaseY: 0.0,
        );
      case _StudioAssetKind.desertWindmill:
        DesertWindmill.build(mesh, Vec3.zero, lighting, shadowCol, animTime);
      case _StudioAssetKind.welcomeSign:
        RoadsideWelcomeSign.build(mesh, Vec3.zero, lighting, shadowCol);
      case _StudioAssetKind.pickupTruck:
        EntityModels.buildVehicle(
          mesh,
          VehicleEntity(
            id: 1,
            kind: VehicleKind.pickupTruck,
            bodyColor: DesertPalette.awningRed,
            position: Vec3.zero,
            yaw: 0,
            speed: 0,
            direction: 1,
            phase: VehiclePhase.highwayCruise,
          ),
          lighting,
        );
      case _StudioAssetKind.camperRv:
        EntityModels.buildVehicle(
          mesh,
          VehicleEntity(
            id: 2,
            kind: VehicleKind.camperRv,
            bodyColor: DesertPalette.terracotta,
            position: Vec3.zero,
            yaw: 0,
            speed: 0,
            direction: 1,
            phase: VehiclePhase.highwayCruise,
          ),
          lighting,
        );
      case _StudioAssetKind.touristVan:
        EntityModels.buildVehicle(
          mesh,
          VehicleEntity(
            id: 3,
            kind: VehicleKind.touristVan,
            bodyColor: DesertPalette.turquoise,
            position: Vec3.zero,
            yaw: 0,
            speed: 0,
            direction: 1,
            phase: VehiclePhase.highwayCruise,
          ),
          lighting,
        );
      case _StudioAssetKind.compactCar:
        EntityModels.buildVehicle(
          mesh,
          VehicleEntity(
            id: 4,
            kind: VehicleKind.compactCar,
            bodyColor: DesertPalette.gold,
            position: Vec3.zero,
            yaw: 0,
            speed: 0,
            direction: 1,
            phase: VehiclePhase.highwayCruise,
          ),
          lighting,
        );
      case _StudioAssetKind.suv:
        EntityModels.buildVehicle(
          mesh,
          VehicleEntity(
            id: 5,
            kind: VehicleKind.suv,
            bodyColor: const Color(0xFF5A778E),
            position: Vec3.zero,
            yaw: 0,
            speed: 0,
            direction: 1,
            phase: VehiclePhase.highwayCruise,
          ),
          lighting,
        );
      case _StudioAssetKind.saguaroCluster:
        DesertFloraAndRocks.addSaguaro(mesh, const Vec3(-0.6, 0, 0), 1.2, 0.3, lighting, shadowCol);
        DesertFloraAndRocks.addSandstoneRock(
          mesh,
          const Vec3(1.1, 0, 0.4),
          1.0,
          0.7,
          0.5,
          lighting: lighting,
          shadowCol: shadowCol,
          groundY: 0,
        );
        DesertFloraAndRocks.addDesertBush(
          mesh,
          const Vec3(0.4, 0, -0.9),
          0.65,
          lighting: lighting,
          shadowCol: shadowCol,
        );
    }

    SceneRenderer3D.paintMesh(canvas, size, camera, lighting, mesh, frame: frame);
  }

  @override
  bool shouldRepaint(covariant _StudioPainter oldDelegate) =>
      oldDelegate.asset != asset ||
      oldDelegate.level != level ||
      oldDelegate.lighting.timeOfDay != lighting.timeOfDay;
}
