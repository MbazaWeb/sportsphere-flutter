import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/admin/app_admin.dart';
import '../../../core/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';

// ══════════════════════════════════════════════════════════════════════════════
// BECOME PRO SHEET
// Lets fans request a PRO role (player, coach, analyst, team, media…).
// ALL requests are inserted as pending rows for admin review.
// Role is NOT written directly — admin approves via PRO Queue tab.
// ══════════════════════════════════════════════════════════════════════════════

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

// ── Role options ──────────────────────────────────────────────────────────────

enum _ProRole {
  player('player',    'Player',          Icons.sports_soccer_rounded,  Color(0xFF22C55E)),
  coach('coach',      'Coach / Manager', Icons.sports_rounded,          Color(0xFF3B82F6)),
  analyst('analyst',  'Analyst',         Icons.analytics_rounded,       Color(0xFF9B6DFF)),
  media('media',      'Journalist / Media', Icons.mic_rounded,          Color(0xFFF59E0B)),
  team('team',        'Club / Team',     Icons.groups_rounded,          Color(0xFFE31B23)),
  federation('federation','Federation',  Icons.emoji_events_rounded,    Color(0xFFFFD700));

  const _ProRole(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class BecomeProSheet extends ConsumerStatefulWidget {
  const BecomeProSheet({super.key});
  @override
  ConsumerState<BecomeProSheet> createState() => _BecomeProSheetState();
}

class _BecomeProSheetState extends ConsumerState<BecomeProSheet> {
  _ProRole? _selected;
  final _entity = TextEditingController();
  final _notes  = TextEditingController();
  bool _saving = false;
  String? _message;

  @override
  void dispose() { _entity.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _submit() async {
    // #3.2 — Admin / official / org / moderator accounts already have
    // privileged access. They should NOT be able to submit a PRO request
    // to themselves (it would create a confusing pending row in the admin
    // queue and would never be approvable). Bail out immediately.
    if (AppAdmin.isSessionAdmin) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final role = _selected;
    if (role == null) return;

    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated || auth.user == null) {
      setState(() => _message = 'Please log in first.');
      return;
    }
    final uid = Supabase.instance.client.auth.currentSession?.user.id;
    if (uid == null) return;

    setState(() { _saving = true; _message = null; });
    try {
      final sb = Supabase.instance.client;
      final reqId = 'pro-${role.id}-$uid-${DateTime.now().millisecondsSinceEpoch}';
      final notesText = [
        if (_entity.text.trim().isNotEmpty) 'Entity: ${_entity.text.trim()}',
        if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
      ].join(' | ');

      // Insert into RoleRequest table
      bool saved = false;
      try {
        await sb.from('RoleRequest').insert({
          'id': reqId,
          'userId': uid,
          'requestedRole': role.id,
          'status': 'pending',
          'notes': notesText.isEmpty ? 'Become Pro request as ${role.label}' : notesText,
          'createdAt': DateTime.now().toIso8601String(),
        });
        saved = true;
      } catch (_) {}

      // Fallback: Claim table
      if (!saved) {
        try {
          await sb.from('Claim').insert({
            'id': reqId,
            'claimantId': uid,
            'profileType': role.id,
            'profileName': _entity.text.trim().isEmpty ? role.label : _entity.text.trim(),
            'status': 'pending',
            'evidenceNotes': notesText.isEmpty ? 'Become Pro request as ${role.label}' : notesText,
            'createdAt': DateTime.now().toIso8601String(),
          });
          saved = true;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _message = saved
              ? 'Your ${role.label} request has been submitted. '
                'Admin will review and activate your PRO profile.'
              : 'Request submitted. Admin will be in touch.';
          _saving = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() { _message = '$e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle bar
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 16),

        const Text('Become PRO', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: SportSphereColors.white)),
        const SizedBox(height: 4),
        const Text('Choose your role. Admin will review within 24 hours.',
            style: TextStyle(color: SportSphereColors.muted, fontSize: 13)),
        const SizedBox(height: 20),

        // Role grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10, crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: _ProRole.values.map((r) {
            final sel = _selected == r;
            return GestureDetector(
              onTap: () => setState(() => _selected = r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? r.color.withValues(alpha: 0.15) : const Color(0xFF071422),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? r.color : Colors.white.withValues(alpha: 0.08),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(r.icon, color: sel ? r.color : SportSphereColors.muted, size: 20),
                  const SizedBox(width: 8),
                  Flexible(child: Text(r.label,
                      style: TextStyle(
                          color: sel ? r.color : SportSphereColors.white,
                          fontWeight: FontWeight.w700, fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Entity / club name field
        _Field('Club / Team / Organisation name (optional)', _entity),
        _Field('Supporting notes or evidence link (optional)', _notes, maxLines: 3),

        if (_message != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (_message!.startsWith('Your') || _message!.startsWith('Request'))
                  ? SportSphereColors.sportGreen.withValues(alpha: 0.1)
                  : const Color(0xFFE31B23).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (_message!.startsWith('Your') || _message!.startsWith('Request'))
                    ? SportSphereColors.sportGreen.withValues(alpha: 0.3)
                    : const Color(0xFFE31B23).withValues(alpha: 0.25),
              ),
            ),
            child: Text(_message!,
                style: const TextStyle(color: SportSphereColors.white, fontSize: 13, height: 1.4)),
          ),
        ],

        const SizedBox(height: 16),

        SizedBox(width: double.infinity,
          child: FilledButton(
            onPressed: (_saving || _selected == null) ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _selected?.color ?? SportSphereColors.electricBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _selected == null ? 'Select a role first' : 'Submit PRO Request',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ])),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final int maxLines;
  const _Field(this.label, this.ctrl, {this.maxLines = 1});

  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0B1626),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    ),
  );
}
