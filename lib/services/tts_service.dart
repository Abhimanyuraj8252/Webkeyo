import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service responsible for communicating with external TTS APIs, downloading audio,
/// and calculating accurate durations required for FFmpeg video synchronization.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final String providerId;
  final String? apiKey;
  final String? baseUrl;
  final String? modelId;

  TtsService({
    this.providerId = 'flutter_tts',
    this.apiKey,
    this.baseUrl,
    this.modelId,
  }) {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("hi-IN");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('Flutter TTS init error: $e');
    }
  }

  /// Generates audio files for a list of scenes and calculates their exact durations.
  Future<List<Map<String, dynamic>>> generateAudioForScenes({
    required List<dynamic> scenesJson,
    required String saveDirectoryPath,
    required String language,
    Function(int currentScene)? onProgress,
  }) async {
    final List<Map<String, dynamic>> audioSyncData = [];
    final player = AudioPlayer();

    final dir = Directory(saveDirectoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final String ttsLang = _mapLanguage(language);
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
        
        // Remove existing file if any to avoid confusion
        if (await savedFile.exists()) await savedFile.delete();

        bool success = false;
        
        switch (providerId) {
          case 'edge_tts':
            success = await _generateAudioWithEdgeTts(
              narration: narration,
              savedFile: savedFile,
              language: ttsLang,
            );
            break;
          case 'piper_tts':
            success = await _generateAudioWithPiperTts(
              narration: narration,
              savedFile: savedFile,
              language: ttsLang,
            );
            break;
          case 'openai_tts':
            success = await _generateAudioWithOpenAiTts(
              narration: narration,
              savedFile: savedFile,
            );
            break;
          case 'elevenlabs':
            success = await _generateAudioWithElevenLabs(
              narration: narration,
              savedFile: savedFile,
            );
            break;
          case 'flutter_tts':
          default:
            final result = await _flutterTts.synthesizeToFile(narration, savedFile.path);
            success = (result == 1);
            break;
        }

        // Fallback to Flutter TTS if specific provider failed
        if (!success && providerId != 'flutter_tts') {
          debugPrint('Provider $providerId failed, falling back to local Flutter TTS');
          final result = await _flutterTts.synthesizeToFile(narration, savedFile.path);
          success = (result == 1);
        }

        if (!success) {
          debugPrint('Warning: TTS failed for scene $sceneNumber');
          continue;
        }

        // Wait for file to be ready
        int retries = 5;
        while (!savedFile.existsSync() && retries > 0) {
          await Future.delayed(const Duration(milliseconds: 300));
          retries--;
        }

        if (!savedFile.existsSync()) {
          debugPrint('Warning: Saved file does not exist for scene $sceneNumber');
          continue;
        }

        // Extract duration
        try {
          final Duration? duration = await player.setFilePath(savedFile.path);
          final double durationInSeconds = duration != null 
              ? duration.inMilliseconds / 1000.0 
              : 0.0;

          audioSyncData.add({
            'scene_number': sceneNumber,
            'audio_path': savedFile.path,
            'duration_in_seconds': durationInSeconds,
          });
        } catch (e) {
          debugPrint('Error extracting duration for scene $sceneNumber: $e');
        }
      }
    } finally {
      await player.dispose();
    }

    return audioSyncData;
  }

  String _mapLanguage(String language) {
    final String langLower = language.toLowerCase();
    final Map<String, String> languageMap = {
      'hinglish': 'hi-IN',
      'hindi': 'hi-IN',
      'hi': 'hi-IN',
      'english': 'en-US',
      'en': 'en-US',
      'japanese': 'ja-JP',
      'korean': 'ko-KR',
      'spanish': 'es-ES',
      'french': 'fr-FR',
      'german': 'de-DE',
    };
    
    for (var entry in languageMap.entries) {
      if (langLower.contains(entry.key)) return entry.value;
    }
    return 'en-US';
  }

  Future<bool> _generateAudioWithEdgeTts({
    required String narration,
    required File savedFile,
    required String language,
  }) async {
    try {
      final effectiveUrl = baseUrl != null && baseUrl!.isNotEmpty 
          ? baseUrl! 
          : 'https://edge-tts.vercel.app/api/tts';
      
      final response = await http.post(
        Uri.parse(effectiveUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': narration,
          'lang': language,
          'voice': language == 'hi-IN' ? 'hi-IN-MadhurNeural' : 'en-US-AriaNeural',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await savedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      debugPrint('Edge TTS Error: $e');
    }
    return false;
  }

  Future<bool> _generateAudioWithPiperTts({
    required String narration,
    required File savedFile,
    required String language,
  }) async {
    try {
      if (baseUrl == null || baseUrl!.isEmpty) return false;
      
      final response = await http.post(
        Uri.parse(baseUrl!),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': narration,
          'model': modelId ?? 'en_US-lessac-medium',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await savedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      debugPrint('Piper TTS Error: $e');
    }
    return false;
  }

  Future<bool> _generateAudioWithOpenAiTts({
    required String narration,
    required File savedFile,
  }) async {
    try {
      if (apiKey == null || apiKey!.isEmpty) return false;
      
      final url = (baseUrl != null && baseUrl!.isNotEmpty) 
          ? baseUrl! 
          : 'https://api.openai.com/v1/audio/speech';
          
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': modelId ?? 'tts-1',
          'input': narration,
          'voice': 'alloy',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await savedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      debugPrint('OpenAI TTS Error: $e');
    }
    return false;
  }

  Future<bool> _generateAudioWithElevenLabs({
    required String narration,
    required File savedFile,
  }) async {
    try {
      if (apiKey == null || apiKey!.isEmpty) return false;
      
      final voiceId = modelId ?? '21m00Tcm4TlvDq8ikWAM'; // Default Rachel voice
      final url = 'https://api.elevenlabs.io/v1/text-to-speech/$voiceId';
          
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'xi-api-key': apiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': narration,
          'model_id': 'eleven_monolingual_v1',
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        await savedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      debugPrint('ElevenLabs Error: $e');
    }
    return false;
  }
}

