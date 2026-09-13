import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants.dart';
import '../../../services/provider_registry.dart';
import '../../../services/srt_service.dart';

/// Full-screen video preview with playback controls, share, SRT export.
class VideoPreviewScreen extends StatefulWidget {
  final String videoPath;
  final String projectName;

  /// Optional project id — enables SRT export (needs script + audio data).
  final String? projectId;

  const VideoPreviewScreen({
    super.key,
    required this.videoPath,
    required this.projectName,
    this.projectId,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _controllerCreated = false;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _srtBusy = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final file = File(widget.videoPath);
    if (!file.existsSync()) {
      setState(() => _errorMessage = 'Video file not found at:\n${widget.videoPath}');
      return;
    }

    _controller = VideoPlayerController.file(file);
    _controllerCreated = true;

    try {
      await _controller.initialize();
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load video: $e');
    }
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  void dispose() {
    if (_controllerCreated) _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _shareVideo() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.videoPath)],
          text: '${widget.projectName} — Created with Webkeyo',
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  Future<void> _exportSrt() async {
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    if (widget.projectId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('SRT export is available from a project.')),
      );
      return;
    }

    final project = registry.projectsBox.get(widget.projectId!);
    if (project == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Project not found.')),
      );
      return;
    }

    setState(() => _srtBusy = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final audioDir = p.join(tempDir.path, 'webkeyo_audio_${project.id}');
      final srtPath = await SrtService.generateSrt(
        projectId: project.id,
        audioDir: audioDir,
        scriptJson: project.generatedScript,
        outputDir: tempDir.path,
      );

      if (srtPath == null) {
        messenger.showSnackBar(
          const SnackBar(
              content:
                  Text('Could not build SRT — script or scene audio missing.')),
        );
        return;
      }

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save subtitles (SRT)',
        fileName: '${project.title}_subtitles.srt',
        initialDirectory: (await getExternalStorageDirectory())?.path,
        type: FileType.custom,
        allowedExtensions: ['srt'],
      );

      if (result != null) {
        await File(result).writeAsBytes(await File(srtPath).readAsBytes());
      }
      messenger.showSnackBar(
        SnackBar(content: Text(result != null ? 'SRT saved to $result' : 'SRT generated (save cancelled)')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('SRT export failed: $e')));
    } finally {
      if (mounted) setState(() => _srtBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.projectName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          if (widget.projectId != null)
            IconButton(
              icon: _srtBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.subtitles_rounded),
              tooltip: 'Export subtitles (SRT)',
              onPressed: _srtBusy ? null : _exportSrt,
            ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareVideo,
            tooltip: 'Share Video',
          ),
        ],
      ),
      body: _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingXLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.redAccent.withAlpha(178)),
                    const SizedBox(height: AppConstants.paddingLarge),
                    Text(
                      _errorMessage,
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : !_isInitialized
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: AppConstants.paddingMedium),
                      Text('Loading video...', style: GoogleFonts.inter(color: Colors.white54)),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video Player
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),

                      // Play/Pause Overlay
                      AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(76),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 64,
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlay,
                          ),
                        ),
                      ),

                      // Bottom Controls
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedOpacity(
                          opacity: _showControls ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.paddingLarge,
                              vertical: AppConstants.paddingMedium,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withAlpha(204),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Progress bar
                                VideoProgressIndicator(
                                  _controller,
                                  allowScrubbing: true,
                                  colors: VideoProgressColors(
                                    playedColor: colorScheme.primary,
                                    bufferedColor: Colors.white24,
                                    backgroundColor: Colors.white12,
                                  ),
                                ),
                                const SizedBox(height: AppConstants.paddingSmall),
                                // Duration text
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(_controller.value.position),
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                    ),
                                    Text(
                                      _formatDuration(_controller.value.duration),
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: _isInitialized
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _shareVideo,
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingMedium),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Video saved at: ${widget.videoPath}'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_alt_rounded),
                        label: const Text('Saved'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
              ),
            )
          : null,
    );
  }
}
