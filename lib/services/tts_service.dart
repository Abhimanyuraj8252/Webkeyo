import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'character_voices.dart';
import 'voice_providers.dart';

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
          case 'sarvam_tts':
          case 'gemini_tts':
          case 'deepgram':
          case 'fish_audio':
          case 'minimax_tts':
          case 'google_cloud_tts':
            // Keyed cloud providers — default narrator voice, emotion
            // neutral. Per-character voices go through synthesizeSpeech.
            try {
              await synthesizeSpeech(
                narration,
                voice: _defaultVoiceFor(providerId),
                outputPath: savedFile.path,
              );
              success = true;
            } catch (e) {
              debugPrint('$providerId failed for scene $sceneNumber: $e');
              success = false;
            }
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

  /// The provider id this service speaks with.
  String get currentProvider => providerId;

  /// Default (narrator) voice per keyed provider. Fish Audio and MiniMax
  /// have no usable default — their voice IDs are UUIDs from the
  /// provider's own library, so the caller must set one in Settings.
  String _defaultVoiceFor(String pid) {
    const defaults = {
      'sarvam_tts': 'Meera',
      'gemini_tts': 'Aoede',
      'deepgram': 'flux-anjali-hi',
      'google_cloud_tts': 'hi-IN-Neural2-D',
    };
    final voice = defaults[pid];
    if (voice == null) {
      throw StateError(
          'No default voice for $pid — paste a voice ID from the '
          'provider\'s voice library into Settings first.');
    }
    return voice;
  }

  String _requireKey(String what, String url) {
    if (apiKey == null || apiKey!.isEmpty) {
      throw StateError('$what is not set. Get a key at $url and paste it in Settings.');
    }
    return apiKey!;
  }

  /// Synthesize one line of speech and write it to [outputPath].
  /// Used by prompt-to-video: per-character voice + emotion pace.
  /// [voice] is the provider voice id (resolved by CharacterVoiceMap).
  /// [speed] is a pace multiplier (1.0 = normal).
  /// Throws on missing key / placeholder voice / tiny audio — never
  /// writes silence as a voiceover.
  Future<void> synthesizeSpeech(
    String text, {
    String? voice,
    double? speed,
    String? providerOverride,
    required String outputPath,
  }) async {
    final pid = providerOverride ?? providerId;
    final bytes = await _synthesizeBytes(
      text: text,
      voice: voice,
      speed: speed ?? 1.0,
      providerId: pid,
    );
    if (bytes.length < 1000) {
      throw StateError(
          '$pid returned only ${bytes.length} bytes — too small to be real audio.');
    }
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  /// One line of speech as bytes, for any provider id.
  Future<Uint8List> _synthesizeBytes({
    required String text,
    String? voice,
    required double speed,
    required String providerId,
  }) async {
    final client = VoiceProviderClient();
    switch (providerId) {
      case 'sarvam_tts':
        return client.synthesizeSarvam(
          apiKey: _requireKey('SARVAM_API_KEY', 'https://www.sarvam.ai/try/tts-api'),
          text: text,
          voiceId: voice ?? 'Meera',
          emotion: 'neutral',
          pace: speed,
        );
      case 'gemini_tts':
        return client.synthesizeGemini(
          apiKey: _requireKey('GEMINI_API_KEY', 'https://aistudio.google.com/apikey'),
          text: text,
          voiceId: voice ?? 'Aoede',
          emotion: 'neutral',
        );
      case 'deepgram':
        return client.synthesizeDeepgram(
          apiKey: _requireKey('DEEPGRAM_API_KEY', 'https://deepgram.com/pricing'),
          text: text,
          voiceId: voice ?? 'flux-anjali-hi',
        );
      case 'fish_audio':
        return client.synthesizeFishAudio(
          apiKey: _requireKey('FISH_AUDIO_API_KEY', 'https://fish.audio/developers/'),
          text: text,
          voiceId: voice ??
              (throw StateError(
                  'Fish Audio needs a voice ID (UUID from the Fish Audio library) in Settings.')),
          emotion: 'neutral',
        );
      case 'minimax_tts':
        return client.synthesizeMiniMax(
          apiKey: _requireKey('MINIMAX_API_KEY', 'https://platform.minimax.io/'),
          text: text,
          voiceId: voice ??
              (throw StateError(
                  'MiniMax needs a voice ID from the MiniMax console in Settings.')),
          speed: speed,
        );
      case 'google_cloud_tts':
        return _synthesizeGoogleCloud(
          text: text,
          voiceId: voice ?? 'hi-IN-Neural2-D',
          speed: speed,
        );
      case 'edge_tts':
        return _synthesizeEdgeBytes(
          text: text,
          voiceId: voice,
          language: 'hi-IN',
        );
      case 'piper_tts':
        return _synthesizePiperBytes(text: text, voice: voice);
      case 'openai_tts':
        return _synthesizeOpenAiBytes(text: text, voice: voice);
      case 'elevenlabs':
        return _synthesizeElevenLabsBytes(text: text, voice: voice);
      case 'flutter_tts':
      default:
        await _flutterTts.setSpeechRate((0.5 * speed).clamp(0.1, 1.0));
        final tmp = File('${Directory.systemTemp.path}/webkeyo_tts_${DateTime.now().microsecondsSinceEpoch}.wav');
        final result = await _flutterTts.synthesizeToFile(text, tmp.path);
        if (result != 1 || !await tmp.exists()) {
          throw StateError('Flutter TTS failed to synthesize the line.');
        }
        return tmp.readAsBytes();
    }
  }

  /// Google Cloud TTS (SSML prosody: rate + pitch). Billing must be
  /// enabled on the Google Cloud project — never the default provider.
  Future<Uint8List> _synthesizeGoogleCloud({
    required String text,
    required String voiceId,
    required double speed,
  }) async {
    final key = _requireKey('GOOGLE_TTS_KEY',
        'https://console.cloud.google.com/apis/library/texttospeech.googleapis.com');
    final clean = stripEmotionTag(text).replaceAll('&', 'and');
    final ssml = '<speak><prosody rate="${speed.toStringAsFixed(2)}" '
        'pitch="+0st">$clean</prosody></speak>';
    final response = await http.post(
      Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$key'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'ssml': ssml},
        'voice': {'languageCode': 'hi-IN', 'name': voiceId},
        'audioConfig': {'audioEncoding': 'MP3'},
      }),
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError(
          'Google Cloud TTS returned HTTP ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final audioContent = data['audioContent'] as String?;
    if (audioContent == null || audioContent.isEmpty) {
      throw StateError('Google Cloud TTS returned no audio.');
    }
    return base64Decode(audioContent);
  }

  Future<Uint8List> _synthesizeEdgeBytes({
    required String text,
    String? voiceId,
    required String language,
  }) async {
    final effectiveUrl = baseUrl != null && baseUrl!.isNotEmpty
        ? baseUrl!
        : 'https://edge-tts.vercel.app/api/tts';
    final response = await http.post(
      Uri.parse(effectiveUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'lang': language,
        'voice': voiceId ??
            (language == 'hi-IN' ? 'hi-IN-MadhurNeural' : 'en-US-AriaNeural'),
      }),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('Edge TTS returned HTTP ${response.statusCode}.');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> _synthesizePiperBytes({
    required String text,
    String? voice,
  }) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      throw StateError('Piper TTS needs a server URL in Settings.');
    }
    // Character voices store Piper as 'male' / 'female' (Pratham /
    // Priyamvada). Any other value is treated as a model name.
    final model = voice == 'male'
        ? 'hi_IN-pratham-medium'
        : voice == 'female'
            ? 'hi_IN-priyamvada-medium'
            : (voice ?? modelId ?? 'en_US-lessac-medium');
    final response = await http.post(
      Uri.parse(baseUrl!),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'model': model}),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('Piper TTS returned HTTP ${response.statusCode}.');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> _synthesizeOpenAiBytes({
    required String text,
    String? voice,
  }) async {
    final key = _requireKey('OPENAI_API_KEY', 'https://platform.openai.com/api-keys');
    final url = (baseUrl != null && baseUrl!.isNotEmpty)
        ? baseUrl!
        : 'https://api.openai.com/v1/audio/speech';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId ?? 'tts-1',
        'input': text,
        'voice': voice ?? 'alloy',
      }),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('OpenAI TTS returned HTTP ${response.statusCode}.');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> _synthesizeElevenLabsBytes({
    required String text,
    String? voice,
  }) async {
    final key = _requireKey('ELEVENLABS_API_KEY', 'https://elevenlabs.io');
    final voiceId = voice ?? modelId ?? '21m00Tcm4TlvDq8ikWAM';
    final response = await http.post(
      Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId'),
      headers: {
        'xi-api-key': key,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_monolingual_v1',
      }),
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError('ElevenLabs returned HTTP ${response.statusCode}.');
    }
    return response.bodyBytes;
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

