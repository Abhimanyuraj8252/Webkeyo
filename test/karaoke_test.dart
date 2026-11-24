// Karaoke caption tests — buildKaraokeAss produces a valid .ass file
// with word-by-word \k tags and matching timestamps.
import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/subtitle_service.dart';

void main() {
  const scenes = [
    {'narration': 'Ek ladka haunted inn me gaya', 'est_seconds': 6.0},
    {'narration': 'Waiter insaan nahi tha', 'est_seconds': 4.0},
  ];

  group('buildKaraokeAss', () {
    test('has the ASS header and Karaoke style', () {
      final ass = buildKaraokeAss(scenes);
      expect(ass, contains('[Script Info]'));
      expect(ass, contains('[V4+ Styles]'));
      expect(ass, contains('Style: Karaoke'));
      expect(ass, contains('[Events]'));
    });

    test('one Dialogue line per scene with \\k tags per word', () {
      final ass = buildKaraokeAss(scenes);
      final lines =
          ass.split('\n').where((l) => l.startsWith('Dialogue:')).toList();
      expect(lines.length, 2);
      // Scene 1 has 6 words -> 6 \k tags; scene 2 has 4 words -> 4.
      expect('\\k'.allMatches(lines[0]).length, 6);
      expect('\\k'.allMatches(lines[1]).length, 4);
    });

    test('timestamps accumulate with the 1.3x factor', () {
      final ass = buildKaraokeAss(scenes);
      final lines =
          ass.split('\n').where((l) => l.startsWith('Dialogue:')).toList();
      // Scene 1: 6.0 * 1.3 = 7.8s -> 0:00:00.00 to 0:00:07.80
      expect(lines[0], contains('0:00:00.00,0:00:07.80'));
      // Scene 2: starts at 7.8s, 4.0 * 1.3 = 5.2s -> ends 13.0s
      expect(lines[1], contains('0:00:07.80,0:00:13.00'));
    });

    test('empty scenes produce no Dialogue lines', () {
      final ass = buildKaraokeAss([]);
      expect(ass.split('\n').where((l) => l.startsWith('Dialogue:')), isEmpty);
    });

    test('scenes with empty narration are skipped', () {
      final ass = buildKaraokeAss([
        {'narration': '', 'est_seconds': 5.0},
        {'narration': 'Hello', 'est_seconds': 2.0},
      ]);
      final lines =
          ass.split('\n').where((l) => l.startsWith('Dialogue:')).toList();
      expect(lines.length, 1);
      expect(lines[0], contains('Hello'));
    });
  });

  group('formatAssTimestamp', () {
    test('formats seconds as H:MM:SS.cc', () {
      expect(formatAssTimestamp(0), '0:00:00.00');
      expect(formatAssTimestamp(7.8), '0:00:07.80');
      expect(formatAssTimestamp(3661.25), '1:01:01.25');
    });
  });
}
