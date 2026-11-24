/// PDF / lecture input — a PDF becomes a video, scene by scene.
///
/// Flow:
///   1. [planPdfLecture] (pure, unit-tested): given a page count and
///      per-page text, cut the PDF into scenes — one scene per page,
///      split again when a page is long. Every scene carries its
///      narration, its estimated seconds, and its start/end in the
///      final video, so audio, scene and captions stay in sync by
///      construction (the same cumulative timing the SRT builder uses).
///   2. [extractPdfPageImages] (device only): renders each page to a
///      PNG with pdfx (free, offline, already a dependency). A page
///      that fails to render gets a `null` image — the render then
///      falls back to a code-drawn scene for that page, never a crash.
///   3. [PdfLecturePlan.toScriptScenes] hands the scenes to
///      [renderPromptVideo] as `scenesOverride`; the render narrates
///      each page, shows its image, and burns the page text as the
///      caption — the whole video is built by itself.
///
/// No usable text on a page is fine: the scene gets a short narrator
/// bridge line instead of an empty cue. A bad PDF (unreadable, zero
/// pages) throws a clear [ArgumentError] from the planner and a
/// friendly error from the extractor — the screen shows it, the app
/// never dies.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';

/// Words per scene at most — a long page is cut into several scenes so
/// no single scene runs too long and the narration stays paced.
const pdfMaxWordsPerScene = 180;

/// Estimated spoken seconds per word of narration (~2.5 words/sec).
const pdfWordsPerSecond = 2.5;

/// Shortest scene, in estimated seconds.
const pdfMinSceneSeconds = 4.0;

/// One scene cut from a PDF page.
class PdfLectureScene {
  /// 1-based page this scene came from.
  final int pageIndex;

  /// Narration for the scene (page text, or a bridge line).
  final String narration;

  /// Estimated narration seconds (before the 1.3 render stretch).
  final double estSeconds;

  /// Rendered page image for this scene, if extraction succeeded.
  final String? imagePath;

  /// True when there is no page image — the render draws a
  /// code-drawn scene instead.
  bool get codeDrawnFallback => imagePath == null;

  const PdfLectureScene({
    required this.pageIndex,
    required this.narration,
    required this.estSeconds,
    this.imagePath,
  });

  Map<String, dynamic> toScriptScene() {
    return <String, dynamic>{
      'speaker': 'Narrator',
      'emotion': 'calm',
      'narration': narration,
      'est_seconds': estSeconds,
      if (imagePath != null) 'imagePath': imagePath,
    };
  }
}

/// The full plan for turning a PDF into a video.
class PdfLecturePlan {
  final String title;
  final int pageCount;
  final List<PdfLectureScene> scenes;

  const PdfLecturePlan({
    required this.title,
    required this.pageCount,
    required this.scenes,
  });

  /// Total rendered video length in seconds (est x 1.3 per scene).
  double get totalSeconds =>
      scenes.fold<double>(0, (sum, s) => sum + s.estSeconds * 1.3);

  /// Start (seconds) of each scene in the final video — the same
  /// cumulative timing the SRT builder uses, so audio, scene and
  /// captions agree exactly.
  List<double> sceneStarts() {
    final starts = <double>[];
    var cursor = 0.0;
    for (final s in scenes) {
      starts.add(cursor);
      cursor += s.estSeconds * 1.3;
    }
    return starts;
  }

  List<Map<String, dynamic>> toScriptScenes() =>
      scenes.map((s) => s.toScriptScene()).toList();
}

/// Cut a PDF into scenes. [pageTexts] is the text of each page in
/// order (empty string for a page with no extractable text).
/// [pageImagePaths], when given, is aligned with the pages — a `null`
/// entry means "no image for this page" (code-drawn fallback).
///
/// Throws [ArgumentError] when [pageCount] is 0 or the lists disagree
/// with it. Pure — no file or platform access, so it is unit-tested
/// without a real PDF.
PdfLecturePlan planPdfLecture({
  required String title,
  required int pageCount,
  required List<String> pageTexts,
  List<String?>? pageImagePaths,
}) {
  if (pageCount <= 0) {
    throw ArgumentError('PDF has no pages — nothing to turn into a video.');
  }
  if (pageTexts.length != pageCount) {
    throw ArgumentError(
        'Expected $pageCount page texts, got ${pageTexts.length}.');
  }
  if (pageImagePaths != null && pageImagePaths.length != pageCount) {
    throw ArgumentError(
        'Expected $pageCount page image paths, got ${pageImagePaths.length}.');
  }
  final scenes = <PdfLectureScene>[];
  for (var page = 0; page < pageCount; page++) {
    final imagePath = pageImagePaths == null ? null : pageImagePaths[page];
    final rawText = pageTexts[page].trim();
    if (rawText.isEmpty) {
      // A page with no text (photo/diagram page) still gets a scene:
      // the narrator bridges it and the page image carries the visual.
      scenes.add(PdfLectureScene(
        pageIndex: page + 1,
        narration: 'Is page par ek tasveer ya diagram hai — dhyaan se dekhiye.',
        estSeconds: pdfMinSceneSeconds,
        imagePath: imagePath,
      ));
      continue;
    }
    final words = rawText.split(RegExp(r'\s+'));
    var offset = 0;
    while (offset < words.length) {
      final chunk = words.skip(offset).take(pdfMaxWordsPerScene).toList();
      offset += chunk.length;
      final est = (chunk.length / pdfWordsPerSecond)
          .clamp(pdfMinSceneSeconds, double.infinity);
      scenes.add(PdfLectureScene(
        pageIndex: page + 1,
        narration: chunk.join(' '),
        estSeconds: est,
        imagePath: imagePath,
      ));
    }
  }
  return PdfLecturePlan(title: title, pageCount: pageCount, scenes: scenes);
}

/// Render every page of [pdfPath] to a PNG in [outDir] (one file per
/// page, `page_0001.png`, …). Returns a list aligned with the pages:
/// the image path, or `null` when that page failed to render.
///
/// Never throws for a bad page — each page is guarded, so one corrupt
/// page cannot kill the import. Throws only when the PDF itself cannot
/// be opened at all (caller shows the message).
Future<List<String?>> extractPdfPageImages({
  required String pdfPath,
  required String outDir,
  double scale = 1.5,
}) async {
  final document = await PdfDocument.openFile(pdfPath);
  final dir = Directory(outDir);
  if (!await dir.exists()) await dir.create(recursive: true);
  final images = <String?>[];
  try {
    for (var i = 1; i <= document.pagesCount; i++) {
      try {
        final page = await document.getPage(i);
        try {
          final pageImage = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: PdfPageImageFormat.png,
          );
          if (pageImage == null) {
            images.add(null);
            continue;
          }
          final file = File(p.join(
              outDir, 'page_${i.toString().padLeft(4, '0')}.png'));
          await file.writeAsBytes(pageImage.bytes);
          images.add(file.path);
        } finally {
          await page.close();
        }
      } catch (_) {
        // One bad page -> code-drawn fallback for it; keep going.
        images.add(null);
      }
    }
  } finally {
    await document.close();
  }
  return images;
}
