import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/social_repository.dart';
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
  late String _theme;
  String? _avatarUrl;
  String? _coverUrl;
  bool _saving = false;
  final _social = SocialRepository();
  final _picker = ImagePicker();

  static const _themes = [
    '#168CFF',
    '#E31B23',
    '#22C55E',
    '#F59E0B',
    '#A855F7',
    '#00C2A8',
  ];

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
    _theme = u.themeColor;
    _avatarUrl = u.avatarUrl;
    _coverUrl = u.coverUrl;
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

  Future<void> _pick(bool cover) async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _saving = true);
    try {
      final url = await _social.uploadPickedFile(
        bucket: cover ? 'covers' : 'avatars',
        folder: cover ? 'covers' : 'avatars',
        file: file,
      );
      setState(() {
        if (cover) {
          _coverUrl = url;
        } else {
          _avatarUrl = url;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          avatarUrl: _avatarUrl,
          coverUrl: _coverUrl,
          themeColor: _theme,
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
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Edit profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _pick(false),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFF102033),
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                        ? const Icon(Icons.camera_alt_outlined, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(true),
                    child: Text(_coverUrl == null ? 'Add cover photo' : 'Change cover'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Theme color', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (final c in _themes)
                  GestureDetector(
                    onTap: () => setState(() => _theme = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _theme == c ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _field('First name', _first),
            _field('Last name', _last),
            _field('Handle', _handle),
            _field('Country', _country),
            _field('Bio', _bio, maxLines: 3),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth', style: TextStyle(color: Colors.white70)),
              subtitle: Text('${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dob,
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _dob = d);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: SportSphereColors.electricBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF0B1626),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
