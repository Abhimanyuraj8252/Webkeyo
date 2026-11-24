import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/script_generator.dart';

void main() {
  test('6 genres exist', () {
    expect(genreIds.length, 6);
    expect(
      genreIds.toSet(),
      {'haunted', 'love', 'action', 'sad', 'motivational', 'mystery'},
    );
  });

  test('generateScript returns title, genre and scenes with a hook + cliffhanger', () {
    final script = generateScript('a boy enters a haunted inn', 'haunted');
    expect(script['genre'], 'haunted');
    expect((script['title'] as String).trim(), isNotEmpty);
    final scenes = script['scenes'] as List;
    expect(scenes.length, greaterThanOrEqualTo(3));
    // First scene is the Narrator hook, last is the cliffhanger.
    final first = scenes.first as Map<String, dynamic>;
    expect(first['speaker'], 'Narrator');
    expect((first['narration'] as String).trim(), isNotEmpty);
    final last = scenes.last as Map<String, dynamic>;
    expect(last['speaker'], 'Narrator');
    expect((last['narration'] as String).trim(), isNotEmpty);
    for (final scene in scenes) {
      final s = scene as Map<String, dynamic>;
      expect(s['emotion'], isNotEmpty);
      expect((s['est_seconds'] as num).toDouble(), greaterThan(0));
    }
  });

  test('generateScript works for every genre', () {
    for (final genre in genreIds) {
      final script = generateScript('a test idea', genre);
      expect((script['scenes'] as List).length, greaterThanOrEqualTo(3));
    }
  });

  test('empty idea and unknown genre throw', () {
    expect(() => generateScript('   ', 'haunted'), throwsArgumentError);
    expect(() => generateScript('an idea', 'nope'), throwsArgumentError);
  });
}
