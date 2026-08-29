// lib/features/auth/presentation/pages/set_password_modal.dart
// Shown when a migrated user tries to login.
// Verifies identity via DOB or OTP before allowing password set.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/vps_repository.dart';
import '../../../../core/theme/colors.dart';

const _kBlue = PlayifyColors.electricBlue;

enum _VerifyMethod { dob, otp }
enum _Step { chooseMethod, verify, setPassword }

/// Show this modal when PASSWORD_NOT_SET — lets user verify + set new password.
Future<bool> showSetPasswordModal(BuildContext context, String email) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SetPasswordModal(email: email),
  );
  return result == true;
}

class _SetPasswordModal extends ConsumerStatefulWidget {
  final String email;
  const _SetPasswordModal({required this.email});
  @override
  ConsumerState<_SetPasswordModal> createState() => _SetPasswordModalState();
}

class _SetPasswordModalState extends ConsumerState<_SetPasswordModal> {
  _Step _step = _Step.chooseMethod;
  _VerifyMethod _method = _VerifyMethod.dob;

  // DOB verification
  DateTime? _dob;

  // OTP
  final _otpCtrl = TextEditingController();
  bool _otpSent  = false;
  bool _sending  = false;
  int _countdown = 0;
  Timer? _timer;

  // New password
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false, _showConfirm = false;

  bool _loading = false;
  String? _error;

  static final _vps = const VpsRepository();

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  // ── OTP ──────────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    setState(() { _sending = true; _error = null; });
    try {
      await _vps.post<void>('/v1/auth/otp/send', data: {'email': widget.email});
      _startCountdown();
      setState(() { _otpSent = true; _sending = false; });
    } catch (e) {
      setState(() { _error = 'Could not send code — try DOB verification instead'; _sending = false; });
    }
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdown > 0) setState(() => _countdown--);
      else _timer?.cancel();
    });
  }

  // ── Verify ───────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_method == _VerifyMethod.dob) {
        if (_dob == null) { setState(() { _error = 'Select your date of birth'; _loading = false; }); return; }
        await _vps.post<void>('/v1/auth/verify-identity', data: {
          'email': widget.email,
          'dob':   _dob!.toIso8601String(),
          'method': 'dob',
        });
      } else {
        final code = _otpCtrl.text.trim();
        if (code.length != 6) { setState(() { _error = 'Enter the 6-digit code'; _loading = false; }); return; }
        await _vps.post<void>('/v1/auth/verify-identity', data: {
          'email':  widget.email,
          'otp':    code,
          'method': 'otp',
        });
      }
      setState(() { _step = _Step.setPassword; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Verification failed — check your details'; _loading = false; });
    }
  }

  // ── Set password ──────────────────────────────────────────────────────────

  Future<void> _setPassword() async {
    final pass = _passCtrl.text;
    if (pass.length < 8) { setState(() => _error = 'At least 8 characters'); return; }
    if (pass != _confirmCtrl.text) { setState(() => _error = 'Passwords do not match'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await _vps.post<void>('/v1/auth/set-password', data: {
        'email':    widget.email,
        'password': pass,
        'method':   _method.name,
        'dob':      _dob?.toIso8601String(),
        'otp':      _otpCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = 'Failed to set password — try again'; _loading = false; });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // Title
          Row(children: [
            const Icon(Icons.lock_reset_rounded, color: _kBlue, size: 24),
            const SizedBox(width: 10),
            Text(_stepTitle(), style: const TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(_stepSubtitle(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          const SizedBox(height: 20),

          // Error
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
            const SizedBox(height: 14),
          ],

          // Step content
          if (_step == _Step.chooseMethod) _buildChooseMethod(),
          if (_step == _Step.verify)       _buildVerify(),
          if (_step == _Step.setPassword)  _buildSetPassword(),
        ],
      )),
    );
  }

  String _stepTitle() => switch (_step) {
    _Step.chooseMethod => 'Verify Your Identity',
    _Step.verify       => _method == _VerifyMethod.dob ? 'Enter Date of Birth' : 'Enter OTP Code',
    _Step.setPassword  => 'Set New Password',
  };

  String _stepSubtitle() => switch (_step) {
    _Step.chooseMethod => 'Choose how to verify your identity',
    _Step.verify       => _method == _VerifyMethod.dob
        ? 'Enter the date of birth linked to your account'
        : 'Enter the 6-digit code sent to ${widget.email}',
    _Step.setPassword  => 'Choose a strong password for your account',
  };

  Widget _buildChooseMethod() => Column(children: [
    // DOB option
    _MethodTile(
      icon: Icons.cake_outlined,
      title: 'Date of Birth',
      subtitle: 'Verify using your date of birth',
      selected: _method == _VerifyMethod.dob,
      onTap: () => setState(() => _method = _VerifyMethod.dob),
    ),
    const SizedBox(height: 10),
    // OTP option
    _MethodTile(
      icon: Icons.sms_outlined,
      title: 'Email / SMS Code',
      subtitle: 'Get a one-time code sent to ${widget.email}',
      selected: _method == _VerifyMethod.otp,
      onTap: () => setState(() => _method = _VerifyMethod.otp),
    ),
    const SizedBox(height: 24),
    _ActionBtn(label: 'Continue', onTap: () {
      setState(() { _step = _Step.verify; _error = null; });
      if (_method == _VerifyMethod.otp && !_otpSent) _sendOtp();
    }),
  ]);

  Widget _buildVerify() => Column(children: [
    if (_method == _VerifyMethod.dob) ...[
      // DOB picker
      GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(now.year - 20),
            firstDate: DateTime(1920), lastDate: DateTime(now.year - 5),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.dark(primary: _kBlue, surface: Color(0xFF0D1F35)),
              ), child: child!,
            ),
          );
          if (picked != null) setState(() { _dob = picked; _error = null; });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _dob != null ? _kBlue : Colors.white.withValues(alpha: 0.1),
                width: _dob != null ? 1.5 : 1),
          ),
          child: Row(children: [
            Icon(Icons.cake_outlined, color: _dob != null ? _kBlue : Colors.white38, size: 20),
            const SizedBox(width: 12),
            Text(_dob == null ? 'Select date of birth'
                : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                style: TextStyle(color: _dob != null ? Colors.white : Colors.white38,
                    fontSize: 15)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
          ]),
        ),
      ),
    ] else ...[
      // OTP input
      if (_sending)
        const Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2))
      else ...[
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 28,
              fontWeight: FontWeight.w900, letterSpacing: 12),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15),
                fontSize: 28, letterSpacing: 12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: _countdown > 0
          ? Text('Resend in ${_countdown}s',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13))
          : TextButton(onPressed: _sendOtp,
              child: const Text('Resend Code', style: TextStyle(color: _kBlue,
                  fontWeight: FontWeight.w700)))),
      ],
    ],
    const SizedBox(height: 24),
    Row(children: [
      Expanded(child: OutlinedButton(
        onPressed: () => setState(() { _step = _Step.chooseMethod; _error = null; }),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white54,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('Back'),
      )),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: _ActionBtn(
        label: _loading ? 'Verifying…' : 'Verify',
        onTap: _loading ? null : _verify,
      )),
    ]),
  ]);

  Widget _buildSetPassword() => Column(children: [
    _PassField(ctrl: _passCtrl, label: 'New Password',
        show: _showPass, onToggle: () => setState(() => _showPass = !_showPass)),
    const SizedBox(height: 14),
    _PassField(ctrl: _confirmCtrl, label: 'Confirm Password',
        show: _showConfirm, onToggle: () => setState(() => _showConfirm = !_showConfirm)),
    const SizedBox(height: 24),
    _ActionBtn(
      label: _loading ? 'Setting password…' : 'Set Password & Login',
      onTap: _loading ? null : _setPassword,
      color: const Color(0xFF4CAF50),
    ),
  ]);
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _MethodTile extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  final bool selected; final VoidCallback onTap;
  const _MethodTile({required this.icon, required this.title, required this.subtitle,
      required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? _kBlue.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? _kBlue : Colors.white.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(icon, color: selected ? _kBlue : Colors.white54, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: selected ? _kBlue : Colors.white,
              fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
        ])),
        if (selected) const Icon(Icons.check_circle_rounded, color: _kBlue, size: 20),
      ]),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label; final VoidCallback? onTap; final Color? color;
  const _ActionBtn({required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color ?? _kBlue,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    ),
  );
}

class _PassField extends StatelessWidget {
  final TextEditingController ctrl; final String label;
  final bool show; final VoidCallback onToggle;
  const _PassField({required this.ctrl, required this.label,
      required this.show, required this.onToggle});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, obscureText: !show,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 18),
      suffixIcon: IconButton(
        icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white38, size: 18),
        onPressed: onToggle,
      ),
      filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBlue, width: 1.5)),
    ),
  );
}
