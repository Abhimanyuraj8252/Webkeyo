import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../services/file_service.dart';

/// The core state manager for the file handling pipeline of Webkeyo.
/// Implements `ChangeNotifier` minimally while preventing tightly coupled UI blocks.
class ProcessProvider extends ChangeNotifier {
  final FileService _fileService = FileService();

  // State Tracking Elements
  bool _isLoading = false;
  String _statusMessage = 'Ready';
  List<String> _extractedImages = [];

  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  List<String> get extractedImages => List.unmodifiable(_extractedImages); // Defensive encapsulation

  /// Internal precise state update function to avoid duplicate/heavy re-renders.
  void _updateState({required bool loading, required String message}) {
    _isLoading = loading;
    _statusMessage = message;
    notifyListeners();
  }

  /// Triggers the full File Selection -> Temporary Cleanup -> Background Extraction -> Image Resolution pipeline.
  /// Wrapped entirely in clean error handling to guarantee safe fallback mechanics.
  Future<void> startFileProcess() async {
    try {
      _updateState(loading: true, message: 'Selecting file...');

      final List<File> pickedFiles = await _fileService.pickFiles();

      if (pickedFiles.isEmpty) {
        _updateState(loading: false, message: 'Selection cancelled.');
        return;
      }

      // Proactively nuke previous cache entirely to evade memory bloat
      _updateState(loading: true, message: 'Cleaning temporary storage...');
      await _fileService.cleanupTempDirectory();

      // Hand off the extremely large CBZ/ZIP operation structurally to the background Isolate
      _updateState(
        loading: true, 
        message: 'Extracting archive in background... UI remains smooth.'
      );
      
      final String? extractionPath = await _fileService.extractArchive(pickedFiles.first);

      if (extractionPath == null) {
        _updateState(loading: false, message: 'Failed to extract the archive safely.');
        return;
      }

      _updateState(loading: true, message: 'Sorting manga pages...');
      
      final List<String> images = await _fileService.getExtractedImages(extractionPath);

      if (images.isEmpty) {
        _updateState(loading: false, message: 'No valid manga images found inside the archive.');
        return;
      }

      // Safely assign extracted payload
      _extractedImages = images;

      _updateState(
        loading: false, 
        message: 'Successfully processed ${images.length} pages.'
      );

    } catch (e, stackTrace) {
      debugPrint('Error triggering file extraction pipeline: $e\n$stackTrace');
      _updateState(
        loading: false, 
        message: 'An unexpected critical error occurred while processing.'
      );
    }
  }

  /// Exposes a manual shutdown mechanism to unmount/delete files immediately if needed.
  Future<void> clearSession() async {
    _extractedImages = [];
    _updateState(loading: true, message: 'Clearing session...');
    await _fileService.cleanupTempDirectory();
    _updateState(loading: false, message: 'Ready');
  }
}
