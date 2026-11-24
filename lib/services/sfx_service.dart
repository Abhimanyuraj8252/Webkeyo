/// Music / SFX skill — synthesised sound effects via FFmpeg, no download.
///
/// Every sound here is SYNTHESISED by FFmpeg filters (anoisesrc, sine,
/// aevalsrc) — no downloaded sound files, no licence, no cost. The SFX
/// type is picked from the prompt's mood / the video style.
///
/// Honest note: these are simple synthesised beds, not real recorded
/// sound and not music. Real background music still needs a licensed
/// source (e.g. the YouTube Audio Library — free, check the licence per
/// track). Do not use a random downloaded song on a monetised video.
///
/// Add a new SFX by adding one branch in [sfxFilter] — see the recipe
/// table in SKILLS.md.
library;

import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// SFX types this service can synthesise.
const List<String> sfxTypes = [
  'rain',
  'rain_thunder',
  'wind',
  'heartbeat',
  'chime',
  'whoosh',
];

/// FFmpeg audio filter (lavfi source) that synthesises [type] for
/// [seconds]. Pure function — unit-tested without running FFmpeg.
String sfxFilter(String type, double seconds) {
  final dur = seconds.toStringAsFixed(1);
  switch (type) {
    case 'rain':
      // Soft filtered noise = rain bed.
      return 'anoisesrc=duration=$dur:color=pink,lowpass=f=1200,volume=0.35';
    case 'rain_thunder':
      // Rain bed + one low 48 Hz rumble in the first seconds.
      // One aevalsrc expression (a chained `sine` source mid-chain is
      // invalid FFmpeg syntax — verified 24 Nov 2026 with system ffmpeg).
      return 'aevalsrc=\'0.22*random(0)+0.5*sin(2*PI*48*t)*exp(-t*1.2)*(lt(t,2.5))\':duration=$dur,lowpass=f=1200,volume=0.9';
    case 'wind':
      // Noise with a slow swell = wind.
      return 'anoisesrc=duration=$dur:color=brown,lowpass=f=500,volume=0.3,'
          'tremolo=f=0.25:d=0.6';
    case 'heartbeat':
      // Low thumps: 55 Hz sine gated by a slow square-ish envelope.
      return 'sine=frequency=55:duration=$dur,volume=0.7,'
          'tremolo=f=1.2:d=0.9';
    case 'chime':
      // Bright bell: 880 Hz + harmonic, fading out.
      return 'sine=frequency=880:duration=$dur,volume=0.25,afade=t=out:st=0:d=$dur';
    case 'whoosh':
      // Noise swell in and out.
      return 'anoisesrc=duration=$dur:color=pink,lowpass=f=2000,volume=0.4,'
          'afade=t=in:st=0:d=${(seconds / 2).toStringAsFixed(1)},'
          'afade=t=out:st=${(seconds / 2).toStringAsFixed(1)}:d=${(seconds / 2).toStringAsFixed(1)}';
    default:
      // Soft pad — calm bed under narration. One aevalsrc expression
      // (two chained `sine` sources are invalid FFmpeg syntax).
      return 'aevalsrc=\'0.08*sin(2*PI*220*t)+0.04*sin(2*PI*330*t)\':duration=$dur';
  }
}

/// Full FFmpeg command that writes [type] SFX to [outPath] (wav).
/// Pure function — unit-tested.
String buildSfxCommand(String type, double seconds, String outPath) {
  final filter = sfxFilter(type, seconds);
  return '-f lavfi -i "$filter" -t ${seconds.toStringAsFixed(1)} '
      '-c:a pcm_s16le -ar 22050 -ac 1 -y "$outPath"';
}

/// Render [type] SFX to [outPath]. Returns the path. Throws on failure.
Future<String> generateSfx({
  required String type,
  required double seconds,
  required String outPath,
}) async {
  final command = buildSfxCommand(type, seconds, outPath);
  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getLogsAsString();
    throw Exception('SFX generation failed for $type: $logs');
  }
  return outPath;
}

/// FFmpeg filter that mixes [narrationPath] with [sfxPath] underneath it
/// at [sfxVolumeDb] (default -18 dB). Pure function — unit-tested.
///
/// [loopSfx]: when true, the SFX bed is looped forever under the
/// narration (`-stream_loop -1`) instead of playing once. Long videos
/// (over ~2 minutes) generate only a short SFX loop and repeat it —
/// a 2-hour SFX file would otherwise be a ~300 MB WAV on the phone.
String buildMixCommand({
  required String narrationPath,
  required String sfxPath,
  required String outPath,
  double sfxVolumeDb = -18.0,
  bool loopSfx = false,
}) {
  // dB -> linear gain: 10^(dB/20). -18 dB ≈ 0.126.
  final gain = math.pow(10, sfxVolumeDb / 20.0).toStringAsFixed(4);
  final sfxInput = loopSfx ? '-stream_loop -1 -i "$sfxPath"' : '-i "$sfxPath"';
  return '-i "$narrationPath" $sfxInput -filter_complex '
      '"[0:a]volume=1.0[a0];[1:a]volume=$gain[a1];'
      '[a0][a1]amix=inputs=2:duration=first:dropout_transition=0[aout]" '
      '-map "[aout]" -c:a aac -b:a 128k -y "$outPath"';
}
