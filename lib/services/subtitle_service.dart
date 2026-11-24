/// Subtitles / captions skill — SRT writing, re-timing, burn-in.
///
/// Rules:
/// - Hindi audio runs longer than the source, so subtitles are re-timed
///   with a factor (default 1.3x) — the same rule as the Katha Studio
///   Python engine, so both agree.
/// - On-screen text is ENGLISH (project rule); the SRT itself may be
///   Hindi / Hinglish for the listener. Default titles/descriptions are
///   Hinglish for Indian audiences, with the original English under the
///   English translation.
/// - Every sample video ships its .srt. Burn-in is done with FFmpeg's
///   subtitles filter for Reels/Shorts (most viewers watch muted).
library;

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Format seconds as an SRT timestamp: 00:01:23,456
String formatSrtTimestamp(double seconds) {
  final totalMs = (seconds * 1000).round();
  final hours = totalMs ~/ 3600000;
  final minutes = (totalMs % 3600000) ~/ 60000;
  final secs = (totalMs % 60000) ~/ 1000;
  final ms = totalMs % 1000;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(secs)},${ms.toString().padLeft(3, '0')}';
}

/// Build SRT text from scenes. Each scene map needs 'narration' (or
/// 'text') and 'est_seconds'. Times accumulate in order; [factor]
/// stretches every cue (Hindi runs ~1.3x longer than the source).
String buildSrt(List<Map<String, dynamic>> scenes, {double factor = 1.3}) {
  final buffer = StringBuffer();
  var cursor = 0.0;
  var index = 1;
  for (final scene in scenes) {
    final text = ((scene['narration'] ?? scene['text'] ?? '') as String).trim();
    if (text.isEmpty) continue;
    final raw = (scene['est_seconds'] as num?)?.toDouble() ?? 6.0;
    final duration = raw * factor;
    buffer.writeln(index);
    buffer.writeln('${formatSrtTimestamp(cursor)} --> ${formatSrtTimestamp(cursor + duration)}');
    buffer.writeln(text);
    buffer.writeln();
    cursor += duration;
    index++;
  }
  return buffer.toString();
}

/// Write the SRT for [scenes] to [outPath]. Returns the path.
Future<String> writeSrt(
  List<Map<String, dynamic>> scenes,
  String outPath, {
  double factor = 1.3,
}) async {
  final file = File(outPath);
  await file.writeAsString(buildSrt(scenes, factor: factor));
  return outPath;
}

/// Re-time an existing SRT file by [factor] (e.g. Hindi 1.3x).
/// Pure function on the SRT text — unit-tested.
String retimeSrtText(String srt, double factor) {
  final timeRe = RegExp(r'(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})');
  double parse(String t) {
    final parts = t.split(RegExp(r'[:,]'));
    return int.parse(parts[0]) * 3600 +
        int.parse(parts[1]) * 60 +
        int.parse(parts[2]) +
        int.parse(parts[3]) / 1000;
  }

  return srt.replaceAllMapped(timeRe, (m) {
    final start = parse(m.group(1)!) * factor;
    final end = parse(m.group(2)!) * factor;
    return '${formatSrtTimestamp(start)} --> ${formatSrtTimestamp(end)}';
  });
}

/// Burn [srtPath] subtitles into [videoPath] -> [outPath] (FFmpeg
/// subtitles filter). Returns the output path. Throws on failure.
Future<String> burnSubtitles({
  required String videoPath,
  required String srtPath,
  required String outPath,
}) async {
  // FFmpeg on Windows needs escaped paths; on Android/iOS the plain path works.
  final safeSrt = srtPath.replaceAll("'", "'\\''");
  final command =
      '-i "$videoPath" -vf "subtitles=\'$safeSrt\':force_style=\'FontSize=28,PrimaryColour=&HFFFFFF&,OutlineColour=&H80000000&,BorderStyle=1\'" '
      '-c:v libx264 -pix_fmt yuv420p -c:a copy -y "$outPath"';
  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getLogsAsString();
    throw Exception('Subtitle burn-in failed: $logs');
  }
  return outPath;
}
