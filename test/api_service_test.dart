import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/api_service.dart';

void main() {
  group('sampleImagePaths', () {
    test('returns a copy when under the limit', () {
      final paths = ['/a.jpg', '/b.jpg', '/c.jpg'];
      final sampled = sampleImagePaths(paths, maxImages: 10);
      expect(sampled, paths);
      expect(identical(sampled, paths), isFalse);
    });

    test('samples down to maxImages including first page', () {
      final paths = List.generate(30, (i) => '/img/$i.jpg');
      final sampled = sampleImagePaths(paths, maxImages: 10);
      expect(sampled.length, 10);
      expect(sampled.first, '/img/0.jpg');
      // every sampled entry must be a real path from the input
      for (final s in sampled) {
        expect(paths, contains(s));
      }
    });

    test('exactly at the limit returns all', () {
      final paths = List.generate(10, (i) => '/img/$i.jpg');
      expect(sampleImagePaths(paths, maxImages: 10).length, 10);
    });
  });

  group('remapSceneImageIndices', () {
    test('remaps sampled indexes to real image indexes', () {
      final all = List.generate(30, (i) => '/img/$i.jpg');
      final sampled = sampleImagePaths(all, maxImages: 10);

      final script = {
        'scenes': [
          {'scene_number': 1, 'image_index': 0, 'narration': 'a'},
          {'scene_number': 2, 'image_index': 9, 'narration': 'b'},
          {'scene_number': 3, 'image_index': 4, 'narration': 'c'},
        ],
      };

      remapSceneImageIndices(script, sampled, all);

      final scenes = script['scenes'] as List;
      expect((scenes[0] as Map)['image_index'], all.indexOf(sampled[0]));
      expect((scenes[1] as Map)['image_index'], all.indexOf(sampled[9]));
      expect((scenes[2] as Map)['image_index'], all.indexOf(sampled[4]));
      // remapped values must point at real images
      for (final s in scenes) {
        final idx = (s as Map)['image_index'] as int;
        expect(all, containsAt(idx, all[idx]));
      }
    });

    test('is a no-op when nothing was sampled', () {
      final all = List.generate(5, (i) => '/img/$i.jpg');
      final sampled = sampleImagePaths(all, maxImages: 10);

      final script = {
        'scenes': [
          {'scene_number': 1, 'image_index': 3, 'narration': 'x'},
        ],
      };
      remapSceneImageIndices(script, sampled, all);
      expect((script['scenes'] as List)[0]['image_index'], 3);
    });

    test('clamps out-of-range indexes instead of crashing', () {
      final all = List.generate(30, (i) => '/img/$i.jpg');
      final sampled = sampleImagePaths(all, maxImages: 10);

      final script = {
        'scenes': [
          {'scene_number': 1, 'image_index': 99, 'narration': 'x'},
          {'scene_number': 2, 'image_index': -5, 'narration': 'y'},
        ],
      };
      remapSceneImageIndices(script, sampled, all);

      final scenes = script['scenes'] as List;
      final idx1 = (scenes[0] as Map)['image_index'] as int;
      final idx2 = (scenes[1] as Map)['image_index'] as int;
      expect(idx1, all.indexOf(sampled[sampled.length - 1]));
      expect(idx2, all.indexOf(sampled[0]));
    });

    test('ignores non-numeric image_index values', () {
      final all = List.generate(20, (i) => '/img/$i.jpg');
      final sampled = sampleImagePaths(all, maxImages: 10);
      final script = {
        'scenes': [
          {'scene_number': 1, 'image_index': 'weird', 'narration': 'x'},
        ],
      };
      remapSceneImageIndices(script, sampled, all);
      expect((script['scenes'] as List)[0]['image_index'], 'weird');
    });
  });
}
