/// "Trending this week" — loads assets/data/trending.json (shipped
/// with the release, updated per release). No server, no tracking.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class TrendingItem {
  final String id;
  final String title;
  final String reason;
  final String templateId;

  const TrendingItem({
    required this.id,
    required this.title,
    required this.reason,
    required this.templateId,
  });

  factory TrendingItem.fromJson(Map<String, dynamic> json) => TrendingItem(
        id: (json['id'] ?? '') as String,
        title: (json['title'] ?? '') as String,
        reason: (json['reason'] ?? '') as String,
        templateId: (json['templateId'] ?? '') as String,
      );
}

/// Load the trending list. Returns an empty list on any error — the
/// home screen simply hides the row instead of crashing.
Future<List<TrendingItem>> loadTrending() async {
  try {
    final raw = await rootBundle.loadString('assets/data/trending.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final items = (data['trending'] as List?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(TrendingItem.fromJson)
        .where((t) => t.templateId.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
}
