/// BillingService — usage counting for a FUTURE paid tier.
///
/// Today Webkeyo is completely free and there is no payment flow, no
/// paywall and no charge. This service only counts, locally (Hive),
/// how many characters of TTS and how many video exports the user has
/// used, so that IF a paid tier is ever added, the app can show a fair
/// free allowance first and ask before charging anything.
///
/// Free-tier limits here are ONLY the officially verified ones
/// (24 Nov 2026, ~800 chars/min = 48,000 chars/hour):
/// - Google Cloud TTS WaveNet: 4,000,000 chars/month
/// - Amazon Polly Standard: 5,000,000 chars/month (first 12 months)
/// - Speechify Simba: 500,000 chars/month
/// - Azure AI Speech (F0): 500,000 neural chars/month
/// Providers without a published monthly character allowance
/// (Sarvam, Gemini, Deepgram, Fish Audio, MiniMax, ElevenLabs, Edge,
/// Piper, Flutter TTS) return null — the app never invents a limit.
library;

import 'package:hive_flutter/hive_flutter.dart';

import 'voice_providers.dart';

/// One month of usage, keyed by provider id.
class MonthlyUsage {
  final String monthKey; // YYYY-MM
  final Map<String, int> charsByProvider;
  final int exports;

  const MonthlyUsage({
    required this.monthKey,
    required this.charsByProvider,
    required this.exports,
  });

  int charsFor(String providerId) => charsByProvider[providerId] ?? 0;

  MonthlyUsage copyWith({
    Map<String, int>? charsByProvider,
    int? exports,
  }) =>
      MonthlyUsage(
        monthKey: monthKey,
        charsByProvider: charsByProvider ?? this.charsByProvider,
        exports: exports ?? this.exports,
      );
}

class BillingService {
  static const String _boxName = 'billing_box';
  static const String _key = 'usage';

  Box? _box;

  Future<void> init() async {
    if (_box != null) return; // already open (main boot opens it)
    _box = await Hive.openBox(_boxName);
  }

  static String monthKeyFor(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  MonthlyUsage get currentUsage {
    final now = DateTime.now();
    final key = monthKeyFor(now);
    final stored = _box?.get(_key) as Map?;
    if (stored == null || stored['month'] != key) {
      return MonthlyUsage(monthKey: key, charsByProvider: {}, exports: 0);
    }
    final chars = <String, int>{};
    final raw = stored['chars'] as Map?;
    raw?.forEach((k, v) {
      if (k is String && v is int) chars[k] = v;
    });
    return MonthlyUsage(
      monthKey: key,
      charsByProvider: chars,
      exports: (stored['exports'] as int?) ?? 0,
    );
  }

  Future<void> recordTtsChars(String providerId, int chars) async {
    final usage = currentUsage;
    final updated = Map<String, int>.from(usage.charsByProvider);
    updated[providerId] = (updated[providerId] ?? 0) + chars;
    await _save(usage.copyWith(charsByProvider: updated));
  }

  Future<void> recordExport() async {
    final usage = currentUsage;
    await _save(usage.copyWith(exports: usage.exports + 1));
  }

  Future<void> _save(MonthlyUsage usage) async {
    await _box?.put(_key, {
      'month': usage.monthKey,
      'chars': usage.charsByProvider,
      'exports': usage.exports,
    });
  }

  /// Published free monthly characters for [providerId], or null when
  /// the provider publishes no monthly character allowance.
  int? freeCharsPerMonth(String providerId) {
    for (final info in voiceProviderInfos) {
      if (info.id == providerId) return info.freeCharsPerMonth;
    }
    return null;
  }

  /// Fraction of the free tier used this month (0.0–1.0+), or null
  /// when the provider publishes no monthly allowance.
  double? freeTierUsedFraction(String providerId) {
    final free = freeCharsPerMonth(providerId);
    if (free == null || free <= 0) return null;
    return currentUsage.charsFor(providerId) / free;
  }

  /// Human-readable free-tier status, e.g. "1.2M / 4M chars free used".
  /// Returns null when the provider publishes no monthly allowance.
  String? freeTierStatus(String providerId) {
    final free = freeCharsPerMonth(providerId);
    if (free == null) return null;
    final used = currentUsage.charsFor(providerId);
    String fmt(int n) => n >= 1000000
        ? '${(n / 1000000).toStringAsFixed(1)}M'
        : n >= 1000
            ? '${(n / 1000).toStringAsFixed(0)}K'
            : '$n';
    return '${fmt(used)} / ${fmt(free)} chars free used this month';
  }
}
