/// Video purpose — what the video is FOR.
///
/// A purpose is not the story genre (haunted / love / action …); it is
/// the job the video has to do. Picking one pre-configures the render:
/// how fast scenes move, which narration tone the bridges use, which
/// background-music mood plays underneath, and whether karaoke captions
/// are on by default. The user can still change every one of those on
/// the prompt-video screen afterwards.
///
/// Pure data — no Flutter dependency, unit-tested.
library;

/// One purpose a video can serve.
class VideoPurpose {
  /// Stable id, e.g. 'reel'.
  final String id;

  /// Short label shown on the picker chip, e.g. 'Reel'.
  final String label;

  /// One line the picker shows under the label, e.g. 'Short, fast, hook-first'.
  final String tagline;

  /// Who / what it is best for — shown on the picker so the choice is obvious.
  final String bestFor;

  /// Target rendered seconds per scene (pacing). Shorter = faster cuts.
  final double sceneSeconds;

  /// Narration tone for chapter headings and bridge lines
  /// (an emotion from character_voices.dart).
  final String tone;

  /// Background-music mood (an sfx_service.dart type), or null to follow
  /// the genre / style instead.
  final String? sfxType;

  /// Whether karaoke captions start ON for this purpose.
  final bool karaokeDefault;

  const VideoPurpose({
    required this.id,
    required this.label,
    required this.tagline,
    required this.bestFor,
    required this.sceneSeconds,
    required this.tone,
    required this.sfxType,
    required this.karaokeDefault,
  });
}

/// All purposes, in picker order.
const List<VideoPurpose> videoPurposes = [
  VideoPurpose(
    id: 'reel',
    label: 'Reel',
    tagline: 'Short, fast, hook-first',
    bestFor: 'Instagram Reels / YouTube Shorts — 1–2 min, stops the scroll.',
    sceneSeconds: 6,
    tone: 'excited',
    sfxType: 'whoosh',
    karaokeDefault: true,
  ),
  VideoPurpose(
    id: 'story',
    label: 'Story',
    tagline: 'Cinematic story video',
    bestFor: 'Hindi story videos — the classic AIN-KAGEWEB format.',
    sceneSeconds: 8,
    tone: 'dramatic',
    sfxType: null,
    karaokeDefault: false,
  ),
  VideoPurpose(
    id: 'lecture',
    label: 'Lecture',
    tagline: 'Long-form teaching, slow and clear',
    bestFor: 'Lectures and classes — 30 min to 2 hours, calm pacing.',
    sceneSeconds: 12,
    tone: 'calm',
    sfxType: 'wind',
    karaokeDefault: true,
  ),
  VideoPurpose(
    id: 'education',
    label: 'Education',
    tagline: 'Explain a topic step by step',
    bestFor: 'Explain a concept, a chapter, or a how-to — captions on.',
    sceneSeconds: 12,
    tone: 'calm',
    sfxType: 'wind',
    karaokeDefault: true,
  ),
  VideoPurpose(
    id: 'information',
    label: 'Information',
    tagline: 'News / facts, straight to the point',
    bestFor: 'News, facts, updates — no drama, just the point.',
    sceneSeconds: 10,
    tone: 'neutral',
    sfxType: null,
    karaokeDefault: false,
  ),
  VideoPurpose(
    id: 'motivation',
    label: 'Motivation',
    tagline: 'High-energy, punchy lines',
    bestFor: 'Motivational videos — fast cuts, big energy.',
    sceneSeconds: 7,
    tone: 'excited',
    sfxType: 'heartbeat',
    karaokeDefault: false,
  ),
];

/// Purpose ids in picker order.
List<String> get purposeIds => videoPurposes.map((p) => p.id).toList();

/// Config for [id]. Unknown / empty ids fall back to 'story' — the
/// picker only ever offers known ids, so this is a safety net, not a
/// silent misconfiguration.
VideoPurpose purposeConfig(String? id) {
  final key = (id ?? '').trim().toLowerCase();
  for (final p in videoPurposes) {
    if (p.id == key) return p;
  }
  return videoPurposes[1]; // story
}
