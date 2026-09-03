// lib/features/shell/parts/video_editor_screen.dart
// Video editor screen — trim, crop, rotate, cover selection.
// Uses video_editor package which wraps ffmpeg_kit.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';

import '../../../core/theme/colors.dart';

const _kBlue = PlayifyColors.electricBlue;

/// Open video editor and return edited file path, or null if cancelled.
Future<File?> openVideoEditor(BuildContext context, File videoFile) async {
  // video_editor not supported on web
  return await Navigator.push<File?>(
    context,
    MaterialPageRoute(
      builder: (_) => _VideoEditorScreen(file: videoFile),
      fullscreenDialog: true,
    ),
  );
}

class _VideoEditorScreen extends StatefulWidget {
  const _VideoEditorScreen({required this.file});
  final File file;
  @override
  State<_VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<_VideoEditorScreen> {
  late final VideoEditorController _ctrl;
  bool _initialized = false;
  bool _exporting = false;
  double _exportProgress = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoEditorController.file(
      widget.file,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(seconds: 60), // 60s max
    );
    _ctrl.initialize(aspectRatio: 9 / 16).then((_) {
      if (mounted) setState(() => _initialized = true);
    }).catchError((e) {
      debugPrint('VideoEditor init error: $e');
      if (mounted) Navigator.pop(context, null);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() { _exporting = true; _exportProgress = 0; });

    try {
      final config = VideoFFmpegVideoEditorConfig(_ctrl);
      final execute = await config.getExecuteConfig();
      
      // Execute FFmpeg command
      await FFmpegKit.executeAsync(
        execute.command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (mounted) {
            if (ReturnCode.isSuccess(returnCode)) {
              final outputFile = File(execute.outputPath);
              if (outputFile.existsSync()) {
                Navigator.pop(context, outputFile);
              }
            } else {
              setState(() => _exporting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Export failed with code: $returnCode'),
                    backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _kBlue, strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Loading video...', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ],
        )),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F35),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: const Text('Edit Video',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          if (!_exporting)
            TextButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.check_rounded, color: _kBlue, size: 20),
              label: const Text('Done',
                  style: TextStyle(color: _kBlue, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: _exporting ? _buildExporting() : _buildEditor(),
    );
  }

  Widget _buildExporting() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(width: 180, child: LinearProgressIndicator(
        value: _exportProgress,
        minHeight: 6,
        backgroundColor: Colors.white12,
        valueColor: const AlwaysStoppedAnimation(_kBlue),
      )),
      const SizedBox(height: 16),
      Text('${(_exportProgress * 100).toInt()}%',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('Exporting video...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
    ],
  ));

  Widget _buildEditor() => Column(children: [
    // Video preview
    Expanded(
      child: CropGridViewer.preview(controller: _ctrl),
    ),

    // Toolbar
    Container(
      color: const Color(0xFF0D1F35),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ToolBtn(Icons.crop_rounded, 'Crop', () => _ctrl.rotate90Degrees()),
          _ToolBtn(Icons.rotate_90_degrees_ccw_rounded, 'Rotate',
              () => _ctrl.rotate90Degrees()),
          _ToolBtn(Icons.flip_rounded, 'Flip',
              () => _ctrl.preferredCropAspectRatio = null),
        ],
      ),
    ),

    // Trim slider
    Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.content_cut_rounded, color: _kBlue, size: 16),
            const SizedBox(width: 6),
            const Text('Trim', style: TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              '${_ctrl.trimmedDuration.inSeconds}s',
              style: const TextStyle(color: _kBlue, fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ]),
          const SizedBox(height: 8),
          TrimSlider(controller: _ctrl, height: 56),
        ],
      ),
    ),

    // Cover selection
    Container(
      color: const Color(0xFF0A1628),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cover Frame', style: TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CoverViewer(controller: _ctrl),
        ],
      ),
    ),
  ]);
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn(this.icon, this.label, this.onTap);
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Icon(icon, color: Colors.white70, size: 24),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]),
  );
}
