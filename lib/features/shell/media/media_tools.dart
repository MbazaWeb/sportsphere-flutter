import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

import 'video_edit_page.dart';

const kMaxVideoSeconds = 30;

bool _isVideo(XFile f) {
  final n = f.name.toLowerCase();
  final p = f.path.toLowerCase();
  return n.endsWith('.mp4') ||
      n.endsWith('.mov') ||
      n.endsWith('.m4v') ||
      p.endsWith('.mp4') ||
      p.endsWith('.mov') ||
      (f.mimeType ?? '').startsWith('video/');
}

Future<XFile?> cropImageFile(XFile file) async {
  if (kIsWeb) return file;
  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: const Color(0xFF071422),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop photo'),
      ],
    );
    if (cropped == null) return file;
    return XFile(cropped.path, mimeType: 'image/jpeg', name: cropped.path.split('/').last);
  } catch (_) {
    return file;
  }
}

Future<XFile?> editVideoFile(BuildContext context, XFile file) async {
  if (kIsWeb) return file;
  final result = await Navigator.of(context).push<VideoEditResult>(
    MaterialPageRoute(
      builder: (_) => VideoEditPage(path: file.path),
      fullscreenDialog: true,
    ),
  );
  if (result == null) return null;
  var out = XFile(result.path, name: result.path.split(RegExp(r'[\\/]')).last, mimeType: 'video/mp4');
  if (result.mute) {
    try {
      final compressed = await VideoCompress.compressVideo(
        result.path,
        quality: VideoQuality.MediumQuality,
        includeAudio: false,
      );
      if (compressed?.path != null) {
        out = XFile(compressed!.path!, name: compressed.path!.split(RegExp(r'[\\/]')).last, mimeType: 'video/mp4');
      }
    } catch (_) {}
  }
  return out;
}

Future<List<XFile>> pickAndEditMedia(BuildContext context, {int remaining = 4}) async {
  if (remaining <= 0) return [];
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF071422),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text('Add media', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photos'),
            onTap: () => Navigator.pop(ctx, 'photo'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Video (max 30s)'),
            subtitle: const Text('Trim, crop timeline, mute'),
            onTap: () => Navigator.pop(ctx, 'video'),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Camera photo'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.fiber_manual_record),
            title: const Text('Record video (max 30s)'),
            onTap: () => Navigator.pop(ctx, 'record'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF document'),
            subtitle: const Text('Reports, fixtures, press kits'),
            onTap: () => Navigator.pop(ctx, 'pdf'),
          ),
          ListTile(
            leading: const Icon(Icons.gif_box_outlined),
            title: const Text('GIF'),
            onTap: () => Navigator.pop(ctx, 'gif'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null) return [];

  final picker = ImagePicker();
  final out = <XFile>[];

  if (choice == 'photo') {
    final files = await picker.pickMultiImage();
    for (final f in files.take(remaining)) {
      final cropped = await cropImageFile(f);
      if (cropped != null) out.add(cropped);
    }
  } else if (choice == 'camera') {
    final f = await picker.pickImage(source: ImageSource.camera);
    if (f != null) {
      final cropped = await cropImageFile(f);
      if (cropped != null) out.add(cropped);
    }
  } else if (choice == 'video') {
    final f = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: kMaxVideoSeconds));
    if (f != null && context.mounted) {
      final edited = await editVideoFile(context, f);
      if (edited != null) out.add(edited);
    }
  } else if (choice == 'record') {
    final f = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: kMaxVideoSeconds));
    if (f != null && context.mounted) {
      final edited = await editVideoFile(context, f);
      if (edited != null) out.add(edited);
    }
  } else if (choice == 'pdf') {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      if (f.path != null) {
        out.add(XFile(f.path!, name: f.name, mimeType: 'application/pdf'));
      } else if (f.bytes != null) {
        out.add(XFile.fromData(f.bytes!, name: f.name, mimeType: 'application/pdf'));
      }
    }
  } else if (choice == 'gif') {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gif'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      if (f.path != null) {
        out.add(XFile(f.path!, name: f.name, mimeType: 'image/gif'));
      } else if (f.bytes != null) {
        out.add(XFile.fromData(f.bytes!, name: f.name, mimeType: 'image/gif'));
      }
    }
  }

  return out;
}


Future<XFile?> pickCommentAttachmentDirect(String type) async {
  if (type == 'image') {
    return ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
  }
  if (type == 'gif') {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gif'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    if (f.path != null) return XFile(f.path!, name: f.name, mimeType: 'image/gif');
    if (f.bytes != null) return XFile.fromData(f.bytes!, name: f.name, mimeType: 'image/gif');
  }
  if (type == 'pdf') {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    if (f.path != null) return XFile(f.path!, name: f.name, mimeType: 'application/pdf');
    if (f.bytes != null) return XFile.fromData(f.bytes!, name: f.name, mimeType: 'application/pdf');
  }
  return null;
}
