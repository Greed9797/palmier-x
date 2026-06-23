import 'dart:convert';
import 'dart:io';

import '../models/video_analysis.dart';

/// Resolves the ffprobe binary, mirroring resolveFfmpeg() in lib/ffmpeg.dart:
/// env FFPROBE → bundled next to the app → PATH fallback.
String resolveFfprobe() {
  final override = Platform.environment['FFPROBE'];
  if (override != null && override.isNotEmpty && File(override).existsSync()) {
    return override;
  }
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final sep = Platform.pathSeparator;
  final bundled = Platform.isWindows
      ? '$exeDir${sep}ffmpeg${sep}ffprobe.exe'
      : '$exeDir${sep}ffprobe';
  return File(bundled).existsSync() ? bundled : 'ffprobe';
}

double _parseFps(String? rate) {
  if (rate == null) return 0;
  final parts = rate.split('/');
  if (parts.length == 2) {
    final n = double.tryParse(parts[0]) ?? 0;
    final d = double.tryParse(parts[1]) ?? 1;
    return d == 0 ? 0 : n / d;
  }
  return double.tryParse(rate) ?? 0;
}

/// Probes [input] with ffprobe and returns structural metadata.
Future<ProbeMeta> probe(String input) async {
  final r = await Process.run(resolveFfprobe(), [
    '-v', 'quiet',
    '-print_format', 'json',
    '-show_streams',
    '-show_format',
    input,
  ]);
  if (r.exitCode != 0) {
    throw Exception('ffprobe falhou (${r.exitCode}): ${r.stderr}');
  }
  final json = jsonDecode(r.stdout as String) as Map<String, dynamic>;
  final streams = (json['streams'] as List? ?? []).cast<Map<String, dynamic>>();
  final format = (json['format'] as Map<String, dynamic>?) ?? const {};

  final video = streams.firstWhere(
    (s) => s['codec_type'] == 'video',
    orElse: () => const <String, dynamic>{},
  );
  final hasAudio = streams.any((s) => s['codec_type'] == 'audio');

  final duration = double.tryParse('${format['duration'] ?? video['duration'] ?? 0}') ?? 0;
  final bitrate = int.tryParse('${format['bit_rate'] ?? ''}');

  return ProbeMeta(
    durationSec: duration,
    width: (video['width'] as int?) ?? 0,
    height: (video['height'] as int?) ?? 0,
    fps: _parseFps(video['avg_frame_rate'] as String? ?? video['r_frame_rate'] as String?),
    codec: (video['codec_name'] as String?) ?? 'unknown',
    hasAudio: hasAudio,
    bitrate: bitrate,
  );
}
