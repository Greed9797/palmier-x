import 'dart:io';

import '../../ffmpeg.dart' show resolveFfmpeg;
import '../models/video_analysis.dart';

final _silenceStart = RegExp(r'silence_start:\s*([0-9.]+)');
final _silenceEnd = RegExp(r'silence_end:\s*([0-9.]+)');

/// Detects silent spans (candidate dead-air cuts) via ffmpeg silencedetect.
Future<List<Silence>> detectSilences(
  String input, {
  double noiseDb = -30,
  double minDurationSec = 0.5,
}) async {
  final r = await Process.run(resolveFfmpeg(), [
    '-hide_banner',
    '-i', input,
    '-af', 'silencedetect=noise=${noiseDb}dB:d=$minDurationSec',
    '-f', 'null',
    '-',
  ]);
  // silencedetect logs to stderr.
  final out = '${r.stderr}';
  final silences = <Silence>[];
  double? start;
  for (final line in out.split('\n')) {
    final s = _silenceStart.firstMatch(line);
    if (s != null) {
      start = double.tryParse(s.group(1)!);
      continue;
    }
    final e = _silenceEnd.firstMatch(line);
    if (e != null && start != null) {
      silences.add(Silence(start: start, end: double.tryParse(e.group(1)!) ?? start));
      start = null;
    }
  }
  return silences;
}
