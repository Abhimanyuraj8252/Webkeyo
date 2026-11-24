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

// ---------------------------------------------------------------------------
// Karaoke-style captions (v1.2.0) — word-by-word highlight (.ass).
//
// The SRT sidecar is per-line; karaoke is per-word: each word gets a
// {\kN} tag (N = centiseconds the word stays highlighted) and the
// .ass player / FFmpeg subtitles filter sweeps the highlight colour
// across the words as the narration speaks. Word timing is estimated
// from the scene duration divided by the word count — the same
// estimate the SRT re-timing already uses, so both agree.
// ---------------------------------------------------------------------------

/// Format seconds as an ASS timestamp: 0:01:23.45
String formatAssTimestamp(double seconds) {
  final totalCs = (seconds * 100).round();
  final hours = totalCs ~/ 360000;
  final minutes = (totalCs % 360000) ~/ 6000;
  final secs = (totalCs % 6000) ~/ 100;
  final cs = totalCs % 100;
  String two(int n) => n.toString().padLeft(2, '0');
  return '$hours:${two(minutes)}:${two(secs)}.${two(cs)}';
}

/// Build a karaoke .ass file from scenes. Each scene map needs
/// 'narration' (or 'text') and 'est_seconds'. [factor] stretches every
/// cue (Hindi runs ~1.3x longer than the source). Words are timed
/// evenly across the scene — good enough for a highlight sweep, and
/// exact per-word timing is a future improvement (needs forced
/// alignment, which no free on-device API provides yet).
String buildKaraokeAss(List<Map<String, dynamic>> scenes,
    {double factor = 1.3}) {
  final buffer = StringBuffer();
  buffer.writeln('[Script Info]');
  buffer.writeln('Title: Webkeyo karaoke captions');
  buffer.writeln('ScriptType: v4.00+');
  buffer.writeln('PlayResX: 720');
  buffer.writeln('PlayResY: 1280');
  buffer.writeln('WrapStyle: 0');
  buffer.writeln();
  buffer.writeln('[V4+ Styles]');
  buffer.writeln(
      'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
  // Primary = white (after highlight), Secondary = yellow (the sweep).
  buffer.writeln(
      'Style: Karaoke,Arial,36,&H00FFFFFF,&H0000FFFF,&H80000000,&H80000000,1,0,0,0,100,100,0,0,1,2,0,2,40,40,120,1');
  buffer.writeln();
  buffer.writeln('[Events]');
  buffer.writeln(
      'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');
  var cursor = 0.0;
  for (final scene in scenes) {
    final text = ((scene['narration'] ?? scene['text'] ?? '') as String).trim();
    if (text.isEmpty) continue;
    final est = (scene['est_seconds'] as num?)?.toDouble() ?? 5.0;
    final duration = est * factor;
    final start = cursor;
    final end = cursor + duration;
    cursor = end;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) continue;
    // Even split; at least 10 centiseconds per word so the sweep is visible.
    final perWordCs = ((duration / words.length) * 100).round().clamp(10, 10000);
    final karaokeText = words
        .map((w) {
          final safe = w.replaceAll('\\', '').replaceAll('{', '').replaceAll('}', '');
          return '{\\k$perWordCs}$safe';
        })
        .join(' ');
    buffer.writeln(
        'Dialogue: 0,${formatAssTimestamp(start)},${formatAssTimestamp(end)},Karaoke,,0,0,0,,${karaokeText.trim()}');
  }
  return buffer.toString();
}

/// Write the karaoke .ass file next to the SRT. Returns the path.
Future<String> writeKaraokeAss(
  List<Map<String, dynamic>> scenes,
  String outPath, {
  double factor = 1.3,
}) async {
  final file = File(outPath);
  await file.writeAsString(buildKaraokeAss(scenes, factor: factor));
  return outPath;
}

/// Burn karaoke [assPath] captions into [videoPath] -> [outPath]
/// (FFmpeg subtitles filter handles .ass, including the \k sweep).
/// Returns the output path. Throws on failure.
Future<String> burnKaraokeSubtitles({
  required String videoPath,
  required String assPath,
  required String outPath,
}) async {
  final safeAss = assPath.replaceAll("'", "'\\''");
  final command =
      '-i "$videoPath" -vf "subtitles=\'$safeAss\'" '
      '-c:v libx264 -pix_fmt yuv420p -c:a copy -y "$outPath"';
  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getLogsAsString();
    throw Exception('Karaoke burn-in failed: $logs');
  }
  return outPath;
}
