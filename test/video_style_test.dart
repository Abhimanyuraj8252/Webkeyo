import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/models/video_style.dart';

void main() {
  test('10 styles, all with names and distinct ids', () {
    expect(videoStyles.length, 10);
    expect(styleIds.length, 10);
    expect(styleIds.toSet().length, 10);
    for (final style in videoStyles.values) {
      expect(style.label.trim(), isNotEmpty);
      expect(style.id.trim(), isNotEmpty);
    }
  });

  test('getVideoStyle returns the style, default exists, unknown throws', () {
    final style = getVideoStyle('horror-night');
    expect(style.id, 'horror-night');
    expect(getVideoStyle(defaultStyleId).id, defaultStyleId);
    expect(getVideoStyle(null).id, defaultStyleId);
    expect(getVideoStyle('').id, defaultStyleId);
    expect(() => getVideoStyle('not-a-style'), throwsArgumentError);
  });

  test('styleIdForTheme maps known themes, falls back to default', () {
    expect(styleIdForTheme('haunted'), 'horror-night');
    expect(styleIdForTheme('love'), 'romantic-pink');
    expect(styleIdForTheme('something-unknown'), defaultStyleId);
  });

  test('rgbOf decodes the ARGB colour', () {
    expect(rgbOf(0xFF112233), [0x11, 0x22, 0x33]);
  });
}
