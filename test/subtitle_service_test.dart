import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/subtitle_service.dart';

void main() {
  test('formatSrtTimestamp formats hours, minutes, seconds, ms', () {
    expect(formatSrtTimestamp(0), '00:00:00,000');
    expect(formatSrtTimestamp(1.5), '00:00:01,500');
    expect(formatSrtTimestamp(61.25), '00:01:01,250');
    expect(formatSrtTimestamp(3661.007), '01:01:01,007');
  });

  test('buildSrt numbers cues and stretches by the Hindi factor', () {
    final srt = buildSrt([
      {'narration': 'Arjun enters the inn.', 'est_seconds': 4.0},
      {'narration': 'The waiter smiles.', 'est_seconds': 2.0},
    ]);
    expect(srt, contains('1\n00:00:00,000 --> 00:00:05,200\nArjun enters the inn.'));
    expect(srt, contains('2\n00:00:05,200 --> 00:00:07,800\nThe waiter smiles.'));
  });

  test('buildSrt skips empty lines and uses factor 1.0 when asked', () {
    final srt = buildSrt([
      {'narration': '  ', 'est_seconds': 4.0},
      {'text': 'A line.', 'est_seconds': 3.0},
    ], factor: 1.0);
    expect(srt, startsWith('1\n00:00:00,000 --> 00:00:03,000\nA line.'));
  });

  test('retimeSrtText scales every cue', () {
    const srt = '1\n00:00:00,000 --> 00:00:04,000\nHello.\n\n'
        '2\n00:00:04,000 --> 00:00:06,000\nWorld.\n';
    final retimed = retimeSrtText(srt, 1.5);
    expect(retimed, contains('00:00:00,000 --> 00:00:06,000'));
    expect(retimed, contains('00:00:06,000 --> 00:00:09,000'));
  });
}
