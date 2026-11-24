/// One-tap share — send a rendered video to YouTube / Instagram with
/// a ready caption + hashtags. Uses share_plus (already a dependency).
/// The app cannot post directly to YouTube or Instagram (their APIs
/// need a reviewed app / OAuth) — it opens the system share sheet with
/// the video file and a caption the creator can paste, which is the
/// same flow every creator app on a phone uses.
///
/// Caption format: Hinglish title line, then hashtags. Hashtags come
/// from the reel template used (or the defaults below).
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static const List<String> defaultHashtags = [
    '#hindistory',
    '#webkeyo',
    '#storytime',
  ];

  /// Build the caption for a video: [title] line + hashtags.
  /// On-screen text is English; the caption is Hinglish (project rule).
  static String buildCaption({
    required String title,
    List<String> hashtags = defaultHashtags,
  }) {
    final tags = hashtags.join(' ');
    return '$title\n\n$tags';
  }

  /// Copy [caption] to the clipboard (so it can be pasted in YouTube /
  /// Instagram after the share sheet opens).
  static Future<void> copyCaption(String caption) async {
    await Clipboard.setData(ClipboardData(text: caption));
  }

  /// Share [videoPath] via the system share sheet, with [caption]
  /// copied to the clipboard first so the creator can paste it in the
  /// YouTube / Instagram upload screen. Returns true when the share
  /// sheet opened.
  static Future<bool> shareVideo({
    required String videoPath,
    required String title,
    List<String> hashtags = defaultHashtags,
  }) async {
    final file = File(videoPath);
    if (!await file.exists()) return false;
    final caption = buildCaption(title: title, hashtags: hashtags);
    await copyCaption(caption);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(videoPath)],
        text: caption,
        subject: title,
      ),
    );
    return result.status == ShareResultStatus.success ||
        result.status == ShareResultStatus.dismissed;
  }
}
