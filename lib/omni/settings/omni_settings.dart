import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../providers/provider_kind.dart';

/// Transcription backend, configured independently of the cut-suggestion
/// provider — even in CLI mode there is no Whisper endpoint, so a key (or
/// Gemini audio) is needed; `none` runs the pipeline frames/scene-only.
enum WhisperBackend { none, groq, openai, gemini }

WhisperBackend _whisperFrom(String s) =>
    WhisperBackend.values.firstWhere((w) => w.name == s, orElse: () => WhisperBackend.none);

OmniProviderKind _kindFrom(String s) =>
    OmniProviderKind.values.firstWhere((k) => k.name == s, orElse: () => OmniProviderKind.claudeCli);

/// Persisted Omni preferences: which provider drives cut suggestions and which
/// backend transcribes audio. Stored under the app-support dir.
class OmniSettings {
  const OmniSettings({
    this.provider = OmniProviderKind.claudeCli,
    this.whisperBackend = WhisperBackend.none,
  });

  final OmniProviderKind provider;
  final WhisperBackend whisperBackend;

  OmniSettings copyWith({OmniProviderKind? provider, WhisperBackend? whisperBackend}) =>
      OmniSettings(
        provider: provider ?? this.provider,
        whisperBackend: whisperBackend ?? this.whisperBackend,
      );

  Map<String, dynamic> toJson() =>
      {'provider': provider.name, 'whisperBackend': whisperBackend.name};

  factory OmniSettings.fromJson(Map<String, dynamic> j) => OmniSettings(
        provider: _kindFrom((j['provider'] ?? 'claudeCli') as String),
        whisperBackend: _whisperFrom((j['whisperBackend'] ?? 'none') as String),
      );

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final base = Directory(p.join(dir.path, 'palmier_x'));
    await base.create(recursive: true);
    return File(p.join(base.path, 'omni_settings.json'));
  }

  static Future<OmniSettings> load() async {
    final f = await _file();
    if (!await f.exists()) return const OmniSettings();
    try {
      return OmniSettings.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const OmniSettings();
    }
  }

  Future<void> save() async {
    final f = await _file();
    await f.writeAsString(jsonEncode(toJson()), flush: true);
  }
}
