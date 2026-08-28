import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/data/vps_repository.dart';

import '../../../../core/theme/colors.dart';
import '../auth_controller.dart';

// ── Country list ───────────────────────────────────────────────────────────────
// Africa-first ordering, then rest of world alphabetically.
const _countries = [
  'Tanzania',
  'Kenya',
  'Uganda',
  'Rwanda',
  'Ethiopia',
  'Nigeria',
  'Ghana',
  'South Africa',
  'Egypt',
  'Morocco',
  'Senegal',
  'Cameroon',
  'Ivory Coast',
  'Angola',
  'Zimbabwe',
  'Zambia',
  'Mozambique',
  'Algeria',
  'Libya',
  'Sudan',
  '──────────────',
  'Afghanistan',
  'Albania',
  'Argentina',
  'Australia',
  'Austria',
  'Belgium',
  'Bolivia',
  'Brazil',
  'Canada',
  'Chile',
  'China',
  'Colombia',
  'Croatia',
  'Czech Republic',
  'Denmark',
  'Ecuador',
  'Finland',
  'France',
  'Germany',
  'Greece',
  'Hungary',
  'India',
  'Indonesia',
  'Iran',
  'Iraq',
  'Ireland',
  'Israel',
  'Italy',
  'Japan',
  'Jordan',
  'Mexico',
  'Netherlands',
  'New Zealand',
  'Norway',
  'Pakistan',
  'Paraguay',
  'Peru',
  'Philippines',
  'Poland',
  'Portugal',
  'Qatar',
  'Romania',
  'Russia',
  'Saudi Arabia',
  'Serbia',
  'South Korea',
  'Spain',
  'Sweden',
  'Switzerland',
  'Thailand',
  'Turkey',
  'Ukraine',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'Uruguay',
  'Venezuela',
  'Vietnam',
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _country;
  DateTime? _dob;

  // Focus state per field
  final _focused = <String, bool>{};

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _handleCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _isFocused(String key) => _focused[key] == true;

  void _setFocus(String key, bool v) =>
      setState(() => _focused[key] = v);

  Future<void> _pickDob() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: PlayifyColors.electricBlue,
              onPrimary: Colors.white,
              surface: PlayifyColors.surface2,
              onSurface: PlayifyColors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: PlayifyColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickCountry() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPicker(
        selected: _country,
        onSelect: (c) => Navigator.pop(context, c),
      ),
    );
    if (result != null && result != '──────────────') {
      setState(() => _country = result);
    }
  }

  // ── Step 2 state ──────────────────────────────────────────────────────────
  final Set<String> _favTeamIds = {};
  final Set<String> _favTeamNames = {};
  String? _avatarUrl;

  Future<bool?> _showFanSetup() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FanSetupSheet(
        favTeamIds: _favTeamIds,
        favTeamNames: _favTeamNames,
        avatarUrl: _avatarUrl,
        onAvatarChanged: (url) => setState(() => _avatarUrl = url),
        onTeamToggled: (id, name, selected) {
          setState(() {
            if (selected) {
              _favTeamIds.add(id);
              _favTeamNames.add(name);
            } else {
              _favTeamIds.remove(id);
              _favTeamNames.remove(name);
            }
          });
        },
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_country == null) {
      _showSnack('Please select your country.');
      return;
    }
    if (_dob == null) {
      _showSnack('Please select your date of birth.');
      return;
    }
    HapticFeedback.lightImpact();

    // Show Step 2 — Fan Setup
    final confirmed = await _showFanSetup();
    if (confirmed != true) return; // user cancelled

    final ok = await ref.read(authControllerProvider.notifier).register(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          handle: _handleCtrl.text.trim().replaceAll('@', ''),
          country: _country!,
          dob: _dob!,
          password: _passwordCtrl.text,
          favTeamIds: _favTeamIds.toList(),
          avatarUrl: _avatarUrl,
        );

    if (!mounted) return;
    if (ok) {
      context.go('/home');
      return;
    }
    final err = ref.read(authControllerProvider).errorMessage ?? '';
    if (err.startsWith('CONFIRM:')) {
      final msg = err.replaceFirst('CONFIRM:', '').trim();
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: const Color(0xFF0C1A2A),
          title: const Text('Verify your email',
              style: TextStyle(color: Colors.white)),
          content: Text(msg, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () async {
                await ref
                    .read(authControllerProvider.notifier)
                    .resendConfirmation(_emailCtrl.text.trim());
                if (d.mounted) Navigator.pop(d);
              },
              child: const Text('Resend link'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(d);
                context.go('/login');
              },
              child: const Text('Go to login'),
            ),
          ],
        ),
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: PlayifyColors.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: PlayifyColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Ambient orbs
          const Positioned(
            top: -100,
            right: -80,
            child: const _Orb(color: PlayifyColors.electricBlue, size: 340),
          ),
          const Positioned(
            bottom: 80,
            left: -100,
            child: const _Orb(color: PlayifyColors.sportGreen, size: 280),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  children: [
                    // ── Header bar ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: PlayifyColors.white,
                              size: 20,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Create Account',
                              style: TextStyle(
                                color: PlayifyColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          // Step indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: PlayifyColors.electricBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: PlayifyColors.electricBlue.withValues(alpha: 0.4)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.looks_one_rounded, color: PlayifyColors.electricBlue, size: 14),
                              SizedBox(width: 4),
                              Text('Step 1 of 2', style: TextStyle(color: PlayifyColors.electricBlue,
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          // Fan badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: PlayifyColors.sportGreen
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PlayifyColors.sportGreen
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  color: PlayifyColors.sportGreen,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Fan Account',
                                  style: const TextStyle(
                                    color: PlayifyColors.sportGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        child: Column(
                          children: [
                            // ── Mini logo ─────────────────────────
                            _MiniLogo(),

                            const SizedBox(height: 20),

                            // ── Form card ─────────────────────────
                            _GlassCard(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Error
                                    if (auth.errorMessage != null) ...[
                                      _ErrorBanner(
                                        message: auth.errorMessage!,
                                        onDismiss: () => ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .clearError(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // Name row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _Field(
                                            ctrl: _firstNameCtrl,
                                            label: 'First Name',
                                            hint: 'John',
                                            icon: Icons.badge_outlined,
                                            focused: _isFocused('fn'),
                                            onFocus: (v) =>
                                                _setFocus('fn', v),
                                            validator: (v) =>
                                                v?.trim().isEmpty == true
                                                    ? 'Required'
                                                    : null,
                                            action: TextInputAction.next,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _Field(
                                            ctrl: _lastNameCtrl,
                                            label: 'Last Name',
                                            hint: 'Doe',
                                            icon: Icons.badge_outlined,
                                            focused: _isFocused('ln'),
                                            onFocus: (v) =>
                                                _setFocus('ln', v),
                                            validator: (v) =>
                                                v?.trim().isEmpty == true
                                                    ? 'Required'
                                                    : null,
                                            action: TextInputAction.next,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 14),

                                    // Email
                                    _Field(
                                      ctrl: _emailCtrl,
                                      label: 'Email Address',
                                      hint: 'you@example.com',
                                      icon: Icons.email_outlined,
                                      focused: _isFocused('em'),
                                      onFocus: (v) => _setFocus('em', v),
                                      keyboard:
                                          TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v?.trim().isEmpty == true) {
                                          return 'Required';
                                        }
                                        if (!RegExp(
                                          r'^[^@]+@[^@]+\.[^@]+',
                                        ).hasMatch(v!)) {
                                          return 'Invalid email';
                                        }
                                        return null;
                                      },
                                      action: TextInputAction.next,
                                    ),

                                    const SizedBox(height: 14),

                                    // Handle
                                    _Field(
                                      ctrl: _handleCtrl,
                                      label: 'Handle / Username',
                                      hint: '@johndoe',
                                      icon: Icons.alternate_email_rounded,
                                      focused: _isFocused('hd'),
                                      onFocus: (v) => _setFocus('hd', v),
                                      validator: (v) {
                                        final h =
                                            v?.trim().replaceAll('@', '') ??
                                                '';
                                        if (h.isEmpty) return 'Required';
                                        if (h.length < 3) {
                                          return 'Min 3 characters';
                                        }
                                        if (!RegExp(r'^[a-zA-Z0-9_]+$')
                                            .hasMatch(h)) {
                                          return 'Letters, numbers & _ only (numbers optional)';
                                        }
                                        return null;
                                      },
                                      action: TextInputAction.next,
                                    ),

                                    const SizedBox(height: 14),

                                    _Field(
                                      ctrl: _passwordCtrl,
                                      label: 'Password',
                                      hint: 'At least 6 characters',
                                      icon: Icons.lock_outline_rounded,
                                      focused: _isFocused('pw'),
                                      onFocus: (v) => _setFocus('pw', v),
                                      obscure: true,
                                      validator: (v) {
                                        if (v == null || v.length < 6) return 'Min 6 characters';
                                        return null;
                                      },
                                      action: TextInputAction.next,
                                    ),

                                    const SizedBox(height: 14),

                                    _Field(
                                      ctrl: _confirmCtrl,
                                      label: 'Confirm password',
                                      hint: 'Repeat password',
                                      icon: Icons.lock_outline_rounded,
                                      focused: _isFocused('pw2'),
                                      onFocus: (v) => _setFocus('pw2', v),
                                      obscure: true,
                                      validator: (v) {
                                        if (v != _passwordCtrl.text) return 'Passwords do not match';
                                        return null;
                                      },
                                      action: TextInputAction.done,
                                    ),

                                    const SizedBox(height: 14),

                                    // Country picker
                                    _TapField(
                                      label: 'Country',
                                      icon: Icons.public_rounded,
                                      value: _country,
                                      placeholder: 'Select your country',
                                      onTap: _pickCountry,
                                      hasError:
                                          _country == null ? false : false,
                                    ),

                                    const SizedBox(height: 14),

                                    // DOB picker
                                    _TapField(
                                      label: 'Date of Birth',
                                      icon: Icons.cake_outlined,
                                      value: _dob != null
                                          ? DateFormat('dd MMM yyyy')
                                              .format(_dob!)
                                          : null,
                                      placeholder: 'Select your date of birth',
                                      onTap: _pickDob,
                                      hasError: false,
                                    ),

                                    const SizedBox(height: 10),

                                    // Fan info note
                                    _FanNote(),

                                    const SizedBox(height: 16),

                                    // Step 2 hint
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: PlayifyColors.electricBlue.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: PlayifyColors.electricBlue.withValues(alpha: 0.2)),
                                      ),
                                      child: const Row(children: [
                                        Icon(Icons.arrow_forward_rounded, color: PlayifyColors.electricBlue, size: 16),
                                        SizedBox(width: 8),
                                        Expanded(child: Text(
                                          'Next: choose your favourite teams and upload a photo',
                                          style: TextStyle(color: PlayifyColors.electricBlue, fontSize: 12),
                                        )),
                                      ]),
                                    ),

                                    const SizedBox(height: 16),

                                    // Submit
                                    _PrimaryButton(
                                      label: 'Continue →  Fan Setup',
                                      loading: auth.isLoading,
                                      onTap: _submit,
                                    ),

                                    const SizedBox(height: 16),

                                    // Terms
                                    _TermsText(),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Already have account
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: PlayifyColors.muted
                                        .withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                  children: [
                                    const TextSpan(
                                        text: 'Already have an account?  '),
                                    const TextSpan(
                                      text: 'Log In',
                                      style: const TextStyle(
                                        color:
                                            PlayifyColors.electricBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini logo (compact version for register) ───────────────────────────────────

class _MiniLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/playify_sign.png',
          height: 110,
          fit: BoxFit.contain,errorBuilder: (_, __, ___) => const Text(
            'Playify',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Join the sports community',
          style: TextStyle(
            color: PlayifyColors.muted.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Form field ─────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.focused,
    required this.onFocus,
    this.validator,
    this.action,
    this.keyboard,
    this.obscure = false,
  });

  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final bool focused;
  final ValueChanged<bool> onFocus;
  final String? Function(String?)? validator;
  final TextInputAction? action;
  final TextInputType? keyboard;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: focused
            ? PlayifyColors.electricBlue.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: focused
              ? PlayifyColors.electricBlue.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.10),
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Focus(
        onFocusChange: onFocus,
        child: TextFormField(
          controller: ctrl,
          validator: validator,
          textInputAction: action,
          keyboardType: keyboard,
          obscureText: obscure,
          style: const TextStyle(
            color: PlayifyColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: PlayifyColors.electricBlue,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: focused
                  ? PlayifyColors.electricBlue
                  : PlayifyColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: PlayifyColors.muted.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                icon,
                color: focused
                    ? PlayifyColors.electricBlue
                    : PlayifyColors.muted,
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tap-to-pick field (country / dob) ──────────────────────────────────────────

class _TapField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final bool hasError;

  const _TapField({
    required this.label,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: filled
              ? PlayifyColors.electricBlue.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: filled
                ? PlayifyColors.electricBlue.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: filled
                  ? PlayifyColors.electricBlue
                  : PlayifyColors.muted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: filled
                          ? PlayifyColors.electricBlue
                          : PlayifyColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? placeholder,
                    style: TextStyle(
                      color: filled
                          ? PlayifyColors.white
                          : PlayifyColors.muted.withValues(alpha: 0.55),
                      fontSize: 14,
                      fontWeight:
                          filled ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PlayifyColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Country picker bottom sheet ────────────────────────────────────────────────

class _CountryPicker extends StatefulWidget {
  const _CountryPicker({this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = _countries;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _countries
            : _countries
                .where((c) => c.toLowerCase().contains(q))
                .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: PlayifyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Country',
                    style: TextStyle(
                      color: PlayifyColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: PlayifyColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                  color: PlayifyColors.white,
                  fontSize: 14,
                ),
                cursorColor: PlayifyColors.electricBlue,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: PlayifyColors.muted,
                    size: 20,
                  ),
                  hintText: 'Search country…',
                  hintStyle: TextStyle(
                    color: PlayifyColors.muted.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                if (c == '──────────────') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  );
                }
                final selected = widget.selected == c;
                return ListTile(
                  onTap: () => widget.onSelect(c),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(
                    c,
                    style: TextStyle(
                      color: selected
                          ? PlayifyColors.electricBlue
                          : PlayifyColors.white,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: PlayifyColors.electricBlue,
                          size: 20,
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fan note ───────────────────────────────────────────────────────────────────

class _FanNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlayifyColors.sportGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PlayifyColors.sportGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: PlayifyColors.sportGreen,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You will start as a Fan - follow teams, vote in polls, predict matches and join communities. Upgrade to a Pro role anytime.',
              style: TextStyle(
                color: PlayifyColors.white.withValues(alpha: 0.82),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets (duplicated from login for isolation) ───────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: child,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: loading
                ? [
                    PlayifyColors.electricBlue.withValues(alpha: 0.6),
                    const Color(0xFF0055BB).withValues(alpha: 0.6),
                  ]
                : [
                    PlayifyColors.electricBlue,
                    const Color(0xFF0066DD),
                  ],
          ),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: PlayifyColors.electricBlue
                        .withValues(alpha: 0.40),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: PlayifyColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PlayifyColors.danger.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: PlayifyColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: PlayifyColors.white,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              Icons.close_rounded,
              color: PlayifyColors.muted,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          color: PlayifyColors.muted.withValues(alpha: 0.75),
          fontSize: 12,
          height: 1.6,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our\n'),
          const TextSpan(
            text: 'Terms of Service',
            style: const TextStyle(
              color: PlayifyColors.electricBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: '  and  '),
          const TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
              color: PlayifyColors.electricBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.10),
              color.withValues(alpha: 0.025),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fan Setup Sheet (Step 2 of registration) ─────────────────────────────────

class _FanSetupSheet extends StatefulWidget {
  final Set<String> favTeamIds;
  final Set<String> favTeamNames;
  final String? avatarUrl;
  final ValueChanged<String?> onAvatarChanged;
  final void Function(String id, String name, bool selected) onTeamToggled;

  const _FanSetupSheet({
    required this.favTeamIds,
    required this.favTeamNames,
    required this.avatarUrl,
    required this.onAvatarChanged,
    required this.onTeamToggled,
  });

  @override
  State<_FanSetupSheet> createState() => _FanSetupSheetState();
}

class _FanSetupSheetState extends State<_FanSetupSheet> {
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _sports = [];
  final Set<String> _selectedSports = {};
  bool _loading = true;
  final _search = TextEditingController();
  String _query = '';
  late Set<String> _selected;

  // Curated sport list shown when VPS sports empty
  static const _defaultSports = [
    {'id': 'sport-football',   'name': 'Football',    'icon': '⚽', 'slug': 'football'},
    {'id': 'sport-basketball', 'name': 'Basketball',  'icon': '🏀', 'slug': 'basketball'},
    {'id': 'sport-athletics',  'name': 'Athletics',   'icon': '🏃', 'slug': 'athletics'},
    {'id': 'sport-tennis',     'name': 'Tennis',      'icon': '🎾', 'slug': 'tennis'},
    {'id': 'sport-volleyball', 'name': 'Volleyball',  'icon': '🏐', 'slug': 'volleyball'},
    {'id': 'sport-cricket',    'name': 'Cricket',     'icon': '🏏', 'slug': 'cricket'},
    {'id': 'sport-boxing',     'name': 'Boxing',      'icon': '🥊', 'slug': 'boxing'},
    {'id': 'sport-swimming',   'name': 'Swimming',    'icon': '🏊', 'slug': 'swimming'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.favTeamIds);
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSports(), _loadTeams()]);
  }

  Future<void> _loadSports() async {
    try {
      final res = await VpsRepository().get<Map<String, dynamic>>('/v1/social/sports');
      final rows = (res.data?['sports'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _sports = rows.isNotEmpty ? rows : List.from(_defaultSports));
    } catch (_) {
      if (mounted) setState(() => _sports = List.from(_defaultSports));
    }
  }

  Future<void> _loadTeams() async {
    try {
      final res = await VpsRepository().get<Map<String, dynamic>>('/v1/admin/teams', query: {'limit': 200});
      final rows = (res.data?['teams'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) setState(() {
        _teams = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = _teams.where((t) =>
        _query.isEmpty ||
        (t['name'] as String? ?? '').toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF071420),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fan Setup', style: TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Step 2 of 2', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
              ]),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  // Save sports selection (best-effort, non-blocking)
                  if (_selectedSports.isNotEmpty) {
                    try {
                      await VpsRepository().post<void>('/v1/social/my-sports', data: {
                        'slugs': _selectedSports.toList(),
                        'primary': _selectedSports.first,
                      });
                    } catch (_) {}
                  }
                  if (context.mounted) Navigator.pop(context, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: PlayifyColors.electricBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Skip', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                )),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Avatar section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              // Avatar preview
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: PlayifyColors.electricBlue.withValues(alpha: 0.15),
                    backgroundImage: widget.avatarUrl != null && widget.avatarUrl!.startsWith('http')
                        ? NetworkImage(widget.avatarUrl!) : null,
                    child: widget.avatarUrl == null
                        ? const Icon(Icons.person_rounded, color: PlayifyColors.electricBlue, size: 32)
                        : null,
                  ),
                  Positioned(right: 0, bottom: 0, child: Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: PlayifyColors.electricBlue),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                  )),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Profile Photo', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Optional — tap to upload', style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
              ])),
            ]),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // ── Sport selection ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Favourite Sports', style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Pick the sports you follow (optional)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8,
                children: _sports.map((s) {
                  final slug = s['slug']?.toString() ?? s['id']?.toString() ?? '';
                  final name = s['name']?.toString() ?? '';
                  final icon = s['icon']?.toString() ?? '🏅';
                  final selected = _selectedSports.contains(slug);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) _selectedSports.remove(slug);
                      else _selectedSports.add(slug);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: selected
                            ? PlayifyColors.electricBlue.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: selected
                              ? PlayifyColors.electricBlue
                              : Colors.white.withValues(alpha: 0.12),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(name, style: TextStyle(
                          color: selected ? PlayifyColors.electricBlue : Colors.white,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        )),
                        if (selected) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_rounded, size: 14,
                              color: PlayifyColors.electricBlue),
                        ],
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Team selection header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('Favourite Teams', style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${_selected.length}/3',
                  style: TextStyle(color: _selected.length >= 3
                      ? PlayifyColors.sportGreen : Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Pick up to 3 teams you support',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          ),

          const SizedBox(height: 12),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search teams…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none), isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Teams list
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: PlayifyColors.electricBlue, strokeWidth: 2))
              : ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final t = filtered[i];
                    final id = t['id']?.toString() ?? '';
                    final name = t['name']?.toString() ?? '';
                    final logo = t['logoUrl'] as String?;
                    final isSelected = _selected.contains(id);
                    final canSelect = isSelected || _selected.length < 3;

                    return GestureDetector(
                      onTap: canSelect ? () {
                        setState(() {
                          if (isSelected) _selected.remove(id);
                          else _selected.add(id);
                        });
                        widget.onTeamToggled(id, name, !isSelected);
                      } : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isSelected
                              ? PlayifyColors.electricBlue.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: isSelected
                              ? PlayifyColors.electricBlue.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.07)),
                        ),
                        child: Row(children: [
                          // Team logo
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: PlayifyColors.electricBlue.withValues(alpha: 0.12),
                            backgroundImage: (logo != null && logo.startsWith('http'))
                                ? NetworkImage(logo) : null,
                            child: (logo == null || !logo.startsWith('http'))
                                ? const Icon(Icons.shield_rounded,
                                    color: PlayifyColors.electricBlue, size: 18) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(name,
                              style: TextStyle(
                                color: isSelected ? PlayifyColors.electricBlue : Colors.white,
                                fontWeight: FontWeight.w600, fontSize: 14))),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: PlayifyColors.electricBlue, size: 22)
                          else if (!canSelect)
                            Icon(Icons.lock_rounded,
                                color: Colors.white.withValues(alpha: 0.2), size: 18),
                        ]),
                      ),
                    );
                  },
                )),
        ]),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    // Pick image and show preview locally.
    // Actual upload happens AFTER registration (needs JWT).
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // Store as data URI for local preview — upload to R2 after login
      final ext = file.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
      widget.onAvatarChanged(dataUri);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick photo: $e')));
    }
  }
}
