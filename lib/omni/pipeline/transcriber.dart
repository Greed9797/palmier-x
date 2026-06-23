import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../ffmpeg.dart' show resolveFfmpeg;
import '../models/video_analysis.dart';
import '../settings/omni_settings.dart';
import '../settings/secret_store.dart';

/// Extracts a small mono 16kHz mp3 (Whisper-friendly) into [dir]; returns its
/// path, or null if the input has no audio / extraction fails.
Future<String?> extractAudio(String input, String dir) async {
  await Directory(dir).create(recursive: true);
  final out = p.join(dir, 'audio.mp3');
  final r = await Process.run(resolveFfmpeg(), [
    '-y', '-i', input, '-vn', '-ac', '1', '-ar', '16000', '-b:a', '64k', out,
  ]);
  if (r.exitCode != 0 || !File(out).existsSync()) return null;
  return out;
}

abstract class Transcriber {
  String get sourceName;
  Future<List<TranscriptSegment>> transcribe(String input, String workDir);
}

/// Resolves the configured transcription backend, or null when transcription is
/// disabled / no key (pipeline then runs frames/scene-only).
Future<Transcriber?> makeTranscriber(OmniSettings s, SecretStore secrets) async {
  switch (s.whisperBackend) {
    case WhisperBackend.none:
      return null;
    case WhisperBackend.groq:
      final k = await secrets.read('groq');
      return (k == null || k.isEmpty)
          ? null
          : WhisperTranscriber(
              endpoint: Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
              model: 'whisper-large-v3',
              key: k,
              sourceName: 'groq');
    case WhisperBackend.openai:
      final k = await secrets.read('openai');
      return (k == null || k.isEmpty)
          ? null
          : WhisperTranscriber(
              endpoint: Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
              model: 'whisper-1',
              key: k,
              sourceName: 'openai');
    case WhisperBackend.gemini:
      final k = await secrets.read('gemini');
      return (k == null || k.isEmpty) ? null : GeminiAudioTranscriber(k);
  }
}

/// OpenAI-compatible Whisper (Groq or OpenAI) — multipart upload, verbose_json
/// gives segment-level start/end/text.
class WhisperTranscriber implements Transcriber {
  WhisperTranscriber({
    required this.endpoint,
    required this.model,
    required this.key,
    required this.sourceName,
  });

  final Uri endpoint;
  final String model;
  final String key;
  @override
  final String sourceName;

  @override
  Future<List<TranscriptSegment>> transcribe(String input, String workDir) async {
    final audio = await extractAudio(input, workDir);
    if (audio == null) return const [];

    final boundary = '----palmierx${DateTime.now().microsecondsSinceEpoch}';
    final fileBytes = await File(audio).readAsBytes();
    final pre = StringBuffer()
      ..write('--$boundary\r\n')
      ..write('Content-Disposition: form-data; name="model"\r\n\r\n$model\r\n')
      ..write('--$boundary\r\n')
      ..write('Content-Disposition: form-data; name="response_format"\r\n\r\nverbose_json\r\n')
      ..write('--$boundary\r\n')
      ..write('Content-Disposition: form-data; name="file"; filename="audio.mp3"\r\n')
      ..write('Content-Type: audio/mpeg\r\n\r\n');
    final body = <int>[
      ...utf8.encode(pre.toString()),
      ...fileBytes,
      ...utf8.encode('\r\n--$boundary--\r\n'),
    ];

    final client = HttpClient();
    try {
      final req = await client.postUrl(endpoint);
      req.headers.set('Authorization', 'Bearer $key');
      req.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');
      req.add(body);
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 300) {
        throw Exception('Transcrição HTTP ${resp.statusCode}: ${text.length > 300 ? text.substring(0, 300) : text}');
      }
      final json = jsonDecode(text) as Map<String, dynamic>;
      final segs = (json['segments'] as List?) ?? [];
      return segs
          .map((e) => TranscriptSegment(
                start: ((e['start'] ?? 0) as num).toDouble(),
                end: ((e['end'] ?? 0) as num).toDouble(),
                text: ('${e['text'] ?? ''}').trim(),
              ))
          .where((s) => s.text.isNotEmpty)
          .toList();
    } finally {
      client.close(force: true);
    }
  }
}

/// Gemini audio: send the clip's audio and ask for JSON segments. Coarser than
/// Whisper (no guaranteed word timing) but needs only the Gemini key.
class GeminiAudioTranscriber implements Transcriber {
  GeminiAudioTranscriber(this.key);
  final String key;
  @override
  String get sourceName => 'gemini';

  @override
  Future<List<TranscriptSegment>> transcribe(String input, String workDir) async {
    final audio = await extractAudio(input, workDir);
    if (audio == null) return const [];
    final b64 = base64Encode(await File(audio).readAsBytes());
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$key');
    final body = {
      'contents': [
        {
          'parts': [
            {
              'text': 'Transcribe this audio. Return ONLY a JSON array of '
                  '{"start":seconds,"end":seconds,"text":string} segments.'
            },
            {'inline_data': {'mime_type': 'audio/mpeg', 'data': b64}},
          ]
        }
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    };
    final client = HttpClient();
    try {
      final req = await client.postUrl(url);
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 300) return const [];
      final json = jsonDecode(text) as Map<String, dynamic>;
      final raw = (json['candidates'] as List?)?.first['content']?['parts']?.first['text']
          as String?;
      if (raw == null) return const [];
      final arr = jsonDecode(raw);
      if (arr is! List) return const [];
      return arr
          .map((e) => TranscriptSegment(
                start: ((e['start'] ?? 0) as num).toDouble(),
                end: ((e['end'] ?? 0) as num).toDouble(),
                text: ('${e['text'] ?? ''}').trim(),
              ))
          .where((s) => s.text.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }
}
