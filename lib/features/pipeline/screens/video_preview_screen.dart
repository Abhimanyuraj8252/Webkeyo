import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants.dart';

/// Full-screen video preview with playback controls, share, and save.
class VideoPreviewScreen extends StatefulWidget {
  final String videoPath;
  final String projectName;

  const VideoPreviewScreen({
    super.key,
    required this.videoPath,
    required this.projectName,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
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

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
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
                            onPressed: () {
                              setState(() {
                                _controller.value.isPlaying
                                    ? _controller.pause()
                                    : _controller.play();
                              });
                            },
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
