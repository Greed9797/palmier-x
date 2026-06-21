import 'package:flutter/material.dart';

/// A burned-in text overlay. Geometry is stored as fractions of the video frame
/// so preview and ffmpeg export stay in sync without knowing pixel dimensions.
@immutable
class Caption {
  const Caption({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
    this.cx = 0.5,
    this.cy = 0.85,
    this.sizeFrac = 0.07,
    this.color = const Color(0xFFFFFFFF),
  });

  final String id;
  final String text;
  final double start; // source seconds
  final double end;
  final double cx; // 0..1 horizontal center
  final double cy; // 0..1 vertical center
  final double sizeFrac; // height fraction
  final Color color;

  Caption copyWith({
    String? text,
    double? start,
    double? end,
    double? cx,
    double? cy,
    double? sizeFrac,
    Color? color,
  }) =>
      Caption(
        id: id,
        text: text ?? this.text,
        start: start ?? this.start,
        end: end ?? this.end,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        sizeFrac: sizeFrac ?? this.sizeFrac,
        color: color ?? this.color,
      );

  bool visibleAt(double t) => t >= start && t <= end;
}
