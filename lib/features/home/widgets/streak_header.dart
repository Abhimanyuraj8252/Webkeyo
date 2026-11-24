/// Streak + level header — the addictive hook on the home screen.
/// Shows the daily creation streak (flame), creator level + XP
/// progress, and how many achievements are unlocked. All local (Hive).
library;

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../services/engagement_service.dart';
import 'home_skeleton.dart';

class StreakHeader extends StatefulWidget {
  const StreakHeader({super.key});

  @override
  State<StreakHeader> createState() => _StreakHeaderState();
}

class _StreakHeaderState extends State<StreakHeader> {
  final EngagementService _engagement = EngagementService();
  EngagementStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _engagement.init();
    if (!mounted) return;
    setState(() => _stats = _engagement.stats);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _stats;
    if (stats == null) {
      return const Row(
        children: [
          ShimmerBox(width: 120, height: 20),
          SizedBox(width: AppConstants.paddingMedium),
          ShimmerBox(width: 120, height: 20),
        ],
      );
    }
    final xpIntoLevel = stats.level == 1
        ? stats.xp
        : stats.level == 2
            ? stats.xp - 500
            : stats.level == 3
                ? stats.xp - 1500
                : stats.level == 4
                    ? stats.xp - 3000
                    : stats.xp - 6000;
    final xpForLevel = stats.level == 1
        ? 500
        : stats.level == 2
            ? 1000
            : stats.level == 3
                ? 1500
                : stats.level == 4
                    ? 3000
                    : 1;
    final progress =
        stats.level >= 5 ? 1.0 : (xpIntoLevel / xpForLevel).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department,
            color: stats.currentStreak > 0 ? Colors.orange : theme.disabledColor,
            size: 28,
          ),
          const SizedBox(width: AppConstants.paddingSmall),
          Text(
            '${stats.currentStreak}-day streak',
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Level ${stats.level} · ${stats.levelName}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: theme.dividerColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stats.level >= 5
                      ? '${stats.xp} XP · max level'
                      : '${stats.xpToNextLevel} XP to Level ${stats.level + 1} · ${stats.unlockedAchievements.length}/${allAchievements.length} badges',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
