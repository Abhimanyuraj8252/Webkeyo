/// Prompt-to-video — prompt in, reel/video out, ₹0.
///
/// Code-only motion graphics, no paid video API, no stock download:
///   prompt -> script_generator -> scenes
///   -> image package draws each frame (gradient, glow, particles,
///      hook title, speaker/emotion chip, progress bar, burned English
///      subtitle text)
///   -> FFmpegKit zoompan (Ken Burns) turns the frames into a video
///   -> narration (TtsService, per-character voices) + synthesised SFX
///      mixed underneath at -18 dB
///   -> vertical 720x1280 (reel) or horizontal 1280x720.
///
/// What this is NOT: real actors, AI-generated video clips, or
/// photographic imagery. It is code-drawn motion graphics — the same
/// idea as the Katha Studio Python engine (kept as reference), ported
/// to Dart so it runs on the phone.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;

import '../models/video_style.dart';
import 'character_voices.dart';
import 'script_generator.dart';
import 'sfx_service.dart';
import 'subtitle_service.dart';
import 'thumbnail_service.dart';
import 'tts_service.dart';

/// One render job, for the UI progress bar.
class PromptVideoProgress {
  final String stage;
  final double fraction; // 0..1
  const PromptVideoProgress(this.stage, this.fraction);
}

class PromptVideoResult {
  final String videoPath;
  final String srtPath;
  final String thumbnailPath;
  final int sceneCount;
  final double durationSeconds;
  final String styleId;
  final bool vertical;

  const PromptVideoResult({
    required this.videoPath,
    required this.srtPath,
    required this.thumbnailPath,
    required this.sceneCount,
    required this.durationSeconds,
    required this.styleId,
    required this.vertical,
  });
}

/// Pick the SFX type for a style/genre.
String sfxForStyle(String styleId, String genre) {
  switch (styleId) {
    case 'horror-night':
      return 'rain_thunder';
    case 'romantic-pink':
      return 'chime';
    case 'motivational-gold':
      return 'whoosh';
    case 'neon-cyberpunk':
      return 'wind';
    default:
      if (genre == 'haunted' || genre == 'mystery') return 'rain_thunder';
      if (genre == 'sad') return 'wind';
      return 'rain';
  }
}

/// Draw one frame for a scene. Pure-ish (writes nothing, returns the
/// image) — the caller saves it. [progress] is 0..1 within the scene
/// (drives the zoom / moving glow).
img.Image drawSceneFrame({
  required Map<String, dynamic> scene,
  required VideoStyle style,
  required int width,
  required int height,
  double progress = 0.0,
  String title = '',
  int sceneIndex = 0,
  int totalScenes = 1,
}) {
  final image = img.Image(width: width, height: height);
  final top = rgbOf(style.topColor);
  final bottom = rgbOf(style.bottomColor);
  final accent = rgbOf(style.accentColor);

  // Vertical gradient.
  for (var y = 0; y < height; y++) {
    final t = y / (height - 1);
    final r = (top[0] + (bottom[0] - top[0]) * t).round();
    final g = (top[1] + (bottom[1] - top[1]) * t).round();
    final b = (top[2] + (bottom[2] - top[2]) * t).round();
    img.drawLine(image, x1: 0, y1: y, x2: width - 1, y2: y,
        color: img.ColorRgb8(r, g, b));
  }

  // Glow drifting with progress (Ken Burns feel).
  final gx = (width * (0.25 + 0.5 * progress)).round();
  final gy = (height * (0.3 + 0.1 * math.sin(progress * math.pi))).round();
  img.fillCircle(image, x: gx, y: gy, radius: width ~/ 3,
      color: img.ColorRgba8(accent[0], accent[1], accent[2], 45));
  img.fillCircle(image, x: gx, y: gy, radius: width ~/ 6,
      color: img.ColorRgba8(accent[0], accent[1], accent[2], 90));

  // Deterministic particles from the scene index.
  final rng = math.Random(1000 + sceneIndex * 7);
  final particleCount = style.particle == 'none' ? 0 : 90;
  for (var i = 0; i < particleCount; i++) {
    final x = rng.nextInt(width);
    final y = rng.nextInt(height);
    final r = rng.nextInt(3) + 1;
    img.fillCircle(image, x: x, y: y, radius: r,
        color: img.ColorRgba8(255, 255, 255, 70));
  }

  // Bottom band for text.
  img.fillRect(image, x1: 0, y1: height - 260, x2: width - 1, y2: height - 1,
      color: img.ColorRgba8(0, 0, 0, 120));

  // Hook title on scene 1.
  if (sceneIndex == 0 && title.isNotEmpty) {
    final lines = _wrap(title.toUpperCase(), 22);
    var y = 60;
    for (final line in lines.take(2)) {
      img.drawString(image, line, font: img.arial48, x: 48, y: y,
          color: img.ColorRgb8(255, 255, 255));
      y += 70;
    }
    // Accent underline.
    img.fillRect(image, x1: 48, y1: y + 8, x2: 48 + 160, y2: y + 18,
        color: img.ColorRgb8(accent[0], accent[1], accent[2]));
  }

  // Speaker / emotion chip.
  final speaker = (scene['speaker'] ?? 'Narrator') as String;
  final emotion = (scene['emotion'] ?? 'calm') as String;
  final chip = '$speaker • $emotion'.toUpperCase();
  img.fillRect(image, x1: 48, y1: height - 330, x2: 48 + chip.length * 13 + 30,
      y2: height - 330 + 46, color: img.ColorRgb8(accent[0], accent[1], accent[2]));
  img.drawString(image, chip, font: img.arial24, x: 62, y: height - 318,
      color: img.ColorRgb8(255, 255, 255));

  // Narration text (English on screen — project rule).
  final text = ((scene['narration'] ?? '') as String).trim();
  if (text.isNotEmpty) {
    final lines = _wrap(text, 34);
    var y = height - 250;
    for (final line in lines.take(3)) {
      img.drawString(image, line, font: img.arial24, x: 48, y: y,
          color: img.ColorRgb8(255, 255, 255));
      y += 36;
    }
  }

  // Progress bar (bottom).
  final filled = ((sceneIndex + progress) / totalScenes * width).round();
  img.fillRect(image, x1: 0, y1: height - 12, x2: width - 1, y2: height - 1,
      color: img.ColorRgba8(255, 255, 255, 40));
  if (filled > 0) {
    img.fillRect(image, x1: 0, y1: height - 12, x2: filled, y2: height - 1,
        color: img.ColorRgb8(accent[0], accent[1], accent[2]));
  }
  return image;
}

List<String> _wrap(String text, int maxChars) {
  final words = text.split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final trial = current.isEmpty ? word : '$current $word';
    if (trial.length <= maxChars) {
      current = trial;
    } else {
      if (current.isNotEmpty) lines.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

/// Render a prompt-to-video. Returns paths + counts. Throws on failure.
Future<PromptVideoResult> renderPromptVideo({
  required String prompt,
  required String genre,
  String styleId = defaultStyleId,
  bool vertical = true,
  double fps = 12.0,
  required String outDir,
  required TtsService tts,
  void Function(PromptVideoProgress progress)? onProgress,
}) async {
  final style = getVideoStyle(styleId);
  final width = vertical ? 720 : 1280;
  final height = vertical ? 1280 : 720;
  final dir = Directory(outDir);
  await dir.create(recursive: true);

  void report(String stage, double f) => onProgress?.call(PromptVideoProgress(stage, f));

  report('Script likh raha hoon…', 0.05);
  final script = generateScript(prompt, genre);
  final scenes = script['scenes'] as List<Map<String, dynamic>>;
  final voiceMap = CharacterVoiceMap.fromScenes(scenes);

  // --- Narration audio per scene (per-character voice + emotion) ---
  report('Voiceover bana raha hoon…', 0.15);
  final sceneAudio = <String>[];
  final sceneSeconds = <double>[];
  for (var i = 0; i < scenes.length; i++) {
    final scene = scenes[i];
    final line = narratorLineForScene(scene);
    final profile = voiceMap.profileFor(line['speaker'] as String);
    final audioPath = '${dir.path}/scene_${i + 1}.mp3';
    try {
      await tts.synthesizeSpeech(
        line['text'] as String,
        voice: profile.voiceIdFor(tts.currentProvider),
        speed: paceForEmotion(line['emotion'] as String),
        providerOverride: null,
        outputPath: audioPath,
      );
    } catch (e) {
      // A failed scene voice must not kill the whole render — but it
      // must never be silent either. Fall back to the default TTS.
      await tts.synthesizeSpeech(
        line['text'] as String,
        speed: paceForEmotion(line['emotion'] as String),
        outputPath: audioPath,
      );
    }
    sceneAudio.add(audioPath);
    sceneSeconds.add(((scene['est_seconds'] as num?)?.toDouble() ?? 6.0) * 1.3);
  }
  final totalSeconds = sceneSeconds.fold<double>(0, (a, b) => a + b);

  // --- SFX bed + mix under narration ---
  report('SFX mix kar raha hoon…', 0.4);
  final sfxType = sfxForStyle(styleId, genre);
  final sfxPath = '${dir.path}/sfx.wav';
  await generateSfx(type: sfxType, seconds: totalSeconds, outPath: sfxPath);
  final narrationPath = '${dir.path}/narration.mp3';
  await _concatAudio(sceneAudio, narrationPath);
  final mixedPath = '${dir.path}/audio_mixed.m4a';
  final mixCommand = buildMixCommand(
      narrationPath: narrationPath, sfxPath: sfxPath, outPath: mixedPath);
  await _runFfmpeg(mixCommand, 'audio mix');

  // --- Frames per scene (2 keyframes each: start + end, zoompan fills
  // the frames between them) ---
  report('Frames bana raha hoon…', 0.55);
  final sceneVideos = <String>[];
  for (var i = 0; i < scenes.length; i++) {
    final scene = scenes[i];
    final frameDir = '${dir.path}/scene_${i + 1}_frames';
    await Directory(frameDir).create(recursive: true);
    for (var k = 0; k < 2; k++) {
      final frame = drawSceneFrame(
        scene: scene,
        style: style,
        width: width,
        height: height,
        progress: k == 0 ? 0.0 : 1.0,
        title: prompt,
        sceneIndex: i,
        totalScenes: scenes.length,
      );
      await File('$frameDir/frame_$k.png').writeAsBytes(img.encodePng(frame));
    }
    final sceneVideo = '${dir.path}/scene_${i + 1}.mp4';
    final seconds = sceneSeconds[i];
    final zoomCmd = '-loop 1 -i "$frameDir/frame_0.png" -i "$frameDir/frame_1.png" '
        '-filter_complex "[0:v]scale=8000:-1,zoompan=z=\'min(zoom+0.0008,1.35)\':'
        'd=${(seconds * fps).round()}:x=\'iw/2-(iw/zoom/2)\':y=\'ih/2-(ih/zoom/2)\':s=${width}x$height:fps=$fps[v]" '
        '-map "[v]" -t ${seconds.toStringAsFixed(1)} -c:v libx264 -pix_fmt yuv420p -y "$sceneVideo"';
    await _runFfmpeg(zoomCmd, 'scene ${i + 1} render');
    sceneVideos.add(sceneVideo);
    report('Scene ${i + 1}/${scenes.length} render…', 0.55 + 0.3 * (i + 1) / scenes.length);
  }

  // --- Concat + mux audio ---
  report('Final video jod raha hoon…', 0.9);
  final concatList = '${dir.path}/concat.txt';
  final listBuffer = StringBuffer();
  for (final v in sceneVideos) {
    listBuffer.writeln("file '$v'");
  }
  await File(concatList).writeAsString(listBuffer.toString());
  final videoPath = '${dir.path}/video.mp4';
  await _runFfmpeg(
      '-f concat -safe 0 -i "$concatList" -i "$mixedPath" -map 0:v -map 1:a '
      '-c:v libx264 -pix_fmt yuv420p -c:a aac -shortest -y "$videoPath"',
      'final mux');

  // --- SRT + thumbnail ---
  final srtPath = '${dir.path}/video.srt';
  await writeSrt(scenes, srtPath);
  final thumbPath = '${dir.path}/thumbnail.png';
  await generateThumbnail(
      title: prompt, styleId: styleId, outPath: thumbPath, label: genre);

  report('Ho gaya!', 1.0);
  return PromptVideoResult(
    videoPath: videoPath,
    srtPath: srtPath,
    thumbnailPath: thumbPath,
    sceneCount: scenes.length,
    durationSeconds: totalSeconds,
    styleId: styleId,
    vertical: vertical,
  );
}

Future<void> _concatAudio(List<String> paths, String outPath) async {
  final listPath = '$outPath.concat.txt';
  final buffer = StringBuffer();
  for (final p in paths) {
    buffer.writeln("file '$p'");
  }
  await File(listPath).writeAsString(buffer.toString());
  try {
    await _runFfmpeg('-f concat -safe 0 -i "$listPath" -c copy -y "$outPath"', 'audio concat');
  } finally {
    try {
      await File(listPath).delete();
    } catch (_) {}
  }
}

Future<void> _runFfmpeg(String command, String what) async {
  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getLogsAsString();
    throw Exception('FFmpeg $what failed: $logs');
  }
}
