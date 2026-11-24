/// Best-effort PDF text extraction — pure Dart, offline, no package.
///
/// Finds each page object (`/Type /Page`), follows its `/Contents`
/// stream(s), Flate-decodes them when they are FlateDecode, and pulls
/// the literal strings shown by the `Tj` / `TJ` text operators.
///
/// Works for the common case: lecture PDFs made by Word / Google Docs
/// / print-to-PDF with Latin text. It does NOT handle custom font
/// encodings, ToUnicode maps, or subset fonts that remap glyphs — for
/// those pages it returns little or no text, and the caller falls back
/// to bridge narration. Encrypted PDFs return no text.
///
/// Never throws: any failure returns what was found so far (possibly
/// empty strings). Latin-1 is used throughout so string indices line
/// up with byte offsets.
library;

import 'dart:io';
import 'dart:typed_data';

/// One object in the file: its absolute start offset and full text.
class _ObjSpan {
  final int start;
  final String text;
  const _ObjSpan(this.start, this.text);
}

/// Extract the text of every page, in page order. The list length is
/// the page count found in the file (0 when the file is not a readable
/// PDF). A page with no extractable text yields an empty string.
List<String> extractPdfPageTexts(Uint8List bytes) {
  try {
    final raw = String.fromCharCodes(bytes);
    final objects = <int, _ObjSpan>{};
    final objRe = RegExp(r'(\d+)\s+\d+\s+obj(.*?)endobj', dotAll: true);
    for (final m in objRe.allMatches(raw)) {
      objects[int.parse(m.group(1)!)] = _ObjSpan(m.start, m.group(0)!);
    }
    if (objects.isEmpty) return const [];

    final pageTexts = <String>[];
    for (final span in objects.values) {
      final body = span.text;
      // '/Type /Page' but not '/Type /Pages'.
      if (!RegExp(r'/Type\s*/Page(?!s)\b').hasMatch(body)) continue;
      final refs = <int>[];
      final contentsRe =
          RegExp(r'/Contents\s*(?:\[([^\]]*)\]|(\d+)\s+\d+\s+R)');
      final cm = contentsRe.firstMatch(body);
      if (cm != null) {
        final listPart = cm.group(1);
        if (listPart != null) {
          for (final rm in RegExp(r'(\d+)\s+\d+\s+R').allMatches(listPart)) {
            refs.add(int.parse(rm.group(1)!));
          }
        } else if (cm.group(2) != null) {
          refs.add(int.parse(cm.group(2)!));
        }
      }
      final pageBuffer = StringBuffer();
      for (final ref in refs) {
        final target = objects[ref];
        if (target != null) {
          pageBuffer.write(_textOfStreamObject(target, bytes));
          pageBuffer.write(' ');
        }
      }
      pageTexts.add(_clean(pageBuffer.toString()));
    }
    return pageTexts;
  } catch (_) {
    return const [];
  }
}

/// Text shown by one content-stream object. Offsets are absolute:
/// Latin-1 keeps string indices aligned with byte offsets.
String _textOfStreamObject(_ObjSpan span, Uint8List bytes) {
  final body = span.text;
  // The stream keyword follows the dict's closing '>>'.
  final dictEnd = body.indexOf('>>');
  final streamStart = body.indexOf('stream', dictEnd < 0 ? 0 : dictEnd);
  if (streamStart < 0) return '';
  var dataStart = streamStart + 'stream'.length;
  if (dataStart < body.length && body.codeUnitAt(dataStart) == 0x0d) {
    dataStart++;
  }
  if (dataStart < body.length && body.codeUnitAt(dataStart) == 0x0a) {
    dataStart++;
  }
  final streamEndRel = body.indexOf('endstream', dataStart);
  if (streamEndRel < 0) return '';
  final absStart = span.start + dataStart;
  final absEnd = span.start + streamEndRel;
  if (absEnd <= absStart || absEnd > bytes.length) return '';
  var data = bytes.sublist(absStart, absEnd);
  if (body.contains('FlateDecode')) {
    try {
      data = Uint8List.fromList(ZLibDecoder().convert(data));
    } catch (_) {
      return '';
    }
  }
  final text = String.fromCharCodes(data);
  final buffer = StringBuffer();
  final literalRe = RegExp(r'\((?:\\.|[^\\()])*\)');
  // (literal) Tj — one string shown.
  final tjRe = RegExp(r'\((?:\\.|[^\\()])*\)\s*Tj');
  for (final m in tjRe.allMatches(text)) {
    final lit = literalRe.firstMatch(m.group(0)!);
    if (lit != null) {
      buffer.write(_unescapeLiteral(lit.group(0)!));
      buffer.write(' ');
    }
  }
  // [...] TJ — several strings shown, with spacing numbers between.
  final tjArrayRe = RegExp(r'\[((?:[^\]])*)\]\s*TJ', dotAll: true);
  for (final m in tjArrayRe.allMatches(text)) {
    for (final lit in literalRe.allMatches(m.group(1)!)) {
      buffer.write(_unescapeLiteral(lit.group(0)!));
      buffer.write(' ');
    }
  }
  return buffer.toString();
}

/// Undo PDF literal-string escapes: \( \) \\ \n \r \t and \ddd octal.
/// [literal] includes its surrounding parens.
String _unescapeLiteral(String literal) {
  final s = literal.substring(1, literal.length - 1);
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c != '\\' || i + 1 >= s.length) {
      out.write(c);
      i++;
      continue;
    }
    final next = s[i + 1];
    switch (next) {
      case 'n':
        out.write('\n');
        i += 2;
      case 'r':
        out.write('\r');
        i += 2;
      case 't':
        out.write('\t');
        i += 2;
      case '(':
      case ')':
      case '\\':
        out.write(next);
        i += 2;
      default:
        final code = next.codeUnitAt(0);
        if (code >= 0x30 && code <= 0x37) {
          // Octal escape, up to 3 digits.
          var digits = '';
          var j = i + 1;
          while (j < s.length &&
              digits.length < 3 &&
              s[j].codeUnitAt(0) >= 0x30 &&
              s[j].codeUnitAt(0) <= 0x37) {
            digits += s[j];
            j++;
          }
          out.write(String.fromCharCode(int.parse(digits, radix: 8)));
          i = j;
        } else {
          // Line continuation or unknown escape — drop the backslash.
          out.write(next);
          i += 2;
        }
    }
  }
  return out.toString();
}

String _clean(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
