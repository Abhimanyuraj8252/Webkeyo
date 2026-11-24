/// Unlimited-duration planning for prompt-to-video.
///
/// The user picks any duration — a 1-minute reel, a 30-minute lecture,
/// a 2-hour story — and the plan scales with it: scene count, chapters,
/// narration characters, render time and output size. There is NO upper
/// cap on the duration: if the user types 180 minutes, the plan covers
/// 180 minutes.
///
/// Pure functions — no Flutter dependency, unit-tested. Nothing here
/// renders anything; the render itself lives in prompt_video_service.dart
/// and follows the same plan.
library;

import 'script_generator.dart';
import 'video_purpose.dart';

/// Duration presets on the picker, in minutes.
const List<int> durationPresetsMinutes = [1, 2, 5, 10, 15, 30, 60, 120];

/// Parse a duration the user typed, in minutes.
///
/// Accepts plain minutes ("90", "90.5", " 30 "), minutes with an "m"
/// suffix ("90m") and hours ("2h", "1.5h"). Returns null for empty,
/// non-numeric, zero or negative input. There is NO upper cap — 1000
/// minutes parses to 1000.0.
double? parseDurationMinutes(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;
  var numberText = text;
  var multiplier = 1.0;
  if (text.endsWith('h')) {
    numberText = text.substring(0, text.length - 1).trim();
    multiplier = 60.0;
  } else if (text.endsWith('m')) {
    numberText = text.substring(0, text.length - 1).trim();
  }
  final value = double.tryParse(numberText);
  if (value == null || !value.isFinite || value <= 0) return null;
  return value * multiplier;
}

/// Human-readable duration: "45 sec", "2 min", "1 min 30 sec",
/// "1 hr", "2 hr 5 min".
String formatDuration(double seconds) {
  if (!seconds.isFinite || seconds <= 0) return '0 sec';
  final total = seconds.round();
  if (total < 60) return '$total sec';
  final minutes = total ~/ 60;
  final secs = total % 60;
  if (minutes < 60) {
    return secs == 0 ? '$minutes min' : '$minutes min $secs sec';
  }
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (mins == 0) return '$hours hr';
  return '$hours hr $mins min';
}

/// One render plan, built from the user's picks before rendering starts.
/// The prompt-video screen shows this card so the user sees the planned
/// duration, scene count and an honest render-time estimate up front.
class VideoDurationPlan {
  /// Requested length, seconds.
  final double targetSeconds;

  /// Length the script actually covers, seconds (exact when [exact]).
  final double totalSeconds;

  /// Scenes the render will produce.
  final int sceneCount;

  /// Chapters (chapter-heading scenes + 1).
  final int chapters;

  /// Rendered seconds per scene (the purpose's pacing).
  final double sceneSeconds;

  /// Rough render time, minutes — TTS ~2s/scene + frame render
  /// ~2.5s/scene + ~1 min fixed. A rough estimate, not a promise.
  final double estRenderMinutes;

  /// Narration characters the TTS providers will speak (drives the
  /// free-tier cost: ~800 chars/min of audio).
  final int estTtsChars;

  /// Rough final file size, MB (~0.3 MB per second at 720p/12fps).
  final double estOutputMb;

  /// True when the SFX bed is a short loop repeated under the whole
  /// video instead of one giant file (durations over 2 minutes).
  final bool sfxLooped;

  /// True when the counts come from the real generated script; false
  /// when they are arithmetic estimates (durations over 4 hours).
  final bool exact;

  final String purposeId;
  final String characterDesign;
  final String styleId;

  const VideoDurationPlan({
    required this.targetSeconds,
    required this.totalSeconds,
    required this.sceneCount,
    required this.chapters,
    required this.sceneSeconds,
    required this.estRenderMinutes,
    required this.estTtsChars,
    required this.estOutputMb,
    required this.sfxLooped,
    required this.exact,
    required this.purposeId,
    required this.characterDesign,
    required this.styleId,
  });
}

/// Build the plan for a render. Cheap for normal durations (the real
/// script is generated, so counts are exact); for durations over 4
/// hours the counts are arithmetic estimates so planning never has to
/// build a giant scene list just to show a preview.
VideoDurationPlan planPromptVideo({
  required String idea,
  required String genre,
  required double targetSeconds,
  String purposeId = 'story',
  String characterDesign = 'anime',
  String styleId = 'cinematic-dark',
}) {
  final purpose = purposeConfig(purposeId);
  final sceneSeconds = purpose.sceneSeconds;

  int sceneCount;
  int chapters;
  double totalSeconds;
  int estTtsChars;
  var exact = true;

  if (targetSeconds <= 4 * 3600) {
    final script = generateScriptForDuration(
      idea,
      genre,
      targetSeconds,
      sceneSeconds: sceneSeconds,
      tone: purpose.tone,
    );
    final scenes = script['scenes'] as List<Map<String, dynamic>>;
    sceneCount = scenes.length;
    chapters = script['chapters'] as int? ?? 1;
    totalSeconds = scenes.fold<double>(
      0,
      (sum, s) => sum + ((s['est_seconds'] as num?)?.toDouble() ?? 6.0) * 1.3,
    );
    estTtsChars = scenes.fold<int>(
      0,
      (sum, s) => sum + ((s['narration'] ?? '') as String).length,
    );
  } else {
    // Arithmetic estimate — no giant list, just the same shape the
    // generator would produce: content scenes + one bridge per beat
    // cycle (6 beats) + one chapter heading per ~12 scenes.
    exact = false;
    final content = (targetSeconds / sceneSeconds).ceil();
    final bridges = (content / 6).ceil();
    final chapterHeadings = ((content + bridges) / 12).floor();
    sceneCount = content + bridges + chapterHeadings + 2;
    chapters = chapterHeadings + 1;
    totalSeconds = sceneCount * sceneSeconds;
    estTtsChars = sceneCount * 110;
  }

  final estRenderMinutes =
      ((sceneCount * 4.5 + 60) / 60).clamp(1.0, double.infinity);
  return VideoDurationPlan(
    targetSeconds: targetSeconds,
    totalSeconds: totalSeconds,
    sceneCount: sceneCount,
    chapters: chapters,
    sceneSeconds: sceneSeconds,
    estRenderMinutes: estRenderMinutes,
    estTtsChars: estTtsChars,
    estOutputMb: totalSeconds * 0.3,
    // The requested length decides the loop, not the float total: a
    // 2-minute video gets one 120s bed; anything longer loops it.
    sfxLooped: targetSeconds > 120,
    exact: exact,
    purposeId: purpose.id,
    characterDesign: characterDesign,
    styleId: styleId,
  );
}
