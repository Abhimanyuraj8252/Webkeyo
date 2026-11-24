import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/voice_providers.dart';

void main() {
  test('pcmToWav wraps PCM in a valid WAV header', () {
    final pcm = Uint8List.fromList(List<int>.generate(2400, (i) => i % 256));
    final wav = pcmToWav(pcm, sampleRate: 24000);
    // RIFF header.
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    // 44-byte header + PCM.
    expect(wav.length, 44 + pcm.length);
    // PCM bytes survive intact after the header.
    expect(wav.sublist(44), pcm);
  });

  test('hexToBytes decodes hex and rejects bad input', () {
    expect(hexToBytes('00ff10'), Uint8List.fromList([0x00, 0xFF, 0x10]));
    expect(hexToBytes(''), isEmpty);
    expect(() => hexToBytes('zz'), throwsFormatException);
    expect(() => hexToBytes('abc'), throwsFormatException);
  });
}
