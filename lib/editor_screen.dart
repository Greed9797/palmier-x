import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import 'ffmpeg.dart';
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
    });
    await _player.open(Media(path), play: false);
  }

  void _seek(double sec) {
    _player.seek(Duration(milliseconds: (sec * 1000).round()));
  }

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
      await exportTrim(
        input: _path!,
        output: outPath,
        start: _trimIn,
        end: _trimOut,
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

  @override
  Widget build(BuildContext context) {
    final hasVideo = _path != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Palmier X'),
        actions: [
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
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: hasVideo
                  ? Video(controller: _controller)
                  : const _EmptyState(),
            ),
          ),
          if (_exporting)
            LinearProgressIndicator(value: _exportProgress),
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
                    onTrimIn: (s) => setState(
                        () => _trimIn = s.clamp(0.0, _trimOut)),
                    onTrimOut: (s) => setState(
                        () => _trimOut = s.clamp(_trimIn, _duration)),
                  ),
                ],
              ),
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
