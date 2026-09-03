// lib/features/auth/presentation/pages/register_screen.dart
// Book-style 3-step registration with progress bar.
//
// Step 1 — Account details (name, email, handle, password)
// Step 2 — Profile setup (avatar, country, DOB)
// Step 3 — Fan setup (sports chips, favourite teams)
//           → tapping Done registers + navigates to /home

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/data/vps_repository.dart';
import '../../../../core/theme/colors.dart';
import '../auth_controller.dart';

// ── Colours ────────────────────────────────────────────────────────────────────
const _kBlue  = PlayifyColors.electricBlue;
const _kGreen = Color(0xFF4CAF50);

// ── Country list ───────────────────────────────────────────────────────────────
const _kCountries = [
  'Tanzania','Kenya','Uganda','Rwanda','Ethiopia','Nigeria','Ghana','South Africa',
  'Egypt','Morocco','Senegal','Ivory Coast','Cameroon','Algeria','Tunisia',
  'Zambia','Zimbabwe','Mozambique','Madagascar','Angola','DR Congo',
  'United Kingdom','United States','Germany','France','Spain','Italy',
  'Portugal','Netherlands','Belgium','Sweden','Norway','Denmark',
  'Brazil','Argentina','Colombia','Mexico','Japan','South Korea',
  'China','India','Australia','Canada','United Arab Emirates','Qatar',
];

// ── Main screen ────────────────────────────────────────────────────────────────
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {

  // Step controller
  final _pageCtrl  = PageController();
  int _step = 0; // 0=account 1=profile 2=fan
  static const _totalSteps = 3;

  // Form keys
  final _step1Key = GlobalKey<FormState>();

  // Step 1 — Account
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _handleCtrl    = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  bool _showPass = false, _showConfirm = false;

  // Step 2 — Profile
  String? _country;
  DateTime? _dob;
  Uint8List? _avatarBytes;
  String? _avatarDataUri;

  // Step 3 — Fan
  final Set<String> _selectedSports = {};
  final Set<String> _selectedTeamIds = {};
  final Set<String> _selectedTeamNames = {};
  List<Map<String,dynamic>> _sports = [];
  List<Map<String,dynamic>> _teams  = [];
  bool _loadingTeams = true;
  final _teamSearch = TextEditingController();
  final _phoneCtrl  = TextEditingController();

  late final AnimationController _progressCtrl;
  late final Animation<double> _progressAnim;
  double _progressTarget = 0;

  static const _vps = VpsRepository();

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _progressAnim = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut);
    _loadFanData();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pageCtrl.dispose();
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _emailCtrl.dispose(); _handleCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    _teamSearch.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFanData() async {
    try {
      final res = await _vps.get<Map<String,dynamic>>('/v1/social/sports');
      final rows = (res.data?['sports'] as List? ?? []).cast<Map<String,dynamic>>();
      if (mounted) setState(() => _sports = rows.isNotEmpty ? rows : _defaultSports());
    } catch (_) {
      if (mounted) setState(() => _sports = _defaultSports());
    }
    try {
      final res = await _vps.get<Map<String,dynamic>>('/v1/admin/teams', query: {'limit': '200'});
      final rows = (res.data?['teams'] as List? ?? []).cast<Map<String,dynamic>>();
      if (mounted) setState(() { _teams = rows; _loadingTeams = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTeams = false);
    }
  }

  List<Map<String,dynamic>> _defaultSports() => [
    {'id':'sport-football',  'name':'Football',   'icon':'⚽','slug':'football'},
    {'id':'sport-basketball','name':'Basketball', 'icon':'🏀','slug':'basketball'},
    {'id':'sport-athletics', 'name':'Athletics',  'icon':'🏃','slug':'athletics'},
    {'id':'sport-tennis',    'name':'Tennis',     'icon':'🎾','slug':'tennis'},
    {'id':'sport-volleyball','name':'Volleyball', 'icon':'🏐','slug':'volleyball'},
    {'id':'sport-cricket',   'name':'Cricket',    'icon':'🏏','slug':'cricket'},
    {'id':'sport-boxing',    'name':'Boxing',     'icon':'🥊','slug':'boxing'},
    {'id':'sport-mma',       'name':'MMA',        'icon':'🥋','slug':'mma'},
  ];

  void _animateProgress(int step) {
    _progressTarget = (step + 1) / _totalSteps;
    _progressCtrl.animateTo(_progressTarget);
  }

  void _nextStep() {
    if (_step == 0) {
      if (!(_step1Key.currentState?.validate() ?? false)) return;
    }
    if (_step == 1) {
      if (_country == null) { _snack('Please select your country'); return; }
      if (_dob == null)     { _snack('Please select your date of birth'); return; }
    }
    HapticFeedback.lightImpact();
    final next = _step + 1;
    setState(() => _step = next);
    _animateProgress(next);
    _pageCtrl.animateToPage(next,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _prevStep() {
    if (_step == 0) { context.pop(); return; }
    HapticFeedback.selectionClick();
    final prev = _step - 1;
    setState(() => _step = prev);
    _animateProgress(prev);
    _pageCtrl.animateToPage(prev,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final file   = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ext   = file.name.split('.').last.toLowerCase();
      final mime  = ext == 'png' ? 'image/png' : 'image/jpeg';
      if (mounted) {
        setState(() {
        _avatarBytes   = bytes;
        _avatarDataUri = 'data:$mime;base64,${base64Encode(bytes)}';
      });
      }
    } catch (e) {
      _snack('Could not pick photo');
    }
  }

  Future<void> _pickCountry() async {
    final result = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _CountryPicker(selected: _country, onSelect: (c) => Navigator.pop(context, c)),
    );
    if (result != null) setState(() => _country = result);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18),
      firstDate: DateTime(1920), lastDate: DateTime(now.year - 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: _kBlue, surface: Color(0xFF0D1F35)),
        ), child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    // Save sports (best-effort)
    if (_selectedSports.isNotEmpty) {
      try {
        await _vps.post<void>('/v1/social/my-sports', data: {
          'slugs': _selectedSports.toList(),
          'primary': _selectedSports.first,
        });
      } catch (_) {}
    }

    final ok = await ref.read(authControllerProvider.notifier).register(
      firstName:  _firstNameCtrl.text.trim(),
      lastName:   _lastNameCtrl.text.trim(),
      email:      _emailCtrl.text.trim(),
      handle:     _handleCtrl.text.trim().replaceAll('@',''),
      country:    _country ?? 'Tanzania',
      dob:        _dob ?? DateTime(2000),
      password:   _passCtrl.text,
      favTeamIds: _selectedTeamIds.toList(),
      avatarUrl:  _avatarDataUri,
      phone:      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    if (ok) { context.go('/home'); return; }
    final err = ref.read(authControllerProvider).errorMessage ?? 'Registration failed';
    _snack(err);
    // Go back to step 1 on error
    setState(() => _step = 0);
    _animateProgress(0);
    _pageCtrl.jumpToPage(0);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: const Color(0xFF0D1F35),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth.isLoading;

    return Scaffold(
      backgroundColor: PlayifyColors.background,
      body: Stack(children: [
        // Ambient orbs
        const Positioned(top:-80, right:-60,
          child: _Orb(color: _kBlue, size: 300)),
        const Positioned(bottom: 100, left:-80,
          child: _Orb(color: _kGreen, size: 250)),

        SafeArea(child: Column(children: [
          // ── Top bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Expanded(child: Text(
                _stepTitle(),
                style: const TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w800),
              )),
              // Step badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBlue.withValues(alpha: 0.4)),
                ),
                child: Text('${_step + 1} of $_totalSteps',
                    style: const TextStyle(color: _kBlue,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // ── Progress bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (_, __) => LinearProgressIndicator(
                    value: ((_step + 1) / _totalSteps),
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation(_kBlue),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: List.generate(_totalSteps, (i) => Expanded(
                child: Center(child: Text(
                  ['Account','Profile','Fan Setup'][i],
                  style: TextStyle(
                    color: i <= _step ? _kBlue : Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                    fontWeight: i == _step ? FontWeight.w700 : FontWeight.w400,
                  ),
                )),
              ))),
            ]),
          ),

          const SizedBox(height: 8),

          // ── Pages ─────────────────────────────────────────────────────────
          Expanded(child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(), // nav via buttons only
            children: [
              _Step1(
                formKey:     _step1Key,
                firstCtrl:   _firstNameCtrl,
                lastCtrl:    _lastNameCtrl,
                emailCtrl:   _emailCtrl,
                handleCtrl:  _handleCtrl,
                passCtrl:    _passCtrl,
                confirmCtrl: _confirmCtrl,
                showPass:    _showPass,
                showConfirm: _showConfirm,
                onTogglePass:    () => setState(() => _showPass = !_showPass),
                onToggleConfirm: () => setState(() => _showConfirm = !_showConfirm),
                onNext: _nextStep,
              ),
              _Step2(
                avatarBytes: _avatarBytes,
                country:     _country,
                dob:         _dob,
                phoneCtrl:   _phoneCtrl,
                onPickAvatar:  _pickAvatar,
                onPickCountry: _pickCountry,
                onPickDob:     _pickDob,
                onNext: _nextStep,
              ),
              _Step3(
                sports:         _sports,
                teams:          _teams,
                loadingTeams:   _loadingTeams,
                selectedSports: _selectedSports,
                selectedTeams:  _selectedTeamIds,
                selectedTeamNames: _selectedTeamNames,
                searchCtrl:     _teamSearch,
                loading:        loading,
                onToggleSport: (slug) => setState(() {
                  if (_selectedSports.contains(slug)) {
                    _selectedSports.remove(slug);
                  } else {
                    _selectedSports.add(slug);
                  }
                }),
                onToggleTeam: (id, name) => setState(() {
                  if (_selectedTeamIds.contains(id)) {
                    _selectedTeamIds.remove(id); _selectedTeamNames.remove(name);
                  } else {
                    _selectedTeamIds.add(id); _selectedTeamNames.add(name);
                  }
                }),
                onSubmit: _submit,
                onSkip: _submit, // skip = submit without selections
              ),
            ],
          )),
        ])),
      ]),
    );
  }

  String _stepTitle() => ['Create Account','Your Profile','Fan Setup'][_step];
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 1 — Account details
// ══════════════════════════════════════════════════════════════════════════════
class _Step1 extends StatelessWidget {
  const _Step1({
    required this.formKey, required this.firstCtrl, required this.lastCtrl,
    required this.emailCtrl, required this.handleCtrl,
    required this.passCtrl, required this.confirmCtrl,
    required this.showPass, required this.showConfirm,
    required this.onTogglePass, required this.onToggleConfirm,
    required this.onNext,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController firstCtrl, lastCtrl, emailCtrl, handleCtrl,
      passCtrl, confirmCtrl;
  final bool showPass, showConfirm;
  final VoidCallback onTogglePass, onToggleConfirm, onNext;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
    child: Form(key: formKey, child: Column(children: [
      // Logo
      const _MiniLogo(),
      const SizedBox(height: 20),

      // Card
      _Card(child: Column(children: [
        // Name row
        Row(children: [
          Expanded(child: _Field(ctrl: firstCtrl, label: 'First Name',
              hint: 'John', icon: Icons.badge_outlined,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              action: TextInputAction.next)),
          const SizedBox(width: 12),
          Expanded(child: _Field(ctrl: lastCtrl, label: 'Last Name',
              hint: 'Doe', icon: Icons.badge_outlined,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              action: TextInputAction.next)),
        ]),
        const SizedBox(height: 14),
        _Field(ctrl: emailCtrl, label: 'Email Address', hint: 'you@example.com',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
            validator: (v) {
              if (v?.trim().isEmpty == true) return 'Required';
              if (!v!.contains('@')) return 'Invalid email';
              return null;
            }),
        const SizedBox(height: 14),
        _Field(ctrl: handleCtrl, label: 'Handle / Username', hint: '@yourname',
            icon: Icons.alternate_email_rounded,
            validator: (v) {
              final h = v?.trim().replaceAll('@','') ?? '';
              if (h.isEmpty) return 'Required';
              if (h.length < 3) return 'At least 3 characters';
              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(h)) return 'Letters, numbers, underscore only';
              return null;
            }),
        const SizedBox(height: 14),
        _Field(ctrl: passCtrl, label: 'Password', hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: !showPass,
            suffix: IconButton(
              icon: Icon(showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white38, size: 18),
              onPressed: onTogglePass,
            ),
            validator: (v) => (v?.length ?? 0) < 8 ? 'At least 8 characters' : null),
        const SizedBox(height: 14),
        _Field(ctrl: confirmCtrl, label: 'Confirm Password', hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: !showConfirm,
            suffix: IconButton(
              icon: Icon(showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white38, size: 18),
              onPressed: onToggleConfirm,
            ),
            validator: (v) {
              if (v != passCtrl.text) return 'Passwords do not match';
              return null;
            },
            action: TextInputAction.done),
        const SizedBox(height: 20),
        _Btn(label: 'Next — Profile', icon: Icons.arrow_forward_rounded, onTap: onNext),
      ])),

      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Already have an account? ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        GestureDetector(
          onTap: () => context.push('/login'),
          child: const Text('Sign in', style: TextStyle(color: _kBlue, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    ])),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 2 — Profile setup
// ══════════════════════════════════════════════════════════════════════════════
class _Step2 extends StatelessWidget {
  const _Step2({
    required this.avatarBytes, required this.country, required this.dob,
    required this.phoneCtrl,
    required this.onPickAvatar, required this.onPickCountry, required this.onPickDob,
    required this.onNext,
  });
  final Uint8List? avatarBytes;
  final String? country;
  final DateTime? dob;
  final TextEditingController phoneCtrl;
  final VoidCallback onPickAvatar, onPickCountry, onPickDob, onNext;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
    child: Column(children: [
      const _SectionHeader('Set Up Your Profile', 'Add a photo and tell us about you'),
      const SizedBox(height: 24),

      // Avatar picker — centre stage
      GestureDetector(
        onTap: onPickAvatar,
        child: Stack(alignment: Alignment.bottomRight, children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                _kBlue.withValues(alpha: 0.3), _kGreen.withValues(alpha: 0.2)
              ]),
              border: Border.all(color: _kBlue, width: 2.5),
            ),
            child: ClipOval(child: avatarBytes != null
              ? Image.memory(avatarBytes!, fit: BoxFit.cover)
              : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.camera_alt_rounded, color: _kBlue, size: 32),
                  SizedBox(height: 4),
                  Text('Add Photo', style: TextStyle(color: _kBlue, fontSize: 11,
                      fontWeight: FontWeight.w600)),
                ]))),
          ),
          if (!kIsWeb) Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _kBlue),
            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Text(kIsWeb ? 'Photo upload available on mobile app'
                  : 'Tap to add profile photo',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
      const SizedBox(height: 28),

      _Card(child: Column(children: [
        // Country
        _TapField(
          label: 'Country',
          value: country,
          hint: 'Select your country',
          icon: Icons.language_rounded,
          onTap: onPickCountry,
        ),
        const SizedBox(height: 14),
        // DOB
        _TapField(
          label: 'Date of Birth',
          value: dob == null ? null : '${dob!.day}/${dob!.month}/${dob!.year}',
          hint: 'Select your date of birth',
          icon: Icons.cake_outlined,
          onTap: onPickDob,
        ),
        const SizedBox(height: 14),
        _Field(
          ctrl: phoneCtrl,
          label: 'Mobile Number (optional)',
          hint: '+255 712 345 678',
          icon: Icons.phone_outlined,
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        _Btn(label: 'Next — Fan Setup', icon: Icons.arrow_forward_rounded, onTap: onNext),
      ])),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 3 — Fan setup
// ══════════════════════════════════════════════════════════════════════════════
class _Step3 extends StatelessWidget {
  const _Step3({
    required this.sports, required this.teams, required this.loadingTeams,
    required this.loading, required this.selectedSports,
    required this.selectedTeams, required this.selectedTeamNames,
    required this.searchCtrl, required this.onToggleSport,
    required this.onToggleTeam, required this.onSubmit, required this.onSkip,
  });
  final List<Map<String,dynamic>> sports, teams;
  final bool loadingTeams, loading;
  final Set<String> selectedSports, selectedTeams, selectedTeamNames;
  final TextEditingController searchCtrl;
  final void Function(String slug) onToggleSport;
  final void Function(String id, String name) onToggleTeam;
  final VoidCallback onSubmit, onSkip;

  @override
  Widget build(BuildContext context) {
    final query = searchCtrl.text.toLowerCase();
    final filtered = teams.where((t) {
      final n = (t['name'] as String? ?? '').toLowerCase();
      return query.isEmpty || n.contains(query);
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader('Your Fan Profile',
            'Pick the sports and teams you support (optional)'),
        const SizedBox(height: 20),

        // Sports chips
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Favourite Sports',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Tap to select',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8,
            children: sports.map((s) {
              final slug = s['slug']?.toString() ?? s['id']?.toString() ?? '';
              final name = s['name']?.toString() ?? '';
              final icon = s['icon']?.toString() ?? '🏅';
              final sel  = selectedSports.contains(slug);
              return GestureDetector(
                onTap: () => onToggleSport(slug),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: sel ? _kBlue.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: sel ? _kBlue : Colors.white.withValues(alpha: 0.12),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(name, style: TextStyle(
                      color: sel ? _kBlue : Colors.white,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    )),
                    if (sel) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_rounded, size: 14, color: _kBlue),
                    ],
                  ]),
                ),
              );
            }).toList(),
          ),
        ])),

        const SizedBox(height: 16),

        // Teams
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Favourite Teams',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 12),
          // Search
          TextField(
            controller: searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search teams...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBlue)),
            ),
          ),
          const SizedBox(height: 10),
          loadingTeams
            ? const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2)))
            : filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text('No teams found',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4)))))
              : Column(
                  children: filtered.take(15).map((t) {
                    final id   = t['id']?.toString() ?? '';
                    final name = t['name']?.toString() ?? '';
                    final logo = t['logoUrl']?.toString();
                    final sel  = selectedTeams.contains(id);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        backgroundImage: (logo != null && logo.startsWith('http'))
                            ? NetworkImage(logo) : null,
                        child: (logo == null || !logo.startsWith('http'))
                            ? Text(name.isNotEmpty ? name[0] : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                            : null,
                      ),
                      title: Text(name, style: TextStyle(
                        color: sel ? _kBlue : Colors.white,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      )),
                      trailing: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel ? _kBlue : Colors.transparent,
                          border: Border.all(color: sel ? _kBlue : Colors.white24, width: 1.5),
                        ),
                        child: sel ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                      ),
                      onTap: () => onToggleTeam(id, name),
                    );
                  }).toList(),
                ),
        ])),

        const SizedBox(height: 20),

        // Selected summary
        if (selectedTeams.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(spacing: 6, children: selectedTeamNames.map((n) => Chip(
              label: Text(n, style: const TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: _kGreen.withValues(alpha: 0.15),
              side: const BorderSide(color: _kGreen, width: 1),
              deleteIcon: const Icon(Icons.close_rounded, size: 14, color: _kGreen),
              onDeleted: () {
                final id = selectedTeams.firstWhere((id) =>
                  true, orElse: () => '');
                onToggleTeam(id, n);
              },
            )).toList()),
          ),

        // Action buttons
        loading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2)))
          : Column(children: [
              _Btn(
                label: 'Create My Account',
                icon: Icons.check_circle_outline_rounded,
                color: _kGreen,
                onTap: onSubmit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSkip,
                child: Text('Skip for now',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13)),
              ),
            ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [_kBlue, _kGreen.withValues(alpha: 0.7)]),
        boxShadow: [BoxShadow(color: _kBlue.withValues(alpha: 0.3), blurRadius: 16)],
      ),
      child: const Center(child: Text('P', style: TextStyle(color: Colors.white,
          fontSize: 22, fontWeight: FontWeight.w900))),
    ),
    const SizedBox(height: 8),
    const Text('Playify', style: TextStyle(color: Colors.white,
        fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
    const SizedBox(height: 2),
    Text('Join the sports community',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
  ]);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(title, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: child,
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl, required this.label, required this.hint,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.obscure = false,
    this.validator,
    this.action = TextInputAction.next,
    this.suffix,
  });
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final TextInputType keyboard;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputAction action;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    obscureText: obscure,
    keyboardType: keyboard,
    textInputAction: action,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    ),
  );
}

class _TapField extends StatelessWidget {
  const _TapField({required this.label, required this.hint, this.value,
      required this.icon, required this.onTap});
  final String label, hint;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value ?? hint, style: TextStyle(
            color: value != null ? Colors.white : Colors.white.withValues(alpha: 0.25),
            fontSize: 14,
          )),
        ])),
        Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 20),
      ]),
    ),
  );
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.icon, this.color = _kBlue, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});
  final Color color; final double size;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      color: color.withValues(alpha: 0.06)));
}

// ══════════════════════════════════════════════════════════════════════════════
// COUNTRY PICKER
// ══════════════════════════════════════════════════════════════════════════════
class _CountryPicker extends StatefulWidget {
  const _CountryPicker({this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;
  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  final _search = TextEditingController();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _kCountries.where((c) => c.toLowerCase().contains(_q)).toList()..sort();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1F35),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Select Country', style: TextStyle(color: Colors.white,
            fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _q = v.toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search country...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
              filled: true, fillColor: Colors.white.withValues(alpha: 0.07),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(filtered[i], style: const TextStyle(color: Colors.white, fontSize: 14)),
            trailing: widget.selected == filtered[i]
                ? const Icon(Icons.check_rounded, color: _kBlue) : null,
            onTap: () { widget.onSelect(filtered[i]); Navigator.pop(context); },
          ),
        )),
      ])),
    );
  }
}
