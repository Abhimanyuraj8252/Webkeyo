import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/thumbnail_service.dart';

void main() {
  test('generateThumbnail writes a 1280x720 PNG', () async {
    final dir = await Directory.systemTemp.createTemp('webkeyo_thumb_test');
    try {
      final outPath = '${dir.path}/thumb.png';
      final result = await generateThumbnail(
        title: 'Haunted Inn',
        outPath: outPath,
        styleId: 'horror-night',
        label: 'HINDI DUB',
      );
      expect(result, outPath);
      final file = File(outPath);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(1000));
      // PNG magic bytes.
      expect(bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      // Width/height from the IHDR chunk (bytes 16-23, big-endian).
      final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      expect(width, 1280);
      expect(height, 720);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('generateThumbnail rejects an empty title', () async {
    await expectLater(
      generateThumbnail(title: '   ', outPath: '/tmp/never.png'),
      throwsArgumentError,
    );
  });
}
