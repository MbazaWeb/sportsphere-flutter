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
import '../../admin/admin_repository.dart';

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

// ══════════════════════════════════════════════════════════════════════════════
// ENTITY EDIT SHEET  —  admin-only editor for Team / Competition / Player / Coach
// (Issue #5.7 — pre-fills fields from a data map, calls AdminRepository.updateX)
// ══════════════════════════════════════════════════════════════════════════════

/// Supported entity types for [EntityEditSheet].
enum EntityType { team, competition, player, coach }

extension EntityTypeX on EntityType {
  String get label {
    switch (this) {
      case EntityType.team: return 'Team';
      case EntityType.competition: return 'Competition';
      case EntityType.player: return 'Player';
      case EntityType.coach: return 'Coach';
    }
  }

  IconData get icon {
    switch (this) {
      case EntityType.team: return Icons.groups_rounded;
      case EntityType.competition: return Icons.emoji_events_rounded;
      case EntityType.player: return Icons.person_rounded;
      case EntityType.coach: return Icons.sports_rounded;
    }
  }
}

/// Convenience helper used by profile screens and admin dashboard.
/// Pops the sheet and returns `true` when the entity was saved successfully.
Future<bool> showEntityEditSheet(
  BuildContext context, {
  required EntityType entityType,
  required String entityId,
  required Map<String, dynamic> initialData,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => EntityEditSheet(
      entityType: entityType,
      entityId: entityId,
      initialData: initialData,
    ),
  );
  return saved ?? false;
}

class EntityEditSheet extends StatefulWidget {
  final EntityType entityType;
  final String entityId;
  final Map<String, dynamic> initialData;

  const EntityEditSheet({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.initialData,
  });

  @override
  State<EntityEditSheet> createState() => _EntityEditSheetState();
}

class _EntityEditSheetState extends State<EntityEditSheet> {
  final _repo = AdminRepository();
  final _social = SocialRepository();
  final _picker = ImagePicker();
  bool _saving = false;

  // Controllers per field — only the ones needed by the active entity type
  // are populated, the rest stay empty.
  late final TextEditingController _name;
  late final TextEditingController _shortName;
  late final TextEditingController _logoUrl;
  late final TextEditingController _primaryColor;
  late final TextEditingController _country;
  late final TextEditingController _venue;
  late final TextEditingController _season;
  late final TextEditingController _sportSlug;
  late final TextEditingController _position;
  late final TextEditingController _nationality;
  late final TextEditingController _photoUrl;
  late final TextEditingController _shirtNumber;
  late final TextEditingController _role;
  late final TextEditingController _teamId;

  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _name = TextEditingController(text: _asString(d['name']));
    _shortName = TextEditingController(text: _asString(d['shortName']));
    _logoUrl = TextEditingController(text: _asString(d['logoUrl'] ?? d['logo_url']));
    _primaryColor = TextEditingController(
        text: _asString(d['primaryColor']));
    _country = TextEditingController(text: _asString(d['country']));
    _venue = TextEditingController(text: _asString(d['venue']));
    _season = TextEditingController(text: _asString(d['season']));
    _sportSlug = TextEditingController(text: _asString(d['sportSlug'] ?? d['sport_slug']));
    _position = TextEditingController(text: _asString(d['position']));
    _nationality = TextEditingController(text: _asString(d['nationality']));
    _photoUrl = TextEditingController(text: _asString(d['photoUrl'] ?? d['photo_url']));
    _shirtNumber = TextEditingController(text: _asString(d['shirtNumber']));
    _role = TextEditingController(text: _asString(d['role']));
    _teamId = TextEditingController(text: _asString(d['teamId'] ?? d['team_id']));
    final dobRaw = d['dateOfBirth'] ?? d['date_of_birth'];
    if (dobRaw is String && dobRaw.isNotEmpty) {
      _dateOfBirth = DateTime.tryParse(dobRaw);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    _logoUrl.dispose();
    _primaryColor.dispose();
    _country.dispose();
    _venue.dispose();
    _season.dispose();
    _sportSlug.dispose();
    _position.dispose();
    _nationality.dispose();
    _photoUrl.dispose();
    _shirtNumber.dispose();
    _role.dispose();
    _teamId.dispose();
    super.dispose();
  }

  String _asString(dynamic v) => v == null ? '' : v.toString();

  Future<void> _pickImage(TextEditingController target, {String folder = 'admin'}) async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f == null) return;
    setState(() => _saving = true);
    try {
      final url = await _social.uploadPickedFile(bucket: 'media', folder: folder, file: f);
      setState(() => target.text = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      switch (widget.entityType) {
        case EntityType.team:
          await _repo.updateTeam(
            id: widget.entityId,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            shortName: _shortName.text.trim().isEmpty ? null : _shortName.text.trim(),
            logoUrl: _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
            primaryColor: _primaryColor.text.trim().isEmpty ? null : _primaryColor.text.trim(),
            country: _country.text.trim().isEmpty ? null : _country.text.trim(),
            venue: _venue.text.trim().isEmpty ? null : _venue.text.trim(),
            leagueId: _teamId.text.trim().isEmpty ? null : _teamId.text.trim(),
          );
          break;
        case EntityType.competition:
          await _repo.updateCompetition(
            id: widget.entityId,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            logoUrl: _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
            season: _season.text.trim().isEmpty ? null : _season.text.trim(),
            sportSlug: _sportSlug.text.trim().isEmpty ? null : _sportSlug.text.trim(),
          );
          break;
        case EntityType.player:
          await _repo.updatePlayer(
            id: widget.entityId,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            position: _position.text.trim().isEmpty ? null : _position.text.trim(),
            nationality: _nationality.text.trim().isEmpty ? null : _nationality.text.trim(),
            dateOfBirth: _dateOfBirth,
            photoUrl: _photoUrl.text.trim().isEmpty ? null : _photoUrl.text.trim(),
            teamId: _teamId.text.trim().isEmpty ? null : _teamId.text.trim(),
            shirtNumber: int.tryParse(_shirtNumber.text.trim()),
          );
          break;
        case EntityType.coach:
          await _repo.updateCoach(
            id: widget.entityId,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            nationality: _nationality.text.trim().isEmpty ? null : _nationality.text.trim(),
            role: _role.text.trim().isEmpty ? null : _role.text.trim(),
            teamId: _teamId.text.trim().isEmpty ? null : _teamId.text.trim(),
            photoUrl: _photoUrl.text.trim().isEmpty ? null : _photoUrl.text.trim(),
          );
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.entityType.label} updated')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
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
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GrassFormHeader(
              title: 'Edit ${widget.entityType.label}',
              subtitle: 'Admin-only — update entity record',
              icon: widget.entityType.icon,
            ),
            const SizedBox(height: 14),
            ..._fieldsForType(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: GrassForm.greenBright,
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

  List<Widget> _fieldsForType() {
    switch (widget.entityType) {
      case EntityType.team:
        return [
          GrassTextField(controller: _name, label: 'Name *'),
          GrassTextField(controller: _shortName, label: 'Short name (e.g. SIM, YAN)'),
          GrassTextField(controller: _primaryColor, label: 'Primary color (e.g. #E31B23)'),
          GrassTextField(controller: _country, label: 'Country'),
          GrassTextField(controller: _venue, label: 'Stadium / Venue'),
          GrassTextField(controller: _teamId, label: 'League / Competition ID'),
          _UploadRow(controller: _logoUrl, label: 'Upload logo', onTap: () => _pickImage(_logoUrl, folder: 'logos')),
        ];

      case EntityType.competition:
        return [
          GrassTextField(controller: _name, label: 'Competition Name *'),
          GrassTextField(controller: _season, label: 'Season (e.g. 2026/27)'),
          GrassTextField(controller: _sportSlug, label: 'Sport slug (e.g. football)'),
          _UploadRow(controller: _logoUrl, label: 'Upload logo', onTap: () => _pickImage(_logoUrl, folder: 'logos')),
        ];

      case EntityType.player:
        return [
          GrassTextField(controller: _name, label: 'Display name *'),
          GrassTextField(controller: _position, label: 'Position (e.g. Forward)'),
          GrassTextField(controller: _nationality, label: 'Nationality'),
          GrassTextField(controller: _shirtNumber, label: 'Shirt #', keyboardType: TextInputType.number),
          GrassTextField(controller: _teamId, label: 'Team ID'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _dateOfBirth == null
                  ? 'Date of birth (optional)'
                  : 'DOB: ${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: _dateOfBirth == null ? SportSphereColors.muted : SportSphereColors.white,
                fontSize: 13,
              ),
            ),
            trailing: const Icon(Icons.calendar_today_rounded,
                color: SportSphereColors.electricBlue, size: 18),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(1998, 1, 1),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _dateOfBirth = d);
            },
          ),
          _UploadRow(controller: _photoUrl, label: 'Upload photo', onTap: () => _pickImage(_photoUrl, folder: 'players')),
        ];

      case EntityType.coach:
        return [
          GrassTextField(controller: _name, label: 'Display name *'),
          GrassTextField(controller: _nationality, label: 'Nationality'),
          GrassTextField(controller: _role, label: 'Role (e.g. head_coach)'),
          GrassTextField(controller: _teamId, label: 'Team ID'),
          _UploadRow(controller: _photoUrl, label: 'Upload photo', onTap: () => _pickImage(_photoUrl, folder: 'coaches')),
        ];
    }
  }
}

/// Small helper row that previews a stored URL and offers an upload button.
class _UploadRow extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onTap;
  const _UploadRow({
    required this.controller,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: GrassTextField(controller: controller, label: 'Media URL'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.upload_rounded, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
