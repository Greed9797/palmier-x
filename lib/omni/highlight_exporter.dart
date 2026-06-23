import 'package:path/path.dart' as p;

import '../ffmpeg.dart';
import 'models/cut_suggestion.dart';
import 'models/video_analysis.dart';

/// Exports each highlight as its own clip (the viral workflow): one exportVideo
/// call per suggestion, with the transcript captions that fall inside its
/// window burned in, reframed to [aspect]. Returns the number of clips written.
Future<int> exportHighlights({
  required String input,
  required List<CutSuggestion> suggestions,
  required List<TranscriptSegment> transcript,
  required ExportAspect aspect,
  required String fontPath,
  required String outDir,
  required String baseName,
  void Function(int done, int total)? onProgress,
}) async {
  var done = 0;
  for (var i = 0; i < suggestions.length; i++) {
    final s = suggestions[i];
    // Transcript segments overlapping the clip window → burned captions.
    // exportVideo shifts their times to clip-relative (subtracts s.start).
    final overlays = [
      for (final seg in transcript)
        if (seg.end > s.start && seg.start < s.end)
          TextOverlay(
            text: seg.text,
            start: seg.start,
            end: seg.end,
            cx: 0.5,
            cy: 0.85,
            sizeFrac: 0.07,
            colorHex: 'FFFFFF',
          ),
    ];
    final pct = (s.score * 100).round().toString().padLeft(2, '0');
    final name = '${baseName}_${(i + 1).toString().padLeft(2, '0')}_$pct.mp4';
    await exportVideo(
      input: input,
      output: p.join(outDir, name),
      start: s.start,
      end: s.end,
      fontPath: fontPath,
      overlays: overlays,
      aspect: aspect,
      onProgress: (_) {},
    );
    done++;
    onProgress?.call(done, suggestions.length);
  }
  return done;
}
