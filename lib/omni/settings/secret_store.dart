import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// File-backed API-key store (analogue of the Swift app's file KeychainStore).
/// Keys live in `omni_secrets.json` under the app-support dir at mode 0600.
/// The VALUE is never logged — callers only ever surface a `hasKey` boolean.
class SecretStore {
  SecretStore._(this._file);

  final File _file;
  static SecretStore? _instance;

  static Future<SecretStore> instance() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final base = Directory(p.join(dir.path, 'palmier_x'));
    await base.create(recursive: true);
    final file = File(p.join(base.path, 'omni_secrets.json'));
    return _instance = SecretStore._(file);
  }

  Future<Map<String, String>> _read() async {
    if (!await _file.exists()) return {};
    try {
      final m = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, String> data) async {
    await _file.writeAsString(jsonEncode(data), flush: true);
    if (!Platform.isWindows) {
      // ponytail: 0600 keeps the key file owner-only; Windows relies on the
      // per-user profile ACL (chmod is a no-op there).
      await Process.run('chmod', ['600', _file.path]);
    }
  }

  Future<String?> read(String key) async => (await _read())[key];

  Future<bool> hasKey(String key) async {
    final v = (await _read())[key];
    return v != null && v.isNotEmpty;
  }

  Future<void> write(String key, String value) async {
    final data = await _read();
    if (value.isEmpty) {
      data.remove(key);
    } else {
      data[key] = value;
    }
    await _write(data);
  }

  Future<void> clear(String key) async {
    final data = await _read();
    data.remove(key);
    await _write(data);
  }
}
