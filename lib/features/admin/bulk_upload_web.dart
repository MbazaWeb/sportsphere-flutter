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
  final input = html.document.createElement('input') as html.FileUploadInputElement;
  input.accept = '.xlsx';
  input.click();
  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) return null;
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  final result = reader.result;
  if (result is ByteBuffer) return result.asUint8List();
  return null;
}
