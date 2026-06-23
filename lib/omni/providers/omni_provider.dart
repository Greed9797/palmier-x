/// Abstraction over the LLM that turns analysis into cut suggestions.
/// Implementations: CLIProvider (claude/codex subprocess) and BYOKProvider
/// (Gemini/OpenAI HTTP). Returns the model's raw text answer (caller parses
/// it into CutSuggestion[]).
abstract class OmniProvider {
  /// [framePaths] are JPEG paths on disk; BYOK sends them as base64 images,
  /// CLI v1 ignores them (transcript + scene/silence digest only).
  Future<String> analyze({
    required String prompt,
    List<String> framePaths,
    String? jsonSchema,
  });

  /// True when usable: CLI binary on PATH, or BYOK key present.
  Future<bool> isAvailable();

  /// True when this provider sends real multimodal frames.
  bool get usesFrames;
}
