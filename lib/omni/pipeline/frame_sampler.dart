import 'dart:io';

import '../../ffmpeg.dart' show resolveFfmpeg;
import '../models/video_analysis.dart';

/// Frame budget by duration (mirrors the watch skill's auto-fps logic).
int frameBudget(double durationSec) {
  if (durationSec <= 30) return 30;
  if (durationSec <= 60) return 40;
  if (durationSec <= 180) return 60;
  if (durationSec <= 600) return 80;
  return 100;
}

/// Extracts evenly-spaced 512px-wide JPEG frames from [input] into [outDir].
/// Returns the sampled frames with their source timestamps.
Future<List<SampledFrame>> sampleFrames({
  required String input,
  required double durationSec,
  required String outDir,
}) async {
  await Directory(outDir).create(recursive: true);
  final budget = frameBudget(durationSec);
  // fps so that ~budget frames span the whole clip; floor to a sane minimum.
  final fps = durationSec <= 0 ? 1.0 : (budget / durationSec).clamp(0.05, 10.0);
  final sep = Platform.pathSeparator;
  final pattern = '$outDir${sep}frame_%04d.jpg';

  final r = await Process.run(resolveFfmpeg(), [
    '-y',
    '-i', input,
    '-vf', 'fps=$fps,scale=512:-2',
    '-q:v', '4',
    pattern,
  ]);
  if (r.exitCode != 0) {
    throw Exception('ffmpeg frame extraction falhou (${r.exitCode}): ${r.stderr}');
  }

  final files = Directory(outDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jpg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  return [
    for (var i = 0; i < files.length; i++)
      SampledFrame(index: i, timestampSec: i / fps, path: files[i].path),
  ];
}
