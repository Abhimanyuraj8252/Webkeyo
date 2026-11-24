/// Tests for the PDF lecture import: page -> scene cutting, audio-scene
/// sync math, and the best-effort PDF text extractor. No real PDF
/// rendering in tests (pdfx needs a device) — the planner is pure.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:webkeyo/services/pdf_lecture.dart';
import 'package:webkeyo/services/pdf_text_extractor.dart';
import 'package:webkeyo/services/subtitle_service.dart';

String _words(int count) =>
    List.filled(count, 'word').join(' ');

void main() {
  group('planPdfLecture', () {
    test('one short page -> one scene, in order', () {
      final plan = planPdfLecture(
        title: 'Lecture 1',
        pageCount: 3,
        pageTexts: ['Hello world', 'Second page here', 'Third page'],
      );
      expect(plan.scenes.length, 3);
      expect(plan.scenes.map((s) => s.pageIndex).toList(), [1, 2, 3]);
      expect(plan.scenes[0].narration, 'Hello world');
      expect(plan.scenes[0].codeDrawnFallback, isTrue);
    });

    test('a long page splits into several scenes', () {
      final plan = planPdfLecture(
        title: 'Long',
        pageCount: 1,
        pageTexts: [_words(400)],
      );
      // 400 words / 180 per scene = 3 scenes.
      expect(plan.scenes.length, 3);
      expect(plan.scenes.every((s) => s.pageIndex == 1), isTrue);
      for (final scene in plan.scenes) {
        expect(scene.narration.split(' ').length,
            lessThanOrEqualTo(pdfMaxWordsPerScene));
      }
    });

    test('a page with no text gets a bridge scene, not an empty cue', () {
      final plan = planPdfLecture(
        title: 'Slides',
        pageCount: 2,
        pageTexts: ['Some text', '   '],
      );
      expect(plan.scenes.length, 2);
      expect(plan.scenes[1].narration, isNotEmpty);
      expect(plan.scenes[1].estSeconds, pdfMinSceneSeconds);
    });

    test('page image paths attach to the right scenes', () {
      final plan = planPdfLecture(
        title: 'Slides',
        pageCount: 2,
        pageTexts: ['Page one', 'Page two'],
        pageImagePaths: ['/tmp/page_0001.png', null],
      );
      expect(plan.scenes[0].codeDrawnFallback, isFalse);
      expect(plan.scenes[0].imagePath, '/tmp/page_0001.png');
      expect(plan.scenes[1].codeDrawnFallback, isTrue);
      final script = plan.toScriptScenes();
      expect(script[0]['imagePath'], '/tmp/page_0001.png');
      expect(script[1].containsKey('imagePath'), isFalse);
    });

    test('zero pages and mismatched lists throw ArgumentError', () {
      expect(
        () => planPdfLecture(title: 'X', pageCount: 0, pageTexts: []),
        throwsArgumentError,
      );
      expect(
        () => planPdfLecture(
            title: 'X', pageCount: 2, pageTexts: ['only one']),
        throwsArgumentError,
      );
      expect(
        () => planPdfLecture(
              title: 'X',
              pageCount: 2,
              pageTexts: ['a', 'b'],
              pageImagePaths: ['only one'],
            ),
        throwsArgumentError,
      );
    });
  });

  group('audio-scene sync math', () {
    test('scene starts are cumulative and match the SRT', () {
      final plan = planPdfLecture(
        title: 'Sync',
        pageCount: 3,
        pageTexts: ['Hello world', 'Second page here', 'Third page'],
      );
      final starts = plan.sceneStarts();
      expect(starts[0], 0.0);
      expect(starts[1], closeTo(plan.scenes[0].estSeconds * 1.3, 0.001));
      expect(
        starts[2],
        closeTo(
            (plan.scenes[0].estSeconds + plan.scenes[1].estSeconds) * 1.3,
            0.001),
      );
      expect(plan.totalSeconds,
          closeTo(plan.scenes.fold<double>(0, (s, sc) => s + sc.estSeconds * 1.3), 0.001));

      // The SRT built from the same scenes agrees exactly.
      final srt = buildSrt(plan.toScriptScenes());
      expect(srt, startsWith('1\n00:00:00,000 --> '));
      expect(srt, contains(formatSrtTimestamp(starts[1])));
      expect(srt, contains(formatSrtTimestamp(starts[2])));
    });
  });

  group('extractPdfPageTexts', () {
    test('extracts text from a generated 2-page PDF, in order', () async {
      final doc = pw.Document();
      doc.addPage(pw.Page(
          build: (context) =>
              pw.Center(child: pw.Text('Hello page one'))));
      doc.addPage(pw.Page(
          build: (context) =>
              pw.Center(child: pw.Text('Second page text here'))));
      final bytes = await doc.save();
      final texts = extractPdfPageTexts(bytes);
      expect(texts.length, 2);
      expect(texts[0], contains('Hello page one'));
      expect(texts[1], contains('Second page text here'));
    });

    test('garbage bytes return an empty list, never throw', () {
      expect(
          extractPdfPageTexts(Uint8List.fromList([0, 1, 2, 3, 4])), isEmpty);
      expect(extractPdfPageTexts(Uint8List(0)), isEmpty);
    });
  });
}
