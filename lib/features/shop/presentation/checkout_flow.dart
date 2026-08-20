import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../models/shop_models.dart';

Future<void> openCheckout(
  BuildContext context, {
  required ShopCatalog catalog,
  required CartLine line,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CheckoutSheet(catalog: catalog, line: line),
  );
}

class _CheckoutSheet extends StatefulWidget {
  final ShopCatalog catalog;
  final CartLine line;
  const _CheckoutSheet({required this.catalog, required this.line});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  late int _qty;
  late int _donateAmount;
  bool _paying = false;
  final _phoneCtrl = TextEditingController();
  bool _done = false;
  String _method = 'M-Pesa';
  static const _donatePresets = [5000, 10000, 25000, 50000];

  @override
  void initState() {
    super.initState();
    _qty = widget.line.qty;
    _donateAmount =
        widget.line.item.priceTzs == 0 ? 10000 : widget.line.item.priceTzs;
  }

  int get _unit => widget.line.item.kind == ShopItemKind.donation
      ? _donateAmount
      : widget.line.item.priceTzs;
  int get _total => _unit * _qty;

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return 'TZS $buf';
  }

  Future<void> _pay() async {
    if (_paying) return;
    HapticFeedback.mediumImpact();
    setState(() => _paying = true);
    try {
      final item = widget.line.item;
      final unit = item.kind == ShopItemKind.donation ? _donateAmount : item.priceTzs;
      final qty = item.kind == ShopItemKind.membership || item.kind == ShopItemKind.donation
          ? 1
          : _qty;
      final commerce = CommerceRepository();
      final method = _method.toLowerCase().contains('pesa')
          ? 'mpesa'
          : _method.toLowerCase().contains('airtel')
              ? 'airtel'
              : 'card';
      final orderId = await commerce.placeOrder(
        itemId: item.id,
        itemName: item.name,
        kind: item.kind.name,
        unitPriceTzs: unit,
        quantity: qty,
        sellerHandle: widget.catalog.sellerHandle,
        sellerName: widget.catalog.sellerName,
        paymentMethod: method,
        phone: _phoneCtrl.text.trim(),
      );
      if (method == 'mpesa') {
        final phone = _phoneCtrl.text.trim();
        if (phone.isEmpty) {
          throw StateError('Enter M-Pesa phone (07… or 254…)');
        }
        final stk = await commerce.initiateMpesaStk(
          orderId: orderId,
          phone: phone,
          amountTzs: unit * qty,
        );
        if (stk['error'] != null && stk['ResponseCode'] != '0') {
          // Still show done with pending if secrets missing
          debugPrint('STK: $stk');
        }
      }
      if (!mounted) return;
      setState(() {
        _paying = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.line.item;
    final accent = item.accent ?? widget.catalog.accent;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF071422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          top: false,
          child: _done ? _success(accent) : _form(item, accent),
        ),
      ),
    );
  }

  Widget _form(ShopItem item, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          switch (item.kind) {
            ShopItemKind.donation => 'Donate',
            ShopItemKind.ticket => 'Buy ticket',
            ShopItemKind.membership => 'Join membership',
            ShopItemKind.merch => 'Checkout',
          },
          style: const TextStyle(
              color: SportSphereColors.white, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(widget.catalog.sellerName,
            style: const TextStyle(color: SportSphereColors.muted, fontSize: 13)),
        const SizedBox(height: 16),
        GlassContainer(
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          color: SportSphereColors.white, fontWeight: FontWeight.w700)),
                  Text(item.subtitle,
                      style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
        if (item.kind == ShopItemKind.donation) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _donatePresets.map((v) {
              final on = _donateAmount == v;
              return GestureDetector(
                onTap: () => setState(() => _donateAmount = v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: on ? accent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: on ? accent : Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Text(_fmt(v),
                      style: TextStyle(
                        color: on ? accent : SportSphereColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                ),
              );
            }).toList(),
          ),
        ] else if (item.kind != ShopItemKind.membership) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Text('Quantity', style: TextStyle(color: SportSphereColors.muted)),
            const Spacer(),
            _QtyBtn(icon: Icons.remove, onTap: () { if (_qty > 1) setState(() => _qty--); }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('$_qty',
                  style: const TextStyle(
                      color: SportSphereColors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            _QtyBtn(icon: Icons.add, onTap: () => setState(() => _qty++)),
          ]),
        ],
        const SizedBox(height: 18),
        Row(children: [
          for (final m in const ['M-Pesa', 'Airtel Money', 'Card']) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _method = m),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _method == m
                        ? accent.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                        color: _method == m ? accent : Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Text(m,
                      style: TextStyle(
                        color: _method == m ? accent : SportSphereColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ),
            ),
            if (m != 'Card') const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 20),
        Row(children: [
          const Text('Total', style: TextStyle(color: SportSphereColors.muted)),
          const Spacer(),
          Text(_fmt(_total),
              style: const TextStyle(
                  color: SportSphereColors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _paying ? null : _pay,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.75)]),
            ),
            child: Center(
              child: _paying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      item.kind == ShopItemKind.donation ? 'Donate now' : 'Pay ${_fmt(_total)}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('Demo payment recorded (no M-Pesa charge yet)',
              style: TextStyle(color: SportSphereColors.muted, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _success(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, color: accent, size: 64),
        const SizedBox(height: 12),
        const Text('Order recorded',
            style: TextStyle(
                color: SportSphereColors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${_fmt(_total)} via $_method\nA receipt was sent to your SportSphere inbox.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SportSphereColors.muted, height: 1.4)),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: const Center(
              child: Text('Done',
                  style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: 16, color: SportSphereColors.white),
      ),
    );
  }
}
