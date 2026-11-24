import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/sfx_service.dart';

void main() {
  test('rain_thunder filter is a single aevalsrc (no chained sine source)', () {
    final filter = sfxFilter('rain_thunder', 6.0);
    expect(filter, contains('aevalsrc'));
    expect(filter, isNot(contains('amix')));
    expect(filter, contains('duration=6.0'));
  });

  test('default pad filter is a single aevalsrc', () {
    final filter = sfxFilter('unknown_type', 4.0);
    expect(filter, contains('aevalsrc'));
    expect(filter, isNot(contains('amix')));
  });

  test('rain, wind, heartbeat and chime filters are non-empty', () {
    for (final type in ['rain', 'wind', 'heartbeat', 'chime', 'whoosh']) {
      expect(sfxFilter(type, 3.0), isNotEmpty);
    }
  });

  test('buildSfxCommand uses lavfi and writes the output path', () {
    final cmd = buildSfxCommand('rain', 5.0, '/tmp/out.wav');
    expect(cmd, contains('lavfi'));
    expect(cmd, contains('"/tmp/out.wav"'));
  });

  test('buildMixCommand mixes narration + SFX at -18 dB by default', () {
    final cmd = buildMixCommand(
      narrationPath: '/tmp/n.wav',
      sfxPath: '/tmp/s.wav',
      outPath: '/tmp/m.wav',
    );
    expect(cmd, contains('amix'));
    // -18 dB -> linear gain 10^(-18/20) = 0.1259.
    expect(cmd, contains('0.1259'));
    expect(cmd, contains('"/tmp/m.wav"'));
  });
}
