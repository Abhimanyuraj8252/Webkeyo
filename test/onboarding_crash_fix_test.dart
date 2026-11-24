/// Regression tests for the v1.2.0 "crash on open" report (25 Nov 2026).
///
/// 1. Onboarding page 2 ("Pick your voice") used Expanded inside a
///    SingleChildScrollView, which throws an unbounded-height layout
///    error as soon as the PageView builds the neighbouring page on
///    first run. This test swipes to that page and asserts no error.
/// 2. A boot failure (e.g. storage that cannot open) must show the
///    "could not start" screen with Retry — never a dead app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/features/onboarding/onboarding_screen.dart';
import 'package:webkeyo/main.dart';

void main() {
  testWidgets('onboarding voice-picker page builds without layout error',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen()),
    );
    await tester.pumpAndSettle();
    // Swipe to page 2 (voice picker).
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('Pick your voice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boot failure shows the error screen, not a dead app',
      (tester) async {
    // In a widget test there is no platform storage, so Hive.initFlutter
    // fails and the boot must land on the failed screen.
    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();
    expect(find.text('Webkeyo could not start.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
