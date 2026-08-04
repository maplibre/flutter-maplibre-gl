import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// One run of an attribution string: plain text, or a link when [href] is set.
class AttributionRun {
  const AttributionRun(this.text, {this.href});

  final String text;
  final String? href;

  bool get isLink => href != null;
}

final _anchorPattern = RegExp(
  '<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
  caseSensitive: false,
  dotAll: true,
);
final _tagPattern = RegExp('<[^>]*>');
final _numericEntityPattern = RegExp('&#(x?)([0-9a-fA-F]+);');

/// The named entities that actually occur in attribution strings. Each pass
/// runs once and never rescans its own output, so "&amp;copy;" decodes to
/// the literal "&copy;" instead of "©", matching HTML semantics.
const _namedEntities = {
  'copy': '©',
  'nbsp': ' ',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'amp': '&',
};

/// Decodes the HTML entities attribution strings use; unknown entities are
/// left as-is rather than dropped, so a new one shows up literal instead of
/// silently disappearing.
String _decodeHtmlEntities(String text) {
  return text
      .replaceAllMapped(_numericEntityPattern, (match) {
        final code = int.tryParse(
          match.group(2)!,
          radix: match.group(1)!.isEmpty ? 10 : 16,
        );
        final valid = code != null && code > 0 && code <= 0x10FFFF;
        return valid ? String.fromCharCode(code) : match.group(0)!;
      })
      .replaceAllMapped(RegExp('&([a-zA-Z]+);'), (match) {
        return _namedEntities[match.group(1)!.toLowerCase()] ?? match.group(0)!;
      });
}

/// The MapLibre credit, prepended when the style's own attributions do not
/// already mention it.
const _maplibreCredit = '<a href="https://maplibre.org/">MapLibre</a>';

/// Orders the attribution fragments to display for a style, adding the
/// MapLibre credit when no source claims it.
List<String> attributionFragments(List<String> styleAttributions) {
  final hasMapLibre = styleAttributions.any(
    (attribution) => attribution.toLowerCase().contains('maplibre'),
  );
  return [if (!hasMapLibre) _maplibreCredit, ...styleAttributions];
}

/// Flattens one attribution HTML fragment into text and link runs.
///
/// Attribution strings come from the style, so they are a tiny, well-known
/// subset of HTML: anchors plus the odd `<span>`, with entities like
/// `&copy;`. Anything that is not an anchor is stripped to its decoded text.
List<AttributionRun> parseAttributionHtml(String html) {
  final runs = <AttributionRun>[];
  var cursor = 0;

  void addText(String raw) {
    final text = _decodeHtmlEntities(raw.replaceAll(_tagPattern, ''));
    if (text.trim().isNotEmpty) runs.add(AttributionRun(text));
  }

  for (final match in _anchorPattern.allMatches(html)) {
    if (match.start > cursor) addText(html.substring(cursor, match.start));
    final label = _decodeHtmlEntities(
      match.group(2)!.replaceAll(_tagPattern, ''),
    ).trim();
    if (label.isNotEmpty) {
      runs.add(AttributionRun(label, href: match.group(1)));
    }
    cursor = match.end;
  }
  if (cursor < html.length) addText(html.substring(cursor));
  return runs;
}

/// Attribution ornament: a pill that expands into the per-source attribution
/// strings of the current style, with tappable links. Starts expanded and
/// collapses to an info button on the first camera movement.
class AttributionOrnament extends StatefulWidget {
  const AttributionOrnament({
    super.key,
    required this.loadAttributions,
    required this.openUri,
    required this.collapseSignal,
    required this.refreshSignal,
    required this.iconAtStart,
  });

  /// Fetches the distinct attribution strings of the active style.
  final Future<List<String>> Function() loadAttributions;

  /// Opens an attribution link.
  final Future<void> Function(String uri) openUri;

  /// Bumped on camera movement: collapses the pill.
  final ValueListenable<int> collapseSignal;

  /// Bumped when a style finishes loading: refetches the attributions.
  final ValueListenable<int> refreshSignal;

  /// Whether the info button sits at the start (left corners) or at the end
  /// (right corners) of the expanded pill.
  final bool iconAtStart;

  @override
  State<AttributionOrnament> createState() => _AttributionOrnamentState();
}

class _AttributionOrnamentState extends State<AttributionOrnament> {
  /// Share of the viewport width the expanded text may occupy.
  static const _maxWidthFraction = 0.6;

  static const _textStyle = TextStyle(
    color: Color(0xDD37474F),
    fontSize: 11,
    height: 1.3,
  );
  static const _linkStyle = TextStyle(
    color: Color(0xFF1E6BB0),
    decoration: TextDecoration.underline,
    decorationColor: Color(0x661E6BB0),
  );

  bool _expanded = true;
  List<String> _attributions = const [];
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    widget.collapseSignal.addListener(_collapse);
    widget.refreshSignal.addListener(_fetch);
    _fetch();
  }

  @override
  void dispose() {
    widget.collapseSignal.removeListener(_collapse);
    widget.refreshSignal.removeListener(_fetch);
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _collapse() {
    if (_expanded && mounted) setState(() => _expanded = false);
  }

  void _fetch() {
    unawaited(() async {
      List<String> attributions;
      try {
        attributions = await widget.loadAttributions();
      } catch (_) {
        attributions = const [];
      }
      if (mounted) setState(() => _attributions = attributions);
    }());
  }

  /// Builds the spans of every attribution fragment, wiring one tap
  /// recognizer per link. Recognizers are owned by this state, so the
  /// previous batch is disposed before a new one is built.
  List<InlineSpan> _buildSpans() {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    final fragments = attributionFragments(_attributions);
    for (var i = 0; i < fragments.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '  '));
      for (final run in parseAttributionHtml(fragments[i])) {
        final href = run.href;
        if (href == null) {
          spans.add(TextSpan(text: run.text));
          continue;
        }
        final recognizer = TapGestureRecognizer()
          ..onTap = () => unawaited(widget.openUri(href));
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: run.text, style: _linkStyle, recognizer: recognizer),
        );
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: () => setState(() => _expanded = !_expanded),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(
          Icons.info_outline,
          size: 18,
          color: Color(0xFF4A5560),
        ),
      ),
    );

    Widget? text;
    if (_expanded) {
      text = Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * _maxWidthFraction,
          ),
          child: RichText(
            text: TextSpan(style: _textStyle, children: _buildSpans()),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.iconAtStart) button,
            if (text != null) ...[
              const SizedBox(width: 2),
              text,
              const SizedBox(width: 6),
            ],
            if (!widget.iconAtStart) button,
          ],
        ),
      ),
    );
  }
}
