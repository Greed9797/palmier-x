/// A suggested edit on the source timeline. Maps directly onto the editor's
/// existing trim state and Caption model — no new export path.
enum CutKind { keep, trim, highlight, removeSilence, captionMoment }

CutKind _kindFrom(String s) =>
    CutKind.values.firstWhere((k) => k.name == s, orElse: () => CutKind.highlight);

class CutSuggestion {
  const CutSuggestion({
    required this.id,
    required this.start,
    required this.end,
    required this.reason,
    required this.score,
    this.kind = CutKind.highlight,
    this.suggestedCaption,
  });

  final String id;
  final double start; // source seconds
  final double end;
  final String reason; // why this is worth keeping/cutting (model rationale)
  final double score; // 0..1 confidence / virality
  final CutKind kind;
  final String? suggestedCaption; // when set → maps to a Caption

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        'reason': reason,
        'score': score,
        'kind': kind.name,
        if (suggestedCaption != null) 'suggestedCaption': suggestedCaption,
      };

  factory CutSuggestion.fromJson(Map<String, dynamic> j) => CutSuggestion(
        id: j['id'] as String,
        start: (j['start'] as num).toDouble(),
        end: (j['end'] as num).toDouble(),
        reason: (j['reason'] ?? '') as String,
        score: ((j['score'] ?? 0.5) as num).toDouble(),
        kind: _kindFrom((j['kind'] ?? 'highlight') as String),
        suggestedCaption: j['suggestedCaption'] as String?,
      );
}
