/// Tests for the v1.2.2 unlimited-duration prompt-to-video plan:
/// duration parsing (no cap), plan scaling, purpose mapping, character
/// designs, code-drawn style previews, the SFX loop flag, and the
/// crash-free render guards (cancel + failing TTS). No real renders —
/// planning a 2-hour video must stay cheap.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:webkeyo/models/video_style.dart';
import 'package:webkeyo/services/prompt_video_service.dart';
import 'package:webkeyo/services/script_generator.dart';
import 'package:webkeyo/services/sfx_service.dart';
import 'package:webkeyo/services/tts_service.dart';
import 'package:webkeyo/services/video_duration.dart';
import 'package:webkeyo/services/video_purpose.dart';

/// A TTS service that always fails immediately — the render must fail
/// loudly with a clear error, never hang or crash.
class _ThrowingTts extends TtsService {
  _ThrowingTts() : super(providerId: 'edge_tts');

  @override
  Future<void> synthesizeSpeech(
    String text, {
    String? voice,
    double? speed,
    String emotion = 'neutral',
    String? providerOverride,
    required String outputPath,
  }) async {
    throw StateError('no network in test');
  }
}

void main() {
  group('parseDurationMinutes', () {
    test('plain minutes and suffixes', () {
      expect(parseDurationMinutes('90'), 90.0);
      expect(parseDurationMinutes('90.5'), 90.5);
      expect(parseDurationMinutes(' 30 '), 30.0);
      expect(parseDurationMinutes('90m'), 90.0);
      expect(parseDurationMinutes('2h'), 120.0);
      expect(parseDurationMinutes('1.5h'), 90.0);
    });

    test('no upper cap — 1000 minutes plans 1000 minutes', () {
      expect(parseDurationMinutes('1000'), 1000.0);
      expect(parseDurationMinutes('16h'), 960.0);
    });

    test('invalid input returns null', () {
      expect(parseDurationMinutes(''), isNull);
      expect(parseDurationMinutes('   '), isNull);
      expect(parseDurationMinutes('abc'), isNull);
      expect(parseDurationMinutes('0'), isNull);
      expect(parseDurationMinutes('-5'), isNull);
      expect(parseDurationMinutes('2x'), isNull);
    });
  });

  group('formatDuration', () {
    test('seconds, minutes, hours', () {
      expect(formatDuration(45), '45 sec');
      expect(formatDuration(120), '2 min');
      expect(formatDuration(90), '1 min 30 sec');
      expect(formatDuration(3600), '1 hr');
      expect(formatDuration(7500), '2 hr 5 min');
    });
  });

  test('duration presets cover reel to 2 hours', () {
    expect(durationPresetsMinutes, [1, 2, 5, 10, 15, 30, 60, 120]);
  });

  group('planPromptVideo', () {
    test('120s story -> 15 scenes, total ~120s', () {
      final plan = planPromptVideo(
        idea: 'a boy enters a haunted inn',
        genre: 'haunted',
        targetSeconds: 120,
      );
      expect(plan.sceneCount, 15);
      expect(plan.totalSeconds, closeTo(120, 1.0));
      expect(plan.chapters, greaterThanOrEqualTo(1));
      expect(plan.sfxLooped, isFalse);
      expect(plan.exact, isTrue);
    });

    test('60s -> the base 8-scene script', () {
      final plan = planPromptVideo(
        idea: 'a boy enters a haunted inn',
        genre: 'haunted',
        targetSeconds: 60,
      );
      expect(plan.sceneCount, 8);
    });

    test('2-hour plan: 900 scenes, chapters, SFX loop — and it is fast', () {
      final stopwatch = Stopwatch()..start();
      final plan = planPromptVideo(
        idea: 'a boy enters a haunted inn',
        genre: 'haunted',
        targetSeconds: 2 * 3600,
      );
      stopwatch.stop();
      expect(plan.sceneCount, 900);
      expect(plan.totalSeconds, closeTo(2 * 3600, 1.0));
      expect(plan.chapters, greaterThanOrEqualTo(2));
      expect(plan.sfxLooped, isTrue);
      expect(plan.exact, isTrue);
      expect(plan.estTtsChars, greaterThan(0));
      // Planning must not blow up — well under a second.
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('plan carries purpose and character choice', () {
      final plan = planPromptVideo(
        idea: 'a lecture on photosynthesis',
        genre: 'motivational',
        targetSeconds: 600,
        purposeId: 'lecture',
        characterDesign: 'silhouette',
      );
      expect(plan.purposeId, 'lecture');
      expect(plan.characterDesign, 'silhouette');
      expect(plan.sceneSeconds, 12.0);
    });

    test('180 minutes (custom, over the presets) plans 180 minutes', () {
      final plan = planPromptVideo(
        idea: 'a long story',
        genre: 'haunted',
        targetSeconds: 180 * 60,
      );
      expect(plan.sceneCount, 1350);
      expect(plan.totalSeconds, closeTo(180 * 60, 1.0));
    });
  });

  group('generateScriptForDuration', () {
    test('short target keeps the base 8-scene script', () {
      final script = generateScriptForDuration('a haunted inn', 'haunted', 30);
      expect((script['scenes'] as List).length, 8);
    });

    test('240s story scales to 30 scenes at the target length', () {
      final script = generateScriptForDuration('a haunted inn', 'haunted', 240);
      final scenes = script['scenes'] as List<Map<String, dynamic>>;
      expect(scenes.length, 30);
      final total = scenes.fold<double>(
          0, (s, sc) => s + ((sc['est_seconds'] as num).toDouble() * 1.3));
      expect(total, closeTo(240, 1.0));
      // Every generated scene lands on the purpose pacing.
      for (final scene in scenes) {
        expect((scene['est_seconds'] as num).toDouble(),
            closeTo(8.0 / 1.3, 0.01));
      }
    });
  });

  group('purpose mapping', () {
    test('every purpose has a valid config', () {
      for (final id in purposeIds) {
        final p = purposeConfig(id);
        expect(p.sceneSeconds, greaterThan(0));
        expect(p.tone, isNotEmpty);
        expect(p.label, isNotEmpty);
        expect(p.bestFor, isNotEmpty);
        expect(p.karaokeDefault, isA<bool>());
        expect(p.sfxType == null || sfxTypes.contains(p.sfxType), isTrue,
            reason: '$id sfxType ${p.sfxType} is not a known SFX type');
      }
    });

    test('unknown purpose falls back to story', () {
      expect(purposeConfig('nope').id, 'story');
      expect(purposeConfig(null).id, 'story');
    });
  });

  group('character designs', () {
    img.Image blankFrame() => img.Image(width: 360, height: 640);

    test('every design draws without throwing', () {
      for (final id in characterDesignIds) {
        final frame = blankFrame();
        expect(
          () => drawCharacterDesign(
            frame,
            design: id,
            bx0: 200,
            by0: 50,
            bx1: 340,
            by1: 290,
            accent: img.ColorRgb8(120, 80, 255),
            progress: 0.5,
          ),
          returnsNormally,
        );
      }
    });

    test('anime and silhouette look different; none draws nothing', () {
      final anime = blankFrame();
      drawCharacterDesign(anime,
          design: 'anime',
          bx0: 200,
          by0: 50,
          bx1: 340,
          by1: 290,
          accent: img.ColorRgb8(120, 80, 255));
      final silhouette = blankFrame();
      drawCharacterDesign(silhouette,
          design: 'silhouette',
          bx0: 200,
          by0: 50,
          bx1: 340,
          by1: 290,
          accent: img.ColorRgb8(120, 80, 255));
      final none = blankFrame();
      drawCharacterDesign(none,
          design: 'none',
          bx0: 200,
          by0: 50,
          bx1: 340,
          by1: 290,
          accent: img.ColorRgb8(120, 80, 255));
      final animeBytes = img.encodePng(anime);
      final silhouetteBytes = img.encodePng(silhouette);
      final noneBytes = img.encodePng(none);
      expect(animeBytes, isNot(equals(silhouetteBytes)));
      expect(noneBytes, equals(img.encodePng(blankFrame())));
    });
  });

  group('style previews', () {
    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

    test('every style has a non-empty PNG preview', () {
      for (final id in styleIds) {
        final bytes = buildStylePreviewBytes(styleId: id);
        expect(bytes, isNotEmpty);
        expect(bytes.sublist(0, 8), pngSignature);
      }
    });

    test('two styles produce different previews', () {
      final a = buildStylePreviewBytes(styleId: 'anime-premium');
      final b = buildStylePreviewBytes(styleId: 'cinematic-dark');
      expect(a, isNot(equals(b)));
    });

    test('character design changes the preview', () {
      final a = buildStylePreviewBytes(
          styleId: 'anime-premium', characterDesign: 'anime');
      final b = buildStylePreviewBytes(
          styleId: 'anime-premium', characterDesign: 'silhouette');
      expect(a, isNot(equals(b)));
    });
  });

  group('buildMixCommand SFX loop', () {
    test('loopSfx adds -stream_loop; default does not', () {
      final looped = buildMixCommand(
        narrationPath: 'n.mp3',
        sfxPath: 's.wav',
        outPath: 'o.m4a',
        loopSfx: true,
      );
      expect(looped, contains('-stream_loop -1'));
      final normal = buildMixCommand(
        narrationPath: 'n.mp3',
        sfxPath: 's.wav',
        outPath: 'o.m4a',
      );
      expect(normal, isNot(contains('stream_loop')));
    });
  });

  group('render guards (no real render)', () {
    late Directory tmp;
    setUp(() async {
      // TtsService builds a FlutterTts (method channel) — the test
      // binding must exist first.
      TestWidgetsFlutterBinding.ensureInitialized();
      tmp = await Directory.systemTemp.createTemp('webkeyo_plan_test_');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('cancel before the first scene throws RenderCancelled', () async {
      await expectLater(
        renderPromptVideo(
          prompt: 'a boy enters a haunted inn',
          genre: 'haunted',
          outDir: tmp.path,
          tts: TtsService(),
          isCancelled: () => true,
        ),
        throwsA(isA<RenderCancelled>()),
      );
    });

    test('a failing TTS provider fails loudly, never hangs', () async {
      await expectLater(
        renderPromptVideo(
          prompt: 'a boy enters a haunted inn',
          genre: 'haunted',
          outDir: tmp.path,
          tts: _ThrowingTts(),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
