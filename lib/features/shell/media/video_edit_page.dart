
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VideoEditResult {
  const VideoEditResult({required this.path, required this.mute});
  final String path;
  final bool mute;
}

class VideoEditPage extends StatelessWidget {
  const VideoEditPage({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.pop(context, VideoEditResult(path: path, mute: false)),
          child: const Text('Use clip'),
        ),
      ),
    );
  }
}

XFile videoAsXFile(String path) => XFile(path);
