
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const kMaxVideoSeconds = 30;

Future<fp.FilePickerResult?> _pickFiles({
  required fp.FileType type,
  List<String>? allowedExtensions,
  bool withData = true,
}) async {
  try {
    return await fp.FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      withData: withData,
      allowMultiple: false,
    );
  } catch (_) {
    // Web / desktop fallback if platform channel is unavailable.
    return await fp.FilePicker.pickFiles(
      type: fp.FileType.any,
      withData: withData,
      allowMultiple: false,
    );
  }
}


Future<XFile?> cropImageFile(XFile file) async => file;

Future<XFile?> editVideoFile(BuildContext context, XFile file) async => file;

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
            onTap: () => Navigator.pop(ctx, 'video'),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Camera photo'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF document'),
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
    out.addAll(files.take(remaining));
  } else if (choice == 'camera') {
    if (kIsWeb) return out; // camera not available on web
    final f = await picker.pickImage(source: ImageSource.camera);
    if (f != null) out.add(f);
  } else if (choice == 'video') {
    final f = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: kMaxVideoSeconds),
    );
    if (f != null) out.add(f);
  } else if (choice == 'pdf' || choice == 'gif') {
    final picked = await pickCommentAttachmentDirect(choice);
    if (picked != null) out.add(picked);
  }

  return out;
}

Future<XFile?> pickCommentAttachmentDirect(String type) async {
  if (type == 'image') {
    return ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
  }
  if (type == 'gif' || type == 'pdf') {
    final res = await _pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: type == 'pdf' ? <String>['pdf'] : <String>['gif'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    final mime = type == 'pdf' ? 'application/pdf' : 'image/gif';
    if (!kIsWeb && f.path != null) {
      return XFile(f.path!, name: f.name, mimeType: mime);
    }
    if (f.bytes != null) {
      return XFile.fromData(f.bytes!, name: f.name, mimeType: mime);
    }
  }
  return null;
}
