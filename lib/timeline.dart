import 'package:flutter/material.dart';

/// A minimal scrubbing timeline: a duration bar with a draggable playhead and
/// two trim handles (in/out). Frame-accuracy is delegated to the player's seek.
class Timeline extends StatelessWidget {
  const Timeline({
    super.key,
    required this.duration,
    required this.position,
    required this.trimIn,
    required this.trimOut,
    required this.onSeek,
    required this.onTrimIn,
    required this.onTrimOut,
  });

  final double duration; // seconds
  final double position;
  final double trimIn;
  final double trimOut;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onTrimIn;
  final ValueChanged<double> onTrimOut;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        double secAt(double dx) =>
            duration <= 0 ? 0 : (dx / w * duration).clamp(0.0, duration);
        double xOf(double sec) => duration <= 0 ? 0 : sec / duration * w;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onSeek(secAt(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => onSeek(secAt(d.localPosition.dx)),
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                // Track.
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                // Selected (export) range.
                Positioned(
                  left: xOf(trimIn),
                  width: (xOf(trimOut) - xOf(trimIn)).clamp(0.0, w),
                  top: 22,
                  bottom: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: brand.withValues(alpha: 0.25),
                      border: Border.all(color: brand, width: 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                _Handle(x: xOf(trimIn), color: brand, onDrag: (dx) => onTrimIn(secAt(dx))),
                _Handle(x: xOf(trimOut), color: brand, onDrag: (dx) => onTrimOut(secAt(dx))),
                // Playhead.
                Positioned(
                  left: xOf(position) - 1,
                  top: 12,
                  bottom: 12,
                  child: Container(width: 2, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.x, required this.color, required this.onDrag});
  final double x;
  final Color color;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - 7,
      top: 16,
      bottom: 16,
      width: 14,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) =>
            onDrag((x - 7 + d.localPosition.dx).clamp(0.0, double.infinity)),
        child: Center(
          child: Container(
            width: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
