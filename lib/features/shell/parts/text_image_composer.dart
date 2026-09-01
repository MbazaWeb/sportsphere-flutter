// lib/features/shell/parts/text_image_composer.dart
// Text Card composer — headline + body text on gradient background.

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';

const _kBlue = PlayifyColors.electricBlue;
const _kGold = Color(0xFFFFD700);

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

const _kAligns    = [TextAlign.left, TextAlign.center, TextAlign.right];
const _kAlignIcons = [
  Icons.format_align_left_rounded,
  Icons.format_align_center_rounded,
  Icons.format_align_right_rounded,
];

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

class _TextImageComposerState extends State<_TextImageComposer>
    with SingleTickerProviderStateMixin {
  final _headCtrl   = TextEditingController();
  final _bodyCtrl   = TextEditingController();
  final _repaintKey = GlobalKey();
  late final TabController _tabCtrl;

  int    _bgIndex   = 0;
  int    _alignIdx  = 1;
  double _headSize  = 32;
  double _bodySize  = 18;
  bool   _boldHead  = true;
  bool   _exporting = false;

  // 0 = editing header, 1 = editing body
  int _activeField = 0;

  _BgPreset get _bg => _kPresets[_bgIndex];
  Color get _textColor => _bg.isDark ? Colors.white : Colors.black87;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() => _activeField = _tabCtrl.index));
  }

  @override
  void dispose() {
    _headCtrl.dispose();
    _bodyCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_headCtrl.text.trim().isEmpty && _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a headline or body text'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _exporting = true);
    try {
      final boundary = _repaintKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.94;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2))),

        // Top bar
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
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
              ? const SizedBox(width: 56, height: 36,
                  child: Center(child: CircularProgressIndicator(
                      color: _kBlue, strokeWidth: 2)))
              : FilledButton(
                  onPressed: _done,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Post',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
          ]),
        ),

        // Live preview
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _bg.colors,
                  ),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: _alignIdx == 0
                      ? CrossAxisAlignment.start
                      : _alignIdx == 2
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.center,
                  children: [
                    // Headline
                    ValueListenableBuilder(
                      valueListenable: _headCtrl,
                      builder: (_, __, ___) {
                        final text = _headCtrl.text;
                        if (text.isEmpty && _bodyCtrl.text.isNotEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          text.isEmpty ? 'Headline...' : text,
                          textAlign: _kAligns[_alignIdx],
                          style: TextStyle(
                            color: text.isEmpty
                                ? _textColor.withValues(alpha: 0.3)
                                : _textColor,
                            fontSize: _headSize,
                            fontWeight: _boldHead
                                ? FontWeight.w900 : FontWeight.w600,
                            height: 1.2,
                          ),
                        );
                      },
                    ),
                    // Divider if both fields have content
                    ValueListenableBuilder(
                      valueListenable: _headCtrl,
                      builder: (_, __, ___) => ValueListenableBuilder(
                        valueListenable: _bodyCtrl,
                        builder: (_, __, ___) {
                          if (_headCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Container(
                              height: 1.5,
                              color: _textColor.withValues(alpha: 0.25),
                            ),
                          );
                        },
                      ),
                    ),
                    // Body
                    ValueListenableBuilder(
                      valueListenable: _bodyCtrl,
                      builder: (_, __, ___) {
                        final text = _bodyCtrl.text;
                        if (text.isEmpty && _headCtrl.text.isNotEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          text.isEmpty ? 'Body text...' : text,
                          textAlign: _kAligns[_alignIdx],
                          style: TextStyle(
                            color: text.isEmpty
                                ? _textColor.withValues(alpha: 0.3)
                                : _textColor.withValues(alpha: 0.85),
                            fontSize: _bodySize,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Tab switcher: Headline / Body
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: _kGold,
            unselectedLabelColor: Colors.white38,
            indicatorColor: _kGold,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [Tab(text: 'Headline'), Tab(text: 'Body')],
          ),
        ),

        // Controls for active field
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: _activeField == 0
              ? _HeadlineControls(
                  size: _headSize,
                  bold: _boldHead,
                  onSizeChanged: (v) => setState(() => _headSize = v),
                  onBoldChanged: (v) => setState(() => _boldHead = v),
                )
              : _BodyControls(
                  size: _bodySize,
                  onSizeChanged: (v) => setState(() => _bodySize = v),
                ),
        ),

        // Alignment + backgrounds
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(children: [
            // Alignment
            ..._kAlignIcons.asMap().entries.map((e) => GestureDetector(
              onTap: () => setState(() => _alignIdx = e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _alignIdx == e.key
                      ? _kBlue.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _alignIdx == e.key ? _kBlue : Colors.transparent),
                ),
                child: Icon(e.value,
                    color: _alignIdx == e.key ? _kBlue : Colors.white38,
                    size: 18),
              ),
            )),
            const Spacer(),
            // BG presets (horizontal scroll mini)
            SizedBox(height: 32, width: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _kPresets.length,
                itemBuilder: (_, i) {
                  final p = _kPresets[i];
                  final sel = _bgIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _bgIndex = i),
                    child: Container(
                      width: 32, height: 32,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: p.colors,
                        ),
                        border: Border.all(
                          color: sel ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: sel
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ]),
        ),

        // Text inputs
        Expanded(child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16,
              MediaQuery.of(context).viewInsets.bottom + 12),
          child: TabBarView(controller: _tabCtrl, children: [
            // Headline input
            TextField(
              controller: _headCtrl,
              maxLines: 3,
              maxLength: 100,
              style: TextStyle(color: Colors.white,
                  fontSize: 17, fontWeight: FontWeight.w700),
              decoration: _inputDeco('Headline text...',
                  'Short, punchy headline (max 100 chars)'),
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
            ),
            // Body input
            TextField(
              controller: _bodyCtrl,
              maxLines: 5,
              maxLength: 280,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: _inputDeco('Body text...',
                  'Supporting text, quote, or detail (max 280 chars)'),
              inputFormatters: [LengthLimitingTextInputFormatter(280)],
            ),
          ]),
        )),
      ]),
    );
  }

  InputDecoration _inputDeco(String hint, String helper) => InputDecoration(
    hintText: hint,
    helperText: helper,
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
    helperStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    counterStyle: const TextStyle(color: Colors.white24, fontSize: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kGold, width: 1.5)),
  );
}

// ── Headline controls ──────────────────────────────────────────────────────────
class _HeadlineControls extends StatelessWidget {
  final double size; final bool bold;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<bool> onBoldChanged;
  const _HeadlineControls({required this.size, required this.bold,
      required this.onSizeChanged, required this.onBoldChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Text('H', style: TextStyle(color: Colors.white54,
        fontSize: 12, fontWeight: FontWeight.w600)),
    Expanded(child: SliderTheme(
      data: SliderThemeData(
        activeTrackColor: _kGold,
        inactiveTrackColor: Colors.white12,
        thumbColor: _kGold,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayColor: _kGold.withValues(alpha: 0.15),
      ),
      child: Slider(value: size, min: 20, max: 52,
          onChanged: onSizeChanged),
    )),
    Text('${size.toInt()}px',
        style: const TextStyle(color: Colors.white38, fontSize: 11, width: 36)),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: () => onBoldChanged(!bold),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bold ? _kGold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: bold ? _kGold : Colors.transparent),
        ),
        child: Text('B', style: TextStyle(
          color: bold ? _kGold : Colors.white38,
          fontWeight: FontWeight.w900, fontSize: 14,
        )),
      ),
    ),
  ]);
}

// ── Body controls ──────────────────────────────────────────────────────────────
class _BodyControls extends StatelessWidget {
  final double size;
  final ValueChanged<double> onSizeChanged;
  const _BodyControls({required this.size, required this.onSizeChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Text('B', style: TextStyle(color: Colors.white54,
        fontSize: 11, fontWeight: FontWeight.w600)),
    Expanded(child: SliderTheme(
      data: SliderThemeData(
        activeTrackColor: _kBlue,
        inactiveTrackColor: Colors.white12,
        thumbColor: _kBlue,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayColor: _kBlue.withValues(alpha: 0.15),
      ),
      child: Slider(value: size, min: 12, max: 32,
          onChanged: onSizeChanged),
    )),
    Text('${size.toInt()}px',
        style: const TextStyle(color: Colors.white38, fontSize: 11)),
    const SizedBox(width: 12),
    Text('Regular', style: TextStyle(
        color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
  ]);
}
