/// Scene-by-scene editor — trim, reorder, re-time, change transitions,
/// edit narration. Every change re-derives the timings, so audio,
/// scene and captions stay in sync automatically.
///
/// The screen takes the planned scenes, lets the user edit them, and
/// returns the edited list (script-scene shape) for a re-render via
/// `renderPromptVideo(scenesOverride: ...)`. Cancelling returns null.
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/scene_editor.dart';
import '../../services/video_duration.dart';

class SceneEditorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> scenes;
  final String title;

  const SceneEditorScreen({
    super.key,
    required this.scenes,
    required this.title,
  });

  @override
  State<SceneEditorScreen> createState() => _SceneEditorScreenState();
}

class _SceneEditorScreenState extends State<SceneEditorScreen> {
  late final VideoEditSession _session;

  @override
  void initState() {
    super.initState();
    _session = VideoEditSession.fromScriptScenes(widget.scenes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timings = _session.sceneTimings();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit scenes'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_session.toScriptScenes()),
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${_session.scenes.length} scenes • total ${formatDuration(_session.totalSeconds)} • '
                    'audio, scene and captions re-sync automatically after every edit.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingLarge),
                itemCount: _session.scenes.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() => _session.moveScene(oldIndex, newIndex));
                },
                itemBuilder: (context, index) {
                  final scene = _session.scenes[index];
                  final timing = timings[index];
                  return Card(
                    key: ValueKey('scene_${scene.sceneNumber}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Scene ${index + 1} • ${scene.speaker} • ${scene.emotion}',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                '${formatDuration(timing.startSeconds)} – ${formatDuration(timing.endSeconds)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _editNarration(index),
                            child: Text(
                              scene.narration.isEmpty
                                  ? '(no narration — tap to add)'
                                  : scene.narration,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Length'),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Shorten by 1s',
                                onPressed: () => setState(() =>
                                    _session.adjustSceneSeconds(index, -1)),
                              ),
                              Text('${scene.renderedSeconds.toStringAsFixed(1)}s'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Lengthen by 1s',
                                onPressed: () => setState(() =>
                                    _session.adjustSceneSeconds(index, 1)),
                              ),
                              const Spacer(),
                              DropdownButton<String>(
                                value: scene.transition,
                                items: sceneTransitions
                                    .map((t) => DropdownMenuItem(
                                        value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _session.setTransition(index, v));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_session.toScriptScenes()),
                  icon: const Icon(Icons.check),
                  label: const Text('Save scenes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNarration(int index) async {
    final controller =
        TextEditingController(text: _session.scenes[index].narration);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scene ${index + 1} narration'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'What the narrator says in this scene',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited != null && mounted) {
      setState(() {
        _session.scenes[index].narration = edited;
        // Keep the estimate in step with the new words (~2.5 words/sec).
        final words = edited.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        if (words > 0) {
          _session.scenes[index].estSeconds =
              (words / 2.5).clamp(minSceneSeconds, maxSceneSeconds);
        }
      });
    }
  }
}
