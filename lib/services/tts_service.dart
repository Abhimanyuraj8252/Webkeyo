import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/io.dart';

/// TTS language -> BCP-47 locale (used by flutter_tts and Edge TTS).
///
/// Top-level so it can be unit tested.
String mapTtsLanguage(String language) {
  final String langLower = language.toLowerCase();
  const Map<String, String> languageMap = {
    'hinglish': 'hi-IN',
    'hindi': 'hi-IN',
    'hi': 'hi-IN',
    'english': 'en-US',
    'en': 'en-US',
    'japanese': 'ja-JP',
    'ja': 'ja-JP',
    'korean': 'ko-KR',
    'ko': 'ko-KR',
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
    'mandarin': 'zh-CN',
    'zh': 'zh-CN',
    'italian': 'it-IT',
    'it': 'it-IT',
    'russian': 'ru-RU',
    'ru': 'ru-RU',
    'turkish': 'tr-TR',
    'tr': 'tr-TR',
    'vietnamese': 'vi-VN',
    'vi': 'vi-VN',
    'indonesian': 'id-ID',
    'id': 'id-ID',
    'thai': 'th-TH',
    'th': 'th-TH',
  };
  // Exact display-name / code match first ("english" must not be mistaken
  // for Spanish by a naive substring match on "es").
  final String? exact = languageMap[langLower];
  if (exact != null) return exact;
  for (final entry in languageMap.entries) {
    if (langLower.startsWith(entry.key)) return entry.value;
  }
  return 'en-US';
}

/// Default Microsoft Edge neural voice per locale (used when the user has
/// not picked a specific voice).
String edgeVoiceForLocale(String locale) {
  const Map<String, String> voices = {
    'hi-IN': 'hi-IN-MadhurNeural',
    'en-US': 'en-US-AriaNeural',
    'ja-JP': 'ja-JP-NanamiNeural',
    'ko-KR': 'ko-KR-SunHiNeural',
    'es-ES': 'es-ES-ElviraNeural',
    'fr-FR': 'fr-FR-DeniseNeural',
    'de-DE': 'de-DE-KatjaNeural',
    'pt-BR': 'pt-BR-FranciscaNeural',
    'ar-SA': 'ar-SA-ZariyahNeural',
    'zh-CN': 'zh-CN-XiaoxiaoNeural',
    'it-IT': 'it-IT-ElsaNeural',
    'ru-RU': 'ru-RU-DmitryNeural',
    'tr-TR': 'tr-TR-EmelNeural',
    'vi-VN': 'vi-VN-HoaiMyNeural',
    'id-ID': 'id-ID-ArdiNeural',
    'th-TH': 'th-TH-PremwadeeNeural',
  };
  return voices[locale] ?? 'en-US-AriaNeural';
}

/// Curated voice choices per locale for the in-app voice picker.
Map<String, List<String>> edgeVoicesForLocale(String locale) {
  const Map<String, List<String>> voices = {
    'hi-IN': ['hi-IN-MadhurNeural', 'hi-IN-SwaraNeural'],
    'en-US': ['en-US-AriaNeural', 'en-US-GuyNeural', 'en-GB-SoniaNeural', 'en-IN-PrabhatNeural'],
    'ja-JP': ['ja-JP-NanamiNeural', 'ja-JP-KeitaNeural'],
    'ko-KR': ['ko-KR-SunHiNeural', 'ko-KR-InJoonNeural'],
    'es-ES': ['es-ES-ElviraNeural', 'es-MX-DaliaNeural'],
    'fr-FR': ['fr-FR-DeniseNeural', 'fr-FR-HenriNeural'],
    'de-DE': ['de-DE-KatjaNeural', 'de-DE-ConradNeural'],
    'pt-BR': ['pt-BR-FranciscaNeural', 'pt-BR-AntonioNeural'],
    'ar-SA': ['ar-SA-ZariyahNeural', 'ar-SA-FahedNeural'],
    'zh-CN': ['zh-CN-XiaoxiaoNeural', 'zh-CN-YunxiNeural'],
    'it-IT': ['it-IT-ElsaNeural', 'it-IT-DiegoNeural'],
    'ru-RU': ['ru-RU-DmitryNeural', 'ru-RU-SvetlanaNeural'],
    'tr-TR': ['tr-TR-EmelNeural', 'tr-TR-AhmetNeural'],
    'vi-VN': ['vi-VN-HoaiMyNeural', 'vi-VN-NamMinhNeural'],
    'id-ID': ['id-ID-ArdiNeural', 'id-ID-GadisNeural'],
    'th-TH': ['th-TH-PremwadeeNeural', 'th-TH-NiwatNeural'],
  };
  return voices[locale] ?? ['en-US-AriaNeural'];
}

/// Service responsible for communicating with external TTS APIs, downloading
/// audio, and calculating accurate durations required for FFmpeg video
/// synchronization.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final String providerId;
  final String? apiKey;
  final String? baseUrl;
  final String? modelId;
  final String? voice;

  TtsService({
    this.providerId = 'flutter_tts',
    this.apiKey,
    this.baseUrl,
    this.modelId,
    this.voice,
  }) {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('Flutter TTS init error: $e');
    }
  }

  /// Generates audio files for a list of scenes and calculates their exact
  /// durations.
  ///
  /// [reuseExisting] lets a retry skip scenes whose audio file already exists
  /// on disk (makes "Retry after TTS failure" much cheaper).
  Future<List<Map<String, dynamic>>> generateAudioForScenes({
    required List<dynamic> scenesJson,
    required String saveDirectoryPath,
    required String language,
    bool reuseExisting = false,
    Function(int currentScene)? onProgress,
  }) async {
    final List<Map<String, dynamic>> audioSyncData = [];
    final player = AudioPlayer();

    final dir = Directory(saveDirectoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final String ttsLang = mapTtsLanguage(language);
    try {
      await _flutterTts.setLanguage(ttsLang);
    } catch (e) {
      debugPrint('setLanguage($ttsLang) failed: $e');
    }

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

        // Reuse previously generated audio when retrying a failed run.
        if (reuseExisting && await savedFile.exists() && savedFile.lengthSync() > 0) {
          final Duration? d = await _durationOf(player, savedFile.path);
          if (d != null && d.inMilliseconds > 0) {
            audioSyncData.add({
              'scene_number': sceneNumber,
              'audio_path': savedFile.path,
              'duration_in_seconds': d.inMilliseconds / 1000.0,
            });
            continue;
          }
        }

        // Remove stale/empty file so a fresh generation starts clean.
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
          final Duration? duration = await _durationOf(player, savedFile.path);
          final double durationInSeconds =
              duration != null ? duration.inMilliseconds / 1000.0 : 0.0;

          if (durationInSeconds > 0) {
            audioSyncData.add({
              'scene_number': sceneNumber,
              'audio_path': savedFile.path,
              'duration_in_seconds': durationInSeconds,
            });
          }
        } catch (e) {
          debugPrint('Error extracting duration for scene $sceneNumber: $e');
        }
      }
    } finally {
      await player.dispose();
    }

    return audioSyncData;
  }

  Future<Duration?> _durationOf(AudioPlayer player, String path) async {
    try {
      return await player.setFilePath(path);
    } catch (e) {
      debugPrint('Duration lookup failed for $path: $e');
      return null;
    }
  }

  // ──────────────────────────── Edge TTS ────────────────────────────
  // Preferred order:
  //  1. User-supplied compatible endpoint (baseUrl) — e.g. a self-hosted
  //     edge-tts-server. POST {text, lang, voice} -> audio bytes.
  //  2. Direct Microsoft Edge TTS WebSocket protocol (no third party,
  //     no API key).
  //  3. Public community fallback endpoint (best effort).
  Future<bool> _generateAudioWithEdgeTts({
    required String narration,
    required File savedFile,
    required String language,
  }) async {
    final String effVoice =
        (voice != null && voice!.isNotEmpty) ? voice! : edgeVoiceForLocale(language);

    if (baseUrl != null && baseUrl!.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse(baseUrl!),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': narration, 'lang': language, 'voice': effVoice}),
        ).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await savedFile.writeAsBytes(response.bodyBytes);
          return true;
        }
      } catch (e) {
        debugPrint('Edge TTS (custom endpoint) error: $e');
      }
      return false;
    }

    // Direct Edge TTS protocol.
    try {
      final bytes = await _edgeTtsDirect(narration, language, effVoice)
          .timeout(const Duration(seconds: 25));
      if (bytes != null && bytes.isNotEmpty) {
        await savedFile.writeAsBytes(bytes);
        return true;
      }
    } catch (e) {
      debugPrint('Edge TTS (direct) error: $e');
    }

    // Community fallback endpoint (best effort, may be down).
    try {
      final response = await http.post(
        Uri.parse('https://edge-tts.vercel.app/api/tts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': narration, 'lang': language, 'voice': effVoice}),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await savedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      debugPrint('Edge TTS (fallback) error: $e');
    }
    return false;
  }

  /// Speaks the Microsoft Edge TTS WebSocket protocol directly (the same
  /// protocol used by the open-source edge-tts tools). No key required.
  Future<List<int>?> _edgeTtsDirect(String text, String locale, String voiceName) async {
    const String trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
    final String ge = _genSecMsGec();

    // Step 1: obtain a Sec-MS-AccessToken from the voices-list endpoint.
    final http.Response metaResp = await http.get(
      Uri.parse(
        'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=$trustedClientToken',
      ),
      headers: {
        'Accept': 'application/json',
        'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
        'Sec-MS-GEC': ge,
        'Sec-MS-GEC-Version': '1-145.32.13.35228',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Edg/122.0.0.0',
      },
    ).timeout(const Duration(seconds: 10));

    if (metaResp.statusCode != 200) return null;

    final dynamic meta = jsonDecode(metaResp.body);
    if (meta is! List || meta.isEmpty) return null;
    final String token = (meta.first is Map) ? (meta.first as Map)['token']?.toString() ?? '' : '';
    final String messageid =
        metaResp.headers['x-ms-messageid']?.toString() ?? _randomHex(16);
    if (token.isEmpty) return null;

    // Step 2: open the synthesis WebSocket.
    final Uri wsUri = Uri.parse(
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1'
      '?TrustedClientToken=$trustedClientToken&Sec-MS-GEC=$ge&Sec-MS-GEC-Version=1-145.32.13.35228',
    );
    final channel = IOWebSocketChannel.connect(wsUri);

    final List<int> audioBytes = [];
    final Completer<void> done = Completer<void>();
    final Completer<void> firstResponse = Completer<void>();

    try {
      channel.stream.listen((data) {
        final String msg = data is String ? data : utf8.decode(data, allowMalformed: true);
        // Server sends "headers\r\n\r\npayload" frames.
        final int sep = msg.indexOf('\r\n\r\n');
        final String headers = sep >= 0 ? msg.substring(0, sep) : '';
        final String payload = sep >= 0 ? msg.substring(sep + 4) : msg;

        if (!firstResponse.isCompleted) firstResponse.complete();

        final String contentType = _headerValue(headers, 'Content-Type') ?? '';
        if (contentType.startsWith('audio/mpeg')) {
          // Audio chunk arrives base64-encoded in the payload.
          try {
            audioBytes.addAll(base64Decode(payload.trim()));
          } catch (_) {}
        } else if (payload.contains('turn.end')) {
          if (!done.isCompleted) done.complete();
        }
      }, onDone: () {
        if (!firstResponse.isCompleted) firstResponse.complete();
        if (!done.isCompleted) done.complete();
      }, onError: (Object e) {
        if (!firstResponse.isCompleted) firstResponse.completeError(e);
        if (!done.isCompleted) done.completeError(e);
      });

      // Wait for the socket to be open.
      await channel.ready.timeout(const Duration(seconds: 8));

      final String timestamp = DateTime.now().toUtc().toIso8601String();

      final String authFrame =
          'X-Timestamp: $timestamp\r\n'
          'Content-Type: application/json;action=auth\r\n'
          'X-Target-User: $token\r\n'
          '\r\n';

      final String configFrame =
          'X-Timestamp: $timestamp\r\n'
          'Content-Type: application/json;action=config\r\n'
          'X-Response-Format: audio\r\n'
          'Host: speech.platform.bing.com\r\n'
          'Origin: chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold\r\n'
          '\r\n'
          '{"context":{"synthesis":{"audio":{"metadata":{"content-category":"SpeechPrinciples"},'
          '"codec":{"bitrate":24000,"container":"raw-rgb","sampleRate":24000},'
          '"config":{"language":"$locale",'
          '"device":{"deviceId":"WebkitSpeech-Default"},"delivery":"Realtime"},'
          '"synthesis":{"metadata":{"loc":"WR","platform":"Win","user":{},"device":{}}}}}}}';

      final String textFrame =
          'X-Timestamp: $timestamp\r\n'
          'Content-Type: application/ssml+xml;Boundary=Word;chunk=false\r\n'
          'X-Client-Message-Id: $_randomHex(16)\r\n'
          'X-Request-Id: $messageid\r\n'
          '\r\n'
          "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='$locale'>"
          "<voice name='$voiceName'>${_escapeXml(text)}</voice>"
          '</speak>';

      channel.sink.add(authFrame);
      // Wait for the server's auth acknowledgement before continuing.
      await firstResponse.future.timeout(const Duration(seconds: 8));
      await Future.delayed(const Duration(milliseconds: 200));
      channel.sink.add(configFrame);
      channel.sink.add(textFrame);

      await done.future;
    } finally {
      try {
        await channel.sink.close();
      } catch (_) {}
    }

    return audioBytes;
  }

  String? _headerValue(String headers, String key) {
    for (final line in headers.split('\n')) {
      final idx = line.indexOf(':');
      if (idx > 0 && line.substring(0, idx).trim().toLowerCase() == key.toLowerCase()) {
        return line.substring(idx + 1).trim();
      }
    }
    return null;
  }

  /// Rolling 44-char base36 "Sec-MS-GEC" value (same algorithm as the
  /// open-source edge-tts client).
  static String _genSecMsGec() {
    const String alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    int value = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final StringBuffer buffer = StringBuffer();
    while (value > 0) {
      buffer.write(alphabet[value % 36]);
      value = value ~/ 36;
    }
    final String encoded = buffer.toString().split('').reversed().join();
    // Pad / repeat to 44 characters, as expected by the endpoint.
    final String padded = (encoded + '0' * 44).substring(0, 44);
    return padded.padLeft(44, '0');
  }

  static String _randomHex(int length) {
    final Random rng = Random.secure();
    const String hex = '0123456789abcdef';
    return List.generate(length, (_) => hex[rng.nextInt(16)]).join();
  }

  static String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ──────────────────────────── Piper TTS ───────────────────────────
  // Piper is used against a self-hosted HTTP server (e.g. piper-http).
  // Requires [baseUrl] — a clear error is raised when it is missing.
  Future<bool> _generateAudioWithPiperTts({
    required String narration,
    required File savedFile,
    required String language,
  }) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      throw Exception(
        'Piper TTS needs a self-hosted Piper server URL. '
        'Set it in the project\'s Audio tab (Custom Base URL).',
      );
    }
    try {
      final response = await http.post(
        Uri.parse(baseUrl!),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': narration,
          'model': modelId ?? 'en_US-lessac-medium',
          'language': language,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await savedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('self-hosted')) rethrow;
      debugPrint('Piper TTS Error: $e');
    }
    return false;
  }

  // ─────────────────────────── OpenAI TTS ───────────────────────────
  Future<bool> _generateAudioWithOpenAiTts({
    required String narration,
    required File savedFile,
  }) async {
    try {
      if (apiKey == null || apiKey!.isEmpty) return false;

      final url = (baseUrl != null && baseUrl!.isNotEmpty)
          ? (baseUrl!.endsWith('/audio/speech') ? baseUrl! : _joinUrl(baseUrl!, 'audio/speech'))
          : 'https://api.openai.com/v1/audio/speech';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': modelId ?? 'gpt-4o-mini-tts',
          'input': narration,
          'voice': voice ?? 'alloy',
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await savedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      debugPrint('OpenAI TTS Error: $e');
    }
    return false;
  }

  static String _joinUrl(String base, String path) {
    final String b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$b/$path';
  }

  // ─────────────────────────── ElevenLabs ───────────────────────────
  Future<bool> _generateAudioWithElevenLabs({
    required String narration,
    required File savedFile,
  }) async {
    try {
      if (apiKey == null || apiKey!.isEmpty) return false;

      final String voiceId = (modelId != null && modelId!.isNotEmpty)
          ? modelId!
          : (voice ?? '21m00Tcm4TlvDq8ikWAM'); // default Rachel
      final url = 'https://api.elevenlabs.io/v1/text-to-speech/$voiceId';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'xi-api-key': apiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': narration,
          'model_id': 'eleven_turbo_v2',
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await savedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      debugPrint('ElevenLabs Error: $e');
    }
    return false;
  }
}
