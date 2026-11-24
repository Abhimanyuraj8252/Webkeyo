/// Style presets for prompt-to-video — the user picks one, the video follows.
///
/// Rebuilt from `katha_studio/styles.py` (same ids, colours, labels).
/// Verified 24 Nov 2026: `flutter analyze` clean, unit-tested (test/video_style_test.dart).
///
/// 10 presets. Each one is a complete look: gradient colours, accent,
/// particle type, SFX, and motion direction (how the Ken Burns pan moves).
/// Colours are 0xFFrrggbb ints (pure Dart, no Flutter dependency).
library;

/// One style preset.
class VideoStyle {
  final String id;
  final String label;
  final String description;
  final int topColor;
  final int bottomColor;
  final int accentColor;
  final String particle; // stars | rain | petals | embers | none
  final String sfx; // sfx_service.dart type
  final String motion; // zoom-in | pan-left | pan-right

  const VideoStyle({
    required this.id,
    required this.label,
    required this.description,
    required this.topColor,
    required this.bottomColor,
    required this.accentColor,
    required this.particle,
    required this.sfx,
    required this.motion,
  });
}

int _c(int r, int g, int b) => 0xFF000000 | (r << 16) | (g << 8) | b;

const String defaultStyleId = 'cinematic-dark';

/// All 10 presets, in display order. Colours mirror katha_studio/styles.py.
final Map<String, VideoStyle> videoStyles = {
  'cinematic-dark': VideoStyle(
    id: 'cinematic-dark',
    label: 'CINEMATIC',
    description: 'Dark premium look — the default. Deep blue-black gradient, red accent.',
    topColor: _c(8, 12, 32),
    bottomColor: _c(28, 8, 40),
    accentColor: _c(180, 40, 60),
    particle: 'stars',
    sfx: 'wind',
    motion: 'zoom-in',
  ),
  'anime-premium': VideoStyle(
    id: 'anime-premium',
    label: 'ANIME',
    description: 'Violet anime look — bold purple, glowing accents, premium story feel.',
    topColor: _c(16, 10, 44),
    bottomColor: _c(60, 16, 80),
    accentColor: _c(168, 85, 247),
    particle: 'stars',
    sfx: 'chime',
    motion: 'zoom-in',
  ),
  'neon-cyberpunk': VideoStyle(
    id: 'neon-cyberpunk',
    label: 'CYBERPUNK',
    description: 'Cyan neon on black — future-city / hacker / robot stories.',
    topColor: _c(6, 8, 24),
    bottomColor: _c(10, 24, 40),
    accentColor: _c(34, 211, 238),
    particle: 'stars',
    sfx: 'whoosh',
    motion: 'pan-right',
  ),
  'horror-night': VideoStyle(
    id: 'horror-night',
    label: 'HAUNTED NIGHT',
    description: 'Blood-red on near-black, heavy rain — haunted / ghost stories.',
    topColor: _c(8, 10, 18),
    bottomColor: _c(24, 4, 12),
    accentColor: _c(220, 38, 38),
    particle: 'rain',
    sfx: 'rain_thunder',
    motion: 'zoom-in',
  ),
  'romantic-pink': VideoStyle(
    id: 'romantic-pink',
    label: 'LOVE STORY',
    description: 'Soft pink on deep maroon, falling petals — love / shaadi stories.',
    topColor: _c(40, 8, 32),
    bottomColor: _c(90, 20, 50),
    accentColor: _c(244, 114, 182),
    particle: 'petals',
    sfx: 'chime',
    motion: 'pan-left',
  ),
  'motivational-gold': VideoStyle(
    id: 'motivational-gold',
    label: 'NEVER GIVE UP',
    description: 'Gold on dark amber, rising embers — jeet / struggle / motivation.',
    topColor: _c(24, 16, 6),
    bottomColor: _c(60, 40, 8),
    accentColor: _c(250, 204, 21),
    particle: 'embers',
    sfx: 'heartbeat',
    motion: 'zoom-in',
  ),
  'minimal-clean': VideoStyle(
    id: 'minimal-clean',
    label: 'STORY',
    description: 'Quiet slate-grey minimal look — explainer / calm narration.',
    topColor: _c(18, 24, 34),
    bottomColor: _c(38, 48, 64),
    accentColor: _c(226, 232, 240),
    particle: 'stars',
    sfx: 'wind',
    motion: 'pan-right',
  ),
  'retro-film': VideoStyle(
    id: 'retro-film',
    label: 'RETRO',
    description: 'Warm sepia / 70s film feel — old-time / village stories.',
    topColor: _c(34, 22, 10),
    bottomColor: _c(74, 52, 18),
    accentColor: _c(251, 146, 60),
    particle: 'embers',
    sfx: 'wind',
    motion: 'pan-left',
  ),
  'nature-green': VideoStyle(
    id: 'nature-green',
    label: 'NATURE',
    description: 'Deep forest green — village / jungle / nature stories.',
    topColor: _c(8, 26, 18),
    bottomColor: _c(16, 56, 32),
    accentColor: _c(74, 222, 128),
    particle: 'petals',
    sfx: 'wind',
    motion: 'pan-right',
  ),
  'royal-purple': VideoStyle(
    id: 'royal-purple',
    label: 'ROYAL',
    description: 'Rich royal purple — raja-rani / fantasy / mystery stories.',
    topColor: _c(18, 8, 40),
    bottomColor: _c(48, 16, 84),
    accentColor: _c(192, 132, 252),
    particle: 'stars',
    sfx: 'chime',
    motion: 'zoom-in',
  ),
};

/// Style ids in display order.
List<String> get styleIds => videoStyles.keys.toList();

/// Style for [id] (default when null/empty). Throws on unknown id.
VideoStyle getVideoStyle(String? id) {
  if (id == null || id.trim().isEmpty) return videoStyles[defaultStyleId]!;
  final key = id.trim().toLowerCase().replaceAll('_', '-');
  final style = videoStyles[key];
  if (style == null) {
    throw ArgumentError(
        "Unknown style '$id'. Choose one of: ${styleIds.join(', ')}");
  }
  return style;
}

/// Detected video theme -> style, used when the user picks no style.
const Map<String, String> themeToStyle = {
  'haunted': 'horror-night',
  'night': 'cinematic-dark',
  'love': 'romantic-pink',
  'action': 'neon-cyberpunk',
  'sad': 'cinematic-dark',
  'happy': 'motivational-gold',
  'mystery': 'royal-purple',
};

String styleIdForTheme(String theme) =>
    themeToStyle[theme.toLowerCase()] ?? defaultStyleId;

/// Split a 0xFFrrggbb colour into [r, g, b].
List<int> rgbOf(int color) =>
    [(color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF];
