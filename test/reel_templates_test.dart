// Reel template + trending tests — every template uses a real style,
// every trending item points at a real template, and the trending
// JSON on disk is valid.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/models/video_style.dart';
import 'package:webkeyo/services/reel_templates.dart';
import 'package:webkeyo/services/share_service.dart';

void main() {
  group('reelTemplates', () {
    test('there are 10 templates, one per style', () {
      expect(reelTemplates.length, 10);
      final allStyleIds = styleIds.toSet();
      for (final t in reelTemplates) {
        expect(allStyleIds.contains(t.styleId), isTrue,
            reason: '${t.id} uses unknown style ${t.styleId}');
        expect(t.prompt.trim(), isNotEmpty);
        expect(t.hashtags, isNotEmpty);
        expect(t.durationSeconds, greaterThan(0));
      }
    });

    test('template ids are unique', () {
      final ids = reelTemplates.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('templateById finds Haunted Night', () {
      final t = templateById('haunted_night');
      expect(t, isNotNull);
      expect(t!.styleId, 'horror-night');
      expect(t.name, 'Haunted Night');
    });

    test('templateById returns null for unknown ids', () {
      expect(templateById('nope'), isNull);
    });
  });

  group('trending.json', () {
    test('is valid JSON and every item points at a real template', () {
      final file = File('assets/data/trending.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final items = (data['trending'] as List).cast<Map<String, dynamic>>();
      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item['title'], isNotEmpty);
        expect(item['reason'], isNotEmpty);
        expect(templateById(item['templateId'] as String), isNotNull,
            reason: 'trending item ${item['id']} points at a missing template');
      }
    });
  });

  group('ShareService.buildCaption', () {
    test('title + hashtags, one blank line between', () {
      expect(
        ShareService.buildCaption(
          title: 'Haunted Inn',
          hashtags: ['#horrorstory', '#webkeyo'],
        ),
        'Haunted Inn\n\n#horrorstory #webkeyo',
      );
    });
  });
}
