import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../models/project_model.dart';
import '../../../services/api_service.dart';
import '../../../services/provider_registry.dart';
import 'pipeline_progress_screen.dart';
import 'script_library_screen.dart';

class ScriptEditorScreen extends StatefulWidget {
  final String projectId;

  const ScriptEditorScreen({super.key, required this.projectId});

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  late TextEditingController _scriptController;
  ProjectModel? _project;

  bool _showScenes = false;
  String? _validationError;
  Timer? _validateTimer;

  AudioPlayer? _scenePlayer;
  bool _scenePlayerWired = false;
  int _playingScene = -1;

  @override
  void initState() {
    super.initState();
    _scriptController = TextEditingController();
    _loadProject();
  }

  void _loadProject() {
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    _project = registry.projectsBox.get(widget.projectId);
    if (_project != null && _project!.generatedScript != null) {
      _scriptController.text = _project!.generatedScript!;
    }
    _validateScript();
  }

  /// Parses the script JSON and reports a friendly error (or null when the
  /// script is usable).
  String? validateScriptJson(String text) {
    if (text.trim().isEmpty) return 'Script is empty.';
    Map<String, dynamic> data;
    try {
      data = jsonDecode(text);
    } catch (e) {
      return 'Not valid JSON: ${e.toString().split('\n').first}';
    }
    final dynamic scenes = data['scenes'];
    if (scenes is! List || scenes.isEmpty) {
      return 'JSON must contain a non-empty "scenes" array.';
    }
    for (final scene in scenes) {
      if (scene is! Map) {
        return 'Every scene must be a JSON object.';
      }
      if (scene['scene_number'] is! num) {
        return 'A scene is missing a numeric "scene_number".';
      }
      if (scene['narration'] is! String || (scene['narration'] as String).trim().isEmpty) {
        return 'Scene ${scene['scene_number']} has an empty "narration".';
      }
      if (scene['image_index'] is! num) {
        return 'Scene ${scene['scene_number']} is missing a numeric "image_index".';
      }
    }
    return null;
  }

  void _onScriptChanged() {
    _validateTimer?.cancel();
    _validateTimer = Timer(const Duration(milliseconds: 400), _validateScript);
  }

  void _validateScript() {
    if (!mounted) return;
    final error = validateScriptJson(_scriptController.text);
    if (error != _validationError) {
      setState(() => _validationError = error);
    }
  }

  Future<void> _saveScript({bool silent = false}) async {
    if (_project != null) {
      _project!.generatedScript = _scriptController.text;
      await _project!.save();
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Script saved successfully!')),
        );
      }
    }
  }

  Future<void> _proceedToAudioGeneration() async {
    // Hard validation gate before spending TTS/FFmpeg effort.
    final error = validateScriptJson(_scriptController.text);
    if (error != null) {
      if (mounted) {
        setState(() => _validationError = error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fix the script first: $error')),
        );
      }
      return;
    }
    await _saveScript();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PipelineProgressScreen(projectId: widget.projectId, startPhase: 4),
        ),
      );
    }
  }

  Future<void> _toggleSceneAudio(int sceneNumber) async {
    if (_playingScene == sceneNumber) {
      _scenePlayer?.stop();
      setState(() => _playingScene = -1);
      return;
    }

    final project = _project!;
    final tempDir = await getTemporaryDirectory();
    final audioDir = p.join(tempDir.path, 'webkeyo_audio_${project.id}');
    final file = File(p.join(audioDir, 'scene_$sceneNumber.wav'));
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio for this scene yet — generate audio first.')),
        );
      }
      return;
    }

    _scenePlayer ??= AudioPlayer();
    if (!_scenePlayerWired) {
      _scenePlayerWired = true;
      _scenePlayer!.processingStateStream.listen((state) {
        if (state == ProcessingState.completed && mounted) {
          setState(() => _playingScene = -1);
        }
      });
    }
    await _scenePlayer!.stop();
    await _scenePlayer!.setFilePath(file.path);
    await _scenePlayer!.play();
    if (mounted) setState(() => _playingScene = sceneNumber);
  }

  Future<void> _polishWithAI() async {
    final project = _project;
    if (project == null) return;

    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    final providerId = project.textProviderId;
    final provider = providerId != null
        ? registry.providers.where((p) => p.id == providerId).firstOrNull
        : null;
    if (provider == null || !provider.isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a text model first (Script Model chip on the home screen, or the project\'s Script tab).'),
          ),
        );
      }
      return;
    }
    final apiKey = provider.apiKey ?? '';
    final baseUrl = provider.customBaseUrl ?? '';
    if (apiKey.isEmpty || baseUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Provider "${provider.name}" has no API key/base URL. Configure it in Settings → AI Providers.')),
        );
      }
      return;
    }
    if (project.textModelId == null || project.textModelId!.isEmpty) {
      final models = registry.getModelsByProvider(provider.id);
      if (models.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No models fetched for ${provider.name}. Fetch models in Settings → AI Providers.')),
          );
        }
        return;
      }
      project.textModelId = models.first.id;
      await project.save();
    }

    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final feedback = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Polish Script with AI'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. make the narration more dramatic, shorter, funnier...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Polish'),
          ),
        ],
      ),
    );
    if (feedback == null || !mounted) return;

    try {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Polishing script with AI...')),
      );
      final polished = await ApiService().polishScript(
        currentScript: _scriptController.text,
        language: project.language,
        apiKey: apiKey,
        baseUrl: baseUrl,
        modelId: project.textModelId!,
        feedback: feedback.isEmpty ? 'Make it more engaging and natural' : feedback,
      );
      if (!mounted) return;
      _scriptController.text = polished;
      _validateScript();
      await _saveScript(silent: true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Script polished & saved.')),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Polish failed: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _parseScenes() {
    try {
      final dynamic data = jsonDecode(_scriptController.text);
      if (data is Map && data['scenes'] is List) {
        return (data['scenes'] as List).whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  void dispose() {
    _validateTimer?.cancel();
    _scriptController.dispose();
    _scenePlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_project == null) {
      return const Scaffold(body: Center(child: Text('Project not found')));
    }

    final scenes = _showScenes ? _parseScenes() : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Refine Script', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showScenes ? Icons.subject_rounded : Icons.view_list_rounded),
            tooltip: _showScenes ? 'Show raw JSON' : 'Show scenes',
            onPressed: () => setState(() => _showScenes = !_showScenes),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded),
            tooltip: 'Polish with AI',
            onPressed: _polishWithAI,
          ),
          IconButton(
            icon: const Icon(Icons.library_books_rounded),
            tooltip: 'Script Library',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScriptLibraryScreen(currentProjectId: widget.projectId),
                ),
              ).then((_) => _loadProject());
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save Script',
            onPressed: _saveScript,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(76),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: colorScheme.primary.withAlpha(51)),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: colorScheme.primary),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(
                    child: Text(
                      'Edit the AI script below. You can add emotion tags (e.g. [happy]) and override a scene\'s image with "image_override": <index>.',
                      style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1),
            const SizedBox(height: AppConstants.paddingSmall),
            if (_validationError != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMedium, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  border: Border.all(color: Colors.amber.withAlpha(120)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),
            const SizedBox(height: AppConstants.paddingSmall),
            Expanded(
              child: _showScenes
                  ? _buildSceneList(context, colorScheme, scenes)
                  : Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withAlpha(51),
                        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                        border: Border.all(color: colorScheme.outline.withAlpha(25)),
                      ),
                      child: TextField(
                        controller: _scriptController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.6,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste or write your script here...',
                          hintStyle: TextStyle(color: colorScheme.onSurface.withAlpha(76)),
                          contentPadding: const EdgeInsets.all(AppConstants.paddingLarge),
                          border: InputBorder.none,
                        ),
                        onChanged: _onScriptChanged,
                      ),
                    ).animate().fadeIn(delay: 100.ms),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            ElevatedButton.icon(
              onPressed: _proceedToAudioGeneration,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingLarge),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
              ),
              icon: const Icon(Icons.mic_rounded),
              label: Text(
                'Generate Audio',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneList(
      BuildContext context, ColorScheme cs, List<Map<String, dynamic>> scenes) {
    final project = _project!;

    if (scenes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No valid scenes found in the script JSON.\nSwitch to raw view to fix the format.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withAlpha(180), fontSize: 13),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(4),
      itemCount: scenes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final scene = scenes[i];
        final int sceneNum = (scene['scene_number'] as num?).toInt() ?? i + 1;
        final String narration = (scene['narration'] ?? '').toString();
        final String description = (scene['description'] ?? '').toString();

        int imageIndex = 0;
        if (scene['image_index'] is num) {
          imageIndex = (scene['image_index'] as num).toInt();
        }
        final override = project.sceneImageOverrides[sceneNum];
        if (override != null) imageIndex = override;
        final String? imagePath =
            (imageIndex >= 0 && imageIndex < project.extractedImagePaths.length)
                ? project.extractedImagePaths[imageIndex]
                : null;
        final File? imgFile =
            (imagePath != null && File(imagePath).existsSync()) ? File(imagePath) : null;

        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withAlpha(51),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: _playingScene == sceneNum
                  ? cs.primary.withAlpha(150)
                  : cs.outline.withAlpha(25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 96,
                    child: imgFile != null
                        ? Image.file(imgFile, fit: BoxFit.cover)
                        : Container(
                            color: cs.surface,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 24),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scene $sceneNum',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: cs.onSurface.withAlpha(140))),
                      ],
                      const SizedBox(height: 6),
                      Text(narration,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Play scene audio',
                  icon: Icon(
                    _playingScene == sceneNum
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 30,
                    color: _playingScene == sceneNum ? cs.primary : null,
                  ),
                  onPressed: () => _toggleSceneAudio(sceneNum),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
