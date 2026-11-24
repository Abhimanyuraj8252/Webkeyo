/// Voice providers — REST TTS clients for the keyed providers.
///
/// Rebuilt from `katha_studio/audio.py` (same endpoints, payloads,
/// limits) + the verified provider facts below.
/// Verified 24 Nov 2026: `flutter analyze` clean, unit-tested
/// (test/voice_providers_test.dart) for the pure helpers. The REST
/// clients themselves are NOT live-tested (no API key was used).
///
/// HARD RULES:
/// - No API key is ever hardcoded. The key comes from Settings only.
/// - A missing key, a placeholder voice id, or an empty / <1000-byte
///   response raises — never return silence as success.
/// - Free limits are ONLY the officially verified ones (24 Nov 2026).
///   Anything not verified is marked "free NOT verified".
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'character_voices.dart';

/// Verified facts about one provider (official page + date).
class VoiceProviderInfo {
  final String id; // provider id used by TtsService / Settings
  final String name;
  final String cost;
  final String freeLimit; // official source + date, or "free NOT verified"
  final String keyUrl;
  final String commercialUse; // allowed / not allowed / check terms
  final String hindiVoices; // which Hindi voices, or "not verified"
  final int maxChars;
  final bool mobileOk;
  final String status; // verified-free | paid-only | not-live-tested

  const VoiceProviderInfo({
    required this.id,
    required this.name,
    required this.cost,
    required this.freeLimit,
    required this.keyUrl,
    required this.commercialUse,
    required this.hindiVoices,
    required this.maxChars,
    required this.mobileOk,
    required this.status,
  });
}

const List<VoiceProviderInfo> voiceProviderInfos = [
  VoiceProviderInfo(
    id: 'sarvam_tts',
    name: 'Sarvam Bulbul',
    cost: '₹100 signup credits, then ₹20 / 10,000 chars',
    freeLimit: '₹100 signup credits (sarvam.ai, checked 24 Nov 2026).',
    keyUrl: 'https://www.sarvam.ai/try/tts-api',
    commercialUse: 'Allowed.',
    hindiVoices: '80+ Hindi voices, native Hinglish.',
    maxChars: 2500,
    mobileOk: true,
    status: 'verified-free',
  ),
  VoiceProviderInfo(
    id: 'gemini_tts',
    name: 'Gemini TTS',
    cost: 'Free of charge on the free tier',
    freeLimit: 'Free of charge on the free tier (Google AI Studio, checked 24 Nov 2026).',
    keyUrl: 'https://aistudio.google.com/apikey',
    commercialUse: 'Check Google AI Studio terms; free-tier content may be used to improve products.',
    hindiVoices: '30 prebuilt voices, Hindi listed.',
    maxChars: 8000,
    mobileOk: true,
    status: 'verified-free',
  ),
  VoiceProviderInfo(
    id: 'deepgram',
    name: 'Deepgram Flux TTS',
    cost: 'Free \$200 credit, then billed per 1,000 chars',
    freeLimit: 'Free \$200 credit, no card, no expiry (deepgram.com/pricing, checked 24 Nov 2026). Per-model rates were NOT on the fetched page.',
    keyUrl: 'https://deepgram.com/pricing',
    commercialUse: 'Check Deepgram terms before monetised use — no commercial-use claim made here.',
    hindiVoices: 'Flux Hindi voices: flux-ajay-hi, flux-anjali-hi, flux-arjun-hi, flux-divya-hi, flux-rahul-hi, flux-ritu-hi (developers.deepgram.com). Aura-2 has NO Hindi — Flux only.',
    maxChars: 2000,
    mobileOk: true,
    status: 'verified-free',
  ),
  VoiceProviderInfo(
    id: 'fish_audio',
    name: 'Fish Audio S2.1 Pro',
    cost: 'Free Tier \$0/mo; S2.1 Pro Free API model free through 30 Nov 2026; paid S2.1 Pro \$15 / 1M UTF-8 bytes',
    freeLimit: 'Free Tier: 8,000 credits/month (~7 min), 500 chars/generation (fish.audio/plan, checked 24 Nov 2026). S2.1 Pro Free API model free to call through 30 Nov 2026 (fish.audio/developers).',
    keyUrl: 'https://fish.audio/developers/',
    commercialUse: 'Free plan = personal, NON-COMMERCIAL only (plan FAQ). Plus \$11/mo billed annually allows commercial use.',
    hindiVoices: 'S2.1 Pro covers 83 languages per Fish Audio docs; Hindi presence NOT individually verified on the official pages fetched.',
    maxChars: 500,
    mobileOk: true,
    status: 'verified-free',
  ),
  VoiceProviderInfo(
    id: 'minimax_tts',
    name: 'MiniMax T2A — PAID ONLY',
    cost: 'speech-2.8-hd \$100/M chars, speech-2.8-turbo \$60/M chars (sync + async)',
    freeLimit: 'Free NOT verified — the official API pricing page (platform.minimax.io/docs/pricing/overview, checked 24 Nov 2026) publishes NO free allowance for speech synthesis. Do NOT present MiniMax as free.',
    keyUrl: 'https://platform.minimax.io/',
    commercialUse: 'Paid API — check MiniMax terms.',
    hindiVoices: '40 languages, 300+ system voices — Hindi voice id must come from the MiniMax console.',
    maxChars: 8000,
    mobileOk: true,
    status: 'paid-only',
  ),
];

VoiceProviderInfo? voiceProviderInfoFor(String id) {
  for (final info in voiceProviderInfos) {
    if (info.id == id) return info;
  }
  return null;
}

/// Wrap raw 16-bit mono PCM (24 kHz, Gemini) in a WAV header.
Uint8List pcmToWav(Uint8List pcm, {int sampleRate = 24000}) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataSize = pcm.length;
  final builder = BytesBuilder();
  void writeString(String s) => builder.add(s.codeUnits);
  void writeU32(int v) => builder.add([
        v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF,
      ]);
  void writeU16(int v) => builder.add([v & 0xFF, (v >> 8) & 0xFF]);
  writeString('RIFF');
  writeU32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeU32(16);
  writeU16(1); // PCM
  writeU16(channels);
  writeU32(sampleRate);
  writeU32(byteRate);
  writeU16(blockAlign);
  writeU16(bitsPerSample);
  writeString('data');
  writeU32(dataSize);
  builder.add(pcm);
  return builder.toBytes();
}

/// Decode a hex string (MiniMax returns audio as hex in data.audio).
Uint8List hexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  if (clean.length.isOdd) {
    throw FormatException('MiniMax hex audio has an odd length');
  }
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Emotion -> inline audio tag (Gemini / Fish). Sarvam / Google get
/// prosody/pace instead.
const Map<String, String> emotionAudioTags = {
  'laugh': '[laughs]',
  'excited': '[excited]',
  'sad': '[sighs]',
  'scared': '[whispers]',
  'whisper': '[whispers]',
  'angry': '[shouting]',
  'surprised': '[gasps]',
  'happy': '[laughs]',
};

/// REST client for the keyed voice providers. One method per provider;
/// every method raises on missing key / placeholder voice / empty audio.
class VoiceProviderClient {
  final http.Client _http;

  VoiceProviderClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  void _checkAudio(Uint8List bytes, String provider) {
    if (bytes.length < 1000) {
      throw StateError(
          '$provider returned only ${bytes.length} bytes — too small to be real audio. '
          'Check the key and the voice id; never treat this as a voiceover.');
    }
  }

  /// Sarvam Bulbul V4 Flash. Returns MP3 bytes.
  /// [pace] overrides the emotion-derived pace (1.0 = normal) — used by
  /// TtsService when the pace was already computed from the emotion.
  Future<Uint8List> synthesizeSarvam({
    required String apiKey,
    required String text,
    required String voiceId,
    required String emotion,
    double? pace,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('SARVAM_API_KEY is not set. Get one free at https://www.sarvam.ai/try/tts-api');
    }
    final clean = stripEmotionTag(text);
    final response = await _http.post(
      Uri.parse('https://api.sarvam.ai/text-to-speech'),
      headers: {
        'Content-Type': 'application/json',
        'api-subscription-key': apiKey,
      },
      body: jsonEncode({
        'inputs': [clean],
        'target_language_code': 'hi-IN',
        'speaker': voiceId,
        'pace': pace ?? paceForEmotion(emotion),
        'speech_sample_rate': 22050,
        'model': 'bulbul-v4-flash',
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Sarvam returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final audios = (data['audios'] as List?) ??
        (data['audio'] != null ? [data['audio']] : null);
    if (audios == null || audios.isEmpty) {
      throw StateError('Sarvam returned no audio: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final bytes = base64Decode(audios.first as String);
    _checkAudio(bytes, 'Sarvam');
    return bytes;
  }

  /// Gemini API TTS. Returns WAV bytes (PCM wrapped by [pcmToWav]).
  Future<Uint8List> synthesizeGemini({
    required String apiKey,
    required String text,
    required String voiceId,
    required String emotion,
    bool isNarration = false,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY is not set. Get one free at https://aistudio.google.com/apikey');
    }
    const model = 'gemini-2.5-flash-preview-tts';
    final clean = stripEmotionTag(text);
    final tag = emotionAudioTags[emotion] ?? '';
    final style = isNarration
        ? 'Narrate calmly and explain the scene'
        : 'Say in a $emotion tone';
    final prompt = '$style, in Hindi: $tag $clean'.trim();
    final response = await _http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voiceId}
            }
          },
        },
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Gemini TTS returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    String? b64;
    try {
      final candidates = data['candidates'] as List;
      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List;
      final inlineData = parts.first['inlineData'] as Map<String, dynamic>;
      b64 = inlineData['data'] as String?;
    } catch (_) {
      b64 = null;
    }
    if (b64 == null) {
      throw StateError('Gemini TTS returned no audio: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final wav = pcmToWav(base64Decode(b64));
    _checkAudio(wav, 'Gemini');
    return wav;
  }

  /// Deepgram Flux TTS. Returns MP3 bytes.
  /// NOTE: Flux is primarily served on /v2/speak; this /v1/speak call is
  /// implemented but NOT live-tested (no key). If v1 rejects a Flux
  /// model, use /v2/speak.
  Future<Uint8List> synthesizeDeepgram({
    required String apiKey,
    required String text,
    required String voiceId,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('DEEPGRAM_API_KEY is not set. Get one free at https://deepgram.com/pricing');
    }
    final clean = stripEmotionTag(text);
    final response = await _http.post(
      Uri.parse('https://api.deepgram.com/v1/speak?model=$voiceId&encoding=mp3'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $apiKey',
      },
      body: jsonEncode({'text': clean}),
    );
    if (response.statusCode != 200) {
      throw StateError('Deepgram returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final bytes = response.bodyBytes;
    _checkAudio(bytes, 'Deepgram');
    return bytes;
  }

  /// Fish Audio S2.1 Pro. Returns MP3 bytes.
  /// Voice IDs are UUIDs from the Fish Audio voice library.
  Future<Uint8List> synthesizeFishAudio({
    required String apiKey,
    required String text,
    required String voiceId,
    required String emotion,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('FISH_AUDIO_API_KEY is not set. Get one free at https://fish.audio/developers/');
    }
    if (voiceId.startsWith('REPLACE_WITH')) {
      throw StateError(
          'Fish Audio voice ID is still the placeholder $voiceId. Paste a real voice ID from the Fish Audio voice library into Settings first.');
    }
    final clean = stripEmotionTag(text);
    final tag = emotionAudioTags[emotion] ?? '';
    final tagged = tag.isEmpty ? clean : '$tag $clean';
    final response = await _http.post(
      Uri.parse('https://api.fish.audio/v1/tts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'text': tagged,
        'reference_id': voiceId,
        'format': 'mp3',
        'mp3_bitrate': 128,
        'normalize': true,
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Fish Audio returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final bytes = response.bodyBytes;
    _checkAudio(bytes, 'Fish Audio');
    return bytes;
  }

  /// MiniMax T2A — PAID ONLY. Free NOT verified (see [VoiceProviderInfo]).
  /// Returns MP3 bytes (hex audio in data.audio, decoded by [hexToBytes]).
  Future<Uint8List> synthesizeMiniMax({
    required String apiKey,
    required String text,
    required String voiceId,
    String model = 'speech-2.8-turbo',
    double speed = 1.0,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('MINIMAX_API_KEY is not set. MiniMax speech synthesis is PAID — no free allowance is published on its official pricing page.');
    }
    if (voiceId.startsWith('REPLACE_WITH')) {
      throw StateError(
          'MiniMax voice ID is still the placeholder $voiceId. Paste a real voice ID from the MiniMax console into Settings first.');
    }
    final clean = stripEmotionTag(text);
    final response = await _http.post(
      Uri.parse('https://api.minimax.io/v1/t2a_v2'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'text': clean,
        'stream': false,
        'voice_setting': {'voice_id': voiceId, 'speed': speed, 'vol': 1.0, 'pitch': 0},
        'audio_setting': {'sample_rate': 32000, 'bitrate': 128000, 'format': 'mp3'},
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('MiniMax returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hex = (data['data'] as Map?)?['audio'] as String?;
    if (hex == null || hex.isEmpty) {
      throw StateError('MiniMax returned no audio: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final bytes = hexToBytes(hex);
    _checkAudio(bytes, 'MiniMax');
    return bytes;
  }
}
