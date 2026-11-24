/// Voice providers — REST TTS clients for the keyed providers.
///
/// Rebuilt from `katha_studio/audio.py` (same endpoints, payloads,
/// limits) + the verified provider facts below.
/// Verified 24 Nov 2026: `flutter analyze` clean, unit-tested
/// (test/voice_providers_test.dart) for the pure helpers. The REST
/// clients themselves are NOT live-tested (no API key was used).
///
/// v1.2.0 (24 Nov 2026): added Google Cloud TTS WaveNet (completed),
/// Amazon Polly (SigV4), Speechify Simba, Azure AI Speech (SwaraNeural
/// emotion styles). Prices/limits are ONLY the officially verified
/// ones (24 Nov 2026, ~800 chars/min = 48,000 chars/hour, ₹88 = $1).
/// Gemini TTS: Google does NOT publish per-project free-tier request
/// limits — published rate-limit tables report ~3 RPM / 10 requests/day
/// for 2.5 Flash TTS, so it is previews/short clips only; never claim
/// hours of free Gemini narration. The preview model
/// (gemini-2.5-flash-preview-tts) is being shut down 18 Dec 2026 —
/// the client now uses gemini-2.5-flash-tts.
/// OpenAI TTS is NOT wired here: tts-1 / gpt-4o-mini-tts shut down
/// 6 Jan 2027. Kokoro is NOT presented as emotional (no emotion
/// control at all).
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

import 'package:crypto/crypto.dart';
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

  /// Free characters per month published on the official pricing page,
  /// or null when the provider publishes no monthly character allowance
  /// (rate-limited / credit-based free tiers). Used by BillingService
  /// to show how much of the free tier is left.
  final int? freeCharsPerMonth;

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
    this.freeCharsPerMonth,
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
    cost: 'Free of charge on the free tier; paid audio tokens from \$9/1M (3.8 Flash TTS, through 31 Dec 2026)',
    freeLimit: 'Free of charge on the free tier (Google AI Studio), BUT Google does NOT publish the per-project request limits — published rate-limit tables report ~3 RPM / 10 requests per day for 2.5 Flash TTS. Treat as previews / short clips only; do NOT plan hours of narration on it. The preview model is being shut down 18 Dec 2026 — the client uses gemini-2.5-flash-tts (checked 24 Nov 2026).',
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
  VoiceProviderInfo(
    id: 'google_cloud_tts',
    name: 'Google Cloud TTS (WaveNet)',
    cost: 'Standard / WaveNet \$4/1M chars (≈₹17/hr); Neural2 \$16/1M (≈₹68/hr); Chirp 3 HD \$30/1M (≈₹127/hr)',
    freeLimit: '4M chars/month free (Standard + WaveNet), 1M/month Neural2 + Chirp 3 HD — permanent, but billing / a card must be enabled on the Google Cloud project even for free use (cloud.google.com/text-to-speech/pricing, checked 24 Nov 2026). 4M chars ≈ 83 hrs/month.',
    keyUrl: 'https://console.cloud.google.com/apis/library/texttospeech.googleapis.com',
    commercialUse: 'Allowed under Google Cloud terms.',
    hindiVoices: '46 hi-IN voices counted on Google\'s supported-voices page (6 Standard, 6 WaveNet, 4 Neural2, 30 Chirp 3 HD).',
    maxChars: 5000,
    mobileOk: true,
    status: 'verified-free',
    freeCharsPerMonth: 4000000,
  ),
  VoiceProviderInfo(
    id: 'amazon_polly',
    name: 'Amazon Polly (Standard)',
    cost: 'Standard \$4/1M chars (≈₹17/hr); Neural \$16/1M (≈₹68/hr)',
    freeLimit: '5M chars/month Standard free, first 12 months only; Neural 1M/month, first 12 months only (aws.amazon.com/polly/pricing, checked 24 Nov 2026). 5M chars ≈ 104 hrs/month while the free tier lasts.',
    keyUrl: 'https://console.aws.amazon.com/polly/',
    commercialUse: 'Allowed under AWS terms.',
    hindiVoices: 'Aditi, Kajal (hi-IN Standard, female). No male Hindi Standard voice verified — male characters need the Neural voice Arjun verified in the AWS console first.',
    maxChars: 3000,
    mobileOk: true,
    status: 'verified-free',
    freeCharsPerMonth: 5000000,
  ),
  VoiceProviderInfo(
    id: 'speechify',
    name: 'Speechify Simba',
    cost: 'Starter \$10/month flat = 2M chars included (≈42 hrs → ≈₹21/hr effective); Simba 3.0/3.2 \$10/1M Starter, \$6/1M Scale',
    freeLimit: 'Free 500K chars/month (≈10 hrs/month), no card, commercial use allowed (speechify.ai/pricing, checked 24 Nov 2026).',
    keyUrl: 'https://platform.speechify.ai',
    commercialUse: 'Commercial use allowed on the free tier.',
    hindiVoices: 'Simba 3.5: every catalog voice speaks 48 languages incl. Hindi. Simba 3.2 is English-only per Speechify docs — use simba-3.5 for Hindi.',
    maxChars: 2000,
    mobileOk: true,
    status: 'verified-free',
    freeCharsPerMonth: 500000,
  ),
  VoiceProviderInfo(
    id: 'azure_speech',
    name: 'Azure AI Speech',
    cost: 'Neural \$15/1M chars (≈₹63/hr); Neural HD \$22/1M (≈₹93/hr)',
    freeLimit: 'F0: 0.5M neural chars/month free (≈10 hrs/month) (azure.microsoft.com pricing, checked 24 Nov 2026).',
    keyUrl: 'https://portal.azure.com/#create/Microsoft.CognitiveServicesSpeechServices',
    commercialUse: 'Allowed under Azure terms.',
    hindiVoices: '9 hi-IN neural voices: Aarav, Ananya, Aarti, Arjun, Kavya, Kunal, Rehaan, Swara (F), Madhur (M). SwaraNeural has REAL emotion styles: cheerful, empathetic, newscast.',
    maxChars: 5000,
    mobileOk: true,
    status: 'verified-free',
    freeCharsPerMonth: 500000,
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
    // Stable (non-preview) model: the preview model
    // (gemini-2.5-flash-preview-tts) is being shut down 18 Dec 2026.
    const model = 'gemini-2.5-flash-tts';
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

  /// Google Cloud TTS (WaveNet default). Returns MP3 bytes.
  /// Billing / a card must be enabled on the Google Cloud project even
  /// for the 4M chars/month free tier — never the default provider.
  /// SSML prosody (rate + pitch) is the only emotion control here.
  Future<Uint8List> synthesizeGoogleCloud({
    required String apiKey,
    required String text,
    required String voiceId,
    required String emotion,
    double? pace,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError(
          'GOOGLE_TTS_KEY is not set. Enable billing and get a key at https://console.cloud.google.com/apis/library/texttospeech.googleapis.com');
    }
    final clean = stripEmotionTag(text).replaceAll('&', 'and');
    final rate = (pace ?? paceForEmotion(emotion)).toStringAsFixed(2);
    // Emotions map to a small pitch shift only — WaveNet has no acted
    // emotion styles; Azure SwaraNeural is the emotional one.
    final pitch = (emotion == 'sad' || emotion == 'calm' || emotion == 'whisper')
        ? '-2st'
        : (emotion == 'excited' || emotion == 'happy' || emotion == 'angry')
            ? '+2st'
            : '+0st';
    final ssml =
        '<speak><prosody rate="$rate" pitch="$pitch">$clean</prosody></speak>';
    final response = await _http.post(
      Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'ssml': ssml},
        'voice': {'languageCode': 'hi-IN', 'name': voiceId},
        'audioConfig': {'audioEncoding': 'MP3'},
      }),
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError(
          'Google Cloud TTS returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final audioContent = data['audioContent'] as String?;
    if (audioContent == null || audioContent.isEmpty) {
      throw StateError('Google Cloud TTS returned no audio.');
    }
    final bytes = base64Decode(audioContent);
    _checkAudio(bytes, 'Google Cloud TTS');
    return bytes;
  }

  /// Amazon Polly (Standard). Returns MP3 bytes.
  /// Needs AWS SigV4 signing: Access Key ID + Secret Access Key +
  /// region (default ap-south-1). Free tier is first 12 months only.
  /// [voiceId] must be a Polly voice id, e.g. 'Aditi' or 'Kajal'.
  Future<Uint8List> synthesizePolly({
    required String accessKeyId,
    required String secretAccessKey,
    required String text,
    required String voiceId,
    String region = 'ap-south-1',
    DateTime? now,
  }) async {
    if (accessKeyId.isEmpty || secretAccessKey.isEmpty) {
      throw StateError(
          'Polly needs an AWS Access Key ID + Secret Access Key in Settings (IAM user with polly:SynthesizeSpeech).');
    }
    final clean = stripEmotionTag(text);
    final body = jsonEncode({
      'OutputFormat': 'mp3',
      'Text': clean,
      'TextType': 'text',
      'VoiceId': voiceId,
    });
    final timestamp = now ?? DateTime.now().toUtc();
    final headers = sigV4Headers(
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
      region: region,
      service: 'polly',
      method: 'POST',
      host: 'polly.$region.amazonaws.com',
      path: '/v1/speech',
      body: body,
      timestamp: timestamp,
    );
    final response = await _http
        .post(
          Uri.parse('https://polly.$region.amazonaws.com/v1/speech'),
          headers: {
            'Content-Type': 'application/json',
            ...headers,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError(
          'Amazon Polly returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final bytes = response.bodyBytes;
    _checkAudio(bytes, 'Amazon Polly');
    return bytes;
  }

  /// Speechify Simba. Returns MP3 bytes (base64 `audio_data` in the
  /// JSON response). [model] is 'simba-3.5' (48 languages incl. Hindi,
  /// default) or 'simba-3.2' (English-only per Speechify docs — do not
  /// use it for Hindi). [voiceId] is a voice id from GET /v1/voices.
  /// Input is limited to 2,000 spoken characters per request.
  Future<Uint8List> synthesizeSpeechify({
    required String apiKey,
    required String text,
    required String voiceId,
    String model = 'simba-3.5',
    String language = 'hi-IN',
  }) async {
    if (apiKey.isEmpty) {
      throw StateError(
          'SPEECHIFY_API_KEY is not set. Get one free at https://platform.speechify.ai');
    }
    if (voiceId.startsWith('REPLACE_WITH')) {
      throw StateError(
          'Speechify voice ID is still the placeholder $voiceId. Paste a real voice ID from GET /v1/voices (platform.speechify.ai) into Settings first.');
    }
    final clean = stripEmotionTag(text);
    final response = await _http.post(
      Uri.parse('https://api.speechify.ai/v1/audio/speech'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'input': clean,
        'voice_id': voiceId,
        'model': model,
        'audio_format': 'mp3',
        'language': language,
      }),
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError(
          'Speechify returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final audioData = data['audio_data'] as String?;
    if (audioData == null || audioData.isEmpty) {
      throw StateError('Speechify returned no audio_data.');
    }
    final bytes = base64Decode(audioData);
    _checkAudio(bytes, 'Speechify');
    return bytes;
  }

  /// Azure AI Speech (neural). Returns MP3 bytes.
  /// [emotion] is mapped to an mstts express-as style for SwaraNeural
  /// only ('cheerful', 'empathetic', 'newscast' — verified). Other
  /// voices get plain SSML (no style). Pass an explicit [style] to
  /// override the mapping.
  Future<Uint8List> synthesizeAzure({
    required String apiKey,
    required String text,
    required String voiceId,
    String region = 'centralindia',
    String emotion = 'neutral',
    String? style,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError(
          'AZURE_SPEECH_KEY is not set. Create a Speech resource (F0 free tier) at https://portal.azure.com and paste its key + region in Settings.');
    }
    final clean = stripEmotionTag(text)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final effectiveStyle = style ?? azureStyleForEmotion(emotion, voiceId);
    final voiceTag = effectiveStyle.isEmpty
        ? '<voice name="$voiceId">$clean</voice>'
        : '<voice name="$voiceId"><mstts:express-as style="$effectiveStyle">$clean</mstts:express-as></voice>';
    final ssml =
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
        'xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="hi-IN">'
        '$voiceTag</speak>';
    final response = await _http.post(
      Uri.parse('https://$region.tts.speech.microsoft.com/cognitiveservices/v1'),
      headers: {
        'Content-Type': 'application/ssml+xml',
        'Ocp-Apim-Subscription-Key': apiKey,
        'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
      },
      body: ssml,
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError(
          'Azure Speech returned HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    }
    final bytes = response.bodyBytes;
    _checkAudio(bytes, 'Azure Speech');
    return bytes;
  }
}

// ---------------------------------------------------------------------------
// AWS Signature Version 4 (for Amazon Polly). Pure helpers — unit-tested.
// See https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sig-create-canonical-request.html
// ---------------------------------------------------------------------------

String _hexSha256(List<int> bytes) => sha256.convert(bytes).toString();

List<int> _hmacSha256(List<int> key, String data) =>
    Hmac(sha256, key).convert(utf8.encode(data)).bytes;

/// The SigV4 canonical request for a Polly SynthesizeSpeech POST.
/// Signed headers are always content-type, host, x-amz-date.
String sigV4CanonicalRequest({
  required String method,
  required String host,
  required String path,
  required String amzDate,
  required String body,
}) {
  final payloadHash = _hexSha256(utf8.encode(body));
  return '$method\n$path\n\n'
      'content-type:application/json\n'
      'host:$host\n'
      'x-amz-date:$amzDate\n'
      '\n'
      'content-type;host;x-amz-date\n'
      '$payloadHash';
}

/// Derive the SigV4 signing key: kDate -> kRegion -> kService -> kSigning.
List<int> sigV4SigningKey({
  required String secretAccessKey,
  required String dateStamp, // YYYYMMDD
  required String region,
  required String service,
}) {
  var key = _hmacSha256(utf8.encode('AWS4$secretAccessKey'), dateStamp);
  key = _hmacSha256(key, region);
  key = _hmacSha256(key, service);
  key = _hmacSha256(key, 'aws4_request');
  return key;
}

/// SigV4 headers for a request: X-Amz-Date + Authorization.
/// [timestamp] is UTC; [body] is the exact request body string.
Map<String, String> sigV4Headers({
  required String accessKeyId,
  required String secretAccessKey,
  required String region,
  required String service,
  required String method,
  required String host,
  required String path,
  required String body,
  required DateTime timestamp,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final amzDate =
      '${timestamp.year}${two(timestamp.month)}${two(timestamp.day)}T${two(timestamp.hour)}${two(timestamp.minute)}${two(timestamp.second)}Z';
  final dateStamp = amzDate.substring(0, 8);
  final canonicalRequest = sigV4CanonicalRequest(
    method: method,
    host: host,
    path: path,
    amzDate: amzDate,
    body: body,
  );
  final scope = '$dateStamp/$region/$service/aws4_request';
  final stringToSign =
      'AWS4-HMAC-SHA256\n$amzDate\n$scope\n${_hexSha256(utf8.encode(canonicalRequest))}';
  final signingKey = sigV4SigningKey(
    secretAccessKey: secretAccessKey,
    dateStamp: dateStamp,
    region: region,
    service: service,
  );
  final signature =
      _hmacSha256(signingKey, stringToSign).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return {
    'X-Amz-Date': amzDate,
    'Authorization':
        'AWS4-HMAC-SHA256 Credential=$accessKeyId/$scope, SignedHeaders=content-type;host;x-amz-date, Signature=$signature',
  };
}

// ---------------------------------------------------------------------------
// Azure emotion styles — ONLY SwaraNeural has verified styles
// (cheerful, empathetic, newscast). Every other hi-IN voice gets plain
// SSML (empty style). Do not invent styles for other voices.
// ---------------------------------------------------------------------------

/// mstts express-as style for [emotion] on [voiceId], or '' for plain SSML.
String azureStyleForEmotion(String emotion, String voiceId) {
  if (!voiceId.contains('SwaraNeural')) return '';
  switch (emotion) {
    case 'happy':
    case 'excited':
    case 'laugh':
      return 'cheerful';
    case 'sad':
    case 'calm':
    case 'whisper':
      return 'empathetic';
    case 'dramatic':
      return 'newscast';
    default:
      return '';
  }
}
