/// Samples screen — one ready prompt per genre.
///
/// Tapping a sample opens the prompt-to-video screen with that prompt,
/// genre and style pre-filled. Samples render on-device (about 30
/// seconds for a 14-second reel). No sample video files ship with the
/// app — every sample is generated fresh, so what you see is what the
/// app actually makes.
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../prompt_video/prompt_video_screen.dart';

class _Sample {
  final String genre;
  final String genreLabel;
  final String prompt;
  final String styleId;
  final String styleName;

  const _Sample({
    required this.genre,
    required this.genreLabel,
    required this.prompt,
    required this.styleId,
    required this.styleName,
  });
}

const List<_Sample> _samples = [
  _Sample(
    genre: 'haunted',
    genreLabel: 'Haunted / Horror',
    prompt: 'A boy enters a haunted inn where the waiter is not human',
    styleId: 'horror-night',
    styleName: 'Horror Night',
  ),
  _Sample(
    genre: 'love',
    genreLabel: 'Love',
    prompt: 'A girl who died a year ago returns to the boy who loved her',
    styleId: 'romantic-pink',
    styleName: 'Romantic Pink',
  ),
  _Sample(
    genre: 'action',
    genreLabel: 'Action',
    prompt: 'A bullied student is reborn with a demon system and takes revenge',
    styleId: 'cinematic-dark',
    styleName: 'Cinematic Dark',
  ),
  _Sample(
    genre: 'sad',
    genreLabel: 'Sad / Emotional',
    prompt: 'A wife leaves her husband in the rain and he waits for her every evening',
    styleId: 'retro-film',
    styleName: 'Retro Film',
  ),
  _Sample(
    genre: 'motivational',
    genreLabel: 'Motivational',
    prompt: 'A poor boy builds an app that changes his whole village',
    styleId: 'motivational-gold',
    styleName: 'Motivational Gold',
  ),
  _Sample(
    genre: 'mystery',
    genreLabel: 'Mystery',
    prompt: 'A CEO hides a secret husband from the world',
    styleId: 'neon-cyberpunk',
    styleName: 'Neon Cyberpunk',
  ),
];

class SamplesScreen extends StatelessWidget {
  const SamplesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Samples')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        children: [
          Text(
            'One sample per genre. Tap one to render it — the video is '
            'generated fresh on your phone, with narration and sound '
            'effects included.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          for (final sample in _samples)
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_outline, size: 36),
                title: Text(sample.prompt),
                subtitle: Text('${sample.genreLabel} • ${sample.styleName}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PromptVideoScreen(
                        initialPrompt: sample.prompt,
                        initialGenre: sample.genre,
                        initialStyle: sample.styleId,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
