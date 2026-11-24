/// "Trending this week" — driven by assets/data/trending.json, which
/// ships with the release and is updated per release. No server, no
/// tracking. Tap a trend and the matching template opens prefilled.
library;

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../prompt_video/prompt_video_screen.dart';
import '../../../services/reel_templates.dart';
import '../../../services/trending_service.dart';
import 'home_skeleton.dart';

class TrendingRow extends StatelessWidget {
  const TrendingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<TrendingItem>>(
      future: loadTrending(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trending this week', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppConstants.paddingSmall),
              const HorizontalRowSkeleton(),
            ],
          );
        }
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trending this week', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppConstants.paddingSmall),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final template = templateById(item.templateId);
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: AppConstants.paddingSmall),
                    child: Material(
                      color: theme.cardColor,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMedium),
                      child: InkWell(
                        onTap: template == null
                            ? null
                            : () {
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
                          width: 200,
                          padding: const EdgeInsets.all(
                              AppConstants.paddingMedium),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusMedium),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.trending_up,
                                      size: 16, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.reason,
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
      },
    );
  }
}
