import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';

const _versionUrl = 'https://playifysport.fun/version.json';
const _apkUrl = 'https://playifysport.fun/download/Playify.apk';

class UpdateChecker {
  static Future<UpdateInfo?> check() async {
    if (kIsWeb) return null;
    try {
      final res = await http.get(
        Uri.parse(_versionUrl),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('[UpdateChecker] HTTP ${res.statusCode}');
        return null;
      }
      debugPrint('[UpdateChecker] version.json: ${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = data['version'] as String? ?? '';
      final notes = data['notes'] as String? ?? '';
      final mandatory = data['mandatory'] as bool? ?? false;
      final info = await PackageInfo.fromPlatform();
      debugPrint('[UpdateChecker] installed=${info.version} latest=$latest');
      if (_isNewer(latest, info.version)) {
        debugPrint('[UpdateChecker] UPDATE AVAILABLE');
        return UpdateInfo(current: info.version, latest: latest,
            notes: notes, mandatory: mandatory);
      }
      debugPrint('[UpdateChecker] already up to date');
      return null;
    } catch (e) {
      debugPrint('[UpdateChecker] error: $e');
      return null;
    }
  }

  static bool _isNewer(String latest, String current) {
    final l = _parts(latest);
    final c = _parts(current);
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static List<int> _parts(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

  static Future<void> launchDownload() async {
    final uri = Uri.parse(_apkUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class UpdateInfo {
  final String current;
  final String latest;
  final String notes;
  final bool mandatory;
  const UpdateInfo({required this.current, required this.latest,
      required this.notes, required this.mandatory});
}

// ── Banner shown at top of home screen ───────────────────────────────────────

class UpdateBanner extends StatefulWidget {
  final Widget child;
  const UpdateBanner({super.key, required this.child});
  @override State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  UpdateInfo? _update;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    // Check immediately then again after 3s
    _check();
    Future.delayed(const Duration(seconds: 3), _check);
  }

  Future<void> _check() async {
    final info = await UpdateChecker.check();
    if (mounted && info != null) setState(() => _update = info);
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    final show = update != null && !_dismissed;
    return Column(children: [
      if (show) _Banner(
        update: update!,
        onDismiss: update.mandatory ? null : () => setState(() => _dismissed = true),
        onUpdate: UpdateChecker.launchDownload,
      ),
      Expanded(child: widget.child),
    ]);
  }
}

class _Banner extends StatelessWidget {
  final UpdateInfo update;
  final VoidCallback? onDismiss;
  final VoidCallback onUpdate;
  const _Banner({required this.update, required this.onDismiss, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF168CFF).withValues(alpha: 0.97),
          const Color(0xFF0A5BB5).withValues(alpha: 0.97),
        ]),
      ),
      child: Row(children: [
        const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update available — v${update.latest}',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 13)),
            if (update.notes.isNotEmpty)
              Text(update.notes, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        )),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onUpdate,
          style: TextButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: SportSphereColors.electricBlue,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        if (onDismiss != null) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ],
      ]),
    );
  }
}
