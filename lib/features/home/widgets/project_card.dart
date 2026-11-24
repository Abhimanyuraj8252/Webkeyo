/// A card widget that displays a project from Hive with status and
/// actions: open, remix (duplicate as a new project) and delete.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../models/project_model.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
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
                      ? Icon(Icons.check_circle_rounded,
                          color: statusColor, size: 22)
                      : hasError
                          ? Icon(Icons.error_rounded,
                              color: statusColor, size: 22)
                          : Icon(Icons.auto_awesome,
                              color: statusColor, size: 22),
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
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
                    if (project.progressValue > 0 &&
                        project.progressValue < 1) ...[
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
              // Remix (duplicate) button
              IconButton(
                icon: Icon(Icons.content_copy_outlined,
                    size: 20, color: theme.textTheme.bodyMedium?.color),
                onPressed: onDuplicate,
                tooltip: 'Remix — duplicate as a new project',
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: theme.textTheme.bodyMedium?.color),
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
