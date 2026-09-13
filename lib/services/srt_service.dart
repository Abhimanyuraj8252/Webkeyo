import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

/// Generates an SRT subtitle file from a project's script + generated
/// scene audio (durations are measured from the actual audio files so the
/// subtitles stay perfectly in sync with the rendered video).
class SrtService {
  /// Returns the path of the generated `.srt` file, or null when there is
  /// no usable script/audio for the project.
  static Future<String?> generateSrt({
    required String projectId,
    required String audioDir,
    required String? scriptJson,
    required String outputDir,
  }) async {
    if (scriptJson == null || scriptJson.trim().isEmpty) return null;

    Map<String, dynamic> scriptData;
    try {
      scriptData = jsonDecode(scriptJson);
    } catch (_) {
      return null;
    }
    final dynamic scenes = scriptData['scenes'];
    if (scenes is! List || scenes.isEmpty) return null;

    final player = AudioPlayer();
    try {
      final List<String> cues = [];
      int cursor = 0; // milliseconds

      for (final scene in scenes) {
        if (scene is! Map) continue;
        final dynamic numRaw = scene['scene_number'];
        final String narration = (scene['narration'] ?? '').toString().trim();
        if (narration.isEmpty) continue;

        final int sceneNumber = numRaw is num ? numRaw.toInt() : 0;
        final File audioFile =
            File(p.join(audioDir, 'scene_$sceneNumber.wav'));

        double seconds = 0;
        if (await audioFile.exists()) {
          try {
            final Duration? d = await player.setFilePath(audioFile.path);
            if (d != null) seconds = d.inMilliseconds / 1000.0;
          } catch (_) {}
        }
        if (seconds <= 0) continue;

        final int start = cursor;
        final int end = cursor + (seconds * 1000).round();
        final String text = narration
            .replaceAll(RegExp(r'\[(happy|sad|angry|excited|calm|serious|scared|surprised|tender|dramatic)\]',
                caseSensitive: false),
            '')
            .trim()
            .replaceAll(RegExp(r'\s+'),
            ' ');
        cues.add('${cues.length + 1}\n${_stamp(start)} --> ${_stamp(end)}\n$text\n');
        cursor = end;
      }

      if (cues.isEmpty) return null;

      final outDir = Directory(outputDir);
      if (!await outDir.exists()) await outDir.create(recursive: true);
      final outFile = File(p.join(outputDir, '${projectId}_subtitles.srt'));
      await outFile.writeAsString(cues.join('\n'));
      return outFile.path;
    } finally {
      await player.dispose();
    }
  }

  /// 00:00:00,000 format
  static String _stamp(int ms) {
    final int h = ms ~/ 3600000;
    final int m = (ms ~/ 60000) % 60;
    final int s = (ms ~/ 1000) % 60;
    final int r = ms % 1000;
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${two(h)}:${two(m)}:${two(s)},${three(r)}';
  }
}
