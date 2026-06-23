import 'package:flutter/material.dart';

import '../providers/cli_provider.dart';
import '../providers/provider_kind.dart';
import '../settings/omni_settings.dart';
import '../settings/secret_store.dart';

/// Provider + transcription settings, and BYOK key entry. Keys go straight to
/// SecretStore — the actual value is never shown back (only a "saved" hint).
class OmniSettingsDialog extends StatefulWidget {
  const OmniSettingsDialog({super.key});

  @override
  State<OmniSettingsDialog> createState() => _OmniSettingsDialogState();
}

class _OmniSettingsDialogState extends State<OmniSettingsDialog> {
  OmniSettings _settings = const OmniSettings();
  SecretStore? _secrets;
  final _hasKey = <String, bool>{'gemini': false, 'openai': false, 'groq': false};
  final _fields = {
    'gemini': TextEditingController(),
    'openai': TextEditingController(),
    'groq': TextEditingController(),
  };
  bool _claudeAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await OmniSettings.load();
    final store = await SecretStore.instance();
    for (final k in _hasKey.keys) {
      _hasKey[k] = await store.hasKey(k);
    }
    final claude = await CLIProvider(OmniProviderKind.claudeCli).isAvailable();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _secrets = store;
      _claudeAvailable = claude;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final store = _secrets!;
    for (final entry in _fields.entries) {
      final v = entry.value.text.trim();
      if (v.isNotEmpty) await store.write(entry.key, v);
    }
    await _settings.save();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Omni — Configurações'),
      content: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<OmniProviderKind>(
                      initialValue: _settings.provider,
                      decoration: const InputDecoration(labelText: 'Provider de cortes'),
                      items: [
                        for (final k in OmniProviderKind.values)
                          DropdownMenuItem(
                            value: k,
                            child: Text(k == OmniProviderKind.claudeCli
                                ? 'Claude CLI (${_claudeAvailable ? "detectado" : "não encontrado"})'
                                : k.label),
                          ),
                      ],
                      onChanged: (v) => setState(() => _settings = _settings.copyWith(provider: v)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WhisperBackend>(
                      initialValue: _settings.whisperBackend,
                      decoration: const InputDecoration(labelText: 'Transcrição (áudio)'),
                      items: const [
                        DropdownMenuItem(value: WhisperBackend.none, child: Text('Nenhuma (só frames/cenas)')),
                        DropdownMenuItem(value: WhisperBackend.groq, child: Text('Whisper via Groq')),
                        DropdownMenuItem(value: WhisperBackend.openai, child: Text('Whisper via OpenAI')),
                        DropdownMenuItem(value: WhisperBackend.gemini, child: Text('Gemini áudio')),
                      ],
                      onChanged: (v) =>
                          setState(() => _settings = _settings.copyWith(whisperBackend: v)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Chaves BYOK (deixe vazio pra manter a salva)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _keyField('gemini', 'Gemini API key'),
                    _keyField('openai', 'OpenAI API key'),
                    _keyField('groq', 'Groq API key'),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: _loading ? null : _save, child: const Text('Salvar')),
      ],
    );
  }

  Widget _keyField(String key, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _fields[key],
          obscureText: true,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            helperText: _hasKey[key]! ? 'salva ✓' : 'não configurada',
          ),
        ),
      );
}
