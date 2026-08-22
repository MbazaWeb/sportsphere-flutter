import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/social_repository.dart';
import '../../../core/data/world_countries.dart';
import '../../../core/taxonomy/sport_catalog.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/grass_form.dart';
import '../../../core/widgets/country_picker_field.dart';
import '../../../core/utils/form_validators.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/utils/friendly_error.dart';

Future<void> showEditProfileSheet(BuildContext context, UserProfile user) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
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
  String? _selectedCountryName;
  late final TextEditingController _bio;
  late DateTime _dob;
  late String _theme;
  String? _avatarUrl;
  String? _coverUrl;
  bool _saving = false;
  final Set<String> _sports = {};
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
    // Match stored country to the seeded list
    if (u.country.isNotEmpty) {
      final match = kWorldCountries.where(
        (c) => c.name.toLowerCase() == u.country.toLowerCase() || c.code.toLowerCase() == u.country.toLowerCase(),
      );
      if (match.isNotEmpty) {
        _selectedCountryName = match.first.name;
      } else {
        _selectedCountryName = u.country;
      }
    }
    _bio = TextEditingController(text: u.bio);
    _dob = u.dob;
    _theme = u.themeColor;
    _avatarUrl = u.avatarUrl;
    _coverUrl = u.coverUrl;
    _social.mySportSlugs().then((s) {
      if (mounted) setState(() => _sports.addAll(s));
    });
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final fn = FormValidators.required(_first.text, field: 'First name');
    final ln = FormValidators.required(_last.text, field: 'Last name');
    final h = FormValidators.handle(_handle.text);
    if (fn != null || ln != null || h != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fn ?? ln ?? h ?? 'Check the form')),
      );
      return;
    }
    if (_selectedCountryName == null || _selectedCountryName!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your country')),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await ref.read(authControllerProvider.notifier).updateProfile({
          'first_name': _first.text.trim(),
          'last_name': _last.text.trim(),
          'handle': _handle.text.trim(),
          'country': _selectedCountryName ?? _country.text.trim(),
          'dob': _dob.toIso8601String(),
          'bio': _bio.text.trim(),
          'avatar_url': _avatarUrl,
          'cover_url': _coverUrl,
          'theme_color': _theme,
        });
    if (!mounted) return;
    setState(() => _saving = false);
    try {
      if (_sports.isNotEmpty) {
        await _social.setMySports(_sports.toList(), primary: _sports.first);
      }
    } catch (_) {}
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
            const GrassFormHeader(
              title: 'Edit profile',
              subtitle: 'Update your profile on Playify',
              icon: Icons.person_rounded,
            ),
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
                        ? ClipOval(child: Image.asset(
                            'assets/images/Playify_logo.png',
                            width: 68, height: 68, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.camera_alt_outlined, color: Colors.white70),
                          ))
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
            const Text('My sports', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in kAllSports)
                  FilterChip(
                    label: Text(sportLabel(s)),
                    selected: _sports.contains(s),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _sports.add(s);
                      } else {
                        _sports.remove(s);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
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
            // Admin: lock name and handle fields
            if (widget.user.email != 'sportsphere.app@sportsphere.com') ...[
              GrassTextField(
                controller: _first,
                label: 'First name *',
                validator: (v) => FormValidators.required(v, field: 'First name'),
              ),
              GrassTextField(
                controller: _last,
                label: 'Last name *',
                validator: (v) => FormValidators.required(v, field: 'Last name'),
              ),
              GrassTextField(
                controller: _handle,
                label: 'Handle *',
                validator: FormValidators.handle,
              ),
              CountryPickerField(
                label: 'Country *',
                value: _selectedCountryName,
                onChanged: (v) => setState(() {
                  _selectedCountryName = v;
                  _country.text = v;
                }),
              ),
            ],
            GrassTextField(
              controller: _bio,
              label: 'Bio',
              maxLines: 3,
            ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: () => showChangePasswordDialog(context, ref),
                    child: const Text('Change password'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: GrassForm.greenBright,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countryField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showCountryPicker(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Country',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF0B1626),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54),
          ),
          child: Text(
            _selectedCountryName ?? 'Select country',
            style: TextStyle(
              color: _selectedCountryName != null ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GrassForm.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search countries...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0B1626),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: searchCountries(searchCtrl.text).length,
                  itemBuilder: (_, i) {
                    final c = searchCountries(searchCtrl.text)[i];
                    final selected = _selectedCountryName == c.name;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCountryName = c.name;
                          _country.text = c.name;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                        decoration: BoxDecoration(
                          color: selected ? SportSphereColors.electricBlue.withValues(alpha: 0.12) : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${c.name}  ',
                              style: TextStyle(
                                color: selected ? SportSphereColors.electricBlue : Colors.white,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              c.code,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            if (selected) ...[
                              const Spacer(),
                              const Icon(Icons.check_circle_rounded, color: SportSphereColors.electricBlue, size: 18),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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

// Change-password dialog used from profile settings.
Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref) async {
  final a = TextEditingController();
  final b = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: const Color(0xFF0C1A2A),
      title: const Text('Change password', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: a,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'New password',
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
          TextField(
            controller: b,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Update')),
      ],
    ),
  );
  if (ok != true) return;
  if (a.text != b.text) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
    }
    return;
  }
  final updated = await ref
      .read(authControllerProvider.notifier)
      .changePassword('', a.text);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? 'Password updated' : 'Unable to update password')),
    );
  }
}
