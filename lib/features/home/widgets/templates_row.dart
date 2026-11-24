/// One-tap reel templates — horizontal row on the home screen.
/// Tap a template and the prompt-to-video screen opens prefilled with
/// that template's prompt and style. One tap, one render.
library;

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../prompt_video/prompt_video_screen.dart';
import '../../../services/reel_templates.dart';

class TemplatesRow extends StatelessWidget {
  const TemplatesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('One-tap reels', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppConstants.paddingSmall),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: reelTemplates.length,
            itemBuilder: (context, index) {
              final template = reelTemplates[index];
              return Padding(
                padding: const EdgeInsets.only(right: AppConstants.paddingSmall),
                child: Material(
                  color: theme.cardColor,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMedium),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PromptVideoScreen(
                            initialPrompt: template.prompt,
                            initialStyle: template.styleId,
                          ),
                        ),
                      );
                    },
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMedium),
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.all(AppConstants.paddingMedium),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMedium),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template.tagline,
                            style: theme.textTheme.bodySmall,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
