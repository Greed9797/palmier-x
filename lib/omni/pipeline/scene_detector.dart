import 'dart:io';

import '../../ffmpeg.dart' show resolveFfmpeg;
import '../models/video_analysis.dart';

final _ptsTime = RegExp(r'pts_time:([0-9.]+)');
final _sceneScore = RegExp(r'lavfi\.scene_score=([0-9.]+)');

/// Detects hard cuts via ffmpeg's scene-change score. Returns the boundary
/// timestamps (seconds) with their scene scores.
Future<List<Scene>> detectScenes(String input, {double threshold = 0.3}) async {
  // metadata=print writes to stdout: a `pts_time:` line then `lavfi.scene_score=`.
  final r = await Process.run(resolveFfmpeg(), [
    '-hide_banner',
    '-i', input,
    '-vf', "select='gt(scene,$threshold)',metadata=print:file=-",
    '-an',
    '-f', 'null',
    '-',
  ]);
  // ffmpeg may exit 0 with output on stdout.
  final out = '${r.stdout}';
  final scenes = <Scene>[];
  double? pendingTime;
  for (final line in out.split('\n')) {
    final t = _ptsTime.firstMatch(line);
    if (t != null) {
      pendingTime = double.tryParse(t.group(1)!);
      continue;
    }
    final s = _sceneScore.firstMatch(line);
    if (s != null && pendingTime != null) {
      scenes.add(Scene(tStart: pendingTime, score: double.tryParse(s.group(1)!) ?? 0));
      pendingTime = null;
    }
  }
  return scenes;
}
