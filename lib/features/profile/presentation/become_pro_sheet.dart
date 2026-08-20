import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../claims/data/claim_repository.dart';

class _ProRole {
  const _ProRole({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.claimBased,
  });
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool claimBased;
}

const _roles = <_ProRole>[
  _ProRole(id: 'player', label: 'Player', subtitle: 'Claim or register as a player', icon: Icons.sports_soccer_rounded, claimBased: true),
  _ProRole(id: 'coach', label: 'Coach', subtitle: 'Claim a coach profile or apply', icon: Icons.sports_rounded, claimBased: true),
  _ProRole(id: 'team', label: 'Team / Club', subtitle: 'Claim an official club page', icon: Icons.shield_rounded, claimBased: true),
  _ProRole(id: 'scout', label: 'Scout', subtitle: 'Talent identification', icon: Icons.travel_explore_rounded, claimBased: false),
  _ProRole(id: 'agent', label: 'Agent', subtitle: 'Player representation', icon: Icons.handshake_rounded, claimBased: false),
  _ProRole(id: 'journalist', label: 'Journalist', subtitle: 'Media & reporting', icon: Icons.newspaper_rounded, claimBased: false),
  _ProRole(id: 'creator', label: 'Creator', subtitle: 'Content & highlights', icon: Icons.videocam_rounded, claimBased: false),
  _ProRole(id: 'analyst', label: 'Analyst', subtitle: 'Tactics & data', icon: Icons.analytics_rounded, claimBased: false),
  _ProRole(id: 'commentator', label: 'Commentator', subtitle: 'Match voice', icon: Icons.mic_rounded, claimBased: false),
];

Future<void> showBecomeProSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF071422),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const BecomeProSheet(),
  );
}

class BecomeProSheet extends ConsumerStatefulWidget {
  const BecomeProSheet({super.key});

  @override
  ConsumerState<BecomeProSheet> createState() => _BecomeProSheetState();
}

class _BecomeProSheetState extends ConsumerState<BecomeProSheet> {
  _ProRole? _selected;
  final _notes = TextEditingController();
  final _entity = TextEditingController();
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    _notes.dispose();
    _entity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final role = _selected;
    if (role == null) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      setState(() => _message = 'Log in to become Pro.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final sb = Supabase.instance.client;
      final uid = sb.auth.currentUser!.id;

      if (role.claimBased) {
        final name = _entity.text.trim().isEmpty
            ? '${role.label} claim'
            : _entity.text.trim();
        await ClaimRepository().submitClaim(
          profileType: role.id,
          profileId:
              'request-${role.id}-${DateTime.now().millisecondsSinceEpoch}',
          profileName: name,
          evidenceNotes: _notes.text.trim().isEmpty
              ? 'Become Pro request as ${role.label}'
              : _notes.text.trim(),
        );
        if (mounted) {
          setState(() {
            _message =
                'Claim submitted for ${role.label}. Admin will review.';
            _saving = false;
          });
        }
        return;
      }

      await sb.from('profiles').update({
        'role': role.id,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      try {
        await sb.from('User').update({
          'role': role.id,
          'updatedAt': DateTime.now().toIso8601String(),
        }).eq('id', uid);
      } catch (_) {}

      await ref.read(authControllerProvider.notifier).refreshProfile();

      if (mounted) {
        setState(() {
          _message =
              'You are now a ${role.label} on SportSphere. Complete your profile next.';
          _saving = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Become Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start as a Fan. Upgrade to a professional role for tools, claims, and a pro identity on SportSphere.',
              style: TextStyle(color: Colors.white54, height: 1.4, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final r in _roles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: _selected?.id == r.id
                      ? SportSphereColors.electricBlue.withValues(alpha: 0.18)
                      : const Color(0xFF0C1A2A),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _selected = r),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            r.icon,
                            color: _selected?.id == r.id
                                ? SportSphereColors.electricBlue
                                : Colors.white70,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${r.subtitle} · ${r.claimBased ? 'needs approval' : 'instant'}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _selected?.id == r.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: _selected?.id == r.id
                                ? SportSphereColors.electricBlue
                                : Colors.white38,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_selected?.claimBased == true) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _entity,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Club / player / coach name',
                  labelStyle: TextStyle(color: Colors.white54),
                  hintText: 'e.g. Simba SC or Clatous Chama',
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'Why you need this role…',
                hintStyle: TextStyle(color: Colors.white30),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.startsWith('Claim') ||
                          _message!.startsWith('You are')
                      ? const Color(0xFF22C55E)
                      : Colors.orangeAccent,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving || _selected == null ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: SportSphereColors.electricBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _selected?.claimBased == true
                          ? 'Submit claim'
                          : 'Upgrade to ${_selected?.label ?? 'Pro'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
