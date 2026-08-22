import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/grass_form.dart';
import '../../../core/utils/friendly_error.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/claim_repository.dart';

final claimRepositoryProvider = Provider((ref) => ClaimRepository());

Future<void> showClaimProfileSheet(
  BuildContext context, {
  required String profileType,
  required String profileId,
  required String profileName,
  String? teamId,
  String? playerId,
  String? coachId,
  String? leagueId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF071422),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ClaimProfileSheet(
      profileType: profileType,
      profileId: profileId,
      profileName: profileName,
      teamId: teamId,
      playerId: playerId,
      coachId: coachId,
      leagueId: leagueId,
    ),
  );
}

class ClaimProfileSheet extends ConsumerStatefulWidget {
  final String profileType;
  final String profileId;
  final String profileName;
  final String? teamId;
  final String? playerId;
  final String? coachId;
  final String? leagueId;

  const ClaimProfileSheet({
    super.key,
    required this.profileType,
    required this.profileId,
    required this.profileName,
    this.teamId,
    this.playerId,
    this.coachId,
    this.leagueId,
  });

  @override
  ConsumerState<ClaimProfileSheet> createState() => _ClaimProfileSheetState();
}

class _ClaimProfileSheetState extends ConsumerState<ClaimProfileSheet> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      _email.text = user.email;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider);
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log in to claim this profile')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(claimRepositoryProvider).submitClaim(
            profileType: widget.profileType,
            profileId: widget.profileId,
            profileName: widget.profileName,
            claimEmail: _email.text.trim(),
            claimPhone: _phone.text.trim(),
            evidenceNotes: _notes.text.trim(),
            teamId: widget.teamId,
            playerId: widget.playerId,
            coachId: widget.coachId,
            leagueId: widget.leagueId,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim request submitted. We will review it soon.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase().contains('duplicate')
          ? 'You already have a pending claim for this profile.'
          : friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GrassFormHeader(
              title: 'Claim ${widget.profileName}',
              subtitle:
                  'This ${widget.profileType} profile was created by SportSphere. '
                  'Submit a claim if you represent this account.',
              icon: Icons.flag_rounded,
            ),
            const SizedBox(height: 16),
            _field('Contact email', _email, TextInputType.emailAddress),
            _field('Phone / WhatsApp', _phone, TextInputType.phone),
            _field('Evidence / notes', _notes, TextInputType.multiline, maxLines: 4),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GrassSubmitButton(
                label: _saving ? 'Submitting…' : 'Submit claim request',
                loading: _saving,
                onPressed: _saving ? null : _submit,
                icon: Icons.verified_user_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c,
    TextInputType type, {
    int maxLines = 1,
  }) {
    return GrassTextField(
      controller: c,
      label: label,
      maxLines: maxLines,
      keyboardType: type,
    );
  }
}

/// Compact claim action used on profile headers.
class ClaimProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  const ClaimProfileButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GrassForm.greenLine.withValues(alpha: 0.7)),
          color: GrassForm.greenBright.withValues(alpha: 0.15),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 16, color: GrassForm.greenLine),
            SizedBox(width: 6),
            Text(
              'Claim profile',
              style: TextStyle(
                color: GrassForm.greenLine,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
