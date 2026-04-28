import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FaceDetectionService {
  static Future<List<String>> extractFacesFromImages(List<String> imagePaths) async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: false,
        enableClassification: false,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    final List<String> extractedFacePaths = [];
    final tempDir = await getTemporaryDirectory();
    final outDir = Directory(p.join(tempDir.path, 'extracted_faces_${DateTime.now().millisecondsSinceEpoch}'));
    await outDir.create(recursive: true);

    int faceIndex = 0;

    for (String path in imagePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      try {
        final inputImage = InputImage.fromFile(file);
        final List<Face> faces = await faceDetector.processImage(inputImage);

        if (faces.isEmpty) continue;

        // Decode image for cropping
        final bytes = await file.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image == null) continue;

        for (Face face in faces) {
          final rect = face.boundingBox;
          
          // Add some padding to the face bounding box
          final paddingX = (rect.width * 0.2).toInt();
          final paddingY = (rect.height * 0.2).toInt();
          
          final x = (rect.left.toInt() - paddingX).clamp(0, image.width);
          final y = (rect.top.toInt() - paddingY).clamp(0, image.height);
          final w = (rect.width.toInt() + paddingX * 2).clamp(0, image.width - x);
          final h = (rect.height.toInt() + paddingY * 2).clamp(0, image.height - y);

          // Skip if bounding box is invalid or too small
          if (w <= 0 || h <= 0) continue;

          final croppedFace = img.copyCrop(image, x: x, y: y, width: w, height: h);
          
          final outPath = p.join(outDir.path, 'face_${faceIndex++}.jpg');
          final outFile = File(outPath);
          await outFile.writeAsBytes(img.encodeJpg(croppedFace));
          
          extractedFacePaths.add(outPath);
          
          // Limit to max 20 faces total to prevent huge memory usage or long processing
          if (extractedFacePaths.length >= 20) {
            break;
          }
        }
      } catch (e) {
        debugPrint('Error processing image for faces: $e');
      }

      if (extractedFacePaths.length >= 20) {
        break;
      }
    }

    faceDetector.close();
    return extractedFacePaths;
  }
}
