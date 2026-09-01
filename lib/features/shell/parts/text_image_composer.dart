// lib/features/shell/parts/text_image_composer.dart
// Compose a "text card" — text rendered over a background color/gradient.
// Output: PNG bytes that get uploaded to R2 like any photo.

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';

const _kBlue = PlayifyColors.electricBlue;

// ── Presets ────────────────────────────────────────────────────────────────────
class _BgPreset {
  final String label;
  final List<Color> colors;
  final bool isDark;
  const _BgPreset(this.label, this.colors, {this.isDark = true});
}

const _kPresets = [
  _BgPreset('Night',    [Color(0xFF0A0E1C), Color(0xFF0D1F35)]),
  _BgPreset('Ocean',    [Color(0xFF006994), Color(0xFF0099CC)]),
  _BgPreset('Sunset',   [Color(0xFFFF6B35), Color(0xFFFF8E53), Color(0xFFFFB347)]),
  _BgPreset('Forest',   [Color(0xFF134E5E), Color(0xFF71B280)]),
  _BgPreset('Purple',   [Color(0xFF4A00E0), Color(0xFF8E2DE2)]),
  _BgPreset('Crimson',  [Color(0xFF8B0000), Color(0xFFDC143C)]),
  _BgPreset('Gold',     [Color(0xFF2C1810), Color(0xFFFFD700)]),
  _BgPreset('Mint',     [Color(0xFF00B4DB), Color(0xFF0083B0)]),
  _BgPreset('Rose',     [Color(0xFFFF758C), Color(0xFFFF7EB3)]),
  _BgPreset('Charcoal', [Color(0xFF232526), Color(0xFF414345)]),
  _BgPreset('White',    [Color(0xFFFFFFFF), Color(0xFFF0F0F0)], isDark: false),
  _BgPreset('Cream',    [Color(0xFFFFF8DC), Color(0xFFFFFACD)], isDark: false),
];

const _kFonts = ['Default', 'Bold', 'Light', 'Italic', 'Mono'];
const _kAligns = [TextAlign.left, TextAlign.center, TextAlign.right];
const _kAlignIcons = [Icons.format_align_left_rounded,
    Icons.format_align_center_rounded, Icons.format_align_right_rounded];

/// Opens the text-image composer. Returns PNG bytes or null if cancelled.
Future<Uint8List?> openTextImageComposer(BuildContext context) =>
    showModalBottomSheet<Uint8List?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TextImageComposer(),
    );

class _TextImageComposer extends StatefulWidget {
  const _TextImageComposer();
  @override
  State<_TextImageComposer> createState() => _TextImageComposerState();
}

class _TextImageComposerState extends State<_TextImageComposer> {
  final _ctrl       = TextEditingController();
  final _repaintKey = GlobalKey();

  int    _bgIndex   = 0;
  int    _fontIndex = 0;
  int    _alignIdx  = 1; // center default
  double _fontSize  = 28;
  bool   _exporting = false;

  _BgPreset get _bg => _kPresets[_bgIndex];

  Color get _textColor => _bg.isDark ? Colors.white : Colors.black87;

  FontWeight get _fontWeight => _fontIndex == 1 ? FontWeight.w900 : FontWeight.w500;
  FontStyle  get _fontStyle  => _fontIndex == 3 ? FontStyle.italic : FontStyle.normal;
  String?    get _fontFamily => _fontIndex == 4 ? 'monospace' : null;

  Future<Uint8List?> _capture() async {
    final boundary = _repaintKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _done() async {
    if (_ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Type something first'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = await _capture();
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.92;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 4),

        // Top bar
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
              onPressed: () => Navigator.pop(context, null),
            ),
            const Expanded(child: Text('Text Card',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w800))),
            _exporting
              ? const SizedBox(width: 44, height: 44,
                  child: Center(child: CircularProgressIndicator(
                      color: _kBlue, strokeWidth: 2)))
              : FilledButton(
                  onPressed: _done,
                  style: FilledButton.styleFrom(backgroundColor: _kBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('Post', style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
                ),
          ]),
        ),

        // Preview card (the thing that gets rendered to PNG)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _bg.colors,
                    ),
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Center(child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _fontSize,
                      fontWeight: _fontWeight,
                      fontStyle: _fontStyle,
                      fontFamily: _fontFamily,
                      height: 1.4,
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: _ctrl,
                      builder: (_, __, ___) => Text(
                        _ctrl.text.isEmpty ? 'Type your text...' : _ctrl.text,
                        textAlign: _kAligns[_alignIdx],
                        style: TextStyle(
                          color: _ctrl.text.isEmpty
                              ? _textColor.withValues(alpha: 0.35)
                              : _textColor,
                          fontSize: _fontSize,
                          fontWeight: _fontWeight,
                          fontStyle: _fontStyle,
                          fontFamily: _fontFamily,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )),
                ),
              ),
            ),
          ),
        ),

        // Font size slider
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            const Icon(Icons.text_fields_rounded, color: Colors.white38, size: 16),
            Expanded(child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _kBlue,
                inactiveTrackColor: Colors.white12,
                thumbColor: _kBlue,
                overlayColor: _kBlue.withValues(alpha: 0.15),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _fontSize,
                min: 14, max: 56,
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            )),
            const Icon(Icons.text_fields_rounded, color: Colors.white, size: 22),
          ]),
        ),

        // Controls row
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            // Alignment
            ..._kAlignIcons.asMap().entries.map((e) => GestureDetector(
              onTap: () => setState(() => _alignIdx = e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _alignIdx == e.key
                      ? _kBlue.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _alignIdx == e.key ? _kBlue : Colors.transparent),
                ),
                child: Icon(e.value,
                    color: _alignIdx == e.key ? _kBlue : Colors.white54, size: 18),
              ),
            )),
            const SizedBox(width: 8),
            // Font style
            ..._kFonts.asMap().entries.map((e) => GestureDetector(
              onTap: () => setState(() => _fontIndex = e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _fontIndex == e.key
                      ? _kBlue.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _fontIndex == e.key ? _kBlue : Colors.transparent),
                ),
                child: Text(e.value[0],
                    style: TextStyle(
                      color: _fontIndex == e.key ? _kBlue : Colors.white54,
                      fontSize: 13, fontWeight: FontWeight.w700,
                    )),
              ),
            )),
          ]),
        ),

        // Background color presets
        Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Background', style: TextStyle(
                  color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 52, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kPresets.length,
              itemBuilder: (_, i) {
                final p = _kPresets[i];
                final sel = _bgIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _bgIndex = i),
                  child: Container(
                    width: 44, height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: p.colors,
                      ),
                      border: Border.all(
                        color: sel ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: sel ? [BoxShadow(
                          color: p.colors.first.withValues(alpha: 0.5),
                          blurRadius: 8)] : null,
                    ),
                    child: sel ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20) : null,
                  ),
                );
              },
            )),
          ]),
        ),

        // Text input
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16,
              MediaQuery.of(context).viewInsets.bottom + 16),
          child: TextField(
            controller: _ctrl,
            maxLines: 4,
            maxLength: 280,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Write something inspiring...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(280)],
          ),
        ),
      ]),
    );
  }
}
