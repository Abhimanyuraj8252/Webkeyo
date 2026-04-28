import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:path/path.dart' as p;
import 'dart:ui' as ui;

class ConversionService {
  /// Extracts a CBZ/ZIP file to a specified output directory.
  /// Returns a list of extracted image file paths, sorted alphabetically.
  static Future<List<String>> cbzToImages(String cbzPath, String outputDirPath) async {
    final bytes = await File(cbzPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    final outputDir = Directory(outputDirPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    List<String> extractedFiles = [];

    for (final file in archive) {
      if (file.isFile) {
        final ext = p.extension(file.name).toLowerCase();
        if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
          final data = file.content as List<int>;
          final outFile = File(p.join(outputDirPath, p.basename(file.name)));
          await outFile.writeAsBytes(data);
          extractedFiles.add(outFile.path);
        }
      }
    }

    // Sort to maintain chapter/page order
    extractedFiles.sort((a, b) => a.compareTo(b));
    return extractedFiles;
  }

  /// Converts a PDF document into a list of image files (PNG).
  /// Saves the images to the specified output directory.
  static Future<List<String>> pdfToImages(String pdfPath, String outputDirPath) async {
    final document = await PdfDocument.openFile(pdfPath);
    
    final outputDir = Directory(outputDirPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    List<String> imagePaths = [];

    for (int i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);
      
      // Render at a high resolution (e.g., 2.0 scale for better quality)
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );

      if (pageImage != null) {
        final imgFile = File(p.join(outputDirPath, 'page_${i.toString().padLeft(4, '0')}.png'));
        await imgFile.writeAsBytes(pageImage.bytes);
        imagePaths.add(imgFile.path);
      }
      await page.close();
    }
    
    await document.close();
    return imagePaths;
  }

  /// Converts a CBZ file into a PDF without compression or margins.
  /// Creates a PDF where each page is exactly the size of the image it contains.
  static Future<String> cbzToPdf(String cbzPath, String outputPdfPath) async {
    final images = await cbzToImages(cbzPath, p.join(p.dirname(outputPdfPath), 'temp_cbz_extract_${DateTime.now().millisecondsSinceEpoch}'));
    
    final pdf = pw.Document();

    for (String imgPath in images) {
      final file = File(imgPath);
      final bytes = await file.readAsBytes();
      
      // Decode the image to get its exact pixel dimensions
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width.toDouble();
      final height = frame.image.height.toDouble();

      final pdfImage = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width, height, marginAll: 0),
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
            );
          },
        ),
      );
    }

    final pdfBytes = await pdf.save();
    final outFile = File(outputPdfPath);
    await outFile.writeAsBytes(pdfBytes);

    // Cleanup extracted temp images
    if (images.isNotEmpty) {
      final tempDir = Directory(p.dirname(images.first));
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }

    return outputPdfPath;
  }
}
