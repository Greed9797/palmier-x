import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:palmier_x/ffmpeg.dart' show resolveFfmpeg;
import 'package:palmier_x/omni/models/video_analysis.dart';
import 'package:palmier_x/omni/pipeline/cut_planner.dart';
import 'package:palmier_x/omni/pipeline/frame_sampler.dart';
import 'package:palmier_x/omni/pipeline/media_probe.dart';
import 'package:palmier_x/omni/pipeline/recipe_extractor.dart';
import 'package:palmier_x/omni/pipeline/scene_detector.dart';
import 'package:palmier_x/omni/pipeline/silence_detector.dart';
import 'package:palmier_x/omni/providers/cli_provider.dart';
import 'package:palmier_x/omni/providers/omni_provider.dart';
import 'package:palmier_x/omni/providers/provider_kind.dart';

/// Returns a fixed JSON answer — exercises CutPlanner parsing deterministically
/// without invoking a real model.
class _FakeProvider implements OmniProvider {
  _FakeProvider(this.answer);
  final String answer;
  @override
  bool get usesFrames => false;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> analyze({required String prompt, List<String> framePaths = const [], String? jsonSchema}) async =>
      answer;
}

void main() {
  final ffmpeg = resolveFfmpeg();
  late Directory tmp;
  late String src;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('omni_');
    src = '${tmp.path}/src.mp4';
    // Two visually distinct halves (movement + a hard cut) plus an audio track.
    final gen = await Process.run(ffmpeg, [
      '-y',
      '-f', 'lavfi', '-i', 'testsrc=duration=6:size=320x240:rate=30',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=6',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', src,
    ]);
    expect(gen.exitCode, 0, reason: 'ffmpeg gen failed: ${gen.stderr}');
  });

  tearDown(() => tmp.delete(recursive: true));

  test('probe reads duration + audio', () async {
    final m = await probe(src);
    expect(m.durationSec, closeTo(6.0, 0.5));
    expect(m.hasAudio, true);
    expect(m.width, 320);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('frame sampler respects budget and monotonic timestamps', () async {
    final frames = await sampleFrames(
        input: src, durationSec: 6.0, outDir: '${tmp.path}/frames');
    expect(frames, isNotEmpty);
    expect(frames.length, lessThanOrEqualTo(frameBudget(6.0) + 2));
    for (var i = 1; i < frames.length; i++) {
      expect(frames[i].timestampSec, greaterThan(frames[i - 1].timestampSec));
      expect(File(frames[i].path).existsSync(), true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('scene + silence detectors return parseable lists', () async {
    final scenes = await detectScenes(src);
    final silences = await detectSilences(src);
    expect(scenes, isA<List<Scene>>());
    expect(silences, isA<List<Silence>>());
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('recipe extractor yields a non-null fingerprint', () async {
    final m = await probe(src);
    final scenes = await detectScenes(src);
    final a = VideoAnalysis(inputPath: src, inputHash: 'h', probe: m, scenes: scenes);
    final recipe = extractRecipe(a);
    expect(recipe.pacing.cutsPerMinute, greaterThanOrEqualTo(0));
    expect(recipe.version, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('CutPlanner parses model JSON into bounded, sorted suggestions', () async {
    const answer = '''
Here are the moments:
[
  {"start": 0.0, "end": 2.0, "reason": "hook", "score": 0.9, "kind": "highlight", "suggestedCaption": "Olha isso"},
  {"start": 3.0, "end": 5.0, "reason": "payoff", "score": 0.7, "kind": "trim", "suggestedCaption": null},
  {"start": 5.0, "end": 999.0, "reason": "overrun clamps", "score": 0.5, "kind": "highlight"}
]
''';
    final m = await probe(src);
    final a = VideoAnalysis(inputPath: src, inputHash: 'h', probe: m);
    final cuts = await CutPlanner(_FakeProvider(answer)).plan(a);
    expect(cuts.length, 3);
    expect(cuts.first.score, 0.9); // sorted desc
    expect(cuts.first.suggestedCaption, 'Olha isso');
    expect(cuts[1].suggestedCaption, isNull); // "null" string dropped
    expect(cuts.last.end, lessThanOrEqualTo(m.durationSec + 0.001)); // clamped
    for (final c in cuts) {
      expect(c.start, lessThan(c.end));
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  // Real CLI smoke — opt-in (OMNI_CLI_TEST=1) so we don't spawn `claude` on every run.
  test('claude CLI produces suggestions (opt-in)', () async {
    if (Platform.environment['OMNI_CLI_TEST'] != '1') {
      markTestSkipped('set OMNI_CLI_TEST=1 to run the real claude CLI');
      return;
    }
    final cli = CLIProvider(OmniProviderKind.claudeCli);
    if (!await cli.isAvailable()) {
      markTestSkipped('claude not on PATH');
      return;
    }
    final m = await probe(src);
    final a = VideoAnalysis(
      inputPath: src,
      inputHash: 'h',
      probe: m,
      scenes: const [Scene(tStart: 3.0, score: 0.8)],
    );
    final cuts = await CutPlanner(cli).plan(a);
    for (final c in cuts) {
      expect(c.start, lessThan(c.end));
      expect(c.end, lessThanOrEqualTo(m.durationSec + 0.001));
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
