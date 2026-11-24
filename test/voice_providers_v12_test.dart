// v1.2.0 tests — SigV4 signing, Azure emotion styles, new provider
// facts. Pure functions only; the REST clients are NOT live-tested
// (no API key is used anywhere).
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/voice_providers.dart';

void main() {
  group('SigV4 primitives', () {
    test('SHA-256 of "abc" matches the known vector', () {
      expect(
        sha256.convert([97, 98, 99]).toString(),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('HMAC-SHA256 matches RFC 4231 test case 2', () {
      // Key "Jefe", data "what do ya want for nothing?"
      final mac = Hmac(sha256, [74, 101, 102, 101])
          .convert([119, 104, 97, 116, 32, 100, 111, 32, 121, 97, 32, 119, 97, 110, 116, 32, 102, 111, 114, 32, 110, 111, 116, 104, 105, 110, 103, 63])
          .toString();
      expect(
        mac,
        '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      );
    });

    test('signing key is 32 bytes and deterministic', () {
      final key1 = sigV4SigningKey(
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        dateStamp: '20150830',
        region: 'us-east-1',
        service: 'iam',
      );
      final key2 = sigV4SigningKey(
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        dateStamp: '20150830',
        region: 'us-east-1',
        service: 'iam',
      );
      expect(key1.length, 32);
      expect(key1, key2);
    });
  });

  group('SigV4 canonical request', () {
    test('assembles the exact AWS-documented format', () {
      const body = '{"OutputFormat":"mp3"}';
      final payloadHash = sha256.convert(body.codeUnits).toString();
      expect(
        sigV4CanonicalRequest(
          method: 'POST',
          host: 'polly.ap-south-1.amazonaws.com',
          path: '/v1/speech',
          amzDate: '20240115T120000Z',
          body: body,
        ),
        'POST\n'
        '/v1/speech\n'
        '\n'
        'content-type:application/json\n'
        'host:polly.ap-south-1.amazonaws.com\n'
        'x-amz-date:20240115T120000Z\n'
        '\n'
        'content-type;host;x-amz-date\n'
        '$payloadHash',
      );
    });

    test('headers carry the right shape and scope', () {
      final headers = sigV4Headers(
        accessKeyId: 'AKIDEXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        region: 'ap-south-1',
        service: 'polly',
        method: 'POST',
        host: 'polly.ap-south-1.amazonaws.com',
        path: '/v1/speech',
        body: '{"OutputFormat":"mp3"}',
        timestamp: DateTime.utc(2024, 1, 15, 12, 0, 0),
      );
      expect(headers['X-Amz-Date'], '20240115T120000Z');
      final auth = headers['Authorization']!;
      expect(auth, startsWith('AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20240115/ap-south-1/polly/aws4_request'));
      expect(auth, contains('SignedHeaders=content-type;host;x-amz-date'));
      final signature = auth.split('Signature=').last;
      expect(signature.length, 64); // hex SHA-256
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(signature), isTrue);
    });
  });

  group('Azure emotion styles', () {
    test('SwaraNeural maps happy/sad/dramatic to verified styles', () {
      expect(azureStyleForEmotion('happy', 'hi-IN-SwaraNeural'), 'cheerful');
      expect(azureStyleForEmotion('excited', 'hi-IN-SwaraNeural'), 'cheerful');
      expect(azureStyleForEmotion('sad', 'hi-IN-SwaraNeural'), 'empathetic');
      expect(azureStyleForEmotion('calm', 'hi-IN-SwaraNeural'), 'empathetic');
      expect(azureStyleForEmotion('dramatic', 'hi-IN-SwaraNeural'), 'newscast');
      expect(azureStyleForEmotion('neutral', 'hi-IN-SwaraNeural'), '');
    });

    test('other voices get no style — never invent one', () {
      expect(azureStyleForEmotion('happy', 'hi-IN-MadhurNeural'), '');
      expect(azureStyleForEmotion('happy', 'hi-IN-AaravNeural'), '');
    });
  });

  group('v1.2.0 provider facts', () {
    VoiceProviderInfo info(String id) =>
        voiceProviderInfos.firstWhere((i) => i.id == id);

    test('Google Cloud WaveNet: 4M free chars/month', () {
      final g = info('google_cloud_tts');
      expect(g.freeCharsPerMonth, 4000000);
      expect(g.maxChars, 5000);
      expect(g.status, 'verified-free');
    });

    test('Amazon Polly: 5M free chars/month, first 12 months', () {
      final p = info('amazon_polly');
      expect(p.freeCharsPerMonth, 5000000);
      expect(p.hindiVoices, contains('Aditi'));
      expect(p.hindiVoices, contains('No male Hindi Standard voice verified'));
    });

    test('Speechify: 500K free chars/month, 2000-char request limit', () {
      final s = info('speechify');
      expect(s.freeCharsPerMonth, 500000);
      expect(s.maxChars, 2000);
      expect(s.hindiVoices, contains('Simba 3.2 is English-only'));
    });

    test('Azure: 0.5M free chars/month', () {
      final a = info('azure_speech');
      expect(a.freeCharsPerMonth, 500000);
      expect(a.hindiVoices, contains('SwaraNeural'));
    });

    test('Gemini free tier is NOT claimed in hours', () {
      final g = info('gemini_tts');
      expect(g.freeLimit, contains('does NOT publish'));
      expect(g.freeLimit, contains('previews / short clips'));
      expect(g.freeCharsPerMonth, isNull);
    });

    test('OpenAI TTS is not a provider any more', () {
      expect(
        voiceProviderInfos.any((i) => i.id == 'openai_tts'),
        isFalse,
      );
    });
  });
}
