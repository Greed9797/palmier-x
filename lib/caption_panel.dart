import 'package:flutter/material.dart';

import 'caption.dart';

/// Side panel: create / read / update / delete burned-in captions.
class CaptionPanel extends StatelessWidget {
  const CaptionPanel({
    super.key,
    required this.captions,
    required this.duration,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onSeek,
  });

  final List<Caption> captions;
  final double duration;
  final VoidCallback onAdd;
  final ValueChanged<Caption> onUpdate;
  final ValueChanged<String> onDelete;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
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
                const Text('Legendas',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('No playhead'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: captions.isEmpty
                ? Center(
                    child: Text('Sem legendas.\n"No playhead" adiciona uma.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: captions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CaptionCard(
                      caption: captions[i],
                      duration: duration,
                      onUpdate: onUpdate,
                      onDelete: onDelete,
                      onSeek: onSeek,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CaptionCard extends StatefulWidget {
  const _CaptionCard({
    required this.caption,
    required this.duration,
    required this.onUpdate,
    required this.onDelete,
    required this.onSeek,
  });
  final Caption caption;
  final double duration;
  final ValueChanged<Caption> onUpdate;
  final ValueChanged<String> onDelete;
  final ValueChanged<double> onSeek;

  @override
  State<_CaptionCard> createState() => _CaptionCardState();
}

class _CaptionCardState extends State<_CaptionCard> {
  late final TextEditingController _text =
      TextEditingController(text: widget.caption.text);

  @override
  void didUpdateWidget(_CaptionCard old) {
    super.didUpdateWidget(old);
    if (widget.caption.text != _text.text) _text.text = widget.caption.text;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.caption;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            style: const TextStyle(fontSize: 14),
            maxLines: null,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'Texto da legenda',
            ),
            onChanged: (v) => widget.onUpdate(c.copyWith(text: v)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TimeField(
                label: 'In',
                value: c.start,
                max: widget.duration,
                onChanged: (v) =>
                    widget.onUpdate(c.copyWith(start: v.clamp(0.0, c.end))),
              ),
              const SizedBox(width: 8),
              _TimeField(
                label: 'Out',
                value: c.end,
                max: widget.duration,
                onChanged: (v) => widget.onUpdate(
                    c.copyWith(end: v.clamp(c.start, widget.duration))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Tamanho', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: c.sizeFrac.clamp(0.03, 0.2),
                  min: 0.03,
                  max: 0.2,
                  onChanged: (v) => widget.onUpdate(c.copyWith(sizeFrac: v)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Y', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: c.cy.clamp(0.0, 1.0),
                  onChanged: (v) => widget.onUpdate(c.copyWith(cy: v)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => widget.onSeek(c.start),
                child: const Text('Ir'),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => widget.onDelete(c.id),
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.red.shade300,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextFormField(
        key: ValueKey('$label-${value.toStringAsFixed(2)}'),
        initialValue: value.toStringAsFixed(2),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: '$label (s)',
        ),
        onFieldSubmitted: (v) {
          final d = double.tryParse(v.replaceAll(',', '.'));
          if (d != null) onChanged(d);
        },
      ),
    );
  }
}
