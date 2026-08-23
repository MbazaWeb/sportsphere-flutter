// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void downloadExcelFile(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<List<int>?> pickExcelFile() async {
  final completer = html.document.createElement('input') as html.FileUploadInputElement;
  completer.accept = '.xlsx';
  completer.click();
  await completer.onChange.first;
  final file = completer.files?.first;
  if (file == null) return null;
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  final result = reader.result;
  if (result is List<int>) return result;
  if (result is html.ByteBuffer) return result.asUint8List();
  return null;
}
