import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfViewerPage extends StatefulWidget {
  final String url;
  final String title;
  const PdfViewerPage({super.key, required this.url, this.title = 'Document'});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfControllerPinch? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    if (kIsWeb) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode >= 400) throw StateError('Could not download PDF');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ss_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(res.bodyBytes);
      _controller = PdfControllerPinch(document: PdfDocument.openFile(file.path));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071422),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071422),
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                          child: const Text('Open externally'),
                        ),
                      ],
                    ),
                  ),
                )
              : kIsWeb
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Open PDF'),
                      ),
                    )
                  : PdfViewPinch(controller: _controller!),
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
