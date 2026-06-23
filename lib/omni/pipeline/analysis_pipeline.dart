import 'package:path/path.dart' as p;

import '../models/analysis_result.dart';
import '../models/video_analysis.dart';
import '../providers/omni_provider.dart';
import 'cut_planner.dart';
import 'frame_sampler.dart';
import 'media_probe.dart';
import 'recipe_extractor.dart';
import 'scene_detector.dart';
import 'silence_detector.dart';
import 'transcriber.dart';

typedef OmniProgress = void Function(String stage, double fraction);

/// Orchestrates the analysis stages off the UI thread (all stages are async
/// Process/HTTP I/O). [workDir] holds extracted frames/audio (the cache dir).
class AnalysisPipeline {
  /// Provider-independent structural analysis (cacheable).
  static Future<VideoAnalysis> analyze({
    required String input,
    required String inputHash,
    required String workDir,
    Transcriber? transcriber,
    OmniProgress? onProgress,
  }) async {
    onProgress?.call('Lendo metadados…', 0.05);
    final meta = await probe(input);

    onProgress?.call('Amostrando frames…', 0.2);
    final frames = await sampleFrames(
      input: input,
      durationSec: meta.durationSec,
      outDir: p.join(workDir, 'frames'),
    );

    onProgress?.call('Detectando cenas…', 0.45);
    final scenes = await detectScenes(input);

    onProgress?.call('Detectando silêncios…', 0.55);
    final silences = await detectSilences(input);

    List<TranscriptSegment> transcript = const [];
    String? source;
    if (transcriber != null) {
      onProgress?.call('Transcrevendo…', 0.7);
      try {
        transcript = await transcriber.transcribe(input, p.join(workDir, 'audio'));
        if (transcript.isNotEmpty) source = transcriber.sourceName;
      } catch (_) {
        // Graceful: fall back to frames/scene-only.
      }
    }

    return VideoAnalysis(
      inputPath: input,
      inputHash: inputHash,
      probe: meta,
      scenes: scenes,
      silences: silences,
      transcript: transcript,
      frames: frames,
      transcriptSource: source,
    );
  }

  /// Full run: structural analysis + recipe + LLM cut suggestions.
  static Future<OmniResult> run({
    required String input,
    required String inputHash,
    required String workDir,
    required OmniProvider provider,
    required String providerName,
    Transcriber? transcriber,
    OmniProgress? onProgress,
    VideoAnalysis? cachedAnalysis,
  }) async {
    final analysis = cachedAnalysis ??
        await analyze(
          input: input,
          inputHash: inputHash,
          workDir: workDir,
          transcriber: transcriber,
          onProgress: onProgress,
        );

    final recipe = extractRecipe(analysis);

    onProgress?.call('Pedindo cortes ao $providerName…', 0.9);
    final suggestions = await CutPlanner(provider).plan(analysis);

    onProgress?.call('Pronto', 1.0);
    return OmniResult(
      analysis: analysis,
      suggestions: suggestions,
      recipe: recipe,
      provider: providerName,
    );
  }
}
