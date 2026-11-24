import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/make_video_row.dart';
import 'widgets/model_selector_row.dart';
import 'widgets/project_list.dart';
import 'widgets/settings_row.dart';
import 'widgets/streak_header.dart';
import 'widgets/templates_row.dart';
import 'widgets/trending_row.dart';
import 'widgets/upload_row.dart';
import '../project/screens/project_context_screen.dart';
import '../pipeline/screens/pipeline_progress_screen.dart';
import '../pipeline/screens/script_editor_screen.dart';
import 'model_selector_sheet.dart';
import '../../models/ai_model.dart';
import '../../models/ai_provider_model.dart';
import '../../core/constants.dart';
import 'package:provider/provider.dart';
import '../../services/provider_registry.dart';
import '../../models/project_model.dart';

/// The main dashboard for Webkeyo with real project listing from Hive.
///
/// The screen is a coordinator: the rows live in widgets/ as small
/// const-friendly widgets (home_app_bar, model_selector_row,
/// settings_row, upload_row, make_video_row, streak_header,
/// templates_row, trending_row, project_list). State (selected models,
/// mode, language, NSFW, project mutations) stays here.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedTextModel;
  String? _selectedVisionModel;
  String? _selectedTtsModel;

  // Store full model info so we can pass provider details to ProjectModel
  AIModel? _selectedVisionModelObj;
  AIModel? _selectedTextModelObj;
  AIModel? _selectedTtsModelObj;

  String _selectedLanguage = 'Hinglish';
  bool _isNsfwEnabled = false;

  final List<String> _languages = [
    'Hinglish', 'Hindi', 'English', 'Japanese', 'Korean',
    'Spanish', 'French', 'German', 'Portuguese', 'Arabic',
    'Chinese', 'Italian', 'Russian', 'Turkish', 'Vietnamese',
    'Indonesian', 'Thai',
  ];

  String _selectedMode = 'Manga/Manhwa Recap';
  final List<String> _modes = [
    'Manga/Manhwa Recap',
    'Study Explainer',
    'Story/Novel Narration',
    'Poem Reciter',
  ];

  late Future<List<ProjectModel>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
  }

  /// Async read of the project list (Hive box, already open). The
  /// FutureBuilder in ProjectList shows a skeleton while this is in
  /// flight.
  Future<List<ProjectModel>> _loadProjects() async {
    final registry =
        Provider.of<ProviderRegistry>(context, listen: false);
    final projects = registry.projectsBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return projects;
  }

  void _refreshProjects() {
    setState(() {
      _projectsFuture = _loadProjects();
    });
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['cbz', 'pdf', 'zip'],
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final registry = Provider.of<ProviderRegistry>(context, listen: false);

      // Find the user's selected vision provider details
      String? visionBaseUrl;
      String? visionApiKey;
      String? visionModelId;

      if (_selectedVisionModelObj != null) {
        final provider = registry.providers.firstWhere(
          (p) => p.id == _selectedVisionModelObj!.providerId,
          orElse: () => registry.providers.firstWhere(
            (p) => p.category == ProviderCategory.vision && p.isEnabled,
            orElse: () => AIProviderModel(id: '', name: '', category: ProviderCategory.vision),
          ),
        );
        visionBaseUrl = provider.customBaseUrl;
        visionApiKey = provider.apiKey;
        visionModelId = _selectedVisionModelObj!.id;
      } else {
        // Fallback: use first enabled vision provider
        final visionProviders = registry.providers
            .where((p) => p.category == ProviderCategory.vision && p.isEnabled)
            .toList();
        if (visionProviders.isNotEmpty) {
          visionBaseUrl = visionProviders.first.customBaseUrl;
          visionApiKey = visionProviders.first.apiKey;
          final models = registry.getModelsByProvider(visionProviders.first.id);
          visionModelId = models.isNotEmpty ? models.first.id : null;
        }
      }

      for (var file in result.files) {
        final projectId = DateTime.now().millisecondsSinceEpoch.toString();
        final newProject = ProjectModel(
          id: projectId,
          title: file.name,
          sourceFilePath: file.path,
          language: _selectedLanguage,
          isNsfw: _isNsfwEnabled,
          generationMode: _selectedMode,
          visionProviderId: _selectedVisionModelObj?.providerId,
          visionModelId: visionModelId,
          visionBaseUrl: visionBaseUrl,
          visionApiKey: visionApiKey,
          textProviderId: _selectedTextModelObj?.providerId,
          textModelId: _selectedTextModelObj?.id,
          ttsProviderId: _selectedTtsModelObj?.providerId,
          status: 'created',
        );

        await registry.projectsBox.put(projectId, newProject);
        registry.refreshProjects();

        // Navigate to project context screen for the first file
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectContextScreen(projectId: projectId),
            ),
          ).then((_) => _refreshProjects()); // Refresh dashboard on return
        }
        break; // Process first file, rest queued
      }
    }
  }

  Future<void> _pickFolder() async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath != null && mounted) {
      final registry = Provider.of<ProviderRegistry>(context, listen: false);
      final projectId = DateTime.now().millisecondsSinceEpoch.toString();
      final folderName = folderPath.split('/').last;

      final newProject = ProjectModel(
        id: projectId,
        title: folderName,
        sourceFilePath: folderPath,
        language: _selectedLanguage,
        isNsfw: _isNsfwEnabled,
        generationMode: _selectedMode,
        status: 'created',
      );

      await registry.projectsBox.put(projectId, newProject);
      registry.refreshProjects();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectContextScreen(projectId: projectId),
          ),
        ).then((_) => _refreshProjects());
      }
    }
  }

  Future<void> _selectModel(ProviderCategory category) async {
    final selected = await ModelSelectorSheet.show(context, category);
    if (selected != null) {
      setState(() {
        if (category == ProviderCategory.text) {
          _selectedTextModel = selected.name;
          _selectedTextModelObj = selected;
        }
        if (category == ProviderCategory.vision) {
          _selectedVisionModel = selected.name;
          _selectedVisionModelObj = selected;
        }
        if (category == ProviderCategory.tts) {
          _selectedTtsModel = selected.name;
          _selectedTtsModelObj = selected;
        }
      });
    }
  }

  void _openProject(ProjectModel project) {
    if (project.status == 'done' && project.finalVideoPath != null) {
      // Show completion dialog with options
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(project.title),
          content: const Text('This project is complete. What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ScriptEditorScreen(projectId: project.id),
                ));
              },
              child: const Text('View Script'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else if (project.status == 'script_ready') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ScriptEditorScreen(projectId: project.id),
      )).then((_) => _refreshProjects());
    } else if (project.status == 'created') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProjectContextScreen(projectId: project.id),
      )).then((_) => _refreshProjects());
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PipelineProgressScreen(projectId: project.id),
      )).then((_) => _refreshProjects());
    }
  }

  void _deleteProject(ProjectModel project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final registry = Provider.of<ProviderRegistry>(context, listen: false);
              final navigator = Navigator.of(ctx);
              await registry.projectsBox.delete(project.id);
              registry.refreshProjects();
              navigator.pop();
              _refreshProjects();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Remix — duplicate a project as a new project with the same source
  /// and settings, so a creator can re-render it with a different
  /// style or voice. The copy starts fresh (status 'created', no
  /// script/audio/video yet).
  Future<void> _duplicateProject(ProjectModel project) async {
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    final copyId = '${DateTime.now().millisecondsSinceEpoch}';
    final copy = ProjectModel(
      id: copyId,
      title: '${project.title} (copy)',
      sourceFilePath: project.sourceFilePath,
      extractedImagePaths: List<String>.from(project.extractedImagePaths),
      editedImagePaths: List<String>.from(project.editedImagePaths),
      language: project.language,
      isNsfw: project.isNsfw,
      charactersContext: project.charactersContext,
      generationMode: project.generationMode,
      visionProviderId: project.visionProviderId,
      visionModelId: project.visionModelId,
      visionBaseUrl: project.visionBaseUrl,
      visionApiKey: project.visionApiKey,
      textProviderId: project.textProviderId,
      textModelId: project.textModelId,
      ttsProviderId: project.ttsProviderId,
      ttsModelId: project.ttsModelId,
      ttsApiKey: project.ttsApiKey,
      ttsBaseUrl: project.ttsBaseUrl,
      videoResolution: project.videoResolution,
      customExportPath: project.customExportPath,
      status: 'created',
    );
    await registry.projectsBox.put(copyId, copy);
    registry.refreshProjects();
    _refreshProjects();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated as "${copy.title}"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch the registry so the list rebuilds when projects change
    // elsewhere (e.g. a pipeline finishing in the background).
    context.watch<ProviderRegistry>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const HomeAppBar(),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLarge),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: AppConstants.paddingMedium),
                  const StreakHeader()
                      .animate()
                      .fadeIn(duration: 200.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: AppConstants.paddingMedium),
                  ModelSelectorRow(
                    selectedTextModel: _selectedTextModel,
                    selectedVisionModel: _selectedVisionModel,
                    selectedTtsModel: _selectedTtsModel,
                    onSelect: _selectModel,
                  ).animate().fadeIn(duration: 200.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: AppConstants.paddingMedium),
                  HomeSettingsRow(
                    selectedMode: _selectedMode,
                    modes: _modes,
                    onModeChanged: (value) =>
                        setState(() => _selectedMode = value),
                    selectedLanguage: _selectedLanguage,
                    languages: _languages,
                    onLanguageChanged: (value) =>
                        setState(() => _selectedLanguage = value),
                    isNsfwEnabled: _isNsfwEnabled,
                    onNsfwChanged: (value) =>
                        setState(() => _isNsfwEnabled = value),
                  ).animate().fadeIn(
                      duration: 200.ms,
                      delay: 50.ms,
                      curve: Curves.easeOutCubic),
                  const SizedBox(height: AppConstants.paddingLarge),
                  UploadRow(
                    onPickFiles: _pickFiles,
                    onPickFolder: _pickFolder,
                  ).animate().fadeIn(
                      duration: 200.ms,
                      delay: 100.ms,
                      curve: Curves.easeOutCubic),
                  const SizedBox(height: AppConstants.paddingLarge),
                  const MakeVideoRow().animate().fadeIn(
                      duration: 200.ms,
                      delay: 150.ms,
                      curve: Curves.easeOutCubic),
                  const SizedBox(height: AppConstants.paddingXLarge),
                  const TemplatesRow().animate().fadeIn(
                      duration: 200.ms,
                      delay: 200.ms,
                      curve: Curves.easeOutCubic),
                  const SizedBox(height: AppConstants.paddingXLarge),
                  const TrendingRow().animate().fadeIn(
                      duration: 200.ms,
                      delay: 250.ms,
                      curve: Curves.easeOutCubic),
                  const SizedBox(height: AppConstants.paddingXLarge),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLarge),
              sliver: ProjectList(
                projectsFuture: _projectsFuture,
                onOpen: _openProject,
                onDelete: _deleteProject,
                onDuplicate: _duplicateProject,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppConstants.paddingXLarge),
            ),
          ],
        ),
      ),
    );
  }
}
