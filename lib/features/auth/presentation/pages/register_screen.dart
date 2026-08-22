import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
            colorScheme: ColorScheme.dark(
              primary: SportSphereColors.electricBlue,
              onPrimary: Colors.white,
              surface: SportSphereColors.surface2,
              onSurface: SportSphereColors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: SportSphereColors.surface,
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

    final ok = await ref.read(authControllerProvider.notifier).register(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          handle: _handleCtrl.text.trim().replaceAll('@', ''),
          country: _country!,
          dob: _dob!,
          password: _passwordCtrl.text,
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
        backgroundColor: SportSphereColors.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: SportSphereColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Ambient orbs
          Positioned(
            top: -100,
            right: -80,
            child: _Orb(color: SportSphereColors.electricBlue, size: 340),
          ),
          Positioned(
            bottom: 80,
            left: -100,
            child: _Orb(color: SportSphereColors.sportGreen, size: 280),
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
                              color: SportSphereColors.white,
                              size: 20,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Create Account',
                              style: TextStyle(
                                color: SportSphereColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          // Fan badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: SportSphereColors.sportGreen
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: SportSphereColors.sportGreen
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.favorite_rounded,
                                  color: SportSphereColors.sportGreen,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Fan Account',
                                  style: TextStyle(
                                    color: SportSphereColors.sportGreen,
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

                                    const SizedBox(height: 22),

                                    // Submit
                                    _PrimaryButton(
                                      label: 'Create Fan Account',
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
                                    color: SportSphereColors.muted
                                        .withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                  children: [
                                    const TextSpan(
                                        text: 'Already have an account?  '),
                                    TextSpan(
                                      text: 'Log In',
                                      style: TextStyle(
                                        color:
                                            SportSphereColors.electricBlue,
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
            color: SportSphereColors.muted.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Form field ─────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: focused
            ? SportSphereColors.electricBlue.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: focused
              ? SportSphereColors.electricBlue.withValues(alpha: 0.55)
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
            color: SportSphereColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: SportSphereColors.electricBlue,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: focused
                  ? SportSphereColors.electricBlue
                  : SportSphereColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                icon,
                color: focused
                    ? SportSphereColors.electricBlue
                    : SportSphereColors.muted,
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
              ? SportSphereColors.electricBlue.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: filled
                ? SportSphereColors.electricBlue.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: filled
                  ? SportSphereColors.electricBlue
                  : SportSphereColors.muted,
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
                          ? SportSphereColors.electricBlue
                          : SportSphereColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? placeholder,
                    style: TextStyle(
                      color: filled
                          ? SportSphereColors.white
                          : SportSphereColors.muted.withValues(alpha: 0.55),
                      fontSize: 14,
                      fontWeight:
                          filled ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: SportSphereColors.muted,
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
  final String? selected;
  final ValueChanged<String> onSelect;
  const _CountryPicker({this.selected, required this.onSelect});

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
        color: SportSphereColors.surface,
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
                      color: SportSphereColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: SportSphereColors.muted,
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
                  color: SportSphereColors.white,
                  fontSize: 14,
                ),
                cursorColor: SportSphereColors.electricBlue,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: SportSphereColors.muted,
                    size: 20,
                  ),
                  hintText: 'Search country…',
                  hintStyle: TextStyle(
                    color: SportSphereColors.muted.withValues(alpha: 0.6),
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
                          ? SportSphereColors.electricBlue
                          : SportSphereColors.white,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: SportSphereColors.electricBlue,
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
        color: SportSphereColors.sportGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SportSphereColors.sportGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: SportSphereColors.sportGreen,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You will start as a Fan - follow teams, vote in polls, predict matches and join communities. Upgrade to a Pro role anytime.",
              style: TextStyle(
                color: SportSphereColors.white.withValues(alpha: 0.82),
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
  final Widget child;
  const _GlassCard({required this.child});

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
                    SportSphereColors.electricBlue.withValues(alpha: 0.6),
                    const Color(0xFF0055BB).withValues(alpha: 0.6),
                  ]
                : [
                    SportSphereColors.electricBlue,
                    const Color(0xFF0066DD),
                  ],
          ),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: SportSphereColors.electricBlue
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
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: SportSphereColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SportSphereColors.danger.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: SportSphereColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              Icons.close_rounded,
              color: SportSphereColors.muted,
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
          color: SportSphereColors.muted.withValues(alpha: 0.75),
          fontSize: 12,
          height: 1.6,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our\n'),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: SportSphereColors.electricBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: '  and  '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: SportSphereColors.electricBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

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
