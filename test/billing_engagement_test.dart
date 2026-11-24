// BillingService + EngagementService tests — local Hive counters.
// Uses a temp Hive dir per test; no network, no server.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webkeyo/services/billing_service.dart';
import 'package:webkeyo/services/engagement_service.dart';
import 'package:webkeyo/services/provider_credentials.dart';

Future<Directory> _tempHiveDir() async {
  final dir = await Directory.systemTemp.createTemp('webkeyo_test_');
  Hive.init(dir.path);
  return dir;
}

void main() {
  group('BillingService', () {
    late Directory dir;
    late BillingService billing;

    setUp(() async {
      dir = await _tempHiveDir();
      billing = BillingService();
      await billing.init();
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('monthKeyFor formats YYYY-MM', () {
      expect(BillingService.monthKeyFor(DateTime(2026, 11, 24)), '2026-11');
      expect(BillingService.monthKeyFor(DateTime(2026, 1, 5)), '2026-01');
    });

    test('freeCharsPerMonth returns only the verified allowances', () {
      expect(billing.freeCharsPerMonth('google_cloud_tts'), 4000000);
      expect(billing.freeCharsPerMonth('amazon_polly'), 5000000);
      expect(billing.freeCharsPerMonth('speechify'), 500000);
      expect(billing.freeCharsPerMonth('azure_speech'), 500000);
      // Providers with no published monthly allowance return null —
      // the app never invents a limit.
      expect(billing.freeCharsPerMonth('sarvam_tts'), isNull);
      expect(billing.freeCharsPerMonth('gemini_tts'), isNull);
      expect(billing.freeCharsPerMonth('deepgram'), isNull);
      expect(billing.freeCharsPerMonth('minimax_tts'), isNull);
    });

    test('recordTtsChars accumulates and freeTierStatus formats', () async {
      await billing.recordTtsChars('google_cloud_tts', 48000);
      expect(billing.currentUsage.charsFor('google_cloud_tts'), 48000);
      expect(billing.freeTierUsedFraction('google_cloud_tts'),
          closeTo(48000 / 4000000, 0.0001));
      expect(billing.freeTierStatus('google_cloud_tts'),
          '48K / 4.0M chars free used this month');
      await billing.recordTtsChars('google_cloud_tts', 48000);
      expect(billing.currentUsage.charsFor('google_cloud_tts'), 96000);
    });

    test('recordExport counts exports', () async {
      expect(billing.currentUsage.exports, 0);
      await billing.recordExport();
      await billing.recordExport();
      expect(billing.currentUsage.exports, 2);
    });

    test('freeTierStatus is null without a published allowance', () {
      expect(billing.freeTierStatus('sarvam_tts'), isNull);
    });
  });

  group('EngagementService', () {
    late Directory dir;
    late EngagementService engagement;

    setUp(() async {
      dir = await _tempHiveDir();
      engagement = EngagementService();
      await engagement.init();
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('starts at zero: Newcomer, no streak, no badges', () {
      final s = engagement.stats;
      expect(s.totalExports, 0);
      expect(s.xp, 0);
      expect(s.level, 1);
      expect(s.levelName, 'Newcomer');
      expect(s.currentStreak, 0);
      expect(s.unlockedAchievements, isEmpty);
    });

    test('first export: +100 XP, streak 1, First reel unlocked', () async {
      final unlocked = await engagement.recordExport();
      expect(unlocked, contains('first_reel'));
      final s = engagement.stats;
      expect(s.totalExports, 1);
      expect(s.xp, 100);
      expect(s.currentStreak, 1);
      expect(s.bestStreak, 1);
      expect(s.xpToNextLevel, 400);
    });

    test('second export the same day: streak stays 1, XP grows', () async {
      await engagement.recordExport();
      final unlocked = await engagement.recordExport();
      expect(unlocked, isEmpty);
      final s = engagement.stats;
      expect(s.totalExports, 2);
      expect(s.xp, 200);
      expect(s.currentStreak, 1);
    });

    test('level thresholds', () {
      const stats = EngagementStats(
        totalExports: 0,
        xp: 500,
        currentStreak: 0,
        bestStreak: 0,
        unlockedAchievements: [],
      );
      expect(stats.level, 2);
      expect(stats.levelName, 'Storyteller');
      const stats3 = EngagementStats(
        totalExports: 0,
        xp: 1500,
        currentStreak: 0,
        bestStreak: 0,
        unlockedAchievements: [],
      );
      expect(stats3.level, 3);
      const stats5 = EngagementStats(
        totalExports: 0,
        xp: 6000,
        currentStreak: 0,
        bestStreak: 0,
        unlockedAchievements: [],
      );
      expect(stats5.level, 5);
      expect(stats5.xpToNextLevel, 0);
    });

    test('achievement checks are pure', () {
      const ten = EngagementStats(
        totalExports: 10,
        xp: 1000,
        currentStreak: 0,
        bestStreak: 7,
        unlockedAchievements: [],
      );
      final byId = {for (final a in allAchievements) a.id: a};
      expect(byId['ten_reels']!.check(ten), isTrue);
      expect(byId['streak_7']!.check(ten), isTrue);
      expect(byId['streak_30']!.check(ten), isFalse);
      expect(byId['hundred_reels']!.check(ten), isFalse);
    });
  });

  group('ProviderCredentials (pure parts)', () {
    test('defaultRegionFor', () {
      expect(defaultRegionFor('amazon_polly'), 'ap-south-1');
      expect(defaultRegionFor('azure_speech'), 'centralindia');
      expect(defaultRegionFor('sarvam_tts'), '');
    });

    test('providerExtraFields declares only the three providers', () {
      expect(providerExtraFields.keys.toSet(),
          {'amazon_polly', 'azure_speech', 'speechify'});
      expect(providerExtraFields['amazon_polly']!.needsSecret, isTrue);
      expect(providerExtraFields['amazon_polly']!.needsRegion, isTrue);
      expect(providerExtraFields['azure_speech']!.needsRegion, isTrue);
      expect(providerExtraFields['azure_speech']!.needsSecret, isFalse);
      expect(providerExtraFields['speechify']!.modelChoices,
          ['simba-3.5', 'simba-3.2']);
    });

    test('extra credentials round-trip through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      await ProviderCredentials.save(
        'amazon_polly',
        const ProviderExtra(secret: 'SECRET', region: 'ap-south-1'),
      );
      final loaded = await ProviderCredentials.load('amazon_polly');
      expect(loaded.secret, 'SECRET');
      expect(loaded.region, 'ap-south-1');
      expect(loaded.hasSecret, isTrue);
      expect(loaded.hasModel, isFalse);
    });

    test('default TTS provider round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      await DefaultTtsProvider.save('azure_speech');
      expect(await DefaultTtsProvider.load(), 'azure_speech');
    });
  });
}
