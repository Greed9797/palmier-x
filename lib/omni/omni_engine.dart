import 'cache/analysis_cache.dart';
import 'models/analysis_result.dart';
import 'pipeline/analysis_pipeline.dart';
import 'pipeline/transcriber.dart';
import 'providers/byok_provider.dart';
import 'providers/cli_provider.dart';
import 'providers/omni_provider.dart';
import 'providers/provider_kind.dart';
import 'settings/omni_settings.dart';
import 'settings/secret_store.dart';

/// Facade the UI calls: loads settings, builds the provider + transcriber,
/// checks the cache, runs the pipeline, persists. One call → an OmniResult.
class OmniEngine {
  static Future<OmniProvider> buildProvider(
      OmniProviderKind kind, SecretStore secrets) async {
    final provider = kind.isCli ? CLIProvider(kind) : BYOKProvider(kind, secrets);
    if (!await provider.isAvailable()) {
      throw Exception(kind.isCli
          ? '${kind.label} não encontrado no PATH. Instale o CLI ou escolha um provider BYOK nas settings.'
          : 'Sem chave para ${kind.label}. Configure nas settings do Omni.');
    }
    return provider;
  }

  static Future<OmniResult> run({
    required String input,
    OmniProgress? onProgress,
  }) async {
    final settings = await OmniSettings.load();
    final secrets = await SecretStore.instance();
    final cache = await AnalysisCache.instance();
    final providerName = settings.provider.name;

    final hash = await AnalysisCache.fileHash(input);

    // Full cache hit (same file, same provider) → instant.
    final cached = await cache.loadResult(hash, providerName);
    if (cached != null) {
      onProgress?.call('Cache', 1.0);
      return cached;
    }

    final provider = await buildProvider(settings.provider, secrets);
    final transcriber = await makeTranscriber(settings, secrets);
    final cachedAnalysis = await cache.loadAnalysis(hash); // reuse structure across providers

    final result = await AnalysisPipeline.run(
      input: input,
      inputHash: hash,
      workDir: cache.dirFor(hash).path,
      provider: provider,
      providerName: providerName,
      transcriber: transcriber,
      onProgress: onProgress,
      cachedAnalysis: cachedAnalysis,
    );

    if (cachedAnalysis == null) await cache.saveAnalysis(hash, result.analysis);
    await cache.saveResult(hash, providerName, result);
    return result;
  }
}
