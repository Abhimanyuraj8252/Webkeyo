/// Project list — section header + the Hive project list, as slivers
/// for the home CustomScrollView.
/// The list is loaded asynchronously (FutureBuilder) so a loading state
/// exists: while the read is in flight a skeleton is shown instead of
/// a blank list. The Hive box is already open by then, so the read is
/// fast — the skeleton is the real loading branch, not a timed fake.
library;

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/project_model.dart';
import 'home_skeleton.dart';
import 'project_card.dart';

class ProjectList extends StatelessWidget {
  final Future<List<ProjectModel>> projectsFuture;
  final void Function(ProjectModel project) onOpen;
  final void Function(ProjectModel project) onDelete;
  final void Function(ProjectModel project) onDuplicate;

  const ProjectList({
    super.key,
    required this.projectsFuture,
    required this.onOpen,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<ProjectModel>>(
      future: projectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Projects', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppConstants.paddingMedium),
                const SizedBox(
                  height: 260,
                  child: ProjectListSkeleton(),
                ),
              ],
            ),
          );
        }
        final projects = snapshot.data ?? [];
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Projects', style: theme.textTheme.titleLarge),
                  if (projects.isNotEmpty)
                    Text('${projects.length} total',
                        style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppConstants.paddingMedium),
            ),
            if (projects.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: theme.dividerColor),
                        const SizedBox(height: AppConstants.paddingMedium),
                        Text(
                          'No projects yet.\nUpload a file to get started.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return ProjectCard(
                    project: project,
                    onTap: () => onOpen(project),
                    onDelete: () => onDelete(project),
                    onDuplicate: () => onDuplicate(project),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
