/// "Make a video" row — Prompt Video / Skills / Samples.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../prompt_video/prompt_video_screen.dart';
import '../../samples/samples_screen.dart';
import '../../skills/skills_screen.dart';

class MakeVideoRow extends StatelessWidget {
  const MakeVideoRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MakeVideoButton(
            icon: Icons.movie_creation_outlined,
            label: 'Prompt Video',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PromptVideoScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: AppConstants.paddingSmall),
        Expanded(
          child: MakeVideoButton(
            icon: Icons.menu_book_outlined,
            label: 'Skills',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SkillsScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: AppConstants.paddingSmall),
        Expanded(
          child: MakeVideoButton(
            icon: Icons.play_circle_outline,
            label: 'Samples',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SamplesScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A small action button for the "Make a video" row on Home.
class MakeVideoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const MakeVideoButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(height: 2),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: theme.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
