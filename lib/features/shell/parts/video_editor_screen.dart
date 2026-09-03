// lib/features/shell/parts/video_editor_screen.dart
// Video editor — ffmpeg_kit removed (jcenter discontinued).
// Simple trim UI shown instead; full editor coming in next release.
import 'dart:io';
import 'package:flutter/material.dart';

/// Opens a basic video preview. Returns original file (no edit).
Future<File?> openVideoEditor(BuildContext context, File videoFile) async {
  // Show info snackbar — full editor requires ffmpeg
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Video uploaded as-is. Full editor coming soon.'),
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: 2),
  ));
  return videoFile; // return original unchanged
}
