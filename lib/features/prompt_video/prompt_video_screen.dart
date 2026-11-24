/// Prompt-to-video screen — one line in, reel/video out, ₹0.
///
/// Renders on the phone with the code-drawn motion-graphics engine
/// (PromptVideoService): 10 styles, hook title, burned English
/// subtitles, speaker/emotion chip, progress bar, narration + SFX.
/// The voiceover uses the TTS provider set in Settings (AI Providers >
/// TTS). No key set yet? Edge TTS is free and built in.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../models/ai_provider_model.dart';
import '../../models/video_style.dart';
import '../../services/prompt_video_service.dart';
import '../../services/provider_registry.dart';
import '../../services/script_generator.dart';
import '../../services/tts_service.dart';

class PromptVideoScreen extends StatefulWidget {
  final String? initialPrompt;
  final String? initialGenre;
  final String? initialStyle;

  const PromptVideoScreen({
    super.key,
    this.initialPrompt,
    this.initialGenre,
    this.initialStyle,
  });

  @override
  State<PromptVideoScreen> createState() => _PromptVideoScreenState();
}

class _PromptVideoScreenState extends State<PromptVideoScreen> {
  late final TextEditingController _promptController;
  String _genre = defaultGenre;
  String _style = 'cinematic-dark';
  bool _vertical = true;
  bool _busy = false;
  String _progressLabel = '';
  double _progress = 0;
  PromptVideoResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.initialPrompt ?? '');
    if (widget.initialGenre != null && genres.containsKey(widget.initialGenre)) {
      _genre = widget.initialGenre!;
    }
    if (widget.initialStyle != null) {
      try {
        getVideoStyle(widget.initialStyle!);
        _style = widget.initialStyle!;
      } catch (_) {
        // Unknown style id — keep the default.
      }
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _render() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = 'Write a one-line idea first, e.g. "a boy enters a haunted inn".');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _progress = 0;
      _progressLabel = 'Starting…';
    });
    try {
      // Voiceover provider: first enabled TTS provider, else Edge TTS
      // (free, no key). Keys come only from Settings — never hardcoded.
      final registry = context.read<ProviderRegistry>();
      final ttsProviders =
          registry.getProvidersByCategory(ProviderCategory.tts);
      AIProviderModel? provider = ttsProviders
          .where((p) => p.isEnabled)
          .firstOrNull;
      provider ??= ttsProviders.where((p) => p.id == 'edge_tts').firstOrNull;
      provider ??= ttsProviders.firstOrNull;
      final tts = TtsService(
        providerId: provider?.id ?? 'edge_tts',
        apiKey: provider?.apiKey,
        baseUrl: provider?.customBaseUrl,
      );

      final docs = await getApplicationDocumentsDirectory();
      final outDir =
          '${docs.path}/prompt_videos/${DateTime.now().millisecondsSinceEpoch}';
      await Directory(outDir).create(recursive: true);

      final result = await renderPromptVideo(
        prompt: prompt,
        genre: _genre,
        styleId: _style,
        outDir: outDir,
        tts: tts,
        vertical: _vertical,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progressLabel = progress.stage;
              _progress = progress.fraction;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Prompt to Video')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One line in, reel out — ₹0. Code-drawn motion graphics, '
                'no stock video, no paid API.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Your idea (one line)',
                  hintText: 'a boy enters a haunted inn where the waiter is not human',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Row(
                children: [
                  Expanded(child: _dropdown(
                    label: 'Genre',
                    value: _genre,
                    items: genreIds,
                    labelOf: (id) => genres[id]!.label,
                    onChanged: (v) => setState(() => _genre = v!),
                  )),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(child: _dropdown(
                    label: 'Style',
                    value: _style,
                    items: styleIds,
                    labelOf: (id) => getVideoStyle(id).label,
                    onChanged: (v) => setState(() => _style = v!),
                  )),
                ],
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Vertical 9:16'), icon: Icon(Icons.phone_android)),
                        ButtonSegment(value: false, label: Text('Horizontal 16:9'), icon: Icon(Icons.tv)),
                      ],
                      selected: {_vertical},
                      onSelectionChanged: (s) => setState(() => _vertical = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Text(
                'Length follows the script — each scene runs as long as its narration (Hindi audio runs ~1.3× the written line).',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _render,
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: Text(_busy ? 'Rendering…' : 'Render video'),
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                LinearProgressIndicator(value: _progress.clamp(0.0, 1.0)),
                const SizedBox(height: 8),
                Text(_progressLabel, style: theme.textTheme.bodySmall),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ],
              if (_result != null) _buildResult(theme),
              const SizedBox(height: AppConstants.paddingMedium),
              Text(
                'Voiceover uses the TTS provider set in Settings (AI Providers > TTS). '
                'No key set yet? Edge TTS is free and built in. '
                'Sarvam (₹100 free credit) is the default Hindi voice; '
                'Deepgram Flux gives a \$200 free credit with Hindi voices.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) labelOf,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),
      items: items
          .map((id) => DropdownMenuItem(value: id, child: Text(labelOf(id))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildResult(ThemeData theme) {
    final videoPath = _result!.videoPath;
    final thumbnailPath = _result!.thumbnailPath;
    final srtPath = _result!.srtPath;
    final title = _promptController.text.trim();
    final duration = _result!.durationSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.paddingLarge),
        Text('Done — your video is ready', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppConstants.paddingSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          child: Image.file(File(thumbnailPath)),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        Text(title, style: theme.textTheme.titleSmall),
        Text(
          '${_result!.sceneCount} scenes • ${duration.toStringAsFixed(1)}s',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        _pathRow(theme, 'Video', videoPath),
        _pathRow(theme, 'Subtitles', srtPath),
        const SizedBox(height: AppConstants.paddingMedium),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(files: [XFile(videoPath)], text: title),
                ),
                icon: const Icon(Icons.share),
                label: const Text('Share video'),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: videoPath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video path copied')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy path'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pathRow(ThemeData theme, String label, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(path, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
