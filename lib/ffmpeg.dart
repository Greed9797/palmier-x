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

// Nominal ASS canvas; libass scales fractional positions to the real frame.
const _assResX = 1280;
const _assResY = 720;

/// ASS time: H:MM:SS.cc (centiseconds).
String _assTime(double sec) {
  final s = sec < 0 ? 0.0 : sec;
  final h = s ~/ 3600;
  final m = (s ~/ 60) % 60;
  final ss = (s % 60);
  final cs = ((ss - ss.truncate()) * 100).round();
  return '$h:${m.toString().padLeft(2, '0')}:${ss.truncate().toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
}

/// RRGGBB → ASS &HAABBGGRR (BGR, alpha 00 = opaque).
String _assColor(String rrggbb) {
  final r = rrggbb.substring(0, 2);
  final g = rrggbb.substring(2, 4);
  final b = rrggbb.substring(4, 6);
  return '&H00$b$g$r';
}

/// Inline-block text: ASS uses {..} for override tags, \N for newlines.
// ponytail: captions with literal braces are vanishingly rare; neutralise them.
String _assText(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('{', '(').replaceAll('}', ')').replaceAll('\n', r'\N');

/// Builds an ASS subtitle document burning every overlay (times relative to the
/// trimmed output). Geometry/size are fractional → positioned in the nominal
/// canvas; libass scales to the real video. Style box (BorderStyle 3) matches
/// the preview's caption background.
String _buildAss(List<TextOverlay> active, double trimStart) {
  final events = active.map((o) {
    final start = _assTime(o.start - trimStart);
    final end = _assTime(o.end - trimStart);
    final fs = (o.sizeFrac * _assResY).round();
    final x = (o.cx * _assResX).round();
    final y = (o.cy * _assResY).round();
    final tags = '{\\an5\\pos($x,$y)\\fs$fs\\1c${_assColor(o.colorHex)}}';
    return 'Dialogue: 0,$start,$end,Default,,0,0,0,,$tags${_assText(o.text)}';
  }).join('\n');

  return '''
[Script Info]
ScriptType: v4.00+
PlayResX: $_assResX
PlayResY: $_assResY
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,DejaVu Sans,48,&H00FFFFFF,&H000000FF,&H73000000,&H73000000,0,0,0,0,100,100,0,0,3,8,0,5,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
$events
''';
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

  // Captions are burned through libass: write an .ass file and render it with
  // the subtitles filter. fontsdir points libass at the bundled DejaVu Sans.
  Directory? subDir;
  String? vf;
  if (active.isNotEmpty) {
    subDir = await Directory.systemTemp.createTemp('palmierx_cap');
    final assPath = '${subDir.path}${Platform.pathSeparator}subs.ass';
    await File(assPath).writeAsString(_buildAss(active, start), flush: true);
    final fontsDir = File(fontPath).parent.path;
    vf = "subtitles='${_ffPath(assPath)}':fontsdir='${_ffPath(fontsDir)}'";
  }

  final args = <String>[
    '-y',
    '-ss', start.toStringAsFixed(3),
    '-to', end.toStringAsFixed(3),
    '-i', input,
    if (vf != null) ...['-vf', vf],
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
    await subDir?.delete(recursive: true);
  }
}
