import 'dart:convert';
import 'dart:io';

import '../settings/secret_store.dart';
import 'omni_provider.dart';
import 'provider_kind.dart';

/// Calls a BYOK multimodal model (Gemini generateContent or OpenAI chat
/// completions) with the prompt + base64 frames. Key comes from SecretStore and
/// is NEVER logged (errors redact any `key=` query param).
class BYOKProvider implements OmniProvider {
  BYOKProvider(this.kind, this.secrets)
      : assert(kind == OmniProviderKind.gemini || kind == OmniProviderKind.openai);

  final OmniProviderKind kind;
  final SecretStore secrets;

  static const int maxFrames = 24;
  static const _geminiModel = 'gemini-2.5-flash';
  static const _openaiModel = 'gpt-4o-mini';

  @override
  bool get usesFrames => true;

  @override
  Future<bool> isAvailable() => secrets.hasKey(kind.secretKey!);

  @override
  Future<String> analyze({
    required String prompt,
    List<String> framePaths = const [],
    String? jsonSchema,
  }) async {
    final key = await secrets.read(kind.secretKey!);
    if (key == null || key.isEmpty) {
      throw Exception('Sem chave ${kind.label}. Configure nas settings do Omni.');
    }
    final frames = framePaths.take(maxFrames).toList();
    final b64 = <String>[];
    for (final f in frames) {
      b64.add(base64Encode(await File(f).readAsBytes()));
    }
    return kind == OmniProviderKind.gemini
        ? _gemini(prompt, b64, key)
        : _openai(prompt, b64, key);
  }

  Future<String> _gemini(String prompt, List<String> frames, String key) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$key');
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      for (final f in frames)
        {'inline_data': {'mime_type': 'image/jpeg', 'data': f}},
    ];
    final body = {
      'contents': [{'parts': parts}],
      'generationConfig': {'responseMimeType': 'application/json'},
    };
    final json = await _post(url, {'Content-Type': 'application/json'}, body);
    final candidates = json['candidates'] as List?;
    final textParts =
        (candidates?.first['content']?['parts'] as List?)?.cast<Map<String, dynamic>>();
    return (textParts?.firstWhere((p) => p['text'] != null, orElse: () => const {})['text']
            as String?) ??
        '';
  }

  Future<String> _openai(String prompt, List<String> frames, String key) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      for (final f in frames)
        {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$f'}},
    ];
    final body = {
      'model': _openaiModel,
      'messages': [{'role': 'user', 'content': content}],
      'response_format': {'type': 'json_object'},
    };
    final json = await _post(
        url, {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'}, body);
    return (json['choices']?.first['message']?['content'] as String?) ?? '';
  }

  Future<Map<String, dynamic>> _post(
      Uri url, Map<String, String> headers, Object body) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(url);
      headers.forEach(req.headers.set);
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${_redact(text)}');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  // Never leak a key that might appear in an echoed URL/body.
  String _redact(String s) {
    final t = s.length > 400 ? s.substring(0, 400) : s;
    return t.replaceAll(RegExp(r'key=[\w\-]+'), 'key=***');
  }
}
