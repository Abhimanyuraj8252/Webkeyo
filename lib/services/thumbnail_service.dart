/// Thumbnail skill — 1280x720 YouTube thumbnail with the `image` package.
///
/// Rules baked in (what the user asked for thumbnails: premium,
/// big-YouTuber style, people click on sight):
/// - 1280x720, the YouTube thumbnail size.
/// - BIG bold English text — at most ~5 words, never small.
/// - High contrast: dark gradient + accent colour from the style,
///   white text with a dark outline so it reads at 120px wide.
/// - A label chip (theme/style) + a scene hint line, so the thumbnail
///   says what the video is in one glance.
/// - No generated image needed — gradient + glow + dots, all code.
///   For a character face, add a real image on top in an editor.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/video_style.dart';

/// Generate a 1280x720 thumbnail PNG. Returns the output path.
/// [title] is the big English hook (keep it <= 5 words for impact).
Future<String> generateThumbnail({
  required String title,
  required String outPath,
  String styleId = defaultStyleId,
  String? label,
  String subtitle = '',
}) async {
  if (title.trim().isEmpty) {
    throw ArgumentError('Thumbnail needs a title — one short English hook.');
  }
  final style = getVideoStyle(styleId);
  const w = 1280;
  const h = 720;
  final image = img.Image(width: w, height: h);
  final top = rgbOf(style.topColor);
  final bottom = rgbOf(style.bottomColor);
  final accent = rgbOf(style.accentColor);

  // Vertical gradient.
  for (var y = 0; y < h; y++) {
    final t = y / (h - 1);
    final r = (top[0] + (bottom[0] - top[0]) * t).round();
    final g = (top[1] + (bottom[1] - top[1]) * t).round();
    final b = (top[2] + (bottom[2] - top[2]) * t).round();
    img.drawLine(image, x1: 0, y1: y, x2: w - 1, y2: y, color: img.ColorRgb8(r, g, b));
  }

  // Glow circle, top-right, accent colour.
  _fillCircle(image, 1060, 200, 180, img.ColorRgba8(accent[0], accent[1], accent[2], 60));
  _fillCircle(image, 1060, 200, 110, img.ColorRgba8(accent[0], accent[1], accent[2], 120));

  // Deterministic star dots.
  final rng = math.Random(42);
  for (var i = 0; i < 120; i++) {
    final x = rng.nextInt(w);
    final y = rng.nextInt(h);
    final r = rng.nextInt(3) + 1;
    _fillCircle(image, x, y, r, img.ColorRgba8(255, 255, 255, 90));
  }

  // Bottom dark band so text always reads.
  img.fillRect(image, x1: 0, y1: h - 330, x2: w - 1, y2: h - 1,
      color: img.ColorRgba8(0, 0, 0, 110));

  // Label chip.
  final chip = (label ?? style.label).toUpperCase();
  final chipFont = img.arial24;
  final chipTextWidth = chip.length * 15;
  final chipX = 60;
  final chipY = 56;
  img.fillRect(image, x1: chipX, y1: chipY, x2: chipX + chipTextWidth + 36, y2: chipY + 62,
      color: img.ColorRgb8(accent[0], accent[1], accent[2]));
  img.drawString(image, chip, font: chipFont, x: chipX + 18, y: chipY + 18,
      color: img.ColorRgb8(255, 255, 255));

  // Big title, outlined, bottom-left. arial_48 drawn on a 2x layer so the
  // text reads big and bold at thumbnail size.
  final lines = _wrapTitle(title.trim().toUpperCase(), maxCharsPerLine: 12);
  var y = h - 300;
  for (final line in lines.take(3)) {
    _drawBigText(image, line, 60, y, img.ColorRgb8(255, 255, 255));
    y += 125;
  }

  // Subtitle / scene hint.
  if (subtitle.isNotEmpty) {
    img.drawString(image, subtitle.substring(0, math.min(70, subtitle.length)),
        font: img.arial24, x: 64, y: h - 84,
        color: img.ColorRgb8(accent[0], accent[1], accent[2]));
  }

  // Accent bar at the very bottom.
  img.fillRect(image, x1: 0, y1: h - 14, x2: w - 1, y2: h - 1,
      color: img.ColorRgb8(accent[0], accent[1], accent[2]));

  final bytes = img.encodePng(image);
  final file = File(outPath);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);
  return outPath;
}

List<String> _wrapTitle(String title, {int maxCharsPerLine = 12}) {
  final words = title.split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final trial = current.isEmpty ? word : '$current $word';
    if (trial.length <= maxCharsPerLine) {
      current = trial;
    } else {
      if (current.isNotEmpty) lines.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

/// Draw [text] large and bold: render with arial_48 on a 2x layer, then
/// stamp it with a dark outline for contrast.
void _drawBigText(img.Image image, String text, int x, int y, img.Color color) {
  const scale = 2;
  final layer = img.Image(width: text.length * 26 * scale, height: 60 * scale);
  img.drawString(layer, text, font: img.arial48, x: 0, y: 4, color: img.ColorRgb8(255, 255, 255));
  // Outline: stamp the layer in black at small offsets first.
  for (var dx = -3; dx <= 3; dx++) {
    for (var dy = -3; dy <= 3; dy++) {
      if (dx == 0 && dy == 0) continue;
      img.compositeImage(image, _tinted(layer, 0, 0, 0),
          dstX: x + dx, dstY: y + dy);
    }
  }
  img.compositeImage(image, layer, dstX: x, dstY: y);
}

img.Image _tinted(img.Image src, int r, int g, int b) {
  final out = img.Image(width: src.width, height: src.height);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final a = p.a.toInt();
      if (a > 0) out.setPixel(x, y, img.ColorRgba8(r, g, b, a));
    }
  }
  return out;
}

void _fillCircle(img.Image image, int cx, int cy, int radius, img.Color color) {
  img.fillCircle(image, x: cx, y: cy, radius: radius, color: color);
}
