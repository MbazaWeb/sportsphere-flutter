import 'package:flutter/material.dart';

import '../data/world_countries.dart';
import '../theme/colors.dart';
import 'grass_form.dart';

/// Searchable world-country selector (ISO list from [kWorldCountries]).
Future<String?> showCountryPicker(
  BuildContext context, {
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _CountryPickerSheet(selected: selected),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final String? selected;
  const _CountryPickerSheet({this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _search = TextEditingController();
  late List<WorldCountry> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = kWorldCountries;
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? kWorldCountries
          : kWorldCountries
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select country',
                    style: TextStyle(
                      color: PlayifyColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: PlayifyColors.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              style: const TextStyle(color: PlayifyColors.white),
              decoration: InputDecoration(
                hintText: 'Search country…',
                hintStyle: const TextStyle(color: PlayifyColors.muted),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: PlayifyColors.muted, size: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final sel = widget.selected != null &&
                    (widget.selected!.toLowerCase() == c.name.toLowerCase() ||
                        widget.selected!.toLowerCase() ==
                            c.code.toLowerCase());
                return ListTile(
                  title: Text(
                    c.name,
                    style: TextStyle(
                      color: sel
                          ? PlayifyColors.electricBlue
                          : PlayifyColors.white,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(c.code,
                      style: const TextStyle(
                          color: PlayifyColors.muted, fontSize: 11)),
                  trailing: sel
                      ? const Icon(Icons.check_rounded,
                          color: PlayifyColors.electricBlue, size: 20)
                      : null,
                  onTap: () => Navigator.pop(context, c.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable field that opens [showCountryPicker].
class CountryPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final String? Function(String?)? validator;

  const CountryPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Select country',
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FormField<String>(
        initialValue: value,
        validator: validator ??
            (v) {
              final cur = value ?? v;
              if (cur == null || cur.trim().isEmpty) {
                return 'Select country';
              }
              return null;
            },
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final picked = await showCountryPicker(context, selected: value);
          if (picked != null) {
            onChanged(picked);
            state.didChange(picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: PlayifyColors.muted),
            filled: true,
            fillColor: GrassForm.fieldFill,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: GrassForm.greenLine.withValues(alpha: 0.22)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: GrassForm.greenLine, width: 1.6),
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded,
                color: GrassForm.greenLine),
          ),
          child: Text(
            (value == null || value!.isEmpty) ? placeholder : value!,
            style: TextStyle(
              color: (value == null || value!.isEmpty)
                  ? PlayifyColors.muted
                  : PlayifyColors.white,
              fontSize: 15,
            ),
          ),
        ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6),
                  child: Text(
                    state.errorText!,
                    style: const TextStyle(
                        color: Color(0xFFE31B23), fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
