import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../models/cut_suggestion.dart';
import 'suggestion_tile.dart';

/// Third editor pane: run analysis, show staged progress, list cut suggestions,
/// and surface the editing fingerprint. Stateless — driven by editor state.
class OmniPanel extends StatelessWidget {
  const OmniPanel({
    super.key,
    required this.result,
    required this.analyzing,
    required this.progress,
    required this.stage,
    required this.error,
    required this.onRun,
    required this.onOpenSettings,
    required this.onApplyTrim,
    required this.onAddCaption,
    required this.onSeek,
    required this.onAutoCaption,
    required this.onExportHighlights,
  });

  final OmniResult? result;
  final bool analyzing;
  final double progress;
  final String? stage;
  final Object? error;
  final VoidCallback onRun;
  final VoidCallback onOpenSettings;
  final void Function(CutSuggestion) onApplyTrim;
  final void Function(CutSuggestion) onAddCaption;
  final void Function(double) onSeek;
  final VoidCallback onAutoCaption;
  final VoidCallback onExportHighlights;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(left: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 6),
                const Text('Omni', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                IconButton(
                  tooltip: 'Configurações',
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                ),
                FilledButton.icon(
                  onPressed: analyzing ? null : onRun,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(result == null ? 'Analisar' : 'Re-analisar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (analyzing) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LinearProgressIndicator(value: progress == 0 ? null : progress),
            const SizedBox(height: 12),
            Text(stage ?? 'Analisando…',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 36),
            const SizedBox(height: 8),
            Text('$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade200, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRun, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    final r = result;
    if (r == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Analise o vídeo pra ver momentos fortes,\ncortes sugeridos e a "DNA" da edição.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
      );
    }
    final hasTranscript = r.analysis.transcriptSource != null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _recipeCard(r),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasTranscript ? onAutoCaption : null,
                icon: const Icon(Icons.subtitles_outlined, size: 16),
                label: const Text('Auto-legenda'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: r.suggestions.isEmpty ? null : onExportHighlights,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Destaques'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (r.analysis.transcriptSource == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Transcript indisponível — análise por frames/cenas.',
                style: TextStyle(
                    fontSize: 12, color: Colors.amber.withValues(alpha: 0.8))),
          ),
        Text('${r.suggestions.length} momentos sugeridos',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final s in r.suggestions)
          SuggestionTile(
            suggestion: s,
            onSeek: () => onSeek(s.start),
            onApplyTrim: () => onApplyTrim(s),
            onAddCaption: () => onAddCaption(s),
          ),
        if (r.suggestions.isEmpty)
          Text('Nenhum corte sugerido.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      ],
    );
  }

  Widget _recipeCard(OmniResult r) {
    final p = r.recipe.pacing;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit DNA', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          _stat('Cortes/min', p.cutsPerMinute.toStringAsFixed(1)),
          _stat('Clipe médio', '${p.avgClipLenSec.toStringAsFixed(1)}s'),
          _stat('Cenas', '${r.analysis.scenes.length}'),
          if (r.analysis.transcriptSource != null)
            _stat('Legenda mediana', '${r.recipe.captionStyle.wordsPerCaptionMedian} palavras'),
        ],
      ),
    );
  }

  Widget _stat(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Text(k, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
            const Spacer(),
            Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
