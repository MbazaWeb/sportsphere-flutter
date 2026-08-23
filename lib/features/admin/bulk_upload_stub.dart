import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadExcelFile(Uint8List bytes, String filename) async {
  final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  final uri = Uri.file(file.path);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<List<int>?> pickExcelFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
    withData: true,
  );
  if (result == null) return null;
  final f = result.files.first;
  if (f.bytes != null) return f.bytes!;
  if (f.path != null) return File(f.path!).readAsBytesSync();
  return null;
}
