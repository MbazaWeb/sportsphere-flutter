import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadExcelFile(Uint8List bytes, String filename) async {
  final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  final uri = Uri.file(file.path);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

// On mobile, we skip file picking and return null (CSV paste used instead)
Future<List<int>?> pickExcelFile() async => null;
