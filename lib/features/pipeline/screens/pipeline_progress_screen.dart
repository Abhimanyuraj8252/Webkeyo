import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';
import '../../../models/project_model.dart';
import '../../../models/ai_provider_model.dart';
import '../../../services/api_service.dart';
import '../../../services/conversion_service.dart';
import '../../../services/ffmpeg_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/provider_registry.dart';
import '../../../services/tts_service.dart';
import '../../project/screens/project_context_screen.dart';
import 'script_editor_screen.dart';
import 'video_preview_screen.dart';

class PipelineProgressScreen extends StatefulWidget {
  final String projectId;

  /// 1 = extract, 2 = script, 4 = audio, 5 = render
  final int startPhase;

  const PipelineProgressScreen({
    super.key,
    required this.projectId,
    this.startPhase = 1,
  });

  @override
  State<PipelineProgressScreen> createState() => _PipelineProgressScreenState();
}

class _PipelineProgressScreenState extends State<PipelineProgressScreen> {
  int _currentPhase = 1;
  String _statusMessage = 'Initializing...';
  bool _hasError = false;

  final List<String> _phases = [
    'Extracting Images',
    'AI Analyzing & Writing Script',
    'Waiting for User Script Approval',
    'Generating Audio',
    'Rendering Final Video',
  ];

  @override
  void initState() {
    super.initState();
    _currentPhase = widget.startPhase;
    _runPipeline();
  }

  Future<void> _runPipeline() async {
    List<Map<String, dynamic>>? finalSyncData;

    try {
      final registry = Provider.of<ProviderRegistry>(context, listen: false);
      final project = registry.projectsBox.get(widget.projectId);
      if (project == null || project.sourceFilePath == null) {
        throw Exception('Project or source file missing.');
      }

      await NotificationService.instance.show(
        'Webkeyo Pipeline',
        'Started: ${project.title} (phase $_currentPhase)',
      );

      // ── Phase 1: Extracting Images ────────────────────────────────
      if (_currentPhase == 1) {
        setState(() => _statusMessage = 'Extracting images from source file...');
        project.status = 'extracting';
        await project.save();

        final ext = project.sourceFilePath!.toLowerCase();
        final tempDir = await getTemporaryDirectory();
        final extractPath = p.join(tempDir.path, 'webkeyo_pipeline_${widget.projectId}');

        List<String> images = [];
        if (ext.endsWith('.cbz') || ext.endsWith('.zip')) {
          images = await ConversionService.cbzToImages(project.sourceFilePath!, extractPath);
        } else if (ext.endsWith('.pdf')) {
          images = await ConversionService.pdfToImages(project.sourceFilePath!, extractPath);
        } else {
          final dir = Directory(project.sourceFilePath!);
          if (await dir.exists()) {
            final entities = dir.listSync();
            const allowedExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
            images = entities
                .where((e) => e is File && allowedExts.contains(p.extension(e.path).toLowerCase()))
                .map((e) => e.path)
                .toList();
          } else {
            images = [project.sourceFilePath!];
          }
        }

        images.sort((a, b) => a.compareTo(b));
        project.extractedImagePaths = images;
        await project.save();

        if (images.isEmpty) throw Exception('No images extracted from source file.');

        if (!mounted) return;
        setState(() => _currentPhase = 2);
      }

      // ── Phase 2: AI Scripting ─────────────────────────────────────
      if (_currentPhase == 2) {
        // Connectivity guard — the vision API needs internet.
        final ConnectivityResult connectivity = await Connectivity().checkConnectivity();
        if (connectivity == ConnectivityResult.none) {
          throw Exception('No internet connection. Connect to WiFi/mobile data and retry.');
        }

        setState(() => _statusMessage = 'Sending images to Vision AI...');
        project.status = 'scripting';
        await project.save();

        // Use the provider/model stored in the project (set from HomeScreen)
        String apiKey = project.visionApiKey ?? '';
        String baseUrl = project.visionBaseUrl ?? '';
        String modelId = project.visionModelId ?? '';

        // Fallback: if project doesn't have provider info, find first
        // enabled vision provider.
        if (apiKey.isEmpty || baseUrl.isEmpty || modelId.isEmpty) {
          final visionProviders = registry.providers
              .where((pr) => pr.category == ProviderCategory.vision && pr.isEnabled)
              .toList();
          if (visionProviders.isEmpty) {
            throw Exception(
              'No Vision API Provider configured. Please go to Settings → AI Providers and enable one.',
            );
          }
          apiKey = visionProviders.first.apiKey ?? '';
          baseUrl = visionProviders.first.customBaseUrl ?? '';
          final models = registry.getModelsByProvider(visionProviders.first.id);
          modelId = models.isNotEmpty ? models.first.id : '';

          if (apiKey.isEmpty) {
            throw Exception(
              "Vision provider '${visionProviders.first.name}' has no API key set.",
            );
          }
        }

        final apiService = ApiService();
        final rawJson = await apiService.generateScript(
          imagePaths: project.extractedImagePaths,
          isUncensored: project.isNsfw,
          language: project.language,
          apiKey: apiKey,
          baseUrl: baseUrl,
          modelId: modelId,
          customPrompt: '',
          charactersContext: project.charactersContext,
          generationMode: project.generationMode,
        );

        project.generatedScript = rawJson;
        project.status = 'script_ready';
        await project.save();

        if (!mounted) return;
        setState(() => _currentPhase = 3);
      }

      // ── Phase 3: Wait for Script Approval ─────────────────────────
      if (_currentPhase == 3) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ScriptEditorScreen(projectId: widget.projectId),
            ),
          );
        }
        return;
      }

      // ── Phase 4: Audio Generation ─────────────────────────────────
      if (_currentPhase == 4) {
        setState(() => _statusMessage = 'Generating Audio via TTS...');
        project.status = 'audio';
        await project.save();

        final String rawJson = project.generatedScript ?? '';
        Map<String, dynamic> scriptData;
        try {
          scriptData = jsonDecode(rawJson);
        } catch (e) {
          throw Exception('Invalid script JSON. Please edit and fix the script format.');
        }
        final List<dynamic> scenes = scriptData['scenes'] ?? [];

        if (scenes.isEmpty) {
          throw Exception('Script has no scenes. Please regenerate or edit the script.');
        }

        final tempDir = await getTemporaryDirectory();
        final audioDir = p.join(tempDir.path, 'webkeyo_audio_${widget.projectId}');

        final ttsService = TtsService(
          providerId: project.ttsProviderId ?? 'flutter_tts',
          apiKey: project.ttsApiKey,
          baseUrl: project.ttsBaseUrl,
          modelId: project.ttsModelId,
          voice: project.ttsVoice,
        );

        final syncData = await ttsService.generateAudioForScenes(
          scenesJson: scenes,
          saveDirectoryPath: audioDir,
          language: project.language,
          // On retry, reuse scenes that already have audio on disk.
          reuseExisting: true,
          onProgress: (sceneNum) {
            if (mounted) {
              setState(() => _statusMessage = 'Generating Audio: Scene $sceneNum / ${scenes.length}...');
            }
          },
        );

        finalSyncData = _mapScenesToImages(project, scenes, syncData);

        if (finalSyncData!.isEmpty) {
          throw Exception(
            'No valid scene-to-image mappings found. Check the script\'s image_index values.',
          );
        }

        if (!mounted) return;
        setState(() => _currentPhase = 5);
      }

      // ── Phase 5: Video Rendering ──────────────────────────────────
      if (_currentPhase == 5) {
        setState(() => _statusMessage = 'FFmpeg: Rendering cinematic video...');
        project.status = 'rendering';
        await project.save();

        // If we resumed straight into rendering (e.g. after an app kill),
        // rebuild the scene→image mapping from the audio files on disk.
        if (finalSyncData == null || finalSyncData!.isEmpty) {
          final String rawJson = project.generatedScript ?? '';
          Map<String, dynamic> scriptData;
          try {
            scriptData = jsonDecode(rawJson);
          } catch (e) {
            throw Exception('Invalid script JSON. Please go back and fix the script.');
          }
          final List<dynamic> scenes = scriptData['scenes'] ?? [];
          finalSyncData = await _buildSyncDataFromDisk(project, scenes);
        }

        if (finalSyncData!.isEmpty) {
          throw Exception(
            'No audio found for the script. Generate audio first (Audio tab).',
          );
        }

        final tempDir = await getTemporaryDirectory();
        final ffmpegService = FfmpegService();

        // Export path priority: project override → global Settings value →
        // default public Movies/Webkeyo (inside FfmpegService).
        String? exportPath = project.customExportPath;
        if (exportPath == null || exportPath.isEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            exportPath = prefs.getString('global_export_path');
          } catch (_) {}
        }

        final String? videoPath = await ffmpegService.renderFinalVideo(
          syncData: finalSyncData!,
          outputDirectory: tempDir.path,
          projectName: widget.projectId,
          resolution: project.videoResolution,
          exportPath: exportPath,
          bgmPath: project.bgmPath,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _statusMessage = 'Rendering Video: ${(progress * 100).toStringAsFixed(1)}%...');
            }
          },
        );

        if (videoPath != null) {
          project.finalVideoPath = videoPath;
          project.status = 'done';
          await project.save();
          await NotificationService.instance.show(
            'Webkeyo Pipeline',
            'Video ready: ${project.title}',
          );
          if (mounted) {
            setState(() {
              _currentPhase = 6; // past the last phase = all complete
              _statusMessage = 'Video Generated Successfully!';
            });
          }
        } else {
          throw Exception('FFmpeg Rendering Failed.');
        }
      }
    } catch (e) {
      await NotificationService.instance.show(
        'Webkeyo Pipeline',
        'Pipeline failed: $e',
      );
      if (mounted) {
        // Update project status to error
        try {
          final registry = Provider.of<ProviderRegistry>(context, listen: false);
          final project = registry.projectsBox.get(widget.projectId);
          if (project != null) {
            project.status = 'error';
            await project.save();
          }
        } catch (_) {}

        setState(() {
          _statusMessage = 'Error: $e';
          _hasError = true;
        });
      }
    }
  }

  /// All images the video can reference: extracted pages first, then any
  /// cropped "extra scenes" from the Image Editor (appended, so the script's
  /// image_index values remain valid).
  List<String> _allImages(ProjectModel project) {
    final List<String> all = List<String>.from(project.extractedImagePaths);
    for (final edited in project.editedImagePaths) {
      if (!all.contains(edited)) all.add(edited);
    }
    return all;
  }

  /// Maps TTS output (scene_number + audio) back to real image paths,
  /// honoring per-scene image overrides set in the Image Editor.
  List<Map<String, dynamic>> _mapScenesToImages(
    ProjectModel project,
    List<dynamic> scenes,
    List<Map<String, dynamic>> syncData,
  ) {
    final List<String> allImages = _allImages(project);
    final List<Map<String, dynamic>> finalSyncData = [];
    for (var scene in syncData) {
      final dynamic numRaw = scene['scene_number'];
      if (numRaw is! num) continue;
      final int sceneNum = numRaw.toInt();
      Map<String, dynamic>? matchingScene;
      for (var s in scenes) {
        if (s is Map && s['scene_number'] == sceneNum) {
          matchingScene = s;
          break;
        }
      }

      int imageIndex = 0;
      if (matchingScene != null) {
        if (matchingScene['image_index'] is num) {
          imageIndex = (matchingScene['image_index'] as num).toInt();
        }
        final override = project.sceneImageOverrides[sceneNum];
        if (override != null) imageIndex = override;
      }

      if (imageIndex >= 0 && imageIndex < allImages.length) {
        finalSyncData.add({
          'image_path': allImages[imageIndex],
          'audio_path': scene['audio_path'],
          'duration_in_seconds': scene['duration_in_seconds'],
        });
      }
    }
    return finalSyncData;
  }

  /// Rebuilds the scene→image mapping straight from the audio files that
  /// TTS already produced (used when resuming the render after a crash).
  Future<List<Map<String, dynamic>>> _buildSyncDataFromDisk(
    ProjectModel project,
    List<dynamic> scenes,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final audioDir = p.join(tempDir.path, 'webkeyo_audio_${widget.projectId}');
    final player = AudioPlayer();
    final result = <Map<String, dynamic>>[];
    final List<String> allImages = _allImages(project);

    try {
      for (var s in scenes) {
        if (s is! Map) continue;
        final dynamic numRaw = s['scene_number'];
        if (numRaw is! num) continue;
        final int sceneNum = numRaw.toInt();

        final File audioFile = File(p.join(audioDir, 'scene_$sceneNum.wav'));
        if (!await audioFile.exists()) continue;

        double duration = 0;
        try {
          final Duration? d = await player.setFilePath(audioFile.path);
          if (d != null) duration = d.inMilliseconds / 1000.0;
        } catch (_) {}
        if (duration <= 0) continue;

        int imageIndex = 0;
        if (s['image_index'] is num) imageIndex = (s['image_index'] as num).toInt();
        final override = project.sceneImageOverrides[sceneNum];
        if (override != null) imageIndex = override;

        if (imageIndex >= 0 && imageIndex < allImages.length) {
          result.add({
            'image_path': allImages[imageIndex],
            'audio_path': audioFile.path,
            'duration_in_seconds': duration,
          });
        }
      }
    } finally {
      await player.dispose();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Task Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _hasError || _statusMessage == 'Video Generated Successfully!'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectContextScreen(projectId: widget.projectId),
                ),
              );
            },
            icon: const Icon(Icons.dashboard_rounded, size: 18),
            label: const Text('View Project'),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            Text(
              _hasError ? 'Pipeline Error' : 'Pipeline Active',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _hasError ? Colors.redAccent : colorScheme.onSurface,
              ),
            ).animate().fadeIn().slideY(begin: -0.2),
            const SizedBox(height: AppConstants.paddingSmall),
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: _hasError
                    ? Colors.redAccent.withAlpha(20)
                    : colorScheme.primaryContainer.withAlpha(40),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _hasError ? Colors.redAccent : colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: AppConstants.paddingXLarge),
            Expanded(
              child: ListView.builder(
                itemCount: _phases.length,
                itemBuilder: (context, index) {
                  final isCompleted = index + 1 < _currentPhase;
                  final isActive = index + 1 == _currentPhase;

                  return _buildPhaseTile(
                    context,
                    title: _phases[index],
                    isCompleted: isCompleted,
                    isActive: isActive,
                  ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.1);
                },
              ),
            ),
            // Action buttons
            if (_hasError)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _statusMessage = 'Retrying...';
                      });
                      // Retry from the phase that was running.
                      _runPipeline();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.paddingLarge,
                        horizontal: AppConstants.paddingXLarge,
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  TextButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('Return to Home'),
                  ),
                ],
              ).animate().scale(delay: 200.ms),
            if (_statusMessage == 'Video Generated Successfully!') ...[
              ElevatedButton.icon(
                onPressed: () {
                  final registry = Provider.of<ProviderRegistry>(context, listen: false);
                  final project = registry.projectsBox.get(widget.projectId);
                  if (project?.finalVideoPath != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPreviewScreen(
                          videoPath: project!.finalVideoPath!,
                          projectName: project.title,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingLarge,
                    horizontal: AppConstants.paddingXLarge,
                  ),
                ),
                icon: const Icon(Icons.play_circle_rounded),
                label: Text('Preview Video', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ).animate().scale(delay: 100.ms),
              const SizedBox(height: AppConstants.paddingMedium),
              ElevatedButton.icon(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingLarge,
                    horizontal: AppConstants.paddingXLarge,
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: Text('Return to Home', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ).animate().scale(delay: 200.ms),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseTile(BuildContext context,
      {required String title, required bool isCompleted, required bool isActive}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color iconColor = colorScheme.outline.withAlpha(76);
    IconData icon = Icons.circle_outlined;

    if (isCompleted) {
      iconColor = Colors.greenAccent;
      icon = Icons.check_circle_rounded;
    } else if (isActive) {
      iconColor = _hasError ? Colors.redAccent : colorScheme.primary;
      icon = _hasError ? Icons.error_rounded : Icons.motion_photos_on_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primaryContainer.withAlpha(40) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isActive ? colorScheme.primary.withAlpha(100) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: AppConstants.paddingLarge),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withAlpha(150),
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (isActive && !_hasError)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
