/// A Clarity community insight for a single perk / mod / catalyst plug, keyed
/// by the plug's `DestinyInventoryItemDefinition` hash — the same hash space
/// as [ItemPlug.plugHash], so the join is a direct map lookup.
///
/// The insight body is a structured document, not a plain string: a list of
/// [ClarityLine] blocks, each holding inline [ClaritySpan]s. Nodes carry no
/// `type` field; their role is inferred from which fields are set, and
/// `classNames` carries all styling (see doc/clarity_community_insights_plan.md).
class ClarityInsight {
  const ClarityInsight({
    required this.hash,
    required this.name,
    required this.lines,
  });

  final int hash;
  final String name;
  final List<ClarityLine> lines;

  /// Parse one `dim.json` entry, or null when it has no usable description.
  /// Reads the `en` document, falling back to the first available language.
  static ClarityInsight? fromJson(Map<String, dynamic> json) {
    final hash = (json['hash'] as num?)?.toInt();
    if (hash == null) return null;
    final descriptions = json['descriptions'];
    if (descriptions is! Map<String, dynamic> || descriptions.isEmpty) {
      return null;
    }
    final doc = descriptions['en'] ?? descriptions.values.first;
    if (doc is! List) return null;
    final lines = [
      for (final line in doc)
        if (line is Map<String, dynamic>) ClarityLine.fromJson(line),
    ];
    if (lines.isEmpty) return null;
    return ClarityInsight(
      hash: hash,
      name: (json['name'] as String?) ?? '',
      lines: lines,
    );
  }
}

/// One block-level line of an insight document. A line with the `spacer`
/// className is a visual divider/gap and typically has no content.
class ClarityLine {
  const ClarityLine({this.classNames = const [], this.content = const []});

  final List<String> classNames;
  final List<ClaritySpan> content;

  bool get isSpacer => classNames.contains('spacer');

  factory ClarityLine.fromJson(Map<String, dynamic> json) => ClarityLine(
        classNames: _stringList(json['classNames']),
        content: [
          for (final span in (json['linesContent'] as List? ?? const []))
            if (span is Map<String, dynamic>) ClaritySpan.fromJson(span),
        ],
      );
}

/// One inline span: its [text] (may be empty for icon-only markers such as a
/// damage-type glyph or the `enhancedArrow`), styling [classNames]
/// (`bold`, damage types, ammo, champions, classes), and an optional [link]
/// URL. Only http(s) links may be rendered tappable — the data is
/// community-authored, so the scheme must be checked before launching.
class ClaritySpan {
  const ClaritySpan({this.text = '', this.classNames = const [], this.link});

  final String text;
  final List<String> classNames;
  final String? link;

  factory ClaritySpan.fromJson(Map<String, dynamic> json) => ClaritySpan(
        text: (json['text'] as String?) ?? '',
        classNames: _stringList(json['classNames']),
        link: json['link'] as String?,
      );
}

List<String> _stringList(Object? value) =>
    [if (value is List) for (final v in value) v.toString()];
