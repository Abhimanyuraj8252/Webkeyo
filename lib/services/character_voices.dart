/// Per-character voice map + emotion — the voicing pipeline's core.
///
/// Rebuilt from `katha_studio/voices.py` + `katha_studio/audio.py`
/// (same profiles, voice IDs, emotion keywords, pace table).
/// Verified 24 Nov 2026: `flutter analyze` clean, unit-tested (test/character_voices_test.dart).
///
/// Rules:
/// - Every speaker gets ONE voice per provider, and that voice never
///   changes mid-story — Arjun always sounds like Arjun.
/// - The Narrator gets a SEPARATE voice from every character.
/// - Gender is recorded per character so a male character never gets a
///   female voice and vice versa.
/// - Provider voice IDs are defaults only. The user picks the real
///   voices in Settings — that overrides everything here. ElevenLabs /
///   Fish / MiniMax voice IDs are UUIDs: the placeholder MUST be replaced
///   with a real ID (voiceFor throws a clear error instead of sending a
///   bad ID).
library;

/// Supported emotions.
const List<String> emotions = [
  'neutral',
  'happy',
  'excited',
  'sad',
  'angry',
  'scared',
  'surprised',
  'calm',
  'whisper',
  'laugh',
  'dramatic',
];

/// One character's voice profile.
class CharacterVoice {
  final String name;
  final String gender; // male | female
  final String tone;
  final String pace; // medium | medium-fast | slow-medium
  final String sampleLine;

  /// Provider id -> voice id. Keys: sarvam, gemini, elevenlabs, google,
  /// piper, edge, deepgram, fish_audio, minimax_tts.
  /// Piper values are 'male' / 'female' (Pratham / Priyamvada).
  final Map<String, String> voices;

  const CharacterVoice({
    required this.name,
    required this.gender,
    required this.tone,
    required this.pace,
    required this.sampleLine,
    required this.voices,
  });

  /// Voice id for [providerId]. Throws a clear error for placeholders.
  String voiceIdFor(String providerId) {
    final id = voices[providerId];
    if (id == null || id.isEmpty) {
      throw StateError(
          'No $providerId voice configured for $name. Set it in Settings first.');
    }
    if (id.startsWith('REPLACE_WITH')) {
      throw StateError(
          '$name\'s $providerId voice is still the placeholder $id. '
          'Paste a real voice ID from the provider\'s voice library into Settings first.');
    }
    return id;
  }
}

const String _elevenPlaceholder = 'REPLACE_WITH_ELEVENLABS_VOICE_ID';
const String _fishPlaceholder = 'REPLACE_WITH_FISH_AUDIO_VOICE_ID';
const String _minimaxPlaceholder = 'REPLACE_WITH_MINIMAX_VOICE_ID';

const CharacterVoice narratorVoice = CharacterVoice(
  name: 'Narrator',
  gender: 'female',
  tone: 'warm, calm, storytelling',
  pace: 'medium',
  sampleLine: 'Aur phir, us raat kuch aisa hua jo kisi ne socha bhi nahi tha.',
  voices: {
    'sarvam_tts': 'Meera',
    'gemini_tts': 'Aoede',
    'elevenlabs': _elevenPlaceholder,
    'google_cloud_tts': 'hi-IN-Neural2-D',
    'piper_tts': 'female', // Priyamvada
    'edge_tts': 'hi-IN-SwaraNeural',
    'deepgram': 'flux-anjali-hi',
    'fish_audio': _fishPlaceholder,
    'minimax_tts': _minimaxPlaceholder,
  },
);

const CharacterVoice arjunVoice = CharacterVoice(
  name: 'Arjun',
  gender: 'male',
  tone: 'young, brave, a little stubborn',
  pace: 'medium-fast',
  sampleLine: 'Main haar nahi maanunga, chahe kuch bhi ho jaye.',
  voices: {
    'sarvam_tts': 'Shubh',
    'gemini_tts': 'Fenrir',
    'elevenlabs': _elevenPlaceholder,
    'google_cloud_tts': 'hi-IN-Neural2-B',
    'piper_tts': 'male', // Pratham
    'edge_tts': 'hi-IN-MadhurNeural',
    'deepgram': 'flux-arjun-hi',
    'fish_audio': _fishPlaceholder,
    'minimax_tts': _minimaxPlaceholder,
  },
);

const CharacterVoice titliVoice = CharacterVoice(
  name: 'Titli',
  gender: 'female',
  tone: 'gentle, mysterious, kind',
  pace: 'slow-medium',
  sampleLine: 'Tumhe pata hai, kuch kahaniyan waqt se pehle khatm nahi hoti.',
  voices: {
    'sarvam_tts': 'Ishita',
    'gemini_tts': 'Leda',
    'elevenlabs': _elevenPlaceholder,
    'google_cloud_tts': 'hi-IN-Neural2-A',
    'piper_tts': 'female', // Priyamvada
    'edge_tts': 'hi-IN-SwaraNeural',
    'deepgram': 'flux-divya-hi',
    'fish_audio': _fishPlaceholder,
    'minimax_tts': _minimaxPlaceholder,
  },
);

const Map<String, CharacterVoice> _knownVoices = {
  'Narrator': narratorVoice,
  'Arjun': arjunVoice,
  'Titli': titliVoice,
};

CharacterVoice _genderFallback(String gender) {
  if (gender == 'male') {
    return const CharacterVoice(
      name: '',
      gender: 'male',
      tone: 'distinct, consistent voice',
      pace: 'medium',
      sampleLine: 'Main yeh kahani suna raha hoon.',
      voices: {
        'sarvam_tts': 'Arjun',
        'gemini_tts': 'Charon',
        'elevenlabs': _elevenPlaceholder,
        'google_cloud_tts': 'hi-IN-Neural2-B',
        'piper_tts': 'male',
        'edge_tts': 'hi-IN-MadhurNeural',
        'deepgram': 'flux-rahul-hi',
        'fish_audio': _fishPlaceholder,
        'minimax_tts': _minimaxPlaceholder,
      },
    );
  }
  return const CharacterVoice(
    name: '',
    gender: 'female',
    tone: 'distinct, consistent voice',
    pace: 'medium',
    sampleLine: 'Main yeh kahani suna raha hoon.',
    voices: {
      'sarvam_tts': 'Ritu',
      'gemini_tts': 'Aoede',
      'elevenlabs': _elevenPlaceholder,
      'google_cloud_tts': 'hi-IN-Neural2-D',
      'piper_tts': 'female',
      'edge_tts': 'hi-IN-SwaraNeural',
      'deepgram': 'flux-ritu-hi',
      'fish_audio': _fishPlaceholder,
      'minimax_tts': _minimaxPlaceholder,
    },
  );
}

/// Voice map for one render: one profile per speaker actually used.
/// Known characters get their curated profile; unknown names get the
/// gender fallback (female by default) so the pipeline never crashes
/// on a new name.
class CharacterVoiceMap {
  final Map<String, CharacterVoice> _map;

  CharacterVoiceMap._(this._map);

  factory CharacterVoiceMap.fromScenes(List<Map<String, dynamic>> scenes,
      {Map<String, String> genders = const {}}) {
    final map = <String, CharacterVoice>{};
    for (final scene in scenes) {
      final speaker = (scene['speaker'] ?? 'Narrator') as String;
      if (map.containsKey(speaker)) continue;
      final known = _knownVoices[speaker];
      if (known != null) {
        map[speaker] = known;
      } else {
        final gender = (genders[speaker] ?? 'female').toLowerCase();
        final fallback = _genderFallback(gender == 'male' ? 'male' : 'female');
        map[speaker] = CharacterVoice(
          name: speaker,
          gender: fallback.gender,
          tone: 'distinct, consistent voice for $speaker',
          pace: fallback.pace,
          sampleLine: fallback.sampleLine,
          voices: fallback.voices,
        );
      }
    }
    map.putIfAbsent('Narrator', () => narratorVoice);
    return CharacterVoiceMap._(map);
  }

  CharacterVoice profileFor(String speaker) =>
      _map[speaker] ?? _map['Narrator']!;

  List<String> get speakers => _map.keys.toList();
}

// ---------------------------------------------------------------------------
// Emotion detection — same keyword table as katha_studio/audio.py.
// Explicit [tag] at the start of a line wins over keyword guessing.
// Matching is TOKEN-based: short keywords (<=3 chars) need an exact
// token, so "room" never reads as crying ("ro").
// ---------------------------------------------------------------------------

final RegExp _tagRe = RegExp(r'^\s*\[([a-zA-Z_ ]+)\]\s*');

const Map<String, List<String>> _emotionKeywords = {
  'laugh': ['hans', 'हंस', 'हँस', 'mazaak', 'मज़ाक', 'mazak', 'laugh', 'haha'],
  'angry': ['gussa', 'गुस्सा', 'krodh', 'क्रोध', 'naaraaz', 'नाराज़', 'angry', 'furious', 'chillata', 'चिल्ला'],
  'sad': ['ro', 'रो', 'rone', 'rota', 'roti', 'roya', 'rona', 'aansu', 'आँसू', 'aansoo', 'dukh', 'दुख', 'udaas', 'उदास', 'sad', 'cry', 'crying'],
  'scared': ['darr', 'डर', 'bhoot', 'भूत', 'khauf', 'खौफ़', 'scared', 'afraid', 'fear', 'bachao', 'बचाओ'],
  'whisper': ['chup', 'चुप', 'dheere', 'धीरे', 'whisper', 'faint', 'kanafusi', 'कानाफूसी'],
  'excited': ['daudo', 'दौड़ो', 'jaldi', 'जल्दी', 'excited', 'amazing', 'shabaash', 'शाबाश', 'jeet', 'जीत'],
  'happy': ['khush', 'खुश', 'muskura', 'मुस्कुरा', 'happy', 'khushi', 'खुशी', 'great', 'badhai', 'बधाई'],
  'surprised': ['hairan', 'हैरान', 'achanak', 'अचानक', 'surprised', 'shock', 'kya', 'क्या', 'arre', 'अरे'],
  'calm': ['shant', 'शांत', 'calm', 'aaram', 'आराम', 'shaanti', 'शांति'],
  'dramatic': ['andhera', 'अंधेरा', 'raaz', 'राज़', 'dramatic', 'rahasya', 'रहस्य', 'dark', 'mystery'],
};

String detectEmotion(String text) {
  if (text.isEmpty) return 'neutral';
  final tagMatch = _tagRe.firstMatch(text);
  if (tagMatch != null) {
    final tag = tagMatch.group(1)!.trim().toLowerCase().replaceAll(' ', '_');
    if (emotions.contains(tag)) return tag;
    if (tag == 'anger' || tag == 'gussa') return 'angry';
    if (tag == 'crying' || tag == 'crie') return 'sad';
  }
  final tokens = RegExp(r'[a-z0-9\u0900-\u097f]+')
      .allMatches(text.toLowerCase())
      .map((m) => m.group(0)!)
      .toList();
  for (final entry in _emotionKeywords.entries) {
    for (final kw in entry.value) {
      if (kw.length <= 3) {
        if (tokens.contains(kw)) return entry.key;
      } else if (tokens.any((tok) => tok.startsWith(kw))) {
        return entry.key;
      }
    }
  }
  return 'neutral';
}

/// Remove a leading [emotion] tag so it is not read aloud.
String stripEmotionTag(String text) => text.replaceFirst(_tagRe, '').trim();

/// Pace multiplier per emotion (Sarvam pace, Google SSML rate).
double paceForEmotion(String emotion) {
  const pace = {
    'neutral': 1.0, 'calm': 0.9, 'sad': 0.85, 'whisper': 0.85,
    'happy': 1.05, 'excited': 1.15, 'angry': 1.1, 'scared': 1.1,
    'surprised': 1.1, 'laugh': 1.05, 'dramatic': 0.9,
  };
  return pace[emotion] ?? 1.0;
}

/// The spoken line for a scene: dialogue as-is; a scene with NO dialogue
/// is explained by the narrator from its description.
Map<String, String> narratorLineForScene(Map<String, dynamic> scene) {
  final narration = ((scene['narration'] ?? scene['text'] ?? '') as String).trim();
  final dialogue = ((scene['dialogue'] ?? '') as String).trim();
  final speaker = ((scene['speaker'] ?? 'Narrator') as String).trim();
  if (dialogue.isNotEmpty) {
    return {'speaker': speaker, 'text': dialogue, 'emotion': detectEmotion(dialogue)};
  }
  // No dialogue — the narrator explains the scene.
  final text = narration.isNotEmpty
      ? narration
      : ((scene['description'] ?? 'Aur phir, kahani aage badhi.') as String);
  return {'speaker': 'Narrator', 'text': text, 'emotion': detectEmotion(text)};
}
