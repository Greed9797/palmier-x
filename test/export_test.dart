import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:palmier_x/ffmpeg.dart';

/// Integration check of the export money-path: generate a clip, trim it, and
/// assert the output exists with the trimmed duration. Requires ffmpeg/ffprobe
/// on PATH (bundled on Windows, system on dev/CI).
void main() {
  test('exportTrim cuts to the requested range', () async {
    final tmp = await Directory.systemTemp.createTemp('palmierx_');
    final src = '${tmp.path}/src.mp4';
    final out = '${tmp.path}/out.mp4';

    // 5s 320x240 test pattern.
    final gen = await Process.run('ffmpeg', [
      '-y', '-f', 'lavfi', '-i', 'testsrc=duration=5:size=320x240:rate=30',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', src,
    ]);
    expect(gen.exitCode, 0, reason: 'ffmpeg gen failed: ${gen.stderr}');

    var last = 0.0;
    await exportTrim(
      input: src,
      output: out,
      start: 1.0,
      end: 3.0,
      onProgress: (v) => last = v,
    );

    expect(File(out).existsSync(), true);
    expect(last, 1.0);

    final probe = await Process.run('ffprobe', [
      '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=nw=1:nk=1', out,
    ]);
    final dur = double.parse((probe.stdout as String).trim());
    expect(dur, closeTo(2.0, 0.3), reason: 'trimmed duration off: $dur');

    await tmp.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
