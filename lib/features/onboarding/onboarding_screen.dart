/// 3-step onboarding — shown once on first run.
///
/// 1. What Webkeyo does.
/// 2. Pick a voice (free providers first; keyed ones need a free key
///    in Settings — the pick just selects, it never asks for a key here).
/// 3. Render a short demo (Edge TTS, free, no key) or jump straight
///    into a sample story (Haunted Night template).
///
/// Completion is stored in SharedPreferences
/// (`webkeyo_onboarding_done`). Skipping is always allowed.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../features/home/home_screen.dart';
import '../../features/prompt_video/prompt_video_screen.dart';
import '../../services/engagement_service.dart';
import '../../services/prompt_video_service.dart';
import '../../services/provider_credentials.dart';
import '../../services/provider_registry.dart';
import '../../services/reel_templates.dart';
import '../../services/tts_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _VoiceOption {
  final String id;
  final String name;
  final String freeLimit;
  final bool needsKey;

  const _VoiceOption({
    required this.id,
    required this.name,
    required this.freeLimit,
    required this.needsKey,
  });
}

const List<_VoiceOption> _voiceOptions = [
  _VoiceOption(
    id: 'edge_tts',
    name: 'Edge TTS',
    freeLimit: 'Free, no key — built in',
    needsKey: false,
  ),
  _VoiceOption(
    id: 'sarvam_tts',
    name: 'Sarvam Bulbul',
    freeLimit: 'Free trial credits, Indian voices',
    needsKey: true,
  ),
  _VoiceOption(
    id: 'google_cloud_tts',
    name: 'Google Cloud WaveNet',
    freeLimit: '4M chars/month free (~83 hrs) — billing must be enabled',
    needsKey: true,
  ),
  _VoiceOption(
    id: 'azure_speech',
    name: 'Azure SwaraNeural',
    freeLimit: '0.5M chars/month free (~10 hrs) — REAL emotion styles',
    needsKey: true,
  ),
  _VoiceOption(
    id: 'speechify',
    name: 'Speechify Simba',
    freeLimit: '500K chars/month free (~10 hrs)',
    needsKey: true,
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  String _voiceId = 'edge_tts';
  bool _demoBusy = false;
  double _demoProgress = 0;
  String _demoLabel = '';
  PromptVideoResult? _demoResult;
  String? _demoError;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('webkeyo_onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _pickVoice(String id) async {
    final registry = context.read<ProviderRegistry>();
    setState(() => _voiceId = id);
    await DefaultTtsProvider.save(id);
    final provider = registry.providers
        .where((p) => p.id == id)
        .firstOrNull;
    if (provider != null && !provider.isEnabled) {
      await registry.updateProvider(provider.copyWith(isEnabled: true));
    }
  }

  Future<void> _renderDemo() async {
    setState(() {
      _demoBusy = true;
      _demoError = null;
      _demoResult = null;
      _demoProgress = 0;
      _demoLabel = 'Starting demo…';
    });
    try {
      final docs = await getApplicationDocumentsDirectory();
      final outDir =
          '${docs.path}/prompt_videos/demo_${DateTime.now().millisecondsSinceEpoch}';
      await Directory(outDir).create(recursive: true);
      // Edge TTS is free with no key — the demo always works.
      final tts = TtsService(providerId: 'edge_tts');
      final result = await renderPromptVideo(
        prompt:
            'A boy enters a haunted inn at midnight. The waiter smiles — he has no shadow.',
        genre: 'horror',
        styleId: 'horror-night',
        outDir: outDir,
        tts: tts,
        vertical: true,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _demoProgress = progress.fraction;
              _demoLabel = progress.stage;
            });
          }
        },
      );
      // A demo render counts as a creation (+10 XP) — no fake numbers,
      // the video file really exists at result.videoPath.
      final engagement = EngagementService();
      await engagement.init();
      await engagement.recordExport(xpGained: 10);
      if (!mounted) return;
      setState(() {
        _demoResult = result;
        _demoBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _demoError = e.toString();
        _demoBusy = false;
      });
    }
  }

  void _trySampleStory() {
    final template = templateById('haunted_night');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PromptVideoScreen(
          initialPrompt: template?.prompt ??
              'A boy enters a haunted inn at midnight.',
          initialGenre: 'horror',
          initialStyle: template?.styleId ?? 'horror-night',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _buildWhatItDoes(theme),
                  _buildPickVoice(theme),
                  _buildTryIt(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                  const Spacer(),
                  if (_page < 2)
                    ElevatedButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: AppConstants.animationMedium,
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _finish,
                      child: const Text('Start creating'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatItDoes(ThemeData theme) {
    return _pagePadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.movie_creation_outlined, size: 64),
          const SizedBox(height: AppConstants.paddingMedium),
          Text('Webkeyo', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            'Turn manga, manhwa, PDFs and documents into cinematic narrated Hindi videos — on your phone.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          _bullet(theme, 'Multi-voice Hindi narration — every character gets their own voice, with real emotion.'),
          _bullet(theme, 'Code-drawn motion graphics — no stock footage, no flat stills.'),
          _bullet(theme, 'Free to start — Edge TTS needs no key; other providers have free tiers.'),
        ],
      ),
    );
  }

  Widget _buildPickVoice(ThemeData theme) {
    return _pagePadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pick your voice', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            'You can change this any time in Settings. Keyed providers need a free key — the app never asks for one here.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Expanded(
            child: ListView.builder(
              itemCount: _voiceOptions.length,
              itemBuilder: (context, index) {
                final option = _voiceOptions[index];
                final selected = option.id == _voiceId;
                return Card(
                  color: selected
                      ? theme.colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(option.name),
                    subtitle: Text(
                      option.freeLimit +
                          (option.needsKey ? ' — needs a free key in Settings' : ''),
                    ),
                    onTap: () => _pickVoice(option.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTryIt(ThemeData theme) {
    return _pagePadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Try it now', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppConstants.paddingSmall),
          const Text(
            'Render a short demo with the free built-in voice, or jump straight into a sample story.',
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          if (_demoBusy) ...[
            LinearProgressIndicator(value: _demoProgress),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(_demoLabel),
          ] else if (_demoResult != null) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Demo ready — ${_demoResult!.durationSeconds.toStringAsFixed(0)} sec, ${_demoResult!.sceneCount} scenes.',
            ),
            Text(
              _demoResult!.videoPath,
              style: theme.textTheme.bodySmall,
            ),
          ] else if (_demoError != null) ...[
            Text('Demo failed: $_demoError',
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppConstants.paddingMedium),
          ElevatedButton.icon(
            onPressed: _demoBusy ? null : _renderDemo,
            icon: const Icon(Icons.play_arrow),
            label: Text(_demoBusy ? 'Rendering…' : 'Render a demo'),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          OutlinedButton.icon(
            onPressed: _trySampleStory,
            icon: const Icon(Icons.auto_stories),
            label: const Text('Try a sample story (Haunted Night)'),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            'Free limits shown here are from the providers’ official pricing pages (24 Nov 2026).',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _pagePadding(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: child,
    );
  }

  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 20),
          const SizedBox(width: AppConstants.paddingSmall),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
