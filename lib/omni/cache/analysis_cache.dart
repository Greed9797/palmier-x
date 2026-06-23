import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/analysis_result.dart';
import '../models/video_analysis.dart';

/// Disk cache for Omni analysis, keyed by a cheap content hash so re-opening a
/// file is instant. The provider-independent VideoAnalysis (scenes/transcript/
/// frames) is cached once; LLM suggestions are cached per provider.
class AnalysisCache {
  AnalysisCache._(this._root);
  final Directory _root;
  static AnalysisCache? _instance;

  static Future<AnalysisCache> instance() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final root = Directory(p.join(dir.path, 'palmier_x', 'omni_cache'));
    await root.create(recursive: true);
    return _instance = AnalysisCache._(root);
  }

  /// Cheap hash: size + mtime + first 1 MB (avoids hashing huge files).
  static Future<String> fileHash(String path) async {
    final f = File(path);
    final stat = await f.stat();
    final head = await (f.openRead(0, 1 << 20)).fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    final input = utf8.encode('${stat.size}:${stat.modified.millisecondsSinceEpoch}:') + head;
    return sha256.convert(input).toString();
  }

  Directory dirFor(String hash) {
    final d = Directory(p.join(_root.path, hash));
    d.createSync(recursive: true);
    return d;
  }

  File _analysisFile(String hash) => File(p.join(dirFor(hash).path, 'analysis.json'));
  File _resultFile(String hash, String provider) =>
      File(p.join(dirFor(hash).path, 'result_$provider.json'));

  Future<VideoAnalysis?> loadAnalysis(String hash) async {
    final f = _analysisFile(hash);
    if (!await f.exists()) return null;
    try {
      return VideoAnalysis.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAnalysis(String hash, VideoAnalysis a) =>
      _analysisFile(hash).writeAsString(jsonEncode(a.toJson()), flush: true);

  Future<OmniResult?> loadResult(String hash, String provider) async {
    final f = _resultFile(hash, provider);
    if (!await f.exists()) return null;
    try {
      return OmniResult.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveResult(String hash, String provider, OmniResult r) =>
      _resultFile(hash, provider).writeAsString(jsonEncode(r.toJson()), flush: true);
}
