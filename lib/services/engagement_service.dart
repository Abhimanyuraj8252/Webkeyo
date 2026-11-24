/// Engagement — daily creation streak, achievements, creator level/XP
/// and the local daily reminder. All local, all free, no server, no
/// account. Stored in Hive (`engagement_box`).
///
/// XP: +100 per exported video, +10 per rendered sample/demo.
/// Levels: 1 Newcomer (0 XP), 2 Storyteller (500), 3 Creator (1500),
/// 4 Director (3000), 5 Studio (6000).
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// One achievement. [id] is stable; [title]/[description] are shown
/// in the app. [check] is evaluated against the current stats.
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon; // emoji-free: material icon name handled by UI
  final bool Function(EngagementStats stats) check;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.check,
  });
}

final List<Achievement> allAchievements = [
  Achievement(
    id: 'first_reel',
    title: 'First reel',
    description: 'Export your first video.',
    icon: 'movie',
    check: (s) => s.totalExports >= 1,
  ),
  Achievement(
    id: 'ten_reels',
    title: '10 reels',
    description: 'Export 10 videos.',
    icon: 'video_library',
    check: (s) => s.totalExports >= 10,
  ),
  Achievement(
    id: 'streak_7',
    title: '7-day streak',
    description: 'Create on 7 days in a row.',
    icon: 'local_fire_department',
    check: (s) => s.bestStreak >= 7,
  ),
  Achievement(
    id: 'streak_30',
    title: '30-day streak',
    description: 'Create on 30 days in a row.',
    icon: 'emoji_events',
    check: (s) => s.bestStreak >= 30,
  ),
  Achievement(
    id: 'hundred_reels',
    title: '100 reels',
    description: 'Export 100 videos.',
    icon: 'stars',
    check: (s) => s.totalExports >= 100,
  ),
];

class EngagementStats {
  final int totalExports;
  final int xp;
  final int currentStreak;
  final int bestStreak;
  final List<String> unlockedAchievements;
  final String? lastActiveDay; // YYYY-MM-DD

  const EngagementStats({
    required this.totalExports,
    required this.xp,
    required this.currentStreak,
    required this.bestStreak,
    required this.unlockedAchievements,
    this.lastActiveDay,
  });

  int get level {
    if (xp >= 6000) return 5;
    if (xp >= 3000) return 4;
    if (xp >= 1500) return 3;
    if (xp >= 500) return 2;
    return 1;
  }

  String get levelName {
    switch (level) {
      case 5:
        return 'Studio';
      case 4:
        return 'Director';
      case 3:
        return 'Creator';
      case 2:
        return 'Storyteller';
      default:
        return 'Newcomer';
    }
  }

  /// XP needed for the next level, or 0 at max level.
  int get xpToNextLevel {
    switch (level) {
      case 1:
        return 500 - xp;
      case 2:
        return 1500 - xp;
      case 3:
        return 3000 - xp;
      case 4:
        return 6000 - xp;
      default:
        return 0;
    }
  }
}

class EngagementService {
  static const String _boxName = 'engagement_box';
  static const String _key = 'stats';

  Box? _box;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_box != null) return; // already open (main boot opens it)
    _box = await Hive.openBox(_boxName);
  }

  EngagementStats get stats {
    final stored = _box?.get(_key) as Map?;
    if (stored == null) {
      return const EngagementStats(
        totalExports: 0,
        xp: 0,
        currentStreak: 0,
        bestStreak: 0,
        unlockedAchievements: [],
      );
    }
    return EngagementStats(
      totalExports: (stored['exports'] as int?) ?? 0,
      xp: (stored['xp'] as int?) ?? 0,
      currentStreak: (stored['streak'] as int?) ?? 0,
      bestStreak: (stored['bestStreak'] as int?) ?? 0,
      unlockedAchievements:
          ((stored['achievements'] as List?) ?? []).cast<String>(),
      lastActiveDay: stored['lastActiveDay'] as String?,
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Call after a video export (or a demo render). Updates the streak,
  /// XP and achievements. Returns the ids of achievements unlocked by
  /// this call (empty when none).
  Future<List<String>> recordExport({int xpGained = 100}) async {
    final now = DateTime.now();
    final today = _dayKey(now);
    final s = stats;
    var streak = s.currentStreak;
    if (s.lastActiveDay != today) {
      final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
      streak = (s.lastActiveDay == yesterday) ? streak + 1 : 1;
    }
    final updated = EngagementStats(
      totalExports: s.totalExports + 1,
      xp: s.xp + xpGained,
      currentStreak: streak,
      bestStreak: streak > s.bestStreak ? streak : s.bestStreak,
      unlockedAchievements: List<String>.from(s.unlockedAchievements),
      lastActiveDay: today,
    );
    final newlyUnlocked = <String>[];
    for (final a in allAchievements) {
      if (!updated.unlockedAchievements.contains(a.id) && a.check(updated)) {
        updated.unlockedAchievements.add(a.id);
        newlyUnlocked.add(a.id);
      }
    }
    await _box?.put(_key, {
      'exports': updated.totalExports,
      'xp': updated.xp,
      'streak': updated.currentStreak,
      'bestStreak': updated.bestStreak,
      'achievements': updated.unlockedAchievements,
      'lastActiveDay': updated.lastActiveDay,
    });
    return newlyUnlocked;
  }

  /// Daily reminder (local time). One notification a day, only if the
  /// user turned it on in Settings. Cancel with [cancelReminder]. No
  /// server — flutter_local_notifications only.
  ///
  /// NOTE: `periodicallyShow` fires once a day starting ~24h after it
  /// is turned on — it does NOT fire at a chosen clock time ([hour] /
  /// [minute] are kept for the future zoned schedule and currently
  /// ignored). An exact clock time needs the `timezone` package and a
  /// `zonedSchedule` call — TODO if the user asks for a fixed time.
  Future<void> scheduleDailyReminder({int hour = 19, int minute = 0}) async {
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings: settings);
    await _notifications.periodicallyShow(
      id: 1,
      title: 'Time to create 🎬',
      body: 'Your streak is waiting — turn one story into a video today.',
      repeatInterval: RepeatInterval.daily,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'webkeyo_reminder',
          'Daily reminder',
          channelDescription: 'Daily creation reminder',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelReminder() async {
    await _notifications.cancel(id: 1);
  }
}
