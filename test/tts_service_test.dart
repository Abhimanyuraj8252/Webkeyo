import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/tts_service.dart';

void main() {
  group('mapTtsLanguage', () {
    test('maps common display languages', () {
      expect(mapTtsLanguage('Hinglish'), 'hi-IN');
      expect(mapTtsLanguage('Hindi'), 'hi-IN');
      expect(mapTtsLanguage('English'), 'en-US');
      expect(mapTtsLanguage('Japanese'), 'ja-JP');
      expect(mapTtsLanguage('Korean'), 'ko-KR');
      expect(mapTtsLanguage('Spanish'), 'es-ES');
      expect(mapTtsLanguage('French'), 'fr-FR');
      expect(mapTtsLanguage('German'), 'de-DE');
    });

    test('covers every language the home screen offers', () {
      // These are the 17 languages offered in HomeScreen — each must map to
      // a real locale, never silently fall back to en-US (except English).
      expect(mapTtsLanguage('Portuguese'), 'pt-BR');
      expect(mapTtsLanguage('Arabic'), 'ar-SA');
      expect(mapTtsLanguage('Chinese'), 'zh-CN');
      expect(mapTtsLanguage('Italian'), 'it-IT');
      expect(mapTtsLanguage('Russian'), 'ru-RU');
      expect(mapTtsLanguage('Turkish'), 'tr-TR');
      expect(mapTtsLanguage('Vietnamese'), 'vi-VN');
      expect(mapTtsLanguage('Indonesian'), 'id-ID');
      expect(mapTtsLanguage('Thai'), 'th-TH');
    });

    test('unknown languages fall back to en-US', () {
      expect(mapTtsLanguage('Klingon'), 'en-US');
      expect(mapTtsLanguage(''), 'en-US');
    });
  });

  group('edgeVoiceForLocale', () {
    test('returns a voice for every mapped locale', () {
      for (final locale in [
        'hi-IN', 'en-US', 'ja-JP', 'ko-KR', 'es-ES', 'fr-FR', 'de-DE',
        'pt-BR', 'ar-SA', 'zh-CN', 'it-IT', 'ru-RU', 'tr-TR', 'vi-VN',
        'id-ID', 'th-TH',
      ]) {
        final voice = edgeVoiceForLocale(locale);
        expect(voice, isNotEmpty);
        expect(voice.startsWith(locale), isTrue, reason: 'voice for $locale');
      }
    });

    test('unknown locale falls back to an English voice', () {
      expect(edgeVoiceForLocale('xx-XX'), 'en-US-AriaNeural');
    });
  });

  group('edgeVoicesForLocale', () {
    test('offers at least one voice per mapped locale', () {
      final voices = edgeVoicesForLocale('hi-IN');
      expect(voices, isNotEmpty);
      expect(voices, contains(edgeVoiceForLocale('hi-IN')));
    });
  });
}
