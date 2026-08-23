import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// BULK UPLOAD SCREEN
// Admin tool for uploading Fixtures, Teams, and Players via CSV.
// Excel files are also supported — user exports to CSV from Excel first.
// ══════════════════════════════════════════════════════════════════════════════

class BulkUploadScreen extends StatelessWidget {
  const BulkUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF071422),
        title: const Text('Bulk Upload',
            style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: SportSphereColors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _UploadSection(
            title: 'Upload Fixtures',
            subtitle: 'Bulk import match schedule from CSV',
            icon: Icons.sports_soccer_rounded,
            color: Color(0xFFE31B23),
            type: _UploadType.fixtures,
          ),
          SizedBox(height: 16),
          _UploadSection(
            title: 'Upload Teams',
            subtitle: 'Bulk import clubs and teams from CSV',
            icon: Icons.groups_rounded,
            color: SportSphereColors.electricBlue,
            type: _UploadType.teams,
          ),
          SizedBox(height: 16),
          _UploadSection(
            title: 'Upload Players',
            subtitle: 'Bulk import player profiles from CSV',
            icon: Icons.person_rounded,
            color: SportSphereColors.sportGreen,
            type: _UploadType.players,
          ),
        ],
      ),
    );
  }
}

enum _UploadType { fixtures, teams, players }

// ── Upload Section ────────────────────────────────────────────────────────────

class _UploadSection extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final _UploadType type;

  const _UploadSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.type,
  });

  @override
  State<_UploadSection> createState() => _UploadSectionState();
}

class _UploadSectionState extends State<_UploadSection> {
  bool _uploading = false;
  String? _result;
  bool _success = false;

  // ── CSV Templates ──────────────────────────────────────────────────────────

  String get _templateCsv {
    switch (widget.type) {
      case _UploadType.fixtures:
        return [
          'homeTeam,awayTeam,league,competition,venue,kickoff,status,homeScore,awayScore,sport',
          'Simba SC,Young Africans,NBC Tanzania Premier League,NBC Tanzania PL,National Stadium,2026-09-01T15:00:00,scheduled,,,football',
          'JKT Tanzania,TRA United,NBC Tanzania Premier League,NBC Tanzania PL,Uhuru Stadium,2026-09-02T16:00:00,finished,2,1,football',
          'Azam FC,Mbeya City,NBC Tanzania Premier League,NBC Tanzania PL,Azam Complex,2026-09-03T15:00:00,scheduled,,,football',
        ].join('\n');
      case _UploadType.teams:
        return [
          'name,shortName,city,country,sport,league,founded,primaryColor,logoUrl',
          'Simba SC,SIM,Dar es Salaam,Tanzania,football,NBC Tanzania Premier League,1936,#E31B23,',
          'Young Africans,YAN,Dar es Salaam,Tanzania,football,NBC Tanzania Premier League,1935,#FFD700,',
          'JKT Tanzania,JKT,Dar es Salaam,Tanzania,football,NBC Tanzania Premier League,1974,#009DFF,',
        ].join('\n');
      case _UploadType.players:
        return [
          'firstName,lastName,team,position,nationality,dateOfBirth,jerseyNumber,sport',
          'Clatous,Chama,Simba SC,Forward,Zambia,1992-03-20,11,football',
          'John,Bocco,Young Africans,Midfielder,Tanzania,1990-01-15,10,football',
          'Ali,Kingu,JKT Tanzania,Goalkeeper,Tanzania,1988-06-05,1,football',
        ].join('\n');
    }
  }

  String get _templateFilename {
    switch (widget.type) {
      case _UploadType.fixtures:
        return 'fixtures_template.csv';
      case _UploadType.teams:
        return 'teams_template.csv';
      case _UploadType.players:
        return 'players_template.csv';
    }
  }

  // ── Parse CSV ──────────────────────────────────────────────────────────────

  List<Map<String, String>> _parseCsv(String csv) {
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return [];
    final headers = _splitCsvLine(lines[0]);
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final values = _splitCsvLine(line);
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i].trim()] = i < values.length ? values[i].trim() : '';
      }
      rows.add(row);
    }
    return rows;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    var inQuotes = false;
    var current = StringBuffer();
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString());
    return result;
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    setState(() { _uploading = true; _result = null; });

    try {
      final picked = await FilePicker().pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        setState(() => _uploading = false);
        return;
      }

      final bytes = picked.files.first.bytes;
      if (bytes == null) throw Exception('Could not read file');
      final csv = utf8.decode(bytes);
      final rows = _parseCsv(csv);
      if (rows.isEmpty) throw Exception('No data rows found. Check CSV format.');

      final sb = Supabase.instance.client;
      int inserted = 0;
      int skipped = 0;

      switch (widget.type) {
        case _UploadType.fixtures:
          for (final row in rows) {
            final home = row['homeTeam'] ?? '';
            final away = row['awayTeam'] ?? '';
            if (home.isEmpty || away.isEmpty) { skipped++; continue; }
            try {
              await sb.from('Match').upsert({
                'homeTeam':    home,
                'awayTeam':    away,
                'league':      row['league'] ?? '',
                'competition': row['competition'] ?? row['league'] ?? '',
                'venue':       row['venue'] ?? '',
                'kickoff':     row['kickoff']?.isNotEmpty == true ? row['kickoff'] : null,
                'status':      row['status']?.isNotEmpty == true ? row['status'] : 'scheduled',
                'homeScore':   int.tryParse(row['homeScore'] ?? ''),
                'awayScore':   int.tryParse(row['awayScore'] ?? ''),
                'sport':       row['sport'] ?? 'football',
              }, onConflict: 'homeTeam,awayTeam,kickoff');
              inserted++;
            } catch (_) { skipped++; }
          }

        case _UploadType.teams:
          for (final row in rows) {
            final name = row['name'] ?? '';
            if (name.isEmpty) { skipped++; continue; }
            try {
              await sb.from('Team').upsert({
                'name':         name,
                'shortName':    row['shortName'] ?? name.substring(0, name.length.clamp(0, 3)).toUpperCase(),
                'city':         row['city'] ?? '',
                'country':      row['country'] ?? 'Tanzania',
                'sport_slug':   row['sport'] ?? 'football',
                'league':       row['league'] ?? '',
                'founded':      int.tryParse(row['founded'] ?? ''),
                'primaryColor': row['primaryColor'] ?? '#009DFF',
                'logoUrl':      row['logoUrl']?.isNotEmpty == true ? row['logoUrl'] : null,
                'isActive':     true,
                'handle':       name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
              }, onConflict: 'name');
              inserted++;
            } catch (_) { skipped++; }
          }

        case _UploadType.players:
          for (final row in rows) {
            final first = row['firstName'] ?? '';
            final last = row['lastName'] ?? '';
            if (first.isEmpty && last.isEmpty) { skipped++; continue; }
            try {
              // Resolve teamId from team name
              String? teamId;
              final teamName = row['team'] ?? '';
              if (teamName.isNotEmpty) {
                final t = await sb.from('Team').select('id').ilike('name', teamName).maybeSingle();
                teamId = t?['id']?.toString();
              }
              await sb.from('Player').upsert({
                'firstName':   first,
                'lastName':    last,
                'teamId':      teamId,
                'teamName':    teamName,
                'position':    row['position'] ?? '',
                'nationality': row['nationality'] ?? '',
                'dateOfBirth': row['dateOfBirth']?.isNotEmpty == true ? row['dateOfBirth'] : null,
                'jerseyNumber': int.tryParse(row['jerseyNumber'] ?? ''),
                'sport':       row['sport'] ?? 'football',
                'isActive':    true,
              }, onConflict: 'firstName,lastName,teamId');
              inserted++;
            } catch (_) { skipped++; }
          }
      }

      setState(() {
        _success = true;
        _result = '✓ Uploaded $inserted rows${skipped > 0 ? ' ($skipped skipped)' : ''}';
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _success = false;
        _result = 'Error: $e';
        _uploading = false;
      });
    }
  }

  void _downloadTemplate() {
    // Copy template to clipboard (mobile-friendly alternative to file download)
    Clipboard.setData(ClipboardData(text: _templateCsv));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_templateFilename copied to clipboard — paste into Excel/Sheets'),
        backgroundColor: widget.color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(
                          color: SportSphereColors.white,
                          fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(widget.subtitle, style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF0F1F35)),

          // ── Actions ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sample template download
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.color,
                    side: BorderSide(color: widget.color.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download Sample Template',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),

                // Upload button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.color,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _uploading ? null : _pickAndUpload,
                    icon: _uploading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(
                      _uploading ? 'Uploading…' : 'Upload CSV File',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),

                // Result message
                if (_result != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_success ? SportSphereColors.sportGreen : const Color(0xFFE31B23))
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_success ? SportSphereColors.sportGreen : const Color(0xFFE31B23))
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(_result!,
                        style: TextStyle(
                          color: _success ? SportSphereColors.sportGreen : const Color(0xFFE31B23),
                          fontSize: 13, fontWeight: FontWeight.w600,
                        )),
                  ),
                ],

                // Instructions
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('How to use:', style: TextStyle(
                          color: SportSphereColors.muted, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '1. Tap "Download Sample Template" to copy CSV format\n'
                        '2. Paste into Excel or Google Sheets and fill your data\n'
                        '3. Export/Save as CSV (.csv)\n'
                        '4. Tap "Upload CSV File" and select your file',
                        style: TextStyle(
                          color: SportSphereColors.muted.withValues(alpha: 0.7),
                          fontSize: 11, height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
