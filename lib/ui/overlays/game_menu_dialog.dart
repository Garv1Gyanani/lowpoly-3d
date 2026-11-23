import 'package:flutter/material.dart';

import '../../systems/game_controller.dart';
import '../formatters.dart';
import '../game_hud_widgets.dart';
import '../object_studio_screen.dart';

/// Compact western carved-wood Game Menu dialog (replaces giant white Material sheets).
class GameMenuDialog extends StatelessWidget {
  const GameMenuDialog({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 360,
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            child: GameWoodPanel(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              radius: 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Carved wood header banner
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: GameHudColors.woodFrame,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'DESERT OUTPOST',
                          style: TextStyle(
                            color: Color(0xFFFFF2D4),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GameBevelButton(
                        onTap: () => Navigator.of(context).pop(),
                        topColor: GameHudColors.terraTop,
                        baseColor: GameHudColors.terraBase,
                        radius: 10,
                        bevelDepth: 2.5,
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Compact stats strip
                  Row(
                    children: [
                      _miniBadge('LANDMARKS', '${controller.builtCount}/8'),
                      const SizedBox(width: 6),
                      _miniBadge('PARKING', '${controller.currentParkingTierData.spaces}'),
                      const SizedBox(width: 6),
                      _miniBadge('VISITORS', '${controller.totalCustomersServed}'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sky lighting row
                          const _TagHeader('SKY & LIGHTING'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _skyBtn('Day', Icons.wb_sunny_rounded, 0.40),
                              const SizedBox(width: 6),
                              _skyBtn('Sunset', Icons.wb_twilight_rounded, 0.74),
                              const SizedBox(width: 6),
                              _skyBtn('Night', Icons.nightlight_round, 0.96),
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quick game modes & studio tools
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
                                  child: const Center(
                                    child: Text(
                                      'LV1 CART',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
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
                                  child: const Center(
                                    child: Text(
                                      'FULL CITY',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
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
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const ObjectStudioScreen(),
                                      ),
                                    );
                                  },
                                  radius: 11,
                                  bevelDepth: 2.5,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.view_in_ar_rounded, color: Color(0xFFFFE7B8), size: 15),
                                      SizedBox(width: 5),
                                      Text(
                                        '3D STUDIO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
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
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.center_focus_strong_rounded, color: Color(0xFFFFE7B8), size: 15),
                                      SizedBox(width: 5),
                                      Text(
                                        'RESET VIEW',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Milestones
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
                                  Icon(
                                    m.claimed
                                        ? Icons.verified_rounded
                                        : Icons.emoji_events_rounded,
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
                                          style: const TextStyle(
                                            color: GameHudColors.ink,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          m.description,
                                          style: const TextStyle(
                                            color: GameHudColors.inkMuted,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (m.claimed)
                                    const Text(
                                      'DONE',
                                      style: TextStyle(
                                        color: GameHudColors.greenBase,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10.5,
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
                                        style: const TextStyle(
                                          color: GameHudColors.ink,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      '+${formatCash(m.rewardCash)}',
                                      style: const TextStyle(
                                        color: GameHudColors.inkMuted,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
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
              style: const TextStyle(
                color: GameHudColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: GameHudColors.inkMuted,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skyBtn(String label, IconData icon, double timeValue) {
    return Expanded(
      child: GameBevelButton(
        onTap: () => controller.setTimePreset(timeValue, pauseCycle: true),
        radius: 11,
        bevelDepth: 2.5,
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFFFE3A3)),
            const SizedBox(height: 1),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
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
      style: const TextStyle(
        color: GameHudColors.inkMuted,
        fontWeight: FontWeight.w900,
        fontSize: 10,
        letterSpacing: 1.0,
      ),
    );
  }
}
