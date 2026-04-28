import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

/// Advanced FFmpeg rendering service.
/// Processes segmented scene generation and combination to prevent OOM errors
/// on mobile devices, applying a cinematic Ken Burns effect to static images.
class FfmpegService {
  /// Renders a full video by generating intermediate scene mp4s and concatenating them.
  ///
  /// [syncData] expects maps with 'image_path', 'audio_path', and 'duration_in_seconds'.
  /// [outputDirectory] is the root directory to store the final output.
  /// [projectName] is used for creating unique project folders and file names.
  /// [onProgress] returns a 0.0 to 1.0 double indicating overall rendering progress.
  Future<String?> renderFinalVideo({
    required List<Map<String, dynamic>> syncData,
    required String outputDirectory,
    required String projectName,
    required Function(double) onProgress,
  }) async {
    // Force export to public Movies directory on Android
    final String publicExportDir = '/storage/emulated/0/Movies/Webkeyo';
    final Directory exportDirObj = Directory(publicExportDir);
    if (!await exportDirObj.exists()) {
      try {
        await exportDirObj.create(recursive: true);
      } catch (e) {
        debugPrint("Could not create public directory, falling back to app dir: $e");
      }
    }
    
    // We use the app's directory for temporary chunks to avoid cluttering public storage
    final String projectDir = p.join(outputDirectory, projectName);
    final Directory dir = Directory(projectDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final List<String> intermediateFiles = [];
    final int totalScenes = syncData.length;

    try {
      // Step A & B & C: Loop through syncData and render each scene
      for (int i = 0; i < totalScenes; i++) {
        final sceneData = syncData[i];
        final String imagePath = sceneData['image_path'];
        final String audioPath = sceneData['audio_path'];
        final double duration = sceneData['duration_in_seconds'];

        final String tempScenePath = p.join(projectDir, 'scene_$i.mp4');
        intermediateFiles.add(tempScenePath);

        // FFmpeg configuration
        const int fps = 25;
        final int totalFrames = (duration * fps).ceil();

        // Analyze image dimensions to determine panning strategy
        bool isPortrait = false;
        try {
          final imageBytes = await File(imagePath).readAsBytes();
          final decodedImage = img.decodeImage(imageBytes);
          if (decodedImage != null) {
            // If height is at least 1.2x width, treat it as tall/portrait manga
            isPortrait = decodedImage.height > (decodedImage.width * 1.2);
          }
        } catch (e) {
          debugPrint("Failed to decode image dimensions for panning: $e");
        }

        // High-performance filter strategy:
        // Landscape: zoompan zooming slightly into center
        // Portrait (Manga): scale width to 1920 (height will be huge), then zoompan sliding Y from 0 to bottom
        String filterComplex;
        if (isPortrait) {
          // Scale image so width is 1920. 
          // Then zoompan: z=1 (no zoom), x=0, y slides from 0 down to the bottom
          filterComplex = 
              "scale=1920:-1,"
              "zoompan=z='1.0':y='(ih-1080)*(on/$totalFrames)':x='0':d=$totalFrames:s=1920x1080,"
              "format=yuv420p";
        } else {
          // Zoom in slightly for landscape
          filterComplex = 
              "scale=1920:1080:force_original_aspect_ratio=increase,"
              "crop=1920:1080,"
              "zoompan=z='1.15':d=$totalFrames:s=1920x1080,"
              "format=yuv420p";
        }

        final String command = "-loop 1 -framerate $fps -t $duration "
            "-i \"$imagePath\" "
            "-i \"$audioPath\" "
            "-vf \"$filterComplex\" "
            "-c:v libx264 -preset veryfast -tune stillimage "
            "-c:a aac -b:a 192k -shortest -y \"$tempScenePath\"";

        debugPrint("Executing FFmpeg for Scene $i:\n$command");

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (!ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getLogsAsString();
          debugPrint("FFmpeg Error logs for Scene $i: $logs");
          throw Exception('FFmpeg failed to render scene $i.');
        }

        // Report progress (reserving 10% for the final concatenation step)
        onProgress((i + 1) / totalScenes * 0.9);
      }

      // Step D: Generate concat.txt
      final String concatFilePath = p.join(projectDir, 'concat.txt');
      final File concatFile = File(concatFilePath);
      final StringBuffer concatContent = StringBuffer();

      for (String file in intermediateFiles) {
        // FFmpeg safe format string requires forward slashes and exact single quotes
        final String safePath = file.replaceAll(Platform.pathSeparator, '/');
        concatContent.writeln("file '$safePath'");
      }
      await concatFile.writeAsString(concatContent.toString());

      // Step E: Run concat demuxer
      // Final video export path
      final String finalVideoPath = p.join(
        exportDirObj.existsSync() ? publicExportDir : outputDirectory, 
        '${projectName}_final.mp4'
      );
      final String concatCommand = "-f concat -safe 0 -i \"$concatFilePath\" -c copy -y \"$finalVideoPath\"";

      debugPrint("Executing FFmpeg Concat:\n$concatCommand");

      final concatSession = await FFmpegKit.execute(concatCommand);
      final concatReturnCode = await concatSession.getReturnCode();

      if (!ReturnCode.isSuccess(concatReturnCode)) {
        final logs = await concatSession.getLogsAsString();
        debugPrint("FFmpeg Concat Error logs: $logs");
        throw Exception('FFmpeg failed to concatenate the final video.');
      }

      onProgress(1.0); // 100% complete

      // Step F: Cleanup intermediate assets to immediately free up user storage
      _cleanupIntermediateFiles(intermediateFiles, concatFile);

      return finalVideoPath;
    } catch (e, stacktrace) {
      debugPrint("Fatal Error rendering final video: $e\\n$stacktrace");
      // Attempt cleanup on failure so we don't leave massive temporary .mp4s
      _cleanupIntermediateFiles(intermediateFiles, File(p.join(projectDir, 'concat.txt')));
      rethrow;
    }
  }

  /// Silently cleans up massive intermediary mp4 chunks and text files securely.
  void _cleanupIntermediateFiles(List<String> files, File? concatTxt) {
    try {
      for (String path in files) {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      }
      if (concatTxt != null && concatTxt.existsSync()) {
        concatTxt.deleteSync();
      }
    } catch (e) {
      debugPrint("Cleanup error (Non-fatal): $e");
    }
  }
}
