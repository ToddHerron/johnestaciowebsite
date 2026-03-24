import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Lightweight Markdown detector and converter for seeding the Quill editor.
///
/// Supported markdown cues:
/// - Headings: #, ##, ###
/// - Unordered lists: -, *
/// - Ordered lists: 1., 2., ...
/// - Bold: **text** or __text__
/// - Italic: *text* or _text_
/// - Links: [text](url)
///
/// Fallback for unsupported markdown is to keep plain text for those parts.
class MarkdownQuillConverter {
  static final RegExp _headingRE = RegExp(r'^(#{1,3})\s+(.*)$');
  static final RegExp _ulRE = RegExp(r'^(?:[-*])\s+(.*)$');
  static final RegExp _olRE = RegExp(r'^(?:\d+)\.\s+(.*)$');
  static final RegExp _boldRE = RegExp(r'(\*\*|__)(.+?)\1');
  static final RegExp _italicRE = RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|_(.+?)_');
  static final RegExp _linkRE = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

  /// Heuristic detector for markdown presence in [text].
  static bool looksLikeMarkdown(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return _headingRE.hasMatch(text) ||
        _ulRE.hasMatch(text) ||
        _olRE.hasMatch(text) ||
        _boldRE.hasMatch(text) ||
        _italicRE.hasMatch(text) ||
        _linkRE.hasMatch(text) ||
        text.contains('```') ||
        text.contains('\n- ') ||
        text.contains('\n* ') ||
        RegExp(r'^\d+\.\s', multiLine: true).hasMatch(text);
  }

  /// Convert a (simple) markdown string into a Quill Document.
  /// If the text doesn't appear to be markdown, it will be inserted as-is.
  static quill.Document toQuillDocument(String text) {
    final ops = toOps(text);
    return quill.Document.fromJson(ops);
  }

  /// Convert to Quill ops (List of insert operations) with a small subset of markdown support.
  static List<Map<String, dynamic>> toOps(String text) {
    final ops = <Map<String, dynamic>>[];

    void insert(String s, [Map<String, dynamic>? attributes]) {
      if (s.isEmpty) return;
      final op = <String, dynamic>{'insert': s};
      if (attributes != null && attributes.isNotEmpty) {
        op['attributes'] = attributes;
      }
      ops.add(op);
    }

    final lines = text.replaceAll('\r\n', '\n').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      _LineParseResult parsed = _parseLinePrefix(line);

      // Build inline segments (bold, italic, link)
      final segments = _parseInline(parsed.content);
      for (final seg in segments) {
        insert(seg.text, seg.attributes);
      }

      // Add newline with optional line-level attribute
      if (parsed.lineAttribute != null) {
        insert('\n', parsed.lineAttribute);
      } else {
        insert('\n');
      }
    }

    return ops;
  }

  static _LineParseResult _parseLinePrefix(String line) {
    // Headings
    final h = _headingRE.firstMatch(line);
    if (h != null) {
      final hashes = h.group(1)!;
      final text = h.group(2) ?? '';
      final level = hashes.length; // 1..3
      final attr = switch (level) {
        1 => quill.Attribute.h1.toJson(),
        2 => quill.Attribute.h2.toJson(),
        _ => quill.Attribute.h3.toJson(),
      };
      return _LineParseResult(text, attr);
    }

    // Unordered list
    final ul = _ulRE.firstMatch(line);
    if (ul != null) {
      final text = ul.group(1) ?? '';
      return _LineParseResult(text, quill.Attribute.ul.toJson());
    }

    // Ordered list
    final ol = _olRE.firstMatch(line);
    if (ol != null) {
      final text = ol.group(0)!;
      // remove the leading number. pattern like "12. "
      final m = RegExp(r'^(\d+)\.\s+').firstMatch(text);
      final content = m != null ? text.substring(m.group(0)!.length) : text;
      return _LineParseResult(content, quill.Attribute.ol.toJson());
    }

    return _LineParseResult(line, null);
  }

  /// Parse inline markdown for bold, italic, and links within a single line.
  static List<_InlineSegment> _parseInline(String input) {
    if (input.isEmpty) return [const _InlineSegment('')];

    // First handle links, splitting the line into [text|link|text|link...] segments
    final segments = <_InlineSegment>[];
    int lastIndex = 0;
    for (final m in _linkRE.allMatches(input)) {
      if (m.start > lastIndex) {
        segments.addAll(_parseInlineStyles(input.substring(lastIndex, m.start)));
      }
      final text = m.group(1) ?? '';
      final url = m.group(2) ?? '';
      segments.add(_InlineSegment(text, { 'link': url }));
      lastIndex = m.end;
    }
    if (lastIndex < input.length) {
      segments.addAll(_parseInlineStyles(input.substring(lastIndex)));
    }

    return segments.isEmpty ? [const _InlineSegment('')] : segments;
  }

  /// Parse bold/italic for a piece without links.
  static List<_InlineSegment> _parseInlineStyles(String input) {
    if (input.isEmpty) return [const _InlineSegment('')];

    // We'll scan left-to-right handling bold then italic markers.
    final result = <_InlineSegment>[];
    int index = 0;

    while (index < input.length) {
      // Try bold **text** or __text__
      final boldMatch = _boldRE.matchAsPrefix(input, index);
      if (boldMatch != null) {
        final text = (boldMatch.group(2) ?? '').trimRight();
        if (index < boldMatch.start) {
          result.add(_InlineSegment(input.substring(index, boldMatch.start)));
        }
        result.add(_InlineSegment(text, { 'bold': true }));
        index = boldMatch.end;
        continue;
      }

      // Try italic *text* or _text_
      final italicMatch = _italicRE.matchAsPrefix(input, index);
      if (italicMatch != null) {
        final text = (italicMatch.group(1) ?? italicMatch.group(2) ?? '').trimRight();
        if (index < italicMatch.start) {
          result.add(_InlineSegment(input.substring(index, italicMatch.start)));
        }
        result.add(_InlineSegment(text, { 'italic': true }));
        index = italicMatch.end;
        continue;
      }

      // Otherwise, consume one character and continue
      result.add(_InlineSegment(input[index]));
      index += 1;
    }

    // Merge adjacent plain segments to reduce noise
    return _mergeAdjacentPlain(result);
  }

  static List<_InlineSegment> _mergeAdjacentPlain(List<_InlineSegment> segs) {
    final merged = <_InlineSegment>[];
    for (final s in segs) {
      if (merged.isNotEmpty && merged.last.isPlain && s.isPlain) {
        merged[merged.length - 1] = _InlineSegment(merged.last.text + s.text);
      } else {
        merged.add(s);
      }
    }
    return merged;
  }
}

class _LineParseResult {
  final String content;
  final Map<String, dynamic>? lineAttribute; // e.g., heading, list
  _LineParseResult(this.content, this.lineAttribute);
}

class _InlineSegment {
  final String text;
  final Map<String, dynamic>? attributes; // e.g., {bold:true}, {italic:true}, {link:url}
  const _InlineSegment(this.text, [this.attributes]);
  bool get isPlain => attributes == null || attributes!.isEmpty;
}
