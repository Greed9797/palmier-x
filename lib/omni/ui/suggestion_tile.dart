import 'package:flutter/material.dart';

import '../models/cut_suggestion.dart';

String _fmt(double sec) {
  final m = (sec ~/ 60).toString().padLeft(2, '0');
  final s = (sec % 60).toStringAsFixed(1).padLeft(4, '0');
  return '$m:$s';
}

/// One cut suggestion: reason + score badge + range, with Jump / Apply-as-trim /
/// Add-caption actions wired back to the editor's existing state.
class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    super.key,
    required this.suggestion,
    required this.onSeek,
    required this.onApplyTrim,
    required this.onAddCaption,
  });

  final CutSuggestion suggestion;
  final VoidCallback onSeek;
  final VoidCallback onApplyTrim;
  final VoidCallback onAddCaption;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final brand = Theme.of(context).colorScheme.primary;
    final pct = (s.score * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$pct%',
                    style: TextStyle(color: brand, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text('${_fmt(s.start)} → ${_fmt(s.end)}',
                  style: const TextStyle(fontFeatures: [], fontSize: 12)),
              const Spacer(),
              Text(s.kind.name,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
            ],
          ),
          if (s.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.reason, style: const TextStyle(fontSize: 13)),
          ],
          if (s.suggestedCaption != null) ...[
            const SizedBox(height: 4),
            Text('“${s.suggestedCaption}”',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.6))),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(onPressed: onSeek, child: const Text('Ir')),
              TextButton(onPressed: onApplyTrim, child: const Text('Aplicar trim')),
              if (s.suggestedCaption != null)
                TextButton(onPressed: onAddCaption, child: const Text('+ Legenda')),
            ],
          ),
        ],
      ),
    );
  }
}
