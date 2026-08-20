import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';

import 'media_tools.dart';

class VideoEditResult {
  final String path;
  final bool mute;
  const VideoEditResult({required this.path, required this.mute});
}

class VideoEditPage extends StatefulWidget {
  final String path;
  const VideoEditPage({super.key, required this.path});

  @override
  State<VideoEditPage> createState() => _VideoEditPageState();
}

class _VideoEditPageState extends State<VideoEditPage> {
  final _trimmer = Trimmer();
  bool _ready = false;
  bool _saving = false;
  bool _mute = false;
  double _start = 0;
  double _end = kMaxVideoSeconds * 1000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _trimmer.loadVideo(videoFile: File(widget.path));
    // video_trimmer 3 uses File
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final span = (_end - _start) / 1000;
    if (span > kMaxVideoSeconds + 0.4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep the clip at 30 seconds or less')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final path = await _trimmer.saveTrimmedVideo(
        startValue: _start,
        endValue: _end,
      );
      if (!mounted) return;
      if (path.isEmpty) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save video')),
        );
        return;
      }
      Navigator.pop(context, VideoEditResult(path: path, mute: _mute));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071422),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071422),
        title: const Text('Edit video · max 30s'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Done', style: const TextStyle(color: Color(0xFF168CFF))),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: VideoViewer(trimmer: _trimmer),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TrimViewer(
                    trimmer: _trimmer,
                    viewerHeight: 54,
                    maxVideoLength: const Duration(seconds: kMaxVideoSeconds),
                    onChangeStart: (v) => _start = v,
                    onChangeEnd: (v) => _end = v,
                    onChangePlaybackState: (_) {},
                  ),
                ),
                SwitchListTile(
                  value: _mute,
                  onChanged: (v) => setState(() => _mute = v),
                  title: const Text('Mute audio'),
                  subtitle: const Text('Remove sound from this clip'),
                  secondary: Icon(_mute ? Icons.volume_off : Icons.volume_up),
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
