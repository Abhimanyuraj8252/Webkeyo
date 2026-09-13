import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/constants.dart';
import '../../../models/project_model.dart';
import '../../../models/ai_provider_model.dart';
import 'package:webkeyo/services/api_service.dart';
import 'package:webkeyo/services/face_detection_service.dart';
import 'package:webkeyo/services/provider_registry.dart';
import 'package:webkeyo/services/srt_service.dart';
import 'package:webkeyo/services/tts_service.dart' show mapTtsLanguage, edgeVoicesForLocale;
import 'package:webkeyo/features/home/model_selector_sheet.dart';
import 'package:webkeyo/features/pipeline/screens/pipeline_progress_screen.dart';
import '../../../features/pipeline/screens/script_editor_screen.dart';
import '../../../features/pipeline/screens/video_preview_screen.dart';
import 'character_assignment_screen.dart';
import 'image_editor_screen.dart';

class ProjectContextScreen extends StatefulWidget {
  final String projectId;
  const ProjectContextScreen({super.key, required this.projectId});

  @override
  State<ProjectContextScreen> createState() => _ProjectContextScreenState();
}

class _ProjectContextScreenState extends State<ProjectContextScreen>
    with SingleTickerProviderStateMixin {
  ProjectModel? _project;
  late TabController _tabController;
  final TextEditingController _ttsApiKeyController = TextEditingController();
  final TextEditingController _ttsBaseUrlController = TextEditingController();
  final TextEditingController _ttsVoiceIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProject();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ttsApiKeyController.dispose();
    _ttsBaseUrlController.dispose();
    _ttsVoiceIdController.dispose();
    super.dispose();
  }

  void _loadProject() {
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    setState(() {
      _project = registry.projectsBox.get(widget.projectId);
      if (_project != null) {
        _ttsApiKeyController.text = _project!.ttsApiKey ?? '';
        _ttsBaseUrlController.text = _project!.ttsBaseUrl ?? '';
        _ttsVoiceIdController.text =
            (_project!.ttsProviderId == 'elevenlabs') ? (_project!.ttsModelId ?? '') : '';
      }
    });
  }

  Future<void> _saveProject() async {
    await _project?.save();
    if (mounted) setState(() {});
  }

  // ── Navigate to full pipeline (all phases from start) ──────────────
  void _startFullPipeline() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PipelineProgressScreen(
          projectId: widget.projectId,
          startPhase: 1,
        ),
      ),
    ).then((_) => _loadProject());
  }

  // ── Navigate to only Script generation (phase 2) ───────────────────
  void _generateScript() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PipelineProgressScreen(
          projectId: widget.projectId,
          startPhase: 2,
        ),
      ),
    ).then((_) => _loadProject());
  }

  // ── Open Script editor ─────────────────────────────────────────────
  void _openScriptEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScriptEditorScreen(projectId: widget.projectId),
      ),
    ).then((_) => _loadProject());
  }

  // ── Generate Audio only (phase 4) ─────────────────────────────────
  void _generateAudio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PipelineProgressScreen(
          projectId: widget.projectId,
          startPhase: 4,
        ),
      ),
    ).then((_) => _loadProject());
  }

  // ── Render Video only (phase 5) ────────────────────────────────────
  void _renderVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PipelineProgressScreen(
          projectId: widget.projectId,
          startPhase: 5,
        ),
      ),
    ).then((_) => _loadProject());
  }

  // ── Preview existing video ─────────────────────────────────────────
  void _previewVideo() {
    if (_project?.finalVideoPath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPreviewScreen(
          videoPath: _project!.finalVideoPath!,
          projectName: _project!.title,
          projectId: widget.projectId,
        ),
      ),
    );
  }

  // ── Open Image Editor ──────────────────────────────────────────────
  void _openImageEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(projectId: widget.projectId),
      ),
    ).then((_) => _loadProject());
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Resolves the project's vision provider (with registry fallback).
  ({String key, String base, String model})? _resolveVision(
    ProviderRegistry registry,
    ProjectModel project,
  ) {
    String key = project.visionApiKey ?? '';
    String base = project.visionBaseUrl ?? '';
    String model = project.visionModelId ?? '';
    if (key.isEmpty || base.isEmpty || model.isEmpty) {
      final visionProviders = registry.providers
          .where((pr) => pr.category == ProviderCategory.vision && pr.isEnabled)
          .toList();
      if (visionProviders.isEmpty) return null;
      key = visionProviders.first.apiKey ?? '';
      base = visionProviders.first.customBaseUrl ?? '';
      final models = registry.getModelsByProvider(visionProviders.first.id);
      model = models.isNotEmpty ? models.first.id : '';
    }
    if (key.isEmpty || base.isEmpty || model.isEmpty) return null;
    return (key: key, base: base, model: model);
  }

  // ── Auto-detect characters with Vision AI ──────────────────────────
  Future<void> _detectCharactersWithAI() async {
    final project = _project;
    if (project == null) return;
    if (project.extractedImagePaths.isEmpty) {
      _snack('Extract images first (run the pipeline or Re-extract).');
      return;
    }

    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    final vision = _resolveVision(registry, project);
    if (vision == null) {
      _snack('No vision provider configured. Set one up in Settings → AI Providers.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
          const SnackBar(content: Text('Detecting characters with AI...')));
      final result = await ApiService().autoDetectCharacters(
        imagePaths: project.extractedImagePaths,
        apiKey: vision.key,
        baseUrl: vision.base,
        modelId: vision.model,
      );
      if (!mounted) return;

      final controller = TextEditingController(text: result);
      final useIt = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Detected Characters'),
          content: SizedBox(
            height: 300,
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              maxLines: null,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Detected characters...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add to Context'),
            ),
          ],
        ),
      );
      if (useIt == true && controller.text.trim().isNotEmpty) {
        project.charactersContext =
            (project.charactersContext != null && project.charactersContext!.trim().isNotEmpty)
                ? '${project.charactersContext!}\n${controller.text.trim()}'
                : controller.text.trim();
        await project.save();
        _loadProject();
        messenger.showSnackBar(
            const SnackBar(content: Text('Characters added to project context.')));
      }
    } catch (e) {
      _snack('Detection failed: $e');
    }
  }

  // ── On-device face detection + manual assignment ───────────────────
  Future<void> _detectFacesAndAssign() async {
    final project = _project;
    if (project == null) return;
    if (project.extractedImagePaths.isEmpty) {
      _snack('Extract images first (run the pipeline or Re-extract).');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
          const SnackBar(content: Text('Detecting faces with on-device ML...')));
      final faces =
          await FaceDetectionService.extractFacesFromImages(project.extractedImagePaths);
      if (!mounted) return;
      if (faces.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('No faces detected in the pages.')));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CharacterAssignmentScreen(project: project, faceImagePaths: faces),
        ),
      );
      _loadProject();
    } catch (e) {
      _snack('Face detection failed: $e');
    }
  }

  // ── Export subtitles (SRT) ─────────────────────────────────────────
  Future<void> _exportSrt() async {
    final project = _project;
    if (project == null) return;
    if (project.generatedScript == null || project.generatedScript!.isEmpty) {
      _snack('Generate a script first.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Building SRT subtitles...')));
      final tempDir = await getTemporaryDirectory();
      final audioDir = p.join(tempDir.path, 'webkeyo_audio_${project.id}');
      final srtPath = await SrtService.generateSrt(
        projectId: project.id,
        audioDir: audioDir,
        scriptJson: project.generatedScript,
        outputDir: tempDir.path,
      );
      if (srtPath == null) {
        _snack('Could not build SRT — scene audio missing. Generate audio first.');
        return;
      }
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save subtitles (SRT)',
        fileName: '${project.title}_subtitles.srt',
        initialDirectory: (await getExternalStorageDirectory())?.path,
        type: FileType.custom,
        allowedExtensions: ['srt'],
      );
      if (result != null) {
        await File(result).writeAsBytes(await File(srtPath).readAsBytes());
        _snack('SRT saved to $result');
      }
    } catch (e) {
      _snack('SRT export failed: $e');
    }
  }

  // ── Background music picker ────────────────────────────────────────
  Future<void> _pickBgm() async {
    final project = _project;
    if (project == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'flac'],
    );
    if (result != null && result.files.single.path != null) {
      project.bgmPath = result.files.single.path;
      await project.save();
      _loadProject();
      _snack('Background music set: ${result.files.single.name}');
    }
  }

  Future<void> _clearBgm() async {
    final project = _project;
    if (project == null) return;
    project.bgmPath = null;
    await project.save();
    _loadProject();
    _snack('Background music removed.');
  }

  // ── TTS voice picker (Edge TTS) ────────────────────────────────────
  Future<void> _pickTtsVoice() async {
    final project = _project;
    if (project == null) return;
    if (project.ttsProviderId != 'edge_tts') {
      _snack('Voice picker is available for Microsoft Edge TTS.');
      return;
    }
    final voices = edgeVoicesForLocale(mapTtsLanguage(project.language));
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Voice'),
        children: ['Auto (language default)', ...voices]
            .map((v) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, v),
                  child: Text(v, style: GoogleFonts.inter(fontSize: 13)),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    project.ttsVoice = (selected == 'Auto (language default)') ? null : selected;
    await project.save();
    _loadProject();
  }

  // ── Change export path ─────────────────────────────────────────────
  Future<void> _changeExportPath() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Export Folder',
    );
    if (path != null && mounted) {
      _project?.customExportPath = path;
      await _saveProject();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export path set to: $path')),
        );
      }
    }
  }

  // ── Dynamic Provider Selection ─────────────────────────────────────
  Future<void> _changeProjectModel(ProviderCategory category) async {
    final selected = await ModelSelectorSheet.show(context, category);
    if (selected != null && _project != null) {
      final registry = Provider.of<ProviderRegistry>(context, listen: false);
      final provider =
          registry.providers.where((p) => p.id == selected.providerId).firstOrNull;

      setState(() {
        if (category == ProviderCategory.text) {
          _project!.textModelId = selected.id;
          _project!.textProviderId = selected.providerId;
        } else if (category == ProviderCategory.tts) {
          _project!.ttsModelId = selected.id;
          _project!.ttsProviderId = selected.providerId;
          // Carry the provider's key/base URL so cloud TTS actually works
          // (without this, the pipeline would always fall back to local TTS).
          if (provider != null) {
            _project!.ttsApiKey = provider.apiKey;
            _project!.ttsBaseUrl = provider.customBaseUrl;
          }
        } else if (category == ProviderCategory.vision) {
          _project!.visionModelId = selected.id;
          _project!.visionProviderId = selected.providerId;
          // Switching vision providers must also switch the API URL + key,
          // otherwise the call goes to the wrong endpoint with a wrong key.
          if (provider != null) {
            _project!.visionBaseUrl = provider.customBaseUrl;
            _project!.visionApiKey = provider.apiKey;
          }
        }
      });
      await _project!.save();
    }
  }

  // ── Manual Script Loading ──────────────────────────────────────────
  Future<void> _pickScriptFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final text = await file.readAsString();
      if (_project != null && mounted) {
        setState(() {
          _project!.generatedScript = text;
        });
        await _project!.save();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Script loaded from file!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_project == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final p = _project!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          p.title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Quick launch full pipeline
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _startFullPipeline,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Auto Generate'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.image_outlined), text: 'Images'),
            Tab(icon: Icon(Icons.article_outlined), text: 'Script'),
            Tab(icon: Icon(Icons.mic_outlined), text: 'Audio'),
            Tab(icon: Icon(Icons.movie_outlined), text: 'Video'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildImagesTab(theme, colorScheme, p),
          _buildScriptTab(theme, colorScheme, p),
          _buildAudioTab(theme, colorScheme, p),
          _buildVideoTab(theme, colorScheme, p),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // IMAGES TAB
  // ════════════════════════════════════════════════════════════════════
  Widget _buildImagesTab(ThemeData theme, ColorScheme cs, ProjectModel p) {
    final images = p.editedImagePaths.isNotEmpty
        ? p.editedImagePaths
        : p.extractedImagePaths;
    final hasImages = images.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCard(
            icon: Icons.photo_library_outlined,
            iconColor: Colors.orangeAccent,
            title: 'Source Images',
            subtitle: hasImages
                ? '${images.length} images available'
                : 'No images extracted yet. Run the pipeline to extract images from your file.',
            children: [
              if (hasImages)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (ctx, i) {
                      final imgFile = File(images[i]);
                      return Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: cs.surfaceContainerHighest,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imgFile.existsSync()
                            ? Image.file(imgFile, fit: BoxFit.cover)
                            : const Icon(Icons.broken_image_outlined),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppConstants.paddingMedium),
              _ActionButton(
                icon: Icons.cut_rounded,
                label: 'Open Image Editor',
                color: Colors.orangeAccent,
                onPressed: _openImageEditor,
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Detect Characters (AI)',
                      color: cs.tertiary,
                      outlined: true,
                      onPressed: _detectCharactersWithAI,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.face_retouching_natural_rounded,
                      label: 'Detect Faces',
                      color: cs.secondary,
                      outlined: true,
                      onPressed: _detectFacesAndAssign,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              _ActionButton(
                icon: Icons.refresh_rounded,
                label: 'Re-extract Images from Source',
                color: cs.outline,
                outlined: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PipelineProgressScreen(
                      projectId: widget.projectId,
                      startPhase: 1,
                    ),
                  ),
                ).then((_) => _loadProject()),
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.05),
          const SizedBox(height: AppConstants.paddingLarge),
          _SectionCard(
            icon: Icons.settings_outlined,
            iconColor: cs.primary,
            title: 'Project Settings',
            children: [
              // Video Resolution
              _SettingsRow(
                label: 'Video Resolution',
                value: p.videoResolution,
                onTap: () => _showResolutionPicker(context, p),
              ),
              const Divider(height: 1),
              // Export Path
              _SettingsRow(
                label: 'Export Path',
                value: p.customExportPath ?? '/Movies/Webkeyo/ (default)',
                onTap: _changeExportPath,
              ),
              const Divider(height: 1),
              // Language
              _SettingsRow(
                label: 'Language',
                value: p.language,
                onTap: () => _showLanguagePicker(context, p),
              ),
              const Divider(height: 1),
              // Generation Mode
              _SettingsRow(
                label: 'Mode',
                value: p.generationMode,
                onTap: () => _showModePicker(context, p),
              ),
              const Divider(height: 1),
              // NSFW toggle
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMedium,
                ),
                title: const Text('NSFW Content'),
                subtitle: const Text('Allow adult-oriented script generation'),
                value: p.isNsfw,
                activeThumbColor: Colors.redAccent,
                onChanged: (val) {
                  setState(() => p.isNsfw = val);
                  p.save();
                },
              ),
            ],
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SCRIPT TAB
  // ════════════════════════════════════════════════════════════════════
  Widget _buildScriptTab(ThemeData theme, ColorScheme cs, ProjectModel p) {
    final hasScript = p.generatedScript != null && p.generatedScript!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCard(
            icon: Icons.article_rounded,
            iconColor: cs.primary,
            title: 'Script Generation',
            subtitle: hasScript
                ? '✅ Script generated (${p.generatedScript!.length} characters)'
                : '⚠️ No script yet. Generate using AI or write your own.',
            children: [
              if (hasScript) ...[
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha(40),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      p.generatedScript!,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.5),
                      maxLines: 10,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
              ],
              _ActionButton(
                icon: Icons.auto_awesome,
                label: hasScript ? 'Re-generate Script with AI' : 'Generate Script with AI',
                color: cs.primary,
                onPressed: _generateScript,
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.file_upload_outlined,
                      label: 'Load .txt',
                      color: Colors.blueAccent,
                      outlined: true,
                      onPressed: _pickScriptFile,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.edit_note_rounded,
                      label: hasScript ? 'Edit' : 'Write',
                      color: Colors.amber,
                      outlined: true,
                      onPressed: _openScriptEditor,
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.05),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildModelSection(cs, 'Script AI Model', ProviderCategory.text, p.textModelId, p.textProviderId)
              .animate().fadeIn(delay: 50.ms),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // AUDIO TAB
  // ════════════════════════════════════════════════════════════════════
  Widget _buildAudioTab(ThemeData theme, ColorScheme cs, ProjectModel p) {
    final hasScript = p.generatedScript != null && p.generatedScript!.isNotEmpty;
    final hasAudio = p.generatedAudioPath != null && p.generatedAudioPath!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCard(
            icon: Icons.mic_rounded,
            iconColor: Colors.purpleAccent,
            title: 'Audio Generation',
            subtitle: hasAudio
                ? '✅ Audio generated at: ${p.generatedAudioPath}'
                : hasScript
                    ? '⚠️ Script ready. Generate audio now.'
                    : '❌ Generate a script first before generating audio.',
            children: [
              _ActionButton(
                icon: Icons.mic_rounded,
                label: hasAudio ? 'Re-generate Audio' : 'Generate Audio from Script',
                color: Colors.purpleAccent,
                onPressed: hasScript ? _generateAudio : null,
              ),
              if (!hasScript)
                Padding(
                  padding: const EdgeInsets.only(top: AppConstants.paddingSmall),
                  child: Text(
                    'Go to the Script tab first to generate a script.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.redAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ).animate().fadeIn().slideY(begin: 0.05),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildModelSection(cs, 'TTS Provider', ProviderCategory.tts, p.ttsModelId, p.ttsProviderId)
              .animate().fadeIn(delay: 50.ms),
          if (p.ttsProviderId == 'edge_tts') ...[
            const SizedBox(height: AppConstants.paddingSmall),
            _SettingsRow(
              label: 'Voice',
              value: p.ttsVoice ?? 'Auto (${mapTtsLanguage(p.language)})',
              onTap: _pickTtsVoice,
            ),
          ],
          if (p.ttsProviderId != null && p.ttsProviderId != 'flutter_tts') ...[
            const SizedBox(height: AppConstants.paddingLarge),
            _SectionCard(
              icon: Icons.vpn_key_outlined,
              iconColor: Colors.amber,
              title: 'TTS API Configuration',
              subtitle: 'Settings for ${p.ttsProviderId}',
              children: [
                TextField(
                  controller: _ttsApiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: 'Enter your TTS API key',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.password),
                  ),
                  onChanged: (val) {
                    p.ttsApiKey = val;
                    p.save();
                  },
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                TextField(
                  controller: _ttsBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Base URL',
                    hintText: 'Leave empty for default',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  onChanged: (val) {
                    p.ttsBaseUrl = val;
                    p.save();
                  },
                ),
                if (p.ttsProviderId == 'elevenlabs') ...[
                  const SizedBox(height: AppConstants.paddingMedium),
                  TextField(
                    controller: _ttsVoiceIdController,
                    decoration: const InputDecoration(
                      labelText: 'Voice ID',
                      hintText: 'e.g. 21m00Tcm4TlvDq8ikWAM (Rachel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.record_voice_over_outlined),
                    ),
                    onChanged: (val) {
                      p.ttsModelId = val.isEmpty ? null : val;
                      p.save();
                    },
                  ),
                ],
              ],
            ).animate().fadeIn(delay: 100.ms),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // VIDEO TAB
  // ════════════════════════════════════════════════════════════════════
  Widget _buildVideoTab(ThemeData theme, ColorScheme cs, ProjectModel p) {
    final hasAudio = p.generatedAudioPath != null && p.generatedAudioPath!.isNotEmpty;
    final hasVideo = p.finalVideoPath != null && p.finalVideoPath!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCard(
            icon: Icons.movie_creation_rounded,
            iconColor: Colors.greenAccent,
            title: 'Video Rendering',
            subtitle: hasVideo
                ? '✅ Video ready: ${p.finalVideoPath}'
                : hasAudio
                    ? '⚠️ Audio ready. Render video now.'
                    : '❌ Generate audio first before rendering video.',
            children: [
              if (hasVideo) ...[
                _ActionButton(
                  icon: Icons.play_circle_rounded,
                  label: 'Preview Video',
                  color: Colors.greenAccent.shade700,
                  onPressed: _previewVideo,
                ),
                const SizedBox(height: AppConstants.paddingSmall),
              ],
              _ActionButton(
                icon: Icons.subtitles_rounded,
                label: 'Export Subtitles (SRT)',
                color: Colors.amber,
                outlined: true,
                onPressed: _exportSrt,
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              _ActionButton(
                icon: Icons.movie_creation_rounded,
                label: hasVideo ? 'Re-render Video' : 'Render Final Video',
                color: Colors.greenAccent,
                onPressed: hasAudio ? _renderVideo : null,
              ),
              if (!hasAudio)
                Padding(
                  padding: const EdgeInsets.only(top: AppConstants.paddingSmall),
                  child: Text(
                    'Go to the Audio tab first to generate audio.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: AppConstants.paddingMedium),
              // Resolution row
              Row(
                children: [
                  Icon(Icons.high_quality_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Resolution: ', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: p.videoResolution,
                    isDense: true,
                    underline: const SizedBox(),
                    items: ['720p', '1080p', '1440p', '4K']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => p.videoResolution = val);
                        p.save();
                      }
                    },
                  ),
                ],
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.05),
          const SizedBox(height: AppConstants.paddingLarge),
          _SectionCard(
            icon: Icons.music_note_rounded,
            iconColor: Colors.tealAccent,
            title: 'Background Music',
            subtitle: p.bgmPath != null
                ? '♪ ${p.bgmPath!.split('/').last} (mixed under narration)'
                : 'Optional: adds a music bed to the final video',
            children: [
              if (p.bgmPath != null)
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.stop_rounded,
                        label: 'Remove Music',
                        color: Colors.redAccent,
                        outlined: true,
                        onPressed: _clearBgm,
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Change Music',
                        color: Colors.tealAccent,
                        outlined: true,
                        onPressed: _pickBgm,
                      ),
                    ),
                  ],
                )
              else
                _ActionButton(
                  icon: Icons.queue_music_rounded,
                  label: 'Add Music File (mp3/wav/m4a)',
                  color: Colors.tealAccent,
                  outlined: true,
                  onPressed: _pickBgm,
                ),
            ],
          ).animate().fadeIn(delay: 30.ms).slideY(begin: 0.05),
          const SizedBox(height: AppConstants.paddingLarge),
          _SectionCard(
            icon: Icons.folder_outlined,
            iconColor: cs.secondary,
            title: 'Export Settings',
            children: [
              _SettingsRow(
                label: 'Export Path',
                value: p.customExportPath ?? '/Movies/Webkeyo/ (default)',
                onTap: _changeExportPath,
              ),
            ],
          ).animate().fadeIn(delay: 50.ms),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SHARED: Model Info Section
  // ════════════════════════════════════════════════════════════════════
  Widget _buildModelSection(
    ColorScheme cs,
    String label,
    ProviderCategory category,
    String? modelId,
    String? providerId,
  ) {
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    final providers = registry.getProvidersByCategory(category);
    final activeProvider = providerId != null
        ? providers.where((p) => p.id == providerId).firstOrNull
        : (providers.isNotEmpty ? providers.first : null);
    final models = modelId != null
        ? registry.models.where((m) => m.id == modelId).toList()
        : [];

    return _SectionCard(
      icon: Icons.hub_outlined,
      iconColor: cs.tertiary,
      title: label,
      subtitle: activeProvider != null
          ? 'Provider: ${activeProvider.name}${models.isNotEmpty ? " · Model: ${models.first.name}" : ""}'
          : 'No provider configured. Go to Settings → AI Providers.',
      children: [
        _ActionButton(
          icon: Icons.swap_horiz_rounded,
          label: 'Change Model/Provider',
          color: cs.tertiary,
          outlined: true,
          onPressed: () => _changeProjectModel(category),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ════════════════════════════════════════════════════════════════════
  Future<void> _showResolutionPicker(BuildContext context, ProjectModel p) async {
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Video Resolution'),
        children: ['720p', '1080p', '1440p', '4K']
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Text(r),
                ))
            .toList(),
      ),
    );
    if (res != null) {
      setState(() => p.videoResolution = res);
      await p.save();
    }
  }

  Future<void> _showLanguagePicker(BuildContext context, ProjectModel p) async {
    final languages = [
      'Hinglish', 'Hindi', 'English', 'Japanese', 'Korean',
      'Spanish', 'French', 'German', 'Portuguese', 'Arabic',
      'Chinese', 'Italian', 'Russian', 'Turkish', 'Vietnamese',
      'Indonesian', 'Thai',
    ];
    final lang = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Language'),
        children: languages
            .map((l) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, l),
                  child: Text(l),
                ))
            .toList(),
      ),
    );
    if (lang != null) {
      setState(() => p.language = lang);
      await p.save();
    }
  }

  Future<void> _showModePicker(BuildContext context, ProjectModel p) async {
    const modes = [
      'Manga/Manhwa Recap',
      'Study Explainer',
      'Story/Novel Narration',
      'Poem Reciter',
      'Exam Focus',
      'Deep Dive Analysis',
      'Character Study',
      'NSFW Story',
    ];
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Generation Mode'),
        children: modes
            .map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, m),
                  child: Text(m),
                ))
            .toList(),
      ),
    );
    if (mode != null) {
      setState(() => p.generationMode = mode);
      await p.save();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: AppConstants.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withAlpha(180)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: AppConstants.paddingLarge),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(120)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          minimumSize: const Size(double.infinity, 44),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        backgroundColor: onPressed == null ? Colors.grey : color,
        foregroundColor: onPressed == null ? Colors.white60 : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        minimumSize: const Size(double.infinity, 44),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium, vertical: 4),
      title: Text(label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        value,
        style: GoogleFonts.inter(
            fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withAlpha(160)),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.edit_outlined,
          size: 18, color: theme.colorScheme.primary),
      onTap: onTap,
    );
  }
}
