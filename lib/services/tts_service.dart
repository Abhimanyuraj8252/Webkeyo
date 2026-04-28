import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// Service responsible for communicating with external TTS APIs, downloading audio,
/// and calculating accurate durations required for FFmpeg video synchronization.
/// Supports both local Flutter TTS and remote Edge TTS API endpoints.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  String? _edgeTtsApiUrl; // Optional Edge TTS API endpoint

  TtsService({String? edgeTtsApiUrl}) {
    _edgeTtsApiUrl = edgeTtsApiUrl;
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("hi-IN");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  /// Determines whether to use Edge TTS API or local Flutter TTS
  bool get _useEdgeTts => _edgeTtsApiUrl != null && _edgeTtsApiUrl!.isNotEmpty;

  /// Generates audio files for a list of scenes and calculates their exact durations.
  /// 
  /// [scenesJson] is a list of maps containing 'scene_number' and 'narration'.
  /// [saveDirectoryPath] is the local path where the .mp3 files will be stored.
  /// [ttsApiUrl] is the endpoint to hit for TTS generation (unused if using flutter_tts).
  /// [onProgress] is an optional callback to report which scene is currently being processed.
  Future<List<Map<String, dynamic>>> generateAudioForScenes({
    required List<dynamic> scenesJson,
    required String saveDirectoryPath,
    required String ttsApiUrl,
    required String language,
    Function(int currentScene)? onProgress,
  }) async {
    final List<Map<String, dynamic>> audioSyncData = [];
    final player = AudioPlayer();

    // Ensure the save directory exists
    final dir = Directory(saveDirectoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Comprehensive language mapping for global TTS support
    final String langLower = language.toLowerCase();
    final Map<String, String> languageMap = {
      'hinglish': 'hi-IN',
      'hindi': 'hi-IN',
      'hi': 'hi-IN',
      'hin': 'hi-IN',
      'english': 'en-US',
      'en': 'en-US',
      'korean': 'ko-KR',
      'ko': 'ko-KR',
      'japanese': 'ja-JP',
      'ja': 'ja-JP',
      'spanish': 'es-ES',
      'es': 'es-ES',
      'french': 'fr-FR',
      'fr': 'fr-FR',
      'german': 'de-DE',
      'de': 'de-DE',
      'portuguese': 'pt-BR',
      'pt': 'pt-BR',
      'arabic': 'ar-SA',
      'ar': 'ar-SA',
      'chinese': 'zh-CN',
      'zh': 'zh-CN',
      'italian': 'it-IT',
      'it': 'it-IT',
      'russian': 'ru-RU',
      'ru': 'ru-RU',
      'thai': 'th-TH',
      'th': 'th-TH',
      'turkish': 'tr-TR',
      'tr': 'tr-TR',
      'vietnamese': 'vi-VN',
      'vi': 'vi-VN',
      'indonesian': 'id-ID',
      'id': 'id-ID',
    };

    final String ttsLang = languageMap.entries
        .where((e) => langLower.contains(e.key))
        .map((e) => e.value)
        .firstOrNull ?? 'en-US';
    await _flutterTts.setLanguage(ttsLang);

    try {
      for (final scene in scenesJson) {
        final int sceneNumber = scene['scene_number'] ?? 0;
        final String narration = scene['narration'] ?? '';

        if (narration.trim().isEmpty) continue;

        if (onProgress != null) {
          onProgress(sceneNumber);
        }

        final String fileName = 'scene_$sceneNumber.wav';
        final File savedFile = File(p.join(saveDirectoryPath, fileName));
        
        // Use Edge TTS if URL is provided, otherwise use local Flutter TTS
        if (_useEdgeTts) {
          await _generateAudioWithEdgeTts(
            narration: narration,
            sceneNumber: sceneNumber,
            savedFile: savedFile,
            language: ttsLang,
          );
        } else {
          // Use local Flutter TTS (default)
          final result = await _flutterTts.synthesizeToFile(narration, savedFile.path);

          if (result != 1) {
            debugPrint('Warning: flutter_tts synthesizeToFile failed for scene $sceneNumber');
            continue;
          }
        }

        // Wait a tiny bit for the file to be fully written
        await Future.delayed(const Duration(milliseconds: 500));

        if (!savedFile.existsSync()) {
          debugPrint('Warning: Saved file does not exist for scene $sceneNumber');
          continue;
        }

        // Load the saved file path into the player to extract its exact duration
        final Duration? duration = await player.setFilePath(savedFile.path);
        
        final double durationInSeconds = duration != null 
            ? duration.inMilliseconds / 1000.0 
            : 0.0; // Fallback if duration cannot be extracted

        if (durationInSeconds == 0.0) {
          debugPrint('Warning: Could not extract duration for scene $sceneNumber');
        }

        // Map strictly matching FFmpeg engine requirements
        audioSyncData.add({
          'scene_number': sceneNumber,
          'audio_path': savedFile.path,
          'duration_in_seconds': durationInSeconds,
        });
      }
    } finally {
      // Always dispose of the player to free up native resources
      await player.dispose();
    }

    return audioSyncData;
  }

  /// Generate audio using Edge TTS API endpoint
  /// [narration] is the text to convert to speech
  /// [sceneNumber] is the scene number for logging
  /// [savedFile] is the file where the audio should be saved
  /// [language] is the language code (e.g., 'hi-IN', 'en-US')
  Future<void> _generateAudioWithEdgeTts({
    required String narration,
    required int sceneNumber,
    required File savedFile,
    required String language,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_edgeTtsApiUrl/tts'),
      )
        ..fields['text'] = narration
        ..fields['language'] = language
        ..fields['voice'] = 'default';

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final bytes = await streamedResponse.stream.toBytes();
        await savedFile.writeAsBytes(bytes);
        debugPrint('Edge TTS generated audio for scene $sceneNumber');
      } else {
        debugPrint('Edge TTS API error for scene $sceneNumber: ${streamedResponse.statusCode}');
        // Fallback to Flutter TTS
        await _flutterTts.synthesizeToFile(narration, savedFile.path);
      }
    } catch (e, stackTrace) {
      debugPrint('Error generating audio with Edge TTS for scene $sceneNumber: $e\n$stackTrace');
      // Fallback to Flutter TTS
      try {
        await _flutterTts.synthesizeToFile(narration, savedFile.path);
      } catch (fallbackError) {
        debugPrint('Fallback Flutter TTS also failed: $fallbackError');
      }
    }
  }
}
