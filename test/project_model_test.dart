import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:webkeyo/models/project_model.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('webkeyo_hive_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ProjectModelAdapter());
    }
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('ProjectModel round-trips all fields (including new ones)', () async {
    final box = await Hive.openBox<ProjectModel>('projects_box');

    final project = ProjectModel(
      id: 'p1',
      title: 'Test Manga',
      sourceFilePath: '/tmp/x.cbz',
      extractedImagePaths: ['/a.jpg', '/b.jpg'],
      generatedScript: '{"scenes":[]}',
      generatedAudioPath: null,
      finalVideoPath: '/tmp/out.mp4',
      language: 'Hindi',
      isNsfw: true,
      charactersContext: 'Ryo: main character',
      generationMode: 'Study Explainer',
      visionProviderId: 'groq',
      visionModelId: 'llama-vision',
      visionBaseUrl: 'https://api.groq.com/openai/v1',
      visionApiKey: 'key-123',
      textProviderId: 'openrouter',
      textModelId: 'text-model-1',
      ttsProviderId: 'elevenlabs',
      status: 'script_ready',
      videoResolution: '4K',
      customExportPath: '/tmp/export',
      editedImagePaths: ['/c.jpg'],
      ttsModelId: 'voice-1',
      ttsApiKey: 'tts-key',
      ttsBaseUrl: 'https://api.elevenlabs.io/v1',
      ttsVoice: 'en-US-AriaNeural',
      sceneImageOverrides: {1: 3, 2: 10},
      bgmPath: '/tmp/music.mp3',
    );

    await box.put('p1', project);
    await box.close();

    final box2 = await Hive.openBox<ProjectModel>('projects_box');
    final loaded = box2.get('p1');

    expect(loaded, isNotNull);
    expect(loaded!.id, 'p1');
    expect(loaded.title, 'Test Manga');
    expect(loaded.sourceFilePath, '/tmp/x.cbz');
    expect(loaded.extractedImagePaths, ['/a.jpg', '/b.jpg']);
    expect(loaded.generatedScript, '{"scenes":[]}');
    expect(loaded.finalVideoPath, '/tmp/out.mp4');
    expect(loaded.language, 'Hindi');
    expect(loaded.isNsfw, isTrue);
    expect(loaded.charactersContext, 'Ryo: main character');
    expect(loaded.generationMode, 'Study Explainer');
    expect(loaded.visionProviderId, 'groq');
    expect(loaded.visionModelId, 'llama-vision');
    expect(loaded.visionBaseUrl, 'https://api.groq.com/openai/v1');
    expect(loaded.visionApiKey, 'key-123');
    expect(loaded.textProviderId, 'openrouter');
    expect(loaded.textModelId, 'text-model-1');
    expect(loaded.ttsProviderId, 'elevenlabs');
    expect(loaded.status, 'script_ready');
    expect(loaded.videoResolution, '4K');
    expect(loaded.customExportPath, '/tmp/export');
    expect(loaded.editedImagePaths, ['/c.jpg']);
    expect(loaded.ttsModelId, 'voice-1');
    expect(loaded.ttsApiKey, 'tts-key');
    expect(loaded.ttsBaseUrl, 'https://api.elevenlabs.io/v1');
    // New fields (26-28)
    expect(loaded.ttsVoice, 'en-US-AriaNeural');
    expect(loaded.sceneImageOverrides, {1: 3, 2: 10});
    expect(loaded.bgmPath, '/tmp/music.mp3');
  });

  test('ProjectModel defaults are sane', () {
    final project = ProjectModel(id: 'p2', title: 'Bare');
    expect(project.language, 'Hinglish');
    expect(project.isNsfw, isFalse);
    expect(project.status, 'created');
    expect(project.videoResolution, '1080p');
    expect(project.extractedImagePaths, isEmpty);
    expect(project.editedImagePaths, isEmpty);
    expect(project.sceneImageOverrides, isEmpty);
    expect(project.ttsVoice, isNull);
    expect(project.bgmPath, isNull);
    expect(project.statusDisplay, 'Ready');
    expect(project.progressValue, 0.0);
  });

  test('statusDisplay and progressValue cover the full lifecycle', () {
    final project = ProjectModel(id: 'p3', title: 'X');
    for (final entry in {
      'extracting': (1, 0.10),
      'scripting': (1, 0.35),
      'script_ready': (1, 0.5),
      'audio': (1, 0.7),
      'rendering': (1, 0.85),
      'done': (1, 1.0),
    }.entries) {
      project.status = entry.key;
      expect(project.progressValue, entry.value.$2);
      expect(project.statusDisplay, isNotEmpty);
    }
    expect(project.progressValue, 1.0);
  });
}
