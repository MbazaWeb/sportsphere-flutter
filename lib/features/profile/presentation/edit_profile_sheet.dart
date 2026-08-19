import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';

Future<void> showEditProfileSheet(BuildContext context, UserProfile user) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF071422),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => EditProfileSheet(user: user),
  );
}

class EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile user;
  const EditProfileSheet({super.key, required this.user});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _handle;
  late final TextEditingController _country;
  late final TextEditingController _bio;
  late DateTime _dob;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _first = TextEditingController(text: u.firstName);
    _last = TextEditingController(text: u.lastName);
    _handle = TextEditingController(text: u.handle);
    _country = TextEditingController(text: u.country);
    _bio = TextEditingController(text: u.bio);
    _dob = u.dob;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _handle.dispose();
    _country.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref.read(authControllerProvider.notifier).updateProfile(
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          handle: _handle.text.trim(),
          country: _country.text.trim(),
          dob: _dob,
          bio: _bio.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } else {
      final err = ref.read(authControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Could not update profile')),
      );
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
            const Text('Edit profile',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 16),
            _box('First name', _first),
            _box('Last name', _last),
            _box('Handle', _handle),
            _box('Country', _country),
            _box('Bio', _bio, maxLines: 3),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth', style: TextStyle(color: Colors.white70)),
              subtitle: Text(
                '${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob,
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dob = picked);
              },
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: SportSphereColors.electricBlue),
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: SportSphereColors.muted),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
