import 'package:flutter/widgets.dart';

import '../../systems/game_controller.dart';
import '../../theme/desert_palette.dart';
import '../formatters.dart';
import '../game_hud_widgets.dart';
import '../game_icons.dart';
import '../object_studio_screen.dart';

/// Compact western carved-wood Game Menu modal built on pure `flutter/widgets.dart`.
class GameMenuDialog extends StatelessWidget {
  const GameMenuDialog({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 376,
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              child: GameWoodPanel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                radius: 22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: GameHudColors.woodFrame,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'DESERT OUTPOST',
                            style: DesertTypography.display(
                              size: 12.5,
                              color: const Color(0xFFFFF2D4),
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GameBevelButton(
                          onTap: controller.toggleSound,
                          topColor: controller.soundEnabled
                              ? GameHudColors.woodBody
                              : GameHudColors.stoneTop,
                          baseColor: controller.soundEnabled
                              ? GameHudColors.woodDeep
                              : GameHudColors.stoneBase,
                          radius: 10,
                          bevelDepth: 2.5,
                          padding: const EdgeInsets.all(6),
                          child: GameIcon(
                            controller.soundEnabled
                                ? GameIconKind.volumeOn
                                : GameIconKind.volumeOff,
                            color: const Color(0xFFFFF2D4),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GameBevelButton(
                          onTap: () => Navigator.of(context).pop(),
                          topColor: GameHudColors.terraTop,
                          baseColor: GameHudColors.terraBase,
                          radius: 10,
                          bevelDepth: 2.5,
                          padding: const EdgeInsets.all(6),
                          child: const GameIcon(
                            GameIconKind.close,
                            color: Color(0xFFFFFFFF),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        _miniBadge('LANDMARKS', '${controller.builtCount}/8'),
                        const SizedBox(width: 6),
                        _miniBadge('PARKING', '${controller.currentParkingTierData.spaces}'),
                        const SizedBox(width: 6),
                        _miniBadge('VISITORS', '${controller.totalCustomersServed}'),
                        const SizedBox(width: 6),
                        _miniBadge('TIP BONUS', '+${controller.decorations.length * 4}%'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _TagHeader('SKY & LIGHTING'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _skyBtn('Day', GameIconKind.sun, 0.40),
                                const SizedBox(width: 6),
                                _skyBtn('Sunset', GameIconKind.sunset, 0.74),
                                const SizedBox(width: 6),
                                _skyBtn('Night', GameIconKind.moon, 0.96),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: GameBevelButton(
                                    onTap: controller.toggleAutoDayNight,
                                    topColor: controller.autoDayNight
                                        ? GameHudColors.greenTop
                                        : GameHudColors.woodBody,
                                    baseColor: controller.autoDayNight
                                        ? GameHudColors.greenBase
                                        : GameHudColors.woodDeep,
                                    radius: 11,
                                    bevelDepth: 2.5,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: Text(
                                        controller.autoDayNight ? 'AUTO' : 'HOLD',
                                        style: DesertTypography.display(
                                          size: 10.0,
                                          color: const Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            const _TagHeader('MODES & TOOLS'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: GameBevelButton(
                                    onTap: () {
                                      controller.switchPreset(OutpostPreset.stageOneCareer);
                                      Navigator.of(context).pop();
                                    },
                                    topColor: controller.activePreset == OutpostPreset.stageOneCareer
                                        ? GameHudColors.terraTop
                                        : GameHudColors.woodBody,
                                    baseColor: controller.activePreset == OutpostPreset.stageOneCareer
                                        ? GameHudColors.terraBase
                                        : GameHudColors.woodDeep,
                                    radius: 11,
                                    bevelDepth: 2.5,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: Text(
                                        'LV1 CART',
                                        style: DesertTypography.display(
                                          size: 10.5,
                                          color: const Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: GameBevelButton(
                                    onTap: () {
                                      controller.switchPreset(OutpostPreset.fullCity);
                                      Navigator.of(context).pop();
                                    },
                                    topColor: controller.activePreset == OutpostPreset.fullCity
                                        ? GameHudColors.terraTop
                                        : GameHudColors.woodBody,
                                    baseColor: controller.activePreset == OutpostPreset.fullCity
                                        ? GameHudColors.terraBase
                                        : GameHudColors.woodDeep,
                                    radius: 11,
                                    bevelDepth: 2.5,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: Text(
                                        'FULL CITY',
                                        style: DesertTypography.display(
                                          size: 10.5,
                                          color: const Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: GameBevelButton(
                                    onTap: () {
                                      final nav = Navigator.of(context);
                                      nav.pop();
                                      nav.push(
                                        PageRouteBuilder<void>(
                                          pageBuilder: (_, _, _) => const ObjectStudioScreen(),
                                        ),
                                      );
                                    },
                                    radius: 11,
                                    bevelDepth: 2.5,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const GameIcon(
                                          GameIconKind.cube3d,
                                          color: Color(0xFFFFE7B8),
                                          size: 15,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '3D STUDIO',
                                          style: DesertTypography.display(
                                            size: 10.5,
                                            color: const Color(0xFFFFFFFF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: GameBevelButton(
                                    onTap: () {
                                      controller.resetCamera();
                                      Navigator.of(context).pop();
                                    },
                                    radius: 11,
                                    bevelDepth: 2.5,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const GameIcon(
                                          GameIconKind.centerFocus,
                                          color: Color(0xFFFFE7B8),
                                          size: 15,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'RESET VIEW',
                                          style: DesertTypography.display(
                                            size: 10.5,
                                            color: const Color(0xFFFFFFFF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            const _TagHeader('REWARDS & GOALS'),
                            const SizedBox(height: 6),
                            for (final m in controller.milestones)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: GameHudColors.parchmentDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (!m.claimed && m.checkCompleted())
                                        ? GameHudColors.goldBase
                                        : GameHudColors.woodRim.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    GameIcon(
                                      m.claimed ? GameIconKind.verified : GameIconKind.trophy,
                                      size: 18,
                                      color: m.claimed
                                          ? GameHudColors.greenBase
                                          : (m.checkCompleted()
                                              ? GameHudColors.goldBase
                                              : GameHudColors.inkMuted),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.title,
                                            style: DesertTypography.ui(
                                              size: 12,
                                              weight: FontWeight.w700,
                                              color: GameHudColors.ink,
                                            ),
                                          ),
                                          Text(
                                            m.description,
                                            style: DesertTypography.ui(
                                              size: 10.5,
                                              weight: FontWeight.w600,
                                              color: GameHudColors.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (m.claimed)
                                      Text(
                                        'DONE',
                                        style: DesertTypography.display(
                                          size: 10,
                                          color: GameHudColors.greenBase,
                                        ),
                                      )
                                    else if (m.checkCompleted())
                                      GameBevelButton(
                                        onTap: () => controller.claimMilestone(m),
                                        topColor: GameHudColors.goldTop,
                                        baseColor: GameHudColors.goldBase,
                                        radius: 9,
                                        bevelDepth: 2,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        child: Text(
                                          '+${formatCash(m.rewardCash)}',
                                          style: DesertTypography.display(
                                            size: 10.5,
                                            color: GameHudColors.ink,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        '+${formatCash(m.rewardCash)}',
                                        style: DesertTypography.display(
                                          size: 10.5,
                                          color: GameHudColors.inkMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _miniBadge(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: GameHudColors.parchmentDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GameHudColors.woodRim.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: DesertTypography.display(
                size: 12.5,
                color: GameHudColors.ink,
              ),
            ),
            Text(
              label,
              style: DesertTypography.ui(
                size: 8.5,
                weight: FontWeight.w700,
                color: GameHudColors.inkMuted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skyBtn(String label, GameIconKind icon, double timeValue) {
    return Expanded(
      child: GameBevelButton(
        onTap: () => controller.setTimePreset(timeValue, pauseCycle: true),
        radius: 11,
        bevelDepth: 2.5,
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(icon, size: 14, color: const Color(0xFFFFE3A3)),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: DesertTypography.display(
                size: 9.0,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagHeader extends StatelessWidget {
  const _TagHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: DesertTypography.display(
        size: 9.8,
        color: GameHudColors.inkMuted,
        letterSpacing: 0.9,
      ),
    );
  }
}
