import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';

// ── Template definitions ───────────────────────────────────────────────────

class _Template {
  final String label;
  final String table;
  final List<_Col> columns;
  const _Template({required this.label, required this.table, required this.columns});

  String get csvHeader => columns.map((c) => c.key).join(',');

  String get exampleRow => columns.map((c) => c.example).join(',');

  String get fullTemplate => '$csvHeader\n$exampleRow';
}

class _Col {
  final String key;       // CSV column name = DB column name
  final String label;     // Human label
  final String example;   // Example value
  final bool required;
  final String hint;
  const _Col(this.key, this.label, this.example, {this.required = false, this.hint = ''});
}

const _templates = [
  _Template(
    label: 'Teams',
    table: 'Team',
    columns: [
      _Col('name',        'Club Name',       'Simba Sport Club',       required: true),
      _Col('shortName',   'Short Name',      'Simba',                  hint: 'Max 6 chars'),
      _Col('country',     'Country',         'Tanzania',               required: true),
      _Col('city',        'City',            'Dar es Salaam'),
      _Col('venue',       'Stadium',         'Benjamin Mkapa Stadium'),
      _Col('foundedYear', 'Founded Year',    '1936',                   hint: 'YYYY'),
      _Col('leagueId',    'League ID',       'league-1787427770104',   hint: 'From leagues table'),
      _Col('logoUrl',     'Logo URL',        'https://example.com/logo.png'),
    ],
  ),
  _Template(
    label: 'Players',
    table: 'Player',
    columns: [
      _Col('firstName',   'First Name',      'John',                   required: true),
      _Col('lastName',    'Last Name',       'Bocco',                  required: true),
      _Col('position',    'Position',        'Forward',                required: true, hint: 'Goalkeeper/Defender/Midfielder/Forward/Winger/Striker'),
      _Col('nationality', 'Nationality',     'Tanzanian'),
      _Col('shirtNumber', 'Shirt Number',    '9',                      hint: 'Integer'),
      _Col('teamId',      'Team ID',         'team-1787435558291',     hint: 'From teams table'),
      _Col('dateOfBirth', 'Date of Birth',   '1995-06-15',             hint: 'YYYY-MM-DD'),
      _Col('heightCm',    'Height (cm)',     '180',                    hint: 'Integer'),
      _Col('weightKg',    'Weight (kg)',     '75',                     hint: 'Integer'),
      _Col('photoUrl',    'Photo URL',       'https://example.com/photo.jpg'),
    ],
  ),
  _Template(
    label: 'Fixtures',
    table: 'Match',
    columns: [
      _Col('homeTeam',    'Home Team Name',  'Simba Sport Club',       required: true),
      _Col('awayTeam',    'Away Team Name',  'Young Africans SC',      required: true),
      _Col('league',      'Competition',     'Tanzania Premier League', required: true),
      _Col('kickoffAt',   'Kickoff (UTC)',   '2026-09-01T18:00:00Z',   required: true, hint: 'ISO 8601'),
      _Col('venue',       'Venue',           'Benjamin Mkapa Stadium'),
      _Col('season',      'Season',          '2026/27'),
      _Col('homeBadge',   'Home Badge URL',  'https://example.com/simba.png'),
      _Col('awayBadge',   'Away Badge URL',  'https://example.com/yanga.png'),
    ],
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key, this.onDone});
  final VoidCallback? onDone;
  @override State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _typeIndex = 0;
  final _ctrl = TextEditingController();
  bool _uploading = false;
  String? _result;

  // Preview state
  List<String> _headers = [];
  List<Map<String, String>> _previewRows = [];
  bool _previewing = false;

  _Template get _tpl => _templates[_typeIndex];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _templates.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {
          _typeIndex = _tabs.index;
          _headers = [];
          _previewRows = [];
          _result = null;
          _ctrl.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _loadTemplate() {
    _ctrl.text = _tpl.fullTemplate;
    _parse();
  }

  void _copyTemplate() {
    Clipboard.setData(ClipboardData(text: _tpl.fullTemplate));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template copied to clipboard'),
          duration: Duration(seconds: 2)));
  }

  void _parse() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) { setState(() { _headers = []; _previewRows = []; }); return; }
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;
    final headers = lines.first.split(',').map((h) => h.trim()).toList();
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final vals = line.split(',').map((v) => v.trim()).toList();
      final row = <String, String>{};
      for (var i = 0; i < headers.length && i < vals.length; i++) {
        row[headers[i]] = vals[i];
      }
      if (row.isNotEmpty) rows.add(row);
    }
    setState(() { _headers = headers; _previewRows = rows; _previewing = true; });
  }

  Future<void> _upload() async {
    if (_previewRows.isEmpty) { _parse(); return; }
    setState(() { _uploading = true; _result = null; });

    final tpl = _tpl;
    int count = 0;
    int failed = 0;

    try {
      for (final row in _previewRows) {
        final insert = <String, dynamic>{};
        final now = DateTime.now().toUtc().toIso8601String();

        for (final col in tpl.columns) {
          final v = row[col.key]?.trim() ?? '';
          if (v.isEmpty) continue;
          // Type coercions
          if (col.key == 'shirtNumber' || col.key == 'heightCm' ||
              col.key == 'weightKg' || col.key == 'foundedYear') {
            insert[col.key] = int.tryParse(v) ?? v;
          } else {
            insert[col.key] = v;
          }
        }

        if (insert.isEmpty) continue;

        // Generate ID and timestamps
        final ts = DateTime.now().millisecondsSinceEpoch;
        insert['id'] ??= '${tpl.table.toLowerCase()}-$ts-$count';
        insert['createdAt'] = now;
        insert['updatedAt'] = now;

        // Team-specific defaults
        if (tpl.table == 'Team') {
          final name = insert['name']?.toString() ?? '';
          final slug = name.toLowerCase().replaceAll(' ', '_')
              .replaceAll(RegExp(r'[^a-z0-9_]'), '');
          insert['slug'] ??= '${slug}_${insert['id']}';
          insert['isActive'] = true;
          insert['verified'] = true;
          insert['source'] = 'bulk_upload';
        }

        // Player-specific defaults
        if (tpl.table == 'Player') {
          final fn = insert['firstName']?.toString() ?? '';
          final ln = insert['lastName']?.toString() ?? '';
          insert['name'] ??= '$fn $ln'.trim();
          final slug = '${fn}_${ln}_$ts'.toLowerCase()
              .replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
          insert['slug'] ??= slug;
          insert['sport_slug'] = 'football';
          insert['isActive'] = true;
          insert['verified'] = false;
        }

        // Match-specific defaults
        if (tpl.table == 'Match') {
          insert['status'] = 'upcoming';
          insert['homeScore'] = 0;
          insert['awayScore'] = 0;
        }

        try {
          await Supabase.instance.client.from(tpl.table).upsert(insert);
          count++;
        } catch (e) {
          failed++;
        }
      }

      final msg = failed == 0
          ? 'Uploaded $count records successfully ✓'
          : 'Uploaded $count records. $failed failed.';
      if (mounted) {
        setState(() { _result = msg; _uploading = false; });
        widget.onDone?.call();
      }
    } catch (e) {
      if (mounted) setState(() { _result = 'Error: $e'; _uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      appBar: AppBar(
        backgroundColor: SportSphereColors.surface,
        title: const Text('Bulk Upload', style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: SportSphereColors.white),
        bottom: TabBar(
          controller: _tabs,
          labelColor: SportSphereColors.electricBlue,
          unselectedLabelColor: SportSphereColors.muted,
          indicatorColor: SportSphereColors.electricBlue,
          tabs: _templates.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _templates.map((_) => _buildBody()).toList(),
      ),
    );
  }

  Widget _buildBody() {
    final tpl = _tpl;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Column reference card ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SportSphereColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SportSphereColors.electricBlue.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.table_chart_rounded, color: SportSphereColors.electricBlue, size: 16),
              const SizedBox(width: 6),
              Text('${tpl.label} Columns',
                  style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _copyTemplate,
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Template', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: SportSphereColors.electricBlue),
              ),
            ]),
            const SizedBox(height: 8),
            ...tpl.columns.map((col) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 5, right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: col.required ? SportSphereColors.danger : SportSphereColors.muted,
                  ),
                ),
                SizedBox(width: 110,
                  child: Text(col.key,
                    style: const TextStyle(color: SportSphereColors.electricBlue, fontSize: 12, fontFamily: 'monospace'))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(col.label,
                    style: const TextStyle(color: SportSphereColors.white, fontSize: 12)),
                  if (col.hint.isNotEmpty)
                    Text(col.hint,
                      style: const TextStyle(color: SportSphereColors.muted, fontSize: 10)),
                ])),
                if (col.required)
                  const Text('*', style: TextStyle(color: SportSphereColors.danger, fontWeight: FontWeight.w900)),
              ]),
            )),
            const SizedBox(height: 4),
            const Text('* Required column',
                style: TextStyle(color: SportSphereColors.muted, fontSize: 10)),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Template download button ──────────────────────────────────────
        OutlinedButton.icon(
          onPressed: _loadTemplate,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Load Example Template'),
          style: OutlinedButton.styleFrom(
            foregroundColor: SportSphereColors.sportGreen,
            side: const BorderSide(color: SportSphereColors.sportGreen),
          ),
        ),

        const SizedBox(height: 14),

        // ── CSV input ─────────────────────────────────────────────────────
        const Text('Paste CSV Data:', style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: SportSphereColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: _ctrl,
            maxLines: 8,
            style: const TextStyle(color: SportSphereColors.white, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '${tpl.csvHeader}\n${tpl.exampleRow}',
              hintStyle: TextStyle(color: SportSphereColors.muted.withValues(alpha: 0.5), fontSize: 11),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) { if (_previewing) setState(() { _headers = []; _previewRows = []; _previewing = false; }); },
          ),
        ),

        const SizedBox(height: 10),

        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.preview_rounded, size: 16),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(foregroundColor: SportSphereColors.electricBlue,
                side: const BorderSide(color: SportSphereColors.electricBlue)),
          )),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(
            onPressed: _uploading ? null : (_previewRows.isNotEmpty ? _upload : _parse),
            icon: _uploading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(_previewRows.isNotEmpty ? Icons.upload_rounded : Icons.preview_rounded, size: 16),
            label: Text(_uploading ? 'Uploading...' : _previewRows.isNotEmpty ? 'Upload ${_previewRows.length} rows' : 'Preview First'),
            style: FilledButton.styleFrom(backgroundColor: SportSphereColors.electricBlue),
          )),
        ]),

        // ── Result ────────────────────────────────────────────────────────
        if (_result != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (_result!.startsWith('Error') ? SportSphereColors.danger : SportSphereColors.sportGreen)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (_result!.startsWith('Error')
                  ? SportSphereColors.danger : SportSphereColors.sportGreen).withValues(alpha: 0.4)),
            ),
            child: Text(_result!, style: TextStyle(
              color: _result!.startsWith('Error') ? SportSphereColors.danger : SportSphereColors.sportGreen,
              fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],

        // ── Preview table ─────────────────────────────────────────────────
        if (_previewRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.table_rows_rounded, color: SportSphereColors.muted, size: 14),
            const SizedBox(width: 6),
            Text('Preview — ${_previewRows.length} row${_previewRows.length == 1 ? '' : 's'}',
                style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(SportSphereColors.surface),
                dataRowColor: WidgetStatePropertyAll(SportSphereColors.background),
                headingTextStyle: const TextStyle(color: SportSphereColors.electricBlue, fontSize: 11, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: SportSphereColors.white, fontSize: 11),
                columnSpacing: 16,
                columns: _headers.map((h) => DataColumn(label: Text(h))).toList(),
                rows: _previewRows.take(10).map((row) => DataRow(
                  cells: _headers.map((h) => DataCell(
                    Text(row[h] ?? '', overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                  )).toList(),
                )).toList(),
              ),
            ),
          ),
          if (_previewRows.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('+ ${_previewRows.length - 10} more rows not shown',
                  style: const TextStyle(color: SportSphereColors.muted, fontSize: 11)),
            ),
        ],

        const SizedBox(height: 80),
      ]),
    );
  }
}
