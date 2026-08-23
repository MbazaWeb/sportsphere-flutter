import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});
  @override State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  final _ctrl = TextEditingController();
  String _type = 'matches';
  bool _uploading = false;
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      appBar: AppBar(
        backgroundColor: SportSphereColors.surface,
        title: const Text('Bulk Upload', style: TextStyle(color: SportSphereColors.white)),
        iconTheme: const IconThemeData(color: SportSphereColors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Paste CSV data below:', style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _type,
            dropdownColor: SportSphereColors.surface,
            decoration: const InputDecoration(labelText: 'Data type', labelStyle: TextStyle(color: SportSphereColors.muted)),
            items: const [
              DropdownMenuItem(value: 'matches', child: Text('Matches', style: TextStyle(color: SportSphereColors.white))),
              DropdownMenuItem(value: 'teams', child: Text('Teams', style: TextStyle(color: SportSphereColors.white))),
              DropdownMenuItem(value: 'players', child: Text('Players', style: TextStyle(color: SportSphereColors.white))),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          Expanded(child: TextField(
            controller: _ctrl,
            maxLines: null,
            expands: true,
            style: const TextStyle(color: SportSphereColors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Paste CSV here (header row first)...',
              hintStyle: const TextStyle(color: SportSphereColors.muted),
              filled: true, fillColor: SportSphereColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
          const SizedBox(height: 12),
          if (_result != null) Text(_result!, style: TextStyle(
              color: _result!.startsWith('Error') ? SportSphereColors.danger : SportSphereColors.sportGreen)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SportSphereColors.electricBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _uploading ? null : _upload,
            child: _uploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Upload', style: TextStyle(fontWeight: FontWeight.w800)),
          )),
        ]),
      ),
    );
  }

  Future<void> _upload() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _uploading = true; _result = null; });
    try {
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) throw Exception('Need header row + at least one data row');
      final headers = lines.first.split(',').map((h) => h.trim()).toList();
      final table = _type == 'matches' ? 'Match' : _type == 'teams' ? 'Team' : 'Player';
      int count = 0;
      for (final line in lines.skip(1)) {
        final vals = line.split(',').map((v) => v.trim()).toList();
        final row = <String, dynamic>{};
        for (var i = 0; i < headers.length && i < vals.length; i++) {
          if (vals[i].isNotEmpty) row[headers[i]] = vals[i];
        }
        if (row.isEmpty) continue;
        row['id'] ??= '$_type-${DateTime.now().millisecondsSinceEpoch}-$count';
        row['createdAt'] ??= DateTime.now().toUtc().toIso8601String();
        await Supabase.instance.client.from(table).upsert(row);
        count++;
      }
      if (mounted) setState(() { _result = 'Uploaded $count records successfully ✓'; _uploading = false; });
    } catch (e) {
      if (mounted) setState(() { _result = 'Error: $e'; _uploading = false; });
    }
  }
}
