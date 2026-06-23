import 'dart:math';

import '../models/edit_recipe.dart';
import '../models/video_analysis.dart';

/// Derives the "Edit DNA" from structural analysis using cheap heuristics
/// (no LLM cost). v2 will extract the same struct from a reference video and
/// use it to re-cut the user's footage.
EditRecipe extractRecipe(VideoAnalysis a) {
  final dur = a.probe.durationSec <= 0 ? 1.0 : a.probe.durationSec;

  // Clip lengths = gaps between consecutive cut boundaries (0 and dur included).
  final cuts = <double>[0, ...a.scenes.map((s) => s.tStart), dur]..sort();
  final lens = <double>[];
  for (var i = 1; i < cuts.length; i++) {
    final l = cuts[i] - cuts[i - 1];
    if (l > 0.01) lens.add(l);
  }
  lens.sort();

  double mean(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
  double median(List<double> xs) =>
      xs.isEmpty ? 0 : xs[xs.length ~/ 2];
  double std(List<double> xs, double m) =>
      xs.isEmpty ? 0 : sqrt(xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / xs.length);

  final avgLen = mean(lens);
  final pacing = PacingStat(
    avgClipLenSec: avgLen,
    medianClipLenSec: median(lens),
    cutsPerMinute: a.scenes.length / (dur / 60.0),
    stdClipLenSec: std(lens, avgLen),
  );

  // Caption cadence from transcript segments.
  final segs = a.transcript;
  final totalChars = segs.fold<int>(0, (s, e) => s + e.text.length);
  final totalSpeech = segs.fold<double>(0, (s, e) => s + (e.end - e.start));
  final segDurs = segs.map((e) => e.end - e.start).toList();
  final wordCounts = segs.map((e) => e.text.split(RegExp(r'\s+')).length).toList()..sort();
  final captionStyle = CaptionStyleStat(
    avgDurationSec: mean(segDurs),
    cps: totalSpeech > 0 ? totalChars / totalSpeech : 0,
    wordsPerCaptionMedian: wordCounts.isEmpty ? 0 : wordCounts[wordCounts.length ~/ 2],
  );

  return EditRecipe(
    pacing: pacing,
    captionStyle: captionStyle,
    hookWindowSec: 3.0,
    cutTimestamps: a.scenes.map((s) => (s.tStart / dur).clamp(0.0, 1.0)).toList(),
  );
}
