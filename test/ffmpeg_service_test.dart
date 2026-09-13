import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/ffmpeg_service.dart';

void main() {
  group('resolutionToSize', () {
    test('maps every user-facing resolution', () {
      expect(resolutionToSize('720p'), (width: 1280, height: 720));
      expect(resolutionToSize('1080p'), (width: 1920, height: 1080));
      expect(resolutionToSize('1440p'), (width: 2560, height: 1440));
      expect(resolutionToSize('4K'), (width: 3840, height: 2160));
    });

    test('unknown or null falls back to 1080p', () {
      expect(resolutionToSize(null), (width: 1920, height: 1080));
      expect(resolutionToSize('garbage'), (width: 1920, height: 1080));
      expect(resolutionToSize(''), (width: 1920, height: 1080));
    });
  });
}
