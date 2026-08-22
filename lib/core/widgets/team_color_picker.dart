import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Preset club colours + optional custom hex for team branding.
const kTeamColorPresets = <Color>[
  Color(0xFFE31B23), // red
  Color(0xFF168CFF), // blue
  Color(0xFF76D42B), // green
  Color(0xFFFF8A00), // orange
  Color(0xFFFFD700), // gold
  Color(0xFF9B6DFF), // purple
  Color(0xFF111111), // black
  Color(0xFFFFFFFF), // white
  Color(0xFF00C896), // teal
  Color(0xFFFF3B61), // pink/red
  Color(0xFF0A5F9E), // navy
  Color(0xFF8B4513), // brown
];

String colorToHex(Color c) {
  final r = ((c.r * 255.0).round() & 0xff);
  final g = ((c.g * 255.0).round() & 0xff);
  final b = ((c.b * 255.0).round() & 0xff);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
}

Color? parseHexColor(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(v);
}

class TeamColorPicker extends StatelessWidget {
  final String? valueHex;
  final ValueChanged<String> onChanged;
  final String label;

  const TeamColorPicker({
    super.key,
    required this.valueHex,
    required this.onChanged,
    this.label = 'Team colour',
  });

  @override
  Widget build(BuildContext context) {
    final selected = parseHexColor(valueHex) ?? kTeamColorPresets.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: SportSphereColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in kTeamColorPresets)
                GestureDetector(
                  onTap: () => onChanged(colorToHex(c)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorToHex(selected) == colorToHex(c)
                            ? SportSphereColors.electricBlue
                            : Colors.white.withValues(alpha: 0.25),
                        width: colorToHex(selected) == colorToHex(c) ? 3 : 1,
                      ),
                      boxShadow: [
                        if (colorToHex(c) == '#FFFFFF')
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                          ),
                      ],
                    ),
                    child: colorToHex(selected) == colorToHex(c)
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: c.computeLuminance() > 0.55
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valueHex ?? colorToHex(selected),
            style: const TextStyle(
                color: SportSphereColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
