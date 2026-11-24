/// One-tap reel templates — the 10 existing styles packaged as named
/// templates a creator can tap once and render. No server, no
/// marketplace: templates are local and ship with the app.
///
/// [styleId] must match a [VideoStyle.id] in video_style.dart.
/// [prompt] is the starter story prompt for the template.
/// [durationSeconds] is the suggested render length for a reel.
library;

class ReelTemplate {
  final String id;
  final String name;
  final String tagline;
  final String styleId;
  final String prompt;
  final int durationSeconds;
  final List<String> hashtags;

  const ReelTemplate({
    required this.id,
    required this.name,
    required this.tagline,
    required this.styleId,
    required this.prompt,
    required this.durationSeconds,
    required this.hashtags,
  });
}

const List<ReelTemplate> reelTemplates = [
  ReelTemplate(
    id: 'haunted_night',
    name: 'Haunted Night',
    tagline: 'A horror story that keeps viewers till the last second.',
    styleId: 'horror-night',
    prompt:
        'A boy checks into a haunted inn at midnight. The waiter is not human. Write a scary Hindi story in 6 scenes, with dialogue and a twist ending.',
    durationSeconds: 60,
    hashtags: ['#horrorstory', '#hindistory', '#haunted', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'love_story',
    name: 'Love Story',
    tagline: 'A soft romantic tale — perfect for evening posting.',
    styleId: 'romantic-pink',
    prompt:
        'Two strangers meet on the last metro of the night and keep meeting by chance. Write a sweet Hindi love story in 6 scenes, with dialogue.',
    durationSeconds: 60,
    hashtags: ['#lovestory', '#hindistory', '#romance', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'revenge_comeback',
    name: 'Revenge Comeback',
    tagline: 'Bullied today, legend tomorrow — the highest-retention format.',
    styleId: 'cinematic-dark',
    prompt:
        'A bullied student is called useless, then returns with a hidden power. Write a Hindi revenge-comeback story in 8 scenes, with dialogue and a big reveal.',
    durationSeconds: 90,
    hashtags: ['#revenge', '#hindistory', '#motivation', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'anime_premium',
    name: 'Anime Premium',
    tagline: 'Bold anime look for manhwa and manga stories.',
    styleId: 'anime-premium',
    prompt:
        'A weak hunter awakens a system that only he can see. Write a Hindi anime-style story in 8 scenes, with dialogue and power-up moments.',
    durationSeconds: 90,
    hashtags: ['#anime', '#manhwa', '#hindistory', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'cyber_hack',
    name: 'Cyber Hack',
    tagline: 'Neon hacker thriller — tech audience loves this one.',
    styleId: 'neon-cyberpunk',
    prompt:
        'A hacker gets a wedding-card APK that steals everything. Write a Hindi cyber-thriller in 6 scenes, with dialogue and a warning at the end.',
    durationSeconds: 60,
    hashtags: ['#cyber', '#hacker', '#techstory', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'motivation',
    name: 'Motivation',
    tagline: 'One line that changes the day — gold, cinematic, shareable.',
    styleId: 'motivational-gold',
    prompt:
        'A boy from a small town fails three times and still becomes the topper. Write a Hindi motivational story in 5 scenes, with dialogue.',
    durationSeconds: 45,
    hashtags: ['#motivation', '#hindistory', '#success', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'nature_tale',
    name: 'Nature Tale',
    tagline: 'Calm, green, slow — for stories that breathe.',
    styleId: 'nature-green',
    prompt:
        'A girl who talks to trees discovers the forest is in danger. Write a gentle Hindi nature story in 6 scenes, with dialogue.',
    durationSeconds: 60,
    hashtags: ['#nature', '#hindistory', '#story', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'royal_drama',
    name: 'Royal Drama',
    tagline: 'Palace intrigue, betrayal and a crown at stake.',
    styleId: 'royal-purple',
    prompt:
        'A forgotten prince returns to the palace on the night of the coronation. Write a Hindi royal drama in 8 scenes, with dialogue.',
    durationSeconds: 90,
    hashtags: ['#royal', '#drama', '#hindistory', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'retro_nostalgia',
    name: 'Retro Nostalgia',
    tagline: 'Old-school film look for 90s childhood stories.',
    styleId: 'retro-film',
    prompt:
        'Three friends reunite after 20 years at their old school. Write a nostalgic Hindi story in 6 scenes, with dialogue.',
    durationSeconds: 60,
    hashtags: ['#nostalgia', '#hindistory', '#90s', '#webkeyo'],
  ),
  ReelTemplate(
    id: 'minimal_quote',
    name: 'Minimal Quote',
    tagline: 'One powerful quote, clean and minimal — 15 seconds.',
    styleId: 'minimal-clean',
    prompt:
        'Write a 15-second Hindi motivational quote video script: one strong line, one scene, one voice.',
    durationSeconds: 15,
    hashtags: ['#quotes', '#motivation', '#shorts', '#webkeyo'],
  ),
];

/// Find a template by id, or null.
ReelTemplate? templateById(String id) {
  for (final t in reelTemplates) {
    if (t.id == id) return t;
  }
  return null;
}
