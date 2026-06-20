import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Resolves the ffmpeg binary: a bundled copy next to the executable wins
/// (Windows distribution), otherwise fall back to whatever is on PATH (dev).
// ponytail: bundled-binary lookup is the only packaging step; PATH covers dev.
String resolveFfmpeg() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final bundled = Platform.isWindows
      ? '$exeDir${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}ffmpeg.exe'
      : '$exeDir${Platform.pathSeparator}ffmpeg';
  return File(bundled).existsSync() ? bundled : 'ffmpeg';
}

/// Trims [input] to [start]..[end] (seconds) and re-encodes to H.264/AAC.
/// Emits 0..1 progress parsed from ffmpeg's `time=` stderr lines.
Future<void> exportTrim({
  required String input,
  required String output,
  required double start,
  required double end,
  required void Function(double progress) onProgress,
}) async {
  final duration = (end - start).clamp(0.001, double.infinity);
  final args = [
    '-y',
    '-ss', start.toStringAsFixed(3),
    '-to', end.toStringAsFixed(3),
    '-i', input,
    '-c:v', 'libx264',
    '-preset', 'veryfast',
    '-crf', '20',
    '-c:a', 'aac',
    '-progress', 'pipe:2',
    '-nostats',
    output,
  ];

  final proc = await Process.start(resolveFfmpeg(), args);
  final errBuffer = StringBuffer();

  proc.stderr
      .transform(const SystemEncoding().decoder)
      .transform(const LineSplitter())
      .listen((line) {
    errBuffer.writeln(line);
    // -progress emits `out_time_ms=<microseconds>` lines.
    if (line.startsWith('out_time_ms=')) {
      final us = int.tryParse(line.substring('out_time_ms='.length).trim());
      if (us != null) {
        onProgress((us / 1e6 / duration).clamp(0.0, 1.0));
      }
    }
  });

  final code = await proc.exitCode;
  if (code != 0) {
    throw Exception('ffmpeg exited $code\n${errBuffer.toString().split('\n').reversed.take(8).toList().reversed.join('\n')}');
  }
  onProgress(1.0);
}
