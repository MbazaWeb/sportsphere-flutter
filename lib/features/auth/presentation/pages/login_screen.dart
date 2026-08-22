import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/grass_form.dart';
import '../auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _identifierFocused = false;
  bool _passwordFocused = false;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();

    final ok = await ref.read(authControllerProvider.notifier).login(
          identifier: _identifierCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (!mounted) return;
    if (ok) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: SportSphereColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Ambient orbs ────────────────────────────────────
          Positioned(
            top: -size.height * 0.12,
            left: -80,
            child: _AmbientOrb(
              color: GrassForm.greenLine,
              size: size.width * 0.95,
            ),
          ),
          Positioned(
            top: size.height * 0.25,
            right: -120,
            child: _AmbientOrb(
              color: SportSphereColors.sportGreen,
              size: size.width * 0.7,
            ),
          ),
          Positioned(
            bottom: -80,
            left: size.width * 0.2,
            child: _AmbientOrb(
              color: SportSphereColors.sportOrange,
              size: size.width * 0.55,
            ),
          ),

          // ── Content ─────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),

                      // ── Logo ─────────────────────────────────
                      _LogoSection(),

                      const SizedBox(height: 36),

                      // ── Glass card ───────────────────────────
                      _GlassCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Error banner
                              if (auth.errorMessage != null) ...[
                                _ErrorBanner(
                                  message: auth.errorMessage!,
                                  onDismiss: () => ref
                                      .read(authControllerProvider.notifier)
                                      .clearError(),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Identifier field
                              _GlassField(
                                controller: _identifierCtrl,
                                label: 'Username / Handle',
                                hint: 'Enter your username or @handle',
                                prefixIcon: Icons.person_outline_rounded,
                                focused: _identifierFocused,
                                onFocusChange: (v) =>
                                    setState(() => _identifierFocused = v),
                                validator: (v) =>
                                    (v?.trim().isEmpty ?? true)
                                        ? 'Enter your username or handle'
                                        : null,
                                textInputAction: TextInputAction.next,
                              ),

                              const SizedBox(height: 14),

                              // Password field
                              _GlassField(
                                controller: _passwordCtrl,
                                label: 'Password',
                                hint: 'Enter your password',
                                prefixIcon: Icons.lock_outline_rounded,
                                obscure: _obscure,
                                focused: _passwordFocused,
                                onFocusChange: (v) =>
                                    setState(() => _passwordFocused = v),
                                suffixIcon: GestureDetector(
                                  onTap: () =>
                                      setState(() => _obscure = !_obscure),
                                  child: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: SportSphereColors.muted,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) =>
                                    (v?.isEmpty ?? true)
                                        ? 'Enter your password'
                                        : null,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              ),

                              const SizedBox(height: 10),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () async {
                                    final ctrl = TextEditingController(
                                      text: _identifierCtrl.text,
                                    );
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (d) => AlertDialog(
                                        backgroundColor: const Color(0xFF0C1A2A),
                                        title: const Text(
                                          'Reset password',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: TextField(
                                          controller: ctrl,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(
                                            labelText: 'Email or handle',
                                            labelStyle: TextStyle(color: Colors.white54),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(d, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(d, true),
                                            child: const Text('Send link'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true || !context.mounted) return;
                                    final sent = await ref
                                        .read(authControllerProvider.notifier)
                                        .sendPasswordReset(ctrl.text.trim());
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          sent
                                              ? 'Password reset email sent. Check your inbox.'
                                              : 'Unable to send the password reset email.',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: GrassForm.greenLine,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Log in button
                              _PrimaryButton(
                                label: 'Log In',
                                loading: auth.isLoading,
                                onTap: _submit,
                              ),

                              const SizedBox(height: 16),

                              // OR divider
                              _OrDivider(),

                              const SizedBox(height: 16),

                              // Sign up button
                              _OutlineButton(
                                label: 'Sign Up',
                                icon: Icons.person_add_outlined,
                                onTap: () => context.push('/register'),
                              ),

                              const SizedBox(height: 20),

                              // Terms
                              _TermsText(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Guest continue
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Text(
                          'Continue as Guest',
                          style: TextStyle(
                            color: SportSphereColors.muted
                                .withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo section ───────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ball with glow ring
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow ring
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: GrassForm.greenLine.withValues(alpha: 0.35),
                    blurRadius: 50,
                    spreadRadius: 8,
                  ),
                  BoxShadow(
                    color: SportSphereColors.sportGreen.withValues(alpha: 0.15),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
            // Outer ring
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: GrassForm.greenLine.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
            ),
            // Icon
            ClipOval(
              child: Image.asset(
                'assets/images/playify_icon.png',
                width: 104,
                height: 104,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 104,
                  height: 104,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SportSphereColors.surface,
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    color: GrassForm.greenLine,
                    size: 52,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // SPORT SPHERE wordmark
        Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _wordmark('SPORT', Colors.white, 28, 2.0),
                const SizedBox(width: 7),
                _wordmark('SPHERE', SportSphereColors.sportGreen, 18, 3.5),
              ],
            ),
            const SizedBox(height: 8),
            // Tagline — 3 coloured words
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tagWord('Connect.', GrassForm.greenLine),
                const SizedBox(width: 6),
                _tagWord('Compete.', SportSphereColors.sportGreen),
                const SizedBox(width: 6),
                _tagWord('Celebrate.', SportSphereColors.sportOrange),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _wordmark(String t, Color c, double size, double spacing) => Text(
        t,
        style: TextStyle(
          color: c,
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: spacing,
          height: 1,
          shadows: [
            Shadow(
              color: c.withValues(alpha: 0.4),
              blurRadius: 16,
            ),
          ],
        ),
      );

  Widget _tagWord(String t, Color c) => Text(
        t,
        style: TextStyle(
          color: c,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      );
}

// ── Glass card ─────────────────────────────────────────────────────────────────

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
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
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

// ── Glass input field ──────────────────────────────────────────────────────────

class _GlassField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final bool focused;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<String>? onSubmitted;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.focused,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
    this.textInputAction,
    this.onFocusChange,
    this.onSubmitted,
  });

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: widget.focused
            ? GrassForm.greenLine.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: widget.focused
              ? GrassForm.greenLine.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.10),
          width: widget.focused ? 1.5 : 1,
        ),
      ),
      child: Focus(
        onFocusChange: widget.onFocusChange,
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscure,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          style: const TextStyle(
            color: SportSphereColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: GrassForm.greenLine,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: widget.focused
                  ? GrassForm.greenLine
                  : SportSphereColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.55),
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                widget.prefixIcon,
                color: widget.focused
                    ? GrassForm.greenLine
                    : SportSphereColors.muted,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: widget.suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: widget.suffixIcon,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Primary button ─────────────────────────────────────────────────────────────

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
                    GrassForm.greenLine.withValues(alpha: 0.6),
                    const Color(0xFF0055BB).withValues(alpha: 0.6),
                  ]
                : [
                    GrassForm.greenLine,
                    const Color(0xFF0066DD),
                  ],
          ),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: GrassForm.greenLine.withValues(alpha: 0.40),
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
                    letterSpacing: 0.4,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Outline button ─────────────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: SportSphereColors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OR divider ─────────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.14),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

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
            child: Icon(
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

// ── Terms text ─────────────────────────────────────────────────────────────────

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
              color: GrassForm.greenLine,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: '  and  '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: GrassForm.greenLine,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ambient orb ────────────────────────────────────────────────────────────────

class _AmbientOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _AmbientOrb({required this.color, required this.size});

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
              color.withValues(alpha: 0.11),
              color.withValues(alpha: 0.03),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
