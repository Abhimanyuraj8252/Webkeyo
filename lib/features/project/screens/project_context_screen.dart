import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants.dart';
import '../../../models/project_model.dart';
import '../../../models/ai_provider_model.dart';
import 'package:webkeyo/services/provider_registry.dart';
import 'package:webkeyo/features/home/model_selector_sheet.dart';
import 'package:webkeyo/features/pipeline/screens/pipeline_progress_screen.dart';
import '../../../features/pipeline/screens/script_editor_screen.dart';
import '../../../features/pipeline/screens/video_preview_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProject();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadProject() {
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    setState(() {
      _project = registry.projectsBox.get(widget.projectId);
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
      setState(() {
        if (category == ProviderCategory.text) {
          _project!.textModelId = selected.id;
          _project!.textProviderId = selected.providerId;
        } else if (category == ProviderCategory.tts) {
          _project!.ttsModelId = selected.id;
          _project!.ttsProviderId = selected.providerId;
        } else if (category == ProviderCategory.vision) {
          _project!.visionModelId = selected.id;
          _project!.visionProviderId = selected.providerId;
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
          _buildModelSection(cs, 'TTS Provider', ProviderCategory.tts, p.ttsProviderId, p.ttsProviderId)
              .animate().fadeIn(delay: 50.ms),
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
