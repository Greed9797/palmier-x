import 'cut_suggestion.dart';
import 'edit_recipe.dart';
import 'video_analysis.dart';

/// The full Omni output for one video: structural analysis + suggested cuts +
/// the editing fingerprint. Cached to disk as JSON.
class OmniResult {
  const OmniResult({
    required this.analysis,
    required this.suggestions,
    required this.recipe,
    this.provider,
  });

  final VideoAnalysis analysis;
  final List<CutSuggestion> suggestions;
  final EditRecipe recipe;
  final String? provider; // which provider produced the suggestions

  OmniResult copyWith({List<CutSuggestion>? suggestions, String? provider}) => OmniResult(
        analysis: analysis,
        suggestions: suggestions ?? this.suggestions,
        recipe: recipe,
        provider: provider ?? this.provider,
      );

  Map<String, dynamic> toJson() => {
        'analysis': analysis.toJson(),
        'suggestions': suggestions.map((s) => s.toJson()).toList(),
        'recipe': recipe.toJson(),
        if (provider != null) 'provider': provider,
      };

  factory OmniResult.fromJson(Map<String, dynamic> j) => OmniResult(
        analysis: VideoAnalysis.fromJson(j['analysis'] as Map<String, dynamic>),
        suggestions: ((j['suggestions'] as List?) ?? [])
            .map((s) => CutSuggestion.fromJson(s as Map<String, dynamic>))
            .toList(),
        recipe: EditRecipe.fromJson(j['recipe'] as Map<String, dynamic>),
        provider: j['provider'] as String?,
      );
}
