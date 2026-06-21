import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:palmier_x/ffmpeg.dart';

/// Integration check of the export money-path: generate a clip, trim it,
/// optionally burn a caption, and assert the output's trimmed duration.
/// Uses `resolveFfmpeg()` (honours the FFMPEG env override so CI can point at
/// the binary it ships); ffprobe via FFPROBE env or PATH.
void main() {
  final ffmpeg = resolveFfmpeg();
  final ffprobe = Platform.environment['FFPROBE'] ?? 'ffprobe';
  late Directory tmp;
  late String src;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('palmierx_');
    src = '${tmp.path}/src.mp4';
    final gen = await Process.run(ffmpeg, [
      '-y', '-f', 'lavfi', '-i', 'testsrc=duration=5:size=320x240:rate=30',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', src,
    ]);
    expect(gen.exitCode, 0, reason: 'ffmpeg gen failed: ${gen.stderr}');
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<double> probeDuration(String path) async {
    final probe = await Process.run(ffprobe, [
      '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=nw=1:nk=1', path,
    ]);
    return double.parse((probe.stdout as String).trim());
  }

  Future<bool> hasDrawtext() async {
    final r = await Process.run(ffmpeg, ['-hide_banner', '-filters']);
    return (r.stdout as String).contains('drawtext');
  }

  test('exportVideo trims to the requested range', () async {
    final out = '${tmp.path}/out.mp4';
    var last = 0.0;
    await exportVideo(
      input: src,
      output: out,
      start: 1.0,
      end: 3.0,
      fontPath: 'assets/fonts/DejaVuSans.ttf',
      onProgress: (v) => last = v,
    );
    expect(File(out).existsSync(), true);
    expect(last, 1.0);
    expect(await probeDuration(out), closeTo(2.0, 0.3));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('exportVideo burns a caption without breaking the file', () async {
    if (!await hasDrawtext()) {
      markTestSkipped('ffmpeg built without drawtext (no libfreetype)');
      return;
    }
    final out = '${tmp.path}/capped.mp4';
    await exportVideo(
      input: src,
      output: out,
      start: 0.0,
      end: 4.0,
      fontPath: 'assets/fonts/DejaVuSans.ttf',
      overlays: const [
        TextOverlay(
          text: "Olá d'água 50% : teste",
          start: 1.0,
          end: 3.0,
          cx: 0.5,
          cy: 0.85,
          sizeFrac: 0.08,
          colorHex: 'FFFFFF',
        ),
      ],
      onProgress: (_) {},
    );
    expect(File(out).existsSync(), true);
    expect(await probeDuration(out), closeTo(4.0, 0.3));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
