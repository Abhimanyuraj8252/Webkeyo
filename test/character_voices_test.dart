import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/character_voices.dart';

void main() {
  test('detectEmotion reads tags and keywords', () {
    expect(detectEmotion('[angry] tum kya kar rahe ho'), 'angry');
    expect(detectEmotion('[happy] bahut khush hoon'), 'happy');
    expect(detectEmotion('main bahut khush hoon'), 'happy');
    expect(detectEmotion(''), 'neutral');
    expect(detectEmotion('a plain line'), 'neutral');
  });

  test('stripEmotionTag removes the leading tag only', () {
    expect(stripEmotionTag('[sad] ro raha hai'), 'ro raha hai');
    expect(stripEmotionTag('no tag here'), 'no tag here');
  });

  test('paceForEmotion: sad is slow, excited is fast, unknown is 1.0', () {
    expect(paceForEmotion('sad'), 0.85);
    expect(paceForEmotion('excited'), 1.15);
    expect(paceForEmotion('neutral'), 1.0);
    expect(paceForEmotion('not-an-emotion'), 1.0);
  });

  test('narratorLineForScene: dialogue as-is, no dialogue -> narrator explains', () {
    final withDialogue = narratorLineForScene({
      'speaker': 'Arjun',
      'dialogue': 'Kaun ho tum?',
      'narration': 'Arjun enters the inn.',
    });
    expect(withDialogue['speaker'], 'Arjun');
    expect(withDialogue['text'], 'Kaun ho tum?');

    final noDialogue = narratorLineForScene({
      'speaker': 'Arjun',
      'dialogue': '',
      'narration': 'Arjun enters the inn.',
    });
    expect(noDialogue['speaker'], 'Narrator');
    expect(noDialogue['text'], contains('Arjun enters the inn'));
  });

  test('CharacterVoiceMap: narrator and characters keep one voice per provider', () {
    final map = CharacterVoiceMap.fromScenes([
      {'speaker': 'Arjun', 'dialogue': 'hi'},
      {'speaker': 'Titli', 'dialogue': 'hello'},
      {'speaker': 'Narrator', 'narration': 'a scene'},
    ]);
    final arjunSarvam = map.profileFor('Arjun').voiceIdFor('sarvam_tts');
    expect(arjunSarvam, isNotEmpty);
    expect(map.profileFor('Arjun').voiceIdFor('sarvam_tts'), arjunSarvam);
    // A male character never gets a female voice id for a gendered provider.
    expect(map.profileFor('Arjun').gender, 'male');
    expect(map.profileFor('Titli').gender, 'female');
    expect(map.speakers, containsAll(['Arjun', 'Titli', 'Narrator']));
  });

  test('MiniMax placeholder voice id is refused', () {
    const placeholder = CharacterVoice(
      name: 'Test',
      gender: 'male',
      tone: 'test',
      pace: 'medium',
      sampleLine: 'test',
      voices: {'minimax_tts': 'REPLACE_WITH_MINIMAX_VOICE_ID'},
    );
    expect(() => placeholder.voiceIdFor('minimax_tts'), throwsStateError);
  });
}
