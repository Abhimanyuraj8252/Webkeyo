/// Script / story skill — template-based script generator (no API key).
///
/// Rebuilt from `katha_studio/scriptgen.py` (same genres, beats,
/// cliffhangers, Claude prompt templates).
/// Verified 24 Nov 2026: `flutter analyze` clean, unit-tested (test/script_generator_test.dart).
///
/// Story structure this module teaches and uses:
///   * Hook in the first 2 seconds — scene 1 opens mid-action, with the
///     story's biggest question, never with background.
///   * 3-act beats: Setup (who + where + want) -> Conflict (obstacle,
///     stakes rise, a twist) -> Payoff (choice, consequence, cliffhanger).
///   * Cliffhanger ending — the last line asks a question the next video
///     answers, so viewers subscribe / watch the next part.
///   * Every scene has ONE speaker (Narrator or a character), ONE emotion,
///     and a line short enough to speak in 4-10 seconds.
///
/// Two paths:
///   * [generateScript] — FREE, local, template-based. No API key, no
///     cost. A solid first draft the user edits.
///   * Claude rewrite — the PREMIUM path: natural spoken Hindi,
///     character consistency, plot kept intact. The prompt templates in
///     [claudePromptTemplates] are exactly what the premium path sends.
library;

/// One genre's beats: (speaker, emotion, template line).
class GenreSpec {
  final String label;
  final String hero;
  final List<(String, String, String)> beats;
  final String cliffhanger;

  const GenreSpec({
    required this.label,
    required this.hero,
    required this.beats,
    required this.cliffhanger,
  });
}

const Map<String, GenreSpec> genres = {
  'haunted': GenreSpec(
    label: 'Haunted / Horror',
    hero: 'Arjun',
    beats: [
      ('Narrator', 'neutral', '{hero} reached the old {place} at midnight. Nobody had entered it for twenty years.'),
      ('Narrator', 'scared', 'Rain was falling hard, and the door opened by itself — slowly, without a sound.'),
      ('{hero}', 'scared', 'Kaun hai andar? Jawab do, main darrne wala nahi hoon!'),
      ('Narrator', 'dramatic', 'Then a cold whisper came from the dark — a voice that knew {hero}\'s name.'),
      ('{hero}', 'angry', 'Main tumse darrta nahi! Samne aao, jo bhi ho!'),
      ('Narrator', 'surprised', 'But the next morning, {hero} was gone — only his phone remained, still recording.'),
    ],
    cliffhanger: 'Phone me aakhri recording me kya tha? Agle part me dekhiye.',
  ),
  'love': GenreSpec(
    label: 'Love Story',
    hero: 'Arjun',
    beats: [
      ('Narrator', 'happy', '{hero} saw {other} for the first time at the {place}, and the world stopped for a second.'),
      ('{hero}', 'surprised', 'Tum... tum wahi ho na, jise main har roz dhoondhta tha?'),
      ('{other}', 'happy', 'Shayad. Par pehle batao, tumhe mera naam kaise pata?'),
      ('Narrator', 'sad', 'But fate had other plans — {other} was leaving the city in just three days.'),
      ('{hero}', 'dramatic', 'Teen din... bas teen din me main tumhe apni kahani ka hissa bana lunga.'),
      ('Narrator', 'happy', 'And on the third day, at the station, {hero} ran — with something in his hand.'),
    ],
    cliffhanger: 'Uske haath me kya tha? Kya {other} rukegi? Agle part me.',
  ),
  'action': GenreSpec(
    label: 'Action / Hero',
    hero: 'Arjun',
    beats: [
      ('Narrator', 'dramatic', 'The city was burning, and only one man stood between the people and the {villain}.'),
      ('{hero}', 'angry', 'Tumne mere sheher ko jalaya. Ab tumhari baari hai.'),
      ('Narrator', 'excited', '{hero} ran through the fire, sword in hand, as the {villain}\'s army closed in.'),
      ('{villain}', 'angry', 'Tum ek aadmi ho. Meri sena hazaaron ki hai!'),
      ('{hero}', 'excited', 'Ek aadmi hi kaafi hai — jab uske peeche poora sheher khada ho.'),
      ('Narrator', 'dramatic', 'The final blow was coming — and nobody in the city dared to blink.'),
    ],
    cliffhanger: 'Aakhri vaar kiska hoga? Agle part me dekhiye.',
  ),
  'sad': GenreSpec(
    label: 'Emotional / Sad',
    hero: 'Arjun',
    beats: [
      ('Narrator', 'sad', '{hero} stood alone in the rain. His best friend had left, and the city felt empty.'),
      ('{hero}', 'sad', 'Tumne kaha tha, hum hamesha saath rahenge. Phir tum chale kyun gaye?'),
      ('Narrator', 'calm', 'He opened the old letter — the one he had never dared to read.'),
      ('{other}', 'sad', 'Agar tum ye padh rahe ho, to samajh lo — main tumhare saath hi hoon, hamesha.'),
      ('{hero}', 'calm', 'To phir main akela kyun mehsoos kar raha hoon?'),
      ('Narrator', 'sad', 'And for the first time in years, {hero} smiled through his tears.'),
    ],
    cliffhanger: 'Us letter me aur kya likha tha? Agle part me.',
  ),
  'motivational': GenreSpec(
    label: 'Motivational',
    hero: 'Arjun',
    beats: [
      ('Narrator', 'sad', '{hero} failed ten times. Everyone laughed — even his own friends stopped calling.'),
      ('{hero}', 'angry', 'Hans lo, jitna hansna hai. Main rukne wala nahi hoon.'),
      ('Narrator', 'calm', 'Every morning at 5 AM, {hero} started again — same dream, same fire.'),
      ('{other}', 'surprised', 'Tum abhi bhi usi sapne ke peeche ho? Kab haar maanoge?'),
      ('{hero}', 'excited', 'Haar? Woh shabd meri dictionary me hai hi nahi.'),
      ('Narrator', 'happy', 'And on the eleventh try, the same people who laughed... stood up and clapped.'),
    ],
    cliffhanger: 'Gyaarahvi koshish me kya badla? Agle part me dekhiye.',
  ),
  'mystery': GenreSpec(
    label: 'Mystery / Thriller',
    hero: 'Arjun',
    beats: [
      ('Narrator', 'dramatic', 'At 3 AM, {hero} got a message from a number that did not exist.'),
      ('{hero}', 'surprised', 'Ye message kisne bheja? Mera phone to band tha!'),
      ('Narrator', 'scared', 'The message had only one line — and it knew everything about {hero}.'),
      ('{other}', 'whisper', 'Chup. Woh sun raha hai. Jo main keh rahi hoon, use dhyaan se suno.'),
      ('{hero}', 'scared', 'Kaun sun raha hai? Batao, kaun hai woh?'),
      ('Narrator', 'dramatic', 'Then the lights went out — and the real game began.'),
    ],
    cliffhanger: 'Message bhejne wala kaun tha? Agle part me.',
  ),
};

const String defaultGenre = 'haunted';

List<String> get genreIds => genres.keys.toList();

String _fill(String template, String hero, String other, String place, String villain) =>
    template
        .replaceAll('{hero}', hero)
        .replaceAll('{other}', other)
        .replaceAll('{place}', place)
        .replaceAll('{villain}', villain);

double _estSeconds(String text) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final seconds = words / 2.5;
  return seconds < 4.0 ? 4.0 : double.parse(seconds.toStringAsFixed(1));
}

/// Template-based scene-by-scene script from a one-line idea.
///
/// No API key, no cost. Returns a map with title / genre / idea /
/// scenes / cliffhanger. Each scene: scene_number, speaker, narration,
/// emotion, est_seconds. The idea is woven into scene 1 as the hook;
/// the user edits the draft — this is a first draft, not a finished story.
Map<String, dynamic> generateScript(String idea, String genre) {
  if (idea.trim().isEmpty) {
    throw ArgumentError("Give a one-line idea first, e.g. 'a boy enters a haunted inn'.");
  }
  final key = genre.trim().toLowerCase();
  final spec = genres[key];
  if (spec == null) {
    throw ArgumentError("Unknown genre '$genre'. Choose one of: ${genreIds.join(', ')}");
  }
  const places = {
    'haunted': 'haunted inn',
    'love': 'old railway station',
    'action': 'burning city',
    'sad': 'empty railway platform',
    'motivational': 'small rented room',
    'mystery': 'dark apartment',
  };
  const villains = {
    'action': 'demon king',
    'haunted': 'shadow',
    'mystery': 'stranger',
    'love': 'fate',
    'sad': 'time',
    'motivational': 'doubt',
  };
  const hero = 'Arjun';
  const other = 'Titli';
  final place = places[key] ?? 'old house';
  final villain = villains[key] ?? 'enemy';

  final scenes = <Map<String, dynamic>>[];
  // Scene 1 hook: the idea itself, spoken as the opening line.
  final hook = '${idea.trim().replaceAll(RegExp(r'[.!?]+$'), '')}.';
  scenes.add({
    'scene_number': 1,
    'speaker': 'Narrator',
    'narration': hook,
    'emotion': 'dramatic',
    'est_seconds': _estSeconds(hook),
  });
  var number = 2;
  for (final (speaker, emotion, template) in spec.beats) {
    final text = _fill(template, hero, other, place, villain);
    scenes.add({
      'scene_number': number++,
      'speaker': speaker
          .replaceAll('{hero}', hero)
          .replaceAll('{other}', other)
          .replaceAll('{villain}', 'Villain'),
      'narration': text,
      'emotion': emotion,
      'est_seconds': _estSeconds(text),
    });
  }
  final cliffhanger = _fill(spec.cliffhanger, hero, other, place, villain);
  scenes.add({
    'scene_number': number,
    'speaker': 'Narrator',
    'narration': cliffhanger,
    'emotion': 'dramatic',
    'est_seconds': 5.0,
  });

  final titleWords = RegExp(r'[A-Za-z]+')
      .allMatches(idea.trim())
      .map((m) => m.group(0)!)
      .take(6)
      .toList();
  final title = titleWords.isEmpty
      ? 'Untitled Story'
      : titleWords.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  return {
    'title': title,
    'genre': key,
    'genre_label': spec.label,
    'idea': idea.trim(),
    'scenes': scenes,
    'cliffhanger': cliffhanger,
    'note': 'Template draft — free, local, no AI call. Edit the lines, '
        'then use the Claude rewrite for natural spoken Hindi.',
  };
}

/// Script scaled to a requested duration — the unlimited-duration path.
///
/// [generateScript] always returns the 8-scene base story (~1 minute).
/// This one repeats the story arc in chapters until the video covers
/// [targetSeconds]: the hook first, then the genre beats cycled, one
/// bridge line after each full beat cycle, and a chapter-heading scene
/// every ~12 scenes, with the cliffhanger always last.
///
/// Every generated scene is timed to [sceneSeconds] of rendered video
/// (est_seconds = sceneSeconds / 1.3, since the render stretches by
/// 1.3x), so the finished video lands on the requested duration.
/// Returns the same map shape as [generateScript], plus
/// 'target_seconds', 'chapters' and 'scene_seconds'.
///
/// Honest limit: a one-line prompt cannot invent hours of *new* story.
/// Long videos retell the arc in chapters — the plan card on the
/// prompt-video screen says so. For a genuinely new 2-hour story the
/// user pastes a longer prompt (or uses the Claude rewrite path).
Map<String, dynamic> generateScriptForDuration(
  String idea,
  String genre,
  double targetSeconds, {
  double sceneSeconds = 8.0,
  String tone = 'dramatic',
}) {
  final base = generateScript(idea, genre);
  final baseScenes = base['scenes'] as List<Map<String, dynamic>>;
  final baseTotal = baseScenes.fold<double>(
    0,
    (sum, s) => sum + ((s['est_seconds'] as num?)?.toDouble() ?? 6.0) * 1.3,
  );
  // Short request — the base story already covers it. No padding.
  if (targetSeconds <= baseTotal) {
    return {
      ...base,
      'target_seconds': targetSeconds,
      'chapters': 1,
      'scene_seconds': sceneSeconds,
    };
  }

  final key = genre.trim().toLowerCase();
  final spec = genres[key]!;
  const places = {
    'haunted': 'haunted inn',
    'love': 'old railway station',
    'action': 'burning city',
    'sad': 'empty railway platform',
    'motivational': 'small rented room',
    'mystery': 'dark apartment',
  };
  const villains = {
    'action': 'demon king',
    'haunted': 'shadow',
    'mystery': 'stranger',
    'love': 'fate',
    'sad': 'time',
    'motivational': 'doubt',
  };
  const hero = 'Arjun';
  const other = 'Titli';
  final place = places[key] ?? 'old house';
  final villain = villains[key] ?? 'enemy';

  // Bridge lines between chapters — narrator, calm, genre-agnostic.
  const bridges = [
    'Aur phir, kahani ne ek naya mod liya.',
    'Lekin ye to bas shuruaat thi — asli kahani abhi baaki thi.',
    'Raat abhi baaki thi, aur kahani bhi.',
    'Tabhi, kuch aisa hua jiski kisi ko ummeed nahi thi.',
    'Aur phir, sab kuch badal gaya.',
  ];

  // How many scenes the video needs (each renders sceneSeconds long).
  final needed = (targetSeconds / sceneSeconds).ceil().clamp(8, 1 << 20);
  final est = sceneSeconds / 1.3;

  Map<String, dynamic> scene(
    int number,
    String speaker,
    String narration,
    String emotion,
  ) =>
      {
        'scene_number': number,
        'speaker': speaker,
        'narration': narration,
        'emotion': emotion,
        // Full precision on purpose: est is sceneSeconds / 1.3, and the
        // render stretches it back by 1.3x. Rounding to 1 decimal here
        // (6.2 instead of 6.1538) made every scene 0.06s too long — a
        // 2-hour video overshot by 54 seconds.
        'est_seconds': est,
      };

  final scenes = <Map<String, dynamic>>[];
  // Scene 1 — the hook, always the user's idea.
  scenes.add(scene(1, 'Narrator',
      '${idea.trim().replaceAll(RegExp(r'[.!?]+$'), '')}.', 'dramatic'));
  var number = 2;
  var chapter = 1;
  var beatIndex = 0;
  var bridgeIndex = 0;
  // Fill up to needed - 1 scenes; the last one is always the cliffhanger.
  while (scenes.length < needed - 1) {
    // Chapter heading every 12 scenes (never right after the hook).
    if (scenes.length > 1 && scenes.length % 12 == 0) {
      chapter++;
      scenes.add(scene(number++, 'Narrator',
          'Chapter $chapter — kahani aage badhti hai.', tone));
      continue;
    }
    final (speaker, emotion, template) =
        spec.beats[beatIndex % spec.beats.length];
    final text = _fill(template, hero, other, place, villain);
    scenes.add(scene(
      number++,
      speaker
          .replaceAll('{hero}', hero)
          .replaceAll('{other}', other)
          .replaceAll('{villain}', 'Villain'),
      text,
      emotion,
    ));
    beatIndex++;
    // One bridge line after each full beat cycle.
    if (beatIndex % spec.beats.length == 0 && scenes.length < needed - 1) {
      scenes.add(scene(number++, 'Narrator',
          bridges[bridgeIndex % bridges.length], 'calm'));
      bridgeIndex++;
    }
  }
  final cliffhanger = _fill(spec.cliffhanger, hero, other, place, villain);
  scenes.add(scene(number, 'Narrator', cliffhanger, 'dramatic'));

  return {
    ...base,
    'scenes': scenes,
    'target_seconds': targetSeconds,
    'chapters': chapter,
    'scene_seconds': sceneSeconds,
  };
}

/// Claude prompt templates — the premium path, documented so the user can
/// also paste them into Claude directly. Same instructions the Claude
/// rewrite sends.
const Map<String, String> claudePromptTemplates = {
  'story_structure':
      'Write the story in 3 acts. Act 1 (Setup): hero, place, want — in 2 scenes. '
      'Act 2 (Conflict): obstacle, stakes rise, one twist — in 3-4 scenes. '
      'Act 3 (Payoff): the hero makes a choice, consequence, cliffhanger ending — '
      'the last line must ask a question the next video answers.',
  'hook_rule':
      'Scene 1 must hook in the first 2 seconds: open mid-action with the story\'s '
      'biggest question. Never open with background, weather, or \'once upon a time\'.',
  'hindi_dubbing':
      'Rewrite each scene in natural, spoken Hindi (Hinglish where people really '
      'speak it), not literal translation. One voice per character, consistent '
      'across all scenes. Keep names and plot facts identical to the source. '
      'Mark the emotion of each line in brackets, e.g. [angry], [sad], [excited]. '
      'Narrator lines explain the scene where there is no dialogue.',
  'dialogue_style':
      'Dialogue must sound like people talking, not like a book: short sentences, '
      'interruptions, questions. Each dialogue line must fit in 4-10 spoken seconds.',
};
