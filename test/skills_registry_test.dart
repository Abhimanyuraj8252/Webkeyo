import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/skills_registry.dart';

void main() {
  test('31 skills across 7 stages', () {
    expect(skills.length, 31);
    expect(skillStages.length, 7);
    expect(
      skillStages.toSet(),
      {'Script', 'Voicing', 'Video', 'Editing', 'Thumbnail', 'Subtitles', 'Music/SFX'},
    );
  });

  test('per-stage counts match the registry', () {
    final grouped = skillsByStage();
    expect(grouped['Script']!.length, 3);
    expect(grouped['Voicing']!.length, 10);
    expect(grouped['Video']!.length, 6);
    expect(grouped['Editing']!.length, 6);
    expect(grouped['Thumbnail']!.length, 1);
    expect(grouped['Subtitles']!.length, 3);
    expect(grouped['Music/SFX']!.length, 2);
  });

  test('every skill has an id, cost, install and guidance', () {
    final ids = <String>{};
    for (final skill in skills) {
      expect(skill.id.trim(), isNotEmpty);
      expect(ids.add(skill.id), isTrue, reason: 'duplicate id ${skill.id}');
      expect(skill.name.trim(), isNotEmpty);
      expect(skill.what.trim(), isNotEmpty);
      expect(skill.cost.trim(), isNotEmpty);
      expect(skill.install.trim(), isNotEmpty);
      expect(skill.whenToUse.trim(), isNotEmpty);
      expect(skill.doesNotDo.trim(), isNotEmpty);
      expect(skillStages, contains(skill.stage));
    }
  });

  test('MiniMax is never presented as free', () {
    final minimax = skills.firstWhere((s) => s.id == 'voice-minimax');
    expect(minimax.name, contains('PAID ONLY'));
    expect(minimax.cost, contains('NO free allowance'));
  });
}
