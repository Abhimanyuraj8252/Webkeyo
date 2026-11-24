import 'package:flutter_test/flutter_test.dart';
import 'package:webkeyo/services/editing_service.dart';

void main() {
  test('buildConcatCommand uses the concat demuxer with copy', () {
    final cmd = buildConcatCommand('/tmp/list.txt', '/tmp/out.mp4');
    expect(cmd, contains('-f concat -safe 0'));
    expect(cmd, contains('-c copy'));
    expect(cmd, contains('"/tmp/out.mp4"'));
  });

  test('buildFadeCommand fades video and audio in and out', () {
    final cmd = buildFadeCommand('/tmp/in.mp4', '/tmp/out.mp4', duration: 10.0);
    expect(cmd, contains('fade=t=in'));
    expect(cmd, contains('fade=t=out'));
    expect(cmd, contains('afade'));
  });

  test('buildCrossfadeCommand uses xfade + acrossfade', () {
    final cmd = buildCrossfadeCommand(
      '/tmp/a.mp4', '/tmp/b.mp4', '/tmp/out.mp4', durationA: 8.0);
    expect(cmd, contains('xfade'));
    expect(cmd, contains('acrossfade'));
  });

  test('buildSpeedCommand rejects out-of-range speeds', () {
    expect(
      () => buildSpeedCommand('/tmp/in.mp4', '/tmp/out.mp4', 0.1),
      throwsArgumentError,
    );
    expect(
      () => buildSpeedCommand('/tmp/in.mp4', '/tmp/out.mp4', 200),
      throwsArgumentError,
    );
    final cmd = buildSpeedCommand('/tmp/in.mp4', '/tmp/out.mp4', 2.0);
    expect(cmd, contains('setpts=0.5000*PTS'));
    expect(cmd, contains('atempo=2.0'));
  });

  test('buildTextOverlayCommand and buildEndScreenCommand burn text', () {
    final overlay = buildTextOverlayCommand('/tmp/in.mp4', '/tmp/out.mp4', 'Hello');
    expect(overlay, contains('drawtext'));
    expect(overlay, contains('Hello'));
    final end = buildEndScreenCommand(
      '/tmp/in.mp4', '/tmp/out.mp4', 'Next part', duration: 20.0);
    expect(end, contains('WATCH NEXT'));
    expect(end, contains('Next part'));
  });
}
