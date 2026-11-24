/// Tests for the scene-by-scene editor: trim, reorder, transitions,
/// timing, and the audio/caption re-sync that follows every edit.
/// Pure logic — no UI, no FFmpeg, no real renders.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/scene_editor.dart';

List<Map<String, dynamic>> _scenes() => [
      {
        'speaker': 'Narrator',
        'emotion': 'calm',
        'narration': 'First scene text',
        'est_seconds': 6.0,
      },
      {
        'speaker': 'Arjun',
        'emotion': 'scared',
        'narration': 'Second scene text',
        'est_seconds': 8.0,
      },
      {
        'speaker': 'Narrator',
        'emotion': 'happy',
        'narration': 'Third scene text',
        'est_seconds': 10.0,
        'imagePath': '/tmp/page_0003.png',
      },
    ];

void main() {
  group('VideoEditSession timing', () {
    test('total and timings use the 1.3 stretch', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      expect(session.totalSeconds, closeTo((6 + 8 + 10) * 1.3, 0.001));
      final timings = session.sceneTimings();
      expect(timings[0].startSeconds, 0.0);
      expect(timings[0].endSeconds, closeTo(6 * 1.3, 0.001));
      expect(timings[1].startSeconds, closeTo(6 * 1.3, 0.001));
      expect(timings[2].startSeconds, closeTo((6 + 8) * 1.3, 0.001));
      expect(timings[2].endSeconds, closeTo((6 + 8 + 10) * 1.3, 0.001));
    });

    test('audio offsets are the scene starts', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      final offsets = session.audioOffsets();
      final timings = session.sceneTimings();
      for (var i = 0; i < offsets.length; i++) {
        expect(offsets[i], closeTo(timings[i].startSeconds, 0.001));
      }
    });
  });

  group('trim', () {
    test('trimming a scene shortens the total and shifts later scenes', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      final applied = session.trimScene(1, 4.0);
      expect(applied, 4.0);
      expect(session.totalSeconds, closeTo((6 + 4 + 10) * 1.3, 0.001));
      expect(session.sceneTimings()[2].startSeconds,
          closeTo((6 + 4) * 1.3, 0.001));
    });

    test('trim clamps to the 2s..120s range', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      expect(session.trimScene(0, 0.5), minSceneSeconds);
      expect(session.trimScene(0, 500), maxSceneSeconds);
    });

    test('adjustSceneSeconds shifts by a delta', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      expect(session.adjustSceneSeconds(0, -1), 5.0);
      expect(session.adjustSceneSeconds(0, 2), 7.0);
    });
  });

  group('reorder', () {
    test('moving a scene reorders it and re-syncs timings + SRT', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      session.moveScene(0, 2);
      expect(session.scenes[2].narration, 'First scene text');
      expect(session.scenes[0].narration, 'Second scene text');
      // The first SRT cue is now the moved-in scene.
      final srt = session.buildSrtText();
      expect(srt, startsWith('1\n00:00:00,000 --> '));
      expect(srt, contains('Second scene text'));
      // Timings still tile the whole video with no gaps.
      final timings = session.sceneTimings();
      expect(timings[0].startSeconds, 0.0);
      expect(timings[2].endSeconds, closeTo(session.totalSeconds, 0.001));
      for (var i = 1; i < timings.length; i++) {
        expect(timings[i].startSeconds,
            closeTo(timings[i - 1].endSeconds, 0.001));
      }
    });

    test('moving to the same index is a no-op', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      session.moveScene(1, 1);
      expect(session.scenes[1].narration, 'Second scene text');
    });
  });

  group('transitions', () {
    test('setTransition stores a valid transition', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      session.setTransition(1, 'fade');
      expect(session.scenes[1].transition, 'fade');
      expect(session.toScriptScenes()[1]['transition'], 'fade');
    });

    test('unknown transition throws', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      expect(() => session.setTransition(0, 'explode'), throwsArgumentError);
    });
  });

  group('guards and round-trip', () {
    test('out-of-range indexes throw ArgumentError', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      expect(() => session.trimScene(5, 4), throwsArgumentError);
      expect(() => session.moveScene(0, 5), throwsArgumentError);
      expect(() => session.moveScene(5, 0), throwsArgumentError);
      expect(() => session.setTransition(-1, 'fade'), throwsArgumentError);
    });

    test('toScriptScenes round-trips narration, timing and image', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      session.scenes[0].narration = 'Edited line';
      final out = session.toScriptScenes();
      expect(out.length, 3);
      expect(out[0]['narration'], 'Edited line');
      expect(out[0]['est_seconds'], 6.0);
      expect(out[0]['transition'], 'cut');
      expect(out[2]['imagePath'], '/tmp/page_0003.png');
    });

    test('karaoke text rebuilds from the edited scenes', () {
      final session = VideoEditSession.fromScriptScenes(_scenes());
      session.moveScene(2, 0);
      final ass = session.buildKaraokeText();
      expect('Dialogue:'.allMatches(ass).length, 3);
      // Words are split by {\kN} tags, so check them individually; the
      // first Dialogue line must hold the moved scene's words.
      final firstDialogue =
          ass.split('\n').firstWhere((l) => l.startsWith('Dialogue:'));
      expect(firstDialogue, contains('Third'));
      expect(firstDialogue, contains('scene'));
      expect(firstDialogue, contains('text'));
    });
  });
}
