// lib/core/update/app_update_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/vps_repository.dart';
import '../theme/colors.dart';

const _kBlue = PlayifyColors.electricBlue;

class AppUpdateService {
  static bool _checkedThisSession = false;
  static final _vps = const VpsRepository();

  static Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb) return;
    try {
      // Only check once per session (avoid repeated prompts)
      if (_checkedThisSession) return;
      _checkedThisSession = true;
      final res  = await _vps.get<Map<String,dynamic>>('/v1/app/version');
      final data = res.data; if (data == null) return;

      final serverCode  = (data['versionCode']    as int?)    ?? 0;
      final forceUpdate = (data['forceUpdate']     as bool?)   ?? false;
      final minCode     = (data['minVersionCode']  as int?)    ?? 0;
      final downloadUrl = (data['downloadUrl']     as String?) ?? '';
      final notes       = (data['releaseNotes']    as String?) ?? '';
      final serverVer   = (data['version']         as String?) ?? '';

      final info      = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(info.buildNumber) ?? 0;
      debugPrint('[Update] local=$localCode server=$serverCode version=${info.version}');
      if (serverCode <= localCode) return; // up to date

      final mustUpdate = forceUpdate || localCode < minCode;
      if (!context.mounted) return;
      _show(context, version: serverVer, url: downloadUrl,
            notes: notes, force: mustUpdate);
    } catch (_) {}
  }

  static void _show(BuildContext ctx, {
    required String version, required String url,
    required String notes,   required bool   force,
  }) {
    showDialog(
      context: ctx,
      barrierDismissible: !force,
      builder: (_) => WillPopScope(
        onWillPop: () async => !force,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D1F35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded, color: _kBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Update Available',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('Version $version',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ])),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (force) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_rounded, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('This update is required to continue.',
                      style: TextStyle(color: Colors.orange, fontSize: 12))),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            if (notes.isNotEmpty) ...[
              Text("What's new:", style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(notes, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            ],
          ]),
          actions: [
            if (!force)
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: Text('Later', style: TextStyle(color: Colors.white.withValues(alpha: 0.4)))),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download Update', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
