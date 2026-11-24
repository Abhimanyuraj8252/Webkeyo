/// Scene-by-scene video editing — pure logic, no UI, no FFmpeg.
///
/// The editor works on an ordered list of scenes (the same map shape
/// the script generator produces: 'speaker', 'emotion', 'narration',
/// 'est_seconds', optional 'imagePath'). Every edit re-derives the
/// timing from the scene list, so audio, scene and captions can never
/// drift apart:
///
///   rendered scene duration = est_seconds x [renderStretch] (1.3 — the
///   same factor the SRT/karaoke builders use, because Hindi audio
///   runs ~1.3x longer than the source text).
///
///   scene N starts at the sum of all previous scenes' rendered
///   durations; the SRT and karaoke .ass are rebuilt from the same
///   list, so a trim/reorder/timing change re-syncs everything at once.
///
/// Editing never touches files — [toScriptScenes] hands the edited list
/// back to [renderPromptVideo] as `scenesOverride` for a re-render.
library;

import 'subtitle_service.dart';

/// Rendered seconds per estimated second. Must match the factor in
/// [buildSrt]/[buildKaraokeAss] and the 1.3 stretch in the render.
const renderStretch = 1.3;

/// Transitions the engine can apply between scenes. 'cut' is the
/// current behaviour (hard cut via the concat demuxer); the others are
/// recorded on the scene and honoured by the render (cross-fade /
/// zoom / slide are applied as per-scene FFmpeg filters in a later
/// pass — the plan and timings are identical either way).
const sceneTransitions = <String>['cut', 'fade', 'zoom', 'slide'];

/// Shortest / longest a single scene may be trimmed to, in estimated
/// seconds (before the 1.3 stretch).
const minSceneSeconds = 2.0;
const maxSceneSeconds = 120.0;

/// One editable scene.
class EditableScene {
  /// 1-based position when the session was created (stable id).
  final int sceneNumber;
  final String speaker;
  final String emotion;

  /// Narration text (editable in the scene editor).
  String narration;

  /// Estimated narration seconds (before the 1.3 stretch).
  double estSeconds;

  /// Transition into this scene.
  String transition;

  /// PDF lecture page image for this scene, if any.
  final String? imagePath;

  EditableScene({
    required this.sceneNumber,
    required this.speaker,
    required this.emotion,
    required this.narration,
    required this.estSeconds,
    this.transition = 'cut',
    this.imagePath,
  });

  factory EditableScene.fromMap(Map<String, dynamic> scene, int number) {
    return EditableScene(
      sceneNumber: number,
      speaker: (scene['speaker'] ?? 'Narrator') as String,
      emotion: (scene['emotion'] ?? 'calm') as String,
      narration: ((scene['narration'] ?? scene['text'] ?? '') as String),
      estSeconds: (scene['est_seconds'] as num?)?.toDouble() ?? 6.0,
      transition: (scene['transition'] ?? 'cut') as String,
      imagePath: scene['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'speaker': speaker,
      'emotion': emotion,
      'narration': narration,
      'est_seconds': estSeconds,
      'transition': transition,
      if (imagePath != null) 'imagePath': imagePath,
    };
  }

  /// Rendered duration in seconds (what the viewer sees).
  double get renderedSeconds => estSeconds * renderStretch;
}

/// Start/end of one scene in the final video, in seconds.
class SceneTiming {
  final int index;
  final double startSeconds;
  final double endSeconds;
  const SceneTiming(this.index, this.startSeconds, this.endSeconds);
  double get durationSeconds => endSeconds - startSeconds;
}

/// An editing session over one video's scenes.
class VideoEditSession {
  final List<EditableScene> scenes;

  VideoEditSession(this.scenes);

  factory VideoEditSession.fromScriptScenes(
      List<Map<String, dynamic>> scriptScenes) {
    final list = <EditableScene>[];
    for (var i = 0; i < scriptScenes.length; i++) {
      list.add(EditableScene.fromMap(scriptScenes[i], i + 1));
    }
    return VideoEditSession(list);
  }

  /// The edited list, back in script-scene shape, for a re-render.
  List<Map<String, dynamic>> toScriptScenes() =>
      scenes.map((s) => s.toMap()).toList();

  /// Total rendered video length in seconds.
  double get totalSeconds =>
      scenes.fold<double>(0, (sum, s) => sum + s.renderedSeconds);

  /// Start/end of every scene, in current order. Audio offsets are
  /// these same starts — narration, scene and captions share them.
  List<SceneTiming> sceneTimings() {
    final timings = <SceneTiming>[];
    var cursor = 0.0;
    for (var i = 0; i < scenes.length; i++) {
      final end = cursor + scenes[i].renderedSeconds;
      timings.add(SceneTiming(i, cursor, end));
      cursor = end;
    }
    return timings;
  }

  /// Audio offset (seconds) of each scene's narration in the mix.
  List<double> audioOffsets() =>
      sceneTimings().map((t) => t.startSeconds).toList();

  /// SRT text for the current edit — rebuilt from the scenes, so it is
  /// always in sync with the audio and the picture.
  String buildSrtText() => buildSrt(toScriptScenes());

  /// Karaoke .ass text for the current edit.
  String buildKaraokeText() => buildKaraokeAss(toScriptScenes());

  void _checkIndex(int index) {
    if (index < 0 || index >= scenes.length) {
      throw ArgumentError(
          'Scene index $index out of range (0..${scenes.length - 1})');
    }
  }

  /// Trim a scene to [newEstSeconds] (estimated seconds, before the
  /// 1.3 stretch). Clamped to [minSceneSeconds]..[maxSceneSeconds].
  /// Returns the clamped value actually applied.
  double trimScene(int index, double newEstSeconds) {
    _checkIndex(index);
    final clamped = newEstSeconds.clamp(minSceneSeconds, maxSceneSeconds);
    scenes[index].estSeconds = clamped;
    return clamped;
  }

  /// Shift a scene's length by [deltaSeconds] (negative shortens it).
  double adjustSceneSeconds(int index, double deltaSeconds) {
    _checkIndex(index);
    return trimScene(index, scenes[index].estSeconds + deltaSeconds);
  }

  /// Move a scene from [oldIndex] to [newIndex]. Timings and captions
  /// are re-derived from the new order — nothing else to update.
  void moveScene(int oldIndex, int newIndex) {
    _checkIndex(oldIndex);
    if (newIndex < 0 || newIndex >= scenes.length) {
      throw ArgumentError(
          'Scene index $newIndex out of range (0..${scenes.length - 1})');
    }
    if (oldIndex == newIndex) return;
    final scene = scenes.removeAt(oldIndex);
    scenes.insert(newIndex, scene);
  }

  /// Change the transition into scene [index].
  /// Throws [ArgumentError] for an unknown transition id.
  void setTransition(int index, String transition) {
    _checkIndex(index);
    if (!sceneTransitions.contains(transition)) {
      throw ArgumentError(
          'Unknown transition "$transition" — use one of $sceneTransitions');
    }
    scenes[index].transition = transition;
  }
}
