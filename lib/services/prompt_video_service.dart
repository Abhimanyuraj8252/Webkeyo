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
/// Duration is unlimited: [renderPromptVideo] takes a target duration
/// (any minutes, no cap) and scales scenes, TTS, SFX (looped past 2
/// minutes) and subtitles to it; purposes tune pacing/tone/SFX; a
/// code-drawn character bust can be drawn into every frame. The render
/// is chunked with progress + per-step timeouts and a user cancel, so
/// a long render never freezes or kills the app. A caller-supplied
/// scene list ([scenesOverride]) renders instead of generating one —
/// that is how the scene editor and PDF-lecture import feed this engine.
///
/// What this is NOT: real actors, AI-generated video clips, or
/// photographic imagery. It is code-drawn motion graphics — the same
/// idea as the Katha Studio Python engine (kept as reference), ported
/// to Dart so it runs on the phone.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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
import 'video_purpose.dart';

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

  /// Chapters in the video (1 for a short reel).
  final int chapters;

  /// Karaoke .ass path — only when karaoke captions were requested.
  final String? karaokePath;

  const PromptVideoResult({
    required this.videoPath,
    required this.srtPath,
    required this.thumbnailPath,
    required this.sceneCount,
    required this.durationSeconds,
    required this.styleId,
    required this.vertical,
    this.chapters = 1,
    this.karaokePath,
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

/// Character-design ids the motion-graphics engine can draw in code.
/// 'none' draws no character (the classic look). Every design is drawn
/// with the `image` package only — no network, no stock, no assets.
const characterDesignIds = <String>['anime', '3d', 'silhouette', 'none'];

const characterDesignLabels = <String, String>{
  'anime': 'Anime',
  '3d': '3D Style',
  'silhouette': 'Silhouette',
  'none': 'No character',
};

/// Draws a code-drawn character bust (head + hair + eyes + shoulders)
/// inside the box [bx0, by0, bx1, by1] on [image], in the style
/// [design]. [accent] is the style accent colour; [progress] (0..1)
/// bobs the character gently so it feels alive across keyframes.
/// Pure drawing — never throws for a known design id; 'none' and
/// unknown ids draw nothing.
void drawCharacterDesign(
  img.Image image, {
  required String design,
  required int bx0,
  required int by0,
  required int bx1,
  required int by1,
  required img.Color accent,
  double progress = 0.0,
}) {
  if (design == 'none' || design.isEmpty) return;
  final w = bx1 - bx0;
  final h = by1 - by0;
  if (w <= 0 || h <= 0) return;
  final cx = bx0 + (w * 0.5).round();
  // Radius fits both dimensions so the bust never overflows the box.
  final r = math.min((w * 0.26).round(), (h * 0.30).round());
  if (r < 8) return;
  final bob = (math.sin(progress * math.pi) * 4).round();
  final cy = by0 + (h * 0.32).round() + bob;
  final skin = img.ColorRgb8(245, 205, 175);
  final dark = img.ColorRgb8(30, 28, 52);
  final white = img.ColorRgb8(255, 255, 255);
  final pink = img.ColorRgba8(255, 140, 160, 90);

  if (design == 'silhouette') {
    // Solid black bust with a glowing accent rim — cheap, premium look.
    final body = img.ColorRgb8(12, 12, 18);
    img.fillPolygon(
      image,
      vertices: [
        img.Point(cx - (r * 1.15).round(), by1),
        img.Point(cx - (r * 0.85).round(), cy + r),
        img.Point(cx + (r * 0.85).round(), cy + r),
        img.Point(cx + (r * 1.15).round(), by1),
      ],
      color: body,
    );
    img.fillCircle(image, x: cx, y: cy, radius: r, color: body);
    img.drawCircle(image, x: cx, y: cy, radius: r + 2, color: accent);
    img.drawCircle(image, x: cx, y: cy, radius: r + 3, color: accent);
    img.drawLine(
      image,
      x1: cx - (r * 0.85).round(),
      y1: cy + r,
      x2: cx - (r * 1.05).round(),
      y2: by1,
      color: accent,
    );
    return;
  }

  // Shoulders / outfit: a trapezoid in a darkened accent.
  final ac = accent is img.ColorRgb8 ? accent : img.ColorRgb8(90, 80, 200);
  final outfit = img.ColorRgb8(
    (ac.r * 0.45).round(),
    (ac.g * 0.45).round(),
    (ac.b * 0.45).round(),
  );
  img.fillPolygon(
    image,
    vertices: [
      img.Point(bx0 + 4, by1),
      img.Point(cx - (r * 0.9).round(), cy + (r * 1.05).round()),
      img.Point(cx + (r * 0.9).round(), cy + (r * 1.05).round()),
      img.Point(bx1 - 4, by1),
    ],
    color: outfit,
  );
  // Collar triangle in the accent colour.
  img.fillPolygon(
    image,
    vertices: [
      img.Point(cx - (r * 0.35).round(), cy + (r * 1.05).round()),
      img.Point(cx + (r * 0.35).round(), cy + (r * 1.05).round()),
      img.Point(cx, cy + (r * 1.45).round()),
    ],
    color: ac,
  );

  // Head.
  img.fillCircle(image, x: cx, y: cy, radius: r, color: skin);
  if (design == '3d') {
    // Gloss + shadow give the smooth 3D-render look.
    img.fillCircle(
      image,
      x: cx - (r * 0.35).round(),
      y: cy - (r * 0.4).round(),
      radius: (r * 0.45).round(),
      color: img.ColorRgba8(255, 255, 255, 70),
    );
    img.fillCircle(
      image,
      x: cx + (r * 0.35).round(),
      y: cy + (r * 0.35).round(),
      radius: (r * 0.85).round(),
      color: img.ColorRgba8(0, 0, 0, 55),
    );
    // Smooth hair cap: two overlapping circles.
    img.fillCircle(
      image,
      x: cx,
      y: cy - (r * 0.18).round(),
      radius: (r * 1.02).round(),
      color: dark,
    );
    img.fillCircle(
      image,
      x: cx,
      y: cy + (r * 0.22).round(),
      radius: (r * 0.9).round(),
      color: skin,
    );
    img.fillCircle(
      image,
      x: cx - (r * 0.4).round(),
      y: cy - (r * 0.55).round(),
      radius: (r * 0.3).round(),
      color: img.ColorRgba8(255, 255, 255, 60),
    );
  } else {
    // Anime: spiky hair — cap circle, then triangles along the top.
    img.fillCircle(
      image,
      x: cx,
      y: cy - (r * 0.15).round(),
      radius: (r * 1.02).round(),
      color: dark,
    );
    img.fillCircle(
      image,
      x: cx,
      y: cy + (r * 0.12).round(),
      radius: (r * 0.88).round(),
      color: skin,
    );
    for (var i = 0; i < 5; i++) {
      final a = math.pi * (1.15 + i * 0.175);
      final tipX = cx + (math.cos(a) * r * 1.45).round();
      final tipY = cy + (math.sin(a) * r * 1.45).round();
      final a1 = a - 0.09;
      final a2 = a + 0.09;
      img.fillPolygon(
        image,
        vertices: [
          img.Point(cx + (math.cos(a1) * r * 0.95).round(),
              cy + (math.sin(a1) * r * 0.95).round()),
          img.Point(tipX, tipY),
          img.Point(cx + (math.cos(a2) * r * 0.95).round(),
              cy + (math.sin(a2) * r * 0.95).round()),
        ],
        color: dark,
      );
    }
    // One accent hair strand.
    img.fillPolygon(
      image,
      vertices: [
        img.Point(cx - (r * 0.55).round(), cy - (r * 0.9).round()),
        img.Point(cx - (r * 0.3).round(), cy - (r * 1.35).round()),
        img.Point(cx - (r * 0.15).round(), cy - (r * 0.85).round()),
      ],
      color: ac,
    );
  }

  // Eyes: white + dark pupil + highlight, for both anime and 3D.
  final eyeY = cy + (r * 0.05).round();
  final eyeR = (r * 0.16).round();
  for (final dx in [-0.38, 0.38]) {
    final ex = cx + (r * dx).round();
    img.fillCircle(image, x: ex, y: eyeY, radius: eyeR, color: white);
    img.fillCircle(
      image,
      x: ex,
      y: eyeY + (r * 0.03).round(),
      radius: (r * 0.08).round(),
      color: dark,
    );
    img.fillCircle(
      image,
      x: ex - (r * 0.04).round(),
      y: eyeY - (r * 0.05).round(),
      radius: (r * 0.03).round(),
      color: white,
    );
    // Brow.
    img.drawLine(
      image,
      x1: ex - (r * 0.14).round(),
      y1: eyeY - (r * 0.24).round(),
      x2: ex + (r * 0.14).round(),
      y2: eyeY - (r * 0.26).round(),
      color: dark,
    );
  }
  // Blush + mouth.
  img.fillCircle(
    image,
    x: cx - (r * 0.55).round(),
    y: cy + (r * 0.35).round(),
    radius: (r * 0.14).round(),
    color: pink,
  );
  img.fillCircle(
    image,
    x: cx + (r * 0.55).round(),
    y: cy + (r * 0.35).round(),
    radius: (r * 0.14).round(),
    color: pink,
  );
  img.drawLine(
    image,
    x1: cx - (r * 0.14).round(),
    y1: cy + (r * 0.55).round(),
    x2: cx + (r * 0.14).round(),
    y2: cy + (r * 0.55).round(),
    color: dark,
  );
}

/// Renders a small code-drawn preview of [styleId] (with the chosen
/// character design) and returns PNG bytes. The preview is built by the
/// same engine that renders real videos, so what the user sees is what
/// they get. Pure drawing — no network, no assets.
Uint8List buildStylePreviewBytes({
  String styleId = 'anime-premium',
  String characterDesign = 'anime',
  String genre = 'haunted',
  String prompt = 'A boy enters a haunted inn at midnight.',
}) {
  final style = getVideoStyle(styleId);
  final scene = <String, dynamic>{
    'speaker': 'Narrator',
    'emotion': 'scared',
    'narration': prompt,
  };
  final frame = drawSceneFrame(
    scene: scene,
    style: style,
    width: 360,
    height: 640,
    progress: 0.35,
    title: 'HAUNTED NIGHT',
    sceneIndex: 0,
    totalScenes: 1,
    characterDesign: characterDesign,
  );
  return Uint8List.fromList(img.encodePng(frame));
}

/// Thrown when the user cancels a render. The screen turns it into a
/// friendly "Render cancelled" message — never a crash.
class RenderCancelled implements Exception {
  const RenderCancelled();
  @override
  String toString() => 'Render cancelled';
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
  String characterDesign = 'none',
  img.Image? baseImage,
}) {
  // A supplied base image (PDF lecture page) replaces the gradient /
  // glow / particles — the page itself is the visual. Otherwise the
  // code-drawn motion-graphics background is painted.
  final img.Image image;
  if (baseImage != null) {
    image = img.copyResize(baseImage, width: width, height: height);
  } else {
    image = img.Image(width: width, height: height);
  }
  final top = rgbOf(style.topColor);
  final bottom = rgbOf(style.bottomColor);
  final accent = rgbOf(style.accentColor);

  if (baseImage == null) {
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
  }

  // Code-drawn character bust on the right, above the text band.
  // Skipped for page-image frames (the page is the visual).
  if (baseImage == null && characterDesign != 'none') {
    drawCharacterDesign(
      image,
      design: characterDesign,
      bx0: (width * 0.56).round(),
      by0: (height * 0.08).round(),
      bx1: width - 20,
      by1: height - 350,
      accent: img.ColorRgb8(accent[0], accent[1], accent[2]),
      progress: progress,
    );
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
///
/// [targetDurationSeconds] — when set, the script scales to that
/// length (no upper cap; see [generateScriptForDuration]). Without it
/// the classic 8-scene ~60-90s video is made. [purposeId] picks the
/// pacing/tone/SFX (see [purposeConfig]). [characterDesign] draws a
/// code-drawn character bust into every frame ('none' = classic look).
/// [scenesOverride] renders a caller-supplied scene list instead of
/// generating one (scene editor + PDF lectures). [isCancelled] is
/// polled between scenes so the user can stop a long render.
Future<PromptVideoResult> renderPromptVideo({
  required String prompt,
  required String genre,
  String styleId = defaultStyleId,
  bool vertical = true,
  double fps = 12.0,
  required String outDir,
  required TtsService tts,
  void Function(PromptVideoProgress progress)? onProgress,
  bool karaoke = false,
  double? targetDurationSeconds,
  String purposeId = 'story',
  String characterDesign = 'none',
  List<Map<String, dynamic>>? scenesOverride,
  bool Function()? isCancelled,
}) async {
  final style = getVideoStyle(styleId);
  final width = vertical ? 720 : 1280;
  final height = vertical ? 1280 : 720;
  final dir = Directory(outDir);
  await dir.create(recursive: true);

  void report(String stage, double f) =>
      onProgress?.call(PromptVideoProgress(stage, f));

  report('Script likh raha hoon…', 0.05);
  final purpose = purposeConfig(purposeId);
  final Map<String, dynamic> script;
  final int chapters;
  if (scenesOverride != null && scenesOverride.isNotEmpty) {
    script = {'scenes': scenesOverride, 'title': prompt};
    chapters = 1 +
        scenesOverride
            .where((s) =>
                ((s['narration'] ?? '') as String).startsWith('Chapter '))
            .length;
  } else if (targetDurationSeconds != null) {
    final planned = generateScriptForDuration(
      prompt,
      genre,
      targetDurationSeconds,
      sceneSeconds: purpose.sceneSeconds,
      tone: purpose.tone,
    );
    script = planned;
    chapters = planned['chapters'] as int? ?? 1;
  } else {
    script = generateScript(prompt, genre);
    chapters = 1;
  }
  final scenes = script['scenes'] as List<Map<String, dynamic>>;
  final voiceMap = CharacterVoiceMap.fromScenes(scenes);

  // --- Narration audio per scene (per-character voice + emotion) ---
  // Chunked: progress every 25 scenes and a UI yield between chunks so
  // a 900-scene lecture never freezes the app. Each TTS call has a
  // 90-second timeout — a hung provider fails loudly instead of hanging
  // the render forever.
  report('Voiceover bana raha hoon…', 0.15);
  final sceneAudio = <String>[];
  final sceneSeconds = <double>[];
  const ttsChunk = 25;
  for (var i = 0; i < scenes.length; i++) {
    if (isCancelled?.call() == true) throw const RenderCancelled();
    final scene = scenes[i];
    final line = narratorLineForScene(scene);
    final profile = voiceMap.profileFor(line['speaker'] as String);
    final audioPath = '${dir.path}/scene_${i + 1}.mp3';
    try {
      await _synthesizeWithTimeout(
        tts,
        line['text'] as String,
        voice: profile.voiceIdFor(tts.currentProvider),
        speed: paceForEmotion(line['emotion'] as String),
        outputPath: audioPath,
      );
    } catch (e) {
      // A failed scene voice must not kill the whole render — but it
      // must never be silent either. Fall back to the default TTS.
      await _synthesizeWithTimeout(
        tts,
        line['text'] as String,
        speed: paceForEmotion(line['emotion'] as String),
        outputPath: audioPath,
      );
    }
    sceneAudio.add(audioPath);
    sceneSeconds.add(((scene['est_seconds'] as num?)?.toDouble() ?? 6.0) * 1.3);
    if ((i + 1) % ttsChunk == 0 || i == scenes.length - 1) {
      report('Voiceover bana raha hoon… scene ${i + 1}/${scenes.length}',
          0.15 + 0.25 * (i + 1) / scenes.length);
      await Future<void>.delayed(Duration.zero);
    }
  }
  final totalSeconds = sceneSeconds.fold<double>(0, (a, b) => a + b);

  // --- SFX bed + mix under narration ---
  // Long videos: only a 120-second bed is synthesised and it is looped
  // under the narration — a 2-hour SFX WAV would be ~300 MB on the phone.
  report('SFX mix kar raha hoon…', 0.4);
  // The requested length decides the loop (not the float total): a
  // 2-minute video gets one 120s bed; anything longer loops it.
  final sfxLooped =
      (targetDurationSeconds ?? totalSeconds) > 120;
  final sfxType = purpose.sfxType ?? sfxForStyle(styleId, genre);
  final sfxPath = '${dir.path}/sfx.wav';
  await _withTimeout(
    generateSfx(type: sfxType, seconds: sfxLooped ? 120.0 : totalSeconds, outPath: sfxPath),
    const Duration(seconds: 180),
    'SFX generation',
  );
  final narrationPath = '${dir.path}/narration.mp3';
  await _concatAudio(sceneAudio, narrationPath);
  final mixedPath = '${dir.path}/audio_mixed.m4a';
  final mixCommand = buildMixCommand(
    narrationPath: narrationPath,
    sfxPath: sfxPath,
    outPath: mixedPath,
    loopSfx: sfxLooped,
  );
  await _runFfmpeg(mixCommand, 'audio mix');

  // --- Frames per scene (2 keyframes each: start + end, zoompan fills
  // the frames between them) ---
  report('Frames bana raha hoon…', 0.55);
  final sceneVideos = <String>[];
  for (var i = 0; i < scenes.length; i++) {
    if (isCancelled?.call() == true) throw const RenderCancelled();
    final scene = scenes[i];
    final frameDir = '${dir.path}/scene_${i + 1}_frames';
    await Directory(frameDir).create(recursive: true);
    // PDF lecture page image? Use it as the frame picture; otherwise
    // the code-drawn motion-graphics frame. A missing/corrupt page
    // image falls back to the code-drawn frame — never a crash.
    img.Image? pageImage;
    final imagePath = scene['imagePath'] as String?;
    if (imagePath != null) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        pageImage = img.decodeImage(bytes);
      } catch (_) {
        pageImage = null;
      }
    }
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
        characterDesign: characterDesign,
        baseImage: pageImage,
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
    // Free the frames immediately — a 900-scene lecture would otherwise
    // hold ~1,800 PNGs (~1 GB) on a low-end phone.
    try {
      await Directory(frameDir).delete(recursive: true);
    } catch (_) {}
    report('Scene ${i + 1}/${scenes.length} render…', 0.55 + 0.3 * (i + 1) / scenes.length);
    await Future<void>.delayed(Duration.zero);
  }

  // --- Concat + mux audio ---
  // Stream-copy the video (scene clips already share codec/size/fps):
  // a 2-hour video muxes in seconds instead of re-encoding for an hour.
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
      '-c:v copy -c:a aac -shortest -y "$videoPath"',
      'final mux',
      timeout: const Duration(seconds: 300));

  // --- SRT + karaoke + thumbnail ---
  final srtPath = '${dir.path}/video.srt';
  await writeSrt(scenes, srtPath);
  String? karaokePath;
  if (karaoke) {
    karaokePath = '${dir.path}/video_karaoke.ass';
    await writeKaraokeAss(scenes, karaokePath);
  }
  final thumbPath = '${dir.path}/thumbnail.png';
  await generateThumbnail(
      title: prompt, styleId: styleId, outPath: thumbPath, label: genre);

  report('Ho gaya!', 1.0);
  // Clean up intermediates (scene clips, narration, SFX, mix) — keep
  // only the video, SRT, thumbnail and karaoke file.
  for (final p in [...sceneVideos, narrationPath, sfxPath, mixedPath, concatList]) {
    try {
      await File(p).delete();
    } catch (_) {}
  }
  return PromptVideoResult(
    videoPath: videoPath,
    srtPath: srtPath,
    thumbnailPath: thumbPath,
    sceneCount: scenes.length,
    durationSeconds: totalSeconds,
    styleId: styleId,
    vertical: vertical,
    chapters: chapters,
    karaokePath: karaokePath,
  );
}

/// One TTS line with a 90-second timeout. A hung provider fails loudly
/// instead of freezing the render; the caller decides the fallback.
Future<void> _synthesizeWithTimeout(
  TtsService tts,
  String text, {
  String? voice,
  required double speed,
  required String outputPath,
}) async {
  try {
    await tts
        .synthesizeSpeech(
            text, voice: voice, speed: speed, outputPath: outputPath)
        .timeout(const Duration(seconds: 90));
  } on TimeoutException {
    throw Exception(
        'Voiceover timed out after 90 seconds — the TTS provider may be slow or unreachable. Check your connection and try again.');
  }
}

/// Runs [future] with a timeout; on timeout, best-effort cancels the
/// running FFmpeg session and throws a friendly error instead of
/// hanging forever.
Future<T> _withTimeout<T>(Future<T> future, Duration timeout, String what) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException {
    try {
      await FFmpegKit.cancel();
    } catch (_) {}
    throw Exception(
        '$what timed out after ${timeout.inSeconds} seconds — FFmpeg may have stalled. Try a shorter video or restart the app.');
  }
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

Future<void> _runFfmpeg(String command, String what,
    {Duration timeout = const Duration(seconds: 180)}) async {
  final session = await _withTimeout(FFmpegKit.execute(command), timeout, 'FFmpeg $what');
  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getLogsAsString();
    throw Exception('FFmpeg $what failed: $logs');
  }
}
