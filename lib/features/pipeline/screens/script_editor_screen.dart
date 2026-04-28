import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants.dart';
import '../../../models/project_model.dart';
import '../../../services/provider_registry.dart';
import 'pipeline_progress_screen.dart';

class ScriptEditorScreen extends StatefulWidget {
  final String projectId;

  const ScriptEditorScreen({super.key, required this.projectId});

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  late TextEditingController _scriptController;
  ProjectModel? _project;

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
  }

  Future<void> _saveScript() async {
    if (_project != null) {
      _project!.generatedScript = _scriptController.text;
      await _project!.save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Script saved successfully!')),
        );
      }
    }
  }

  void _proceedToAudioGeneration() async {
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

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_project == null) {
      return const Scaffold(body: Center(child: Text("Project not found")));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Refine Script', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveScript,
            tooltip: 'Save Script',
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
                      'Edit the AI script below. You can inject emotion tags (e.g., [happy]) depending on your selected TTS provider. Or paste a custom script completely!',
                      style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1),
            const SizedBox(height: AppConstants.paddingLarge),
            Expanded(
              child: Container(
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
}
