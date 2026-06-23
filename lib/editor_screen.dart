import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import 'caption.dart';
import 'caption_panel.dart';
import 'ffmpeg.dart';
import 'omni/omni.dart';
import 'timeline.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  final _subs = <StreamSubscription>[];

  String? _path;
  double _duration = 0; // seconds
  double _position = 0;
  double _trimIn = 0;
  double _trimOut = 0;
  bool _exporting = false;
  double _exportProgress = 0;
  int _captionSeq = 0;
  List<Caption> _captions = const [];
  ExportAspect _aspect = ExportAspect.r9x16; // viral default

  // ---- Omni engine state ----
  OmniResult? _omni;
  bool _analyzing = false;
  double _analyzeProgress = 0;
  String? _analyzeStage;
  Object? _omniError;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.stream.duration.listen((d) {
      setState(() {
        _duration = d.inMilliseconds / 1000;
        if (_trimOut == 0) _trimOut = _duration;
      });
    }));
    _subs.add(_player.stream.position.listen((pos) {
      setState(() => _position = pos.inMilliseconds / 1000);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      dialogTitle: 'Importar vídeo',
    );
    final path = res?.files.single.path;
    if (path == null) return;
    setState(() {
      _path = path;
      _duration = 0;
      _position = 0;
      _trimIn = 0;
      _trimOut = 0;
      _captions = const [];
      _omni = null;
      _omniError = null;
    });
    await _player.open(Media(path), play: false);
  }

  void _seek(double sec) =>
      _player.seek(Duration(milliseconds: (sec * 1000).round()));

  // ---- Omni ------------------------------------------------------------------

  Future<void> _runOmni() async {
    if (_path == null) return;
    setState(() {
      _analyzing = true;
      _analyzeProgress = 0;
      _analyzeStage = null;
      _omniError = null;
    });
    try {
      final r = await OmniEngine.run(
        input: _path!,
        onProgress: (stage, f) {
          if (!mounted) return;
          setState(() {
            _analyzeStage = stage;
            _analyzeProgress = f;
          });
        },
      );
      if (mounted) setState(() => _omni = r);
    } catch (e) {
      if (mounted) setState(() => _omniError = e);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _applyTrim(CutSuggestion s) {
    setState(() {
      _trimIn = s.start.clamp(0.0, _duration);
      _trimOut = s.end.clamp(_trimIn, _duration);
    });
    _seek(s.start);
  }

  void _addCaptionFromSuggestion(CutSuggestion s) {
    final text = s.suggestedCaption;
    if (text == null) return;
    setState(() {
      _captions = [
        ..._captions,
        Caption(id: 'c${_captionSeq++}', text: text, start: s.start, end: s.end),
      ];
    });
  }

  Future<void> _openOmniSettings() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const OmniSettingsDialog(),
    );
  }

  void _autoCaption() {
    final transcript = _omni?.analysis.transcript ?? const [];
    if (transcript.isEmpty) {
      _snack('Sem transcript — rode o Omni com um backend de transcrição.', error: true);
      return;
    }
    setState(() {
      _captions = [
        ..._captions,
        for (final seg in transcript)
          Caption(id: 'c${_captionSeq++}', text: seg.text, start: seg.start, end: seg.end),
      ];
    });
    _snack('${transcript.length} legendas geradas do transcript.');
  }

  Future<void> _exportHighlights() async {
    final r = _omni;
    if (_path == null || r == null || r.suggestions.isEmpty) return;
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pasta para os clipes de destaque',
    );
    if (dir == null) return;

    setState(() {
      _exporting = true;
      _exportProgress = 0;
    });
    try {
      final fontPath = await _ensureFont();
      final n = await exportHighlights(
        input: _path!,
        suggestions: r.suggestions,
        transcript: r.analysis.transcript,
        aspect: _aspect,
        fontPath: fontPath,
        outDir: dir,
        baseName: p.basenameWithoutExtension(_path!),
        onProgress: (done, total) =>
            setState(() => _exportProgress = total == 0 ? 1 : done / total),
      );
      if (mounted) _snack('$n clipes exportados em ${p.basename(dir)}/');
    } catch (e) {
      if (mounted) _snack('Falha no export de destaques: $e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---- Caption CRUD ----------------------------------------------------------

  void _addCaption() {
    final start = _position;
    final end = (start + 2.0).clamp(0.0, _duration == 0 ? start + 2.0 : _duration);
    setState(() {
      _captions = [
        ..._captions,
        Caption(id: 'c${_captionSeq++}', text: 'Legenda', start: start, end: end),
      ];
    });
  }

  void _updateCaption(Caption c) => setState(() {
        _captions = [
          for (final x in _captions) if (x.id == c.id) c else x,
        ];
      });

  void _deleteCaption(String id) =>
      setState(() => _captions = _captions.where((c) => c.id != id).toList());

  Future<String> _ensureFont() async {
    final bytes = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final dir = await Directory.systemTemp.createTemp('palmierx_font');
    final f = File(p.join(dir.path, 'DejaVuSans.ttf'));
    await f.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return f.path;
  }

  // ---- Export ----------------------------------------------------------------

  Future<void> _export() async {
    if (_path == null) return;
    final outPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar vídeo',
      fileName: '${p.basenameWithoutExtension(_path!)}_export.mp4',
      type: FileType.video,
      allowedExtensions: ['mp4'],
    );
    if (outPath == null) return;

    setState(() {
      _exporting = true;
      _exportProgress = 0;
    });
    try {
      final fontPath = await _ensureFont();
      await exportVideo(
        input: _path!,
        output: outPath,
        start: _trimIn,
        end: _trimOut,
        fontPath: fontPath,
        aspect: _aspect,
        overlays: [
          for (final c in _captions)
            TextOverlay(
              text: c.text,
              start: c.start,
              end: c.end,
              cx: c.cx,
              cy: c.cy,
              sizeFrac: c.sizeFrac,
              colorHex: c.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2),
            ),
        ],
        onProgress: (v) => setState(() => _exportProgress = v),
      );
      if (mounted) _snack('Exportado: ${p.basename(outPath)}');
    } catch (e) {
      if (mounted) _snack('Falha no export: $e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade900 : null,
    ));
  }

  // ---- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final hasVideo = _path != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Palmier X'),
        actions: [
          if (hasVideo)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<ExportAspect>(
                value: _aspect,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.aspect_ratio, size: 18),
                items: [
                  for (final a in ExportAspect.values)
                    DropdownMenuItem(value: a, child: Text(a.label)),
                ],
                onChanged: _exporting
                    ? null
                    : (a) => setState(() => _aspect = a ?? _aspect),
              ),
            ),
          TextButton.icon(
            onPressed: _exporting ? null : _import,
            icon: const Icon(Icons.video_file_outlined),
            label: const Text('Importar'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: (!hasVideo || _exporting) ? null : _export,
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(_exporting
                ? 'Exportando ${(_exportProgress * 100).toStringAsFixed(0)}%'
                : 'Exportar'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: hasVideo
                        ? _Preview(
                            controller: _controller,
                            captions: _captions,
                            position: _position,
                          )
                        : const _EmptyState(),
                  ),
                ),
                if (_exporting) LinearProgressIndicator(value: _exportProgress),
                if (hasVideo)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _player.playOrPause(),
                              icon: const Icon(Icons.play_arrow),
                            ),
                            Text(_fmt(_position)),
                            const Spacer(),
                            Text('Trim ${_fmt(_trimIn)} → ${_fmt(_trimOut)}'),
                          ],
                        ),
                        Timeline(
                          duration: _duration,
                          position: _position,
                          trimIn: _trimIn,
                          trimOut: _trimOut,
                          onSeek: _seek,
                          onTrimIn: (s) =>
                              setState(() => _trimIn = s.clamp(0.0, _trimOut)),
                          onTrimOut: (s) => setState(
                              () => _trimOut = s.clamp(_trimIn, _duration)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (hasVideo)
            CaptionPanel(
              captions: _captions,
              duration: _duration,
              onAdd: _addCaption,
              onUpdate: _updateCaption,
              onDelete: _deleteCaption,
              onSeek: _seek,
            ),
          if (hasVideo)
            OmniPanel(
              result: _omni,
              analyzing: _analyzing,
              progress: _analyzeProgress,
              stage: _analyzeStage,
              error: _omniError,
              onRun: _runOmni,
              onOpenSettings: _openOmniSettings,
              onApplyTrim: _applyTrim,
              onAddCaption: _addCaptionFromSuggestion,
              onSeek: _seek,
              onAutoCaption: _autoCaption,
              onExportHighlights: _exportHighlights,
            ),
        ],
      ),
    );
  }

  String _fmt(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toStringAsFixed(1).padLeft(4, '0');
    return '$m:$s';
  }
}

/// Video with caption overlays positioned at fractional coordinates. Positions
/// are relative to the player box (letterboxing not accounted for in v1).
class _Preview extends StatelessWidget {
  const _Preview({
    required this.controller,
    required this.captions,
    required this.position,
  });
  final VideoController controller;
  final List<Caption> captions;
  final double position;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            Video(controller: controller),
            for (final cap in captions)
              if (cap.visibleAt(position))
                Positioned(
                  left: 0,
                  right: 0,
                  top: cap.cy * h - cap.sizeFrac * h,
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment(2 * cap.cx - 1, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Text(
                          cap.text,
                          style: TextStyle(
                            fontFamily: 'DejaVuSans',
                            color: cap.color,
                            fontSize: cap.sizeFrac * h,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Importe um vídeo para começar',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}
