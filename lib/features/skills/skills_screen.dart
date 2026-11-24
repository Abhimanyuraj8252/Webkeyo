/// Skills screen — every stage of making a story video, in one list.
///
/// Reads the registry in services/skills_registry.dart (same data as
/// SKILLS.md). Each skill: what it does, cost, install/key, mobile OK?,
/// when to use, what it does NOT do, and whether it is working code in
/// this app or a documented guide.
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/skills_registry.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  String _statusLabel(SkillStatus status) {
    switch (status) {
      case SkillStatus.code:
        return 'In this app';
      case SkillStatus.starter:
        return 'Starter';
      case SkillStatus.docs:
        return 'Guide';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = skillsByStage();
    return Scaffold(
      appBar: AppBar(title: const Text('Skills Library')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        children: [
          Text(
            '${skills.length} skills across ${skillStages.length} stages — '
            'Script, Voicing, Video, Editing, Thumbnail, Subtitles, '
            'Music/SFX. Free first: anything that costs money says so.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          for (final stage in skillStages) ...[
            Text(
              '$stage (${grouped[stage]!.length})',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            for (final skill in grouped[stage]!)
              Card(
                child: ExpansionTile(
                  title: Text(skill.name, style: theme.textTheme.titleSmall),
                  subtitle: Text(
                    skill.what,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Chip(
                    label: Text(
                      _statusLabel(skill.status),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row(theme, 'Cost', skill.cost),
                          _row(theme, 'Install / key', skill.install),
                          _row(
                            theme,
                            'Mobile',
                            skill.mobileOk
                                ? 'Yes — ${skill.mobileNote}'
                                : 'No — ${skill.mobileNote}',
                          ),
                          _row(theme, 'Use when', skill.whenToUse),
                          _row(theme, 'Does NOT do', skill.doesNotDo),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppConstants.paddingLarge),
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
