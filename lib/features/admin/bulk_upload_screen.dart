import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';

import '../../core/data/vps_supabase_compat.dart';
import '../../core/theme/colors.dart';

// ignore: avoid_web_libraries_in_flutter
import 'bulk_upload_web.dart' if (dart.library.io) 'bulk_upload_stub.dart';

// ── Column definition ──────────────────────────────────────────────────────

class _Col {
  const _Col(this.key, this.label, this.example,
      {this.required = false, this.hint = ''});
  final String key;
  final String label;
  final String example;
  final bool required;
  final String hint;
}

// ── Sheet templates ────────────────────────────────────────────────────────

const _teamCols = [
  _Col('name',        'Club Name',       'Simba Sport Club',            required: true),
  _Col('shortName',   'Short Name',      'Simba',                       hint: 'Max 6 chars'),
  _Col('country',     'Country',         'Tanzania',                    required: true),
  _Col('city',        'City',            'Dar es Salaam'),
  _Col('venue',       'Stadium',         'Benjamin Mkapa Stadium'),
  _Col('foundedYear', 'Founded Year',    '1936',                        hint: 'YYYY number'),
  _Col('leagueId',    'League ID',       '',                            hint: 'From Leagues tab'),
  _Col('logoUrl',     'Logo URL',        ''),
];

const _playerCols = [
  _Col('firstName',   'First Name',      'John',                        required: true),
  _Col('lastName',    'Last Name',       'Bocco',                       required: true),
  _Col('position',    'Position',        'Forward',                     required: true,
      hint: 'Goalkeeper / Defender / Midfielder / Forward / Winger / Striker'),
  _Col('nationality', 'Nationality',     'Tanzanian'),
  _Col('shirtNumber', 'Shirt Number',    '9',                           hint: 'Number'),
  _Col('teamId',      'Team ID',         '',                            hint: 'From Teams tab'),
  _Col('dateOfBirth', 'Date of Birth',   '1995-06-15',                  hint: 'YYYY-MM-DD'),
  _Col('heightCm',    'Height cm',       '180',                         hint: 'Number'),
  _Col('weightKg',    'Weight kg',       '75',                          hint: 'Number'),
  _Col('photoUrl',    'Photo URL',       ''),
];

const _fixtureCols = [
  _Col('homeTeam',    'Home Team Name',  'Simba Sport Club',            required: true),
  _Col('awayTeam',    'Away Team Name',  'Young Africans SC',           required: true),
  _Col('league',      'Competition',     'Tanzania Premier League',     required: true),
  _Col('kickoffAt',   'Kickoff UTC',     '2026-09-01T18:00:00Z',        required: true,
      hint: 'ISO 8601 e.g. 2026-09-01T18:00:00Z'),
  _Col('venue',       'Venue',           'Benjamin Mkapa Stadium'),
  _Col('season',      'Season',          '2026/27'),
  _Col('homeBadge',   'Home Badge URL',  ''),
  _Col('awayBadge',   'Away Badge URL',  ''),
];

const _sheets = [
  ('Teams',    _teamCols),
  ('Players',  _playerCols),
  ('Fixtures', _fixtureCols),
];

// ── Excel generation ───────────────────────────────────────────────────────

Uint8List _buildTemplate() {
  final excel = Excel.createExcel();
  // Remove default Sheet1
  excel.delete('Sheet1');

  for (final (sheetName, cols) in _sheets) {
    final sheet = excel[sheetName];

    // Header row — bold
    for (var i = 0; i < cols.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(cols[i].key);
      cell.cellStyle = CellStyle(bold: true, fontColorHex: ExcelColor.fromHexString('FF168CFF'));
    }

    // Hint row (row 2, italic)
    for (var i = 0; i < cols.length; i++) {
      final col = cols[i];
      final hint = [
        col.label,
        if (col.required) '(REQUIRED)',
        if (col.hint.isNotEmpty) col.hint,
      ].join(' — ');
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(hint);
      cell.cellStyle = CellStyle(italic: true, fontColorHex: ExcelColor.fromHexString('FF888888'));
    }

    // Example data row
    for (var i = 0; i < cols.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(cols[i].example);
    }

    // Set column widths
    for (var i = 0; i < cols.length; i++) {
      sheet.setColumnWidth(i, 22);
    }
  }

  final bytes = excel.encode();
  return Uint8List.fromList(bytes!);
}

// ── Screen ─────────────────────────────────────────────────────────────────

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key, this.onDone});
  final VoidCallback? onDone;
  @override State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _downloading = false;

  // Per-tab state
  final List<List<String>> _headers = [[], [], []];
  final List<List<Map<String, String>>> _rows = [[], [], []];
  final List<String?> _results = [null, null, null];
  final List<bool> _uploading = [false, false, false];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  // ── Download template ───────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    setState(() => _downloading = true);
    try {
      final bytes = _buildTemplate();
      downloadExcelFile(bytes, 'playify_bulk_template.xlsx');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Template downloaded — fill all 3 sheets then upload')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ── Upload filled file ──────────────────────────────────────────────────

  Future<void> _pickAndParse() async {
    try {
      final bytes = await pickExcelFile();
      if (bytes == null) return;

      final excel = Excel.decodeBytes(bytes);
      for (var si = 0; si < _sheets.length; si++) {
        final sheetName = _sheets[si].$1;
        final sheet = excel[sheetName];
        if (sheet.rows.isEmpty) continue;

        // Row 0 = headers (column keys)
        final hdrs = sheet.rows[0]
            .map((c) => c?.value?.toString().trim() ?? '')
            .where((h) => h.isNotEmpty)
            .toList();

        // Row 2+ = data (skip row 1 hints)
        final dataRows = <Map<String, String>>[];
        for (final row in sheet.rows.skip(2)) {
          final map = <String, String>{};
          for (var i = 0; i < hdrs.length && i < row.length; i++) {
            final v = row[i]?.value?.toString().trim() ?? '';
            if (v.isNotEmpty) map[hdrs[i]] = v;
          }
          if (map.isNotEmpty) dataRows.add(map);
        }

        _headers[si] = hdrs;
        _rows[si] = dataRows;
        _results[si] = null;
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Loaded — Teams: ${_rows[0].length}, '
                'Players: ${_rows[1].length}, Fixtures: ${_rows[2].length} rows')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')));
      }
    }
  }

  // ── Upload one sheet ────────────────────────────────────────────────────

  Future<void> _uploadSheet(int si) async {
    final rows = _rows[si];
    if (rows.isEmpty) return;
    setState(() { _uploading[si] = true; _results[si] = null; });

    final tableName = si == 0 ? 'Team' : si == 1 ? 'Player' : 'Match';
    int count = 0; int failed = 0;

    for (final row in rows) {
      final insert = <String, dynamic>{};
      final now = DateTime.now().toUtc().toIso8601String();
      final ts = DateTime.now().millisecondsSinceEpoch;

      row.forEach((k, v) {
        if (v.isEmpty) return;
        const intCols = ['shirtNumber', 'heightCm', 'weightKg', 'foundedYear',
                         'homeScore', 'awayScore'];
        if (intCols.contains(k)) {
          insert[k] = int.tryParse(v) ?? v;
        } else {
          insert[k] = v;
        }
      });

      if (insert.isEmpty) continue;
      insert['id'] ??= '${tableName.toLowerCase()}-$ts-$count';
      insert['createdAt'] = now;
      insert['updatedAt'] = now;

      if (tableName == 'Team') {
        final name = insert['name']?.toString() ?? '';
        final slug = name.toLowerCase()
            .replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
        insert['slug'] ??= '${slug}_${insert['id']}';
        insert['isActive'] = true;
        insert['verified'] = true;
        insert['source'] = 'bulk_upload';
      }
      if (tableName == 'Player') {
        final fn = insert['firstName']?.toString() ?? '';
        final ln = insert['lastName']?.toString() ?? '';
        insert['name'] = '$fn $ln'.trim();
        final slug = '${fn}_${ln}_$ts'.toLowerCase()
            .replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
        insert['slug'] ??= slug;
        insert['sport_slug'] = 'football';
        insert['isActive'] = true;
        insert['verified'] = false;
      }
      if (tableName == 'Match') {
        insert['status'] ??= 'upcoming';
        insert['homeScore'] ??= 0;
        insert['awayScore'] ??= 0;
      }

      try {
        await VpsSupabaseCompat.client.from(tableName).upsert(insert);
        count++;
      } catch (_) { failed++; }
    }

    final msg = failed == 0
        ? 'Uploaded $count records ✓'
        : 'Uploaded $count, failed $failed';
    if (mounted) {
      setState(() { _results[si] = msg; _uploading[si] = false; });
      if (failed == 0) widget.onDone?.call();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayifyColors.background,
      appBar: AppBar(
        backgroundColor: PlayifyColors.surface,
        title: const Text('Bulk Upload', style: TextStyle(
            color: PlayifyColors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: PlayifyColors.white),
        actions: [
          TextButton.icon(
            onPressed: _downloading ? null : _downloadTemplate,
            icon: _downloading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            label: const Text('Download Template',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _pickAndParse,
            icon: const Icon(Icons.upload_file_rounded, color: PlayifyColors.electricBlue, size: 18),
            label: const Text('Upload File',
                style: TextStyle(color: PlayifyColors.electricBlue, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: PlayifyColors.electricBlue,
          unselectedLabelColor: PlayifyColors.muted,
          indicatorColor: PlayifyColors.electricBlue,
          tabs: const [Tab(text: 'Teams'), Tab(text: 'Players'), Tab(text: 'Fixtures')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: List.generate(3, (si) => _buildTab(si)),
      ),
    );
  }

  Widget _buildTab(int si) {
    final sheetName = _sheets[si].$1;
    final cols = _sheets[si].$2;
    final rows = _rows[si];
    final headers = _headers[si];
    final result = _results[si];
    final uploading = _uploading[si];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── How to use ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PlayifyColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PlayifyColors.electricBlue.withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: PlayifyColors.electricBlue, size: 16),
              const SizedBox(width: 6),
              Text('$sheetName — Required Columns',
                  style: const TextStyle(color: PlayifyColors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
            const SizedBox(height: 10),
            ...cols.map((col) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 5, right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: col.required ? PlayifyColors.danger : PlayifyColors.muted,
                  )),
                SizedBox(width: 130,
                  child: Text(col.key, style: const TextStyle(
                      color: PlayifyColors.electricBlue, fontSize: 12,
                      fontFamily: 'monospace'))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(col.label, style: const TextStyle(color: PlayifyColors.white, fontSize: 12)),
                  if (col.hint.isNotEmpty)
                    Text(col.hint, style: const TextStyle(
                        color: PlayifyColors.muted, fontSize: 10)),
                ])),
                if (col.required)
                  const Text('*', style: TextStyle(
                      color: PlayifyColors.danger, fontWeight: FontWeight.w900)),
              ]),
            )),
            const SizedBox(height: 6),
            const Text('* Required  ● = Optional',
                style: TextStyle(color: PlayifyColors.muted, fontSize: 10)),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Step guide ───────────────────────────────────────────────────
        if (rows.isEmpty) ...[
          const _Step(n: '1', text: 'Tap Download Template (top right) to get the Excel file'),
          _Step(n: '2', text: 'Fill in the data on the $sheetName sheet'),
          const _Step(n: '3', text: 'Tap Upload File to import your data'),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _downloading ? null : _downloadTemplate,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download Template (.xlsx)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: PlayifyColors.sportGreen,
              side: const BorderSide(color: PlayifyColors.sportGreen),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )),
        ],

        // ── Preview table ────────────────────────────────────────────────
        if (rows.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.table_rows_rounded, color: PlayifyColors.sportGreen, size: 16),
            const SizedBox(width: 6),
            Text('${rows.length} row${rows.length == 1 ? '' : 's'} ready to upload',
                style: const TextStyle(color: PlayifyColors.white, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(PlayifyColors.surface),
                dataRowColor: const WidgetStatePropertyAll(PlayifyColors.background),
                headingTextStyle: const TextStyle(color: PlayifyColors.electricBlue,
                    fontSize: 11, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: PlayifyColors.white, fontSize: 11),
                columnSpacing: 16,
                columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
                rows: rows.take(10).map((row) => DataRow(
                  cells: headers.map((h) => DataCell(
                    Text(row[h] ?? '', overflow: TextOverflow.ellipsis))).toList(),
                )).toList(),
              ),
            ),
          ),
          if (rows.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${rows.length - 10} more rows',
                  style: const TextStyle(color: PlayifyColors.muted, fontSize: 11)),
            ),
          const SizedBox(height: 12),

          if (result != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: (result.startsWith('Uploaded') && !result.contains('failed')
                    ? PlayifyColors.sportGreen : PlayifyColors.danger)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(result, style: TextStyle(
                color: result.startsWith('Uploaded') && !result.contains('failed')
                    ? PlayifyColors.sportGreen : PlayifyColors.danger,
                fontWeight: FontWeight.w600)),
            ),

          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: uploading ? null : () => _uploadSheet(si),
            icon: uploading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(uploading ? 'Uploading...' : 'Upload ${rows.length} $sheetName'),
            style: FilledButton.styleFrom(
              backgroundColor: PlayifyColors.electricBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )),
        ],

        const SizedBox(height: 80),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(
        width: 24, height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: PlayifyColors.electricBlue,
        ),
        child: Text(n, style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: PlayifyColors.white, fontSize: 13))),
    ]),
  );
}
