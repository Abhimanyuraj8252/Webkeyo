/// Editing skills — FFmpeg-based cuts, transitions, overlays, end screens.
///
/// No paid editor, no heavy app: every helper here is one FFmpegKit call.
/// Command builders are pure functions (unit-tested); the `run*`
/// wrappers execute them. See SKILLS.md "Editing" for the recipes.
library;

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// FFmpeg concat-demuxer command for a list file at [listPath] -> [outPath].
/// The list file itself (one `file '...'` line per clip) is written by
/// [concatVideos]. Pure function — unit-tested.
String buildConcatCommand(String listPath, String outPath) =>
    '-f concat -safe 0 -i "$listPath" -c copy -y "$outPath"';

/// FFmpeg fade in/out command (video + audio).
String buildFadeCommand(String inPath, String outPath,
    {double fadeIn = 0.5, double fadeOut = 0.5, required double duration}) {
  final tOut = (duration - fadeOut).clamp(0.0, duration).toStringAsFixed(2);
  return '-i "$inPath" '
      '-vf "fade=t=in:st=0:d=$fadeIn,fade=t=out:st=$tOut:d=$fadeOut" '
      '-af "afade=t=in:st=0:d=$fadeIn,afade=t=out:st=$tOut:d=$fadeOut" '
      '-c:v libx264 -pix_fmt yuv420p -c:a aac -y "$outPath"';
}

/// FFmpeg crossfade (xfade + acrossfade) from [aPath] to [bPath].
String buildCrossfadeCommand(String aPath, String bPath, String outPath,
    {String transition = 'fade', double duration = 1.0, required double durationA}) {
  final offset = (durationA - duration).clamp(0.0, durationA).toStringAsFixed(2);
  return '-i "$aPath" -i "$bPath" -filter_complex '
      '"[0:v][1:v]xfade=transition=$transition:duration=$duration:offset=$offset[v];'
      '[0:a][1:a]acrossfade=d=$duration[a]" '
      '-map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -c:a aac -y "$outPath"';
}

/// FFmpeg speed ramp command (setpts + atempo). speed > 1 = faster.
String buildSpeedCommand(String inPath, String outPath, double speed) {
  if (speed < 0.5 || speed > 100) {
    throw ArgumentError('speed must be 0.5-100 (atempo limit)');
  }
  final pts = (1.0 / speed).toStringAsFixed(4);
  return '-i "$inPath" -filter_complex '
      '"[0:v]setpts=$pts*PTS[v];[0:a]atempo=$speed[a]" '
      '-map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -c:a aac -y "$outPath"';
}

/// FFmpeg drawtext overlay command (one line of English text).
String buildTextOverlayCommand(String inPath, String outPath, String text,
    {int fontSize = 48, String y = 'h-160'}) {
  final safe = text.replaceAll("'", '`');
  return '-i "$inPath" -vf "drawtext=text=\'$safe\':fontsize=$fontSize:'
      'fontcolor=white:box=1:boxcolor=black@0.5:x=(w-text_w)/2:y=$y" '
      '-c:v libx264 -pix_fmt yuv420p -c:a copy -y "$outPath"';
}

/// FFmpeg end-screen command: a dark band with "WATCH NEXT" + the next
/// video's title burned into the LAST [seconds] of the video.
/// This is the project's end-screen rule in its simplest working form.
String buildEndScreenCommand(String inPath, String outPath, String nextTitle,
    {double seconds = 5.0, required double duration}) {
  final start = (duration - seconds).clamp(0.0, duration).toStringAsFixed(2);
  const bandH = 220;
  final safe = nextTitle.replaceAll("'", '`');
  return '-i "$inPath" -vf '
      '"drawbox=y=ih-$bandH:color=black@0.75:width=iw:height=$bandH:t=fill:enable=\'gte(t,$start)\','
      'drawtext=text=\'WATCH NEXT\':fontsize=44:fontcolor=yellow:x=(w-text_w)/2:y=h-${bandH - 20}:enable=\'gte(t,$start)\','
      'drawtext=text=\'$safe\':fontsize=40:fontcolor=white:x=(w-text_w)/2:y=h-${bandH - 90}:enable=\'gte(t,$start)\'" '
      '-c:v libx264 -pix_fmt yuv420p -c:a copy -y "$outPath"';
}

Future<String> _run(String command, String what) async {
  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getLogsAsString();
    throw Exception('FFmpeg $what failed: $logs');
  }
  return command;
}

/// Join MP4s (same codec/size) in order. Returns outPath.
Future<String> concatVideos(List<String> paths, String outPath) async {
  if (paths.length < 2) {
    throw ArgumentError('concat needs at least 2 videos');
  }
  // Write the concat list file next to the output, then run the demuxer.
  final listPath = '$outPath.concat.txt';
  final buffer = StringBuffer();
  for (final p in paths) {
    buffer.writeln("file '${p.replaceAll("'", "'\\''")}'");
  }
  await _writeFile(listPath, buffer.toString());
  try {
    await _run(buildConcatCommand(listPath, outPath), 'concat');
  } finally {
    await _deleteFile(listPath);
  }
  return outPath;
}

Future<String> fadeInOut(String inPath, String outPath,
        {double fadeIn = 0.5, double fadeOut = 0.5, required double duration}) async =>
    _runAndReturn(
        buildFadeCommand(inPath, outPath, fadeIn: fadeIn, fadeOut: fadeOut, duration: duration),
        'fade in/out',
        outPath);

Future<String> crossfade(String aPath, String bPath, String outPath,
        {String transition = 'fade', double duration = 1.0, required double durationA}) async =>
    _runAndReturn(
        buildCrossfadeCommand(aPath, bPath, outPath,
            transition: transition, duration: duration, durationA: durationA),
        'crossfade',
        outPath);

Future<String> speedRamp(String inPath, String outPath, double speed) async =>
    _runAndReturn(buildSpeedCommand(inPath, outPath, speed), 'speed ramp', outPath);

Future<String> addTextOverlay(String inPath, String outPath, String text,
        {int fontSize = 48, String y = 'h-160'}) async =>
    _runAndReturn(
        buildTextOverlayCommand(inPath, outPath, text, fontSize: fontSize, y: y),
        'text overlay',
        outPath);

Future<String> addEndScreen(String inPath, String outPath, String nextTitle,
        {double seconds = 5.0, required double duration}) async =>
    _runAndReturn(
        buildEndScreenCommand(inPath, outPath, nextTitle, seconds: seconds, duration: duration),
        'end screen',
        outPath);

Future<String> _runAndReturn(String command, String what, String outPath) async {
  await _run(command, what);
  return outPath;
}

Future<void> _writeFile(String path, String content) async {
  await File(path).writeAsString(content);
}

Future<void> _deleteFile(String path) async {
  try {
    await File(path).delete();
  } catch (_) {
    // Non-fatal cleanup failure.
  }
}
