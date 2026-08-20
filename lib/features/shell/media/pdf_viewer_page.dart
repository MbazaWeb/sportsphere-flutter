
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfViewerPage extends StatelessWidget {
  final String url;
  final String title;
  const PdfViewerPage({super.key, required this.url, this.title = 'Document'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071422),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071422),
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: FilledButton.icon(
          onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Open PDF'),
        ),
      ),
    );
  }
}

void openMediaUrl(BuildContext context, String url, {String? title}) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.pdf') || lower.contains('application/pdf')) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(url: url, title: title ?? 'PDF'),
      ),
    );
  } else {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
