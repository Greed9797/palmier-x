import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A burned-in text overlay, in SOURCE-time coordinates. Geometry is fractional
/// (0..1 of the frame) so it survives unknown video dimensions.
class TextOverlay {
  const TextOverlay({
    required this.text,
    required this.start,
    required this.end,
    required this.cx,
    required this.cy,
    required this.sizeFrac,
    required this.colorHex, // 'RRGGBB'
  });
  final String text;
  final double start;
  final double end;
  final double cx;
  final double cy;
  final double sizeFrac;
  final String colorHex;
}

/// Resolves the ffmpeg binary: a bundled copy next to the executable wins
/// (Windows distribution), otherwise fall back to whatever is on PATH (dev).
// ponytail: bundled-binary lookup is the only packaging step; PATH covers dev.
String resolveFfmpeg() {
  final override = Platform.environment['FFMPEG'];
  if (override != null && override.isNotEmpty && File(override).existsSync()) {
    return override;
  }
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final sep = Platform.pathSeparator;
  final bundled = Platform.isWindows
      ? '$exeDir${sep}ffmpeg${sep}ffmpeg.exe'
      : '$exeDir${sep}ffmpeg';
  return File(bundled).existsSync() ? bundled : 'ffmpeg';
}

/// Escapes a filesystem path for use inside an ffmpeg filter argument
/// (backslashes to forward slashes, colon escaped — Windows `C:\` → `C\:/`).
String _ffPath(String p) => p.replaceAll('\\', '/').replaceAll(':', '\\:');

String _drawtext(TextOverlay o, String fontPath, String textFile, double trimStart) {
  // -ss before -i resets output timestamps to 0, so shift enable window.
  final s = (o.start - trimStart).clamp(0.0, double.infinity);
  final e = (o.end - trimStart).clamp(0.0, double.infinity);
  // textfile= reads UTF-8 from disk: dodges command-line arg encoding (Windows
  // mangles multibyte chars in argv) and all drawtext text escaping.
  return "drawtext=fontfile='${_ffPath(fontPath)}'"
      ":textfile='${_ffPath(textFile)}'"
      ':fontsize=(h*${o.sizeFrac.toStringAsFixed(4)})'
      ':fontcolor=0x${o.colorHex}'
      ':x=(w*${o.cx.toStringAsFixed(4)}-text_w/2)'
      ':y=(h*${o.cy.toStringAsFixed(4)}-text_h/2)'
      ':box=1:boxcolor=black@0.45:boxborderw=12'
      ":enable='between(t,${s.toStringAsFixed(3)},${e.toStringAsFixed(3)})'";
}

/// Trims [input] to [start]..[end] (seconds), burns [overlays], re-encodes to
/// H.264/AAC. Emits 0..1 progress from ffmpeg's `out_time_ms` lines.
Future<void> exportVideo({
  required String input,
  required String output,
  required double start,
  required double end,
  required String fontPath,
  List<TextOverlay> overlays = const [],
  required void Function(double progress) onProgress,
}) async {
  final duration = (end - start).clamp(0.001, double.infinity);

  // Keep only overlays that intersect the trimmed range.
  final active =
      overlays.where((o) => o.end > start && o.start < end).toList();

  // Each caption's text goes to a UTF-8 file (referenced via textfile=).
  Directory? textDir;
  final filters = <String>[];
  if (active.isNotEmpty) {
    textDir = await Directory.systemTemp.createTemp('palmierx_cap');
    final sep = Platform.pathSeparator;
    for (var i = 0; i < active.length; i++) {
      final path = '${textDir.path}${sep}cap$i.txt';
      await File(path).writeAsString(active[i].text, flush: true); // UTF-8
      filters.add(_drawtext(active[i], fontPath, path, start));
    }
  }

  final args = <String>[
    '-y',
    '-ss', start.toStringAsFixed(3),
    '-to', end.toStringAsFixed(3),
    '-i', input,
    if (filters.isNotEmpty) ...['-vf', filters.join(',')],
    '-c:v', 'libx264',
    '-preset', 'veryfast',
    '-crf', '20',
    '-c:a', 'aac',
    '-progress', 'pipe:1', // progress on stdout keeps stderr pure for errors
    '-nostats',
    output,
  ];

  final proc = await Process.start(resolveFfmpeg(), args);
  final errBuffer = StringBuffer();

  // Progress (stdout): key=value lines, including out_time_ms=<microseconds>.
  proc.stdout
      .transform(const SystemEncoding().decoder)
      .transform(const LineSplitter())
      .listen((line) {
    if (line.startsWith('out_time_ms=')) {
      final us = int.tryParse(line.substring('out_time_ms='.length).trim());
      if (us != null) {
        onProgress((us / 1e6 / duration).clamp(0.0, 1.0));
      }
    }
  });

  // Errors (stderr): keep the whole thing so a failure surfaces the real cause.
  proc.stderr
      .transform(const SystemEncoding().decoder)
      .transform(const LineSplitter())
      .listen(errBuffer.writeln);

  try {
    final code = await proc.exitCode;
    if (code != 0) {
      final tail = errBuffer.toString().split('\n').reversed.take(20).toList().reversed.join('\n');
      throw Exception('ffmpeg exited $code\n$tail');
    }
    onProgress(1.0);
  } finally {
    await textDir?.delete(recursive: true);
  }
}
