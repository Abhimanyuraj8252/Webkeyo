import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../models/project_model.dart';
import '../../../services/provider_registry.dart';

/// Browse every script that has been generated so far, reuse one in the
/// current project, or delete it.
class ScriptLibraryScreen extends StatelessWidget {
  final String currentProjectId;

  const ScriptLibraryScreen({super.key, required this.currentProjectId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registry = context.watch<ProviderRegistry>();

    final withScripts = registry.projectsBox.values
        .where((p) => p.generatedScript != null && p.generatedScript!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: Text('Script Library', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: withScripts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_books_outlined,
                        size: 56, color: theme.dividerColor),
                    const SizedBox(height: 16),
                    Text(
                      'No saved scripts yet.\nGenerate a script first and it will appear here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              itemCount: withScripts.length,
              itemBuilder: (context, index) {
                final project = withScripts[index];
                final isCurrent = project.id == currentProjectId;
                final preview = _firstNarrationPreview(project.generatedScript!);

                return Card(
                  margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCurrent
                                  ? Icons.current_location_rounded
                                  : Icons.article_outlined,
                              size: 18,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project.title,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              project.createdAt
                                  .toIso8601String()
                                  .substring(0, 10),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (!isCurrent)
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.input_rounded, size: 18),
                                  label: const Text('Use this script'),
                                  onPressed: () => _copyToCurrent(
                                    context, registry, project,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: const Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: BorderSide(color: Colors.redAccent.withAlpha(120)),
                                ),
                                onPressed: () => _deleteScript(
                                  context, registry, project,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _firstNarrationPreview(String scriptJson) {
    try {
      final dynamic data = jsonDecode(scriptJson);
      if (data is Map && data['scenes'] is List && (data['scenes'] as List).isNotEmpty) {
        final dynamic first = (data['scenes'] as List).first;
        if (first is Map && first['narration'] is String) {
          return (first['narration'] as String).trim();
        }
      }
    } catch (_) {}
    return scriptJson.length > 120 ? '${scriptJson.substring(0, 120)}…' : scriptJson;
  }

  Future<void> _copyToCurrent(
    BuildContext context,
    ProviderRegistry registry,
    ProjectModel source,
  ) async {
    final target = registry.projectsBox.get(currentProjectId);
    if (target == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use this script?'),
        content: Text(
          'Replace the current script of "${target.title}" with the script from "${source.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    if (ok == true) {
      target.generatedScript = source.generatedScript;
      target.status = 'script_ready';
      await target.save();
      registry.refreshProjects();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Script loaded into the current project.')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _deleteScript(
    BuildContext context,
    ProviderRegistry registry,
    ProjectModel project,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete script'),
        content: Text('Delete the saved script of "${project.title}"? The project itself is kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      project.generatedScript = null;
      if (project.status == 'script_ready') project.status = 'created';
      await project.save();
      registry.refreshProjects();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Script deleted.')));
      }
    }
  }
}
