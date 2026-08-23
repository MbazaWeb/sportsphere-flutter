import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/colors.dart';
import 'admin_repository.dart';

/// Bulk upload screen for admins. Supports Excel-based upload of
/// fixtures, teams, and players with downloadable sample templates.
class BulkUploadScreen extends StatefulWidget {
  final void Function() onDone;
  const BulkUploadScreen({super.key, required this.onDone});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  final _repo = AdminRepository();
  bool _uploading = false;
  String _status = '';
  int _progress = 0;
  int _total = 0;

  // ── Template generation ──────────────────────────────────────────

  Future<void> _downloadTemplate(BulkType type) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel[type.sheetName];

    // Header row
    final headers = type.headers;
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(headers[c]);
    }

    // Sample data row
    final sample = type.sampleRow;
    for (var c = 0; c < sample.length && c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
      final v = sample[c];
      cell.value = v is int ? IntCellValue(v) : TextCellValue(v.toString());
    }

    // Save to temporary file and share
    final bytes = excel.save();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${type.fileName}');
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template saved: ${type.fileName}'),
          backgroundColor: SportSphereColors.sportGreen,
          action: SnackBarAction(
            label: 'OK',
            textColor: SportSphereColors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // ── Excel parsing ────────────────────────────────────────────────

  List<Map<String, dynamic>> _parseExcel(File file, BulkType type) {
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel[type.sheetName];
    if (sheet == null) {
      throw Exception('Sheet "${type.sheetName}" not found in the workbook');
    }
    final headers = type.headers;
    final rows = <Map<String, dynamic>>[];

    for (var r = 1; r <= sheet.maxRows; r++) {
      final row = <String, dynamic>{};
      var hasData = false;
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        final val = cell.value;
        if (val == null) continue;
        final str = val.toString().trim();
        if (str.isEmpty) continue;
        hasData = true;
        row[headers[c]] = str;
      }
      if (hasData) rows.add(row);
    }
    return rows;
  }

  // ── Upload flow ──────────────────────────────────────────────────

  Future<void> _pickAndUpload(BulkType type) async {
    // Pick file
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    final file = File(filePath);
    if (!file.existsSync()) return;

    setState(() {
      _uploading = true;
      _status = 'Parsing ${type.label}...';
      _progress = 0;
      _total = 0;
    });

    try {
      final rows = _parseExcel(file, type);
      if (rows.isEmpty) {
        _showError('No valid rows found in the Excel file.');
        return;
      }
      _total = rows.length;

      // Resolve team names to IDs for players
      if (type == BulkType.players) {
        final teams = await _repo.listTeams();
        final nameToId = <String, String>{};
        for (final t in teams) {
          final n = (t['name'] as String?)?.trim().toLowerCase() ?? '';
          final id = (t['id'] as String?) ?? '';
          if (n.isNotEmpty && id.isNotEmpty) nameToId[n] = id;
        }
        for (final r in rows) {
          final teamName = (r['team'] as String?)?.trim().toLowerCase() ?? '';
          if (teamName.isNotEmpty && nameToId.containsKey(teamName)) {
            r['teamId'] = nameToId[teamName];
          }
        }
      }

      // Resolve league name to ID for teams
      if (type == BulkType.teams) {
        final comps = await _repo.listCompetitions();
        final nameToId = <String, String>{};
        for (final c in comps) {
          final n = (c['name'] as String?)?.trim().toLowerCase() ?? '';
          final id = (c['id'] as String?) ?? '';
          if (n.isNotEmpty && id.isNotEmpty) nameToId[n] = id;
        }
        for (final r in rows) {
          final leagueName = (r['league'] as String?)?.trim().toLowerCase() ?? '';
          if (leagueName.isNotEmpty && nameToId.containsKey(leagueName)) {
            r['leagueId'] = nameToId[leagueName];
          }
        }
      }

      setState(() => _status = 'Uploading ${rows.length} ${type.label}...');

      int inserted;
      switch (type) {
        case BulkType.teams:
          inserted = await _repo.bulkCreateTeams(rows);
        case BulkType.players:
          inserted = await _repo.bulkCreatePlayers(rows);
        case BulkType.fixtures:
          inserted = await _repo.bulkCreateFixtures(rows);
      }

      if (mounted) {
        setState(() {
          _uploading = false;
          _status = 'Done! $inserted/${rows.length} ${type.label} uploaded.';
          _progress = rows.length;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$inserted ${type.label} uploaded successfully'),
            backgroundColor: SportSphereColors.sportGreen,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (mounted) {
      setState(() {
        _uploading = false;
        _status = 'Error: $msg';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: SportSphereColors.danger,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      appBar: AppBar(
        backgroundColor: SportSphereColors.background,
        foregroundColor: SportSphereColors.white,
        elevation: 0,
        title: const Text('Bulk Upload',
            style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status bar
          if (_status.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _status.startsWith('Error')
                    ? SportSphereColors.danger.withOpacity(0.12)
                    : _status.startsWith('Done')
                        ? SportSphereColors.sportGreen.withOpacity(0.12)
                        : SportSphereColors.electricBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _status.startsWith('Error')
                      ? SportSphereColors.danger
                      : _status.startsWith('Done')
                          ? SportSphereColors.sportGreen
                          : SportSphereColors.electricBlue,
                  width: 1,
                ),
              ),
              child: Row(children: [
                if (_uploading)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: SportSphereColors.electricBlue),
                  )
                else if (_status.startsWith('Done'))
                  const Icon(Icons.check_circle_rounded,
                      color: SportSphereColors.sportGreen, size: 20)
                else if (_status.startsWith('Error'))
                  const Icon(Icons.error_rounded,
                      color: SportSphereColors.danger, size: 20)
                else
                  const Icon(Icons.upload_rounded,
                      color: SportSphereColors.electricBlue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_status,
                      style: const TextStyle(color: SportSphereColors.white, fontSize: 13)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Upload cards for each type
          _BulkCard(
            icon: Icons.sports_soccer_rounded,
            title: 'Upload Fixtures',
            subtitle: 'Bulk schedule matches from Excel',
            color: const Color(0xFFE31B23),
            uploading: _uploading,
            onUpload: () => _pickAndUpload(BulkType.fixtures),
            onTemplate: () => _downloadTemplate(BulkType.fixtures),
          ),
          const SizedBox(height: 12),
          _BulkCard(
            icon: Icons.groups_rounded,
            title: 'Upload Teams',
            subtitle: 'Bulk create clubs/national teams',
            color: SportSphereColors.electricBlue,
            uploading: _uploading,
            onUpload: () => _pickAndUpload(BulkType.teams),
            onTemplate: () => _downloadTemplate(BulkType.teams),
          ),
          const SizedBox(height: 12),
          _BulkCard(
            icon: Icons.person_rounded,
            title: 'Upload Players',
            subtitle: 'Bulk create players for teams',
            color: SportSphereColors.sportGreen,
            uploading: _uploading,
            onUpload: () => _pickAndUpload(BulkType.players),
            onTemplate: () => _downloadTemplate(BulkType.players),
          ),
          const SizedBox(height: 24),

          // Instructions
          _InstructionsSection(),
        ],
      ),
    );
  }
}

// ── Bulk upload type enum ─────────────────────────────────────────────

enum BulkType {
  fixtures,
  teams,
  players;

  String get label => switch (this) {
    BulkType.fixtures => 'Fixtures',
    BulkType.teams => 'Teams',
    BulkType.players => 'Players',
  };

  String get sheetName => switch (this) {
    BulkType.fixtures => 'Fixtures',
    BulkType.teams => 'Teams',
    BulkType.players => 'Players',
  };

  String get fileName => switch (this) {
    BulkType.fixtures => 'bulk_fixtures_template.xlsx',
    BulkType.teams => 'bulk_teams_template.xlsx',
    BulkType.players => 'bulk_players_template.xlsx',
  };

  List<String> get headers => switch (this) {
    BulkType.fixtures => ['homeTeam', 'awayTeam', 'league', 'kickoffAt', 'venue', 'season'],
    BulkType.teams => ['name', 'country', 'city', 'league', 'venue', 'foundedYear', 'primaryColor'],
    BulkType.players => ['name', 'position', 'team', 'nationality', 'shirtNumber'],
  };

  List<dynamic> get sampleRow => switch (this) {
    BulkType.fixtures => ['Simba SC', 'Young Africans', 'Tanzania Premier League', '2026-09-15 15:00', 'National Stadium', '2026/27'],
    BulkType.teams => ['Simba SC', 'Tanzania', 'Dar es Salaam', 'Tanzania Premier League', 'National Stadium', 1936, '#E31B23'],
    BulkType.players => ['John Bocco', 'Forward', 'Simba SC', 'Tanzania', 9],
  };
}

// ── Upload card widget ─────────────────────────────────────────────────

class _BulkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onTemplate;

  const _BulkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.uploading,
    required this.onUpload,
    required this.onTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: SportSphereColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onTemplate,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Sample Template', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: SportSphereColors.muted,
                side: const BorderSide(color: SportSphereColors.muted),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: uploading ? null : onUpload,
              icon: uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SportSphereColors.white))
                  : const Icon(Icons.upload_rounded, size: 16),
              label: Text(uploading ? 'Uploading...' : 'Upload', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: color.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Instructions section ───────────────────────────────────────────────

class _InstructionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('How to Use',
            style: TextStyle(color: SportSphereColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _step('1', 'Download the sample template for the type you want to upload.'),
        const SizedBox(height: 8),
        _step('2', 'Fill in your data in the Excel file. Keep the header row exactly as provided.'),
        const SizedBox(height: 8),
        _step('3', 'For Fixtures: kickoffAt format is yyyy-MM-dd HH:mm (e.g. 2026-09-15 15:00).'),
        const SizedBox(height: 8),
        _step('4', 'For Teams: league and primaryColor are optional. Use exact league names.'),
        const SizedBox(height: 8),
        _step('5', 'For Players: team name must match an existing team. Position: GK/DF/MF/FW.'),
        const SizedBox(height: 8),
        _step('6', 'Tap Upload and select your filled Excel file. Max 50 rows per batch.'),
      ]),
    );
  }

  Widget _step(String num, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: SportSphereColors.electricBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(num, style: const TextStyle(color: SportSphereColors.electricBlue, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: SportSphereColors.muted, fontSize: 12, height: 1.4))),
    ]);
  }
}
