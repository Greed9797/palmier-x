import 'dart:convert';
import 'dart:io';

import 'omni_provider.dart';
import 'provider_kind.dart';

/// Drives a local `claude` / `codex` CLI as a subprocess (no API key — uses the
/// user's CLI subscription). Mirrors the Swift CLIClient: prompt via stdin, a
/// neutral temp cwd so no stray CLAUDE.md leaks, PATH prefixed for GUI launches.
///
/// v1 sends NO frames (claude -p has no image-attach flag); it works from the
/// transcript + scene/silence digest the cut_planner builds.
class CLIProvider implements OmniProvider {
  CLIProvider(this.kind) : assert(kind == OmniProviderKind.claudeCli || kind == OmniProviderKind.codexCli);

  final OmniProviderKind kind;

  @override
  bool get usesFrames => false;

  static const _pathPrefix =
      'export PATH="\$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"; ';

  String get _bin => kind == OmniProviderKind.claudeCli ? 'claude' : 'codex';

  @override
  Future<bool> isAvailable() async {
    try {
      if (Platform.isWindows) {
        final r = await Process.run('where', [_bin]);
        return r.exitCode == 0;
      }
      final r = await Process.run('/bin/zsh', ['-lc', '${_pathPrefix}command -v $_bin']);
      return r.exitCode == 0 && '${r.stdout}'.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> analyze({
    required String prompt,
    List<String> framePaths = const [],
    String? jsonSchema,
  }) async {
    final cwd = await Directory.systemTemp.createTemp('palmierx_cli');
    try {
      final Process proc;
      if (kind == OmniProviderKind.claudeCli) {
        final cmd = 'claude -p --output-format json '
            '--dangerously-skip-permissions --setting-sources project,local';
        proc = Platform.isWindows
            ? await Process.start('claude', [
                '-p',
                '--output-format', 'json',
                '--dangerously-skip-permissions',
                '--setting-sources', 'project,local',
              ], workingDirectory: cwd.path)
            : await Process.start('/bin/zsh', ['-lc', '$_pathPrefix$cmd'],
                workingDirectory: cwd.path);
      } else {
        // codex: best-effort; isAvailable() gates this off when absent.
        final cmd = 'codex exec --json --skip-git-repo-check --ignore-user-config';
        proc = Platform.isWindows
            ? await Process.start('codex',
                ['exec', '--json', '--skip-git-repo-check', '--ignore-user-config'],
                workingDirectory: cwd.path)
            : await Process.start('/bin/zsh', ['-lc', '$_pathPrefix$cmd'],
                workingDirectory: cwd.path);
      }

      proc.stdin.write(prompt);
      await proc.stdin.close();

      final out = await proc.stdout.transform(utf8.decoder).join();
      final err = await proc.stderr.transform(utf8.decoder).join();
      final code = await proc.exitCode;
      if (code != 0) {
        throw Exception('$_bin saiu $code: ${err.isEmpty ? out : err}');
      }
      return _extractResult(out);
    } finally {
      await cwd.delete(recursive: true);
    }
  }

  /// claude -p --output-format json wraps the answer in {type:'result', result:'…'}.
  /// codex --json streams events; we fall back to the raw text otherwise.
  String _extractResult(String stdout) {
    final trimmed = stdout.trim();
    try {
      final obj = jsonDecode(trimmed);
      if (obj is Map && obj['result'] is String) return obj['result'] as String;
    } catch (_) {
      // codex streams one JSON object per line; pick the last with a text field.
      for (final line in trimmed.split('\n').reversed) {
        try {
          final o = jsonDecode(line.trim());
          if (o is Map) {
            final t = o['text'] ?? o['message'] ?? o['result'];
            if (t is String && t.isNotEmpty) return t;
          }
        } catch (_) {}
      }
    }
    return trimmed;
  }
}
