import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';

/// A high-performance, low-latency file handling service for Webkeyo.
/// Encapsulates all OS-level file operations and manages heavy extraction tasks.
class FileService {
  /// Opens the native file picker to select CBZ, ZIP, or PDF files.
  Future<List<File>> pickFiles() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cbz', 'zip', 'pdf'],
      allowMultiple: true,
    );
    
    if (result != null && result.files.isNotEmpty) {
      return result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
    }
    return [];
  }

  /// Opens the native file picker to select a directory (folder).
  Future<String?> pickFolder() async {
    return await FilePicker.platform.getDirectoryPath();
  }

  /// Cleans up the specific temporary extracted directory to avoid memory leaks
  /// and excessive disk usage over time.
  Future<void> cleanupTempDirectory() async {
    final Directory tempDir = await getTemporaryDirectory();
    final Directory webkeyoDir = Directory(p.join(tempDir.path, 'webkeyo_extracted'));
    
    if (await webkeyoDir.exists()) {
      await webkeyoDir.delete(recursive: true);
    }
  }

  /// Extracts a PDF to images securely.
  Future<String?> extractPdf(File pdfFile) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String extractPath = p.join(
      tempDir.path, 
      'webkeyo_extracted', 
      p.basenameWithoutExtension(pdfFile.path)
    );

    final Directory extractDir = Directory(extractPath);
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    try {
      final document = await PdfDocument.openFile(pdfFile.path);
      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        // Render at 1080px width for good quality while keeping performance
        final double width = 1080.0;
        final double scale = width / page.width;
        final double height = page.height * scale;
        
        final PdfPageImage? pageImage = await page.render(
          width: width,
          height: height,
          format: PdfPageImageFormat.jpeg,
        );

        if (pageImage != null) {
          final String zeroPaddedIndex = i.toString().padLeft(4, '0');
          final File imageFile = File(p.join(extractPath, 'page_$zeroPaddedIndex.jpg'));
          await imageFile.writeAsBytes(pageImage.bytes);
        }
        await page.close();
      }
      await document.close();
      return extractPath;
    } catch (e) {
      debugPrint('PDF Extraction Error: $e');
      return null;
    }
  }

  /// Extracts the archive to a temporary folder securely.
  /// 
  /// **CRITICAL**: The extraction passes the file paths to a separate Isolate via `compute()`.
  /// This ensures that extracting massive manga CBZ files does not freeze the main Flutter UI thread,
  /// keeping the 60/120 FPS experience intact.
  Future<String?> extractArchive(File archiveFile) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String extractPath = p.join(
      tempDir.path, 
      'webkeyo_extracted', 
      p.basenameWithoutExtension(archiveFile.path)
    );

    // Ensure pristine extraction state for this specific file
    final Directory extractDir = Directory(extractPath);
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    // Hand off heavy IO and decompression task to background Isolate worker
    final bool success = await compute(_extractWorker, {
      'archivePath': archiveFile.path,
      'destinationPath': extractPath,
    });

    return success ? extractPath : null;
  }

  /// The Isolate worker function containing the synchronous extraction logic.
  /// Needs to be a top-level or static function to be accessible by the Isolate.
  static Future<bool> _extractWorker(Map<String, String> args) async {
    try {
      final String archivePath = args['archivePath']!;
      final String destinationPath = args['destinationPath']!;

      // archive_io's `extractFileToDisk` is highly optimized for sequential disk writes
      // doing this off the main thread ensures zero-stutter on UI.
      extractFileToDisk(archivePath, destinationPath);
      return true;
    } catch (e) {
      debugPrint('Isolate Extraction Error: $e');
      return false;
    }
  }

  /// Recursively scans the extraction directory, filters for image formats,
  /// and sorts them alphabetically so manga pages remain in exact reading order.
  Future<List<String>> getExtractedImages(String directoryPath) async {
    final Directory dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();
    final List<String> imagePaths = [];

    const List<String> allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

    for (var entity in entities) {
      if (entity is File) {
        final String ext = p.extension(entity.path).toLowerCase();
        if (allowedExtensions.contains(ext)) {
          imagePaths.add(entity.path);
        }
      }
    }

    // Sort alphabetically naturally (e.g. 001.jpg, 002.jpg). 
    // CBZ standard highly recommends zero-padded naming which sorts perfectly here.
    imagePaths.sort((a, b) => a.compareTo(b));

    return imagePaths;
  }
}
