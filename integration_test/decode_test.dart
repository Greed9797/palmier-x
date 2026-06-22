import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

/// Runs on the real platform (Windows in CI). Proves libmpv actually DECODES a
/// video — not just that the DLLs load — by opening a clip and waiting for the
/// player to report a non-zero duration. This is the playback path marketing
/// will exercise first. ffmpeg via FFMPEG env (CI) or PATH.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('media_kit decodes a video on this platform', (tester) async {
    MediaKit.ensureInitialized();

    final ffmpeg = Platform.environment['FFMPEG'] ?? 'ffmpeg';
    final tmp = await Directory.systemTemp.createTemp('pxit');
    final src = '${tmp.path}${Platform.pathSeparator}s.mp4';
    final gen = await Process.run(ffmpeg, [
      '-y', '-f', 'lavfi', '-i', 'testsrc=duration=2:size=320x240:rate=30',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', src,
    ]);
    expect(gen.exitCode, 0, reason: 'ffmpeg gen failed: ${gen.stderr}');

    final player = Player();
    try {
      await player.open(Media(src), play: false);
      final duration = await player.stream.duration
          .firstWhere((d) => d.inMilliseconds > 0)
          .timeout(const Duration(seconds: 15));
      expect(duration.inMilliseconds, greaterThan(1000),
          reason: 'libmpv reported ~2s clip duration');
    } finally {
      await player.dispose();
      await tmp.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
