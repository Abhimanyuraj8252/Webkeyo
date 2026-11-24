/// Regression tests for the v1.2.2 prompt-video screen (25 Nov 2026).
///
/// The v1.2.1 crash was a layout error that shipped because no test
/// opened the screen and exercised its flows. These tests do exactly
/// that for the new screen: open it, pick purpose / character /
/// duration, open the scene editor, save — and assert no exception at
/// any step. No real render is started (TTS + FFmpeg need a device).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webkeyo/features/prompt_video/prompt_video_screen.dart';
import 'package:webkeyo/services/provider_registry.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<ProviderRegistry>.value(
        value: ProviderRegistry(),
        child: const PromptVideoScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('screen opens with all pickers and the render plan',
      (tester) async {
    await _pumpScreen(tester);
    expect(find.text('Style — see exactly how it will look'), findsOneWidget);
    expect(find.text('Purpose — what is this video for?'), findsOneWidget);
    expect(find.text('Character design — code-drawn, anime-like'),
        findsOneWidget);
    expect(find.text('Duration — no limit'), findsOneWidget);
    expect(find.text('Render plan'), findsOneWidget);
    // Default: 2-minute story reel -> 15 scenes.
    expect(find.textContaining('Planned: 2 min'), findsOneWidget);
    expect(find.textContaining('15 scenes'), findsOneWidget);
    expect(find.text('Render video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purpose chip changes pacing and the karaoke default',
      (tester) async {
    await _pumpScreen(tester);
    // Story starts with karaoke off.
    var karaoke =
        tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(karaoke.value, isFalse);
    await tester.ensureVisible(find.text('Lecture'));
    await tester.tap(find.text('Lecture'));
    await tester.pump();
    expect(find.textContaining('Long-form teaching'), findsOneWidget);
    karaoke = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(karaoke.value, isTrue);
    // Back to Story: karaoke off again, pacing back to 8s/scene.
    await tester.ensureVisible(find.text('Story'));
    await tester.tap(find.text('Story'));
    await tester.pump();
    karaoke = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(karaoke.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duration preset updates the plan card', (tester) async {
    await _pumpScreen(tester);
    await tester.ensureVisible(find.text('5 min'));
    await tester.tap(find.text('5 min'));
    await tester.pump();
    expect(find.textContaining('Planned: 5 min'), findsOneWidget);
    expect(find.textContaining('Planned: 2 min'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('character picker switches the selection', (tester) async {
    await _pumpScreen(tester);
    await tester.ensureVisible(find.text('Silhouette').last);
    await tester.tap(find.text('Silhouette').last);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty prompt shows a validation error, not a crash',
      (tester) async {
    await _pumpScreen(tester);
    await tester.ensureVisible(find.text('Render video'));
    await tester.tap(find.text('Render video'));
    await tester.pump();
    expect(find.textContaining('Write a one-line idea first'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('end to end: pick purpose + duration, edit scenes, save',
      (tester) async {
    await _pumpScreen(tester);
    await tester.enterText(
        find.byType(TextField).first, 'a boy enters a haunted inn');
    await tester.pump();
    await tester.ensureVisible(find.text('Lecture'));
    await tester.tap(find.text('Lecture'));
    await tester.pump();
    await tester.ensureVisible(find.text('5 min'));
    await tester.tap(find.text('5 min'));
    await tester.pump();
    await tester.ensureVisible(
        find.text('Edit scenes — trim, reorder, retime'));
    await tester.tap(find.text('Edit scenes — trim, reorder, retime'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Edit scenes'), findsOneWidget);
    expect(find.textContaining('Scene 1'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save scenes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Back on the prompt screen, with the edited scenes noted.
    expect(find.text('Prompt to Video'), findsOneWidget);
    expect(find.textContaining('Edited scenes:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
