import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/upload_card.dart';
import '../settings/settings_screen.dart';
import '../tools/tools_screen.dart';
import '../../models/ai_provider_model.dart';
import '../../core/constants.dart';
import 'package:provider/provider.dart';
import '../../services/provider_registry.dart';
import '../../models/project_model.dart';
import '../project/screens/project_context_screen.dart';
import '../pipeline/screens/pipeline_progress_screen.dart';
import '../pipeline/screens/script_editor_screen.dart';
import 'model_selector_sheet.dart';
import '../../models/ai_model.dart';

/// The main dashboard for Webkeyo with real project listing from Hive.
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
          ).then((_) => setState(() {})); // Refresh dashboard on return
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
        ).then((_) => setState(() {}));
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
      )).then((_) => setState(() {}));
    } else if (project.status == 'created') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProjectContextScreen(projectId: project.id),
      )).then((_) => setState(() {}));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PipelineProgressScreen(projectId: project.id),
      )).then((_) => setState(() {}));
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
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registry = context.watch<ProviderRegistry>();
    final projects = registry.projectsBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context, theme),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConstants.paddingMedium),

              // Quick Model Selectors
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildSelectorChip('Script Model', _selectedTextModel, ProviderCategory.text),
                    const SizedBox(width: AppConstants.paddingSmall),
                    _buildSelectorChip('Vision Model', _selectedVisionModel, ProviderCategory.vision),
                    const SizedBox(width: AppConstants.paddingSmall),
                    _buildSelectorChip('TTS Model', _selectedTtsModel, ProviderCategory.tts),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: AppConstants.paddingMedium),

              // Settings Row: Mode, Language & NSFW
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMode,
                          isExpanded: true,
                          icon: const Icon(Icons.mode_edit_outline, size: 20),
                          items: _modes.map((String mode) {
                            return DropdownMenuItem<String>(
                              value: mode,
                              child: Text(mode, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _selectedMode = value);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          isExpanded: true,
                          icon: const Icon(Icons.language_rounded, size: 20),
                          items: _languages.map((String lang) {
                            return DropdownMenuItem<String>(
                              value: lang,
                              child: Text(lang, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _selectedLanguage = value);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Expanded(
                    flex: 2,
                    child: _buildNsfwToggle(theme),
                  ),
                ],
              ).animate().fadeIn(duration: 200.ms, delay: 50.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: AppConstants.paddingLarge),

              // Upload Area with File + Folder options
              Row(
                children: [
                  Expanded(
                    child: UploadCard(
                      onTap: _pickFiles,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    child: InkWell(
                      onTap: _pickFolder,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, color: theme.colorScheme.secondary, size: 24),
                            const SizedBox(height: 2),
                            Text('Folder', style: GoogleFonts.inter(fontSize: 10, color: theme.colorScheme.secondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 200.ms, delay: 100.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: AppConstants.paddingXLarge),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Projects', style: theme.textTheme.titleLarge),
                  if (projects.isNotEmpty)
                    Text('${projects.length} total', style: theme.textTheme.bodyMedium),
                ],
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: AppConstants.paddingMedium),

              // Project Dashboard (from Hive)
              Expanded(
                child: projects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: theme.dividerColor),
                            const SizedBox(height: AppConstants.paddingMedium),
                            Text(
                              'No projects yet.\nUpload a file to get started.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ).animate().fadeIn()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return _ProjectCard(
                            project: project,
                            onTap: () => _openProject(project),
                            onDelete: () => _deleteProject(project),
                          ).animate().fadeIn(
                                duration: 200.ms,
                                delay: Duration(milliseconds: 40 * index),
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNsfwToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: _isNsfwEnabled
            ? Colors.redAccent.withAlpha(25)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: _isNsfwEnabled
              ? Colors.redAccent.withAlpha(128)
              : theme.dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'NSFW',
              style: TextStyle(
                fontSize: 11,
                color: _isNsfwEnabled ? Colors.redAccent : theme.textTheme.bodyMedium?.color,
                fontWeight: _isNsfwEnabled ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: _isNsfwEnabled,
              activeThumbColor: Colors.redAccent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (val) => setState(() => _isNsfwEnabled = val),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildSelectorChip(String title, String? selectedModel, ProviderCategory category) {
    final theme = Theme.of(context);
    final hasSelection = selectedModel != null;

    return ActionChip(
      avatar: Icon(
        hasSelection ? Icons.check_circle : Icons.add_circle_outline,
        size: 18,
        color: hasSelection ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
      ),
      label: Text(
        hasSelection ? selectedModel : title,
        style: TextStyle(
          color: hasSelection ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
          fontWeight: hasSelection ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      backgroundColor: hasSelection
          ? theme.primaryColor.withAlpha(25)
          : theme.cardColor,
      side: BorderSide(
        color: hasSelection ? theme.primaryColor : theme.dividerColor,
      ),
      onPressed: () => _selectModel(category),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: const DecorationImage(
                image: AssetImage('assets/logo.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Webkeyo', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.handyman_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ToolsScreen()),
            );
          },
          tooltip: 'Quick Tools',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }
}

/// A card widget that displays a project from Hive with status and actions.
class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = project.status == 'done';
    final hasError = project.status == 'error';

    Color statusColor = theme.primaryColor;
    if (isDone) statusColor = Colors.greenAccent;
    if (hasError) statusColor = Colors.redAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check_circle_rounded, color: statusColor, size: 22)
                      : hasError
                          ? Icon(Icons.error_rounded, color: statusColor, size: 22)
                          : Icon(Icons.auto_awesome, color: statusColor, size: 22),
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              // Project info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              project.statusDisplay,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            project.generationMode,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (project.progressValue > 0 && project.progressValue < 1) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: project.progressValue,
                          backgroundColor: theme.dividerColor,
                          valueColor: AlwaysStoppedAnimation(statusColor),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: theme.textTheme.bodyMedium?.color),
                onPressed: onDelete,
                tooltip: 'Delete Project',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
