/// The engine's cut-suggestion provider. CLI kinds drive a local `claude`/
/// `codex` subprocess (no API key, uses the user's CLI subscription); BYOK
/// kinds call Gemini/OpenAI over HTTP with an API key. Mirrors the Swift
/// LLMProvider split (CLIClient vs OpenAICompatClient).
enum OmniProviderKind { claudeCli, codexCli, gemini, openai }

extension OmniProviderKindX on OmniProviderKind {
  bool get isCli => this == OmniProviderKind.claudeCli || this == OmniProviderKind.codexCli;
  bool get isByok => !isCli;

  String get label => switch (this) {
        OmniProviderKind.claudeCli => 'Claude CLI',
        OmniProviderKind.codexCli => 'Codex CLI',
        OmniProviderKind.gemini => 'Gemini (BYOK)',
        OmniProviderKind.openai => 'OpenAI (BYOK)',
      };

  /// Secret-store key for BYOK providers (null for CLI).
  String? get secretKey => switch (this) {
        OmniProviderKind.gemini => 'gemini',
        OmniProviderKind.openai => 'openai',
        _ => null,
      };
}
