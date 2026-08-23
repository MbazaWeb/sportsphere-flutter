import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class ProfileBadge extends StatelessWidget {
  const ProfileBadge({
  final String label;
  final Color? color;

    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? SportSphereColors.electricBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.40)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
