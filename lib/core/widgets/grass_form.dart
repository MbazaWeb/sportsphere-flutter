import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Pitch / grass palette for Playify forms.
class GrassForm {
  GrassForm._();

  static const greenDeep = Color(0xFF0D3B1E);
  static const greenMid = Color(0xFF1B5E20);
  static const greenBright = Color(0xFF2E7D32);
  static const greenLine = Color(0xFF76D42B);
  static const turf = Color(0xFF0A1F12);
  static const sheetBg = Color(0xFF071422);
  static const fieldFill = Color(0xFF0B1A14);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenDeep, greenMid, greenBright, greenMid],
  );

  static BoxDecoration pitchDecoration({
    BorderRadius? radius,
    double borderAlpha = 0.45,
  }) {
    return BoxDecoration(
      borderRadius: radius ?? BorderRadius.circular(18),
      gradient: gradient,
      border: Border.all(
        color: greenLine.withValues(alpha: borderAlpha),
        width: 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: greenLine.withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

/// Custom painter: subtle pitch lines.
class GrassPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final stripe = size.width / 10;
    for (var i = 1; i < 10; i++) {
      final x = stripe * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.22,
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom sheet shell with grass header band.
class GrassFormSheet extends StatelessWidget {

  const GrassFormSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.sports_soccer_rounded,
    required this.children,
    this.footer,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? footer;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData icon = Icons.sports_soccer_rounded,
    required List<Widget> children,
    Widget? footer,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GrassForm.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => GrassFormSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        footer: footer,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              GrassFormHeader(
                title: title,
                subtitle: subtitle,
                icon: icon,
              ),
              const SizedBox(height: 16),
              ...children,
              if (footer != null) ...[
                const SizedBox(height: 16),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GrassFormHeader extends StatelessWidget {

  const GrassFormHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.sports_soccer_rounded,
  });
  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: GrassForm.pitchDecoration(),
      child: CustomPaint(
        painter: GrassPitchPainter(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text field with turf fill + green focus ring.
class GrassTextField extends StatelessWidget {

  const GrassTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.obscure = false,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscure;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: const TextStyle(
          color: PlayifyColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: GrassForm.greenLine,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(
            color: PlayifyColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color: PlayifyColors.muted.withValues(alpha: 0.55),
            fontSize: 13,
          ),
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: GrassForm.greenLine, size: 18),
          filled: true,
          fillColor: GrassForm.fieldFill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: GrassForm.greenLine.withValues(alpha: 0.22),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GrassForm.greenLine, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: PlayifyColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: PlayifyColors.danger, width: 1.6),
          ),
        ),
      ),
    );
  }
}

/// Primary CTA with grass gradient.
class GrassSubmitButton extends StatelessWidget {

  const GrassSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: onPressed == null || loading
              ? LinearGradient(colors: [
                  GrassForm.greenMid.withValues(alpha: 0.45),
                  GrassForm.greenBright.withValues(alpha: 0.45),
                ])
              : GrassForm.gradient,
          boxShadow: onPressed == null || loading
              ? null
              : [
                  BoxShadow(
                    color: GrassForm.greenLine.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Upload tile with pitch background.
class GrassUploadTile extends StatelessWidget {

  const GrassUploadTile({
    super.key,
    required this.label,
    required this.onTap,
    this.url,
    this.uploading = false,
  });
  final String label;
  final String? url;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = url != null && url!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: uploading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 88,
            decoration: GrassForm.pitchDecoration(
              radius: BorderRadius.circular(16),
              borderAlpha: done ? 0.7 : 0.35,
            ),
            child: CustomPaint(
              painter: GrassPitchPainter(),
              child: Center(
                child: uploading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle_rounded
                                : Icons.cloud_upload_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            done ? 'Uploaded ✓' : label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section label used inside long forms.
class GrassSectionLabel extends StatelessWidget {
  const GrassSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: GrassForm.greenLine,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: GrassForm.greenLine.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}


/// Styled dropdown matching grass form fields.
class GrassDropdown<T> extends StatelessWidget {

  const GrassDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.icon,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        dropdownColor: GrassForm.sheetBg,
        style: const TextStyle(color: PlayifyColors.white, fontSize: 14),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: GrassForm.greenLine),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: PlayifyColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: GrassForm.greenLine, size: 18),
          filled: true,
          fillColor: GrassForm.fieldFill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: GrassForm.greenLine.withValues(alpha: 0.22),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: GrassForm.greenLine, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: PlayifyColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: PlayifyColors.danger, width: 1.6),
          ),
        ),
      ),
    );
  }
}
