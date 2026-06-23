import 'dart:convert';

import '../models/cut_suggestion.dart';
import '../models/video_analysis.dart';
import '../providers/omni_provider.dart';

/// Builds the LLM prompt from analysis, calls the provider, and parses the
/// answer into CutSuggestion[]. Works with or without a transcript; BYOK
/// providers also receive the sampled frames.
class CutPlanner {
  CutPlanner(this.provider);
  final OmniProvider provider;

  Future<List<CutSuggestion>> plan(VideoAnalysis a, {int maxSuggestions = 8}) async {
    final prompt = _buildPrompt(a, maxSuggestions);
    final framePaths = provider.usesFrames ? a.frames.map((f) => f.path).toList() : const <String>[];
    final raw = await provider.analyze(prompt: prompt, framePaths: framePaths);
    return _parse(raw, a.probe.durationSec);
  }

  String _buildPrompt(VideoAnalysis a, int maxSuggestions) {
    final b = StringBuffer();
    b.writeln('You are a viral short-form video editor analyzing a source clip to pick the best moments to cut/keep.');
    b.writeln('Video duration: ${a.probe.durationSec.toStringAsFixed(2)}s, ${a.probe.width}x${a.probe.height}.');
    b.writeln();

    if (a.scenes.isNotEmpty) {
      b.writeln('Scene cuts (seconds): ${a.scenes.map((s) => s.tStart.toStringAsFixed(2)).join(', ')}');
    }
    if (a.silences.isNotEmpty) {
      b.writeln('Silences (start-end): ${a.silences.map((s) => '${s.start.toStringAsFixed(2)}-${s.end.toStringAsFixed(2)}').join(', ')}');
    }
    b.writeln();

    if (a.hasTranscript) {
      b.writeln('Transcript (start-end: text):');
      for (final s in a.transcript) {
        b.writeln('${s.start.toStringAsFixed(2)}-${s.end.toStringAsFixed(2)}: ${s.text}');
      }
    } else {
      b.writeln('No transcript available — judge from scene structure'
          '${provider.usesFrames ? ' and the attached frames' : ''}.');
    }
    if (provider.usesFrames && a.frames.isNotEmpty) {
      b.writeln();
      b.writeln('Attached frames (timestamps, seconds): '
          '${a.frames.map((f) => f.timestampSec.toStringAsFixed(1)).join(', ')}');
    }

    b.writeln();
    b.writeln('Return ONLY a JSON array (max $maxSuggestions items) of the strongest moments, each:');
    b.writeln('{"start":sec,"end":sec,"reason":"why it is engaging","score":0..1,'
        '"kind":"highlight|trim|removeSilence|captionMoment","suggestedCaption":"short on-screen text or null"}');
    b.writeln('Rules: start<end, both within 0..${a.probe.durationSec.toStringAsFixed(2)}. '
        'Order by score descending. Keep clips punchy (a few seconds). No prose outside the JSON.');
    return b.toString();
  }

  List<CutSuggestion> _parse(String raw, double duration) {
    final jsonText = _extractJsonArray(raw);
    if (jsonText == null) return const [];
    final List<dynamic> arr;
    try {
      arr = jsonDecode(jsonText) as List<dynamic>;
    } catch (_) {
      return const [];
    }
    final out = <CutSuggestion>[];
    for (var i = 0; i < arr.length; i++) {
      final m = arr[i];
      if (m is! Map) continue;
      var start = ((m['start'] ?? 0) as num).toDouble();
      var end = ((m['end'] ?? 0) as num).toDouble();
      if (end <= start) continue;
      start = start.clamp(0.0, duration);
      end = end.clamp(start + 0.05, duration <= 0 ? end : duration);
      out.add(CutSuggestion(
        id: 'omni_$i',
        start: start,
        end: end,
        reason: '${m['reason'] ?? ''}',
        score: ((m['score'] ?? 0.5) as num).toDouble().clamp(0.0, 1.0),
        kind: CutSuggestion.fromJson({
          'id': 'x', 'start': 0, 'end': 1, 'kind': '${m['kind'] ?? 'highlight'}',
        }).kind,
        suggestedCaption: (m['suggestedCaption'] is String &&
                (m['suggestedCaption'] as String).trim().isNotEmpty &&
                (m['suggestedCaption'] as String).toLowerCase() != 'null')
            ? (m['suggestedCaption'] as String).trim()
            : null,
      ));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  /// Pulls the first JSON array out of a possibly fenced / chatty answer.
  String? _extractJsonArray(String s) {
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start < 0 || end <= start) return null;
    return s.substring(start, end + 1);
  }
}
