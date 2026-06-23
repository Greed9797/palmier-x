/// Structural analysis of a source video: probe metadata, detected scene cuts,
/// silences, transcript, and sampled frames. Provider-independent — produced by
/// the pipeline once and cached. Frames are referenced by PATH, never bytes.
class ProbeMeta {
  const ProbeMeta({
    required this.durationSec,
    required this.width,
    required this.height,
    required this.fps,
    required this.codec,
    required this.hasAudio,
    this.bitrate,
  });

  final double durationSec;
  final int width;
  final int height;
  final double fps;
  final String codec;
  final bool hasAudio;
  final int? bitrate;

  Map<String, dynamic> toJson() => {
        'durationSec': durationSec,
        'width': width,
        'height': height,
        'fps': fps,
        'codec': codec,
        'hasAudio': hasAudio,
        if (bitrate != null) 'bitrate': bitrate,
      };

  factory ProbeMeta.fromJson(Map<String, dynamic> j) => ProbeMeta(
        durationSec: (j['durationSec'] as num).toDouble(),
        width: j['width'] as int,
        height: j['height'] as int,
        fps: (j['fps'] as num).toDouble(),
        codec: j['codec'] as String,
        hasAudio: j['hasAudio'] as bool,
        bitrate: j['bitrate'] as int?,
      );
}

class Scene {
  const Scene({required this.tStart, required this.score});
  final double tStart; // seconds — a detected cut boundary
  final double score; // scene-change score (0..1)

  Map<String, dynamic> toJson() => {'tStart': tStart, 'score': score};
  factory Scene.fromJson(Map<String, dynamic> j) =>
      Scene(tStart: (j['tStart'] as num).toDouble(), score: (j['score'] as num).toDouble());
}

class Silence {
  const Silence({required this.start, required this.end});
  final double start;
  final double end;
  double get duration => end - start;

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
  factory Silence.fromJson(Map<String, dynamic> j) =>
      Silence(start: (j['start'] as num).toDouble(), end: (j['end'] as num).toDouble());
}

class TranscriptWord {
  const TranscriptWord({required this.text, required this.start, required this.end});
  final String text;
  final double start;
  final double end;

  Map<String, dynamic> toJson() => {'text': text, 'start': start, 'end': end};
  factory TranscriptWord.fromJson(Map<String, dynamic> j) => TranscriptWord(
        text: j['text'] as String,
        start: (j['start'] as num).toDouble(),
        end: (j['end'] as num).toDouble(),
      );
}

class TranscriptSegment {
  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
    this.words = const [],
  });
  final double start;
  final double end;
  final String text;
  final List<TranscriptWord> words;

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'text': text,
        'words': words.map((w) => w.toJson()).toList(),
      };
  factory TranscriptSegment.fromJson(Map<String, dynamic> j) => TranscriptSegment(
        start: (j['start'] as num).toDouble(),
        end: (j['end'] as num).toDouble(),
        text: j['text'] as String,
        words: ((j['words'] as List?) ?? [])
            .map((w) => TranscriptWord.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}

class SampledFrame {
  const SampledFrame({required this.index, required this.timestampSec, required this.path});
  final int index;
  final double timestampSec;
  final String path; // JPEG on disk (cache dir)

  Map<String, dynamic> toJson() => {'index': index, 'timestampSec': timestampSec, 'path': path};
  factory SampledFrame.fromJson(Map<String, dynamic> j) => SampledFrame(
        index: j['index'] as int,
        timestampSec: (j['timestampSec'] as num).toDouble(),
        path: j['path'] as String,
      );
}

class VideoAnalysis {
  const VideoAnalysis({
    required this.inputPath,
    required this.inputHash,
    required this.probe,
    this.scenes = const [],
    this.silences = const [],
    this.transcript = const [],
    this.frames = const [],
    this.transcriptSource,
  });

  final String inputPath;
  final String inputHash;
  final ProbeMeta probe;
  final List<Scene> scenes;
  final List<Silence> silences;
  final List<TranscriptSegment> transcript;
  final List<SampledFrame> frames;
  final String? transcriptSource; // 'groq' | 'openai' | 'gemini' | null (frames-only)

  bool get hasTranscript => transcript.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'inputPath': inputPath,
        'inputHash': inputHash,
        'probe': probe.toJson(),
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'silences': silences.map((s) => s.toJson()).toList(),
        'transcript': transcript.map((s) => s.toJson()).toList(),
        'frames': frames.map((f) => f.toJson()).toList(),
        if (transcriptSource != null) 'transcriptSource': transcriptSource,
      };

  factory VideoAnalysis.fromJson(Map<String, dynamic> j) => VideoAnalysis(
        inputPath: j['inputPath'] as String,
        inputHash: j['inputHash'] as String,
        probe: ProbeMeta.fromJson(j['probe'] as Map<String, dynamic>),
        scenes: ((j['scenes'] as List?) ?? [])
            .map((s) => Scene.fromJson(s as Map<String, dynamic>))
            .toList(),
        silences: ((j['silences'] as List?) ?? [])
            .map((s) => Silence.fromJson(s as Map<String, dynamic>))
            .toList(),
        transcript: ((j['transcript'] as List?) ?? [])
            .map((s) => TranscriptSegment.fromJson(s as Map<String, dynamic>))
            .toList(),
        frames: ((j['frames'] as List?) ?? [])
            .map((f) => SampledFrame.fromJson(f as Map<String, dynamic>))
            .toList(),
        transcriptSource: j['transcriptSource'] as String?,
      );
}
