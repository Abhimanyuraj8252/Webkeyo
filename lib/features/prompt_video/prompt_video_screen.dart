/// Prompt-to-video screen — one line in, reel/video out, ₹0.
///
/// Renders on the phone with the code-drawn motion-graphics engine
/// (PromptVideoService): 10 styles, hook title, burned English
/// subtitles, speaker/emotion chip, progress bar, narration + SFX.
/// The voiceover uses the TTS provider set in Settings (AI Providers >
/// TTS). No key set yet? Edge TTS is free and built in.
///
/// v1.2.2: no duration limit (presets + custom minutes, no cap), style
/// picker with code-drawn previews, purpose picker, character-design
/// picker, PDF lecture import (pages -> scenes, in sync), and a
/// scene-by-scene editor. Long renders are chunked with progress,
/// per-step timeouts and a Cancel button — they never freeze the app.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/ai_provider_model.dart';
import '../../models/video_style.dart';
import '../../services/engagement_service.dart';
import '../../services/pdf_lecture.dart';
import '../../services/pdf_text_extractor.dart';
import '../../services/prompt_video_service.dart';
import '../../services/provider_credentials.dart';
import '../../services/provider_registry.dart';
import '../../services/script_generator.dart';
import '../../services/share_service.dart';
import '../../services/tts_service.dart';
import '../../services/video_duration.dart';
import '../../services/video_purpose.dart';
import 'scene_editor_screen.dart';

/// Builds one style preview on a background isolate (for [compute]).
Uint8List _previewEntry(Map<String, String> args) => buildStylePreviewBytes(
      styleId: args['styleId'] ?? 'anime-premium',
      characterDesign: args['characterDesign'] ?? 'anime',
    );

class PromptVideoScreen extends StatefulWidget {
  final String? initialPrompt;
  final String? initialGenre;
  final String? initialStyle;
  final double? initialDurationSeconds;

  const PromptVideoScreen({
    super.key,
    this.initialPrompt,
    this.initialGenre,
    this.initialStyle,
    this.initialDurationSeconds,
  });

  @override
  State<PromptVideoScreen> createState() => _PromptVideoScreenState();
}

class _PromptVideoScreenState extends State<PromptVideoScreen> {
  late final TextEditingController _promptController;
  late final TextEditingController _customMinutesController;
  String _genre = defaultGenre;
  String _style = 'cinematic-dark';
  String _purpose = 'story';
  String _character = 'anime';
  bool _vertical = true;
  bool _karaoke = false;
  bool _busy = false;
  bool _pdfBusy = false;
  String _progressLabel = '';
  double _progress = 0;
  PromptVideoResult? _result;
  String? _error;
  bool _cancelRequested = false;

  /// Duration preset in minutes; null when a custom value is typed.
  double? _presetMinutes = 2.0;

  /// Code-drawn style previews, keyed "$styleId|$characterDesign".
  final Map<String, Uint8List> _previews = {};

  /// The current render plan (recomputed only when the inputs change,
  /// never on progress ticks).
  VideoDurationPlan? _plan;

  /// A PDF lecture, when one was imported.
  PdfLecturePlan? _pdfPlan;

  /// Scenes edited in the scene editor (or null when unedited).
  List<Map<String, dynamic>>? _editedScenes;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.initialPrompt ?? '');
    _customMinutesController = TextEditingController();
    if (widget.initialGenre != null && genres.containsKey(widget.initialGenre)) {
      _genre = widget.initialGenre!;
    }
    if (widget.initialStyle != null) {
      try {
        getVideoStyle(widget.initialStyle!);
        _style = widget.initialStyle!;
      } catch (_) {
        // Unknown style id — keep the default.
      }
    }
    if (widget.initialDurationSeconds != null &&
        widget.initialDurationSeconds! > 0) {
      final minutes = widget.initialDurationSeconds! / 60;
      if (durationPresetsMinutes.contains(minutes.round()) &&
          (minutes - minutes.round()).abs() < 0.01) {
        _presetMinutes = minutes.roundToDouble();
      } else {
        _presetMinutes = null;
        _customMinutesController.text = minutes.toStringAsFixed(1);
      }
    }
    _karaoke = purposeConfig(_purpose).karaokeDefault;
    _recomputePlan();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreviews());
  }

  @override
  void dispose() {
    _promptController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  /// Requested length in seconds, or null when neither a preset nor a
  /// valid custom value is set. No upper cap — 180 minutes plans 180.
  double? _targetSeconds() {
    final custom = parseDurationMinutes(_customMinutesController.text);
    if (custom != null) return custom * 60;
    if (_presetMinutes != null) return _presetMinutes! * 60;
    return null;
  }

  void _recomputePlan() {
    if (_pdfPlan != null || _editedScenes != null) {
      _plan = null;
      return;
    }
    final target = _targetSeconds();
    if (target == null) {
      _plan = null;
      return;
    }
    final prompt = _promptController.text.trim();
    try {
      _plan = planPromptVideo(
        idea: prompt.isEmpty ? 'a story' : prompt,
        genre: _genre,
        targetSeconds: target,
        purposeId: _purpose,
        characterDesign: _character,
        styleId: _style,
      );
    } catch (_) {
      _plan = null;
    }
  }

  /// Generate the code-drawn previews progressively: first the current
  /// style in every character design (for the character picker), then
  /// every style in the current character. A failed preview just leaves
  /// the shimmer — never a crash.
  Future<void> _loadPreviews() async {
    final jobs = <(String, String)>[];
    for (final character in characterDesignIds) {
      jobs.add((_style, character));
    }
    for (final id in styleIds) {
      if (id != _style) jobs.add((id, _character));
    }
    for (final (styleId, character) in jobs) {
      if (!mounted) return;
      final key = '$styleId|$character';
      if (_previews.containsKey(key)) continue;
      try {
        final bytes = await compute(_previewEntry, {
          'styleId': styleId,
          'characterDesign': character,
        });
        if (!mounted) return;
        setState(() => _previews[key] = bytes);
      } catch (_) {}
    }
  }

  void _onPurposeChanged(String id) {
    setState(() {
      _purpose = id;
      // The purpose's caption default; the user can still toggle it.
      _karaoke = purposeConfig(id).karaokeDefault;
      _recomputePlan();
    });
  }

  void _onCharacterChanged(String id) {
    setState(() => _character = id);
    _recomputePlan();
    _loadPreviews();
  }

  Future<void> _importPdf() async {
    setState(() {
      _pdfBusy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.single.path == null) {
        if (mounted) setState(() => _pdfBusy = false);
        return;
      }
      final pdfPath = result.files.single.path!;
      final title = p.basenameWithoutExtension(pdfPath);
      final bytes = await File(pdfPath).readAsBytes();
      // Page text (best effort — empty for image-only pages) and page
      // images, both aligned with the page order.
      final texts = extractPdfPageTexts(bytes);
      final docs = await getApplicationDocumentsDirectory();
      final outDir =
          '${docs.path}/pdf_lectures/${DateTime.now().millisecondsSinceEpoch}';
      final images =
          await extractPdfPageImages(pdfPath: pdfPath, outDir: outDir);
      if (images.isEmpty) {
        throw Exception('Could not read any page from this PDF.');
      }
      final pageTexts = List<String>.generate(
          images.length, (i) => i < texts.length ? texts[i] : '');
      final plan = planPdfLecture(
        title: title,
        pageCount: images.length,
        pageTexts: pageTexts,
        pageImagePaths: images,
      );
      if (!mounted) return;
      setState(() {
        _pdfPlan = plan;
        _editedScenes = null;
        _pdfBusy = false;
        _plan = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'PDF ready: ${plan.pageCount} pages → ${plan.scenes.length} scenes, ${formatDuration(plan.totalSeconds)}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'PDF import failed: $e';
        _pdfBusy = false;
      });
    }
  }

  /// Scenes for the editor: the edited list, the PDF scenes, or the
  /// planned script for the current picks.
  List<Map<String, dynamic>>? _editorScenes() {
    if (_editedScenes != null) return _editedScenes;
    if (_pdfPlan != null) return _pdfPlan!.toScriptScenes();
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return null;
    final target = _targetSeconds();
    if (target != null && target > 4 * 3600) return null; // too many to edit
    final purpose = purposeConfig(_purpose);
    if (target != null) {
      final script = generateScriptForDuration(prompt, _genre, target,
          sceneSeconds: purpose.sceneSeconds, tone: purpose.tone);
      return script['scenes'] as List<Map<String, dynamic>>;
    }
    final script = generateScript(prompt, _genre);
    return script['scenes'] as List<Map<String, dynamic>>;
  }

  Future<void> _openEditor() async {
    final scenes = _editorScenes();
    if (scenes == null || scenes.isEmpty) {
      setState(() => _error =
          'Write an idea first (or import a PDF) — then edit its scenes. '
          'Videos over 4 hours cannot be edited scene by scene.');
      return;
    }
    final title = _pdfPlan?.title ?? _promptController.text.trim();
    final edited = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) => SceneEditorScreen(scenes: scenes, title: title),
      ),
    );
    if (edited != null && mounted) {
      setState(() => _editedScenes = edited);
    }
  }

  Future<void> _render() async {
    final prompt = _pdfPlan?.title ?? _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error =
          'Write a one-line idea first, e.g. "a boy enters a haunted inn".');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _progress = 0;
      _progressLabel = 'Starting…';
      _cancelRequested = false;
    });
    try {
      // Voiceover provider: the onboarding pick first (if enabled),
      // then the first enabled TTS provider, else Edge TTS (free, no
      // key). Keys come only from Settings — never hardcoded.
      final registry = context.read<ProviderRegistry>();
      final ttsProviders =
          registry.getProvidersByCategory(ProviderCategory.tts);
      AIProviderModel? provider;
      final storedDefault = await DefaultTtsProvider.load();
      if (storedDefault != null) {
        provider = ttsProviders
            .where((p) => p.id == storedDefault && p.isEnabled)
            .firstOrNull;
      }
      provider ??= ttsProviders.where((p) => p.isEnabled).firstOrNull;
      provider ??= ttsProviders.where((p) => p.id == 'edge_tts').firstOrNull;
      provider ??= ttsProviders.firstOrNull;
      final tts = TtsService(
        providerId: provider?.id ?? 'edge_tts',
        apiKey: provider?.apiKey,
        baseUrl: provider?.customBaseUrl,
      );

      final docs = await getApplicationDocumentsDirectory();
      final outDir =
          '${docs.path}/prompt_videos/${DateTime.now().millisecondsSinceEpoch}';
      await Directory(outDir).create(recursive: true);

      final scenesOverride = _editedScenes ?? _pdfPlan?.toScriptScenes();
      final result = await renderPromptVideo(
        prompt: prompt,
        genre: _genre,
        styleId: _style,
        outDir: outDir,
        tts: tts,
        vertical: _vertical,
        karaoke: _karaoke,
        targetDurationSeconds:
            scenesOverride == null ? _targetSeconds() : null,
        purposeId: _purpose,
        characterDesign: _character,
        scenesOverride: scenesOverride,
        isCancelled: () => _cancelRequested,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progressLabel = progress.stage;
              _progress = progress.fraction;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
      // A finished export counts toward the streak / XP (+100). Never
      // let the counter break the render flow.
      try {
        final engagement = EngagementService();
        await engagement.init();
        final unlocked = await engagement.recordExport();
        if (mounted && unlocked.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Achievement unlocked: ${unlocked.join(', ')} 🎉')),
          );
        }
      } catch (_) {}
    } on RenderCancelled {
      if (!mounted) return;
      setState(() {
        _error = 'Render cancelled — nothing was saved.';
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purpose = purposeConfig(_purpose);
    return Scaffold(
      appBar: AppBar(title: const Text('Prompt to Video')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One line in, reel out — ₹0. Code-drawn motion graphics, '
                'no stock video, no paid API. Any duration, any purpose.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Your idea (one line)',
                  hintText: 'a boy enters a haunted inn where the waiter is not human',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pdfBusy ? null : _importPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(_pdfBusy ? 'Reading PDF…' : 'Import PDF lecture'),
                    ),
                  ),
                  if (_pdfPlan != null) ...[
                    const SizedBox(width: AppConstants.paddingMedium),
                    IconButton(
                      tooltip: 'Remove PDF',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _pdfPlan = null;
                        _editedScenes = null;
                        _recomputePlan();
                      }),
                    ),
                  ],
                ],
              ),
              if (_pdfPlan != null) ...[
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  'PDF: ${_pdfPlan!.title} — ${_pdfPlan!.pageCount} pages → '
                  '${_pdfPlan!.scenes.length} scenes, ${formatDuration(_pdfPlan!.totalSeconds)}. '
                  'Each page gets its own scene and narration, in sync. '
                  'Pages without a readable image fall back to a code-drawn scene.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppConstants.paddingMedium),
              _dropdown(
                label: 'Genre',
                value: _genre,
                items: genreIds,
                labelOf: (id) => genres[id]!.label,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _genre = v;
                    _recomputePlan();
                  });
                },
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Text('Style — see exactly how it will look',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: styleIds.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppConstants.paddingSmall),
                  itemBuilder: (context, index) {
                    final id = styleIds[index];
                    final selected = id == _style;
                    final preview = _previews['$id|$_character'];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _style = id);
                        _recomputePlan();
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 104,
                            height: 156,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMedium),
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                width: selected ? 3 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: preview != null
                                ? Image.memory(preview, fit: BoxFit.cover)
                                : Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(getVideoStyle(id).label,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Text('Purpose — what is this video for?',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: purposeIds
                    .map((id) => ChoiceChip(
                          label: Text(purposeConfig(id).label),
                          selected: id == _purpose,
                          onSelected: (_) => _onPurposeChanged(id),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Text(
                '${purpose.tagline} Best for: ${purpose.bestFor}. '
                'Pacing: ${purpose.sceneSeconds.toStringAsFixed(0)}s per scene, '
                'tone: ${purpose.tone}.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Text('Character design — code-drawn, anime-like',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              Row(
                children: characterDesignIds.map((id) {
                  final selected = id == _character;
                  final preview = _previews['$_style|$id'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _onCharacterChanged(id),
                        child: Column(
                          children: [
                            Container(
                              height: 96,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMedium),
                                border: Border.all(
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: preview != null
                                  ? Image.memory(preview, fit: BoxFit.cover)
                                  : Container(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      child: Center(
                                          child: Text(
                                              characterDesignLabels[id] ?? id,
                                              textAlign: TextAlign.center,
                                              style:
                                                  theme.textTheme.bodySmall)),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(characterDesignLabels[id] ?? id,
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Text('Duration — no limit',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...durationPresetsMinutes.map((minutes) {
                    final label = minutes >= 60
                        ? '${minutes ~/ 60} hr'
                        : '$minutes min';
                    return ChoiceChip(
                      label: Text(label),
                      selected: _presetMinutes == minutes.toDouble() &&
                          _customMinutesController.text.trim().isEmpty,
                      onSelected: (_) {
                        setState(() {
                          _presetMinutes = minutes.toDouble();
                          _customMinutesController.clear();
                          _recomputePlan();
                        });
                      },
                    );
                  }),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _customMinutesController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Custom (min)',
                        hintText: 'e.g. 90 or 2h',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {
                          _presetMinutes = null;
                          _recomputePlan();
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_plan != null) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                _buildPlanCard(theme, _plan!),
              ],
              if (_editedScenes != null) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                Text(
                  'Edited scenes: ${_editedScenes!.length} scenes, '
                  '${formatDuration(_editedScenes!.fold<double>(0, (s, sc) => s + ((sc['est_seconds'] as num?)?.toDouble() ?? 6.0) * 1.3))}. '
                  'The render will use your edited scenes.',
                  style: theme.textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _editedScenes = null;
                    _recomputePlan();
                  }),
                  child: const Text('Discard edits'),
                ),
              ],
              const SizedBox(height: AppConstants.paddingMedium),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Vertical 9:16'), icon: Icon(Icons.phone_android)),
                        ButtonSegment(value: false, label: Text('Horizontal 16:9'), icon: Icon(Icons.tv)),
                      ],
                      selected: {_vertical},
                      onSelectionChanged: (s) => setState(() => _vertical = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              SwitchListTile(
                title: const Text('Karaoke captions'),
                subtitle: const Text(
                    'Word-by-word highlight captions (.ass) next to the video — burn them in with FFmpeg for Reels/Shorts.'),
                value: _karaoke,
                onChanged: (v) => setState(() => _karaoke = v),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _openEditor,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Edit scenes — trim, reorder, retime'),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _render,
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: Text(_busy ? 'Rendering…' : 'Render video'),
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                LinearProgressIndicator(value: _progress.clamp(0.0, 1.0)),
                const SizedBox(height: 8),
                Text(_progressLabel, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _cancelRequested = true),
                  icon: const Icon(Icons.stop),
                  label: const Text('Cancel render'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                Text(_error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _render,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
              if (_result != null) _buildResult(theme),
              const SizedBox(height: AppConstants.paddingMedium),
              Text(
                'Voiceover uses the TTS provider set in Settings (AI Providers > TTS). '
                'No key set yet? Edge TTS is free and built in. '
                'Free tiers (official pricing pages, 24 Nov 2026): Google Cloud WaveNet 4M chars/month, '
                'Amazon Polly 5M/month (first 12 months), Speechify 500K/month, '
                'Azure SwaraNeural 0.5M/month with real emotion styles, '
                'Deepgram Flux \$200 free credit with Hindi voices.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(ThemeData theme, VideoDurationPlan plan) {
    final lines = <String>[
      'Planned: ${formatDuration(plan.totalSeconds)} • ${plan.sceneCount} scenes • ${plan.chapters} chapter${plan.chapters == 1 ? '' : 's'}',
      'Estimated render time: ~${plan.estRenderMinutes.toStringAsFixed(0)} min (rough — TTS + frames + mux)',
      'Narration: ~${plan.estTtsChars} characters • size ~${plan.estOutputMb.toStringAsFixed(0)} MB',
      if (plan.sfxLooped)
        'SFX: a 2-minute bed looped under the whole video (saves ~${((plan.totalSeconds - 120) * 0.176).toStringAsFixed(0)} MB of audio)',
      if (!plan.exact)
        'Estimates for very long videos are arithmetic — the render still covers the full duration.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Render plan', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l, style: theme.textTheme.bodySmall),
                )),
            if (plan.estRenderMinutes > 20)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Long render — keep the app open and the phone awake. You can cancel any time.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) labelOf,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),
      items: items
          .map((id) => DropdownMenuItem(value: id, child: Text(labelOf(id))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildResult(ThemeData theme) {
    final videoPath = _result!.videoPath;
    final thumbnailPath = _result!.thumbnailPath;
    final srtPath = _result!.srtPath;
    final title = _pdfPlan?.title ?? _promptController.text.trim();
    final duration = _result!.durationSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.paddingLarge),
        Text('Done — your video is ready', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppConstants.paddingSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          child: Image.file(File(thumbnailPath)),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        Text(title, style: theme.textTheme.titleSmall),
        Text(
          '${_result!.sceneCount} scenes • ${_result!.chapters} chapter${_result!.chapters == 1 ? '' : 's'} • ${duration.toStringAsFixed(1)}s',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        _pathRow(theme, 'Video', videoPath),
        _pathRow(theme, 'Subtitles', srtPath),
        if (_result!.karaokePath != null)
          _pathRow(theme, 'Karaoke', _result!.karaokePath!),
        const SizedBox(height: AppConstants.paddingMedium),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await ShareService.shareVideo(
                    videoPath: videoPath,
                    title: title,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Caption + hashtags copied — paste them in YouTube / Instagram.'
                          : 'Video file not found.'),
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share video'),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: videoPath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video path copied')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy path'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pathRow(ThemeData theme, String label, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(path, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
